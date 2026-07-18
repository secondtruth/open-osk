import AppKit
import OpenOSKCore

/// The "Texter" companion: a small compose window for UI elements that do not
/// play well with direct on-screen keyboard input (e.g. terminal views inside
/// editors). Text is composed here and then injected into the previously
/// active application, either by typing or via clipboard paste.
final class TexterController: NSObject, NSWindowDelegate {
    private let injector: KeyInjector
    private let resolver: KeycodeResolver
    private let preferences = Preferences.shared

    private var window: NSWindow?
    private var textView: NSTextView!
    private var pasteCheckbox: NSButton!
    private var returnCheckbox: NSButton!
    private var targetApp: NSRunningApplication?

    init(injector: KeyInjector, resolver: KeycodeResolver) {
        self.injector = injector
        self.resolver = resolver
        super.init()
    }

    func show() {
        captureTargetApp()
        if window == nil {
            buildWindow()
        }
        updateTitle()
        pasteCheckbox.state = preferences.texterPasteMode ? .on : .off
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(textView)
    }

    private func captureTargetApp() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            targetApp = frontmost
        }
    }

    private func updateTitle() {
        let name = targetApp?.localizedName ?? "?"
        window?.title = "Texter → \(name)"
    }

    // MARK: - Window construction

    private func buildWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 240),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        window.minSize = NSSize(width: 360, height: 180)

        let content = NSView()
        window.contentView = content

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView()
        textView.font = .systemFont(ofSize: 14)
        textView.isRichText = false
        textView.allowsUndo = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView
        self.textView = textView

        pasteCheckbox = NSButton(
            checkboxWithTitle: "Insert via clipboard (⌘V)",
            target: self,
            action: #selector(pasteModeToggled)
        )
        returnCheckbox = NSButton(
            checkboxWithTitle: "Press Return after",
            target: nil,
            action: nil
        )

        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearText))
        let insertButton = NSButton(title: "Insert", target: self, action: #selector(insertText))
        insertButton.keyEquivalent = "\r"
        insertButton.keyEquivalentModifierMask = [.command]
        insertButton.bezelStyle = .rounded

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let bottomBar = NSStackView(views: [
            pasteCheckbox, returnCheckbox, spacer, clearButton, insertButton,
        ])
        bottomBar.orientation = .horizontal
        bottomBar.spacing = 10
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(scrollView)
        content.addSubview(bottomBar)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -10),
            bottomBar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            bottomBar.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            bottomBar.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
        ])

        self.window = window
    }

    // MARK: - Actions

    @objc private func pasteModeToggled() {
        preferences.texterPasteMode = pasteCheckbox.state == .on
    }

    @objc private func clearText() {
        textView.string = ""
    }

    @objc private func insertText() {
        let text = textView.string
        guard !text.isEmpty, let targetApp else { return }
        let pressReturn = returnCheckbox.state == .on
        let usePaste = pasteCheckbox.state == .on

        targetApp.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            if usePaste {
                self.pasteInto(text: text, pressReturn: pressReturn)
            } else {
                let injector = self.injector
                let resolver = self.resolver
                DispatchQueue.global(qos: .userInitiated).async {
                    injector.typeText(text)
                    if pressReturn {
                        injector.pressKey(SpecialKey.return.keyCode)
                    }
                    _ = resolver
                }
            }
            self.textView.string = ""
        }
    }

    private func pasteInto(text: String, pressReturn: Bool) {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard let resolution = resolver.resolve("v") else { return }
        injector.pressKey(resolution.keyCode, flags: .maskCommand)
        if pressReturn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [injector] in
                injector.pressKey(SpecialKey.return.keyCode)
            }
        }

        // Restore the previous clipboard content once the paste went through.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            pasteboard.clearContents()
            if let previous {
                pasteboard.setString(previous, forType: .string)
            }
        }
    }
}
