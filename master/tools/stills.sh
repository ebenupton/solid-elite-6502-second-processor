#!/bin/sh
# master/tools/stills.sh [planets] [sunnear]: the stills of screenshots/planets
# and screenshots/sunnear from the build in master/build (harness/mplanet.mjs
# and master/tools/planetvis.py; harness/msunnear.mjs and
# master/tools/sunnear.py). Headless (jsbeeb). Each planet still is the last
# frame of a short posed scene; the seeds are the systems' QQ2 (s0 lo, hi, s1
# lo, hi, s2 lo, hi): Leesti's for the craters.
set -u
cd "$(dirname "$0")/../.." || exit 1
T=$(pwd)
W=$T/scratch/stills; mkdir -p "$W"
what=${*:-planets sunnear}
LEESTI=38,BA,7C,0D,5D,41
pl() {      # pl name args...: a scene, its last frame as screenshots/planets/name.png
    n=$1; shift
    node harness/mplanet.mjs --tree "${TREE:-$T}" --out "$W/$n" --from 300 --n 6 "$@" > "$W/$n.log" 2>&1 &&
    python3 master/tools/planetvis.py "$W/$n" "screenshots/planets/$n.png" 305 > /dev/null
}
case "$what" in *planets*)
    pl beach --type 128 --x 128 --y 96 --r 70 --pose 20,30,0 &
    pl caps --type 130 --qq2 $LEESTI --x 128 --y 96 --r 70 --pose 20,30,0 &
    pl caps2 --type 130 --qq2 38,BA,7C,0D,5D,41 --x 120 --y 100 --r 50 --pose 0,60,20 --spin 5 &
    wait ;;
esac
case "$what" in *sunnear*)
    node harness/msunnear.mjs --out "$W/sunnear" > "$W/sunnear.log" 2>&1
    python3 master/tools/sunnear.py "$W/sunnear" screenshots/sunnear/frames --sheet 0,12,24,36,48,60,76,88,100,112,124,140 \
        --mp4 screenshots/sunnear/sunnear.mp4 --gif screenshots/sunnear/sunnear.gif > /dev/null
    [ -f screenshots/sunnear/frames/sheet.png ] && mv screenshots/sunnear/frames/sheet.png screenshots/sunnear/sheet.png
    node harness/msunnear.mjs --spawn --out "$W/spawn" > "$W/spawn.log" 2>&1
    python3 master/tools/sunnear.py "$W/spawn" "$W/spawnpng" > /dev/null
    last=$(ls "$W/spawnpng"/frame-*.png | tail -1); cp "$last" screenshots/sunnear/spawn.png ;;
esac
