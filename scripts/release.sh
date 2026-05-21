#!/usr/bin/env bash
# Build a release ZIP for Quiet Finance (ad-hoc signed, unsigned distribution).
#
# Usage:
#   bash scripts/release.sh 2.6.0
#
# Produces build/QuietFinance-VERSION.zip. Install via homebrew-quietfinance tap
# which strips the quarantine xattr automatically.
set -euo pipefail

VERSION="${1:?usage: release.sh VERSION (e.g. 2.6.0)}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
ARCHIVE="$BUILD/QuietFinance.xcarchive"
APP="$ARCHIVE/Products/Applications/Quiet Finance.app"
ZIP="$BUILD/QuietFinance-${VERSION}.zip"

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

echo
echo "Artifact: $ZIP ($SIZE)"
echo "sha256:   $SHA"
echo
echo "Next steps:"
echo "  1. Create GitHub release:"
echo "       gh release create v${VERSION} '$ZIP' -R quietapps/QuietFinance \\"
echo "         --title 'Quiet Finance ${VERSION}' \\"
echo "         --notes-file CHANGELOG.md"
echo
echo "  2. Update quietapps/homebrew-quietfinance → Casks/quietfinance.rb:"
echo "       version \"${VERSION}\""
echo "       sha256 \"${SHA}\""
