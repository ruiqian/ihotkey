import Foundation
import CoreGraphics

/// Every window layout action iHotkey supports.
public enum SnapAction: String, CaseIterable, Codable, Identifiable, Sendable {
    // Halves
    case leftHalf, rightHalf, topHalf, bottomHalf
    // Quarters
    case topLeft, topRight, bottomLeft, bottomRight
    // Thirds
    case firstThird, centerThird, lastThird, firstTwoThirds, lastTwoThirds
    // Whole screen
    case maximize, almostMaximize, maximizeHeight, center, restore
    // Displays
    case nextDisplay, previousDisplay

    public var id: String { rawValue }

    public enum Group: String, CaseIterable, Sendable {
        case halves, quarters, thirds, screen, displays
    }

    public var group: Group {
        switch self {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf: return .halves
        case .topLeft, .topRight, .bottomLeft, .bottomRight: return .quarters
        case .firstThird, .centerThird, .lastThird, .firstTwoThirds, .lastTwoThirds: return .thirds
        case .maximize, .almostMaximize, .maximizeHeight, .center, .restore: return .screen
        case .nextDisplay, .previousDisplay: return .displays
        }
    }

    public var title: String {
        switch self {
        case .leftHalf: return L("左半屏", "Left Half")
        case .rightHalf: return L("右半屏", "Right Half")
        case .topHalf: return L("上半屏", "Top Half")
        case .bottomHalf: return L("下半屏", "Bottom Half")
        case .topLeft: return L("左上角", "Top Left")
        case .topRight: return L("右上角", "Top Right")
        case .bottomLeft: return L("左下角", "Bottom Left")
        case .bottomRight: return L("右下角", "Bottom Right")
        case .firstThird: return L("左 1/3", "First Third")
        case .centerThird: return L("中 1/3", "Center Third")
        case .lastThird: return L("右 1/3", "Last Third")
        case .firstTwoThirds: return L("左 2/3", "First Two Thirds")
        case .lastTwoThirds: return L("右 2/3", "Last Two Thirds")
        case .maximize: return L("最大化", "Maximize")
        case .almostMaximize: return L("几乎最大化", "Almost Maximize")
        case .maximizeHeight: return L("最大化高度", "Maximize Height")
        case .center: return L("居中", "Center")
        case .restore: return L("恢复原大小", "Restore")
        case .nextDisplay: return L("移到下一个显示器", "Next Display")
        case .previousDisplay: return L("移到上一个显示器", "Previous Display")
        }
    }

    /// Unit rectangle (0...1, origin at TOP-left of the screen) used for the
    /// preview glyph and for layout. `nil` for actions that are not a fixed region.
    public var unitRect: CGRect? {
        switch self {
        case .leftHalf: return CGRect(x: 0, y: 0, width: 0.5, height: 1)
        case .rightHalf: return CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        case .topHalf: return CGRect(x: 0, y: 0, width: 1, height: 0.5)
        case .bottomHalf: return CGRect(x: 0, y: 0.5, width: 1, height: 0.5)
        case .topLeft: return CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        case .topRight: return CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
        case .bottomLeft: return CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)
        case .bottomRight: return CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        case .firstThird: return CGRect(x: 0, y: 0, width: 1.0 / 3, height: 1)
        case .centerThird: return CGRect(x: 1.0 / 3, y: 0, width: 1.0 / 3, height: 1)
        case .lastThird: return CGRect(x: 2.0 / 3, y: 0, width: 1.0 / 3, height: 1)
        case .firstTwoThirds: return CGRect(x: 0, y: 0, width: 2.0 / 3, height: 1)
        case .lastTwoThirds: return CGRect(x: 1.0 / 3, y: 0, width: 2.0 / 3, height: 1)
        case .maximize: return CGRect(x: 0, y: 0, width: 1, height: 1)
        case .almostMaximize: return CGRect(x: 0.05, y: 0.05, width: 0.9, height: 0.9)
        case .maximizeHeight, .center, .restore, .nextDisplay, .previousDisplay: return nil
        }
    }

    /// Halves cycle through 1/2 → 2/3 → 1/3 when pressed repeatedly.
    public var supportsCycling: Bool {
        switch self {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf: return true
        default: return false
        }
    }

    /// Defaults are close to the widely used Rectangle/Spectacle layout.
    public var defaultCombo: KeyCombo? {
        let ca: KeyModifiers = [.control, .option]
        let cac: KeyModifiers = [.control, .option, .command]
        switch self {
        case .leftHalf: return KeyCombo(keyCode: KeyCode.leftArrow, modifiers: ca)
        case .rightHalf: return KeyCombo(keyCode: KeyCode.rightArrow, modifiers: ca)
        case .topHalf: return KeyCombo(keyCode: KeyCode.upArrow, modifiers: ca)
        case .bottomHalf: return KeyCombo(keyCode: KeyCode.downArrow, modifiers: ca)
        case .topLeft: return KeyCombo(keyCode: KeyCode.u, modifiers: ca)
        case .topRight: return KeyCombo(keyCode: KeyCode.i, modifiers: ca)
        case .bottomLeft: return KeyCombo(keyCode: KeyCode.j, modifiers: ca)
        case .bottomRight: return KeyCombo(keyCode: KeyCode.k, modifiers: ca)
        case .firstThird: return KeyCombo(keyCode: KeyCode.d, modifiers: ca)
        case .centerThird: return KeyCombo(keyCode: KeyCode.f, modifiers: ca)
        case .lastThird: return KeyCombo(keyCode: KeyCode.g, modifiers: ca)
        case .firstTwoThirds: return KeyCombo(keyCode: KeyCode.e, modifiers: ca)
        case .lastTwoThirds: return KeyCombo(keyCode: KeyCode.t, modifiers: ca)
        case .maximize: return KeyCombo(keyCode: KeyCode.returnKey, modifiers: ca)
        case .almostMaximize: return nil
        case .maximizeHeight: return KeyCombo(keyCode: KeyCode.upArrow, modifiers: [.control, .option, .shift])
        case .center: return KeyCombo(keyCode: KeyCode.c, modifiers: ca)
        case .restore: return KeyCombo(keyCode: KeyCode.delete, modifiers: ca)
        case .nextDisplay: return KeyCombo(keyCode: KeyCode.rightArrow, modifiers: cac)
        case .previousDisplay: return KeyCombo(keyCode: KeyCode.leftArrow, modifiers: cac)
        }
    }

    public static var defaultBindings: [String: KeyCombo] {
        var d: [String: KeyCombo] = [:]
        for a in allCases { if let c = a.defaultCombo { d[a.rawValue] = c } }
        return d
    }
}

extension SnapAction.Group {
    public var title: String {
        switch self {
        case .halves: return L("半屏", "Halves")
        case .quarters: return L("四分屏", "Quarters")
        case .thirds: return L("三分屏", "Thirds")
        case .screen: return L("整屏", "Screen")
        case .displays: return L("多显示器", "Displays")
        }
    }

    public var actions: [SnapAction] { SnapAction.allCases.filter { $0.group == self } }
}
