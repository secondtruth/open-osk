import CoreGraphics
import Foundation

/// A programmable key action: a sequence of steps that insert text, press
/// shortcuts, open apps/URLs, or wait.
public struct Macro: Codable, Equatable, Sendable {
    public var steps: [MacroStep]

    public init(steps: [MacroStep]) {
        self.steps = steps
    }

    /// Macros that only insert text can keep the composition tracker in sync;
    /// anything else invalidates it.
    public var isPlainText: Bool {
        steps.allSatisfy { $0.text != nil && $0.shortcut == nil && $0.open == nil }
    }
}

/// One step of a macro. Exactly one of `text`, `shortcut` or `open` should be
/// set; `delayMs` optionally waits before the step executes.
public struct MacroStep: Codable, Equatable, Sendable {
    /// Text to type.
    public var text: String?
    /// Shortcut to press, e.g. `"cmd+shift+s"`, `"ctrl+c"`, `"cmd+return"`.
    public var shortcut: String?
    /// URL or absolute file path to open.
    public var open: String?
    /// Delay in milliseconds before this step runs.
    public var delayMs: Int?

    public init(text: String? = nil, shortcut: String? = nil, open: String? = nil, delayMs: Int? = nil) {
        self.text = text
        self.shortcut = shortcut
        self.open = open
        self.delayMs = delayMs
    }
}

/// A parsed shortcut string: modifier flags plus either a character (resolved
/// to a key code at execution time) or a named special key.
public struct ParsedShortcut: Equatable {
    public var flags: CGEventFlags
    public var character: Character?
    public var special: SpecialKey?

    public init(flags: CGEventFlags, character: Character? = nil, special: SpecialKey? = nil) {
        self.flags = flags
        self.character = character
        self.special = special
    }
}

public enum ShortcutParser {
    private static let specialAliases: [String: SpecialKey] = [
        "enter": .return,
        "esc": .escape,
        "backspace": .delete,
        "del": .forwardDelete,
        "pgup": .pageUp,
        "pgdown": .pageDown,
    ]

    /// Parses strings like `"cmd+shift+s"`, `"ctrl+alt+delete"`, `"cmd+,"`.
    /// Returns nil for malformed input.
    public static func parse(_ string: String) -> ParsedShortcut? {
        let parts = string.lowercased().split(separator: "+").map(String.init)
        // A trailing "+" means the key itself is "+" (e.g. "cmd++"), and all
        // named parts are modifiers.
        let keyIsPlus = string.hasSuffix("+")
        let keyPart = keyIsPlus ? "+" : parts.last
        guard let keyPart, keyIsPlus || !parts.isEmpty else { return nil }

        var flags: CGEventFlags = []
        for part in keyIsPlus ? parts[...] : parts.dropLast() {
            switch part {
            case "cmd", "command": flags.insert(.maskCommand)
            case "ctrl", "control": flags.insert(.maskControl)
            case "alt", "opt", "option": flags.insert(.maskAlternate)
            case "shift": flags.insert(.maskShift)
            default: return nil
            }
        }

        if let special = SpecialKey(rawValue: keyPart) ?? specialAliases[keyPart] {
            return ParsedShortcut(flags: flags, special: special)
        }
        guard keyPart.count == 1, let character = keyPart.first else { return nil }
        return ParsedShortcut(flags: flags, character: character)
    }
}
