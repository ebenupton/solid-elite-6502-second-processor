#!/usr/bin/env python3
"""Before/after crops of the filled planet: for the given iterations, the
screen as captured (harness/planet-capture.mjs) by two builds, side by side
with the true-geometry ideal, and the wrong pixels (vs the ideal, beyond
one pixel of an ideal boundary) marked red.

python3 tools/planet_crops.py BEFORE_CAP AFTER_CAP OUTDIR [--iters a,b,c]
        [--worst N]
"""
import sys, os, json, argparse
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("before"); ap.add_argument("after"); ap.add_argument("out")
ap.add_argument("--iters"); ap.add_argument("--worst", type=int, default=6)
ap.add_argument("--scale", type=int, default=3)
opt = ap.parse_args()
sys.argv = [sys.argv[0], opt.before]
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "planet_model.py")).read()
exec(src.split("frames = [json.loads")[0])      # the model's functions
HEMI = 1.0
RGB = np.array([(0, 0, 0), (0, 255, 255), (255, 0, 255), (255, 255, 0)], np.uint8)


def load(cap):
    fr = [json.loads(l) for l in open(os.path.join(cap, "frames.jsonl"))]
    sc = open(os.path.join(cap, "screens.bin"), "rb").read()
    return {f["iter"]: (f, sc[i * 12288:(i + 1) * 12288]) for i, f in enumerate(fr)}


B = load(opt.before); A = load(opt.after)
common = sorted(i for i in B if i in A and B[i][0]["plt"] == 128 and B[i][0]["ncv"] and A[i][0]["ncv"])


def gross_of(f, scr):
    m = frame_model(f, scr)
    T = m["T"]
    vv = m["valid"] & ~m["amb"]
    w1 = ((m["S"] != T) & vv).sum(); w2 = ((m["S"] != ~T) & vv).sum()
    if w2 < w1:
        T = ~T
    wr = (m["S"] != T) & vv
    n_, l_, g_, gm = classify(wr, T, m)
    return m, T, wr & ~boundary_mask(T, m["disc"]), (n_, l_, g_)


if opt.iters:
    its = [int(x) for x in opt.iters.split(",")]
else:
    sc = []
    for i in common:
        _, _, _, st = gross_of(*B[i])
        sc.append((st[1] + st[2], i))
    its = [i for _, i in sorted(sc, reverse=True)[:opt.worst]]
os.makedirs(opt.out, exist_ok=True)
for it in its:
    panels = []
    for cap in (B, A):
        f, scr = cap[it]
        m, T, bad, st = gross_of(f, scr)
        img = RGB[decode(scr)]
        cx, cy, r = m["cx"], m["cy"], m["r"]
        x0, x1 = max(0, cx - r - 3), min(256, cx + r + 4)
        y0, y1 = max(0, cy - r - 3), min(192, cy + r + 4)
        mark = img.copy()
        mark[bad] = (255, 0, 0)
        panels.append((img[y0:y1, x0:x1], mark[y0:y1, x0:x1], st))
    ideal = np.zeros((192, 256, 3), np.uint8)
    disc = m["disc"]
    PB = pattern(f["dbe"], f["dbo"])
    ea = PA[YY & 1, XX & 3]; eb = PB[YY & 1, XX & 3]
    ideal[disc] = RGB[np.where(T, eb, ea)][disc]
    ideal = ideal[y0:y1, x0:x1]
    gap = np.full((y1 - y0, 4, 3), 64, np.uint8)
    row = np.concatenate([panels[0][0], gap, panels[0][1], gap, panels[1][0], gap, panels[1][1], gap, ideal], 1)
    im = Image.fromarray(row).resize((row.shape[1] * opt.scale, row.shape[0] * opt.scale), Image.NEAREST)
    name = os.path.join(opt.out, f"planet_it{it:05d}.png")
    im.save(name)
    print(f"{name}: before near/limb/gross {tuple(int(x) for x in panels[0][2])}, after {tuple(int(x) for x in panels[1][2])}")
print("panels: before screen | before, wrong pixels red | after screen | after, wrong red | true ideal")
