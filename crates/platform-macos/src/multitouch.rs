//! Contact frames from the private `MultitouchSupport.framework`, loaded at
//! runtime with `dlopen`, exactly like the Swift bridge.

use std::ffi::{c_char, c_int, c_void, CStr, CString};
use std::ptr::null_mut;
use std::sync::atomic::{AtomicPtr, Ordering};
use std::sync::mpsc::Sender;

use trackcontrol_core::TouchPoint;

#[repr(C)]
#[derive(Clone, Copy)]
pub struct MtPoint {
    x: f32,
    y: f32,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct MtVector {
    position: MtPoint,
    velocity: MtPoint,
}

/// Layout must match `MTTouch` in the framework (and `MTTouch` in the Swift bridge).
#[repr(C)]
#[derive(Clone, Copy)]
pub struct MtTouch {
    frame: i32,
    timestamp: f64,
    path_index: i32,
    state: u32,
    finger_id: i32,
    hand_id: i32,
    normalized: MtVector,
    z_total: f32,
    reserved0: i32,
    angle: f32,
    major_axis: f32,
    minor_axis: f32,
    absolute: MtVector,
    reserved1: i32,
    reserved2: i32,
    z_density: f32,
}

/// Contact states that mean "finger is on the surface".
const TOUCHING: [u32; 2] = [3, 4];

type CreateListFn = unsafe extern "C" fn() -> *const c_void;
type RegisterFn =
    unsafe extern "C" fn(device: *mut c_void, callback: FrameCallback, refcon: *mut c_void);
type StartFn = unsafe extern "C" fn(device: *mut c_void, unknown: i32) -> i32;
type StopFn = unsafe extern "C" fn(device: *mut c_void) -> i32;
type IsBuiltInFn = unsafe extern "C" fn(device: *mut c_void) -> bool;

/// `touches` is a raw pointer to an array of `MtTouch`; a typed pointer is not
/// representable in a C convention callback.
type FrameCallback = unsafe extern "C" fn(
    device: *mut c_void,
    touches: *mut c_void,
    count: c_int,
    timestamp: f64,
    frame: c_int,
);

static SINK: AtomicPtr<Sender<Vec<TouchPoint>>> = AtomicPtr::new(null_mut());

extern "C" {
    fn dlopen(path: *const c_char, mode: i32) -> *mut c_void;
    fn dlsym(handle: *mut c_void, symbol: *const c_char) -> *mut c_void;
    fn dlerror() -> *const c_char;
    fn CFArrayGetCount(array: *const c_void) -> isize;
    fn CFArrayGetValueAtIndex(array: *const c_void, index: isize) -> *const c_void;
    fn CFRelease(value: *const c_void);
}

const RTLD_NOW: i32 = 0x2;

pub struct Bridge {
    register: RegisterFn,
    start: StartFn,
    stop: StopFn,
    devices: Vec<*mut c_void>,
    device_list: *const c_void,
}

impl Bridge {
    /// Loads the framework and starts the built-in trackpad.
    pub fn start(sink: Sender<Vec<TouchPoint>>) -> Option<Self> {
        let path = CString::new(
            "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
        )
        .ok()?;
        let handle = unsafe { dlopen(path.as_ptr(), RTLD_NOW) };
        if handle.is_null() {
            log_line("multitouch: framework not available");
            return None;
        }

        let create_list: CreateListFn = unsafe { symbol(handle, "MTDeviceCreateList") }?;
        let register: RegisterFn =
            unsafe { symbol(handle, "MTRegisterContactFrameCallbackWithRefcon") }?;
        let start: StartFn = unsafe { symbol(handle, "MTDeviceStart") }?;
        let stop: StopFn = unsafe { symbol(handle, "MTDeviceStop") }?;
        let is_built_in: Option<IsBuiltInFn> = unsafe { symbol(handle, "MTDeviceIsBuiltIn") };

        let device_list = unsafe { create_list() };
        let count = if device_list.is_null() {
            0
        } else {
            unsafe { CFArrayGetCount(device_list) }
        };
        log_line(&format!("multitouch: {count} device(s)"));

        let mut devices = Vec::new();
        for index in 0..count {
            let raw = unsafe { CFArrayGetValueAtIndex(device_list, index) } as *mut c_void;
            if raw.is_null() {
                continue;
            }
            if let Some(is_built_in) = is_built_in {
                if !unsafe { is_built_in(raw) } {
                    continue;
                }
            }
            devices.push(raw);
        }
        let Some(&device) = devices.first() else {
            log_line("multitouch: no built-in trackpad found");
            return None;
        };

        let sink = Box::into_raw(Box::new(sink));
        SINK.store(sink, Ordering::SeqCst);

        unsafe { register(device, frame_callback, null_mut()) };
        let status = unsafe { start(device, 0) };
        log_line(&format!("multitouch: start status {status}"));
        if status != 0 {
            return None;
        }

        Some(Self {
            register,
            start,
            stop,
            devices,
            device_list,
        })
    }

    pub fn stop(&mut self) {
        for device in &self.devices {
            unsafe { (self.stop)(*device) };
        }
        self.devices.clear();
        let sink = SINK.swap(null_mut(), Ordering::SeqCst);
        if !sink.is_null() {
            drop(unsafe { Box::from_raw(sink) });
        }
        if !self.device_list.is_null() {
            unsafe { CFRelease(self.device_list) };
            self.device_list = null_mut();
        }
        let _ = (&self.register, &self.start);
    }
}

unsafe extern "C" fn frame_callback(
    _device: *mut c_void,
    touches: *mut c_void,
    count: c_int,
    _timestamp: f64,
    _frame: c_int,
) {
    let mut points = Vec::with_capacity(count.max(0) as usize);
    if count > 0 && !touches.is_null() {
        let touches = touches as *const MtTouch;
        for index in 0..count as usize {
            let touch = unsafe { *touches.add(index) };
            if !TOUCHING.contains(&touch.state) {
                continue;
            }
            points.push(TouchPoint::new(
                touch.normalized.position.x,
                touch.normalized.position.y,
            ));
        }
    }
    let sink = SINK.load(Ordering::SeqCst);
    if !sink.is_null() {
        let sender = unsafe { &*sink };
        let _ = sender.send(points);
    }
}

unsafe fn symbol<T>(handle: *mut c_void, name: &str) -> Option<T> {
    let name = CString::new(name).ok()?;
    let pointer = unsafe { dlsym(handle, name.as_ptr()) };
    if pointer.is_null() {
        let error = unsafe { dlerror() };
        if !error.is_null() {
            let text = unsafe { CStr::from_ptr(error) }.to_string_lossy();
            log_line(&format!("multitouch: symbol missing: {text}"));
        }
        return None;
    }
    Some(unsafe { std::mem::transmute_copy(&pointer) })
}

fn log_line(message: &str) {
    eprintln!("{message}");
}
