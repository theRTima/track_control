import Foundation

/// Per-side action mapping, persisted in UserDefaults.
/// `UserDefaults` is thread-safe, so an instance can be shared across threads.
public final class Settings: @unchecked Sendable {
    public static let shared = Settings()

    private let defaults: UserDefaults
    private let keyPrefix = "action."

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func action(for side: TrackpadSide) -> ControlAction {
        guard let raw = defaults.string(forKey: keyPrefix + side.rawValue),
              let action = ControlAction(rawValue: raw) else {
            return Self.defaultActions[side] ?? .none
        }
        return action
    }

    public func set(_ action: ControlAction, for side: TrackpadSide) {
        defaults.set(action.rawValue, forKey: keyPrefix + side.rawValue)
        NotificationCenter.default.post(name: .trackControlSettingsChanged, object: nil)
    }

    static let defaultActions: [TrackpadSide: ControlAction] = [
        .left: .volume,
        .right: .displayBrightness,
        .top: .keyboardBrightness,
        .bottom: .none,
    ]
}

public extension Notification.Name {
    static let trackControlSettingsChanged = Notification.Name("TrackControlSettingsChanged")
}
