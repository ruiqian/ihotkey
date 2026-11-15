import Foundation

/// What happens when an app shortcut is pressed.
public enum AppHotkeyBehavior: String, Codable, CaseIterable, Sendable {
    /// Launch the app, or bring it to the front if already running.
    case launchOrFocus
    /// Like `launchOrFocus`, but hide the app if it is already frontmost.
    case toggle

    public var title: String {
        switch self {
        case .launchOrFocus: return L("打开 / 切换到", "Open / Focus")
        case .toggle: return L("显示 / 隐藏", "Show / Hide")
        }
    }
}

public struct AppBinding: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var bundleIdentifier: String?
    public var path: String
    public var combo: KeyCombo?
    public var behavior: AppHotkeyBehavior
    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        bundleIdentifier: String?,
        path: String,
        combo: KeyCombo? = nil,
        behavior: AppHotkeyBehavior = .toggle,
        enabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.path = path
        self.combo = combo
        self.behavior = behavior
        self.enabled = enabled
    }

    enum CodingKeys: String, CodingKey { case id, name, bundleIdentifier, path, combo, behavior, enabled }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        bundleIdentifier = try c.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        path = try c.decode(String.self, forKey: .path)
        combo = try c.decodeIfPresent(KeyCombo.self, forKey: .combo)
        behavior = try c.decodeIfPresent(AppHotkeyBehavior.self, forKey: .behavior) ?? .toggle
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var hotkeysEnabled: Bool = true
    public var showWindowOnLaunch: Bool = true
    public var showDockIconWhenWindowOpen: Bool = true
    public var snapGap: Double = 0
    public var cycleHalves: Bool = true
    public var language: AppLanguage = .system

    public init() {}

    enum CodingKeys: String, CodingKey {
        case hotkeysEnabled, showWindowOnLaunch, showDockIconWhenWindowOpen, snapGap, cycleHalves, language
    }

    // Tolerant decoding: unknown/missing keys fall back to defaults so that
    // configs written by older or newer versions keep loading.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        hotkeysEnabled = try c.decodeIfPresent(Bool.self, forKey: .hotkeysEnabled) ?? d.hotkeysEnabled
        showWindowOnLaunch = try c.decodeIfPresent(Bool.self, forKey: .showWindowOnLaunch) ?? d.showWindowOnLaunch
        showDockIconWhenWindowOpen = try c.decodeIfPresent(Bool.self, forKey: .showDockIconWhenWindowOpen) ?? d.showDockIconWhenWindowOpen
        snapGap = try c.decodeIfPresent(Double.self, forKey: .snapGap) ?? d.snapGap
        cycleHalves = try c.decodeIfPresent(Bool.self, forKey: .cycleHalves) ?? d.cycleHalves
        language = (try? c.decodeIfPresent(AppLanguage.self, forKey: .language)) ?? d.language
    }
}

public struct AppConfig: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int = AppConfig.currentVersion
    public var apps: [AppBinding] = []
    /// SnapAction.rawValue -> combo. A missing key means "no shortcut".
    public var snaps: [String: KeyCombo] = SnapAction.defaultBindings
    public var settings: AppSettings = AppSettings()

    public init() {}

    enum CodingKeys: String, CodingKey { case version, apps, snaps, settings }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? AppConfig.currentVersion
        apps = try c.decodeIfPresent([AppBinding].self, forKey: .apps) ?? []
        snaps = try c.decodeIfPresent([String: KeyCombo].self, forKey: .snaps) ?? SnapAction.defaultBindings
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
        // Drop actions this version does not know about.
        snaps = snaps.filter { SnapAction(rawValue: $0.key) != nil }
    }

    public func combo(for action: SnapAction) -> KeyCombo? { snaps[action.rawValue] }

    public mutating func setCombo(_ combo: KeyCombo?, for action: SnapAction) {
        snaps[action.rawValue] = combo
    }

    public func encoded() throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(self)
    }

    public static func decode(_ data: Data) throws -> AppConfig {
        try JSONDecoder().decode(AppConfig.self, from: data)
    }
}
