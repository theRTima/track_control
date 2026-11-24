import Foundation
import TrackControlCore

// Headless checks for the gesture engine. Run with `swift run TrackControlSelfTest`.

final class Counter: @unchecked Sendable { var failures = 0 }
let counter = Counter()

func check(_ condition: Bool, _ name: String) {
    if condition {
        print("ok   \(name)")
    } else {
        print("FAIL \(name)")
        counter.failures += 1
    }
}

func run(_ recognizer: EdgeSwipeRecognizer, _ frame: [TouchPoint]) -> [SwipeEvent] {
    recognizer.process(frame)
}

func totalDelta(_ events: [SwipeEvent]) -> Float {
    events.reduce(0) { sum, event in
        if case let .changed(_, delta) = event { return sum + delta }
        return sum
    }
}

func finger(_ x: Float, _ y: Float) -> TouchPoint { TouchPoint(x: x, y: y) }

// 1. Two fingers starting on the left edge and moving up: left side, positive delta.
do {
    let recognizer = EdgeSwipeRecognizer()
    var events: [SwipeEvent] = []

    events += run(recognizer, [finger(0.05, 0.30), finger(0.07, 0.40)])
    check(events == [.began(side: .left)], "left-edge swipe starts as left")

    for step in 1...5 {
        let y = 0.30 + Float(step) * 0.06
        events += run(recognizer, [finger(0.05, y), finger(0.07, y + 0.10)])
    }
    check(abs(totalDelta(events) - 0.30) < 0.001, "upward travel is reported as a positive delta")

    events += run(recognizer, [])
    check(events.last == .ended(side: .left), "lifting the fingers ends the gesture")
}

// 2. A swipe in the middle of the trackpad is ignored (that is the normal scroll area).
do {
    let recognizer = EdgeSwipeRecognizer()
    let events = run(recognizer, [finger(0.5, 0.5), finger(0.55, 0.45)])
    check(events.isEmpty, "swipe away from the edges is ignored")
}

// 3. Fingers that pull away from the edge turn into a normal scroll.
do {
    let recognizer = EdgeSwipeRecognizer()
    var events = run(recognizer, [finger(0.05, 0.30), finger(0.05, 0.45)])
    events += run(recognizer, [finger(0.60, 0.32), finger(0.62, 0.47)])
    check(events == [.began(side: .left), .cancelled], "drifting off the edge cancels the gesture")
}

// 4. One swipe cannot restart until all fingers are released.
do {
    let recognizer = EdgeSwipeRecognizer()
    _ = run(recognizer, [finger(0.05, 0.30), finger(0.05, 0.45)])
    _ = run(recognizer, [finger(0.05, 0.35), finger(0.05, 0.50)])
    let ended = run(recognizer, [])
    check(ended == [.ended(side: .left)], "gesture ends when the fingers lift")
    let afterEnd = run(recognizer, [finger(0.05, 0.40), finger(0.05, 0.55)])
    check(afterEnd.isEmpty, "no new gesture before release")
    _ = run(recognizer, [])
    let restarted = run(recognizer, [finger(0.05, 0.40), finger(0.05, 0.55)])
    check(restarted == [.began(side: .left)], "new gesture after release")
}

// 5. Right edge, top edge and bottom edge are mapped to their own sides.
do {
    let right = EdgeSwipeRecognizer()
    check(run(right, [finger(0.95, 0.40), finger(0.97, 0.50)]) == [.began(side: .right)], "right edge detected")

    let top = EdgeSwipeRecognizer()
    check(run(top, [finger(0.40, 0.95), finger(0.50, 0.96)]) == [.began(side: .top)], "top edge detected")

    let bottom = EdgeSwipeRecognizer()
    check(run(bottom, [finger(0.40, 0.03), finger(0.50, 0.04)]) == [.began(side: .bottom)], "bottom edge detected")
}

// 6. Horizontal travel along the top edge is reported as a delta.
do {
    let recognizer = EdgeSwipeRecognizer()
    var events = run(recognizer, [finger(0.30, 0.97), finger(0.36, 0.96)])
    events += run(recognizer, [finger(0.40, 0.97), finger(0.46, 0.96)])
    check(events.first == .began(side: .top), "top edge gesture started")
    check(abs(totalDelta(events) - 0.10) < 0.001, "horizontal travel reported for top edge")
}

// 7. Three fingers are not our gesture.
do {
    let recognizer = EdgeSwipeRecognizer()
    let events = run(recognizer, [finger(0.05, 0.30), finger(0.05, 0.45), finger(0.06, 0.60)])
    check(events.isEmpty, "three fingers are ignored")
}

print(counter.failures == 0 ? "all checks passed" : "\(counter.failures) check(s) failed")
exit(counter.failures == 0 ? 0 : 1)
