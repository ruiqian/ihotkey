# Known issues and verification limits

This is an initial release candidate, not a promise of full cross-version certification.

## Outstanding source-review findings

- **Login-event detection:** the code currently compares `keyAEPropData` with a login-item keyword instead of checking keyword presence. The uptime heuristic is not a reliable substitute; delayed login may show the settings window.
- **Monterey → Ventura+ migration:** legacy LaunchAgent presence is not reconciled with SMAppService state after upgrading the OS. UI state may disagree with the old registration.
- **Pending approval UI:** requiresApproval is displayed as disabled; a clear cancel/open-login-settings flow is missing.
- **Restore errors:** restore discards its saved record and returns moved without checking the AX set-frame error. A successful happy-path test does not cover rejection.
- **Monterey permission wording:** instructions currently use newer System Settings menu labels.

These are known, intentionally disclosed behaviors, not fixed by the rename/source organization. Avoid changing signed production identity or user login settings merely to hide them.

## Compatibility coverage

- The former-name build was tested on macOS 26.6.2 Apple Silicon: core tests, hotkey registration/dispatch, main window/menu lifecycle, six TextEdit snap actions.
- Source deployment-target checks for macOS 12/13/14/15/26 and both CPU architectures passed on a modern SDK. That does not run those OS releases.
- The renamed candidate has its own validation report under [testing](testing/). Do not treat the historical report as a test of a new binary.
- Real macOS 12–15, Intel hardware/Rosetta, multiple displays, Stage Manager, real login/reboot, clean-machine Gatekeeper and update migration are not fully verified.

## Permissions and distribution

Accessibility grants cannot be transferred automatically from the old prototype identity. Default development builds are ad-hoc signed, unnotarized, and may require a fresh grant after rebuilding. Use an approved, stable Developer ID release workflow for public distribution. Do not tell users to globally disable Gatekeeper.
