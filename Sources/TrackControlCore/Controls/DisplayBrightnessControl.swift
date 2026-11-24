import CoreGraphics
import Foundation

/// Display brightness through `DisplayServices`, the private framework the
/// brightness keys themselves end up in.
public enum DisplayBrightnessControl {
    private typealias GetFn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (UInt32, Float) -> Int32

    private static let api: (get: GetFn, set: SetFn)? = {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_NOW
        ),
        let getSymbol = dlsym(handle, "DisplayServicesGetBrightness"),
        let setSymbol = dlsym(handle, "DisplayServicesSetBrightness")
        else {
            Debug.log("brightness: DisplayServices unavailable")
            return nil
        }
        return (
            unsafeBitCast(getSymbol, to: GetFn.self),
            unsafeBitCast(setSymbol, to: SetFn.self)
        )
    }()

    public static var isAvailable: Bool { api != nil }

    public static func current() -> Float? {
        guard let api else { return nil }
        var value: Float = 0
        guard api.get(CGMainDisplayID(), &value) == 0 else { return nil }
        return value
    }

    public static func set(_ value: Float) {
        guard let api else { return }
        _ = api.set(CGMainDisplayID(), min(max(value, 0), 1))
    }
}
