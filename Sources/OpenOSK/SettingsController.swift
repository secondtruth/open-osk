#if canImport(AppKit)
import AppKit
import OpenOSKCore

/// Settings window: toolbar tabs (General, Typing, Access, Panels), each a
/// grid of controls bound to `Preferences` by key path.
final class SettingsController: NSObject {
    private let preferences = Preferences.shared
    private let onClearLearnedWords: () -> Void

    private var window: NSWindow?
    private var layoutPopup: NSPopUpButton!
    private var layouts: [KeyboardLayout] = []
    /// Controls that only make sense while their switch is on.
    private var dependents: [(control: NSControl, isEnabled: () -> Bool)] = []

    private static let paneWidth: CGFloat = 460
    private static let scanKeys: [(id: String, title: String)] = [
        ("space", L("Space")),
        ("return", L("Return")),
        ("f13", "F13"),
        ("f14", "F14"),
        ("f15", "F15"),
    ]

    init(onClearLearnedWords: @escaping () -> Void) {
        self.onClearLearnedWords = onClearLearnedWords
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

    // MARK: - Window

    /// The settings panes in tab order. Also rendered by `--snapshot`.
    func makeTabs() -> [NSTabViewItem] {
        let tabs = [
            tab(L("General"), symbol: "gearshape", rows: generalRows()),
            tab(L("Typing"), symbol: "character.cursor.ibeam", rows: typingRows()),
            tab(L("Access"), symbol: "accessibility", rows: accessRows()),
            tab(L("Panels"), symbol: "rectangle.3.group", rows: panelRows()),
        ]
        reloadLayouts()
        refreshDependents()
        return tabs
    }

    private func buildWindow() {
        let tabs = SettingsTabViewController()
        tabs.tabStyle = .toolbar
        makeTabs().forEach(tabs.addTabViewItem)

        // No title of its own: a toolbar-style tab controller titles the
        // window after the selected tab.
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
    }

    private func tab(_ title: String, symbol: String, rows: [[NSView]]) -> NSTabViewItem {
        let grid = NSGridView(views: rows)
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 10
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline

        let pane = NSView()
        pane.addSubview(grid)
        NSLayoutConstraint.activate([
            pane.widthAnchor.constraint(equalToConstant: Self.paneWidth),
            grid.topAnchor.constraint(equalTo: pane.topAnchor, constant: 20),
            grid.centerXAnchor.constraint(equalTo: pane.centerXAnchor),
            grid.leadingAnchor.constraint(greaterThanOrEqualTo: pane.leadingAnchor, constant: 20),
            grid.bottomAnchor.constraint(equalTo: pane.bottomAnchor, constant: -20),
        ])

        let controller = NSViewController()
        controller.view = pane
        controller.title = title
        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }

    // MARK: - Panes

    private func generalRows() -> [[NSView]] {
        layoutPopup = NSPopUpButton()
        layoutPopup.target = self
        layoutPopup.action = #selector(layoutSelected)

        let themePopup = popup(
            titles: Theme.all.map(\.name), ids: Theme.all.map(\.id), keyPath: \.themeID)

        // Every distinct key size rebuilds the keyboard, so it applies on release.
        let scale = slider(\.scale, range: 0.7...1.6, format: Self.percent, continuous: false)
        let opacity = slider(\.opacity, range: 0.35...1.0, format: Self.percent)

        return [
            [label(L("Layout:")), layoutPopup],
            [label(L("Theme:")), themePopup],
            [label(L("Key size:")), scale],
            [label(L("Opacity:")), opacity],
            [spacer(), checkbox(L("Show current text on the keyboard"), \.showCurrentText)],
            [spacer(), checkbox(L("Fade keyboard when inactive"), \.inactivityFadeEnabled)],
            [spacer(), checkbox(L("Show keyboard when editing text"), \.autoShowOnTextFocus)],
            [spacer(), checkbox(L("Key click sound"), \.keyClickSound)],
        ]
    }

    private func typingRows() -> [[NSView]] {
        let clearButton = NSButton(
            title: L("Clear Learned Words"), target: self, action: #selector(clearLearned))
        return [
            [label(L("Predictions:")), checkbox(L("Show word predictions"), \.predictionsEnabled)],
            [spacer(), checkbox(L("Learn words from my typing"), \.learningEnabled)],
            [spacer(), checkbox(L("Use system dictionary for predictions"), \.systemDictionaryEnabled)],
            [spacer(), checkbox(L("Complete shell commands in terminals"), \.terminalCompletionsEnabled)],
            [spacer(), clearButton],
            [label(L("Typing aids:")), checkbox(L("Auto-capitalize after sentence end"), \.autoCapitalization)],
            [spacer(), checkbox(L("Double-space inserts a period"), \.autoSpacing)],
        ]
    }

    private func accessRows() -> [[NSView]] {
        let dwellTime = slider(\.dwellTime, range: 0.3...2.5, format: Self.seconds)
        let scanInterval = slider(\.scanInterval, range: 0.5...3.0, format: Self.seconds)
        let switchKey = popup(
            titles: Self.scanKeys.map(\.title), ids: Self.scanKeys.map(\.id),
            keyPath: \.scanSwitchKey)
        let advanceKey = popup(
            titles: [L("None")] + Self.scanKeys.map(\.title),
            ids: ["none"] + Self.scanKeys.map(\.id),
            keyPath: \.scanAdvanceKey)

        let preferences = self.preferences
        dependents.append((dwellTime.slider, { preferences.dwellEnabled }))
        for control in [scanInterval.slider, switchKey, advanceKey] as [NSControl] {
            dependents.append((control, { preferences.scanningEnabled }))
        }

        return [
            [label(L("Dwell:")), checkbox(L("Dwell input (hover to press)"), \.dwellEnabled)],
            [label(L("Dwell time:")), dwellTime],
            [label(L("Scanning:")), checkbox(L("Scanning (switch access)"), \.scanningEnabled)],
            [label(L("Scan interval:")), scanInterval],
            [label(L("Switch key:")), switchKey],
            [label(L("Advance key:")), advanceKey],
        ]
    }

    private func panelRows() -> [[NSView]] {
        [
            [label(L("Panels:")), NSButton(
                title: L("Panel Editor…"), target: self, action: #selector(editPanels))],
            [spacer(), NSButton(
                title: L("Open Panels Folder…"), target: self, action: #selector(openPanelsFolder))],
            [label(L("Per app:")), NSButton(
                title: L("App Profiles…"), target: self, action: #selector(editProfiles))],
        ]
    }

    // MARK: - Control factories

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded())) %"
    }

    private static func seconds(_ value: Double) -> String {
        String(format: "%.1f s", locale: .current, value)
    }

    private func label(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }

    private func spacer() -> NSView {
        NSGridCell.emptyContentView
    }

    private func checkbox(
        _ title: String, _ keyPath: ReferenceWritableKeyPath<Preferences, Bool>
    ) -> NSButton {
        let button = PreferenceCheckbox(checkboxWithTitle: title, target: self, action: #selector(checkboxToggled))
        button.keyPath = keyPath
        button.state = preferences[keyPath: keyPath] ? .on : .off
        return button
    }

    private func slider(
        _ keyPath: ReferenceWritableKeyPath<Preferences, Double>,
        range: ClosedRange<Double>,
        format: @escaping (Double) -> String,
        continuous: Bool = true
    ) -> PreferenceSliderRow {
        let row = PreferenceSliderRow(
            value: preferences[keyPath: keyPath], range: range, format: format)
        row.appliesOnRelease = !continuous
        row.onChange = { [preferences] value in preferences[keyPath: keyPath] = value }
        return row
    }

    private func popup(
        titles: [String], ids: [String],
        keyPath: ReferenceWritableKeyPath<Preferences, String>
    ) -> NSPopUpButton {
        let popup = PreferencePopup()
        popup.addItems(withTitles: titles)
        popup.ids = ids
        popup.keyPath = keyPath
        if let index = ids.firstIndex(of: preferences[keyPath: keyPath]) {
            popup.selectItem(at: index)
        }
        popup.target = self
        popup.action = #selector(popupSelected)
        return popup
    }

    private func refreshDependents() {
        for dependent in dependents {
            dependent.control.isEnabled = dependent.isEnabled()
        }
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

    @objc private func checkboxToggled(_ sender: PreferenceCheckbox) {
        guard let keyPath = sender.keyPath else { return }
        preferences[keyPath: keyPath] = sender.state == .on
        refreshDependents()
    }

    @objc private func popupSelected(_ sender: PreferencePopup) {
        let index = sender.indexOfSelectedItem
        guard let keyPath = sender.keyPath, sender.ids.indices.contains(index) else { return }
        preferences[keyPath: keyPath] = sender.ids[index]
    }

    @objc private func layoutSelected(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem
        guard layouts.indices.contains(index) else { return }
        preferences.layoutID = layouts[index].id
    }

    @objc private func clearLearned() {
        let alert = NSAlert()
        alert.messageText = L("Clear all learned words?")
        alert.informativeText = L("Predictions fall back to the bundled word lists. This cannot be undone.")
        alert.addButton(withTitle: L("Clear Learned Words"))
        alert.addButton(withTitle: L("Cancel"))
        alert.buttons.first?.hasDestructiveAction = true
        guard let window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertFirstButtonReturn {
                self?.onClearLearnedWords()
            }
        }
    }

    @objc private func editProfiles() {
        (NSApp.delegate as? AppDelegate)?.profileEditorController.show()
    }

    @objc private func editPanels() {
        (NSApp.delegate as? AppDelegate)?.panelEditorController.show()
    }

    @objc private func openPanelsFolder() {
        let url = LayoutStore.userPanelsDirectory
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Bound controls

private final class PreferenceCheckbox: NSButton {
    var keyPath: ReferenceWritableKeyPath<Preferences, Bool>?
}

private final class PreferencePopup: NSPopUpButton {
    var keyPath: ReferenceWritableKeyPath<Preferences, String>?
    /// Stored value per menu item, parallel to the item titles.
    var ids: [String] = []
}

/// A slider with its current value spelled out next to it.
private final class PreferenceSliderRow: NSStackView {
    let slider: NSSlider
    var onChange: ((Double) -> Void)?
    /// Report the value only once the drag ends; the label still follows it.
    var appliesOnRelease = false

    private let valueLabel = NSTextField(labelWithString: "")
    private let format: (Double) -> String

    init(value: Double, range: ClosedRange<Double>, format: @escaping (Double) -> String) {
        self.format = format
        slider = NSSlider(
            value: value, minValue: range.lowerBound, maxValue: range.upperBound,
            target: nil, action: nil)
        super.init(frame: .zero)
        slider.target = self
        slider.action = #selector(changed)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        valueLabel.stringValue = format(value)

        orientation = .horizontal
        spacing = 8
        addArrangedSubview(slider)
        addArrangedSubview(valueLabel)
        NSLayoutConstraint.activate([
            slider.widthAnchor.constraint(equalToConstant: 220),
            valueLabel.widthAnchor.constraint(equalToConstant: 48),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func changed() {
        valueLabel.stringValue = format(slider.doubleValue)
        let isDragging = NSApp.currentEvent.map {
            $0.type == .leftMouseDown || $0.type == .leftMouseDragged
        } ?? false
        if !(appliesOnRelease && isDragging) {
            onChange?(slider.doubleValue)
        }
    }
}

/// Resizes the window to the selected pane, like System Settings-era
/// preference windows do.
private final class SettingsTabViewController: NSTabViewController {
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        guard let window = view.window, let pane = tabViewItem?.view else { return }
        let content = window.frameRect(forContentRect: NSRect(origin: .zero, size: pane.fittingSize))
        var frame = window.frame
        frame.origin.y += frame.height - content.height
        frame.size = content.size
        window.setFrame(frame, display: true, animate: true)
    }
}
#endif
