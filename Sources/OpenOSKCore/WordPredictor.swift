import Foundation

/// Prefix-based word prediction backed by frequency-ordered word lists and
/// words learned from the user's own typing.
public final class WordPredictor {
    private final class Node {
        var children: [Character: Node] = [:]
        /// Position in the base word list; lower = more frequent.
        var rank: Int?
        /// Lowest rank anywhere below (and including) this node. Lets the
        /// search walk straight to the most frequent words instead of
        /// exploring the subtree, which for short prefixes is most of the trie.
        var bestRank = Int.max
    }

    private let root = Node()
    private var nextRank = 0
    /// How often the user typed each word. Kept beside the trie: the set is
    /// small, and it has to be cleared and ranked independently of list order.
    private var learnedCounts: [String: Int] = [:]
    /// Large sorted word list used as a low-priority fallback (kept out of
    /// the trie to save memory; e.g. /usr/share/dict/words).
    private var fallbackWords: [String] = []

    public init() {}

    // MARK: - Loading

    public func load(words: [String]) {
        for word in words {
            let normalized = word.trimmingCharacters(in: .whitespaces)
            guard !normalized.isEmpty, !normalized.hasPrefix("#") else { continue }
            insert(normalized.lowercased())
        }
    }

    private func insert(_ word: String) {
        var path = [root]
        for character in word {
            let parent = path[path.count - 1]
            if let child = parent.children[character] {
                path.append(child)
            } else {
                let child = Node()
                parent.children[character] = child
                path.append(child)
            }
        }
        guard let node = path.last, node.rank == nil else { return }
        node.rank = nextRank
        // Ranks only grow, so a node's best rank is settled by its first word.
        for ancestor in path where ancestor.bestRank == Int.max {
            ancestor.bestRank = nextRank
        }
        nextRank += 1
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
        learnedCounts[normalized, default: 0] += count
    }

    /// Forgets everything learned; the base word lists stay loaded.
    public func clearLearned() {
        learnedCounts = [:]
    }

    // MARK: - Prediction

    /// Suggestions for a prefix, most likely first. Capitalization of the
    /// prefix is carried over to the suggestions.
    public func suggestions(forPrefix prefix: String, limit: Int = 5) -> [String] {
        guard prefix.count >= 1 else { return [] }
        let lowered = prefix.lowercased()

        let learnedMatches = learnedCounts.filter { $0.key.hasPrefix(lowered) }
        var results: [(word: String, learned: Int, rank: Int)] = learnedMatches.map {
            ($0.key, $0.value, node(for: $0.key)?.rank ?? Int.max)
        }
        if let start = node(for: lowered) {
            // Learned words may displace list words, so fetch enough of both.
            let ranked = mostFrequent(from: start, prefix: lowered, count: limit + learnedMatches.count)
            results += ranked
                .filter { learnedMatches[$0.word] == nil }
                .map { ($0.word, 0, $0.rank) }
        }

        results.sort {
            if $0.learned != $1.learned { return $0.learned > $1.learned }
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            if $0.word.count != $1.word.count { return $0.word.count < $1.word.count }
            return $0.word < $1.word
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

    /// Best-first walk ordered by `bestRank`: yields the `count` most
    /// frequent list words below `node`, most frequent first.
    private func mostFrequent(
        from node: Node, prefix: String, count: Int
    ) -> [(word: String, rank: Int)] {
        enum Entry {
            case subtree(Node, String)
            case word(String, Int)
        }
        func priority(_ entry: Entry) -> Int {
            switch entry {
            case .subtree(let node, _): return node.bestRank
            case .word(_, let rank): return rank
            }
        }

        var found: [(word: String, rank: Int)] = []
        var frontier: [Entry] = [.subtree(node, prefix)]
        // The frontier holds a handful of entries per visited level, so a
        // linear minimum scan is cheaper than maintaining a heap.
        while found.count < count,
              let next = frontier.indices.min(by: { priority(frontier[$0]) < priority(frontier[$1]) }),
              priority(frontier[next]) != Int.max {
            switch frontier.remove(at: next) {
            case .word(let word, let rank):
                found.append((word, rank))
            case .subtree(let node, let word):
                if let rank = node.rank {
                    frontier.append(.word(word, rank))
                }
                for (character, child) in node.children where child.bestRank != Int.max {
                    frontier.append(.subtree(child, word + String(character)))
                }
            }
        }
        return found
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

    private func node(for word: String) -> Node? {
        var current = root
        for character in word {
            guard let child = current.children[character] else { return nil }
            current = child
        }
        return current
    }
}
