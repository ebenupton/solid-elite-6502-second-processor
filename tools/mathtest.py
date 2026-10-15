#!/usr/bin/env python3
"""
Equivalence tests for the BBC Master port's optimised maths routines.

Runs each routine in the ORIGINAL demo binary (ref/.../3-assembled-output/
ELTA..ELTG.bin, loaded at &0F40) and in the PORT (build/ELTMAIN.bin at &0F40 and
build/ELTBANK.bin at &8000) on py65's 65C02 core, with identical starting
memory, and compares the results:

  * registers A, X, Y and the N, Z and C flags (V is reported separately: no
    caller of these routines uses V, see the notes in the source)
  * the whole of zero page (&00-&FF, excluding the stack page) plus the
    workspace pages the routines may touch (&0300-&03FF, &0D40-&0F38)

Routines are looked up by name in both symbol tables (build/orig-symbols.txt
and build/symbols.txt), so the comparison is old-binary vs new-binary.

  python3 tools/mathtest.py [ROUTINE ...] [--quick]

Each routine is tested exhaustively over its 8-bit or 16-bit input space where
that is feasible, and with random inputs (and random background memory)
otherwise.
"""
import sys, re, random, time
from py65.devices.mpu65c02 import MPU

ROOT = '/Users/ebenupton/elite'
QUICK = '--quick' in sys.argv

def syms(path):
    d = {}
    for m in re.finditer(r"'([^']+)':(\d+)", open(path).read()):
        d[m.group(1)] = int(m.group(2))
    return d

OS = syms(ROOT + '/build/orig-symbols.txt')
PS = syms(ROOT + '/build/symbols.txt')

def load_orig():
    mem = bytearray(65536)
    a = 0x0F40
    for n in 'ABCDEFG':
        b = open(ROOT + '/ref/elite-demo-source-code-bbc-micro/3-assembled-output/ELT%s.bin' % n, 'rb').read()
        mem[a:a + len(b)] = b
        a += len(b)
    return mem

def load_port():
    mem = bytearray(65536)
    b = open(ROOT + '/build/ELTMAIN.bin', 'rb').read(); mem[0x0F40:0x0F40 + len(b)] = b
    b = open(ROOT + '/build/ELTBANK.bin', 'rb').read(); mem[0x8000:0x8000 + len(b)] = b
    return mem

SENT = 0xFFF0
CMP_RANGES = [(0x0000, 0x0100), (0x0300, 0x0400), (0x0D40, 0x0F39)]

class Runner:
    def __init__(self, image, symtab):
        self.base = image
        self.syms = symtab
        self.cpu = MPU()
        self.mem = self.cpu.memory
        self.mem[0:65536] = list(image)
        self.mem[SENT] = 0xEA

    def call(self, name, a, x, y, flags_c, membytes):
        cpu = self.cpu
        for addr, v in membytes.items():
            self.mem[addr] = v
        cpu.a, cpu.x, cpu.y = a, x, y
        cpu.p = 0x20 | 0x04 | (1 if flags_c else 0)        # I set, C as given
        cpu.sp = 0xFD
        self.mem[0x1FE] = (SENT - 1) & 255
        self.mem[0x1FF] = (SENT - 1) >> 8
        cpu.pc = self.syms[name]
        n = 0
        while cpu.pc != SENT:
            cpu.step()
            n += 1
            if n > 200000:
                raise RuntimeError('%s did not return' % name)
        out = {'A': cpu.a, 'X': cpu.x, 'Y': cpu.y,
               'N': (cpu.p >> 7) & 1, 'Z': (cpu.p >> 1) & 1, 'C': cpu.p & 1, 'V': (cpu.p >> 6) & 1,
               'cycles': cpu.processorCycles}
        return out

    def state(self):
        return [bytes(self.mem[a:b]) for a, b in CMP_RANGES]

ORIG = Runner(load_orig(), OS)
PORT = Runner(load_port(), PS)

def check(name, cases, pname=None):
    """cases: iterable of (A, X, Y, C, {addr: value}) tuples"""
    pname = pname or name
    rnd = random.Random(1)
    bad = 0; vdiff = 0; n = 0
    oc = pc = 0
    t0 = time.time()
    # identical random background in the compared areas
    bg = {}
    for a, b in CMP_RANGES:
        for i in range(a, b):
            if 0x100 <= i < 0x200: continue
            bg[i] = rnd.randrange(256)
    for r in (ORIG, PORT):
        for i, v in bg.items():
            r.mem[i] = v
    for (A, X, Y, C, mb) in cases:
        n += 1
        c0 = ORIG.cpu.processorCycles; o = ORIG.call(name, A, X, Y, C, mb); oc += ORIG.cpu.processorCycles - c0
        c0 = PORT.cpu.processorCycles; p = PORT.call(pname, A, X, Y, C, mb); pc += PORT.cpu.processorCycles - c0
        so, sp = ORIG.state(), PORT.state()
        diff = [k for k in ('A', 'X', 'Y', 'N', 'Z', 'C') if o[k] != p[k]]
        if o['V'] != p['V']: vdiff += 1
        mdiff = []
        for (a, b), x, yy in zip(CMP_RANGES, so, sp):
            if x != yy:
                for i in range(b - a):
                    if x[i] != yy[i] and not (0x100 <= a + i < 0x200):
                        mdiff.append('&%02X: %02X/%02X' % (a + i, x[i], yy[i]))
        if diff or mdiff:
            bad += 1
            if bad <= 8:
                print('  MISMATCH %s A=%02X X=%02X Y=%02X C=%d mem=%s: regs %s %s mem %s' % (
                    name, A, X, Y, C, {'&%02X' % k: '%02X' % v for k, v in mb.items()},
                    diff, {k: (o[k], p[k]) for k in diff}, mdiff[:8]))
            # resynchronise memory so later cases start identical
            for (a, b), x in zip(CMP_RANGES, so):
                PORT.mem[a:b] = list(x)
    print('%-10s %8d cases, %s, V differs in %d, avg cycles orig %.1f port %.1f (%.1fs)' % (
        name, n, 'OK' if not bad else '%d MISMATCHES' % bad, vdiff, oc / max(n, 1), pc / max(n, 1), time.time() - t0))
    return bad == 0

Z = lambda n: OS[n]   # zero page addresses (same in both builds)

def rnd_cases(gen, count, seed=2):
    r = random.Random(seed)
    for _ in range(count):
        yield gen(r)

def all8x8(fa, fb, extra=lambda r: {}, step=1):
    """All (a, b) pairs with fa(a,b) giving the case tuple"""
    r = random.Random(3)
    for a in range(0, 256, step):
        for b in range(0, 256, step):
            yield fa(a, b, r)

TESTS = {}
def test(f):
    TESTS[f.__name__] = f
    return f

STEP = 3 if QUICK else 1

@test
def FMLTU():
    P, Q = Z('P'), Z('Q')
    return check('FMLTU', all8x8(lambda a, b, r: (a, r.randrange(256), r.randrange(256), r.randrange(2), {Q: b, P: r.randrange(256)}), None, step=STEP))

@test
def FMLTU2():
    K, P = Z('K'), Z('P')
    return check('FMLTU2', all8x8(lambda a, b, r: (a, r.randrange(256), r.randrange(256), r.randrange(2), {K: b, P: r.randrange(256)}), None, step=STEP))

@test
def MULTU():
    P, Q = Z('P'), Z('Q')
    return check('MULTU', all8x8(lambda a, b, r: (r.randrange(256), r.randrange(256), r.randrange(256), r.randrange(2), {P: a, Q: b}), None, step=STEP))

@test
def MU11():
    P = Z('P')
    return check('MU11', all8x8(lambda a, b, r: (r.randrange(256), b, r.randrange(256), r.randrange(2), {P: a}), None, step=STEP))

@test
def SQUA2():
    return check('SQUA2', ((a, 0, 0, c, {}) for a in range(256) for c in range(2)))

@test
def SQUA():
    return check('SQUA', ((a, 0, 0, c, {}) for a in range(256) for c in range(2)))

@test
def MLU2():
    Q = Z('Q')
    return check('MLU2', all8x8(lambda a, b, r: (a, r.randrange(256), r.randrange(256), r.randrange(2), {Q: b}), None, step=STEP))

@test
def MULTS():
    P = Z('P')
    return check('MULTS', all8x8(lambda a, b, r: (a, r.randrange(256), r.randrange(256), r.randrange(2), {P: b}), None, step=STEP))

@test
def MLS1():
    A1 = OS['ALP1']
    return check('MLS1', all8x8(lambda a, b, r: (a, r.randrange(256), r.randrange(256), r.randrange(2), {A1: b}), None, step=STEP))

@test
def MULT1():
    Q = Z('Q')
    return check('MULT1', all8x8(lambda a, b, r: (a, r.randrange(256), r.randrange(256), r.randrange(2), {Q: b}), None, step=STEP))

@test
def MULT3():
    P, Q = Z('P'), Z('Q')
    return check('MULT3', rnd_cases(lambda r: (r.randrange(256), r.randrange(256), r.randrange(256), r.randrange(2),
                                                {P: r.randrange(256), P + 1: r.randrange(256), Q: r.randrange(256)}), 20000 if QUICK else 200000))

@test
def MLTU2():
    P, Q = Z('P'), Z('Q')
    return check('MLTU2', rnd_cases(lambda r: (r.randrange(256), r.randrange(256), r.randrange(256), r.randrange(2),
                                                {P: r.randrange(256), P + 1: r.randrange(256), Q: r.randrange(256)}), 20000 if QUICK else 200000))

@test
def ADD():
    P, R, S = Z('P'), Z('R'), Z('S')
    return check('ADD', rnd_cases(lambda r: (r.randrange(256), r.randrange(256), r.randrange(256), r.randrange(2),
                                              {P: r.randrange(256), R: r.randrange(256), S: r.randrange(256)}), 20000 if QUICK else 300000))

@test
def MAD():
    P, Q, R, S = Z('P'), Z('Q'), Z('R'), Z('S')
    return check('MAD', rnd_cases(lambda r: (r.randrange(256), r.randrange(256), r.randrange(256), r.randrange(2),
                                              {Q: r.randrange(256), R: r.randrange(256), S: r.randrange(256)}), 20000 if QUICK else 300000))

@test
def DVID4():
    Q = Z('Q')
    return check('DVID4', all8x8(lambda a, b, r: (a, r.randrange(256), r.randrange(256), r.randrange(2), {Q: b}), None, step=STEP))

@test
def LL28():
    Q = Z('Q')
    return check('LL28', all8x8(lambda a, b, r: (a, r.randrange(256), r.randrange(256), r.randrange(2), {Q: b}), None, step=STEP))

@test
def TIS2():
    Q = Z('Q')
    return check('TIS2', all8x8(lambda a, b, r: (a, r.randrange(256), r.randrange(256), r.randrange(2), {Q: b}), None, step=STEP))

@test
def LL5():
    Q, R = Z('Q'), Z('R')
    return check('LL5', all8x8(lambda a, b, r: (r.randrange(256), r.randrange(256), r.randrange(256), r.randrange(2), {Q: a, R: b}), None, step=STEP))

if __name__ == '__main__':
    names = [a for a in sys.argv[1:] if not a.startswith('--')] or list(TESTS)
    ok = True
    for n in names:
        ok &= TESTS[n]()
    sys.exit(0 if ok else 1)
