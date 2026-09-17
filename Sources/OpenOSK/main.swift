#if canImport(AppKit)
import AppKit
#endif
import Foundation

let appVersion = "0.6.0"

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
          --snapshot DIR  Render the keyboard in every theme to PNGs in DIR

        OpenOSK runs as a menu bar application. It needs Accessibility access
        (System Settings → Privacy & Security → Accessibility) to send
        keystrokes to other applications.
        """
    )
    exit(0)
}

#if canImport(AppKit)
if let flag = arguments.firstIndex(of: "--snapshot") {
    guard arguments.indices.contains(flag + 1) else {
        FileHandle.standardError.write(Data("openosk: --snapshot needs a directory\n".utf8))
        exit(2)
    }
    do {
        try Snapshot.write(to: URL(fileURLWithPath: arguments[flag + 1]))
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("openosk: \(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
#else
// The UI is AppKit-only; this stub exists so the whole package (and its
// test target) builds on Linux, where only OpenOSKCore is functional.
print("OpenOSK \(appVersion): the UI requires macOS; only OpenOSKCore is available on this platform.")
exit(1)
#endif
