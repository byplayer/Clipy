import Foundation
import Quick
import Nimble
@testable import Clipy

class FuzzyMatchBasicSpec: QuickSpec {
    override func spec() {
        describe("fuzzyMatch") {
            it("returns high score for exact match") {
                let result = fuzzyMatch(query: "hello", target: "hello")
                expect(result).toNot(beNil())
                expect(result!.score).to(beGreaterThan(50))
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
                expect(result!.matchedIndices).to(equal([0, 6]))
            }

            it("gives prefix bonus") {
                let prefixMatch = fuzzyMatch(query: "he", target: "hello")
                let nonPrefixMatch = fuzzyMatch(query: "he", target: "xhello")
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
                let result = fuzzyMatch(query: "ABC", target: "ABC")
                expect(result).toNot(beNil())
                expect(result!.matchedIndices).to(equal([0, 1, 2]))
            }

            it("matches Japanese characters") {
                let result = fuzzyMatch(query: "こん", target: "こんにちは")
                expect(result).toNot(beNil())
                expect(result!.matchedIndices).to(equal([0, 1]))
            }

            // MARK: - Smart Case (fzf behavior)

            context("smart case") {
                it("all-lowercase query matches case-insensitively") {
                    let result = fuzzyMatch(query: "abc", target: "ABC")
                    expect(result).toNot(beNil())
                    expect(result!.matchedIndices).to(equal([0, 1, 2]))
                }

                it("query with uppercase is case-sensitive and rejects mismatch") {
                    let result = fuzzyMatch(query: "Abc", target: "abc")
                    expect(result).to(beNil())
                }

                it("query with uppercase matches when case matches") {
                    let result = fuzzyMatch(query: "Abc", target: "Abc")
                    expect(result).toNot(beNil())
                    expect(result!.matchedIndices).to(equal([0, 1, 2]))
                }

                it("mixed case query matches exact case in target") {
                    let result = fuzzyMatch(query: "FooBar", target: "FooBar")
                    expect(result).toNot(beNil())
                }

                it("mixed case query rejects wrong case") {
                    let result = fuzzyMatch(query: "FooBar", target: "foobar")
                    expect(result).to(beNil())
                }
            }

            // MARK: - CamelCase Bonus (fzf behavior)

            context("camelCase bonus") {
                it("prefers camelCase boundary match") {
                    let camelResult = fuzzyMatch(query: "fb", target: "fooBar")
                    let noCamelResult = fuzzyMatch(query: "fb", target: "foobxr")
                    expect(camelResult).toNot(beNil())
                    expect(noCamelResult).toNot(beNil())
                    expect(camelResult!.score).to(beGreaterThan(noCamelResult!.score))
                }

                it("matches camelCase with case-sensitive query") {
                    let result = fuzzyMatch(query: "gC", target: "getCursor")
                    expect(result).toNot(beNil())
                    expect(result!.matchedIndices).to(contain(3))
                }
            }
        }
    }
}
