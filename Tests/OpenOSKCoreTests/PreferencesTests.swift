import Foundation
import Testing

@testable import OpenOSKCore

@Suite struct PreferencesTests {
    private func makePreferences() -> Preferences {
        let suite = "OpenOSKTests-\(UUID().uuidString)"
        return Preferences(defaults: UserDefaults(suiteName: suite)!)
    }

    @Test func changeNotificationNamesTheChangedKey() {
        let preferences = makePreferences()
        var received: [Preferences.Key] = []
        let observer = NotificationCenter.default.addObserver(
            forName: Preferences.didChangeNotification, object: preferences, queue: nil
        ) { notification in
            if let key = Preferences.changedKey(in: notification) {
                received.append(key)
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        preferences.opacity = 0.5
        preferences.themeID = "dark"

        #expect(received == [.opacity, .themeID])
    }

    @Test func unchangedValuesDoNotNotify() {
        let preferences = makePreferences()
        preferences.scale = 1.2
        var count = 0
        let observer = NotificationCenter.default.addObserver(
            forName: Preferences.didChangeNotification, object: preferences, queue: nil
        ) { _ in count += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }

        preferences.scale = 1.2

        #expect(count == 0)
    }

    @Test func panelOriginRoundTrips() {
        let preferences = makePreferences()
        #expect(preferences.panelOrigin(forID: "keyboard") == nil)

        preferences.setPanelOrigin(x: 12.5, y: 80, forID: "keyboard")

        let origin = preferences.panelOrigin(forID: "keyboard")
        #expect(origin?.x == 12.5)
        #expect(origin?.y == 80)
    }
}
