#if canImport(AppKit)
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
            title: keyboardVisible ? L("Hide Keyboard") : L("Show Keyboard"),
            action: #selector(toggleKeyboard)
        ))
        menu.addItem(makeItem(title: L("Open Texter"), action: #selector(openTexter)))

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
        let layoutItem = NSMenuItem(title: L("Layout"), action: nil, keyEquivalent: "")
        layoutItem.submenu = layoutMenu
        menu.addItem(layoutItem)

        let panelsMenu = NSMenu()
        let panelsController = appDelegate.keyboardController.panels
        let openIDs = panelsController.openPanelIDs
        for panel in panelsController.availablePanels() {
            let item = NSMenuItem(
                title: panel.name,
                action: #selector(togglePanelWindow(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = panel.id
            item.state = openIDs.contains(panel.id) ? .on : .off
            panelsMenu.addItem(item)
        }
        let panelsItem = NSMenuItem(title: L("Panels"), action: nil, keyEquivalent: "")
        panelsItem.submenu = panelsMenu
        menu.addItem(panelsItem)

        let scanItem = makeItem(
            title: L("Scanning (switch access)"),
            action: #selector(toggleScanning)
        )
        scanItem.state = Preferences.shared.scanningEnabled ? .on : .off
        menu.addItem(scanItem)

        menu.addItem(makeItem(title: L("Panel Editor…"), action: #selector(openPanelEditor)))
        menu.addItem(makeItem(title: L("App Profiles…"), action: #selector(openProfileEditor)))
        menu.addItem(makeItem(title: L("Settings…"), action: #selector(openSettings)))
        menu.addItem(.separator())

        if !KeyInjector.isTrusted() {
            menu.addItem(makeItem(
                title: "⚠️ " + L("Grant Accessibility Access…"),
                action: #selector(openAccessibilitySettings)
            ))
            menu.addItem(.separator())
        }

        menu.addItem(makeItem(title: L("About OpenOSK"), action: #selector(showAbout)))
        menu.addItem(makeItem(title: L("Quit OpenOSK"), action: #selector(quit)))
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

    @objc private func togglePanelWindow(_ sender: NSMenuItem) {
        guard let panelID = sender.representedObject as? String else { return }
        appDelegate.keyboardController.panels.toggle(panelID: panelID)
    }

    @objc private func toggleScanning() {
        Preferences.shared.scanningEnabled.toggle()
    }

    @objc private func openSettings() {
        appDelegate.settingsController.show()
    }

    @objc private func openPanelEditor() {
        appDelegate.panelEditorController.show()
    }

    @objc private func openProfileEditor() {
        appDelegate.profileEditorController.show()
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
#endif
