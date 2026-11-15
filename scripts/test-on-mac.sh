#!/bin/bash
# Run on each actual Mac without Xcode/Python. Uses the already installed bundle.
# No TCC reset, login-item writes, Rosetta installation or network access.
# Logs PASS/FAIL/BLOCKED for the host that really ran the tests.
set -u
APP="${1:-/Applications/KeyPilot.app}"
OUT="${2:-$HOME/Desktop/KeyPilot-Compatibility-$(date +%Y%m%d-%H%M%S)}"
BIN="$APP/Contents/MacOS/KeyPilot"
if [ ! -x "$BIN" ]; then printf 'Missing app: %s\n' "$APP"; exit 2; fi
if [ -e "$OUT" ]; then printf 'Output already exists: %s\n' "$OUT"; exit 2; fi
mkdir -p "$OUT"
PASS=0; FAIL=0; BLOCKED=0
{
  date '+%Y-%m-%dT%H:%M:%S%z'
  sw_vers
  uname -m
  shasum -a 256 "$BIN"
  lipo -archs "$BIN"
} > "$OUT/host.txt" 2>&1
printf 'Logs: %s\nThis briefly closes KeyPilot and focuses a scratch TextEdit window.\n' "$OUT"

# Ask the running app to quit gracefully; do not kill unrelated copies.
PIDS="$(ps -axo pid=,comm= | while read -r pid path; do [ "$path" = "$BIN" ] && printf '%s\n' "$pid"; done)"
if [ -n "$PIDS" ]; then
  for pid in $PIDS; do kill -TERM "$pid"; done
  sleep 2
fi
trap 'open "$APP" >/dev/null 2>&1' EXIT

check() {
  local name="$1" token="$2"; shift 2
  "$@" > "$OUT/$name.log" 2>&1
  local rc=$?
  if [ "$rc" -eq 0 ] && /usr/bin/grep -qF "$token" "$OUT/$name.log"; then
    echo "PASS $name" | tee -a "$OUT/summary.txt"; PASS=$((PASS+1))
  elif /usr/bin/grep -qF 'Bad CPU type' "$OUT/$name.log"; then
    echo "BLOCKED $name: architecture cannot execute here" | tee -a "$OUT/summary.txt"; BLOCKED=$((BLOCKED+1))
  else
    echo "FAIL $name: inspect $name.log" | tee -a "$OUT/summary.txt"; FAIL=$((FAIL+1))
  fi
}
if codesign --verify --strict "$APP" > "$OUT/signature.log" 2>&1; then
  echo 'PASS signature' | tee -a "$OUT/summary.txt"; PASS=$((PASS+1))
else
  echo 'FAIL signature' | tee -a "$OUT/summary.txt"; FAIL=$((FAIL+1))
fi
CPU="$(uname -m)"
check "basic-$CPU" 'SELF-TEST OK' /usr/bin/arch "-$CPU" "$BIN" --self-test
check "ui-$CPU" 'UI SELF-TEST OK' /usr/bin/arch "-$CPU" "$BIN" --self-test-ui
if [ "$CPU" = arm64 ]; then
  check basic-x86_64 'SELF-TEST OK' /usr/bin/arch -x86_64 "$BIN" --self-test
fi
# LaunchServices is necessary so the TCC grant is attributed to KeyPilot itself.
open -n "$APP" --args --self-test-snap "$OUT/snap.txt"
for n in {1..40}; do [ -f "$OUT/snap.txt" ] && break; sleep 1; done
if [ -f "$OUT/snap.txt" ] && grep -qF 'SNAP-TEST OK' "$OUT/snap.txt"; then
  echo 'PASS snap (6 real TextEdit actions)' | tee -a "$OUT/summary.txt"; PASS=$((PASS+1))
elif [ -f "$OUT/snap.txt" ] && grep -qF 'FAIL AXIsProcessTrusted' "$OUT/snap.txt"; then
  echo 'BLOCKED snap: grant KeyPilot Accessibility permission and rerun' | tee -a "$OUT/summary.txt"; BLOCKED=$((BLOCKED+1))
else
  echo 'FAIL snap: inspect snap.txt; no report also counts as failure' | tee -a "$OUT/summary.txt"; FAIL=$((FAIL+1))
fi
printf 'PASS=%s FAIL=%s BLOCKED=%s\n' "$PASS" "$FAIL" "$BLOCKED" | tee -a "$OUT/summary.txt"
printf 'This verifies ONLY the macOS version in host.txt, not any older OS.\n' | tee -a "$OUT/summary.txt"
[ "$FAIL" -eq 0 ]
