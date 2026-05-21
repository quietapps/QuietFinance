#!/usr/bin/env bash
# Bump MARKETING_VERSION and CURRENT_PROJECT_VERSION in the Xcode project,
# and reset the sha256 in Casks/quietfinance.rb so release.sh can re-pin it.
#
# Usage:
#   bash scripts/bump-version.sh 2.7.0          # auto-increments build number
#   bash scripts/bump-version.sh 2.7.0 12       # explicit build number
set -euo pipefail

VERSION="${1:?usage: bump-version.sh VERSION [BUILD]}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBXPROJ="$ROOT/QuietFinance.xcodeproj/project.pbxproj"
CASK="$ROOT/Casks/quietfinance.rb"

# Derive current build number from pbxproj (uses last match)
current_build=$(grep -E 'CURRENT_PROJECT_VERSION' "$PBXPROJ" | tail -1 | grep -oE '[0-9]+' || echo "0")
BUILD="${2:-$((current_build + 1))}"

# Xcode stores MARKETING_VERSION without patch when it's x.y (e.g. "2.6").
# We write the full semver into the cask but store the Xcode-style value.
XCODE_VERSION="${VERSION%.*}"   # strip patch if it's .0
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.0$ ]] || XCODE_VERSION="$VERSION"

/usr/bin/sed -i '' -E "s/(MARKETING_VERSION = )[^;]+;/\1${XCODE_VERSION};/" "$PBXPROJ"
/usr/bin/sed -i '' -E "s/(CURRENT_PROJECT_VERSION = )[^;]+;/\1${BUILD};/" "$PBXPROJ"

/usr/bin/sed -i '' -E "s/^(  version )\".*\"/\1\"${VERSION}\"/" "$CASK"
/usr/bin/sed -i '' -E 's/^(  sha256 ).*/\1:no_check  # set by scripts\/release.sh output/' "$CASK"

echo "Bumped to ${VERSION} (build ${BUILD})."
echo "  QuietFinance.xcodeproj: MARKETING_VERSION=${XCODE_VERSION}, CURRENT_PROJECT_VERSION=${BUILD}"
echo "  Casks/quietfinance.rb:  version=\"${VERSION}\" (sha256 reset)"
echo
echo "Next:"
echo "  bash scripts/release.sh ${VERSION}"
