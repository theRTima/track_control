import Foundation

/// Recognizes a two-finger swipe that starts on one of the four trackpad edges
/// and travels along it.
///
/// The class is a pure state machine: it takes the contacts of one frame and
/// returns the events that frame produced, which makes it easy to test without
/// a trackpad.
public final class EdgeSwipeRecognizer: @unchecked Sendable {
    public struct Tuning: Sendable {
        /// Both fingers must start within this fraction of the trackpad from the edge.
        public var startZone: Float = 0.10
        /// How far the fingers may drift away from the starting edge before the
        /// gesture is treated as an ordinary scroll instead.
        public var driftLimit: Float = 0.35

        public init() {}
    }

    public var tuning = Tuning()

    private var activeSide: TrackpadSide?
    private var lastAlong: Float = 0
    private var anchorPerpendicular: Float = 0
    /// After a gesture ends we ignore contacts until the fingers are lifted,
    /// otherwise the tail of one swipe would immediately start another.
    private var waitingForRelease = false

    public init() {}

    public func reset() {
        activeSide = nil
        waitingForRelease = false
    }

    /// - Parameter fingers: contacts of the current frame that are actually touching.
    public func process(_ fingers: [TouchPoint]) -> [SwipeEvent] {
        if fingers.isEmpty {
            waitingForRelease = false
            return finish()
        }
        guard !waitingForRelease else { return finish() }

        if let side = activeSide {
            guard fingers.count == 2 else { return cancel() }

            let along = mean(fingers.map { alongPosition(of: side, $0) })
            let perpendicular = mean(fingers.map { perpendicularPosition(of: side, $0) })

            guard abs(perpendicular - anchorPerpendicular) <= tuning.driftLimit else {
                return cancel()
            }

            let delta = along - lastAlong
            lastAlong = along
            guard delta != 0 else { return [] }
            return [.changed(side: side, delta: delta)]
        }

        guard fingers.count == 2 else { return [] }
        guard let side = commonEdge(of: fingers) else { return [] }

        activeSide = side
        lastAlong = mean(fingers.map { alongPosition(of: side, $0) })
        anchorPerpendicular = mean(fingers.map { perpendicularPosition(of: side, $0) })
        return [.began(side: side)]
    }

    // MARK: - Geometry

    private func finish() -> [SwipeEvent] {
        guard let side = activeSide else { return [] }
        activeSide = nil
        waitingForRelease = true
        return [.ended(side: side)]
    }

    private func cancel() -> [SwipeEvent] {
        guard activeSide != nil else { return [] }
        activeSide = nil
        waitingForRelease = true
        return [.cancelled]
    }

    /// Both fingers must sit in the zone of the same edge; the closest edge wins.
    private func commonEdge(of fingers: [TouchPoint]) -> TrackpadSide? {
        let a = nearestEdge(for: fingers[0])
        let b = nearestEdge(for: fingers[1])
        guard let a, let b, a.side == b.side else { return nil }
        return a.side
    }

    private func nearestEdge(for point: TouchPoint) -> (side: TrackpadSide, distance: Float)? {
        let candidates: [(TrackpadSide, Float)] = [
            (.left, point.x),
            (.right, 1 - point.x),
            (.bottom, point.y),
            (.top, 1 - point.y),
        ]
        return candidates
            .filter { $0.1 >= 0 && $0.1 <= tuning.startZone }
            .min { $0.1 < $1.1 }
            .map { (side: $0.0, distance: $0.1) }
    }

    /// Position measured along the edge; growing values mean "increase the setting".
    private func alongPosition(of side: TrackpadSide, _ point: TouchPoint) -> Float {
        switch side {
        case .left, .right: return point.y
        case .top, .bottom: return point.x
        }
    }

    /// Position measured away from the edge.
    private func perpendicularPosition(of side: TrackpadSide, _ point: TouchPoint) -> Float {
        switch side {
        case .left: return point.x
        case .right: return 1 - point.x
        case .bottom: return point.y
        case .top: return 1 - point.y
        }
    }

    private func mean(_ values: [Float]) -> Float {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Float(values.count)
    }
}
