import SwiftUI
import AppKit

final class ClipboardPreviewController {
    static let shared = ClipboardPreviewController()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?
    private var currentItemID: UUID?
    private var showTimer: Timer?
    private var hideTimer: Timer?

    private(set) var isMouseInsidePreview: Bool = false

    var panelFrame: NSRect? {
        panel?.isVisible == true ? panel?.frame : nil
    }

    private init() {}

    func scheduleShow(for item: ClipboardItem, adjacentTo sourceRect: NSRect) {
        hideTimer?.invalidate()
        hideTimer = nil

        if panel?.isVisible == true {
            show(for: item, adjacentTo: sourceRect)
        } else {
            showTimer?.invalidate()
            showTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: false) { [weak self] _ in
                self?.show(for: item, adjacentTo: sourceRect)
            }
        }
    }

    func show(for item: ClipboardItem, adjacentTo sourceRect: NSRect) {
        hideTimer?.invalidate()
        hideTimer = nil
        showTimer?.invalidate()
        showTimer = nil

        let previewPanel = getOrCreatePanel()
        currentItemID = item.id

        let previewView = ClipboardPreviewView(item: item)
        if let hosting = hostingView {
            hosting.rootView = AnyView(previewView)
        } else {
            let hosting = NSHostingView(rootView: AnyView(previewView))
            hosting.wantsLayer = true
            hosting.layer?.backgroundColor = .clear
            previewPanel.contentView = hosting
            hostingView = hosting
        }

        // Determine screen and compute larger, spacious preview size
        let screen = NSScreen.screens.first { $0.frame.intersects(sourceRect) } ?? NSScreen.main ?? NSScreen.screens.first!
        let visibleFrame = screen.visibleFrame

        let previewWidth: CGFloat = min(500, max(460, visibleFrame.width * 0.32))
        let previewHeight: CGFloat = min(540, max(480, visibleFrame.height * 0.65))

        var originX: CGFloat = 0
        // Prefer placing on the right if there is room; otherwise place on the left
        if sourceRect.maxX + previewWidth + 10 <= visibleFrame.maxX {
            originX = sourceRect.maxX + 6
        } else {
            originX = sourceRect.minX - previewWidth - 6
        }
        originX = max(visibleFrame.minX + 8, min(visibleFrame.maxX - previewWidth - 8, originX))

        // Center vertically with sourceRect, clamped to visible screen area
        var originY = sourceRect.midY - previewHeight / 2
        originY = max(visibleFrame.minY + 8, min(visibleFrame.maxY - previewHeight - 8, originY))

        let targetFrame = NSRect(x: originX, y: originY, width: previewWidth, height: previewHeight)
        previewPanel.setFrame(targetFrame, display: true)

        if !previewPanel.isVisible {
            previewPanel.alphaValue = 0
            previewPanel.orderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                previewPanel.animator().alphaValue = 1.0
            }
        }
    }

    func setPreviewHovered(_ isHovered: Bool) {
        isMouseInsidePreview = isHovered
        if isHovered {
            hideTimer?.invalidate()
            hideTimer = nil
        } else {
            scheduleHide()
        }
    }

    func scheduleHide() {
        showTimer?.invalidate()
        showTimer = nil

        hideTimer?.invalidate()
        // Generous 350ms delay allowing user to move cursor smoothly into preview window
        hideTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if !self.isMouseInsidePreview {
                self.hideImmediately()
            }
        }
    }

    func hideImmediately() {
        showTimer?.invalidate()
        showTimer = nil
        hideTimer?.invalidate()
        hideTimer = nil
        isMouseInsidePreview = false

        if let panel = panel, panel.isVisible {
            panel.orderOut(nil)
        }
        currentItemID = nil
    }

    private func getOrCreatePanel() -> NSPanel {
        if let existing = panel {
            return existing
        }

        let newPanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = .popUpMenu
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.hidesOnDeactivate = false
        newPanel.ignoresMouseEvents = false
        newPanel.animationBehavior = .utilityWindow

        self.panel = newPanel
        return newPanel
    }
}

struct ClipboardPreviewView: View {
    let item: ClipboardItem
    private let appearance = AppearanceService.shared

    @State private var isCopiedFeedback: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .opacity(0.3)
            content
            Divider()
                .opacity(0.3)
            footer
        }
        .frame(minWidth: 460, maxWidth: 500, minHeight: 480, maxHeight: 540)
        .glassmorphic(opacity: appearance.glassOpacity, cornerRadius: 16)
        .onHover { isHovered in
            ClipboardPreviewController.shared.setPreviewHovered(isHovered)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(item.isImage ? Color.purple.opacity(0.2) : Color.blue.opacity(0.2))
                    .frame(width: 28, height: 28)
                Image(systemName: item.isImage ? "photo.fill" : "doc.text.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(item.isImage ? .purple : .blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(metaTitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)

                Text(metaSubtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if item.isPinned {
                HStack(spacing: 3) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                    Text("Pinned")
                        .font(.system(size: 9.5, weight: .semibold))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
            }

            Text(item.timestamp.formatted(.relative(presentation: .named)))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
    }

    private var metaTitle: String {
        switch item.content {
        case .text:
            return "Text Content"
        case .image:
            return "Image Content"
        }
    }

    private var metaSubtitle: String {
        switch item.content {
        case .text(let text):
            let charCount = text.count
            let wordCount = text.split { $0.isWhitespace || $0.isNewline }.count
            let lineCount = text.split(separator: "\n", omittingEmptySubsequences: false).count
            return "\(charCount) characters • \(wordCount) words • \(lineCount) lines"
        case .image:
            if let dims = item.imageDimensions {
                return "\(Int(dims.width)) × \(Int(dims.height)) px"
            }
            return "High resolution image"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.content {
        case .text(let string):
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    Text(string)
                        .font(.system(size: 13.5, weight: .regular))
                        .textSelection(.enabled)
                        .lineSpacing(4.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Quick copy button in preview
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(string, forType: .string)
                    withAnimation(.spring(response: 0.2)) {
                        isCopiedFeedback = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation { isCopiedFeedback = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isCopiedFeedback ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9))
                        Text(isCopiedFeedback ? "Copied" : "Copy")
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .padding(10)
            }
        case .image(let image):
            VStack {
                Spacer()
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 440, maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 5)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(14)
            .background(Color.black.opacity(0.08))
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("⏎")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3.5))
                Text("Copy & Paste")
                    .font(.system(size: 10.5))
            }
            .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Text("⌥P")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3.5))
                Text("Pin")
                    .font(.system(size: 10.5))
            }
            .foregroundStyle(.secondary)

            Spacer()

            Text("Scrollable • Selectable")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.02))
    }
}
