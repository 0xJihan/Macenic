import SwiftUI

struct SystemMonitorView: View {
    let monitor: SystemMonitorService

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                GaugeView(
                    title: "CPU",
                    value: monitor.cpuUsage,
                    detail: "\(Int(monitor.cpuUsage))% used",
                    color: cpuColor
                )
                GaugeView(
                    title: "Memory",
                    value: monitor.memoryUsagePercent,
                    detail: "\(ByteFormatter.format(monitor.memoryUsed)) / \(ByteFormatter.format(monitor.memoryTotal))",
                    color: memoryColor
                )
                GaugeView(
                    title: "Disk",
                    value: monitor.diskUsagePercent,
                    detail: "\(ByteFormatter.format(monitor.diskUsed)) / \(ByteFormatter.format(monitor.diskTotal))",
                    color: diskColor
                )
                GaugeView(
                    title: "GPU",
                    value: monitor.gpuUtilization,
                    detail: "\(Int(monitor.gpuUtilization))% used",
                    color: gpuUsageColor
                )

                Divider()

                networkSection

                if monitor.hasBattery {
                    Divider()
                    batterySection
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
    }

    private var networkSection: some View {
        HStack(spacing: 0) {
            metricTile(
                icon: "arrow.down.circle.fill",
                label: "Download",
                value: ByteFormatter.formatSpeed(monitor.networkSpeedIn),
                color: .blue
            )
            metricTile(
                icon: "arrow.up.circle.fill",
                label: "Upload",
                value: ByteFormatter.formatSpeed(monitor.networkSpeedOut),
                color: .orange
            )
        }
    }

    private var batterySection: some View {
        VStack(spacing: 6) {
            Image(systemName: batteryIcon)
                .font(.system(size: 22))
                .foregroundStyle(batteryColor)

            HStack(spacing: 6) {
                Text("\(monitor.batteryLevel)%")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                if monitor.batteryIsCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                }
            }

            HStack(spacing: 8) {
                if monitor.batteryTimeRemaining >= 0 {
                    Text(batteryTimeFormatted)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Text("Health: \(monitor.batteryHealth)%")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                if monitor.batteryCycleCount > 0 {
                    Text("\(monitor.batteryCycleCount) cycles")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            if let lastCharging = monitor.lastChargingTime {
                Text("Last charged: \(lastCharging, style: .relative) ago")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func metricTile(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var cpuColor: Color {
        monitor.cpuUsage > 80 ? .red : monitor.cpuUsage > 50 ? .orange : .green
    }

    private var memoryColor: Color {
        monitor.memoryUsagePercent > 80 ? .red : monitor.memoryUsagePercent > 50 ? .orange : .blue
    }

    private var diskColor: Color {
        monitor.diskUsagePercent > 80 ? .red : monitor.diskUsagePercent > 50 ? .orange : .purple
    }

    private var gpuUsageColor: Color {
        monitor.gpuUtilization > 90 ? .red : monitor.gpuUtilization > 65 ? .orange : .blue
    }

    private var batteryIcon: String {
        switch monitor.batteryLevel {
        case 0..<13: return "battery.0percent"
        case 13..<38: return "battery.25percent"
        case 38..<63: return "battery.50percent"
        case 63..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private var batteryTimeFormatted: String {
        let minutes = monitor.batteryTimeRemaining
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m remaining" }
        if h > 0 { return "\(h)h remaining" }
        return "\(m)m remaining"
    }

    private var batteryColor: Color {
        if monitor.batteryIsCharging { return .green }
        if monitor.batteryLevel < 20 { return .red }
        return .primary
    }
}
