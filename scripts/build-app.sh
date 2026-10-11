#!/bin/bash
# Release build of the app, ad-hoc signed (no team). Sparkle.framework is the one nested bundle; xcodebuild signs
# it ad hoc on embedding, and `codesign --verify --deep` below checks the whole tree.
# Built for any Mac (Apple Silicon and Intel): without a generic destination xcodebuild builds only this Mac's
# architecture. The debugger entitlement (get-task-allow) is left out of the release signature.
# Usage: scripts/build-app.sh [project-root]
set -euo pipefail
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"
mkdir -p build
xcodebuild -project app/TokenCats.xcodeproj -scheme TokenCats -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build/DerivedData CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  build -quiet > build/xcodebuild.log 2>&1 || { grep -E "error:" build/xcodebuild.log | sort -u | head -40; exit 1; }
APP="build/DerivedData/Build/Products/Release/TokenCats.app"
codesign --verify --deep "$APP"
ARCHS="$(lipo -archs "$APP/Contents/MacOS/TokenCats")"
[[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]] || { echo "error: expected arm64 and x86_64, got: $ARCHS"; exit 1; }
if codesign -d --entitlements :- "$APP" 2>/dev/null | grep -q "get-task-allow"; then
  echo "error: release signature still carries get-task-allow"; exit 1
fi
echo "built: $APP ($ARCHS)"
