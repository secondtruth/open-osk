import Foundation

/// Specification of a shell command, its flags and subcommands.
public struct ShellCommandSpec: Codable, Equatable, Sendable {
    public var name: String
    public var flags: [String]?
    public var subcommands: [ShellCommandSpec]?

    public init(name: String, flags: [String]? = nil, subcommands: [ShellCommandSpec]? = nil) {
        self.name = name
        self.flags = flags
        self.subcommands = subcommands
    }
}

public struct ShellCompletionData: Codable, Sendable {
    public var commands: [ShellCommandSpec]

    public init(commands: [ShellCommandSpec]) {
        self.commands = commands
    }
}

/// Completes commands, subcommands and flags for terminal input, based on a
/// bundled database plus optional user additions from
/// `~/Library/Application Support/OpenOSK/shell-completions.json`.
public final class ShellCompleter {
    private var commands: [ShellCommandSpec] = []
    /// Names loaded from curated completion data (as opposed to $PATH
    /// discovery); curated commands rank first in suggestions.
    private var curatedNames: Set<String> = []

    /// Command prefixes that are transparent for completion purposes.
    private static let passthroughCommands: Set<String> = ["sudo", "env", "time", "nohup", "xargs"]

    public init() {}

    public func load(data: ShellCompletionData) {
        var byName: [String: ShellCommandSpec] = [:]
        for command in commands { byName[command.name] = command }
        for command in data.commands {
            byName[command.name] = command
            curatedNames.insert(command.name)
        }
        commands = byName.values.sorted { $0.name < $1.name }
    }

    // MARK: - $PATH discovery

    /// Executable names found in the given directories (used for bare command
    /// completion without flag knowledge).
    public static func executableNames(inDirectories directories: [String]) -> [String] {
        let fileManager = FileManager.default
        var names: Set<String> = []
        for directory in directories {
            guard let entries = try? fileManager.contentsOfDirectory(atPath: directory) else {
                continue
            }
            for entry in entries where !entry.hasPrefix(".") {
                if fileManager.isExecutableFile(atPath: directory + "/" + entry) {
                    names.insert(entry)
                }
            }
        }
        return names.sorted()
    }

    /// The user's $PATH plus common locations that may be missing from the
    /// app's own environment (e.g. Homebrew when launched from Finder).
    public static var defaultSearchDirectories: [String] {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        var directories = path.split(separator: ":").map(String.init)
        directories += ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        var seen: Set<String> = []
        return directories.filter { seen.insert($0).inserted }
    }

    /// Adds bare commands (no flags/subcommands) for the given names without
    /// overriding curated entries.
    public func addDiscoveredCommands(names: [String]) {
        let existing = Set(commands.map(\.name))
        let additions = names
            .filter { !existing.contains($0) }
            .map { ShellCommandSpec(name: $0) }
        guard !additions.isEmpty else { return }
        commands = (commands + additions).sorted { $0.name < $1.name }
    }

    public func loadBundled() {
        guard
            let url = Bundle.module.url(
                forResource: "completions",
                withExtension: "json",
                subdirectory: "Resources/Shell"
            ),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(ShellCompletionData.self, from: data)
        else { return }
        load(data: decoded)
    }

    public func loadUserCompletions() {
        let url = LayoutStore.appSupportDirectory.appendingPathComponent("shell-completions.json")
        guard
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(ShellCompletionData.self, from: data)
        else { return }
        load(data: decoded)
    }

    /// Completion candidates for the current command line. Candidates are
    /// full tokens; the caller is responsible for computing the remainder
    /// relative to what has already been typed.
    public func suggestions(forLine line: String, limit: Int = 5) -> [String] {
        var tokens = line.components(separatedBy: " ")
        let current = tokens.popLast() ?? ""
        var previous = tokens.filter { !$0.isEmpty }
        while let first = previous.first, Self.passthroughCommands.contains(first) {
            previous.removeFirst()
        }

        if previous.isEmpty {
            // Rank curated commands (with flag knowledge) before discovered
            // ones, then shorter and alphabetically earlier names first.
            let candidates = commands.map(\.name)
                .filter { $0.hasPrefix(current) && $0 != current }
                .sorted { lhs, rhs in
                    let lhsCurated = curatedNames.contains(lhs)
                    let rhsCurated = curatedNames.contains(rhs)
                    if lhsCurated != rhsCurated { return lhsCurated }
                    if lhs.count != rhs.count { return lhs.count < rhs.count }
                    return lhs < rhs
                }
            return Array(candidates.prefix(limit))
        }

        guard var spec = commands.first(where: { $0.name == previous[0] }) else {
            return []
        }
        for token in previous.dropFirst() {
            guard let sub = spec.subcommands?.first(where: { $0.name == token }) else { continue }
            spec = sub
        }

        if current.hasPrefix("-") {
            return match(spec.flags ?? [], prefix: current, limit: limit)
        }
        if let subcommands = spec.subcommands {
            return match(subcommands.map(\.name), prefix: current, limit: limit)
        }
        return []
    }

    private func match(_ candidates: [String], prefix: String, limit: Int) -> [String] {
        candidates
            .filter { $0.hasPrefix(prefix) && $0 != prefix }
            .prefix(limit)
            .map { $0 }
    }
}
