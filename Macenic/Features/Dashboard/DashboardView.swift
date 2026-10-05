import SwiftUI

enum DashboardTab: String, CaseIterable, Identifiable {
    case system = "System"
    case controls = "Controls"
    case processes = "Processes"
    case windows = "Windows"
    case devTools = "DevTools"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .system: return "gauge.with.dots.needle.bottom.50percent"
        case .processes: return "cpu"
        case .windows: return "macwindow.on.rectangle"
        case .devTools: return "curlybraces"
        case .controls: return "slider.horizontal.3"
        }
    }
}

enum SystemSubtab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case network = "Network"
    case storage = "Storage"
    case battery = "Battery"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview: return "chart.bar.xaxis"
        case .network: return "wifi"
        case .storage: return "internaldrive"
        case .battery: return "battery.100"
        }
    }
}

enum ControlsSubtab: String, CaseIterable, Identifiable {
    case clipboard = "Clipboard"
    case audio = "Audio"
    case toggles = "Toggles"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .clipboard: return "clipboard"
        case .audio: return "speaker.wave.2"
        case .toggles: return "switch.2"
        }
    }
}

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: DashboardTab = .system
    @State private var selectedSystemSubtab: SystemSubtab = .overview
    @State private var selectedControlsSubtab: ControlsSubtab = .clipboard

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            tabPicker
            Divider()
            tabContent
                .frame(height: 420)
            Divider()
            footer
        }
        .frame(width: 380)
        .alert(
            "Version \(appState.updates.latestVersion) available",
            isPresented: updateAlertPresented
        ) {
            Button("Download") {
                appState.updates.openDownload()
            }
            Button("Later", role: .cancel) {
                appState.updates.dismissUpdate()
            }
        } message: {
            Text(updateMessage)
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tint)
            Text("Macenic")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1")")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var tabPicker: some View {
        HStack(spacing: 2) {
            ForEach(DashboardTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                        Text(tab.rawValue)
                            .font(.system(size: 9.5, weight: selectedTab == tab ? .semibold : .medium))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedTab == tab ? AnyShapeStyle(Color.accentColor.opacity(0.18)) : AnyShapeStyle(Color.clear))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(selectedTab == tab ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
                    )
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .system:
            VStack(spacing: 0) {
                subtabBar(selection: $selectedSystemSubtab) { $0.icon }
                Divider()

                switch selectedSystemSubtab {
                case .overview:
                    SystemMonitorView(monitor: appState.systemMonitor)
                        .padding(.horizontal, 12)
                case .network:
                    NetworkMonitorView(network: appState.networkMonitor, systemMonitor: appState.systemMonitor)
                case .storage:
                    StorageMonitorView(service: appState.storageMonitor)
                case .battery:
                    BatteryHealthView(service: appState.batteryHealth)
                }
            }
        case .processes:
            ProcessManagerView(service: appState.processManager)
        case .windows:
            WindowManagerView(service: appState.windowManager, hotKey: appState.hotKey)
        case .devTools:
            DevToolkitView(service: appState.devToolkit)
        case .controls:
            VStack(spacing: 0) {
                subtabBar(selection: $selectedControlsSubtab) { $0.icon }
                Divider()

                switch selectedControlsSubtab {
                case .clipboard:
                    ClipboardHistoryView(service: appState.clipboard, hotKey: appState.hotKey)
                case .audio:
                    AudioSwitcherView(service: appState.audio)
                case .toggles:
                    QuickTogglesView(
                        keepAwake: appState.keepAwake,
                        keyboardCleaner: appState.keyboardCleaner
                    )
                }
            }
        }
    }

    private func subtabBar<T: CaseIterable & Identifiable & RawRepresentable>(
        selection: Binding<T>,
        icon: @escaping (T) -> String
    ) -> some View where T.RawValue == String, T.AllCases: RandomAccessCollection {
        HStack(spacing: 3) {
            ForEach(Array(T.allCases)) { sub in
                Button {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        selection.wrappedValue = sub
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: icon(sub))
                            .font(.system(size: 10))
                        Text(sub.rawValue)
                            .font(.system(size: 10, weight: selection.wrappedValue == sub ? .semibold : .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(selection.wrappedValue == sub ? AnyShapeStyle(Color.primary.opacity(0.1)) : AnyShapeStyle(Color.clear))
                    )
                    .foregroundStyle(selection.wrappedValue == sub ? Color.primary : Color.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                showAboutWindow()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                    Text("About")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button {
                Task { await appState.updates.checkForUpdates() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 10))
                    Text("Check Updates")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private static weak var aboutWindow: NSWindow?

    private var updateAlertPresented: Binding<Bool> {
        Binding(
            get: { appState.updates.isUpdateAvailable },
            set: { newValue in
                if !newValue {
                    appState.updates.dismissUpdate()
                }
            }
        )
    }

    private var updateMessage: String {
        if appState.updates.releaseNotes.isEmpty {
            return """
            • Bug fixes
            • Faster performance
            • UI improvements
            """
        }

        let lines = appState.updates.releaseNotes
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .map { line in
                if line.hasPrefix("-") || line.hasPrefix("*") || line.hasPrefix("•") {
                    return "• " + line.dropFirst().trimmingCharacters(in: .whitespaces)
                }
                return "• " + line
            }

        return lines.joined(separator: "\n")
    }

    private func showAboutWindow() {
        if let existing = Self.aboutWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let aboutView = AboutView()
        let hostingView = NSHostingView(rootView: aboutView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 420)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        Self.aboutWindow = window
    }
}
