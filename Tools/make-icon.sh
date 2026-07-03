#!/bin/bash
# Build Support/AppIcon.icns from a source PNG.
#
#   Tools/make-icon.sh [source.png]
#
# Default source: Support/Brand/AppIcon-flame-imagegen.png (drop your generated
# 1024x1024 art there). Masks it to the macOS squircle, renders the full iconset,
# and assembles the .icns. The previous ring master is preserved aside.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="${1:-Support/Brand/AppIcon-flame-imagegen.png}"
[ -f "$SRC" ] || { echo "error: source not found: $SRC" >&2; exit 1; }

MASTER="Support/Brand/AppIcon-master.png"
ICONSET="Support/AppIcon.iconset"
ICNS="Support/AppIcon.icns"
RING="Support/Brand/AppIcon-ring-master.png"

# Preserve the current (ring) master once, so the pivot stays reversible.
if [ -f "$MASTER" ] && [ ! -f "$RING" ]; then
  cp "$MASTER" "$RING"
  echo "kept previous master -> $RING"
fi

echo "masking $SRC -> squircle master"
python3 Tools/squircle_mask.py "$SRC" "$MASTER"

echo "rendering iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
render() { sips -z "$1" "$1" "$MASTER" --out "$ICONSET/$2" >/dev/null; }
render 16   icon_16x16.png
render 32   icon_16x16@2x.png
render 32   icon_32x32.png
render 64   icon_32x32@2x.png
render 128  icon_128x128.png
render 256  icon_128x128@2x.png
render 256  icon_256x256.png
render 512  icon_256x256@2x.png
render 512  icon_512x512.png
render 1024 icon_512x512@2x.png

echo "assembling icns"
iconutil -c icns "$ICONSET" -o "$ICNS"
echo "done -> $ICNS"
