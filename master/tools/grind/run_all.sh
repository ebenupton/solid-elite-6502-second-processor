#!/bin/sh
# run_all.sh [root]: analyse (build + liveness + ranges), profile the same build over
# the gate's run, windows.  root defaults to the tree this script is in; outputs in
# <this tree>/scratch/grind/ (logs: analyse.log, profile.log, windows.log there).
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
ROOT=$(cd "${1:-$REPO}" && pwd)
OUT=$REPO/scratch/grind
mkdir -p "$OUT"
T0=$(date +%s)
python3 "$HERE/analyse.py" --root "$ROOT" --build "$OUT/build" --out "$OUT" 2>&1 | tee "$OUT/analyse.log"
T1=$(date +%s)
node "$HERE/profile.mjs" --root "$ROOT" --disc "$OUT/build/tree/master/build/elite-master-sng47.ssd" \
    --syms "$OUT/build/tree/master/build/symbols.txt" --out "$OUT/profile.json" 2>&1 | tee "$OUT/profile.log"
T2=$(date +%s)
python3 "$HERE/windows.py" --grind "$OUT" 2>&1 | tee "$OUT/windows.log"
T3=$(date +%s)
echo "run_all: analyse $((T1 - T0)) s, profile $((T2 - T1)) s, windows $((T3 - T2)) s, total $((T3 - T0)) s"
