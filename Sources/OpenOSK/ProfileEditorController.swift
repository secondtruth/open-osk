#if canImport(AppKit)
import AppKit
import OpenOSKCore

/// Table-based editor for per-app profiles (app-profiles.json): bundle id,
/// layout override, and forced terminal mode per application.
final class ProfileEditorController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    private struct Row {
        var bundleID: String
        var layoutID: String?
        var terminal: TerminalSetting
    }

    private enum TerminalSetting: Int, CaseIterable {
        case automatic = 0
        case on
        case off

        var profileValue: Bool? {
            switch self {
            case .automatic: return nil
            case .on: return true
            case .off: return false
            }
        }

        init(profileValue: Bool?) {
            switch profileValue {
            case nil: self = .automatic
            case true?: self = .on
            case false?: self = .off
            }
        }

        var title: String {
            switch self {
            case .automatic: return L("Automatic")
            case .on: return L("On")
            case .off: return L("Off")
            }
        }
    }

    private let store = AppProfileStore()
    private var rows: [Row] = []
    private var layouts: [KeyboardLayout] = []

    private var window: NSWindow?
    private var tableView: NSTableView!

    func show() {
        layouts = LayoutStore.allLayouts()
        store.reload()
        rows = store.profiles
            .map { Row(bundleID: $0.key, layoutID: $0.value.layout,
                       terminal: TerminalSetting(profileValue: $0.value.terminalMode)) }
            .sorted { $0.bundleID < $1.bundleID }

        if window == nil {
            buildWindow()
        }
        tableView.reloadData()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Window

    private func buildWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 320),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L("App Profiles")
        window.isReleasedWhenClosed = false
        window.center()

        let table = NSTableView()
        table.dataSource = self
        table.delegate = self
        table.rowHeight = 26
        table.usesAlternatingRowBackgroundColors = true

        let bundleColumn = NSTableColumn(identifier: .init("bundle"))
        bundleColumn.title = L("Bundle Identifier")
        bundleColumn.width = 240
        table.addTableColumn(bundleColumn)

        let layoutColumn = NSTableColumn(identifier: .init("layout"))
        layoutColumn.title = L("Layout")
        layoutColumn.width = 150
        table.addTableColumn(layoutColumn)

        let terminalColumn = NSTableColumn(identifier: .init("terminal"))
        terminalColumn.title = L("Terminal Mode")
        terminalColumn.width = 110
        table.addTableColumn(terminalColumn)

        let scrollView = NSScrollView()
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        tableView = table

        let addButton = NSButton(title: "+", target: self, action: #selector(addRow))
        let addFrontmostButton = NSButton(
            title: L("Add Frontmost App"), target: self, action: #selector(addFrontmost))
        let removeButton = NSButton(title: "−", target: self, action: #selector(removeRow))
        let saveButton = NSButton(title: L("Save"), target: self, action: #selector(save))
        saveButton.keyEquivalent = "\r"

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let bar = NSStackView(views: [addButton, removeButton, addFrontmostButton, spacer, saveButton])
        bar.orientation = .horizontal
        bar.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(scrollView)
        content.addSubview(bar)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: bar.topAnchor, constant: -10),
            bar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            bar.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            bar.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
        ])
        window.contentView = content
        self.window = window
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row rowIndex: Int
    ) -> NSView? {
        guard let identifier = tableColumn?.identifier else { return nil }
        let row = rows[rowIndex]

        switch identifier.rawValue {
        case "bundle":
            let field = NSTextField(string: row.bundleID)
            field.isBordered = false
            field.backgroundColor = .clear
            field.target = self
            field.action = #selector(bundleEdited(_:))
            field.tag = rowIndex
            return field

        case "layout":
            let popup = NSPopUpButton()
            popup.isBordered = false
            popup.addItem(withTitle: L("Default Layout"))
            popup.addItems(withTitles: layouts.map(\.name))
            if let layoutID = row.layoutID,
               let index = layouts.firstIndex(where: { $0.id == layoutID }) {
                popup.selectItem(at: index + 1)
            }
            popup.target = self
            popup.action = #selector(layoutEdited(_:))
            popup.tag = rowIndex
            return popup

        case "terminal":
            let popup = NSPopUpButton()
            popup.isBordered = false
            popup.addItems(withTitles: TerminalSetting.allCases.map(\.title))
            popup.selectItem(at: row.terminal.rawValue)
            popup.target = self
            popup.action = #selector(terminalEdited(_:))
            popup.tag = rowIndex
            return popup

        default:
            return nil
        }
    }

    // MARK: - Actions

    @objc private func bundleEdited(_ sender: NSTextField) {
        guard rows.indices.contains(sender.tag) else { return }
        rows[sender.tag].bundleID = sender.stringValue
            .trimmingCharacters(in: .whitespaces)
    }

    @objc private func layoutEdited(_ sender: NSPopUpButton) {
        guard rows.indices.contains(sender.tag) else { return }
        let index = sender.indexOfSelectedItem
        rows[sender.tag].layoutID = index == 0 ? nil : layouts[index - 1].id
    }

    @objc private func terminalEdited(_ sender: NSPopUpButton) {
        guard rows.indices.contains(sender.tag),
              let setting = TerminalSetting(rawValue: sender.indexOfSelectedItem)
        else { return }
        rows[sender.tag].terminal = setting
    }

    @objc private func addRow() {
        rows.append(Row(bundleID: "com.example.App", layoutID: nil, terminal: .automatic))
        tableView.reloadData()
    }

    @objc private func addFrontmost() {
        // Our own app is frontmost while the editor is key; take the previous
        // app from the ordered running list instead.
        let candidate = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .first { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        let bundleID = candidate?.bundleIdentifier ?? "com.example.App"
        guard !rows.contains(where: { $0.bundleID == bundleID }) else { return }
        rows.append(Row(bundleID: bundleID, layoutID: nil, terminal: .automatic))
        tableView.reloadData()
    }

    @objc private func removeRow() {
        let index = tableView.selectedRow
        guard rows.indices.contains(index) else { return }
        rows.remove(at: index)
        tableView.reloadData()
    }

    @objc private func save() {
        window?.makeFirstResponder(nil)  // commit in-progress text edits
        var profiles: [String: AppProfile] = [:]
        for row in rows where !row.bundleID.isEmpty {
            let profile = AppProfile(
                layout: row.layoutID,
                terminalMode: row.terminal.profileValue
            )
            if profile.layout != nil || profile.terminalMode != nil {
                profiles[row.bundleID] = profile
            }
        }
        do {
            try store.write(profiles: profiles)
            NotificationCenter.default.post(name: .openOSKProfilesChanged, object: nil)
            window?.close()
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
#endif
