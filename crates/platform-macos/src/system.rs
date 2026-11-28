//! Display brightness, the system media keys, and the Accessibility check.

use std::ffi::{c_char, c_void, CString};
use std::ptr::null_mut;
use std::sync::OnceLock;

type BrightnessGetter = unsafe extern "C" fn(u32, *mut f32) -> i32;
type BrightnessSetter = unsafe extern "C" fn(u32, f32) -> i32;

struct DisplayServices {
    get: BrightnessGetter,
    set: BrightnessSetter,
}

#[link(name = "CoreGraphics", kind = "framework")]
extern "C" {
    fn CGMainDisplayID() -> u32;
    fn CGEventCreateKeyboardEvent(source: *mut c_void, key: u16, down: bool) -> *mut c_void;
    fn CGEventSetType(event: *mut c_void, kind: u32);
    fn CGEventSetIntegerValueField(event: *mut c_void, field: u32, value: i64);
    fn CGEventPost(tap: u32, event: *mut c_void);
    fn CGEventSetFlags(event: *mut c_void, flags: u64);
    fn CFRelease(value: *const c_void);
}

#[link(name = "ApplicationServices", kind = "framework")]
extern "C" {
    fn AXIsProcessTrusted() -> bool;
}

extern "C" {
    fn dlopen(path: *const c_char, mode: i32) -> *mut c_void;
    fn dlsym(handle: *mut c_void, symbol: *const c_char) -> *mut c_void;
}

const RTLD_NOW: i32 = 0x2;
const NX_SYSTEM_DEFINED: u32 = 14;
const HID_EVENT_TAP: u32 = 0;

// Field numbers taken from the CGEvent an `NSEvent.otherEvent(type: .systemDefined)`
// produces: subtype, data1 and data2 are not the public field names.
const FIELD_SUBTYPE: u32 = 83;
const FIELD_DATA1: u32 = 149;
const FIELD_DATA2: u32 = 150;

/// Volume keys, as the Fn row presses them.
pub const SOUND_UP: i32 = 0;
pub const SOUND_DOWN: i32 = 1;
pub const ILLUMINATION_UP: i32 = 21;
pub const ILLUMINATION_DOWN: i32 = 22;

fn display_services() -> Option<&'static DisplayServices> {
    static API: OnceLock<Option<DisplayServices>> = OnceLock::new();
    API.get_or_init(|| {
        let path = CString::new(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        )
        .ok()?;
        let handle = unsafe { dlopen(path.as_ptr(), RTLD_NOW) };
        if handle.is_null() {
            eprintln!("brightness: DisplayServices unavailable");
            return None;
        }
        let get: BrightnessGetter = unsafe { symbol(handle, "DisplayServicesGetBrightness") }?;
        let set: BrightnessSetter = unsafe { symbol(handle, "DisplayServicesSetBrightness") }?;
        Some(DisplayServices { get, set })
    })
    .as_ref()
}

unsafe fn symbol<T>(handle: *mut c_void, name: &str) -> Option<T> {
    let name = CString::new(name).ok()?;
    let pointer = unsafe { dlsym(handle, name.as_ptr()) };
    if pointer.is_null() {
        None
    } else {
        Some(unsafe { std::mem::transmute_copy(&pointer) })
    }
}

pub fn display_brightness() -> Option<f32> {
    let api = display_services()?;
    let mut value: f32 = 0.0;
    let display = unsafe { CGMainDisplayID() };
    match unsafe { (api.get)(display, &mut value) } {
        0 => Some(value),
        _ => None,
    }
}

pub fn set_display_brightness(value: f32) {
    let Some(api) = display_services() else {
        return;
    };
    let display = unsafe { CGMainDisplayID() };
    unsafe { (api.set)(display, value.clamp(0.0, 1.0)) };
}

/// Accessibility ("control other apps") permission: needed for the media keys
/// and for the scroll event tap. Reading the trackpad and display brightness
/// work without it.
pub fn accessibility_granted() -> bool {
    unsafe { AXIsProcessTrusted() }
}

/// Posts one press and release of a system-defined key.
pub fn post_media_key(key: i32) {
    if !accessibility_granted() {
        eprintln!("media keys: accessibility permission missing");
        return;
    }
    for down in [true, false] {
        let event = unsafe { CGEventCreateKeyboardEvent(null_mut(), 0, down) };
        if event.is_null() {
            continue;
        }
        let data1 = ((key as i64) << 16) | if down { 0x0A00 } else { 0x0B00 };
        let modifier_flags: u64 = if down { 0x0A00 } else { 0x0B00 };
        unsafe {
            CGEventSetType(event, NX_SYSTEM_DEFINED);
            CGEventSetIntegerValueField(event, FIELD_SUBTYPE, 8);
            CGEventSetIntegerValueField(event, FIELD_DATA1, data1);
            CGEventSetIntegerValueField(event, FIELD_DATA2, -1);
            CGEventSetFlags(event, modifier_flags);
            CGEventPost(HID_EVENT_TAP, event);
            CFRelease(event as *const c_void);
        }
    }
}
