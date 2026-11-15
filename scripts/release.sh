#!/usr/bin/env bash
# Official release: Developer ID signing + Apple notarization + stapling.
# The result opens on any Mac without Gatekeeper warnings and keeps the
# Accessibility grant across updates (same Team ID => same designated requirement).
#
# One-time setup (requires Apple Developer Program membership):
#   1. Xcode/Keychain: create a "Developer ID Application" certificate and install it.
#   2. Store notarization credentials in the keychain (app-specific password from appleid.apple.com):
#        xcrun notarytool store-credentials keypilot-notary \
#          --apple-id you@example.com --team-id TEAMID1234 --password abcd-efgh-ijkl-mnop
#
# Usage:
#   VERSION=1.0.0 ./scripts/release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:?set VERSION, e.g. VERSION=1.0.0}"
PROFILE="${NOTARY_PROFILE:-keypilot-notary}"
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | grep -m1 'Developer ID Application' | sed -E 's/.*"(.*)"/\1/')}"
[[ -n "$IDENTITY" ]] || { echo "No 'Developer ID Application' certificate found in keychain."; exit 1; }
echo "==> Identity: $IDENTITY"

# Build + sign app with hardened runtime (build-app.sh handles the signing flags).
SIGN_IDENTITY="$IDENTITY" VERSION="$VERSION" ./scripts/build-app.sh

APP=dist/KeyPilot.app
DMG="dist/KeyPilot-${VERSION}.dmg"

echo "==> Signing DMG"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

echo "==> Notarizing (this usually takes 1-5 minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait

echo "==> Stapling"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "==> Gatekeeper check"
spctl -a -vvv -t install "$DMG" || true
MNT="$(hdiutil attach -nobrowse -readonly "$DMG" | tail -1 | awk -F'\t' '{print $NF}')"
spctl -a -vvv "$MNT/KeyPilot.app"
hdiutil detach "$MNT" >/dev/null

shasum -a 256 "$DMG"
echo "==> Ready to publish: $DMG"
