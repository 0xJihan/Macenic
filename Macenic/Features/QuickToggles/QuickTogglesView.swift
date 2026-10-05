import SwiftUI
import ServiceManagement

struct QuickTogglesView: View {
    let keepAwake: KeepAwakeService
    let keyboardCleaner: KeyboardCleanerService
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 4) {
            toggleRow(
                icon: "power",
                title: "Launch at Login",
                subtitle: "Start automatically on login",
                isActive: launchAtLogin
            ) {
                do {
                    if launchAtLogin {
                        try SMAppService.mainApp.unregister()
                    } else {
                        try SMAppService.mainApp.register()
                    }
                } catch {}
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }

            toggleRow(
                icon: "moon.zzz",
                title: "Keep Awake",
                subtitle: "Prevent display from sleeping",
                isActive: keepAwake.isActive
            ) {
                keepAwake.toggle()
            }

            toggleRow(
                icon: "keyboard",
                title: "Keyboard Cleaner",
                subtitle: "Lock keyboard for 30 seconds",
                isActive: keyboardCleaner.isActive
            ) {
                keyboardCleaner.activate(duration: 30)
            }

            if keyboardCleaner.permissionDenied {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text("Accessibility permission required")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    Button {
                        keyboardCleaner.openAccessibilitySettings()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "gear")
                                .font(.system(size: 10))
                            Text("Open Accessibility Settings")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    Text("Enable Macenic in the list, then try again")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func toggleRow(
        icon: String,
        title: String,
        subtitle: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .frame(width: 28)
                    .foregroundStyle(isActive ? .green : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Circle()
                    .fill(isActive ? .green : .secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
