#!/usr/bin/env python3
"""tpoly.py: the parasite's R_POLY (phase A, the one-pass generator and the
C_SPANS stream it sends), one parasite build against another, on py65
(65C02): the Master port's 6-harness/test_raster.py for the Tube's parasite.

    python3 tube/tools/tpoly.py REFDIR [CANDDIR] [--n 20000] [--seed 1]

REFDIR and CANDDIR (default tube/build) each hold a parasite build's
PCODE.bin, HOVS.bin and psyms.txt. Each build's resident image (PCODE from
CODE% to QSL), the quarter squares as p_boot makes them and overlay S's image
(HOVS, at OVL_START) are loaded into its own 64K, which then persists from
call to call as in the game (the operands the generator patches carry over).
Register 1's status always shows room, so every byte goes straight out
(never to the ring), and each byte written to its data register is kept.

Each call sets the same polygon on both, in the rasteriser's inputs (R_PN,
R_PXL/R_PXH, R_PYL/R_PYH, the four colours) and the clip window (mostly the
game's, 1-254 by 1-191; sometimes another), then enters R_POLY. The polygons
are random, 3 to 9 vertices, any order (convex or not, self-crossing,
degenerate: repeated vertices, flat edges, one row): 8-bit ones of every
size, from a few pixels to the whole window and beyond its edges, and 16-bit
ones (some coordinate outside 0..255, far out too). After every call these
must be equal: the bytes sent (the C_SPANS stream: the opcode, the colours,
the first row, each row's ends, the end mark), the buffer's dirty extents
(R_DIRTYL0, R_DIRTYR0, the rows r_dyt, r_dyb) and the C flag R_POLY
returns with (its only caller, T_POLY in p-io.asm, keeps A, X and Y round
it, and its PLA sets N and Z). Exit status 0 only if every call gives the
same results; prints the parasite cycles a call took on each build, by kind.
"""
import os, random, re, sys

from py65.devices.mpu65c02 import MPU

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RET = 0xFEF0                            # (the Tube's guard: never code)
PR1S, PR1D = 0xFEF8, 0xFEF9
ZP_CL, ZP_CR, ZP_CT, ZP_CB = 0x0A, 0x0B, 0x0C, 0x0D
R_COLE, R_COLO = 0x06, 0x07
PR_DL, PR_DR = 0xE4, 0xE6


class Mem(list):
    """64K with register 1: its status reads &40 (room), its data's writes kept"""
    def __init__(self):
        super().__init__([0] * 0x10000)
        self.out = []

    def __getitem__(self, a):
        if a == PR1S:
            return 0x40
        return list.__getitem__(self, a)

    def __setitem__(self, a, v):
        if a == PR1D:
            self.out.append(v)
        list.__setitem__(self, a, v)


class Build:
    def __init__(self, d):
        sy = {}
        for m in re.finditer(r"'([^']+)':(\d+)", open(os.path.join(d, 'psyms.txt')).read()):
            sy.setdefault(m.group(1), int(m.group(2)))
        self.sy = sy
        img = open(os.path.join(d, 'PCODE.bin'), 'rb').read()
        code, qsl = sy['PCODE_START'], sy['QSL']
        mem = Mem()
        for k, b in enumerate(img[:qsl - code]):
            list.__setitem__(mem, code + k, b)
        for n in range(512):                # (p_boot's quarter squares)
            q = n * n // 4
            list.__setitem__(mem, qsl + n, q & 255)
            list.__setitem__(mem, qsl + 512 + n, q >> 8)
        s = open(os.path.join(d, 'HOVS.bin'), 'rb').read()
        for k, b in enumerate(s):
            list.__setitem__(mem, sy['OVL_START'] + k, b)
        self.mem = mem
        self.mpu = MPU(memory=mem)
        self.cycles = {}
        # this buffer's dirty extents: buffer 0's arrays, empty
        for y in range(192):
            mem[sy['R_DIRTYL0'] + y] = 255
            mem[sy['R_DIRTYR0'] + y] = 0
        mem[PR_DL], mem[PR_DL + 1] = sy['R_DIRTYL0'] & 255, sy['R_DIRTYL0'] >> 8
        mem[PR_DR], mem[PR_DR + 1] = sy['R_DIRTYR0'] & 255, sy['R_DIRTYR0'] >> 8
        mem[sy['r_buf']] = 0
        mem[sy['KMODE']] = 0

    def poly(self, kind, pts, cols, clip):
        mpu, mem, sy = self.mpu, self.mem, self.sy
        mem[sy['R_PN']] = len(pts)
        for i, (x, y) in enumerate(pts):
            mem[sy['R_PXL'] + i], mem[sy['R_PXH'] + i] = x & 255, (x >> 8) & 255
            mem[sy['R_PYL'] + i], mem[sy['R_PYH'] + i] = y & 255, (y >> 8) & 255
        mem[R_COLE], mem[R_COLO], mem[sy['R_COL2']], mem[sy['R_COL3']] = cols
        mem[ZP_CL], mem[ZP_CR], mem[ZP_CT], mem[ZP_CB] = clip
        for k in (0, 1):
            mem[sy['r_dyt'] + k], mem[sy['r_dyb'] + k] = 255, 0
        for y in range(192):
            mem[sy['R_DIRTYL0'] + y] = 255
            mem[sy['R_DIRTYR0'] + y] = 0
        mem.out = []
        mpu.a, mpu.x, mpu.y, mpu.p = 0, 0, 0, 0x24
        mpu.sp = 0xFD
        mem[0x1FF], mem[0x1FE] = (RET - 1) >> 8, (RET - 1) & 255
        mpu.pc = sy['R_POLY']
        c0 = mpu.processorCycles
        n = 0
        while mpu.pc != RET:
            mpu.step()
            n += 1
            if n > 2000000:
                raise RuntimeError('runaway at &%04X' % mpu.pc)
        c = self.cycles.setdefault(kind, [0, 0])
        c[0] += mpu.processorCycles - c0
        c[1] += 1
        dl = [mem[sy['R_DIRTYL0'] + y] for y in range(192)]
        dr = [mem[sy['R_DIRTYR0'] + y] for y in range(192)]
        return (list(mem.out), dl, dr, mem[sy['r_dyt']], mem[sy['r_dyb']],
                mpu.p & 0x01)


def main():
    args = sys.argv[1:]
    opt = lambda n, d: (args[args.index(n) + 1] if n in args else d)
    pos = [a for k, a in enumerate(args) if not a.startswith('--') and (k == 0 or args[k - 1] not in ('--n', '--seed'))]
    ref = pos[0]
    cand = pos[1] if len(pos) > 1 else os.path.join(ROOT, 'tube', 'build')
    n, seed = int(opt('--n', 20000)), int(opt('--seed', 1))
    A, B = Build(ref), Build(cand)
    rnd = random.Random(seed)
    sent = 0
    for call in range(n):
        r = rnd.random()
        nv = rnd.choice((3, 3, 4, 4, 4, 5, 6, 7, 8, 9))
        if r < 0.75:                        # 8-bit: a box of some size
            kind = '8-bit'
            sz = rnd.choice((4, 8, 16, 32, 64, 128, 256))
            cx, cy = rnd.randrange(256), rnd.randrange(256)
            pts = [(min(255, max(0, cx + rnd.randrange(-sz, sz + 1))), min(255, max(0, cy + rnd.randrange(-sz, sz + 1)))) for _ in range(nv)]
        else:                               # 16-bit
            kind = '16-bit'
            sz = rnd.choice((64, 256, 1000, 30000))
            cx, cy = rnd.randrange(-300, 560), rnd.randrange(-300, 500)
            pts = [(max(-32768, min(32767, cx + rnd.randrange(-sz, sz + 1))), max(-32768, min(32767, cy + rnd.randrange(-sz, sz + 1)))) for _ in range(nv)]
        if rnd.random() < 0.1 and nv > 3:   # degenerate: a repeated vertex, a flat edge
            i = rnd.randrange(nv)
            pts[(i + 1) % nv] = pts[i] if rnd.random() < 0.5 else (pts[(i + 1) % nv][0], pts[i][1])
        if rnd.random() < 0.8:
            clip = (1, 254, 1, 191)
        else:
            cl, ct = rnd.randrange(1, 128), rnd.randrange(1, 96)
            clip = (cl, rnd.randrange(cl, 255), ct, rnd.randrange(ct, 192))
        if kind == '8-bit':                 # (whether the window clips its rows)
            ys = [y for x, y in pts]
            kind = '8-bit, rows clipped' if min(ys) < clip[2] or max(ys) - 1 > clip[3] else '8-bit, rows inside'
        cols = tuple(rnd.randrange(256) for _ in range(4))
        ra = A.poly(kind, pts, cols, clip)
        rb = B.poly(kind, pts, cols, clip)
        sent += len(ra[0])
        if ra != rb:
            what = []
            if ra[0] != rb[0]:
                what.append('stream: ref %s, build %s' % (ra[0][:40], rb[0][:40]))
            if ra[1:5] != rb[1:5]:
                what.append('dirty extents differ')
            if ra[5] != rb[5]:
                what.append('C: ref %s, build %s' % (ra[5], rb[5]))
            raise SystemExit('call %d (seed %d): %s %s clip %s:\n  %s' % (call, seed, kind, pts, clip, '\n  '.join(what)))
    print('R_POLY (parasite): %d calls, seed %d: equal (%d bytes sent)' % (n, seed, sent))
    for k in sorted(A.cycles):
        ca, cb = A.cycles[k], B.cycles[k]
        print('  %-20s %6d calls: cycles a call: reference %.1f, build %.1f (%+.2f%%)' % (
            k, ca[1], ca[0] / ca[1], cb[0] / cb[1], 100.0 * (cb[0] - ca[0]) / ca[0]))


if __name__ == '__main__':
    main()
