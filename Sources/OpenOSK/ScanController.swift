#if canImport(AppKit)
import AppKit
import OpenOSKCore

/// Scanning (switch access) input: highlights key groups sequentially; a
/// single switch press selects the highlighted group, then the highlighted
/// key within it. For users who cannot operate a pointer at all.
///
/// The switch is a configurable hardware key (Space, Return, F13–F15) that is
/// consumed globally via a CGEvent tap while scanning is active — assistive
/// switch hardware typically emulates exactly such a key.
final class ScanController {
    private enum Level {
        case groups
        case items(Int)
    }

    /// Key-name → macOS virtual key code for the switch options.
    static let switchKeyCodes: [String: CGKeyCode] = [
        "space": 49,
        "return": 36,
        "f13": 105,
        "f14": 107,
        "f15": 113,
    ]

    private weak var keyboardView: KeyboardView?
    private var level: Level = .groups
    private var index = 0
    private var timer: Timer?
    private var highlighted: [NSView] = []

    var interval: TimeInterval = 1.2
    private var manualAdvance = false
    private let switchTap = SwitchTap()

    init() {
        switchTap.onSwitch = { [weak self] in self?.select() }
        switchTap.onAdvance = { [weak self] in self?.advance() }
    }

    private(set) var isActive = false

    func attach(to view: KeyboardView?) {
        keyboardView = view
        if isActive {
            restartCycle()
        }
    }

    /// Starts scanning. With an advance key set, the scan only moves when
    /// that key is pressed (two-switch mode); otherwise a timer advances it.
    func start(switchKey: String, advanceKey: String? = nil) {
        stop()
        switchTap.switchKeyCode = Self.switchKeyCodes[switchKey] ?? 49
        switchTap.advanceKeyCode = advanceKey.flatMap { Self.switchKeyCodes[$0] }
        manualAdvance = switchTap.advanceKeyCode != nil
        switchTap.start()
        isActive = true
        level = .groups
        index = 0
        scheduleTimer()
        applyHighlight()
    }

    func stop() {
        isActive = false
        timer?.invalidate()
        timer = nil
        switchTap.stop()
        clearHighlight()
        level = .groups
        index = 0
    }

    // MARK: - Cycle

    private var groups: [[NSView]] {
        keyboardView?.scanGroups ?? []
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = nil
        guard !manualAdvance else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.advance()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func restartCycle() {
        level = .groups
        index = 0
        scheduleTimer()
        applyHighlight()
    }

    func advance() {
        let groups = groups
        guard !groups.isEmpty else { return }
        switch level {
        case .groups:
            index = (index + 1) % groups.count
        case .items(let group):
            guard groups.indices.contains(group) else {
                level = .groups
                index = 0
                return
            }
            index = (index + 1) % groups[group].count
        }
        applyHighlight()
    }

    /// Switch press: descend into the highlighted group, or activate the
    /// highlighted item and return to group scanning.
    func select() {
        let groups = groups
        guard !groups.isEmpty else { return }
        switch level {
        case .groups:
            let group = min(index, groups.count - 1)
            level = .items(group)
            index = 0
        case .items(let group):
            if groups.indices.contains(group), groups[group].indices.contains(index) {
                activate(groups[group][index])
            }
            level = .groups
            index = 0
        }
        scheduleTimer()
        applyHighlight()
    }

    private func activate(_ view: NSView) {
        if let keyView = view as? KeyView {
            keyView.triggerPress()
        } else if let button = view as? NSButton {
            button.performClick(nil)
        }
    }

    // MARK: - Highlighting

    private func applyHighlight() {
        clearHighlight()
        let groups = groups
        guard !groups.isEmpty else { return }
        let views: [NSView]
        switch level {
        case .groups:
            views = groups[min(index, groups.count - 1)]
        case .items(let group):
            guard groups.indices.contains(group), groups[group].indices.contains(index) else {
                return
            }
            views = [groups[group][index]]
        }
        for view in views {
            setHighlight(view, true)
        }
        highlighted = views
    }

    private func clearHighlight() {
        for view in highlighted {
            setHighlight(view, false)
        }
        highlighted = []
    }

    private func setHighlight(_ view: NSView, _ value: Bool) {
        if let keyView = view as? KeyView {
            keyView.isScanHighlighted = value
        } else if let button = view as? SuggestionButton {
            button.isScanHighlighted = value
        }
    }
}

/// Global CGEvent tap that consumes the configured switch key while active.
/// Ignores events injected by OpenOSK itself (marked with the injection
/// signature) so synthetic Space/Return presses don't trigger the switch.
private final class SwitchTap {
    var onSwitch: (() -> Void)?
    var onAdvance: (() -> Void)?
    var switchKeyCode: CGKeyCode = 49
    var advanceKeyCode: CGKeyCode?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        guard tap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let tap = Unmanaged<SwitchTap>.fromOpaque(refcon).takeUnretainedValue()
            return tap.handle(type: type, event: event)
        }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) else {
            NSLog("OpenOSK: could not create the scanning switch event tap")
            return
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown else { return Unmanaged.passUnretained(event) }
        guard event.getIntegerValueField(.eventSourceUserData)
                != KeyInjector.injectionSignature
        else { return Unmanaged.passUnretained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if keyCode == Int64(switchKeyCode) {
            DispatchQueue.main.async { [weak self] in
                self?.onSwitch?()
            }
            return nil
        }
        if let advanceKeyCode, keyCode == Int64(advanceKeyCode) {
            DispatchQueue.main.async { [weak self] in
                self?.onAdvance?()
            }
            return nil
        }
        return Unmanaged.passUnretained(event)
    }
}
#endif
