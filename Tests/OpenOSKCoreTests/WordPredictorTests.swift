import Testing

@testable import OpenOSKCore

@Suite struct WordPredictorTests {
    @Test func prefixSuggestionsOrderedByFrequency() {
        let predictor = WordPredictor()
        predictor.load(words: ["hello", "help", "helicopter", "world"])

        #expect(predictor.suggestions(forPrefix: "hel") == ["hello", "help", "helicopter"])
    }

    @Test func learnedWordsRankFirst() {
        let predictor = WordPredictor()
        predictor.load(words: ["hello", "help"])
        predictor.learn("helios")

        #expect(predictor.suggestions(forPrefix: "hel").first == "helios")
    }

    @Test func capitalizationCarriesOver() {
        let predictor = WordPredictor()
        predictor.load(words: ["hello"])

        #expect(predictor.suggestions(forPrefix: "Hel") == ["Hello"])
        #expect(predictor.suggestions(forPrefix: "HEL") == ["HELLO"])
        #expect(predictor.suggestions(forPrefix: "hel") == ["hello"])
    }

    @Test func umlautsAreSupported() {
        let predictor = WordPredictor()
        predictor.load(words: ["möglich", "möchte"])

        #expect(Set(predictor.suggestions(forPrefix: "mö")) == ["möglich", "möchte"])
    }

    @Test func noSuggestionsForUnknownPrefix() {
        let predictor = WordPredictor()
        predictor.load(words: ["hello"])

        #expect(predictor.suggestions(forPrefix: "xyz").isEmpty)
    }

    @Test func bundledWordlistsLoad() {
        let predictor = WordPredictor()
        predictor.loadBundledWordlists(languages: ["de", "en"])

        #expect(!predictor.suggestions(forPrefix: "th").isEmpty)
        #expect(!predictor.suggestions(forPrefix: "un").isEmpty)
    }

    /// A one-letter prefix spans far more trie nodes than any search budget;
    /// the most frequent words must still win, on every run.
    @Test func frequentWordsWinInLargeSubtrees() {
        let predictor = WordPredictor()
        var words = ["sehr", "sie", "sind"]
        for index in 0..<3000 {
            words.append("s" + String(index, radix: 36) + "zzzzzzzz")
        }
        predictor.load(words: words)

        #expect(predictor.suggestions(forPrefix: "s", limit: 3) == ["sehr", "sie", "sind"])
    }

    @Test func clearLearnedForgetsLearnedWords() {
        let predictor = WordPredictor()
        predictor.load(words: ["hello", "help"])
        predictor.learn("helios", count: 4)
        predictor.learn("help", count: 2)
        predictor.clearLearned()

        #expect(predictor.suggestions(forPrefix: "hel") == ["hello", "help"])
    }
}
