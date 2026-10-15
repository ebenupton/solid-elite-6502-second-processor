#!/usr/bin/env python3
"""Look for disc-colour pixels left outside the disc (traces) in captured
frames (harness/planet-capture.mjs): pixels outside the current disc and
this buffer's dirty extents that match the planet's colour A or B dither
in runs of 3 or more along a row (stars and the overlay are excluded by the
run length and the text rows).

python3 tools/planet_traces.py CAPDIR
"""
import sys, os, json
import numpy as np
sys.argv = [sys.argv[0], sys.argv[1]]
src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "planet_model.py")).read()
exec(src.split("frames = [json.loads")[0])
cap = sys.argv[1]
frames = [json.loads(l) for l in open(os.path.join(cap, "frames.jsonl"))]
scrs = open(os.path.join(cap, "screens.bin"), "rb").read()
bad = 0
for i, f in enumerate(frames):
    S = decode(scrs[i * 12288:(i + 1) * 12288])
    disc = np.zeros((192, 256), bool)
    for y in range(f["ndt"], f["ndb"] + 1):
        if f["ndl"][y] <= f["ndr"][y]:
            disc[y, f["ndl"][y]:f["ndr"][y] + 1] = True
    dirty = np.zeros((192, 256), bool)
    for y in range(192):
        if f["dirr"][y] and f["dirl"][y] <= f["dirr"][y]:
            dirty[y, f["dirl"][y]:f["dirr"][y] + 1] = True
    PB = pattern(f["dbe"], f["dbo"])
    ea = PA[YY & 1, XX & 3]; eb = PB[YY & 1, XX & 3]
    m = ((S == ea) | (S == eb)) & (S != 0) & ~disc & ~dirty & ~SIGHTS
    m[:, :2] = False; m[:, 254:] = False; m[0] = False
    m[8:16] = False; m[176:] = False            # text rows
    # runs of >= 3 matching pixels (dither: allow gaps of one black pixel)
    hit = []
    for y in range(192):
        row = m[y] | ((S[y] == 0) & ((S[y] == ea[y]) | (S[y] == eb[y])))
        xs = np.nonzero(m[y])[0]
        if len(xs) >= 3 and (xs[-1] - xs[0]) >= 2:
            # count positions inside a stretch where every pixel matches a disc colour
            run = 0; best = 0
            for x in range(xs[0], xs[-1] + 1):
                run = run + 1 if row[x] else 0
                best = max(best, run)
            if best >= 5:
                hit.append((y, int(xs[0]), int(xs[-1])))
    if hit:
        bad += 1
        if bad <= 15:
            print(f"iter {f['iter']} buf {f['buf']} planet ({s16(*f['plx'])},{s16(*f['ply'])}) r {f['plr']} type {f['plt']}: rows {hit[:6]}")
print(f"{len(frames)} frames, {bad} with traces")
