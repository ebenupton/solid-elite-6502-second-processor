#!/usr/bin/env python3
"""tstars.py: the parasite's front-view stardust (STARS with VIEW = 0), one
parasite build against another, on py65 (65C02): the Master port's
6-harness/test_stars.py for the Tube's parasite.

    python3 tube/tools/tstars.py REFDIR [CANDDIR] [--n 5000] [--seed 1]
                                 [--strict] [--cruise] [--d255]

REFDIR and CANDDIR (default tube/build) each hold a parasite build's
PCODE.bin and psyms.txt. Each build's resident image (PCODE from CODE% to
QSL: the code, the data and the log tables) is loaded into its own 64K, with
the quarter squares QSL and QSH as p_boot makes them; that memory then
persists from call to call as in the game (so the operands STARS1 patches,
and anything it keeps between calls, such as STL1's divide cache, carry
over).

Each call enters STARS (from a JMP in the main loop, so with a return address
on the stack) in record mode (QQ11 = 0, GFORCE = 0), the front view
(VIEW = 0), with the same random A, X, Y and flags on both (D clear). Between
calls the speed DELTA (0..40, DELT4 = 64 * DELTA) and the roll and pitch
change as the main loop's key handling derives them from JSTX and JSTY
(ALP1, ALP2, ALP2+1, ALPHA, BET1, BET2, BET2+1, BETA), sometimes every call
and sometimes not for many calls, with zero roll or pitch and the changes to
and from them. The particles start as nWq makes them (NOSTM = NOST, or 3 as
in witchspace), and RAND is sometimes moved on between calls.

After every call these must be equal: zero page except the temporaries P,
P+1, Q, R, S, T, T1, XX(1 0), YY(1 0) and widget, the particles SX, SY, SZ,
SXL, SYL, SZL, the renderer's records R_SX, R_SY, R_SS, and the A, X, Y and
flags (N, V, Z, C) that STARS returns with. The temporaries are set to
different random values on the two builds before each call, so a read of one
before STARS writes it shows up. With --strict the temporaries start equal
and are compared as well (but for widget, on a build with STL1's divide
cache, whose hits do not write it). With --cruise the speed changes only
between runs of calls (1 to 200 long). With --d255 the speed is sometimes
255, whose tag DELTA + 1 would be 0, an empty entry's (STARS1 then patches
STL1's tag test to always miss). Exit status 0 only if every call gives
the same results; prints the cycles a call took on each build (parasite
cycles), how often the rare paths ran on the reference, and on a build with
STL1's divide cache (stlx) its lookups, hits and misses.
"""
import os, random, re, sys

from py65.devices.mpu65c02 import MPU

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
NOST = 20
RET = 0xFEF0                            # (the Tube's guard: never code)
TEMPS = ('P', 'P+1', 'Q', 'R', 'S', 'T', 'T1', 'XX', 'XX+1', 'YY', 'YY+1', 'widget')
RARE = ('KILL1', 'stl_dvs', 'mlqr', 'mlar', 'mlbr', 'MU8', 'mlsk', 'mlbk')
CACHE = ('STL1', 'stlx', 'stl_dvs')


def addr(sy, n):
    if n.endswith('+1'):
        return sy[n[:-2]] + 1
    return sy[n]


class Build:
    def __init__(self, d):
        sy = {}
        for m in re.finditer(r"'([^']+)':(\d+)", open(os.path.join(d, 'psyms.txt')).read()):
            sy.setdefault(m.group(1), int(m.group(2)))
        self.sy = sy
        img = open(os.path.join(d, 'PCODE.bin'), 'rb').read()
        code, qsl = sy['PCODE_START'], sy['QSL']
        mem = [0] * 0x10000
        mem[code:qsl] = list(img[:qsl - code])
        for n in range(512):                # (p_boot's quarter squares)
            q = n * n // 4
            mem[qsl + n] = q & 255
            mem[qsl + 512 + n] = q >> 8
        self.mem = mem
        self.mpu = MPU()
        self.mpu.memory = mem
        self.cycles = 0
        self.calls = 0
        self.watch = {}

    def stars(self, regs):
        mpu, mem = self.mpu, self.mem
        mpu.a, mpu.x, mpu.y, mpu.p = regs
        mpu.sp = 0xFD
        mem[0x1FF], mem[0x1FE] = (RET - 1) >> 8, (RET - 1) & 255
        mpu.pc = self.sy['STARS']
        c0 = mpu.processorCycles
        watch = self.watch
        n = 0
        while mpu.pc != RET:
            if mpu.pc in watch:
                w = watch[mpu.pc]
                w[1] += 1
                if len(w) > 2 and mpu.a:     # (at stlx: the entry held another speed's R)
                    w[2] += 1
            mpu.step()
            n += 1
            if n > 200000:
                raise RuntimeError('runaway at &%04X' % mpu.pc)
        self.cycles += mpu.processorCycles - c0
        self.calls += 1
        return mpu.a, mpu.x, mpu.y, mpu.p & 0xC3, mpu.sp


def roll(jstx):
    a = jstx ^ 0x80
    alp2 = a & 0x80
    m = (256 - a) & 255 if a & 0x80 else a
    m >>= 2
    if m < 8:
        m >>= 1
    return alp2, alp2 ^ 0x80, m, m | alp2


def pitch(jsty, c):
    a = jsty ^ 0x80
    bet21 = a & 0x80
    bet2 = bet21 ^ 0x80
    if a & 0x80:
        a ^= 0xFF
    m = (a + 4 + c) >> 4
    if m < 3:
        m >>= 1
    return bet2, bet21, m, m | bet2


def main():
    args = sys.argv[1:]
    opt = lambda n, d: (args[args.index(n) + 1] if n in args else d)
    pos = [a for k, a in enumerate(args) if not a.startswith('--') and (k == 0 or args[k - 1] not in ('--n', '--seed'))]
    ref = pos[0]
    cand = pos[1] if len(pos) > 1 else os.path.join(ROOT, 'tube', 'build')
    n, seed = int(opt('--n', 5000)), int(opt('--seed', 1))
    strict = '--strict' in args
    cruise = '--cruise' in args
    d255 = '--d255' in args
    A, B = Build(ref), Build(cand)
    sa, sb = A.sy, B.sy
    names = ('SX', 'SY', 'SZ', 'SXL', 'SYL', 'SZL', 'R_SX', 'R_SY', 'R_SS', 'RAND', 'VIEW', 'GFORCE')
    for nm in names + ('QQ11', 'NOSTM', 'DELTA', 'DELT4', 'ALPHA', 'ALP1', 'ALP2', 'BETA', 'BET1', 'BET2') + TEMPS[::2]:
        k = nm[:-2] if nm.endswith('+1') else nm
        if sa[k] != sb[k]:
            raise SystemExit('%s is at &%04X in the reference, &%04X in the build' % (k, sa[k], sb[k]))
    for nm in RARE:
        if nm in sa:
            A.watch[sa[nm]] = [nm, 0]
    cache = 'stlx' in sb
    if cache:
        for nm in CACHE:
            B.watch[sb[nm]] = [nm, 0] + ([0] if nm == 'stlx' else [])
        for X in (A, B):                    # (BEGIN empties the cache: the
            if 'STLZT' in X.sy:             # memory starts zeroed anyway)
                X.mem[X.sy['STLZT']:X.sy['STLZT'] + 256] = [0] * 256
    recent = [3]
    temps = {addr(sa, t) for t in TEMPS}
    loose = {sa['widget']} if cache else set()
    zp = [k for k in range(256) if (k not in temps if not strict else k not in loose) and k not in (0, 1)]
    arrays = [(nm, sa[nm], 4 if nm == 'RAND' else (1 if nm in ('VIEW', 'GFORCE') else NOST + 1)) for nm in names]
    rnd = random.Random(seed)

    def put(nm, v):
        for X in (A, B):
            X.mem[addr(sa, nm)] = v

    def dornd_seed():
        v = [rnd.randrange(256) for _ in range(4)]
        for X in (A, B):
            X.mem[sa['RAND']:sa['RAND'] + 4] = v

    def nwq(nost):
        for i in range(1, nost + 1):
            vals = [rnd.randrange(256) | 8, rnd.randrange(256), rnd.randrange(256)] + [rnd.randrange(256) for _ in range(3)]
            for X in (A, B):
                for nm, v in zip(('SZ', 'SX', 'SY', 'SZL', 'SXL', 'SYL'), vals):
                    X.mem[sa[nm] + i] = v

    for k in range(2, 256):
        v = rnd.randrange(256)
        A.mem[k] = B.mem[k] = v
    for nm in ('R_SX', 'R_SY', 'R_SS'):
        v = [rnd.randrange(256) for _ in range(NOST + 1)]
        for X in (A, B):
            X.mem[sa[nm]:sa[nm] + NOST + 1] = v
    put('VIEW', 0)
    put('QQ11', 0)
    put('GFORCE', 0)
    dornd_seed()
    nost = NOST
    put('NOSTM', nost)
    nwq(nost)

    jstx, jsty, c, delta = 128, 128, 0, 3
    hold = 0
    mode = 'steady'
    for call in range(n):
        if hold <= 0:
            mode = rnd.choice(('steady', 'steady', 'every', 'zero', 'toggle'))
            hold = rnd.choice((1, 5, 20, 60, 200))
            if rnd.random() < 0.03:
                nost = 3 if rnd.random() < 0.2 else NOST
                put('NOSTM', nost)
                nwq(nost)
        hold -= 1
        change = (mode == 'every') or (mode in ('zero', 'toggle') and rnd.random() < 0.3) or hold == 0
        if change or call == 0:
            if mode == 'zero':
                jstx = rnd.choice((128 + rnd.randrange(-7, 8), rnd.randrange(1, 256)))
                jsty = rnd.choice((128 + rnd.randrange(-20, 21), rnd.randrange(1, 256)))
            elif mode == 'toggle':
                jstx = 128 if rnd.random() < 0.5 else rnd.randrange(1, 256)
                jsty = 128 if rnd.random() < 0.5 else rnd.randrange(1, 256)
            else:
                jstx = rnd.randrange(1, 256)
                jsty = rnd.randrange(1, 256)
            c = rnd.randrange(2)
            if rnd.random() < 0.7 and not (cruise and hold > 0):
                delta = rnd.choice((rnd.randrange(0, 41), 40, 0, 1, rnd.randrange(30, 41), rnd.choice(recent)))
                if d255 and rnd.random() < 0.1:
                    delta = 255
                recent = (recent + [delta])[-4:]
        alp2, alp21, alp1, alpha = roll(jstx)
        bet2, bet21, bet1, beta = pitch(jsty, c)
        put('ALP2', alp2)
        put('ALP2+1', alp21)
        put('ALP1', alp1)
        put('ALPHA', alpha)
        put('BET2', bet2)
        put('BET2+1', bet21)
        put('BET1', bet1)
        put('BETA', beta)
        put('DELTA', delta)
        put('DELT4', (delta & 3) << 6)
        put('DELT4+1', delta >> 2)
        if rnd.random() < 0.5:
            dornd_seed()
        for t in temps:
            A.mem[t] = rnd.randrange(256)
            B.mem[t] = A.mem[t] if strict else rnd.randrange(256)
        regs = (rnd.randrange(256), rnd.randrange(256), rnd.randrange(256), (rnd.randrange(256) & 0xC3) | 0x20)
        ra = A.stars(regs)
        rb = B.stars(regs)
        bad = []
        if ra != rb:
            bad.append('registers (A, X, Y, P & NVZC, SP): ref %s, build %s' % (
                tuple('%02X' % v for v in ra), tuple('%02X' % v for v in rb)))
        for nm, a0, ln in arrays:
            va, vb = A.mem[a0:a0 + ln], B.mem[a0:a0 + ln]
            if va != vb:
                d = [k for k in range(ln) if va[k] != vb[k]]
                bad.append('%s differs at %s: ref %s, build %s' % (nm, d[:8], [va[k] for k in d[:8]], [vb[k] for k in d[:8]]))
        dz = [k for k in zp if A.mem[k] != B.mem[k]]
        if dz:
            bad.append('zero page differs at %s: ref %s, build %s' % (
                ['&%02X' % k for k in dz[:8]], [A.mem[k] for k in dz[:8]], [B.mem[k] for k in dz[:8]]))
        if bad:
            raise SystemExit('call %d (seed %d; DELTA %d, ALP1 %d, BET1 %d, NOSTM %d):\n  %s' % (
                call, seed, delta, alp1, bet1, nost, '\n  '.join(bad)))
    cov = ', '.join('%s %d' % (w[0], w[1]) for w in sorted(A.watch.values()))
    print('STARS (front view, parasite): %d calls, seed %d: equal%s' % (n, seed, ' (strict: temporaries too)' if strict else ''))
    print('  cycles a call: reference %.1f, build %.1f' % (A.cycles / n, B.cycles / n))
    print('  rare paths on the reference: %s' % cov)
    if B.watch:
        w = {v[0]: v for v in B.watch.values()}
        looks = w['STL1'][1]
        misses = w['stlx'][1]
        print('  divide cache on the build: %d lookups, %d hits (%.1f%%), %d misses (%d of them replacing another'
              ' speed\'s entry), %d of the misses DELTA >= z_hi (stl_dvs, not cached)' % (
                  looks, looks - misses, 100.0 * (looks - misses) / max(looks, 1), misses, w['stlx'][2], w['stl_dvs'][1]))
    miss = [w[0] for w in A.watch.values() if w[1] == 0]
    if miss:
        print('  (not reached: %s)' % ', '.join(miss))


if __name__ == '__main__':
    main()
