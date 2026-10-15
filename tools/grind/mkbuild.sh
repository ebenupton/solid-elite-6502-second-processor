#!/bin/sh
# mkbuild.sh <root> <outdir>: build <root>'s sources in a private copy (never touches
# <root>/build): <outdir>/tree/{src,build.sh,tools/beebasm} is <root>'s, built there with
# its own build.sh (-> tree/build/elite-master.ssd, symbols.txt, compile.txt ...), then
# assembled once more with the patched BeebAsm (tools/grind/bin/beebasm-grind) for the
# provenance map.  Leaves in <outdir>:
#   tree/       the copy and its build
#   gmap.tsv    the grindmap (see tools/grind/beebasm/grindmap.patch)
#   compile.txt, symbols.txt   (the -v listing and -d dump, as build.sh makes them)
set -e
ROOT=$(cd "$1" && pwd); OUT=$2
HERE=$(cd "$(dirname "$0")" && pwd)
BA=$HERE/bin/beebasm-grind
[ -x "$BA" ] || sh "$HERE/beebasm/build.sh"
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
rm -rf "$OUT/tree"; mkdir -p "$OUT/tree/build" "$OUT/tree/tools"
cp -R "$ROOT/src" "$OUT/tree/src"
cp "$ROOT/build.sh" "$OUT/tree/build.sh"
cp "$ROOT/tools/beebasm" "$OUT/tree/tools/beebasm"
cp "$ROOT"/tools/*.py "$OUT/tree/tools/" 2>/dev/null || true
# build.sh needs no orig-symbols; keep its output for the error check
( cd "$OUT/tree" && sh ./build.sh > "$OUT/build.log" 2>&1 ) || { cat "$OUT/build.log"; echo "mkbuild: build.sh failed" >&2; exit 1; }
cp "$OUT/tree/build/compile.txt" "$OUT/compile.txt"
cp "$OUT/tree/build/symbols.txt" "$OUT/symbols.txt"
# the provenance map: the same assembly again (its SAVEs rewrite identical images)
( cd "$OUT/tree" && BEEBASM_GRINDMAP="$OUT/gmap.tsv" "$BA" -i src/elite-source.asm > /dev/null 2> "$OUT/gmap.stderr" ) || { cat "$OUT/gmap.stderr"; exit 1; }
