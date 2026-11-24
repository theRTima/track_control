import Foundation

/// Shared flag: true while a two-finger edge swipe is in progress.
/// Read by the scroll suppressor on the event tap thread.
public final class GestureActivity: @unchecked Sendable {
    private let lock = NSLock()
    private var active = false

    public init() {}

    public var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        return active
    }

    public func setActive(_ value: Bool) {
        lock.lock()
        active = value
        lock.unlock()
    }
}
