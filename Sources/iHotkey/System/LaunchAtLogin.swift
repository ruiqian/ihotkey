import AppKit
import ServiceManagement
import iHotkeyCore

/// Launch at login.
/// - macOS 13+: `SMAppService.mainApp` (shows up in System Settings › Login Items).
/// - macOS 12:  a per-user LaunchAgent in ~/Library/LaunchAgents.
enum LaunchAtLogin {
    static let launchArgument = "--launched-at-login"
    private static let agentLabel = "com.ihotkey.app.launcher"

    private static var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")
    }

    enum State: Equatable {
        case enabled, disabled, requiresApproval
    }

    static var state: State {
        if #available(macOS 13, *) {
            switch SMAppService.mainApp.status {
            case .enabled: return .enabled
            case .requiresApproval: return .requiresApproval
            default: return .disabled
            }
        }
        return FileManager.default.fileExists(atPath: agentURL.path) ? .enabled : .disabled
    }

    static func set(_ enabled: Bool) throws {
        if #available(macOS 13, *) {
            // Clean up a LaunchAgent left over from running on macOS 12.
            try? FileManager.default.removeItem(at: agentURL)
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return
        }
        if enabled {
            try writeAgent()
        } else if FileManager.default.fileExists(atPath: agentURL.path) {
            try FileManager.default.removeItem(at: agentURL)
        }
    }

    static func openLoginItemsSettings() {
        if #available(macOS 13, *) {
            SMAppService.openSystemSettingsLoginItems()
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Accounts.prefPane"))
        }
    }

    /// Re-point an existing LaunchAgent at the current bundle location
    /// (e.g. after the user moved the app into /Applications).
    static func refreshAgentIfNeeded() {
        if #available(macOS 13, *) { return }
        guard FileManager.default.fileExists(atPath: agentURL.path) else { return }
        try? writeAgent()
    }

    private static func writeAgent() throws {
        let dir = agentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": ["/usr/bin/open", "-a", Bundle.main.bundlePath, "--args", launchArgument],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: agentURL, options: .atomic)
    }

    /// Best effort detection of "this launch came from login".
    static var wasLaunchedAtLogin: Bool {
        if CommandLine.arguments.contains(launchArgument) { return true }
        // Login items start within the first minutes after boot; a user rarely
        // launches iHotkey by hand that early. Only applies when enabled.
        if state == .enabled && ProcessInfo.processInfo.systemUptime < 180 { return true }
        if let event = NSAppleEventManager.shared().currentAppleEvent,
           event.eventID == kAEOpenApplication,
           event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem {
            return true
        }
        return false
    }
}
