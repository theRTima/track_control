#!/bin/bash
# Builds a distributable disk image: build/TrackControl-<version>.dmg
#
# The app inside is ad-hoc signed on purpose: the local development certificate
# is only trusted on this machine, so a bundle signed with it would fail
# verification everywhere else.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
APP_DIR="build/dist"
DMG="build/TrackControl-$VERSION.dmg"

# Keep the development build in build/ untouched, so its Accessibility grant
# survives; the distribution bundle is assembled separately.
TRACKCONTROL_APP_DIR="$APP_DIR" TRACKCONTROL_SIGN_IDENTITY=- ./scripts/build-app.sh

STAGE=$(mktemp -d)
MOUNT=$(mktemp -d)
trap 'hdiutil detach -quiet "$MOUNT" 2>/dev/null || true; rm -rf "$STAGE" "$MOUNT"' EXIT

cp -R "$APP_DIR/TrackControl.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create -quiet -volname "Track Control" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

# Prove the image mounts and the copy inside carries a valid signature.
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$MOUNT" "$DMG"
if codesign -v "$MOUNT/TrackControl.app" 2>/dev/null; then
    echo "Verified signature inside the image"
else
    echo "Signature check failed inside the image" >&2
    exit 1
fi
hdiutil detach -quiet "$MOUNT"

SIZE=$(du -h "$DMG" | cut -f1)
echo "Built $DMG ($SIZE, version $VERSION)"
