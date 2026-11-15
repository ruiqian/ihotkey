# Moving from the KeyPilot prototype to iHotkey

The name, Swift package/targets, executable, bundle ID, menu labels, config directory, login label and build artifacts are now iHotkey. The project directory is `iHotkey/`.

| Identity | Prototype | iHotkey |
|---|---|---|
| Bundle ID | `com.keypilot.app` | `com.ihotkey.app` |
| Configuration | `~/Library/Application Support/KeyPilot/config.json` | `~/Library/Application Support/iHotkey/config.json` |
| Monterey login label | `com.keypilot.app.launcher` | `com.ihotkey.app.launcher` |

## Safe migration

1. In the old app, export configuration and turn off launch at login if enabled.
2. Quit the old app before launching iHotkey: both apps cannot reliably own the same global shortcuts.
3. Copy `iHotkey.app` to Applications and open it.
4. Grant **iHotkey** Accessibility permission explicitly. macOS treats it as a new identity; the old switch is not sufficient.
5. Import the exported JSON in General. The config schema is unchanged; brand changes do not rewrite app bindings or key codes.
6. Enable iHotkey launch at login if desired. Verify it after a real logout/login on your OS.

No automatic deletion, legacy config mutation, login-item removal, or authorization reset occurs as part of this source rename. The old installed app is preserved. Avoid running both apps at once. Remove old files only after confirming the new installation works and keeping a backup.

For developers, the default build no longer creates a signing identity automatically. Use the explicit local signing mode documented in [Development](DEVELOPMENT.md), or the Developer ID release path.
