#!/bin/bash
# Installs and launches a built iPhone app on the connected iPhone.
# Usage: install-ios.sh "<path to .app>"   (DEVICE=<identifier> to pick a phone)
set -euo pipefail

APP="$1"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")

DEVICE="${DEVICE:-}"
if [ -z "$DEVICE" ]; then
    LIST=$(mktemp)
    xcrun devicectl list devices --json-output "$LIST" >/dev/null
    DEVICE=$(python3 - "$LIST" <<'EOF'
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
phones = [d for d in devices
          if d.get("hardwareProperties", {}).get("deviceType") == "iPhone"
          and d.get("connectionProperties", {}).get("pairingState") == "paired"]
if phones:
    print(phones[0]["identifier"])
EOF
)
    rm -f "$LIST"
fi

if [ -z "$DEVICE" ]; then
    echo "No paired iPhone found. Connect it with a cable, unlock it, and tap Trust if asked."
    echo "Devices Xcode can see:"
    xcrun devicectl list devices
    exit 1
fi

xcrun devicectl device install app --device "$DEVICE" "$APP"
if ! xcrun devicectl device process launch --device "$DEVICE" "$BUNDLE_ID"; then
    echo
    echo "Installed, but the iPhone refused to launch it. On a first install, trust the developer:"
    echo "  iPhone Settings → General → VPN & Device Management → your Apple ID → Trust"
    exit 1
fi
