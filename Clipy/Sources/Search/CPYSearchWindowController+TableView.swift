//
//  CPYSearchWindowController+TableView.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa

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
            cell = Self.makeResultCellView(identifier: cellIdentifier)
        }

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

    func tableViewSelectionDidChange(_ notification: Notification) {
        updatePreview()
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row < results.count else { return 32 }
        let item = results[row]
        return item.subtitle.isEmpty ? 28 : 44
    }

    static func makeResultCellView(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
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
