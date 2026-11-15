import AppKit
import SwiftUI
import KeyPilotCore

/// `KeyPilot --render-screenshots <dir> [--lang zh|en] [--dark]`
/// Renders every settings tab to PNG files using the app's own views, then exits.
/// Used for README screenshots and visual checks; needs no Screen Recording permission.
enum ScreenshotRenderer {
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--render-screenshots"), i + 1 < args.count else { return false }
        let dir = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let state = AppState.shared
        if let li = args.firstIndex(of: "--lang"), li + 1 < args.count {
            Localizer.language = AppLanguage(rawValue: args[li + 1]) ?? .system
        }
        let dark = args.contains("--dark")
        NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)

        // Sample data, never saved: assigning to config would schedule a save,
        // so we swap in a demo copy and disable persistence by exiting before it fires.
        var demo = AppConfig()
        demo.settings.language = Localizer.language
        let samples = ["/System/Applications/Notes.app", "/Applications/Safari.app",
                       "/System/Applications/Utilities/Terminal.app", "/System/Applications/Calendar.app"]
        let keys: [UInt16] = [KeyCode.n, KeyCode.s, KeyCode.t, KeyCode.c]
        for (p, k) in zip(samples, keys) {
            let url = URL(fileURLWithPath: p)
            guard FileManager.default.fileExists(atPath: p), var b = AppLauncher.makeBinding(from: url) else { continue }
            b.combo = KeyCombo(keyCode: k, modifiers: [.control, .command])
            demo.apps.append(b)
        }
        if demo.apps.count > 3 { demo.apps[3].behavior = .launchOrFocus }
        state.replaceConfigWithoutSaving(demo)

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        let host = NSHostingView(rootView: MainView().environmentObject(state))
        window.contentView = host
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.orderFrontRegardless()

        var tabs = SidebarTab.allCases
        func next() {
            guard !tabs.isEmpty else { exit(0) }
            let tab = tabs.removeFirst()
            state.selectedTab = tab
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                // Render the whole window frame (including the traffic lights).
                let view = window.contentView!.superview ?? window.contentView!
                view.layoutSubtreeIfNeeded()
                guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: rep)
                let name = "\(tab.rawValue)\(dark ? "-dark" : "").png"
                try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent(name))
                print("rendered \(name)")
                next()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: next)
        return true
    }
}
