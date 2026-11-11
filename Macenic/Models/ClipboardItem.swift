import AppKit

struct ClipboardItem: Identifiable {
    let id: UUID
    let content: Content
    let timestamp: Date
    var isPinned: Bool

    enum Content {
        case text(String)
        case image(NSImage)
    }

    var isImage: Bool {
        if case .image = content { return true }
        return false
    }

    var imageDimensions: NSSize? {
        guard case .image(let img) = content else { return nil }
        guard let rep = img.representations.first else { return img.size }
        return NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    }

    var textPreview: String {
        switch content {
        case .text(let string): return string
        case .image:
            if let dims = imageDimensions {
                return "Image \(Int(dims.width))×\(Int(dims.height))"
            }
            return "Image"
        }
    }
}

enum ClipboardFilter: String, CaseIterable {
    case all = "All"
    case text = "Text"
    case images = "Images"
}
