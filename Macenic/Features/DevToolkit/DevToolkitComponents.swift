import SwiftUI
import AppKit

struct DevCard<Content: View>: View {
    let title: String?
    let icon: String?
    let content: Content

    init(title: String? = nil, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                HStack(spacing: 5) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tint)
                    }
                    Text(title.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
            content
        }
        .padding(10)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
        )
    }
}

struct DevCopyButton: View {
    let text: String
    var compact: Bool = false

    @State private var copied = false

    var body: some View {
        Button {
            guard !text.isEmpty else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            withAnimation(.easeOut(duration: 0.12)) {
                copied = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.15)) {
                    copied = false
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 8.5, weight: .semibold))
                if !compact {
                    Text(copied ? "Copied" : "Copy")
                        .font(.system(size: 9, weight: .medium))
                }
            }
            .foregroundStyle(copied ? Color.green : Color.secondary)
            .padding(.horizontal, compact ? 4 : 6)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(text.isEmpty)
        .help("Copy to clipboard")
    }
}

struct DevOutputField: View {
    let text: String
    var lineLimit: Int = 1
    var truncationMode: Text.TruncationMode = .middle
    var showsCopyButton: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            Text(text.isEmpty ? "—" : text)
                .font(.system(size: 10.5, design: .monospaced))
                .lineLimit(lineLimit)
                .truncationMode(truncationMode)
                .textSelection(.enabled)
                .foregroundStyle(text.isEmpty ? Color.secondary : Color.primary)

            Spacer(minLength: 4)

            if showsCopyButton {
                DevCopyButton(text: text, compact: true)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct DevMonoEditor: View {
    var title: String? = nil
    @Binding var text: String
    var isReadOnly: Bool = false
    var minHeight: CGFloat = 72
    var maxHeight: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                HStack(spacing: 5) {
                    Text(title.uppercased())
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    if isReadOnly {
                        DevCopyButton(text: text, compact: true)
                    }
                }
            }

            TextEditor(text: isReadOnly ? Binding.constant(text) : $text)
                .scrollContentBackground(.hidden)
                .font(.system(size: 10.5, design: .monospaced))
                .frame(minHeight: minHeight, maxHeight: maxHeight)
                .padding(5)
                .background(Color.primary.opacity(0.055))
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 0.5)
                )
                .disabled(isReadOnly)
        }
    }
}

struct DevStatusBanner: View {
    let message: String
    var isError: Bool = false
    var isSuccess: Bool = false

    private var color: Color {
        if isError { return .orange }
        if isSuccess { return .green }
        return .secondary
    }

    private var icon: String {
        if isError { return "exclamationmark.triangle.fill" }
        if isSuccess { return "checkmark.circle.fill" }
        return "info.circle.fill"
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)
            Text(message)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(color)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

struct DevSmallButton: View {
    let title: String
    var icon: String? = nil
    var prominent: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 9, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 9.5, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(prominent ? AnyShapeStyle(Color.accentColor.opacity(0.16)) : AnyShapeStyle(Color.primary.opacity(0.06)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(prominent ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .foregroundStyle(prominent ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}
