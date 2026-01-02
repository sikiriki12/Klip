#!/bin/bash

# Build script for Klip.app
# Creates a distributable macOS app bundle and DMG

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

# Create DMG with Applications symlink for drag-to-install
echo ""
echo "📀 Creating DMG..."

DMG_STAGING="dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

# Copy app to staging
cp -R "$APP_DIR" "$DMG_STAGING/"

# Create symlink to Applications folder
ln -s /Applications "$DMG_STAGING/Applications"

# Create the DMG
rm -f Klip.dmg
hdiutil create -volname "Klip" -srcfolder "$DMG_STAGING" -ov -format UDZO Klip.dmg

# Clean up staging
rm -rf "$DMG_STAGING"

echo "✅ Created: Klip.dmg"
echo ""
echo "To install from DMG:"
echo "  1. Open Klip.dmg"
echo "  2. Drag Klip.app to the Applications folder"
echo "  3. Right-click → Open (first time only, to bypass Gatekeeper)"
