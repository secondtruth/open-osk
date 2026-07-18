import Foundation
import Testing

@testable import OpenOSKCore

@Suite struct PathCompletionTests {
    @Test func completesAbsolutePaths() {
        let suggestions = ShellCompleter.pathSuggestions(forToken: "/us")
        #expect(suggestions.contains("/usr/"))
    }

    @Test func directoriesGetTrailingSlash() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("openosk-path-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent("subdir"), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: dir.appendingPathComponent("file.txt"))
        defer { try? FileManager.default.removeItem(at: dir) }

        let suggestions = ShellCompleter.pathSuggestions(forToken: dir.path + "/")
        #expect(suggestions.contains(dir.path + "/subdir/"))
        #expect(suggestions.contains(dir.path + "/file.txt"))
    }

    @Test func tildeAloneCompletesToHome() {
        #expect(ShellCompleter.pathSuggestions(forToken: "~") == ["~/"])
    }

    @Test func relativePathsAreNotCompleted() {
        #expect(ShellCompleter.pathSuggestions(forToken: "src/ma").isEmpty)
    }

    @Test func pathTokensWinInsideCommandLines() {
        let completer = ShellCompleter()
        completer.load(data: ShellCompletionData(commands: [
            ShellCommandSpec(name: "cat")
        ]))
        #expect(completer.suggestions(forLine: "cat /us").contains("/usr/"))
    }
}

@Suite struct UsageRankingTests {
    @Test func frequentlyUsedCommandsRankFirst() {
        let completer = ShellCompleter()
        completer.load(data: ShellCompletionData(commands: [
            ShellCommandSpec(name: "git", flags: ["--help"]),
            ShellCommandSpec(name: "gimp"),
        ]))
        completer.usageCounts = ["gimp": 10]

        #expect(completer.suggestions(forLine: "gi").first == "gimp")
    }

    @Test func usageStorePersists() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("openosk-usage-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = CommandUsageStore(fileURL: url)
        store.record(command: "git")
        store.record(command: "git")
        store.record(command: "-v")

        let reloaded = CommandUsageStore(fileURL: url)
        #expect(reloaded.counts["git"] == 2)
        #expect(reloaded.counts["-v"] == nil)
    }
}

@Suite struct FallbackDictionaryTests {
    @Test func fallbackFillsUpSuggestions() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("openosk-dict-\(UUID().uuidString).txt")
        try "zebra\nzephyr\nzelot\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let predictor = WordPredictor()
        predictor.load(words: ["zeit"])
        predictor.loadFallbackDictionary(atPath: url.path)

        let suggestions = predictor.suggestions(forPrefix: "ze")
        #expect(suggestions.first == "zeit")
        #expect(suggestions.contains("zebra"))
    }

    @Test func clearRemovesFallback() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("openosk-dict-\(UUID().uuidString).txt")
        try "zebra\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let predictor = WordPredictor()
        predictor.loadFallbackDictionary(atPath: url.path)
        predictor.clearFallbackDictionary()
        #expect(predictor.suggestions(forPrefix: "ze").isEmpty)
    }
}

@Suite struct MediaKeyTests {
    @Test func mediaKeyDecodesFromLayoutJSON() throws {
        let json = #"{ "media": "volumeUp" }"#
        let key = try JSONDecoder().decode(Key.self, from: Data(json.utf8))
        guard case .media(let media)? = key.kind else {
            Issue.record("Expected media kind")
            return
        }
        #expect(media == .volumeUp)
        #expect(media.autorepeats)
    }

    @Test func systemPanelLoads() throws {
        let panel = try #require(LayoutStore.panel(id: "system-panel"))
        let keys = panel.rows.flatMap { $0 }
        #expect(keys.contains { $0.media == .playPause })
    }

    @Test func macroStepsSupportPanelAndSay() throws {
        let json = #"{ "steps": [ { "panel": "git-panel" }, { "say": "done" } ] }"#
        let macro = try JSONDecoder().decode(Macro.self, from: Data(json.utf8))
        #expect(macro.steps[0].panel == "git-panel")
        #expect(macro.steps[1].say == "done")
        #expect(!macro.isPlainText)
    }
}
