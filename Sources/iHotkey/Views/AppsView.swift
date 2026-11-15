import SwiftUI
import AppKit
import UniformTypeIdentifiers
import iHotkeyCore

struct AppsView: View {
    @EnvironmentObject private var state: AppState
    @State private var dropTargeted = false
    @State private var search = ""

    private var filteredIndices: [Int] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        return state.config.apps.indices.filter {
            q.isEmpty || state.config.apps[$0].name.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                title: L("应用快捷键", "App Shortcuts"),
                subtitle: L("为任意应用设置全局快捷键，一键打开、切换或隐藏。", "Open, focus or hide any app with a global shortcut.")
            ) {
                Button {
                    pickApps()
                } label: {
                    Label(L("添加应用", "Add App"), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("n", modifiers: .command)
            }

            if state.config.apps.isEmpty {
                emptyState
            } else {
                if state.config.apps.count > 6 {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                        TextField(L("搜索应用", "Search apps"), text: $search).textFieldStyle(.plain)
                    }
                    .padding(7)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
                }
                ScrollView {
                    Card {
                        ForEach(Array(filteredIndices.enumerated()), id: \.element) { pos, idx in
                            if pos > 0 { Divider().padding(.leading, 56) }
                            AppRow(binding: $state.config.apps[idx]) {
                                let id = state.config.apps[idx].id
                                withAnimation { state.removeApp(id) }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)

                    Text(L("提示：把 .app 拖进窗口即可添加。「显示/隐藏」模式下，在应用已在前台时再按一次会隐藏它。",
                           "Tip: drag .app files here to add. In Show/Hide mode, pressing again while the app is in front hides it."))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 28)
                        .padding(.top, 2)
                        .padding(.bottom, 24)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
                .padding(10)
                .opacity(dropTargeted ? 1 : 0)
        )
        .onDrop(of: [UTType.fileURL], isTargeted: $dropTargeted, perform: handleDrop)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "app.badge.checkmark")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(.secondary)
            Text(L("还没有应用快捷键", "No app shortcuts yet"))
                .font(.system(size: 15, weight: .medium))
            Text(L("点击「添加应用」，或把应用从访达拖到这里", "Click “Add App” or drag apps here from Finder"))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Button(L("添加应用", "Add App")) { pickApps() }
                .controlSize(.large)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func pickApps() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = L("添加", "Add")
        panel.message = L("选择要设置快捷键的应用", "Choose apps to assign shortcuts to")
        if panel.runModal() == .OK {
            withAnimation {
                for url in panel.urls { state.addApp(url: url) }
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for p in providers where p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            handled = true
            p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                var url: URL?
                if let data = item as? Data { url = URL(dataRepresentation: data, relativeTo: nil) }
                else if let u = item as? URL { url = u }
                guard let url, url.pathExtension == "app" else { return }
                DispatchQueue.main.async { withAnimation { state.addApp(url: url) } }
            }
        }
        return handled
    }
}

private struct AppRow: View {
    @Binding var binding: AppBinding
    let onDelete: () -> Void
    @EnvironmentObject private var state: AppState
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            AppIcon(binding: binding)
                .frame(width: 32, height: 32)
                .opacity(binding.enabled ? 1 : 0.4)

            VStack(alignment: .leading, spacing: 2) {
                Text(binding.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(binding.enabled ? .primary : .secondary)
                    .lineLimit(1)
                if let error = errorText {
                    Text(error).font(.system(size: 11)).foregroundColor(.orange).lineLimit(2)
                } else if !AppLauncher.isInstalled(binding) {
                    Text(L("找不到该应用", "App not found")).font(.system(size: 11)).foregroundColor(.orange)
                }
            }

            Spacer(minLength: 8)

            Picker("", selection: $binding.behavior) {
                ForEach(AppHotkeyBehavior.allCases, id: \.self) { b in
                    Text(b.title).tag(b)
                }
            }
            .labelsHidden()
            .frame(width: 128)
            .controlSize(.small)

            ShortcutRecorder(owner: .app(binding.id), combo: $binding.combo)

            Toggle("", isOn: $binding.enabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.mini)
                .help(L("启用/停用", "Enable/disable"))

            Button(action: onDelete) {
                Image(systemName: "trash").foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0.35)
            .help(L("移除", "Remove"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .contextMenu {
            Button(L("立即打开", "Open Now")) { AppLauncher.trigger(binding) }
            if let url = AppLauncher.url(for: binding) {
                Button(L("在访达中显示", "Show in Finder")) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
            Divider()
            Button(L("移除", "Remove"), action: onDelete)
        }
    }

    private var errorText: String? {
        guard binding.enabled, binding.combo != nil else { return nil }
        return state.registrationErrors[.app(binding.id)]
    }
}

struct AppIcon: View {
    let binding: AppBinding
    var body: some View {
        if let icon = AppLauncher.icon(for: binding) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "questionmark.app.dashed")
                .resizable()
                .foregroundColor(.secondary)
        }
    }
}
