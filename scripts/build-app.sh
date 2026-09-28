#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
APP_NAME="CaseCloser"
APP_BUNDLE="$PROJECT_DIR/dist/$APP_NAME.app"
ICON_SOURCE="$PROJECT_DIR/Assets/CaseCloserIcon.png"
ICONSET_DIR="$PROJECT_DIR/.build/CaseCloser.iconset"
ICNS_FILE="$PROJECT_DIR/.build/CaseCloser.icns"

cd "$PROJECT_DIR"
swift build -c release --arch arm64 --arch x86_64 --product CaseCloser
BIN_DIR=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)

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
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_FILE"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BIN_DIR/CaseCloser" "$APP_BUNDLE/Contents/MacOS/CaseCloser"
cp "$PROJECT_DIR/Support/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$ICNS_FILE" "$APP_BUNDLE/Contents/Resources/CaseCloser.icns"
chmod +x "$APP_BUNDLE/Contents/MacOS/CaseCloser"

codesign --force --deep --sign - "$APP_BUNDLE"
echo "$APP_BUNDLE"
