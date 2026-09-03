#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$PROJECT_DIR/dist/Mac Gadgets.app"
CONTENTS_DIR="$APP_DIR/Contents"
ICON_ARTWORK="$PROJECT_DIR/Packaging/AppIcon.png"
ICON_SOURCE="$PROJECT_DIR/.build/AppIcon-Prepared.png"
ICONSET_DIR="$PROJECT_DIR/.build/AppIcon.iconset"

cd "$PROJECT_DIR"
swift build -c release

if [[ -d "$APP_DIR" ]]; then
    rm -rf "$APP_DIR"
fi

mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$PROJECT_DIR/.build/release/MacGadgets" "$CONTENTS_DIR/MacOS/MacGadgets"
cp "$PROJECT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"
cp -R "$PROJECT_DIR/locale" "$CONTENTS_DIR/Resources/locale"
chmod +x "$CONTENTS_DIR/MacOS/MacGadgets"

swift "$PROJECT_DIR/scripts/prepare-app-icon.swift" "$ICON_ARTWORK" "$ICON_SOURCE"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$ICON_SOURCE" "$ICONSET_DIR/icon_512x512@2x.png"
iconutil -c icns "$ICONSET_DIR" -o "$CONTENTS_DIR/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP_DIR"
touch "$APP_DIR"
echo "$APP_DIR"
