//! Track Control: gestures on the trackpad edges, in Rust.
//!
//! `trackcontrol` starts the daemon; `--probe` prints what the platform layer
//! can see, which is the quickest way to check a machine.

use std::path::PathBuf;
use std::sync::mpsc::{channel, RecvTimeoutError};
use std::time::{Duration, Instant};

use trackcontrol_core::{ActionRunner, Controls, Recognizer, Settings, SwipeEvent, Tuning};
use trackcontrol_platform_macos::MacPlatform;

const WATCHDOG: Duration = Duration::from_millis(500);

fn main() {
    let argument = std::env::args().nth(1);
    match argument.as_deref() {
        Some("--probe") => probe(),
        Some("--settings") => print_settings(),
        Some("--help" | "-h") => usage(),
        None => run(),
        Some(other) => {
            eprintln!("unknown argument: {other}");
            usage();
            std::process::exit(2);
        }
    }
}

fn usage() {
    println!(
        "trackcontrol [--probe | --settings]\n\
         \n\
         \x20 --probe     report the platform layer and the first contact frames\n\
         \x20 --settings  print the settings file path and its contents"
    );
}

fn settings_path() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| ".".into());
    PathBuf::from(home)
        .join("Library/Application Support/TrackControl")
        .join("settings.conf")
}

fn print_settings() {
    let path = settings_path();
    println!("settings: {}", path.display());
    match std::fs::read_to_string(&path) {
        Ok(text) => print!("{text}"),
        Err(_) => println!("(no file yet, defaults apply)\n{}", Settings::default()),
    }
}

fn probe() {
    println!("accessibility granted: {}", MacPlatform::accessibility_granted());
    println!("display brightness: {:?}", {
        let mut platform = MacPlatform::new();
        platform.display_brightness()
    });

    let (tx, rx) = channel();
    let mut platform = MacPlatform::new();
    if !platform.start_touches(tx) {
        println!("trackpad: not available");
        return;
    }
    println!("scroll suppression: {}", platform.start_scroll_suppression());

    let deadline = Instant::now() + Duration::from_secs(5);
    let mut frames = 0usize;
    while Instant::now() < deadline {
        match rx.recv_timeout(Duration::from_millis(200)) {
            Ok(points) => {
                frames += 1;
                if frames <= 10 {
                    println!("frame {frames}: {} contact(s) {:?}", points.len(), points);
                }
            }
            Err(RecvTimeoutError::Timeout) => continue,
            Err(RecvTimeoutError::Disconnected) => break,
        }
    }
    println!("frames in 5 s: {frames}");
    platform.stop();
}

fn run() {
    let path = settings_path();
    let settings = Settings::load(&path);
    if let Err(error) = settings.save(&path) {
        eprintln!("settings: cannot write {}: {error}", path.display());
    }

    let mut platform = MacPlatform::new();
    let (tx, rx) = channel();
    if !platform.start_touches(tx) {
        eprintln!("trackpad: not available");
        std::process::exit(1);
    }
    let suppressed = platform.start_scroll_suppression();

    let mut tuning = Tuning::default();
    tuning.start_zone = settings.edge_zone();
    tuning.edge_hug = settings.edge_zone() / 2.0;
    let mut recognizer = Recognizer::new(tuning);
    let mut runner = ActionRunner::new();
    let mut last_frame = Instant::now();

    eprintln!(
        "track control: running (edge zone {:.2}, scroll suppression {}, accessibility {})",
        settings.edge_zone(),
        suppressed,
        MacPlatform::accessibility_granted()
    );

    loop {
        match rx.recv_timeout(WATCHDOG) {
            Ok(points) => {
                last_frame = Instant::now();
                if std::env::var("TRACKCONTROL_DEBUG").as_deref() == Ok("1") {
                    eprintln!("frame: {} contact(s)", points.len());
                }
                for event in recognizer.process(&points) {
                    match event {
                        SwipeEvent::Began(side) => {
                            platform.set_gesture_active(true);
                            runner.began(side, &settings, &mut platform);
                        }
                        SwipeEvent::Changed(side, delta) => {
                            runner.changed(side, delta, &mut platform);
                        }
                        SwipeEvent::Ended(_) | SwipeEvent::Cancelled => {
                            platform.set_gesture_active(false);
                            runner.ended();
                        }
                    }
                }
            }
            Err(RecvTimeoutError::Timeout) => {
                // The driver stops sending frames mid-gesture: end it instead of
                // leaving scrolling blocked forever.
                if recognizer.is_active() && last_frame.elapsed() > WATCHDOG {
                    recognizer.reset();
                    platform.set_gesture_active(false);
                    runner.ended();
                }
            }
            Err(RecvTimeoutError::Disconnected) => break,
        }
    }

    platform.stop();
}
