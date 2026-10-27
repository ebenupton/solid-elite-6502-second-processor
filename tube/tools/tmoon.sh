#!/bin/sh
# tmoon.sh DIR: forced checks of the planet styles run1 does not reach: the
# system seed poked (QQ2+1, +3, +5) so that the planet has a moon and a ring
# (h = 0x41), bands, or a moon only; each window on the Master port (the
# oracle) against the Tube build in DIR on both hosts. The first frames after
# the poke may differ (the poke lands at a different point of the frame on
# the two machines). Run from the repository root.
D=$1
LOG=scratch/curious/run1/inputs.jsonl
MS=master/build/elite-master-sng47.ssd; MY=master/build/symbols.txt
T="mrbeach:p:300:QQ2+1:65;p:300:QQ2+3:0;p:300:QQ2+5:0@290-420 mrcrater:p:1000:QQ2+1:65;p:1000:QQ2+3:1;p:1000:QQ2+5:0@990-1200 mbands:p:1000:QQ2+1:65;p:1000:QQ2+3:0;p:1000:QQ2+5:0@990-1200 moononly:p:5355:QQ2+1:1;p:5355:QQ2+3:0;p:5355:QQ2+5:0@5345-5460"
for t in $T; do
  name=${t%%:*}; rest=${t#*:}; spec=${rest%@*}; win=${rest##*@}; f=${win%-*}; to=${win#*-}
  O=$D/mr-$name; mkdir -p $O
  node master/tools/agentplay/fbreplay.mjs --inject "$spec" --log $LOG --out $O/ref --cand $MS --csyms $MY --from $f --to $to > $O/ref.log 2>&1
  for H in Master B; do
    S=$D/elite-tube.ssd; [ $H = B ] && S=$D/elite-tube-b.ssd
    node tube/tools/tfbreplay.mjs --inject "$spec" --log $LOG --out $O/$H --cand $S --csyms $D/psyms.txt --host $H --from $f --to $to > $O/$H.log 2>&1
    p=$(node tube/tools/fbcmp.mjs $O/ref/fb.json $O/$H/fb.json --to $((to - 1)) 2>&1 | tail -1)
    echo "$name $H: $p"
  done
done
