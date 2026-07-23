#!/bin/bash
# Builds APO Equalizer.app directly with swiftc, no Xcode required.
# For local testing/dev only (ad-hoc code signing).
set -euo pipefail

APP_NAME="APO Equalizer"
EXECUTABLE_NAME="APOEqualizer"
BUNDLE_ID="com.ryanghosh.apoequalizer"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$ROOT_DIR/APOEqualizer"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "==> Cleaning $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

echo "==> Compiling Swift sources"
SOURCES=()
while IFS= read -r -d '' file; do
  SOURCES+=("$file")
done < <(find "$SRC_DIR" -name "*.swift" -print0)

xcrun swiftc \
  -o "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME" \
  -parse-as-library \
  -framework SwiftUI \
  -framework AppKit \
  -framework AVFoundation \
  -framework AudioToolbox \
  -framework CoreAudio \
  -framework Combine \
  "${SOURCES[@]}"

echo "==> Writing Info.plist"
cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.music</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>APO Equalizer captures system audio through a virtual loopback device (BlackHole) so it can apply EQ and effects before sending it to your speakers or headphones. No microphone audio is ever recorded or transmitted.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> Code signing (ad-hoc)"
codesign --force --deep --sign - \
  --entitlements "$SRC_DIR/APOEqualizer.entitlements" \
  "$APP_BUNDLE"

echo "==> Done: $APP_BUNDLE"
echo "Run with: open \"$APP_BUNDLE\""
