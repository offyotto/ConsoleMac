#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICONSET_DIR="$ROOT_DIR/.build/generated/AppIcon.iconset"
OUTPUT_ICNS="$ROOT_DIR/Sources/ConsoleMac/Resources/AppIcon.icns"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

swift "$ROOT_DIR/script/render_borderless_app_icon.swift" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

echo "wrote $OUTPUT_ICNS"
