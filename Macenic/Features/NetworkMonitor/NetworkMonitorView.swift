import SwiftUI

struct NetworkMonitorView: View {
    @Bindable var network: NetworkMonitorService
    let systemMonitor: SystemMonitorService

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                statusCard
                speedsRow
                detailsGrid
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .onAppear { network.onScreenAppear() }
        .onDisappear { network.onScreenDisappear() }
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(network.info.isConnected ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: network.info.interfaceType.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(network.info.isConnected ? .green : .red)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(network.info.ssid ?? "\(network.info.interfaceType.rawValue) (\(network.info.interfaceName))")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Circle()
                        .fill(network.info.isConnected ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                }

                Text(network.info.isConnected ? "Connected to Internet" : "No Internet Connection")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                network.measureLatency()
            } label: {
                HStack(spacing: 4) {
                    if network.info.isMeasuringLatency {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9))
                    }
                    if let latency = network.info.latencyMs {
                        Text(String(format: "%.0f ms", latency))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    } else {
                        Text("Test")
                            .font(.system(size: 10))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.quaternary.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
            .disabled(network.info.isMeasuringLatency)
        }
        .padding(10)
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var speedsRow: some View {
        HStack(spacing: 8) {
            speedTile(
                icon: "arrow.down.circle.fill",
                title: "Download",
                value: ByteFormatter.formatSpeed(systemMonitor.networkSpeedIn),
                color: .blue
            )
            speedTile(
                icon: "arrow.up.circle.fill",
                title: "Upload",
                value: ByteFormatter.formatSpeed(systemMonitor.networkSpeedOut),
                color: .orange
            )
        }
    }

    private func speedTile(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
            }
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var detailsGrid: some View {
        VStack(spacing: 6) {
            detailRow(label: "Interface", value: network.info.interfaceName)
            detailRow(label: "Interface Type", value: network.info.interfaceType.rawValue)
            if let ip = network.info.localIP {
                detailRowWithCopy(label: "Local IP", value: ip)
            }
            if let latency = network.info.latencyMs {
                detailRow(label: "Latency", value: String(format: "%.1f ms (Cloudflare)", latency))
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }

    private func detailRowWithCopy(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")
            }
        }
    }
}
