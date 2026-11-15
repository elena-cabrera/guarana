#!/usr/bin/env bash
# Builds build/Guarana.app (universal: arm64 + x86_64), ad-hoc signed.
# Set SIGN_IDENTITY="Developer ID Application: …" to sign for distribution.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Guarana.app
ASSETS=build/assets

echo "› Rendering artwork"
swift run -c release GuaranaAssets "$ASSETS" >/dev/null
iconutil -c icns "$ASSETS/AppIcon.iconset" -o "$ASSETS/AppIcon.icns"

echo "› Compiling"
# Build each architecture separately (works with just the Command Line Tools), then lipo.
BINS=()
for ARCH in arm64 x86_64; do
  swift build -c release --product Guarana --triple "$ARCH-apple-macosx13.0"
  BINS+=("$(swift build -c release --product Guarana --triple "$ARCH-apple-macosx13.0" --show-bin-path)/Guarana")
done
mkdir -p build
lipo -create "${BINS[@]}" -output build/Guarana-universal
BIN=build/Guarana-universal

echo "› Bundling"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Guarana"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$ASSETS/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
# CI passes BUILD_NUMBER so every release gets its own version (1.0.<n>).
if [ -n "${BUILD_NUMBER:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.0.$BUILD_NUMBER" "$APP/Contents/Info.plist"
fi

echo "› Signing"
codesign --force --options runtime --timestamp=none --sign "${SIGN_IDENTITY:--}" "$APP"

echo "✓ $APP"
