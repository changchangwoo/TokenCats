#!/bin/bash
# Restarts the built notch app.
set -euo pipefail
cd "$(dirname "$0")/.."
pkill -x "TokenCats" || true
for _ in $(seq 1 20); do pgrep -x "TokenCats" >/dev/null || break; sleep 0.25; done
pgrep -x "TokenCats" >/dev/null && pkill -9 -x "TokenCats"
sleep 0.5
open "build/DerivedData/Build/Products/Release/TokenCats.app"
sleep 3
pgrep -lx "TokenCats"
