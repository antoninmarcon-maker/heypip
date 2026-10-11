#!/bin/bash
# Builds a signed, notarized Pip.zip ready for a GitHub release.
#
# Signing uses Xcode's cloud-managed Developer ID (the team's Account Holder signed in to Xcode → Settings → Accounts):
# no certificate is needed on this Mac. Notarization uses a keychain profile, created once with an App Store Connect
# API key:  xcrun notarytool store-credentials heypip --key AuthKey_XXXX.p8 --key-id XXXX --issuer <issuer-id>
#
#   bash release.sh            (TEAM_ID and NOTARY_PROFILE can override the defaults)
set -euo pipefail
cd "$(dirname "$0")"
TEAM_ID="${TEAM_ID:-93UZLJAMCN}"
PROFILE="${NOTARY_PROFILE:-heypip}"
BUILD=build/release
rm -rf "$BUILD" Pip.zip
command -v xcodegen >/dev/null || { echo "xcodegen missing: brew install xcodegen"; exit 1; }
xcodegen generate --quiet

xcodebuild -project Pip.xcodeproj -scheme Pip -configuration Release -destination "generic/platform=macOS" \
  -archivePath "$BUILD/Pip.xcarchive" archive -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM_ID" -quiet
cat > "$BUILD/export.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>export</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$BUILD/Pip.xcarchive" -exportPath "$BUILD/export" \
  -exportOptionsPlist "$BUILD/export.plist" -allowProvisioningUpdates -quiet
APP="$BUILD/export/Pip.app"
codesign --verify --deep --strict --verbose=2 "$APP"

ditto -c -k --keepParent "$APP" "$BUILD/Pip-notarize.zip"
xcrun notarytool submit "$BUILD/Pip-notarize.zip" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose "$APP"
ditto -c -k --keepParent "$APP" Pip.zip
echo "→ $(pwd)/Pip.zip (signed, notarized, stapled)"
