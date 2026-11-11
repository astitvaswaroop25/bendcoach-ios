#!/bin/bash
# Builds an unsigned Debug BendCoach.ipa for installing on your own iPhone with Sideloadly or
# AltStore, which sign it with your Apple ID. Debug builds include Settings → Developer →
# "Unlock Pro" so Pro screens can be tested without a purchase.
set -euo pipefail

xcodebuild build \
  -project BendCoach.xcodeproj \
  -scheme BendCoach \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  -quiet \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  ENABLE_DEBUG_DYLIB=NO \
  ENABLE_PREVIEWS=NO

APP="build/DerivedData/Build/Products/Debug-iphoneos/BendCoach.app"
test -d "$APP"

rm -rf build/ipa build/BendCoach.ipa
mkdir -p build/ipa/Payload
cp -R "$APP" build/ipa/Payload/
(cd build/ipa && zip -qry ../BendCoach.ipa Payload)
ls -lh build/BendCoach.ipa
