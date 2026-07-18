import Foundation

/// User preferences, backed by `UserDefaults`.
public final class Preferences {
    public static let shared = Preferences()
    public static let didChangeNotification = Notification.Name("OpenOSKPreferencesDidChange")

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.layoutID: "qwertz-de",
            Keys.scale: 1.0,
            Keys.opacity: 0.97,
            Keys.predictionsEnabled: true,
            Keys.learningEnabled: true,
            Keys.terminalCompletionsEnabled: true,
            Keys.texterPasteMode: true,
            Keys.wordlistLanguages: ["de", "en"],
        ])
    }

    private enum Keys {
        static let layoutID = "layoutID"
        static let scale = "keyboardScale"
        static let opacity = "keyboardOpacity"
        static let predictionsEnabled = "predictionsEnabled"
        static let learningEnabled = "learningEnabled"
        static let terminalCompletionsEnabled = "terminalCompletionsEnabled"
        static let texterPasteMode = "texterPasteMode"
        static let wordlistLanguages = "wordlistLanguages"
    }

    public var layoutID: String {
        get { defaults.string(forKey: Keys.layoutID) ?? "qwertz-de" }
        set { set(newValue, forKey: Keys.layoutID) }
    }

    /// Key size multiplier (1.0 = standard).
    public var scale: Double {
        get { defaults.double(forKey: Keys.scale) }
        set { set(newValue, forKey: Keys.scale) }
    }

    public var opacity: Double {
        get { defaults.double(forKey: Keys.opacity) }
        set { set(newValue, forKey: Keys.opacity) }
    }

    public var predictionsEnabled: Bool {
        get { defaults.bool(forKey: Keys.predictionsEnabled) }
        set { set(newValue, forKey: Keys.predictionsEnabled) }
    }

    public var learningEnabled: Bool {
        get { defaults.bool(forKey: Keys.learningEnabled) }
        set { set(newValue, forKey: Keys.learningEnabled) }
    }

    public var terminalCompletionsEnabled: Bool {
        get { defaults.bool(forKey: Keys.terminalCompletionsEnabled) }
        set { set(newValue, forKey: Keys.terminalCompletionsEnabled) }
    }

    /// Whether the Texter inserts via clipboard + ⌘V instead of typing.
    public var texterPasteMode: Bool {
        get { defaults.bool(forKey: Keys.texterPasteMode) }
        set { set(newValue, forKey: Keys.texterPasteMode) }
    }

    public var wordlistLanguages: [String] {
        get { defaults.stringArray(forKey: Keys.wordlistLanguages) ?? ["de", "en"] }
        set { set(newValue, forKey: Keys.wordlistLanguages) }
    }

    private func set(_ value: Any, forKey key: String) {
        defaults.set(value, forKey: key)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
