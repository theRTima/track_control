import ApplicationServices

/// Accessibility ("control other apps") permission.
///
/// Needed for exactly two optional things: posting the system media keys, which
/// is how volume and keyboard brightness move, and the event tap that drops
/// scroll events during a swipe. Reading the trackpad, display brightness and
/// the CoreAudio fallback work without it.
public enum AccessibilityPermission {
    public static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Asks macOS to show the "add Track Control to Accessibility" prompt.
    @discardableResult
    public static func request() -> Bool {
        // "AXTrustedCheckOptionPrompt" is the documented value of
        // kAXTrustedCheckOptionPrompt, which is a global var Swift 6 refuses to read here.
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }
}
