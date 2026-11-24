import Foundation

/// One contact as reported by the multitouch driver.
struct MTTouch {
    var frame: Int32
    var timestamp: Double
    var pathIndex: Int32
    var state: UInt32
    var fingerID: Int32
    var handID: Int32
    var normalized: MTVector
    var zTotal: Float
    var reserved0: Int32
    var angle: Float
    var majorAxis: Float
    var minorAxis: Float
    var absolute: MTVector
    var reserved1: Int32
    var reserved2: Int32
    var zDensity: Float
}

struct MTPoint {
    var x: Float
    var y: Float
}

struct MTVector {
    var position: MTPoint
    var velocity: MTPoint
}

/// Thin layer over the private `MultitouchSupport.framework`, the same way
/// several open source gesture tools read the built-in trackpad.
///
/// The framework is loaded at runtime, so the app does not link a private
/// framework at build time and still starts on machines without a trackpad.
final class MultitouchBridge {
    /// `touches` is a raw pointer to an array of `MTTouch`; a typed pointer is not
    /// representable in a C convention closure.
    typealias FrameCallback = @convention(c) (
        UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int, Double, Int
    ) -> Void

    private typealias CreateListFn = @convention(c) () -> Unmanaged<CFArray>?
    private typealias RegisterFn = @convention(c) (UnsafeMutableRawPointer?, FrameCallback?, UnsafeMutableRawPointer?) -> Void
    private typealias StartFn = @convention(c) (UnsafeMutableRawPointer?, Int32) -> Int32
    private typealias StopFn = @convention(c) (UnsafeMutableRawPointer?) -> Int32
    private typealias IsBuiltInFn = @convention(c) (UnsafeMutableRawPointer?) -> Bool

    private var registerFn: RegisterFn?
    private var startFn: StartFn?
    private var stopFn: StopFn?
    private var devices: [UnsafeMutableRawPointer] = []

    /// Receives the touching contacts of every frame.
    var onFrame: (([TouchPoint]) -> Void)?

    /// Contact states that mean "finger is on the surface".
    private static let touchStates: Set<UInt32> = [3 /* make touch */, 4 /* touching */]

    func start() -> Bool {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
            RTLD_NOW
        ) else {
            Debug.log("multitouch: framework not available")
            return false
        }

        guard let createList: CreateListFn = Self.symbol(handle, "MTDeviceCreateList"),
              let register: RegisterFn = Self.symbol(handle, "MTRegisterContactFrameCallbackWithRefcon"),
              let starter: StartFn = Self.symbol(handle, "MTDeviceStart"),
              let stopper: StopFn = Self.symbol(handle, "MTDeviceStop")
        else {
            Debug.log("multitouch: required symbols missing")
            return false
        }
        registerFn = register
        startFn = starter
        stopFn = stopper

        let list = createList()?.takeRetainedValue() as? [Any] ?? []
        let isBuiltIn: IsBuiltInFn? = Self.symbol(handle, "MTDeviceIsBuiltIn")
        Debug.log("multitouch: \(list.count) device(s)")

        for entry in list {
            let device = Unmanaged<AnyObject>.passUnretained(entry as AnyObject).toOpaque()
            if let isBuiltIn, !isBuiltIn(device) { continue }
            devices.append(device)
        }
        guard let device = devices.first else {
            Debug.log("multitouch: no built-in trackpad found")
            return false
        }

        register(device, { _, touches, count, _, _ in
            MultitouchBridge.current?.handle(touches, count: count)
        }, Unmanaged.passUnretained(self).toOpaque())

        let status = starter(device, 0)
        Debug.log("multitouch: start status \(status)")
        return status == 0
    }

    func stop() {
        for device in devices {
            _ = stopFn?(device)
        }
        devices.removeAll()
    }

    private func handle(_ rawTouches: UnsafeMutableRawPointer?, count: Int) {
        guard count > 0, let rawTouches else {
            onFrame?([])
            return
        }
        let touches = rawTouches.assumingMemoryBound(to: MTTouch.self)
        var points: [TouchPoint] = []
        points.reserveCapacity(count)
        for index in 0..<count {
            let touch = touches[index]
            guard Self.touchStates.contains(touch.state) else { continue }
            points.append(TouchPoint(x: touch.normalized.position.x, y: touch.normalized.position.y))
        }
        onFrame?(points)
    }

    // The C callback carries no user data of its own beyond the refcon the
    // framework hands back, so the active instance is parked here. Frames are
    // delivered on one serial thread owned by the driver.
    nonisolated(unsafe) private static var current: MultitouchBridge?

    static func setCurrent(_ bridge: MultitouchBridge?) {
        current = bridge
    }

    private static func symbol<T>(_ handle: UnsafeMutableRawPointer, _ name: String) -> T? {
        guard let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }
}
