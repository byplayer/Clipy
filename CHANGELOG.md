# Changelog

## [2.2.1] - 2026-04-16

### Refactoring

- Fix swiftlint `for_where` violations in FuzzyMatch.swift by converting to `while` loops and `where` clauses
- Fix swiftlint `function_body_length` violation by splitting FuzzyMatchSpec into FuzzyMatchBasicSpec and FuzzyMatchScoringSpec

## [2.2.0] - 2026-04-16

### Features

- Replace fuzzy matching algorithm with fzf's FuzzyMatchV2 (ported from junegunn/fzf)
  - Dynamic programming based optimal alignment instead of greedy matching
  - Smart case: case-insensitive when query is all lowercase, case-sensitive when query contains uppercase
  - Improved scoring with camelCase bonus, word boundary bonus, and first character multiplier
  - fzf-compatible scoring constants (scoreMatch=16, bonusBoundary=8, bonusCamel123=7, etc.)

## [2.1.0] - 2026-04-15

### Features

- Support multi-word fuzzy match queries in search window

### Bug Fixes

- Enable single-click to paste from search dialog

## [2.0.1] - 2026-03-26

### Bug Fixes

- Fix incremental search paste not reordering clipboard history to match history menu behavior
- Remove ad-hoc re-signing in install script to preserve macOS accessibility permission across reinstalls
- Upgrade realm-swift from v10 to v20 to fix build failure with Xcode 26.4

## [2.0.0] - 2026-03-09

### Features

- Add fuzzy search window for clips and snippets
- Add preview panel in search window and increase max results to 100
- Add clipboard history export/import with import completion alert

### Improvements

- Migrate CocoaPods to Swift Package Manager
- Raise macOS deployment target to 11.0
- Update runner to macOS 15 and use default Xcode
- Fix deprecated APIs and resolve build warnings
- Remove Ruby toolchain (Fastlane, Danger, Bundler)
- Remove Fabric/Crashlytics that has ended service
- Update dependency libraries for M1 native build
- Update dependency libraries for Reactive Extensions and global hotkeys
- Build with Swift 5.2 / Xcode 12.2
- Fix spacing between "Export clipboard history" section and status bar icon in General preferences

### Bug Fixes

- Fix CI test failure and newline handling in search results
- Fix status bar item to use variableLength
- Embed RealmSwift framework and fix install script
- Resolve Xcode build phase issues for SPM migration
- Fix xcodebuild command syntax in CI
- Fix an issue where whitespace was removed when importing snippets

## [1.2.1] - 2018-10-15

- Update LoginServiceKit.framework
