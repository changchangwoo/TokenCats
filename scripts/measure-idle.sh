#!/bin/bash
# Usage: scripts/measure-idle.sh ["process name"] [minutes]
# Samples CPU every 10s for N minutes and prints memory once. Close the notch panel and stay idle while it runs.
set -euo pipefail
NAME="${1:-TokenCats}"
MINUTES="${2:-10}"
PID=$(pgrep -x "$NAME" | head -1) || { echo "process $NAME not running" >&2; exit 1; }
SAMPLES=$((MINUTES * 6))
echo "date=$(date '+%Y-%m-%d %H:%M') pid=$PID minutes=$MINUTES"
echo "device=$(sysctl -n machdep.cpu.brand_string) ram=$(( $(sysctl -n hw.memsize) / 1073741824 ))GB macOS=$(sw_vers -productVersion)"
echo "power=$(pmset -g batt | head -1 | sed "s/.*'\(.*\)'.*/\1/")"
CPU_AVG=$(top -l $((SAMPLES + 1)) -s 10 -pid "$PID" -stats cpu \
  | awk '/^[0-9.]+$/ { n++; if (n > 1) { s += $1; c++; if ($1 > m) m = $1 } } END { printf "%.2f (samples=%d, max=%.1f)", (c ? s / c : 0), c, m }')
echo "avg_cpu_percent=$CPU_AVG"
echo "rss_kb=$(ps -o rss= -p "$PID" | tr -d ' ')"
footprint -p "$PID" 2>/dev/null | grep -i "footprint" | head -3 || echo "footprint unavailable"
