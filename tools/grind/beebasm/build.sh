#!/bin/sh
# Build tools/grind/bin/beebasm-grind: BeebAsm 1.11 (stardot/beebasm @ ca2cc5f)
# plus grindmap.patch, which writes a per-byte provenance map (instruction/data,
# source file:line, labels, CLEAR/ORG/SAVE/COPYBLOCK) to $BEEBASM_GRINDMAP.
# Assembly output is unchanged.
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=${TMPDIR:-/tmp}/beebasm-grind-src.$$
git clone -q https://github.com/stardot/beebasm.git "$WORK"
cd "$WORK" && git checkout -q ca2cc5f
git apply "$HERE/grindmap.patch"
cd src && make code >/dev/null
mkdir -p "$HERE/../bin" && cp "$WORK/beebasm" "$HERE/../bin/beebasm-grind"
rm -rf "$WORK"
echo "built $HERE/../bin/beebasm-grind"
