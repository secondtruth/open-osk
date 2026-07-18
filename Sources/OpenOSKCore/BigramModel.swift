import Foundation

/// Next-word prediction from learned word pairs (bigrams). Purely usage-based:
/// the model starts empty and learns from what the user types through OpenOSK.
public final class BigramModel {
    private var counts: [String: [String: Int]] = [:]
    private let fileURL: URL?

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL
        load()
    }

    /// Convenience initializer using the default persistence location.
    public static func standard() -> BigramModel {
        BigramModel(
            fileURL: LayoutStore.appSupportDirectory.appendingPathComponent("bigrams.json"))
    }

    public func learn(previous: String, next: String) {
        let prev = previous.lowercased()
        let word = next.lowercased()
        guard prev.count >= 2, word.count >= 2 else { return }
        counts[prev, default: [:]][word, default: 0] += 1
        save()
    }

    /// Most likely next words after `word`, most frequent first.
    public func suggestions(after word: String, limit: Int = 3) -> [String] {
        guard let followers = counts[word.lowercased()] else { return [] }
        return followers
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                return $0.key < $1.key
            }
            .prefix(limit)
            .map(\.key)
    }

    public func clear() {
        counts = [:]
        save()
    }

    private func load() {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        counts = (try? JSONDecoder().decode([String: [String: Int]].self, from: data)) ?? [:]
    }

    private func save() {
        guard let fileURL else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(counts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
