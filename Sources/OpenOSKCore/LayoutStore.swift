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
        return decodeLayouts(from: urls)
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
        return decodeLayouts(from: urls)
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

    private static func decodeLayouts(from urls: [URL]) -> [KeyboardLayout] {
        urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(KeyboardLayout.self, from: data)
        }
    }
}
