#!/usr/bin/env python3
"""test_onepass.py -- the one-pass span generator prototype (R_SPANS,
master/src/gfx-raster_onepass.asm), against the reference and against R_POLY's
two-phase path.

    GRIND_TREE=<tree> python3 master/tools/grind/test_onepass.py [--seed N] [--n 3000]

Assembles the rasteriser as test_raster.py does, with ONEPASS = TRUE (r_e8's
DDA entries divert into the generator when it asks) and the generator in the
test's HAZEL-like area.  For random polygons (test_raster's kinds, and clip
windows), R_SPANS hands every row's span to a recorder; the spans must be the
reference's (poly_spans) exactly.  Cycles: R_SPANS with an emitter that only
returns, against the two-phase path doing the same job (R_POLY up to its
phase B, r_pdirty: edge tables, orientation, clip, trim; then a loop reading
the tables and handing each row on to the same emitter).
"""
import os, sys, random, argparse, importlib.util
HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True
_spec = importlib.util.spec_from_file_location('mtest_raster', os.path.join(HERE, 'test_raster.py'))
mt = importlib.util.module_from_spec(_spec)      # the Master adapter (it imports the
_spec.loader.exec_module(mt)                     # demo's test_raster itself)
tr = mt.tr

ONEPASS_SRC = os.path.join(mt.MS, 'gfx-raster_onepass.asm')
_gc = mt.gfx_constants


def gfx_constants():
    out = [l for l in _gc().split('\n') if not l.startswith('ONEPASS')]
    return '\n'.join(out + ['ONEPASS = TRUE'])


mt.gfx_constants = gfx_constants
mt.KEPT_HZ += '''INCLUDE "%s"
.f_emitrec                \\ the recorder: xl, xr + 1 per row
  STA f_rr,Y
  TXA
  STA f_rl,Y
  RTS
.f_tabemit                \\ the two-phase path's hand-off: R_POLY's tables, rows
  LDA r_pbl1_e+1          \\ r_ystart..r_ylast, its orientation (r_pcbd's patches)
  STA otl+1
  LDA r_pbl1_e+2
  STA otl+2
  LDA r_pbr1_e+1
  STA otr1+1
  STA otr2+1
  LDA r_pbr1_e+2
  STA otr1+2
  STA otr2+2
  LDY r_ystart
.otlp
.otl
  LDA &FFFF,Y
.otr1
  CMP &FFFF,Y
  BCS otsk
  TAX
.otr2
  LDA &FFFF,Y
.otem
  JSR f_emitnull
.otsk
  INY
  CPY r_yend
  BCC otlp
  RTS
.f_rl SKIP 192
.f_rr SKIP 192
''' % ONEPASS_SRC


def run_to(m, entry, stops, bank):
    """run from entry with ROMSEL bank until a stop PC or the return; cycles, pc"""
    m.page(bank)
    mpu, mem = m.mpu, m.mem
    mpu.p = 0x24
    ret = tr.RET - 1
    mem[0x1FF] = ret >> 8
    mem[0x1FE] = ret & 0xFF
    mpu.sp = 0xFD
    mpu.pc = m.syms[entry]
    c0 = mpu.processorCycles
    while mpu.pc != tr.RET and mpu.pc not in stops:
        mpu.step()
        rs = mem[tr.ROMSEL]
        if rs != m.romsel:
            m.page(rs)
        if mpu.processorCycles - c0 > 5_000_000:
            raise RuntimeError('runaway at &%04X' % mpu.pc)
    return mpu.processorCycles - c0, mpu.pc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--seed', type=int, default=1)
    ap.add_argument('--n', type=int, default=3000)
    a = ap.parse_args()
    m = mt.Machine(0x8000, a.seed)
    rnd = random.Random(a.seed)
    m.call('R_INIT')
    m.call('R_SETBUF', a=0)
    s = m.syms
    poly = mt.ENTRY_BANK['R_POLY']
    clip = (1, 254, 1, 191)
    stats = dict(handled=0, nothandled=0, rows=0, new=0, old=0, spans=0)
    kinds = {}
    pts = []

    def setjsr(at, tgt):
        m.mem[at + 1] = tgt & 0xFF
        m.mem[at + 2] = tgt >> 8

    for it in range(a.n):
        if it % 40 == 0:
            if rnd.random() < 0.3:
                cl = rnd.randrange(1, 100)
                ct = rnd.randrange(0, 100)
                clip = (cl, rnd.randrange(cl, 255), ct, rnd.randrange(ct, 192))
            else:
                clip = (1, 254, 1, 191)
            for n, v in zip(('R_CL', 'R_CR', 'R_CT', 'R_CB'), clip):
                m.wzp(n, v)
        kind = rnd.choice(['small', 'small', 'screen', 'edge', 'tiny', 'degen', 'big'])
        verts = tr.random_poly(rnd, kind)
        m.wr('R_PN', len(verts))
        for i, (x, y) in enumerate(verts[:16]):
            m.wr('R_PXL', x & 0xFF, i)
            m.wr('R_PXH', (x >> 8) & 0xFF, i)
            m.wr('R_PYL', y & 0xFF, i)
            m.wr('R_PYH', (y >> 8) & 0xFF, i)
        ref = tr.poly_spans(verts, clip)
        # the generator, recording
        setjsr(s['fem'], s['f_emitrec'])
        setjsr(s['fem2'], s['f_emitrec'])
        for y in range(192):
            m.mem[s['f_rl'] + y] = 0xFF
            m.mem[s['f_rr'] + y] = 0
        m.guard = False
        m.call('R_SPANS', bank=poly)
        c = m.mpu.p & 1
        k = kinds.setdefault(kind, [0, 0])
        if c:
            stats['nothandled'] += 1
            k[1] += 1
            continue
        k[0] += 1
        got = {y: (m.mem[s['f_rl'] + y], m.mem[s['f_rr'] + y] - 1)
               for y in range(192) if m.mem[s['f_rl'] + y] != 0xFF}
        if got != ref:
            ys = sorted(set(got) ^ set(ref) | {y for y in got if y in ref and got[y] != ref[y]})
            raise AssertionError('poly %s clip %s: rows %s got %s ref %s'
                                 % (verts, clip, ys[:6], [got.get(y) for y in ys[:3]], [ref.get(y) for y in ys[:3]]))
        stats['handled'] += 1
        stats['rows'] += len(range(max(clip[2], min(v[1] for v in verts)), min(clip[3], max(v[1] for v in verts) - 1) + 1))
        stats['spans'] += len(ref)
        # timing: the generator with an emitter that returns
        setjsr(s['fem'], s['f_emitnull'])
        setjsr(s['fem2'], s['f_emitnull'])
        cn, _ = run_to(m, 'R_SPANS', (), poly)
        # the two-phase path: R_POLY to r_pdirty, then the tables handed on
        co, pc = run_to(m, 'R_POLY', (s['r_pdirty'],), poly)
        if pc == s['r_pdirty']:
            setjsr(s['otem'], s['f_emitnull'])
            ct, _ = run_to(m, 'f_tabemit', (), poly)
            co += ct
        stats['new'] += cn
        stats['old'] += co
        pts.append((len(range(max(clip[2], min(v[1] for v in verts)), min(clip[3], max(v[1] for v in verts) - 1) + 1)), cn, co, len(verts)))
    h = stats['handled']
    print('handled %d, not handled %d (by kind: %s)' % (h, stats['nothandled'],
          ', '.join('%s %d/%d' % (k, v[0], v[0] + v[1]) for k, v in sorted(kinds.items()))))
    print('spans exact: %d polygons, %d spans, %d rows in their y ranges' % (h, stats['spans'], stats['rows']))
    print('cycles: one-pass %d, two-phase %d (%.1f%%); per row %.1f vs %.1f, saved %.1f'
          % (stats['new'], stats['old'], 100.0 * stats['new'] / max(1, stats['old']),
             stats['new'] / max(1, stats['rows']), stats['old'] / max(1, stats['rows']),
             (stats['old'] - stats['new']) / max(1, stats['rows'])))
    def fit(i):
        n = len(pts); sx = sum(p[0] for p in pts); sy = sum(p[i] for p in pts)
        sxx = sum(p[0] * p[0] for p in pts); sxy = sum(p[0] * p[i] for p in pts)
        b = (n * sxy - sx * sy) / max(1, n * sxx - sx * sx)
        return (sy - b * sx) / n, b
    (a1, b1), (a2, b2) = fit(1), fit(2)
    print('fit: one-pass %.0f + %.1f a row; two-phase %.0f + %.1f a row' % (a1, b1, a2, b2))


if __name__ == '__main__':
    main()
