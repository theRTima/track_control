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

The script builds the package and assembles `build/TrackControl.app`, ad-hoc
signed. Copy it to `/Applications` if you want to keep it around.

## Permissions

Volume and display brightness work immediately. Two things need **Accessibility**
access:

- blocking the scroll that would otherwise reach the app you are working in;
- keyboard brightness, which presses the illumination keys for you.

Without the permission the app still runs, the scroll simply goes through as
well and keyboard brightness does nothing. Use the button in the app's settings
to open the right pane of System Settings.

## Signing

macOS remembers a permission per code signature. The build script signs with a
local certificate when one exists, which keeps the Accessibility grant across
rebuilds; without it the app is signed ad-hoc and macOS treats every rebuild as
a new app that has to be allowed again.

One-time setup of the local certificate (it stays in
`~/Library/Application Support/TrackControl/signing`):

```sh
DIR="$HOME/Library/Application Support/TrackControl/signing"
mkdir -p "$DIR" && cd "$DIR"
openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout key.pem -out cert.pem -subj "/CN=TrackControl Local Signing" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,digitalSignature,keyCertSign" \
  -addext "extendedKeyUsage=codeSigning"
openssl pkcs12 -export -inkey key.pem -in cert.pem -out identity.p12 \
  -passout pass:trackcontrol -name "TrackControl Local Signing"
security import identity.p12 -k "$HOME/Library/Keychains/login.keychain-db" \
  -P trackcontrol -T /usr/bin/codesign -A
security add-trusted-cert -r trustRoot -p codeSign \
  -k "$HOME/Library/Keychains/login.keychain-db" cert.pem
```

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

Working: settings UI, per-edge mapping, adjustable edge zone, volume, display
brightness, keyboard brightness, scroll blocking during a swipe (the last two
after Accessibility access has been granted).
