#!/bin/bash
# Renders the settings window into Resources/settings-window.png.
#
# No Screen Recording permission is involved: the picture is drawn by the same
# SettingsPane view the app puts in its window (scripts/make-screenshot.swift),
# so it cannot drift away from the real UI.
set -euo pipefail
cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# SettingsPane is part of the app target and imports the core as a module;
# compiled together with the core sources it must not import itself.
sed '/^import TrackControlCore$/d' Sources/TrackControl/SettingsPane.swift > "$tmp/SettingsPane.swift"

swiftc -O scripts/make-screenshot.swift "$tmp/SettingsPane.swift" \
    Sources/TrackControlCore/*.swift Sources/TrackControlCore/Controls/*.swift \
    -o "$tmp/settings-shot"
"$tmp/settings-shot"
