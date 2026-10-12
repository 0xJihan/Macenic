import SwiftUI
import AppKit

struct ClipboardHUDView: View {
    @Bindable var service: ClipboardService
    var onPaste: (ClipboardItem) -> Void
    var onDismiss: () -> Void
    private var appearance = AppearanceService.shared

    @State private var selectedIndex: Int = 0
    @State private var hoveredItemID: UUID?
    @FocusState private var isSearchFocused: Bool
    @State private var lastRowScreenRect: NSRect = .zero

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            Divider()
                .opacity(0.3)
            filterBar
            Divider()
                .opacity(0.3)

            if service.filteredItems.isEmpty {
                emptyState
            } else {
                itemsList
            }

            Divider()
                .opacity(0.3)
            hudFooter
        }
        .frame(width: 360, height: 460)
        .glassmorphic(opacity: appearance.glassOpacity, cornerRadius: 16)
        .onAppear {
            selectedIndex = 0
            isSearchFocused = true
            ClipboardPreviewController.shared.hideImmediately()
        }
        .onDisappear {
            ClipboardPreviewController.shared.hideImmediately()
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .onKeyPress(.return) {
            pasteSelected()
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveSelection(-1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(1)
            return .handled
        }
        .onKeyPress(characters: .decimalDigits) { press in
            guard let digit = Int(press.characters), digit >= 1, digit <= 9 else {
                return .ignored
            }
            let index = digit - 1
            guard index < service.filteredItems.count else { return .ignored }
            if press.modifiers.contains(.command) || press.modifiers.contains(.option) || service.searchQuery.isEmpty {
                onPaste(service.filteredItems[index])
                return .handled
            }
            return .ignored
        }
        .onChange(of: service.searchQuery) {
            selectedIndex = 0
            updatePreviewForSelected()
        }
        .onChange(of: service.selectedFilter) {
            selectedIndex = 0
            updatePreviewForSelected()
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tint)

            TextField("Type to search history...", text: $service.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isSearchFocused)

            if !service.searchQuery.isEmpty {
                Button {
                    service.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text("ESC")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
    }

    private var filterBar: some View {
        HStack {
            Picker("", selection: $service.selectedFilter) {
                ForEach(ClipboardFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 190)

            Spacer()

            Text("\(service.filteredItems.count) items")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var itemsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Color.clear
                    .frame(height: 0)
                    .id("CLIPBOARD_HUD_TOP")

                LazyVStack(spacing: 3) {
                    ForEach(Array(service.filteredItems.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemRow(
                            item: item,
                            index: index,
                            isSelected: index == selectedIndex,
                            onTap: {
                                selectedIndex = index
                                onPaste(item)
                            },
                            onPin: {
                                service.togglePin(item)
                            },
                            onDelete: {
                                service.delete(item)
                                ClipboardPreviewController.shared.hideImmediately()
                            },
                            onHover: { hovering, rect in
                                if hovering {
                                    hoveredItemID = item.id
                                    lastRowScreenRect = rect
                                    selectedIndex = index
                                    ClipboardPreviewController.shared.scheduleShow(for: item, adjacentTo: rect)
                                } else {
                                    if hoveredItemID == item.id {
                                        hoveredItemID = nil
                                        ClipboardPreviewController.shared.scheduleHide()
                                    }
                                }
                            }
                        )
                        .id(item.id)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .onAppear {
                proxy.scrollTo("CLIPBOARD_HUD_TOP", anchor: .top)
                updatePreviewForSelected()
            }
            .onChange(of: service.items.first?.id) { _, _ in
                selectedIndex = 0
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("CLIPBOARD_HUD_TOP", anchor: .top)
                }
            }
            .onChange(of: selectedIndex) { _, newIndex in
                guard newIndex < service.filteredItems.count else { return }
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(service.filteredItems[newIndex].id, anchor: .center)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "clipboard")
                .font(.system(size: 26))
                .foregroundStyle(.quaternary)
            Text(service.searchQuery.isEmpty ? "Clipboard history is empty" : "No matching items")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var hudFooter: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                Text("⏎")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 3.5)
                    .padding(.vertical, 1)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                Text("Paste")
                    .font(.system(size: 9.5))
            }

            HStack(spacing: 3) {
                Text("1-9")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 3.5)
                    .padding(.vertical, 1)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                Text("Quick Copy")
                    .font(.system(size: 9.5))
            }

            Spacer()

            HStack(spacing: 3) {
                Text("⌥P")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 3.5)
                    .padding(.vertical, 1)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                Text("Pin")
                    .font(.system(size: 9.5))
            }

            Button {
                service.clearUnpinned()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Clear unpinned items")
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.02))
    }

    private func moveSelection(_ delta: Int) {
        let count = service.filteredItems.count
        guard count > 0 else { return }
        selectedIndex = max(0, min(count - 1, selectedIndex + delta))
        updatePreviewForSelected()
    }

    private func pasteSelected() {
        guard selectedIndex < service.filteredItems.count else { return }
        onPaste(service.filteredItems[selectedIndex])
    }

    private func updatePreviewForSelected() {
        guard selectedIndex < service.filteredItems.count else {
            ClipboardPreviewController.shared.hideImmediately()
            return
        }
        let item = service.filteredItems[selectedIndex]
        let targetRect = lastRowScreenRect.isEmpty ? (NSApp.keyWindow?.frame ?? .zero) : lastRowScreenRect
        ClipboardPreviewController.shared.scheduleShow(for: item, adjacentTo: targetRect)
    }
}
