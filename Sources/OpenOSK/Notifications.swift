import Foundation

extension Notification.Name {
    /// Posted by the profile editor after app-profiles.json was saved.
    static let openOSKProfilesChanged = Notification.Name("OpenOSKProfilesChanged")
    /// Posted by the panel editor after a panel was saved or deleted.
    static let openOSKPanelsChanged = Notification.Name("OpenOSKPanelsChanged")
}
