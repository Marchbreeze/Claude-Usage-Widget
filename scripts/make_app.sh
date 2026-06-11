#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --arch arm64 --arch x86_64

APP=build/ClaudeUsageWidget.app
rm -rf "$APP" build/AppIcon.iconset
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/AppIcon.iconset

BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/ClaudeUsageWidget
cp "$BIN" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"

base64 -d < assets/AppIcon.png.b64 > build/AppIcon.png
for s in 16 32 128 256 512; do
  sips -z $s $s build/AppIcon.png --out "build/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) build/AppIcon.png --out "build/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force -s - "$APP"
ditto -c -k --keepParent "$APP" build/ClaudeUsageWidget.zip
echo "Built: build/ClaudeUsageWidget.zip"
