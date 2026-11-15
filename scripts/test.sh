#!/usr/bin/env bash
# Run unit tests. Works with full Xcode and with Command Line Tools only
# (CLT needs the Swift Testing framework path passed explicitly).
set -euo pipefail
cd "$(dirname "$0")/.."

CLT=/Library/Developer/CommandLineTools/Library/Developer
if [[ "$(xcode-select -p)" == /Library/Developer/CommandLineTools* && -d "$CLT/Frameworks/Testing.framework" ]]; then
  exec swift test \
    -Xswiftc -F"$CLT/Frameworks" \
    -Xlinker -rpath -Xlinker "$CLT/Frameworks" \
    -Xlinker -rpath -Xlinker "$CLT/usr/lib" "$@"
fi
exec swift test "$@"
