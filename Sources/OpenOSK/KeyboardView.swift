import AppKit
import OpenOSKCore

/// Sizing constants for the keyboard, scaled by the user's key size setting.
struct KeyboardMetrics {
    let scale: CGFloat
    var showsCurrentText = true
    var showsSuggestionBar = true

    var unit: CGFloat { 46 * scale }
    var keyHeight: CGFloat { 46 * scale }
    var gap: CGFloat { 5 * scale }
    var padding: CGFloat { 8 * scale }
    var currentTextHeight: CGFloat { showsCurrentText ? 24 * scale : 0 }
    var suggestionHeight: CGFloat { showsSuggestionBar ? 34 * scale : 0 }
    var keyFontSize: CGFloat { 16 * scale }
    var secondaryFontSize: CGFloat { 9 * scale }
    var suggestionFontSize: CGFloat { 13 * scale }
    var currentTextFontSize: CGFloat { 12 * scale }

    func size(for layout: KeyboardLayout) -> NSSize {
        let maxUnits = CGFloat(layout.maxRowUnits)
        let maxKeys = CGFloat(layout.rows.map(\.count).max() ?? 0)
        let width = maxUnits * unit + max(0, maxKeys - 1) * gap + padding * 2
        let rows = CGFloat(layout.rows.count)
        let height = rows * keyHeight + (rows - 1) * gap
            + currentTextHeight + suggestionHeight + gap + padding * 2
        return NSSize(width: ceil(width), height: ceil(height))
    }
}

/// Dwell (hover-to-press) configuration shared by key and suggestion views.
struct DwellConfiguration {
    var enabled = false
    var time: TimeInterval = 0.9
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
    var dwell = DwellConfiguration()

    var onPress: ((Key) -> Void)?
    /// Long-press hook for character keys; returns true if it was handled
    /// (e.g. a variant popup was shown), which suppresses the normal press.
    var onLongPress: ((Key, KeyView) -> Bool)?
    /// Highlight driven by scanning (switch access) mode.
    var isScanHighlighted = false {
        didSet { needsDisplay = true }
    }

    /// Programmatic activation, used by scanning mode.
    func triggerPress() {
        isPressedVisual = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.isPressedVisual = false
        }
        onPress?(key)
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

    private var dwellTicker: Timer?
    private var dwellStart: Date?
    private var dwellProgress: CGFloat = 0 {
        didSet { needsDisplay = true }
    }
    private var dwellCompleted = false

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

    // MARK: Mouse handling

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        if dwell.enabled, !dwellCompleted {
            startDwell()
        }
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        cancelDwell()
        dwellCompleted = false
    }

    override func mouseDown(with event: NSEvent) {
        cancelDwell()
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

    // MARK: Dwell

    private func startDwell() {
        cancelDwell()
        dwellStart = Date()
        let ticker = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.dwellStart else { return }
            let progress = CGFloat(Date().timeIntervalSince(start) / self.dwell.time)
            if progress >= 1 {
                self.completeDwell()
            } else {
                self.dwellProgress = progress
            }
        }
        RunLoop.current.add(ticker, forMode: .common)
        dwellTicker = ticker
    }

    private func completeDwell() {
        cancelDwell()
        dwellCompleted = true
        isPressedVisual = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.isPressedVisual = false
        }
        onPress?(key)
    }

    private func cancelDwell() {
        dwellTicker?.invalidate()
        dwellTicker = nil
        dwellStart = nil
        dwellProgress = 0
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)

        let isCharacter: Bool
        if case .character = key.kind { isCharacter = true } else { isCharacter = false }

        var fill: NSColor
        if isPressedVisual {
            fill = .controlAccentColor
        } else {
            switch modifierState {
            case .off:
                fill = isCharacter
                    ? NSColor.controlColor
                    : NSColor.controlColor.withAlphaComponent(0.55)
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

        if isScanHighlighted {
            let border = NSBezierPath(
                roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), xRadius: 6, yRadius: 6)
            NSColor.systemOrange.setStroke()
            border.lineWidth = 3
            border.stroke()
        }

        let textColor: NSColor = isPressedVisual ? .white : .labelColor

        if !displayText.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: fontSize, weight: isCharacter ? .regular : .medium),
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

        if dwellProgress > 0 {
            drawDwellProgress()
        }
    }

    /// Pie-style dwell progress indicator in the key's center.
    private func drawDwellProgress() {
        let radius = min(bounds.width, bounds.height) / 4.5
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
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
        NSColor.controlAccentColor.withAlphaComponent(0.55).setFill()
        pie.fill()
    }
}

// MARK: - Suggestion bar

/// Button that supports dwell selection.
final class SuggestionButton: NSButton {
    var dwell = DwellConfiguration()
    private var dwellTimer: Timer?

    var isScanHighlighted = false {
        didSet {
            wantsLayer = true
            layer?.borderWidth = isScanHighlighted ? 3 : 0
            layer?.borderColor = NSColor.systemOrange.cgColor
            layer?.cornerRadius = 6
        }
    }

    override var mouseDownCanMoveWindow: Bool { false }

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
        guard dwell.enabled else { return }
        let timer = Timer(timeInterval: dwell.time, repeats: false) { [weak self] _ in
            self?.performClick(nil)
        }
        RunLoop.current.add(timer, forMode: .common)
        dwellTimer = timer
    }

    override func mouseExited(with event: NSEvent) {
        dwellTimer?.invalidate()
        dwellTimer = nil
    }
}

final class SuggestionBarView: NSView {
    var onSelect: ((String) -> Void)?
    var fontSize: CGFloat = 13
    var dwell = DwellConfiguration()

    private var buttons: [SuggestionButton] = []

    var scanItems: [SuggestionButton] { buttons }

    override var mouseDownCanMoveWindow: Bool { true }

    func setSuggestions(_ suggestions: [String]) {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = suggestions.map { suggestion in
            let button = SuggestionButton(title: suggestion, target: self, action: #selector(selected(_:)))
            button.bezelStyle = .rounded
            button.controlSize = .large
            button.font = .systemFont(ofSize: fontSize)
            button.dwell = dwell
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
    var onKeyLongPress: ((Key, KeyView) -> Bool)?
    /// Reports pointer entering/leaving the whole keyboard (for fade logic).
    var onHoverChange: ((Bool) -> Void)?

    private var keyViews: [KeyView] = []
    private(set) var keyRows: [[KeyView]] = []
    private let currentTextLabel = NSTextField(labelWithString: "")

    /// Groups for scanning mode: the suggestion bar (if populated) followed by
    /// each key row.
    var scanGroups: [[NSView]] {
        var groups: [[NSView]] = []
        if metrics.showsSuggestionBar, !suggestionBar.scanItems.isEmpty {
            groups.append(suggestionBar.scanItems)
        }
        groups.append(contentsOf: keyRows.map { $0 })
        return groups
    }

    init(layout: KeyboardLayout, metrics: KeyboardMetrics, dwell: DwellConfiguration) {
        self.layout = layout
        self.metrics = metrics
        super.init(frame: NSRect(origin: .zero, size: metrics.size(for: layout)))
        wantsLayer = true

        if metrics.showsCurrentText {
            currentTextLabel.font = .monospacedSystemFont(
                ofSize: metrics.currentTextFontSize, weight: .regular)
            currentTextLabel.textColor = .secondaryLabelColor
            currentTextLabel.lineBreakMode = .byTruncatingHead
            currentTextLabel.alignment = .left
            addSubview(currentTextLabel)
        }

        if metrics.showsSuggestionBar {
            suggestionBar.fontSize = metrics.suggestionFontSize
            suggestionBar.dwell = dwell
            addSubview(suggestionBar)
        }

        for row in layout.rows {
            var rowViews: [KeyView] = []
            for key in row {
                let view = KeyView(key: key)
                view.fontSize = metrics.keyFontSize
                view.secondaryFontSize = metrics.secondaryFontSize
                view.dwell = dwell
                view.onPress = { [weak self] key in self?.onKeyPress?(key) }
                view.onLongPress = { [weak self] key, keyView in
                    self?.onKeyLongPress?(key, keyView) ?? false
                }
                addSubview(view)
                keyViews.append(view)
                rowViews.append(view)
            }
            keyRows.append(rowViews)
        }
        updateKeyCaps(shifted: false, alted: false, modifierStates: [:])
        layoutKeys()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override var mouseDownCanMoveWindow: Bool { true }
    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas where area.owner === self {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) { onHoverChange?(true) }
    override func mouseExited(with event: NSEvent) { onHoverChange?(false) }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds, xRadius: 14, yRadius: 14)
        NSColor.windowBackgroundColor.setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    func setCurrentText(_ text: String) {
        guard metrics.showsCurrentText else { return }
        currentTextLabel.stringValue = text
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
            case .macro:
                view.displayText = key.label ?? key.text.map { String($0.prefix(6)) } ?? "◆"
                view.secondaryText = nil
                view.modifierState = .off
            case nil:
                break
            }
            view.needsDisplay = true
        }
    }

    private func layoutKeys() {
        let m = metrics
        var y = m.padding

        if m.showsCurrentText {
            currentTextLabel.frame = NSRect(
                x: m.padding + 4,
                y: y + 2,
                width: bounds.width - (m.padding + 4) * 2,
                height: m.currentTextHeight - 4
            )
            y += m.currentTextHeight
        }

        if m.showsSuggestionBar {
            suggestionBar.frame = NSRect(
                x: m.padding,
                y: y,
                width: bounds.width - m.padding * 2,
                height: m.suggestionHeight
            )
            y += m.suggestionHeight + m.gap
        }

        var index = 0
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
