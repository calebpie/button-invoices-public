#!/bin/bash
# Installs and launches a built app in the iOS Simulator, booting the simulator if needed.
# Usage: run-sim.sh "<path to .app>" "<simulator name>"
set -euo pipefail

APP="$1"
NAME="${2:-iPhone 15 Pro Max}"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")

find_udid() {
    xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
for runtime, devices in json.load(sys.stdin)["devices"].items():
    for d in devices:
        if d["name"] == name and "iOS" in runtime:
            print(d["udid"]); sys.exit()
' "$NAME"
}

UDID=$(find_udid)

# Xcode lists some device models without a simulator made for them (her iPhone 15 Pro Max
# in Xcode 27). Make one with the newest iOS the Mac has.
if [ -z "$UDID" ]; then
    TYPE=$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
for t in json.load(sys.stdin)["devicetypes"]:
    if t["name"] == sys.argv[1]: print(t["identifier"])
' "$NAME")
    RUNTIME=$(xcrun simctl list runtimes available -j | python3 -c '
import json, sys
ios = [r for r in json.load(sys.stdin)["runtimes"] if r["platform"] == "iOS"]
if ios: print(max(ios, key=lambda r: [int(p) for p in r["version"].split(".")])["identifier"])
')
    if [ -n "$TYPE" ] && [ -n "$RUNTIME" ]; then
        echo "Making a \"$NAME\" simulator ($RUNTIME)"
        xcrun simctl create "$NAME" "$TYPE" "$RUNTIME" >/dev/null && UDID=$(find_udid)
    fi
fi

if [ -z "$UDID" ]; then
    echo "No simulator named \"$NAME\". Available:"
    xcrun simctl list devices available | grep -E "iPhone|iPad"
    exit 1
fi

xcrun simctl boot "$UDID" 2>/dev/null || true
# Show the device. Xcode 27 replaced the Simulator app with Device Hub; earlier Xcodes
# still have Simulator. The app installs and runs either way.
if open -b com.apple.iphonesimulator --args -CurrentDeviceUDID "$UDID" 2>/dev/null; then :
elif open -b com.apple.dt.Devices 2>/dev/null; then echo "Opened Device Hub; select $NAME in its sidebar if it isn't shown."
else echo "Couldn't open Simulator or Device Hub; the app is still installed and launched."
fi
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" "$BUNDLE_ID"
