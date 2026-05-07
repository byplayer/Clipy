import Foundation
import Cocoa
import Quick
import Nimble
import RealmSwift
@testable import Clipy

class SearchWindowDeleteSpec: QuickSpec {
    override func spec() {

        beforeEach {
            Realm.Configuration.defaultConfiguration.inMemoryIdentifier = NSUUID().uuidString
        }

        describe("SearchResultTableView keyDown") {
            it("invokes onDeleteKeyPressed when delete (keyCode 51) is pressed") {
                let table = SearchResultTableView()
                var called = false
                table.onDeleteKeyPressed = { called = true }

                let event = self.makeKeyDown(keyCode: 51)
                table.keyDown(with: event)

                expect(called).to(beTrue())
            }

            it("invokes onDeleteKeyPressed when forward delete (keyCode 117) is pressed") {
                let table = SearchResultTableView()
                var called = false
                table.onDeleteKeyPressed = { called = true }

                let event = self.makeKeyDown(keyCode: 117)
                table.keyDown(with: event)

                expect(called).to(beTrue())
            }

            it("invokes onTabKeyPressed when tab (keyCode 48) is pressed") {
                let table = SearchResultTableView()
                var called = false
                table.onTabKeyPressed = { called = true }

                let event = self.makeKeyDown(keyCode: 48)
                table.keyDown(with: event)

                expect(called).to(beTrue())
            }

            it("does not invoke delete callback for unrelated keys") {
                let table = SearchResultTableView()
                var called = false
                table.onDeleteKeyPressed = { called = true }

                // 'a' key
                let event = self.makeKeyDown(keyCode: 0)
                table.keyDown(with: event)

                expect(called).to(beFalse())
            }

            it("invokes onEnterKeyPressed for return key") {
                let table = SearchResultTableView()
                var called = false
                table.onEnterKeyPressed = { called = true }

                let event = self.makeKeyDown(keyCode: 36)
                table.keyDown(with: event)

                expect(called).to(beTrue())
            }

            it("invokes onEscapeKeyPressed for escape key") {
                let table = SearchResultTableView()
                var called = false
                table.onEscapeKeyPressed = { called = true }

                let event = self.makeKeyDown(keyCode: 53)
                table.keyDown(with: event)

                expect(called).to(beTrue())
            }
        }

        describe("ClipService.delete removes clip from history") {
            it("removes the clip from realm") {
                self.createClip(with: "delete me", index: 0)
                self.createClip(with: "keep me", index: 1)

                let realm = try! Realm()
                expect(realm.objects(CPYClip.self).count).to(equal(2))

                guard let target = realm.objects(CPYClip.self).filter("title == 'delete me'").first else {
                    fail("clip not found")
                    return
                }

                ClipService().delete(with: target)

                let titles = realm.objects(CPYClip.self).map { $0.title }
                expect(titles).to(contain("keep me"))
                expect(titles).toNot(contain("delete me"))
                expect(realm.objects(CPYClip.self).count).to(equal(1))
            }
        }

        afterEach {
            let realm = try! Realm()
            realm.transaction { realm.deleteAll() }
        }
    }

    private func makeKeyDown(keyCode: UInt16) -> NSEvent {
        return NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        )!
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

        if CPYUtilities.prepareSaveToPath(CPYUtilities.applicationSupportFolder()) {
            if let archivedData = try? NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: false) {
                try? archivedData.write(to: URL(fileURLWithPath: savedPath))
            }
        }
        let realm = try! Realm()
        realm.transaction { realm.add(clip) }
    }
}
