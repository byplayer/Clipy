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
    var results = [SearchResultItem]()
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

    private lazy var tableView: SearchResultTableView = {
        let table = SearchResultTableView()
        table.headerView = nil
        table.rowHeight = 32
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.backgroundColor = .clear
        table.delegate = self
        table.dataSource = self
        table.target = self
        table.action = #selector(tableViewSingleClicked)
        table.doubleAction = #selector(tableViewDoubleClicked)
        table.onEnterKeyPressed = { [weak self] in
            self?.selectCurrentItem()
        }
        table.onEscapeKeyPressed = { [weak self] in
            self?.closeSearchWindow()
        }
        table.onDeleteKeyPressed = { [weak self] in
            self?.deleteCurrentItem()
        }
        table.onTabKeyPressed = { [weak self] in
            guard let self = self else { return }
            self.panel.makeFirstResponder(self.searchField)
        }

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ResultColumn"))
        column.width = 580
        table.addTableColumn(column)

        return table
    }()

    private lazy var previewPanel: NSPanel = {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = .canJoinAllSpaces
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = NSColor.windowBackgroundColor
        return panel
    }()

    private lazy var previewTextView: NSTextView = {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        return textView
    }()

    private lazy var previewScrollView: NSScrollView = {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.borderType = .noBorder
        scroll.documentView = previewTextView
        return scroll
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
        setupPreviewPanel()
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

    private func setupPreviewPanel() {
        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        previewPanel.contentView = contentView
        contentView.addSubview(previewScrollView)

        NSLayoutConstraint.activate([
            previewScrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            previewScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            previewScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            previewScrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
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
        previewPanel.orderOut(nil)
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
        updatePreview()
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
                if AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.reorderClipsAfterPasting) {
                    realm.transaction {
                        clip.updateTime = Int(Date().timeIntervalSince1970)
                    }
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

    // MARK: - Deletion
    private func deleteCurrentItem() {
        let row = tableView.selectedRow
        guard row >= 0 && row < results.count else {
            NSSound.beep()
            return
        }
        let item = results[row]
        guard item.type == .clip else {
            NSSound.beep()
            return
        }

        let realm = try! Realm()
        guard let clip = realm.object(ofType: CPYClip.self, forPrimaryKey: item.primaryKey) else {
            NSSound.beep()
            return
        }
        AppEnvironment.current.clipService.delete(with: clip)

        results.remove(at: row)
        tableView.reloadData()

        if results.isEmpty {
            previewPanel.orderOut(nil)
            panel.makeFirstResponder(searchField)
        } else {
            let nextRow = min(row, results.count - 1)
            tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
            tableView.scrollRowToVisible(nextRow)
            updatePreview()
        }
    }

    // MARK: - Preview
    private func needsPreview(_ item: SearchResultItem) -> Bool {
        let content = item.fullContent
        if content == "(Image)" || content == "(PDF)" || content == "(Filenames)" || content == "(Empty)" {
            return false
        }
        if content.contains("\n") || content.contains("\r") {
            return true
        }
        // Check if content is long enough to be truncated in the table
        if content.count > 80 {
            return true
        }
        return false
    }

    func updatePreview() {
        let row = tableView.selectedRow
        guard row >= 0 && row < results.count else {
            previewPanel.orderOut(nil)
            return
        }

        let item = results[row]
        guard needsPreview(item) else {
            previewPanel.orderOut(nil)
            return
        }

        previewTextView.string = item.fullContent

        // Position preview panel to the right of main panel
        let mainFrame = panel.frame
        let previewX = mainFrame.maxX + 4
        let previewFrame = NSRect(x: previewX, y: mainFrame.origin.y, width: 400, height: mainFrame.height)
        previewPanel.setFrame(previewFrame, display: true)

        if !previewPanel.isVisible {
            previewPanel.orderFront(nil)
        }

        // Scroll to top
        previewTextView.scrollToBeginningOfDocument(nil)
    }

    // MARK: - Actions
    @objc private func tableViewSingleClicked() {
        selectCurrentItem()
    }

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
        if commandSelector == #selector(NSResponder.insertTab(_:)) {
            if !results.isEmpty {
                if tableView.selectedRow < 0 {
                    tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                }
                panel.makeFirstResponder(tableView)
            }
            return true
        }
        return false
    }
}
