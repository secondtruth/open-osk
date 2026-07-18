import Testing

@testable import OpenOSKCore

@Suite struct CharacterVariantsTests {
    @Test func lowercaseVariants() {
        let variants = CharacterVariants.variants(for: "a", shifted: false)
        #expect(variants.contains("à"))
        #expect(variants.contains("á"))
    }

    @Test func shiftedVariantsAreUppercased() {
        let variants = CharacterVariants.variants(for: "a", shifted: true)
        #expect(variants.contains("À"))
        #expect(!variants.contains("à"))
    }

    @Test func euroOnE() {
        #expect(CharacterVariants.variants(for: "e", shifted: false).contains("€"))
    }

    @Test func punctuationVariants() {
        #expect(CharacterVariants.variants(for: "-", shifted: false).contains("–"))
        #expect(CharacterVariants.variants(for: ".", shifted: false).contains("…"))
    }

    @Test func noVariantsForPlainKeys() {
        #expect(CharacterVariants.variants(for: "q", shifted: false).isEmpty)
        #expect(CharacterVariants.variants(for: "5", shifted: false).isEmpty)
    }
}
