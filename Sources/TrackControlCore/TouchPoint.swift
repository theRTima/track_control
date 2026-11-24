import Foundation

/// A finger position on the trackpad surface, normalized to 0...1.
/// Origin is the bottom-left corner of the trackpad.
public struct TouchPoint: Equatable, Sendable {
    public var x: Float
    public var y: Float

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
}

/// What the recognizer reports while a two-finger edge swipe is in progress.
public enum SwipeEvent: Equatable, Sendable {
    /// Two fingers started at `side` and are now tracked.
    case began(side: TrackpadSide)
    /// The fingers moved by `delta` along the edge (positive = towards the "increase" end).
    case changed(side: TrackpadSide, delta: Float)
    /// The fingers were lifted.
    case ended(side: TrackpadSide)
    /// The gesture turned into something else (scrolled away from the edge, extra fingers).
    case cancelled
}
