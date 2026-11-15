import AppKit
import ApplicationServices

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

    /// The switch in System Settings can be ON while macOS still refuses access:
    /// the grant is bound to the app's code signature, so a rebuilt or replaced
    /// copy no longer matches. Removing iHotkey's stale entry and asking again fixes it.
    static func resetAndRequest() {
        if let bid = Bundle.main.bundleIdentifier {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            p.arguments = ["reset", "Accessibility", bid]
            try? p.run()
            p.waitUntilExit()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            request()
            openSettings()
        }
    }
}
