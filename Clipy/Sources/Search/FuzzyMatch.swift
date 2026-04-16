//
//  FuzzyMatch.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2018 Clipy Project.
//
//  FuzzyMatchV2 algorithm ported from junegunn/fzf
//  https://github.com/junegunn/fzf
//

import Foundation

struct FuzzyMatchResult {
    let score: Int
    let matchedIndices: [Int]
}

// MARK: - fzf Scoring Constants

private let scoreMatch: Int = 16
private let scoreGapStart: Int = -3
private let scoreGapExtension: Int = -1
private let bonusBoundary: Int = scoreMatch / 2            // 8
private let bonusBoundaryWhite: Int = bonusBoundary + 2    // 10
private let bonusNonWord: Int = scoreMatch / 2             // 8
private let bonusCamel123: Int = bonusBoundary - 1         // 7
private let bonusConsecutive: Int = -(scoreGapStart + scoreGapExtension) // 4
private let bonusFirstCharMultiplier: Int = 2

// MARK: - Character Classification

private enum CharClass {
    case white
    case nonWord
    case delimiter
    case lower
    case upper
    case letter
    case number
}

private func classifyChar(_ char: Character) -> CharClass {
    if char.isWhitespace {
        return .white
    }
    if char.isNumber {
        return .number
    }
    if char.isLetter {
        if char.isUppercase { return .upper }
        if char.isLowercase { return .lower }
        return .letter
    }
    switch char {
    case "/", "-", "_", ".", ",", ";", ":", "(", ")", "[", "]", "{", "}":
        return .delimiter
    default:
        return .nonWord
    }
}

private func isWordClass(_ cls: CharClass) -> Bool {
    switch cls {
    case .lower, .upper, .letter, .number:
        return true
    default:
        return false
    }
}

// MARK: - Bonus Matrix

private func bonusFor(prevClass: CharClass, currentClass: CharClass) -> Int {
    if isWordClass(currentClass) {
        switch prevClass {
        case .white:
            return bonusBoundaryWhite
        case .delimiter:
            return bonusBoundary
        case .nonWord:
            return bonusBoundary
        default:
            break
        }
        // camelCase / number transitions
        if prevClass == .lower && currentClass == .upper {
            return bonusCamel123
        }
        if prevClass == .letter && currentClass == .upper {
            return bonusCamel123
        }
        if prevClass == .number && currentClass != .number {
            return bonusCamel123
        }
        if currentClass == .number && prevClass != .number && isWordClass(prevClass) {
            return bonusCamel123
        }
    }

    if currentClass == .nonWord || currentClass == .delimiter {
        return bonusNonWord
    }

    return 0
}

// MARK: - Public API

func fuzzyMatch(query: String, target: String) -> FuzzyMatchResult? {
    guard !query.isEmpty, !target.isEmpty else { return nil }

    let words = query.split(separator: " ").map(String.init)
    guard !words.isEmpty else { return nil }

    if words.count > 1 {
        var totalScore = 0
        var allIndices = [Int]()
        for word in words {
            guard let result = fuzzyMatchSingle(query: word, target: target) else {
                return nil
            }
            totalScore += result.score
            allIndices.append(contentsOf: result.matchedIndices)
        }
        return FuzzyMatchResult(score: totalScore, matchedIndices: allIndices.sorted())
    }

    return fuzzyMatchSingle(query: query, target: target)
}

// MARK: - FuzzyMatchV2 Core
// swiftlint:disable function_body_length cyclomatic_complexity

private func fuzzyMatchSingle(query: String, target: String) -> FuzzyMatchResult? {
    guard !query.isEmpty, !target.isEmpty else { return nil }

    let queryChars = Array(query)
    let targetChars = Array(target)
    let patternLen = queryChars.count
    let textLen = targetChars.count

    // Smart case: if query has any uppercase letter, match case-sensitively
    let caseSensitive = queryChars.contains(where: { $0.isUppercase })

    // --- Phase 1: Forward scan to find if all pattern chars exist & find end bound ---
    var endIdx = -1
    var queryIdx = 0
    var textIdx = 0
    while textIdx < textLen {
        if charsEqual(queryChars[queryIdx], targetChars[textIdx], caseSensitive: caseSensitive) {
            queryIdx += 1
            if queryIdx == patternLen {
                endIdx = textIdx
                break
            }
        }
        textIdx += 1
    }
    guard queryIdx == patternLen else { return nil }

    // --- Phase 1b: Reverse scan to find start bound ---
    var startIdx = endIdx
    queryIdx = patternLen - 1
    textIdx = endIdx
    while textIdx >= 0 {
        if charsEqual(queryChars[queryIdx], targetChars[textIdx], caseSensitive: caseSensitive) {
            startIdx = textIdx
            queryIdx -= 1
            if queryIdx < 0 { break }
        }
        textIdx -= 1
    }

    let width = endIdx - startIdx + 1

    // --- Phase 2: Precompute bonuses ---
    var bonuses = [Int](repeating: 0, count: width)
    var prevCls: CharClass = startIdx == 0 ? .white : classifyChar(targetChars[startIdx - 1])
    for idx in 0..<width {
        let curCls = classifyChar(targetChars[startIdx + idx])
        bonuses[idx] = bonusFor(prevClass: prevCls, currentClass: curCls)
        prevCls = curCls
    }

    // --- Phase 3: DP ---
    // scoreMatrix[row][col] = best score matching query[0..row] ending at target position startIdx+col
    // consMatrix[row][col] = consecutive match count at that position

    var scoreMatrix = [[Int]](repeating: [Int](repeating: 0, count: width), count: patternLen)
    var consMatrix = [[Int]](repeating: [Int](repeating: 0, count: width), count: patternLen)
    var fromMatch = [[Bool]](repeating: [Bool](repeating: false, count: width), count: patternLen)

    for row in 0..<patternLen {
        var inGap = false
        for col in 0..<width {
            let textPos = startIdx + col
            let isMatch = charsEqual(queryChars[row], targetChars[textPos], caseSensitive: caseSensitive)

            // Score from diagonal (match)
            var matchScore = Int.min
            if isMatch {
                var diag = 0
                var consecutive = 0
                if row > 0 && col > 0 {
                    diag = scoreMatrix[row - 1][col - 1]
                    consecutive = consMatrix[row - 1][col - 1]
                } else if row == 0 {
                    diag = 0
                } else {
                    diag = Int.min / 2
                }

                if diag > Int.min / 2 {
                    consecutive += 1
                    var bonus = bonuses[col]
                    if consecutive > 1 {
                        bonus = max(bonus, max(bonusConsecutive, bonuses[col - consecutive + 1]))
                    }
                    if row == 0 {
                        bonus *= bonusFirstCharMultiplier
                    }
                    matchScore = diag + scoreMatch + bonus
                }
            }

            // Score from left (gap in target)
            var gapScore = Int.min
            if col > 0 {
                let penalty = inGap ? scoreGapExtension : scoreGapStart
                let leftScore = scoreMatrix[row][col - 1]
                if leftScore > Int.min / 2 {
                    gapScore = leftScore + penalty
                }
            }

            let best = max(max(matchScore, gapScore), 0)
            scoreMatrix[row][col] = best

            if matchScore > gapScore && matchScore > 0 && isMatch {
                consMatrix[row][col] = (row > 0 && col > 0) ? consMatrix[row - 1][col - 1] + 1 : 1
                fromMatch[row][col] = true
                inGap = false
            } else {
                consMatrix[row][col] = 0
                fromMatch[row][col] = false
                inGap = (best == gapScore && gapScore > 0)
            }
        }
    }

    // --- Phase 3b: Find best score in last row ---
    var bestScore = 0
    var bestCol = -1
    let lastRow = scoreMatrix[patternLen - 1]
    for col in 0..<width where lastRow[col] > bestScore {
        bestScore = lastRow[col]
        bestCol = col
    }

    guard bestScore > 0, bestCol >= 0 else { return nil }

    // --- Phase 4: Backtrace to find matched indices ---
    var matchedIndices = [Int]()
    var row = patternLen - 1
    var col = bestCol
    while row >= 0 && col >= 0 {
        if fromMatch[row][col] {
            matchedIndices.append(startIdx + col)
            row -= 1
            col -= 1
        } else {
            col -= 1
        }
    }
    matchedIndices.reverse()

    guard matchedIndices.count == patternLen else { return nil }

    return FuzzyMatchResult(score: bestScore, matchedIndices: matchedIndices)
}

// swiftlint:enable function_body_length cyclomatic_complexity

// MARK: - Helpers

private func charsEqual(_ lhs: Character, _ rhs: Character, caseSensitive: Bool) -> Bool {
    if caseSensitive {
        return lhs == rhs
    }
    return lhs.lowercased() == rhs.lowercased()
}
