#!/bin/sh
# tgate.sh DIR: the Tube build's gates on a copy of the current build, in DIR
# (docs/TUBE-MAP.md, TUBE-REPORT.md's verification commands), both hosts in
# parallel: the Master port byte-identical to scratch/master-ref.ssd, the
# lockstep replay of run1 against SNG47, the pixels against the Master port's
# oracle (scratch/fbref), the disc menu, a deliberate BRK (tcrash.mjs), the station
# in front of a planet over 65536 away (tstation.mjs), and the speed windows (flight
# 1000-1400, docking 3420-3550, 0-3550, the beach balls 300-403, 5355-5457),
# the Master host's at a 4 MHz parasite, the Model B's at 3 MHz.
# Run from the repository root after master/build.sh and tube/build.sh.
# TO=N limits the lockstep and pixel runs to N iterations (default 16000).
set -u
D=$1; TO=${TO:-16000}
mkdir -p $D
cp tube/build/elite-tube.ssd tube/build/elite-tube-b.ssd tube/build/psyms.txt tube/build/hsyms.txt tube/build/hbmsyms.txt $D/
if cmp -s master/build/elite-master-sng47.ssd scratch/master-ref.ssd; then echo "master: byte-identical" > $D/master.txt; else echo "master: DIFFERS" > $D/master.txt; fi
LOG=scratch/curious/run1/inputs.jsonl
for H in Master B; do
  S=$D/elite-tube.ssd; [ $H = B ] && S=$D/elite-tube-b.ssd
  ( TUBE=$H node master/tools/agentplay/replay.mjs --run scratch/curious/run1 --out $D/rp$H --until $TO --noobserve --cand $S --csyms $D/psyms.txt > $D/lockstep-$H.txt 2>&1 ) &
  if [ $H = Master ]; then   # (the Master's internal co-processor, reachable only with ACCCON's ITU set: harness/tlib.mjs TUBEINT=1)
    ( TUBEINT=1 TUBE=$H node master/tools/agentplay/replay.mjs --run scratch/curious/run1 --out $D/rpint --until 600 --noobserve --cand $S --csyms $D/psyms.txt > $D/lockint-$H.txt 2>&1 ) &
  fi
  ( node tube/tools/tfbreplay.mjs --log $LOG --out $D/fb$H --cand $S --csyms $D/psyms.txt --host $H --from 0 --to $TO > $D/fb-$H.log 2>&1;
    node tube/tools/fbcmp.mjs scratch/fbref/fb.json $D/fb$H/fb.json --to $((TO - 1)) > $D/pixels-$H.txt 2>&1
    node tube/tools/fbcmp.mjs scratch/dashref/dash.json $D/fb$H/dash.json --to $((TO - 1)) > $D/dash-$H.txt 2>&1 ) &
  ( node tube/tools/tsavetest.mjs --host $H --disc $S --psyms $D/psyms.txt --out $D/tsave-$H > $D/tsave-$H.txt 2>&1; echo "exit $?" >> $D/tsave-$H.txt
    node tube/tools/tcrash.mjs --host $H --disc $S --psyms $D/psyms.txt 2>/dev/null | tail -1 > $D/crash-$H.txt
    node tube/tools/tstation.mjs --host $H --disc $S --psyms $D/psyms.txt --out $D/tstation-$H 2>/dev/null | tail -1 > $D/station-$H.txt ) &
  M=3; [ $H = Master ] && M=4   # (the target clocks: the Master host's internal 4 MHz co-processor, a 3 MHz one on the Model B)
  ( TUBEMHZ=$M node tube/tools/tspeed.mjs --log $LOG --kind t --host $H --cand $S --csyms $D/psyms.txt --windows 1000-1400,3420-3550,0-3550,300-403,5355-5457 > $D/speed-$H.txt 2>&1 ) &
done
wait
cat $D/master.txt
for H in Master B; do
  echo "== $H"
  grep -h "REPLAY" $D/lockstep-$H.txt | tail -1
  [ $H = Master ] && echo "internal co-processor (TUBEINT=1): $(grep -h "REPLAY" $D/lockint-$H.txt | tail -1)"
  cat $D/pixels-$H.txt
  echo "dashboard: $(cat $D/dash-$H.txt)"
  tail -1 $D/tsave-$H.txt
  cat $D/crash-$H.txt
  echo "station: $(cat $D/station-$H.txt)"
  grep -h "iterations" $D/speed-$H.txt
done
