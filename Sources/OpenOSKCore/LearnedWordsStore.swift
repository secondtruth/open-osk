import Foundation

/// Persists words learned from the user's typing as a simple JSON dictionary
/// of word → count in Application Support.
public final class LearnedWordsStore {
    private let fileURL: URL
    private var counts: [String: Int] = [:]

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL
            ?? LayoutStore.appSupportDirectory.appendingPathComponent("learned-words.json")
        load()
    }

    public var allWords: [String: Int] { counts }

    public func record(_ word: String) {
        let normalized = word.lowercased()
        guard normalized.count >= 2 else { return }
        counts[normalized, default: 0] += 1
        save()
    }

    public func applyTo(_ predictor: WordPredictor) {
        for (word, count) in counts {
            predictor.learn(word, count: count)
        }
    }

    public func clear() {
        counts = [:]
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        counts = (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
    }

    private func save() {
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(counts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
