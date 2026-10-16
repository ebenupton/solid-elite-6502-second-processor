#!/bin/sh
# master/verify.sh [iterations] [mcompare options...]: the gate for a change to
# BBC Master Elite (master/src), for Stages B onwards of docs/MASTER-PLAN.md.
#
#  1. build: master/build.sh (VERIFY=no: a changed source no longer matches the
#     released binaries); FAIL on a non-zero exit or an error/ASSERT message.
#     Reports whether the five binaries still match master/reference/sng47.
#  2. determinism: node harness/mcompare.mjs --iters N (default 10000) of the
#     released SNG47 disc (master/reference, with master/reference/symbols.txt)
#     against the new build (its own symbols), both flown by the same pilot;
#     FAIL on a divergence of game state, or a run that stops early.
#  3. speed: the flight-loop iterations per emulated second over the whole run,
#     reference and candidate, and their ratio (reported, not gated; the
#     per-window table is in the log).
#
# Extra arguments go to mcompare.mjs (for example --loose once the drawing
# changes, to exclude drawing temporaries). Prints PASS/FAIL per step, then
# "VERIFY PASS <ref it/s> <cand it/s> <ratio>" or "VERIFY FAIL <step>"; exit
# status 0 only on PASS. Logs go to scratch/master-verify/. 10000 iterations
# take about 4 minutes.
set -u
cd "$(dirname "$0")/.." || exit 1
WT=$(pwd)
ITERS=${1:-10000}
[ $# -gt 0 ] && shift
LOG=$WT/scratch/master-verify
mkdir -p "$LOG"
fail() { echo "VERIFY FAIL $1"; exit 1; }

# ---- 1. build
if ! VERIFY=no sh master/build.sh > "$LOG/build.log" 2>&1; then
    tail -20 "$LOG/build.log"; echo "build: FAIL (exit status)"; fail build
fi
if grep -iE "error|assertion failed" "$LOG/build.log" master/build/compile.txt > "$LOG/build.errors" && [ -s "$LOG/build.errors" ]; then
    cat "$LOG/build.errors"; echo "build: FAIL (error/ASSERT in output)"; fail build
fi
grep "^BCODE" "$LOG/build.log"
python3 master/tools/crc32.py master/reference/sng47 master/build > "$LOG/crc32.txt"
SAME=$(grep -c " Yes " "$LOG/crc32.txt")
echo "build: PASS ($SAME of 5 binaries identical to the SNG47 reference)"

# ---- 2 and 3. determinism and speed
node harness/mcompare.mjs --iters "$ITERS" \
    --cand master/build/elite-master-sng47.ssd --csyms master/build/symbols.txt \
    --out "$LOG/compare" "$@" > "$LOG/compare.log" 2>&1
CST=$?
grep -E "^Pilot \(ref\)" "$LOG/compare.log"
if grep -q "FIRST DIVERGENCE" "$LOG/compare.log"; then
    grep -A14 "FIRST DIVERGENCE" "$LOG/compare.log" | head -24; echo "compare: FAIL (divergence)"; fail compare
fi
if [ $CST -ne 0 ] || ! grep -q "^MCOMPARE PASS" "$LOG/compare.log"; then
    tail -20 "$LOG/compare.log"; echo "compare: FAIL (exit $CST)"; fail compare
fi
grep "Game state identical" "$LOG/compare.log"
echo "compare: PASS"
ALL=$(grep -E "^ +all " "$LOG/compare.log")
echo "speed (flight it/s, ref cand cand/ref): $ALL"
set -- $ALL
echo "VERIFY PASS $3 $4 $5"
exit 0
