# iHotkey rename validation — 1.0.0-rc.1

This report describes the **renamed candidate**, not the old KeyPilot binary. Validation host: macOS 26.6.2 (25G83), Apple Silicon arm64, Swift 6.3.3. No GitHub runner or notarization service was invoked.

## Verified

- `bash scripts/test.sh`: **26/26 tests passed** after directory/target renaming and source organization.
- `python3 scripts/test-repository.py`: **7 repository checks passed**, including current brand in all active Swift sources, organized folders, ignored signing material, draft-only release workflow, version docs and About release-version display.
- `bash scripts/build-app.sh`: universal arm64/x86_64 app and DMG built successfully. `codesign --verify --strict` and DMG checksum verification passed.
- `python3 scripts/compatibility-test.py --app "$PWD/dist/iHotkey.app"`: **33 script checks passed**, including minimum OS 12.0 in both slices/Info.plist, weak ServiceManagement linkage, unit suite and ten deployment-target typechecks (12/13/14/15/26 × two CPU architectures). These are source checks with a modern SDK, **not** ten OS runtime tests.
- Renamed binary `--self-test`: **20/20 global hotkeys registered**, internal duplicate rejected, synthetic Carbon event dispatched, TextEdit bundle resolution/config round trip passed.
- Renamed binary `--self-test-ui`: **10 checks passed** covering window open, Dock icon policy, close/minimize-to-menu-bar, menu items and reopen.
- Fresh Chinese/light and English/dark screenshots rendered from renamed views; branding visually checked.
- Release script fails clearly before building/notarizing when no Developer ID identity is available. Full Developer ID/signing/notarization path remains unexecuted.

The candidate executable SHA-256 is:
`398b55fb78305239f55aa9c47651f51a05c2b4521a30b66253c6de816a28a5fc`

## Unverified and unchanged

The candidate uses bundle ID `com.ihotkey.app` and has not received its own Accessibility permission. Therefore **real TextEdit window snapping was not rerun on this renamed binary**. Historical real snap evidence belongs to the old identity only. No implicit transfer/reset of permissions is claimed.

Old installed prototype and its configuration were preserved; testing briefly stopped it to avoid hotkey conflicts, then reopened it. New app was not installed over it. No keychain/signing identity was created by the default build and no login-item setting was changed.

macOS 12–15 real desktop testing, Intel hardware/Rosetta execution, multiple displays, reboot/login flows, clean-user Gatekeeper and update migration remain outstanding. [Known issues](../KNOWN_ISSUES.md) are explicitly disclosed, not silently fixed as part of this rename.

## Local evidence

Generated logs remain ignored under `build/rename-validation/`, `build/rename-final-audit/`, and `build/final-*.log`. Do not publish those raw logs without checking paths and other local details. The public report records findings without personal machine paths.
