#!/bin/sh
set -e

APP_DIR="BooConnect.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp Packaging/Info.plist "$CONTENTS_DIR/Info.plist"
cp Resources/AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
cp Resources/Dialog.icns "$RESOURCES_DIR/Dialog.icns"
cp Resources/Alert.caf "$RESOURCES_DIR/Alert.caf"
cp Resources/icon_lock.png "$RESOURCES_DIR/icon_lock.png"
cp Resources/icon_wait.png "$RESOURCES_DIR/icon_wait.png"
cp Resources/icon_shield.png "$RESOURCES_DIR/icon_shield.png"
cp Resources/vpnc-script.example "$RESOURCES_DIR/vpnc-script.example"

swiftc Source/main.swift -o "$MACOS_DIR/BooConnect"
chmod +x "$MACOS_DIR/BooConnect"
codesign --force --deep --sign - "$APP_DIR"

echo "Built $APP_DIR"
