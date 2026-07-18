import Foundation
import Testing

@testable import OpenOSKCore

@Suite struct BigramModelTests {
    @Test func suggestsByFrequency() {
        let model = BigramModel()
        model.learn(previous: "guten", next: "morgen")
        model.learn(previous: "guten", next: "morgen")
        model.learn(previous: "guten", next: "abend")

        #expect(model.suggestions(after: "guten") == ["morgen", "abend"])
    }

    @Test func matchingIsCaseInsensitive() {
        let model = BigramModel()
        model.learn(previous: "Guten", next: "Morgen")

        #expect(model.suggestions(after: "guten") == ["morgen"])
        #expect(model.suggestions(after: "GUTEN") == ["morgen"])
    }

    @Test func ignoresShortWords() {
        let model = BigramModel()
        model.learn(previous: "a", next: "morgen")
        model.learn(previous: "guten", next: "b")

        #expect(model.suggestions(after: "a").isEmpty)
        #expect(model.suggestions(after: "guten").isEmpty)
    }

    @Test func unknownWordYieldsNothing() {
        let model = BigramModel()
        #expect(model.suggestions(after: "unbekannt").isEmpty)
    }

    @Test func persistsAcrossInstances() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("openosk-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let model = BigramModel(fileURL: url)
        model.learn(previous: "hello", next: "world")

        let reloaded = BigramModel(fileURL: url)
        #expect(reloaded.suggestions(after: "hello") == ["world"])
    }
}
