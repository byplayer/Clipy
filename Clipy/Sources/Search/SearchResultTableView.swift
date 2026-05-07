//
//  SearchResultTableView.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa

final class SearchResultTableView: NSTableView {

    var onEnterKeyPressed: (() -> Void)?
    var onEscapeKeyPressed: (() -> Void)?
    var onDeleteKeyPressed: (() -> Void)?
    var onTabKeyPressed: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        // Return (36) or numpad Enter (76)
        if event.keyCode == 36 || event.keyCode == 76 {
            onEnterKeyPressed?()
            return
        }
        // Escape (53)
        if event.keyCode == 53 {
            onEscapeKeyPressed?()
            return
        }
        // Delete/Backspace (51) or Forward Delete (117)
        if event.keyCode == 51 || event.keyCode == 117 {
            onDeleteKeyPressed?()
            return
        }
        // Tab (48)
        if event.keyCode == 48 {
            onTabKeyPressed?()
            return
        }
        super.keyDown(with: event)
    }
}
