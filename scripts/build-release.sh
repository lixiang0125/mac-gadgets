#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INFO_PLIST="$PROJECT_DIR/Packaging/Info.plist"
APP_DIR="$PROJECT_DIR/dist/Mac Gadgets.app"
RELEASE_DIR="$PROJECT_DIR/release"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
DMG_PATH="$RELEASE_DIR/Mac-Gadgets-$VERSION.dmg"
swift "$PROJECT_DIR/scripts/update-release-docs.swift" --validate
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mac-gadgets-release.XXXXXX")"

cleanup() {
    rm -R "$STAGING_DIR"
}
trap cleanup EXIT

"$PROJECT_DIR/scripts/build-app.sh"
codesign --verify --deep --strict "$APP_DIR"

mkdir -p "$RELEASE_DIR"
ditto "$APP_DIR" "$STAGING_DIR/Mac Gadgets.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "Mac Gadgets $VERSION" \
    -srcfolder "$STAGING_DIR" \
    -format UDZO \
    -ov \
    "$DMG_PATH"

hdiutil verify "$DMG_PATH"
swift "$PROJECT_DIR/scripts/update-release-docs.swift" --write
swift "$PROJECT_DIR/scripts/update-release-docs.swift" --check

echo "$DMG_PATH"
