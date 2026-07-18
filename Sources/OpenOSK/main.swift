import AppKit
import Foundation

let appVersion = "0.4.0"

let arguments = CommandLine.arguments
if arguments.contains("--version") {
    print("OpenOSK \(appVersion)")
    exit(0)
}
if arguments.contains("--help") {
    print(
        """
        OpenOSK \(appVersion) — Open On-Screen Keyboard for macOS

        Usage: openosk [options]

        Options:
          --version     Print version and exit
          --help        Show this help and exit
          --smoke-test  Start the UI, verify it initializes, then exit

        OpenOSK runs as a menu bar application. It needs Accessibility access
        (System Settings → Privacy & Security → Accessibility) to send
        keystrokes to other applications.
        """
    )
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
