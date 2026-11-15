# Changelog

User-visible changes and release-readiness notes for iHotkey. Candidate headings describe development scope, not proof that a package has been published, signed by Apple or runtime-tested on every deployment target.

## [Unreleased]

Changes after the `1.0.0-rc.1` candidate will be recorded here.

## [1.0.0-rc.2] — Unreleased candidate

### Fixed

- Menu-bar icon now has a stable autosave identity and a one-time right-edge placement hint, preventing initial placement under the display notch. A compact 24-point item with a 16-point template Command icon supports system tint and preserves later user placement.
- Minimizing iHotkey's own settings window now uses its native hide-to-menu-bar path before any Accessibility check. The preview button no longer hides first and accidentally targets the previous application.
- Minimize failures now distinguish full-screen, missing window and AX failure instead of always suggesting the window is full-screen.
- Added a failing-then-passing UI regression for own-window minimize, continued menu-bar operation and absence of an error toast.
- Real snap diagnostics explicitly target TextEdit, not whichever app happens to become frontmost during the test.

### Added

- **Minimize Window** in Window Snap → Screen and the status-bar menu. Uses Accessibility `AXMinimized` to minimize the focused window to Dock, not hide the whole app.
- Default `⌃⌥M` for new configurations. Existing/imported configurations retain their bindings without silently adding a new global shortcut; record a key for the new row explicitly.
- Four core regression tests for action/default registration, non-geometric behavior, safe old config decoding, custom bindings and clearing. Snap self-test now reads `AXMinimized` on the same window handle and unminimizes it during cleanup.

## [1.0.0-rc.1] — Unreleased candidate

### Added

- Global app shortcuts with per-app **Open / Focus** and **Show / Hide** behavior, app drag-and-drop, and enable/disable controls.
- Twenty window actions: halves, quarters, thirds, two-thirds, maximize, almost maximize, maximize height, center, restore, and next/previous display.
- Configurable window gaps and optional half-screen size cycling through ½, ⅔ and ⅓.
- Shortcut recording with cancel/clear controls, common reserved-shortcut validation, internal conflict reassignment and registration-error feedback.
- Menu bar controls, optional Dock icon visibility while settings are open, and hide-to-menu-bar behavior when closing or minimizing the settings window.
- English and Simplified Chinese interface options, plus system-language selection.
- Local JSON configuration with import/export and tolerant decoding for missing fields.
- Optional launch-at-login integration using `SMAppService` on macOS 13+ and a LaunchAgent on macOS 12.
- Core unit tests, local diagnostics, deployment-target audit tooling and a runtime test script for Macs without developer tools.

### Changed

- Renamed the project from **KeyPilot** to **iHotkey**, including Swift package/module names and app identity. The current bundle identifier is `com.ihotkey.app`, and configuration is stored in `~/Library/Application Support/iHotkey/config.json`.
- Prepared a universal Apple Silicon/Intel packaging workflow with a macOS 12 deployment target.
- Separated ad-hoc local builds, optional stable local self-signing, and the credential-dependent Developer ID/notarization release workflow.
- Documented Swift 6 / Xcode 16+ as the development/test requirement because tests use Swift Testing; the app's deployment target remains macOS 12.
- Split English and Chinese READMEs and added contribution and security policies.

### Verification and known limitations

- Renamed candidate verified locally on **macOS 26.6.2 arm64**: 26 unit tests, seven repository checks, 20 registered hotkeys with synthetic event dispatch and ten window/menu lifecycle checks. Real snapping under the renamed identity still needs Accessibility approval and a fresh run; historical snap evidence belongs to the old build.
- macOS 12, 13, 14 and 15 deployment-target typechecks passed for both architectures using a current SDK; those OS versions were **not runtime-tested**.
- Intel execution was blocked on the available Apple Silicon host because Rosetta was unavailable; no Intel hardware validation is claimed.
- Login-event detection, old LaunchAgent migration after an OS upgrade, login approval UI and restore-error handling remain known issues. Real login/reboot, multi-display and clean-install/upgrade validation remain incomplete.
- Automatic migration from the old project identity, configuration location or permission grants is not promised. Export existing settings and retain a backup before trying a renamed build; review imported paths and re-grant permissions if needed.
- No public download, completed CI run, Apple notarization or clean-machine Gatekeeper acceptance is asserted for this candidate.

See [known issues](docs/KNOWN_ISSUES.md) and the [historical compatibility report](docs/testing/legacy-compatibility-report.md) before evaluating release readiness.

### 中文摘要

`1.0.0-rc.1` 是尚未发布的候选版本：项目由 KeyPilot 更名为 iHotkey，整理了应用快捷键、20 种窗口动作、本地配置与中英文界面，并补充构建、测试和安全文档。改名后的候选版本已通过 macOS 26.6.2 arm64 的单元、仓库、快捷键和界面生命周期检查；新身份真实分屏仍待授权实测。旧系统只有类型检查，Intel 未做运行验证。登录启动、迁移、审批界面和恢复失败处理仍有已知问题，不宣称已完成公开发布、CI 或 Apple 公证。
