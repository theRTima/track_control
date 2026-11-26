#!/bin/bash
# Builds the Swift package and assembles TrackControl.app
#   build/TrackControl.app by default, or $TRACKCONTROL_APP_DIR/TrackControl.app
set -euo pipefail
cd "$(dirname "$0")/.."

# Universal: the binary runs on Apple silicon and on Intel Macs.
swift build -c release --arch arm64 --arch x86_64

APP="${TRACKCONTROL_APP_DIR:-build}/TrackControl.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp -f Resources/Info.plist "$APP/Contents/Info.plist"
cp -f Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -f .build/release/TrackControl "$APP/Contents/MacOS/TrackControl"
# Drop local symbols: ~80 KB smaller, and the signature below covers the result.
strip -x "$APP/Contents/MacOS/TrackControl"

# Signing with a stable local identity keeps the Accessibility permission across
# rebuilds; ad-hoc signing gives every build a new identity and macOS forgets the
# grant. Set TRACKCONTROL_SIGN_IDENTITY to pick one explicitly, e.g. "-" to force
# an ad-hoc signature.
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
