import ApplicationServices
import CoreGraphics
import Foundation

/// Posts synthetic keyboard events to the system.
///
/// Character output is injected as Unicode strings, which makes it independent
/// of the active system keyboard layout (and immune to dead keys). Shortcuts
/// and special keys are posted as virtual key codes so applications receive
/// proper key equivalents.
public final class KeyInjector {
    /// Marker written into `.eventSourceUserData` of every injected event so
    /// OpenOSK's own event taps (e.g. the scanning switch) can ignore them.
    public static let injectionSignature: Int64 = 0x4F534B  // "OSK"

    /// Delay between successive events in microseconds. Some applications
    /// drop or reorder events that arrive too fast.
    public var interEventDelay: useconds_t = 2000

    private let source = CGEventSource(stateID: .combinedSessionState)

    public init() {}

    /// Whether this process is allowed to post events (Accessibility access).
    public static func isTrusted(promptIfNeeded: Bool = false) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: promptIfNeeded
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Types arbitrary text into the focused application.
    public func typeText(_ text: String) {
        for character in text {
            var units = Array(String(character).utf16)
            guard
                let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else { continue }
            down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
            up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
            down.setIntegerValueField(.eventSourceUserData, value: Self.injectionSignature)
            up.setIntegerValueField(.eventSourceUserData, value: Self.injectionSignature)
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
            usleep(interEventDelay)
        }
    }

    /// Posts a key down/up pair for a virtual key code with modifier flags.
    public func pressKey(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { return }
        down.flags = flags
        up.flags = flags
        down.setIntegerValueField(.eventSourceUserData, value: Self.injectionSignature)
        up.setIntegerValueField(.eventSourceUserData, value: Self.injectionSignature)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        usleep(interEventDelay)
    }
}
