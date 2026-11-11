import AppKit
import SwiftUI
import CoreGraphics

private var activeEventTap: CFMachPort?

private func keyboardCleanerCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        if let tap = activeEventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    default:
        return nil
    }
}

private class CleanerWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    var onClickAnywhere: (() -> Void)?

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .keyDown, .keyUp, .flagsChanged:
            return
        case .leftMouseDown, .rightMouseDown:
            onClickAnywhere?()
        default:
            super.sendEvent(event)
        }
    }
}

@Observable
final class KeyboardCleanerService {
    var isActive = false
    var permissionDenied = false

    @ObservationIgnored private var cleanerWindow: NSWindow?
    @ObservationIgnored private var exitTimer: Timer?
    @ObservationIgnored private var runLoopSource: CFRunLoopSource?
    @ObservationIgnored private var pendingDuration: Int = 30

    static var hasPermission: Bool {
        AccessibilityService.shared.isTrusted
    }

    func activate(duration: Int = 30) {
        guard !isActive else { return }

        if !AccessibilityService.shared.isTrusted {
            permissionDenied = true
            pendingDuration = duration
            openAccessibilitySettings()
            return
        }

        permissionDenied = false
        startCleaner(duration: duration)
    }

    func openAccessibilitySettings() {
        AccessibilityService.shared.openAccessibilitySettings()
        AccessibilityService.shared.checkAndPrompt { [weak self] in
            guard let self else { return }
            self.permissionDenied = false
            self.activate(duration: self.pendingDuration)
        }
    }

    private func startCleaner(duration: Int) {
        guard let screen = NSScreen.main else { return }

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: keyboardCleanerCallback,
            userInfo: nil
        ) else {
            permissionDenied = false
            openAccessibilitySettings()
            return
        }

        activeEventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        runLoopSource = source

        let endDate = Date().addingTimeInterval(TimeInterval(duration))

        let window = CleanerWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.onClickAnywhere = { [weak self] in
            DispatchQueue.main.async { self?.deactivate() }
        }

        let overlay = KeyboardCleanerOverlay(endDate: endDate)
        window.contentView = NSHostingView(rootView: overlay)

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(window.contentView)

        exitTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(duration),
            repeats: false
        ) { [weak self] _ in
            self?.deactivate()
        }

        cleanerWindow = window
        isActive = true
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false

        if let tap = activeEventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        activeEventTap = nil
        runLoopSource = nil

        exitTimer?.invalidate()
        exitTimer = nil
        cleanerWindow?.orderOut(nil)
        cleanerWindow = nil
    }
}
