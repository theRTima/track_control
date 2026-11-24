import CoreGraphics
import Foundation

/// Drops scroll wheel events while an edge swipe is running, so adjusting the
/// volume does not also scroll the window underneath.
///
/// Suppressing events needs an event tap, which needs Accessibility access. If
/// the tap cannot be created the app keeps working, the scroll just goes
/// through as well.
public final class ScrollSuppressor: @unchecked Sendable {
    private let activity: GestureActivity
    private var tap: CFMachPort?
    private var runLoop: CFRunLoop?

    public init(activity: GestureActivity) {
        self.activity = activity
    }

    @discardableResult
    public func start() -> Bool {
        guard tap == nil else { return true }

        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let suppressor = Unmanaged<ScrollSuppressor>.fromOpaque(refcon).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    suppressor.reenable()
                    return Unmanaged.passUnretained(event)
                }
                if suppressor.activity.isActive {
                    return nil
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            Debug.log("scroll suppressor: no event tap (Accessibility access needed)")
            return false
        }

        self.tap = tap
        let thread = Thread { [weak self] in self?.run(tap) }
        thread.name = "TrackControl.ScrollTap"
        thread.start()
        Debug.log("scroll suppressor: running")
        return true
    }

    /// macOS disables slow taps; turn it back on instead of losing suppression.
    fileprivate func reenable() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: true)
            Debug.log("scroll suppressor: re-enabled")
        }
    }

    public func stop() {
        if let runLoop {
            CFRunLoopStop(runLoop)
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        tap = nil
    }

    private func run(_ tap: CFMachPort) {
        runLoop = CFRunLoopGetCurrent()
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        CFRunLoopRun()
    }
}
