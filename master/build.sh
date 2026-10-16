#!/bin/sh
# Build BBC Master Elite (SNG47) in-tree from master/src into master/build:
#   build/BCODE.unprot.bin, BDATA.unprot.bin (assembler output),
#   build/BCODE.bin, BDATA.bin (commander checksum, encrypted unless ENCRYPT=no),
#   build/M128Elt.bin (loader), build/README.txt,
#   build/symbols.txt (beebasm -d symbol dump of elite-source.asm; zero page,
#   workspaces and main code), build/symbols-data.txt (elite-data.asm, bank 6),
#   build/elite-master-sng47.ssd (bootable with SHIFT+BREAK on a BBC Master).
#
# Options (environment):
#   ENCRYPT=no    _REMOVE_CHECKSUMS=TRUE and no encryption (as upstream's
#                 "make encrypt=no"); the default reproduces the released game
#   MATCH=no      zero-filled workspaces (upstream "match=no")
#   VERIFY=no     skip the crc32 comparison with master/reference/sng47
#                 (default: verify, and fail on any mismatch, but only when
#                 ENCRYPT and MATCH are at their defaults)
#
# Like upstream's Makefile, but the checksum script is given the F%, G% and
# NA2% that the assembler prints, rather than the released game's values, so
# a modified source still gets a correct commander checksum and decryption.
set -e
cd "$(dirname "$0")"
BEEBASM=${BEEBASM:-../tools/beebasm}
ENCRYPT=${ENCRYPT:-yes}
MATCH=${MATCH:-yes}
VERIFY=${VERIFY:-yes}
mkdir -p build
rm -f build/*.bin build/*.ssd build/README.txt

if [ "$ENCRYPT" = no ]; then RC=TRUE; U=-u; else RC=FALSE; U=; fi
if [ "$MATCH" = no ]; then MO=FALSE; else MO=TRUE; fi
cat > build/elite-build-options.asm <<EOF
_VERSION=4
_VARIANT=1
_REMOVE_CHECKSUMS=$RC
_MATCH_ORIGINAL_BINARIES=$MO
_MAX_COMMANDER=FALSE
EOF

: > build/compile.txt
for f in loader source data readme; do
    $BEEBASM -i src/elite-$f.asm -v >> build/compile.txt 2>&1 || { tail -20 build/compile.txt; exit 1; }
done
$BEEBASM -i src/elite-source.asm -d > build/symbols.txt 2>/dev/null
$BEEBASM -i src/elite-data.asm -d > build/symbols-data.txt 2>/dev/null

F=$(sed -n 's/^F% = &\([0-9A-F]*\).*/\1/p' build/compile.txt)
G=$(sed -n 's/^G% = &\([0-9A-F]*\).*/\1/p' build/compile.txt)
N=$(sed -n 's/^NA2% = &\([0-9A-F]*\).*/\1/p' build/compile.txt)
python3 tools/elite-checksum.py $U -rel1 -d build -f "$F" -g "$G" -n "$N" > build/checksum.txt

$BEEBASM -i src/elite-disc.asm -boot M128Elt -do build/elite-master-sng47.ssd -title "E L I T E"
echo "BCODE &1300-&$F (G% &$G, NA2% &$N), encrypt=$ENCRYPT match=$MATCH"

if [ "$VERIFY" != no ] && [ "$ENCRYPT" != no ] && [ "$MATCH" != no ]; then
    python3 tools/crc32.py reference/sng47 build | tee build/crc32.txt
    if grep -q " No " build/crc32.txt || [ "$(grep -c " Yes " build/crc32.txt)" -ne 5 ]; then
        echo "VERIFY FAIL: build differs from master/reference/sng47"; exit 1
    fi
    if cmp -s build/elite-master-sng47.ssd reference/elite-master-sng47.ssd; then
        echo "disc image identical to master/reference/elite-master-sng47.ssd"
    else
        echo "note: disc image differs from master/reference/elite-master-sng47.ssd (binaries match)"
    fi
    echo "VERIFY PASS: all 5 binaries identical to the SNG47 reference"
fi
