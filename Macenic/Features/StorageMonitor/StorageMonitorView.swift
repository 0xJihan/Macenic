import SwiftUI

struct StorageMonitorView: View {
    @Bindable var service: StorageMonitorService

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                overviewCard
                categoriesSection
                settingsButton
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .onAppear { service.calculateCategoriesIfNeeded() }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tint)
                    Text("Macintosh HD")
                        .font(.system(size: 13, weight: .semibold))
                }

                Spacer()

                Text("\(Int(service.info.usagePercent))% Used")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(service.info.usagePercent > 85 ? .red : service.info.usagePercent > 70 ? .orange : .secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 8)
                    Capsule()
                        .fill(barGradient)
                        .frame(
                            width: min(CGFloat(service.info.usagePercent) / 100.0 * geo.size.width, geo.size.width),
                            height: 8
                        )
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(ByteFormatter.format(service.info.usedBytes)) used")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(ByteFormatter.format(service.info.freeBytes)) available of \(ByteFormatter.format(service.info.totalBytes))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if service.info.purgeableBytes > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                    Text("\(ByteFormatter.format(service.info.purgeableBytes)) purgeable space")
                        .font(.system(size: 9))
                    Spacer()
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Category Breakdown")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    service.refreshCategories()
                } label: {
                    HStack(spacing: 3) {
                        if service.info.isCalculatingCategories {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 8))
                        }
                        Text("Refresh")
                            .font(.system(size: 9))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .disabled(service.info.isCalculatingCategories)
            }

            VStack(spacing: 4) {
                ForEach(service.info.categories) { cat in
                    categoryRow(cat)
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func categoryRow(_ category: StorageCategory) -> some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.system(size: 11))
                .foregroundStyle(.tint)
                .frame(width: 16)

            Text(category.name)
                .font(.system(size: 11))
                .foregroundStyle(.primary)

            Spacer()

            Text(ByteFormatter.format(category.bytes))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var settingsButton: some View {
        Button {
            service.openStorageSettings()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "gear")
                    .font(.system(size: 10))
                Text("Manage in macOS Storage Settings")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.quaternary.opacity(0.25))
            .foregroundStyle(.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var barGradient: LinearGradient {
        let percent = service.info.usagePercent
        let color: Color = percent > 85 ? .red : percent > 70 ? .orange : .accentColor
        return LinearGradient(
            colors: [color.opacity(0.8), color],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
