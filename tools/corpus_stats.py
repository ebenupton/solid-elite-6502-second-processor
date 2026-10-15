#!/usr/bin/env python3
"""Per-window accounting of a capture corpus: cycles per iteration by bank and
by rasteriser call, and the polygons' shapes."""
import sys
from collections import defaultdict
sys.path.insert(0, __file__.rsplit('/', 1)[0])
from corpus import load

def poly_rows(verts, ct=1, cb=191, cl=2, cr=253):
    import math
    ys = [v[1] for v in verts]
    y0, y1 = max(ct, min(ys)), min(cb, max(ys) - 1)
    rows = px = 0
    n = len(verts)
    for y in range(y0, y1 + 1):
        xs = []
        for i in range(n):
            (xa, ya), (xb, yb) = verts[i], verts[(i + 1) % n]
            if ya == yb: continue
            if ya > yb: xa, ya, xb, yb = xb, yb, xa, ya
            if ya <= y < yb: xs.append(xa + -((-(xb - xa) * (y - ya)) // (yb - ya)))
        if len(xs) < 2: continue
        l, r = max(min(xs), cl), min(max(xs), cr + 1) - 1
        if l <= r: rows += 1; px += r - l + 1
    return rows, px

path = sys.argv[1]
W = int(sys.argv[2]) if len(sys.argv) > 2 else 200
acc = None
def flush(w):
    n = acc['n']
    print('window %4d-%4d: %7.0f cyc/it (%.2f it/s)  ' % (w, w + W - 1, acc['cyc'] / n, 2e6 * n / acc['cyc'])
          + ' '.join('%s %.0f' % (k, v / n) for k, v in sorted(acc['grp'].items(), key=lambda x: -x[1])))
    print('   calls/it: ' + ' '.join('%s %d×%.0f=%.0f' % (k, acc['cnt'][k] / n, acc['ccy'][k] / max(1, acc['cnt'][k]), acc['ccy'][k] / n)
                                   for k in sorted(acc['ccy'], key=lambda k: -acc['ccy'][k])))
    p = acc['poly']
    if p[0]:
        print('   polys/it %.1f, rows/poly %.1f, px/poly %.0f, cyc/poly %.0f, cyc/row %.0f' % (p[0] / n, p[1] / p[0], p[2] / p[0], p[3] / p[0], p[3] / max(1, p[1])))
cw = -1
for it, cyc, grp, calls in load(path):
    w = it // W * W
    if w != cw:
        if acc: flush(cw)
        cw = w
        acc = dict(n=0, cyc=0, grp=defaultdict(int), cnt=defaultdict(int), ccy=defaultdict(int), poly=[0, 0, 0, 0])
    acc['n'] += 1; acc['cyc'] += cyc
    for k, v in grp.items(): acc['grp'][k] += v
    for d, c in calls:
        acc['cnt'][d['name']] += 1; acc['ccy'][d['name']] += c
        if d['name'] == 'POLY':
            r, px = poly_rows(d['verts'])
            p = acc['poly']; p[0] += 1; p[1] += r; p[2] += px; p[3] += c
flush(cw)
