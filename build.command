#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="FirePlayer"
VERSION="1.8.0"
MIN_MACOS="12.0"
APP_DIR="$PWD/${APP_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

pause_and_exit() {
  local code="${1:-0}"
  echo
  read -r -p "按回车退出..." || true
  exit "$code"
}

if ! command -v swiftc >/dev/null 2>&1; then
  echo "没有找到 swiftc。请先在终端运行："
  echo "xcode-select --install"
  pause_and_exit 1
fi

HOST_ARCH="$(uname -m)"
TARGET_ARCH="${FIREPLAYER_TARGET_ARCH:-$HOST_ARCH}"
case "$TARGET_ARCH" in
  x86_64) CHIP_NAME="Intel" ;;
  arm64) CHIP_NAME="Apple Silicon" ;;
  *)
    echo "不支持的输出架构：$TARGET_ARCH"
    echo "可用值：arm64 或 x86_64"
    pause_and_exit 1
    ;;
esac

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
if [[ -z "$SDK_PATH" ]]; then
  echo "找不到 macOS SDK，请先运行：xcode-select --install"
  pause_and_exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

echo "正在编译 FirePlayer $VERSION..."
echo "当前电脑架构：$HOST_ARCH"
echo "输出架构：$TARGET_ARCH ($CHIP_NAME)"
echo "最低系统：macOS $MIN_MACOS"
echo

swiftc FirePlayer.swift \
  -sdk "$SDK_PATH" \
  -target "${TARGET_ARCH}-apple-macosx${MIN_MACOS}" \
  -framework AppKit \
  -framework AVFoundation \
  -framework UniformTypeIdentifiers \
  -O \
  -o "$MACOS/$APP_NAME"

if [[ -f "AppIcon.png" ]]; then
  ICONSET="$PWD/AppIcon-${TARGET_ARCH}.iconset"
  rm -rf "$ICONSET" && mkdir -p "$ICONSET"
  sips -z 16 16 AppIcon.png --out "$ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32 AppIcon.png --out "$ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 AppIcon.png --out "$ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64 AppIcon.png --out "$ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 AppIcon.png --out "$ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256 AppIcon.png --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 AppIcon.png --out "$ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512 AppIcon.png --out "$ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 AppIcon.png --out "$ICONSET/icon_512x512.png" >/dev/null
  cp AppIcon.png "$ICONSET/icon_512x512@2x.png"
  iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"
  rm -rf "$ICONSET"
fi

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>FirePlayer</string>
<key>CFBundleDisplayName</key><string>FirePlayer</string>
<key>CFBundleIdentifier</key><string>com.fireplace.fireplayer</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleExecutable</key><string>FirePlayer</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

chmod +x "$MACOS/$APP_NAME"
/usr/bin/codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
/usr/bin/touch "$APP_DIR"

ACTUAL_ARCH="$(/usr/bin/file "$MACOS/$APP_NAME" 2>/dev/null || true)"

echo
echo "构建完成：$APP_DIR"
echo "处理器：$CHIP_NAME"
echo "最低系统：macOS $MIN_MACOS"
echo "$ACTUAL_ARCH"
echo
echo "这台 Intel MacBook Pro（macOS 12.7.6）会自动生成 x86_64 版本。"
if [[ "${CI:-}" != "true" ]]; then
  open "$PWD"
  pause_and_exit 0
fi
