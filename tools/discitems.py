#!/usr/bin/env python3
"""Bookkeeping items of the disc picture, rows vs byte columns: per row, the
edges of the pixel picture (span ends + boundaries, as the row disc layer
keeps them); per byte column, the rows at which the column's byte content
class changes (black / solid A / solid B / mixed) -- what a column disc layer
would have to keep and diff -- and the mixed bytes (whose masks need each
row's x anyway)."""
import sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from corpus import load, disc_row_pixels

def main(path, lo, hi):
    T = dict(fr=0, rowitems=0, colitems=0, mixed=0, colmixruns=0)
    for it, cyc, grp, calls in load(path, lo, hi):
        for d, c in calls:
            if d['name'] != 'DISCROWS' or d['ndt'] > d['ndb']: continue
            P = [disc_row_pixels(d, y) for y in range(192)]
            T['fr'] += 1
            for y in range(192):
                row = P[y]
                T['rowitems'] += sum(1 for x in range(1, 256) if row[x] != row[x - 1])
            for c in range(64):
                prev = None; inmix = False
                for y in range(192):
                    px = P[y][4 * c:4 * c + 4]
                    cls = ('m' if len(set(px)) > 1 else px[0])
                    if cls != prev and prev is not None: T['colitems'] += 1
                    if cls == 'm':
                        T['mixed'] += 1
                        if not inmix: T['colmixruns'] += 1
                    inmix = cls == 'm'
                    prev = cls
    f = max(1, T['fr'])
    print('%d-%d, %d disc frames, per frame:' % (lo, hi, T['fr']), {k: round(v / f) for k, v in T.items() if k != 'fr'})

if __name__ == '__main__':
    main(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]))
