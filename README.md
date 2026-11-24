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

**Edge zone** in the settings window controls how close to an edge two fingers
have to start, as a share of the trackpad (2% to 30%, 12% by default). While a
swipe is running the app drops the scroll events that would otherwise scroll the
window underneath.

## Build

Requires macOS 13 or newer and the Xcode Command Line Tools (`xcode-select
--install`); a full Xcode install is not needed.

```sh
./scripts/build-app.sh
open build/TrackControl.app
```

The script builds the package, assembles `build/TrackControl.app` and signs it.
Copy it to `/Applications` if you want to keep it around.

For a disk image to hand out:

```sh
./scripts/make-dmg.sh     # -> build/TrackControl-<version>.dmg
```

The version comes from `CFBundleShortVersionString` in `Resources/Info.plist`.
The image contains an ad-hoc signed copy of the app, because the local
development certificate is only trusted on the machine that made it. The
development build in `build/` is left alone.

## Permissions

Volume and display brightness work immediately. Two things need **Accessibility**
access:

- blocking the scroll that would otherwise reach the app you are working in;
- keyboard brightness, which presses the illumination keys for you.

Without the permission the app still runs, the scroll simply goes through as
well and keyboard brightness does nothing. Use the button in the app's settings
to open the right pane of System Settings.

## How it works

- Trackpad contacts come from the private `MultitouchSupport.framework`, loaded
  at runtime (`MTDeviceCreateList` + `MTRegisterContactFrameCallbackWithRefcon`).
  Only the built-in trackpad is used, and only touching contacts.
- `EdgeSwipeRecognizer` is a pure state machine: two fingers that start inside
  the edge zone (12% of the trackpad by default, adjustable in settings, one of
  them within half of it) and travel along that edge produce swipe deltas.
  Drifting away from the edge cancels the gesture.
- `ActionRunner` applies the deltas: volume through CoreAudio on the default
  output device, display brightness through `DisplayServices`, keyboard
  backlight through the illumination media keys.
- While a swipe runs, an event tap drops scroll events so the window underneath
  stays put.

## Checks

```sh
swift run TrackControlSelfTest            # gesture recognizer, headless
swift run TrackControlSelfTest --system   # drives real volume/brightness changes
```

Set `TRACKCONTROL_DEBUG=1` in the environment to write frames and setting
changes to `~/Library/Logs/TrackControl.log`.
