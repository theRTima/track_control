//! Turns swipe deltas into changes of the setting mapped to the swiped edge.

use crate::settings::Settings;
use crate::types::{Action, Side};

/// The system calls the runner needs; implemented per platform.
pub trait Controls {
    /// Current display brightness, `0.0..=1.0`, if the display reports it.
    fn display_brightness(&mut self) -> Option<f32>;
    fn set_display_brightness(&mut self, value: f32);
    /// Moves volume by whole steps through the system's own keys.
    fn volume_steps(&mut self, steps: i32);
    /// Moves keyboard backlight by whole steps.
    fn backlight_steps(&mut self, steps: i32);
}

#[derive(Debug, Default)]
pub struct ActionRunner {
    side: Option<Side>,
    action: Action,
    value: f32,
    carried_steps: f32,
}

impl Default for Action {
    fn default() -> Self {
        Action::None
    }
}

impl ActionRunner {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn began(&mut self, side: Side, settings: &Settings, controls: &mut dyn Controls) {
        self.side = Some(side);
        self.action = settings.action(side);
        self.carried_steps = 0.0;
        // Only brightness is absolute. Volume and keyboard brightness move in
        // whole steps, so the system keeps the value.
        if self.action == Action::DisplayBrightness {
            self.value = controls.display_brightness().unwrap_or(0.5);
        }
    }

    pub fn changed(&mut self, side: Side, delta: f32, controls: &mut dyn Controls) {
        if Some(side) != self.side || self.action == Action::None {
            return;
        }
        match self.action {
            Action::DisplayBrightness => {
                self.value = (self.value + delta).clamp(0.0, 1.0);
                controls.set_display_brightness(self.value);
            }
            Action::Volume => {
                let whole = self.take_whole_steps(delta, self.action);
                if whole != 0 {
                    controls.volume_steps(whole);
                }
            }
            Action::KeyboardBrightness => {
                let whole = self.take_whole_steps(delta, self.action);
                if whole != 0 {
                    controls.backlight_steps(whole);
                }
            }
            Action::None => {}
        }
    }

    pub fn ended(&mut self) {
        self.side = None;
        self.action = Action::None;
        self.carried_steps = 0.0;
    }

    /// Converts swipe travel into whole steps, keeping the fraction for the
    /// frames that are too short to fill a step on their own.
    fn take_whole_steps(&mut self, delta: f32, action: Action) -> i32 {
        self.carried_steps += delta * action.step_count() as f32;
        let whole = self.carried_steps.trunc();
        if whole == 0.0 {
            return 0;
        }
        self.carried_steps -= whole;
        whole as i32
    }
}
