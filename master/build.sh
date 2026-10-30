#!/bin/sh
# Build BBC Master Elite (SNG47) in-tree from master/src into master/build:
#   build/BCODE.unprot.bin, BDATA.unprot.bin (assembler output),
#   build/BCODE.bin, BDATA.bin (with the commander checksum set),
#   build/M128Elt.bin (loader), build/README.txt,
#   build/BANK4.bin (Elite's home bank: the data and bank 4 code),
#   build/COLD7.bin (the cold area, bank 7 from &8000), build/MERID.bin (the
#   renderer's meridian window, bank 7 after it),
#   build/HICODE.bin (main RAM &7000-&7FFF: the quarter-square tables, then the run),
#   build/HAZEL.bin (HAZEL: the hot data), build/HZDATA.bin (the same, for
#   the tools),
#   build/symbols.txt (beebasm -d symbol dump of elite-layout.asm; zero page,
#   workspaces, main code, banked code and the data), build/banks.txt (the
#   banked labels' banks),
#   build/starocc.txt (tools/starocc.py: no star shows through a fill),
#   build/elite-master-sng47.ssd (bootable with SHIFT+BREAK on a BBC Master).
#
# The copy protection is gone (Stage B, docs/MASTER-PLAN.md): the game is
# assembled with _REMOVE_CHECKSUMS=TRUE (no decryption at start-up, no
# checksum test when a commander file is loaded) and elite-checksum.py runs
# with -u (no encryption of G%..F% and of the data; it still sets the
# commander checksum in NA%), as upstream's "make encrypt=no". Relocating the
# code would otherwise have meant moving the encrypted ranges with it. The
# build therefore no longer matches the released binaries; the pristine
# sources are at commit 9a86dec (master: import pristine BBC Master Elite
# sources) and the reference disc is master/reference.
#
# Options (environment):
#   MATCH=no      zero-filled workspaces (upstream "match=no")
#   MOON=on       moons: a quarter of the systems, by the seed, have a moon,
#                 scenery fixed in space and solid (gfx-planet7.asm's pf_moon,
#                 gfx-frame.asm's f_moon, gfx-ssun.asm's MN_TURN,
#                 elite-moon.asm's MOONHIT); off by default, when no system
#                 has a moon and their code, tables and variables are
#                 assembled out
#   BANDS=on      banded planets (a quarter of the crater planets, by the seed:
#                 gfx-planet7.asm's pf_bands); off by default, when no planet
#                 has bands and their code is assembled out
#   RINGS=on      planet rings (an eighth of the systems, by the seed:
#                 gfx-planet7.asm's pf_ring, gfx-frame.asm's f_ring); off by
#                 default, when no planet has a ring and their code and
#                 variables are assembled out
#
# The checksum script is given the F%, G% and NA2% that the assembler prints,
# so a changed source still gets a correct commander checksum.
set -e
cd "$(dirname "$0")"
BEEBASM=${BEEBASM:-../tools/beebasm}
MATCH=${MATCH:-yes}
MOON=${MOON:-off}
BANDS=${BANDS:-off}
RINGS=${RINGS:-off}
mkdir -p build
rm -f build/*.bin build/*.ssd build/README.txt

RC=TRUE; U=-u
if [ "$MATCH" = no ]; then MO=FALSE; else MO=TRUE; fi
cat > build/elite-build-options.asm <<EOF
_VERSION=4
_VARIANT=1
_REMOVE_CHECKSUMS=$RC
_MATCH_ORIGINAL_BINARIES=$MO
_MAX_COMMANDER=FALSE
_PLANET_MOON=$( [ "$MOON" = on ] && echo TRUE || echo FALSE )
_PLANET_BANDS=$( [ "$BANDS" = on ] && echo TRUE || echo FALSE )
_PLANET_RINGS=$( [ "$RINGS" = on ] && echo TRUE || echo FALSE )
EOF

: > build/compile.txt
# the dashboard image and its tables (build/DIALS1.bin, build/dashtab.asm)
python3 tools/dashboard.py build > /dev/null
# gfx-light.asm's two passes (its IF LIGHTPASS blocks): L_SUN at bank 4's end
# (build/gfx-light-4.asm, elite-layout.asm), L_REC in bank 6
# (build/gfx-light-6.asm, elite-gfx.asm); the other half is assembled out,
# and the line numbers are the source's
for p in 4 6; do
  sed -e "s/^IF LIGHTPASS = $p /IF TRUE  /" -e "s/^IF LIGHTPASS = [0-9] /IF FALSE  /" src/gfx-light.asm > build/gfx-light-$p.asm
done
rm -f build/data-addresses.asm build/symbols-data.txt build/HZDATA1.bin build/HZDATA2.bin build/COLDD.bin
rm -f build/elite-source-*.asm build/elite-data-*.asm build/measure-symbols.txt build/flow.txt
# elite-source.asm's passes, low, hot and cold (docs/MASTER-MAP.md, "The source
# and its passes"): streams.py writes the copies for the measure (the hot pass
# in one copy, build/elite-source-measure.asm, and the hot data in one,
# build/elite-data-measure.asm), elite-measure.asm gives each block's size
# (build/measure-symbols.txt), then streams.py flows the hot pass and the hot
# data through their containers by those sizes and writes the copies that
# elite-layout.asm assembles (build/elite-source-config.asm, -low, -hot1,
# -hot2, -hot3, -cold; build/elite-data-hot.asm, -hot4, -cold and -bdata, the
# dashboard image, BDATA, assembled here), and build/flow.txt
python3 tools/streams.py measure >> build/compile.txt || { tail -20 build/compile.txt; exit 1; }
$BEEBASM -i src/elite-measure.asm -d > build/measure-symbols.txt 2>> build/compile.txt || { tail -20 build/compile.txt; exit 1; }
python3 tools/streams.py place >> build/compile.txt || { tail -20 build/compile.txt; exit 1; }
$BEEBASM -i build/elite-data-bdata.asm -v >> build/compile.txt 2>&1 || { tail -20 build/compile.txt; exit 1; }
$BEEBASM -i src/elite-layout.asm -v >> build/compile.txt 2>&1 || { tail -20 build/compile.txt; exit 1; }
$BEEBASM -i src/elite-layout.asm -d > build/symbols.txt 2>/dev/null
# build/banks.txt: the labels of the code in sideways RAM and the ROMSEL value
# of their bank (harness/mlib.mjs and tools/bankcheck.py read it). Each name
# once, the first file's: the game's copies come first, and a name they share
# with a scoped local label of the renderer's (.t2, .out ...) is the game's
python3 - <<'PY'
import re
seen = set()
with open("build/banks.txt", "w") as f:
    for src, bank in (("build/elite-source-hot3.asm", "4"), ("build/elite-data-hot4.asm", "4"),
                      ("build/dashtab-scan.asm", "4"), ("build/dashtab-dot.asm", "4"), ("build/dashtab-spbt.asm", "4"),
                      ("build/dashtab-ecbt.asm", "4"), ("build/dashtab-msbar.asm", "4"),
                      ("build/elite-source-cold.asm", "7"),
                      ("src/gfx-raster.asm", "5"), ("src/gfx-raster_disc.asm", "5"), ("src/gfx-raster_poly.asm", "85"),
                      ("src/gfx-raster_line.asm", "85"), ("src/gfx-raster_lcold.asm", "5"),
                      ("src/gfx-raster_disc2.asm", "5"), ("src/gfx-raster_kept.asm", "5"),
                      ("src/gfx-raster_strips.asm", "5"), ("src/gfx-raster_init.asm", "5"),
                      ("src/gfx-raster_reset.asm", "5"), ("src/gfx-raster_wspan.asm", "5"),
                      ("src/gfx-frame.asm", "6"), ("src/gfx-flare6.asm", "6"), ("src/gfx-hangar.asm", "6"),
                      ("src/gfx-faces.asm", "6"), ("src/gfx-frame_cold.asm", "6"),
                      ("src/gfx-merid.asm", "7"), ("src/gfx-kept7.asm", "7"), ("src/gfx-planet7.asm", "7"),
                      ("src/gfx-flare.asm", "7"), ("src/gfx-ssun.asm", "4"), ("src/elite-moon.asm", "4")):
        for m in re.finditer(r"^\.([A-Za-z_][\w%]*)", open(src).read(), re.M):
            if m.group(1) not in seen:
                seen.add(m.group(1))
                f.write("%s %s\n" % (m.group(1), bank))
PY
# the loader takes the game's entry point from the game's symbols
python3 - <<'PY'
import re
v = int(re.search(r"'S%':(\d+)", open("build/symbols.txt").read()).group(1))
bank = 4                                   # S%'s bank: the cold area if banks.txt says so
for l in open("build/banks.txt"):
    if l.split()[0] == "S%":
        bank = int(l.split()[1], 16)
sy = {}
for m in re.finditer(r"'([^']+)':(\d+)", open("build/symbols.txt").read()):
    sy.setdefault(m.group(1), int(m.group(2)))
with open("build/game-addresses.asm", "w") as f:
    f.write("\\ Generated by build.sh\n S%% = &%04X\n SBANK = &%02X\n" % (v, bank))
    # the renderer's files (elite-gfx.asm): HAZEL's code and their lengths
    f.write(" HZ_START = &%04X\n HZLEN = &%04X\n" % (sy["HZ_START"], sy["HZ_END"] - sy["HZ_START"]))
    f.write(" BCODEAT = &%s\n" % re.search(r"^S\.BCODE &([0-9A-F]+)", open("build/compile.txt").read(), re.M).group(1))
    f.write(" DFSST = &%04X\n DFSST2 = &%04X\n DFSIN = &%04X\n" % (sy["DFSST"], sy["DFSST2"], sy["DFSIN"]))
    f.write(" B5LEN = &%04X\n B6LEN = &%04X\n RALEN = &%04X\n" % (sy["B5_END"] - 0x8000, sy["B6_END"] - 0x8000, sy["RA_END"] - 0x8000))
    f.write(" GINIT = &%04X\n" % sy["G_INIT"])
    f.write(" C7LEN = &%04X\n" % (sy["COLD_END%"] - 0x8000))   # (the cold area, bank 7 from &8000)
    f.write(" M7AT = &%04X\n M7LEN = &%04X\n" % (sy["MERID_START"], sy["MERID_END"] - sy["MERID_START"]))   # (the meridian window, bank 7 after it)
    f.write(" HILEN = &1000\n")   # (HICODE: main RAM &7000-&7FFF, the quarter-square tables then the run)
# build/images.txt: where the loader puts each image (harness/mboot.mjs checks
# them): file, ROMSEL (hex; bit 7: ANDY) or main/shadow/hazel, start (hex), and
# "v" for images holding variables or self-modified code
with open("build/images.txt", "w") as f:
    for img, rs, at, v in (("BANK4.bin", "4", 0x8000, "v"), ("COLD7.bin", "7", 0x8000, ""),
                           ("MERID.bin", "7", sy["MERID_START"], "v"),
                           ("BANK5.bin", "5", 0x8000, "v"), ("RASTA.bin", "85", 0x8000, "v"),
                           ("BANK6.bin", "6", 0x8000, "v"),
                           ("HAZEL.bin", "hazel", sy["HZ_START"], "v"), ("HICODE.bin", "main", 0x7000, "v")):
        f.write("%s %s %04X %s\n" % (img, rs, at, v))
PY
python3 tools/bankcheck.py || exit 1
# no star can show through a fill (R_STARPLOT's rule, master/tools/starocc.py)
python3 tools/starocc.py build > build/starocc.txt || { cat build/starocc.txt; exit 1; }
for f in loader readme; do
    $BEEBASM -i src/elite-$f.asm -v >> build/compile.txt 2>&1 || { tail -20 build/compile.txt; exit 1; }
done

F=$(sed -n 's/^F% = &\([0-9A-F]*\).*/\1/p' build/compile.txt)
G=$(sed -n 's/^G% = &\([0-9A-F]*\).*/\1/p' build/compile.txt)
N=$(sed -n 's/^NA2% = &\([0-9A-F]*\).*/\1/p' build/compile.txt)
L=$(sed -n 's/^S.BCODE &\([0-9A-F]*\) .*/\1/p' build/compile.txt)
python3 tools/elite-checksum.py $U -rel1 -d build -f "$F" -g "$G" -n "$N" -l "$L" > build/checksum.txt

$BEEBASM -i src/elite-disc.asm -boot M128Elt -do build/elite-master-sng47.ssd -title "E L I T E"
E=$(sed -n 's/^S.BCODE &[0-9A-F]* *&\([0-9A-F]*\) .*/\1/p' build/compile.txt)
echo "BCODE &$L-&$E (then bank 4; F% &$F, G% &$G, NA2% &$N), match=$MATCH"
