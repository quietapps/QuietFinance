#!/usr/bin/env bash
# Build a release ZIP for Quiet Finance (ad-hoc signed, unsigned distribution).
#
# Usage:
#   bash scripts/release.sh 2.6.0
#
# Produces build/QuietFinance-VERSION.zip, patches Casks/quietfinance.rb with
# the real sha256, and copies it to the homebrew tap if present.
set -euo pipefail

VERSION="${1:?usage: release.sh VERSION (e.g. 2.6.0)}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
ARCHIVE="$BUILD/QuietFinance.xcarchive"
APP="$ARCHIVE/Products/Applications/Quiet Finance.app"
ZIP="$BUILD/QuietFinance-${VERSION}.zip"
CASK="$ROOT/Casks/quietfinance.rb"
TAP="/opt/homebrew/Library/Taps/quietapps/homebrew-quietfinance/Casks/quietfinance.rb"

rm -rf "$BUILD"
mkdir -p "$BUILD"

echo "==> Archive (ad-hoc signed)"
xcodebuild -project "$ROOT/QuietFinance.xcodeproj" -scheme QuietFinance \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -destination 'generic/platform=macOS' \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  archive

echo "==> Zip"
ditto -c -k --keepParent "$APP" "$ZIP"

SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
SIZE=$(du -h "$ZIP" | awk '{print $1}')

echo "==> Patching Casks/quietfinance.rb"
/usr/bin/sed -i '' -E "s/^(  version )\".*\"/\1\"${VERSION}\"/" "$CASK"
/usr/bin/sed -i '' -E "s/^(  sha256 ).*/\1\"${SHA}\"/" "$CASK"

if [ -f "$TAP" ]; then
    echo "==> Copying cask to tap"
    cp "$CASK" "$TAP"
    echo "    Tap updated: $TAP"
    echo "    Commit + push:"
    echo "      cd $(dirname "$TAP")/.. && git add Casks/quietfinance.rb && git commit -m 'release: quietfinance ${VERSION}' && git push"
fi

echo
echo "Artifact: $ZIP ($SIZE)"
echo "sha256:   $SHA"
echo
echo "Next:"
echo "  gh release create v${VERSION} '$ZIP' -R quietapps/QuietFinance \\"
echo "    --title 'Quiet Finance ${VERSION}' \\"
echo "    --notes-file CHANGELOG.md"
