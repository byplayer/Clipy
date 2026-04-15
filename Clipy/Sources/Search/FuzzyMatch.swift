//
//  FuzzyMatch.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation

struct FuzzyMatchResult {
    let score: Int
    let matchedIndices: [Int]
}

func fuzzyMatch(query: String, target: String) -> FuzzyMatchResult? {
    guard !query.isEmpty, !target.isEmpty else { return nil }

    // Split query by spaces into words, ignoring empty strings from extra spaces
    let words = query.split(separator: " ").map(String.init)
    guard !words.isEmpty else { return nil }

    // If multiple words, match each independently and combine results
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

private func fuzzyMatchSingle(query: String, target: String) -> FuzzyMatchResult? {
    guard !query.isEmpty, !target.isEmpty else { return nil }

    let queryChars = Array(query.lowercased())
    let targetLower = target.lowercased()
    let targetChars = Array(targetLower)
    let targetOriginal = Array(target)

    var matchedIndices = [Int]()
    var queryIndex = 0

    for (targetIdx, char) in targetChars.enumerated() {
        if queryIndex < queryChars.count && char == queryChars[queryIndex] {
            matchedIndices.append(targetIdx)
            queryIndex += 1
        }
    }

    guard queryIndex == queryChars.count else { return nil }

    // Scoring
    var score = 0
    let boundaryChars: Set<Character> = [" ", "_", "-", ".", "/"]

    for (i, idx) in matchedIndices.enumerated() {
        // Base match score
        score += 1

        // Consecutive match bonus
        if i > 0 && idx == matchedIndices[i - 1] + 1 {
            score += 3
        }

        // Word boundary bonus
        if idx == 0 || boundaryChars.contains(Character(String(targetOriginal[idx - 1]))) {
            score += 5
        }

        // Prefix bonus (first character matches target's first character)
        if i == 0 && idx == 0 {
            score += 10
        }

        // Gap penalty
        if i > 0 {
            let gap = idx - matchedIndices[i - 1] - 1
            if gap > 0 {
                score -= gap
            }
        }
    }

    return FuzzyMatchResult(score: score, matchedIndices: matchedIndices)
}
