#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="LocalSend USB"
EXEC_NAME="LocalSendUSB"
APP_DIR="$ROOT/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
MODULE_CACHE="$ROOT/.build/module-cache"
MASTER_ICON="$ROOT/.build/AppIcon.tiff"
INFO_PLIST="$ROOT/resources/Info.plist"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$MODULE_CACHE"

xcrun swift -module-cache-path "$MODULE_CACHE" "$ROOT/scripts/GenerateIcon.swift" "$MASTER_ICON"
tiff2icns "$MASTER_ICON" "$RESOURCES_DIR/AppIcon.icns"
cp "$INFO_PLIST" "$CONTENTS_DIR/Info.plist"

xcrun swiftc \
  -module-cache-path "$MODULE_CACHE" \
  -framework SwiftUI \
  -framework AppKit \
  "$ROOT/LocalSendUSBApp.swift" \
  "$ROOT/ContentView.swift" \
  "$ROOT/SetupRunner.swift" \
  -o "$MACOS_DIR/$EXEC_NAME"

chmod +x "$MACOS_DIR/$EXEC_NAME"
codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "$APP_DIR"
