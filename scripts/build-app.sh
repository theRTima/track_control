#!/bin/bash
# Builds the Swift package and assembles TrackControl.app in ./build
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/TrackControl.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp -f Resources/Info.plist "$APP/Contents/Info.plist"
cp -f .build/release/TrackControl "$APP/Contents/MacOS/TrackControl"

# Signing with a stable identity keeps the Accessibility permission across
# rebuilds; ad-hoc signing gives every build a new identity and macOS forgets
# the grant. See README for creating the local certificate.
IDENTITY="${TRACKCONTROL_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
    IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
        | grep "TrackControl Local Signing" \
        | grep -v "Invalid" \
        | head -1 | awk '{print $2}' || true)
fi

if [ -n "$IDENTITY" ]; then
    codesign --force --sign "$IDENTITY" "$APP"
    echo "Signed with $IDENTITY"
else
    codesign --force --sign - "$APP"
    echo "Signed ad-hoc (Accessibility access has to be granted again after each build)"
fi

echo "Built $APP"
