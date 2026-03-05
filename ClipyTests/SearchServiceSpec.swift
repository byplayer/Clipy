import Foundation
import Cocoa
import Quick
import Nimble
import RealmSwift
@testable import Clipy

class SearchServiceSpec: QuickSpec {
    override func spec() {
        beforeEach {
            Realm.Configuration.defaultConfiguration.inMemoryIdentifier = NSUUID().uuidString
        }

        describeEmptyQuery()
        describeSearchWithQuery()
        describeSearchResultTypes()
        describeTextTruncation()
        describeFullContent()

        afterEach {
            let realm = try! Realm()
            realm.transaction { realm.deleteAll() }
        }
    }
}

// MARK: - Empty Query
extension SearchServiceSpec {
    func describeEmptyQuery() {
        describe("search with empty query") {
            it("returns empty array when no clips or snippets exist") {
                let service = SearchService()
                let results = service.search(query: "")
                expect(results).to(beEmpty())
            }

            it("returns clips in updateTime descending order") {
                self.createClip(with: "oldest clip", index: 0)
                self.createClip(with: "newest clip", index: 1)

                let service = SearchService()
                let results = service.search(query: "")
                expect(results.count).to(equal(2))
                expect(results.first?.title).to(equal("newest clip"))
                expect(results.last?.title).to(equal("oldest clip"))
            }

            it("returns at most 100 clips") {
                for idx in 0..<105 {
                    self.createClip(with: "clip \(idx)", index: idx)
                }

                let service = SearchService()
                let results = service.search(query: "")
                expect(results.count).to(equal(100))
            }
        }
    }
}

// MARK: - Search With Query
extension SearchServiceSpec {
    func describeSearchWithQuery() {
        describe("search with query") {
            it("returns clips matching title") {
                self.createClip(with: "hello world", index: 0)
                self.createClip(with: "goodbye world", index: 1)

                let service = SearchService()
                let results = service.search(query: "hello")
                expect(results.count).to(equal(1))
                expect(results.first?.title).to(equal("hello world"))
            }

            it("returns snippets matching title") {
                self.createSnippet(title: "my snippet", content: "some content")

                let service = SearchService()
                let results = service.search(query: "snippet")
                expect(results.count).to(equal(1))
                expect(results.first?.title).to(equal("my snippet"))
            }

            it("returns snippets matching content even if title does not match") {
                self.createSnippet(title: "title", content: "special keyword here")

                let service = SearchService()
                let results = service.search(query: "keyword")
                expect(results.count).to(equal(1))
                expect(results.first?.title).to(equal("title"))
            }

            it("sorts results by score descending") {
                self.createClip(with: "abc", index: 0)
                self.createClip(with: "xabc", index: 1)

                let service = SearchService()
                let results = service.search(query: "abc")
                expect(results.count).to(equal(2))
                // "abc" has prefix bonus, "xabc" does not
                expect(results.first?.title).to(equal("abc"))
            }

            it("limits results to 100") {
                for idx in 0..<105 {
                    self.createClip(with: "match \(idx)", index: idx)
                }

                let service = SearchService()
                let results = service.search(query: "match")
                expect(results.count).to(equal(100))
            }

            it("excludes disabled snippets") {
                self.createSnippet(title: "enabled snippet", content: "content", snippetEnabled: true)
                self.createSnippet(title: "disabled snippet", content: "content", snippetEnabled: false)

                let service = SearchService()
                let results = service.search(query: "snippet")
                expect(results.count).to(equal(1))
                expect(results.first?.title).to(equal("enabled snippet"))
            }

            it("excludes snippets in disabled folders") {
                self.createSnippet(title: "visible snippet", content: "content", folderEnabled: true)
                self.createSnippet(title: "hidden snippet", content: "content", folderEnabled: false)

                let service = SearchService()
                let results = service.search(query: "snippet")
                expect(results.count).to(equal(1))
                expect(results.first?.title).to(equal("visible snippet"))
            }

            it("returns empty array when nothing matches") {
                self.createClip(with: "hello world", index: 0)

                let service = SearchService()
                let results = service.search(query: "xyz")
                expect(results).to(beEmpty())
            }
        }
    }
}

// MARK: - Search Result Types
extension SearchServiceSpec {
    func describeSearchResultTypes() {
        describe("search result types") {
            it("clip results have clip type") {
                self.createClip(with: "test clip", index: 0)

                let service = SearchService()
                let results = service.search(query: "test")
                expect(results.first?.type).to(equal(SearchResultType.clip))
            }

            it("snippet results have snippet type") {
                self.createSnippet(title: "test snippet", content: "content")

                let service = SearchService()
                let results = service.search(query: "test")
                expect(results.first?.type).to(equal(SearchResultType.snippet))
            }

            it("clip primaryKey is set to dataHash") {
                self.createClip(with: "test clip", index: 0)

                let service = SearchService()
                let results = service.search(query: "test")
                expect(results.first?.primaryKey).toNot(beEmpty())
            }

            it("snippet primaryKey is set to identifier") {
                self.createSnippet(title: "test snippet", content: "content")

                let service = SearchService()
                let results = service.search(query: "test")
                let realm = try! Realm()
                let snippet = realm.objects(CPYSnippet.self).first
                expect(results.first?.primaryKey).to(equal(snippet?.identifier))
            }
        }
    }
}

// MARK: - Text Truncation
extension SearchServiceSpec {
    func describeTextTruncation() {
        describe("text truncation") {
            it("truncates long snippet content to 50 chars with ellipsis") {
                let longContent = String(repeating: "a", count: 80)
                self.createSnippet(title: "long content snippet", content: longContent)

                let service = SearchService()
                let results = service.search(query: "long")
                expect(results.first?.subtitle.count).to(equal(53))
                expect(results.first?.subtitle.hasSuffix("...")).to(beTrue())
            }

            it("does not truncate short snippet content") {
                self.createSnippet(title: "short content snippet", content: "short text")

                let service = SearchService()
                let results = service.search(query: "short")
                expect(results.first?.subtitle).to(equal("short text"))
            }

            it("clip subtitle is always empty") {
                let longTitle = String(repeating: "x", count: 200)
                self.createClip(with: longTitle, index: 0)

                let service = SearchService()
                let results = service.search(query: "xxx")
                expect(results.first?.subtitle).to(equal(""))
            }

            it("replaces newlines with spaces in clip title") {
                self.createClip(with: "line one\nline two\nline three", index: 0)

                let service = SearchService()
                let results = service.search(query: "line")
                expect(results.first?.title).to(equal("line one line two line three"))
            }

            it("replaces newlines with spaces in snippet content preview") {
                self.createSnippet(title: "multiline snippet", content: "first\nsecond\nthird")

                let service = SearchService()
                let results = service.search(query: "multiline")
                expect(results.first?.subtitle).to(equal("first second third"))
            }

            it("snippet content at exactly 50 chars is not truncated") {
                let exact50 = String(repeating: "b", count: 50)
                self.createSnippet(title: "exact snippet", content: exact50)

                let service = SearchService()
                let results = service.search(query: "exact")
                expect(results.first?.subtitle).to(equal(exact50))
                expect(results.first?.subtitle.count).to(equal(50))
            }
        }
    }
}

// MARK: - Full Content
extension SearchServiceSpec {
    func describeFullContent() {
        describe("fullContent") {
            it("preserves newlines in clip fullContent") {
                self.createClip(with: "line one\nline two\nline three", index: 0)

                let service = SearchService()
                let results = service.search(query: "line")
                expect(results.first?.title).to(equal("line one line two line three"))
                expect(results.first?.fullContent).to(equal("line one\nline two\nline three"))
            }

            it("preserves newlines in clip fullContent for empty query") {
                self.createClip(with: "first\nsecond", index: 0)

                let service = SearchService()
                let results = service.search(query: "")
                expect(results.first?.fullContent).to(equal("first\nsecond"))
            }

            it("returns full snippet content without truncation") {
                let longContent = String(repeating: "a", count: 80)
                self.createSnippet(title: "long snippet", content: longContent)

                let service = SearchService()
                let results = service.search(query: "long")
                expect(results.first?.subtitle.count).to(equal(53))
                expect(results.first?.fullContent).to(equal(longContent))
                expect(results.first?.fullContent.count).to(equal(80))
            }

            it("preserves newlines in snippet fullContent") {
                self.createSnippet(title: "multiline", content: "line1\nline2\nline3")

                let service = SearchService()
                let results = service.search(query: "multiline")
                expect(results.first?.subtitle).to(equal("line1 line2 line3"))
                expect(results.first?.fullContent).to(equal("line1\nline2\nline3"))
            }

            it("returns short clip content as-is in fullContent") {
                self.createClip(with: "short", index: 0)

                let service = SearchService()
                let results = service.search(query: "short")
                expect(results.first?.fullContent).to(equal("short"))
            }

            it("returns (Empty) for empty clip fullContent") {
                self.createClip(with: "", index: 0)

                let service = SearchService()
                let results = service.search(query: "")
                expect(results.first?.fullContent).to(equal("(Empty)"))
            }
        }
    }
}

// MARK: - Helpers
extension SearchServiceSpec {
    func createClip(with string: String, index: Int = 0) {
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

    func createSnippet(title: String, content: String, folderEnabled: Bool = true, snippetEnabled: Bool = true) {
        let realm = try! Realm()

        let folder = CPYFolder()
        folder.title = "Test Folder"
        folder.enable = folderEnabled
        folder.identifier = NSUUID().uuidString

        let snippet = CPYSnippet()
        snippet.title = title
        snippet.content = content
        snippet.enable = snippetEnabled
        snippet.identifier = NSUUID().uuidString

        realm.transaction {
            realm.add(folder, update: .all)
            folder.snippets.append(snippet)
        }
    }
}
