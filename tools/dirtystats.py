#!/usr/bin/env python3
"""Dirty-extent repair, rows vs byte columns: per frame, the pixels shapes
wrote (polygons, lines, dots, marked text) are repaired on the next frame of
the same buffer.  Row extents: per row [min x, max x]; column extents: per
byte column [min y, max y].  Counts bytes and runs each way."""
import sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from corpus import load
from test_raster import poly_spans, line_pixels, dot_pixels

def frame_pixels(calls):
    rows = {}  # y -> list of (l, r)
    for d, c in calls:
        n = d['name']
        clip = (d.get('cl', 2), d.get('cr', 253), d.get('ct', 1), d.get('cb', 191)) if n != 'SETBUF' else None
        if n == 'POLY':
            for y, (l, r) in poly_spans(d['verts'], clip).items():
                rows.setdefault(y, []).append((l, r))
        elif n == 'LINE':
            for x, y in line_pixels(*d['line']):
                if clip[0] <= x <= clip[1] and clip[2] <= y <= clip[3]:
                    rows.setdefault(y, []).append((x, x))
        elif n == 'DOT':
            for x, y in dot_pixels(d['x'], d['y'], d['a']):
                if clip[0] <= x <= clip[1] and clip[2] <= y <= clip[3]:
                    rows.setdefault(y, []).append((x, x))
        elif n == 'MARKDIRTY':
            rows.setdefault(d['y'], []).append((d['xl'], d['xr']))
    return rows

def main(path, lo, hi):
    T = dict(fr=0, rowext_rows=0, rowext_bytes=0, colext_cols=0, colext_bytes=0, exact_bytes=0, polys=0)
    for it, cyc, grp, calls in load(path, lo, hi):
        rows = frame_pixels(calls)
        T['fr'] += 1
        T['polys'] += sum(1 for d, c in calls if d['name'] == 'POLY')
        cols = {}
        exact = set()
        for y, segs in rows.items():
            l = min(s[0] for s in segs); r = max(s[1] for s in segs)
            T['rowext_rows'] += 1
            T['rowext_bytes'] += (r >> 2) - (l >> 2) + 1
            for a, b in segs:
                for c in range(a >> 2, (b >> 2) + 1):
                    exact.add((y, c))
                    t, bb = cols.get(c, (999, -1))
                    cols[c] = (min(t, y), max(bb, y))
        T['exact_bytes'] += len(exact)
        T['colext_cols'] += len(cols)
        T['colext_bytes'] += sum(b - t + 1 for t, b in cols.values())
    f = T['fr']
    print('%d-%d per frame:' % (lo, hi), {k: round(v / f, 1) for k, v in T.items() if k != 'fr'})
    r = (T['rowext_rows'] * 140 + T['rowext_bytes'] * 5) / f
    c = (T['colext_cols'] * 70 + T['colext_bytes'] * 5) / f
    print('   black repair model: rows %.0f (140/row + 5/byte), cols %.0f (70/col + 5/byte)' % (r, c))

if __name__ == '__main__':
    main(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]))
