import AppKit

private struct StoredItem: Codable {
    let id: UUID
    let text: String?
    let imageData: Data?
    let timestamp: Date
    let isPinned: Bool
}

@Observable
final class ClipboardService {
    var items: [ClipboardItem] = []
    var searchQuery: String = ""
    var selectedFilter: ClipboardFilter = .all

    var filteredItems: [ClipboardItem] {
        var result = items
        switch selectedFilter {
        case .all: break
        case .text: result = result.filter { !$0.isImage }
        case .images: result = result.filter { $0.isImage }
        }
        if !searchQuery.isEmpty {
            result = result.filter {
                $0.textPreview.localizedCaseInsensitiveContains(searchQuery)
            }
        }
        return result
    }

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastChangeCount: Int = 0
    @ObservationIgnored private let maxItems = 50

    func start() {
        loadFromDisk()
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkPasteboard()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch item.content {
        case .text(let string):
            pasteboard.setString(string, forType: .string)
        case .image(let image):
            if let tiffData = image.tiffRepresentation {
                pasteboard.setData(tiffData, forType: .tiff)
                if let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    pasteboard.setData(pngData, forType: .png)
                }
            }
        }
        lastChangeCount = pasteboard.changeCount
    }

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        saveToDisk()
    }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        saveToDisk()
    }

    func clearUnpinned() {
        items.removeAll { !$0.isPinned }
        saveToDisk()
    }

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            if case .text(let last) = items.first?.content, last == string { return }
            let item = ClipboardItem(
                id: UUID(),
                content: .text(string),
                timestamp: Date(),
                isPinned: false
            )
            items.insert(item, at: 0)
            trimItems()
            saveToDisk()
        } else if let image = captureImage(from: pasteboard) {
            let item = ClipboardItem(
                id: UUID(),
                content: .image(image),
                timestamp: Date(),
                isPinned: false
            )
            items.insert(item, at: 0)
            trimItems()
            saveToDisk()
        }
    }

    private func captureImage(from pasteboard: NSPasteboard) -> NSImage? {
        let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]
        for type in imageTypes {
            if let data = pasteboard.data(forType: type), let image = NSImage(data: data) {
                return image
            }
        }
        if let image = NSImage(pasteboard: pasteboard), image.isValid {
            return image
        }
        return nil
    }

    private func trimItems() {
        let unpinned = items.filter { !$0.isPinned }
        guard unpinned.count > maxItems else { return }
        let excess = Set(unpinned.suffix(unpinned.count - maxItems).map(\.id))
        items.removeAll { excess.contains($0.id) }
    }

    private var storageURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Macenic", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("clipboard.json")
    }

    private func saveToDisk() {
        let stored = items.map { item -> StoredItem in
            switch item.content {
            case .text(let string):
                return StoredItem(id: item.id, text: string, imageData: nil, timestamp: item.timestamp, isPinned: item.isPinned)
            case .image(let image):
                let data = image.tiffRepresentation.flatMap {
                    NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:])
                }
                return StoredItem(id: item.id, text: nil, imageData: data, timestamp: item.timestamp, isPinned: item.isPinned)
            }
        }
        if let data = try? JSONEncoder().encode(stored) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }

    private func loadFromDisk() {
        guard let data = try? Data(contentsOf: storageURL),
              let stored = try? JSONDecoder().decode([StoredItem].self, from: data) else { return }
        items = stored.compactMap { item in
            if let text = item.text {
                return ClipboardItem(id: item.id, content: .text(text), timestamp: item.timestamp, isPinned: item.isPinned)
            } else if let imageData = item.imageData, let image = NSImage(data: imageData) {
                return ClipboardItem(id: item.id, content: .image(image), timestamp: item.timestamp, isPinned: item.isPinned)
            }
            return nil
        }
    }
}
