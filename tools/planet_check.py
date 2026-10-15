#!/usr/bin/env python3
"""Check the 6502 meridian boundaries bit-exactly against the reference model:
for every captured meridian frame (harness/planet-capture.mjs output), the
disc layer's request (R_NDN, R_NDX0-3, R_NDP for rows R_NDT..R_NDB) must
equal tools/planet_analytic.py's analytic_rows_fixed on the same inputs.

python3 tools/planet_check.py CAPDIR
"""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import planet_analytic as PA


def s16(lo, hi):
    v = lo | (hi << 8)
    return v - 65536 if v >= 32768 else v


cap = sys.argv[1]
nf = nbad = 0
for line in open(os.path.join(cap, "frames.jsonl")):
    f = json.loads(line)
    if f["plt"] != 128 or f["ncv"] == 0 or not f["pl"]:
        continue
    nf += 1
    cx, cy, r = s16(*f["plx"]), s16(*f["ply"]), f["plr"]
    rows = PA.analytic_rows_fixed(cx, cy, r, PA.frame_normals(f["pl"]["inwk"]),
                                  f["ndt"], f["ndb"], f["ndl"], f["ndr"])
    bad = []
    for y in range(f["ndt"], f["ndb"] + 1):
        n = f["ndn"][y]
        got = (f["ndp"][y] & 1, [f["ndx"][k][y] for k in range(n)])   # must be ascending
        want = (rows[y][0] & 1, rows[y][1])
        if got != want:
            bad.append((y, got, want))
    if bad:
        nbad += 1
        if nbad <= 5:
            print(f"iter {f['iter']}: {len(bad)} rows differ, e.g.", bad[:3])
print(f"{nf} meridian frames checked, {nbad} differ")
