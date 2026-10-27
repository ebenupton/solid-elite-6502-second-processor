#!/usr/bin/env python3
# pmap.py [BUILD [OUT.json [ROOT [COMMIT]]]]: the parasite's memory map, &0000-&FFFF as the
# 6502 Second Processor sees it, from a Tube build (tube/build.sh's
# build/psyms.txt and build/compile-p.txt, tube/src's constants and the
# stream copies): every region with its start, end, name, kind, pass/area,
# source files, bytes used and bytes free. The overlay region is listed once
# for each overlay (D, S) and for the boot's staging, which share it
# ("alternative": its name). BUILD defaults to tube/build, OUT to stdout,
# ROOT (the tree whose sources made the build: the constants RING, VIA and
# ZPSAVE are read from them) to the current directory, COMMIT (recorded in
# the map) to ROOT's git HEAD.
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
    """a constant's value from a source (the parasite's branch: the last
    plain hex assignment, or the one in an _TPART = 1 block)"""
    txt = open(path, encoding="latin-1").read()
    m = re.search(r"IF _TPART = 1\s*\n\s*%s\s*=\s*([^\\\n]+)" % re.escape(name), txt) or \
        re.search(r"^\s*%s\s*=\s*([^\\\n]+)" % re.escape(name), txt, re.M)
    e = m.group(1).strip().replace("&", "0x")
    return int(eval(e, {}, {}))


def first_label(path):
    for l in open(path, encoding="latin-1"):
        m = re.match(r"^\.([A-Za-z_][\w%]*)", l)
        if m and m.group(1) in sy:
            return sy[m.group(1)]
    return None


code0, = printed(r"Parasite: code &&?([0-9A-F]+) ")
run_end, = printed(r"run and Master's drawing end at &&?([0-9A-F]+)")
zp_end, = printed(r"ZP workspace from &([0-9A-F]+) to &([0-9A-F]+)")[1:]
k_end, = printed(r"K% workspace from &[0-9A-F]+ to &([0-9A-F]+)")
wp0, wp_end = printed(r"WP workspace from &([0-9A-F]+) to &([0-9A-F]+)")
RING = const(os.path.join(SRC, "p-io.asm"), "RING")
m = re.search(r"IF _PLANET_RINGS\s*\nRING\s*=\s*&([0-9A-F]+).*?\nELSE.*?\nRING\s*=\s*&([0-9A-F]+)",
              open(os.path.join(SRC, "p-io.asm"), encoding="latin-1").read(), re.S)
if m:                                  # (RING by the build's RINGS switch)
    rings = "_PLANET_RINGS=TRUE" in open(os.path.join(B, "elite-build-options.asm")).read()
    RING = int(m.group(1 if rings else 2), 16)
VIA = const(os.path.join(MSRC, "elite-source.asm"), "VIA")
ZPSAVE = const(os.path.join(MSRC, "elite-source.asm"), "ZPSAVE")
b4 = first_label(os.path.join(B, "elite-source-bank4.asm"))
regions = []


def reg(start, end, name, kind, area, files, used_end=None, alt=None):
    """[start, end) with [start, used_end) used"""
    u = end if used_end is None else used_end
    regions.append({"start": "&%04X" % start, "end": "&%04X" % (end - 1), "name": name, "kind": kind,
                    "area": area, "files": files, "used": u - start, "free": end - u,
                    **({"alternative": alt} if alt else {})})


# zero page: the game's, then the Tube's pointers (p-rast.asm's pr_*, the ring's)
zpt = sorted(v for k, v in sy.items() if k.startswith("pr_") and v < 0x100)
reg(0, zp_end + 1, "game zero page", "workspace", "ZP", ["master/src/elite-source.asm"])
if zp_end + 1 < 0xE4:
    reg(zp_end + 1, 0xE4, "zero page (unused)", "free", "-", [], zp_end + 1)
reg(0xE4, 0xF9, "rasteriser pointers and scratch (pr_*)", "workspace", "ovl S", ["tube/src/p-rast.asm"])
reg(0xF9, 0xFA, "zero page (unused)", "free", "-", [], 0xF9)
reg(0xFA, 0x100, "ring pointers (rq, p_oscli's, rpz)", "workspace", "resident", ["tube/src/p-io.asm"])
reg(0x100, 0x200, "stack (XX3 at its foot)", "stack", "-", ["master/src/elite-source.asm"])
reg(0x200, 0x400, "QSL, the quarter squares' low bytes", "data", "low pages", ["tube/src/p-layout.asm"])
reg(0x400, k_end + 1, "K%: ship data blocks", "workspace", "K%", ["master/src/elite-source.asm"])
reg(k_end + 1, wp0, "ship line heap (down from WP)", "workspace", "K%", ["master/src/elite-source.asm"])
reg(wp0 - 0, wp_end + 1, "WP: Elite's workspace, the dashboard's variables", "workspace", "WP", ["master/src/elite-source.asm"])
# page &0D: the dummy SHEILA byte (ACCCON, VIA + &34) and setzp/getzp's buffer
p = wp_end + 1
pws0 = sy.get("PWS_START", 0xE00)
if "MN_E" in sy and sy["MN_E"] == p:          # (the moon's place after WP: p-ws.asm)
    e = sy["ss_sg"] + 1
    reg(p, e, "the moon's place and MN_TURN's variables (gfx-mnturn.asm)", "workspace", "PWS", ["tube/src/p-ws.asm"])
    p = e
pd = sorted(x for x in [(VIA + 0x34, VIA + 0x35, "dummy ACCCON (VIA + &34)"), (ZPSAVE + 0x90, ZPSAVE + 0x100, "ZPSAVE (zero page &90-&FF)")]
            if x[0] < pws0)
for s, e, n in pd:
    if s > p:
        reg(p, s, "free", "free", "-", [], p)
    reg(s, e, n, "workspace", "WP", ["master/src/elite-source.asm"])
    p = e
if p < pws0:
    reg(p, pws0, "free", "free", "-", [], p)
reg(pws0, code0, "frame layer's inputs (p-ws.asm)", "workspace", "PWS", ["tube/src/p-ws.asm"], sy["PWS_END"])
# the resident image
pad = int(re.search(r"the font's alignment: (\d+) ", cp).group(1))   # (decimal)
reg(code0, sy["HEAD_END%"], "low area and head (p-low.asm, the font's widths, the log tables, QSH; free: the log tables' page alignment)",
    "code", "run (head)", ["build/elite-source-run.asm", "tube/src/p-low.asm", "build/p-glue-frame.asm", "master/src/gfx-hooks.asm"],
    sy["HEAD_END%"] - pad)
reg(sy["HEAD_END%"], b4, "the run", "code", "run", ["build/elite-source-run.asm"])
reg(b4, run_end, "Master's drawing (bank 4 blocks)", "code", "bank4", ["build/elite-source-bank4.asm"])
reg(sy["HZ_START"], sy["HZDATA_END%"], "game data (XX21, blueprints, QQ18 ...)", "data", "hot data", ["build/elite-data-hot.asm"])
reg(sy["HZDATA_END%"], sy["HZ_END"], "hangar tables, moon and ring variables", "data", "hot data",
    ["master/src/gfx-hangar6.asm", "master/src/gfx-planetv.asm"])
reg(sy["PF_START"], sy["PF_CODE_END"], "frame layer (parasite part)", "code", "frame",
    ["build/gfx-frame-frame.asm", "master/src/gfx-faces.asm", "master/src/gfx-light6.asm", "master/src/gfx-light.asm",
     "master/src/gfx-frame_cold.asm", "master/src/gfx-hangar.asm"])
reg(sy["PF_CODE_END"], sy["F_DLEND"], "frame layer state (F_HW, F_HW2, F_DL with F_INIT)", "buffers", "frame",
    ["tube/src/p-layout.asm", "master/src/gfx-finit.asm"])
reg(sy["F_DLEND"], sy["PRES_END"], "text map (F_TM, F_ST)", "buffers", "frame", ["tube/src/p-layout.asm"])
o = sy["OVL_START"]
if sy["PRES_END"] < o:
    reg(sy["PRES_END"], o, "free (to the overlay region's page)", "free", "-", [], sy["PRES_END"])
reg(o, RING, "overlay D (direct mode)", "overlay", "ovl D",
    ["build/elite-source-cold.asm", "build/elite-data-cold.asm", "build/p-io-ovld.asm", "build/p-glue-ovld.asm"],
    sy["OVL_D_END"], alt="D")
reg(o, RING, "overlay S (space mode): state, then code", "overlay", "ovl S",
    ["tube/src/p-rast.asm", "tube/src/p-moon.asm", "tube/src/p-emit.asm", "tube/src/p-kept.asm", "tube/src/p-polya.asm",
     "tube/src/p-onepass.asm", "master/src/gfx-ftext.asm", "master/src/gfx-flare.asm", "master/src/gfx-merid.asm",
     "master/src/gfx-planet7.asm"], sy["OVL_S_END"], alt="S")
reg(sy["OVL_D_END"], RING, "boot staging (p_boot and the high area's images: boot only)", "boot", "ovl D's tail",
    ["tube/src/p-layout.asm"], sy["PSTG_END"], alt="boot")
if ZPSAVE + 0x90 >= o:
    reg(ZPSAVE + 0x90, ZPSAVE + 0x100, "ZPSAVE: getzp's buffer for zero page &90-&FF (direct mode, above overlay D)",
        "workspace", "ovl D's tail", ["master/src/elite-source.asm"], alt="D")
reg(RING, 0xF800, "command ring", "buffers", "ring", ["tube/src/p-io.asm"])
reg(0xF800, 0xFEF0, "high area (phase A's tail, the panel's tail, kept rows, one-pass tail)", "code", "high",
    ["tube/src/p-polyb.asm", "tube/src/p-dash2.asm", "tube/src/p-kept2.asm", "tube/src/p-onepass2.asm"], sy["PHIGH_END"])
reg(0xFEF0, 0xFF00, "Tube registers (&FEF8-&FEFF) and guard", "io", "-", [])
reg(0xFF00, 0xFFFA, "page &FF: p_crash, the flare's step and tables, the directly drawn stars", "code", "page FF",
    ["tube/src/p-layout.asm", "master/src/gfx-flare6.asm", "tube/src/p-flt.asm"], sy["PFF_END"])
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
