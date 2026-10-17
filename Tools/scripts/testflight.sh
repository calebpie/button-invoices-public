#!/bin/bash
# Builds the app for the App Store, signs it with the paid team and uploads it to App
# Store Connect, where it reaches TestFlight once Apple has processed it (README,
# "TestFlight"). Each upload gets a new build number, the UTC date and time
# (20261017.1530), so builds sort in the order they were made.
# UPLOAD=0 makes the same signed package in build/testflight without uploading it.
# Usage: testflight.sh <project> <build dir>
set -euo pipefail
cd "$(dirname "$0")/../.."
PROJECT=$1
OUT=$2/testflight

TEAM=$(sed -n 's/^DEVELOPMENT_TEAM *= *//p' Configs/Signing.xcconfig)
if [ -z "$TEAM" ]; then
    echo "Configs/Signing.xcconfig has no team. Run make setup (README, \"First-time setup\", step 4)."
    exit 1
fi

# The seed is gitignored, and the app loads it once, on first launch: a build without it
# would open on her iPhone with no business details, buttons or sent invoices.
for file in business.json catalog.json invoices.json; do
    if [ ! -f "App/Resources/Seed/$file" ]; then
        echo "App/Resources/Seed/$file is missing. Run make seed first (README, \"Commands\")."
        exit 1
    fi
done

# So each build she installs matches a commit.
if [ -n "$(git status --porcelain)" ] && [ -z "${ALLOW_DIRTY:-}" ]; then
    echo "Uncommitted changes:"
    git status --short
    echo "Commit them first, so the build matches a commit (or ALLOW_DIRTY=1 to build anyway)."
    exit 1
fi

BUILD=$(date -u +%Y%m%d.%H%M)
COMMIT=$(git rev-parse --short HEAD)
ARCHIVE="$OUT/ButtonInvoices $BUILD.xcarchive"
mkdir -p "$OUT"

echo "Building $BUILD from commit $COMMIT"
xcodebuild -project "$PROJECT" -scheme ButtonInvoices -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates CURRENT_PROJECT_VERSION="$BUILD" -quiet archive

if [ "${UPLOAD:-1}" = 0 ]; then DESTINATION=export; else DESTINATION=upload; fi
cat > "$OUT/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>$DESTINATION</string>
    <key>teamID</key>
    <string>$TEAM</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF

xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$OUT/ExportOptions.plist" \
    -exportPath "$OUT/$BUILD" -allowProvisioningUpdates

if [ "$DESTINATION" = upload ]; then
    echo "Uploaded build $BUILD (commit $COMMIT). It appears in App Store Connect → Apps →"
    echo "the app → TestFlight once Apple has processed it, usually within 15 minutes."
    echo "Record it in Docs/progress.md: build $BUILD, commit $COMMIT, expires 90 days after upload."
else
    echo "Signed, not uploaded: $OUT/$BUILD (build $BUILD, commit $COMMIT)."
fi
