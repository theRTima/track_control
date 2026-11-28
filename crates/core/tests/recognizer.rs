//! The behaviour that was pinned by `Tests/SelfTest/main.swift`, case by case.

use trackcontrol_core::{Recognizer, Side, SwipeEvent, Tuning, TouchPoint};

fn finger(x: f32, y: f32) -> TouchPoint {
    TouchPoint::new(x, y)
}

fn run(recognizer: &mut Recognizer, frame: &[TouchPoint]) -> Vec<SwipeEvent> {
    recognizer.process(frame)
}

fn total_delta(events: &[SwipeEvent]) -> f32 {
    events
        .iter()
        .map(|event| match event {
            SwipeEvent::Changed(_, delta) => *delta,
            _ => 0.0,
        })
        .sum()
}

#[test]
fn left_edge_swipe_starts_as_left() {
    let mut recognizer = Recognizer::default();
    let events = run(&mut recognizer, &[finger(0.05, 0.30), finger(0.07, 0.40)]);
    assert_eq!(events, vec![SwipeEvent::Began(Side::Left)]);
}

#[test]
fn upward_travel_is_a_positive_delta() {
    let mut recognizer = Recognizer::default();
    let mut events = run(&mut recognizer, &[finger(0.05, 0.30), finger(0.07, 0.40)]);
    for step in 1..=5 {
        let y = 0.30 + step as f32 * 0.06;
        events.extend(run(&mut recognizer, &[finger(0.05, y), finger(0.07, y + 0.10)]));
    }
    assert!((total_delta(&events) - 0.30).abs() < 0.001);
}

#[test]
fn lifting_the_fingers_ends_the_gesture() {
    let mut recognizer = Recognizer::default();
    let _ = run(&mut recognizer, &[finger(0.05, 0.30), finger(0.07, 0.40)]);
    assert_eq!(run(&mut recognizer, &[]), vec![SwipeEvent::Ended(Side::Left)]);
}

#[test]
fn swipe_away_from_the_edges_is_ignored() {
    let mut recognizer = Recognizer::default();
    let events = run(&mut recognizer, &[finger(0.5, 0.5), finger(0.55, 0.45)]);
    assert!(events.is_empty());
}

#[test]
fn drifting_off_the_edge_cancels_the_gesture() {
    let mut recognizer = Recognizer::default();
    let mut events = run(&mut recognizer, &[finger(0.05, 0.30), finger(0.05, 0.45)]);
    events.extend(run(&mut recognizer, &[finger(0.60, 0.32), finger(0.62, 0.47)]));
    assert_eq!(
        events,
        vec![SwipeEvent::Began(Side::Left), SwipeEvent::Cancelled]
    );
}

#[test]
fn no_new_gesture_before_release() {
    let mut recognizer = Recognizer::default();
    let _ = run(&mut recognizer, &[finger(0.05, 0.30), finger(0.05, 0.45)]);
    let _ = run(&mut recognizer, &[finger(0.05, 0.35), finger(0.05, 0.50)]);
    assert_eq!(run(&mut recognizer, &[]), vec![SwipeEvent::Ended(Side::Left)]);
    assert!(run(&mut recognizer, &[finger(0.05, 0.40), finger(0.05, 0.55)]).is_empty());
    let _ = run(&mut recognizer, &[]);
    assert_eq!(
        run(&mut recognizer, &[finger(0.05, 0.40), finger(0.05, 0.55)]),
        vec![SwipeEvent::Began(Side::Left)]
    );
}

#[test]
fn each_edge_maps_to_its_own_side() {
    let mut right = Recognizer::default();
    assert_eq!(
        run(&mut right, &[finger(0.95, 0.40), finger(0.97, 0.50)]),
        vec![SwipeEvent::Began(Side::Right)]
    );
    let mut top = Recognizer::default();
    assert_eq!(
        run(&mut top, &[finger(0.40, 0.95), finger(0.50, 0.96)]),
        vec![SwipeEvent::Began(Side::Top)]
    );
    let mut bottom = Recognizer::default();
    assert_eq!(
        run(&mut bottom, &[finger(0.40, 0.03), finger(0.50, 0.04)]),
        vec![SwipeEvent::Began(Side::Bottom)]
    );
}

#[test]
fn horizontal_travel_along_the_top_edge() {
    let mut recognizer = Recognizer::default();
    let mut events = run(&mut recognizer, &[finger(0.30, 0.97), finger(0.36, 0.96)]);
    events.extend(run(&mut recognizer, &[finger(0.40, 0.97), finger(0.46, 0.96)]));
    assert_eq!(events.first(), Some(&SwipeEvent::Began(Side::Top)));
    assert!((total_delta(&events) - 0.10).abs() < 0.001);
}

#[test]
fn two_fingers_near_but_not_on_the_edge_are_ignored() {
    let mut recognizer = Recognizer::default();
    let events = run(&mut recognizer, &[finger(0.09, 0.30), finger(0.11, 0.45)]);
    assert!(events.is_empty());
}

#[test]
fn one_finger_hugging_the_edge_starts_the_gesture() {
    let mut recognizer = Recognizer::default();
    let events = run(&mut recognizer, &[finger(0.02, 0.30), finger(0.09, 0.45)]);
    assert_eq!(events, vec![SwipeEvent::Began(Side::Left)]);
}

#[test]
fn three_fingers_are_ignored() {
    let mut recognizer = Recognizer::default();
    let events = run(
        &mut recognizer,
        &[finger(0.05, 0.30), finger(0.05, 0.45), finger(0.06, 0.60)],
    );
    assert!(events.is_empty());
}

#[test]
fn tuning_defaults_match_the_app() {
    let tuning = Tuning::default();
    assert_eq!(tuning.start_zone, 0.12);
    assert_eq!(tuning.edge_hug, 0.05);
    assert_eq!(tuning.drift_limit, 0.15);
}
