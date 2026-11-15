import AppKit
import Carbon
import iHotkeyCore

/// System-wide hotkeys via Carbon `RegisterEventHotKey`.
/// This API does NOT require Accessibility permission and works on macOS 12+.
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    struct Binding {
        let owner: HotkeyOwner
        let combo: KeyCombo
        let handler: () -> Void
    }

    private var refs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var eventHandler: EventHandlerRef?
    private let signature: OSType = 0x4948_4B59 // 'IHKY'

    private init() {
        installHandler()
    }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return status }
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            return center.fire(hotKeyID.id) ? noErr : OSStatus(eventNotHandledErr)
        }, 1, &spec, selfPtr, &eventHandler)
    }

    private func fire(_ id: UInt32) -> Bool {
        guard let handler = handlers[id] else { return false }
        DispatchQueue.main.async(execute: handler)
        return true
    }

    /// Replace every registered hotkey with `bindings`.
    /// Returns owners whose registration failed, with a reason.
    @discardableResult
    func apply(_ bindings: [Binding]) -> [HotkeyOwner: String] {
        unregisterAll()
        var failures: [HotkeyOwner: String] = [:]
        var seen = Set<KeyCombo>()
        var nextID: UInt32 = 1

        for b in bindings {
            if seen.contains(b.combo) {
                failures[b.owner] = L("与 iHotkey 内其他快捷键重复", "Duplicate of another iHotkey shortcut")
                continue
            }
            if let reason = HotKeyCenter.osRestriction(for: b.combo) {
                failures[b.owner] = reason
                continue
            }
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: signature, id: nextID)
            let status = RegisterEventHotKey(
                UInt32(b.combo.keyCode),
                b.combo.modifiers.carbonFlags,
                id,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if status == noErr, let ref {
                refs[nextID] = ref
                handlers[nextID] = b.handler
                seen.insert(b.combo)
                nextID += 1
            } else if status == OSStatus(eventHotKeyExistsErr) {
                failures[b.owner] = L("已被其他应用占用", "Already taken by another app")
            } else {
                failures[b.owner] = L("注册失败（\(status)）", "Registration failed (\(status))")
            }
        }
        return failures
    }

    func unregisterAll() {
        for (_, ref) in refs { UnregisterEventHotKey(ref) }
        refs.removeAll()
        handlers.removeAll()
    }

    /// macOS 15 Sequoia rejects global hotkeys whose only modifiers are ⌥ or ⌥⇧.
    static func osRestriction(for combo: KeyCombo) -> String? {
        if #available(macOS 15, *) {
            let mods = combo.modifiers
            let optionOnly = mods.contains(.option) && mods.subtracting([.option, .shift]).isEmpty
            if optionOnly && !KeyNames.isFunctionKey(combo.keyCode) {
                return L("macOS 15 起不允许仅用 ⌥ 或 ⌥⇧ 作全局快捷键，请加上 ⌘ 或 ⌃",
                         "macOS 15+ does not allow ⌥ / ⌥⇧-only global shortcuts. Add ⌘ or ⌃")
            }
        }
        return nil
    }
}
