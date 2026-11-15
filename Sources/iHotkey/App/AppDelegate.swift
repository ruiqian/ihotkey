import AppKit
import SwiftUI
import Combine
import iHotkeyCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private let state = AppState.shared
    private var statusItem: NSStatusItem!
    private var window: MainWindow?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ScreenshotRenderer.runIfRequested() { return }
        if SelfTest.runIfRequested() { return }
        if activateExistingInstance() { return }

        NSApp.setActivationPolicy(.accessory)
        buildMainMenu()
        setupStatusItem()
        state.applyHotkeys()
        LaunchAtLogin.refreshAgentIfNeeded()

        // Rebuild menus when the language changes.
        state.$config
            .map(\.settings.language)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.buildMainMenu()
                    self?.window?.title = "iHotkey"
                }
            }
            .store(in: &cancellables)

        let fromLogin = LaunchAtLogin.wasLaunchedAtLogin
        if state.isFirstRun || (!fromLogin && state.config.settings.showWindowOnLaunch) {
            showMainWindow()
        }
        if CommandLine.arguments.contains("--self-test-ui") { runUISelfTest() }
    }

    /// Drives the real window lifecycle: show → close → minimize → reopen.
    private func runUISelfTest() {
        var failed = false
        func check(_ ok: Bool, _ msg: String) { print((ok ? "PASS " : "FAIL ") + msg); if !ok { failed = true } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
            showMainWindow()
            check(window?.isVisible == true, "window shown")
            check(NSApp.activationPolicy() == .regular, "Dock icon visible while window open")
            check(statusItem?.button?.image != nil, "status bar item present")

            window?.performClose(nil)
            check(window?.isVisible == false, "close button hides window")
            check(NSApp.activationPolicy() == .accessory, "Dock icon removed after close (menu bar only)")

            showMainWindow()
            window?.miniaturize(nil)
            check(window?.isVisible == false && window?.isMiniaturized == false, "minimize goes to menu bar, not Dock")
            check(NSApp.activationPolicy() == .accessory, "Dock icon removed after minimize")

            let menu = statusItem.menu!
            menuNeedsUpdate(menu)
            let titles = menu.items.map(\.title)
            check(titles.contains(L("打开设置…", "Open Settings…")), "status menu has Open Settings")
            check(menu.items.contains { $0.submenu?.items.count ?? 0 >= SnapAction.allCases.count }, "status menu lists all snap actions")

            _ = applicationShouldHandleReopen(NSApp, hasVisibleWindows: false)
            check(window?.isVisible == true, "Dock/Finder reopen shows window")
            print(failed ? "UI SELF-TEST FAILED" : "UI SELF-TEST OK")
            exit(failed ? 1 : 0)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        state.saveNow()
        HotKeyCenter.shared.unregisterAll()
    }

    /// Only one iHotkey may own the hotkeys. If another copy is running, focus it.
    private func activateExistingInstance() -> Bool {
        guard let bid = Bundle.main.bundleIdentifier else { return false }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bid)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        guard let other = others.first else { return false }
        if let url = other.bundleURL {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        NSApp.terminate(nil)
        return true
    }

    // MARK: - Main window

    @objc func showMainWindow() {
        if window == nil {
            let w = MainWindow(
                contentRect: NSRect(x: 0, y: 0, width: 780, height: 540),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            w.title = "iHotkey"
            w.titleVisibility = .hidden
            w.titlebarAppearsTransparent = true
            w.isReleasedWhenClosed = false
            w.minSize = NSSize(width: 720, height: 480)
            w.contentView = NSHostingView(rootView: MainView().environmentObject(state))
            w.delegate = self
            w.center()
            w.setFrameAutosaveName("iHotkeyMainWindow")
            w.onMinimizeToMenuBar = { [weak self] in self?.hideToMenuBar() }
            window = w
        }
        if state.config.settings.showDockIconWhenWindowOpen {
            NSApp.setActivationPolicy(.regular)
        }
        state.refreshAccessibility()
        state.refreshLaunchAtLogin()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideToMenuBar() {
        window?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Closing never quits: iHotkey keeps running in the menu bar.
        hideToMenuBar()
        return false
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "command.square", accessibilityDescription: "iHotkey")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "iHotkey"
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateStatusIcon()
        state.$config.map(\.settings.hotkeysEnabled).removeDuplicates()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.updateStatusIcon() } }
            .store(in: &cancellables)
    }

    private func updateStatusIcon() {
        statusItem?.button?.appearsDisabled = !state.config.settings.hotkeysEnabled
    }

    /// The menu is rebuilt each time it opens so it always reflects the config.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let cfg = state.config

        let header = NSMenuItem(title: "iHotkey", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        if !state.accessibilityTrusted {
            let ax = NSMenuItem(title: "⚠️ " + L("分屏需要辅助功能权限…", "Window snap needs Accessibility…"),
                                action: #selector(openAccessibility), keyEquivalent: "")
            ax.target = self
            menu.addItem(ax)
        }

        let toggle = NSMenuItem(title: L("启用快捷键", "Enable Shortcuts"),
                                action: #selector(toggleHotkeys), keyEquivalent: "")
        toggle.target = self
        toggle.state = cfg.settings.hotkeysEnabled ? .on : .off
        menu.addItem(toggle)
        menu.addItem(.separator())

        // Window snap submenu: clicking applies to the frontmost window.
        let snapItem = NSMenuItem(title: L("分屏", "Window Snap"), action: nil, keyEquivalent: "")
        let snapMenu = NSMenu()
        for group in SnapAction.Group.allCases {
            if snapMenu.numberOfItems > 0 { snapMenu.addItem(.separator()) }
            for action in group.actions {
                let item = NSMenuItem(title: action.title, action: #selector(runSnap(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = action.rawValue
                if let combo = cfg.combo(for: action) { applyKeyEquivalent(combo, to: item) }
                snapMenu.addItem(item)
            }
        }
        snapItem.submenu = snapMenu
        menu.addItem(snapItem)

        // App shortcut submenu
        let appsItem = NSMenuItem(title: L("应用快捷键", "App Shortcuts"), action: nil, keyEquivalent: "")
        let appsMenu = NSMenu()
        let bound = cfg.apps.filter(\.enabled)
        if bound.isEmpty {
            let empty = NSMenuItem(title: L("尚未添加应用", "No apps yet"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            appsMenu.addItem(empty)
        }
        for app in bound {
            let item = NSMenuItem(title: app.name, action: #selector(runApp(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = app.id.uuidString
            if let original = AppLauncher.icon(for: app), let icon = original.copy() as? NSImage {
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
            }
            if let combo = app.combo { applyKeyEquivalent(combo, to: item) }
            appsMenu.addItem(item)
        }
        appsItem.submenu = appsMenu
        menu.addItem(appsItem)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: L("打开设置…", "Open Settings…"), action: #selector(showMainWindow), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let login = NSMenuItem(title: L("开机自动启动", "Launch at Login"), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = state.launchAtLoginState == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: L("退出 iHotkey", "Quit iHotkey"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    func menuWillOpen(_ menu: NSMenu) {
        state.refreshLaunchAtLogin()
        state.refreshAccessibility()
    }

    /// Shows the shortcut on the right side of a menu item (display only).
    private func applyKeyEquivalent(_ combo: KeyCombo, to item: NSMenuItem) {
        guard let key = MenuKeyEquivalent.string(for: combo.keyCode) else { return }
        item.keyEquivalent = key
        var mask: NSEvent.ModifierFlags = []
        if combo.modifiers.contains(.command) { mask.insert(.command) }
        if combo.modifiers.contains(.option) { mask.insert(.option) }
        if combo.modifiers.contains(.control) { mask.insert(.control) }
        if combo.modifiers.contains(.shift) { mask.insert(.shift) }
        item.keyEquivalentModifierMask = mask
    }

    @objc private func runSnap(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let action = SnapAction(rawValue: raw) else { return }
        // Let the menu close and focus return to the target window first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.state.performSnap(action) }
    }

    @objc private func runApp(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let app = state.config.apps.first(where: { $0.id.uuidString == raw }) else { return }
        AppLauncher.trigger(app)
    }

    @objc private func toggleHotkeys() {
        state.config.settings.hotkeysEnabled.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        state.setLaunchAtLogin(state.launchAtLoginState != .enabled)
    }

    @objc private func openAccessibility() {
        Accessibility.request()
        Accessibility.openSettings()
    }

    // MARK: - Main menu (when the window is open)

    private func buildMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L("关于 iHotkey", "About iHotkey"), action: #selector(showAbout), keyEquivalent: "").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("设置…", "Settings…"), action: #selector(showMainWindow), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("隐藏到状态栏", "Hide to Menu Bar"), action: #selector(hideToMenuBarAction), keyEquivalent: "h").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("退出 iHotkey", "Quit iHotkey"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: L("编辑", "Edit"))
        editMenu.addItem(withTitle: L("撤销", "Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: L("重做", "Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L("剪切", "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L("拷贝", "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L("粘贴", "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L("全选", "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: L("窗口", "Window"))
        windowMenu.addItem(withTitle: L("最小化到状态栏", "Minimize to Menu Bar"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: L("关闭", "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        NSApp.mainMenu = main
    }

    @objc private func hideToMenuBarAction() { hideToMenuBar() }

    @objc private func showAbout() {
        state.selectedTab = .about
        showMainWindow()
    }
}

/// The settings window. The yellow "minimize" button hides to the menu bar
/// instead of the Dock.
final class MainWindow: NSWindow {
    var onMinimizeToMenuBar: (() -> Void)?

    override func miniaturize(_ sender: Any?) {
        if let onMinimizeToMenuBar { onMinimizeToMenuBar() } else { super.miniaturize(sender) }
    }

    override func performMiniaturize(_ sender: Any?) {
        miniaturize(sender)
    }
}

enum MenuKeyEquivalent {
    static func string(for keyCode: UInt16) -> String? {
        func scalar(_ v: Int) -> String { String(Character(UnicodeScalar(v)!)) }
        switch keyCode {
        case KeyCode.leftArrow: return scalar(NSLeftArrowFunctionKey)
        case KeyCode.rightArrow: return scalar(NSRightArrowFunctionKey)
        case KeyCode.upArrow: return scalar(NSUpArrowFunctionKey)
        case KeyCode.downArrow: return scalar(NSDownArrowFunctionKey)
        case KeyCode.returnKey: return "\r"
        case KeyCode.delete: return scalar(0x08)
        case KeyCode.forwardDelete: return scalar(NSDeleteFunctionKey)
        case KeyCode.tab: return "\t"
        case KeyCode.space: return " "
        case KeyCode.escape: return scalar(0x1B)
        case KeyCode.home: return scalar(NSHomeFunctionKey)
        case KeyCode.end: return scalar(NSEndFunctionKey)
        case KeyCode.pageUp: return scalar(NSPageUpFunctionKey)
        case KeyCode.pageDown: return scalar(NSPageDownFunctionKey)
        default:
            if let n = KeyNames.functionKeys[keyCode] { return scalar(NSF1FunctionKey + n - 1) }
            let name = KeyNames.name(for: keyCode)
            return name.count == 1 ? name.lowercased() : nil
        }
    }
}
