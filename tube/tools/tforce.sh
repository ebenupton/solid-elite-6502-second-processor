#!/bin/sh
# tforce.sh DIR [BASEDIR]: targeted checks of paths run1 does not reach, by
# forced inputs over run1's log (fbreplay.mjs / tfbreplay.mjs --inject): each
# test's frames on the Master port (the oracle) against the Tube build in DIR
# on both hosts (pixels and dashboard), and the Tube's overlay loads (against
# BASEDIR's build, if given). Run from the repository root.
#   f8 and f5 in flight, a hyperspace countdown that ends with the short-range
#   chart up, a mis-jump into witchspace (CTRL held with PATG set), the
#   mission 1 debrief and the mission 2 briefing on docking, H while docked
set -u
D=$1; B=${2:-}
LOG=scratch/curious/run1/inputs.jsonl
MS=master/build/elite-master-sng47.ssd; MY=master/build/symbols.txt
T="f8:1100:1:DOKEY:118@1090-1160 f5:1100:1:DOKEY:116@1090-1160 chart:395:1:DOKEY:116@380-470 mjp:p:300:PATG:255;d:395:12:1@380-520 debrief:p:3400:TP:3@3480-3700 brief2:p:3400:TP:2;p:3400:GCNT:2;p:3400:TALLY+1:5@3480-3700 hdock:3590:1:DOKEY:84@3580-3640"
for t in $T; do
  name=${t%%:*}; rest=${t#*:}; spec=${rest%@*}; win=${rest##*@}; f=${win%-*}; to=${win#*-}
  case $spec in k:*|p:*|d:*) ;; *) spec="k:$spec";; esac
  O=$D/force-$name; mkdir -p $O
  node master/tools/agentplay/fbreplay.mjs --inject "$spec" --log $LOG --out $O/ref --cand $MS --csyms $MY --from $f --to $to > $O/ref.log 2>&1
  for H in Master B; do
    S=$D/elite-tube.ssd; [ $H = B ] && S=$D/elite-tube-b.ssd
    node tube/tools/tfbreplay.mjs --inject "$spec" --log $LOG --out $O/$H --cand $S --csyms $D/psyms.txt --host $H --from $f --to $to > $O/$H.log 2>&1
    p=$(node tube/tools/fbcmp.mjs $O/ref/fb.json $O/$H/fb.json --to $((to - 1)) 2>&1 | grep -o "[0-9]* mismatched" )
    q=$(node tube/tools/fbcmp.mjs $O/ref/dash.json $O/$H/dash.json --to $((to - 1)) 2>&1 | grep -o "[0-9]* mismatched" )
    l=$(grep "overlay loads" $O/$H.log | sed 's/.*: //')
    lb=""
    if [ -n "$B" ]; then
      node tube/tools/tfbreplay.mjs --inject "$spec" --log $LOG --out $O/base$H --cand $B/elite-tube$([ $H = B ] && echo -b).ssd --csyms $B/psyms.txt --host $H --from $f --to $to > $O/base$H.log 2>&1
      lb=" (base $(grep "overlay loads" $O/base$H.log | sed 's/.*: //'))"
    fi
    echo "$name $H: pixels $p, dashboard $q; loads $l$lb; $(grep -m1 poked $O/$H.log)"
  done
done
