#if canImport(AppKit)
import AppKit
import OpenOSKCore

/// Posts system-defined (NX) events for media/system keys — volume,
/// brightness, playback. These are not regular virtual key codes and need the
/// IOKit event subtype 8 encoding.
enum MediaKeyInjector {
    static func press(_ key: MediaKey) {
        post(key: key, down: true)
        post(key: key, down: false)
    }

    private static func post(key: MediaKey, down: Bool) {
        let flags: NSEvent.ModifierFlags = down ? [] : []
        let data1 = (Int(key.nxKeyType) << 16) | ((down ? 0xA : 0xB) << 8)
        guard let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        ) else { return }
        event.cgEvent?.post(tap: .cghidEventTap)
    }
}
#endif
