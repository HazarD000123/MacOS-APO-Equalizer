import Foundation
import CoreAudio
import AudioToolbox

/// A lightweight description of a Core Audio device, enough for the UI to
/// list devices and for the engine to address them by AudioDeviceID.
struct AudioDeviceInfo: Identifiable, Hashable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let inputChannelCount: Int
    let outputChannelCount: Int

    var isOutputCapable: Bool { outputChannelCount > 0 }
    var isInputCapable: Bool { inputChannelCount > 0 }
}

/// Thin wrapper around the Core Audio HAL (AudioObject) C APIs, used to
/// enumerate microphones and virtual devices like BlackHole.
///
/// Nothing here writes to the system-wide default device. Each engine is
/// pointed at a specific device via `kAudioOutputUnitProperty_CurrentDevice`,
/// so other apps are never affected and there's nothing to restore on quit.
enum AudioDeviceManager {

    /// Name fragment used to identify the virtual loopback driver.
    /// BlackHole (https://github.com/ExistentialAudio/BlackHole) ships
    /// devices named "BlackHole 2ch" / "BlackHole 16ch" etc.
    static let virtualDeviceNameHint = "BlackHole"

    // MARK: - Enumeration

    static func allDevices() -> [AudioDeviceInfo] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize)
        guard status == noErr, dataSize > 0 else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceIDs)
        guard status == noErr else { return [] }

        return deviceIDs.compactMap { info(for: $0) }
    }

    static func info(for deviceID: AudioDeviceID) -> AudioDeviceInfo? {
        guard let name = deviceName(deviceID) else { return nil }
        let uid = deviceUID(deviceID) ?? "unknown-\(deviceID)"
        let outChannels = channelCount(deviceID, scope: kAudioObjectPropertyScopeOutput)
        let inChannels = channelCount(deviceID, scope: kAudioObjectPropertyScopeInput)
        return AudioDeviceInfo(id: deviceID, uid: uid, name: name, inputChannelCount: inChannels, outputChannelCount: outChannels)
    }

    static func outputDevices() -> [AudioDeviceInfo] {
        allDevices().filter { $0.isOutputCapable }
    }

    /// Real (non-virtual) microphones -- what the capture engine can read from.
    static func inputDevices() -> [AudioDeviceInfo] {
        allDevices().filter { $0.isInputCapable && !$0.name.localizedCaseInsensitiveContains(virtualDeviceNameHint) }
    }

    /// Finds the first installed BlackHole (or compatible) virtual device.
    static func virtualLoopbackDevice() -> AudioDeviceInfo? {
        allDevices().first { $0.name.localizedCaseInsensitiveContains(virtualDeviceNameHint) && $0.isOutputCapable }
    }

    static func isVirtualDeviceInstalled() -> Bool {
        virtualLoopbackDevice() != nil
    }

    // MARK: - Default device

    /// The mic the rest of the system is currently using -- used only to
    /// pick a sane initial selection in the UI, never written to.
    static func defaultInputDevice() -> AudioDeviceInfo? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        guard status == noErr, deviceID != 0 else { return nil }
        return info(for: deviceID)
    }

    /// Read-only lookup of the system output, used to decide where the
    /// optional Monitor tap plays out. Never written to.
    static func defaultOutputDevice() -> AudioDeviceInfo? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        guard status == noErr, deviceID != 0 else { return nil }
        return info(for: deviceID)
    }

    // MARK: - Sample rate

    /// Reads a device's current nominal sample rate. Used to pin BlackHole's
    /// rate to whatever the microphone is running at, so the ring buffer
    /// bridging the two engines never drifts or needs resampling.
    static func nominalSampleRate(_ deviceID: AudioDeviceID) -> Double? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var rate: Double = 0
        var size = UInt32(MemoryLayout<Double>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &rate)
        guard status == noErr, rate > 0 else { return nil }
        return rate
    }

    @discardableResult
    static func setNominalSampleRate(_ deviceID: AudioDeviceID, rate: Double) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var mutableRate = rate
        let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, UInt32(MemoryLayout<Double>.size), &mutableRate)
        return status == noErr
    }

    // MARK: - Property helpers

    static func deviceName(_ deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &name) { ptr -> OSStatus in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, ptr)
        }
        guard status == noErr else { return nil }
        return name as String
    }

    static func deviceUID(_ deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &uid) { ptr -> OSStatus in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, ptr)
        }
        guard status == noErr else { return nil }
        return uid as String
    }

    static func channelCount(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize)
        guard status == noErr, dataSize > 0 else { return 0 }

        let bufferListPointer = UnsafeMutableRawPointer.allocate(byteCount: Int(dataSize), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { bufferListPointer.deallocate() }
        status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &dataSize, bufferListPointer)
        guard status == noErr else { return 0 }

        let bufferList = bufferListPointer.assumingMemoryBound(to: AudioBufferList.self)
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        allDevices().first { $0.uid == uid }?.id
    }
}
