#if canImport(AppKit)
import AppKit

/// Visual theme for the keyboard and panels. "System" follows the macOS
/// appearance via semantic colors; the others are fixed palettes, including a
/// high-contrast theme for low vision.
struct Theme {
    let id: String
    let nameKey: String
    let background: NSColor
    let keyFill: NSColor
    let specialFill: NSColor
    let text: NSColor
    let secondaryText: NSColor
    let pressed: NSColor
    let pressedText: NSColor

    var name: String { L(nameKey) }

    static let system = Theme(
        id: "system",
        nameKey: "System",
        background: .windowBackgroundColor,
        keyFill: .controlColor,
        specialFill: NSColor.controlColor.withAlphaComponent(0.55),
        text: .labelColor,
        secondaryText: .secondaryLabelColor,
        pressed: .controlAccentColor,
        pressedText: .white
    )

    static let highContrast = Theme(
        id: "high-contrast",
        nameKey: "High Contrast",
        background: .black,
        keyFill: .white,
        specialFill: NSColor(white: 0.82, alpha: 1),
        text: .black,
        secondaryText: NSColor(white: 0.25, alpha: 1),
        pressed: .systemYellow,
        pressedText: .black
    )

    static let dark = Theme(
        id: "dark",
        nameKey: "Dark",
        background: NSColor(white: 0.12, alpha: 1),
        keyFill: NSColor(white: 0.22, alpha: 1),
        specialFill: NSColor(white: 0.17, alpha: 1),
        text: .white,
        secondaryText: NSColor(white: 0.65, alpha: 1),
        pressed: .systemBlue,
        pressedText: .white
    )

    static let light = Theme(
        id: "light",
        nameKey: "Light",
        background: NSColor(white: 0.96, alpha: 1),
        keyFill: .white,
        specialFill: NSColor(white: 0.88, alpha: 1),
        text: .black,
        secondaryText: NSColor(white: 0.4, alpha: 1),
        pressed: .systemBlue,
        pressedText: .white
    )

    static let all: [Theme] = [.system, .highContrast, .dark, .light]

    static func theme(id: String) -> Theme {
        all.first { $0.id == id } ?? .system
    }
}
#endif
