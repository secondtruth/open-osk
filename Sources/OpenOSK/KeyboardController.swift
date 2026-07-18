import AppKit
import AVFoundation
import OpenOSKCore

/// Coordinates the keyboard panel: key handling, modifier latching,
/// predictions, typing aids, dwell, macros and terminal mode.
final class KeyboardController: NSObject {
    enum ModifierState {
        case off
        case latched
        case locked

        var isActive: Bool { self != .off }

        var next: ModifierState {
            switch self {
            case .off: return .latched
            case .latched: return .locked
            case .locked: return .off
            }
        }

        var visual: ModifierVisualState {
            switch self {
            case .off: return .off
            case .latched: return .latched
            case .locked: return .locked
            }
        }
    }

    /// Bundle identifiers treated as terminals for command completion.
    static let terminalBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
        "com.mitchellh.ghostty",
        "org.alacritty",
        "co.zeit.hyper",
    ]

    private let injector: KeyInjector
    private let resolver: KeycodeResolver
    private let predictor = WordPredictor()
    private let shellCompleter = ShellCompleter()
    private let tracker = CompositionTracker()
    private let learnedStore = LearnedWordsStore()
    private let bigrams = BigramModel.standard()
    private let profileStore = AppProfileStore()
    private let commandUsage = CommandUsageStore()
    private let preferences = Preferences.shared
    private let variantPopup = VariantPopup()
    private let focusWatcher = FocusWatcher()
    private let scanController = ScanController()
    private let speech = AVSpeechSynthesizer()
    private(set) lazy var panels = PanelsController(keyboardController: self)

    private let panel: KeyboardPanel
    private var keyboardView: KeyboardView!
    private var layout: KeyboardLayout
    private var modifierStates: [Modifier: ModifierState] = [:]
    private var terminalMode = false
    private var didPositionPanel = false
    private var panelWasAutoShown = false
    private var inactivityTimer: Timer?
    private var activeProfile: AppProfile?

    init(injector: KeyInjector, resolver: KeycodeResolver) {
        self.injector = injector
        self.resolver = resolver
        self.layout = LayoutStore.layout(id: Preferences.shared.layoutID)
            ?? LayoutStore.bundledLayouts().first
            ?? KeyboardLayout(id: "empty", name: "Empty", rows: [])
        self.panel = KeyboardPanel(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100))
        super.init()

        predictor.loadBundledWordlists(languages: preferences.wordlistLanguages)
        learnedStore.applyTo(predictor)
        shellCompleter.loadBundled()
        shellCompleter.loadUserCompletions()
        shellCompleter.usageCounts = commandUsage.counts
        loadSystemDictionaryIfEnabled()

        activeProfile = profileStore.profile(
            for: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
        applyEffectiveLayout()
        rebuildKeyboardView()
        observeEnvironment()
        refreshTerminalMode()
        applyScanningState()

        focusWatcher.onTextFocusChange = { [weak self] hasTextFocus in
            self?.handleTextFocusChange(hasTextFocus)
        }
        focusWatcher.attach(to: NSWorkspace.shared.frontmostApplication)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelDidMove),
            name: NSWindow.didMoveNotification,
            object: panel
        )

        // Discover bare commands on $PATH for terminal completion.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let names = ShellCompleter.executableNames(
                inDirectories: ShellCompleter.defaultSearchDirectories)
            DispatchQueue.main.async {
                self?.shellCompleter.addDiscoveredCommands(names: names)
            }
        }
    }

    /// The layout that should be active considering the frontmost app's
    /// profile; returns true if the layout changed.
    @discardableResult
    private func applyEffectiveLayout() -> Bool {
        let desiredID = activeProfile?.layout ?? preferences.layoutID
        guard desiredID != layout.id, let desired = LayoutStore.layout(id: desiredID) else {
            return false
        }
        layout = desired
        return true
    }

    private func applyScanningState() {
        if preferences.scanningEnabled {
            scanController.interval = preferences.scanInterval
            scanController.attach(to: keyboardView)
            let advanceKey = preferences.scanAdvanceKey
            scanController.start(
                switchKey: preferences.scanSwitchKey,
                advanceKey: advanceKey == "none" ? nil : advanceKey
            )
        } else {
            scanController.stop()
        }
    }

    private var systemDictionaryLoaded = false

    private func loadSystemDictionaryIfEnabled() {
        if preferences.systemDictionaryEnabled {
            guard !systemDictionaryLoaded else { return }
            systemDictionaryLoaded = true
            let predictor = self.predictor
            DispatchQueue.global(qos: .utility).async {
                predictor.loadFallbackDictionary(atPath: "/usr/share/dict/words")
            }
        } else if systemDictionaryLoaded {
            systemDictionaryLoaded = false
            predictor.clearFallbackDictionary()
        }
    }

    /// Remembers the panel position across launches (multi-display safe: the
    /// saved origin is only used if it is still on a visible screen).
    @objc private func panelDidMove(_ notification: Notification) {
        guard didPositionPanel else { return }
        UserDefaults.standard.set(
            [panel.frame.origin.x, panel.frame.origin.y], forKey: "panelOrigin")
    }

    // MARK: - Panel

    var isPanelVisible: Bool { panel.isVisible }

    func showPanel(automatically: Bool = false) {
        if !didPositionPanel {
            positionAtBottomCenter()
            didPositionPanel = true
        }
        panelWasAutoShown = automatically
        panel.orderFrontRegardless()
        noteActivity()
    }

    func hidePanel() {
        variantPopup.dismiss()
        panelWasAutoShown = false
        panel.orderOut(nil)
    }

    func togglePanel() {
        isPanelVisible ? hidePanel() : showPanel()
    }

    func clearLearnedWords() {
        learnedStore.clear()
        bigrams.clear()
    }

    private func positionAtBottomCenter() {
        if let saved = UserDefaults.standard.array(forKey: "panelOrigin") as? [Double],
           saved.count == 2 {
            let origin = NSPoint(x: saved[0], y: saved[1])
            let restoredFrame = NSRect(origin: origin, size: panel.frame.size)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(restoredFrame) }) {
                panel.setFrameOrigin(origin)
                return
            }
        }
        guard let screen = NSScreen.main else { return }
        let frame = panel.frame
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: visible.midX - frame.width / 2,
            y: visible.minY + 12
        ))
    }

    private func rebuildKeyboardView() {
        var metrics = KeyboardMetrics(scale: CGFloat(preferences.scale))
        metrics.showsCurrentText = preferences.showCurrentText
        let dwell = DwellConfiguration(
            enabled: preferences.dwellEnabled,
            time: preferences.dwellTime
        )

        let view = KeyboardView(
            layout: layout,
            metrics: metrics,
            dwell: dwell,
            theme: Theme.theme(id: preferences.themeID)
        )
        view.onKeyPress = { [weak self] key in self?.handleKey(key) }
        view.onKeyLongPress = { [weak self] key, keyView in
            self?.handleLongPress(key, keyView: keyView) ?? false
        }
        view.onHoverChange = { [weak self] hovering in
            if hovering { self?.noteActivity() }
        }
        view.suggestionBar.onSelect = { [weak self] suggestion in
            self?.acceptSuggestion(suggestion)
        }
        keyboardView = view

        let size = metrics.size(for: layout)
        let origin = panel.frame.origin
        panel.setContentSize(size)
        panel.contentView = view
        panel.setFrameOrigin(origin)
        panel.alphaValue = CGFloat(preferences.opacity)
        refreshKeyCaps()
        updateSuggestions()
        noteActivity()
        scanController.attach(to: view)
    }

    // MARK: - Inactivity fade

    /// Restores full opacity and restarts the inactivity countdown.
    private func noteActivity() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = CGFloat(preferences.opacity)
        }
        inactivityTimer?.invalidate()
        guard preferences.inactivityFadeEnabled, preferences.inactivityFadeDelay > 0 else {
            return
        }
        let timer = Timer(
            timeInterval: preferences.inactivityFadeDelay, repeats: false
        ) { [weak self] _ in
            self?.fadeOut()
        }
        RunLoop.main.add(timer, forMode: .common)
        inactivityTimer = timer
    }

    private func fadeOut() {
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.6
            panel.animator().alphaValue = max(0.12, CGFloat(preferences.opacity) * 0.2)
        }
    }

    // MARK: - Environment observation

    private func observeEnvironment() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontmostAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesChanged),
            name: Preferences.didChangeNotification,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: NSNotification.Name("com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"),
            object: nil
        )
    }

    @objc private func frontmostAppChanged(_ notification: Notification) {
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication
        let isSelf = app?.processIdentifier == ProcessInfo.processInfo.processIdentifier

        if !isSelf {
            activeProfile = profileStore.profile(for: app?.bundleIdentifier)
            if applyEffectiveLayout() {
                rebuildKeyboardView()
            }
        }
        refreshTerminalMode()
        tracker.reset()
        updateSuggestions()

        if !isSelf {
            focusWatcher.attach(to: app)
        }
    }

    @objc private func preferencesChanged(_ notification: Notification) {
        applyEffectiveLayout()
        rebuildKeyboardView()
        applyScanningState()
        loadSystemDictionaryIfEnabled()
        panels.rebuildOpenPanels()
    }

    @objc private func inputSourceChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.resolver.rebuild()
        }
    }

    private func refreshTerminalMode() {
        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if let forced = activeProfile?.terminalMode {
            terminalMode = forced
        } else {
            terminalMode = bundleID.map { Self.terminalBundleIDs.contains($0) } ?? false
        }
    }

    private func handleTextFocusChange(_ hasTextFocus: Bool) {
        guard preferences.autoShowOnTextFocus else { return }
        if hasTextFocus {
            if !isPanelVisible {
                showPanel(automatically: true)
            }
        } else if panelWasAutoShown {
            hidePanel()
        }
    }

    // MARK: - Modifier handling

    private func isActive(_ modifier: Modifier) -> Bool {
        (modifierStates[modifier] ?? .off).isActive
    }

    private func currentFlags() -> CGEventFlags {
        var flags: CGEventFlags = []
        for (modifier, state) in modifierStates where state.isActive {
            flags.insert(modifier.flags)
        }
        return flags
    }

    private func releaseLatchedModifiers() {
        for (modifier, state) in modifierStates where state == .latched {
            modifierStates[modifier] = .off
        }
    }

    private func refreshKeyCaps() {
        keyboardView.updateKeyCaps(
            shifted: isActive(.shift),
            alted: isActive(.option),
            modifierStates: modifierStates.mapValues(\.visual)
        )
    }

    // MARK: - Key handling

    func handleKey(_ key: Key) {
        guard let kind = key.kind else { return }
        variantPopup.dismiss()
        noteActivity()
        if preferences.keyClickSound {
            NSSound(named: "Tink")?.play()
        }

        switch kind {
        case .modifier(let modifier):
            modifierStates[modifier] = (modifierStates[modifier] ?? .off).next
            refreshKeyCaps()
            return

        case .character:
            handleCharacterKey(key)

        case .special(let special):
            handleSpecialKey(special)

        case .macro(let macro):
            runMacro(macro)

        case .media(let media):
            MediaKeyInjector.press(media)
        }
        releaseLatchedModifiers()
        refreshKeyCaps()
        updateSuggestions()
    }

    /// Long-press on a character key: show the variant popup. Returns whether
    /// the popup was shown (which suppresses the normal key press).
    private func handleLongPress(_ key: Key, keyView: KeyView) -> Bool {
        guard let base = key.base else { return false }
        let variants = CharacterVariants.variants(for: base, shifted: isActive(.shift))
        guard !variants.isEmpty else { return false }

        variantPopup.show(
            variants: variants,
            relativeTo: keyView,
            metrics: keyboardView.metrics
        ) { [weak self] variant in
            guard let self else { return }
            self.injector.typeText(variant)
            self.tracker.typed(variant)
            self.releaseLatchedModifiers()
            self.refreshKeyCaps()
            self.updateSuggestions()
        }
        return true
    }

    private func handleCharacterKey(_ key: Key) {
        let shifted = isActive(.shift)
        let alted = isActive(.option)

        if isActive(.command) || isActive(.control) {
            // Keyboard shortcut: post the real key code for the base character.
            guard let character = key.base?.first,
                  let resolution = resolver.resolve(character)
            else { return }
            var flags = currentFlags()
            if resolution.needsShift { flags.insert(.maskShift) }
            injector.pressKey(resolution.keyCode, flags: flags)
            tracker.reset()
            return
        }

        guard var output = key.output(shifted: shifted, alted: alted) else { return }

        if preferences.autoCapitalization, !terminalMode, !shifted, !alted,
           output.count == 1, output.first!.isLowercase,
           TypingAids.shouldAutoCapitalize(afterLine: tracker.line) {
            output = output.uppercased()
        }

        injector.typeText(output)
        tracker.typed(output)
    }

    private func handleSpecialKey(_ special: SpecialKey) {
        let flags = currentFlags()
        switch special {
        case .space:
            if preferences.autoSpacing, !terminalMode, flags.isEmpty,
               TypingAids.shouldInsertPeriodOnDoubleSpace(line: tracker.line) {
                // Second space of a double-space becomes ". ".
                injector.pressKey(SpecialKey.delete.keyCode)
                injector.typeText(". ")
                tracker.backspaced()
                tracker.typed(". ")
                return
            }
            commitCurrentWord()
            injector.pressKey(special.keyCode, flags: flags)
            tracker.typed(" ")
        case .return:
            commitCurrentWord()
            injector.pressKey(special.keyCode, flags: flags)
            let line = tracker.submittedLine()
            if terminalMode {
                recordCommandUsage(fromLine: line)
            }
        case .delete:
            injector.pressKey(special.keyCode, flags: flags)
            tracker.backspaced()
        case .forwardDelete, .tab, .escape,
             .left, .right, .up, .down, .home, .end, .pageUp, .pageDown:
            // These move the caret or hand control to the target application,
            // so our model of the current line is no longer reliable.
            injector.pressKey(special.keyCode, flags: flags)
            tracker.reset()
        }
    }

    private func commitCurrentWord() {
        guard !terminalMode, preferences.learningEnabled else { return }
        let word = tracker.currentWord
        guard word.count >= 3 else { return }
        predictor.learn(word)
        learnedStore.record(word)
        let previous = tracker.previousWord
        if !previous.isEmpty {
            bigrams.learn(previous: previous, next: word)
        }
    }

    private func recordCommandUsage(fromLine line: String) {
        var tokens = line.split(separator: " ").map(String.init)
        while let first = tokens.first,
              ["sudo", "env", "time", "nohup"].contains(first) {
            tokens.removeFirst()
        }
        guard let command = tokens.first, !command.isEmpty else { return }
        commandUsage.record(command: command)
        shellCompleter.usageCounts = commandUsage.counts
    }

    // MARK: - Macros

    private func runMacro(_ macro: Macro) {
        if macro.isPlainText {
            for step in macro.steps {
                if let text = step.text { tracker.typed(text) }
            }
        } else {
            tracker.reset()
        }

        let injector = self.injector
        let resolver = self.resolver
        DispatchQueue.global(qos: .userInitiated).async {
            for step in macro.steps {
                if let delay = step.delayMs, delay > 0 {
                    usleep(useconds_t(delay) * 1000)
                }
                if let text = step.text {
                    injector.typeText(text)
                }
                if let shortcut = step.shortcut,
                   let parsed = ShortcutParser.parse(shortcut) {
                    if let special = parsed.special {
                        injector.pressKey(special.keyCode, flags: parsed.flags)
                    } else if let character = parsed.character,
                              let resolution = resolver.resolve(character) {
                        var flags = parsed.flags
                        if resolution.needsShift { flags.insert(.maskShift) }
                        injector.pressKey(resolution.keyCode, flags: flags)
                    }
                }
                if let target = step.open {
                    DispatchQueue.main.async { Self.open(target) }
                }
                if let panelID = step.panel {
                    DispatchQueue.main.async { [weak self] in
                        self?.panels.toggle(panelID: panelID)
                    }
                }
                if let phrase = step.say {
                    DispatchQueue.main.async { [weak self] in
                        self?.speech.speak(AVSpeechUtterance(string: phrase))
                    }
                }
            }
        }
    }

    private static func open(_ target: String) {
        if target.hasPrefix("/") || target.hasPrefix("~") {
            let path = (target as NSString).expandingTildeInPath
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        } else if let url = URL(string: target), url.scheme != nil {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Suggestions & current text

    private func updateSuggestions() {
        keyboardView.suggestionBar.setSuggestions(computeSuggestions())
        keyboardView.setCurrentText(tracker.line)
    }

    private func computeSuggestions() -> [String] {
        guard preferences.predictionsEnabled else { return [] }
        if terminalMode {
            guard preferences.terminalCompletionsEnabled, !tracker.line.isEmpty else { return [] }
            return shellCompleter.suggestions(forLine: tracker.line)
        }
        let word = tracker.currentWord
        if word.isEmpty {
            // Next-word prediction from learned bigrams after a completed word.
            let last = tracker.lastCompletedWord
            guard !last.isEmpty, tracker.line.hasSuffix(" ") else { return [] }
            return bigrams.suggestions(after: last)
        }
        return predictor.suggestions(forPrefix: word)
    }

    private func acceptSuggestion(_ suggestion: String) {
        noteActivity()
        let bigramContext = terminalMode ? "" : tracker.previousWord
        let prefix = terminalMode ? tracker.currentToken : tracker.currentWord
        let completion: String
        if suggestion.lowercased().hasPrefix(prefix.lowercased()) {
            completion = String(suggestion.dropFirst(prefix.count)) + " "
        } else {
            completion = suggestion + " "
        }
        injector.typeText(completion)
        tracker.typed(completion)

        if !terminalMode, preferences.learningEnabled, suggestion.count >= 3 {
            predictor.learn(suggestion)
            learnedStore.record(suggestion)
            if !bigramContext.isEmpty {
                bigrams.learn(previous: bigramContext, next: suggestion)
            }
        }
        updateSuggestions()
    }
}
