import Foundation

/// Per-side action mapping, persisted in UserDefaults.
/// `UserDefaults` is thread-safe, so an instance can be shared across threads.
public final class Settings: @unchecked Sendable {
    public static let shared = Settings()

    private let defaults: UserDefaults
    private let keyPrefix = "action."
    private let edgeZoneKey = "edgeZone"

    /// Fraction of the trackpad that counts as "on the edge", 0.02...0.30.
    public static let defaultEdgeZone: Float = 0.12
    public static let edgeZoneRange: ClosedRange<Float> = 0.02...0.30

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var edgeZone: Float {
        get {
            guard let stored = defaults.object(forKey: edgeZoneKey) as? Double else {
                return Self.defaultEdgeZone
            }
            return min(max(Float(stored), Self.edgeZoneRange.lowerBound), Self.edgeZoneRange.upperBound)
        }
        set {
            let clamped = min(max(newValue, Self.edgeZoneRange.lowerBound), Self.edgeZoneRange.upperBound)
            defaults.set(Double(clamped), forKey: edgeZoneKey)
            NotificationCenter.default.post(name: .trackControlSettingsChanged, object: nil)
        }
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
