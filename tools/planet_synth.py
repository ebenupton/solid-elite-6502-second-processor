#!/usr/bin/env python3
"""Synthetic test of the analytic meridian boundaries (tools/planet_analytic.py)
against the true-geometry ideal: random orientations (orthonormal frames
scaled to 0x6000 with a few % noise, as Elite's), radii 6..248, centres on
and off screen.

python3 tools/planet_synth.py [N] [--seed S] [--float] [--dump file.json]
Prints near/limb/gross wrong-pixel statistics (as tools/planet_model.py).
--dump writes the cases and the expected per-row output, for checking the
6502 implementation bit-exactly (harness/planet-unit.mjs).
"""
import sys, os, json, math, random
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import planet_analytic as PA

args = [a for a in sys.argv[1:] if not a.startswith("--")]
N = int(args[0]) if args else 300
seed = 1
if "--seed" in sys.argv:
    seed = int(sys.argv[sys.argv.index("--seed") + 1])
FIXED = "--float" not in sys.argv
DUMP = sys.argv[sys.argv.index("--dump") + 1] if "--dump" in sys.argv else None
rng = random.Random(seed)
CL, CR, CT, CB = 2, 253, 1, 191
YY, XX = np.mgrid[0:192, 0:256]


def hw_table(r):
    return [math.isqrt(r * r - d * d) for d in range(r + 1)]


def spans(cx, cy, r):
    hw = hw_table(r)
    top, bot = max(cy - r, CT), min(cy + r, CB)
    ndl = [255] * 192; ndr = [0] * 192
    if top > bot:
        return 1, 0, ndl, ndr
    for y in range(top, bot + 1):
        h = hw[abs(y - cy)]
        l, rr = cx - h, cx + h
        if rr < CL or l > CR:
            continue
        ndl[y] = max(l, CL); ndr[y] = min(rr, CR)
    return top, bot, ndl, ndr


def rand_frame():
    # random rotation
    q = [rng.gauss(0, 1) for _ in range(4)]
    n = math.sqrt(sum(x * x for x in q)); w, x, y, z = [v / n for v in q]
    R = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    vecs = []
    for i in range(3):
        sc = 24576 * (1 + rng.uniform(-0.04, 0.04))
        vecs.append([int(round(R[j][i] * sc)) for j in range(3)])
    # occasionally near-degenerate: a normal nearly along an axis
    if rng.random() < 0.15:
        k = rng.randrange(3); ax = rng.randrange(3)
        eps = rng.uniform(-0.02, 0.02)
        v = [0, 0, 0]; v[ax] = 24576
        for j in range(3):
            if j != ax:
                v[j] = int(24576 * rng.uniform(-1, 1) * abs(eps))
        vecs[k] = v
    return vecs


def tomag(v):
    return max(-32767, min(32767, v))


def ideal(cx, cy, r, side, roof, disc):
    side = np.array(side, float); roof = np.array(roof, float)
    side /= np.linalg.norm(side); roof /= np.linalg.norm(roof)
    X = (XX - cx).astype(float); Y = (cy - YY).astype(float)
    Z = np.sqrt(np.maximum(r * r - X * X - Y * Y, 0))
    a = X * side[0] + Y * side[1] + Z * side[2] > 0
    b = X * roof[0] + Y * roof[1] + Z * roof[2] > 0
    return ~(a ^ b)


def neighbourhood(m, k=1):
    out = m.copy()
    for dy in range(-k, k + 1):
        for dx in range(-k, k + 1):
            out |= np.roll(np.roll(m, dy, 0), dx, 1)
    return out


tot = np.zeros(3); worst = []
cases = []
for i in range(N):
    vecs = rand_frame()
    roof, side = vecs[1], vecs[2]
    r = rng.choice([rng.randint(6, 40), rng.randint(40, 130), rng.randint(130, 248)])
    if rng.random() < 0.6:
        cx = rng.randint(20, 236); cy = rng.randint(10, 182)
    else:
        cx = rng.randint(-r + 10, 255 + r - 10); cy = rng.randint(-r + 10, 191 + r - 10)
    top, bot, ndl, ndr = spans(cx, cy, r)
    if top > bot:
        continue
    rows = PA.analytic_rows(cx, cy, r, [side, roof], top, bot, ndl, ndr, fixed=FIXED)
    Q = np.zeros((192, 256), bool); disc = np.zeros((192, 256), bool)
    for y in range(top, bot + 1):
        if ndl[y] > ndr[y]:
            continue
        disc[y, ndl[y]:ndr[y] + 1] = True
        p0, xs = rows[y]
        c = np.full(256, p0 & 1, np.int8)
        for x0 in xs:
            c[x0:] ^= 1
        Q[y] = c.astype(bool)
    T = ideal(cx, cy, r, side, roof, disc)
    wr = (Q != T) & disc
    ch = np.zeros_like(T)
    ch[:, 1:] |= T[:, 1:] != T[:, :-1]; ch[:, :-1] |= T[:, 1:] != T[:, :-1]
    ch[1:, :] |= T[1:, :] != T[:-1, :]; ch[:-1, :] |= T[1:, :] != T[:-1, :]
    near = wr & neighbourhood(ch, 1)
    udisc = (XX - cx) ** 2 + (YY - cy) ** 2 <= r * r
    limb = wr & ~near & neighbourhood(~udisc, 2)
    gross = wr & ~near & ~limb
    st = np.array([near.sum(), limb.sum(), gross.sum()])
    tot += st
    worst.append((st[2], st[1], i, cx, cy, r, side, roof))
    if DUMP:
        cases.append(dict(cx=cx, cy=cy, r=r, side=side, roof=roof, top=top, bot=bot,
                          ndl=ndl, ndr=ndr, rows={y: rows[y] for y in range(top, bot + 1)}))
n = len(worst)
print(f"{n} cases ({'fixed' if FIXED else 'float'}): near {tot[0]/n:.1f} limb {tot[1]/n:.2f} gross {tot[2]/n:.2f} per case; "
      f"cases with gross {sum(1 for w in worst if w[0])}, with limb {sum(1 for w in worst if w[1])}")
for w in sorted(worst, key=lambda w: (-w[0], -w[1]))[:8]:
    print("  gross", w[0], "limb", w[1], "case", w[2], "c", w[3], w[4], "r", w[5], "side", w[6], "roof", w[7])
if DUMP:
    json.dump(cases, open(DUMP, "w"))
