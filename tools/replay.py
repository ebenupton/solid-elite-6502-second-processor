#!/usr/bin/env python3
"""Replay a capture corpus (harness/capture.mjs) through the rasteriser in
py65 and report cycles per call type, per window; compare with the in-game
cycles recorded in the corpus.

    python3 tools/replay.py CORPUS [--lo N] [--hi N] [--win 200]
        [--src src/raster.asm] [--save-state DIR --at 1000,1400]
        [--load-state FILE] [--screens DIR]

Two screens are kept (buffer 0 / 1): SETBUF swaps them in and out of the
machine's &4000-&6FFF.  DISCDIRTY (the frame layer's f_discdirty, which
pokes the rasteriser's arrays) is emulated here.
"""
import argparse
import os
import pickle
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import test_raster as tr
from corpus import load

ZPN = ('R_COLE', 'R_COLO', 'R_XL', 'R_XR', 'R_CL', 'R_CR', 'R_CT', 'R_CB', 'R_DCE', 'R_DCO')


class Replayer:
    def __init__(self, src=None, org=0x8000):
        if src:
            tr.SRC = os.path.abspath(src)
        self.m = tr.Machine(org, 1)
        self.m.guard = False
        m = self.m
        for a in range(0x4000, 0x7000):
            m.mem[a] = 0
        self.screens = [bytes(0x3000), bytes(0x3000)]
        self.buf = 0
        m.call('R_INIT')
        m.call('R_SETBUF', a=0)
        self.buf = 0

    def setzp(self, d):
        m = self.m
        for n in ZPN:
            m.mem[tr.ZP[n]] = d[n[2:].lower()]

    def setbuf(self, b):
        m = self.m
        if b != self.buf:
            self.screens[self.buf] = bytes(m.mem[0x4000:0x7000])
            m.mem[0x4000:0x7000] = list(self.screens[b])
            self.buf = b

    def do(self, d):
        m, n = self.m, d['name']
        if n == 'SETBUF':
            self.setbuf(d['a'] & 1)
            return m.call('R_SETBUF', a=d['a'])
        if n == 'DISCDIRTY':
            b = self.buf
            dl, dr = m.s('R_DIRTYL0') + 0x300 * b, m.s('R_DIRTYR0') + 0x300 * b
            sl, sr = m.s('R_DISCL0') + 0x300 * b, m.s('R_DISCR0') + 0x300 * b
            for y in range(192):
                if m.mem[sl + y] < m.mem[dl + y]:
                    m.mem[dl + y] = m.mem[sl + y]
                if m.mem[sr + y] >= m.mem[dr + y]:
                    m.mem[dr + y] = m.mem[sr + y]
            return 0
        if n in ('RESETBUF', 'STARERASE', 'WMERGE', 'INIT'):
            return m.call('R_' + n)
        self.setzp(d)
        if n == 'CLEARALL':
            return m.call('R_CLEARALL')
        if n == 'POLY':
            v = d['verts']
            m.wr('R_PN', len(v))
            for i, (x, y) in enumerate(v):
                m.wr('R_PXL', x & 255, i); m.wr('R_PXH', (x >> 8) & 255, i)
                m.wr('R_PYL', y & 255, i); m.wr('R_PYH', (y >> 8) & 255, i)
            return m.call('R_POLY')
        if n == 'LINE':
            for nm, v in zip(('R_X0', 'R_Y0', 'R_X1', 'R_Y1'), d['line']):
                m.wr(nm, v & 255); m.wr(nm, (v >> 8) & 255, 1)
            return m.call('R_LINE')
        if n == 'DOT':
            return m.call('R_DOT', a=d['a'], x=d['x'], y=d['y'])
        if n in ('SPAN', 'MARKDIRTY'):
            return m.call('R_' + n, y=d['y'])
        if n == 'STARPLOT':
            m.wr('R_SN', len(d['stars']))
            for i, (x, y, s) in enumerate(d['stars']):
                m.wr('R_SX', x, i); m.wr('R_SY', y, i); m.wr('R_SS', s, i)
            m.wr('R_SCOL', d['scol'])
            return m.call('R_STARPLOT')
        if n == 'DISCROWS':
            m.wr('R_NDT', d['ndt']); m.wr('R_NDB', d['ndb'])
            m.wr('R_NDF', d['ndf']); m.wr('R_DBE', d['dbe']); m.wr('R_DBO', d['dbo'])
            for y, (L, R, N, P, X) in d['rows'].items():
                m.wr('R_NDISCL', L, y); m.wr('R_NDISCR', R, y)
                m.wr('R_NDN', N, y); m.wr('R_NDP', P, y)
                for k in range(4):
                    m.wr('R_NDX%d' % k, X[k], y)
            return m.call('R_DISCROWS')
        raise ValueError(n)

    def state(self):
        self.screens[self.buf] = bytes(self.m.mem[0x4000:0x7000])
        return dict(mem=list(self.m.mem), screens=list(self.screens), buf=self.buf, bank=self.m.bank,
                    banks={k: (list(v) if v is not None else None) for k, v in self.m.banks.items()})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('corpus')
    ap.add_argument('--lo', type=int, default=0)
    ap.add_argument('--hi', type=int, default=None)
    ap.add_argument('--win', type=int, default=200)
    ap.add_argument('--src', default=None)
    ap.add_argument('--verbose', action='store_true')
    ap.add_argument('--prof', action='store_true', help='cycles by routine label')
    ap.add_argument('--proflo', type=int, default=0, help='profile from this iteration')
    a = ap.parse_args()
    r = Replayer(a.src)
    prof = None
    if a.prof:
        prof = defaultdict(int)
        live = [False]
        install_prof(r.m, prof, live)
    acc = None
    cw = None

    def flush():
        n = acc['n']
        print('window %d (%d its): replay %s' % (cw, n, ' '.join('%s %.0f' % (k, v / n) for k, v in sorted(acc['rep'].items(), key=lambda x: -x[1]))))
        print('      in-game          %s' % ' '.join('%s %.0f' % (k, acc['game'][k] / n) for k, v in sorted(acc['rep'].items(), key=lambda x: -x[1])))
        print('      total replay %.0f  in-game %.0f' % (sum(acc['rep'].values()) / n, sum(acc['game'].values()) / n))
        sys.stdout.flush()
    for it, cyc, grp, calls in load(a.corpus, a.lo, a.hi):
        w = it // a.win * a.win
        if w != cw:
            if acc:
                flush()
            cw = w
            acc = dict(n=0, rep=defaultdict(int), game=defaultdict(int))
        acc['n'] += 1
        if prof is not None:
            live[0] = it >= a.proflo
        for d, c in calls:
            rc = r.do(d)
            acc['rep'][d['name']] += rc
            acc['game'][d['name']] += c
    if acc:
        flush()
    if prof is not None:
        report_prof(r.m, prof, a.hi - max(a.lo, a.proflo) if a.hi else 1)


def install_prof(m, prof, live):
    mpu = m.mpu
    orig = mpu.step
    def step():
        if not live[0]:
            return orig()
        pc = mpu.pc
        c = mpu.processorCycles
        orig()
        prof[(pc, m.bank)] += mpu.processorCycles - c
    mpu.step = step


def report_prof(m, prof, n):
    labs = sorted((v, k) for k, v in m.syms.items() if not k.startswith(('r_pt', 'R_P')) and 0x8000 <= v < 0xC000)
    import bisect
    keys = [v for v, k in labs]
    agg = defaultdict(int)
    for (pc, bank), c in prof.items():
        i = bisect.bisect_right(keys, pc) - 1
        agg[(labs[i][1] if i >= 0 else '?') + ('' if bank == 5 else '@%d' % bank)] += c
    tot = sum(agg.values())
    for k, v in sorted(agg.items(), key=lambda x: -x[1])[:40]:
        print('  %-24s %8.0f /it %5.1f%%' % (k, v / n, 100 * v / tot))


if __name__ == '__main__':
    main()
