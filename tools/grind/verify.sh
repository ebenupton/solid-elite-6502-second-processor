#!/bin/sh
# verify.sh <worktree> [base]: the grind's gate for a candidate change.
#
#  1. build: ./build.sh in the worktree; FAIL on a non-zero exit or any error/ASSERT
#     message in its output;
#  2. determinism: node harness/compare.mjs --frames 3000 --lasct against the original
#     demo (the worktree's own compare.mjs, its build's disc and symbols); FAIL on a
#     FIRST DIVERGENCE (or no "identical at all" line); reports the port's TT100
#     iterations per emulated second over all 3000 (the speed table's "all" row);
#  3. rasteriser: when any src/raster*.asm differs from base (default: master; working
#     tree changes included), python3 tools/test_raster.py --quick in the worktree;
#     FAIL on a non-zero exit.
#
# Prints PASS/FAIL per step, then "VERIFY PASS <it/s>" or "VERIFY FAIL <step>"; exit
# status 0 only on PASS.  Logs go to <worktree>/scratch/grind-verify/ (compare.mjs's
# --out too, so concurrent runs in different worktrees do not collide).  compare.mjs
# takes about 3-4 minutes.
set -u
WT=$(cd "${1:?usage: verify.sh <worktree> [base]}" && pwd)
BASE=${2:-master}
LOG=$WT/scratch/grind-verify
mkdir -p "$LOG"
fail() { echo "VERIFY FAIL $1"; exit 1; }

# ---- 1. build
cd "$WT" || fail build
if ! sh ./build.sh > "$LOG/build.log" 2>&1; then
    tail -20 "$LOG/build.log"; echo "build: FAIL (exit status)"; fail build
fi
if grep -iE "error|assertion failed" "$LOG/build.log" > "$LOG/build.errors" && [ -s "$LOG/build.errors" ]; then
    cat "$LOG/build.errors"; echo "build: FAIL (error/ASSERT in output)"; fail build
fi
grep -E "^(Main code|Bank 4|HAZEL|Bank 5|Bank 6|Bank 7)" "$LOG/build.log"
echo "build: PASS"

# ---- 3 first (fast): rasteriser soak test when the rasteriser changed
RCH=$(git -C "$WT" diff --name-only "$BASE" -- 'src/raster*.asm' 2>/dev/null; \
      git -C "$WT" ls-files --others --exclude-standard -- 'src/raster*.asm' 2>/dev/null)
if [ -n "$RCH" ]; then
    echo "rasteriser changed vs $BASE: $(echo $RCH)"
    if ( cd "$WT" && python3 tools/test_raster.py --quick ) > "$LOG/test_raster.log" 2>&1; then
        tail -3 "$LOG/test_raster.log"; echo "test_raster: PASS"
    else
        tail -20 "$LOG/test_raster.log"; echo "test_raster: FAIL"; fail test_raster
    fi
else
    echo "test_raster: skipped (no src/raster*.asm change vs $BASE)"
fi

# ---- 2. determinism + speed
node "$WT/harness/compare.mjs" --frames 3000 --lasct \
    --port "$WT/build/elite-master.ssd" --psyms "$WT/build/symbols.txt" \
    --out "$LOG/compare" > "$LOG/compare.log" 2>&1
CST=$?
if grep -q "FIRST DIVERGENCE" "$LOG/compare.log"; then
    grep -A12 "FIRST DIVERGENCE" "$LOG/compare.log" | head -20; echo "compare: FAIL (divergence)"; fail compare
fi
if [ $CST -ne 0 ] || ! grep -q "Game state identical at all" "$LOG/compare.log"; then
    tail -20 "$LOG/compare.log"; echo "compare: FAIL (exit $CST / no identical-state line)"; fail compare
fi
SPEED=$(awk '$1 == "all" { v = $NF } END { print v }' "$LOG/compare.log")
grep "Game state identical" "$LOG/compare.log"
grep -E "^ *all " "$LOG/compare.log"
echo "compare: PASS (port $SPEED it/s over all 3000)"
echo "VERIFY PASS $SPEED"
exit 0
