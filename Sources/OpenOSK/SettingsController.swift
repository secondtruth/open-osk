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
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L("OpenOSK Settings")
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
        let dwellTimeSlider = NSSlider(
            value: preferences.dwellTime, minValue: 0.3, maxValue: 2.5,
            target: self, action: #selector(dwellTimeChanged)
        )

        let scanIntervalSlider = NSSlider(
            value: preferences.scanInterval, minValue: 0.5, maxValue: 3.0,
            target: self, action: #selector(scanIntervalChanged)
        )
        let switchKeyPopup = NSPopUpButton()
        switchKeyPopup.addItems(withTitles: Self.switchKeys.map { $0.title })
        if let index = Self.switchKeys.firstIndex(where: { $0.id == preferences.scanSwitchKey }) {
            switchKeyPopup.selectItem(at: index)
        }
        switchKeyPopup.target = self
        switchKeyPopup.action = #selector(switchKeySelected)

        let clearButton = NSButton(
            title: L("Clear Learned Words"),
            target: self,
            action: #selector(clearLearned)
        )

        let grid = NSGridView(views: [
            [label(L("Layout:")), layoutPopup],
            [label(L("Key size:")), scaleSlider],
            [label(L("Opacity:")), opacitySlider],
            [NSGridCell.emptyContentView, checkbox(
                L("Show word predictions"),
                selector: #selector(predictionsToggled),
                state: preferences.predictionsEnabled)],
            [NSGridCell.emptyContentView, checkbox(
                L("Learn words from my typing"),
                selector: #selector(learningToggled),
                state: preferences.learningEnabled)],
            [NSGridCell.emptyContentView, checkbox(
                L("Complete shell commands in terminals"),
                selector: #selector(terminalToggled),
                state: preferences.terminalCompletionsEnabled)],
            [NSGridCell.emptyContentView, checkbox(
                L("Auto-capitalize after sentence end"),
                selector: #selector(autoCapToggled),
                state: preferences.autoCapitalization)],
            [NSGridCell.emptyContentView, checkbox(
                L("Double-space inserts a period"),
                selector: #selector(autoSpacingToggled),
                state: preferences.autoSpacing)],
            [NSGridCell.emptyContentView, checkbox(
                L("Show current text on the keyboard"),
                selector: #selector(currentTextToggled),
                state: preferences.showCurrentText)],
            [NSGridCell.emptyContentView, checkbox(
                L("Fade keyboard when inactive"),
                selector: #selector(fadeToggled),
                state: preferences.inactivityFadeEnabled)],
            [NSGridCell.emptyContentView, checkbox(
                L("Show keyboard when editing text"),
                selector: #selector(autoShowToggled),
                state: preferences.autoShowOnTextFocus)],
            [NSGridCell.emptyContentView, checkbox(
                L("Dwell input (hover to press)"),
                selector: #selector(dwellToggled),
                state: preferences.dwellEnabled)],
            [label(L("Dwell time:")), dwellTimeSlider],
            [NSGridCell.emptyContentView, checkbox(
                L("Scanning (switch access)"),
                selector: #selector(scanningToggled),
                state: preferences.scanningEnabled)],
            [label(L("Scan interval:")), scanIntervalSlider],
            [label(L("Switch key:")), switchKeyPopup],
            [NSGridCell.emptyContentView, clearButton],
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 10
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing

        let content = NSView()
        content.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -20),
            grid.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20),
            scaleSlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
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

    @objc private func dwellTimeChanged(_ sender: NSSlider) {
        preferences.dwellTime = sender.doubleValue
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

    @objc private func autoCapToggled(_ sender: NSButton) {
        preferences.autoCapitalization = sender.state == .on
    }

    @objc private func autoSpacingToggled(_ sender: NSButton) {
        preferences.autoSpacing = sender.state == .on
    }

    @objc private func currentTextToggled(_ sender: NSButton) {
        preferences.showCurrentText = sender.state == .on
    }

    @objc private func fadeToggled(_ sender: NSButton) {
        preferences.inactivityFadeEnabled = sender.state == .on
    }

    @objc private func autoShowToggled(_ sender: NSButton) {
        preferences.autoShowOnTextFocus = sender.state == .on
    }

    @objc private func dwellToggled(_ sender: NSButton) {
        preferences.dwellEnabled = sender.state == .on
    }

    @objc private func clearLearned() {
        keyboardController.clearLearnedWords()
    }

    private static let switchKeys: [(id: String, title: String)] = [
        ("space", L("Space")),
        ("return", L("Return")),
        ("f13", "F13"),
        ("f14", "F14"),
        ("f15", "F15"),
    ]

    @objc private func scanningToggled(_ sender: NSButton) {
        preferences.scanningEnabled = sender.state == .on
    }

    @objc private func scanIntervalChanged(_ sender: NSSlider) {
        preferences.scanInterval = sender.doubleValue
    }

    @objc private func switchKeySelected(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard Self.switchKeys.indices.contains(index) else { return }
        preferences.scanSwitchKey = Self.switchKeys[index].id
    }
}
