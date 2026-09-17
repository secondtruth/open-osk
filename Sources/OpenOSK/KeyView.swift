#if canImport(AppKit)
import AppKit
import OpenOSKCore

enum ModifierVisualState {
    case off
    case latched
    case locked
}

final class KeyView: NSView {
    let key: Key
    var displayText = ""
    var secondaryText: String?
    /// SF Symbol shown instead of the text label.
    var imageName: String? {
        didSet { if imageName != oldValue { symbolCache = [:] } }
    }
    /// What VoiceOver and Voice Control call this key.
    var spokenLabel = ""
    var modifierState: ModifierVisualState = .off {
        didSet { needsDisplay = true }
    }
    var fontSize: CGFloat = 16
    var secondaryFontSize: CGFloat = 9
    var cornerRadius: CGFloat = 7
    var dwell = DwellConfiguration()
    var theme = Theme.system

    var onPress: ((Key) -> Void)?
    /// Long-press hook for character keys; returns true if it was handled
    /// (e.g. a variant popup was shown), which suppresses the normal press.
    var onLongPress: ((Key, KeyView) -> Bool)?
    /// Highlight driven by scanning (switch access) mode.
    var isScanHighlighted = false {
        didSet { needsDisplay = true }
    }

    private var isPressedVisual = false {
        didSet { needsDisplay = true }
    }
    private var isHovered = false {
        didSet { needsDisplay = true }
    }
    private var repeatTimer: Timer?
    private var longPressTimer: Timer?
    private var longPressTriggered = false

    private let dwellTimer = DwellTimer()
    private var dwellProgress: CGFloat = 0 {
        didSet { needsDisplay = true }
    }
    private var dwellCompleted = false
    private var symbolCache: [Bool: NSImage] = [:]

    init(key: Key) {
        self.key = key
        super.init(frame: .zero)
        dwellTimer.onProgress = { [weak self] in self?.dwellProgress = $0 }
        dwellTimer.onComplete = { [weak self] in
            self?.dwellCompleted = true
            self?.triggerPress()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var mouseDownCanMoveWindow: Bool { false }

    /// Programmatic activation: scanning, dwell and assistive technology.
    func triggerPress() {
        isPressedVisual = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.isPressedVisual = false
        }
        onPress?(key)
    }

    private var autorepeats: Bool {
        switch key.kind {
        case .special(let special): return special.autorepeats
        case .media(let media): return media.autorepeats
        default: return false
        }
    }

    /// Character and macro keys fire on release (enables long-press variants
    /// and slide-away cancel-free behavior); specials/modifiers fire on press
    /// so autorepeat and latching feel immediate.
    private var firesOnMouseUp: Bool {
        switch key.kind {
        case .character, .macro: return true
        default: return false
        }
    }

    private var supportsLongPress: Bool {
        guard case .character = key.kind, let base = key.base else { return false }
        return !CharacterVariants.variants(for: base, shifted: false).isEmpty
            || !CharacterVariants.variants(for: base, shifted: true).isEmpty
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

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        symbolCache = [:]
        needsDisplay = true
    }

    // MARK: Accessibility

    // The panel never becomes key, but assistive technology reads and presses
    // its elements through the accessibility API regardless of focus.
    override func isAccessibilityElement() -> Bool { true }
    override func accessibilityRole() -> NSAccessibility.Role? { .button }
    override func accessibilityLabel() -> String? { spokenLabel }

    override func accessibilityPerformPress() -> Bool {
        triggerPress()
        return true
    }

    // MARK: Mouse handling

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        if dwell.enabled, !dwellCompleted {
            dwellTimer.start(duration: dwell.time)
        }
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        dwellTimer.cancel()
        dwellCompleted = false
    }

    override func mouseDown(with event: NSEvent) {
        dwellTimer.cancel()
        isPressedVisual = true
        longPressTriggered = false

        if firesOnMouseUp {
            if supportsLongPress {
                let timer = Timer(timeInterval: 0.45, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    self.longPressTriggered = self.onLongPress?(self.key, self) ?? false
                    if self.longPressTriggered {
                        self.isPressedVisual = false
                    }
                }
                RunLoop.current.add(timer, forMode: .common)
                longPressTimer = timer
            }
        } else {
            onPress?(key)
            if autorepeats {
                let timer = Timer(timeInterval: 0.35, repeats: false) { [weak self] _ in
                    self?.startRepeating()
                }
                RunLoop.current.add(timer, forMode: .common)
                repeatTimer = timer
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        isPressedVisual = false
        stopRepeating()
        longPressTimer?.invalidate()
        longPressTimer = nil

        if firesOnMouseUp, !longPressTriggered {
            onPress?(key)
        }
        longPressTriggered = false
    }

    // MARK: Autorepeat

    private func startRepeating() {
        stopRepeating()
        let timer = Timer(timeInterval: 0.06, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.onPress?(self.key)
        }
        RunLoop.current.add(timer, forMode: .common)
        repeatTimer = timer
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }

    // MARK: Drawing

    private var isCharacter: Bool {
        if case .character = key.kind { return true }
        return false
    }

    private var fillColor: NSColor {
        if isPressedVisual { return theme.pressed }
        var fill: NSColor
        switch modifierState {
        case .off:
            fill = isCharacter ? theme.keyFill : theme.specialFill
            if isHovered {
                fill = fill.blended(withFraction: 0.15, of: theme.pressed) ?? fill
            }
        // Blended rather than translucent: over a black panel a see-through
        // accent turns muddy.
        case .latched:
            fill = theme.specialFill.blended(withFraction: 0.4, of: theme.pressed) ?? theme.pressed
        case .locked:
            fill = theme.specialFill.blended(withFraction: 0.85, of: theme.pressed) ?? theme.pressed
        }
        if isScanHighlighted {
            fill = fill.blended(withFraction: 0.3, of: theme.scanHighlight) ?? fill
        }
        return fill
    }

    override func draw(_ dirtyRect: NSRect) {
        // One point at the bottom is left for the lip that lifts the key cap
        // off the panel.
        var cap = bounds.insetBy(dx: 0.5, dy: 0.5)
        cap.origin.y += 1
        cap.size.height -= 1

        if !isPressedVisual {
            let lip = NSBezierPath(
                roundedRect: cap.offsetBy(dx: 0, dy: -1),
                xRadius: cornerRadius, yRadius: cornerRadius)
            theme.border.withAlphaComponent(0.6).setFill()
            lip.fill()
        }

        let path = NSBezierPath(roundedRect: cap, xRadius: cornerRadius, yRadius: cornerRadius)
        fillColor.setFill()
        path.fill()
        theme.border.setStroke()
        path.lineWidth = 1
        path.stroke()

        if isScanHighlighted {
            strokeInnerBorder(in: cap, color: theme.scanHighlight, width: 3)
        } else if modifierState != .off {
            strokeInnerBorder(in: cap, color: theme.pressed, width: 2)
        }

        let textColor: NSColor = isPressedVisual ? theme.pressedText : theme.text
        let center = NSPoint(x: cap.midX, y: cap.midY)

        if let symbol = symbolImage(pressed: isPressedVisual) {
            let size = symbol.size
            symbol.draw(in: NSRect(
                x: center.x - size.width / 2,
                y: center.y - size.height / 2,
                width: size.width,
                height: size.height
            ))
        } else if !displayText.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: isCharacter ? .regular : .medium),
                .foregroundColor: textColor,
            ]
            let size = displayText.size(withAttributes: attributes)
            displayText.draw(
                at: NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2),
                withAttributes: attributes)
        }

        if let secondaryText, !secondaryText.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: secondaryFontSize),
                .foregroundColor: isPressedVisual
                    ? theme.pressedText.withAlphaComponent(0.8)
                    : theme.secondaryText,
            ]
            let size = secondaryText.size(withAttributes: attributes)
            let inset = cornerRadius * 0.7
            secondaryText.draw(
                at: NSPoint(x: cap.maxX - size.width - inset, y: cap.maxY - size.height - inset / 2),
                withAttributes: attributes)
        }

        if dwellProgress > 0 {
            drawDwellProgress(center: center)
        }
    }

    private func strokeInnerBorder(in rect: NSRect, color: NSColor, width: CGFloat) {
        let inset = width / 2
        let border = NSBezierPath(
            roundedRect: rect.insetBy(dx: inset, dy: inset),
            xRadius: max(0, cornerRadius - inset), yRadius: max(0, cornerRadius - inset))
        color.setStroke()
        border.lineWidth = width
        border.stroke()
    }

    /// The key's SF Symbol in the current text color. Rendered once per
    /// pressed state; redrawing happens on every hover and dwell tick.
    private func symbolImage(pressed: Bool) -> NSImage? {
        guard let imageName else { return nil }
        if let cached = symbolCache[pressed] { return cached }
        let color = pressed ? theme.pressedText : theme.text
        let configuration = NSImage.SymbolConfiguration(pointSize: fontSize * 1.15, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        guard let image = NSImage(systemSymbolName: imageName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        else { return nil }
        symbolCache[pressed] = image
        return image
    }

    /// Pie-style dwell progress indicator in the key's center.
    private func drawDwellProgress(center: NSPoint) {
        let radius = min(bounds.width, bounds.height) / 4.5
        let pie = NSBezierPath()
        pie.move(to: center)
        pie.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: 90 - 360 * dwellProgress,
            clockwise: true
        )
        pie.close()
        theme.pressed.withAlphaComponent(0.55).setFill()
        pie.fill()
    }
}
#endif
