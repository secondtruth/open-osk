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
    /// Large sorted word list used as a low-priority fallback (kept out of
    /// the trie to save memory; e.g. /usr/share/dict/words).
    private var fallbackWords: [String] = []

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

    /// Loads a large dictionary as lowest-priority fallback. The file is one
    /// word per line; entries are lowercased and sorted for prefix search.
    public func loadFallbackDictionary(atPath path: String, maxWordLength: Int = 16) {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        fallbackWords = content
            .components(separatedBy: .newlines)
            .lazy
            .map { $0.lowercased() }
            .filter { $0.count >= 3 && $0.count <= maxWordLength }
            .sorted()
    }

    public func clearFallbackDictionary() {
        fallbackWords = []
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

        var suggestions = results
            .prefix(limit)
            .map { applyCapitalization(of: prefix, to: $0.word) }

        if suggestions.count < limit {
            let lowered = Set(suggestions.map { $0.lowercased() })
            for word in fallbackMatches(forPrefix: prefix.lowercased()) {
                guard suggestions.count < limit else { break }
                guard !lowered.contains(word) else { continue }
                suggestions.append(applyCapitalization(of: prefix, to: word))
            }
        }
        return suggestions
    }

    /// Binary search into the sorted fallback list, then walk matches.
    private func fallbackMatches(forPrefix prefix: String, cap: Int = 10) -> [String] {
        guard !fallbackWords.isEmpty else { return [] }
        var low = 0
        var high = fallbackWords.count
        while low < high {
            let mid = (low + high) / 2
            if fallbackWords[mid] < prefix {
                low = mid + 1
            } else {
                high = mid
            }
        }
        var matches: [String] = []
        var index = low
        while index < fallbackWords.count, matches.count < cap,
              fallbackWords[index].hasPrefix(prefix) {
            if fallbackWords[index] != prefix {
                matches.append(fallbackWords[index])
            }
            index += 1
        }
        matches.sort { $0.count != $1.count ? $0.count < $1.count : $0 < $1 }
        return matches
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
