# Contributing to iHotkey

Contributions are welcome in English or Chinese. Small, focused changes with reproducible evidence are easier to review than broad rewrites. Check the [known issues](docs/KNOWN_ISSUES.md) before starting; report suspected vulnerabilities using [SECURITY.md](SECURITY.md), not a public issue.

## Development setup

Use a Mac with **Swift 6 / Xcode 16 or later**, or compatible Command Line Tools with Swift Testing. The app's deployment target remains **macOS 12**; the development toolchain requirement is separate from the minimum runtime OS. Python 3 is required by the packaging and compatibility audit scripts.

From your local checkout:

```bash
./scripts/test.sh
VERSION=1.0.0-rc.1 SIGN_IDENTITY=- ./scripts/build-app.sh
```

`test.sh` handles the Swift Testing framework paths required by Command Line Tools installations. The build creates a universal `dist/iHotkey.app` and versioned DMG; it does not install or launch the app. Open `Package.swift` in Xcode for interactive development.

Use `open dist/iHotkey.app` when you intentionally want to run the bundle. Window snapping requires Accessibility permission for the tested app identity. Running an executable directly from a terminal or Xcode can change TCC attribution and is not equivalent to launching the app bundle through LaunchServices.

### Signing choices

- **Default / `SIGN_IDENTITY=-`:** ad-hoc signing for local builds. No certificate setup is required, but permissions may need to be granted again after a rebuild.
- **`SIGN_MODE=local`:** opt into the dedicated local self-signing setup via `scripts/setup-signing.sh`. This modifies the user's signing keychain configuration; run it only when you want that behavior. It is not Developer ID signing or notarization.
- **Developer ID:** use a properly configured Developer ID Application identity for distribution. Keep certificates, private keys, notarization credentials and local keychain password files out of commits, logs and issue attachments.

Do not reset permissions, change login items, install a build, or install Rosetta as an incidental part of an unrelated change.

## Project layout

```text
Sources/
  iHotkeyCore/             Models, key names, configuration, conflicts and geometry
  iHotkey/
    App/                   Application lifecycle and shared state
    Hotkeys/               Global shortcut registration
    Windows/               Accessibility window operations
    Applications/          App lookup, launch, focus and hide
    System/                Permissions and launch-at-login integration
    Diagnostics/           Self-tests and screenshot rendering
    Views/                 SwiftUI settings and shortcut recording
Tests/iHotkeyCoreTests/    Swift Testing tests
scripts/                   Build, signing, release and compatibility tools
docs/                      Screenshots, compatibility evidence and known issues
```

Keep deterministic logic in `iHotkeyCore` where it can be tested without AppKit. Use the exact product name **iHotkey** in user-facing text, executable names and documentation.

## Making a change

1. Discuss substantial features or behavior changes before implementing them. When this project is hosted on GitHub, use its issue tracker; there is no prescribed remote URL in this checkout.
2. Create a focused branch in your own checkout. Avoid mixing unrelated formatting, generated files and functional changes.
3. Add a regression test for a bug, or tests for new deterministic behavior. Do not move UI or macOS service dependencies into the core just to make a test convenient.
4. Maintain macOS 12 availability guards. In particular, `SMAppService` is available on macOS 13+; linking a framework weakly does not replace guarding API calls.
5. Update both [English](README.md) and [Chinese](README.zh-CN.md) documentation when behavior, commands or setup changes. Update [CHANGELOG.md](CHANGELOG.md) and known issues as appropriate.
6. Run the checks relevant to your change and describe the actual results, including blockers, in the pull request.

Prefer existing style and naming. Handle failed Accessibility calls and persistence errors explicitly; a UI success message is not proof that a window moved or configuration was saved. Avoid broad permission resets, destructive cleanup, silently changing user settings, and machine-specific paths.

## Verification

### Unit tests

```bash
./scripts/test.sh
```

Core tests cover geometry, shortcut models, configuration and conflict handling. They do not exercise TCC, login items, a real keyboard, or every application's window behavior.

### Artifact and deployment-target audit

Build the bundle first, then run:

```bash
python3 scripts/compatibility-test.py --app dist/iHotkey.app
```

This inspects a real bundle, runs core tests and typechecks deployment targets. **Typechecking against a current SDK does not run older macOS versions.** Report the SDK, toolchain, architecture and exact OS that were actually used.

### Runtime checks

These commands interact with the desktop: they briefly close/reopen the tested app and focus a scratch TextEdit window. Save your work and deliberately choose the app copy to test.

```bash
python3 scripts/compatibility-test.py --app dist/iHotkey.app --runtime --snap

# On another Mac with a copy of the app; no Xcode/Python required:
bash scripts/test-on-mac.sh /Applications/iHotkey.app
```

Accessibility approval is required for real snapping. The scripts do not reset TCC, toggle login items or install Rosetta. Review individual logs and all `PASS`, `FAIL` and `BLOCKED` entries; a zero exit status can still include blocked checks. Rosetta, if available, is not a substitute for testing an Intel Mac.

For changes involving UI, system integration or windows, also test the relevant scenarios manually:

- Physical-keyboard app launch/focus/hide, recording cancel/clear, conflict reassignment and registration failure.
- Closing, minimizing and reopening the settings window; menu bar and optional Dock icon behavior.
- First Accessibility approval, denial, revocation and re-approval, without bypassing system protections.
- Window sizes and restore, non-resizable/minimum-size windows, display scaling and multi-display arrangements.
- Login approval, enable/disable, logout/login, and old LaunchAgent migration when those paths change.
- English/Chinese and light/dark appearance.

Do not claim these scenarios passed unless you ran them. Preserve a copy of the user's configuration before intentional configuration testing. Redact user paths and unrelated information before sharing logs.

## Pull request checklist

- [ ] Scope and user-visible behavior are explained.
- [ ] Relevant tests are added or updated, and executed commands/results are included.
- [ ] Actual OS, architecture and toolchain are stated; untested environments and blocked checks are identified.
- [ ] New APIs are guarded for macOS 12 where required.
- [ ] Both README languages and changelog/known issues are updated where needed.
- [ ] No signing material, personal configuration, build products or private logs are included.
- [ ] Screenshots are current if the UI changed, and use non-sensitive sample data.

## Release preparation

`VERSION` is the release-version source of truth. The current candidate is `1.0.0-rc.1`; keep it aligned with release notes and any explicit `VERSION` override. A candidate is not a stable-release claim.

Before publishing:

1. Resolve or explicitly document release blockers in [known issues](docs/KNOWN_ISSUES.md). The [historical compatibility report](docs/testing/legacy-compatibility-report.md) is evidence for an earlier build, not certification of a renamed artifact.
2. Run unit tests, audit the final universal bundle and perform runtime checks on the actual target systems/hardware available. Record remaining gaps honestly.
3. For official distribution, configure a Developer ID Application certificate and a notarization keychain profile using Apple's tooling. Never put credentials in the repository or documentation examples.
4. Run the release workflow intentionally with the configured identity and profile:

   ```bash
   VERSION=1.0.0-rc.1 \
   SIGN_IDENTITY="Developer ID Application: YOUR SIGNING IDENTITY" \
   NOTARY_PROFILE=ihotkey-notary \
   ./scripts/release.sh
   ```

5. Inspect the real notarization, stapling, signature and Gatekeeper results. Verify the exact final artifact on a clean machine before describing it as ready for distribution. Local code-signature verification alone is insufficient.
6. Only then prepare a prerelease and upload verified artifacts to the actual project host. A successful local build or a workflow file in the repository does not mean a GitHub release exists, CI ran, or Apple accepted the app.

## License

By submitting a contribution, you agree that it may be distributed under the project's [MIT License](LICENSE).

## 中文说明

欢迎用中文提交问题和贡献。请保持改动范围清晰，同时更新中英文使用文档；提交前运行相关测试，并注明真实的系统、架构、工具链与未覆盖场景。旧系统的类型检查不等于运行实测，`BLOCKED` 不等于通过。请勿提交个人配置、签名私钥或公证凭据。安全问题请按 [SECURITY.md](SECURITY.md) 私下报告，不要在公开 Issue 中发布敏感细节。
