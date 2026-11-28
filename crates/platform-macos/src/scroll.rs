//! Drops scroll wheel events while a swipe is running, so adjusting the volume
//! does not also scroll the window underneath.
//!
//! Suppressing events needs an event tap, which needs Accessibility access. If
//! the tap cannot be created the app keeps working, the scroll just goes through.

use std::ffi::c_void;
use std::ptr::null_mut;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread::JoinHandle;

#[link(name = "CoreGraphics", kind = "framework")]
extern "C" {
    fn CGEventTapCreate(
        tap: u32,
        place: u32,
        options: u32,
        events_of_interest: u64,
        callback: TapCallback,
        user_info: *mut c_void,
    ) -> *mut c_void;
    fn CGEventTapEnable(tap: *mut c_void, enable: bool);
    static kCFRunLoopCommonModes: *const c_void;
}

#[link(name = "CoreFoundation", kind = "framework")]
extern "C" {
    fn CFMachPortCreateRunLoopSource(
        allocator: *const c_void,
        port: *mut c_void,
        order: isize,
    ) -> *mut c_void;
    fn CFRunLoopGetCurrent() -> *mut c_void;
    fn CFRunLoopAddSource(run_loop: *mut c_void, source: *mut c_void, mode: *const c_void);
    fn CFRunLoopRun();
    fn CFRunLoopStop(run_loop: *mut c_void);
    fn CFRelease(value: *const c_void);
}

const SESSION_EVENT_TAP: u32 = 1;
const HEAD_INSERT_EVENT_TAP: u32 = 0;
const TAP_OPTION_DEFAULT: u32 = 0;
const SCROLL_WHEEL_EVENT: u32 = 22;
const TAP_DISABLED_BY_TIMEOUT: u32 = 0xFFFF_FFFE;
const TAP_DISABLED_BY_USER_INPUT: u32 = 0xFFFF_FFFF;

type TapCallback =
    unsafe extern "C" fn(proxy: *mut c_void, kind: u32, event: *mut c_void, refcon: *mut c_void)
        -> *mut c_void;

pub struct Suppressor {
    active: Arc<AtomicBool>,
    run_loop: *mut c_void,
    thread: Option<JoinHandle<()>>,
}

impl Suppressor {
    pub fn start() -> Option<Self> {
        let active = Arc::new(AtomicBool::new(false));
        let flag = active.clone();
        // A raw pointer is not Send; the address travels as a number.
        let (ready_tx, ready_rx) = std::sync::mpsc::channel::<usize>();

        let thread = std::thread::Builder::new()
            .name("TrackControl.ScrollTap".into())
            .spawn(move || {
                let user_info = Arc::as_ptr(&flag) as *mut c_void;
                let tap = unsafe {
                    CGEventTapCreate(
                        SESSION_EVENT_TAP,
                        HEAD_INSERT_EVENT_TAP,
                        TAP_OPTION_DEFAULT,
                        1 << SCROLL_WHEEL_EVENT,
                        tap_callback,
                        user_info,
                    )
                };
                if tap.is_null() {
                    eprintln!("scroll suppressor: no event tap (Accessibility access needed)");
                    let _ = ready_tx.send(0);
                    return;
                }

                let run_loop = unsafe { CFRunLoopGetCurrent() };
                let source = unsafe { CFMachPortCreateRunLoopSource(null_mut(), tap, 0) };
                unsafe {
                    CFRunLoopAddSource(run_loop, source, kCFRunLoopCommonModes);
                    CGEventTapEnable(tap, true);
                }
                let _ = ready_tx.send(run_loop as usize);
                unsafe { CFRunLoopRun() };
                unsafe {
                    CGEventTapEnable(tap, false);
                    CFRelease(source);
                }
                drop(flag);
            })
            .ok()?;

        let run_loop = ready_rx.recv().ok()? as *mut c_void;
        if run_loop.is_null() {
            return None;
        }
        Some(Self {
            active,
            run_loop,
            thread: Some(thread),
        })
    }

    /// Called by the gesture loop: `true` while a swipe is in progress.
    pub fn set_active(&self, value: bool) {
        self.active.store(value, Ordering::SeqCst);
    }

    pub fn stop(&mut self) {
        if !self.run_loop.is_null() {
            unsafe { CFRunLoopStop(self.run_loop) };
            self.run_loop = null_mut();
        }
        if let Some(thread) = self.thread.take() {
            let _ = thread.join();
        }
    }
}

impl Drop for Suppressor {
    fn drop(&mut self) {
        self.stop();
    }
}

unsafe extern "C" fn tap_callback(
    _proxy: *mut c_void,
    kind: u32,
    event: *mut c_void,
    refcon: *mut c_void,
) -> *mut c_void {
    if kind == TAP_DISABLED_BY_TIMEOUT || kind == TAP_DISABLED_BY_USER_INPUT || refcon.is_null() {
        return event;
    }
    let active = unsafe { &*(refcon as *const AtomicBool) };
    if active.load(Ordering::SeqCst) {
        return null_mut(); // dropping the event swallows the scroll
    }
    event
}
