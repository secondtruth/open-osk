import Foundation
import Testing

@testable import OpenOSKCore

@Suite struct AppProfileStoreTests {
    @Test func loadsProfilesFromFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("openosk-profiles-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let json = """
        {
          "com.microsoft.VSCode": { "terminalMode": true },
          "com.apple.Terminal": { "layout": "qwerty-us" }
        }
        """
        try Data(json.utf8).write(to: url)

        let store = AppProfileStore(fileURL: url)
        #expect(store.profile(for: "com.microsoft.VSCode")?.terminalMode == true)
        #expect(store.profile(for: "com.apple.Terminal")?.layout == "qwerty-us")
        #expect(store.profile(for: "com.example.Other") == nil)
        #expect(store.profile(for: nil) == nil)
    }

    @Test func missingFileYieldsEmptyStore() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("openosk-missing-\(UUID().uuidString).json")
        let store = AppProfileStore(fileURL: url)
        #expect(store.profiles.isEmpty)
    }
}
