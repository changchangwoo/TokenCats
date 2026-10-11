#!/bin/zsh
# Debug 빌드로 프로필 카드 5종(SVG)과 화면 5장, 온보딩 시안 12장(PNG)을 뽑는다. 리팩토링 전후 비교용.
# 데이터는 고정 사본(NC_SUPPORT_DIR)을 읽는다: 기준 폴더에 support/가 없으면 지금 데이터를 거기에 복사해 둔다.
# 사용: scripts/snapshot.sh <out-dir> [--no-build]   (기준 폴더: $TOKENCATS_SNAPSHOT_BASE, 기본 ~/.cache/tokencats/snapshot-base)
# 앱에 인자를 더 넘기려면 TOKENCATS_LAUNCH_ARGS="-companionLanguage en" 처럼 준다.
set -euo pipefail
OUT="$1"; mkdir -p "$OUT/cards" "$OUT/screens" "$OUT/onboarding"
BASE="${TOKENCATS_SNAPSHOT_BASE:-$HOME/.cache/tokencats/snapshot-base}"
SUPPORT="$BASE/support"
LIVE="$HOME/Library/Application Support/TokenCats"
if [ ! -d "$SUPPORT" ]; then
  mkdir -p "$SUPPORT"
  # A machine without data (fresh checkout, CI) snapshots an empty room; that is still a valid baseline.
  [ -d "$LIVE" ] && rsync -a --exclude 'companion.sock' --exclude 'backups' "$LIVE/" "$SUPPORT/"
fi
# 적용 배경은 UserDefaults(실행 중인 앱과 공유)에서 오므로, 기준 폴더에 적어 둔 값을 인자로 고정한다.
if [ ! -f "$BASE/theme" ]; then defaults read io.github.changchangwoo.tokencats roomThemeID 2>/dev/null > "$BASE/theme" || echo cozy > "$BASE/theme"; fi
THEME="$(cat "$BASE/theme")"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$(ls -d "$ROOT"/app/*.xcodeproj | head -1)"
SCHEME="$(basename "$PROJECT" .xcodeproj)"
if [ "${2:-}" != "--no-build" ]; then
  xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
    -derivedDataPath "$ROOT/build/DerivedData" build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
fi
APP="$(ls -d "$ROOT"/build/DerivedData/Build/Products/Debug/*.app | head -1)"
BIN="$APP/Contents/MacOS/$(basename "$APP" .app)"

# run <dir> <expected-file-count> [ENV=VALUE ...]
run() {
  local dir="$1" want="$2"; shift 2
  env NC_SNAPSHOT_DIR="$dir" NC_SUPPORT_DIR="$SUPPORT" "$@" "$BIN" -roomThemeID "$THEME" ${=TOKENCATS_LAUNCH_ARGS:-} >/dev/null 2>&1 &
  local pid=$!
  for _ in $(seq 1 90); do
    [ "$(find "$dir" -type f | wc -l | tr -d ' ')" -ge "$want" ] && break
    sleep 1
  done
  sleep 2; kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
}
run "$OUT/cards" 5 NC_SNAPSHOT_CARDS=1
run "$OUT/screens" 5
run "$OUT/onboarding" 12 NC_SNAPSHOT_ONBOARDING=1 NC_SNAPSHOT_CARD_SVG="$ROOT/docs/design/card-example.svg"
ls "$OUT/cards" "$OUT/screens" "$OUT/onboarding"
