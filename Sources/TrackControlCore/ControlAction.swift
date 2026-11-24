import Foundation

/// The four trackpad edges a gesture can start from.
public enum TrackpadSide: String, CaseIterable, Codable, Sendable {
    case top
    case right
    case bottom
    case left

    public var title: String {
        switch self {
        case .top: return "Top"
        case .right: return "Right"
        case .bottom: return "Bottom"
        case .left: return "Left"
        }
    }
}

/// What a swipe along a trackpad edge controls.
public enum ControlAction: String, CaseIterable, Codable, Sendable {
    case none
    case volume
    case displayBrightness
    case keyboardBrightness

    public var title: String {
        switch self {
        case .none: return "Nothing"
        case .volume: return "Volume"
        case .displayBrightness: return "Display brightness"
        case .keyboardBrightness: return "Keyboard brightness"
        }
    }
}
