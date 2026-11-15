#!/usr/bin/env bash
# Builds the installer: build/Guarana.dmg with the custom drag-to-Applications window.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -d build/Guarana.app ] || scripts/build-app.sh

ASSETS=build/assets
# Retina background: combine 1x + 2x into one multi-resolution TIFF.
tiffutil -cathidpicheck "$ASSETS/dmg-background.png" "$ASSETS/dmg-background@2x.png" \
  -out "$ASSETS/dmg-background.tiff" >/dev/null

# dmgbuild writes the Finder layout (.DS_Store) without needing to drive Finder.
VENV=build/.dmg-venv
if [ ! -x "$VENV/bin/dmgbuild" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet dmgbuild
fi

rm -f build/Guarana.dmg
"$VENV/bin/dmgbuild" -s installer/dmg-settings.py "Guarana" build/Guarana.dmg
echo "✓ build/Guarana.dmg"
