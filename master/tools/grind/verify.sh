#!/bin/sh
# verify.sh <worktree> [base]: the grind's gate for a candidate change to full Master
# Elite (master/src) in <worktree>.
#
#  1. rasteriser (first, as it is quick): always the soak test
#     master/tools/grind/test_raster.py --quick on the worktree's rasteriser
#     (GRIND_TREE=<worktree>), whatever changed (a data move once broke it unnoticed
#     when only rasteriser changes ran it); FAIL on a non-zero exit;
#  2. the gate proper: <worktree>/master/verify.sh 10000 (build; determinism of game
#     state against the released SNG47 disc over 10000 piloted iterations, page &0D
#     untouched; the redock, save/load and view-change regressions; the speed of both).  PASS only
#     if it prints "VERIFY PASS", "Game state identical at all" and
#     "regressions: PASS (redock, savetest, views)" and exits 0.
#
# Prints the steps, then "VERIFY PASS <ratio> <cand it/s>" (cand/ref flight iterations
# per emulated second, and the candidate's) or "VERIFY FAIL <step>" (test_raster, build,
# compare, redock, savetest, regressions); exit status 0 only on PASS.  Logs: master/verify.sh's
# in <worktree>/scratch/master-verify/ (its compare/, redock/, save/ there too, so runs
# in different worktrees do not collide), this script's in <worktree>/scratch/grind-verify/.
# About 4-6 minutes (the reference run is cached in <worktree>/scratch/master/refcache
# after the first).
set -u
WT=$(cd "${1:?usage: verify.sh <worktree> [base]}" && pwd)
# (a second argument, the base, is accepted and ignored: test_raster once ran only
# when the rasteriser differed from it)
HERE=$(cd "$(dirname "$0")" && pwd)
LOG=$WT/scratch/grind-verify
mkdir -p "$LOG"
fail() { echo "VERIFY FAIL $1"; exit 1; }

# ---- 1. rasteriser soak test, always
if GRIND_TREE="$WT" python3 "$HERE/test_raster.py" --quick > "$LOG/test_raster.log" 2>&1; then
    grep -E " ok" "$LOG/test_raster.log" | sort | uniq -c | tr '\n' ';'; echo
    echo "test_raster: PASS"
else
    tail -20 "$LOG/test_raster.log"; echo "test_raster: FAIL"; fail test_raster
fi

# ---- 2. master/verify.sh 10000
sh "$WT/master/verify.sh" 10000 > "$LOG/verify.log" 2>&1
VST=$?
cat "$LOG/verify.log"
STEP=$(sed -n 's/^VERIFY FAIL //p' "$LOG/verify.log" | tail -1)
[ -n "$STEP" ] && fail "$STEP"
[ $VST -eq 0 ] || fail "verify(exit $VST)"
grep -q "^VERIFY PASS" "$LOG/verify.log" || fail verify
grep -q "Game state identical at all" "$LOG/verify.log" || fail compare
grep -q "^regressions: PASS (redock, savetest, views)" "$LOG/verify.log" || fail regressions
set -- $(sed -n 's/^VERIFY PASS //p' "$LOG/verify.log" | tail -1)
# master/verify.sh: VERIFY PASS <ref it/s> <cand it/s> <cand/ref>
echo "VERIFY PASS $3 $2"
exit 0
