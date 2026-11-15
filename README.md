# KeyPilot

**English** | [简体中文](#简体中文)

KeyPilot is a free, open-source macOS menu bar app for two things:

1. **App shortcuts.** Assign a global hotkey to any app: press it to open or focus the app, press again to hide it.
2. **Window snapping.** Move the focused window into halves, quarters, thirds or the center, maximize it, or send it to another display, all from the keyboard.

- Native Swift + SwiftUI, around 1 MB, no Electron, no telemetry, no network access
- Runs in the menu bar. Closing or minimizing the window hides it there.
- Launch at login (SMAppService on macOS 13+, LaunchAgent on macOS 12)
- macOS 12 Monterey and later, universal binary (Apple Silicon + Intel)
- Chinese and English UI

## Install

Download `KeyPilot-x.y.z.dmg` from Releases and drag KeyPilot into Applications.

The release build is ad-hoc signed, not notarized. The first time you open it, **right-click KeyPilot.app → Open**, or run:

```bash
xattr -dr com.apple.quarantine /Applications/KeyPilot.app
```

### Permissions

| Feature | Permission |
|---|---|
| App shortcuts | None (uses Carbon `RegisterEventHotKey`) |
| Window snap | **Accessibility**: System Settings › Privacy & Security › Accessibility › KeyPilot |

## Default window shortcuts

| Action | Shortcut | | Action | Shortcut |
|---|---|---|---|---|
| Left / Right half | ⌃⌥← / ⌃⌥→ | | Top / Bottom half | ⌃⌥↑ / ⌃⌥↓ |
| Top-left / Top-right | ⌃⌥U / ⌃⌥I | | Bottom-left / Bottom-right | ⌃⌥J / ⌃⌥K |
| First / Center / Last third | ⌃⌥D / ⌃⌥F / ⌃⌥G | | First / Last two thirds | ⌃⌥E / ⌃⌥T |
| Maximize | ⌃⌥↩ | | Maximize height | ⌃⌥⇧↑ |
| Center | ⌃⌥C | | Restore | ⌃⌥⌫ |
| Next / Previous display | ⌃⌥⌘→ / ⌃⌥⌘← | | | |

Pressing a half shortcut repeatedly cycles through 1/2 → 2/3 → 1/3. You can turn this off.

## Build from source

Requires Swift 5.10 or later (Xcode 15.3+, or just the Command Line Tools).

```bash
git clone <repo> && cd KeyPilot
./scripts/test.sh          # unit tests
./scripts/build-app.sh     # -> dist/KeyPilot.app and dist/KeyPilot-1.0.0.dmg
open dist/KeyPilot.app
```

For development you can open `Package.swift` in Xcode, or run `swift run`. Window snapping needs the Accessibility permission granted to your terminal or to Xcode.

Config lives in `~/Library/Application Support/KeyPilot/config.json` and can be imported and exported from **General**.

## Architecture

```
Sources/KeyPilotCore/   pure logic, unit tested (no AppKit)
  KeyCombo, KeyNames    key codes, modifiers, display strings, validation
  SnapAction            all window actions, titles, default shortcuts
  SnapGeometry          layout math, cycling, gaps, multi-display, coordinate flip
  Config                Codable config with tolerant decoding
  ConflictDetector      duplicate shortcut detection
Sources/KeyPilot/       the app
  HotKeyCenter          Carbon global hotkeys
  WindowManager         Accessibility API window move/resize and restore memory
  AppLauncher           open / focus / hide apps
  LaunchAtLogin         SMAppService (13+) / LaunchAgent (12)
  AppDelegate           status bar menu, window lifecycle, minimize to menu bar
  Views/                SwiftUI settings UI and shortcut recorder
```

## License

MIT

---

## 简体中文

KeyPilot 是一款免费、开源的 macOS 状态栏工具：

1. **应用快捷键**：给任意应用设置全局快捷键，按一下打开或切换过去，再按一下隐藏
2. **分屏**：用快捷键把当前窗口放到半屏、四分屏、三分屏、居中、最大化，或移到另一台显示器

- 原生 Swift + SwiftUI，体积约 1 MB，无 Electron、无统计上报、不联网
- 常驻状态栏，关闭或最小化窗口会收回状态栏
- 支持开机自动启动（macOS 13+ 用 SMAppService，macOS 12 用 LaunchAgent）
- 支持 macOS 12 Monterey 及以上，通用二进制（Apple 芯片 + Intel）
- 中英文界面

**安装**：下载 DMG，把 KeyPilot 拖进「应用程序」。首次打开请**右键 → 打开**，或执行 `xattr -dr com.apple.quarantine /Applications/KeyPilot.app`。

**权限**：应用快捷键不需要任何权限。分屏需要「辅助功能」权限（系统设置 › 隐私与安全性 › 辅助功能）。

**使用**：
- 「应用快捷键」页：点「添加应用」或把 .app 拖进来，点击右侧框录制快捷键（⎋ 取消，⌫ 清除）
- 「分屏」页：可修改每个动作的快捷键，点左侧小图标可直接对后面的窗口试用
- 快捷键冲突时会自动从旧动作上移走并提示；系统保留快捷键（⌘Space 等）会被拒绝
- macOS 15 起系统不允许只用 ⌥ 或 ⌥⇧ 作全局快捷键，录制时会提示

**从源码构建**：`./scripts/test.sh` 运行测试，`./scripts/build-app.sh` 生成 `dist/KeyPilot.app` 和 DMG。
