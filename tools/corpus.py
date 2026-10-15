#!/usr/bin/env python3
"""Parse a harness/capture.mjs corpus (one JSON line per TT100 iteration) into
call records, and some reference geometry helpers for analysing it."""
import json


def zp(b):
    return dict(cole=b[0], colo=b[1], xl=b[2], xr=b[3], cl=b[4], cr=b[5], ct=b[6], cb=b[7], dce=b[8], dco=b[9])


def s8(lo, hi):
    v = lo | (hi << 8)
    return v - 65536 if v & 0x8000 else v


def decode(name, h):
    b = bytes.fromhex(h)
    d = {'name': name}
    if name == 'SETBUF':
        d['a'] = b[0]
    elif name in ('POLY', 'LINE', 'DOT', 'SPAN', 'MARKDIRTY', 'STARPLOT', 'DISCROWS', 'CLEARALL'):
        d.update(zp(b[:10]))
        a = b[10:]
        if name == 'POLY':
            n = a[0]
            d['verts'] = [(s8(a[1 + i], a[17 + i]), s8(a[33 + i], a[49 + i])) for i in range(min(n, 16))]
        elif name == 'LINE':
            d['line'] = (s8(a[0], a[1]), s8(a[2], a[3]), s8(a[4], a[5]), s8(a[6], a[7]))
        elif name == 'DOT':
            d['a'], d['x'], d['y'] = a[0], a[1], a[2]
        elif name in ('SPAN', 'MARKDIRTY'):
            d['y'] = a[0]
        elif name == 'STARPLOT':
            n = a[0]
            d['stars'] = [(a[1 + i], a[25 + i], a[49 + i]) for i in range(n)]
            d['scol'] = a[73]
        elif name == 'DISCROWS':
            t, bb = a[0], a[1]
            d['ndt'], d['ndb'] = t, bb
            d['ndf'], d['dbe'], d['dbo'] = a[2], a[3], a[4]
            rows = {}
            if t <= bb:
                n = bb - t + 1
                r = a[5:]
                arr = [r[k * n:(k + 1) * n] for k in range(8)]
                for i in range(n):
                    rows[t + i] = (arr[0][i], arr[1][i], arr[2][i], arr[3][i], [arr[4 + k][i] for k in range(4)])
            d['rows'] = rows       # y: (L, R, N, P, [x0..x3])
    return d


def load(path, lo=0, hi=None):
    """Yield (it, cyc, grp, [(decoded, cycles), ...]) for iterations lo..hi-1."""
    with open(path) as f:
        for line in f:
            r = json.loads(line)
            if r['it'] < lo:
                continue
            if hi is not None and r['it'] >= hi:
                break
            yield r['it'], r['cyc'], r['grp'], [(decode(n, h), c) for n, c, h in r['calls']]


def disc_row_pixels(d, y, cl=2, cr=253):
    """Colour index per pixel x of row y of a DISCROWS record: 0 none, 1 A, 2 B."""
    out = [0] * 256
    if y not in d['rows']:
        return out
    L, R, N, P, X = d['rows'][y]
    if L == 255 or L > R:
        return out
    L, R = max(L, cl), min(R, cr)
    xs = sorted(X[:N]) if d['ndf'] else []
    for x in range(L, R + 1):
        c = (P & 1) if d['ndf'] else 0
        for b in xs:
            if b <= x:
                c ^= 1
        out[x] = 1 + c
    return out
