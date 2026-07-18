import Foundation
import Testing

@testable import OpenOSKCore

@Suite struct PanelStoreTests {
    @Test func bundledPanelsLoad() {
        let ids = LayoutStore.bundledPanels().map(\.id)
        #expect(ids.contains("git-panel"))
        #expect(ids.contains("editing-panel"))
    }

    @Test func gitPanelHasMacroKeys() throws {
        let panel = try #require(LayoutStore.panel(id: "git-panel"))
        let keys = panel.rows.flatMap { $0 }
        let statusKey = try #require(keys.first { $0.label == "status" })
        guard case .macro(let macro)? = statusKey.kind else {
            Issue.record("Expected macro kind")
            return
        }
        #expect(macro.steps.first?.text == "git status")
        #expect(macro.steps.last?.shortcut == "return")
    }
}

@Suite struct ShellCompleterDiscoveryTests {
    @Test func findsExecutablesInDirectory() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("openosk-bin-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let executable = dir.appendingPathComponent("mytool")
        try Data("#!/bin/sh\n".utf8).write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755], ofItemAtPath: executable.path)

        let plainFile = dir.appendingPathComponent("notes.txt")
        try Data("hi".utf8).write(to: plainFile)

        let names = ShellCompleter.executableNames(inDirectories: [dir.path])
        #expect(names.contains("mytool"))
        #expect(!names.contains("notes.txt"))
    }

    @Test func discoveredCommandsCompleteButRankAfterCurated() {
        let completer = ShellCompleter()
        completer.load(data: ShellCompletionData(commands: [
            ShellCommandSpec(name: "git", flags: ["--help"])
        ]))
        completer.addDiscoveredCommands(names: ["gitk", "gimp"])

        let suggestions = completer.suggestions(forLine: "gi")
        #expect(suggestions.first == "git")
        #expect(suggestions.contains("gitk"))
        #expect(suggestions.contains("gimp"))
    }

    @Test func discoveredCommandsDoNotOverrideCurated() {
        let completer = ShellCompleter()
        completer.load(data: ShellCompletionData(commands: [
            ShellCommandSpec(name: "git", flags: ["--version"])
        ]))
        completer.addDiscoveredCommands(names: ["git"])

        #expect(completer.suggestions(forLine: "git --v") == ["--version"])
    }
}

@Suite struct CompositionTrackerBigramTests {
    @Test func previousWordWhileTyping() {
        let tracker = CompositionTracker()
        tracker.typed("guten mor")
        #expect(tracker.previousWord == "guten")
        #expect(tracker.lastCompletedWord.isEmpty)
    }

    @Test func lastCompletedWordAfterSpace() {
        let tracker = CompositionTracker()
        tracker.typed("guten morgen ")
        #expect(tracker.lastCompletedWord == "morgen")
        #expect(tracker.previousWord.isEmpty)
    }

    @Test func firstWordHasNoPreviousWord() {
        let tracker = CompositionTracker()
        tracker.typed("guten")
        #expect(tracker.previousWord.isEmpty)
    }
}
