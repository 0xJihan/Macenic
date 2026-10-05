import SwiftUI
import CoreAudio

struct AudioSwitcherView: View {
    let service: AudioService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                deviceSection(
                    title: "Output",
                    icon: "speaker.wave.2",
                    devices: service.outputDevices,
                    activeID: service.defaultOutputID,
                    onSelect: { service.setDefaultOutput($0) }
                )

                if !service.inputDevices.isEmpty {
                    Divider()
                        .padding(.horizontal, 12)
                    inputSection
                }
            }
            .padding(.vertical, 8)
        }
        .onAppear { service.refresh() }
    }

    private func deviceSection(
        title: String,
        icon: String,
        devices: [AudioDevice],
        activeID: AudioDeviceID,
        onSelect: @escaping (AudioDeviceID) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ForEach(devices) { device in
                Button {
                    onSelect(device.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: device.id == activeID ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 12))
                            .foregroundStyle(device.id == activeID ? .blue : .secondary)
                        Text(device.name)
                            .font(.system(size: 12))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Input", systemImage: "mic")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ForEach(service.inputDevices) { device in
                VStack(spacing: 4) {
                    Button {
                        service.setDefaultInput(device.id)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: device.id == service.defaultInputID ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 12))
                                .foregroundStyle(device.id == service.defaultInputID ? .blue : .secondary)
                            Text(device.name)
                                .font(.system(size: 12))
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    let hasControl = service.hasInputVolumeControl(device.id)
                    Slider(
                        value: Binding(
                            get: { Double(service.inputVolume(for: device.id)) },
                            set: { service.setInputVolume(device.id, value: Float($0)) }
                        ),
                        in: 0...1
                    )
                    .disabled(!hasControl)
                    .opacity(hasControl ? 1 : 0.4)
                    .padding(.leading, 28)
                    .padding(.trailing, 16)
                }
            }
        }
    }
}
