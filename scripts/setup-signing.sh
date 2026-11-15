#!/usr/bin/env bash
# Explicit opt-in: stable local identity, NOT Apple Developer ID.
set -euo pipefail
cd "$(dirname "$0")/.."
NAME='iHotkey Local Development'
KC="$HOME/Library/Keychains/ihotkey-signing.keychain-db"
PWFILE="$HOME/Library/Application Support/iHotkey/.signing-keychain-password"
if security find-identity -p codesigning "$KC" 2>/dev/null | grep -qF "$NAME"; then
  printf '%s\n' "$NAME"; exit 0
fi
mkdir -p "$(dirname "$PWFILE")" build
umask 077
if [[ ! -s "$PWFILE" ]]; then openssl rand -hex 24 > "$PWFILE"; fi
PW="$(<"$PWFILE")"
TMP="$(mktemp -d "$PWD/build/signing.XXXXXX")"
cat > "$TMP/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
O = iHotkey
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
EOF
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cert.cnf" >/dev/null 2>&1
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$NAME" -out "$TMP/identity.p12" -passout "file:$PWFILE"
if [[ ! -f "$KC" ]]; then security create-keychain -p "$PW" "$KC"; security set-keychain-settings "$KC"; fi
security unlock-keychain -p "$PW" "$KC"
security import "$TMP/identity.p12" -k "$KC" -P "$PW" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PW" "$KC" >/dev/null
python3 - "$KC" <<'PY'
import shlex, subprocess, sys
paths=shlex.split(subprocess.check_output(['security','list-keychains','-d','user'],text=True))
if sys.argv[1] not in paths:
 subprocess.run(['security','list-keychains','-d','user','-s',*paths,sys.argv[1]],check=True)
PY
# Preserve private intermediate files in Trash, outside the source tree.
mv "$TMP" "$HOME/.Trash/ihotkey-signing-$(date +%Y%m%d%H%M%S)-$$"
printf '%s\n' "$NAME"
