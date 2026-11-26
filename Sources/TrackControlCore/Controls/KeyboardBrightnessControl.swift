import AppKit
import Foundation

/// Keyboard backlight is only reachable through the media keys: the HID device
/// that owns it refuses feature reports without root. So the gesture presses
/// the illumination keys, which needs Accessibility permission for this app.
public enum KeyboardBrightnessControl {
    private static let illuminationUp: Int32 = 21
    private static let illuminationDown: Int32 = 22
    /// macOS uses 16 hardware steps for the keyboard backlight.
    public static let stepCount = 16

    /// Spaced-out key presses take up to half a second, so they run on their own
    /// queue: the gesture queue must not wait for them.
    private static let queue = DispatchQueue(label: "TrackControl.KeyboardBrightness")

    public static func adjust(steps: Int) {
        guard steps != 0 else { return }
        guard AccessibilityPermission.isGranted else {
            Debug.log("keyboard brightness: \(steps) step(s) dropped, accessibility permission missing")
            return
        }
        Debug.log("keyboard brightness: \(steps) step(s)")
        let key = steps > 0 ? illuminationUp : illuminationDown
        let count = abs(steps)
        queue.async {
            for _ in 0..<count {
                MediaKeys.post(key)
                usleep(30_000)
            }
        }
    }
}
