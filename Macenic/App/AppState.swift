import SwiftUI
import AppKit

private class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    var onDismiss: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            onDismiss?()
        } else {
            super.keyDown(with: event)
        }
    }
}

@Observable
final class AppState {
    let systemMonitor = SystemMonitorService()
    let networkMonitor = NetworkMonitorService()
    let batteryHealth = BatteryHealthService()
    let storageMonitor = StorageMonitorService()
    let processManager = ProcessManagerService()
    let windowManager = WindowManagerService()
    let devToolkit = DevToolkitService()
    let clipboard = ClipboardService()
    let audio = AudioService()
    let updates = AppUpdateService()
    let keepAwake = KeepAwakeService()
    let keyboardCleaner = KeyboardCleanerService()
    let hotKey = HotKeyService()
    let accessibility = AccessibilityService.shared
    let appearance = AppearanceService.shared

    @ObservationIgnored private var hudWindow: NSPanel?
    @ObservationIgnored private var escMonitor: Any?
    @ObservationIgnored private var outsideClickMonitor: Any?
    @ObservationIgnored private var appDeactivateObserver: Any?
    @ObservationIgnored private var previouslyActiveApp: NSRunningApplication?

    init() {
        systemMonitor.start()
        networkMonitor.start()
        batteryHealth.start()
        storageMonitor.start()
        clipboard.start()
        audio.refresh()

        hotKey.onHotKey = { [weak self] in
            self?.toggleClipboardHUD()
        }
        hotKey.onSnapLeft = { [weak self] in
            self?.windowManager.snap(.leftHalf)
        }
        hotKey.onSnapRight = { [weak self] in
            self?.windowManager.snap(.rightHalf)
        }
        hotKey.onMaximize = { [weak self] in
            self?.windowManager.snap(.maximize)
        }
        hotKey.onRestore = { [weak self] in
            self?.windowManager.snap(.restore)
        }
        hotKey.register()

        Task { [weak self] in
            await self?.updates.checkForUpdates()
        }
    }

    func toggleClipboardHUD() {
        if let window = hudWindow, window.isVisible {
            hideClipboardHUD()
        } else {
            showClipboardHUD()
        }
    }

    func showClipboardHUD() {
        // Capture the app that was frontmost before HUD opens
        previouslyActiveApp = NSWorkspace.shared.frontmostApplication

        // Reset search query so the HUD opens fresh
        clipboard.searchQuery = ""

        if hudWindow == nil {
            let hudView = ClipboardHUDView(
                service: clipboard,
                onPaste: { [weak self] item in
                    self?.handlePaste(item: item)
                },
                onDismiss: { [weak self] in
                    self?.hideClipboardHUD()
                }
            )

            let contentRect = NSRect(x: 0, y: 0, width: 340, height: 440)

            let panel = FloatingPanel(
                contentRect: contentRect,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )

            let clearView = hudView.background(.clear)
            let hostingView = NSHostingView(rootView: clearView)
            hostingView.frame = contentRect
            hostingView.wantsLayer = true
            hostingView.layer?.backgroundColor = .clear

            if #available(macOS 26.0, *) {
                let glassView = NSGlassEffectView()
                glassView.frame = contentRect
                glassView.cornerRadius = 16
                glassView.contentView = hostingView
                panel.contentView = glassView
            } else {
                hostingView.layer?.cornerRadius = 16
                hostingView.layer?.masksToBounds = true
                panel.contentView = hostingView
            }

            panel.isFloatingPanel = true
            panel.level = .floating
            panel.isMovableByWindowBackground = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = false
            panel.hasShadow = true
            panel.onDismiss = { [weak self] in
                self?.hideClipboardHUD()
            }

            hudWindow = panel
        }

        guard let panel = hudWindow, let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - panel.frame.width / 2
        let y = screenFrame.midY - panel.frame.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        startMonitors()
    }

    func hideClipboardHUD() {
        hudWindow?.orderOut(nil)
        stopMonitors()
        ClipboardPreviewController.shared.hideImmediately()
    }

    private func handlePaste(item: ClipboardItem) {
        clipboard.copyToClipboard(item)
        hideClipboardHUD()

        // If accessibility is enabled, simulate Cmd+V in the target app
        if accessibility.isTrusted,
           let app = previouslyActiveApp,
           app.bundleIdentifier != Bundle.main.bundleIdentifier {
            app.activate(options: .activateIgnoringOtherApps)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                self.simulatePasteKeystroke()
            }
        }
    }

    private func simulatePasteKeystroke() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 9 // ANSI 'v'
        guard let vDown = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: true),
              let vUp = CGEvent(keyboardEventSource: src, virtualKey: vKeyCode, keyDown: false) else { return }
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand
        vDown.post(tap: .cghidEventTap)
        vUp.post(tap: .cghidEventTap)
    }

    private func startMonitors() {
        if escMonitor == nil {
            escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 {
                    self?.hideClipboardHUD()
                    return nil
                }
                return event
            }
        }

        if outsideClickMonitor == nil {
            outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                guard let self, let panel = self.hudWindow, panel.isVisible else { return }
                let clickLocation = NSEvent.mouseLocation
                if panel.frame.contains(clickLocation) { return }
                if let previewFrame = ClipboardPreviewController.shared.panelFrame, previewFrame.contains(clickLocation) { return }
                self.hideClipboardHUD()
            }
        }

        if appDeactivateObserver == nil {
            appDeactivateObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.hideClipboardHUD()
            }
        }
    }

    private func stopMonitors() {
        if let monitor = escMonitor {
            NSEvent.removeMonitor(monitor)
            escMonitor = nil
        }
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
        if let observer = appDeactivateObserver {
            NotificationCenter.default.removeObserver(observer)
            appDeactivateObserver = nil
        }
    }
}
