import Foundation
import Quick
import Nimble
@testable import Clipy

class DraggedDataSpec: QuickSpec {
    override func spec() {

        describe("NSCoding") {

            it("Archive data") {
                let draggedData = CPYDraggedData(type: .folder, folderIdentifier: NSUUID().uuidString, snippetIdentifier: nil, index: 10)
                let data = try! NSKeyedArchiver.archivedData(withRootObject: draggedData, requiringSecureCoding: false)

                let unarchiver = try! NSKeyedUnarchiver(forReadingFrom: data)
                unarchiver.requiresSecureCoding = false
                let unarchiveData = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? CPYDraggedData
                unarchiver.finishDecoding()
                expect(unarchiveData).toNot(beNil())
                expect(unarchiveData?.type) == draggedData.type
                expect(unarchiveData?.folderIdentifier) == draggedData.folderIdentifier
                expect(unarchiveData?.snippetIdentifier).to(beNil())
                expect(unarchiveData?.index) == draggedData.index
            }

        }

    }
}
