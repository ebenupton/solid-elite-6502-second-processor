#!/bin/sh
# run_all.sh [root]: analyse (build + liveness + ranges), profile the same build, windows.
# root defaults to the grind worktree.  Outputs in scratch/grind/ of this repo.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
ROOT=${1:-/Users/ebenupton/elite-grind}
OUT=$REPO/scratch/grind
python3 "$HERE/analyse.py" --root "$ROOT" --build "$OUT/build" --out "$OUT"
node "$HERE/profile.mjs" --disc "$OUT/build/tree/build/elite-master.ssd" \
    --syms "$OUT/build/symbols.txt" --out "$OUT/profile.json"
python3 "$HERE/windows.py" --grind "$OUT"
