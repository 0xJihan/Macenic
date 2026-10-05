import AppKit
import ApplicationServices

@Observable
final class AccessibilityService {
    static let shared = AccessibilityService()

    var isTrusted: Bool = AXIsProcessTrusted()

    @ObservationIgnored private var pollTimer: Timer?
    @ObservationIgnored private var onGrantedCallbacks: [() -> Void] = []

    init() {
        refreshStatus()
    }

    func refreshStatus() {
        isTrusted = AXIsProcessTrusted()
    }

    @discardableResult
    func checkAndPrompt(onGranted: (() -> Void)? = nil) -> Bool {
        refreshStatus()
        if isTrusted {
            onGranted?()
            return true
        }

        if let onGranted {
            onGrantedCallbacks.append(onGranted)
        }

        promptForPermission()
        startPolling()
        return false
    }

    func promptForPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        promptForPermission()

        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ]

        var opened = false
        for string in urls {
            if let url = URL(string: string), NSWorkspace.shared.open(url) {
                opened = true
                break
            }
        }

        if !opened {
            NSWorkspace.shared.open(
                URL(fileURLWithPath: "/System/Applications/System Settings.app")
            )
        }

        startPolling()
    }

    func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.refreshStatus()
            if self.isTrusted {
                self.stopPolling()
                let callbacks = self.onGrantedCallbacks
                self.onGrantedCallbacks.removeAll()
                for callback in callbacks {
                    callback()
                }
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
