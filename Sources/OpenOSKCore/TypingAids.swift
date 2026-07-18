import Foundation

/// Sentence-level typing conveniences, modeled after the macOS Accessibility
/// Keyboard: auto-capitalization at sentence starts and double-space → period.
public enum TypingAids {
    private static let sentenceEnders: Set<Character> = [".", "!", "?"]

    /// Whether the next typed letter should be capitalized: the tracked line
    /// ends with sentence-ending punctuation followed by whitespace.
    ///
    /// An empty line is deliberately *not* treated as a sentence start — the
    /// tracker resets whenever focus moves, so an empty line usually means
    /// "unknown context", not "new sentence".
    public static func shouldAutoCapitalize(afterLine line: String) -> Bool {
        guard line.hasSuffix(" ") else { return false }
        guard let lastNonSpace = line.last(where: { $0 != " " }) else { return false }
        return sentenceEnders.contains(lastNonSpace)
    }

    /// Whether pressing space should turn the trailing "word " into "word. "
    /// (the second space of a double-space becomes a period).
    public static func shouldInsertPeriodOnDoubleSpace(line: String) -> Bool {
        guard line.hasSuffix(" "), !line.hasSuffix("  ") else { return false }
        guard let beforeSpace = line.dropLast().last else { return false }
        return beforeSpace.isLetter || beforeSpace.isNumber
    }
}
