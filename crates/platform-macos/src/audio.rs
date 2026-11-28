//! System output volume through CoreAudio.
//!
//! Used when Accessibility is not granted: the media keys are not available, so
//! the level is written directly. The system HUD does not follow such a change,
//! which is exactly why the keys are preferred when they can be used.

use std::ffi::{c_uint, c_void};
use std::ptr::null;

#[repr(C)]
struct AudioObjectPropertyAddress {
    selector: u32,
    scope: u32,
    element: u32,
}

#[link(name = "CoreAudio", kind = "framework")]
extern "C" {
    fn AudioObjectGetPropertyData(
        object: u32,
        address: *const AudioObjectPropertyAddress,
        qualifier_size: c_uint,
        qualifier: *const c_void,
        size: *mut c_uint,
        data: *mut c_void,
    ) -> i32;
    fn AudioObjectSetPropertyData(
        object: u32,
        address: *const AudioObjectPropertyAddress,
        qualifier_size: c_uint,
        qualifier: *const c_void,
        size: c_uint,
        data: *const c_void,
    ) -> i32;
    fn AudioObjectIsPropertySettable(
        object: u32,
        address: *const AudioObjectPropertyAddress,
        settable: *mut u8,
    ) -> i32;
}

const SYSTEM_OBJECT: u32 = 1;
const SCOPE_GLOBAL: u32 = fourcc(b"glob");
const SCOPE_OUTPUT: u32 = fourcc(b"outp");
const MAIN_ELEMENT: u32 = 0;
const DEFAULT_OUTPUT_DEVICE: u32 = fourcc(b"dOut");
const VOLUME_SCALAR: u32 = fourcc(b"volm");

const fn fourcc(code: &[u8; 4]) -> u32 {
    u32::from_be_bytes(*code)
}

fn address(selector: u32, scope: u32, element: u32) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress {
        selector,
        scope,
        element,
    }
}

fn output_device() -> Option<u32> {
    let mut device: u32 = 0;
    let mut size = std::mem::size_of::<u32>() as c_uint;
    let status = unsafe {
        AudioObjectGetPropertyData(
            SYSTEM_OBJECT,
            &address(DEFAULT_OUTPUT_DEVICE, SCOPE_GLOBAL, MAIN_ELEMENT),
            0,
            null(),
            &mut size,
            &mut device as *mut u32 as *mut c_void,
        )
    };
    (status == 0 && device != 0).then_some(device)
}

fn read_scalar(device: u32, element: u32) -> Option<f32> {
    let mut value: f32 = 0.0;
    let mut size = std::mem::size_of::<f32>() as c_uint;
    let status = unsafe {
        AudioObjectGetPropertyData(
            device,
            &address(VOLUME_SCALAR, SCOPE_OUTPUT, element),
            0,
            null(),
            &mut size,
            &mut value as *mut f32 as *mut c_void,
        )
    };
    (status == 0).then_some(value)
}

fn write_scalar(device: u32, element: u32, value: f32) -> bool {
    let address = address(VOLUME_SCALAR, SCOPE_OUTPUT, element);
    let mut settable: u8 = 0;
    let status = unsafe { AudioObjectIsPropertySettable(device, &address, &mut settable) };
    if status != 0 || settable == 0 {
        return false;
    }
    unsafe {
        AudioObjectSetPropertyData(
            device,
            &address,
            0,
            null(),
            std::mem::size_of::<f32>() as c_uint,
            &value as *const f32 as *const c_void,
        ) == 0
    }
}

/// Current level of the default output device, `0.0..=1.0`.
pub fn volume() -> Option<f32> {
    let device = output_device()?;
    if let Some(value) = read_scalar(device, MAIN_ELEMENT) {
        return Some(value);
    }
    // Devices that do not expose the master element report one per channel.
    let channels: Vec<f32> = (1..=2).filter_map(|element| read_scalar(device, element)).collect();
    if channels.is_empty() {
        None
    } else {
        Some(channels.iter().sum::<f32>() / channels.len() as f32)
    }
}

/// Moves the level by whole steps out of sixteen, the way the keys would.
pub fn adjust_volume(steps: i32) {
    let Some(device) = output_device() else {
        return;
    };
    let current = volume().unwrap_or(0.5);
    let target = (current + steps as f32 / 16.0).clamp(0.0, 1.0);
    if write_scalar(device, MAIN_ELEMENT, target) {
        return;
    }
    for element in 1..=2 {
        write_scalar(device, element, target);
    }
}
