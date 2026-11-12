#!/bin/bash
# Archives a Release build, signs it for the App Store and uploads it to App Store Connect,
# where it shows up in TestFlight. Runs in the "Release" workflow on a macOS runner.
#
# Needs these environment variables (GitHub repository secrets):
#   APPLE_TEAM_ID   10-character Team ID from developer.apple.com > Account > Membership
#   ASC_KEY_ID      App Store Connect API key ID
#   ASC_ISSUER_ID   App Store Connect API issuer ID
#   ASC_KEY_P8      Contents of the AuthKey_XXXXXXXXXX.p8 file (Admin access)
# Optional: BUILD_NUMBER (defaults to the workflow run number).
set -euo pipefail

missing=""
for name in APPLE_TEAM_ID ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_P8; do
  if [ -z "${!name:-}" ]; then missing="$missing $name"; fi
done
if [ -n "$missing" ]; then
  echo "::error::Missing repository secrets:$missing. See docs/APP_STORE.md, step 4."
  exit 1
fi

BUILD_NUMBER="${BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}"
WORK="${RUNNER_TEMP:-/tmp}/bendcoach-release"
KEY_PATH="$WORK/AuthKey_${ASC_KEY_ID}.p8"
mkdir -p "$WORK"
printf '%s\n' "$ASC_KEY_P8" > "$KEY_PATH"
trap 'rm -f "$KEY_PATH"' EXIT

# Lets Xcode create the signing certificate, App ID and profile through the API key.
AUTH=(-allowProvisioningUpdates
      -authenticationKeyPath "$KEY_PATH"
      -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID")

echo "Archiving BendCoach, build $BUILD_NUMBER"
xcodebuild archive \
  -project BendCoach.xcodeproj \
  -scheme BendCoach \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "$WORK/BendCoach.xcarchive" \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  "${AUTH[@]}"

cat > "$WORK/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>teamID</key><string>$APPLE_TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST

echo "Signing and uploading to App Store Connect"
xcodebuild -exportArchive \
  -archivePath "$WORK/BendCoach.xcarchive" \
  -exportOptionsPlist "$WORK/ExportOptions.plist" \
  -exportPath "$WORK/export" \
  "${AUTH[@]}"

echo "Uploaded build $BUILD_NUMBER. It appears in App Store Connect > TestFlight after Apple processes it (usually 5 to 30 minutes)."
