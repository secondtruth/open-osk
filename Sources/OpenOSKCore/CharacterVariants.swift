import Foundation

/// Alternate characters offered on long-press of a base key, like the iOS
/// keyboard and the Accessibility Keyboard's Option layers.
public enum CharacterVariants {
    private static let table: [Character: [String]] = [
        "a": ["à", "á", "â", "ã", "å", "ā", "æ"],
        "e": ["è", "é", "ê", "ë", "ē", "€"],
        "i": ["ì", "í", "î", "ï", "ī"],
        "o": ["ò", "ó", "ô", "õ", "ō", "ø", "œ"],
        "u": ["ù", "ú", "û", "ū"],
        "y": ["ý", "ÿ"],
        "c": ["ç", "ć", "č"],
        "n": ["ñ", "ń"],
        "s": ["ß", "ś", "š"],
        "z": ["ź", "ž", "ż"],
        "d": ["ð", "đ"],
        "l": ["ł"],
        "t": ["þ"],
        "-": ["–", "—", "·"],
        ".": ["…", "•"],
        ",": ["‚", "„"],
        "'": ["‘", "’", "‹", "›"],
        "\"": ["„", "“", "”", "«", "»"],
        "0": ["°"],
        "$": ["€", "£", "¥", "¢"],
        "+": ["±", "×", "÷"],
        "=": ["≠", "≈", "≤", "≥"],
        "/": ["\\", "÷"],
        "?": ["¿"],
        "!": ["¡"],
    ]

    /// Variants for a key's base output; uppercased when Shift is active.
    /// Returns an empty array if the key has no variants.
    public static func variants(for base: String, shifted: Bool) -> [String] {
        guard let first = base.lowercased().first, let entries = table[first] else {
            return []
        }
        guard shifted else { return entries }
        return entries.map { variant in
            let upper = variant.uppercased()
            return upper.count == variant.count ? upper : variant
        }
    }
}
