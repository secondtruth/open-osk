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
}
