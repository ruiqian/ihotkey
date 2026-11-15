#!/usr/bin/env bash
# Build KeyPilot.app (universal arm64 + x86_64, macOS 12+) and a DMG.
#   ./scripts/build-app.sh            -> dist/KeyPilot.app + dist/KeyPilot-<ver>.dmg
#   SIGN_IDENTITY="Developer ID Application: …" ./scripts/build-app.sh   (optional real signing)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-1.0.0}"
BUILD="${BUILD:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
BUNDLE_ID="com.keypilot.app"
APP="dist/KeyPilot.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"   # "-" = ad-hoc

echo "==> Compiling (release, universal)"
if swift build -c release --arch arm64 --arch x86_64 >/tmp/keypilot-build.log 2>&1; then
  BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/KeyPilot"
else
  echo "    universal build unavailable here, building per-arch and merging with lipo"
  swift build -c release --triple arm64-apple-macosx12.0
  swift build -c release --triple x86_64-apple-macosx12.0
  mkdir -p .build/universal
  lipo -create \
    .build/arm64-apple-macosx/release/KeyPilot \
    .build/x86_64-apple-macosx/release/KeyPilot \
    -output .build/universal/KeyPilot
  BIN=.build/universal/KeyPilot
fi

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/KeyPilot"

if [[ ! -f build/AppIcon.icns ]]; then
  echo "==> Rendering icon"
  mkdir -p build/AppIcon.iconset
  swift scripts/make-icon.swift build/icon-1024.png
  for s in 16 32 128 256 512; do
    sips -z $s $s build/icon-1024.png --out build/AppIcon.iconset/icon_${s}x${s}.png >/dev/null
    sips -z $((s*2)) $((s*2)) build/icon-1024.png --out build/AppIcon.iconset/icon_${s}x${s}@2x.png >/dev/null
  done
  iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string></array>
  <key>CFBundleDisplayName</key><string>KeyPilot</string>
  <key>CFBundleName</key><string>KeyPilot</string>
  <key>CFBundleExecutable</key><string>KeyPilot</string>
  <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD}</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSSupportsAutomaticTermination</key><false/>
  <key>NSSupportsSuddenTermination</key><false/>
  <key>NSHumanReadableCopyright</key><string>MIT License. Free and open source.</string>
</dict>
</plist>
PLIST
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Codesigning ($SIGN_IDENTITY)"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$APP"
else
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi
codesign --verify --strict "$APP"

echo "==> Creating DMG"
DMG="dist/KeyPilot-${VERSION}.dmg"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "KeyPilot" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "==> Done"
lipo -info "$APP/Contents/MacOS/KeyPilot"
ls -lh "$DMG"
