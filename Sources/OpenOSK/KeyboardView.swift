import AppKit
import OpenOSKCore

/// Sizing constants for the keyboard, scaled by the user's key size setting.
struct KeyboardMetrics {
    let scale: CGFloat

    var unit: CGFloat { 46 * scale }
    var keyHeight: CGFloat { 46 * scale }
    var gap: CGFloat { 5 * scale }
    var padding: CGFloat { 8 * scale }
    var suggestionHeight: CGFloat { 34 * scale }
    var keyFontSize: CGFloat { 16 * scale }
    var secondaryFontSize: CGFloat { 9 * scale }
    var suggestionFontSize: CGFloat { 13 * scale }

    func size(for layout: KeyboardLayout) -> NSSize {
        let maxUnits = CGFloat(layout.maxRowUnits)
        let maxKeys = CGFloat(layout.rows.map(\.count).max() ?? 0)
        let width = maxUnits * unit + max(0, maxKeys - 1) * gap + padding * 2
        let rows = CGFloat(layout.rows.count)
        let height = rows * keyHeight + (rows - 1) * gap + suggestionHeight + gap + padding * 2
        return NSSize(width: ceil(width), height: ceil(height))
    }
}

enum ModifierVisualState {
    case off
    case latched
    case locked
}

// MARK: - Key view

final class KeyView: NSView {
    let key: Key
    var displayText = ""
    var secondaryText: String?
    var modifierState: ModifierVisualState = .off {
        didSet { needsDisplay = true }
    }
    var fontSize: CGFloat = 16
    var secondaryFontSize: CGFloat = 9

    var onPress: ((Key) -> Void)?

    private var isPressedVisual = false {
        didSet { needsDisplay = true }
    }
    private var isHovered = false {
        didSet { needsDisplay = true }
    }
    private var repeatTimer: Timer?

    init(key: Key) {
        self.key = key
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var mouseDownCanMoveWindow: Bool { false }

    private var autorepeats: Bool {
        if case .special(let special) = key.kind { return special.autorepeats }
        return false
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

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }

    override func mouseDown(with event: NSEvent) {
        isPressedVisual = true
        onPress?(key)
        if autorepeats {
            let timer = Timer(timeInterval: 0.35, repeats: false) { [weak self] _ in
                self?.startRepeating()
            }
            RunLoop.current.add(timer, forMode: .common)
            repeatTimer = timer
        }
    }

    override func mouseUp(with event: NSEvent) {
        isPressedVisual = false
        stopRepeating()
    }

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

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)

        let isSpecial: Bool
        if case .character = key.kind { isSpecial = false } else { isSpecial = true }

        var fill: NSColor
        if isPressedVisual {
            fill = .controlAccentColor
        } else {
            switch modifierState {
            case .off:
                fill = isSpecial
                    ? NSColor.controlColor.withAlphaComponent(0.55)
                    : NSColor.controlColor
                if isHovered {
                    fill = fill.blended(withFraction: 0.15, of: .controlAccentColor) ?? fill
                }
            case .latched:
                fill = NSColor.controlAccentColor.withAlphaComponent(0.35)
            case .locked:
                fill = NSColor.controlAccentColor.withAlphaComponent(0.7)
            }
        }
        fill.setFill()
        path.fill()

        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        if modifierState == .latched || modifierState == .locked {
            let border = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
            NSColor.controlAccentColor.setStroke()
            border.lineWidth = 2
            border.stroke()
        }

        let textColor: NSColor = isPressedVisual ? .white : .labelColor

        if !displayText.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: isSpecial ? .medium : .regular),
                .foregroundColor: textColor,
            ]
            let size = displayText.size(withAttributes: attributes)
            let origin = NSPoint(
                x: bounds.midX - size.width / 2,
                y: bounds.midY - size.height / 2
            )
            displayText.draw(at: origin, withAttributes: attributes)
        }

        if let secondaryText, !secondaryText.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: secondaryFontSize),
                .foregroundColor: isPressedVisual
                    ? NSColor.white.withAlphaComponent(0.8)
                    : NSColor.secondaryLabelColor,
            ]
            let size = secondaryText.size(withAttributes: attributes)
            let origin = NSPoint(
                x: bounds.maxX - size.width - 5,
                y: bounds.maxY - size.height - 3
            )
            secondaryText.draw(at: origin, withAttributes: attributes)
        }
    }
}

// MARK: - Suggestion bar

final class SuggestionBarView: NSView {
    var onSelect: ((String) -> Void)?
    var fontSize: CGFloat = 13

    private var buttons: [NSButton] = []

    override var mouseDownCanMoveWindow: Bool { true }

    func setSuggestions(_ suggestions: [String]) {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = suggestions.map { suggestion in
            let button = NSButton(title: suggestion, target: self, action: #selector(selected(_:)))
            button.bezelStyle = .rounded
            button.controlSize = .large
            button.font = .systemFont(ofSize: fontSize)
            addSubview(button)
            return button
        }
        needsLayout = true
        layoutButtons()
    }

    @objc private func selected(_ sender: NSButton) {
        onSelect?(sender.title)
    }

    override func layout() {
        super.layout()
        layoutButtons()
    }

    private func layoutButtons() {
        var x: CGFloat = 0
        for button in buttons {
            let width = button.intrinsicContentSize.width + 8
            button.frame = NSRect(x: x, y: 0, width: width, height: bounds.height)
            x += width + 6
        }
    }
}

// MARK: - Keyboard view

final class KeyboardView: NSView {
    let layout: KeyboardLayout
    let metrics: KeyboardMetrics
    let suggestionBar = SuggestionBarView()

    var onKeyPress: ((Key) -> Void)?

    private var keyViews: [KeyView] = []

    init(layout: KeyboardLayout, metrics: KeyboardMetrics) {
        self.layout = layout
        self.metrics = metrics
        super.init(frame: NSRect(origin: .zero, size: metrics.size(for: layout)))
        wantsLayer = true

        suggestionBar.fontSize = metrics.suggestionFontSize
        addSubview(suggestionBar)

        for row in layout.rows {
            for key in row {
                let view = KeyView(key: key)
                view.fontSize = metrics.keyFontSize
                view.secondaryFontSize = metrics.secondaryFontSize
                view.onPress = { [weak self] key in self?.onKeyPress?(key) }
                addSubview(view)
                keyViews.append(view)
            }
        }
        updateKeyCaps(shifted: false, alted: false, modifierStates: [:])
        layoutKeys()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var mouseDownCanMoveWindow: Bool { true }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 14, yRadius: 14)
        NSColor.windowBackgroundColor.setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    func updateKeyCaps(
        shifted: Bool,
        alted: Bool,
        modifierStates: [Modifier: ModifierVisualState]
    ) {
        for view in keyViews {
            let key = view.key
            switch key.kind {
            case .character:
                view.displayText = key.label ?? key.output(shifted: shifted, alted: alted) ?? ""
                if !shifted, !alted, let shiftOutput = key.shift,
                   shiftOutput != key.base?.uppercased() {
                    view.secondaryText = shiftOutput
                } else {
                    view.secondaryText = nil
                }
                view.modifierState = .off
            case .special(let special):
                view.displayText = key.label ?? special.symbol
                view.secondaryText = nil
                view.modifierState = .off
            case .modifier(let modifier):
                view.displayText = key.label ?? modifier.symbol
                view.secondaryText = nil
                view.modifierState = modifierStates[modifier] ?? .off
            case nil:
                break
            }
            view.needsDisplay = true
        }
    }

    private func layoutKeys() {
        let m = metrics
        suggestionBar.frame = NSRect(
            x: m.padding,
            y: m.padding,
            width: bounds.width - m.padding * 2,
            height: m.suggestionHeight
        )

        var index = 0
        var y = m.padding + m.suggestionHeight + m.gap
        for row in layout.rows {
            let rowUnits = row.reduce(0.0) { $0 + $1.effectiveWidth }
            let rowWidth = CGFloat(rowUnits) * m.unit + CGFloat(row.count - 1) * m.gap
            var x = (bounds.width - rowWidth) / 2
            for key in row {
                let width = CGFloat(key.effectiveWidth) * m.unit
                keyViews[index].frame = NSRect(x: x, y: y, width: width, height: m.keyHeight)
                x += width + m.gap
                index += 1
            }
            y += m.keyHeight + m.gap
        }
    }
}
