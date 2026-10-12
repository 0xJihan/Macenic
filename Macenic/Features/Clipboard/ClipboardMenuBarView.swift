import SwiftUI
import AppKit

struct ClipboardMenuBarView: View {
    @Bindable var service: ClipboardService
    var hotKey: HotKeyService?
    private var appearance = AppearanceService.shared

    @State private var showSettingsPopover: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .opacity(0.3)
            ClipboardHistoryView(service: service, hotKey: hotKey)
        }
        .frame(width: 370, height: 470)
        .glassmorphic(opacity: appearance.glassOpacity, cornerRadius: 16)
        .onDisappear {
            ClipboardPreviewController.shared.hideImmediately()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.18))
                    .frame(width: 24, height: 24)
                Image(systemName: "clipboard.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tint)
            }

            Text("Clipboard")
                .font(.system(size: 13, weight: .bold))

            Spacer()

            Text("\(service.filteredItems.count) items")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())

            // Glassmorphism and UI appearance button
            Button {
                showSettingsPopover.toggle()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(5)
                    .background(Color.white.opacity(showSettingsPopover ? 0.15 : 0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Adjust Glassmorphism & Appearance")
            .popover(isPresented: $showSettingsPopover, arrowEdge: .bottom) {
                GlassmorphismSettingsPopover()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.04))
    }
}

struct GlassmorphismSettingsPopover: View {
    @Bindable var appearance = AppearanceService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)
                Text("Glassmorphism Effect")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text("\(Int(appearance.glassOpacity * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
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

            Divider()
                .padding(.vertical, 2)

            HStack {
                Button("Reset Default") {
                    appearance.glassOpacity = 0.75
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding(14)
        .frame(width: 240)
    }
}
