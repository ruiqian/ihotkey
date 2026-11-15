import SwiftUI
import AppKit
import iHotkeyCore

/// Explains the Accessibility grant and fixes the common "switch is ON but it
/// still doesn't work" case (stale grant bound to an older code signature).
struct AccessibilityHelpBanner: View {
    @EnvironmentObject private var state: AppState
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("分屏需要「辅助功能」权限", "Window snap needs Accessibility permission"))
                        .font(.system(size: 12, weight: .semibold))
                    Text(L("在 系统设置 › 隐私与安全性 › 辅助功能 中打开 iHotkey 的开关。授权后这里会自动消失。",
                           "Turn on iHotkey in System Settings › Privacy & Security › Accessibility. This banner disappears once granted."))
                        .font(.system(size: 12))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(L("去授权", "Grant")) {
                    Accessibility.request()
                    Accessibility.openSettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Button {
                withAnimation { expanded.toggle() }
            } label: {
                Label(L("已经打开了开关，还是不行？", "Already switched on but it still doesn't work?"),
                      systemImage: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("macOS 把权限绑定在应用的签名上。iHotkey 被更新、重新编译或换了位置后，旧的授权记录会失效，但设置里的开关仍显示为打开。点下面的按钮会清除旧记录并重新申请，然后在弹出的系统设置里重新打开 iHotkey 的开关即可。",
                           "macOS ties the permission to the app's signature. After iHotkey is updated, rebuilt or moved, the old grant stops matching while the switch still shows ON. The button below clears the stale entry and asks again — then switch iHotkey on in System Settings."))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button(L("重置并重新授权", "Reset & Grant Again")) {
                            Accessibility.resetAndRequest()
                        }
                        .controlSize(.small)
                        Button(L("重启 iHotkey", "Relaunch iHotkey")) { Relauncher.relaunch() }
                            .controlSize(.small)
                    }
                }
                .padding(.leading, 26)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
    }
}

enum Relauncher {
    static func relaunch() {
        let path = Bundle.main.bundlePath
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        // Wait for this process to exit, then open the bundle again.
        p.arguments = ["-c", "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"\(path)\""]
        try? p.run()
        NSApp.terminate(nil)
    }
}
