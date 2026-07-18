import Testing

@testable import OpenOSKCore

@Suite struct TypingAidsTests {
    @Test func capitalizesAfterSentenceEnd() {
        #expect(TypingAids.shouldAutoCapitalize(afterLine: "Hallo Welt. "))
        #expect(TypingAids.shouldAutoCapitalize(afterLine: "Wirklich! "))
        #expect(TypingAids.shouldAutoCapitalize(afterLine: "Echt? "))
        #expect(TypingAids.shouldAutoCapitalize(afterLine: "Ende.  "))
    }

    @Test func doesNotCapitalizeMidSentence() {
        #expect(!TypingAids.shouldAutoCapitalize(afterLine: "Hallo Welt "))
        #expect(!TypingAids.shouldAutoCapitalize(afterLine: "Hallo,"))
        #expect(!TypingAids.shouldAutoCapitalize(afterLine: "3.14 "))
    }

    @Test func emptyLineIsNotASentenceStart() {
        #expect(!TypingAids.shouldAutoCapitalize(afterLine: ""))
        #expect(!TypingAids.shouldAutoCapitalize(afterLine: " "))
    }

    @Test func doubleSpaceInsertsPeriodAfterWord() {
        #expect(TypingAids.shouldInsertPeriodOnDoubleSpace(line: "Hallo Welt "))
        #expect(TypingAids.shouldInsertPeriodOnDoubleSpace(line: "42 "))
    }

    @Test func doubleSpaceNotAfterPunctuationOrRepeatedSpace() {
        #expect(!TypingAids.shouldInsertPeriodOnDoubleSpace(line: "Hallo. "))
        #expect(!TypingAids.shouldInsertPeriodOnDoubleSpace(line: "Hallo  "))
        #expect(!TypingAids.shouldInsertPeriodOnDoubleSpace(line: "Hallo"))
        #expect(!TypingAids.shouldInsertPeriodOnDoubleSpace(line: ""))
    }
}
