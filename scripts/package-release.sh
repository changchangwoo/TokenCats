#!/bin/bash
# Builds the release zip, its Homebrew cask and the Sparkle appcast locally. Publishes nothing: it prints the
# commands that do.
#   build/release/TokenCats-<version>.zip   (universal, ad-hoc signed; ditto keeps the bundle's signature)
#   build/release/tokencats.rb              (packaging/homebrew/tokencats.rb.template with version and sha256)
#   appcast.xml                             (the update feed the app reads; signed with the EdDSA key in the keychain)
#   CHANGELOG.md                            (a new section for this version from the notes, above the last one)
# Usage: scripts/package-release.sh [release-notes.md]
#   The notes file's "- " lines become the update's release notes, shown by the app before installing, and the
#   version's CHANGELOG section (the [Unreleased] section is emptied).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
scripts/build-app.sh
APP="build/DerivedData/Build/Products/Release/TokenCats.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
OUT="build/release"
ZIP="$OUT/TokenCats-$VERSION.zip"
mkdir -p "$OUT"
# Older zips would end up in the appcast too, pointing at this release's download folder: keep only this one.
rm -f "$OUT"/*.zip
ditto -c -k --keepParent "$APP" "$ZIP"
SHA="$(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
sed -e "s/\"VERSION\"/\"$VERSION\"/" -e "s/\"SHA256\"/\"$SHA\"/" packaging/homebrew/tokencats.rb.template > "$OUT/tokencats.rb"

# The appcast: generate_appcast signs every zip in the folder with the key in the keychain and embeds the notes
# next to it (<zip name>.html). Only the current zip is kept there, so the feed carries the newest version.
NOTES="${1:-}"
HTML="$OUT/TokenCats-$VERSION.html"
rm -f "$OUT"/*.html "$OUT"/*.delta
if [[ -n "$NOTES" ]]; then
  { echo "<ul>"; grep '^- ' "$NOTES" | sed -e 's/^- //' -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/^/<li>/' -e 's/$/<\/li>/'; echo "</ul>"; } > "$HTML"
fi
# generate_appcast updates an existing feed in place and keeps entries whose zips are gone, so start fresh: the
# feed lists only the version in the folder, which is all an older app needs to find.
rm -f appcast.xml
if [[ -n "$NOTES" ]]; then
  python3 - "$VERSION" "$NOTES" <<'PY'
import pathlib, re, sys, datetime
version, notes = sys.argv[1], pathlib.Path(sys.argv[2]).read_text()
log = pathlib.Path("CHANGELOG.md"); text = log.read_text()
bullets = "\n".join(line for line in notes.splitlines() if line.startswith("- "))
section = f"## [{version}] - {datetime.date.today().isoformat()}\n\n{bullets}\n\n"
if f"## [{version}]" in text:
    sys.exit(0)
text = re.sub(r"## \[Unreleased\]\n\n(?:.*\n)*?(?=## \[)", "## [Unreleased]\n\n" + section, text, count=1)
text = re.sub(r"\[Unreleased\]: (\S+?)/compare/v[\d.]+\.\.\.HEAD",
              lambda m: f"[Unreleased]: {m.group(1)}/compare/v{version}...HEAD\n[{version}]: {m.group(1)}/releases/tag/v{version}", text, count=1)
log.write_text(text)
PY
fi
GENERATE_APPCAST="$(find build/DerivedData/SourcePackages/artifacts -type f -name generate_appcast | head -1)"
[[ -n "$GENERATE_APPCAST" ]] || { echo "error: generate_appcast not found; build once so the Sparkle package is resolved"; exit 1; }
# The EdDSA key comes from the login keychain, which can stop to ask on screen; SPARKLE_ED_KEY_FILE points at
# the exported key instead (kept outside the repository) so a release can run unattended.
KEY_ARGS=()
[[ -n "${SPARKLE_ED_KEY_FILE:-}" ]] && KEY_ARGS=(--ed-key-file "$SPARKLE_ED_KEY_FILE")
"$GENERATE_APPCAST" "${KEY_ARGS[@]}" --download-url-prefix "https://github.com/changchangwoo/TokenCats/releases/download/v$VERSION/" \
  --link "https://github.com/changchangwoo/TokenCats" \
  --full-release-notes-url "https://github.com/changchangwoo/TokenCats/releases/tag/v$VERSION" \
  --embed-release-notes -o appcast.xml "$OUT"
echo "zip:     $ZIP"
echo "sha256:  $SHA"
echo "cask:    $OUT/tokencats.rb"
echo "appcast: appcast.xml (commit it with the release; the app reads it from main)"
[[ -n "$NOTES" ]] && echo "changelog: CHANGELOG.md has a $VERSION section (commit it too)"
echo
echo "To publish (the TokenCats repo must be public for anonymous downloads):"
echo "  commit appcast.xml and push main, then"
echo "  gh release create v$VERSION $ZIP --repo changchangwoo/TokenCats --title \"TokenCats $VERSION\""
echo "  copy $OUT/tokencats.rb to Casks/tokencats.rb in changchangwoo/homebrew-tap and push"
