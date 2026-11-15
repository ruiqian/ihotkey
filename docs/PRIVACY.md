# Privacy

iHotkey stores shortcut settings locally in `~/Library/Application Support/iHotkey/config.json`. App bindings contain app names, bundle IDs, executable bundle paths, assigned key codes/modifiers and enable state. Do not attach an unreviewed config to a public issue if paths reveal personal information.

The app has no account system, analytics backend, advertising or application-initiated network API in this version. macOS security services, GitHub downloads and maintainer notarization are separate system/distribution activities; do not interpret this as a claim that the OS never connects to Apple.

Global shortcut registration uses Carbon. Window control uses macOS Accessibility, only after the user grants it. iHotkey reads the targeted application's focused window position/size and requests moves/resizes. It does not need Screen Recording for these operations.

Diagnostic modes may open a scratch TextEdit document and save screenshots or logs at the explicitly supplied path. Logs can contain OS/build details and local paths. Review before sharing. Signing credentials belong in Keychain, never in the repository or issue reports.
