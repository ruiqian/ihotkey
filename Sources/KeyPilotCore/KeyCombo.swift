import Foundation

/// Modifier flags, independent of AppKit / Carbon so the core stays testable.
public struct KeyModifiers: OptionSet, Codable, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let command = KeyModifiers(rawValue: 1 << 0)
    public static let option  = KeyModifiers(rawValue: 1 << 1)
    public static let control = KeyModifiers(rawValue: 1 << 2)
    public static let shift   = KeyModifiers(rawValue: 1 << 3)

    /// Carbon modifier mask (cmdKey / shiftKey / optionKey / controlKey).
    public var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= 1 << 8 }   // cmdKey     = 256
        if contains(.shift)   { flags |= 1 << 9 }   // shiftKey   = 512
        if contains(.option)  { flags |= 1 << 11 }  // optionKey  = 2048
        if contains(.control) { flags |= 1 << 12 }  // controlKey = 4096
        return flags
    }

    /// Symbols in the canonical macOS order: ⌃ ⌥ ⇧ ⌘
    public var symbols: String {
        var s = ""
        if contains(.control) { s += "⌃" }
        if contains(.option)  { s += "⌥" }
        if contains(.shift)   { s += "⇧" }
        if contains(.command) { s += "⌘" }
        return s
    }
}

/// A global keyboard shortcut: a virtual key code plus modifiers.
public struct KeyCombo: Codable, Hashable, Sendable, CustomStringConvertible {
    public var keyCode: UInt16
    public var modifiers: KeyModifiers

    public init(keyCode: UInt16, modifiers: KeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Human readable, e.g. "⌃⌥←".
    public var displayString: String {
        modifiers.symbols + KeyNames.name(for: keyCode)
    }

    public var description: String { displayString }

    /// A combo is valid as a *global* hotkey when it has at least one of ⌘⌃⌥,
    /// or when the key is a function key (F1–F20), which may be used bare or with ⇧.
    public var isValidGlobalHotKey: Bool {
        if KeyNames.isModifierKey(keyCode) { return false }
        if KeyNames.isFunctionKey(keyCode) { return true }
        return !modifiers.intersection([.command, .control, .option]).isEmpty
    }
}

extension KeyCombo {
    /// Common system shortcuts that users almost certainly do not want to override.
    public static let systemReserved: [KeyCombo: String] = [
        KeyCombo(keyCode: KeyCode.space, modifiers: [.command]): "Spotlight",
        KeyCombo(keyCode: KeyCode.tab, modifiers: [.command]): "App Switcher",
        KeyCombo(keyCode: KeyCode.q, modifiers: [.command]): "Quit",
        KeyCombo(keyCode: KeyCode.w, modifiers: [.command]): "Close Window",
        KeyCombo(keyCode: KeyCode.h, modifiers: [.command]): "Hide",
        KeyCombo(keyCode: KeyCode.m, modifiers: [.command]): "Minimize",
        KeyCombo(keyCode: KeyCode.c, modifiers: [.command]): "Copy",
        KeyCombo(keyCode: KeyCode.v, modifiers: [.command]): "Paste",
        KeyCombo(keyCode: KeyCode.x, modifiers: [.command]): "Cut",
        KeyCombo(keyCode: KeyCode.z, modifiers: [.command]): "Undo",
        KeyCombo(keyCode: KeyCode.a, modifiers: [.command]): "Select All",
        KeyCombo(keyCode: KeyCode.s, modifiers: [.command]): "Save",
        KeyCombo(keyCode: KeyCode.escape, modifiers: [.command, .option]): "Force Quit",
        KeyCombo(keyCode: KeyCode.three, modifiers: [.command, .shift]): "Screenshot",
        KeyCombo(keyCode: KeyCode.four, modifiers: [.command, .shift]): "Screenshot",
        KeyCombo(keyCode: KeyCode.five, modifiers: [.command, .shift]): "Screenshot",
    ]

    public var systemReservedName: String? { KeyCombo.systemReserved[self] }
}
