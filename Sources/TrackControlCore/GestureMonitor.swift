import Foundation

/// Feeds trackpad contacts into the recognizer and the resulting events into
/// the `ActionRunner`.
public final class GestureMonitor: @unchecked Sendable {
    private let bridge = MultitouchBridge()
    private let recognizer = EdgeSwipeRecognizer()
    private let runner: ActionRunner
    private let settings: Settings
    private let activity = GestureActivity()
    private let queue = DispatchQueue(label: "TrackControl.Gestures", qos: .userInteractive)
    private var suppressor: ScrollSuppressor?
    private var frameCounter = 0
    private var lastFrameTime = Date.distantPast
    private var watchdog: DispatchSourceTimer?
    private var settingsObserver: NSObjectProtocol?

    public private(set) var isRunning = false

    public init(runner: ActionRunner = ActionRunner(), settings: Settings = .shared) {
        self.runner = runner
        self.settings = settings
    }

    @discardableResult
    public func start() -> Bool {
        applyEdgeZone()
        startSuppressor()

        settingsObserver = NotificationCenter.default.addObserver(
            forName: .trackControlSettingsChanged, object: nil, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            queue.async { self.applyEdgeZone() }
        }

        bridge.onFrame = { [weak self] points in
            guard let self else { return }
            queue.async { self.handle(points) }
        }

        // If the driver stops sending frames mid-gesture, end it instead of
        // leaving scrolling blocked forever.
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.5, repeating: 0.5)
        timer.setEventHandler { [weak self] in self?.checkForStalledGesture() }
        timer.resume()
        watchdog = timer

        MultitouchBridge.setCurrent(bridge)
        isRunning = bridge.start()
        // Do not leave a timer, a tap thread and an observer behind on failure.
        if !isRunning { stop() }
        Debug.log("gesture monitor running: \(isRunning)")
        return isRunning
    }

    /// The event tap cannot be created before macOS grants Accessibility, so try
    /// again once the app is active and the user has had a chance to grant it.
    public func refreshScrollSuppression() {
        guard isRunning else { return }
        if suppressor == nil { startSuppressor() }
        suppressor?.start()
    }

    public func stop() {
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        settingsObserver = nil
        watchdog?.cancel()
        watchdog = nil
        bridge.stop()
        MultitouchBridge.setCurrent(nil)
        suppressor?.stop()
        suppressor = nil
        isRunning = false
    }

    private func startSuppressor() {
        let suppressor = ScrollSuppressor(activity: activity)
        suppressor.start()
        self.suppressor = suppressor
    }

    private func applyEdgeZone() {
        let zone = settings.edgeZone
        recognizer.tuning.startZone = zone
        // One finger has to be in the inner half of the zone, which keeps a
        // scroll that merely starts near an edge from stealing the gesture.
        recognizer.tuning.edgeHug = zone / 2
        Debug.log("edge zone set to \(zone)")
    }

    private func checkForStalledGesture() {
        guard activity.isActive, Date().timeIntervalSince(lastFrameTime) > 0.5 else { return }
        Debug.log("gesture stalled, resetting")
        recognizer.reset()
        activity.setActive(false)
        runner.ended()
    }

    private func handle(_ points: [TouchPoint]) {
        lastFrameTime = Date()
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
                activity.setActive(true)
                runner.began(side: side)
            case let .changed(side, delta):
                runner.changed(side: side, delta: delta)
            case .ended, .cancelled:
                activity.setActive(false)
                runner.ended()
            }
        }
    }
}
