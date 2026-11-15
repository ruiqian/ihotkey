import AppKit
import Combine
import KeyPilotCore

enum SidebarTab: String, CaseIterable, Identifiable {
    case apps, snap, general, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .apps: return L("应用快捷键", "App Shortcuts")
        case .snap: return L("分屏", "Window Snap")
        case .general: return L("通用", "General")
        case .about: return L("关于", "About")
        }
    }

    var symbol: String {
        switch self {
        case .apps: return "square.grid.2x2"
        case .snap: return "rectangle.split.2x1"
        case .general: return "gearshape"
        case .about: return "info.circle"
        }
    }
}

/// Single source of truth for the UI, the menu bar and the hotkey engine.
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var config: AppConfig {
        didSet {
            guard config != oldValue else { return }
            Localizer.language = config.settings.language
            guard persistenceEnabled else { return }
            scheduleSave()
            scheduleApply()
        }
    }
    private var persistenceEnabled = true

    /// For screenshot rendering: show demo data without touching disk or hotkeys.
    func replaceConfigWithoutSaving(_ cfg: AppConfig) {
        persistenceEnabled = false
        config = cfg
    }
    @Published var selectedTab: SidebarTab = .apps
    @Published private(set) var accessibilityTrusted = Accessibility.isTrusted
    @Published private(set) var launchAtLoginState = LaunchAtLogin.state
    @Published var launchAtLoginError: String?
    @Published private(set) var registrationErrors: [HotkeyOwner: String] = [:]
    /// A freshly added app row starts recording its shortcut immediately.
    @Published var pendingRecordOwner: HotkeyOwner?

    let isFirstRun: Bool
    private var recordingDepth = 0
    private var saveWork: DispatchWorkItem?
    private var applyWork: DispatchWorkItem?
    private var axTimer: Timer?

    static var configDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("KeyPilot", isDirectory: true)
    }
    static var configURL: URL { configDirectory.appendingPathComponent("config.json") }

    private init() {
        if let data = try? Data(contentsOf: AppState.configURL), let cfg = try? AppConfig.decode(data) {
            config = cfg
            isFirstRun = false
        } else {
            config = AppConfig()
            isFirstRun = true
        }
        Localizer.language = config.settings.language
        if isFirstRun && !CommandLine.arguments.contains(where: { $0.hasPrefix("--render") || $0 == "--self-test" }) {
            saveNow()
        }
        startAccessibilityPolling()
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    func saveNow() {
        do {
            try FileManager.default.createDirectory(at: AppState.configDirectory, withIntermediateDirectories: true)
            try config.encoded().write(to: AppState.configURL, options: .atomic)
        } catch {
            NSLog("KeyPilot: failed to save config: \(error)")
        }
    }

    func exportConfig(to url: URL) throws { try config.encoded().write(to: url, options: .atomic) }

    func importConfig(from url: URL) throws {
        config = try AppConfig.decode(Data(contentsOf: url))
    }

    // MARK: - Hotkeys

    private func scheduleApply() {
        applyWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.applyHotkeys() }
        applyWork = work
        DispatchQueue.main.async(execute: work)
    }

    func applyHotkeys() {
        var bindings: [HotKeyCenter.Binding] = []
        if config.settings.hotkeysEnabled && recordingDepth == 0 {
            for app in config.apps where app.enabled {
                guard let combo = app.combo else { continue }
                let id = app.id
                bindings.append(.init(owner: .app(id), combo: combo) { [weak self] in
                    guard let self, let current = self.config.apps.first(where: { $0.id == id }) else { return }
                    AppLauncher.trigger(current)
                })
            }
            for action in SnapAction.allCases {
                guard let combo = config.combo(for: action) else { continue }
                bindings.append(.init(owner: .snap(action), combo: combo) { [weak self] in
                    self?.performSnap(action)
                })
            }
        }
        let failures = HotKeyCenter.shared.apply(bindings)
        if recordingDepth == 0 { registrationErrors = failures }
    }

    func performSnap(_ action: SnapAction) {
        let outcome = WindowManager.shared.perform(
            action,
            gap: CGFloat(config.settings.snapGap),
            cycle: config.settings.cycleHalves
        )
        if outcome == .notTrusted {
            // Make the failure visible instead of silently doing nothing.
            refreshAccessibility()
            selectedTab = .snap
            (NSApp.delegate as? AppDelegate)?.showMainWindow()
            showToast(L("分屏需要辅助功能权限，请按页面顶部提示授权", "Window snap needs Accessibility permission — see the banner above"), isError: true)
        }
    }

    /// Global hotkeys swallow key presses before our window sees them, so they are
    /// paused while a shortcut field is recording.
    func beginRecording() {
        recordingDepth += 1
        if recordingDepth == 1 { HotKeyCenter.shared.unregisterAll() }
    }

    func endRecording() {
        recordingDepth = max(0, recordingDepth - 1)
        if recordingDepth == 0 { applyHotkeys() }
    }

    // MARK: - App bindings

    func addApp(url: URL) {
        guard var binding = AppLauncher.makeBinding(from: url) else { return }
        let exists = config.apps.contains {
            $0.path == binding.path || ($0.bundleIdentifier != nil && $0.bundleIdentifier == binding.bundleIdentifier)
        }
        if exists { return }
        binding.behavior = .toggle
        config.apps.append(binding)
        pendingRecordOwner = .app(binding.id)
    }

    func removeApp(_ id: UUID) {
        config.apps.removeAll { $0.id == id }
    }

    func resetSnapDefaults() {
        config.snaps = SnapAction.defaultBindings
    }

    func clearCombo(for owner: HotkeyOwner) {
        switch owner {
        case .app(let id):
            if let i = config.apps.firstIndex(where: { $0.id == id }) { config.apps[i].combo = nil }
        case .snap(let action):
            config.setCombo(nil, for: action)
        }
    }

    func bindingForApp(_ id: UUID) -> AppBinding? { config.apps.first { $0.id == id } }

    // MARK: - Toast

    struct Toast: Equatable {
        let id = UUID()
        let message: String
        let isError: Bool
    }

    @Published var toast: Toast?
    private var toastWork: DispatchWorkItem?

    func showToast(_ message: String, isError: Bool) {
        toast = Toast(message: message, isError: isError)
        toastWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.toast = nil }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    // MARK: - Launch at login

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            try LaunchAtLogin.set(enabled)
        } catch {
            launchAtLoginError = L("设置失败：", "Failed: ") + error.localizedDescription
        }
        refreshLaunchAtLogin()
    }

    func refreshLaunchAtLogin() {
        launchAtLoginState = LaunchAtLogin.state
    }

    // MARK: - Accessibility

    private func startAccessibilityPolling() {
        axTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.refreshAccessibility()
        }
    }

    func refreshAccessibility() {
        let trusted = Accessibility.isTrusted
        if trusted != accessibilityTrusted { accessibilityTrusted = trusted }
    }

    func refreshLanguage() {
        Localizer.language = config.settings.language
        objectWillChange.send()
    }
}
