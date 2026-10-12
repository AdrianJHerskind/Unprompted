import AppKit
import CoreAudio
import IOKit.ps

/// Context the assistant can read without asking for any permissions.
enum SystemInfo {
    /// Seconds since the last keyboard, mouse or trackpad input.
    static func secondsSinceAnyInput() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    static func secondsSinceKeyPress() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
    }

    /// Total key presses since login. A count only: it never says which keys.
    static func keyPressCount() -> UInt32 {
        CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
    }

    /// nil on Macs without a battery.
    static func battery() -> (percent: Int, charging: Bool)? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let current = desc[kIOPSCurrentCapacityKey] as? Int,
                  let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            let onAC = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            return (current * 100 / max, onAC)
        }
        return nil
    }

    /// Whether some other app is recording sound right now, as it does during a call in any app.
    /// It only asks macOS whether audio input is running: it never uses the microphone itself.
    /// Asking every app takes several milliseconds of waiting on the audio system, so call it off
    /// the main thread.
    nonisolated static func isMicrophoneInUse() -> Bool {
        if let processes = audioObjects(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyProcessObjectList) {
            let ownPID = UInt32(bitPattern: getpid())
            return processes.contains { process in
                audioValue(process, kAudioProcessPropertyIsRunningInput) == 1 && audioValue(process, kAudioProcessPropertyPID) != ownPID
            }
        }
        // Before macOS 14 only devices can be asked, and only whether they run at all, so only
        // input-only ones count: a headset that's just playing music would look like a call.
        let devices = audioObjects(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDevices) ?? []
        return devices.contains { device in
            hasStreams(device, kAudioObjectPropertyScopeInput) && !hasStreams(device, kAudioObjectPropertyScopeOutput)
                && audioValue(device, kAudioDevicePropertyDeviceIsRunningSomewhere) == 1
        }
    }

    private static func audioAddress(_ selector: AudioObjectPropertySelector,
                                     _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    /// nil when there's no such property (like the process list before macOS 14).
    private static func audioObjects(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> [AudioObjectID]? {
        var address = audioAddress(selector)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr else { return nil }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &objects) == noErr else { return nil }
        return objects
    }

    private static func audioValue(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32? {
        var address = audioAddress(selector)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func hasStreams(_ device: AudioObjectID, _ scope: AudioObjectPropertyScope) -> Bool {
        var address = audioAddress(kAudioDevicePropertyStreams, scope)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr && size > 0
    }
}
