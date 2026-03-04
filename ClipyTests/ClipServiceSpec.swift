import Foundation
import Cocoa
import Quick
import Nimble
import RealmSwift
import AEXML
@testable import Clipy

class ClipServiceSpec: QuickSpec {
    override func spec() {

        beforeEach {
            Realm.Configuration.defaultConfiguration.inMemoryIdentifier = NSUUID().uuidString
        }

        describe("Export") {
            it("export clipboard") {
                let clipService = ClipService()
                let noItemXml = clipService.exportClipboard()
                expect(noItemXml[Constants.HistoryXml.rootElement].children.count).to(equal(0))

                (0..<20).forEach { self.createClip(with: "test\($0)", index: $0) }
                let exportXml = clipService.exportClipboard()
                expect(exportXml[Constants.HistoryXml.rootElement].children.count).to(equal(20))
                let firstValue = exportXml[Constants.HistoryXml.rootElement].children.first?[Constants.HistoryXml.contentElement].value
                expect(firstValue).to(equal("test0"))
            }

            it("trim max history size") {
                UserDefaults.standard.set(10, forKey: Constants.UserDefaults.maxHistorySize)
                let clipService = ClipService()
                let noItemXml = clipService.exportClipboard()
                expect(noItemXml[Constants.HistoryXml.rootElement].children.count).to(equal(0))

                (0..<20).forEach { self.createClip(with: "test\($0)", index: $0) }
                let exportXml = clipService.exportClipboard()
                expect(exportXml[Constants.HistoryXml.rootElement].children.count).to(equal(10))
            }

            it("no export empty string") {
                let clipService = ClipService()
                let noItemXml = clipService.exportClipboard()
                expect(noItemXml[Constants.HistoryXml.rootElement].children.count).to(equal(0))

                (0..<20).forEach { self.createClip(with: "test\($0)", index: $0) }
                self.createClip(with: "")
                let exportXml = clipService.exportClipboard()
                expect(exportXml[Constants.HistoryXml.rootElement].children.count).to(equal(20))
            }

            it("ascending") {
                UserDefaults.standard.set(true, forKey: Constants.UserDefaults.reorderClipsAfterPasting)
                let clipService = ClipService()
                let noItemXml = clipService.exportClipboard()
                expect(noItemXml[Constants.HistoryXml.rootElement].children.count).to(equal(0))

                (0..<20).forEach { self.createClip(with: "test\($0)", index: $0) }
                let exportXml = clipService.exportClipboard()
                expect(exportXml[Constants.HistoryXml.rootElement].children.count).to(equal(20))
                let firstValue = exportXml[Constants.HistoryXml.rootElement].children.first?[Constants.HistoryXml.contentElement].value
                expect(firstValue).to(equal("test19"))
            }
        }

        describe("Import") {
            it("Import clipboard") {
                let realm = try! Realm()
                let clips = realm.objects(CPYClip.self)
                expect(clips.count).to(equal(0))

                let clipService = ClipService()
                let xmlDocument = AEXMLDocument()
                let root = xmlDocument.addChild(name: Constants.HistoryXml.rootElement)
                for i in 0..<10 {
                    let history = root.addChild(name: Constants.HistoryXml.historyElement)
                    history.addChild(name: Constants.HistoryXml.contentElement, value: "test\(i)")
                }
                clipService.importClipboard(with: xmlDocument)

                expect(clips.count).toEventually(equal(10), timeout: .seconds(5))
            }
        }

        afterEach {
            UserDefaults.standard.set(30, forKey: Constants.UserDefaults.maxHistorySize)
            UserDefaults.standard.set(false, forKey: Constants.UserDefaults.reorderClipsAfterPasting)
            let realm = try! Realm()
            realm.transaction { realm.deleteAll() }
        }
    }

    private func createClip(with string: String, index: Int = 0) {
        let data = CPYClipData(string: string)
        let unixTime = Int(Date().timeIntervalSince1970) + index
        let savedPath = CPYUtilities.applicationSupportFolder() + "/\(NSUUID().uuidString).data"

        let clip = CPYClip()
        clip.dataPath = savedPath
        clip.title = data.stringValue[0...10000]
        clip.dataHash = "\(data.hash)_\(index)"
        clip.updateTime = unixTime
        clip.primaryType = data.primaryType?.rawValue ?? ""

        guard CPYUtilities.prepareSaveToPath(CPYUtilities.applicationSupportFolder()) else { return }
        if let archivedData = try? NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: false) {
            try? archivedData.write(to: URL(fileURLWithPath: savedPath))
        }
        let realm = try! Realm()
        realm.transaction { realm.add(clip) }
    }
}
