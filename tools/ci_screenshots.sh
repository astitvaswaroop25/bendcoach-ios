#!/bin/bash
# Builds the app, runs it in the iOS Simulator in demo mode and screenshots each screen.
# Used by the "screenshots" CI job (add [screenshots] to a commit message to run it).
# Screenshots land in ./screenshots and are also printed to the log as base64 JPEGs.
set -euo pipefail

BUNDLE_ID="com.astitvaswaroop.bendcoach"
OUT="screenshots"
SCREENS=(home offset offset:results stub90:results threePointSaddle:results fourPointSaddle:results
         backToBack:results rollingOffset:results guided benders level saved settings paywall)

UDID=$(xcrun simctl list devices available --json | python3 -c '
import json, sys
best = ""
for runtime, devices in json.load(sys.stdin)["devices"].items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        name = device["name"]
        if name.startswith("iPhone") and "Plus" not in name and "Max" not in name and "SE" not in name:
            best = device["udid"]
print(best)
')
if [ -z "$UDID" ]; then
  echo "No iPhone simulator found" >&2
  xcrun simctl list devices available
  exit 1
fi
echo "Using simulator $UDID"

xcodebuild build \
  -project BendCoach.xcodeproj \
  -scheme BendCoach \
  -configuration Debug \
  -destination "id=$UDID" \
  -derivedDataPath build/DerivedData \
  -quiet
APP="build/DerivedData/Build/Products/Debug-iphonesimulator/BendCoach.app"

xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 || true
xcrun simctl install "$UDID" "$APP"

mkdir -p "$OUT"
first=1
for screen in "${SCREENS[@]}"; do
  name="${screen//:/-}"
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -demoScreen "$screen" >/dev/null
  if [ "$first" = 1 ]; then sleep 10; first=0; else sleep 5; fi
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$name.png" >/dev/null
  sips -Z 760 -s format jpeg -s formatOptions 55 "$OUT/$name.png" --out "$OUT/$name.jpg" >/dev/null
  echo "SCREENSHOT-BEGIN $name"
  base64 -b 76 -i "$OUT/$name.jpg"
  echo "SCREENSHOT-END $name"
done
echo "Took ${#SCREENS[@]} screenshots"
