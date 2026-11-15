import AppKit
import Carbon
import KeyPilotCore

/// `KeyPilot --self-test` : registers every default shortcut with the real
/// system, fires one through the Carbon event path, and prints a report.
/// Does not touch the user's config. Exit code 0 = all good.
enum SelfTest {
    static func runIfRequested() -> Bool {
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

        // 2. Duplicate detection inside KeyPilot.
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

    private static func makeHotKeyEvent(id: UInt32) -> EventRef? {
        var event: EventRef?
        guard CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed),
                          GetCurrentEventTime(), EventAttributes(kEventAttributeNone), &event) == noErr,
              let event else { return nil }
        var hk = EventHotKeyID(signature: 0x4B50_4C54, id: id)
        SetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                          MemoryLayout<EventHotKeyID>.size, &hk)
        return event
    }
}
