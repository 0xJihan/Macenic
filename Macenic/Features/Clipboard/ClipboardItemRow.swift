import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    var index: Int? = nil
    var isSelected: Bool = false
    var isCopied: Bool = false
    let onTap: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            if let index, index < 9 {
                Text("\(index + 1)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 14)
            }

            contentPreview
                .frame(maxWidth: .infinity, alignment: .leading)

            if isCopied {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.green)
                    Text("Copied!")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: onPin) {
                    Image(systemName: item.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 10))
                        .foregroundStyle(item.isPinned ? .orange : .secondary)
                }
                .buttonStyle(.plain)
                .help(item.isPinned ? "Unpin item" : "Pin item to keep")

                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete item")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .help("Click to copy to clipboard")
        .onHover { isHovered = $0 }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(borderStroke, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.15), value: isCopied)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }

    private var backgroundFill: AnyShapeStyle {
        if isCopied {
            return AnyShapeStyle(Color.green.opacity(0.12))
        }
        if isSelected {
            return AnyShapeStyle(Color.accentColor.opacity(0.15))
        }
        if isHovered {
            return AnyShapeStyle(Color.primary.opacity(0.06))
        }
        return AnyShapeStyle(Color.primary.opacity(0.03))
    }

    private var borderStroke: Color {
        if isCopied {
            return Color.green.opacity(0.4)
        }
        if isSelected {
            return Color.accentColor.opacity(0.35)
        }
        if isHovered {
            return Color.primary.opacity(0.1)
        }
        return Color.clear
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch item.content {
        case .text(let string):
            Text(string.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.primary)
        case .image(let image):
            HStack(spacing: 6) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                if let dims = item.imageDimensions {
                    Text("\(Int(dims.width))×\(Int(dims.height))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
