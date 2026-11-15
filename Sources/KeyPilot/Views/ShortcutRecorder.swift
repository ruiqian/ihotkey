import SwiftUI
import AppKit
import KeyPilotCore

/// Click to record a global shortcut.
/// While recording: press a combo to set it, ⎋ to cancel, ⌫ to clear.
struct ShortcutRecorder: View {
    let owner: HotkeyOwner
    @Binding var combo: KeyCombo?
    @EnvironmentObject private var state: AppState

    @State private var recording = false
    @State private var liveModifiers: KeyModifiers = []
    @State private var monitor: Any?
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 4) {
            Button(action: toggle) {
                Text(label)
                    .font(.system(size: 12, weight: combo == nil && !recording ? .regular : .medium, design: .rounded))
                    .foregroundColor(textColor)
                    .frame(minWidth: 96)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(recording ? Color.accentColor.opacity(0.12) : Color.primary.opacity(hovering ? 0.08 : 0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(recording ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: recording ? 1.5 : 0.5)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .help(recording
                  ? L("按下快捷键；⎋ 取消，⌫ 清除", "Press a shortcut; ⎋ cancel, ⌫ clear")
                  : L("点击录制快捷键", "Click to record a shortcut"))

            Button {
                combo = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
            .opacity(combo != nil && !recording ? 1 : 0)
            .disabled(combo == nil || recording)
            .help(L("清除快捷键", "Clear shortcut"))
        }
        .onAppear {
            if state.pendingRecordOwner == owner {
                state.pendingRecordOwner = nil
                DispatchQueue.main.async { start() }
            }
        }
        .onDisappear { stop() }
    }

    private var label: String {
        if recording {
            return liveModifiers.isEmpty ? L("请按快捷键…", "Type shortcut…") : liveModifiers.symbols + "…"
        }
        return combo?.displayString ?? L("点击设置", "Record")
    }

    private var textColor: Color {
        if recording { return .accentColor }
        return combo == nil ? .secondary : .primary
    }

    private func toggle() { recording ? stop() : start() }

    private func start() {
        guard !recording else { return }
        NotificationCenter.default.post(name: .keyPilotRecorderWillStart, object: nil)
        recording = true
        liveModifiers = []
        state.beginRecording()
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged, .leftMouseDown]) { event in
            handle(event)
        }
        stopObserver = NotificationCenter.default.addObserver(forName: .keyPilotRecorderWillStart, object: nil, queue: .main) { _ in
            stop()
        }
    }

    @State private var stopObserver: NSObjectProtocol?

    private func stop() {
        guard recording else { return }
        recording = false
        liveModifiers = []
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if let stopObserver { NotificationCenter.default.removeObserver(stopObserver) }
        stopObserver = nil
        state.endRecording()
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        switch event.type {
        case .leftMouseDown:
            // Clicking anywhere else cancels recording.
            DispatchQueue.main.async { stop() }
            return event
        case .flagsChanged:
            liveModifiers = KeyModifiers(event.modifierFlags)
            return nil
        case .keyDown:
            let mods = KeyModifiers(event.modifierFlags)
            if mods.isEmpty && event.keyCode == KeyCode.escape { stop(); return nil }
            if mods.isEmpty && (event.keyCode == KeyCode.delete || event.keyCode == KeyCode.forwardDelete) {
                combo = nil
                stop()
                return nil
            }
            let candidate = KeyCombo(keyCode: event.keyCode, modifiers: mods)
            if let problem = validate(candidate) {
                state.showToast(problem, isError: true)
                NSSound.beep()
                return nil
            }
            if let other = ConflictDetector.owner(of: candidate, in: state.config, excluding: owner) {
                state.clearCombo(for: other.owner)
                state.showToast(L("已从「\(other.title)」移除 \(candidate.displayString)",
                                  "Moved \(candidate.displayString) from “\(other.title)”"), isError: false)
            }
            combo = candidate
            stop()
            return nil
        default:
            return event
        }
    }

    private func validate(_ c: KeyCombo) -> String? {
        if !c.isValidGlobalHotKey {
            return L("快捷键需包含 ⌘、⌃ 或 ⌥ 之一（F1–F20 除外）", "Shortcut needs ⌘, ⌃ or ⌥ (except F1–F20)")
        }
        if let reserved = c.systemReservedName {
            return L("\(c.displayString) 是系统快捷键（\(reserved)），请换一个", "\(c.displayString) is a system shortcut (\(reserved))")
        }
        return HotKeyCenter.osRestriction(for: c)
    }
}

extension Notification.Name {
    static let keyPilotRecorderWillStart = Notification.Name("KeyPilotRecorderWillStart")
}

extension KeyModifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        var m: KeyModifiers = []
        if flags.contains(.command) { m.insert(.command) }
        if flags.contains(.option) { m.insert(.option) }
        if flags.contains(.control) { m.insert(.control) }
        if flags.contains(.shift) { m.insert(.shift) }
        self = m
    }
}
