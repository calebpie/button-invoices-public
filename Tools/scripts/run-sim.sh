#!/bin/bash
# Installs and launches a built app in the iOS Simulator, booting the simulator if needed.
# Usage: run-sim.sh "<path to .app>" "<simulator name>"
set -euo pipefail

APP="$1"
NAME="${2:-iPhone 17}"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
for runtime, devices in json.load(sys.stdin)["devices"].items():
    for d in devices:
        if d["name"] == name and "iOS" in runtime:
            print(d["udid"]); sys.exit()
' "$NAME")

if [ -z "$UDID" ]; then
    echo "No simulator named \"$NAME\". Available:"
    xcrun simctl list devices available | grep -E "iPhone|iPad"
    exit 1
fi

xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator --args -CurrentDeviceUDID "$UDID"
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" "$BUNDLE_ID"
