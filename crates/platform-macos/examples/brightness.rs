//! Reads, then nudges display brightness by a step:
//! `cargo run -p trackcontrol-platform-macos --example brightness -- -0.1`

use trackcontrol_platform_macos::system::{display_brightness, set_display_brightness};

fn main() {
    let before = display_brightness();
    println!("before: {before:?}");
    let step: f32 = std::env::args()
        .nth(1)
        .and_then(|v| v.parse().ok())
        .unwrap_or(-0.1);
    if let Some(value) = before {
        set_display_brightness(value + step);
    }
    std::thread::sleep(std::time::Duration::from_millis(100));
    println!("after:  {:?}", display_brightness());
}
