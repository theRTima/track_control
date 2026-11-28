//! Recognises a two-finger swipe that starts on one of the four edges and
//! travels along it.
//!
//! A pure state machine: it takes the contacts of one frame and returns the
//! events that frame produced, which is what makes it testable without a
//! trackpad.

use crate::types::{Side, SwipeEvent, TouchPoint};

/// Geometry of the gesture, in fractions of the touch surface.
#[derive(Clone, Copy, Debug)]
pub struct Tuning {
    /// Both fingers must start within this distance from the edge.
    pub start_zone: f32,
    /// At least one finger has to be this close to the edge; a scroll that
    /// merely starts near an edge rarely touches it.
    pub edge_hug: f32,
    /// How far the fingers may drift from the starting edge before the swipe
    /// turns into an ordinary scroll.
    pub drift_limit: f32,
}

impl Default for Tuning {
    fn default() -> Self {
        Self {
            start_zone: 0.12,
            edge_hug: 0.05,
            drift_limit: 0.15,
        }
    }
}

#[derive(Debug, Default)]
pub struct Recognizer {
    pub tuning: Tuning,
    active_side: Option<Side>,
    last_along: f32,
    anchor_perpendicular: f32,
    /// After a gesture ends we ignore contacts until the fingers are lifted,
    /// otherwise the tail of one swipe would immediately start another.
    waiting_for_release: bool,
}

impl Recognizer {
    pub fn new(tuning: Tuning) -> Self {
        Self {
            tuning,
            ..Default::default()
        }
    }

    pub fn reset(&mut self) {
        self.active_side = None;
        self.last_along = 0.0;
        self.anchor_perpendicular = 0.0;
        self.waiting_for_release = false;
    }

    pub fn is_active(&self) -> bool {
        self.active_side.is_some()
    }

    /// Feeds the contacts of one frame and returns the events it produced.
    ///
    /// `fingers` holds only the contacts that are actually touching.
    pub fn process(&mut self, fingers: &[TouchPoint]) -> Vec<SwipeEvent> {
        if fingers.is_empty() {
            self.waiting_for_release = false;
            return self.finish();
        }
        // A finished gesture ignores the rest of its own frames until release.
        if self.waiting_for_release {
            return Vec::new();
        }
        if fingers.len() != 2 {
            return if self.active_side.is_none() {
                Vec::new()
            } else {
                self.cancel()
            };
        }

        let (first, second) = (fingers[0], fingers[1]);

        if let Some(side) = self.active_side {
            let along = (self.along(side, first) + self.along(side, second)) / 2.0;
            let perpendicular =
                (self.perpendicular(side, first) + self.perpendicular(side, second)) / 2.0;

            if (perpendicular - self.anchor_perpendicular).abs() > self.tuning.drift_limit {
                return self.cancel();
            }

            let delta = along - self.last_along;
            self.last_along = along;
            return if delta == 0.0 {
                Vec::new()
            } else {
                vec![SwipeEvent::Changed(side, delta)]
            };
        }

        let Some(side) = self.common_edge(first, second) else {
            return Vec::new();
        };
        self.active_side = Some(side);
        self.last_along = self.along(side, first) / 2.0 + self.along(side, second) / 2.0;
        self.anchor_perpendicular =
            self.perpendicular(side, first) / 2.0 + self.perpendicular(side, second) / 2.0;
        vec![SwipeEvent::Began(side)]
    }

    fn finish(&mut self) -> Vec<SwipeEvent> {
        match self.active_side.take() {
            None => Vec::new(),
            Some(side) => {
                self.waiting_for_release = true;
                vec![SwipeEvent::Ended(side)]
            }
        }
    }

    fn cancel(&mut self) -> Vec<SwipeEvent> {
        if self.active_side.take().is_none() {
            return Vec::new();
        }
        self.waiting_for_release = true;
        vec![SwipeEvent::Cancelled]
    }

    /// Both fingers must sit in the zone of the same edge, and one of them must
    /// hug the edge itself; the closest edge wins.
    fn common_edge(&self, first: TouchPoint, second: TouchPoint) -> Option<Side> {
        let a = self.nearest_edge(first)?;
        let b = self.nearest_edge(second)?;
        if a.0 != b.0 || a.1.min(b.1) > self.tuning.edge_hug {
            return None;
        }
        Some(a.0)
    }

    fn nearest_edge(&self, point: TouchPoint) -> Option<(Side, f32)> {
        let candidates = [
            (Side::Left, point.x),
            (Side::Right, 1.0 - point.x),
            (Side::Bottom, point.y),
            (Side::Top, 1.0 - point.y),
        ];
        let mut best: Option<(Side, f32)> = None;
        for (side, distance) in candidates {
            if !(0.0..=self.tuning.start_zone).contains(&distance) {
                continue;
            }
            if best.map(|(_, d)| distance < d).unwrap_or(true) {
                best = Some((side, distance));
            }
        }
        best
    }

    /// Position measured along the edge; growing values mean "increase".
    fn along(&self, side: Side, point: TouchPoint) -> f32 {
        match side {
            Side::Left | Side::Right => point.y,
            Side::Top | Side::Bottom => point.x,
        }
    }

    /// Position measured away from the edge.
    fn perpendicular(&self, side: Side, point: TouchPoint) -> f32 {
        match side {
            Side::Left => point.x,
            Side::Right => 1.0 - point.x,
            Side::Bottom => point.y,
            Side::Top => 1.0 - point.y,
        }
    }
}
