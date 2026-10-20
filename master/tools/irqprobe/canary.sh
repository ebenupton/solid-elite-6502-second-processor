#!/bin/sh
# canary.sh [out.ssd]: build the IRQ canary disc, for checking the dashboard split on a
# real BBC Master. It is the normal build (master/build.sh, from this tree's master/src,
# in a private copy: master/build is not touched) except that the loader fills main RAM
# &7000-&71FF, the static copy of the dashboard's first character row that is shown if
# the split comes late, with solid yellow (MODE 1 byte &FF, logical colour 3), which the
# dashboard's first row hardly uses. Any late split then shows as a yellow flash across
# the top of the dashboard. Default output: /Users/ebenupton/elite-full/elite-master-full-irqcanary.ssd
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
TREE=$(cd "$HERE/../../.." && pwd)
OUT=${1:-/Users/ebenupton/elite-full/elite-master-full-irqcanary.ssd}
TMP=$(mktemp -d "${TMPDIR:-/tmp}/irqcanary.XXXXXX")
mkdir -p "$TMP/tools"
rsync -a --exclude build "$TREE/master/" "$TMP/master/"
cp "$TREE/tools/beebasm" "$TMP/tools/"
python3 - "$TMP/master" <<'PY'
import sys
m = sys.argv[1]
p = m + "/src/elite-loader.asm"; s = open(p).read()
old = """ EQUW MESS1             \\ BDATA again: the dashboard's first character row in"""
assert s.count(old) == 1
s = s.replace(old, """ EQUW MESSCN            \\ IRQ CANARY: solid yellow instead of the dashboard's first character row in""")
old = """.MESS14
"""
assert s.count(old) == 1
s = s.replace(old, """.MESSCN

 EQUS "L.CANARY FFFF1300"   \\ IRQ canary: *LOAD CANARY FFFF1300
 EQUB 13

.MESS14
""")
open(p, "w").write(s)
p = m + "/src/elite-disc.asm"; s = open(p).read()
old = """ PUTFILE "build/HICODE.bin", "HICODE", &000000, &000000
ELIF _COMPACT"""
assert s.count(old) == 1
s = s.replace(old, """ PUTFILE "build/HICODE.bin", "HICODE", &000000, &000000
 PUTFILE "canary.bin", "CANARY", &000000, &000000
ELIF _COMPACT""")
open(p, "w").write(s)
open(m + "/canary.bin", "wb").write(b"\xff" * 512)
PY
(cd "$TMP/master" && sh build.sh > build.log 2>&1) || { tail -20 "$TMP/master/build.log"; exit 1; }
cp "$TMP/master/build/elite-master-sng47.ssd" "$OUT"
echo "canary: $OUT ($(cd "$TREE" && git rev-parse --short HEAD) + yellow &7000-&71FF)"
rm -rf "$TMP"
