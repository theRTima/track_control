import AppKit
import ApplicationServices
import Foundation

/// Keyboard backlight is only reachable through the media keys: the HID device
/// that owns it refuses feature reports without root. So the gesture presses
/// the illumination keys, which needs Accessibility permission for this app.
public enum KeyboardBrightnessControl {
    private static let illuminationUp: Int32 = 21
    private static let illuminationDown: Int32 = 22
    /// macOS uses 16 hardware steps for the keyboard backlight.
    public static let stepCount = 16

    public static var isAvailable: Bool { AccessibilityPermission.isGranted }

    public static func adjust(steps: Int) {
        guard steps != 0 else { return }
        guard AccessibilityPermission.isGranted else {
            Debug.log("keyboard brightness: \(steps) step(s) dropped, accessibility permission missing")
            return
        }
        Debug.log("keyboard brightness: \(steps) step(s)")
        let key = steps > 0 ? illuminationUp : illuminationDown
        for _ in 0..<abs(steps) {
            postKey(key)
            usleep(30_000)
        }
    }

    /// Posts one press+release of a system-defined media key.
    private static func postKey(_ key: Int32) {
        for pressed in [true, false] {
            let flags = NSEvent.ModifierFlags(rawValue: pressed ? 0xA00 : 0xB00)
            let data1 = Int((key << 16) | Int32(pressed ? 0x0A00 : 0x0B00))
            guard let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            ) else { continue }
            event.cgEvent?.post(tap: .cghidEventTap)
        }
    }
}

/// Accessibility ("post events") permission used for the media keys.
public enum AccessibilityPermission {
    public static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Asks macOS to show the "add Track Control to Accessibility" prompt.
    @discardableResult
    public static func request() -> Bool {
        // "AXTrustedCheckOptionPrompt" is the documented value of
        // kAXTrustedCheckOptionPrompt, which is a global var Swift 6 refuses to read here.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
