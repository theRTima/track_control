//! Posts a media key, to check that the Accessibility path works:
//! `cargo run -p trackcontrol-platform-macos --example media_keys -- down 2`

use trackcontrol_platform_macos::system::{
    accessibility_granted, post_media_key, ILLUMINATION_DOWN, ILLUMINATION_UP, SOUND_DOWN, SOUND_UP,
};

fn main() {
    let mut args = std::env::args().skip(1);
    let which = args.next().unwrap_or_else(|| "down".into());
    let times: i32 = args.next().and_then(|n| n.parse().ok()).unwrap_or(1);

    if !accessibility_granted() {
        println!("accessibility: not granted, keys are dropped");
    }
    let key = match which.as_str() {
        "up" => SOUND_UP,
        "down" => SOUND_DOWN,
        "backlight-up" => ILLUMINATION_UP,
        "backlight-down" => ILLUMINATION_DOWN,
        other => {
            eprintln!("unknown key: {other}");
            std::process::exit(2);
        }
    };
    for _ in 0..times.abs() {
        post_media_key(key);
        std::thread::sleep(std::time::Duration::from_millis(30));
    }
    println!("posted {times} x {which}");
}
