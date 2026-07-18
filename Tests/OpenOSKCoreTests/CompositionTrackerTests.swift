import Testing

@testable import OpenOSKCore

@Suite struct CompositionTrackerTests {
    @Test func typedAccumulatesLine() {
        let tracker = CompositionTracker()
        tracker.typed("git sta")
        #expect(tracker.line == "git sta")
        #expect(tracker.currentToken == "sta")
        #expect(tracker.currentWord == "sta")
    }

    @Test func backspaceRemovesLastCharacter() {
        let tracker = CompositionTracker()
        tracker.typed("abc")
        tracker.backspaced()
        #expect(tracker.line == "ab")
        tracker.backspaced()
        tracker.backspaced()
        tracker.backspaced()
        #expect(tracker.line.isEmpty)
    }

    @Test func newlineResetsLine() {
        let tracker = CompositionTracker()
        tracker.typed("hello\nwor")
        #expect(tracker.line == "wor")
    }

    @Test func submittedLineReturnsAndClears() {
        let tracker = CompositionTracker()
        tracker.typed("ls -la")
        #expect(tracker.submittedLine() == "ls -la")
        #expect(tracker.line.isEmpty)
    }

    @Test func currentWordStopsAtPunctuation() {
        let tracker = CompositionTracker()
        tracker.typed("Hallo, Wel")
        #expect(tracker.currentWord == "Wel")
        tracker.typed("t!")
        #expect(tracker.currentWord.isEmpty)
    }

    @Test func currentWordSupportsUmlauts() {
        let tracker = CompositionTracker()
        tracker.typed("das ist mögl")
        #expect(tracker.currentWord == "mögl")
    }

    @Test func currentTokenIncludesFlagsAndPaths() {
        let tracker = CompositionTracker()
        tracker.typed("git commit --am")
        #expect(tracker.currentToken == "--am")
        #expect(tracker.currentWord == "am")
    }
}
