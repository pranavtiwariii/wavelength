#!/usr/bin/env bash
# Starts exactly one API server.
#
# PGlite is single-writer: a second process on the same .pgdata directory blocks
# forever while still holding an accepted socket, which is indistinguishable
# from a hung server. Always clear the old one first.
set -euo pipefail
cd "$(dirname "$0")/.."

PORT="${PORT:-4000}"
LOG="${LOG:-/tmp/wl-server.log}"

pgrep -f "tsx src/index.ts" | xargs kill -9 2>/dev/null || true
lsof -ti:"$PORT" | xargs kill -9 2>/dev/null || true
sleep 1

: > "$LOG"
npx tsx src/index.ts >"$LOG" 2>&1 &

for _ in $(seq 1 40); do
  if curl -sf -m 2 "http://localhost:$PORT/health" >/dev/null 2>&1; then
    echo "API up on :$PORT (log: $LOG)"
    exit 0
  fi
  sleep 0.5
done

echo "API failed to start; log:" >&2
tail -20 "$LOG" >&2
exit 1
