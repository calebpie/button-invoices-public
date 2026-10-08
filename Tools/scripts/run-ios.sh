#!/bin/bash
# Builds the app for the iPhone (or iPad) connected to this Mac, installs it and opens it.
# Usage: run-ios.sh "<project>" "<derived data dir>" "<path to built .app>"
#        DEVICE=<UDID or name> picks one device when several are connected.
#
# The build names that device, so Xcode can register it with the signing team and make a
# provisioning profile for it. A free Personal Team has no profile until a device is
# registered; building for "any iPhone" failed with "Your team has no devices"
# (Caleb, Oct 8, 2026).
set -euo pipefail

PROJECT="$1"
BUILD_DIR="$2"
APP="$3"

# Xcode 27's device list includes the simulators, also "paired"; only real devices count.
LIST=$(mktemp)
trap 'rm -f "$LIST"' EXIT
xcrun devicectl list devices --json-output "$LIST" >/dev/null
FOUND=$(python3 -I - "$LIST" "${DEVICE:-}" <<'EOF'
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
wanted = sys.argv[2]

def get(d, *path):
    for key in path:
        d = d.get(key, {}) if isinstance(d, dict) else {}
    return d if d != {} else None

def find_key(d, word):
    """The first value whose key contains `word`, anywhere in the device's record."""
    if isinstance(d, dict):
        for key, value in d.items():
            if word in key.lower() and not isinstance(value, dict):
                return value
            found = find_key(value, word)
            if found is not None:
                return found
    return None

real = []
for d in devices:
    hardware = get(d, "properties", "hardware") or d.get("hardwareProperties", {})
    connection = get(d, "properties", "connection") or d.get("connectionProperties", {})
    name = get(d, "properties", "state", "name") or get(d, "deviceProperties", "name") or "?"
    if hardware.get("reality") != "physical" or hardware.get("platform") != "iOS":
        continue
    if connection.get("pairingState") != "paired":
        continue
    if wanted and wanted not in (hardware.get("udid"), d.get("identifier"), name):
        continue
    real.append((hardware.get("deviceType") != "iPhone", name, hardware.get("udid"), d.get("identifier"),
                 str(find_key(d, "developermode") or "").lower()))

if real:
    real.sort()
    _, name, udid, identifier, developer_mode = real[0]
    print(f"{udid}\t{identifier}\t{developer_mode}\t{name}")
EOF
)

if [ -z "$FOUND" ]; then
    echo "No iPhone or iPad found. Connect it to this Mac with a cable, unlock it, and tap"
    echo "Trust if it asks (README, \"Installing on her iPhone or iPad\")."
    exit 1
fi
IFS=$'\t' read -r UDID IDENTIFIER DEVELOPER_MODE NAME <<<"$FOUND"
echo "Building for $NAME"
# Not a stop: the switch only appears on the device once Xcode has talked to it, which
# this build does.
if [ "$DEVELOPER_MODE" = "disabled" ]; then
    echo "Developer Mode is off on $NAME, so it won't open the app. On the device:"
    echo "Settings → Privacy & Security → Developer Mode → on, restart it, confirm, then run"
    echo "make ios again."
fi

xcodebuild -project "$PROJECT" -scheme ButtonInvoices -configuration Debug \
    -derivedDataPath "$BUILD_DIR" -destination "id=$UDID" \
    -allowProvisioningUpdates -allowProvisioningDeviceRegistration -quiet build

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")
xcrun devicectl device install app --device "$IDENTIFIER" "$APP"
if ! xcrun devicectl device process launch --device "$IDENTIFIER" "$BUNDLE_ID"; then
    echo
    echo "Installed, but $NAME refused to open it. On a first install, trust the developer:"
    echo "  Settings → General → VPN & Device Management → your Apple ID → Trust"
    echo "then open Invoices from the Home Screen."
    exit 1
fi
