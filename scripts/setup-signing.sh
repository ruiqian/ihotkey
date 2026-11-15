#!/usr/bin/env bash
# Create (once) a self-signed code-signing identity in a dedicated keychain.
#
# Why: ad-hoc signatures ("codesign -s -") identify the app only by its binary
# hash, so macOS forgets the Accessibility permission after every rebuild.
# Signing with a stable certificate makes the designated requirement
#   identifier "com.keypilot.app" and certificate leaf = H"<cert hash>"
# which survives rebuilds, so the permission is granted once and kept.
#
# The identity lives in its own keychain (~/Library/Keychains/keypilot-signing.keychain-db)
# with a generated password, so codesign never shows a GUI prompt.
set -euo pipefail

NAME="${SIGN_CERT_NAME:-KeyPilot Self-Signed}"
KC="$HOME/Library/Keychains/keypilot-signing.keychain-db"
PWFILE="$HOME/Library/Application Support/KeyPilot/.signing-keychain-password"

if security find-certificate -c "$NAME" "$KC" >/dev/null 2>&1; then
  echo "$NAME"
  exit 0
fi

mkdir -p "$(dirname "$PWFILE")"
if [[ ! -f "$PWFILE" ]]; then
  openssl rand -hex 24 >"$PWFILE"
  chmod 600 "$PWFILE"
fi
PW="$(cat "$PWFILE")"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat >"$TMP/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
O = KeyPilot
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
EOF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cert.cnf" >/dev/null 2>&1
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -name "$NAME" -out "$TMP/id.p12" -passout pass:keypilot >/dev/null 2>&1

if [[ ! -f "$KC" ]]; then
  security create-keychain -p "$PW" "$KC"
  security set-keychain-settings "$KC"          # no auto-lock timeout
fi
security unlock-keychain -p "$PW" "$KC"
security import "$TMP/id.p12" -k "$KC" -P keypilot -T /usr/bin/codesign >/dev/null
# Allow codesign to use the key without a GUI prompt.
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PW" "$KC" >/dev/null

# Add to the user's keychain search list (keeps existing entries).
EXISTING=$(security list-keychains -d user | sed -e 's/^ *"//' -e 's/" *$//')
if ! grep -qF "$KC" <<<"$EXISTING"; then
  # shellcheck disable=SC2086
  security list-keychains -d user -s $EXISTING "$KC"
fi

echo "$NAME"
