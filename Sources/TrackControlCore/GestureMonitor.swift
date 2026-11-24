import Foundation

/// Feeds trackpad contacts into the recognizer and the resulting events into
/// the `ActionRunner`.
public final class GestureMonitor: @unchecked Sendable {
    private let bridge = MultitouchBridge()
    private let recognizer = EdgeSwipeRecognizer()
    private let runner: ActionRunner
    private let queue = DispatchQueue(label: "TrackControl.Gestures", qos: .userInteractive)
    private var frameCounter = 0

    public private(set) var isRunning = false

    public init(runner: ActionRunner = ActionRunner()) {
        self.runner = runner
    }

    @discardableResult
    public func start() -> Bool {
        bridge.onFrame = { [weak self] points in
            guard let self else { return }
            queue.async { self.handle(points) }
        }
        MultitouchBridge.setCurrent(bridge)
        isRunning = bridge.start()
        Debug.log("gesture monitor running: \(isRunning)")
        return isRunning
    }

    public func stop() {
        bridge.stop()
        MultitouchBridge.setCurrent(nil)
        isRunning = false
    }

    private func handle(_ points: [TouchPoint]) {
        if Debug.isEnabled {
            frameCounter += 1
            if frameCounter % 20 == 0 || !points.isEmpty {
                let description = points.map { String(format: "(%.2f, %.2f)", $0.x, $0.y) }.joined(separator: " ")
                Debug.log("frame \(points.count) contacts: \(description)")
            }
        }

        for event in recognizer.process(points) {
            switch event {
            case let .began(side):
                runner.began(side: side)
            case let .changed(side, delta):
                runner.changed(side: side, delta: delta)
            case .ended:
                runner.ended()
            case .cancelled:
                runner.ended()
            }
        }
    }
}
