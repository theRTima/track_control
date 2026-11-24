#!/bin/bash
# Builds the Swift package and assembles TrackControl.app in ./build
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="build/TrackControl.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp -f Resources/Info.plist "$APP/Contents/Info.plist"
cp -f .build/release/TrackControl "$APP/Contents/MacOS/TrackControl"

# Ad-hoc signature: gives the app a stable identity, which macOS needs in order
# to remember the Accessibility permission across launches.
codesign --force --sign - "$APP"

echo "Built $APP"
