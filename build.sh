#!/bin/bash
# Builds Pip.app: bash build.sh   (macOS 26+, Xcode 26+ command line tools)
set -euo pipefail
cd "$(dirname "$0")"
APP=Pip.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# universal binary (Apple silicon + Intel), runs on macOS 15+; SpeechAnalyzer is used on macOS 26+
for ARCH in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $ARCH-apple-macos15.0 -parse-as-library Sources/*.swift -o "build-$ARCH" \
    -framework AppKit -framework SwiftUI -framework ScreenCaptureKit -framework Speech -framework AVFoundation -framework CoreMedia
done
lipo -create build-arm64 build-x86_64 -output "$APP/Contents/MacOS/Pip"
rm -f build-arm64 build-x86_64
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
echo "→ $(pwd)/$APP"
