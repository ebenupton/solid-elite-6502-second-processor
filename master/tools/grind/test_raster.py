#!/usr/bin/env python3
"""Soak test for the full Master port's rasteriser (master/src/gfx-raster*.asm).

A thin adapter over the demo port's tools/test_raster.py (its pixel-exact Python
reference, py65 65C02, the write guard and every test), pointed at the Master files:

  * the wrapper assembles the renderer's shared workspace as elite-gfx.asm lays it
    out in main RAM (from its `ORG &1300` to WS_END: gfx-raster_scr.asm, the per-call
    scratch, with R_NDISCL page aligned; gfx-raster_vars.asm at its fixed base, as the
    laser-sight rows must not cross a page; R_WL, R_WR, R_NDN, the stars), the
    cross-bank stubs gfx-raster_hz.asm at &DF00, gfx-raster.asm at --org (bank 5) and
    gfx-raster7.asm at &8000 (bank 7);
  * the write guard allows exactly those areas (plus the renderer's zero page, the
    stack and the screen, as before);
  * R_POLY's 4-row colour: every polygon is drawn with R_COL2 = R_COLE and
    R_COL3 = R_COLO, the 2-row colour pair the reference models (gfx-raster.asm's
    header: "set R_COL2 = R_COLE and R_COL3 = R_COLO for a 2-row colour pair").  The
    4-row dither itself is not checked here.

    python3 master/tools/grind/test_raster.py [--seed N] [--quick] [--org HEX] [--only x,y]

Run from anywhere; needs py65 and <repo>/tools/beebasm.  Exit status 0 only if every
test passes.
"""
import os, re, subprocess, sys, tempfile, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(REPO, 'tools'))
sys.dont_write_bytecode = True
import test_raster as tr                         # noqa: E402  (the demo's test)

TREE = os.path.abspath(os.environ.get('GRIND_TREE', REPO))     # the tree whose rasteriser is tested
MS = os.path.join(TREE, 'master', 'src')
tr.SRC = os.path.join(MS, 'gfx-raster.asm')
tr.SRCV = os.path.join(MS, 'gfx-raster_vars.asm')
tr.SRCH = os.path.join(MS, 'gfx-raster_hz.asm')
tr.SRC7 = os.path.join(MS, 'gfx-raster7.asm')
GFX = os.path.join(MS, 'elite-gfx.asm')
tr.HZ = 0xDF00


def gfx_constants():
    """elite-gfx.asm's constants (MCB, banks, sizes), defined before its first CLEAR"""
    out = ['HOMEBANK = 4']
    for l in open(GFX).read().split('\n'):
        if re.match(r'\s*CLEAR\b', l):
            break
        if re.match(r'^[A-Z_][A-Z0-9_]*\s*=', l):
            out.append(l)
    # the shared workspace's F_DSS is NDSTAR (elite-gfx.asm, after its first CLEAR) long,
    # from Elite's NOST (elite-source.asm)
    src = open(os.path.join(MS, 'elite-source.asm')).read()
    out.append('NOST = %s' % re.search(r'^\s*NOST\s*=\s*(\d+)', src, re.M).group(1))
    out += [l for l in open(GFX).read().split('\n') if re.match(r'^NDSTAR\s*=', l)]
    return '\n'.join(out)


def ws_block():
    """elite-gfx.asm's shared workspace (after `NDSTAR =`, from its first ORG to
    .WS_END: two parts, WS_START..WS_HI_END and WS_LO..WS_END), as text, with its
    INCLUDEs made absolute"""
    t = open(GFX).read().split('\n')
    i = next(n for n, l in enumerate(t) if re.match(r'^NDSTAR\s*=', l)) + 1
    out = []
    for l in t[i:]:
        out.append(l.replace('"src/', '"%s/' % MS))
        if l.startswith('.WS_END'):
            break
    return '\n'.join(out)


def assemble(org):
    base = os.path.join(REPO, 'scratch', 'raster')
    os.makedirs(base, exist_ok=True)
    d = tempfile.mkdtemp(prefix='mraster_', dir=base)
    w = os.path.join(d, 'w.asm')
    with open(w, 'w') as f:
        f.write(gfx_constants() + '\n')
        f.write(ws_block() + '\n')
        f.write('ORG &%X\nINCLUDE "%s"\n.r_hz_end\n' % (tr.HZ, tr.SRCH))
        f.write('ORG &%X\nINCLUDE "%s"\n' % (org, tr.SRC))
        f.write('SAVE "r.bin", &%X, P%%\n' % org)
        f.write('CLEAR &8000, &C000\nORG &8000\nINCLUDE "%s"\nSAVE "r7.bin", &8000, P%%\n' % tr.SRC7)
        f.write('SAVE "h.bin", &%X, r_hz_end\n' % tr.HZ)
    r = subprocess.run([tr.BEEBASM, '-i', w, '-d', '-labels', os.path.join(d, 'w.lab')],
                       cwd=d, capture_output=True, text=True)
    if r.returncode != 0 or 'error' in r.stdout.lower():
        print(r.stdout, r.stderr)
        raise SystemExit('assembly failed')
    txt = open(os.path.join(d, 'w.lab')).read()
    syms = {k: int(v) for k, v in re.findall(r"'([^']+)':(-?\d+)L?", txt)}
    data = open(os.path.join(d, 'r.bin'), 'rb').read()
    data7 = open(os.path.join(d, 'r7.bin'), 'rb').read()
    datah = open(os.path.join(d, 'h.bin'), 'rb').read()
    msg = [l for l in r.stdout.splitlines() if l.startswith('raster')]
    shutil.rmtree(d, ignore_errors=True)
    return syms, (data, data7, datah), ('; '.join(msg))


class Machine(tr.Machine):
    def check_writes(self, snap, name):
        mem, s = self.mem, self.syms
        allowed = sorted([(0x06, 0x28), (tr.ROMSELCOPY, tr.ROMSELCOPY + 1), (0x100, 0x200),
                          (tr.SCR0, tr.SCR1), (self.lo, self.hi),
                          (s['WS_START'], s['WS_HI_END']), (s['WS_LO'], s['WS_END']), (tr.HZ, s['r_hz_end']),
                          (tr.ROMSEL, tr.ROMSEL + 1)])
        a0 = 0
        for lo, hi in allowed + [(0x10000, 0x10000)]:
            if a0 < lo and mem[a0:lo] != snap[a0:lo]:
                for a in range(a0, lo):
                    if mem[a] != snap[a]:
                        raise AssertionError('%s wrote &%04X' % (name, a))
            a0 = max(a0, hi)
        r0 = s['r_run0']
        for r in range(24):
            b = r0 + 256 * r
            if mem[b:b + 190] != snap[b:b + 190]:
                raise AssertionError('%s left run %d modified' % (name, r))


    def page(self, nb):
        """page sideways bank nb in (as a write to ROMSEL would)"""
        if nb != self.bank:
            self.banks[self.bank] = self.mem[0x8000:0xC000]
            self.mem[0x8000:0xC000] = self.banks[nb]
            self.bank = nb
        self.mem[tr.ROMSEL] = self.mem[tr.ROMSELCOPY] = nb

    def call(self, name, a=0, x=0, y=0, maxcyc=20_000_000, bank=5):
        """as the demo's, but entered (and returning) with bank `bank` paged: R_LINE is
        in bank 7, which the frame layer's T_LINE pages in itself"""
        self.page(bank)
        mpu, mem = self.mpu, self.mem
        if self.guard:
            snap = mem[:]
        mpu.a, mpu.x, mpu.y = a, x, y
        mpu.p = 0x24
        ret = tr.RET - 1
        mem[0x1FF] = ret >> 8
        mem[0x1FE] = ret & 0xFF
        mpu.sp = 0xFD
        mpu.pc = self.syms[name] if isinstance(name, str) else name
        c0 = mpu.processorCycles
        step = mpu.step
        while mpu.pc != tr.RET:
            step()
            nb = mem[tr.ROMSEL]
            if nb != self.bank:
                self.banks[self.bank] = mem[0x8000:0xC000]
                mem[0x8000:0xC000] = self.banks[nb]
                self.bank = nb
            if mpu.processorCycles - c0 > maxcyc:
                raise RuntimeError('runaway in %s' % name)
        if self.bank != bank:
            raise AssertionError('%s returned with bank %d paged' % (name, self.bank))
        self.cycles = mpu.processorCycles - c0
        if self.guard:
            self.check_writes(snap, name)
        self.page(5)
        return self.cycles


def set_col(self, ce, co):
    self.m.wzp('R_COLE', ce)
    self.m.wzp('R_COLO', co)
    self.m.wr('R_COL2', ce)          # a 2-row colour pair in R_POLY's 4-row colour
    self.m.wr('R_COL3', co)


def draw_line(self, x0, y0, x1, y1, ce, co, entry='R_LINE'):
    m = self.m
    for nm, v in (('R_X0', x0), ('R_Y0', y0), ('R_X1', x1), ('R_Y1', y1)):
        m.wr(nm, v & 0xFF)
        m.wr(nm, (v >> 8) & 0xFF, 1)
    self.set_col(ce, co)
    return m.call(entry, bank=7)          # (T_LINE: bank 7)


tr.assemble = assemble
tr.Machine = Machine
tr.Tester.set_col = set_col
tr.Tester.draw_line = draw_line

if __name__ == '__main__':
    tr.main()
