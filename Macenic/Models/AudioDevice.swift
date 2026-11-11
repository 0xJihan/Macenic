import CoreAudio

struct AudioDevice: Identifiable {
    let id: AudioDeviceID
    let name: String
    let hasInput: Bool
    let hasOutput: Bool
}
