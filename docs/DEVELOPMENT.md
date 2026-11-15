# Development

## Toolchain

Use macOS with Swift **6.0+** (Xcode 16+ or compatible Command Line Tools), Python 3 and the system packaging utilities. Swift Testing is used by the test target. The package manifest uses Swift tools 5.10 syntax, but that is not the test suite's minimum compiler requirement. The shipped application targets macOS **12.0+**, independently of the development toolchain.

```bash
bash scripts/test.sh
python3 scripts/test-repository.py
bash scripts/build-app.sh
open dist/iHotkey.app
```

The first command works with Command Line Tools-only installations. The build produces a universal arm64/x86_64 app, DMG and `dist/SHA256SUMS`. Previous artifacts are moved under `build/package.*/previous/`; build logs remain under the same directory. No Xcode project or third-party package dependency is required.

## Source map

```text
Sources/
  iHotkey/
    main.swift          NSApplication entry point
    App/                lifecycle, state, persistence, status menu
    Applications/       application resolution, launch and toggle
    Diagnostics/        command-line self-tests and screenshot renderer
    Hotkeys/            Carbon registration and dispatch
    System/             login-item integration and Monterey fallback
    Windows/            Accessibility window control and restore memory
    Views/              native SwiftUI settings and shortcut recorder
  iHotkeyCore/          AppKit-independent models, geometry and conflicts
Tests/iHotkeyCoreTests/ deterministic unit tests
scripts/                testing, signing, packaging and release tools
packaging/              Homebrew cask example (not an installed/published tap)
```

Keep geometry and config logic in the core target. Changes to behavior require a failing regression test before the fix. Do not mix speculative compatibility fixes into cosmetic refactors.

## Signing modes

- Default `SIGN_MODE=adhoc`: no keychain changes, suitable for reproducible local/CI experiments; not notarized. Rebuilding can invalidate Accessibility grants.
- `SIGN_MODE=local bash scripts/build-app.sh`: explicit opt-in creates a dedicated local development identity/keychain. This helps retain grants across local rebuilds; it is not Apple Developer ID and does not bypass Gatekeeper.
- `SIGN_MODE=developer-id SIGN_IDENTITY='Developer ID Application: …'`: official identity required; use `scripts/release.sh` for notarization.

Never commit signing passwords, certificates, private keys, provisioning profiles, notarization credentials or generated logs. Do not run signing scripts with shell tracing enabled.

## Diagnostics

Quit other copies first: two copies compete for hotkeys. Direct terminal launch and LaunchServices can have different TCC attribution; the snap test must use LaunchServices.

```bash
dist/iHotkey.app/Contents/MacOS/iHotkey --self-test
dist/iHotkey.app/Contents/MacOS/iHotkey --self-test-ui
open -n dist/iHotkey.app --args --self-test-snap "$PWD/build/snap.txt"
dist/iHotkey.app/Contents/MacOS/iHotkey --render-screenshots "$PWD/build/screenshots" --lang en
```

`--self-test` registers real hotkeys and dispatches a synthetic Carbon event. It is not a physical-keyboard test. `--self-test-ui` drives the real main window and menu. `--self-test-snap` opens a scratch TextEdit document, changes its window and restores it; Accessibility permission is required. Diagnostic modes exit when finished. The optional `--self-test --login-item` actually changes login-item registration and is **not** part of the default regression suite.

```bash
python3 scripts/compatibility-test.py --app "$PWD/dist/iHotkey.app"
# On a dedicated test machine, runtime tests briefly close/reopen the tested app:
python3 scripts/compatibility-test.py --app /Applications/iHotkey.app --runtime --snap
# No developer tools needed on a tester's Mac:
bash scripts/test-on-mac.sh /Applications/iHotkey.app
```

Deployment-target typechecking is not old-system runtime testing. Keep test logs local and sanitize user paths before sharing.

## Renamed identity

The current app is `iHotkey`, executable/package `iHotkey`, bundle ID `com.ihotkey.app`, configuration `~/Library/Application Support/iHotkey/config.json`, and Monterey agent label `com.ihotkey.app.launcher`. This is a distinct identity from the former KeyPilot prototype. See [migration](MIGRATION.md). No automatic permission transfer is attempted.
