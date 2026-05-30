#!/bin/bash
set -e

# Local Sparkle update test — no GitHub upload needed

cd "$(dirname "$0")/.."

# 1. Build app
bash .github/build_app.sh

# 2. Create DMG
rm -f .build/Snything-Test.dmg
hdiutil create -srcfolder ".build/Snything.app" -volname "Snything" -fs HFS+ -format UDZO ".build/Snything-Test.dmg"

# 3. Sign DMG
SIGN_UPDATE=$(find .build -name "sign_update" -type f | head -1)
SIG_OUTPUT=$($SIGN_UPDATE ".build/Snything-Test.dmg" 2>&1)
ED_SIG=$(echo "$SIG_OUTPUT" | grep "sparkle:edSignature=" | sed 's/.*sparkle:edSignature="\([^"]*\)".*/\1/')
LENGTH=$(echo "$SIG_OUTPUT" | grep "length=" | sed 's/.*length="\([^"]*\)".*/\1/')

echo "Signature: $ED_SIG"
echo "Length: $LENGTH"

# 4. Create local appcast
cat > .build/test_appcast.xml << APPCAST
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Snything Test</title>
    <item>
      <title>Version 99.99.99</title>
      <sparkle:version>9999</sparkle:version>
      <sparkle:shortVersionString>99.99.99</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <pubDate>$(date -u +"%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <enclosure
        url="http://localhost:8765/Snything-Test.dmg"
        sparkle:edSignature="$ED_SIG"
        length="$LENGTH"
        type="application/octet-stream"/>
    </item>
  </channel>
</rss>
APPCAST

# 5. Copy app và modify version để force update
rm -rf /Applications/Snything-Test.app
cp -R .build/Snything.app /Applications/Snything-Test.app
plutil -replace CFBundleVersion -string "0" /Applications/Snything-Test.app/Contents/Info.plist
plutil -replace SUFeedURL -string "http://localhost:8765/test_appcast.xml" /Applications/Snything-Test.app/Contents/Info.plist
codesign --force --deep --sign - /Applications/Snything-Test.app

# 6. Start local server
python3 -m http.server 8765 --directory .build &
SERVER_PID=$!
sleep 2

echo ""
echo "=== LOCAL TEST SERVER RUNNING ==="
echo "App: /Applications/Snything-Test.app"
echo "Feed: http://localhost:8765/test_appcast.xml"
echo "DMG:  http://localhost:8765/Snything-Test.dmg"
echo ""
echo "Open /Applications/Snything-Test.app and click 'Check for Updates...'"
echo "Expected: Sparkle shows 'Update available: v99.99.99'"
echo ""
echo "Press Enter to stop server..."
read
echo "Stopping server..."
kill $SERVER_PID 2>/dev/null
