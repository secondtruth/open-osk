import AppKit
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
    private let preferences = Preferences.shared
    private let variantPopup = VariantPopup()
    private let focusWatcher = FocusWatcher()

    private let panel: KeyboardPanel
    private var keyboardView: KeyboardView!
    private var layout: KeyboardLayout
    private var modifierStates: [Modifier: ModifierState] = [:]
    private var terminalMode = false
    private var didPositionPanel = false
    private var panelWasAutoShown = false
    private var inactivityTimer: Timer?

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

        rebuildKeyboardView()
        observeEnvironment()
        refreshTerminalMode()

        focusWatcher.onTextFocusChange = { [weak self] hasTextFocus in
            self?.handleTextFocusChange(hasTextFocus)
        }
        focusWatcher.attach(to: NSWorkspace.shared.frontmostApplication)
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
    }

    private func positionAtBottomCenter() {
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

        let view = KeyboardView(layout: layout, metrics: metrics, dwell: dwell)
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
        refreshTerminalMode()
        tracker.reset()
        updateSuggestions()

        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
            as? NSRunningApplication
        if app?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            focusWatcher.attach(to: app)
        }
    }

    @objc private func preferencesChanged(_ notification: Notification) {
        let newLayout = LayoutStore.layout(id: preferences.layoutID)
        if let newLayout, newLayout.id != layout.id {
            layout = newLayout
        }
        rebuildKeyboardView()
    }

    @objc private func inputSourceChanged(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.resolver.rebuild()
        }
    }

    private func refreshTerminalMode() {
        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        terminalMode = bundleID.map { Self.terminalBundleIDs.contains($0) } ?? false
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
            tracker.submittedLine()
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
        guard !word.isEmpty else { return [] }
        return predictor.suggestions(forPrefix: word)
    }

    private func acceptSuggestion(_ suggestion: String) {
        noteActivity()
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
        }
        updateSuggestions()
    }
}
