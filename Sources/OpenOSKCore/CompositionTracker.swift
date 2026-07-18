import Foundation

/// Tracks what the on-screen keyboard has typed since the last line break so
/// that predictions can work on the current word or command line.
///
/// Only input injected by OpenOSK itself is visible here — text typed with a
/// hardware keyboard or completed by the target application is not observed.
public final class CompositionTracker {
    public private(set) var line = ""

    public init() {}

    /// Characters considered part of a word for text prediction.
    private static let wordCharacters = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: "'äöüßÄÖÜáàâéèêíìîóòôúùû"))

    /// The token being typed, i.e. everything after the last whitespace.
    public var currentToken: String {
        guard let lastSpace = line.lastIndex(where: { $0 == " " || $0 == "\t" }) else {
            return line
        }
        return String(line[line.index(after: lastSpace)...])
    }

    /// The trailing run of word characters (for word prediction).
    public var currentWord: String {
        var word = ""
        for character in line.reversed() {
            guard let scalar = character.unicodeScalars.first,
                  Self.wordCharacters.contains(scalar)
            else { break }
            word.insert(character, at: word.startIndex)
        }
        return word
    }

    /// All complete word tokens in the current line.
    private var wordTokens: [String] {
        line.split { character in
            guard let scalar = character.unicodeScalars.first else { return true }
            return !Self.wordCharacters.contains(scalar)
        }.map(String.init)
    }

    /// The word before the one currently being typed (for bigram learning).
    public var previousWord: String {
        guard !currentWord.isEmpty else { return "" }
        let tokens = wordTokens
        return tokens.count >= 2 ? tokens[tokens.count - 2] : ""
    }

    /// The most recently completed word when the line ends in a separator
    /// (for next-word prediction).
    public var lastCompletedWord: String {
        guard currentWord.isEmpty else { return "" }
        return wordTokens.last ?? ""
    }

    public func typed(_ text: String) {
        for character in text {
            if character == "\n" || character == "\r" {
                line = ""
            } else {
                line.append(character)
            }
        }
    }

    public func backspaced() {
        if !line.isEmpty {
            line.removeLast()
        }
    }

    /// Called when Return is pressed; returns the submitted line.
    @discardableResult
    public func submittedLine() -> String {
        defer { line = "" }
        return line
    }

    /// Forget everything, e.g. after the user clicked somewhere else.
    public func reset() {
        line = ""
    }
}
