#!/bin/bash
# Release build of the app, ad-hoc signed (no team). Sparkle.framework is the one nested bundle; xcodebuild signs
# it ad hoc on embedding, and `codesign --verify --deep` below checks the whole tree.
# The hardened runtime stays off: it exists for notarization, and with it on, library validation refuses an ad-hoc
# signed framework ("mapping process and mapped file have different Team IDs"), so the app dies at launch. The
# build ends by launching the app once, because a signing mistake like that only shows when it runs.
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
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO ENABLE_HARDENED_RUNTIME=NO \
  build -quiet > build/xcodebuild.log 2>&1 || { grep -E "error:" build/xcodebuild.log | sort -u | head -40; exit 1; }
APP="build/DerivedData/Build/Products/Release/TokenCats.app"
codesign --verify --deep "$APP"
ARCHS="$(lipo -archs "$APP/Contents/MacOS/TokenCats")"
[[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]] || { echo "error: expected arm64 and x86_64, got: $ARCHS"; exit 1; }
if codesign -d --entitlements :- "$APP" 2>/dev/null | grep -q "get-task-allow"; then
  echo "error: release signature still carries get-task-allow"; exit 1
fi
if codesign -dvv "$APP" 2>&1 | grep -q "flags=.*runtime"; then
  echo "error: release signature has the hardened runtime flag; the ad-hoc Sparkle framework would not load"; exit 1
fi
# Smoke test: the app must still be running five seconds after launch, on an empty data folder of its own.
SMOKE_DIR="$(mktemp -d)"
NC_SUPPORT_DIR="$SMOKE_DIR" "$APP/Contents/MacOS/TokenCats" > "$SMOKE_DIR/launch.log" 2>&1 &
SMOKE_PID=$!
sleep 5
if kill -0 "$SMOKE_PID" 2>/dev/null; then
  kill "$SMOKE_PID" 2>/dev/null || true
  wait "$SMOKE_PID" 2>/dev/null || true
else
  echo "error: the release app exited within five seconds of launch:"; head -5 "$SMOKE_DIR/launch.log"; exit 1
fi
rm -rf "$SMOKE_DIR"
echo "built: $APP ($ARCHS), launched and ran"
