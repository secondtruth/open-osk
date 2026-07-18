import Foundation

/// Localized string lookup; the key doubles as the English fallback.
func L(_ key: String) -> String {
    Bundle.module.localizedString(forKey: key, value: key, table: nil)
}
