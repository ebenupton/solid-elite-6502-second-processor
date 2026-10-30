#!/bin/sh
# tscenes.sh DIR [scene ...]: the disc bench's posed scenes (tscenes.mjs) on the
# Master port (master/build) and the Tube build (tube/build, both hosts, at
# their target clocks), one run at a time, each Tube run compared frame for
# frame with the Master port's, with the disc heap's counts (drops, frames
# drawn whole). Run from the repository root after master/build.sh and
# tube/build.sh. Default: every scene.
set -u
D=$1; shift
mkdir -p $D/master $D/tube-Master $D/tube-B
cp tube/build/elite-tube.ssd tube/build/elite-tube-b.ssd tube/build/psyms.txt tube/build/hsyms.txt tube/build/hbmsyms.txt tube/build/compile-p.txt $D/
S=${*:-$(node tube/tools/tscenes.mjs --list)}
for sc in $S; do
  node tube/tools/tscenes.mjs --scene $sc --out $D/master --cand master/build/elite-master-sng47.ssd --csyms master/build/symbols.txt > $D/master/$sc.log 2>&1
  TUBEMHZ=4 node tube/tools/tscenes.mjs --scene $sc --out $D/tube-Master --cand $D/elite-tube.ssd --csyms $D/psyms.txt --tube Master > $D/tube-Master/$sc.log 2>&1
  TUBEMHZ=3 node tube/tools/tscenes.mjs --scene $sc --out $D/tube-B --cand $D/elite-tube-b.ssd --csyms $D/psyms.txt --tube B > $D/tube-B/$sc.log 2>&1
  for H in Master B; do
    echo "$H: $(node tube/tools/tscenes.mjs --cmp $D/master/$sc.json $D/tube-$H/$sc.json 2>&1)"
  done
done | tee $D/summary.txt
