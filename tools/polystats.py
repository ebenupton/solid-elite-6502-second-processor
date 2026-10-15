#!/usr/bin/env python3
"""Polygon fill structure over a corpus window: per face rows, full bytes,
partial (masked) bytes, byte columns with full bytes; modelled costs."""
import sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from corpus import load
from test_raster import poly_spans

def face(verts, clip):
    sp = poly_spans(verts, clip)
    rows = len(sp); full = part = 0; cols = set()
    for y, (l, r) in sp.items():
        cl, cr = (l + 3) >> 2, (r + 1) >> 2          # full columns cl..cr-1
        if cl < cr:
            full += cr - cl
            cols.update(range(cl, cr))
            part += (l & 3 != 0) + (r & 3 != 3)
        else:
            part += 1 if (l >> 2) == (r >> 2) else 2
    return rows, full, part, len(cols)

def main(path, lo, hi):
    T = dict(n=0, rows=0, full=0, part=0, cols=0, game=0)
    for it, cyc, grp, calls in load(path, lo, hi):
        for d, c in calls:
            if d['name'] != 'POLY': continue
            r, f, p, cc = face(d['verts'], (d['cl'], d['cr'], d['ct'], d['cb']))
            T['n'] += 1; T['rows'] += r; T['full'] += f; T['part'] += p; T['cols'] += cc; T['game'] += c
    it = hi - lo
    print('%d-%d per iteration:' % (lo, hi), {k: round(v / it) for k, v in T.items()})
    n = T['n']
    for name, S, R, B, C, CB in (('rows tight (S1000 R130)', 1000, 130, 5, 0, 0),
                                 ('cols (S1000 R100 C70 7.5/b)', 1000, 100, 0, 70, 7.5),
                                 ('cols (S1000 R80 C70 7.5/b)', 1000, 80, 0, 70, 7.5)):
        cost = n * S + T['rows'] * R + T['full'] * B + T['cols'] * C + T['full'] * CB
        print('   %-30s %7.0f /it' % (name, cost / it))

if __name__ == '__main__':
    main(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]))
