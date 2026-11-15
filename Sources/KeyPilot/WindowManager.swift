import AppKit
import ApplicationServices
import KeyPilotCore

/// Moves / resizes the focused window of the frontmost app using the
/// Accessibility API. Requires the user to grant Accessibility permission.
final class WindowManager {
    static let shared = WindowManager()

    private struct Memory {
        let window: AXUIElement
        let original: CGRect      // AX (top-left) coordinates
        var lastApplied: CGRect   // AX (top-left) coordinates
    }

    private var memories: [Memory] = []

    func perform(_ action: SnapAction, gap: CGFloat, cycle: Bool) {
        guard Accessibility.isTrusted else {
            Accessibility.request()
            return
        }
        guard let window = focusedWindow(), let axFrame = frame(of: window) else {
            NSSound.beep()
            return
        }
        if isFullScreen(window) { NSSound.beep(); return }

        let screens = NSScreen.screens
        guard let primary = screens.first else { return }
        let primaryHeight = primary.frame.height
        let current = SnapGeometry.flip(axFrame, primaryScreenHeight: primaryHeight)
        guard let idx = SnapGeometry.bestScreenIndex(for: current, screens: screens.map(\.frame)) else { return }
        let screen = screens[idx]
        let visible = screen.visibleFrame

        // Restore
        if action == .restore {
            if let i = memoryIndex(for: window) {
                let original = memories[i].original
                memories.remove(at: i)
                setFrame(original, of: window)
            } else {
                NSSound.beep()
            }
            return
        }

        var target: CGRect?
        switch action {
        case .nextDisplay, .previousDisplay:
            guard screens.count > 1 else { NSSound.beep(); return }
            let ordered = screens.enumerated().sorted {
                ($0.element.frame.minX, -$0.element.frame.minY) < ($1.element.frame.minX, -$1.element.frame.minY)
            }
            guard let pos = ordered.firstIndex(where: { $0.offset == idx }) else { return }
            let step = action == .nextDisplay ? 1 : -1
            let dest = ordered[(pos + step + ordered.count) % ordered.count].element
            target = SnapGeometry.move(current, from: visible, to: dest.visibleFrame)
        default:
            target = SnapGeometry.target(for: action, current: current, visible: visible, gap: gap, cycle: cycle)
        }
        guard let target else { return }

        let axTarget = SnapGeometry.flip(target, primaryScreenHeight: primaryHeight)
        remember(window, current: axFrame)
        setFrame(axTarget, of: window)
        if let i = memoryIndex(for: window) {
            memories[i].lastApplied = frame(of: window) ?? axTarget
        }
    }

    // MARK: - Restore memory

    private func memoryIndex(for window: AXUIElement) -> Int? {
        memories.firstIndex { CFEqual($0.window, window) }
    }

    private func remember(_ window: AXUIElement, current: CGRect) {
        if let i = memoryIndex(for: window) {
            // If the user moved the window by hand since our last snap,
            // treat the hand-placed frame as the new "original".
            if !SnapGeometry.approximatelyEqual(memories[i].lastApplied, current, tolerance: 8) {
                memories[i] = Memory(window: window, original: current, lastApplied: current)
            }
        } else {
            memories.append(Memory(window: window, original: current, lastApplied: current))
            if memories.count > 64 { memories.removeFirst(memories.count - 64) }
        }
    }

    // MARK: - AX helpers

    private func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        for attr in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            var value: CFTypeRef?
            if AXUIElementCopyAttributeValue(appEl, attr as CFString, &value) == .success,
               let value, CFGetTypeID(value) == AXUIElementGetTypeID() {
                return (value as! AXUIElement)
            }
        }
        return nil
    }

    private func isFullScreen(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value) == .success else { return false }
        return (value as? Bool) ?? false
    }

    private func frame(of window: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posRef, let sizeRef else { return nil }
        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    private func setFrame(_ rect: CGRect, of window: AXUIElement) {
        var point = rect.origin
        var size = rect.size
        guard let pos = AXValueCreate(.cgPoint, &point), let sz = AXValueCreate(.cgSize, &size) else { return }

        // Some apps animate (and fight) frame changes while "enhanced UI" is on.
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        let appEl = AXUIElementCreateApplication(pid)
        let enhanced = "AXEnhancedUserInterface" as CFString
        var enhancedValue: CFTypeRef?
        let wasEnhanced = AXUIElementCopyAttributeValue(appEl, enhanced, &enhancedValue) == .success
            && (enhancedValue as? Bool) == true
        if wasEnhanced { AXUIElementSetAttributeValue(appEl, enhanced, kCFBooleanFalse) }

        // size → position → size: lets windows grow when moving to a larger
        // display and shrink before moving to a smaller one.
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sz)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sz)

        if wasEnhanced { AXUIElementSetAttributeValue(appEl, enhanced, kCFBooleanTrue) }
    }
}

enum Accessibility {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt (only once per app identity).
    static func request() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
