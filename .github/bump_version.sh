#!/bin/bash
set -e

# Auto-bump version and update appcast.xml
# Fetches latest GitHub release, increments patch, updates files.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

REPO="williamcachamwri/Snything"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

# ─── Fetch latest release ─────────────────────────────────────────────
echo "Fetching latest release from GitHub..."
LATEST_TAG=$(curl -s "$API_URL" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tag_name','v1.0.0').lstrip('v'))" 2>/dev/null || echo "1.0.0")

if [ -z "$LATEST_TAG" ]; then
    echo "Warning: Could not fetch latest release. Using fallback 1.0.0"
    LATEST_TAG="1.0.0"
fi

echo "Latest release: v${LATEST_TAG}"

# ─── Parse version ──────────────────────────────────────────────────
IFS='.' read -r MAJOR MINOR PATCH <<< "$LATEST_TAG"
MAJOR=${MAJOR:-1}
MINOR=${MINOR:-0}
PATCH=${PATCH:-0}

# ─── Bump patch (custom format: {1+}.{0-20}.{0-100}) ───────────────
PATCH=$((PATCH + 1))

if [ "$PATCH" -gt 100 ]; then
    PATCH=0
    MINOR=$((MINOR + 1))
fi

if [ "$MINOR" -gt 20 ]; then
    MINOR=0
    MAJOR=$((MAJOR + 1))
fi

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"
echo "Bumped version: v${NEW_VERSION}"

# ─── Update build_app.sh default ────────────────────────────────────
sed -i.bak "s/APP_VERSION=\"\${APP_VERSION:-[^\"]*}\"/APP_VERSION=\"\${APP_VERSION:-${NEW_VERSION}}\"/" .github/build_app.sh
rm -f .github/build_app.sh.bak

# ─── Update appcast.xml ─────────────────────────────────────────────
RELEASE_NOTES=$(curl -s "$API_URL" | python3 -c "import sys,json; b=json.load(sys.stdin).get('body',''); print(b[:500] if b else '')" 2>/dev/null || echo "")
if [ -z "$RELEASE_NOTES" ]; then
    RELEASE_NOTES="<ul><li>Bug fixes and improvements.</li></ul>"
fi

PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S +0000")

# Write Python script to temp file
cat > /tmp/update_appcast.py << 'PYEOF'
import os, sys

new_version = os.environ["NEW_VERSION"]
patch = os.environ["PATCH"]
repo = os.environ["REPO"]
pub_date = os.environ["PUB_DATE"]
notes = os.environ["RELEASE_NOTES"]

with open("appcast.xml", "r") as f:
    content = f.read()

new_item = """    <item>
      <title>Version %s</title>
      <description><![CDATA[
        <h2>What is New</h2>
        %s
      ]]></description>
      <pubDate>%s</pubDate>
      <enclosure url="https://github.com/%s/releases/download/v%s/Snything-Release.dmg" sparkle:version="%s" sparkle:shortVersionString="%s" length="0" type="application/octet-stream" sparkle:edSignature=""/>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
    </item>""" % (new_version, notes, pub_date, repo, new_version, patch, new_version)

marker = "<language>en</language>"
if marker in content:
    content = content.replace(marker, marker + "\n" + new_item, 1)
    with open("appcast.xml", "w") as f:
        f.write(content)
    print("appcast.xml updated.")
else:
    print("Warning: could not find <language>en</language> in appcast.xml")
    sys.exit(1)
PYEOF

export NEW_VERSION PATCH REPO PUB_DATE RELEASE_NOTES
python3 /tmp/update_appcast.py

# ─── Done ───────────────────────────────────────────────────────────
echo ""
echo "Updated files:"
echo "  .github/build_app.sh  → default v${NEW_VERSION}"
echo "  appcast.xml          → added v${NEW_VERSION}"
echo ""
echo "Next steps:"
echo "  1. Commit: git add -A && git commit -m \"release: v${NEW_VERSION}\""
echo "  2. Build:  bash .github/build_app.sh"
echo "  3. Tag:    git tag v${NEW_VERSION} && git push origin v${NEW_VERSION}"
echo "  4. Upload: .build/Snything-Release.dmg to GitHub Releases"
