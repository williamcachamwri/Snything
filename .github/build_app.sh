#!/bin/bash
set -e

# This script lives in .github/ — resolve paths from repo root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

APP_NAME="Snything"
BUNDLE_ID="com.snything.mac"
BUILD_DIR="${PROJECT_ROOT}/.build"
RELEASE_BIN="${BUILD_DIR}/release/${APP_NAME}"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
APP_VERSION="${APP_VERSION:-1.0.0}"

echo "Building release binary..."
swift build -c release

echo "Creating .app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${RELEASE_BIN}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Copy all resources into the .app bundle (used by Bundle.main)
if [ -d "Sources/Snything/Resources" ]; then
    echo "Copying resources..."
    cp Sources/Snything/Resources/* "${APP_BUNDLE}/Contents/Resources/" 2>/dev/null || true
fi

cat > "${APP_BUNDLE}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/williamcachamwri/Snything/main/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>YOUR_ED_PUBLIC_KEY_HERE</string>
</dict>
</plist>
EOF

if [ -f "Sources/Snything/Resources/AppIcon.icns" ]; then
    cp "Sources/Snything/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
fi

if [ -f "Snything.entitlements" ]; then
    cp "Snything.entitlements" "${APP_BUNDLE}/Contents/Resources/"
fi

# Copy Sparkle framework and helper tools into the bundle
echo "Copying Sparkle framework..."
SPARKLE_BUILD="${BUILD_DIR}/release/Sparkle"
if [ -d "${SPARKLE_BUILD}.framework" ]; then
    mkdir -p "${APP_BUNDLE}/Contents/Frameworks"
    cp -R "${SPARKLE_BUILD}.framework" "${APP_BUNDLE}/Contents/Frameworks/"
fi

# Find Sparkle artifacts from SPM
cd "${PROJECT_ROOT}"
SPARKLE_CHECK=$(swift package show-dependencies 2>/dev/null | grep "Sparkle" || true)
if [ -n "${SPARKLE_CHECK}" ]; then
    echo "Sparkle dependency found in SPM"
fi

echo "Signing app bundle..."
codesign --force --deep --sign - \
    --entitlements "Snything.entitlements" \
    "${APP_BUNDLE}"

echo "Done: ${APP_BUNDLE}"
