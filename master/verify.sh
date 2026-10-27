#!/bin/sh
# master/verify.sh [iterations] [mcompare options...]: the gate for a change to
# BBC Master Elite (master/src), for Stages B onwards of docs/MASTER-PLAN.md.
#
#  1. build: master/build.sh (a changed source no longer matches the
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
# From Stage C on (the renderer replaces Master's drawing) mcompare runs with
# --loose: drawing temporaries, the planet's and sun's line heaps and the
# ship line heap stop being game state (see harness/mlib.mjs DRAW_EXCLUDE;
# the renderer records what it draws instead of keeping EOR lines on the
# heaps). STRICT=1 runs without it.
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
if ! sh master/build.sh > "$LOG/build.log" 2>&1; then
    tail -20 "$LOG/build.log"; echo "build: FAIL (exit status)"; fail build
fi
if grep -iE "error|assertion failed" "$LOG/build.log" master/build/compile.txt > "$LOG/build.errors" && [ -s "$LOG/build.errors" ]; then
    cat "$LOG/build.errors"; echo "build: FAIL (error/ASSERT in output)"; fail build
fi
grep "^BCODE" "$LOG/build.log"
python3 master/tools/crc32.py master/reference/sng47 master/build > "$LOG/crc32.txt"
SAME=$(grep -c " Yes " "$LOG/crc32.txt")
echo "build: PASS ($SAME of 5 binaries identical to the SNG47 reference)"
# the lens flare's tables as their generator makes them (master/tools/flare.py)
python3 master/tools/flare.py --verify > "$LOG/flare.log" 2>&1 || { cat "$LOG/flare.log"; echo "flare tables: FAIL"; fail flare; }

# ---- 2 and 3. determinism and speed
LOOSE=--loose; [ "${STRICT:-0}" = 1 ] && LOOSE=
node harness/mcompare.mjs --iters "$ITERS" $LOOSE \
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
# ---- 4. regressions: with real key presses, dock, launch, dock again (the
# hangar's ships once wrote over the glue code), and save, load, a load error,
# catalogue (the disc glue); a save's bytes against SNG47's; the station in front of a far planet; with the
# pilot, changes of view; the ships the ship audit flagged, posed
node harness/mredock.mjs --out "$LOG/redock" > "$LOG/redock.log" 2>&1
grep -E "^docking|^REDOCK" "$LOG/redock.log"
grep -q "^REDOCK PASS" "$LOG/redock.log" || { echo "redock: FAIL"; fail redock; }
node harness/msavetest.mjs --out "$LOG/save" > "$LOG/save.log" 2>&1 || { tail -5 "$LOG/save.log"; echo "savetest: FAIL"; fail savetest; }
# saves byte-identical: the same commander saved on SNG47 and on this build,
# the files (and their catalogue entries) compared byte for byte
node harness/msavebytes.mjs --ref master/reference/elite-master-sng47.ssd --rsyms master/reference/symbols.txt \
    --cand master/build/elite-master-sng47.ssd --csyms master/build/symbols.txt \
    --out "$LOG/savebytes" > "$LOG/savebytes.log" 2>&1
grep -E "^savebytes:|^SAVEBYTES" "$LOG/savebytes.log"
grep -q "^SAVEBYTES PASS" "$LOG/savebytes.log" || { tail -5 "$LOG/savebytes.log"; echo "savebytes: FAIL"; fail savebytes; }
# the station in front of a planet just over 65536 away (a docking run with the
# planet behind the station) must be drawn: F_PLANET once kept 16 bits of the
# planet's z, and f_behind hid the station behind it
node harness/mstation.mjs --out "$LOG/station" > "$LOG/station.log" 2>&1
grep -E "^[0-9]+ iterations" "$LOG/station.log"
grep -q "^STATION PASS" "$LOG/station.log" || { echo "station: FAIL"; fail station; }
# changes of space view in flight (the gate's pilot never changes view): the
# pilot looks rear, left, right and front again every 50 flight iterations,
# against the reference over 1500 iterations (LOOK1 once fell into DEATH)
node harness/mcompare.mjs --iters 1500 $LOOSE --views --maxsecs 400 \
    --cand master/build/elite-master-sng47.ssd --csyms master/build/symbols.txt \
    --out "$LOG/views" > "$LOG/views.log" 2>&1
grep -q "^MCOMPARE PASS" "$LOG/views.log" || { grep -A8 "FIRST DIVERGENCE" "$LOG/views.log" | head -10; echo "views: FAIL"; fail views; }
# the ship audit's flagged poses (the missile's fins, the splinter's faces),
# in flight, in both handednesses: nothing drawn outside the ship, its body
# covered, its front faces and no others filled
node harness/mshippose.mjs --disc master/build/elite-master-sng47.ssd --syms master/build/symbols.txt \
    --out "$LOG/shippose" > "$LOG/shippose.log" 2>&1
grep -q "^SHIPPOSE PASS" "$LOG/shippose.log" || { grep "BAD" "$LOG/shippose.log" | head -10; echo "shippose: FAIL"; fail shippose; }
echo "regressions: PASS (redock, savetest, savebytes, station, views, shippose)"
ALL=$(grep -E "^ +all " "$LOG/compare.log")
echo "speed (flight it/s, ref cand cand/ref): $ALL"
set -- $ALL
echo "VERIFY PASS $3 $4 $5"
exit 0
