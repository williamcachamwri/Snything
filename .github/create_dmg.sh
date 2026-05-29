#!/bin/bash
set -e

# This script lives in .github/ — resolve paths from repo root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

APP_NAME="Snything"
BUILD_DIR="${PROJECT_ROOT}/.build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DMG_OUTPUT="${BUILD_DIR}/${APP_NAME}-Release.dmg"
DMG_STAGING="/tmp/snything-dmg-staging"

echo "Creating DMG for ${APP_NAME}..."

# Clean up
rm -rf "$DMG_STAGING"
rm -f "$DMG_OUTPUT"
mkdir -p "$DMG_STAGING"

# Verify app exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: ${APP_BUNDLE} not found. Run .github/build_app.sh first."
    exit 1
fi

# Copy app
cp -R "$APP_BUNDLE" "$DMG_STAGING/"

# Create Applications symlink
ln -s /Applications "$DMG_STAGING/Applications"

# Create compressed DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_OUTPUT"

echo "DMG created: ${DMG_OUTPUT}"
ls -lh "$DMG_OUTPUT"

# Clean up staging
rm -rf "$DMG_STAGING"
