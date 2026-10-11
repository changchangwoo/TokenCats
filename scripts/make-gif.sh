#!/bin/zsh
# 화면 녹화(.mov, .mp4)를 README용 GIF로 바꾼다. 두 번 거쳐(팔레트 만들기 → 적용) 색이 뭉개지지 않게 한다.
# 사용: scripts/make-gif.sh <입력.mov|mp4> <출력.gif> [시작초] [길이초] [가로px] [fps]
#   기본값: 시작 0, 길이 전체, 가로 720, fps 12 (고양이 그림은 초당 8장이라 12면 충분하다)
#   색은 128개, 디더링 없이: 픽셀 그림은 색이 적고, 디더링 점이 용량만 늘린다.
# 예: scripts/make-gif.sh ~/Desktop/notch.mp4 docs/readme/notch.gif
# 레티나 녹화(2배)를 정확히 절반으로 줄이면 픽셀 그림이 번지지 않게 nearest로 줄인다.
set -euo pipefail
IN="$1"; OUT="$2"; START="${3:-0}"; DURATION="${4:-}"; WIDTH="${5:-720}"; FPS="${6:-12}"
command -v ffmpeg >/dev/null || { echo "ffmpeg가 없습니다: brew install ffmpeg" >&2; exit 1; }
PALETTE="$(mktemp -t tokencats-palette).png"
trap 'rm -f "$PALETTE"' EXIT
SRC_WIDTH="$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$IN")"
SCALER="lanczos"; [ "$SRC_WIDTH" -eq $(( WIDTH * 2 )) ] && SCALER="neighbor"
TRIM=(-ss "$START"); [ -n "$DURATION" ] && TRIM+=(-t "$DURATION")
FILTERS="fps=$FPS,scale=$WIDTH:-1:flags=$SCALER"
ffmpeg -v error -y "${TRIM[@]}" -i "$IN" -vf "$FILTERS,palettegen=stats_mode=diff:max_colors=128" "$PALETTE"
ffmpeg -v error -y "${TRIM[@]}" -i "$IN" -i "$PALETTE" \
  -lavfi "$FILTERS [x]; [x][1:v] paletteuse=dither=none:diff_mode=rectangle" -loop 0 "$OUT"
SIZE_KB=$(( $(stat -f%z "$OUT") / 1024 ))
echo "$OUT  ${SIZE_KB}KB  (가로 ${WIDTH}px, ${FPS}fps, 축소 방식 $SCALER)"
[ "$SIZE_KB" -gt 5120 ] && echo "5MB를 넘습니다. 길이를 줄이거나 가로를 줄여 보세요." >&2
exit 0
