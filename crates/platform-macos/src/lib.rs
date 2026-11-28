//! macOS backend: the same system calls the Swift app makes, behind the core's
//! `Controls` trait.

pub mod multitouch;
pub mod scroll;
pub mod system;

use std::sync::mpsc::Sender;

use trackcontrol_core::{Controls, TouchPoint};

pub struct MacPlatform {
    bridge: Option<multitouch::Bridge>,
    suppressor: Option<scroll::Suppressor>,
}

impl MacPlatform {
    pub fn new() -> Self {
        Self {
            bridge: None,
            suppressor: None,
        }
    }

    /// Starts the built-in trackpad; every frame is sent to `sink`.
    pub fn start_touches(&mut self, sink: Sender<Vec<TouchPoint>>) -> bool {
        self.bridge = multitouch::Bridge::start(sink);
        self.bridge.is_some()
    }

    /// Starts the scroll tap if Accessibility access is available; otherwise the
    /// app still runs, scrolling just goes through during a swipe.
    pub fn start_scroll_suppression(&mut self) -> bool {
        if self.suppressor.is_none() {
            self.suppressor = scroll::Suppressor::start();
        }
        self.suppressor.is_some()
    }

    pub fn set_gesture_active(&self, active: bool) {
        if let Some(suppressor) = &self.suppressor {
            suppressor.set_active(active);
        }
    }

    pub fn accessibility_granted() -> bool {
        system::accessibility_granted()
    }

    pub fn stop(&mut self) {
        if let Some(mut bridge) = self.bridge.take() {
            bridge.stop();
        }
        if let Some(mut suppressor) = self.suppressor.take() {
            suppressor.stop();
        }
    }
}

impl Default for MacPlatform {
    fn default() -> Self {
        Self::new()
    }
}

impl Controls for MacPlatform {
    fn display_brightness(&mut self) -> Option<f32> {
        system::display_brightness()
    }

    fn set_display_brightness(&mut self, value: f32) {
        system::set_display_brightness(value);
    }

    fn volume_steps(&mut self, steps: i32) {
        let key = if steps > 0 {
            system::SOUND_UP
        } else {
            system::SOUND_DOWN
        };
        for _ in 0..steps.abs() {
            system::post_media_key(key);
        }
    }

    fn backlight_steps(&mut self, steps: i32) {
        let key = if steps > 0 {
            system::ILLUMINATION_UP
        } else {
            system::ILLUMINATION_DOWN
        };
        for _ in 0..steps.abs() {
            system::post_media_key(key);
            std::thread::sleep(std::time::Duration::from_millis(30));
        }
    }
}
