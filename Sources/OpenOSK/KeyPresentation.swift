#if canImport(AppKit)
import Foundation
import OpenOSKCore

/// How keys are named to assistive technology (VoiceOver, Voice Control) and
/// which SF Symbol stands in for glyphs the system font renders as emoji.
extension SpecialKey {
    var spokenName: String {
        switch self {
        case .escape: return L("Escape")
        case .tab: return L("Tab")
        case .delete: return L("Delete")
        case .forwardDelete: return L("Forward Delete")
        case .return: return L("Return")
        case .space: return L("Space")
        case .left: return L("Left Arrow")
        case .right: return L("Right Arrow")
        case .up: return L("Up Arrow")
        case .down: return L("Down Arrow")
        case .home: return L("Home")
        case .end: return L("End")
        case .pageUp: return L("Page Up")
        case .pageDown: return L("Page Down")
        }
    }
}

extension Modifier {
    var spokenName: String {
        switch self {
        case .shift: return L("Shift")
        case .control: return L("Control")
        case .option: return L("Option")
        case .command: return L("Command")
        }
    }
}

extension MediaKey {
    var spokenName: String {
        switch self {
        case .volumeUp: return L("Volume Up")
        case .volumeDown: return L("Volume Down")
        case .mute: return L("Mute")
        case .brightnessUp: return L("Brightness Up")
        case .brightnessDown: return L("Brightness Down")
        case .playPause: return L("Play/Pause")
        case .next: return L("Next Track")
        case .previous: return L("Previous Track")
        }
    }

    var symbolName: String {
        switch self {
        case .volumeUp: return "speaker.wave.3.fill"
        case .volumeDown: return "speaker.wave.1.fill"
        case .mute: return "speaker.slash.fill"
        case .brightnessUp: return "sun.max.fill"
        case .brightnessDown: return "sun.min.fill"
        case .playPause: return "playpause.fill"
        case .next: return "forward.fill"
        case .previous: return "backward.fill"
        }
    }
}
#endif
