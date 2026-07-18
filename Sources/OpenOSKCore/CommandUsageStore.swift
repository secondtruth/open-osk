import Foundation

/// Persists how often shell commands were submitted, so frequently used
/// commands rank first in terminal completion.
public final class CommandUsageStore {
    private let fileURL: URL
    private(set) public var counts: [String: Int] = [:]

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL
            ?? LayoutStore.appSupportDirectory.appendingPathComponent("command-usage.json")
        load()
    }

    public func record(command: String) {
        let name = command.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !name.hasPrefix("-") else { return }
        counts[name, default: 0] += 1
        save()
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
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(counts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
