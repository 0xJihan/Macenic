import Carbon.HIToolbox
import AppKit

private func hotKeyEventHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData, let event else { return OSStatus(eventNotHandledErr) }
    let service = Unmanaged<HotKeyService>.fromOpaque(userData).takeUnretainedValue()

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    if status == noErr {
        DispatchQueue.main.async {
            service.handleHotKey(id: hotKeyID.id)
        }
    }
    return noErr
}

enum HotKeyTarget: String, CaseIterable, Identifiable {
    case clipboard = "Clipboard HUD"
    case snapLeft = "Snap Left"
    case snapRight = "Snap Right"
    case maximize = "Maximize"
    case restore = "Restore"

    var id: String { rawValue }

    var hotKeyID: UInt32 {
        switch self {
        case .clipboard: return 1
        case .snapLeft: return 2
        case .snapRight: return 3
        case .maximize: return 4
        case .restore: return 5
        }
    }
}

struct KeyShortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let defaultClipboard = KeyShortcut(keyCode: 9, modifiers: 0x0300) // Cmd + Shift + V
    static let defaultSnapLeft = KeyShortcut(keyCode: 123, modifiers: UInt32(controlKey | optionKey)) // Ctrl + Opt + Left
    static let defaultSnapRight = KeyShortcut(keyCode: 124, modifiers: UInt32(controlKey | optionKey)) // Ctrl + Opt + Right
    static let defaultMaximize = KeyShortcut(keyCode: 126, modifiers: UInt32(controlKey | optionKey)) // Ctrl + Opt + Up
    static let defaultRestore = KeyShortcut(keyCode: 51, modifiers: UInt32(controlKey | optionKey)) // Ctrl + Opt + Delete

    private static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
        24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
        32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K",
        43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        49: "Space", 51: "⌫",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8",
        101: "F9", 103: "F11", 109: "F10", 111: "F12", 118: "F4",
        120: "F2", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑"
    ]

    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(Self.keyNames[keyCode] ?? "?")
        return parts.joined()
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        return carbon
    }
}

@Observable
final class HotKeyService {
    var onHotKey: (() -> Void)?
    var onSnapLeft: (() -> Void)?
    var onSnapRight: (() -> Void)?
    var onMaximize: (() -> Void)?
    var onRestore: (() -> Void)?

    var currentShortcut: KeyShortcut = .defaultClipboard
    var snapLeftShortcut: KeyShortcut = .defaultSnapLeft
    var snapRightShortcut: KeyShortcut = .defaultSnapRight
    var maximizeShortcut: KeyShortcut = .defaultMaximize
    var restoreShortcut: KeyShortcut = .defaultRestore

    var recordingTarget: HotKeyTarget?
    var isRecording: Bool { recordingTarget != nil }

    @ObservationIgnored private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    @ObservationIgnored private var handlerRef: EventHandlerRef?
    @ObservationIgnored private var recordMonitor: Any?

    private static let clipboardShortcutKey = "clipboardShortcut"
    private static let snapLeftShortcutKey = "snapLeftShortcut"
    private static let snapRightShortcutKey = "snapRightShortcut"
    private static let maximizeShortcutKey = "maximizeShortcut"
    private static let restoreShortcutKey = "restoreShortcut"

    init() {
        loadShortcuts()
    }

    func shortcut(for target: HotKeyTarget) -> KeyShortcut {
        switch target {
        case .clipboard: return currentShortcut
        case .snapLeft: return snapLeftShortcut
        case .snapRight: return snapRightShortcut
        case .maximize: return maximizeShortcut
        case .restore: return restoreShortcut
        }
    }

    func setShortcut(_ shortcut: KeyShortcut, for target: HotKeyTarget) {
        switch target {
        case .clipboard: currentShortcut = shortcut
        case .snapLeft: snapLeftShortcut = shortcut
        case .snapRight: snapRightShortcut = shortcut
        case .maximize: maximizeShortcut = shortcut
        case .restore: restoreShortcut = shortcut
        }
        saveShortcuts()
    }

    func handleHotKey(id: UInt32) {
        switch id {
        case 1: onHotKey?()
        case 2: onSnapLeft?()
        case 3: onSnapRight?()
        case 4: onMaximize?()
        case 5: onRestore?()
        default: break
        }
    }

    func register() {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            selfPtr,
            &handlerRef
        )

        let targets: [(HotKeyTarget, KeyShortcut)] = [
            (.clipboard, currentShortcut),
            (.snapLeft, snapLeftShortcut),
            (.snapRight, snapRightShortcut),
            (.maximize, maximizeShortcut),
            (.restore, restoreShortcut)
        ]

        for (target, shortcut) in targets {
            var hotKeyID = EventHotKeyID(signature: 0x4D434E43, id: target.hotKeyID)
            var hotKeyRef: EventHotKeyRef?

            let status = RegisterEventHotKey(
                shortcut.keyCode,
                shortcut.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            if status == noErr, let ref = hotKeyRef {
                hotKeyRefs[target.hotKeyID] = ref
            }
        }
    }

    func unregister() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()

        if let ref = handlerRef {
            RemoveEventHandler(ref)
            handlerRef = nil
        }
    }

    func startRecording(for target: HotKeyTarget = .clipboard) {
        unregister()
        recordingTarget = target
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let activeTarget = self.recordingTarget else { return event }
            let mods = KeyShortcut.carbonModifiers(from: event.modifierFlags)
            guard mods != 0 else { return nil }

            let newShortcut = KeyShortcut(keyCode: UInt32(event.keyCode), modifiers: mods)
            self.setShortcut(newShortcut, for: activeTarget)
            self.stopRecording()
            self.register()
            return nil
        }
    }

    func stopRecording() {
        recordingTarget = nil
        if let monitor = recordMonitor {
            NSEvent.removeMonitor(monitor)
            recordMonitor = nil
        }
    }

    func cancelRecording() {
        stopRecording()
        register()
    }

    private func saveShortcuts() {
        saveShortcut(currentShortcut, key: Self.clipboardShortcutKey)
        saveShortcut(snapLeftShortcut, key: Self.snapLeftShortcutKey)
        saveShortcut(snapRightShortcut, key: Self.snapRightShortcutKey)
        saveShortcut(maximizeShortcut, key: Self.maximizeShortcutKey)
        saveShortcut(restoreShortcut, key: Self.restoreShortcutKey)
    }

    private func saveShortcut(_ shortcut: KeyShortcut, key: String) {
        if let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadShortcuts() {
        if let loaded = loadShortcut(key: Self.clipboardShortcutKey) {
            currentShortcut = loaded
        }
        if let loaded = loadShortcut(key: Self.snapLeftShortcutKey) {
            snapLeftShortcut = loaded
        }
        if let loaded = loadShortcut(key: Self.snapRightShortcutKey) {
            snapRightShortcut = loaded
        }
        if let loaded = loadShortcut(key: Self.maximizeShortcutKey) {
            maximizeShortcut = loaded
        }
        if let loaded = loadShortcut(key: Self.restoreShortcutKey) {
            restoreShortcut = loaded
        }
    }

    private func loadShortcut(key: String) -> KeyShortcut? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let shortcut = try? JSONDecoder().decode(KeyShortcut.self, from: data)
        else { return nil }
        return shortcut
    }
}
