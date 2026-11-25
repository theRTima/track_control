import AppKit
import Foundation

/// Presses the system's own media keys.
///
/// Some settings (volume, keyboard backlight) cannot be moved continuously in a
/// way the system acknowledges: it only turns a key press into a visible step.
/// Posting the key event is what makes macOS do the change *and* draw its HUD,
/// which needs Accessibility permission for this app.
public enum MediaKeys {
    public static let volumeUp: Int32 = 0
    public static let volumeDown: Int32 = 1

    /// Posts one press+release of a system-defined key.
    public static func post(_ key: Int32) {
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
