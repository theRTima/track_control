//! Platform-independent part of Track Control: the gesture state machine, the
//! mapping from swipes to settings, and the preferences model.
//!
//! Nothing here touches macOS, Windows or Linux; the OS specifics live behind
//! [`Controls`] and in the platform crates.

pub mod recognizer;
pub mod runner;
pub mod settings;
pub mod types;

pub use recognizer::{Recognizer, Tuning};
pub use runner::{ActionRunner, Controls};
pub use settings::Settings;
pub use types::{Action, Side, SwipeEvent, TouchPoint};
