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

    /// Command prefixes that are transparent for completion purposes.
    private static let passthroughCommands: Set<String> = ["sudo", "env", "time", "nohup", "xargs"]

    public init() {}

    public func load(data: ShellCompletionData) {
        var byName: [String: ShellCommandSpec] = [:]
        for command in commands { byName[command.name] = command }
        for command in data.commands { byName[command.name] = command }
        commands = byName.values.sorted { $0.name < $1.name }
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
            return match(commands.map(\.name), prefix: current, limit: limit)
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
