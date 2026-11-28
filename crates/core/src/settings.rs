//! Per-edge action mapping and the edge-zone width, stored as a small text
//! file so the format is readable on every platform.

use std::fmt;
use std::fs;
use std::path::Path;

use crate::types::{Action, Side};

/// Fraction of the trackpad that counts as "on the edge".
pub const DEFAULT_EDGE_ZONE: f32 = 0.12;
pub const MIN_EDGE_ZONE: f32 = 0.02;
pub const MAX_EDGE_ZONE: f32 = 0.30;

pub const DEFAULT_ACTIONS: [Action; 4] = [
    Action::Volume,            // left
    Action::DisplayBrightness, // right
    Action::KeyboardBrightness, // top
    Action::None,              // bottom
];

#[derive(Clone, Debug)]
pub struct Settings {
    edge_zone: f32,
    show_menu_bar_icon: bool,
    actions: [Action; 4],
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            edge_zone: DEFAULT_EDGE_ZONE,
            show_menu_bar_icon: true,
            actions: DEFAULT_ACTIONS,
        }
    }
}

impl Settings {
    pub fn edge_zone(&self) -> f32 {
        self.edge_zone
    }

    pub fn set_edge_zone(&mut self, value: f32) {
        self.edge_zone = value.clamp(MIN_EDGE_ZONE, MAX_EDGE_ZONE);
    }

    pub fn show_menu_bar_icon(&self) -> bool {
        self.show_menu_bar_icon
    }

    pub fn set_show_menu_bar_icon(&mut self, value: bool) {
        self.show_menu_bar_icon = value;
    }

    pub fn action(&self, side: Side) -> Action {
        self.actions[side_index(side)]
    }

    pub fn set_action(&mut self, side: Side, action: Action) {
        self.actions[side_index(side)] = action;
    }

    /// Reads the file, falling back to defaults for anything missing or broken.
    pub fn load(path: &Path) -> Self {
        let mut settings = Self::default();
        let Ok(text) = fs::read_to_string(path) else {
            return settings;
        };
        for line in text.lines() {
            let Some((key, value)) = line.split_once('=') else {
                continue;
            };
            let (key, value) = (key.trim(), value.trim());
            match key {
                "edge_zone" => {
                    if let Ok(zone) = value.parse::<f32>() {
                        settings.set_edge_zone(zone);
                    }
                }
                "show_menu_bar_icon" => settings.show_menu_bar_icon = value == "true",
                _ => {
                    if let Some(name) = key.strip_prefix("action.") {
                        if let Some(side) = Side::ALL.into_iter().find(|s| s.key() == name) {
                            if let Some(action) = Action::from_key(value) {
                                settings.set_action(side, action);
                            }
                        }
                    }
                }
            }
        }
        settings
    }

    pub fn save(&self, path: &Path) -> std::io::Result<()> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(path, self.to_string())
    }
}

impl fmt::Display for Settings {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        writeln!(f, "edge_zone={}", self.edge_zone)?;
        writeln!(f, "show_menu_bar_icon={}", self.show_menu_bar_icon)?;
        for side in Side::ALL {
            writeln!(f, "action.{}={}", side.key(), self.action(side).key())?;
        }
        Ok(())
    }
}

fn side_index(side: Side) -> usize {
    match side {
        Side::Left => 0,
        Side::Right => 1,
        Side::Top => 2,
        Side::Bottom => 3,
    }
}
