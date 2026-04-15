import Foundation
import Quick
import Nimble
@testable import Clipy

class FuzzyMatchSpec: QuickSpec {
    override func spec() {

        describe("fuzzyMatch") {
            it("returns high score for exact match") {
                let result = fuzzyMatch(query: "hello", target: "hello")
                expect(result).toNot(beNil())
                expect(result!.score).to(beGreaterThan(20))
                expect(result!.matchedIndices).to(equal([0, 1, 2, 3, 4]))
            }

            it("matches partial characters") {
                let result = fuzzyMatch(query: "hwr", target: "hello world")
                expect(result).toNot(beNil())
                expect(result!.matchedIndices).to(contain(0))
            }

            it("gives consecutive match bonus") {
                let consecutive = fuzzyMatch(query: "hel", target: "hello")
                let nonConsecutive = fuzzyMatch(query: "hlo", target: "hello")
                expect(consecutive).toNot(beNil())
                expect(nonConsecutive).toNot(beNil())
                expect(consecutive!.score).to(beGreaterThan(nonConsecutive!.score))
            }

            it("gives word boundary bonus") {
                let result = fuzzyMatch(query: "hw", target: "hello world")
                expect(result).toNot(beNil())
                // 'w' is at word boundary (after space)
                expect(result!.matchedIndices).to(equal([0, 6]))
            }

            it("gives prefix bonus") {
                let prefixMatch = fuzzyMatch(query: "he", target: "hello")
                let nonPrefixMatch = fuzzyMatch(query: "he", target: "the hello")
                expect(prefixMatch).toNot(beNil())
                expect(nonPrefixMatch).toNot(beNil())
                expect(prefixMatch!.score).to(beGreaterThan(nonPrefixMatch!.score))
            }

            it("returns nil for non-matching query") {
                let result = fuzzyMatch(query: "xyz", target: "hello world")
                expect(result).to(beNil())
            }

            it("returns nil for empty query") {
                let result = fuzzyMatch(query: "", target: "hello")
                expect(result).to(beNil())
            }

            it("returns nil for empty target") {
                let result = fuzzyMatch(query: "hello", target: "")
                expect(result).to(beNil())
            }

            it("matches case insensitively") {
                let result = fuzzyMatch(query: "ABC", target: "abc")
                expect(result).toNot(beNil())
                expect(result!.matchedIndices).to(equal([0, 1, 2]))
            }

            it("matches Japanese characters") {
                let result = fuzzyMatch(query: "こん", target: "こんにちは")
                expect(result).toNot(beNil())
                expect(result!.matchedIndices).to(equal([0, 1]))
            }

            context("multi-word query (space-separated)") {
                it("matches when all words are found in URL") {
                    let result = fuzzyMatch(query: "example dd", target: "https://example.com/abc/zzzz-ddee")
                    expect(result).toNot(beNil())
                }

                it("matches when all words are found in URL with different word order") {
                    let result = fuzzyMatch(query: "example zz", target: "https://example.com/abc/zzzz-ddee")
                    expect(result).toNot(beNil())
                }

                it("returns nil when one word does not match") {
                    let result = fuzzyMatch(query: "example xyz", target: "https://example.com/abc/zzzz-ddee")
                    expect(result).to(beNil())
                }

                it("matches single word query as before") {
                    let result = fuzzyMatch(query: "example", target: "https://example.com/abc/zzzz-ddee")
                    expect(result).toNot(beNil())
                }

                it("combines scores from all matched words") {
                    let singleWord = fuzzyMatch(query: "example", target: "https://example.com/abc/zzzz-ddee")
                    let multiWord = fuzzyMatch(query: "example dd", target: "https://example.com/abc/zzzz-ddee")
                    expect(singleWord).toNot(beNil())
                    expect(multiWord).toNot(beNil())
                    expect(multiWord!.score).to(beGreaterThan(singleWord!.score))
                }

                it("ignores extra spaces between words") {
                    let result = fuzzyMatch(query: "example   dd", target: "https://example.com/abc/zzzz-ddee")
                    expect(result).toNot(beNil())
                }
            }
        }
    }
}
