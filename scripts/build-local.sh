#!/usr/bin/env bash
# Daily-use build on this Mac: reuse the stable local signing identity.
# Does not install, reset permissions or remove other apps.
set -euo pipefail
cd "$(dirname "$0")/.."
SIGN_MODE=local bash scripts/build-app.sh
printf '\nUse this signed bundle consistently. Grant Accessibility to the installed /Applications/iHotkey.app.\n'
printf 'Default CI/ad-hoc builds have different identities and are not interchangeable with this local build.\n'
