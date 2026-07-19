import Foundation

/// Loads keyboard layouts from the bundled resources and from the user's
/// `~/Library/Application Support/OpenOSK/Layouts` directory.
public enum LayoutStore {
    public static var userLayoutsDirectory: URL {
        appSupportDirectory.appendingPathComponent("Layouts", isDirectory: true)
    }

    public static var appSupportDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OpenOSK", isDirectory: true)
    }

    public static func bundledLayouts() -> [KeyboardLayout] {
        guard let urls = Bundle.module.urls(
            forResourcesWithExtension: "json",
            subdirectory: "Resources/Layouts"
        ) else { return [] }
        // On Linux, this API returns [NSURL]; bridge to [URL] for both platforms.
        return decodeLayouts(from: urls.map { $0 as URL })
    }

    public static func userLayouts() -> [KeyboardLayout] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: userLayoutsDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        return decodeLayouts(from: urls.filter { $0.pathExtension == "json" })
    }

    /// All available layouts; user layouts override bundled ones with the same id.
    public static func allLayouts() -> [KeyboardLayout] {
        var byID: [String: KeyboardLayout] = [:]
        for layout in bundledLayouts() { byID[layout.id] = layout }
        for layout in userLayouts() { byID[layout.id] = layout }
        return byID.values.sorted { $0.name < $1.name }
    }

    public static func layout(id: String) -> KeyboardLayout? {
        allLayouts().first { $0.id == id }
    }

    // MARK: - Custom panels

    /// Panels reuse the layout format: rows of (mostly macro/text) keys.
    public static var userPanelsDirectory: URL {
        appSupportDirectory.appendingPathComponent("Panels", isDirectory: true)
    }

    public static func bundledPanels() -> [KeyboardLayout] {
        guard let urls = Bundle.module.urls(
            forResourcesWithExtension: "json",
            subdirectory: "Resources/Panels"
        ) else { return [] }
        // On Linux, this API returns [NSURL]; bridge to [URL] for both platforms.
        return decodeLayouts(from: urls.map { $0 as URL })
    }

    public static func userPanels() -> [KeyboardLayout] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: userPanelsDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        return decodeLayouts(from: urls.filter { $0.pathExtension == "json" })
    }

    /// All available panels; user panels override bundled ones with the same id.
    public static func allPanels() -> [KeyboardLayout] {
        var byID: [String: KeyboardLayout] = [:]
        for panel in bundledPanels() { byID[panel.id] = panel }
        for panel in userPanels() { byID[panel.id] = panel }
        return byID.values.sorted { $0.name < $1.name }
    }

    public static func panel(id: String) -> KeyboardLayout? {
        allPanels().first { $0.id == id }
    }

    /// Saves a panel into the user panels directory (overriding a bundled
    /// panel with the same id, per the usual precedence).
    public static func writeUserPanel(_ panel: KeyboardLayout) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(panel)
        try FileManager.default.createDirectory(
            at: userPanelsDirectory, withIntermediateDirectories: true)
        let url = userPanelsDirectory.appendingPathComponent("\(panel.id).json")
        try data.write(to: url, options: .atomic)
    }

    /// Removes a user panel file; bundled panels cannot be deleted.
    @discardableResult
    public static func deleteUserPanel(id: String) -> Bool {
        let url = userPanelsDirectory.appendingPathComponent("\(id).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        return (try? FileManager.default.removeItem(at: url)) != nil
    }

    private static func decodeLayouts(from urls: [URL]) -> [KeyboardLayout] {
        urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(KeyboardLayout.self, from: data)
        }
    }
}
