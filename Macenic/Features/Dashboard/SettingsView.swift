import SwiftUI
import AppKit

struct SettingsView: View {
    @Bindable var appearance = AppearanceService.shared
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .opacity(0.3)

            ScrollView {
                VStack(spacing: 16) {
                    appearanceSection
                    clipboardSection
                    shortcutsSection
                }
                .padding(16)
            }

            Divider()
                .opacity(0.3)
            footer
        }
        .frame(width: 320, height: 420)
        .glassmorphic(opacity: appearance.glassOpacity, cornerRadius: 16)
    }

    private var header: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.18))
                    .frame(width: 26, height: 26)
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tint)
            }
            Text("Settings")
                .font(.system(size: 13, weight: .bold))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.04))
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Glassmorphism & Appearance", systemImage: "sparkles")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Effect Visibility / Blur")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(appearance.glassOpacity * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                }

                Slider(value: $appearance.glassOpacity, in: 0.15...1.0, step: 0.05)
                    .tint(.accentColor)

                HStack {
                    Text("Translucent")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("Vibrant Glass")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
        }
    }

    private var clipboardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Clipboard Features", systemImage: "clipboard")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.primary)

            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Direct Auto-Paste")
                            .font(.system(size: 11, weight: .medium))
                        Text("Paste directly into the frontmost app on select")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.green)
                }

                Divider()
                    .opacity(0.2)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hover Zoom Preview")
                            .font(.system(size: 11, weight: .medium))
                        Text("Slideout panel for large text and images")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.green)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
        }
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Global Shortcut", systemImage: "keyboard")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.primary)

            HStack {
                Text("Clipboard HUD")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(appState.hotKey.currentShortcut.displayString)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
        }
    }

    private var footer: some View {
        HStack {
            Button("Reset Default Theme") {
                appearance.glassOpacity = 0.75
            }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)

            Spacer()

            Button("Done") {
                NSApp.keyWindow?.orderOut(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
    }
}
