import CoreGraphics
import Foundation

/// A latchable modifier key on the on-screen keyboard.
public enum Modifier: String, Codable, CaseIterable, Sendable {
    case shift
    case control
    case option
    case command

    public var flags: CGEventFlags {
        switch self {
        case .shift: return .maskShift
        case .control: return .maskControl
        case .option: return .maskAlternate
        case .command: return .maskCommand
        }
    }

    public var symbol: String {
        switch self {
        case .shift: return "⇧"
        case .control: return "⌃"
        case .option: return "⌥"
        case .command: return "⌘"
        }
    }
}

/// Non-character keys that are posted as virtual key codes.
public enum SpecialKey: String, Codable, CaseIterable, Sendable {
    case escape
    case tab
    case delete
    case forwardDelete
    case `return`
    case space
    case left
    case right
    case up
    case down
    case home
    case end
    case pageUp
    case pageDown

    /// Hardware-independent macOS virtual key code (kVK_* constants).
    public var keyCode: CGKeyCode {
        switch self {
        case .escape: return 53
        case .tab: return 48
        case .delete: return 51
        case .forwardDelete: return 117
        case .return: return 36
        case .space: return 49
        case .left: return 123
        case .right: return 124
        case .down: return 125
        case .up: return 126
        case .home: return 115
        case .end: return 119
        case .pageUp: return 116
        case .pageDown: return 121
        }
    }

    public var symbol: String {
        switch self {
        case .escape: return "esc"
        case .tab: return "⇥"
        case .delete: return "⌫"
        case .forwardDelete: return "⌦"
        case .return: return "⏎"
        case .space: return ""
        case .left: return "←"
        case .right: return "→"
        case .up: return "↑"
        case .down: return "↓"
        case .home: return "↖"
        case .end: return "↘"
        case .pageUp: return "⇞"
        case .pageDown: return "⇟"
        }
    }

    /// Keys that repeat while held down.
    public var autorepeats: Bool {
        switch self {
        case .delete, .forwardDelete, .left, .right, .up, .down, .space:
            return true
        default:
            return false
        }
    }
}

/// A single key definition inside a layout.
///
/// Exactly one of `base`, `special` or `modifier` should be set.
public struct Key: Codable, Equatable, Sendable {
    /// Output of a character key in the base layer.
    public var base: String?
    /// Output with Shift active. Defaults to the uppercased base.
    public var shift: String?
    /// Output with Option active.
    public var alt: String?
    /// Output with Shift+Option active.
    public var shiftAlt: String?
    /// Special (non-character) key.
    public var special: SpecialKey?
    /// Modifier key.
    public var modifier: Modifier?
    /// Text snippet inserted verbatim (programmable key shorthand).
    public var text: String?
    /// Macro executed by this key (programmable key).
    public var macro: Macro?
    /// Width in key units (1.0 = one standard key).
    public var width: Double?
    /// Display label override.
    public var label: String?

    public init(
        base: String? = nil, shift: String? = nil, alt: String? = nil, shiftAlt: String? = nil,
        special: SpecialKey? = nil, modifier: Modifier? = nil,
        text: String? = nil, macro: Macro? = nil,
        width: Double? = nil, label: String? = nil
    ) {
        self.base = base
        self.shift = shift
        self.alt = alt
        self.shiftAlt = shiftAlt
        self.special = special
        self.modifier = modifier
        self.text = text
        self.macro = macro
        self.width = width
        self.label = label
    }

    public enum Kind {
        case character
        case special(SpecialKey)
        case modifier(Modifier)
        case macro(Macro)
    }

    public var kind: Kind? {
        if let macro { return .macro(macro) }
        if let text { return .macro(Macro(steps: [MacroStep(text: text)])) }
        if let special { return .special(special) }
        if let modifier { return .modifier(modifier) }
        if base != nil { return .character }
        return nil
    }

    public var effectiveWidth: Double { width ?? 1.0 }

    /// The text a character key produces for the given modifier layer.
    public func output(shifted: Bool, alted: Bool) -> String? {
        guard let base else { return nil }
        switch (shifted, alted) {
        case (false, false):
            return base
        case (true, false):
            return shift ?? autoShifted(base)
        case (false, true):
            return alt ?? base
        case (true, true):
            return shiftAlt ?? alt.map(autoShifted) ?? shift ?? autoShifted(base)
        }
    }

    private func autoShifted(_ text: String) -> String {
        let upper = text.uppercased()
        return upper == text ? text : upper
    }
}

/// A complete keyboard layout, loadable from JSON.
public struct KeyboardLayout: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var rows: [[Key]]

    public init(id: String, name: String, rows: [[Key]]) {
        self.id = id
        self.name = name
        self.rows = rows
    }

    /// Width of the widest row in key units, gaps not included.
    public var maxRowUnits: Double {
        rows.map { $0.reduce(0) { $0 + $1.effectiveWidth } }.max() ?? 0
    }
}
