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
        public var startZone: Float = 0.12
        /// At least one finger has to be this close to the edge. A two-finger
        /// scroll that happens to start near an edge rarely touches it, which is
        /// what keeps ordinary scrolling from changing settings.
        public var edgeHug: Float = 0.05
        /// How far the fingers may drift away from the starting edge before the
        /// gesture is treated as an ordinary scroll instead.
        public var driftLimit: Float = 0.15

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
        lastAlong = 0
        anchorPerpendicular = 0
        waitingForRelease = false
    }

    /// - Parameter fingers: contacts of the current frame that are actually touching.
    public func process(_ fingers: [TouchPoint]) -> [SwipeEvent] {
        if fingers.isEmpty {
            waitingForRelease = false
            return finish()
        }
        // A finished gesture ignores the rest of its own frames until release.
        guard !waitingForRelease else { return [] }
        guard fingers.count == 2 else { return activeSide == nil ? [] : cancel() }

        let (first, second) = (fingers[0], fingers[1])

        if let side = activeSide {
            let along = (alongPosition(of: side, first) + alongPosition(of: side, second)) / 2
            let perpendicular = (perpendicularPosition(of: side, first) + perpendicularPosition(of: side, second)) / 2
            guard abs(perpendicular - anchorPerpendicular) <= tuning.driftLimit else {
                return cancel()
            }

            let delta = along - lastAlong
            lastAlong = along
            return delta == 0 ? [] : [.changed(side: side, delta: delta)]
        }

        guard let side = commonEdge(first, second) else { return [] }
        activeSide = side
        lastAlong = alongPosition(of: side, first) / 2 + alongPosition(of: side, second) / 2
        anchorPerpendicular = perpendicularPosition(of: side, first) / 2 + perpendicularPosition(of: side, second) / 2
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

    /// Both fingers must sit in the zone of the same edge, and one of them must
    /// hug the edge itself; the closest edge wins.
    private func commonEdge(_ first: TouchPoint, _ second: TouchPoint) -> TrackpadSide? {
        guard let a = nearestEdge(first), let b = nearestEdge(second), a.side == b.side else { return nil }
        return min(a.distance, b.distance) <= tuning.edgeHug ? a.side : nil
    }

    private func nearestEdge(_ point: TouchPoint) -> (side: TrackpadSide, distance: Float)? {
        var best: (side: TrackpadSide, distance: Float)?
        func consider(_ side: TrackpadSide, _ distance: Float) {
            guard (0...tuning.startZone).contains(distance) else { return }
            if best.map({ distance < $0.distance }) ?? true {
                best = (side, distance)
            }
        }
        consider(.left, point.x)
        consider(.right, 1 - point.x)
        consider(.bottom, point.y)
        consider(.top, 1 - point.y)
        return best
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
}
