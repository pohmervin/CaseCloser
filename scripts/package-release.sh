#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROJECT_DIR=${SCRIPT_DIR:h}
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Support/Info.plist")
ARCHIVE="$PROJECT_DIR/dist/CaseCloser-$VERSION-macOS.zip"

"$PROJECT_DIR/scripts/build-app.sh"
rm -f "$ARCHIVE"
ditto -c -k --sequesterRsrc --keepParent "$PROJECT_DIR/dist/CaseCloser.app" "$ARCHIVE"
echo "$ARCHIVE"
