#!/bin/sh
# mkbuild.sh <root> <outdir>: build <root>'s full Master Elite (master/) in a private
# copy (never touches <root>/master/build): <outdir>/tree/master/{src,build.sh,tools}
# and <outdir>/tree/tools/beebasm are <root>'s, built there with master/build.sh
# (-> tree/master/build/elite-master-sng47.ssd, symbols.txt, banks.txt, compile.txt,
# the images ...), then elite-source.asm is assembled once more with the patched
# BeebAsm (tools/grind/bin/beebasm-grind, the demo port's: see tools/grind/README.md)
# for the provenance map.  Leaves in <outdir>:
#   tree/                       the copy and its build
#   gmap.tsv                    the grindmap (tools/grind/beebasm/grindmap.patch)
#   compile.txt, symbols.txt, banks.txt, symbols-data.txt   (as build.sh makes them)
set -e
ROOT=$(cd "$1" && pwd); OUT=$2
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
BA=$REPO/tools/grind/bin/beebasm-grind
[ -x "$BA" ] || sh "$REPO/tools/grind/beebasm/build.sh"
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
rm -rf "$OUT/tree"; mkdir -p "$OUT/tree/master/tools" "$OUT/tree/tools"
cp -R "$ROOT/master/src" "$OUT/tree/master/src"
cp "$ROOT/master/build.sh" "$OUT/tree/master/build.sh"
# master/tools: the build's helpers (dashboard.py, elite-checksum.py, bankcheck.py ...)
for f in "$ROOT"/master/tools/*; do
    [ "$(basename "$f")" = grind ] && continue
    cp -R "$f" "$OUT/tree/master/tools/"
done
cp "$ROOT/tools/beebasm" "$OUT/tree/tools/beebasm"
( cd "$OUT/tree" && sh master/build.sh > "$OUT/build.log" 2>&1 ) || { tail -30 "$OUT/build.log"; echo "mkbuild: master/build.sh failed" >&2; exit 1; }
if grep -iE "error|assertion failed" "$OUT/build.log" "$OUT/tree/master/build/compile.txt" > "$OUT/build.errors"; then
    cat "$OUT/build.errors"; echo "mkbuild: error/ASSERT in the build output" >&2; exit 1
fi
for f in compile.txt symbols.txt banks.txt symbols-data.txt; do
    cp "$OUT/tree/master/build/$f" "$OUT/$f"
done
# the provenance map: the same assembly again (its SAVEs rewrite identical images;
# checked below)
mkdir -p "$OUT/imgs"
for f in "$OUT"/tree/master/build/*.bin; do cp "$f" "$OUT/imgs/"; done
( cd "$OUT/tree/master" && BEEBASM_GRINDMAP="$OUT/gmap.tsv" "$BA" -i src/elite-source.asm > "$OUT/gmap.stdout" 2> "$OUT/gmap.stderr" ) || { cat "$OUT/gmap.stderr"; exit 1; }
for f in "$OUT"/imgs/*.bin; do
    cmp -s "$f" "$OUT/tree/master/build/$(basename "$f")" || { echo "mkbuild: the patched BeebAsm's $(basename "$f") differs from tools/beebasm's" >&2; exit 1; }
done
rm -rf "$OUT/imgs"
