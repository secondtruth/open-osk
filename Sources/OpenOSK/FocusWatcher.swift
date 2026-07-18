import AppKit
import ApplicationServices

/// Watches the frontmost application's focused UI element via the
/// Accessibility API and reports whether a text-input element has focus.
/// Used for the "show keyboard automatically when editing text" feature.
final class FocusWatcher {
    var onTextFocusChange: ((Bool) -> Void)?

    private var observer: AXObserver?
    private var appElement: AXUIElement?

    private static let textRoles: Set<String> = [
        kAXTextFieldRole,
        kAXTextAreaRole,
        kAXComboBoxRole,
        "AXSearchField",
    ]

    /// Re-attaches the AX observer to the given application. Call whenever
    /// the frontmost app changes.
    func attach(to app: NSRunningApplication?) {
        detach()
        guard
            let app,
            app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
            AXIsProcessTrusted()
        else { return }

        var newObserver: AXObserver?
        let callback: AXObserverCallback = { _, element, _, refcon in
            guard let refcon else { return }
            let watcher = Unmanaged<FocusWatcher>.fromOpaque(refcon).takeUnretainedValue()
            watcher.reportFocus(of: element)
        }
        guard
            AXObserverCreate(app.processIdentifier, callback, &newObserver) == .success,
            let newObserver
        else { return }

        let element = AXUIElementCreateApplication(app.processIdentifier)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(
            newObserver, element, kAXFocusedUIElementChangedNotification as CFString, refcon)
        CFRunLoopAddSource(
            CFRunLoopGetMain(), AXObserverGetRunLoopSource(newObserver), .defaultMode)

        observer = newObserver
        appElement = element
        evaluateCurrentFocus()
    }

    func detach() {
        if let observer {
            CFRunLoopRemoveSource(
                CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        appElement = nil
    }

    private func evaluateCurrentFocus() {
        guard let appElement else { return }
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement, kAXFocusedUIElementAttribute as CFString, &value)
        guard result == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            onTextFocusChange?(false)
            return
        }
        reportFocus(of: value as! AXUIElement)
    }

    private func reportFocus(of element: AXUIElement) {
        var roleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        let role = roleValue as? String
        let isText = role.map { Self.textRoles.contains($0) } ?? false
        DispatchQueue.main.async { [weak self] in
            self?.onTextFocusChange?(isText)
        }
    }
}
