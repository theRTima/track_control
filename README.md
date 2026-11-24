# track_control

App for controlling stuff on your Mac with the trackpad.

Two-finger swipes along the edges of the MacBook trackpad control system
settings — the open-source take on apps like Slidr. Each of the four edges
can be mapped to a different setting, and the mapping is configurable from the
app's settings window.

Default mapping:

| Edge   | Setting             |
| ------ | ------------------- |
| Left   | Volume              |
| Right  | Display brightness  |
| Top    | Keyboard brightness |
| Bottom | Nothing             |

Swiping towards the "increase" end of the edge (upwards for the left and right
edges, rightwards for the top and bottom edges) raises the value, swiping back
lowers it. A swipe that covers a third of the edge changes the value by about a
third.

## Build

Requires macOS 13 or newer and the Xcode Command Line Tools (`xcode-select
--install`); a full Xcode install is not needed.

```sh
./scripts/build-app.sh
open build/TrackControl.app
```

The script builds the package and assembles `build/TrackControl.app`, ad-hoc
signed. Copy it to `/Applications` if you want to keep it around.

## Permissions

Volume and display brightness work immediately. Keyboard brightness presses the
system illumination keys for you, which needs **Accessibility** access: open the
app's settings, select "Keyboard brightness" for an edge, and use the button
that appears. The setting is remembered for as long as the app bundle keeps its
signature.

## How it works

- Trackpad contacts come from the private `MultitouchSupport.framework`, loaded
  at runtime (`MTDeviceCreateList` + `MTRegisterContactFrameCallbackWithRefcon`).
  Only the built-in trackpad is used, and only touching contacts.
- `EdgeSwipeRecognizer` is a pure state machine: two fingers that start within
  10% of the same edge and travel along it produce swipe deltas. Drifting away
  from the edge cancels the gesture, so ordinary scrolling is left alone.
- `ActionRunner` applies the deltas: volume through CoreAudio on the default
  output device, display brightness through `DisplayServices`, keyboard
  backlight through the illumination media keys.

## Checks

```sh
swift run TrackControlSelfTest            # gesture recognizer, headless
swift run TrackControlSelfTest --system   # drives real volume/brightness changes
```

Set `TRACKCONTROL_DEBUG=1` in the environment to write frames and setting
changes to `~/Library/Logs/TrackControl.log`.

## Status

Working: switching, settings UI, persistence, volume, display brightness.
Keyboard brightness needs Accessibility access to be granted before it works.
