#!/bin/bash
# Builds the release zip and its Homebrew cask locally. Publishes nothing: it prints the commands that do.
#   build/release/TokenCats-<version>.zip   (universal, ad-hoc signed; ditto keeps the bundle's signature)
#   build/release/tokencats.rb              (packaging/homebrew/tokencats.rb.template with version and sha256)
# Usage: scripts/package-release.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
scripts/build-app.sh
APP="build/DerivedData/Build/Products/Release/TokenCats.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
OUT="build/release"
ZIP="$OUT/TokenCats-$VERSION.zip"
mkdir -p "$OUT"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
SHA="$(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
sed -e "s/\"VERSION\"/\"$VERSION\"/" -e "s/\"SHA256\"/\"$SHA\"/" packaging/homebrew/tokencats.rb.template > "$OUT/tokencats.rb"
echo "zip:    $ZIP"
echo "sha256: $SHA"
echo "cask:   $OUT/tokencats.rb"
echo
echo "To publish (the tokenCats repo must be public for anonymous downloads):"
echo "  gh release create v$VERSION $ZIP --repo changchangwoo/tokenCats --title \"TokenCats $VERSION\""
echo "  copy $OUT/tokencats.rb to Casks/tokencats.rb in changchangwoo/homebrew-tap and push"
