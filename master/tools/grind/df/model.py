"""model -- the assembled full Master Elite program (master/), from a BeebAsm build with a
grindmap.  (master/tools/grind copy of tools/grind/df/model.py, which replaced beebgame's
ld65-debug-file model; changed for the Master build's memory map.)

Built from what master/tools/grind/mkbuild.sh leaves in a build directory:

  gmap.tsv      the patched BeebAsm's provenance records (tools/grind/beebasm): for
                every emitted byte run, I (instruction) / D (data: EQUB, EQUW, EQUS,
                INCBIN...) / S (SKIP), its address, length, the source file:line of
                the statement (inside a macro: the macro body's line) and the outermost
                non-macro line (the "site"); label definitions; CLEAR / ORG / SAVE /
                COPYBLOCK events
  tree/master/src     the sources exactly as assembled
  tree/master/build   the SAVEd images (BCODE, HICODE, BANK4, COLD7, HAZEL,
                      BANK5, RASTA, BANK6)
  symbols.txt   beebasm -d (global symbols: labels and equates)

Segments (a record's segment is its CLEAR epoch plus the SAVE whose range covers it):

  main  main RAM: BCODE &1F00-&3FFF, HICODE &7200-&7FFF (QSL/QSH, renderer stubs and
        hooks, the lighting's game half, the far7 stubs)
  B4    BANK4.bin, sideways RAM bank 4 (Elite's home bank: the main code's
        continuation, then elite-bank4.asm's code)
  C7    COLD7.bin, bank 7 from &8000: the cold area (QQ18 and the extended
        tokens, the cold code, the far4 stubs; ROMSEL 7)
  B5    BANK5.bin (the rasteriser's shared region and disc window; ROMSEL 5)
  RA    RASTA.bin, ANDY (the rasteriser's polygon window: R_POLY, R_LINE; ROMSEL &85)
  B6    BANK6.bin (frame layer, faces, lighting)
  HZ    HAZEL &C000-&DFFF (HAZEL.bin: the game data, and the glue at &C300)
  SH    shadow RAM data (once TOKENS.bin, the extended tokens at &3100; now none: the
        tokens are in bank 7, in COLD7.bin, read by the cold code directly)
  RAM   workspace with no image (zero page, K%, WP ...)

Only bytes inside a SAVEd image are loaded (`loaded`): anything else in a segment's
extent (the renderer's shared workspace, WP, the screen) is unknown at
start-up, never a link-time constant.

An instruction starts exactly where an I record starts (macros and FOR loops expanded by
the assembler); every other byte is data.  No disassembly guesses.

Which bank a reference to &8000-&BFFF reaches (bank_at): the segment of the label the
operand names in the source, when it names one (JSR F_FRAME in a G_ stub reaches bank 6);
else what the referencing segment sees paged: main and B4 code bank 4; the cold code
(C7: ROMSEL 7) bank 7; B5 bank 5; RA ANDY over bank 5; B6 itself;
HAZEL code any bank (unknown).
"""
import os, re, collections, bisect

# ---------------------------------------------------------------- opcode table
# NMOS official + the 65C02's (the Master's 65SC12: no BBR/BBS/RMB/SMB).  modes:
# imp acc imm zp zpx zpy inx iny zpi((zp)) abs abx aby ind iax(jmp (a,x)) rel
_NMOS = """
00 BRK imp|01 ORA inx|05 ORA zp|06 ASL zp|08 PHP imp|09 ORA imm|0A ASL acc|0D ORA abs|0E ASL abs
10 BPL rel|11 ORA iny|15 ORA zpx|16 ASL zpx|18 CLC imp|19 ORA aby|1D ORA abx|1E ASL abx
20 JSR abs|21 AND inx|24 BIT zp|25 AND zp|26 ROL zp|28 PLP imp|29 AND imm|2A ROL acc|2C BIT abs
2D AND abs|2E ROL abs|30 BMI rel|31 AND iny|35 AND zpx|36 ROL zpx|38 SEC imp|39 AND aby|3D AND abx
3E ROL abx|40 RTI imp|41 EOR inx|45 EOR zp|46 LSR zp|48 PHA imp|49 EOR imm|4A LSR acc|4C JMP abs
4D EOR abs|4E LSR abs|50 BVC rel|51 EOR iny|55 EOR zpx|56 LSR zpx|58 CLI imp|59 EOR aby|5D EOR abx
5E LSR abx|60 RTS imp|61 ADC inx|65 ADC zp|66 ROR zp|68 PLA imp|69 ADC imm|6A ROR acc|6C JMP ind
6D ADC abs|6E ROR abs|70 BVS rel|71 ADC iny|75 ADC zpx|76 ROR zpx|78 SEI imp|79 ADC aby|7D ADC abx
7E ROR abx|81 STA inx|84 STY zp|85 STA zp|86 STX zp|88 DEY imp|8A TXA imp|8C STY abs|8D STA abs
8E STX abs|90 BCC rel|91 STA iny|94 STY zpx|95 STA zpx|96 STX zpy|98 TYA imp|99 STA aby|9A TXS imp
9D STA abx|A0 LDY imm|A1 LDA inx|A2 LDX imm|A4 LDY zp|A5 LDA zp|A6 LDX zp|A8 TAY imp|A9 LDA imm
AA TAX imp|AC LDY abs|AD LDA abs|AE LDX abs|B0 BCS rel|B1 LDA iny|B4 LDY zpx|B5 LDA zpx|B6 LDX zpy
B8 CLV imp|B9 LDA aby|BA TSX imp|BC LDY abx|BD LDA abx|BE LDX aby|C0 CPY imm|C1 CMP inx|C4 CPY zp
C5 CMP zp|C6 DEC zp|C8 INY imp|C9 CMP imm|CA DEX imp|CC CPY abs|CD CMP abs|CE DEC abs|D0 BNE rel
D1 CMP iny|D5 CMP zpx|D6 DEC zpx|D8 CLD imp|D9 CMP aby|DD CMP abx|DE DEC abx|E0 CPX imm|E1 SBC inx
E4 CPX zp|E5 SBC zp|E6 INC zp|E8 INX imp|E9 SBC imm|EA NOP imp|EC CPX abs|ED SBC abs|EE INC abs
F0 BEQ rel|F1 SBC iny|F5 SBC zpx|F6 INC zpx|F8 SED imp|F9 SBC aby|FD SBC abx|FE INC abx
"""
_CMOS = """
04 TSB zp|0C TSB abs|12 ORA zpi|14 TRB zp|1A INC acc|1C TRB abs|32 AND zpi|34 BIT zpx|3A DEC acc
3C BIT abx|52 EOR zpi|5A PHY imp|64 STZ zp|72 ADC zpi|74 STZ zpx|7A PLY imp|7C JMP iax|80 BRA rel
89 BIT imm|92 STA zpi|9C STZ abs|9E STZ abx|B2 LDA zpi|D2 CMP zpi|DA PHX imp|F2 SBC zpi|FA PLX imp
"""
LEN = {'imp': 1, 'acc': 1, 'imm': 2, 'zp': 2, 'zpx': 2, 'zpy': 2, 'inx': 2, 'iny': 2,
       'zpi': 2, 'rel': 2, 'abs': 3, 'abx': 3, 'aby': 3, 'ind': 3, 'iax': 3}
NMOS, CMOS = {}, {}
for tab, spec in ((NMOS, _NMOS), (CMOS, _CMOS)):
    for ent in spec.replace('\n', '|').split('|'):
        p = ent.split()
        if p:
            tab[int(p[0], 16)] = (p[1], p[2])
OPS = dict(NMOS); OPS.update(CMOS)
MNEMONICS = {m.lower() for m, _ in OPS.values()}
BRANCHES = {'BPL', 'BMI', 'BVC', 'BVS', 'BCC', 'BCS', 'BNE', 'BEQ', 'BRA'}

_RMW = {'ASL', 'LSR', 'ROL', 'ROR', 'INC', 'DEC', 'TSB', 'TRB'}


def cycles(mn, mode):
    """65C02 base cycles (no page-crossing / branch-taken extras).  Returns (base, note):
    note '+p' (+1 on a page crossing), '+t' (branch: +1 taken, +1 more crossing)."""
    if mode == 'rel':
        return (3, '+p') if mn == 'BRA' else (2, '+t')
    if mode in ('imp', 'acc'):
        return {'PHA': 3, 'PHP': 3, 'PHX': 3, 'PHY': 3, 'PLA': 4, 'PLP': 4, 'PLX': 4,
                'PLY': 4, 'RTS': 6, 'RTI': 6, 'BRK': 7}.get(mn, 2), ''
    if mode == 'imm':
        return 2, ''
    rmw = mn in _RMW
    if mode == 'zp':
        return (5 if rmw else 3), ''
    if mode in ('zpx', 'zpy'):
        return (6 if rmw else 4), ''
    if mode == 'abs':
        if mn == 'JMP':
            return 3, ''
        if mn == 'JSR':
            return 6, ''
        return (6 if rmw else 4), ''
    if mode in ('abx', 'aby'):
        if mn in ('INC', 'DEC'):
            return 7, ''
        if rmw:
            return 6, '+p'
        if mn in ('STA', 'STZ'):
            return 5, ''
        return 4, '+p'
    if mode == 'inx':
        return 6, ''
    if mode == 'iny':
        return (6, '') if mn == 'STA' else (5, '+p')
    if mode == 'zpi':
        return 5, ''
    if mode in ('ind', 'iax'):
        return 6, ''
    return 2, ''


SEGFILE = {'BCODE': 'main', 'HICODE': 'main',
           'BANK4': 'B4', 'COLD7': 'C7', 'BANK5': 'B5',
           'RASTA': 'RA', 'BANK6': 'B6', 'HAZEL': 'HZ'}
SIDEWAYS = ('B4', 'C7', 'B5', 'RA', 'B6')
SEGORDER = ('main', 'B4', 'C7', 'HZ', 'B5', 'RA', 'B6')
# The sideways memory map, as data: each bank's segments at &8000-&BFFF, the
# segment ANDY holds (ROMSEL bit 7 shows it over &8000-&8FFF of the paged bank),
# and the ROMSEL each segment's code runs with.  What code in a segment sees at
# &8000-&BFFF (VIEW, [(segment, lo, hi)]; None: unknown, any bank) and what each
# ROMSEL value shows (ROMSEL_VIEW: the far calls) follow from them.
ANDYSEG = 'RA'          # the rasteriser's polygon window (ROMSEL &85)


BANKSEGS = {4: (('B4', 0x8000, 0xC000),), 5: (('B5', 0x8000, 0xC000),), 6: (('B6', 0x8000, 0xC000),),
            7: (('C7', 0x8000, 0xC000),)}
# (B5's code at &9000-, the rasteriser's shared region, runs with either window:
# its view is the disc window's; references naming a label resolve by the label)
SEGROMSEL = {'B4': 0x04, 'C7': 0x07, 'B5': 0x05, 'RA': 0x85, 'B6': 0x06}


def romsel_view(rs):
    """what ROMSEL rs shows at &8000-&BFFF (bit 7: ANDYSEG over &8000-&8FFF)"""
    segs = BANKSEGS.get(rs & 15)
    if segs is None:
        return None
    if rs & 0x80:
        return ((ANDYSEG, 0x8000, 0x9000),) + tuple((s, max(lo, 0x9000), hi) for s, lo, hi in segs if hi > 0x9000)
    return segs


def _views():
    global VIEW, ROMSEL_VIEW
    ROMSEL_VIEW = {rs: romsel_view(rs) for rs in set(SEGROMSEL.values())}
    VIEW = {'main': romsel_view(4), 'RAM': romsel_view(4), 'HZ': None, 'SH': None}
    VIEW.update({sg: romsel_view(rs) for sg, rs in SEGROMSEL.items()})


_views()




def profile_seg(pfx, a):
    """the segment that a profile key (mprof's mapping: M, A, B4..B7, HZ) names at a"""
    if pfx == 'M':
        return 'main'
    if pfx == 'HZ':
        return 'HZ'
    if pfx == 'A':
        return ANDYSEG
    if pfx.startswith('B') and pfx[1:].isdigit():
        return view_seg(BANKSEGS.get(int(pfx[1:])), a)
    return None


# shadow RAM data (elite-data.asm's TOKENS.bin): the equates naming it
SHADOW_NAMES = ('TKN1', 'RUPLA', 'RUGAL', 'RUTOK')


def view_seg(view, a):
    """the segment a view shows at sideways address a (None: unknown)"""
    if view is None:
        return None
    for s, lo, hi in view:
        if lo <= a < hi:
            return s
    return None


def sideways(a):
    return 0x8000 <= a < 0xC000


class Source:
    """file (path as BeebAsm names it, e.g. src/raster.asm) -> lines"""
    def __init__(self, tree):
        self.tree, self.lines, self.names = tree, {}, {}

    def load(self, fid):
        if fid in self.lines:
            return
        p = os.path.join(self.tree, fid)
        try:
            self.lines[fid] = open(p, 'rb').read().decode('latin-1').split('\n')
        except OSError:
            self.lines[fid] = None
        self.names[fid] = fid

    def text(self, fid, line):
        L = self.lines.get(fid)
        if L is None or not (1 <= line <= len(L)):
            return None
        return L[line - 1].rstrip('\r')

    def short(self, fid):
        return fid


class Insn:
    __slots__ = ('key', 'seg', 'addr', 'op', 'mn', 'mode', 'len', 'opnd', 'bytes',
                 'outer', 'inner', 'game', 'volatile', 'opvolatile', 'idx', 'cmos', 'skip',
                 'opname', 'tseg')

    def __repr__(self):
        return f"{self.mn} {self.mode} ${self.addr:04X}"


_IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_%$]*")
_FUNCS = {'LO', 'HI', 'AND', 'OR', 'EOR', 'DIV', 'MOD', 'NOT', 'A', 'X', 'Y', 'P%',
          'SIN', 'COS', 'INT', 'ABS', 'SQR', 'RND', 'LEFT', 'RIGHT'}


def strip_comment(t):
    """a BeebAsm source line without its comment (\\ or ;), strings kept"""
    out, q = [], None
    for ch in t:
        if q:
            out.append(ch)
            if ch == q:
                q = None
            continue
        if ch in '"\'':
            q = ch; out.append(ch); continue
        if ch in '\\;':
            break
        out.append(ch)
    return ''.join(out)


def operand_text(t):
    """the operand part of an instruction statement: 'LDA #LO(x)' -> '#LO(x)'.
    A line may hold a label and several ':'-separated statements; the first with a
    mnemonic is taken (callers that care check the mnemonic)."""
    s = strip_comment(t or '')
    for part in s.split(':'):
        p = part.strip()
        p = re.sub(r'^\.[\^*]?[A-Za-z_][\w%$]*\s*', '', p)
        m = re.match(r'([A-Za-z]{3})\b\s*(.*)$', p)
        if m and m.group(1).lower() in MNEMONICS:
            return m.group(1).upper(), m.group(2).strip()
    return None, ''


class Program:
    def __init__(self, root, build, game_dir=None):
        self.root, self.build, self.notes = root, build, []
        self.tree = os.path.join(build, 'tree', 'master')
        self.src = Source(self.tree)
        self._read_gmap()
        self._read_symbols()
        self._segments()
        self._decode()
        self._symbols()

    # ------------------------------------------------------------ gmap
    def _read_gmap(self):
        epoch = 0
        recs, labels, saves, copies, equs = [], [], [], [], []
        with open(os.path.join(self.build, 'gmap.tsv'), encoding='latin-1') as fh:
            for ln in fh:
                f = ln.rstrip('\n').split('\t')
                k = f[0]
                if k == 'C':
                    epoch += 1
                elif k in ('I', 'D', 'S'):
                    recs.append((k, int(f[1]), int(f[2]), f[3], int(f[4]), f[5], int(f[6]), epoch))
                elif k == 'L':
                    labels.append((f[1], int(f[2]), f[3], int(f[4]), epoch))
                elif k == 'V':
                    # (name without extension(s), start, end, epoch, the file as saved)
                    saves.append((os.path.basename(f[1]).split('.')[0], int(f[2]), int(f[3]), epoch, f[1]))
                elif k == 'B':
                    copies.append((int(f[1]), int(f[2]), int(f[3]), epoch))
                elif k == 'E':
                    equs.append((f[1], int(float(f[2])), f[3], int(f[4])))
        self.grecs, self.glabels, self.gsaves, self.gcopies = recs, labels, saves, copies
        self.gequs = equs

    def _read_symbols(self):
        self.gsym = {}
        try:
            txt = open(os.path.join(self.build, 'symbols.txt'), encoding='latin-1').read()
            for m in re.finditer(r"'([^']+)':(-?\d+)L?", txt):
                self.gsym.setdefault(m.group(1), int(m.group(2)))
        except OSError:
            self.notes.append('symbols.txt missing: no equates')

    def segname(self, pc, epoch):
        for name, s, e, ep, _f in self.gsaves:
            if ep == epoch and s <= pc < e:
                return SEGFILE.get(name, name)
        if 0xC000 <= pc < 0xE000:
            return 'HZ'
        return 'RAM'

    # ------------------------------------------------------------ segments
    def _segments(self):
        ext = collections.defaultdict(lambda: [0x10000, 0])
        for (k, pc, n, *_r, ep) in self.grecs:
            s = self.segname(pc, ep)
            e = ext[s]
            e[0] = min(e[0], pc); e[1] = max(e[1], pc + n)
        self.segs = {}
        # the images: per segment [(start, bytes)].  BCODE.unprot.bin is what the
        # assembler saved; the disc has BCODE.bin (the commander checksum set by
        # elite-checksum.py), which is what the loader loads
        imgs = collections.defaultdict(list)
        for name, s, e, ep, f in self.gsaves:
            seg = SEGFILE.get(name, name)
            p = os.path.join(self.tree, f)
            if f.endswith('.unprot.bin') and os.path.exists(p.replace('.unprot.bin', '.bin')):
                p = p.replace('.unprot.bin', '.bin')
            try:
                imgs[seg].append((s, open(p, 'rb').read()[:e - s]))
            except OSError:
                self.notes.append(f'image {p} unreadable')
        # shadow RAM's tokens (elite-data.asm's TOKENS.bin at TKN1): data only
        tk = self.gsym.get('TKN1', next((v for n, v, f, l in self.gequs if n == 'TKN1'), None))
        p = os.path.join(self.tree, 'build', 'TOKENS.bin')
        if tk is not None and os.path.exists(p):
            b = open(p, 'rb').read()
            imgs['SH'].append((tk, b))
            ext['SH'] = [tk, tk + len(b)]
        else:
            self.notes.append('TOKENS.bin / TKN1 missing: no shadow RAM data segment')
        self.loaded = {}             # seg -> [(lo, hi)]: the bytes an image loads
        for seg, (lo, hi) in ext.items():
            data = None
            if seg in imgs:
                data = bytearray(hi - lo)
                for s0, b in imgs[seg]:
                    for a in range(max(lo, s0), min(hi, s0 + len(b))):
                        data[a - lo] = b[a - s0]
                self.loaded[seg] = sorted((max(lo, s0), min(hi, s0 + len(b))) for s0, b in imgs[seg])
            self.segs[seg] = dict(name=seg, start=lo, size=hi - lo,
                                  data=bytes(data) if data is not None and seg != 'RAM' else None,
                                  bank=seg, oname=seg)
        self.segs.setdefault('RAM', dict(name='RAM', start=0, size=0, data=None, bank='RAM', oname=None))
        # per segment: data offsets (D and S), SKIP offsets (bss), record source lines
        self.data_off = collections.defaultdict(set)
        self.bss = collections.defaultdict(set)
        self.datarec = collections.defaultdict(dict)       # seg -> addr -> (file, line)
        for (k, pc, n, f, l, sf, sl, ep) in self.grecs:
            if k == 'I':
                continue
            seg = self.segname(pc, ep)
            st = self.segs[seg]['start']
            for a in range(pc, pc + n):
                self.data_off[seg].add(a - st)
                if k == 'S':
                    self.bss[seg].add(a)
            self.datarec[seg][pc] = (k, n, f, l, sf, sl)

    # ------------------------------------------------------------ decoding
    def _decode(self):
        S = self.src
        insn_at = {}
        bad = []
        for (k, pc, n, f, l, sf, sl, ep) in self.grecs:
            if k != 'I':
                continue
            seg = self.segname(pc, ep)
            sg = self.segs[seg]
            if sg['data'] is None:
                bad.append((seg, pc)); continue
            off = pc - sg['start']
            op = sg['data'][off]
            ent = OPS.get(op)
            if ent is None or LEN[ent[1]] != n:
                bad.append((seg, pc)); continue
            S.load(f); S.load(sf)
            i = Insn()
            i.key = (seg, pc); i.seg = seg; i.addr = pc; i.op = op
            i.mn, i.mode = ent; i.len = n; i.cmos = op in CMOS
            b = sg['data'][off:off + n]; i.bytes = b
            if i.mode == 'rel':
                d = b[1]
                i.opnd = (pc + 2 + (d - 256 if d >= 128 else d)) & 0xFFFF
            elif n == 2:
                i.opnd = b[1]
            elif n == 3:
                i.opnd = b[1] | (b[2] << 8)
            else:
                i.opnd = None
            i.inner = dict(file=f, line=l)
            i.outer = dict(file=sf, line=sl)
            i.game = True
            i.volatile = False; i.opvolatile = False; i.skip = False
            i.opname = None; i.tseg = None
            insn_at[(seg, pc)] = i
        self.insns = insn_at
        self.bad = bad
        self.by_addr = collections.defaultdict(list)
        for i in insn_at.values():
            self.by_addr[i.addr].append(i)
        self.cover = collections.defaultdict(list)
        for i in insn_at.values():
            for k in range(i.len):
                self.cover[(i.addr + k) & 0xFFFF].append((i, k))
        self.game_files = {i.outer['file'] for i in insn_at.values()}
        self.reorder()
        if bad:
            self.notes.append(f"{len(bad)} instruction records whose bytes did not decode to "
                              f"their length (counted as data)")

    def reorder(self):
        segord = {s: n for n, s in enumerate(SEGORDER)}
        self.order = sorted(self.insns.values(), key=lambda i: (segord.get(i.seg, 9), i.addr))
        for n, i in enumerate(self.order):
            i.idx = n

    def code_segs(self):
        return {i.seg for i in self.insns.values()}

    def is_data(self, seg, addr):
        sg = self.segs[seg]
        return (addr - sg['start']) in self.data_off[seg]

    def bank_at(self, from_seg, addr):
        """the segment code in from_seg sees at sideways address addr (None: unknown --
        HAZEL code runs with any bank paged)"""
        return view_seg(VIEW.get(from_seg), addr)

    def paged(self, seg, addr=0x8000):
        """(compatibility) the segment seg's code sees at addr"""
        return self.bank_at(seg, addr)

    def is_loaded(self, seg, addr):
        """is addr's byte in seg loaded from an image (else unknown at start-up)?"""
        for lo, hi in self.loaded.get(seg, ()):
            if lo <= addr < hi:
                return True
        return False

    def resolve(self, addr, from_seg, insn=None):
        """The instruction a JSR/JMP/branch to addr from code in from_seg reaches, or None"""
        c = self.by_addr.get(addr, [])
        if not c:
            return None
        if insn is not None and insn.tseg is not None:
            for i in c:
                if i.seg == insn.tseg:
                    return i
        for i in c:
            if i.seg == from_seg:
                return i
        if sideways(addr):
            pb = self.bank_at(from_seg, addr)
            same = [i for i in c if i.seg == pb]
            if len(same) == 1:
                return same[0]
            if pb is not None:
                return None
        if len(c) == 1:
            return c[0]
        return None

    def resolve_view(self, addr, view):
        """the instruction at addr with a given bank view (far calls), or None"""
        c = self.by_addr.get(addr, [])
        if sideways(addr):
            s = view_seg(view, addr)
            c = [i for i in c if i.seg == s]
        else:
            c = [i for i in c if i.seg not in SIDEWAYS]
        return c[0] if len(c) == 1 else None

    def resolve_all(self, addr, from_seg, insn=None):
        t = self.resolve(addr, from_seg, insn)
        if t is not None:
            return [t]
        if sideways(addr) and self.bank_at(from_seg, addr) is not None:
            return []
        return list(self.by_addr.get(addr, []))

    def in_seg(self, seg, addr):
        sg = self.segs[seg]
        return sg['start'] <= addr < sg['start'] + sg['size']

    def mem_seg(self, addr, from_seg, insn=None):
        """the segment whose byte a data access to addr from from_seg reads (None:
        none or ambiguous).  Shadow RAM (SH) only for an operand that names its data."""
        if insn is not None and insn.tseg is not None and self.in_seg(insn.tseg, addr):
            return insn.tseg
        if sideways(addr):
            pb = self.bank_at(from_seg, addr)
            if pb is None:
                return None
            return pb if pb in self.segs and self.in_seg(pb, addr) else None
        for s, sg in self.segs.items():
            if sg['data'] is not None and s not in SIDEWAYS and s != 'SH' and self.in_seg(s, addr):
                return s
        return None

    # ------------------------------------------------------------ symbols
    def _symbols(self):
        self.syms = []
        self.label_seg = collections.defaultdict(set)     # name -> {seg}
        lab_by = collections.defaultdict(list)            # name -> [(val, seg)]
        for (name, pc, f, l, ep) in self.glabels:
            seg = self.segname(pc, ep)
            if seg == 'RAM':
                # a label at the very end of a segment (MAIN_END ...) or in a gap
                for s, sg in self.segs.items():
                    if sg['data'] is not None and sg['start'] <= pc <= sg['start'] + sg['size'] \
                            and (s not in SIDEWAYS or self.segname(pc - 1, ep) == s):
                        seg = s
            glob = self.gsym.get(name) == pc
            self.syms.append(dict(name=name, val=pc, seg=seg, type='lab', refs=[], size=0,
                                  parent=None if glob else 'local', scope=None, file=f, line=l))
            self.label_seg[name].add(seg)
            lab_by[name].append((pc, seg))
        labnames = set(lab_by)
        seen = set()
        for name, v, f, l in self.gequs:
            if name in labnames or (name, v) in seen:
                continue
            seen.add((name, v))
            self.syms.append(dict(name=name, val=v, seg=None, type='equ', refs=[], size=0,
                                  parent=None, scope=None, file=f, line=l))
        self.lab_by = lab_by
        # operand symbols: the label (or equate) the operand text names, and the segment
        # of a label it names (a transfer or data access into a sideways bank)
        eq = {}
        for s in self.syms:
            if s['type'] == 'equ':
                eq.setdefault(s['name'], s['val'])
        self.equ = eq
        for i in self.insns.values():
            mn, ot = operand_text(self.src.text(i.inner['file'], i.inner['line']))
            if mn != i.mn or i.opnd is None or i.mode in ('imp', 'acc', 'imm'):
                continue
            for m in _IDENT.finditer(ot):
                nm = m.group(0)
                if nm.upper() in _FUNCS:
                    continue
                cands = lab_by.get(nm)
                if cands:
                    xfer = i.mode == 'rel' or i.mn in ('JSR', 'JMP') and i.mode == 'abs'
                    hit = [(v, s) for v, s in cands if (v == i.opnd if xfer else 0 <= i.opnd - v <= 255)]
                    if hit:
                        v, s = hit[0]
                        segs = {s for v2, s in hit if v2 == v}
                        if len(segs) == 1 and s in self.segs and s != 'RAM':
                            i.tseg = s
                        i.opname = nm if i.opnd == v else f"{nm}+{i.opnd - v}"
                        break
                elif nm in eq and 0 <= i.opnd - eq[nm] + 1 <= 256 and i.mode not in ('rel',):
                    v = eq[nm]
                    i.opname = nm if i.opnd == v else (f"{nm}+{i.opnd - v}" if i.opnd > v else f"{nm}-1")
                    if nm in SHADOW_NAMES and 'SH' in self.segs:
                        i.tseg = 'SH'        # shadow RAM data (read with ACCCON X set)
                    break
        # names for data addresses: labels outside code (RAM, data in segments), globals
        # first; then equates the code uses as memory operands
        self.addr_name = {}          # (seg or None, addr) -> name; seg only for sideways
        for s in sorted((s for s in self.syms if s['type'] == 'lab'),
                        key=lambda s: (s['parent'] is not None, len(s['name']))):
            if (s['seg'], s['val']) in self.insns:
                continue
            k = (s['seg'] if sideways(s['val']) else None, s['val'])
            self.addr_name.setdefault(k, s['name'])
        for i in self.insns.values():
            if i.opname and '+' not in i.opname and i.mode not in ('rel',) and \
                    i.mn not in ('JSR', 'JMP'):
                k = (self.mem_seg(i.opnd, i.seg, i) if sideways(i.opnd) else None, i.opnd)
                self.addr_name.setdefault(k, i.opname)
        self.code_label = collections.defaultdict(list)
        for s in self.syms:
            if s['type'] == 'lab' and (s['seg'], s['val']) in self.insns:
                self.code_label[(s['seg'], s['val'])].append(s)
        # routine names: global code labels per segment
        self.glob = collections.defaultdict(list)
        for s in self.syms:
            if s['type'] == 'lab' and s['parent'] is None and s['seg'] is not None:
                self.glob[s['seg']].append((s['val'], s['name']))
        for v in self.glob.values():
            v.sort()

    def find(self, name):
        """value of a symbol (label or equate) or None"""
        v = self.lab_by.get(name)
        if v:
            return v[0][0]
        if name in self.equ:
            return self.equ[name]
        return self.gsym.get(name)

    def where(self, i):
        return f"{i.outer['file']}:{i.outer['line']}"

    def text(self, i, inner=False):
        r = i.inner if inner else i.outer
        return (self.src.text(r['file'], r['line']) or '').rstrip()

    def routine_of(self, i):
        g = self.glob.get(i.seg, [])
        k = bisect.bisect_right(g, (i.addr, '￿')) - 1
        return g[k][1] if k >= 0 else '?'

    def name(self, addr, seg=None):
        """a name for data address addr (as code in seg sees it)"""
        s = self.mem_seg(addr, seg) if (seg is not None and sideways(addr)) else None
        k = (s, addr)
        n = self.addr_name.get(k)
        if n:
            return n
        if (s, addr - 1) in self.addr_name:
            return self.addr_name[(s, addr - 1)] + '+1'
        return f"${addr:04X}" if addr > 0xFF else f"${addr:02X}"

    def label_of(self, i):
        labs = self.code_label.get(i.key)
        if not labs:
            return None
        return sorted(labs, key=lambda s: (s['parent'] is not None, len(s['name'])))[0]['name']

    def disasm(self, i):
        m = i.mn.lower(); o = i.opnd
        nm = lambda a: (i.opname if i.opname else self.name(a, i.seg)) if a is not None else '?'
        fmt = {'imp': '{}', 'acc': 'a', 'imm': '#${:02X}', 'zp': '{}', 'zpx': '{},x',
               'zpy': '{},y', 'inx': '({},x)', 'iny': '({}),y', 'zpi': '({})', 'abs': '{}',
               'abx': '{},x', 'aby': '{},y', 'ind': '({})', 'iax': '({},x)', 'rel': '${:04X}'}[i.mode]
        if i.mode == 'imp':
            s = ''
        elif i.mode in ('imm', 'rel'):
            s = fmt.format(o if o is not None else 0)
        else:
            s = fmt.format(nm(o))
        if i.mn in ('JSR', 'JMP') and i.mode == 'abs' or i.mode == 'rel':
            t = self.resolve(o, i.seg, i)
            lab = self.label_of(t) if t else None
            s = lab if lab else f"${o:04X}"
        return (m + ' ' + s).strip()
