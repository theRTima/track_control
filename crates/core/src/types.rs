//! Values shared by the recognizer, the runner and the platforms.

/// A finger position on the touch surface, normalised to `0.0..=1.0`.
/// The origin is the bottom-left corner, as on macOS.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct TouchPoint {
    pub x: f32,
    pub y: f32,
}

impl TouchPoint {
    pub const fn new(x: f32, y: f32) -> Self {
        Self { x, y }
    }
}

/// The four edges a gesture can start from.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum Side {
    Top,
    Right,
    Bottom,
    Left,
}

impl Side {
    /// Same order as `TrackpadSide.allCases` in the Swift app.
    pub const ALL: [Side; 4] = [Side::Top, Side::Right, Side::Bottom, Side::Left];

    pub const fn key(self) -> &'static str {
        match self {
            Side::Top => "top",
            Side::Right => "right",
            Side::Bottom => "bottom",
            Side::Left => "left",
        }
    }

    pub const fn title(self) -> &'static str {
        match self {
            Side::Top => "Top",
            Side::Right => "Right",
            Side::Bottom => "Bottom",
            Side::Left => "Left",
        }
    }
}

/// What a swipe along an edge controls.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Action {
    None,
    Volume,
    DisplayBrightness,
    KeyboardBrightness,
}

impl Action {
    pub const ALL: [Action; 4] = [
        Action::None,
        Action::Volume,
        Action::DisplayBrightness,
        Action::KeyboardBrightness,
    ];

    pub const fn key(self) -> &'static str {
        match self {
            Action::None => "none",
            Action::Volume => "volume",
            Action::DisplayBrightness => "displayBrightness",
            Action::KeyboardBrightness => "keyboardBrightness",
        }
    }

    pub fn from_key(key: &str) -> Option<Self> {
        Action::ALL.into_iter().find(|action| action.key() == key)
    }

    /// Volume and keyboard brightness are applied by pressing the system media
    /// keys, which is the only thing here that needs Accessibility on macOS.
    pub const fn needs_accessibility(self) -> bool {
        matches!(self, Action::Volume | Action::KeyboardBrightness)
    }

    /// How many steps the system splits the range into (16 on macOS).
    pub const fn step_count(self) -> i32 {
        match self {
            Action::Volume | Action::KeyboardBrightness => 16,
            _ => 0,
        }
    }
}

/// What the recognizer reports while a two-finger edge swipe is in progress.
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum SwipeEvent {
    /// Two fingers started at `side` and are now tracked.
    Began(Side),
    /// The fingers moved by `delta` along the edge (positive = towards "increase").
    Changed(Side, f32),
    /// The fingers were lifted.
    Ended(Side),
    /// The gesture turned into something else (scrolled away, extra fingers).
    Cancelled,
}
