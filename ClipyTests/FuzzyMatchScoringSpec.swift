import Foundation
import Quick
import Nimble
@testable import Clipy

class FuzzyMatchScoringSpec: QuickSpec {
    override func spec() {
        // MARK: - Optimal Alignment (fzf DP vs greedy)

        describe("fuzzyMatch optimal alignment") {
            it("prefers consecutive match over scattered match within window") {
                let result = fuzzyMatch(query: "abc", target: "aXbc")
                expect(result).toNot(beNil())
                expect(result!.matchedIndices).to(equal([0, 2, 3]))
            }

            it("finds best scoring alignment among duplicates") {
                let result = fuzzyMatch(query: "ab", target: "xxab")
                expect(result).toNot(beNil())
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

        describe("fuzzyMatch delimiter boundary bonuses") {
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

        describe("fuzzyMatch gap penalties") {
            it("single long gap costs less than multiple short gaps") {
                let singleGap = fuzzyMatch(query: "ac", target: "aXXXXc")
                let multiGap = fuzzyMatch(query: "abc", target: "aXbXXc")
                expect(singleGap).toNot(beNil())
                expect(multiGap).toNot(beNil())
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

        describe("fuzzyMatch first character multiplier") {
            it("first position match gets boosted score") {
                let firstPos = fuzzyMatch(query: "a", target: "aXX")
                let laterPos = fuzzyMatch(query: "a", target: "XaX")
                expect(firstPos).toNot(beNil())
                expect(laterPos).toNot(beNil())
                expect(firstPos!.score).to(beGreaterThan(laterPos!.score))
            }
        }

        // MARK: - Multi-word queries

        describe("fuzzyMatch multi-word query (space-separated)") {
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
