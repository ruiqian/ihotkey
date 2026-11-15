#!/usr/bin/env bash
# Build a universal macOS 12+ app and DMG; preserve previous artifacts.
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${VERSION:-$(tr -d '\r\n' < VERSION)}"
BUILD="${BUILD:-$(git rev-list --count HEAD 2>/dev/null || printf 1)}"
SIGN_MODE="${SIGN_MODE:-adhoc}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]] || { echo 'Invalid VERSION' >&2; exit 2; }
[[ "$BUILD" =~ ^[0-9]+$ ]] || { echo 'BUILD must be numeric' >&2; exit 2; }
APP=dist/iHotkey.app
DMG="dist/iHotkey-$VERSION.dmg"
BUNDLE_ID=com.ihotkey.app
mkdir -p build dist
RUN="$(mktemp -d "$PWD/build/package.XXXXXX")"
# Per-triple builds work with Xcode and Command Line Tools.
for cpu in arm64 x86_64; do
  swift build -c release --triple "$cpu-apple-macosx12.0" | tee "$RUN/build-$cpu.log"
done
BUNDLE="$RUN/iHotkey.app"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
lipo -create .build/arm64-apple-macosx/release/iHotkey .build/x86_64-apple-macosx/release/iHotkey \
  -output "$BUNDLE/Contents/MacOS/iHotkey"
swift scripts/make-icon.swift "$RUN/icon.png"
mkdir -p "$RUN/AppIcon.iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$RUN/icon.png" --out "$RUN/AppIcon.iconset/icon_${size}x${size}.png" >/dev/null
  twice=$((size*2))
  sips -z "$twice" "$twice" "$RUN/icon.png" --out "$RUN/AppIcon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$RUN/AppIcon.iconset" -o "$BUNDLE/Contents/Resources/AppIcon.icns"
python3 - "$BUNDLE" "$VERSION" "$BUILD" <<'PY'
import pathlib, plistlib, sys
bundle, version, build = sys.argv[1:]
p = pathlib.Path(bundle)/'Contents'
info = dict(CFBundleDevelopmentRegion='en', CFBundleLocalizations=['en','zh-Hans'],
 CFBundleDisplayName='iHotkey', CFBundleName='iHotkey', CFBundleExecutable='iHotkey',
 CFBundleIdentifier='com.ihotkey.app', CFBundleIconFile='AppIcon', CFBundlePackageType='APPL',
 CFBundleShortVersionString=version.split('-')[0], CFBundleVersion=build,
 IHReleaseVersion=version, LSMinimumSystemVersion='12.0', LSUIElement=True,
 LSApplicationCategoryType='public.app-category.utilities', NSHighResolutionCapable=True,
 NSSupportsAutomaticTermination=False, NSSupportsSuddenTermination=False,
 NSHumanReadableCopyright='MIT License. iHotkey contributors.')
(p/'Info.plist').write_bytes(plistlib.dumps(info))
(p/'PkgInfo').write_bytes(b'APPL????')
PY
case "$SIGN_MODE" in
  adhoc) codesign --force --sign - "$BUNDLE" ;;
  local)
    SIGN_IDENTITY="$(bash scripts/setup-signing.sh)"
    KEYCHAIN="$HOME/Library/Keychains/ihotkey-signing.keychain-db"
    security unlock-keychain -p "$(<"$HOME/Library/Application Support/iHotkey/.signing-keychain-password")" "$KEYCHAIN"
    codesign --force --keychain "$KEYCHAIN" --sign "$SIGN_IDENTITY" "$BUNDLE" ;;
  developer-id)
    [[ "$SIGN_IDENTITY" == 'Developer ID Application:'* ]] || { echo 'Developer ID Application identity required' >&2; exit 2; }
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$BUNDLE" ;;
  *) echo 'Choose SIGN_MODE=adhoc, local or developer-id' >&2; exit 2 ;;
esac
codesign --verify --strict "$BUNDLE"
mkdir -p "$RUN/previous"
for artifact in "$APP" "$DMG" dist/SHA256SUMS; do
  if [[ -e "$artifact" ]]; then mv "$artifact" "$RUN/previous/"; fi
done
mv "$BUNDLE" "$APP"
mkdir -p "$RUN/dmg-stage"
ditto "$APP" "$RUN/dmg-stage/iHotkey.app"
ln -s /Applications "$RUN/dmg-stage/Applications"
hdiutil create -volname iHotkey -srcfolder "$RUN/dmg-stage" -format UDZO "$DMG" >/dev/null
hdiutil verify "$DMG" > "$RUN/dmg-verification.log"
(cd dist && shasum -a 256 "iHotkey-$VERSION.dmg" > SHA256SUMS)
lipo -info "$APP/Contents/MacOS/iHotkey"
printf 'Built %s (%s signing)\nLogs and previous artifacts: %s\n' "$DMG" "$SIGN_MODE" "$RUN"
