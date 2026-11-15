import SwiftUI
import AppKit
import UniformTypeIdentifiers
import iHotkeyCore

struct GeneralView: View {
    @EnvironmentObject private var state: AppState

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { state.launchAtLoginState == .enabled },
            set: { state.setLaunchAtLogin($0) }
        )
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { state.config.settings.language },
            set: {
                state.config.settings.language = $0
                state.refreshLanguage()
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(title: L("通用", "General"), subtitle: L("启动、外观与权限。", "Startup, appearance and permissions."))
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section(L("启动", "Startup")) {
                        row(L("开机自动启动", "Launch at login"),
                            detail: launchDetail) {
                            Toggle("", isOn: launchBinding).toggleStyle(.switch).labelsHidden()
                        }
                        Divider()
                        row(L("手动启动时显示此窗口", "Show this window when opened manually"),
                            detail: L("开机自启时始终静默在状态栏运行", "Always starts silently in the menu bar at login")) {
                            Toggle("", isOn: $state.config.settings.showWindowOnLaunch).toggleStyle(.switch).labelsHidden()
                        }
                    }

                    section(L("外观", "Appearance")) {
                        row(L("窗口打开时显示程序坞图标", "Show Dock icon while window is open"),
                            detail: L("关闭或最小化窗口后，iHotkey 只保留在状态栏", "Closing or minimizing hides iHotkey to the menu bar")) {
                            Toggle("", isOn: $state.config.settings.showDockIconWhenWindowOpen)
                                .toggleStyle(.switch).labelsHidden()
                                .onChange(of: state.config.settings.showDockIconWhenWindowOpen) { on in
                                    NSApp.setActivationPolicy(on ? .regular : .accessory)
                                    NSApp.activate(ignoringOtherApps: true)
                                }
                        }
                        Divider()
                        row(L("语言", "Language"), detail: nil) {
                            Picker("", selection: languageBinding) {
                                ForEach(AppLanguage.allCases, id: \.self) { Text($0.title).tag($0) }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }

                    section(L("权限", "Permissions")) {
                        row(L("辅助功能", "Accessibility"),
                            detail: L("分屏移动窗口需要；应用快捷键不需要", "Needed for window snap; not for app shortcuts")) {
                            if state.accessibilityTrusted {
                                Label(L("已授权", "Granted"), systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green).font(.system(size: 12))
                            } else {
                                HStack {
                                    Button(L("重置授权", "Reset")) { Accessibility.resetAndRequest() }
                                        .help(L("开关已打开但仍无效时使用", "Use when the switch is on but it still doesn't work"))
                                    Button(L("去授权", "Grant")) {
                                        Accessibility.request()
                                        Accessibility.openSettings()
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            }
                        }
                    }

                    section(L("配置", "Configuration")) {
                        row(L("导入 / 导出配置", "Import / Export"),
                            detail: AppState.configURL.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")) {
                            HStack {
                                Button(L("导入…", "Import…"), action: importConfig)
                                Button(L("导出…", "Export…"), action: exportConfig)
                            }
                        }
                        Divider()
                        row(L("在访达中显示配置文件", "Reveal config in Finder"), detail: nil) {
                            Button(L("显示", "Reveal")) {
                                state.saveNow()
                                NSWorkspace.shared.activateFileViewerSelecting([AppState.configURL])
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private var launchDetail: String? {
        if let e = state.launchAtLoginError { return e }
        if state.launchAtLoginState == .requiresApproval {
            return L("需要在 系统设置 › 登录项 中允许", "Approve it in System Settings › Login Items")
        }
        return nil
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            Card { content() }
        }
    }

    private func row<Trailing: View>(_ title: String, detail: String?, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13))
                if let detail {
                    Text(detail).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 12)
            trailing()
        }
        .padding(12)
    }

    private func importConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try state.importConfig(from: url)
            state.refreshLanguage()
            state.showToast(L("配置已导入", "Configuration imported"), isError: false)
        } catch {
            state.showToast(L("导入失败：不是有效的 iHotkey 配置", "Import failed: not a valid iHotkey config"), isError: true)
        }
    }

    private func exportConfig() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "iHotkey-config.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try state.exportConfig(to: url)
            state.showToast(L("配置已导出", "Configuration exported"), isError: false)
        } catch {
            state.showToast(error.localizedDescription, isError: true)
        }
    }
}

struct AboutView: View {
    private var version: String {
        let v = (Bundle.main.object(forInfoDictionaryKey: "IHReleaseVersion") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "dev"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 96, height: 96)
            Text("iHotkey").font(.system(size: 24, weight: .semibold))
            Text(L("版本 ", "Version ") + version).foregroundColor(.secondary).font(.system(size: 12))
            Text(L("免费、开源的 macOS 快捷键与分屏工具", "A free, open-source hotkey & window snapping tool for macOS"))
                .font(.system(size: 13))
            Text(L("MIT 许可证 · 支持 macOS 12 Monterey 及以上", "MIT License · macOS 12 Monterey and later"))
                .font(.system(size: 11)).foregroundColor(.secondary)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
