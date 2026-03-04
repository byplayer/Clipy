#!/bin/bash
set -xe -o pipefail

PROJECT="Clipy.xcodeproj"
SCHEME="Clipy"
APP_NAME="Clipy"
BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/archive.xcarchive"

IGNORE_LINT=false
DRY_RUN=false
SKIP_TEST=false

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --ignore-lint) IGNORE_LINT=true ;;
        --dry-run) DRY_RUN=true ;;
        --skip-test) SKIP_TEST=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# --- Lint ---
if [ "$IGNORE_LINT" = false ]; then
    if command -v swiftlint &> /dev/null; then
        swiftlint --fix --format
        swiftlint --quiet --strict
    else
        echo "swiftlint could not be found. Please rerun the script as \`./install.sh --ignore-lint\`."
        echo "To install swiftlint, run \`brew install swiftlint\`"
        exit 1
    fi
else
    echo "Skipping swiftlint checks due to --ignore-lint option."
fi

# --- Test ---
if [ "$SKIP_TEST" = false ]; then
    if command -v xcpretty &> /dev/null; then
        xcodebuild test -project "$PROJECT" -scheme "$SCHEME" | xcpretty
    else
        xcodebuild test -project "$PROJECT" -scheme "$SCHEME"
    fi
else
    echo "Skipping tests due to --skip-test option."
fi

# --- Build (Archive) ---
if command -v xcpretty &> /dev/null; then
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" clean archive -archivePath "$ARCHIVE_PATH" | xcpretty
else
    echo "xcpretty could not be found. Proceeding without xcpretty."
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" clean archive -archivePath "$ARCHIVE_PATH"
fi

# --- Install ---
APP_SRC="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app"

if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN: Would execute the following commands:"
    echo "  rm -rf /Applications/${APP_NAME}.app"
    echo "  cp -r ${APP_SRC} /Applications/"
    echo "  pkill ${APP_NAME} (if running)"
    echo "  open /Applications/${APP_NAME}.app"
    echo "Build completed successfully. Use without --dry-run to actually install."
else
    rm -rf "/Applications/${APP_NAME}.app"
    cp -r "$APP_SRC" /Applications/
    pkill "$APP_NAME" || true
    open "/Applications/${APP_NAME}.app"
fi
