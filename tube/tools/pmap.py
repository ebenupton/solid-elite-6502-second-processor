#!/usr/bin/env python3
# pmap.py [BUILD [OUT.json [ROOT [COMMIT]]]]: the parasite's memory map, &0000-&FFFF as the
# 6502 Second Processor sees it, from a Tube build (tube/build.sh's
# build/psyms.txt and build/compile-p.txt, and tube/src's constants): every
# region with its start, end, name, kind, place (p-layout.asm's passes),
# source files, bytes used and bytes free. The overlay region is listed once
# for each overlay (D, S) and for the boot's staging, which share it
# ("alternative": its name). BUILD defaults to tube/build, OUT to stdout,
# ROOT (the tree whose sources made the build: the constants RING and ZPSAVE
# are read from them) to the current directory, COMMIT (recorded in the map)
# to ROOT's git HEAD. docs/TUBE-MAP.md's parasite map is this, in words.
import json, os, re, subprocess, sys

B = sys.argv[1] if len(sys.argv) > 1 else "tube/build"
OUT = sys.argv[2] if len(sys.argv) > 2 else None
ROOT = sys.argv[3] if len(sys.argv) > 3 else "."
SRC = os.path.join(ROOT, "tube", "src")
MSRC = os.path.join(ROOT, "master", "src")

sy = {}
for m in re.finditer(r"'([^']+)':(\d+)", open(os.path.join(B, "psyms.txt")).read()):
    sy.setdefault(m.group(1), int(m.group(2)))
cp = open(os.path.join(B, "compile-p.txt"), encoding="latin-1").read()


def printed(pat):
    m = re.search(pat, cp)
    if not m:
        sys.exit("pmap: no %r in compile-p.txt" % pat)
    return [int(x, 16) for x in m.groups()]


def const(path, name):
    """a constant's plain hex value from a source (the parasite's: the one in
    an _TPART = 1 block if there is one)"""
    txt = open(path, encoding="latin-1").read()
    m = re.search(r"IF _TPART = 1\s*\n\s*%s\s*=\s*&([0-9A-F]+)" % re.escape(name), txt) or \
        re.search(r"^\s*%s\s*=\s*&([0-9A-F]+)" % re.escape(name), txt, re.M)
    return int(m.group(1), 16)


zp_end, = printed(r"ZP workspace from &[0-9A-F]+ to &([0-9A-F]+)")
k_end, = printed(r"K% workspace from &[0-9A-F]+ to &([0-9A-F]+)")
wp0, wp_end = printed(r"WP workspace from &([0-9A-F]+) to &([0-9A-F]+)")
RING = const(os.path.join(SRC, "p-io.asm"), "RING")
ZPSAVE = const(os.path.join(MSRC, "elite-source.asm"), "ZPSAVE")
regions = []


def reg(start, end, name, kind, area, files, used_end=None, alt=None):
    """[start, end) with [start, used_end) used"""
    u = end if used_end is None else used_end
    regions.append({"start": "&%04X" % start, "end": "&%04X" % (end - 1), "name": name, "kind": kind,
                    "area": area, "files": files, "used": u - start, "free": end - u,
                    **({"alternative": alt} if alt else {})})


# the game's workspaces at the Master port's addresses, with the Tube's pointers
# in zero page (p-rast.asm's pr_*, the ring's) and QSL in pages 2 and 3
reg(0, zp_end + 1, "game zero page", "workspace", "ZP", ["master/src/elite-source.asm"])
if zp_end + 1 < 0xE4:
    reg(zp_end + 1, 0xE4, "zero page (unused)", "free", "-", [], zp_end + 1)
reg(0xE4, 0xF9, "rasteriser pointers and scratch (pr_*)", "workspace", "ovl S", ["tube/src/p-rast.asm"])
reg(0xF9, 0xFA, "zero page (unused)", "free", "-", [], 0xF9)
reg(0xFA, 0x100, "ring pointers (rq, p_oscli's, rpz)", "workspace", "resident", ["tube/src/p-io.asm"])
reg(0x100, 0x200, "stack (XX3 at its foot)", "stack", "-", ["master/src/elite-source.asm"])
reg(0x200, 0x400, "QSL, the quarter squares' low bytes (made by p_boot)", "workspace", "QSL",
    ["master/src/elite-qs.asm", "tube/src/p-io.asm"])
reg(0x400, k_end + 1, "K%: ship data blocks", "workspace", "K%", ["master/src/elite-source.asm"])
reg(k_end + 1, wp0, "ship line heap (down from WP)", "workspace", "K%", ["master/src/elite-source.asm"])
reg(wp0, wp_end + 1, "WP: Elite's workspace, the dashboard's variables", "workspace", "WP", ["master/src/elite-source.asm"])
reg(wp_end + 1, sy["PWS_START"], "VEC (the IRQ1 vector's old value, WP's last)", "workspace", "WP", ["master/src/elite-source.asm"])
# the Tube's workspace, one run (p-ws.asm), zeroed by p_boot
ws = [("PWS_START", "hp_dfl", "PACC: the dummy ACCCON (VIA + &34)"),
      ("hp_dfl", "R_PXL", "the disc heap's flags and counts, the flare's probes, R_POLY's scratch"),
      ("R_PXL", "R_NDISCL", "the frame layer's inputs: polygons, lines, stars, the text map's row counts, scratch"),
      ("R_NDISCL", "F_HW", "row arrays R_NDISCL, R_NDX0, R_NDX1, R_NDN (page aligned)"),
      ("F_HW", "F_TM", "F_HW, F_HW2: the planet's and the sun's half-widths"),
      ("F_TM", "R_NDISCR", "F_TM: the text map"),
      ("R_NDISCR", "ss_d", "row arrays R_NDISCR, R_NDX2, R_NDX3"),
      ("ss_d", "F_BX", "S_SUN's and the second disc's places, the discs' and kept rows' scratch"),
      ("F_BX", "F_SR", "the frame layer's small state (F_BX, F_BY, f_tcol, f_zsv, F_SLV)"),
      ("F_SR", "F_RP", "F_SR: the ships' faces' levels"),
      ("F_RP", "F_DSX", "F_RP: the ship records"),
      ("F_DSX", "PWS_END", "F_DSX, F_DSY: the stars drawn directly")]
for a, b, n in ws:
    reg(sy[a], sy[b], n, "workspace", "workspace", ["tube/src/p-ws.asm"])
# the resident code and data: one run from the workspace's end, the one gap,
# then the page aligned tables, ending at the overlay region
reg(sy["PCODE_START"], sy["GLUE_END%"], "glue (p-low.asm: the stubs into overlay D, the shared variables, the G_ stubs and text hooks, "
    "the drawing hooks, the Tube's I/O, the overlay manager, the panel's game halves)", "code", "resident",
    ["tube/src/p-low.asm", "build/elite-stubs.asm", "master/src/gfx-gvars.asm", "tube/src/p-glue.asm", "master/src/gfx-hooks.asm",
     "tube/src/p-io.asm", "tube/src/p-ovl.asm", "tube/src/p-dash.asm"])
reg(sy["GLUE_END%"], sy["HZ_START"], "the run (the game's resident blocks, in the source's order)", "code", "resident",
    ["master/src/elite-source.asm"])
reg(sy["HZ_START"], sy["HZDATA_END%"], "game data (XX21, blueprints, ...)", "data", "resident", ["master/src/elite-data.asm"])
reg(sy["HZDATA_END%"], sy["HZ_END"], "hangar tables, moon and ring variables", "data", "resident",
    ["master/src/gfx-hangar6.asm", "master/src/gfx-planetv.asm"])
reg(sy["PF_START"], sy["PRES_CODE_END"], "the frame layer (parasite part), the resident parts of overlay S's files, F_INIT", "code", "resident",
    ["master/src/gfx-frame.asm", "master/src/gfx-faces.asm", "master/src/gfx-light6.asm", "master/src/gfx-light.asm",
     "master/src/gfx-frame_cold.asm", "master/src/gfx-flare.asm", "master/src/gfx-hangar.asm", "master/src/gfx-ssun.asm",
     "master/src/elite-moon.asm", "tube/src/p-probe.asm", "tube/src/p-disc.asm", "tube/src/p-poly.asm", "tube/src/p-kept.asm",
     "tube/src/p-onepass.asm", "master/src/gfx-finit.asm"])
reg(sy["PRES_CODE_END"], sy["TAB_START"], "free (the resident code's one gap)", "free", "-", [], sy["PRES_CODE_END"])
reg(sy["TAB_START"], sy["TAB_END"], "page aligned tables: log, logL, alogh, QSH", "data", "aligned",
    ["master/src/elite-source.asm", "master/src/elite-qs.asm"])
# the overlay region, D or S; the boot's staging above D at the boot
o = sy["OVL_START"]
reg(o, RING, "overlay D (direct mode)", "overlay", "ovl D",
    ["master/src/elite-source.asm", "master/src/elite-data.asm", "tube/src/p-io.asm", "tube/src/p-glue.asm",
     "master/src/gfx-hooks.asm", "master/src/gfx-frame_cold.asm", "master/src/gfx-hangar.asm"], sy["OVL_D_END"], alt="D")
reg(o, RING, "overlay S (space mode): state, then code", "overlay", "ovl S",
    ["tube/src/p-rast.asm", "tube/src/p-disc.asm", "tube/src/p-emit.asm", "tube/src/p-kept.asm", "tube/src/p-poly.asm",
     "tube/src/p-onepass.asm", "master/src/gfx-frame.asm", "master/src/gfx-flare.asm", "tube/src/p-probe.asm",
     "master/src/gfx-merid.asm", "master/src/gfx-planet7.asm", "master/src/gfx-frame_cold.asm", "master/src/gfx-hangar.asm",
     "master/src/gfx-ssun.asm", "tube/src/p-lost.asm"], sy["OVL_S_END"], alt="S")
reg(sy["OVL_D_END"], RING, "the boot's staging (p_start, p_boot, the top pages' images: boot only)", "boot", "boot",
    ["tube/src/p-io.asm", "tube/src/p-layout.asm"], sy["PSTG_END"], alt="boot")
reg(ZPSAVE + 0x90, ZPSAVE + 0x100, "ZPSAVE: getzp's buffer for zero page &90-&FF (direct mode, above overlay D)",
    "workspace", "ovl D", ["master/src/elite-source.asm"], alt="D")
reg(RING, RING + 0x400, "the command ring", "buffers", "ring", ["tube/src/p-io.asm"])
reg(0xFE00, 0xFEF0, "the page below the registers: pbl (pirq's unrolled sends), p_crash", "code", "page FE",
    ["tube/src/p-io.asm"], sy["PFE_END"])
reg(0xFEF0, 0xFF00, "Tube registers (&FEF8-&FEFF) and guard", "io", "-", [])
reg(0xFF00, 0xFFFA, "page &FF: pirq, the ring's doorbell", "code", "page FF", ["tube/src/p-io.asm"], sy["PFF_END"])
reg(0xFFFA, 0x10000, "vectors (NMI, RESET, IRQ/BRK)", "vectors", "-", ["tube/src/p-layout.asm"])

sha = sys.argv[4] if len(sys.argv) > 4 else subprocess.run(["git", "-C", ROOT, "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip() \
    if os.path.isdir(os.path.join(ROOT, ".git")) or os.path.isfile(os.path.join(ROOT, ".git")) else os.path.basename(os.path.abspath(ROOT))
doc = {"what": "the Tube parasite's memory map (tube/tools/pmap.py)", "commit": sha, "build": B,
       "free_total_resident": sum(r["free"] for r in regions if "alternative" not in r),
       "regions": regions}
s = json.dumps(doc, indent=1)
if OUT:
    open(OUT, "w").write(s + "\n")
else:
    print(s)
