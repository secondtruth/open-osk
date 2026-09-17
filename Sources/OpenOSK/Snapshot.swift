#if canImport(AppKit)
import AppKit
import OpenOSKCore

/// `--snapshot <dir>`: renders the keyboard once per theme, and every settings
/// pane, into PNG files without showing a window. For checking visual changes and for README
/// screenshots. The System theme's desktop blur cannot be captured
/// off-screen, so its snapshot falls back to the theme's background color.
enum Snapshot {
    static func write(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let layout = LayoutStore.layout(id: Preferences.shared.layoutID)
            ?? LayoutStore.bundledLayouts().first
        else { return }

        for theme in Theme.all {
            var flat = theme
            flat.usesVibrancy = false
            let view = KeyboardView(
                layout: layout,
                metrics: KeyboardMetrics(scale: 1),
                dwell: DwellConfiguration(),
                theme: flat
            )
            view.setCurrentText("OpenOSK types this te")
            view.suggestionBar.setSuggestions(["text", "test", "terminal", "team"])
            view.updateKeyCaps(shifted: false, alted: false, modifierStates: [.shift: .latched])
            view.keyRows.first?.first?.isScanHighlighted = true

            try write(view, to: directory.appendingPathComponent("keyboard-\(theme.id).png"))
        }

        let settings = SettingsController(onClearLearnedWords: {})
        for (index, tab) in settings.makeTabs().enumerated() {
            guard let pane = tab.view else { continue }
            // Panes are transparent; a window normally supplies the backdrop.
            let backdrop = NSBox(frame: NSRect(origin: .zero, size: pane.fittingSize))
            backdrop.boxType = .custom
            backdrop.borderWidth = 0
            backdrop.fillColor = .windowBackgroundColor
            backdrop.contentViewMargins = .zero
            backdrop.appearance = NSAppearance(named: .aqua)
            pane.frame = backdrop.bounds
            backdrop.addSubview(pane)
            backdrop.layoutSubtreeIfNeeded()
            try write(backdrop, to: directory.appendingPathComponent("settings-\(index + 1).png"))
        }
    }

    private static func write(_ view: NSView, to url: URL) throws {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])?.write(to: url)
    }
}
#endif
