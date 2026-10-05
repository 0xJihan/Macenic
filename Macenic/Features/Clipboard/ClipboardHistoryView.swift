import SwiftUI
import AppKit

struct ClipboardHistoryView: View {
    @Bindable var service: ClipboardService
    var hotKey: HotKeyService?

    @State private var copiedItemID: UUID?
    @State private var copiedFeedbackText: String?

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            filterBar

            if service.filteredItems.isEmpty {
                emptyState
            } else {
                itemsList
            }

            Divider()
            bottomBar
        }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("Search clipboard...", text: $service.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 11))

            if !service.searchQuery.isEmpty {
                Button {
                    service.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            Picker("", selection: $service.selectedFilter) {
                ForEach(ClipboardFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            if let hotKey {
                Spacer()
                shortcutBadge(hotKey: hotKey)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private func shortcutBadge(hotKey: HotKeyService) -> some View {
        Button(action: {
            if hotKey.isRecording {
                hotKey.cancelRecording()
            } else {
                hotKey.startRecording(for: .clipboard)
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: "keyboard")
                    .font(.system(size: 9))
                Text(hotKey.isRecording ? "Press keys..." : hotKey.currentShortcut.displayString)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(hotKey.isRecording ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(hotKey.isRecording ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(.quaternary.opacity(0.4)))
            )
        }
        .buttonStyle(.plain)
        .help("Click to change shortcut")
    }

    private var itemsList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(service.filteredItems) { item in
                    ClipboardItemRow(
                        item: item,
                        isCopied: copiedItemID == item.id,
                        onTap: {
                            service.copyToClipboard(item)
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                copiedItemID = item.id
                                copiedFeedbackText = "Copied to clipboard"
                            }
                            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)

                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    if copiedItemID == item.id {
                                        copiedItemID = nil
                                        copiedFeedbackText = nil
                                    }
                                }
                            }
                        },
                        onPin: { service.togglePin(item) },
                        onDelete: { service.delete(item) }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "clipboard")
                .font(.system(size: 24))
                .foregroundStyle(.quaternary)
            Text(service.searchQuery.isEmpty ? "Clipboard history is empty" : "No matches found")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var bottomBar: some View {
        HStack {
            if let feedback = copiedFeedbackText {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text(feedback)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.green)
                }
                .transition(.opacity)
            } else {
                Button(action: { service.clearUnpinned() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                        Text("Clear Unpinned")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if let hotKey {
                Text(hotKey.currentShortcut.displayString)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.15))
    }
}
