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
            Keys.autoCapitalization: true,
            Keys.autoSpacing: true,
            Keys.showCurrentText: true,
            Keys.dwellEnabled: false,
            Keys.dwellTime: 0.9,
            Keys.inactivityFadeEnabled: true,
            Keys.inactivityFadeDelay: 10.0,
            Keys.autoShowOnTextFocus: false,
            Keys.scanningEnabled: false,
            Keys.scanInterval: 1.2,
            Keys.scanSwitchKey: "space",
            Keys.openPanelIDs: [String](),
            Keys.themeID: "system",
            Keys.keyClickSound: false,
            Keys.systemDictionaryEnabled: false,
            Keys.scanAdvanceKey: "none",
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
        static let autoCapitalization = "autoCapitalization"
        static let autoSpacing = "autoSpacing"
        static let showCurrentText = "showCurrentText"
        static let dwellEnabled = "dwellEnabled"
        static let dwellTime = "dwellTime"
        static let inactivityFadeEnabled = "inactivityFadeEnabled"
        static let inactivityFadeDelay = "inactivityFadeDelay"
        static let autoShowOnTextFocus = "autoShowOnTextFocus"
        static let scanningEnabled = "scanningEnabled"
        static let scanInterval = "scanInterval"
        static let scanSwitchKey = "scanSwitchKey"
        static let openPanelIDs = "openPanelIDs"
        static let themeID = "themeID"
        static let keyClickSound = "keyClickSound"
        static let systemDictionaryEnabled = "systemDictionaryEnabled"
        static let scanAdvanceKey = "scanAdvanceKey"
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

    /// Capitalize the first letter after sentence-ending punctuation.
    public var autoCapitalization: Bool {
        get { defaults.bool(forKey: Keys.autoCapitalization) }
        set { set(newValue, forKey: Keys.autoCapitalization) }
    }

    /// Double-space inserts ". ".
    public var autoSpacing: Bool {
        get { defaults.bool(forKey: Keys.autoSpacing) }
        set { set(newValue, forKey: Keys.autoSpacing) }
    }

    /// Show the current-text bar on the keyboard.
    public var showCurrentText: Bool {
        get { defaults.bool(forKey: Keys.showCurrentText) }
        set { set(newValue, forKey: Keys.showCurrentText) }
    }

    /// Hovering a key presses it after `dwellTime`.
    public var dwellEnabled: Bool {
        get { defaults.bool(forKey: Keys.dwellEnabled) }
        set { set(newValue, forKey: Keys.dwellEnabled) }
    }

    /// Dwell duration in seconds.
    public var dwellTime: Double {
        get { defaults.double(forKey: Keys.dwellTime) }
        set { set(newValue, forKey: Keys.dwellTime) }
    }

    /// Fade the keyboard after a period without interaction.
    public var inactivityFadeEnabled: Bool {
        get { defaults.bool(forKey: Keys.inactivityFadeEnabled) }
        set { set(newValue, forKey: Keys.inactivityFadeEnabled) }
    }

    /// Seconds of inactivity before the keyboard fades.
    public var inactivityFadeDelay: Double {
        get { defaults.double(forKey: Keys.inactivityFadeDelay) }
        set { set(newValue, forKey: Keys.inactivityFadeDelay) }
    }

    /// Show the keyboard automatically when a text field gains focus.
    public var autoShowOnTextFocus: Bool {
        get { defaults.bool(forKey: Keys.autoShowOnTextFocus) }
        set { set(newValue, forKey: Keys.autoShowOnTextFocus) }
    }

    /// Scanning (switch access) input mode.
    public var scanningEnabled: Bool {
        get { defaults.bool(forKey: Keys.scanningEnabled) }
        set { set(newValue, forKey: Keys.scanningEnabled) }
    }

    /// Seconds between scan highlight steps.
    public var scanInterval: Double {
        get { defaults.double(forKey: Keys.scanInterval) }
        set { set(newValue, forKey: Keys.scanInterval) }
    }

    /// Hardware key acting as the scan switch: "space", "return", "f13"–"f15".
    public var scanSwitchKey: String {
        get { defaults.string(forKey: Keys.scanSwitchKey) ?? "space" }
        set { set(newValue, forKey: Keys.scanSwitchKey) }
    }

    /// Custom panels that are currently open (restored on launch).
    public var openPanelIDs: [String] {
        get { defaults.stringArray(forKey: Keys.openPanelIDs) ?? [] }
        set { set(newValue, forKey: Keys.openPanelIDs) }
    }

    /// Visual theme id ("system", "high-contrast", "dark", "light").
    public var themeID: String {
        get { defaults.string(forKey: Keys.themeID) ?? "system" }
        set { set(newValue, forKey: Keys.themeID) }
    }

    /// Play a click sound on key press.
    public var keyClickSound: Bool {
        get { defaults.bool(forKey: Keys.keyClickSound) }
        set { set(newValue, forKey: Keys.keyClickSound) }
    }

    /// Merge /usr/share/dict/words as low-priority prediction fallback.
    public var systemDictionaryEnabled: Bool {
        get { defaults.bool(forKey: Keys.systemDictionaryEnabled) }
        set { set(newValue, forKey: Keys.systemDictionaryEnabled) }
    }

    /// Optional second switch that advances the scan manually ("none"
    /// disables it; otherwise same key names as `scanSwitchKey`). With an
    /// advance key set, the automatic scan timer is disabled.
    public var scanAdvanceKey: String {
        get { defaults.string(forKey: Keys.scanAdvanceKey) ?? "none" }
        set { set(newValue, forKey: Keys.scanAdvanceKey) }
    }

    private func set(_ value: Any, forKey key: String) {
        defaults.set(value, forKey: key)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
