import AppKit
import ApplicationServices

enum WindowSnapAction: String, CaseIterable {
    case leftHalf = "Left Half"
    case rightHalf = "Right Half"
    case topHalf = "Top Half"
    case maximize = "Maximize"
    case restore = "Restore"
}

@Observable
final class WindowManagerService {
    var lastActionMessage: String?
    var hasAccessibilityPermission: Bool {
        AccessibilityService.shared.isTrusted
    }

    @ObservationIgnored private var previousFrames: [String: CGRect] = [:]

    func snap(_ action: WindowSnapAction) {
        guard AccessibilityService.shared.isTrusted else {
            AccessibilityService.shared.openAccessibilitySettings()
            lastActionMessage = "Accessibility permission required"
            return
        }

        guard let (windowElement, appName, windowKey) = getTargetWindow() else {
            lastActionMessage = "No controllable window found"
            return
        }

        guard let currentFrame = getWindowFrame(windowElement) else {
            lastActionMessage = "Could not read window frame"
            return
        }

        let targetScreen = screen(for: currentFrame)
        let usableRect = visibleAxRect(for: targetScreen)

        if action == .restore {
            if let saved = previousFrames[windowKey] {
                applyFrame(saved, to: windowElement)
                previousFrames.removeValue(forKey: windowKey)
                lastActionMessage = "Restored \(appName) window"
            } else {
                lastActionMessage = "No previous position for \(appName)"
            }
            return
        }

        if previousFrames[windowKey] == nil {
            previousFrames[windowKey] = currentFrame
        }

        let targetFrame: CGRect
        switch action {
        case .leftHalf:
            targetFrame = CGRect(
                x: usableRect.origin.x,
                y: usableRect.origin.y,
                width: usableRect.width / 2,
                height: usableRect.height
            )
        case .rightHalf:
            targetFrame = CGRect(
                x: usableRect.origin.x + usableRect.width / 2,
                y: usableRect.origin.y,
                width: usableRect.width / 2,
                height: usableRect.height
            )
        case .topHalf:
            targetFrame = CGRect(
                x: usableRect.origin.x,
                y: usableRect.origin.y,
                width: usableRect.width,
                height: usableRect.height / 2
            )
        case .maximize:
            targetFrame = usableRect
        case .restore:
            return
        }

        applyFrame(targetFrame, to: windowElement)
        lastActionMessage = "\(action.rawValue) applied to \(appName)"
    }

    private func getTargetWindow() -> (AXUIElement, String, String)? {
        let runningApps = NSWorkspace.shared.runningApplications
        let currentBundleID = Bundle.main.bundleIdentifier

        // Prefer the active regular application other than Macenic itself
        var candidateApp: NSRunningApplication?
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != currentBundleID {
            candidateApp = front
        } else {
            candidateApp = runningApps.first {
                $0.activationPolicy == .regular &&
                $0.bundleIdentifier != currentBundleID &&
                $0.isActive
            } ?? runningApps.first {
                $0.activationPolicy == .regular &&
                $0.bundleIdentifier != currentBundleID &&
                !$0.isTerminated
            }
        }

        guard let app = candidateApp else { return nil }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )

        if result != .success || focusedWindow == nil {
            _ = AXUIElementCopyAttributeValue(
                appElement,
                kAXMainWindowAttribute as CFString,
                &focusedWindow
            )
        }

        guard let windowRef = focusedWindow,
              CFGetTypeID(windowRef) == AXUIElementGetTypeID() else {
            return nil
        }

        let element = unsafeBitCast(windowRef, to: AXUIElement.self)
        let appName = app.localizedName ?? "App"
        let key = "\(app.processIdentifier)_\(appName)"
        return (element, appName, key)
    }

    private func getWindowFrame(_ window: AXUIElement) -> CGRect? {
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue)
        AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)

        guard let posAX = posValue, let sizeAX = sizeValue,
              CFGetTypeID(posAX) == AXValueGetTypeID(),
              CFGetTypeID(sizeAX) == AXValueGetTypeID() else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        let posVal = unsafeBitCast(posAX, to: AXValue.self)
        let sizeVal = unsafeBitCast(sizeAX, to: AXValue.self)

        guard AXValueGetValue(posVal, .cgPoint, &point),
              AXValueGetValue(sizeVal, .cgSize, &size) else {
            return nil
        }

        return CGRect(origin: point, size: size)
    }

    private func applyFrame(_ frame: CGRect, to window: AXUIElement) {
        var origin = frame.origin
        var size = frame.size

        guard let posAX = AXValueCreate(.cgPoint, &origin),
              let sizeAX = AXValueCreate(.cgSize, &size) else {
            return
        }

        // Set position, then size, then position again (to handle window constraints)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posAX)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeAX)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posAX)
    }

    private func screen(for axRect: CGRect) -> NSScreen {
        guard let primary = NSScreen.screens.first else {
            return NSScreen.main ?? NSScreen()
        }

        let H = primary.frame.height
        let center = CGPoint(x: axRect.midX, y: axRect.midY)

        for screen in NSScreen.screens {
            let screenAxY = H - (screen.frame.origin.y + screen.frame.height)
            let screenAxRect = CGRect(
                x: screen.frame.origin.x,
                y: screenAxY,
                width: screen.frame.width,
                height: screen.frame.height
            )
            if screenAxRect.contains(center) {
                return screen
            }
        }

        return NSScreen.main ?? primary
    }

    private func visibleAxRect(for screen: NSScreen) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let axX = screen.visibleFrame.origin.x
        let axY = primaryHeight - (screen.visibleFrame.origin.y + screen.visibleFrame.height)
        let axWidth = screen.visibleFrame.width
        let axHeight = screen.visibleFrame.height
        return CGRect(x: axX, y: axY, width: axWidth, height: axHeight)
    }
}
