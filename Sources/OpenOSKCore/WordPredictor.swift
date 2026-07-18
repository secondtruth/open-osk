import Foundation

/// Prefix-based word prediction backed by frequency-ordered word lists and
/// words learned from the user's own typing.
public final class WordPredictor {
    private final class Node {
        var children: [Character: Node] = [:]
        /// Position in the base word list; lower = more frequent.
        var rank: Int?
        /// How often the user typed this word.
        var learnedCount = 0
    }

    private let root = Node()
    private var nextRank = 0

    public init() {}

    // MARK: - Loading

    public func load(words: [String]) {
        for word in words {
            let normalized = word.trimmingCharacters(in: .whitespaces)
            guard !normalized.isEmpty, !normalized.hasPrefix("#") else { continue }
            let node = node(for: normalized.lowercased(), createIfMissing: true)!
            if node.rank == nil {
                node.rank = nextRank
                nextRank += 1
            }
        }
    }

    /// Loads bundled word lists, e.g. `["de", "en"]`.
    public func loadBundledWordlists(languages: [String]) {
        for language in languages {
            guard
                let url = Bundle.module.url(
                    forResource: language,
                    withExtension: "txt",
                    subdirectory: "Resources/Wordlists"
                ),
                let content = try? String(contentsOf: url, encoding: .utf8)
            else { continue }
            load(words: content.components(separatedBy: .newlines))
        }
    }

    // MARK: - Learning

    public func learn(_ word: String, count: Int = 1) {
        let normalized = word.lowercased()
        guard normalized.count >= 2 else { return }
        let node = node(for: normalized, createIfMissing: true)!
        node.learnedCount += count
    }

    // MARK: - Prediction

    /// Suggestions for a prefix, most likely first. Capitalization of the
    /// prefix is carried over to the suggestions.
    public func suggestions(forPrefix prefix: String, limit: Int = 5) -> [String] {
        guard prefix.count >= 1 else { return [] }
        let lowered = prefix.lowercased()
        guard let start = node(for: lowered, createIfMissing: false) else { return [] }

        var results: [(word: String, learned: Int, rank: Int)] = []
        collect(from: start, prefix: lowered, into: &results, budget: 500)

        results.sort {
            if $0.learned != $1.learned { return $0.learned > $1.learned }
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            return $0.word.count < $1.word.count
        }

        return results
            .prefix(limit)
            .map { applyCapitalization(of: prefix, to: $0.word) }
    }

    private func collect(
        from node: Node,
        prefix: String,
        into results: inout [(word: String, learned: Int, rank: Int)],
        budget: Int
    ) {
        var remaining = budget
        var stack: [(Node, String)] = [(node, prefix)]
        while let (current, word) = stack.popLast(), remaining > 0 {
            remaining -= 1
            if current.rank != nil || current.learnedCount > 0 {
                results.append((word, current.learnedCount, current.rank ?? Int.max))
            }
            for (character, child) in current.children {
                stack.append((child, word + String(character)))
            }
        }
    }

    private func applyCapitalization(of prefix: String, to word: String) -> String {
        guard word.lowercased().hasPrefix(prefix.lowercased()) else { return word }
        if prefix.count >= 2, prefix == prefix.uppercased(), prefix != prefix.lowercased() {
            return word.uppercased()
        }
        if let first = prefix.first, first.isUppercase {
            return word.prefix(1).uppercased() + word.dropFirst()
        }
        return word
    }

    private func node(for word: String, createIfMissing: Bool) -> Node? {
        var current = root
        for character in word {
            if let child = current.children[character] {
                current = child
            } else if createIfMissing {
                let child = Node()
                current.children[character] = child
                current = child
            } else {
                return nil
            }
        }
        return current
    }
}
