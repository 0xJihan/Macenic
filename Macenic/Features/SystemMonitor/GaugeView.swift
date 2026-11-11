import SwiftUI

struct GaugeView: View {
    let title: String
    let value: Double
    let detail: String
    let color: Color
    var centerText: String?
    var showsRing: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if showsRing {
                    Circle()
                        .stroke(color.opacity(0.15), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: min(value / 100, 1.0))
                        .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: value)
                }
                Text(centerText ?? "\(Int(value))%")
                    .font(.system(size: showsRing ? 11 : 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
