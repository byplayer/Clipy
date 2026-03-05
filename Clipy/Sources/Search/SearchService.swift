//
//  SearchService.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation
import Cocoa
import RealmSwift

final class SearchService {

    // MARK: - Properties
    private let maxResults = 20

    // MARK: - Search
    func search(query: String) -> [SearchResultItem] {
        let realm = try! Realm()

        if query.isEmpty {
            return emptyQueryResults(realm: realm)
        }

        return fuzzySearchResults(query: query, realm: realm)
    }

    // MARK: - Empty Query (show recent clips)
    private func emptyQueryResults(realm: Realm) -> [SearchResultItem] {
        let clips = realm.objects(CPYClip.self).sorted(byKeyPath: "updateTime", ascending: false)
        var results = [SearchResultItem]()

        for clip in clips {
            guard results.count < maxResults else { break }
            let title = clipTitle(for: clip)
            let item = SearchResultItem(
                type: .clip,
                primaryKey: clip.dataHash,
                title: title,
                subtitle: "",
                score: 0,
                matchedIndices: []
            )
            results.append(item)
        }

        return results
    }

    // MARK: - Fuzzy Search
    private func fuzzySearchResults(query: String, realm: Realm) -> [SearchResultItem] {
        var results = [SearchResultItem]()

        // Search clips
        let clips = realm.objects(CPYClip.self).sorted(byKeyPath: "updateTime", ascending: false)
        for clip in clips {
            let title = clipTitle(for: clip)
            if let matchResult = fuzzyMatch(query: query, target: title) {
                let item = SearchResultItem(
                    type: .clip,
                    primaryKey: clip.dataHash,
                    title: title,
                    subtitle: "",
                    score: matchResult.score,
                    matchedIndices: matchResult.matchedIndices
                )
                results.append(item)
            }
        }

        // Search snippets
        let folders = realm.objects(CPYFolder.self).filter("enable == true")
        for folder in folders {
            let snippets = folder.snippets.filter("enable == true")
            for snippet in snippets {
                let titleMatch = fuzzyMatch(query: query, target: snippet.title)
                let contentMatch = fuzzyMatch(query: query, target: snippet.content)

                // Take the higher score
                var bestScore: Int?
                var bestIndices = [Int]()

                if let titleResult = titleMatch {
                    bestScore = titleResult.score
                    bestIndices = titleResult.matchedIndices
                }
                if let contentResult = contentMatch, contentResult.score > (bestScore ?? Int.min) {
                    bestScore = contentResult.score
                    bestIndices = contentResult.matchedIndices
                }

                guard let score = bestScore else { continue }

                let singleLine = snippet.content.components(separatedBy: .newlines).joined(separator: " ")
                let contentPreview: String
                if singleLine.count > 50 {
                    contentPreview = String(singleLine.prefix(50)) + "..."
                } else {
                    contentPreview = singleLine
                }

                let item = SearchResultItem(
                    type: .snippet,
                    primaryKey: snippet.identifier,
                    title: snippet.title,
                    subtitle: contentPreview,
                    score: score,
                    matchedIndices: bestIndices
                )
                results.append(item)
            }
        }

        // Sort by score descending, limit to maxResults
        results.sort { $0.score > $1.score }
        return Array(results.prefix(maxResults))
    }

    // MARK: - Helpers
    private func clipTitle(for clip: CPYClip) -> String {
        let primaryPboardType = NSPasteboard.PasteboardType(rawValue: clip.primaryType)
        if primaryPboardType == .deprecatedTIFF {
            return "(Image)"
        } else if primaryPboardType == .deprecatedPDF {
            return "(PDF)"
        } else if primaryPboardType == .deprecatedFilenames && clip.title.isEmpty {
            return "(Filenames)"
        }
        let title = clip.title.isEmpty ? "(Empty)" : clip.title
        return title.components(separatedBy: .newlines).joined(separator: " ")
    }
}
