#!/usr/bin/env python3
"""Disc-layer change structure over a corpus window, rows vs columns:
changed bytes split into solid (new byte one colour) and mixed; solid runs
along rows and down byte columns; modelled costs."""
import sys
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from corpus import load, disc_row_pixels

def pic(d):
    return [tuple(tuple(p[4 * c:4 * c + 4]) for c in range(64)) for p in (disc_row_pixels(d, y) for y in range(192))]

def runs(seq):
    out, start = [], None
    for i, v in enumerate(seq + [False]):
        if v and start is None: start = i
        if not v and start is not None: out.append(i - start); start = None
    return out

def analyse(path, lo, hi, quiet=True):
    prev = {}
    T = dict(fr=0, ch=0, mixed=0, solid=0, rr=0, cr=0, rows=0, cols=0, game=0)
    for it, cyc, grp, calls in load(path, lo, hi):
        buf = None
        for d, c in calls:
            if d['name'] == 'SETBUF': buf = d['a']
            if d['name'] != 'DISCROWS': continue
            P = pic(d)
            if buf in prev:
                O = prev[buf]
                ch = [[O[y][c] != P[y][c] for c in range(64)] for y in range(192)]
                mixed = [[ch[y][c] and len(set(P[y][c])) > 1 for c in range(64)] for y in range(192)]
                solid = [[ch[y][c] and not mixed[y][c] for c in range(64)] for y in range(192)]
                rr = sum(len(runs(solid[y])) for y in range(192))
                cr = sum(len(runs([solid[y][c] for y in range(192)])) for c in range(64))
                T['fr'] += 1; T['game'] += c
                T['ch'] += sum(map(sum, ch)); T['mixed'] += sum(map(sum, mixed)); T['solid'] += sum(map(sum, solid))
                T['rr'] += rr; T['cr'] += cr
                T['rows'] += sum(1 for y in range(192) if any(ch[y]))
                T['cols'] += sum(1 for c in range(64) if any(ch[y][c] for y in range(192)))
            prev[buf] = P
    return T

if __name__ == '__main__':
    lo, hi = int(sys.argv[2]), int(sys.argv[3])
    T = analyse(sys.argv[1], lo, hi)
    f = max(1, T['fr'])
    print('iterations %d-%d, %d disc frames; per frame:' % (lo, hi, T['fr']), {k: round(v / f) for k, v in T.items() if k != 'fr'})
    # cost models (cycles): rows: per solid run 100 + 5/byte; columns: per run 75 + 7.5/byte; mixed 30 each
    for name, ro, rb, co, cb, mx in (('model A', 100, 5, 75, 7.5, 30), ('model B (2-pass cols)', 100, 5, 110, 5, 30)):
        r = (T['rr'] * ro + T['solid'] * rb + T['mixed'] * mx) / f
        cc = (T['cr'] * co + T['solid'] * cb + T['mixed'] * mx) / f
        print('  %s: rows %.0f  cols %.0f  (writes only)' % (name, r, cc))
