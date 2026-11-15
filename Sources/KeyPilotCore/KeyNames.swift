import Foundation

/// Virtual key codes (ANSI layout, from Carbon's Events.h).
public enum KeyCode {
    public static let a: UInt16 = 0x00, s: UInt16 = 0x01, d: UInt16 = 0x02, f: UInt16 = 0x03
    public static let h: UInt16 = 0x04, g: UInt16 = 0x05, z: UInt16 = 0x06, x: UInt16 = 0x07
    public static let c: UInt16 = 0x08, v: UInt16 = 0x09, b: UInt16 = 0x0B, q: UInt16 = 0x0C
    public static let w: UInt16 = 0x0D, e: UInt16 = 0x0E, r: UInt16 = 0x0F, y: UInt16 = 0x10
    public static let t: UInt16 = 0x11, one: UInt16 = 0x12, two: UInt16 = 0x13, three: UInt16 = 0x14
    public static let four: UInt16 = 0x15, six: UInt16 = 0x16, five: UInt16 = 0x17, equal: UInt16 = 0x18
    public static let nine: UInt16 = 0x19, seven: UInt16 = 0x1A, minus: UInt16 = 0x1B, eight: UInt16 = 0x1C
    public static let zero: UInt16 = 0x1D, rightBracket: UInt16 = 0x1E, o: UInt16 = 0x1F, u: UInt16 = 0x20
    public static let leftBracket: UInt16 = 0x21, i: UInt16 = 0x22, p: UInt16 = 0x23, l: UInt16 = 0x25
    public static let j: UInt16 = 0x26, quote: UInt16 = 0x27, k: UInt16 = 0x28, semicolon: UInt16 = 0x29
    public static let backslash: UInt16 = 0x2A, comma: UInt16 = 0x2B, slash: UInt16 = 0x2C, n: UInt16 = 0x2D
    public static let m: UInt16 = 0x2E, period: UInt16 = 0x2F, grave: UInt16 = 0x32

    public static let returnKey: UInt16 = 0x24, tab: UInt16 = 0x30, space: UInt16 = 0x31
    public static let delete: UInt16 = 0x33, escape: UInt16 = 0x35, forwardDelete: UInt16 = 0x75
    public static let home: UInt16 = 0x73, end: UInt16 = 0x77, pageUp: UInt16 = 0x74, pageDown: UInt16 = 0x79
    public static let leftArrow: UInt16 = 0x7B, rightArrow: UInt16 = 0x7C
    public static let downArrow: UInt16 = 0x7D, upArrow: UInt16 = 0x7E
    public static let keypadEnter: UInt16 = 0x4C
}

public enum KeyNames {
    private static let table: [UInt16: String] = {
        var t: [UInt16: String] = [
            0x00: "A", 0x01: "S", 0x02: "D", 0x03: "F", 0x04: "H", 0x05: "G", 0x06: "Z", 0x07: "X",
            0x08: "C", 0x09: "V", 0x0B: "B", 0x0C: "Q", 0x0D: "W", 0x0E: "E", 0x0F: "R", 0x10: "Y",
            0x11: "T", 0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x16: "6", 0x17: "5", 0x18: "=",
            0x19: "9", 0x1A: "7", 0x1B: "-", 0x1C: "8", 0x1D: "0", 0x1E: "]", 0x1F: "O", 0x20: "U",
            0x21: "[", 0x22: "I", 0x23: "P", 0x25: "L", 0x26: "J", 0x27: "'", 0x28: "K", 0x29: ";",
            0x2A: "\\", 0x2B: ",", 0x2C: "/", 0x2D: "N", 0x2E: "M", 0x2F: ".", 0x32: "`",
            0x24: "↩", 0x30: "⇥", 0x31: "Space", 0x33: "⌫", 0x35: "⎋", 0x75: "⌦",
            0x73: "↖", 0x77: "↘", 0x74: "⇞", 0x79: "⇟",
            0x7B: "←", 0x7C: "→", 0x7D: "↓", 0x7E: "↑",
            0x4C: "⌤",
            // Keypad
            0x41: "Num.", 0x43: "Num*", 0x45: "Num+", 0x47: "Clear", 0x4B: "Num/", 0x4E: "Num-",
            0x51: "Num=", 0x52: "Num0", 0x53: "Num1", 0x54: "Num2", 0x55: "Num3", 0x56: "Num4",
            0x57: "Num5", 0x58: "Num6", 0x59: "Num7", 0x5B: "Num8", 0x5C: "Num9",
        ]
        for (code, n) in functionKeys { t[code] = "F\(n)" }
        return t
    }()

    /// key code -> F-number
    public static let functionKeys: [UInt16: Int] = [
        0x7A: 1, 0x78: 2, 0x63: 3, 0x76: 4, 0x60: 5, 0x61: 6, 0x62: 7, 0x64: 8, 0x65: 9, 0x6D: 10,
        0x67: 11, 0x6F: 12, 0x69: 13, 0x6B: 14, 0x71: 15, 0x6A: 16, 0x40: 17, 0x4F: 18, 0x50: 19, 0x5A: 20,
    ]

    private static let modifierKeyCodes: Set<UInt16> = [
        0x37, 0x36, // command L/R
        0x38, 0x3C, // shift L/R
        0x3A, 0x3D, // option L/R
        0x3B, 0x3E, // control L/R
        0x39,       // caps lock
        0x3F,       // fn
    ]

    public static func name(for keyCode: UInt16) -> String {
        table[keyCode] ?? "Key\(keyCode)"
    }

    public static func isFunctionKey(_ keyCode: UInt16) -> Bool {
        functionKeys[keyCode] != nil
    }

    public static func isModifierKey(_ keyCode: UInt16) -> Bool {
        modifierKeyCodes.contains(keyCode)
    }
}
