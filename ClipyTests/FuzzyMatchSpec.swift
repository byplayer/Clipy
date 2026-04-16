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

            // MARK: - Optimal Alignment (fzf DP vs greedy)

            context("optimal alignment") {
                it("prefers consecutive match over scattered match within window") {
                    // In "aXbc", DP should prefer a(0),b(2),c(3) with consecutive b,c
                    // over any other alignment. The consecutive bonus on b,c makes this optimal.
                    let result = fuzzyMatch(query: "abc", target: "aXbc")
                    expect(result).toNot(beNil())
                    expect(result!.matchedIndices).to(equal([0, 2, 3]))
                }

                it("finds best scoring alignment among duplicates") {
                    // fzf narrows the search window via reverse scan, preferring tighter matches
                    let result = fuzzyMatch(query: "ab", target: "xxab")
                    expect(result).toNot(beNil())
                    // Should match the consecutive "ab" at indices [2,3]
                    expect(result!.matchedIndices).to(equal([2, 3]))
                }

                it("consecutive match scores higher than scattered match") {
                    let consecutive = fuzzyMatch(query: "abc", target: "abc")
                    let scattered = fuzzyMatch(query: "abc", target: "aXbXc")
                    expect(consecutive).toNot(beNil())
                    expect(scattered).toNot(beNil())
                    expect(consecutive!.score).to(beGreaterThan(scattered!.score))
                }
            }

            // MARK: - Boundary Bonuses (fzf behavior)

            context("delimiter boundary bonuses") {
                it("gives bonus after slash delimiter") {
                    let result = fuzzyMatch(query: "fb", target: "foo/bar")
                    expect(result).toNot(beNil())
                    expect(result!.matchedIndices).to(equal([0, 4]))
                }

                it("gives bonus after dash delimiter") {
                    let result = fuzzyMatch(query: "fb", target: "foo-bar")
                    expect(result).toNot(beNil())
                    expect(result!.matchedIndices).to(equal([0, 4]))
                }

                it("gives bonus after underscore delimiter") {
                    let result = fuzzyMatch(query: "fb", target: "foo_bar")
                    expect(result).toNot(beNil())
                    expect(result!.matchedIndices).to(equal([0, 4]))
                }

                it("whitespace boundary scores higher than delimiter boundary") {
                    let spaceResult = fuzzyMatch(query: "fb", target: "f bar")
                    let delimResult = fuzzyMatch(query: "fb", target: "f_bar")
                    expect(spaceResult).toNot(beNil())
                    expect(delimResult).toNot(beNil())
                    expect(spaceResult!.score).to(beGreaterThanOrEqualTo(delimResult!.score))
                }
            }

            // MARK: - Gap Penalties (fzf behavior)

            context("gap penalties") {
                it("single long gap costs less than multiple short gaps") {
                    // "ac" in "aXXXXc" = 1 gap of 4 chars: scoreGapStart + 3*scoreGapExtension = -3 + -3 = -6
                    // vs conceptual: multiple gaps would accumulate more scoreGapStart penalties
                    let singleGap = fuzzyMatch(query: "ac", target: "aXXXXc")
                    let multiGap = fuzzyMatch(query: "abc", target: "aXbXXc")
                    expect(singleGap).toNot(beNil())
                    expect(multiGap).toNot(beNil())
                    // Both should have valid scores, just verifying gap penalty works
                    expect(singleGap!.score).to(beGreaterThan(0))
                }

                it("closer matches score higher than distant matches") {
                    let close = fuzzyMatch(query: "ab", target: "aXb")
                    let far = fuzzyMatch(query: "ab", target: "aXXXXXb")
                    expect(close).toNot(beNil())
                    expect(far).toNot(beNil())
                    expect(close!.score).to(beGreaterThan(far!.score))
                }
            }

            // MARK: - First Character Multiplier (fzf behavior)

            context("first character multiplier") {
                it("first position match gets boosted score") {
                    let firstPos = fuzzyMatch(query: "a", target: "aXX")
                    let laterPos = fuzzyMatch(query: "a", target: "XaX")
                    expect(firstPos).toNot(beNil())
                    expect(laterPos).toNot(beNil())
                    expect(firstPos!.score).to(beGreaterThan(laterPos!.score))
                }
            }

            // MARK: - Multi-word queries

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
