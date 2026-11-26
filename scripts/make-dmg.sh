#!/bin/bash
# Builds one disk image per architecture:
#   build/TrackControl-<version>-arm64.dmg   (Apple silicon)
#   build/TrackControl-<version>-x86_64.dmg  (Intel)
#
# The apps inside are ad-hoc signed on purpose: the local development certificate
# is only trusted on this machine, so a bundle signed with it would fail
# verification everywhere else.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)

for ARCH in arm64 x86_64; do
    APP_DIR="build/dist-$ARCH"
    DMG="build/TrackControl-$VERSION-$ARCH.dmg"
    STAGE="build/stage-$ARCH"
    MOUNT="build/mount-$ARCH"

    # A separate build per architecture: the bundle inside the image carries one
    # slice, and the development build in build/ keeps its Accessibility grant.
    TRACKCONTROL_ARCHS="$ARCH" TRACKCONTROL_APP_DIR="$APP_DIR" \
        TRACKCONTROL_SIGN_IDENTITY=- ./scripts/build-app.sh

    rm -rf "$STAGE" "$MOUNT"
    mkdir -p "$STAGE" "$MOUNT"
    cp -R "$APP_DIR/TrackControl.app" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -quiet -volname "Track Control" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

    # Prove the image mounts and the copy inside has the expected slice and a
    # signature that verifies.
    hdiutil attach -quiet -nobrowse -readonly -mountpoint "$MOUNT" "$DMG"
    BUILT=$(lipo -archs "$MOUNT/TrackControl.app/Contents/MacOS/TrackControl")
    if [ "$BUILT" != "$ARCH" ]; then
        echo "$DMG holds $BUILT, expected $ARCH" >&2
        hdiutil detach -quiet "$MOUNT"
        exit 1
    fi
    if ! codesign -v "$MOUNT/TrackControl.app" 2>/dev/null; then
        echo "Signature check failed inside $DMG" >&2
        hdiutil detach -quiet "$MOUNT"
        exit 1
    fi
    hdiutil detach -quiet "$MOUNT"
    rm -rf "$STAGE" "$MOUNT"

    echo "Built $DMG ($(du -h "$DMG" | cut -f1), $ARCH, version $VERSION)"
done
