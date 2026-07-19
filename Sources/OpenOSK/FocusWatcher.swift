#if canImport(AppKit)
import AppKit
import ApplicationServices

/// What is currently focused in the frontmost app, as far as AX tells us.
struct FocusInfo {
    var isTextInput: Bool
    var role: String?
    var descriptionText: String?
}

/// Watches the frontmost application's focused UI element via the
/// Accessibility API and reports focus changes. Drives "show keyboard when
/// editing text" and the editor-integrated-terminal detection.
final class FocusWatcher {
    var onFocusChange: ((FocusInfo) -> Void)?

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
            onFocusChange?(FocusInfo(isTextInput: false, role: nil, descriptionText: nil))
            return
        }
        reportFocus(of: value as! AXUIElement)
    }

    private func reportFocus(of element: AXUIElement) {
        var roleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        let role = roleValue as? String

        var descriptionValue: CFTypeRef?
        AXUIElementCopyAttributeValue(
            element, kAXDescriptionAttribute as CFString, &descriptionValue)
        var description = descriptionValue as? String
        if description?.isEmpty != false {
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue)
            description = titleValue as? String
        }

        let info = FocusInfo(
            isTextInput: role.map { Self.textRoles.contains($0) } ?? false,
            role: role,
            descriptionText: description
        )
        DispatchQueue.main.async { [weak self] in
            self?.onFocusChange?(info)
        }
    }
}
#endif
