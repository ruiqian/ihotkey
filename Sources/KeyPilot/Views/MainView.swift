import SwiftUI
import AppKit
import KeyPilotCore

struct MainView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: 190)
            Divider()
            ZStack(alignment: .bottom) {
                Group {
                    switch state.selectedTab {
                    case .apps: AppsView()
                    case .snap: SnapView()
                    case .general: GeneralView()
                    case .about: AboutView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if let toast = state.toast {
                    ToastView(toast: toast)
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .id(toast.id)
                }
            }
            .animation(.easeOut(duration: 0.2), value: state.toast)
        }
        .frame(minWidth: 720, minHeight: 480)
        .ignoresSafeArea(.container, edges: .top)
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "command.square.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.accentColor)
                Text("KeyPilot")
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.top, 44)
            .padding(.bottom, 18)

            ForEach(SidebarTab.allCases) { tab in
                SidebarRow(tab: tab, selected: state.selectedTab == tab) {
                    state.selectedTab = tab
                }
            }

            Spacer()

            // Master switch
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $state.config.settings.hotkeysEnabled) {
                    Text(L("启用全部快捷键", "Shortcuts enabled"))
                        .font(.system(size: 12))
                }
                .toggleStyle(.switch)
                .controlSize(.small)

                if !state.accessibilityTrusted {
                    Button {
                        Accessibility.request()
                        Accessibility.openSettings()
                    } label: {
                        Label(L("分屏需授权 ›", "Grant access ›"), systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .help(L("打开系统设置授予辅助功能权限", "Open System Settings to grant Accessibility"))
                }
            }
            .padding(14)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(VisualEffect(material: .sidebar))
    }
}

private struct SidebarRow: View {
    let tab: SidebarTab
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.symbol)
                    .frame(width: 18)
                    .foregroundColor(selected ? .white : .accentColor)
                Text(tab.title)
                    .foregroundColor(selected ? .white : .primary)
                Spacer()
            }
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(selected ? Color.accentColor : Color.primary.opacity(hovering ? 0.06 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .padding(.horizontal, 8)
    }
}

// MARK: - Shared pieces

struct PageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 20, weight: .semibold))
                Text(subtitle).font(.system(size: 12)).foregroundColor(.secondary)
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, 24)
        .padding(.top, 36)
        .padding(.bottom, 14)
    }
}

extension PageHeader where Trailing == EmptyView {
    init(title: String, subtitle: String) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
    }
}

struct ToastView: View {
    let toast: AppState.Toast
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(toast.isError ? .orange : .green)
            Text(toast.message).font(.system(size: 12))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(VisualEffect(material: .hudWindow).clipShape(Capsule()))
        .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    }
}

struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .followsWindowActiveState
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) { v.material = material }
}

struct WarningBanner: View {
    let text: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
            Text(text)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
    }
}
