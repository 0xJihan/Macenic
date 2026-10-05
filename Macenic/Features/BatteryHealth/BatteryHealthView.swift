import SwiftUI

struct BatteryHealthView: View {
    let service: BatteryHealthService

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if !service.info.hasBattery {
                    desktopMacCard
                } else {
                    mainBatteryCard
                    healthMetricsCard
                    cycleCountCard
                    powerDetailsGrid
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private var desktopMacCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 32))
                .foregroundStyle(.tint)
            Text("Desktop Mac")
                .font(.system(size: 13, weight: .semibold))
            Text("Connected directly to AC Power. No internal battery present.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var mainBatteryCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(batteryColor.opacity(0.2), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, service.info.level)) / 100.0)
                    .stroke(batteryColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(service.info.level)%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(service.info.isCharging ? "Charging" : (service.info.isPluggedIn ? "Fully Charged / On AC" : "On Battery"))
                        .font(.system(size: 13, weight: .semibold))
                    if service.info.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                    }
                }

                if service.info.timeRemainingMinutes >= 0 {
                    Text(timeRemainingFormatted)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text(service.info.powerSource)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let wattage = service.info.wattage {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.1f W", wattage))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    Text(service.info.isCharging ? "Input Power" : "Discharging")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var healthMetricsCard: some View {
        HStack(spacing: 8) {
            metricBox(
                title: "Maximum Capacity",
                value: service.info.maxCapacityPercent.map { "\($0)%" } ?? "Unavailable",
                color: (service.info.maxCapacityPercent ?? 100) >= 80 ? .green : .orange
            )
            metricBox(
                title: "Condition",
                value: service.info.condition,
                color: service.info.condition == "Normal" ? .green : .orange
            )
        }
    }

    private func metricBox(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var cycleCountCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Cycle Count")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                if let designCycles = service.info.designCycleCount, designCycles > 0 {
                    Text("\(service.info.cycleCount) / \(designCycles) cycles")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                } else {
                    Text("\(service.info.cycleCount) cycles")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }

            if let designCycles = service.info.designCycleCount, designCycles > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 5)
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(
                                width: min(CGFloat(service.info.cycleCount) / CGFloat(designCycles) * geo.size.width, geo.size.width),
                                height: 5
                            )
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var powerDetailsGrid: some View {
        VStack(spacing: 5) {
            if let full = service.info.fullChargeCapacityMah,
               let design = service.info.designCapacityMah {
                detailRow(label: "Full Charge vs Design", value: "\(full) / \(design) mAh")
            }
            if let current = service.info.currentCapacityMah {
                detailRow(label: "Remaining Capacity", value: "\(current) mAh")
            }
            if let lastCharged = service.info.lastChargingTime {
                HStack {
                    Text("Last Charged")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(lastCharged, style: .relative)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary) + Text(" ago").font(.system(size: 11))
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.15))
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

    private var timeRemainingFormatted: String {
        let mins = service.info.timeRemainingMinutes
        let h = mins / 60
        let m = mins % 60
        let prefix = service.info.isCharging ? "Until full: " : "Remaining: "
        if h > 0 { return "\(prefix)\(h)h \(m)m" }
        return "\(prefix)\(m)m"
    }

    private var batteryColor: Color {
        if service.info.isCharging { return .green }
        if service.info.level < 20 { return .red }
        if service.info.level < 40 { return .orange }
        return .accentColor
    }
}
