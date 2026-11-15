import Foundation

/// Identifies who owns a shortcut, for conflict reporting.
public enum HotkeyOwner: Hashable, Sendable {
    case app(UUID)
    case snap(SnapAction)
}

public struct HotkeyAssignment: Hashable, Sendable {
    public var owner: HotkeyOwner
    public var title: String
    public var combo: KeyCombo

    public init(owner: HotkeyOwner, title: String, combo: KeyCombo) {
        self.owner = owner
        self.title = title
        self.combo = combo
    }
}

public enum ConflictDetector {

    /// All *active* shortcut assignments in a config.
    public static func assignments(in config: AppConfig) -> [HotkeyAssignment] {
        var result: [HotkeyAssignment] = []
        for app in config.apps where app.enabled {
            if let c = app.combo {
                result.append(HotkeyAssignment(owner: .app(app.id), title: app.name, combo: c))
            }
        }
        for action in SnapAction.allCases {
            if let c = config.combo(for: action) {
                result.append(HotkeyAssignment(owner: .snap(action), title: action.title, combo: c))
            }
        }
        return result
    }

    /// Owners whose combo is used more than once inside KeyPilot.
    /// Returns owner -> titles of the *other* owners it clashes with.
    public static func internalConflicts(in config: AppConfig) -> [HotkeyOwner: [String]] {
        let all = assignments(in: config)
        let grouped = Dictionary(grouping: all, by: { $0.combo })
        var result: [HotkeyOwner: [String]] = [:]
        for (_, group) in grouped where group.count > 1 {
            for a in group {
                result[a.owner] = group.filter { $0.owner != a.owner }.map(\.title)
            }
        }
        return result
    }

    /// Who (other than `excluding`) already uses `combo`.
    public static func owner(of combo: KeyCombo, in config: AppConfig, excluding: HotkeyOwner?) -> HotkeyAssignment? {
        assignments(in: config).first { $0.combo == combo && $0.owner != excluding }
    }
}
