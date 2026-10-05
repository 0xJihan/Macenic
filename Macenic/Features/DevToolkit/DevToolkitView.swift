import SwiftUI

enum DevCategory: String, CaseIterable, Identifiable {
    case data = "Data"
    case generators = "Generators"
    case text = "Text"
    case hashes = "Hashes"

    var id: String { rawValue }
}

struct DevToolkitView: View {
    let service: DevToolkitService
    var isStandalone: Bool = false

    @State private var selectedCategory: DevCategory = .data

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()

            ScrollView {
                VStack(spacing: 12) {
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
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Picker("", selection: $selectedCategory) {
                ForEach(DevCategory.allCases) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
            .pickerStyle(.segmented)

            if !isStandalone {
                Button {
                    DevToolkitWindowController.shared.show(service: service)
                } label: {
                    Image(systemName: "arrow.up.backward.and.arrow.down.forward.rectangle")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Open in standalone window")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
