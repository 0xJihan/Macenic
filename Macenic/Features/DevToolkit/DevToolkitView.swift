import SwiftUI

enum DevCategory: String, CaseIterable, Identifiable {
    case data = "Data"
    case generators = "Generators"
    case text = "Text"
    case hashes = "Hashes"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .data: return "curlybraces"
        case .generators: return "wand.and.stars"
        case .text: return "textformat"
        case .hashes: return "number"
        }
    }

    var subtitle: String {
        switch self {
        case .data: return "JSON, Base64, URLs and JWT payloads"
        case .generators: return "UUIDs, ULIDs, tokens and timestamps"
        case .text: return "Regex, case conversion and text cleanup"
        case .hashes: return "SHA, MD5 and HMAC digests"
        }
    }
}

struct DevToolkitView: View {
    let service: DevToolkitService
    var isStandalone: Bool = false

    @State private var selectedCategory: DevCategory = .data

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
                .opacity(0.3)

            ScrollView {
                VStack(spacing: 12) {
                    header

                    switch selectedCategory {
                    case .data:
                        DataToolsView(service: service)
                    case .generators:
                        GeneratorsView(service: service)
                    case .text:
                        TextToolsView(service: service)
                    case .hashes:
                        HashToolsView(service: service)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .background(Color.clear)
    }

    private var topBar: some View {
        HStack(spacing: 3) {
            ForEach(DevCategory.allCases) { category in
                Button {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        selectedCategory = category
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: category.icon)
                            .font(.system(size: 10, weight: selectedCategory == category ? .semibold : .regular))
                        Text(category.rawValue)
                            .font(.system(size: 10, weight: selectedCategory == category ? .semibold : .medium))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedCategory == category ? AnyShapeStyle(Color.accentColor.opacity(0.16)) : AnyShapeStyle(Color.clear))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(selectedCategory == category ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 0.5)
                    )
                    .foregroundStyle(selectedCategory == category ? Color.accentColor : Color.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if !isStandalone {
                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 2)

                Button {
                    DevToolkitWindowController.shared.show(service: service)
                } label: {
                    Image(systemName: "arrow.up.backward.and.arrow.down.forward.rectangle")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .help("Open in standalone window")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.03))
    }

    private var header: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: 28, height: 28)
                Image(systemName: selectedCategory.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tint)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(selectedCategory.rawValue)
                    .font(.system(size: 12, weight: .bold))
                Text(selectedCategory.subtitle)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text("DEV TOOLS")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.05))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 2)
    }
}
