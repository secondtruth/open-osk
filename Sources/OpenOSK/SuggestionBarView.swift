#if canImport(AppKit)
import AppKit

/// One suggestion, drawn in the keyboard's theme. Pressable by click, dwell,
/// scanning and assistive technology.
final class SuggestionChipView: NSView {
    let title: String
    var onSelect: ((String) -> Void)?
    var isScanHighlighted = false {
        didSet { needsDisplay = true }
    }

    private let theme: Theme
    private let font: NSFont
    private let dwell: DwellConfiguration
    private let dwellTimer = DwellTimer()
    private var dwellProgress: CGFloat = 0 {
        didSet { needsDisplay = true }
    }
    private var isHovered = false {
        didSet { needsDisplay = true }
    }
    private var isPressed = false {
        didSet { needsDisplay = true }
    }

    init(title: String, theme: Theme, font: NSFont, dwell: DwellConfiguration) {
        self.title = title
        self.theme = theme
        self.font = font
        self.dwell = dwell
        super.init(frame: .zero)
        dwellTimer.onProgress = { [weak self] in self?.dwellProgress = $0 }
        dwellTimer.onComplete = { [weak self] in self?.select() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var mouseDownCanMoveWindow: Bool { false }

    /// Width the chip needs for its title at the given height.
    func fittingWidth(height: CGFloat) -> CGFloat {
        ceil(title.size(withAttributes: [.font: font]).width) + height * 0.9
    }

    func select() {
        onSelect?(title)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        if dwell.enabled {
            dwellTimer.start(duration: dwell.time)
        }
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        dwellTimer.cancel()
    }

    override func mouseDown(with event: NSEvent) {
        dwellTimer.cancel()
        isPressed = true
    }

    override func mouseUp(with event: NSEvent) {
        isPressed = false
        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            select()
        }
    }

    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? { title }

    override func accessibilityPerformPress() -> Bool {
        select()
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let radius = rect.height / 2
        let pill = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

        var fill = isPressed ? theme.pressed : theme.specialFill
        if isHovered, !isPressed {
            fill = fill.blended(withFraction: 0.15, of: theme.pressed) ?? fill
        }
        if isScanHighlighted {
            fill = fill.blended(withFraction: 0.3, of: theme.scanHighlight) ?? fill
        }
        fill.setFill()
        pill.fill()

        if dwellProgress > 0 {
            // Fills from the leading edge; a centered pie would hide the word.
            NSGraphicsContext.saveGraphicsState()
            pill.addClip()
            theme.pressed.withAlphaComponent(0.4).setFill()
            NSRect(x: rect.minX, y: rect.minY, width: rect.width * dwellProgress, height: rect.height)
                .fill(using: .sourceOver)
            NSGraphicsContext.restoreGraphicsState()
        }

        (isScanHighlighted ? theme.scanHighlight : theme.border).setStroke()
        pill.lineWidth = isScanHighlighted ? 3 : 1
        pill.stroke()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: isPressed ? theme.pressedText : theme.text,
        ]
        let size = title.size(withAttributes: attributes)
        title.draw(
            at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
            withAttributes: attributes)
    }
}

final class SuggestionBarView: NSView {
    var onSelect: ((String) -> Void)?
    var fontSize: CGFloat = 13
    var spacing: CGFloat = 6
    var dwell = DwellConfiguration()
    var theme = Theme.system

    private var chips: [SuggestionChipView] = []

    /// The chips currently on screen, for scanning.
    var scanItems: [SuggestionChipView] { chips }

    override var mouseDownCanMoveWindow: Bool { true }

    func setSuggestions(_ suggestions: [String]) {
        guard suggestions != chips.map(\.title) else { return }
        chips.forEach { $0.removeFromSuperview() }
        chips = []

        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let height = bounds.height - 2
        var x: CGFloat = 0
        for suggestion in suggestions {
            let chip = SuggestionChipView(title: suggestion, theme: theme, font: font, dwell: dwell)
            let width = chip.fittingWidth(height: height)
            // Suggestions are ordered best-first, so whatever no longer fits
            // is dropped rather than clipped mid-word.
            guard x + width <= bounds.width else { break }
            chip.frame = NSRect(x: x, y: 1, width: width, height: height)
            chip.onSelect = { [weak self] title in self?.onSelect?(title) }
            addSubview(chip)
            chips.append(chip)
            x += width + spacing
        }
    }
}
#endif
