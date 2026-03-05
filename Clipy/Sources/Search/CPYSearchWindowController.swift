//
//  CPYSearchWindowController.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa
import RealmSwift

final class CPYSearchWindowController: NSObject {

    // MARK: - Properties
    static let shared = CPYSearchWindowController()

    private let searchService = SearchService()
    private var results = [SearchResultItem]()
    private var previousApp: NSRunningApplication?
    private var debounceWorkItem: DispatchWorkItem?

    private lazy var panel: NSPanel = {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = .canJoinAllSpaces
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = NSColor.windowBackgroundColor
        return panel
    }()

    private lazy var searchField: NSTextField = {
        let field = NSTextField()
        field.placeholderString = "Search clips and snippets..."
        field.font = NSFont.systemFont(ofSize: 16)
        field.focusRingType = .none
        field.translatesAutoresizingMaskIntoConstraints = false
        field.delegate = self
        return field
    }()

    private lazy var scrollView: NSScrollView = {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.borderType = .noBorder
        return scroll
    }()

    private lazy var tableView: NSTableView = {
        let table = NSTableView()
        table.headerView = nil
        table.rowHeight = 32
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.backgroundColor = .clear
        table.delegate = self
        table.dataSource = self
        table.target = self
        table.doubleAction = #selector(tableViewDoubleClicked)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ResultColumn"))
        column.width = 580
        table.addTableColumn(column)

        return table
    }()

    private var isSetUp = false

    // MARK: - Init
    private override init() {
        super.init()
    }

    // MARK: - Setup
    private func setupIfNeeded() {
        guard !isSetUp else { return }
        isSetUp = true
        setupUI()
        setupNotifications()
    }

    private func setupUI() {
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false

        panel.contentView = contentView

        contentView.addSubview(searchField)
        contentView.addSubview(scrollView)
        scrollView.documentView = tableView

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(separator)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 36),

            separator.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            scrollView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey),
            name: NSWindow.didResignKeyNotification,
            object: panel
        )
    }

    // MARK: - Show / Hide
    func showSearchWindow() {
        setupIfNeeded()
        previousApp = NSWorkspace.shared.frontmostApplication

        // Position at center top of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let originX = screenFrame.midX - 300
            let originY = screenFrame.maxY - 450
            panel.setFrameOrigin(NSPoint(x: originX, y: originY))
        }

        searchField.stringValue = ""
        performSearch(query: "")

        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(searchField)
    }

    private func closeSearchWindow() {
        panel.orderOut(nil)
        previousApp = nil
    }

    // MARK: - Notifications
    @objc private func windowDidResignKey(_ notification: Notification) {
        closeSearchWindow()
    }

    // MARK: - Search
    private func performSearch(query: String) {
        results = searchService.search(query: query)
        tableView.reloadData()
        if !results.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }
    }

    private func debouncedSearch(query: String) {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.performSearch(query: query)
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
    }

    // MARK: - Selection
    private func selectCurrentItem() {
        let row = tableView.selectedRow
        guard row >= 0 && row < results.count else { return }
        let item = results[row]

        closeSearchWindow()

        // Restore previous app and paste
        if let previousApp = previousApp {
            previousApp.activate()
        }

        let pasteService = AppEnvironment.current.pasteService

        // Small delay to allow app activation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            switch item.type {
            case .clip:
                let realm = try! Realm()
                guard let clip = realm.object(ofType: CPYClip.self, forPrimaryKey: item.primaryKey) else {
                    NSSound.beep()
                    return
                }
                pasteService.paste(with: clip)
            case .snippet:
                let realm = try! Realm()
                guard let snippet = realm.object(ofType: CPYSnippet.self, forPrimaryKey: item.primaryKey) else {
                    NSSound.beep()
                    return
                }
                pasteService.copyToPasteboard(with: snippet.content)
                pasteService.paste()
            }
        }
    }

    // MARK: - Actions
    @objc private func tableViewDoubleClicked() {
        selectCurrentItem()
    }
}

// MARK: - NSTextFieldDelegate
extension CPYSearchWindowController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        debouncedSearch(query: searchField.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.moveUp(_:)) {
            let row = tableView.selectedRow
            if row > 0 {
                tableView.selectRowIndexes(IndexSet(integer: row - 1), byExtendingSelection: false)
                tableView.scrollRowToVisible(row - 1)
            }
            return true
        }
        if commandSelector == #selector(NSResponder.moveDown(_:)) {
            let row = tableView.selectedRow
            if row < results.count - 1 {
                tableView.selectRowIndexes(IndexSet(integer: row + 1), byExtendingSelection: false)
                tableView.scrollRowToVisible(row + 1)
            }
            return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            selectCurrentItem()
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            closeSearchWindow()
            return true
        }
        return false
    }
}

// MARK: - NSTableViewDataSource
extension CPYSearchWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return results.count
    }
}

// MARK: - NSTableViewDelegate
extension CPYSearchWindowController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < results.count else { return nil }
        let item = results[row]

        let cellIdentifier = NSUserInterfaceItemIdentifier("SearchResultCell")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView {
            cell = reused
        } else {
            cell = makeResultCellView(identifier: cellIdentifier)
        }

        // Configure
        let typeIcon: String
        switch item.type {
        case .clip:
            typeIcon = "📋"
        case .snippet:
            typeIcon = "📝"
        }

        cell.textField?.stringValue = "\(typeIcon)  \(item.title)"

        if let subtitleField = cell.viewWithTag(100) as? NSTextField {
            subtitleField.stringValue = item.subtitle
            subtitleField.isHidden = item.subtitle.isEmpty
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row < results.count else { return 32 }
        let item = results[row]
        return item.subtitle.isEmpty ? 28 : 44
    }

    private func makeResultCellView(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        let titleField = NSTextField(labelWithString: "")
        titleField.font = NSFont.systemFont(ofSize: 13)
        titleField.lineBreakMode = .byTruncatingTail
        titleField.maximumNumberOfLines = 1
        titleField.cell?.truncatesLastVisibleLine = true
        titleField.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(titleField)
        cell.textField = titleField

        let subtitleField = NSTextField(labelWithString: "")
        subtitleField.font = NSFont.systemFont(ofSize: 11)
        subtitleField.textColor = .secondaryLabelColor
        subtitleField.lineBreakMode = .byTruncatingTail
        subtitleField.maximumNumberOfLines = 1
        subtitleField.cell?.truncatesLastVisibleLine = true
        subtitleField.translatesAutoresizingMaskIntoConstraints = false
        subtitleField.tag = 100
        cell.addSubview(subtitleField)

        NSLayoutConstraint.activate([
            titleField.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
            titleField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 12),
            titleField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12),

            subtitleField.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 1),
            subtitleField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 36),
            subtitleField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -12)
        ])

        return cell
    }
}
