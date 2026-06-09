#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="ConsoleMac"
DISPLAY_NAME="Console"
BUNDLE_ID="com.bookme.ConsoleMac"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$DISPLAY_NAME.app"
DOWNLOADS_DIR="$HOME/Downloads"
PACKAGE_STAMP="${PACKAGE_STAMP:-$(date +%Y%m%d-%H%M%S)}"
DOWNLOADS_APP_BUNDLE="$DOWNLOADS_DIR/ConsoleMac-Improved-$PACKAGE_STAMP.app"
DOWNLOADS_ZIP="$DOWNLOADS_DIR/ConsoleMac-Improved-$PACKAGE_STAMP.zip"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_PLUGINS="$APP_CONTENTS/PlugIns"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
PROJECT_RESOURCES="$ROOT_DIR/Sources/ConsoleMac/Resources"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
MLX_METAL_ROOT="$ROOT_DIR/.build/checkouts/mlx-swift/Source/Cmlx/mlx-generated/metal"
MLX_METAL_BUILD_DIR="$ROOT_DIR/.build/console-mlx-metal"
MLX_METALLIB="$MLX_METAL_BUILD_DIR/default.metallib"

cd "$ROOT_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

for RESOURCE_BUNDLE in "$(swift build --show-bin-path)"/${APP_NAME}_*.bundle; do
  if [[ -d "$RESOURCE_BUNDLE" ]]; then
    rm -rf "$APP_RESOURCES/$(basename "$RESOURCE_BUNDLE")"
    cp -R "$RESOURCE_BUNDLE" "$APP_RESOURCES/"
  fi
done

if [[ -f "$PROJECT_RESOURCES/AppIcon.icns" ]]; then
  cp "$PROJECT_RESOURCES/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
fi

if [[ -d "$PROJECT_RESOURCES/AppIcon.icon" ]]; then
  ditto "$PROJECT_RESOURCES/AppIcon.icon" "$APP_RESOURCES/AppIcon.icon"
fi

stage_mlx_metallib() {
  if [[ ! -d "$MLX_METAL_ROOT" ]]; then
    echo "warning: MLX Metal sources not found at $MLX_METAL_ROOT" >&2
    return
  fi

  rm -rf "$MLX_METAL_BUILD_DIR"
  mkdir -p "$MLX_METAL_BUILD_DIR/air"

  local metal_file
  local rel
  local air_file
  while IFS= read -r metal_file; do
    rel="${metal_file#$MLX_METAL_ROOT/}"
    air_file="$MLX_METAL_BUILD_DIR/air/${rel//\//_}.air"
    xcrun -sdk macosx metal \
      -x metal \
      -Wall \
      -Wextra \
      -fno-fast-math \
      -Wno-c++17-extensions \
      -Wno-c++20-extensions \
      -mmacosx-version-min="$MIN_SYSTEM_VERSION" \
      -c "$metal_file" \
      -I"$MLX_METAL_ROOT" \
      -o "$air_file"
  done < <(find "$MLX_METAL_ROOT" -name '*.metal' -type f | sort)

  xcrun -sdk macosx metallib "$MLX_METAL_BUILD_DIR"/air/*.air -o "$MLX_METALLIB"
  cp "$MLX_METALLIB" "$APP_MACOS/mlx.metallib"
}

stage_mlx_metallib

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>ITSAppUsesNonExemptEncryption</key>
  <false/>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.developer-tools</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSDesktopFolderUsageDescription</key>
  <string>Console searches local files you choose or allow so local coding models can answer with project context.</string>
  <key>NSDocumentsFolderUsageDescription</key>
  <string>Console searches local files you choose or allow so local coding models can answer with project context.</string>
  <key>NSDownloadsFolderUsageDescription</key>
  <string>Console searches local files you choose or allow so local coding models can answer with project context.</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

sign_code() {
  local target="$1"
  local args=(--force)

  args+=(--sign "$SIGN_IDENTITY" "$target")
  /usr/bin/codesign "${args[@]}"
}

if [[ -d "$APP_FRAMEWORKS" ]]; then
  while IFS= read -r RUNTIME_LIBRARY; do
    sign_code "$RUNTIME_LIBRARY"
  done < <(find "$APP_FRAMEWORKS" -type f -name '*.dylib' -print)
fi

if [[ -d "$APP_PLUGINS" ]]; then
  while IFS= read -r RUNTIME_PLUGIN; do
    sign_code "$RUNTIME_PLUGIN"
  done < <(find "$APP_PLUGINS" -type f -name '*.so' -print)
fi

while IFS= read -r METAL_LIBRARY; do
  sign_code "$METAL_LIBRARY"
done < <(find "$APP_CONTENTS" -type f -name '*.metallib' -print)

sign_code "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

package_for_downloads() {
  mkdir -p "$DOWNLOADS_DIR"
  rm -rf "$DOWNLOADS_APP_BUNDLE" "$DOWNLOADS_ZIP"
  ditto "$APP_BUNDLE" "$DOWNLOADS_APP_BUNDLE"
  ditto -c -k --keepParent "$DOWNLOADS_APP_BUNDLE" "$DOWNLOADS_ZIP"
  echo "Packaged app: $DOWNLOADS_APP_BUNDLE"
  echo "Packaged zip: $DOWNLOADS_ZIP"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 2
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --package|package)
    package_for_downloads
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--package]" >&2
    exit 2
    ;;
esac
