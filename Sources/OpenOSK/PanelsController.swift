#if canImport(AppKit)
import AppKit
import OpenOSKCore

/// Manages custom panels: small non-activating windows with user-defined
/// buttons (macros, snippets, shortcuts), inspired by the macOS Panel Editor.
final class PanelsController {
    private unowned let keyboardController: KeyboardController
    private let preferences = Preferences.shared
    private var openPanels: [String: KeyboardPanel] = [:]
    /// Called when a panel opened, closed or was rebuilt (scanning follows).
    var onChange: (() -> Void)?

    init(keyboardController: KeyboardController) {
        self.keyboardController = keyboardController
    }

    var openPanelIDs: Set<String> { Set(openPanels.keys) }

    /// Scan groups of all open panels, in a stable order.
    var scanGroups: [[NSView]] {
        openPanels.keys.sorted().flatMap { id in
            (openPanels[id]?.contentView as? KeyboardView)?.scanGroups ?? []
        }
    }

    func availablePanels() -> [KeyboardLayout] {
        LayoutStore.allPanels()
    }

    /// Reopens panels that were open in the previous session.
    func restoreOpenPanels() {
        for id in preferences.openPanelIDs {
            if let panel = LayoutStore.panel(id: id) {
                open(panel)
            }
        }
        onChange?()
    }

    func toggle(panelID: String) {
        if openPanels[panelID] != nil {
            close(panelID: panelID)
        } else if let panel = LayoutStore.panel(id: panelID) {
            open(panel)
        }
        persistOpenState()
        onChange?()
    }

    func closeAll() {
        for id in Array(openPanels.keys) {
            close(panelID: id)
        }
        persistOpenState()
        onChange?()
    }

    private func open(_ layout: KeyboardLayout) {
        var metrics = KeyboardMetrics(scale: CGFloat(preferences.scale))
        metrics.showsCurrentText = false
        metrics.showsSuggestionBar = false

        let view = KeyboardView(
            layout: layout,
            metrics: metrics,
            dwell: DwellConfiguration(
                enabled: preferences.dwellEnabled,
                time: preferences.dwellTime
            ),
            theme: Theme.theme(id: preferences.themeID)
        )
        view.onKeyPress = { [weak self] key in
            self?.keyboardController.handleKey(key)
        }

        let size = metrics.size(for: layout)
        let window = KeyboardPanel(contentRect: NSRect(origin: .zero, size: size))
        window.contentView = view
        window.setContentSize(size)
        if !window.restoreOrigin(forID: layout.id) {
            position(window, stackIndex: openPanels.count)
        }
        window.trackOrigin(as: layout.id)
        window.alphaValue = CGFloat(preferences.opacity)
        window.orderFrontRegardless()

        openPanels[layout.id] = window
    }

    private func close(panelID: String) {
        openPanels[panelID]?.orderOut(nil)
        openPanels.removeValue(forKey: panelID)
    }

    /// Stack new panels above the right edge of the keyboard (or the screen
    /// bottom-right if the keyboard is hidden).
    private func position(_ window: KeyboardPanel, stackIndex: Int) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = window.frame.size
        let x = visible.maxX - size.width - 16
        let y = visible.minY + 16 + CGFloat(stackIndex) * (size.height + 12)
        window.setFrameOrigin(NSPoint(
            x: max(visible.minX, x),
            y: min(y, visible.maxY - size.height)
        ))
    }

    func setOpacity(_ opacity: CGFloat) {
        openPanels.values.forEach { $0.alphaValue = opacity }
    }

    /// Rebuilds open panels (after scale, theme, dwell or panel edits).
    func rebuildOpenPanels() {
        let ids = Array(openPanels.keys)
        for id in ids {
            close(panelID: id)
        }
        for id in ids {
            if let panel = LayoutStore.panel(id: id) {
                open(panel)
            }
        }
        onChange?()
    }

    private func persistOpenState() {
        preferences.openPanelIDs = Array(openPanels.keys).sorted()
    }
}
#endif
