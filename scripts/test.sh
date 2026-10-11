#!/bin/bash
# Runs the TokenCatsCore tests. Under Command Line Tools (no Xcode) Swift Testing needs explicit framework paths.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(xcode-select -p)" == *CommandLineTools* ]]; then
  F="$(xcode-select -p)/Library/Developer/Frameworks"
  exec swift test -Xswiftc -F -Xswiftc "$F" -Xswiftc -Xfrontend -Xswiftc -disable-cross-import-overlays -Xlinker -F -Xlinker "$F" -Xlinker -rpath -Xlinker "$F" "$@"
fi
exec swift test "$@"
