import CoreAudio
import Foundation

/// System volume of the current output device.
public enum VolumeControl {
    /// macOS moves the volume in 16 steps, and draws its HUD once per step.
    public static let stepCount = 16

    /// Turns the volume by whole steps through the system's own volume keys.
    ///
    /// Writing `kAudioDevicePropertyVolumeScalar` directly changes the level but
    /// leaves the screen silent, and the system only shows the level it was told
    /// about once, after the change is over. Pressing the keys instead is what
    /// makes the HUD follow a swipe, one 1/16 step at a time — the same feedback
    /// the brightness keys give.
    public static func adjust(steps: Int) {
        guard steps != 0 else { return }

        guard AccessibilityPermission.isGranted else {
            // No event posting: fall back to a direct write, which moves the
            // level without the HUD.
            let level = (current() ?? 0.5) + Float(steps) / Float(stepCount)
            Debug.log("volume: \(steps) step(s) by direct write, accessibility permission missing")
            set(level)
            return
        }

        Debug.log("volume: \(steps) step(s)")
        let key = steps > 0 ? MediaKeys.volumeUp : MediaKeys.volumeDown
        for _ in 0..<abs(steps) {
            MediaKeys.post(key)
        }
    }

    public static func current() -> Float? {
        guard let device = defaultOutputDevice() else { return nil }
        return getScalar(device, selector: kAudioDevicePropertyVolumeScalar, element: 0)
            ?? averageChannelVolume(device)
    }

    public static func set(_ value: Float) {
        guard let device = defaultOutputDevice() else { return }
        let clamped = min(max(value, 0), 1)

        if setScalar(device, selector: kAudioDevicePropertyVolumeScalar, element: 0, value: clamped) {
            // Raising the volume on a muted device should be audible again.
            if clamped > 0 {
                _ = setUInt32(device, selector: kAudioDevicePropertyMute, element: 0, value: 0)
            }
            return
        }

        for element in channelElements(device) {
            _ = setScalar(device, selector: kAudioDevicePropertyVolumeScalar, element: element, value: clamped)
        }
    }

    // MARK: - CoreAudio plumbing

    private static func defaultOutputDevice() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device
        )
        guard status == noErr, device != 0 else { return nil }
        return device
    }

    private static func address(_ selector: AudioObjectPropertySelector, _ element: UInt32) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
    }

    private static func getScalar(_ device: AudioDeviceID, selector: AudioObjectPropertySelector, element: UInt32) -> Float? {
        var address = address(selector, element)
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    private static func setScalar(_ device: AudioDeviceID, selector: AudioObjectPropertySelector, element: UInt32, value: Float) -> Bool {
        var address = address(selector, element)
        var settable: DarwinBoolean = false
        guard AudioObjectIsPropertySettable(device, &address, &settable) == noErr, settable.boolValue else {
            return false
        }
        var mutableValue = value
        let size = UInt32(MemoryLayout<Float32>.size)
        return AudioObjectSetPropertyData(device, &address, 0, nil, size, &mutableValue) == noErr
    }

    private static func setUInt32(_ device: AudioDeviceID, selector: AudioObjectPropertySelector, element: UInt32, value: UInt32) -> Bool {
        var address = address(selector, element)
        var mutableValue = value
        let size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectSetPropertyData(device, &address, 0, nil, size, &mutableValue) == noErr
    }

    private static func channelElements(_ device: AudioDeviceID) -> [UInt32] {
        var address = address(kAudioDevicePropertyStreamConfiguration, 0)
        var size = UInt32(0)
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr, size > 0 else {
            return []
        }
        let list = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { list.deallocate() }
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, list) == noErr else { return [] }

        let buffers = UnsafeMutableAudioBufferListPointer(list.assumingMemoryBound(to: AudioBufferList.self))
        let channels = buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
        return (1...max(channels, 1)).map { UInt32($0) }
    }

    private static func averageChannelVolume(_ device: AudioDeviceID) -> Float? {
        let values = channelElements(device).compactMap {
            getScalar(device, selector: kAudioDevicePropertyVolumeScalar, element: $0)
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Float(values.count)
    }
}
