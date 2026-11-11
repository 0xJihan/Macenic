import AppKit
import SwiftUI

final class DevToolkitWindowController {
    static let shared = DevToolkitWindowController()

    private var window: NSWindow?

    func show(service: DevToolkitService) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = DevToolkitView(service: service, isStandalone: true)
        let hosting = NSHostingView(rootView: contentView)
        let rect = NSRect(x: 0, y: 0, width: 500, height: 640)
        hosting.frame = rect

        let win = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Macenic Dev Toolkit"
        win.contentView = hosting
        win.minSize = NSSize(width: 400, height: 480)
        win.center()
        win.isReleasedWhenClosed = false

        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
