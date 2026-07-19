import Foundation

/// Per-application overrides, keyed by bundle identifier. Stored as JSON in
/// `~/Library/Application Support/OpenOSK/app-profiles.json`, e.g.:
///
///     {
///       "com.microsoft.VSCode": { "terminalMode": true },
///       "com.apple.Terminal": { "layout": "qwerty-us" }
///     }
public struct AppProfile: Codable, Equatable, Sendable {
    /// Layout id to activate while this app is frontmost.
    public var layout: String?
    /// Forces terminal-mode completions on or off, overriding detection.
    public var terminalMode: Bool?

    public init(layout: String? = nil, terminalMode: Bool? = nil) {
        self.layout = layout
        self.terminalMode = terminalMode
    }
}

public final class AppProfileStore {
    private let fileURL: URL
    private(set) public var profiles: [String: AppProfile] = [:]

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL
            ?? LayoutStore.appSupportDirectory.appendingPathComponent("app-profiles.json")
        reload()
    }

    public func profile(for bundleID: String?) -> AppProfile? {
        guard let bundleID else { return nil }
        return profiles[bundleID]
    }

    public func reload() {
        guard let data = try? Data(contentsOf: fileURL) else {
            profiles = [:]
            return
        }
        profiles = (try? JSONDecoder().decode([String: AppProfile].self, from: data)) ?? [:]
    }

    /// Persists the given profiles and adopts them as the current state.
    public func write(profiles: [String: AppProfile]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(profiles)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        self.profiles = profiles
    }
}
