"""tube_onepass.py -- test_onepass.py's --tube mode: a differential test of the
Tube parasite's R_POLY (tube/src/p-polya.asm, gfx-raster_poly.asm and
gfx-raster_onepass.asm, p-emit.asm) between two builds.

    python3 master/tools/grind/test_onepass.py --tube REF CAND [--seed N] [--n N]
        [--kinds k,..] [--corpus F] [--kmode]

REF and CAND are tube build directories (PCODE.bin, HOVS.bin, PHIGH.bin,
psyms.txt).  Each build's parasite image (the resident code, overlay S over
the overlay region, the high area) runs in its own py65 65C02; register 1's
status always has room, and every byte written to its data register is
recorded.  For each polygon (R_PN, R_PXL/PXH/PYL/PYH, the clip window, the
four colours) both run T_POLY; the recorded bytes and the rasteriser's state
(this buffer's dirty extents and disc span arrays, r_dyt, r_dyb) must be the
same.  The buffer changes now and then (T_SETBUF), as do the clip window and
the colours.  --kmode runs with KMODE set (K mode: the kept rows' pass for
each row); T_KFRAME is not run, so this covers the pass with no kept rows.

Kinds: test_raster's (small, screen, big, huge, edge, tiny, degen), and
  cross    a convex polygon with two vertices swapped (self-crossing)
  bow      a bow tie: four points, the middle two in the other order
  thin     a sliver: a convex polygon a pixel or less wide, its vertices
           rounded (the rounding often crosses it over)
  thin16   the same, partly outside 0..255 (the 16-bit path)
  cross16  cross with coordinates outside 0..255
  nonmono  vertices in random order (chains not monotone in y; reported
           apart: not exact by design, R_POLY's faces are convex)
--corpus F: a file of polygons recorded from a run (tube/tools/tpolycap.mjs:
one JSON list a line: n, xs, ys, clip, colours), replayed first.
"""
import os, re, sys, random, math, json, argparse
from py65.devices.mpu65c02 import MPU
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(REPO, 'tools'))
import test_raster as tr                       # noqa: E402 (random_poly, convex_hull)

PR1S, PR1D, PR4S = 0xFEF8, 0xFEF9, 0xFEFE
RET = 0xFFF0                                   # (a return address: BRK there)


class Par:
    def __init__(self, d):
        s = open(os.path.join(d, 'psyms.txt')).read()
        self.syms = {m.group(1): int(m.group(2)) for m in re.finditer(r"'([^']+)':(\d+)", s)}
        mem = bytearray(65536)
        pc = open(os.path.join(d, 'PCODE.bin'), 'rb').read()
        code = self.syms.get('PSTG_END', self.syms['PCODE_END']) - len(pc)   # (with the boot's staging)
        mem[code:code + len(pc)] = pc
        if 'PSTG_FF' in self.syms:              # (p_boot's copies: the page at &FF00, pages 2 and 3)
            f = self.syms['PSTG_FF']
            mem[0xFF00:0x10000] = mem[f:f + 256]
            if 'PSTG_LO' in self.syms:
                lo = self.syms['PSTG_LO']
                mem[0x200:0x400] = mem[lo:lo + 512]
        ov = open(os.path.join(d, 'HOVS.bin'), 'rb').read()
        o = self.syms['OVL_START']
        mem[o:o + len(ov)] = ov
        hi = open(os.path.join(d, 'PHIGH.bin'), 'rb').read()
        mem[0xF800:0xF800 + len(hi)] = hi
        self.out = []
        par = self

        class Mem(bytearray):
            def __getitem__(self, a):
                if a == PR1S:
                    return 0x40                # (room)
                if a == PR4S:
                    raise RuntimeError('register 4 read at &%04X' % par.mpu.pc)
                return bytearray.__getitem__(self, a)

            def __setitem__(self, a, v):
                if a == PR1D:
                    par.out.append(v)
                    return
                bytearray.__setitem__(self, a, v)
        self.mem = Mem(mem)
        self.mpu = MPU(memory=self.mem)

    def call(self, name, a=0, x=0, y=0):
        mpu, mem = self.mpu, self.mem
        mpu.a, mpu.x, mpu.y, mpu.p = a, x, y, 0x24
        mpu.sp = 0xFF
        mem[0x1FF], mem[0x1FE] = (RET - 1) >> 8, (RET - 1) & 0xFF
        mpu.sp = 0xFD
        mpu.pc = self.syms[name]
        n = 0
        while mpu.pc != RET:
            mpu.step()
            n += 1
            if n > 2_000_000:
                raise RuntimeError('runaway at &%04X' % mpu.pc)
        return mpu.processorCycles

    def wr(self, name, v, i=0):
        self.mem[self.syms[name] + i] = v & 0xFF

    def state(self):
        """the rasteriser's state that a polygon changes: both buffers' dirty
        extents and disc span arrays, and their dirty row ranges"""
        out = []
        for b in '01':
            for n in ('R_DIRTYL', 'R_DIRTYR', 'R_DISCL', 'R_DISCR'):
                a = self.syms[n + b]
                out.append(bytes(self.mem[a:a + 192]))
        for n in ('r_dyt', 'r_dyb'):
            a = self.syms[n]
            out.append(bytes(self.mem[a:a + 2]))
        return out


def thin_poly(rnd, big):
    """a convex sliver at most about a pixel wide, rounded"""
    if big:
        cx, cy, L = rnd.randrange(-400, 650), rnd.randrange(-400, 600), rnd.uniform(50, 1500)
    else:
        cx, cy, L = rnd.uniform(0, 256), rnd.uniform(0, 192), rnd.uniform(3, 200)
    a = rnd.random() * math.pi
    w = rnd.uniform(0.05, 1.5)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx
    k = rnd.randrange(3, 7)
    # points along the long axis, pushed out to either side, convex order
    ts = sorted(rnd.uniform(-L / 2, L / 2) for _ in range(k))
    side1 = [(cx + t * dx + nx * w * rnd.random(), cy + t * dy + ny * w * rnd.random()) for t in ts]
    ts2 = sorted((rnd.uniform(-L / 2, L / 2) for _ in range(k)), reverse=True)
    side2 = [(cx + t * dx - nx * w * rnd.random(), cy + t * dy - ny * w * rnd.random()) for t in ts2]
    pts = [(int(round(x)), int(round(y))) for x, y in side1 + side2]
    out = []
    for p in pts:                              # (drop repeats, as a projection might not)
        if not out or out[-1] != p or rnd.random() < 0.2:
            out.append(p)
    if rnd.random() < 0.5:
        out = out[::-1]
    j = rnd.randrange(len(out))
    return (out[j:] + out[:j])[:16]


def make_poly(rnd, kind):
    if kind in ('cross', 'cross16'):
        while True:
            P = tr.random_poly(rnd, 'big' if kind == 'cross16' else rnd.choice(['small', 'screen', 'edge']))
            if len(P) >= 4:
                break
        i = rnd.randrange(len(P))
        j = (i + rnd.choice([1, 2])) % len(P)
        P = list(P)
        P[i], P[j] = P[j], P[i]
        return P
    if kind == 'bow':
        x0, y0 = rnd.randrange(0, 256), rnd.randrange(0, 192)
        P = [(x0 + rnd.randrange(-60, 60), y0 + rnd.randrange(-60, 60)) for _ in range(4)]
        return P
    if kind in ('thin', 'thin16'):
        return thin_poly(rnd, kind == 'thin16')
    if kind == 'nonmono':
        return [(rnd.randrange(-20, 280), rnd.randrange(-20, 210)) for _ in range(rnd.randrange(3, 9))]
    return tr.random_poly(rnd, kind)


KINDS = ['small', 'screen', 'big', 'huge', 'edge', 'tiny', 'degen', 'cross', 'bow', 'thin', 'thin16', 'cross16']


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument('--tube', nargs=2, required=True)
    ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('--n', type=int, default=3000)
    ap.add_argument('--kinds', default=','.join(KINDS))
    ap.add_argument('--corpus')
    ap.add_argument('--kmode', action='store_true')
    ap.add_argument('--cycles', action='store_true', help='report the cycles of each build')
    a = ap.parse_args(argv)
    ms = [Par(d) for d in a.tube]
    for m in ms:
        m.call('T_INIT')
        if a.kmode:
            m.wr('KMODE', 0x80)
        m.out.clear()
    rnd = random.Random(a.seed)
    kinds = a.kinds.split(',')
    polys = []
    if a.corpus:
        for l in open(a.corpus):
            if l.strip():
                polys.append(('corpus', json.loads(l)))
    for it in range(a.n):
        k = rnd.choice(kinds)
        P = make_poly(rnd, k)
        if it % 40 == 0 or not polys:
            if rnd.random() < 0.3:
                cl = rnd.randrange(1, 100)
                ct = rnd.randrange(0, 100)
                clip = [cl, rnd.randrange(cl, 255), ct, rnd.randrange(ct, 192)]
            else:
                clip = [rnd.choice([1, 2]), rnd.choice([253, 254]), 1, 191]
        cols = [rnd.randrange(256) for _ in range(4)]
        polys.append((k, dict(xs=[p[0] for p in P], ys=[p[1] for p in P], clip=clip, cols=cols,
                              buf=rnd.random() < 0.02)))
    stats, bad, cyc, kcyc = {}, {}, [0, 0], {}
    for i, (k, d) in enumerate(polys):
        n = len(d['xs'])
        res = []
        for mi, m in enumerate(ms):
            if d.get('buf'):
                m.call('T_SETBUF', a=rnd.randrange(2) if False else (i & 1))
            m.wr('R_PN', n)
            for j in range(min(n, 16)):
                x, y = d['xs'][j], d['ys'][j]
                m.wr('R_PXL', x, j); m.wr('R_PXH', x >> 8, j)
                m.wr('R_PYL', y, j); m.wr('R_PYH', y >> 8, j)
            for nm, v in zip(('R_CL', 'R_CR', 'R_CT', 'R_CB'), d['clip']):
                m.mem[{'R_CL': 0x0A, 'R_CR': 0x0B, 'R_CT': 0x0C, 'R_CB': 0x0D}[nm]] = v
            for adr, v in zip((0x06, 0x07), d['cols'][:2]):
                m.mem[adr] = v
            m.wr('R_COL2', d['cols'][2]); m.wr('R_COL3', d['cols'][3])
            m.out.clear()
            c0 = m.mpu.processorCycles
            m.call('T_POLY')
            cyc[mi] += m.mpu.processorCycles - c0
            kcyc.setdefault(k, [0, 0])[mi] += m.mpu.processorCycles - c0
            res.append((list(m.out), m.state()))
        st = stats.setdefault(k, [0, 0])
        st[0] += 1
        if res[0] != res[1]:
            if not bad:                        # (the first: in detail, as the state
                o0, o1 = res[0][0], res[1][0]  # carries on from it)
                j = next((q for q in range(min(len(o0), len(o1))) if o0[q] != o1[q]), min(len(o0), len(o1)))
                print('FIRST DIFFERENCE: polygon %d (%s) %s' % (i, k, json.dumps(d)))
                print('  bytes from %d: ref %s\n                 cand %s' % (j, o0[j:j + 24], o1[j:j + 24]))
                names = ['%s%s' % (n, b) for b in '01' for n in ('R_DIRTYL', 'R_DIRTYR', 'R_DISCL', 'R_DISCR')] + ['r_dyt', 'r_dyb']
                for nm, x0, x1 in zip(names, res[0][1], res[1][1]):
                    if x0 != x1:
                        q = [r for r in range(len(x0)) if x0[r] != x1[r]]
                        print('  state %s differs at %s: ref %s cand %s' % (nm, q[:6], [x0[r] for r in q[:6]], [x1[r] for r in q[:6]]))
            st[1] += 1
            if k not in bad:
                bad[k] = (d, res[0][0][:40], res[1][0][:40])
    print('polygons %d (%s)' % (len(polys), ', '.join('%s %d' % (k, v[0]) for k, v in sorted(stats.items()))))
    if a.cycles:
        print('cycles: ref %d, cand %d (%.1f%%)' % (cyc[0], cyc[1], 100.0 * cyc[1] / max(1, cyc[0])))
        print('  by kind (a polygon): ' + ', '.join('%s %d/%d' % (k, v[0] // stats[k][0], v[1] // stats[k][0]) for k, v in sorted(kcyc.items())))
    if not bad:
        print('identical: every polygon\'s bytes to the host and the state after it')
        return 0
    for k, (d, r0, r1) in bad.items():
        print('DIFFER %s: %d of %d; first: %s\n  ref  %s\n  cand %s' % (k, stats[k][1], stats[k][0], json.dumps(d), r0, r1))
    return 0 if set(bad) <= {'nonmono'} else 1
