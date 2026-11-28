#!/bin/bash
# Builds the Rust daemon into build/TrackControlRS.app
set -euo pipefail
cd "$(dirname "$0")/.."

cargo build --release

APP="${TRACKCONTROL_APP_DIR:-build}/TrackControlRS.app"
BUNDLE_ID="com.rtima.trackcontrol.rust"
VERSION=$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -1)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -f target/release/trackcontrol "$APP/Contents/MacOS/trackcontrol"
strip -x "$APP/Contents/MacOS/trackcontrol"
cp -f Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>Track Control RS</string>
	<key>CFBundleDisplayName</key>
	<string>Track Control RS</string>
	<key>CFBundleExecutable</key>
	<string>trackcontrol</string>
	<key>CFBundleIdentifier</key>
	<string>${BUNDLE_ID}</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>${VERSION}</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
PLIST

IDENTITY="${TRACKCONTROL_SIGN_IDENTITY:-}"
if [ -z "$IDENTITY" ]; then
    IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
        | grep "TrackControl Local Signing" | grep -v "Invalid" | head -1 | awk '{print $2}' || true)
fi
if [ -n "$IDENTITY" ]; then
    codesign --force --sign "$IDENTITY" "$APP"
    echo "Signed with $IDENTITY"
else
    codesign --force --sign - "$APP"
    echo "Signed ad-hoc (Accessibility has to be granted again after each build)"
fi

echo "Built $APP (version $VERSION)"
