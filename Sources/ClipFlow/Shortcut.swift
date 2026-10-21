import AppKit
import Carbon
import Combine

struct Shortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String

    static let defaultShortcut = Shortcut(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey), keyLabel: "V")
    static let allowedModifiers = UInt32(cmdKey | controlKey | optionKey | shiftKey)

    var display: String {
        [(UInt32(controlKey), "⌃"), (UInt32(optionKey), "⌥"), (UInt32(shiftKey), "⇧"), (UInt32(cmdKey), "⌘")]
            .filter { modifiers & $0.0 != 0 }.map(\.1).joined() + keyLabel
    }

    var validationMessage: String? {
        guard keyCode < 128, ![54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 53].contains(keyCode),
              !keyLabel.isEmpty, keyLabel.count <= 24, modifiers & ~Self.allowedModifiers == 0 else {
            return "请选择一个普通按键；Esc 用于取消录入。"
        }
        guard modifiers & UInt32(cmdKey | controlKey | optionKey) != 0 else {
            return "请至少包含 ⌘ Command、⌃ Control 或 ⌥ Option 中的一个，避免影响日常输入。"
        }
        let protectedKeys = [kVK_ANSI_V, kVK_ANSI_C, kVK_ANSI_X, kVK_ANSI_Z, kVK_ANSI_A,
                             kVK_ANSI_Q, kVK_ANSI_W, kVK_ANSI_H, kVK_ANSI_M, kVK_ANSI_S,
                             kVK_ANSI_P, kVK_ANSI_F, kVK_ANSI_N, kVK_ANSI_O]
        if modifiers == UInt32(cmdKey), protectedKeys.contains(Int(keyCode)) {
            return "为避免覆盖复制、粘贴等常用操作，请添加其他修饰键。"
        }
        return nil
    }

    init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode; self.modifiers = modifiers; self.keyLabel = keyLabel
    }

    init(event: NSEvent) {
        let flags = event.modifierFlags
        var mask: UInt32 = 0
        if flags.contains(.command) { mask |= UInt32(cmdKey) }
        if flags.contains(.control) { mask |= UInt32(controlKey) }
        if flags.contains(.option) { mask |= UInt32(optionKey) }
        if flags.contains(.shift) { mask |= UInt32(shiftKey) }
        let special: [UInt16: String] = [36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 76: "⌤", 117: "⌦",
            123: "←", 124: "→", 125: "↓", 126: "↑", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15",
            106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20"]
        // Translate without modifiers so Option/Control do not turn the label into
        // an accented character or a control code. The physical key code is saved.
        let characters = event.characters(byApplyingModifiers: [])?.uppercased() ?? ""
        let label = special[event.keyCode] ?? (characters.isEmpty ? "Key \(event.keyCode)" : characters)
        self.init(keyCode: UInt32(event.keyCode), modifiers: mask, keyLabel: label)
    }
}

@MainActor protocol HotKeyRegistering: AnyObject {
    /// A failed registration must leave an existing registration untouched.
    func register(_ shortcut: Shortcut) -> OSStatus
    func unregister()
}

@MainActor final class CarbonHotKeyRegistrar: HotKeyRegistering {
    private var reference: EventHotKeyRef?
    func register(_ shortcut: Shortcut) -> OSStatus {
        var candidate: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
            EventHotKeyID(signature: 0x434C4950, id: 1), GetApplicationEventTarget(), 0, &candidate)
        guard status == noErr else { return status }
        if let reference { UnregisterEventHotKey(reference) }
        reference = candidate
        return noErr
    }
    func unregister() {
        if let reference { UnregisterEventHotKey(reference) }
        reference = nil
    }
}

@MainActor final class ShortcutManager: ObservableObject {
    static let preferenceKey = "globalShortcut"
    @Published private(set) var shortcut: Shortcut
    @Published private(set) var isAvailable = false
    @Published private(set) var isRecording = false
    @Published private(set) var message = ""
    @Published private(set) var hasError = false
    private let defaults: UserDefaults
    private let registrar: HotKeyRegistering

    init(defaults: UserDefaults = .standard, registrar: HotKeyRegistering) {
        self.defaults = defaults; self.registrar = registrar
        if let data = defaults.data(forKey: Self.preferenceKey),
           let saved = try? JSONDecoder().decode(Shortcut.self, from: data), saved.validationMessage == nil {
            shortcut = saved
        } else { shortcut = .defaultShortcut }
        isAvailable = registrar.register(shortcut) == noErr
        if !isAvailable { message = "当前快捷键无法注册，可能已被占用。可从菜单栏打开，或重新设置。"; hasError = true }
    }

    func startRecording() {
        guard !isRecording else { return }
        registrar.unregister()
        isRecording = true; isAvailable = false; hasError = false
        message = "按下新的组合键；Esc 取消。录入期间暂停全局唤起。"
    }

    func cancelRecording() {
        guard isRecording else { return }
        isRecording = false
        isAvailable = registrar.register(shortcut) == noErr
        hasError = !isAvailable
        message = isAvailable ? "已取消录入，保留原快捷键。" : "原快捷键暂时无法恢复，请重新设置；仍可从菜单栏打开。"
    }

    @discardableResult func apply(_ candidate: Shortcut) -> Bool {
        if let error = candidate.validationMessage { message = error; hasError = true; return false }
        let sameBinding = candidate.keyCode == shortcut.keyCode && candidate.modifiers == shortcut.modifiers
        if !sameBinding || !isAvailable {
            let result = registrar.register(candidate)
            guard result == noErr else {
                hasError = true
                message = "无法使用这个组合键（可能已被系统或其他应用占用）。请选择其他组合。"
                return false
            }
        }
        shortcut = candidate; isAvailable = true; isRecording = false; hasError = false
        if let data = try? JSONEncoder().encode(candidate) { defaults.set(data, forKey: Self.preferenceKey) }
        message = "已保存，立即生效。"
        return true
    }
}
