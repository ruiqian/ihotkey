# iHotkey 1.0.0-rc.1 — release notes draft

Free, MIT-licensed native macOS app shortcuts and window snapping.

- App launch/focus and show/hide bindings with a shortcut recorder.
- Twenty window actions including halves, quarters, thirds, maximize, center, restore and display movement.
- Menu-bar operation, hide-on-close/minimize, launch-at-login support, English and Simplified Chinese UI.
- Renamed from the local KeyPilot prototype; source organization and contributor/release documentation prepared.

## Before installing

This workflow's development DMG is **ad-hoc signed and not notarized**. Do not describe it as Apple-certified. The release is a candidate with [known issues](KNOWN_ISSUES.md), especially login-item edge cases. macOS 12 is the deployment target, not a claim that all old systems have been exercised.

If migrating from the prototype, quit it first, import its exported config, and grant Accessibility to the new iHotkey identity. See [Migration](MIGRATION.md).

Maintainer: replace development assets with verified Developer ID notarized artifacts before announcing a notarized release. Confirm the final version, compatibility report, SHA256SUMS and known issues before publishing this draft.
