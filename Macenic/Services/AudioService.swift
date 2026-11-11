import CoreAudio
import Foundation

@Observable
final class AudioService {
    var outputDevices: [AudioDevice] = []
    var inputDevices: [AudioDevice] = []
    var defaultOutputID: AudioDeviceID = 0
    var defaultInputID: AudioDeviceID = 0
    var inputVolumeCache: [AudioDeviceID: Float] = [:]
    var inputVolumeWritable: [AudioDeviceID: Bool] = [:]
    var inputMuteCache: [AudioDeviceID: Bool] = [:]
    var inputMuteWritable: [AudioDeviceID: Bool] = [:]

    func refresh() {
        loadDevices()
        loadDefaults()
        refreshInputVolumes()
    }

    func setDefaultOutput(_ deviceID: AudioDeviceID) {
        setDefault(deviceID, selector: kAudioHardwarePropertyDefaultOutputDevice)
        defaultOutputID = deviceID
    }

    func setDefaultInput(_ deviceID: AudioDeviceID) {
        setDefault(deviceID, selector: kAudioHardwarePropertyDefaultInputDevice)
        defaultInputID = deviceID
        refreshInputVolume(for: deviceID)
    }

    func inputVolume(for deviceID: AudioDeviceID) -> Float {
        if let value = inputVolumeCache[deviceID] { return value }
        let value = getInputVolume(deviceID) ?? 0.5
        inputVolumeCache[deviceID] = value
        inputVolumeWritable[deviceID] = hasInputVolumeControl(deviceID)
        inputMuteCache[deviceID] = isMuted(deviceID)
        inputMuteWritable[deviceID] = hasMuteControl(deviceID)
        return value
    }

    func hasInputVolumeControl(_ deviceID: AudioDeviceID) -> Bool {
        if let value = inputVolumeWritable[deviceID] { return value }
        let value = hasVolumeControl(deviceID, scope: kAudioDevicePropertyScopeInput)
        inputVolumeWritable[deviceID] = value
        return value
    }

    func setInputVolume(_ deviceID: AudioDeviceID, value: Float) {
        guard hasInputVolumeControl(deviceID) else { return }
        setVolume(deviceID, scope: kAudioDevicePropertyScopeInput, value: value)
        inputVolumeCache[deviceID] = value
        if value <= 0 {
            setMuted(deviceID, true)
        } else {
            setMuted(deviceID, false)
        }
    }

    func hasMuteControl(_ deviceID: AudioDeviceID) -> Bool {
        if let value = inputMuteWritable[deviceID] { return value }
        let value = hasMuteProperty(deviceID, scope: kAudioDevicePropertyScopeInput)
        inputMuteWritable[deviceID] = value
        return value
    }

    func isMuted(_ deviceID: AudioDeviceID) -> Bool {
        if let value = inputMuteCache[deviceID] { return value }
        let value = getMuted(deviceID) ?? false
        inputMuteCache[deviceID] = value
        return value
    }

    func setMuted(_ deviceID: AudioDeviceID, _ muted: Bool) {
        guard hasMuteControl(deviceID) else { return }
        setMute(deviceID, scope: kAudioDevicePropertyScopeInput, muted: muted)
        inputMuteCache[deviceID] = muted
    }

    private func setDefault(_ deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) {
        var id = deviceID
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size), &id
        )
    }

    private func loadDevices() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &dataSize
        ) == noErr else { return }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)

        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &dataSize, &ids
        ) == noErr else { return }

        var outputs: [AudioDevice] = []
        var inputs: [AudioDevice] = []

        for id in ids {
            guard let name = deviceName(id) else { continue }
            let hasOut = hasStreams(id, scope: kAudioDevicePropertyScopeOutput)
            let hasIn = hasStreams(id, scope: kAudioDevicePropertyScopeInput)
            let device = AudioDevice(id: id, name: name, hasInput: hasIn, hasOutput: hasOut)
            if hasOut { outputs.append(device) }
            if hasIn { inputs.append(device) }
        }

        outputDevices = outputs
        inputDevices = inputs
    }

    private func loadDefaults() {
        defaultOutputID = getDefault(kAudioHardwarePropertyDefaultOutputDevice)
        defaultInputID = getDefault(kAudioHardwarePropertyDefaultInputDevice)
    }

    private func refreshInputVolumes() {
        var nextCache: [AudioDeviceID: Float] = [:]
        var nextWritable: [AudioDeviceID: Bool] = [:]
        var nextMute: [AudioDeviceID: Bool] = [:]
        var nextMuteWritable: [AudioDeviceID: Bool] = [:]
        for device in inputDevices {
            let writable = hasVolumeControl(device.id, scope: kAudioDevicePropertyScopeInput)
            nextWritable[device.id] = writable
            nextCache[device.id] = getInputVolume(device.id) ?? 0.5
            nextMuteWritable[device.id] = hasMuteProperty(device.id, scope: kAudioDevicePropertyScopeInput)
            nextMute[device.id] = getMuted(device.id) ?? false
        }
        inputVolumeCache = nextCache
        inputVolumeWritable = nextWritable
        inputMuteCache = nextMute
        inputMuteWritable = nextMuteWritable
    }

    private func refreshInputVolume(for deviceID: AudioDeviceID) {
        inputVolumeCache[deviceID] = getInputVolume(deviceID) ?? 0.5
        inputVolumeWritable[deviceID] = hasVolumeControl(deviceID, scope: kAudioDevicePropertyScopeInput)
        inputMuteWritable[deviceID] = hasMuteProperty(deviceID, scope: kAudioDevicePropertyScopeInput)
        inputMuteCache[deviceID] = getMuted(deviceID) ?? false
    }

    private func getDefault(_ selector: AudioObjectPropertySelector) -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &deviceID
        )
        return deviceID
    }

    private func deviceName(_ deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        guard AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &size, &name
        ) == noErr else { return nil }
        return name as String
    }

    private func hasStreams(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            deviceID, &address, 0, nil, &size
        ) == noErr else { return false }
        return size > 0
    }

    private func getInputVolume(_ deviceID: AudioDeviceID) -> Float? {
        getVolume(deviceID, scope: kAudioDevicePropertyScopeInput)
    }

    private func getVolume(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Float? {
        let elements = volumeElements(deviceID, scope: scope)
        guard !elements.isEmpty else { return nil }
        if elements.contains(kAudioObjectPropertyElementMain) {
            return readVolume(deviceID, scope: scope, element: kAudioObjectPropertyElementMain)
        }
        let values = elements.compactMap { readVolume(deviceID, scope: scope, element: $0) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Float(values.count)
    }

    private func setVolume(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, value: Float) {
        let elements = settableVolumeElements(deviceID, scope: scope)
        guard !elements.isEmpty else { return }
        if elements.contains(kAudioObjectPropertyElementMain) {
            writeVolume(deviceID, scope: scope, element: kAudioObjectPropertyElementMain, value: value)
            return
        }
        for element in elements {
            writeVolume(deviceID, scope: scope, element: element, value: value)
        }
    }

    private func hasVolumeControl(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        !settableVolumeElements(deviceID, scope: scope).isEmpty
    }

    private func volumeElements(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> [AudioObjectPropertyElement] {
        let candidates: [AudioObjectPropertyElement] = [kAudioObjectPropertyElementMain, 1, 2]
        return candidates.filter { hasVolumeProperty(deviceID, scope: scope, element: $0) }
    }

    private func settableVolumeElements(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> [AudioObjectPropertyElement] {
        let candidates: [AudioObjectPropertyElement] = [kAudioObjectPropertyElementMain, 1, 2]
        return candidates.filter { isVolumeSettable(deviceID, scope: scope, element: $0) }
    }

    private func hasVolumeProperty(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, element: AudioObjectPropertyElement) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: scope,
            mElement: element
        )
        return AudioObjectHasProperty(deviceID, &address)
    }

    private func isVolumeSettable(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, element: AudioObjectPropertyElement) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: scope,
            mElement: element
        )
        var isSettable: DarwinBoolean = false
        let status = AudioObjectIsPropertySettable(deviceID, &address, &isSettable)
        return status == noErr && isSettable.boolValue
    }

    private func readVolume(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, element: AudioObjectPropertyElement) -> Float? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: scope,
            mElement: element
        )
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        return status == noErr ? Float(value) : nil
    }

    private func writeVolume(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, element: AudioObjectPropertyElement, value: Float) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: scope,
            mElement: element
        )
        var newValue = Float32(min(max(value, 0), 1))
        var size = UInt32(MemoryLayout<Float32>.size)
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &newValue)
    }

    private func getMuted(_ deviceID: AudioDeviceID) -> Bool? {
        let elements = muteElements(deviceID, scope: kAudioDevicePropertyScopeInput)
        guard !elements.isEmpty else { return nil }
        if elements.contains(kAudioObjectPropertyElementMain) {
            return readMute(deviceID, scope: kAudioDevicePropertyScopeInput, element: kAudioObjectPropertyElementMain)
        }
        let values = elements.compactMap { readMute(deviceID, scope: kAudioDevicePropertyScopeInput, element: $0) }
        guard !values.isEmpty else { return nil }
        return values.contains(true)
    }

    private func setMute(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, muted: Bool) {
        let elements = settableMuteElements(deviceID, scope: scope)
        guard !elements.isEmpty else { return }
        if elements.contains(kAudioObjectPropertyElementMain) {
            writeMute(deviceID, scope: scope, element: kAudioObjectPropertyElementMain, muted: muted)
            return
        }
        for element in elements {
            writeMute(deviceID, scope: scope, element: element, muted: muted)
        }
    }

    private func hasMuteProperty(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        !settableMuteElements(deviceID, scope: scope).isEmpty
    }

    private func muteElements(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> [AudioObjectPropertyElement] {
        let candidates: [AudioObjectPropertyElement] = [kAudioObjectPropertyElementMain, 1, 2]
        return candidates.filter { hasMuteProperty(deviceID, scope: scope, element: $0) }
    }

    private func settableMuteElements(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> [AudioObjectPropertyElement] {
        let candidates: [AudioObjectPropertyElement] = [kAudioObjectPropertyElementMain, 1, 2]
        return candidates.filter { isMuteSettable(deviceID, scope: scope, element: $0) }
    }

    private func hasMuteProperty(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, element: AudioObjectPropertyElement) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: scope,
            mElement: element
        )
        return AudioObjectHasProperty(deviceID, &address)
    }

    private func isMuteSettable(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, element: AudioObjectPropertyElement) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: scope,
            mElement: element
        )
        var isSettable: DarwinBoolean = false
        let status = AudioObjectIsPropertySettable(deviceID, &address, &isSettable)
        return status == noErr && isSettable.boolValue
    }

    private func readMute(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, element: AudioObjectPropertyElement) -> Bool? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: scope,
            mElement: element
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        return status == noErr ? (value != 0) : nil
    }

    private func writeMute(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope, element: AudioObjectPropertyElement, muted: Bool) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: scope,
            mElement: element
        )
        var value: UInt32 = muted ? 1 : 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &value)
    }
}
