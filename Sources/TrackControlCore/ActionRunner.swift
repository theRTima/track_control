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
        // Only brightness is absolute. Volume and keyboard brightness move in
        // whole steps, so the system keeps the value.
        if action == .displayBrightness {
            value = DisplayBrightnessControl.current() ?? 0.5
        }
        Debug.log("gesture began on \(side.rawValue) -> \(action.rawValue)")
    }

    public func changed(side: TrackpadSide, delta: Float) {
        guard side == self.side, action != .none else { return }

        switch action {
        case .displayBrightness:
            value = min(max(value + delta * sensitivity, 0), 1)
            DisplayBrightnessControl.set(value)
            Debug.log("display brightness = \(value)")

        case .volume:
            steps(delta, stepCount: VolumeControl.stepCount, apply: VolumeControl.adjust(steps:))

        case .keyboardBrightness:
            steps(delta, stepCount: KeyboardBrightnessControl.stepCount, apply: KeyboardBrightnessControl.adjust(steps:))

        case .none:
            break
        }
    }

    public func ended() {
        side = nil
        action = .none
        carriedSteps = 0
    }

    /// Converts swipe travel into whole steps, keeping the fraction for the
    /// frames that are too short to fill a step on their own.
    private func steps(_ delta: Float, stepCount: Int, apply: (Int) -> Void) {
        carriedSteps += delta * sensitivity * Float(stepCount)
        let whole = carriedSteps.rounded(.towardZero)
        guard whole != 0 else { return }
        carriedSteps -= whole
        apply(Int(whole))
    }
}
