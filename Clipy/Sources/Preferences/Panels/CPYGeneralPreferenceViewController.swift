//
//  CPYGeneralPreferenceViewController.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa
import AEXML

final class CPYGeneralPreferenceViewController: NSViewController {

    // MARK: - IBActions
    @IBAction private func exportHistoryButtonTapped(_ sender: Any) {
        let exportXml = AppEnvironment.current.clipService.exportClipboard()

        let panel = NSSavePanel()
        panel.allowedFileTypes = [Constants.HistoryXml.fileType]
        panel.allowsOtherFileTypes = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        panel.nameFieldStringValue = "clipy_history"
        let returnCode = panel.runModal()

        if returnCode != .OK { return }

        guard let data = exportXml.xml.data(using: .utf8) else { return }
        guard let url = panel.url else { return }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            NSSound.beep()
        }
    }

    @IBAction private func importHistoryButtonTapped(_ sender: Any) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        panel.allowedFileTypes = [Constants.HistoryXml.fileType]
        let returnCode = panel.runModal()

        if returnCode != .OK { return }

        let fileURLs = panel.urls
        guard let url = fileURLs.first else { return }
        guard let data = try? Data(contentsOf: url) else { return }

        do {
            let xmlDocument = try AEXMLDocument(xml: data)
            AppEnvironment.current.clipService.importClipboard(with: xmlDocument)
            showImportCompletionAlert()
        } catch {
            NSSound.beep()
        }
    }

    private func showImportCompletionAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.importCompleted
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
