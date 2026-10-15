#!/usr/bin/env python3
"""Black repair with and without skipping what the new frame overwrites:
old (frame t-2, same buffer) column extents minus new frame's fully
covered bytes; runs by columns and by rows."""
import sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from corpus import load
from dirtystats import frame_pixels

def cover(rows):
    """per (y, c): set of pixels written"""
    full, any_ = set(), set()
    for y, segs in rows.items():
        px = {}
        for a, b in segs:
            for x in range(a, b + 1):
                px.setdefault(x >> 2, set()).add(x & 3)
        for c, s in px.items():
            any_.add((y, c))
            if len(s) == 4: full.add((y, c))
    return full, any_

def main(path, lo, hi):
    prev = {}
    T = dict(fr=0, colext=0, colruns=0, skipbytes=0, skipcolruns=0, skiprowruns=0, rowext=0)
    buf = 0
    for it, cyc, grp, calls in load(path, lo - 2, hi):
        for d, c in calls:
            if d['name'] == 'SETBUF': buf = d['a']
        full, any_ = cover(frame_pixels(calls))
        cols = {}
        for y, c in any_:
            t, b = cols.get(c, (999, -1)); cols[c] = (min(t, y), max(b, y))
        if buf in prev and it >= lo:
            oc = prev[buf]
            T['fr'] += 1
            T['colext'] += sum(b - t + 1 for t, b in oc.values()); T['colruns'] += len(oc)
            rem = set()
            for c, (t, b) in oc.items():
                inrun = False
                for y in range(t, b + 1):
                    if (y, c) not in full:
                        rem.add((y, c))
                        if not inrun: T['skipcolruns'] += 1
                        inrun = True
                    else: inrun = False
            T['skipbytes'] += len(rem)
            for y in set(y for y, c in rem):
                cs = sorted(c for yy, c in rem if yy == y)
                T['skiprowruns'] += 1 + sum(1 for i in range(1, len(cs)) if cs[i] != cs[i - 1] + 1)
        prev[buf] = cols
    f = T['fr']
    print('%d-%d per frame:' % (lo, hi), {k: round(v / f, 1) for k, v in T.items() if k != 'fr'})

if __name__ == '__main__':
    main(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]))
