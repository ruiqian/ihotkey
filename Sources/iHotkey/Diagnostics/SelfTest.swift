import AppKit
import Carbon
import iHotkeyCore

/// `iHotkey --self-test` : registers every default shortcut with the real
/// system, fires one through the Carbon event path, and prints a report.
/// Does not touch the user's config. Exit code 0 = all good.
enum SelfTest {
    static func runIfRequested() -> Bool {
        if CommandLine.arguments.contains("--self-test-snap") { runSnapTest(); return true }
        guard CommandLine.arguments.contains("--self-test") else { return false }
        var failed = false
        func check(_ ok: Bool, _ msg: String) {
            print((ok ? "PASS " : "FAIL ") + msg)
            if !ok { failed = true }
        }

        print("macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("Accessibility trusted: \(Accessibility.isTrusted)")
        print("Launch at login state: \(LaunchAtLogin.state)")

        // 1. Register every default snap shortcut + a sample app shortcut.
        var fired = false
        var bindings: [HotKeyCenter.Binding] = SnapAction.allCases.compactMap { a in
            a.defaultCombo.map { HotKeyCenter.Binding(owner: .snap(a), combo: $0) {} }
        }
        let probeCombo = KeyCombo(keyCode: KeyCode.k, modifiers: [.control, .option, .command, .shift])
        bindings.append(.init(owner: .app(UUID()), combo: probeCombo) { fired = true })
        let failures = HotKeyCenter.shared.apply(bindings)
        for (owner, reason) in failures { print("  conflict: \(owner) -> \(reason)") }
        check(failures.isEmpty, "registered \(bindings.count - failures.count)/\(bindings.count) global hotkeys")

        // 2. Duplicate detection inside iHotkey.
        let dup = HotKeyCenter.shared.apply([
            .init(owner: .snap(.leftHalf), combo: probeCombo) {},
            .init(owner: .snap(.rightHalf), combo: probeCombo) {},
        ])
        check(dup.count == 1 && dup[.snap(.rightHalf)] != nil, "duplicate combo rejected")

        // 3. Fire the probe hotkey through the real Carbon dispatcher.
        HotKeyCenter.shared.apply(bindings)
        if let target = GetApplicationEventTarget(),
           let ev = makeHotKeyEvent(id: UInt32(bindings.count)) {
            SendEventToEventTarget(ev, target)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        check(fired, "hotkey event dispatched to handler")

        // 4. App resolution for a system app.
        let notes = AppLauncher.makeBinding(from: URL(fileURLWithPath: "/System/Applications/TextEdit.app"))
        check(notes?.bundleIdentifier == "com.apple.TextEdit", "app bundle parsed (\(notes?.name ?? "nil"))")
        check(notes.map(AppLauncher.isInstalled) == true, "app path resolved")

        // 5. Config round-trip.
        let cfg = AppConfig()
        check((try? AppConfig.decode(cfg.encoded())) == cfg, "config round-trip")

        // 6. Optional: really toggle launch-at-login, then restore the original state.
        if CommandLine.arguments.contains("--login-item") {
            let original = LaunchAtLogin.state
            do {
                try LaunchAtLogin.set(true)
                let on = LaunchAtLogin.state
                check(on == .enabled || on == .requiresApproval, "launch at login enabled (state: \(on))")
                try LaunchAtLogin.set(false)
                check(LaunchAtLogin.state == .disabled, "launch at login disabled again")
                if original == .enabled { try LaunchAtLogin.set(true) }
            } catch {
                check(false, "launch at login error: \(error)")
            }
        }

        HotKeyCenter.shared.unregisterAll()
        print(failed ? "SELF-TEST FAILED" : "SELF-TEST OK")
        exit(failed ? 1 : 0)
    }

    /// Real end-to-end window snap against TextEdit. Must be started via
    /// `open iHotkey.app --args --self-test-snap <report-file>` so that macOS
    /// attributes the Accessibility check to iHotkey rather than the terminal.
    private static func runSnapTest() {
        let args = CommandLine.arguments
        let reportPath = args.firstIndex(of: "--self-test-snap").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        var lines: [String] = []
        var failed = false
        func log(_ s: String) { lines.append(s); print(s) }
        func check(_ ok: Bool, _ msg: String) { log((ok ? "PASS " : "FAIL ") + msg); if !ok { failed = true } }
        func finish() {
            log(failed ? "SNAP-TEST FAILED" : "SNAP-TEST OK")
            if let reportPath { try? lines.joined(separator: "\n").write(toFile: reportPath, atomically: true, encoding: .utf8) }
            exit(failed ? 1 : 0)
        }

        log("bundle: \(Bundle.main.bundlePath)")
        let trusted = Accessibility.isTrusted
        check(trusted, "AXIsProcessTrusted")
        guard trusted else { finish(); return }

        // Open a scratch TextEdit document and bring it to front.
        let doc = FileManager.default.temporaryDirectory.appendingPathComponent("ihotkey-snap-test.txt")
        try? "iHotkey snap test".write(to: doc, atomically: true, encoding: .utf8)
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        let textEdit = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        NSWorkspace.shared.open([doc], withApplicationAt: textEdit, configuration: cfg) { _, _ in }

        func step(_ delay: Double, _ body: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: body)
        }
        step(2.5) {
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first?
                .activate(options: [])
            step(0.8) {
                let wm = WindowManager.shared
                log("target app: \(wm.targetApp()?.localizedName ?? "nil")")
                guard let screen = NSScreen.screens.first(where: {
                    wm.targetWindowFrame().map($0.frame.intersects) ?? false
                }) ?? NSScreen.main else { check(false, "screen"); finish(); return }
                let visible = screen.visibleFrame
                let before = wm.targetWindowFrame()
                check(before != nil, "read focused window frame \(before.map { "\($0)" } ?? "")")

                for action in [SnapAction.leftHalf, .rightHalf, .topLeft, .maximize, .center, .restore] {
                    let outcome = wm.perform(action, gap: 0, cycle: false)
                    usleep(300_000)
                    let now = wm.targetWindowFrame() ?? .zero
                    var ok = outcome == .moved
                    if let unit = action.unitRect {
                        let expected = SnapGeometry.rect(forUnit: unit, in: visible)
                        ok = ok && SnapGeometry.approximatelyEqual(now, expected, tolerance: 4)
                    }
                    if action == .restore, let before {
                        ok = ok && SnapGeometry.approximatelyEqual(now, before, tolerance: 4)
                    }
                    check(ok, "\(action.rawValue) -> \(outcome) frame \(now.integral)")
                }
                finish()
            }
        }
    }

    private static func makeHotKeyEvent(id: UInt32) -> EventRef? {
        var event: EventRef?
        guard CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed),
                          GetCurrentEventTime(), EventAttributes(kEventAttributeNone), &event) == noErr,
              let event else { return nil }
        var hk = EventHotKeyID(signature: 0x4948_4B59, id: id)
        SetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                          MemoryLayout<EventHotKeyID>.size, &hk)
        return event
    }
}
