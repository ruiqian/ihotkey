import SwiftUI
import AppKit
import iHotkeyCore

struct SnapView: View {
    @EnvironmentObject private var state: AppState
    @State private var confirmReset = false

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                title: L("分屏", "Window Snap"),
                subtitle: L("用快捷键把当前窗口放到屏幕的指定位置。点击图标可直接试用。", "Move the focused window into place with a shortcut. Click a glyph to try it.")
            ) {
                Button(L("恢复默认", "Reset Defaults")) { confirmReset = true }
                    .alert(L("恢复默认分屏快捷键？", "Reset snap shortcuts?"), isPresented: $confirmReset) {
                        Button(L("恢复", "Reset"), role: .destructive) {
                            state.resetSnapDefaults()
                            state.showToast(L("已恢复默认分屏快捷键", "Snap shortcuts reset"), isError: false)
                        }
                        Button(L("取消", "Cancel"), role: .cancel) {}
                    } message: {
                        Text(L("只影响分屏快捷键，应用快捷键不变。", "Only window snap shortcuts are affected."))
                    }
            }

            if !state.accessibilityTrusted {
                AccessibilityHelpBanner()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(SnapAction.Group.allCases, id: \.self) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .padding(.leading, 4)
                            Card {
                                ForEach(Array(group.actions.enumerated()), id: \.element) { i, action in
                                    if i > 0 { Divider().padding(.leading, 60) }
                                    SnapRow(action: action)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("选项", "Options"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.leading, 4)
                        Card {
                            HStack {
                                Text(L("窗口间距", "Gap between windows"))
                                Spacer()
                                Slider(value: $state.config.settings.snapGap, in: 0...30, step: 2)
                                    .frame(width: 180)
                                Text("\(Int(state.config.settings.snapGap)) pt")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 44, alignment: .trailing)
                            }
                            .padding(12)
                            Divider()
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L("重复按下半屏键时循环尺寸", "Cycle sizes on repeated half presses"))
                                    Text(L("1/2 → 2/3 → 1/3", "1/2 → 2/3 → 1/3"))
                                        .font(.system(size: 11)).foregroundColor(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: $state.config.settings.cycleHalves)
                                    .toggleStyle(.switch).labelsHidden()
                            }
                            .padding(12)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct SnapRow: View {
    let action: SnapAction
    @EnvironmentObject private var state: AppState
    @State private var glyphHover = false

    private var combo: Binding<KeyCombo?> {
        Binding(
            get: { state.config.combo(for: action) },
            set: { state.config.setCombo($0, for: action) }
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                // Hide our window so the action applies to the window behind it.
                (NSApp.delegate as? AppDelegate)?.hideToMenuBar()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { state.performSnap(action) }
            } label: {
                SnapGlyph(action: action)
                    .frame(width: 36, height: 24)
                    .padding(3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(glyphHover ? 0.12 : 0)))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { glyphHover = $0 }
            .help(L("点击：对后面的窗口试用", "Click to try on the window behind"))

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title).font(.system(size: 13))
                if let err = errorText {
                    Text(err).font(.system(size: 11)).foregroundColor(.orange).lineLimit(2)
                }
            }
            Spacer()
            ShortcutRecorder(owner: .snap(action), combo: combo)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private var errorText: String? {
        guard state.config.combo(for: action) != nil else { return nil }
        return state.registrationErrors[.snap(action)]
    }
}

/// A small screen illustration showing where the window lands.
struct SnapGlyph: View {
    let action: SnapAction

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.secondary.opacity(0.6), lineWidth: 1)
                region(in: size)
            }
        }
    }

    @ViewBuilder
    private func region(in size: CGSize) -> some View {
        let inset: CGFloat = 2.5
        let w = size.width - inset * 2
        let h = size.height - inset * 2
        if let u = action.unitRect {
            // Exact proportions; a hairline gap only on edges that touch another region.
            let gapL: CGFloat = u.minX > 0.001 ? 0.75 : 0
            let gapR: CGFloat = u.maxX < 0.999 ? 0.75 : 0
            let gapT: CGFloat = u.minY > 0.001 ? 0.75 : 0
            let gapB: CGFloat = u.maxY < 0.999 ? 0.75 : 0
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.accentColor)
                .frame(width: u.width * w - gapL - gapR, height: u.height * h - gapT - gapB)
                .offset(x: inset + u.minX * w + gapL, y: inset + u.minY * h + gapT)
        } else {
            switch action {
            case .center:
                RoundedRectangle(cornerRadius: 1.5).fill(Color.accentColor)
                    .frame(width: w * 0.5, height: h * 0.6)
                    .offset(x: inset + w * 0.25, y: inset + h * 0.2)
            case .maximizeHeight:
                RoundedRectangle(cornerRadius: 1.5).fill(Color.accentColor)
                    .frame(width: w * 0.4, height: h)
                    .offset(x: inset + w * 0.3, y: inset)
            case .restore:
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: size.width, height: size.height)
            case .nextDisplay:
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: size.width, height: size.height)
            case .previousDisplay:
                Image(systemName: "arrow.left")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: size.width, height: size.height)
            default:
                EmptyView()
            }
        }
    }
}
