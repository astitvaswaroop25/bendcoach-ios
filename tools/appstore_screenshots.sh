#!/bin/bash
# Takes full-resolution App Store screenshots in the simulator, in demo mode:
#   6.9" iPhone: iPhone 16 Pro Max, 1320 x 2868
#   13" iPad:    iPad Pro 13-inch (M4), 2064 x 2752
# plus the paywall for the in-app purchase review screenshot. Output: build/appstore/*.png
# and build/BendCoach-AppStore-screenshots.zip. Used by the "App Store screenshots" workflow.
set -euo pipefail

BUNDLE_ID="com.astitvaswaroop.bendcoach"
OUT="build/appstore"
IPHONE="iPhone 16 Pro Max"
IPAD="iPad Pro 13-inch (M4)"
IPHONE_SCREENS=(guided threePointSaddle:results offset:results keypad level home)
IPAD_SCREENS=(threePointSaddle:results guided home level saved)

# Prints the UDID of the named simulator, creating it if this machine doesn't have one.
device() {
  local udid
  udid=$(xcrun simctl list devices available --json | python3 -c '
import json, sys
for runtime, devices in json.load(sys.stdin)["devices"].items():
    if "iOS" in runtime:
        for device in devices:
            if device["name"] == sys.argv[1]:
                print(device["udid"])
                sys.exit()
' "$1")
  if [ -z "$udid" ]; then
    udid=$(xcrun simctl create "$1" "$1")
  fi
  echo "$udid"
}

prepare() {
  xcrun simctl boot "$1" || true
  xcrun simctl bootstatus "$1" -b
  xcrun simctl ui "$1" appearance light
  xcrun simctl status_bar "$1" override --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularMode active --cellularBars 4 --wifiBars 3 || true
  xcrun simctl install "$1" "$APP"
}

# shoot <udid> <prefix> <screens...>: saves <prefix>-01-<screen>.png and so on.
shoot() {
  local udid="$1" prefix="$2" n=1
  shift 2
  for screen in "$@"; do
    local name
    name=$(printf "%s-%02d-%s" "$prefix" "$n" "${screen//:/-}")
    xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch "$udid" "$BUNDLE_ID" -demoScreen "$screen" >/dev/null
    sleep 6
    xcrun simctl io "$udid" screenshot --type=png "$OUT/$name.png" >/dev/null 2>&1
    echo "$name $(sips -g pixelWidth -g pixelHeight "$OUT/$name.png" | awk '/pixel/ {printf "%s ", $2}')"
    n=$((n + 1))
  done
}

PHONE_ID=$(device "$IPHONE")
PAD_ID=$(device "$IPAD")
echo "iPhone: $PHONE_ID  iPad: $PAD_ID"

xcodebuild build \
  -project BendCoach.xcodeproj \
  -scheme BendCoach \
  -configuration Debug \
  -destination "id=$PHONE_ID" \
  -derivedDataPath build/DerivedData \
  -quiet
APP="build/DerivedData/Build/Products/Debug-iphonesimulator/BendCoach.app"

rm -rf "$OUT"
mkdir -p "$OUT"

prepare "$PHONE_ID"
sleep 8
shoot "$PHONE_ID" iphone "${IPHONE_SCREENS[@]}"
shoot "$PHONE_ID" iap-review paywall:store
xcrun simctl shutdown "$PHONE_ID" || true

prepare "$PAD_ID"
sleep 8
shoot "$PAD_ID" ipad "${IPAD_SCREENS[@]}"

(cd "$OUT" && zip -q ../BendCoach-AppStore-screenshots.zip ./*.png)
echo "Saved $(ls "$OUT"/*.png | wc -l | tr -d ' ') screenshots"
