#if canImport(AppKit)
import AppKit
import OpenOSKCore

/// Popup shown above a key on long-press, offering alternate characters
/// (à á â …). Non-activating like the keyboard itself; dismissed by selecting
/// a variant, pressing any other key, or clicking anywhere else.
final class VariantPopup {
    private var panel: KeyboardPanel?
    private var eventMonitors: [Any] = []

    var isVisible: Bool { panel?.isVisible ?? false }

    func show(
        variants: [String],
        relativeTo keyView: KeyView,
        metrics: KeyboardMetrics,
        theme: Theme,
        onSelect: @escaping (String) -> Void
    ) {
        dismiss()
        guard !variants.isEmpty, let keyWindow = keyView.window else { return }

        let pad: CGFloat = 6
        let count = CGFloat(variants.count)
        let size = NSSize(
            width: count * metrics.unit + (count - 1) * metrics.gap + pad * 2,
            height: metrics.keyHeight + pad * 2
        )

        let panel = KeyboardPanel(contentRect: NSRect(origin: .zero, size: size))
        let content = PopupBackgroundView(frame: NSRect(origin: .zero, size: size))
        content.theme = theme
        content.cornerRadius = metrics.keyCornerRadius + pad

        var x = pad
        for variant in variants {
            let view = KeyView(key: Key(base: variant))
            view.displayText = variant
            view.spokenLabel = variant
            view.fontSize = metrics.keyFontSize
            view.cornerRadius = metrics.keyCornerRadius
            view.theme = theme
            view.onPress = { [weak self] _ in
                onSelect(variant)
                self?.dismiss()
            }
            view.frame = NSRect(x: x, y: pad, width: metrics.unit, height: metrics.keyHeight)
            content.addSubview(view)
            x += metrics.unit + metrics.gap
        }
        panel.contentView = content

        let keyRectInWindow = keyView.convert(keyView.bounds, to: nil)
        let keyRectOnScreen = keyWindow.convertToScreen(keyRectInWindow)
        var origin = NSPoint(
            x: keyRectOnScreen.midX - size.width / 2,
            y: keyRectOnScreen.maxY + 8
        )
        if let screen = keyWindow.screen {
            origin.x = max(screen.visibleFrame.minX + 4,
                           min(origin.x, screen.visibleFrame.maxX - size.width - 4))
        }
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        self.panel = panel

        installDismissMonitors()
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        eventMonitors.forEach(NSEvent.removeMonitor)
        eventMonitors = []
    }

    /// Any click outside the popup dismisses it — inside our app (local
    /// monitor) as well as in other apps (global monitor).
    private func installDismissMonitors() {
        let local = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown],
            handler: { [weak self] event in
                if event.window !== self?.panel {
                    self?.dismiss()
                }
                return event
            }
        )
        if let local {
            eventMonitors.append(local)
        }
        let global = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown],
            handler: { [weak self] _ in
                self?.dismiss()
            }
        )
        if let global {
            eventMonitors.append(global)
        }
    }
}

private final class PopupBackgroundView: NSView {
    var theme = Theme.system
    var cornerRadius: CGFloat = 10

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: cornerRadius, yRadius: cornerRadius)
        theme.background.setFill()
        path.fill()
        theme.border.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}
#endif
