import AppKit
import OpenOSKCore

final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private unowned let appDelegate: AppDelegate

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "keyboard.fill",
                accessibilityDescription: "OpenOSK"
            )
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let keyboardVisible = appDelegate.keyboardController.isPanelVisible
        menu.addItem(makeItem(
            title: keyboardVisible ? "Hide Keyboard" : "Show Keyboard",
            action: #selector(toggleKeyboard)
        ))
        menu.addItem(makeItem(title: "Open Texter", action: #selector(openTexter)))

        let layoutMenu = NSMenu()
        let currentLayoutID = Preferences.shared.layoutID
        for layout in LayoutStore.allLayouts() {
            let item = NSMenuItem(
                title: layout.name,
                action: #selector(selectLayout(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = layout.id
            item.state = layout.id == currentLayoutID ? .on : .off
            layoutMenu.addItem(item)
        }
        let layoutItem = NSMenuItem(title: "Layout", action: nil, keyEquivalent: "")
        layoutItem.submenu = layoutMenu
        menu.addItem(layoutItem)

        menu.addItem(makeItem(title: "Settings…", action: #selector(openSettings)))
        menu.addItem(.separator())

        if !KeyInjector.isTrusted() {
            menu.addItem(makeItem(
                title: "⚠️ Grant Accessibility Access…",
                action: #selector(openAccessibilitySettings)
            ))
            menu.addItem(.separator())
        }

        menu.addItem(makeItem(title: "About OpenOSK", action: #selector(showAbout)))
        menu.addItem(makeItem(title: "Quit OpenOSK", action: #selector(quit)))
    }

    private func makeItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    // MARK: - Actions

    @objc private func toggleKeyboard() {
        appDelegate.keyboardController.togglePanel()
    }

    @objc private func openTexter() {
        appDelegate.texterController.show()
    }

    @objc private func selectLayout(_ sender: NSMenuItem) {
        guard let layoutID = sender.representedObject as? String else { return }
        Preferences.shared.layoutID = layoutID
    }

    @objc private func openSettings() {
        appDelegate.settingsController.show()
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!
        NSWorkspace.shared.open(url)
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "OpenOSK",
            .applicationVersion: appVersion,
        ])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
