//! Writes the output level directly, without the media keys:
//! `cargo run -p trackcontrol-platform-macos --example volume`

use trackcontrol_platform_macos::audio;

fn main() {
    println!("volume now: {:?}", audio::volume());
    audio::adjust_volume(-2);
    std::thread::sleep(std::time::Duration::from_millis(150));
    println!("after -2 steps: {:?}", audio::volume());
    audio::adjust_volume(2);
    std::thread::sleep(std::time::Duration::from_millis(150));
    println!("after +2 steps: {:?}", audio::volume());
}
