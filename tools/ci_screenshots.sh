#!/bin/bash
# Builds the app, runs it in the iOS Simulator in demo mode and screenshots each screen:
# iPhone in light mode, dark mode and accessibility text sizes, then iPad.
# Used by the "screenshots" CI job (add [screenshots] to a commit message to run it).
# Screenshots land in ./screenshots and are also printed to the log as base64 JPEGs.
set -euo pipefail

BUNDLE_ID="com.astitvaswaroop.bendcoach"
OUT="screenshots"
PHONE_SCREENS=(home offset offset:results stub90:results threePointSaddle:results fourPointSaddle:results
               backToBack:results rollingOffset:results guided benders keypad level saved settings paywall)
DARK_SCREENS=(home offset:results threePointSaddle:results guided keypad level saved settings paywall)
AX_SCREENS=(home offset offset:results threePointSaddle:results guided benders keypad level saved settings paywall)
IPAD_SCREENS=(home threePointSaddle:results guided benders keypad level saved settings paywall)
IPAD_DARK_SCREENS=(home offset:results saved)

# Prints the UDID of an available simulator: "phone" picks a regular-size iPhone,
# "pad" an 11-inch iPad if there is one.
pick_device() {
  xcrun simctl list devices available --json | python3 -c '
import json, sys
kind = sys.argv[1]
best, fallback = "", ""
for runtime, devices in json.load(sys.stdin)["devices"].items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        name = device["name"]
        if kind == "phone":
            if name.startswith("iPhone") and not any(x in name for x in ("Plus", "Max", "SE", "mini")):
                best = device["udid"]
        elif name.startswith("iPad") and "mini" not in name:
            fallback = device["udid"]
            if "11-inch" in name or "(11" in name:
                best = device["udid"]
print(best or fallback)
' "$1"
}

boot() {
  xcrun simctl boot "$1" || true
  xcrun simctl bootstatus "$1" -b
  xcrun simctl status_bar "$1" override --time "9:41" --batteryState charged --batteryLevel 100 || true
  xcrun simctl install "$1" "$APP"
}

# shoot <udid> <name prefix> <screens...>
first=1
shoot() {
  local udid="$1" prefix="$2"
  shift 2
  for screen in "$@"; do
    local name="$prefix-${screen//:/-}"
    xcrun simctl terminate "$udid" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch "$udid" "$BUNDLE_ID" -demoScreen "$screen" >/dev/null
    if [ "$first" = 1 ]; then sleep 10; first=0; else sleep 5; fi
    xcrun simctl io "$udid" screenshot --type=png "$OUT/$name.png" >/dev/null
    sips -Z 900 -s format jpeg -s formatOptions 55 "$OUT/$name.png" --out "$OUT/$name.jpg" >/dev/null
    echo "SCREENSHOT-BEGIN $name"
    base64 -b 76 -i "$OUT/$name.jpg"
    echo "SCREENSHOT-END $name"
  done
}

PHONE=$(pick_device phone)
PAD=$(pick_device pad)
if [ -z "$PHONE" ]; then
  echo "No iPhone simulator found" >&2
  xcrun simctl list devices available
  exit 1
fi
echo "Using iPhone simulator $PHONE and iPad simulator ${PAD:-none}"

xcodebuild build \
  -project BendCoach.xcodeproj \
  -scheme BendCoach \
  -configuration Debug \
  -destination "id=$PHONE" \
  -derivedDataPath build/DerivedData \
  -quiet
APP="build/DerivedData/Build/Products/Debug-iphonesimulator/BendCoach.app"

mkdir -p "$OUT"
boot "$PHONE"
xcrun simctl ui "$PHONE" appearance light
shoot "$PHONE" phone "${PHONE_SCREENS[@]}"

xcrun simctl ui "$PHONE" appearance dark
shoot "$PHONE" dark "${DARK_SCREENS[@]}"

xcrun simctl ui "$PHONE" appearance light
xcrun simctl ui "$PHONE" content_size accessibility-extra-large
shoot "$PHONE" ax "${AX_SCREENS[@]}"
xcrun simctl ui "$PHONE" content_size large
xcrun simctl shutdown "$PHONE" || true

if [ -n "$PAD" ]; then
  first=1
  boot "$PAD"
  xcrun simctl ui "$PAD" appearance light
  shoot "$PAD" ipad "${IPAD_SCREENS[@]}"
  xcrun simctl ui "$PAD" appearance dark
  shoot "$PAD" ipad-dark "${IPAD_DARK_SCREENS[@]}"
fi
echo "Took $(ls "$OUT"/*.jpg | wc -l | tr -d ' ') screenshots"
