#!/usr/bin/env bash
# Official release: Developer ID signing + Apple notarization + stapling.
# The result opens on any Mac without Gatekeeper warnings and keeps the
# Accessibility grant across updates (same Team ID => same designated requirement).
#
# One-time setup (requires Apple Developer Program membership):
#   1. Xcode/Keychain: create a "Developer ID Application" certificate and install it.
#   2. Store notarization credentials interactively (never put a password in shell history):
#        xcrun notarytool store-credentials ihotkey-notary
#
# Usage:
#   VERSION=1.0.0 ./scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(tr -d '\r\n' < VERSION)}"
PROFILE="${NOTARY_PROFILE:-ihotkey-notary}"
IDENTITY="${SIGN_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then
  IDENTITY="$(security find-identity -v -p codesigning | python3 -c 'import re,sys; a=re.findall(r"\"(Developer ID Application:[^\"]+)\"",sys.stdin.read()); print(a[0] if a else "")')"
fi
[[ -n "$IDENTITY" ]] || { echo "No 'Developer ID Application' certificate found in keychain."; exit 1; }
echo "==> Identity: $IDENTITY"

# Build + sign app with hardened runtime (build-app.sh handles the signing flags).
SIGN_MODE=developer-id SIGN_IDENTITY="$IDENTITY" VERSION="$VERSION" bash scripts/build-app.sh

APP=dist/iHotkey.app
DMG="dist/iHotkey-${VERSION}.dmg"

echo "==> Signing DMG"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

echo "==> Notarizing (this usually takes 1-5 minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait

echo "==> Stapling"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "==> Gatekeeper check"
MNT="$(mktemp -d "$PWD/build/verify-mount.XXXXXX")"
trap 'hdiutil detach "$MNT" >/dev/null 2>&1 || true' EXIT
hdiutil attach -nobrowse -readonly -mountpoint "$MNT" "$DMG" >/dev/null
spctl --assess --verbose=2 "$MNT/iHotkey.app"
hdiutil detach "$MNT" >/dev/null
trap - EXIT

(cd dist && shasum -a 256 "iHotkey-${VERSION}.dmg" > SHA256SUMS)
echo "==> Ready to publish: $DMG"
