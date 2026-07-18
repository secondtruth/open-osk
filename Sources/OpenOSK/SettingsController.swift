import AppKit
import OpenOSKCore

final class SettingsController: NSObject {
    private let preferences = Preferences.shared
    private unowned let keyboardController: KeyboardController

    private var window: NSWindow?
    private var layoutPopup: NSPopUpButton!
    private var layouts: [KeyboardLayout] = []

    init(keyboardController: KeyboardController) {
        self.keyboardController = keyboardController
        super.init()
    }

    func show() {
        if window == nil {
            buildWindow()
        }
        reloadLayouts()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func buildWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "OpenOSK Settings"
        window.isReleasedWhenClosed = false
        window.center()

        layoutPopup = NSPopUpButton()
        layoutPopup.target = self
        layoutPopup.action = #selector(layoutSelected)

        let scaleSlider = NSSlider(
            value: preferences.scale, minValue: 0.7, maxValue: 1.6,
            target: self, action: #selector(scaleChanged)
        )
        let opacitySlider = NSSlider(
            value: preferences.opacity, minValue: 0.35, maxValue: 1.0,
            target: self, action: #selector(opacityChanged)
        )

        let predictionsCheckbox = checkbox(
            "Show word predictions",
            selector: #selector(predictionsToggled),
            state: preferences.predictionsEnabled
        )
        let learningCheckbox = checkbox(
            "Learn words from my typing",
            selector: #selector(learningToggled),
            state: preferences.learningEnabled
        )
        let terminalCheckbox = checkbox(
            "Complete shell commands in terminals",
            selector: #selector(terminalToggled),
            state: preferences.terminalCompletionsEnabled
        )

        let clearButton = NSButton(
            title: "Clear Learned Words",
            target: self,
            action: #selector(clearLearned)
        )

        let grid = NSGridView(views: [
            [label("Layout:"), layoutPopup],
            [label("Key size:"), scaleSlider],
            [label("Opacity:"), opacitySlider],
            [NSGridCell.emptyContentView, predictionsCheckbox],
            [NSGridCell.emptyContentView, learningCheckbox],
            [NSGridCell.emptyContentView, terminalCheckbox],
            [NSGridCell.emptyContentView, clearButton],
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 12
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing

        let content = NSView()
        content.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20),
            grid.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20),
            scaleSlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
        ])
        window.contentView = content

        self.window = window
    }

    private func label(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }

    private func checkbox(_ title: String, selector: Selector, state: Bool) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: self, action: selector)
        button.state = state ? .on : .off
        return button
    }

    private func reloadLayouts() {
        layouts = LayoutStore.allLayouts()
        layoutPopup.removeAllItems()
        layoutPopup.addItems(withTitles: layouts.map(\.name))
        if let index = layouts.firstIndex(where: { $0.id == preferences.layoutID }) {
            layoutPopup.selectItem(at: index)
        }
    }

    // MARK: - Actions

    @objc private func layoutSelected(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard layouts.indices.contains(index) else { return }
        preferences.layoutID = layouts[index].id
    }

    @objc private func scaleChanged(_ sender: NSSlider) {
        preferences.scale = sender.doubleValue
    }

    @objc private func opacityChanged(_ sender: NSSlider) {
        preferences.opacity = sender.doubleValue
    }

    @objc private func predictionsToggled(_ sender: NSButton) {
        preferences.predictionsEnabled = sender.state == .on
    }

    @objc private func learningToggled(_ sender: NSButton) {
        preferences.learningEnabled = sender.state == .on
    }

    @objc private func terminalToggled(_ sender: NSButton) {
        preferences.terminalCompletionsEnabled = sender.state == .on
    }

    @objc private func clearLearned() {
        keyboardController.clearLearnedWords()
    }
}
