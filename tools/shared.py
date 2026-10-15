#!/usr/bin/env python3
"""Whole-ship rendering potential: per frame, partial (masked) bytes of the
faces, and how many of them another face of the frame also writes (bytes on
shared edges, written twice face by face: once each side)."""
import sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from corpus import load
from test_raster import poly_spans

def main(path, lo, hi):
    T = dict(it=0, faces=0, partial=0, shared=0, full=0)
    for it, cyc, grp, calls in load(path, lo, hi):
        T['it'] += 1
        cover = {}
        for d, c in calls:
            if d['name'] != 'POLY': continue
            T['faces'] += 1
            for y, (l, r) in poly_spans(d['verts'], (d['cl'], d['cr'], d['ct'], d['cb'])).items():
                for cc in range(l >> 2, (r >> 2) + 1):
                    full = 4 * cc >= l and 4 * cc + 3 <= r
                    k = cover.setdefault((y, cc), [0, 0])
                    k[0 if full else 1] += 1
        for (y, cc), (f, p) in cover.items():
            T['full'] += f; T['partial'] += p
            if p and f + p >= 2: T['shared'] += p
    n = T['it']
    print('%d-%d per iteration:' % (lo, hi), {k: round(v / n, 1) for k, v in T.items() if k != 'it'})

if __name__ == '__main__':
    main(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]))
