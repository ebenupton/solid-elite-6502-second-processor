#!/usr/bin/env python3
# pmap.py [BUILD [OUT.json [ROOT [COMMIT]]]]: the parasite's memory map, &0000-&FFFF as the
# 6502 Second Processor sees it, from a Tube build (tube/build.sh's
# build/psyms.txt and build/compile-p.txt, and tube/src's constants): every
# region with its start, end, name, kind, place (p-layout.asm's passes),
# source files (for code and data, those that assemble bytes there, from
# the listing), bytes used and bytes free. Names are the Master port's
# (docs/MASTER-MAP.md) for what the parasite shares with it. The overlay region is listed once
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


def source(f):
    """the source behind a listing's file name (the stage's src/ is master/src,
    tsrc/ tube/src; build/NAME-PASS.asm is streams.py's copy of NAME.asm)"""
    d, n = f.split("/", 1)
    if d in ("src", "tsrc"):
        return ("master/src/" if d == "src" else "tube/src/") + n
    n = n[:-4]
    while True:
        for s in ("tube/src/", "master/src/"):
            if os.path.isfile(os.path.join(ROOT, s + n + ".asm")):
                return s + n + ".asm"
        if "-" not in n:
            return "tube/" + f
        n = n.rsplit("-", 1)[0]


# what each file assembles, from the listing: (assembly, address, source),
# the assembly being S (overlay S's, from OVL_S_START to OVL_S_END), boot
# (the boot's staging, from p-io-boot.asm's copy on) or main (the rest)
asm, stack, phase = [], ["tube/src/p-layout.asm"], "main"
for ln in cp.splitlines():
    if ln.startswith("Including file "):
        f = ln[15:].strip()
        stack.append(source(f))
        if f == "build/p-io-boot.asm":
            phase = "boot"
    elif ln.startswith("Processed file "):
        stack.pop()
    elif ln == ".OVL_S_START":
        phase = "S"
    elif ln == ".OVL_S_END":
        phase = "main"
    else:
        m = re.match(r"     ([0-9A-F]{4})   [0-9A-F]{2}", ln)
        if m:
            asm.append((phase, int(m.group(1), 16), stack[-1]))


def assembled(start, end, ph):
    """the sources that assemble bytes in [start, end) in assembly ph, in order"""
    out = []
    for p, a, f in asm:
        if p == ph and start <= a < end and f not in out:
            out.append(f)
    return out


def reg(start, end, name, kind, area, files, used_end=None, alt=None, ph=None):
    """[start, end) with [start, used_end) used; with ph, files are the
    sources that assemble bytes there in assembly ph (what assembles nothing
    in this build, such as a feature's files with the feature off, is not listed)"""
    u = end if used_end is None else used_end
    if ph:
        files = assembled(start, u, ph)
    regions.append({"start": "&%04X" % start, "end": "&%04X" % (end - 1), "name": name, "kind": kind,
                    "area": area, "files": files, "used": u - start, "free": end - u,
                    **({"alternative": alt} if alt else {})})


# Elite's workspaces at the Master port's addresses, with the parasite's
# pointers in zero page (p-rast.asm's pr_*, the ring's: always there, so their
# area is ZP, though only overlay S's code uses pr_*) and the quarter-square
# tables' QSL in pages 2 and 3
reg(0, zp_end + 1, "Zero page: Elite's workspace (ZP)", "workspace", "ZP", ["master/src/elite-source.asm"])
if zp_end + 1 < 0xE4:
    reg(zp_end + 1, 0xE4, "Free (zero page)", "free", "-", [], zp_end + 1)
reg(0xE4, 0xF9, "Zero page: the rasteriser's pointers and scratch (p-rast.asm's pr_*, overlay S's)", "workspace", "ZP",
    ["tube/src/p-rast.asm"])
reg(0xF9, 0xFA, "Free (zero page)", "free", "-", [], 0xF9)
reg(0xFA, 0x100, "Zero page: the ring's pointers (rq, p_oscli's, rpz)", "workspace", "ZP", ["tube/src/p-io.asm"])
reg(0x100, 0x200, "Stack (XX3 at its foot)", "stack", "-", ["master/src/elite-source.asm"])
reg(0x200, 0x400, "Quarter-square tables: QSL (made by p_boot)", "workspace", "QSL",
    ["master/src/elite-qs.asm", "tube/src/p-io.asm"])
reg(0x400, k_end + 1, "K%: Elite's workspace, the ship data blocks", "workspace", "K%", ["master/src/elite-source.asm"])
reg(k_end + 1, wp0, "K%: the ship line heap (down from WP)", "workspace", "K%", ["master/src/elite-source.asm"])
reg(wp0, wp_end + 1, "WP: Elite's workspace, then the dashboard's variables DASHV", "workspace", "WP", ["master/src/elite-source.asm"])
reg(wp_end + 1, sy["PWS_START"], "WP: VEC (the IRQ1 vector's old value, WP's last)", "workspace", "WP", ["master/src/elite-source.asm"])
# the shared workspace, one run (p-ws.asm), zeroed by p_boot
ws = [("PWS_START", "hp_dfl", "Shared workspace: PACC, the dummy ACCCON (VIA + &34)"),
      ("hp_dfl", "R_PXL", "Shared workspace: the disc heap's flags and counts, the lens flare's probes, R_POLY's scratch"),
      ("R_PXL", "R_NDISCL", "Shared workspace: the rasteriser's per-call inputs, the stars (R_SS, F_DSS, R_SX, R_SY), the text map's "
       "row counts F_TMR, S_SUN's ss_zs, the sun this frame (F_SUX, F_SUY), the kept solid rows' scratch, F_DCOL"),
      ("R_NDISCL", "F_HW", "Shared workspace: the new disc spans' row arrays R_NDISCL, R_NDX0, R_NDX1, R_NDN (page aligned)"),
      ("F_HW", "F_TM", "Shared workspace: the half-widths F_HW, F_HW2 (the planet's, the sun's)"),
      ("F_TM", "R_NDISCR", "Shared workspace: the text map F_TM"),
      ("R_NDISCR", "ss_d", "Shared workspace: the new disc spans' row arrays R_NDISCR, R_NDX2, R_NDX3"),
      ("ss_d", "F_BX", "Shared workspace: S_SUN's (ss_d ... ss_su), SS_OK, FL_BEH, GFAR ... GSHT, the second disc's rows and "
       "colour by buffer (R_S2T, R_S2B, R_S2C), the incremental discs' scratch"),
      ("F_BX", "F_SR", "Shared workspace: the frame layer's state (F_BX, F_BY, f_tcol, f_zsv, F_SLV)"),
      ("F_SR", "F_RP", "Shared workspace: the ship records F_SR (the faces' levels)"),
      ("F_RP", "F_DSX", "Shared workspace: the ship records F_RP"),
      ("F_DSX", "PWS_END", "Shared workspace: the directly drawn stars F_DSX, F_DSY")]
for a, b, n in ws:
    reg(sy[a], sy[b], n, "workspace", "workspace", ["tube/src/p-ws.asm"])
# the resident code and data: one run from the shared workspace's end, the
# one gap, then the log tables and QSH, ending at the overlay region
reg(sy["PCODE_START"], sy["GLUE_END%"], "Glue area (p-low.asm: the stubs between the passes, none; the renderer's shared variables, "
    "the G_ stubs and the text hooks, the drawing hooks, the Tube I/O, the overlay manager, the dashboard's parasite halves)",
    "code", "resident", None, ph="main")
reg(sy["GLUE_END%"], sy["HZ_START"], "The game's run (Elite's resident blocks, in the source's order)", "code", "resident",
    None, ph="main")
reg(sy["HZ_START"], sy["HZDATA_END%"], "Game data (the hot data: XX21, E%, KWL%, KWH%, the blueprints, ...)", "data", "resident",
    None, ph="main")
reg(sy["HZDATA_END%"], sy["HZ_END"], "The hangar's tables (HFY, HPWL, HPWH)", "data", "resident", None, ph="main")
reg(sy["PF_START"], sy["PRES_CODE_END"], "Frame layer (the parasite's part), the resident parts of overlay S's files, F_INIT", "code", "resident",
    None, ph="main")
reg(sy["PRES_CODE_END"], sy["TAB_START"], "Free (the resident code's one gap)", "free", "-", [], sy["PRES_CODE_END"])
reg(sy["TAB_START"], sy["TAB_END"], "Log tables (log, logL, alogh) and the quarter-square tables' QSH, page aligned", "data", "aligned",
    None, ph="main")
# the overlay region, D or S; the boot's staging above D at the boot
o = sy["OVL_START"]
reg(o, RING, "Overlay D (direct mode)", "overlay", "ovl D", None, sy["OVL_D_END"], alt="D", ph="main")
reg(o, RING, "Overlay S (space mode): the rasteriser's private state, then code", "overlay", "ovl S", None, sy["OVL_S_END"],
    alt="S", ph="S")
reg(sy["OVL_D_END"], RING, "The boot's staging (p_start, p_boot, the top pages' images: boot only)", "boot", "boot",
    ["tube/src/p-io.asm", "tube/src/p-layout.asm"], sy["PSTG_END"], alt="boot")
reg(ZPSAVE + 0x90, ZPSAVE + 0x100, "ZPSAVE: the zero-page save (getzp/setzp, &90-&FF; direct mode, above overlay D)",
    "workspace", "ovl D", ["master/src/elite-source.asm"], alt="D")
reg(RING, RING + 0x400, "The ring (the commands to the host)", "buffers", "ring", ["tube/src/p-io.asm"])
reg(0xFE00, 0xFEF0, "The page below the registers: pbl (pirq's unrolled sends), p_crash", "code", "page FE", None,
    sy["PFE_END"], ph="main")
reg(0xFEF0, 0xFF00, "Tube registers (&FEF8-&FEFF) and guard", "io", "-", [])
reg(0xFF00, 0xFFFA, "Page &FF: pirq, the ring's doorbell", "code", "page FF", None, sy["PFF_END"], ph="main")
reg(0xFFFA, 0x10000, "Vectors (NMI, RESET, IRQ/BRK)", "vectors", "-", None, ph="main")

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
