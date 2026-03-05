//
//  SearchResultItem.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation

enum SearchResultType: Equatable {
    case clip
    case snippet
}

struct SearchResultItem {
    let type: SearchResultType
    let primaryKey: String
    let title: String
    let subtitle: String
    let score: Int
    let matchedIndices: [Int]
}
