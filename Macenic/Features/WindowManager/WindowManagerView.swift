import SwiftUI

struct WindowManagerView: View {
    @Bindable var service: WindowManagerService
    var hotKey: HotKeyService?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if !service.hasAccessibilityPermission {
                    permissionBanner
                }

                tilesGrid

                if let message = service.lastActionMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.tint)
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }

                Divider()
                    .padding(.horizontal, 12)

                shortcutsSection
            }
            .padding(.vertical, 8)
        }
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                Text("Accessibility Permission Required")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange)
                Spacer()
            }

            Text("Window snapping needs Accessibility access to resize and position windows.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            Button {
                AccessibilityService.shared.openAccessibilitySettings()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gear")
                        .font(.system(size: 10))
                    Text("Open System Settings")
                        .font(.system(size: 11, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(.blue.opacity(0.12))
                .foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 14)
    }

    private var tilesGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                snapCard(
                    title: "Left Half",
                    icon: "rectangle.lefthalf.filled",
                    shortcut: hotKey?.snapLeftShortcut.displayString,
                    action: { service.snap(.leftHalf) }
                )
                snapCard(
                    title: "Right Half",
                    icon: "rectangle.righthalf.filled",
                    shortcut: hotKey?.snapRightShortcut.displayString,
                    action: { service.snap(.rightHalf) }
                )
            }

            HStack(spacing: 8) {
                snapCard(
                    title: "Maximize",
                    icon: "rectangle.fill",
                    shortcut: hotKey?.maximizeShortcut.displayString,
                    action: { service.snap(.maximize) }
                )
                snapCard(
                    title: "Top Half",
                    icon: "rectangle.tophalf.filled",
                    shortcut: nil,
                    action: { service.snap(.topHalf) }
                )
            }

            snapCard(
                title: "Restore Position",
                icon: "arrow.uturn.backward.circle.fill",
                shortcut: hotKey?.restoreShortcut.displayString,
                action: { service.snap(.restore) }
            )
        }
        .padding(.horizontal, 14)
    }

    private func snapCard(
        title: String,
        icon: String,
        shortcut: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.tint)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                }

                Spacer()

                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Click to record")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)

            if let hotKey {
                VStack(spacing: 6) {
                    shortcutRow(target: .snapLeft, label: "Snap Left", hotKey: hotKey)
                    shortcutRow(target: .snapRight, label: "Snap Right", hotKey: hotKey)
                    shortcutRow(target: .maximize, label: "Maximize", hotKey: hotKey)
                    shortcutRow(target: .restore, label: "Restore", hotKey: hotKey)
                }
                .padding(.horizontal, 14)
            }
        }
    }

    private func shortcutRow(target: HotKeyTarget, label: String, hotKey: HotKeyService) -> some View {
        let isRec = hotKey.recordingTarget == target
        let shortcut = hotKey.shortcut(for: target)

        return HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                if isRec {
                    hotKey.cancelRecording()
                } else {
                    hotKey.startRecording(for: target)
                }
            } label: {
                Text(isRec ? "Press keys..." : shortcut.displayString)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(isRec ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isRec ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(.quaternary))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
