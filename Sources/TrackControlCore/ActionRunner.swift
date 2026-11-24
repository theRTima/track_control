import Foundation

/// Turns swipe deltas into changes of the setting mapped to the swiped edge.
public final class ActionRunner: @unchecked Sendable {
    private let settings: Settings

    /// Fraction of a trackpad edge length that covers the whole setting range.
    public var sensitivity: Float = 1.0

    private var side: TrackpadSide?
    private var action: ControlAction = .none
    private var value: Float = 0
    private var carriedSteps: Float = 0

    public init(settings: Settings = .shared) {
        self.settings = settings
    }

    public func began(side: TrackpadSide) {
        self.side = side
        action = settings.action(for: side)
        carriedSteps = 0
        guard action != .none else { return }

        switch action {
        case .volume:
            value = VolumeControl.current() ?? 0.5
        case .displayBrightness:
            value = DisplayBrightnessControl.current() ?? 0.5
        case .keyboardBrightness, .none:
            value = 0
        }
        Debug.log("gesture began on \(side.rawValue) -> \(action.rawValue) (current \(value))")
    }

    public func changed(side: TrackpadSide, delta: Float) {
        guard side == self.side, action != .none else { return }

        switch action {
        case .volume, .displayBrightness:
            value = min(max(value + delta * sensitivity, 0), 1)
            apply(value)

        case .keyboardBrightness:
            carriedSteps += delta * sensitivity * Float(KeyboardBrightnessControl.stepCount)
            let whole = carriedSteps.rounded(.towardZero)
            guard whole != 0 else { return }
            carriedSteps -= whole
            KeyboardBrightnessControl.adjust(steps: Int(whole))

        case .none:
            break
        }
    }

    public func ended() {
        side = nil
        action = .none
        carriedSteps = 0
    }

    private func apply(_ newValue: Float) {
        switch action {
        case .volume:
            VolumeControl.set(newValue)
        case .displayBrightness:
            DisplayBrightnessControl.set(newValue)
        default:
            break
        }
        Debug.log("\(action.rawValue) = \(newValue)")
    }
}
