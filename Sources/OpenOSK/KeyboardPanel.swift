#if canImport(AppKit)
import AppKit
import OpenOSKCore

/// Borderless floating panel that never takes key or main status, so the
/// focused application keeps receiving our synthetic keystrokes.
final class KeyboardPanel: NSPanel {
    private var originID: String?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.assistiveTechHighWindow)))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true
    }

    /// Moves the panel to where the user last left it. Fails if it was never
    /// moved, or if that spot is no longer on any screen (display unplugged).
    func restoreOrigin(forID id: String) -> Bool {
        guard let saved = Preferences.shared.panelOrigin(forID: id) else { return false }
        let origin = NSPoint(x: saved.x, y: saved.y)
        let restored = NSRect(origin: origin, size: frame.size)
        guard NSScreen.screens.contains(where: { $0.visibleFrame.intersects(restored) }) else {
            return false
        }
        setFrameOrigin(origin)
        return true
    }

    /// From now on, remembers the panel's position under `id`. Call after the
    /// initial placement so a default position is never stored as a choice.
    func trackOrigin(as id: String) {
        guard originID == nil else { return }
        originID = id
        NotificationCenter.default.addObserver(
            self, selector: #selector(originDidChange),
            name: NSWindow.didMoveNotification, object: self)
    }

    @objc private func originDidChange(_ notification: Notification) {
        guard let originID else { return }
        Preferences.shared.setPanelOrigin(
            x: Double(frame.origin.x), y: Double(frame.origin.y), forID: originID)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
#endif
