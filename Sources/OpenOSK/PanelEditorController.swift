#if canImport(AppKit)
import AppKit
import OpenOSKCore

/// Editor for custom panels: create/edit button collections without touching
/// JSON. Buttons are listed as table rows; the "Row" column groups them into
/// panel rows. Complex hand-written macros survive round-trips untouched
/// (shown as "Custom"); edits are saved to the user panels directory, which
/// overrides bundled panels by id.
final class PanelEditorController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private enum ActionType: Int, CaseIterable {
        case text = 0
        case commandReturn
        case shortcut
        case open
        case custom

        var title: String {
            switch self {
            case .text: return L("Insert Text")
            case .commandReturn: return L("Type + Return")
            case .shortcut: return L("Press Shortcut")
            case .open: return L("Open URL/File")
            case .custom: return L("Custom (JSON)")
            }
        }
    }

    private struct ButtonRow {
        var row: Int
        var label: String
        var image: String
        var action: ActionType
        var value: String
        /// Preserved original for keys the simple editor cannot express.
        var originalKey: Key?
    }

    private var panels: [KeyboardLayout] = []
    private var selectedPanelIndex = -1
    private var buttons: [ButtonRow] = []
    private var panelName = ""

    private var window: NSWindow?
    private var panelPopup: NSPopUpButton!
    private var nameField: NSTextField!
    private var tableView: NSTableView!

    func show() {
        reloadPanels(selecting: nil)
        if window == nil {
            buildWindow()
        }
        refreshPanelPopup()
        loadSelectedPanel()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Model mapping

    private func reloadPanels(selecting panelID: String?) {
        panels = LayoutStore.allPanels()
        if let panelID, let index = panels.firstIndex(where: { $0.id == panelID }) {
            selectedPanelIndex = index
        } else if selectedPanelIndex >= panels.count {
            selectedPanelIndex = panels.isEmpty ? -1 : 0
        } else if selectedPanelIndex < 0, !panels.isEmpty {
            selectedPanelIndex = 0
        }
    }

    private func loadSelectedPanel() {
        guard panels.indices.contains(selectedPanelIndex) else {
            buttons = []
            panelName = ""
            nameField?.stringValue = ""
            tableView?.reloadData()
            return
        }
        let panel = panels[selectedPanelIndex]
        panelName = panel.name
        nameField?.stringValue = panel.name
        buttons = panel.rows.enumerated().flatMap { rowIndex, keys in
            keys.map { key in buttonRow(from: key, rowIndex: rowIndex) }
        }
        tableView?.reloadData()
    }

    private func buttonRow(from key: Key, rowIndex: Int) -> ButtonRow {
        let label = key.label ?? key.text ?? ""
        let image = key.image ?? ""

        if let text = key.text, key.macro == nil {
            return ButtonRow(row: rowIndex, label: label, image: image,
                             action: .text, value: text)
        }
        if let macro = key.macro {
            let steps = macro.steps
            if steps.count == 1, let text = steps[0].text, steps[0].shortcut == nil,
               steps[0].open == nil, steps[0].panel == nil, steps[0].say == nil {
                return ButtonRow(row: rowIndex, label: label, image: image,
                                 action: .text, value: text)
            }
            if steps.count == 2, let text = steps[0].text, steps[1].shortcut == "return" {
                return ButtonRow(row: rowIndex, label: label, image: image,
                                 action: .commandReturn, value: text)
            }
            if steps.count == 1, let shortcut = steps[0].shortcut {
                return ButtonRow(row: rowIndex, label: label, image: image,
                                 action: .shortcut, value: shortcut)
            }
            if steps.count == 1, let open = steps[0].open {
                return ButtonRow(row: rowIndex, label: label, image: image,
                                 action: .open, value: open)
            }
        }
        return ButtonRow(row: rowIndex, label: label, image: image,
                         action: .custom, value: "", originalKey: key)
    }

    private func key(from button: ButtonRow) -> Key {
        let label = button.label.isEmpty ? nil : button.label
        let image = button.image.isEmpty ? nil : button.image
        switch button.action {
        case .text:
            return Key(text: button.value, image: image, width: 1.8, label: label)
        case .commandReturn:
            return Key(
                macro: Macro(steps: [
                    MacroStep(text: button.value),
                    MacroStep(shortcut: "return"),
                ]),
                image: image, width: 1.8, label: label
            )
        case .shortcut:
            return Key(
                macro: Macro(steps: [MacroStep(shortcut: button.value)]),
                image: image, width: 1.8, label: label
            )
        case .open:
            return Key(
                macro: Macro(steps: [MacroStep(open: button.value)]),
                image: image, width: 1.8, label: label
            )
        case .custom:
            var key = button.originalKey ?? Key(label: label)
            key.label = label
            key.image = image
            return key
        }
    }

    // MARK: - Window

    private func buildWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L("Panel Editor")
        window.isReleasedWhenClosed = false
        window.center()

        panelPopup = NSPopUpButton()
        panelPopup.target = self
        panelPopup.action = #selector(panelSelected)

        let newPanelButton = NSButton(
            title: L("New Panel"), target: self, action: #selector(newPanel))
        let deletePanelButton = NSButton(
            title: L("Delete Panel"), target: self, action: #selector(deletePanel))

        nameField = NSTextField(string: "")
        nameField.placeholderString = L("Panel name")
        nameField.target = self
        nameField.action = #selector(nameEdited)

        let topBar = NSStackView(views: [
            panelPopup, newPanelButton, deletePanelButton,
            NSTextField(labelWithString: L("Name:")), nameField,
        ])
        topBar.orientation = .horizontal
        topBar.translatesAutoresizingMaskIntoConstraints = false

        let table = NSTableView()
        table.dataSource = self
        table.delegate = self
        table.rowHeight = 26
        table.usesAlternatingRowBackgroundColors = true

        for (identifier, title, width) in [
            ("row", L("Row"), CGFloat(40)),
            ("label", L("Label"), 120),
            ("image", L("Symbol"), 110),
            ("action", L("Action"), 150),
            ("value", L("Value"), 200),
        ] {
            let column = NSTableColumn(identifier: .init(identifier))
            column.title = title
            column.width = width
            table.addTableColumn(column)
        }

        let scrollView = NSScrollView()
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        tableView = table

        let addButton = NSButton(title: "+", target: self, action: #selector(addButtonRow))
        let removeButton = NSButton(title: "−", target: self, action: #selector(removeButtonRow))
        let saveButton = NSButton(title: L("Save"), target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"
        let hint = NSTextField(
            labelWithString: L("Saved panels override bundled ones with the same id."))
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 11)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let bottomBar = NSStackView(views: [addButton, removeButton, hint, spacer, saveButton])
        bottomBar.orientation = .horizontal
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(topBar)
        content.addSubview(scrollView)
        content.addSubview(bottomBar)
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            topBar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            topBar.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -12),
            nameField.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            scrollView.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor, constant: -10),
            bottomBar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            bottomBar.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            bottomBar.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
        ])
        window.contentView = content
        self.window = window
    }

    private func refreshPanelPopup() {
        panelPopup.removeAllItems()
        panelPopup.addItems(withTitles: panels.map(\.name))
        if panels.indices.contains(selectedPanelIndex) {
            panelPopup.selectItem(at: selectedPanelIndex)
        }
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int {
        buttons.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row rowIndex: Int
    ) -> NSView? {
        guard let identifier = tableColumn?.identifier else { return nil }
        let button = buttons[rowIndex]

        func textCell(_ value: String, _ action: Selector) -> NSTextField {
            let field = NSTextField(string: value)
            field.isBordered = false
            field.backgroundColor = .clear
            field.target = self
            field.action = action
            field.tag = rowIndex
            return field
        }

        switch identifier.rawValue {
        case "row":
            return textCell(String(button.row + 1), #selector(rowNumberEdited(_:)))
        case "label":
            return textCell(button.label, #selector(labelEdited(_:)))
        case "image":
            let field = textCell(button.image, #selector(imageEdited(_:)))
            field.placeholderString = "SF Symbol"
            return field
        case "action":
            let popup = NSPopUpButton()
            popup.isBordered = false
            popup.addItems(withTitles: ActionType.allCases.map(\.title))
            popup.selectItem(at: button.action.rawValue)
            popup.isEnabled = button.action != .custom
            popup.target = self
            popup.action = #selector(actionEdited(_:))
            popup.tag = rowIndex
            return popup
        case "value":
            let field = textCell(button.value, #selector(valueEdited(_:)))
            if button.action == .custom {
                field.isEditable = false
                field.stringValue = L("(kept as defined in JSON)")
                field.textColor = .secondaryLabelColor
            }
            return field
        default:
            return nil
        }
    }

    // MARK: - Cell edits

    @objc private func rowNumberEdited(_ sender: NSTextField) {
        guard buttons.indices.contains(sender.tag) else { return }
        buttons[sender.tag].row = max(0, (Int(sender.stringValue) ?? 1) - 1)
    }

    @objc private func labelEdited(_ sender: NSTextField) {
        guard buttons.indices.contains(sender.tag) else { return }
        buttons[sender.tag].label = sender.stringValue
    }

    @objc private func imageEdited(_ sender: NSTextField) {
        guard buttons.indices.contains(sender.tag) else { return }
        buttons[sender.tag].image = sender.stringValue
            .trimmingCharacters(in: .whitespaces)
    }

    @objc private func actionEdited(_ sender: NSPopUpButton) {
        guard buttons.indices.contains(sender.tag),
              let action = ActionType(rawValue: sender.indexOfSelectedItem),
              action != .custom
        else { return }
        buttons[sender.tag].action = action
    }

    @objc private func valueEdited(_ sender: NSTextField) {
        guard buttons.indices.contains(sender.tag),
              buttons[sender.tag].action != .custom
        else { return }
        buttons[sender.tag].value = sender.stringValue
    }

    // MARK: - Actions

    @objc private func panelSelected() {
        selectedPanelIndex = panelPopup.indexOfSelectedItem
        loadSelectedPanel()
    }

    @objc private func nameEdited() {
        panelName = nameField.stringValue
    }

    @objc private func newPanel() {
        selectedPanelIndex = -1
        panelName = L("My Panel")
        nameField.stringValue = panelName
        buttons = [ButtonRow(row: 0, label: "Hello", image: "", action: .text, value: "Hello ")]
        panelPopup.select(nil)
        tableView.reloadData()
    }

    @objc private func deletePanel() {
        guard panels.indices.contains(selectedPanelIndex) else { return }
        let panel = panels[selectedPanelIndex]
        if LayoutStore.deleteUserPanel(id: panel.id) {
            NotificationCenter.default.post(name: .openOSKPanelsChanged, object: nil)
        }
        reloadPanels(selecting: nil)
        refreshPanelPopup()
        loadSelectedPanel()
    }

    @objc private func addButtonRow() {
        let lastRow = buttons.map(\.row).max() ?? 0
        buttons.append(ButtonRow(row: lastRow, label: "", image: "", action: .text, value: ""))
        tableView.reloadData()
    }

    @objc private func removeButtonRow() {
        let index = tableView.selectedRow
        guard buttons.indices.contains(index) else { return }
        buttons.remove(at: index)
        tableView.reloadData()
    }

    @objc private func save() {
        window?.makeFirstResponder(nil)  // commit in-progress text edits
        panelName = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !panelName.isEmpty, !buttons.isEmpty else { return }

        let panelID: String
        if panels.indices.contains(selectedPanelIndex) {
            panelID = panels[selectedPanelIndex].id
        } else {
            panelID = Self.slug(for: panelName)
        }

        let grouped = Dictionary(grouping: buttons, by: \.row)
        let rows = grouped.keys.sorted().map { rowIndex in
            grouped[rowIndex]!.map { key(from: $0) }
        }
        let panel = KeyboardLayout(id: panelID, name: panelName, rows: rows)

        do {
            try LayoutStore.writeUserPanel(panel)
            NotificationCenter.default.post(name: .openOSKPanelsChanged, object: nil)
            reloadPanels(selecting: panelID)
            refreshPanelPopup()
            loadSelectedPanel()
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    static func slug(for name: String) -> String {
        let lowered = name.lowercased()
        let mapped = lowered.map { character -> Character in
            character.isLetter || character.isNumber ? character : "-"
        }
        let collapsed = String(mapped)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return collapsed.isEmpty ? "panel" : collapsed
    }
}
#endif
