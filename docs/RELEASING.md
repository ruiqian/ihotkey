# Publishing iHotkey

## Current readiness

The repository can be built and tested locally. No GitHub account/repository has been selected, workflows have **not** run on GitHub, and no Developer ID notarization is claimed. The initial version is `1.0.0-rc.1`. Resolve or disclose [known issues](KNOWN_ISSUES.md) before promoting it to stable.

## Before the first push

- [ ] Select the owner and repository name (`iHotkey` recommended); check naming/trademark availability independently.
- [ ] Review LICENSE, security policy, screenshots and release notes.
- [ ] Run unit tests, repository checks and universal packaging from [Development](DEVELOPMENT.md).
- [ ] Confirm no personal paths, configuration, private keys, passwords or certificates are tracked. Review **history**, not only the working tree.
- [ ] Keep `build/`, `dist/`, `.build/`, `.env`, keychains and private credentials ignored.
- [ ] Enable Issues and private vulnerability reporting if appropriate; confirm the reporting route in SECURITY.md.

This repository preserves local prototype history. It contains old branding and historical paths in earlier commits; do not rewrite that history casually. If a clean public history is preferred, copy the source-only export into a new repository and make an initial commit. The export must not include `.git`, `.build`, `build`, `dist`, signing data or user config.

The following commands are examples for the maintainer to execute **after approving the public content**; no remote is preconfigured:

```bash
gh auth login
gh repo create OWNER/iHotkey --public --source . --remote origin
# Review local commits and remote owner first.
git push -u origin main
```

## CI and draft prereleases

CI is configured for `macos-14` and `macos-15`. It runs repository checks, Swift tests, universal packaging, and uploads development artifacts. It does not claim interactive UI, TCC, login or macOS 12/13 coverage. Runner availability and the selected Swift version must be checked on the first actual GitHub run.

A `v*` tag matching `VERSION` runs the draft workflow. The workflow creates a **draft prerelease**, never automatically publishes it. Assets use ad-hoc signing and are **not notarized**. On `workflow_dispatch` without a tag it only uploads artifacts.

```bash
# After reviewing code, release notes and version:
git tag v1.0.0-rc.1
git push origin v1.0.0-rc.1
```

Do not publish that draft as a notarized stable release. Review its warnings, or replace its development assets with the official notarized artifacts below.

## Developer ID distribution

1. Join Apple Developer Program; install a valid **Developer ID Application** identity and private key in Keychain.
2. Store notarization credentials interactively on your Mac (no password in a command, document, chat or GitHub log):
   ```bash
   xcrun notarytool store-credentials ihotkey-notary
   ```
3. Set VERSION to the intended version, then:
   ```bash
   bash scripts/release.sh
   ```
4. Inspect notarization result, stapling, Gatekeeper assessment and SHA256SUMS. The script stops on failures and does not publish to GitHub.
5. Verify the exact DMG on a clean user account/Mac. Verify the minimum supported OS, Intel hardware, permissions, update path and login-item scenarios. Do not infer this from a binary's minimum-OS flag.
6. Attach the tested DMG and fresh checksums to a draft. Review content before clicking Publish.

Keep release identity stable. Do not mix ephemeral self-signed CI identities across official updates. Bundle ID changes require a new Accessibility grant even if the app is renamed similarly.

## Homebrew

`packaging/ihotkey.rb.example` is a template only. After an actual release URL exists, fill the real owner, version, URL and checksum; validate the cask in a tap before advertising a brew command. No tap or Homebrew entry has been submitted.
