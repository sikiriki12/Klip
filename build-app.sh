#!/bin/bash

# Build script for Klip.app
# Creates a distributable macOS app bundle

set -e

echo "🔨 Building Klip..."

# Build release version
swift build -c release

# Create app bundle structure
APP_NAME="Klip"
APP_DIR="$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Creating app bundle..."

# Clean previous build
rm -rf "$APP_DIR"

# Create directories
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp .build/release/Klip "$MACOS_DIR/"

# Copy Info.plist
cp Resources/Info.plist "$CONTENTS_DIR/"

# Copy icon
cp Resources/AppIcon.icns "$RESOURCES_DIR/"

# Copy status bar icons
cp Resources/StatusBarIcon-Black.png "$RESOURCES_DIR/"
cp Resources/StatusBarIcon-Blue.png "$RESOURCES_DIR/"

# Copy sounds if they exist
if [ -d "Resources/Sounds" ]; then
    cp -r Resources/Sounds "$RESOURCES_DIR/"
fi

# Sign the app with ad-hoc signature to prevent "app is damaged" errors
echo "🔐 Signing app..."
codesign --force --deep --sign - "$APP_DIR"

echo "✅ Built successfully: $APP_DIR"
echo ""
echo "To install:"
echo "  1. Drag $APP_DIR to /Applications"
echo "  2. Right-click → Open (first time only, to bypass Gatekeeper)"
echo ""
echo "To create a DMG for distribution:"
echo "  hdiutil create -volname Klip -srcfolder $APP_DIR -ov -format UDZO Klip.dmg"
