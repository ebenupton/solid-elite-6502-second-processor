#!/usr/bin/env python3
"""Column dirty records from per-shape bounding boxes vs exact per-column
extents: bytes to repair per frame."""
import sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from corpus import load
from test_raster import poly_spans, line_pixels

def main(path, lo, hi):
    T = dict(fr=0, exact=0, box=0, cols_exact=0, cols_box=0)
    for it, cyc, grp, calls in load(path, lo, hi):
        ex, bx = {}, {}
        for d, c in calls:
            n = d['name']
            if n not in ('POLY', 'LINE', 'DOT', 'MARKDIRTY'): continue
            clip = (d['cl'], d['cr'], d['ct'], d['cb'])
            pts = {}
            if n == 'POLY':
                sp = poly_spans(d['verts'], clip)
                for y, (l, r) in sp.items():
                    for cc in range(l >> 2, (r >> 2) + 1): pts.setdefault(cc, []).append(y)
            elif n == 'LINE':
                for x, y in line_pixels(*d['line']):
                    if clip[0] <= x <= clip[1] and clip[2] <= y <= clip[3]: pts.setdefault(x >> 2, []).append(y)
            elif n == 'DOT':
                for x, y in ((d['x'], d['y']), (d['x'] + 1, d['y']), (d['x'], d['y'] + 1), (d['x'] + 1, d['y'] + 1)):
                    pts.setdefault(min(x, 255) >> 2, []).append(min(y, 191))
            else:
                for cc in range(d['xl'] >> 2, (d['xr'] >> 2) + 1): pts.setdefault(cc, []).append(d['y'])
            if not pts: continue
            for cc, ys in pts.items():
                t, b = ex.get(cc, (999, -1)); ex[cc] = (min(t, min(ys)), max(b, max(ys)))
            ally = [y for ys in pts.values() for y in ys]
            for cc in range(min(pts), max(pts) + 1):
                t, b = bx.get(cc, (999, -1)); bx[cc] = (min(t, min(ally)), max(b, max(ally)))
        T['fr'] += 1
        T['exact'] += sum(b - t + 1 for t, b in ex.values()); T['cols_exact'] += len(ex)
        T['box'] += sum(b - t + 1 for t, b in bx.values()); T['cols_box'] += len(bx)
    f = T['fr']
    print('%d-%d per frame:' % (lo, hi), {k: round(v / f, 1) for k, v in T.items() if k != 'fr'})

if __name__ == '__main__':
    main(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]))
