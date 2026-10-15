#!/usr/bin/env python3
"""Stage 1: blueprint parsing (filled out further below)."""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'ref', 'elite-demo-source-code-bbc-micro', '3-assembled-output')

SHIPS_LOAD = 0x563A
PYTHON_LOAD = 0x7F00
NAMES = {1: 'Sidewinder', 2: 'Viper', 3: 'Mamba', 4: 'Python', 5: 'Cobra Mk III (bounty hunter)',
         6: 'Thargoid', 7: 'Cobra Mk III (trader)', 8: 'Coriolis station', 9: 'Missile',
         10: 'Asteroid', 11: 'Cargo canister', 12: 'Thargon', 13: 'Escape pod'}
NTYPES = 13


def _mem():
    mem = bytearray(0x10000)
    d = open(os.path.join(OUT, 'SHIPS.bin'), 'rb').read()
    mem[SHIPS_LOAD:SHIPS_LOAD + len(d)] = d
    d = open(os.path.join(OUT, 'PYTHON.bin'), 'rb').read()
    mem[PYTHON_LOAD:PYTHON_LOAD + len(d)] = d
    return mem


def _sgn(b, mask, v):
    return -v if b & mask else v


def parse(mem, a):
    h = mem[a:a + 20]
    eoff = h[3] | h[16] << 8
    foff = h[4] | h[17] << 8
    nv, ne, nf = h[8] // 6, h[9], h[12] // 4
    verts = []
    for i in range(nv):
        b = mem[a + 20 + 6 * i:a + 26 + 6 * i]
        verts.append(dict(x=_sgn(b[3], 0x80, b[0]), y=_sgn(b[3], 0x40, b[1]), z=_sgn(b[3], 0x20, b[2]),
                          vis=b[3] & 31, faces=(b[4] & 15, b[4] >> 4, b[5] & 15, b[5] >> 4)))
    edges = []
    ea = (a + eoff) & 0xFFFF
    for i in range(ne):
        b = mem[ea + 4 * i:ea + 4 * i + 4]
        edges.append(dict(vis=b[0] & 31, f1=b[1] & 15, f2=b[1] >> 4, v1=b[2] >> 2, v2=b[3] >> 2))
    faces = []
    fa = (a + foff) & 0xFFFF
    for i in range(nf):
        b = mem[fa + 4 * i:fa + 4 * i + 4]
        faces.append(dict(vis=b[0] & 31, n=(_sgn(b[0], 0x80, b[1]), _sgn(b[0], 0x40, b[2]),
                                            _sgn(b[0], 0x20, b[3]))))
    return dict(addr=a, scale=h[18], gun=h[6], visdist=h[13], verts=verts, edges=edges, faces=faces)


def load_ships():
    mem = _mem()
    out = []
    for t in range(1, NTYPES + 1):
        a = mem[SHIPS_LOAD + 2 * (t - 1)] | mem[SHIPS_LOAD + 2 * (t - 1) + 1] << 8
        s = parse(mem, a)
        s['name'] = NAMES[t]
        out.append((t, s))
    return out


# ---------------------------------------------------------------------------
# Face reconstruction

import math
from collections import defaultdict


def _vec(v):
    return (v['x'], v['y'], v['z'])


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _unit(a):
    m = math.sqrt(_dot(a, a))
    return (a[0] / m, a[1] / m, a[2] / m)


def _basis(n):
    """Two unit vectors u, w spanning the plane normal to n, with u x w = n-hat
    (so angles measured from u towards w go anticlockwise about n)."""
    nh = _unit(n)
    a = (1, 0, 0) if abs(nh[0]) < 0.9 else (0, 1, 0)
    u = _unit(_cross(a, nh))
    w = _cross(nh, u)
    return nh, u, w


def _hull(pts):
    """Andrew's monotone chain on [(x, y, id)]; anticlockwise, collinear points dropped."""
    pts = sorted(set(pts))
    if len(pts) < 3:
        return [p[2] for p in pts]

    def cr(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lo, hi = [], []
    for p in pts:
        while len(lo) >= 2 and cr(lo[-2], lo[-1], p) <= 1e-9:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(hi) >= 2 and cr(hi[-2], hi[-1], p) <= 1e-9:
            hi.pop()
        hi.append(p)
    return [p[2] for p in lo[:-1] + hi[:-1]]


def reconstruct(s):
    """Fill s['polys'][f] (list of vertex indices, clockwise about the face
    normal in blueprint coordinates = clockwise on screen when front-facing,
    or [] if unfillable), s['detail'] (edge
    indices that are not polygon sides) and s['notes'] (diagnostics)."""
    V = [_vec(v) for v in s['verts']]
    notes = []
    polys = []
    for f, face in enumerate(s['faces']):
        n = face['n']
        nh, u, w = _basis(n)
        B = [e for e in s['edges'] if f in (e['f1'], e['f2']) and e['f1'] != e['f2']]
        adj = defaultdict(set)
        for e in B:
            adj[e['v1']].add(e['v2'])
            adj[e['v2']].add(e['v1'])
        # prune dangling chains (guns, fins): degree-1 vertices, repeatedly
        changed = True
        while changed:
            changed = False
            for v in list(adj):
                if len(adj[v]) <= 1:
                    for o in adj[v]:
                        adj[o].discard(v)
                    del adj[v]
                    changed = True
        cand = sorted(adj)
        if len(cand) < 3:
            polys.append([])
            notes.append(f'face {f}: no closed boundary ({len(B)} edges) -> n=0')
            continue
        ext = max(math.dist(V[a], V[b]) for a in cand for b in cand)
        keep = cand
        pts = [(round(_dot(u, V[v]), 6), round(_dot(w, V[v]), 6), v) for v in keep]
        poly = _hull(pts)
        inside = [v for v in keep if v not in poly]
        # an interior (non-collinear) candidate means the boundary is non-convex
        for v in inside:
            # collinear with a hull side?
            p = (_dot(u, V[v]), _dot(w, V[v]))
            on = False
            for i in range(len(poly)):
                a, b = poly[i], poly[(i + 1) % len(poly)]
                pa = (_dot(u, V[a]), _dot(w, V[a]))
                pb = (_dot(u, V[b]), _dot(w, V[b]))
                cr = (pb[0] - pa[0]) * (p[1] - pa[1]) - (pb[1] - pa[1]) * (p[0] - pa[0])
                if abs(cr) < 1e-6 * ext * ext:
                    on = True
            if not on:
                notes.append(f'face {f}: boundary vertex {v} inside hull -> face non-convex')
        if len(poly) < 3:
            polys.append([])
            notes.append(f'face {f}: degenerate hull -> n=0')
            continue
        # true normal of the polygon (Newell) vs blueprint normal
        nw = [0.0, 0.0, 0.0]
        for i in range(len(poly)):
            a, b = V[poly[i]], V[poly[(i + 1) % len(poly)]]
            nw[0] += (a[1] - b[1]) * (a[2] + b[2])
            nw[1] += (a[2] - b[2]) * (a[0] + b[0])
            nw[2] += (a[0] - b[0]) * (a[1] + b[1])
        ang = math.degrees(math.acos(max(-1, min(1, _dot(_unit(nw), nh)))))
        nwh = _unit(nw)
        hs = [_dot(nwh, V[v]) for v in keep]
        dev = (max(hs) - min(hs)) / 2
        if dev > 0.02 * ext:
            notes.append(f'face {f}: non-planar: vertices +-{dev:.1f} off their best plane '
                         f'over extent {ext:.0f}')
        if ang > 5:
            notes.append(f'face {f}: blueprint normal is {ang:.0f} deg off the polygon\'s true normal')
        # hull sides should be blueprint edges of this face
        eset = {frozenset((e['v1'], e['v2'])) for e in s['edges'] if f in (e['f1'], e['f2'])}
        for i in range(len(poly)):
            a, b = poly[i], poly[(i + 1) % len(poly)]
            if frozenset((a, b)) not in eset:
                notes.append(f'face {f}: hull side {a}-{b} is not an edge of this face')
        # The hull runs anticlockwise about the blueprint normal (right-hand rule
        # in blueprint coordinates).  Every ship orientation in the game has det
        # -1 (ZINF: sidev (1,0,0), roofv (0,1,0), nosev (0,0,-1); TIDY keeps
        # sidev = nosev x roofv), a reflection, so that order shows anticlockwise
        # on screen; reverse it to get CLOCKWISE ON SCREEN (x right, y down) for a
        # front-facing face (checked by tools/faces_preview.py).
        polys.append(poly[::-1])
    # detail edges: not a side of the polygon of either of its faces
    detail = []
    for i, e in enumerate(s['edges']):
        side = False
        for f in {e['f1'], e['f2']}:
            p = polys[f] if f < len(polys) else []
            for j in range(len(p)):
                if {p[j], p[(j + 1) % len(p)]} == {e['v1'], e['v2']}:
                    side = True
        if not side:
            detail.append(i)
    s['polys'], s['detail'], s['notes'] = polys, detail, notes
    return s


def check_projection(s, samples=20000, seed=1):
    """Each polygon vertex must be projected by LL9 whenever its face is filled:
    LL9 projects vertex v only if one of v's four faces (or face 15) has XX2 != 0
    and v's visibility distance >= XX4.  Static test + Monte Carlo over viewpoints
    using Elite's own test (face f visible iff n.(p + n/2^scale) < 0 where p is
    the ship's position in its own frame; the normal tip is the face's foot)."""
    import random
    rnd = random.Random(seed)
    out = []
    sc = 2 ** s['scale']
    nf = len(s['faces'])
    static = []
    for f, p in enumerate(s['polys']):
        for v in p:
            vf = set(s['verts'][v]['faces'])
            if s['verts'][v]['vis'] < 31:
                out.append(f'face {f}: vertex {v} has visibility distance {s["verts"][v]["vis"]} '
                           f'< 31 (not projected when XX4 > {s["verts"][v]["vis"]}, i.e. z >= '
                           f'{(s["verts"][v]["vis"] + 1) * 128})')
            if f in vf or 15 in vf:
                continue
            static.append((f, v, vf))
    for f, v, vf in static:
        bad = 0
        for _ in range(samples):
            # random direction, distance 1.5..20 x ship radius
            while True:
                d = (rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))
                if 0.01 < _dot(d, d) <= 1:
                    break
            r = rnd.uniform(1.5, 20) * 200
            pos = tuple(c * r / math.sqrt(_dot(d, d)) for c in d)

            def vis(g):
                n = s['faces'][g]['n']
                return _dot(n, tuple(pos[i] + n[i] / sc for i in range(3))) < 0
            if vis(f) and not any(g < nf and vis(g) for g in vf):
                bad += 1
        out.append(f'face {f}: vertex {v} lists faces {sorted(vf)} not {f}: '
                   f'{"STALE in %.1f%% of views where face %d is visible" % (100.0 * bad / samples, f) if bad else "never stale in sampling (a listed face is always visible with it)"}')
    return out


# ---------------------------------------------------------------------------
# A model of LL9 part 5's arithmetic, to find what XX2 holds

def _fm(a, q):
    return (a * q) >> 8


def _add(s1, m1, s2, m2):
    """LL38 on sign-magnitude bytes: returns (sign, mag, overflow)."""
    if s1 == s2:
        r = m1 + m2
        return s1, r & 255, r > 255
    if m1 >= m2:
        return s1, m1 - m2, False
    return s2, m2 - m1, False


def elite_xx2(s, pos, M):
    """XX2 values LL9 computes for ship s at view-space position pos (integers)
    with orientation rows M = (sidev, roofv, nosev) as unit vectors in view
    space.  Returns list of XX2 bytes (0 = hidden) and zn (z after the shifts)."""
    x, y, z = (abs(int(c)) for c in pos)
    sx, sy, sz = (c < 0 for c in pos)
    xx17 = s['scale']
    while z >> 8:
        xx17 += 1
        x >>= 1
        y >>= 1
        z >>= 1
    zn = z
    o = [[min(255, int(abs(M[r][c]) * 96 * 2 * 256 / 197 / 1)) for c in range(3)] for r in range(3)]
    p = []
    for r in range(3):
        acc_s, acc = False, 0
        for c, (m, sg) in enumerate(((x, sx), (y, sy), (z, sz))):
            t = _fm(m, o[r][c])
            acc_s, acc, _ = _add(acc_s, acc, sg ^ (M[r][c] < 0), t)
        p.append((acc_s, acc))
    out = []
    for face in s['faces']:
        n = face['n']
        ns = [c < 0 for c in n]
        nm = [abs(c) for c in n]
        pp = list(p)
        if xx17 >= 4:
            X = pp
        else:
            sh = xx17
            while True:
                nn = [m >> sh for m in nm]
                X, ovf = [], False
                for i in range(3):
                    sg, m, o_ = _add(ns[i], nn[i], pp[i][0], pp[i][1])
                    ovf |= o_
                    X.append((sg, m))
                if not ovf:
                    break
                pp = [(sg, m >> 1) for sg, m in pp]
                sh = 1
        acc_s, acc = False, 0
        for i in range(3):
            t = _fm(X[i][1], nm[i])
            acc_s, acc, _ = _add(acc_s, acc, X[i][0] ^ ns[i], t)
        out.append(acc if acc_s else 0)
    return out, zn


# ---------------------------------------------------------------------------
# Colours

import sys as _sys
_sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import swatch35 as SW                                   # noqa: E402

# Hue ramps: 8 entries of swatch35.ALL indices, level 0 (darkest, still not black)
# to level 7 (brightest), CIE L* (linear-light average of the PHYS inks) strictly
# rising.  Detail ink: the solid ink drawn for detail lines over this hue.
HUES = [
    # name       ramp (swatch35 numbers)               detail ink (None: automatic)
    ('steel',   [31, 27, 25, 17, 19, 2, 4, 1],    SW.K),   # 0 station, escape pod: cool grey
    ('fire',    [33, 30, 29, 23, 13, 12, 11, 10], None),   # 1 Sidewinder: crimson -> yellow
    ('police',  [31, 27, 25, 17, 15, 2, 0, 1],    None),   # 2 Viper: cyan
    ('amber',   [32, 29, 28, 22, 21, 7, 11, 10],  None),   # 3 Mamba: olive -> amber -> yellow
    ('violet',  [33, 30, 27, 20, 17, 5, 2, 0],    None),   # 4 Python: violet -> blue
    ('rose',    [33, 30, 29, 23, 13, 8, 12, 11],  None),   # 5 Cobra (bounty hunter): pink-red
    ('alien',   [31, 32, 25, 26, 16, 18, 3, 6],   None),   # 6 Thargoid, Thargon: green
    ('cream',   [32, 29, 28, 19, 22, 7, 11, 10],  None),   # 7 Cobra (trader): khaki/cream
    ('hotpink', [33, 30, 24, 14, 9, 13, 5, 8],    None),   # 8 missile: magenta
    ('rock',    [32, 29, 28, 19, 22, 8, 4, 7],    None),   # 9 asteroid: grey-brown
    ('cargo',   [31, 32, 26, 28, 18, 21, 6, 10],  None),   # 10 canister: yellow-green -> yellow
    ('sun',     [30, 29, 23, 13, 22, 12, 11, 10], None),   # 11 sun (use level 6)
    ('planet',  [33, 31, 27, 25, 17, 15, 2, 0],   None),   # 12 planet (use level 4)
]
SHIP_HUE = {1: 1, 2: 2, 3: 3, 4: 4, 5: 5, 6: 6, 7: 7, 8: 0, 9: 8, 10: 9, 11: 10, 12: 6, 13: 0}
SUN_HUE, SUN_LEVEL = 11, 6
PLANET_HUE, PLANET_LEVEL = 12, 4
INK_BYTE = {SW.K: 0x00, SW.C: 0x0F, SW.M: 0xF0, SW.Y: 0xFF}


def dither_bytes(n):
    """(even-row byte, odd-row byte) of swatch35.ALL[n]: MODE 1 pixel p of a byte
    (x = 4c + p, so x AND 1 = p AND 1) takes the ink at (p AND 1, row AND 1);
    colour v sets bit 7-p to v bit 1 and bit 3-p to v bit 0."""
    cl = SW.cell(*SW.ALL[n])
    out = []
    for row in (0, 1):
        b = 0
        for p in range(4):
            v = cl[(p & 1, row)]
            b |= ((v >> 1) & 1) << (7 - p) | (v & 1) << (3 - p)
        out.append(b)
    return tuple(out)


def _lin(c):
    c /= 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _lab(li):
    r, g, b = li
    X = 0.4124 * r + 0.3576 * g + 0.1805 * b
    Y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    Z = 0.0193 * r + 0.1192 * g + 0.9505 * b

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(X / 0.9505), f(Y), f(Z / 1.089)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def swatch_lab(n):
    cl = SW.cell(*SW.ALL[n])
    li = [sum(_lin(SW.PHYS[v][ch]) for v in cl.values()) / 4 for ch in range(3)]
    return _lab(li)


def ink_lab(ink):
    return _lab([_lin(c) for c in SW.PHYS[ink]])


def detail_ink(ramp):
    """The solid ink (K, C, M or Y) with the greatest worst-case contrast (CIE76
    delta E) against the ramp's levels 2..7 (the ones a face is usually lit at)."""
    best = None
    for ink in (SW.K, SW.C, SW.M, SW.Y):
        il = ink_lab(ink)
        d = min(math.dist(il, swatch_lab(n)) for n in ramp[2:])
        if best is None or d > best[0]:
            best = (d, ink)
    return best[1]


def hue_detail_ink(h):
    name, ramp, ink = HUES[h]
    return detail_ink(ramp) if ink is None else ink


def check_ramps():
    for h, (name, ramp, _) in enumerate(HUES):
        Ls = [swatch_lab(n)[0] for n in ramp]
        assert all(b > a for a, b in zip(Ls, Ls[1:])), (name, Ls)
        assert 34 not in ramp


# ---------------------------------------------------------------------------
# Brightness: XX2 -> level
#
# LL9 part 5 leaves XX2[f] = |n_f . (p + n_f / 2^XX17)| / 256 for a visible face
# (0 if hidden), where n_f is the blueprint normal as stored (magnitude |n_f|,
# 22..185 over the demo's ships), p the ship's position in its own frame after
# the coordinates were halved until z_hi = 0, and XX17 = blueprint scale +
# halvings.  So XX2 ~ |n_f| * cos(theta) * |p| / 256, with |p| ~ zn, the
# halved z (128..255 once z >= 256, z itself when z < 256).  XX2 therefore
# depends on the face's normal length and saw-tooths with distance; to get a
# cos(theta) we divide both out, in logs, so everything is additions:
#
#   idx = min(255, FC_LOG[XX2] + C_f + D)
#   FC_LOG[x] = min(255, round(32 * log2(x)))   (FC_LOG[0] = 0)
#   C_f = 255 - FC_LOG[round(|n_f|)]            (per face, FC_NRMTAB)
#   D   = min(255, 256 - FC_LOG[zn])            (once per ship)
#
# so idx ~ 258 + 32 * log2(cos theta) (calibrated by simulation of LL9's
# arithmetic: median idx 172 / 221 / 244 / 254 at cos 0.15 / 0.45 / 0.75 / 0.95)
# and level = FC_LEVEL[idx] = min(7, int(8 * c ** 0.8)), c = min(1, 2^((idx -
# 258) / 32)): head-on faces 7, grazing faces 0.

LOGK = 32
IDX0 = 258
FAR_LEVEL = 4          # level to use when XX2 = 255 (forced visible, no normal test)


def log_table():
    return [0] + [min(255, round(LOGK * math.log2(x))) for x in range(1, 256)]


def level_table():
    out = []
    for i in range(256):
        c = min(1.0, 2 ** ((i - IDX0) / LOGK))
        out.append(min(7, int(8 * c ** 0.8)))
    return out


def face_c(s):
    L = log_table()
    return [255 - L[round(math.sqrt(_dot(f['n'], f['n'])))] for f in s['faces']]


def zn_of(z):
    z = abs(int(z))
    while z >> 8:
        z >>= 1
    return z


def level_of(xx2, cf, zn):
    L = log_table()
    if xx2 == 0:
        return None
    d = min(255, 256 - L[max(1, zn)])
    return level_table()[min(255, L[xx2] + cf + d)]


# ---------------------------------------------------------------------------
# Output

def _equb(vals, per=16):
    out = []
    for i in range(0, len(vals), per):
        out.append(' EQUB ' + ', '.join('&%02X' % v for v in vals[i:i + per]))
    return out


def emit(ships, path):
    check_ramps()
    L = []
    nbytes = 0

    def eb(vals, per=16):
        nonlocal nbytes
        nbytes += len(vals)
        L.extend(_equb(vals, per))
    L += ['\\ faces.asm -- generated by tools/faces.py; do not edit.',
          '\\',
          '\\ Filled faces, detail lines and colours for the demo\'s 13 ship types.',
          '\\ All per-type pointer tables have an entry for every type 0..13 (type 0',
          '\\ is a dummy), so entry = table + 2 * type, as for XX21 - 2.',
          '\\',
          '\\ FC_FACETAB -> per face f, in blueprint order: n, then n XX3 offsets (4 *',
          '\\   vertex).  Polygons are convex and CLOCKWISE ON SCREEN (x right, y down)',
          '\\   when the face is front-facing, for every orientation with det -1, i.e.',
          '\\   as set by ZINF and kept by TIDY (sidev = nosev x roofv).  The station',
          '\\   (NWSPS negates the planet\'s nosev) is mirrored, det +1, until its',
          '\\   first TIDY: so do not rely on winding for it.  n = 0: do not fill.',
          '\\ FC_DETTAB -> count, then count edges in Elite\'s own edge layout:',
          '\\   visibility distance, face1 + 16 * face2, XX3 offset a, XX3 offset b.',
          '\\   Draw as a line over the fill when XX4 <= visibility and XX2[face1] or',
          '\\   XX2[face2] is non-zero (exactly LL9 part 9\'s rule; face1 = face2 for',
          '\\   surface detail).',
          '\\ FC_NRMTAB -> per face f: C_f = 255 - FC_LOG[|normal_f|].',
          '\\ Level of a visible face (XX2[f] <> 0, <> 255):',
          '\\   D = min(255, 256 - FC_LOG[zn]) once per ship, zn = INWK z halved until',
          '\\   its high byte is 0 (as LL9 part 5 does);',
          '\\   level = FC_LEVEL[min(255, FC_LOG[XX2[f]] + C_f + D)]  (0 dark .. 7 bright)',
          '\\   XX2[f] = 255 means LL9 skipped the normal test (far ship or exploding):',
          '\\   use FC_FARLVL and cull by screen winding instead.',
          '\\ Colour of (hue, level): even rows FC_RAMPE[hue*8+level], odd rows',
          '\\   FC_RAMPO[hue*8+level]; FC_HUE[type] = hue; FC_DETC[hue] = detail line',
          '\\   byte (one solid ink, same on both rows).',
          '\\ FC_MINVIS[type]: if XX4 > it, a polygon vertex may not have been',
          '\\   projected (vertex visibility distance < XX4): do not fill that ship.',
          '']
    hues = [SHIP_HUE.get(t, 0) for t in range(0, NTYPES + 1)]
    L.append('FC_FARLVL = %d' % FAR_LEVEL)
    L.append('FC_NTYPES = %d' % NTYPES)
    L.append('FC_NHUES = %d' % len(HUES))
    se, so = dither_bytes(HUES[SUN_HUE][1][SUN_LEVEL])
    pe, po = dither_bytes(HUES[PLANET_HUE][1][PLANET_LEVEL])
    L.append('FC_SUNHUE = %d : FC_SUNLVL = %d : FC_SUNE = &%02X : FC_SUNO = &%02X'
             % (SUN_HUE, SUN_LEVEL, se, so))
    L.append('FC_PLANHUE = %d : FC_PLANLVL = %d : FC_PLANE = &%02X : FC_PLANO = &%02X'
             % (PLANET_HUE, PLANET_LEVEL, pe, po))
    L.append('')
    # share identical data (the two Cobras)
    key = {}
    for t, s in ships:
        key.setdefault(s['addr'], t)
    for name in ('FACETAB', 'DETTAB', 'NRMTAB'):
        L.append('.FC_%s' % name)
        tag = {'FACETAB': 'F', 'DETTAB': 'D', 'NRMTAB': 'N'}[name]
        L.append('%-30s\\ type 0: unused' % ' EQUW 0')
        nbytes += 2
        for t, s in ships:
            L.append(('%-30s' % (' EQUW FC_S%d_%s' % (key[s['addr']], tag)))
                     + '\\ type %d: %s' % (t, s['name']))
            nbytes += 2
        L.append('')
    for t, s in ships:
        if key[s['addr']] != t:
            continue
        L.append('\\ %s (type %d%s)' % (s['name'], t, ''.join(
            ', type %d' % u for u, s2 in ships if s2['addr'] == s['addr'] and u != t)))
        L.append('.FC_S%d_F' % t)
        for f, p in enumerate(s['polys']):
            vals = [len(p)] + [4 * v for v in p]
            nbytes += len(vals)
            L.append(' EQUB ' + ', '.join('%d' % v for v in vals) + '    \\ face %d' % f)
        L.append('.FC_S%d_D' % t)
        L.append(' EQUB %d' % len(s['detail']))
        nbytes += 1
        for i in s['detail']:
            e = s['edges'][i]
            L.append(' EQUB %d, &%02X, %d, %d    \\ edge %d' % (
                e['vis'], e['f1'] | e['f2'] << 4, 4 * e['v1'], 4 * e['v2'], i))
            nbytes += 4
        L.append('.FC_S%d_N' % t)
        eb(face_c(s))
        L.append('')
    L.append('.FC_HUE                       \\ indexed by ship type 0..%d' % NTYPES)
    eb(hues)
    L.append('.FC_MINVIS                     \\ by type: least visibility distance of any polygon vertex;')
    L.append('                              \\ if XX4 > this, some polygon vertex may be unprojected (stale)')
    mv = [31] + [min([s['verts'][v]['vis'] for p in s['polys'] for v in p] + [31]) for t, s in ships]
    eb(mv)
    L.append('.FC_DETC                      \\ indexed by hue')
    eb([INK_BYTE[hue_detail_ink(h)] for h in range(len(HUES))])
    L.append('.FC_RAMPE                     \\ hue * 8 + level, even rows')
    ramps = [dither_bytes(n) for _, r, _ in HUES for n in r]
    eb([e for e, o in ramps], 8)
    L.append('.FC_RAMPO                     \\ hue * 8 + level, odd rows')
    eb([o for e, o in ramps], 8)
    L.append('.FC_LOG                       \\ min(255, round(32 * log2(x))), 0 for x = 0')
    eb(log_table())
    L.append('.FC_LEVEL                     \\ level 0..7 from the log-domain index')
    eb(level_table())
    L.append('')
    L.append('\\ %d bytes in all' % nbytes)
    open(path, 'w').write('\n'.join(L) + '\n')
    return nbytes


def report(ships):
    out = []
    for t, s in ships:
        out.append('%d %s' % (t, s['name']))
        for n in s['notes']:
            out.append('   ' + n)
        for n in check_projection(s):
            out.append('   ' + n)
    return out


def main():
    ships = load_ships()
    for t, s in ships:
        reconstruct(s)
    n = emit(ships, os.path.join(ROOT, 'src', 'faces.asm'))
    print('\n'.join(report(ships)))
    print('faces.asm: %d bytes of tables' % n)


if __name__ == '__main__':
    main()
