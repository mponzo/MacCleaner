#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/OpenCleanMyMac/.build/debug/OpenCleanPrivilegedHelper"
mkdir -p "$(dirname "$OUT")"
swiftc -parse-as-library \
  "$ROOT/Tools/OpenCleanPrivilegedHelper/main.swift" \
  -o "$OUT"
echo "Built $OUT"
"$OUT" --ping
