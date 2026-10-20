"""analysis -- CFG, interprocedural summaries, backward liveness, forward constants.

(tools/grind copy, adapted from beebgame/tools/dataflow/analysis.py for Elite's BeebAsm
build: BIT skips from the grindmap's EQUB records; address-taken entries from the
source text (immediates #LO()/#HI() and data naming a code label); self-modifying
stores restricted to the bank the store can reach; the rasteriser's cross-bank calls
(r_call7 / r_call5 through r_hzt7 / r_hzt5) resolved to their targets; the interrupt's
JMP (VEC) into the MOS taken as an exit that touches no game memory; PAGED is
&3000-&BFFF (HAZEL is fixed RAM during the game).)


The domain is one Python int per program point:
    bit 0..6   A X Y N Z C V
    bit 7..    one bit per memory byte in the UNIVERSE: every address any decoded
               instruction (or inline helper operand) names directly, less the stack
               page and the I/O pages.  Memory nobody names directly cannot be the
               target of a dead store, so it needs no bit; reads of it through
               pointers are covered by MALL (every universe bit).

Soundness rules (unknown means everything live, every value unknown):
  * an edge the CFG cannot resolve (jmp (ind), jmp (a,x), BRK, a branch or
    fall-through into data, a JSR/JMP to an address several banks share, a
    self-modified opcode) is an exit where everything is live;
  * RTS: all memory live, plus the registers/flags any caller of any routine whose
    body contains this RTS reads after its JSR.  A routine entered other than by a
    resolved JSR (address-taken, a dispatch table, the interrupt, code with no
    known predecessor) returns with everything live;
  * JSR to a routine whose body plays stack games (PHA/PLA imbalance, TSX/TXS),
    leaves the model, or is unresolved: callee reads and clobbers everything;
  * the interrupt (irq_handler / isr_body and everything they reach) may run
    between any two instructions: memory it reads is live everywhere, memory it
    writes is never a known constant;
  * paged memory ($3000-$DFFF: shadow screen, sideways banks, HAZEL) is made live
    by every JSR and every I/O write, so a store is never called dead because a
    store to "the same" address in a different bank follows it;
  * stores into code (self-modification) mark the patched instruction: an operand
    patch makes its operand unknown, an opcode patch makes it a barrier.
"""
import bisect, collections, re
from model import BRANCHES, LEN, Insn, operand_text, strip_comment, sideways, _IDENT, _FUNCS

A, X, Y, N, Z, C, V = (1 << k for k in range(7))
REGS = A | X | Y
FLAGS = N | Z | C | V
RF = REGS | FLAGS
RNAME = [(A, 'A'), (X, 'X'), (Y, 'Y'), (N, 'N'), (Z, 'Z'), (C, 'C'), (V, 'V')]


def model_sideways_segs():
    import model
    return model.SIDEWAYS


def rf_str(m):
    s = ''.join(n for b, n in RNAME if m & b)
    return s or '-'


IO_LO, IO_HI = 0xFC00, 0xFEFF
PAGED_LO, PAGED_HI = 0x3000, 0xBFFF
STACK_LO, STACK_HI = 0x0100, 0x01FF

# The game's inline-operand helpers, their scratch words and the interrupt's data
# pointers: the game's config (gamecfg.py).  A helper's contract is (roles, uses): see there.
import gamecfg


def helpers():
    """{label: (roles, uses as register bits)} from the game's config"""
    bits = {'A': A, 'X': X, 'Y': Y}
    out = {}
    for k, (roles, uses) in gamecfg.C.INLINE_HELPERS.items():
        u = 0
        if isinstance(uses, int):
            u = uses
        else:
            for r in uses or ():
                u |= bits[r]
        out[k] = (list(roles), u)
    return out


STORES = {'STA', 'STX', 'STY', 'STZ'}
RMW = {'INC', 'DEC', 'ASL', 'LSR', 'ROL', 'ROR', 'TSB', 'TRB'}
READS_MEM = {'LDA', 'LDX', 'LDY', 'ADC', 'SBC', 'AND', 'ORA', 'EOR', 'CMP', 'CPX', 'CPY',
             'BIT'} | RMW
ZNSET = {'LDA', 'LDX', 'LDY', 'TAX', 'TAY', 'TXA', 'TYA', 'TSX', 'PLA', 'PLX', 'PLY',
         'INX', 'INY', 'DEX', 'DEY', 'INC', 'DEC', 'AND', 'ORA', 'EOR', 'ADC', 'SBC',
         'ASL', 'LSR', 'ROL', 'ROR', 'CMP', 'CPX', 'CPY'}


class Analysis:
    def __init__(self, P, isr_roots=None, strict_isr=False):
        self.P = P
        self.strict_isr = strict_isr
        self.notes = P.notes
        self.isr_names = isr_roots or tuple(gamecfg.C.ISR_ROOTS)
        self._skips()
        self._far()
        self._universe()
        self._smc()
        self._cfg()
        self._entries()
        self._contexts()
        self._isr()
        self._summaries()
        self._forward()
        # a branch whose other edge falls into data/unknown is an unresolved exit;
        # where the forward pass proves that edge never taken, drop it and redo
        if self._prune():
            self._isr()
            self._summaries()
            self._forward()
        self._liveness()

    # ------------------------------------------------------------ BIT skips
    def _skips(self):
        """`EQUB &2C` / `EQUB &24` in code: the BIT that skips the next instruction.
        Modelled as the BIT it is (reads its operand, sets N V Z)."""
        P = self.P
        n = 0
        more = True
        while more:
          more = False
          for seg, recs in P.datarec.items():
            sg = P.segs[seg]
            if sg['data'] is None:
                continue
            for a, (k, ln_, f, l, sf, sl) in recs.items():
                if k != 'D' or ln_ != 1 or (seg, a) in P.insns:
                    continue
                op = sg['data'][a - sg['start']]
                if op not in (0x2C, 0x24):
                    continue
                ln = 3 if op == 0x2C else 2
                if (seg, a + 1) not in P.insns or (seg, a + ln) not in P.insns:
                    continue
                off = a - sg['start']
                b = sg['data'][off:off + ln]
                j = Insn()
                j.key = (seg, a); j.seg = seg; j.addr = a; j.op = op
                j.mn = 'BIT'; j.mode = 'abs' if ln == 3 else 'zp'; j.len = ln
                j.bytes = b; j.opnd = b[1] | (b[2] << 8) if ln == 3 else b[1]
                j.cmos = False; j.volatile = False; j.opvolatile = False
                j.inner = dict(file=f, line=l); j.outer = dict(file=sf, line=sl)
                j.game = True; j.skip = True; j.opname = None; j.tseg = None
                P.insns[j.key] = j
                P.by_addr[a].append(j)
                for kk in range(ln):
                    P.cover[(a + kk) & 0xFFFF].append((j, kk))
                n += 1; more = True
        # a transfer into the middle of an instruction whose byte there is an RTS
        # (Elite's `BNE zZ+1`, zZ: LDA #&60): that RTS, as an instruction of its own
        nh = 0
        for i in list(P.insns.values()):
            if not (i.mode == 'rel' or i.mn in ('JSR', 'JMP') and i.mode == 'abs'):
                continue
            a = i.opnd
            if P.resolve(a, i.seg, i) is not None:
                continue
            for (c, kk) in P.cover.get(a, []):
                if kk == 0 or (sideways(a) and c.seg != (i.tseg or P.bank_at(i.seg, a) or c.seg)) or \
                        (not sideways(a) and c.seg not in (i.seg, i.tseg) and len(P.cover.get(a)) > 1):
                    continue
                sg = P.segs[c.seg]
                if sg['data'][a - sg['start']] != 0x60 or (c.seg, a) in P.insns:
                    continue
                j = Insn()
                j.key = (c.seg, a); j.seg = c.seg; j.addr = a; j.op = 0x60
                j.mn = 'RTS'; j.mode = 'imp'; j.len = 1; j.bytes = bytes([0x60]); j.opnd = None
                j.cmos = False; j.volatile = False; j.opvolatile = False
                j.inner = c.inner; j.outer = c.outer; j.game = True; j.skip = True
                j.opname = None; j.tseg = None
                P.insns[j.key] = j; P.by_addr[a].append(j); P.cover[a].append((j, 0))
                nh += 1
        if nh:
            self.notes.append(f"{nh} transfers into an instruction's operand byte that is an RTS "
                              f"(`BNE zZ+1`): that byte modelled as an RTS")
        self.skip_keys = {k for k, i in P.insns.items() if getattr(i, 'skip', False)}
        if n:
            self.notes.append(f"{n} BIT-skip bytes (EQUB &2C/&24) modelled as BIT")
        P.reorder()

    # ------------------------------------------------------------ far calls
    def _far(self):
        """The far calls between the home bank and the cold area (master/src/elite-far.asm):
        `JSR far7 : EQUW target` (far4, far7j, far4j likewise).  far7/far4 page the
        target's bank in (ROMSEL &87 / 4), call it, page the caller's bank back and return
        to the stub's *caller* (the stub's own return address is dropped); A X Y and every
        flag pass both ways unchanged.  far7j/far4j jump (the target returns to the stub's
        caller, if at all).  So a stub is modelled as `JSR target` with the far code's
        effects (it writes the config's FAR_SCRATCH: fA fX fB ft, &F4; ROMSEL; may page
        any bank) followed by an RTS standing for the EQUW's two bytes (a pseudo
        instruction).  self.far: JSR key -> target insn; self.far_ops: the EQUWs."""
        P = self.P
        import model
        self.far, self.far_ops, bad = {}, set(), []
        fl = {}
        for nm, romsel in gamecfg.C.FAR_CALLS.items():
            a = P.find(nm)
            if a is not None:
                fl[a] = (nm, romsel)
        for i in list(P.insns.values()):
            if i.mn != 'JSR' or i.mode != 'abs' or i.opnd not in fl:
                continue
            nm, romsel = fl[i.opnd]
            sg = P.segs[i.seg]
            o = i.addr + 3 - sg['start']
            rec = P.datarec.get(i.seg, {}).get(i.addr + 3)
            if rec is None or rec[0] != 'D' or (i.seg, i.addr + 3) in P.insns:
                bad.append(i); continue
            w = sg['data'][o] | (sg['data'][o + 1] << 8)
            t = P.resolve_view(w, model.ROMSEL_VIEW.get(romsel))
            if t is None:
                bad.append(i); continue
            j = Insn()
            j.key = (i.seg, i.addr + 3); j.seg = i.seg; j.addr = i.addr + 3; j.op = 0x60
            j.mn = 'RTS'; j.mode = 'imp'; j.len = 2; j.bytes = sg['data'][o:o + 2]; j.opnd = None
            j.cmos = False; j.volatile = False; j.opvolatile = False
            j.inner = dict(file=rec[2], line=rec[3]); j.outer = dict(file=rec[4], line=rec[5])
            j.game = True; j.skip = True
            j.opname = None; j.tseg = None
            P.insns[j.key] = j; P.by_addr[j.addr].append(j)
            for kk in range(2):
                P.cover[(j.addr + kk) & 0xFFFF].append((j, kk))
            self.far[i.key] = t
            self.far_ops.add(j.key)
        P.reorder()
        sc = 0
        for nm in gamecfg.C.FAR_SCRATCH:
            a = P.find(nm) if isinstance(nm, str) else nm
            if a is not None:
                sc += 1
        self.notes.append(f"far calls: {len(self.far)} `JSR far7/far4/far7j/far4j : EQUW target` "
                          f"resolved (each a call to its target plus the far code's effects, then a "
                          f"return: the EQUW is a pseudo RTS); {len(bad)} unresolved"
                          + (': ' + ', '.join(P.where(b) for b in bad[:10]) if bad else ''))
        self.far_bad = bad

    # ------------------------------------------------------------ universe
    def _helper_ops(self, i):
        """For a JSR to an inline helper: (spec, operand bytes) or None."""
        P = self.P
        if i.mn != 'JSR':
            return None
        t = P.resolve(i.opnd, i.seg)
        if t is None:
            return None
        for s in P.code_label.get(t.key, []):
            H = helpers()
            if s['name'] in H:
                roles, uses = H[s['name']]
                sg = P.segs[i.seg]
                off = i.addr + 3 - sg['start']
                ops = list(sg['data'][off:off + len(roles)])
                return s['name'], roles, uses, ops
        return None

    def _universe(self):
        P = self.P
        U = set()
        def ok(a):
            return not (STACK_LO <= a <= STACK_HI or IO_LO <= a <= IO_HI)
        for i in P.insns.values():
            if i.mode in ('zp', 'abs', 'zpx', 'zpy', 'abx', 'aby') and \
                    i.mn not in ('JSR', 'JMP') and i.opnd is not None:
                if ok(i.opnd):
                    U.add(i.opnd)
                if i.mode in ('zp', 'zpx', 'zpy') or i.mode in ('abx', 'aby'):
                    pass
            if i.mode in ('inx', 'iny', 'zpi'):
                U.add(i.opnd); U.add((i.opnd + 1) & 0xFF)
            h = self._helper_ops(i)
            if h:
                for role, v in zip(h[1], h[3]):
                    if role != 'i':
                        U.add(v); U.add((v + 1) & 0xFF)
        for nm in gamecfg.C.HELPER_SCRATCH:
            for s in P.syms:
                if s['name'] == nm:
                    U.add(s['val']); U.add(s['val'] + 1)
        self.U = sorted(U)
        self.bit = {a: 1 << (7 + k) for k, a in enumerate(self.U)}
        self.MALL = ((1 << len(self.U)) - 1) << 7
        self.ALL = self.MALL | RF
        self.ZPALL = 0
        self.PAGED = 0
        for a, b in self.bit.items():
            if a < 0x100:
                self.ZPALL |= b
            if PAGED_LO <= a <= PAGED_HI:
                self.PAGED |= b
        self._rng = {}

    def mbits(self, lo, n):
        """Universe bits for addresses lo .. lo+n-1."""
        k = (lo, n)
        r = self._rng.get(k)
        if r is None:
            r = 0
            a = bisect.bisect_left(self.U, lo)
            while a < len(self.U) and self.U[a] < lo + n:
                r |= self.bit[self.U[a]]; a += 1
            self._rng[k] = r
        return r

    def mb(self, a):
        return self.bit.get(a, 0)

    def names_of(self, m):
        out = []
        m >>= 7
        k = 0
        while m:
            if m & 1:
                out.append(self.U[k])
            m >>= 1; k += 1
        return out

    # ------------------------------------------------------------ SMC
    def _smc(self):
        """Stores into code.  A direct store marks the instruction whose bytes hold its
        target -- in the bank the store reaches: the segment of the label its operand
        names (STA r_pt3+2), else the storer's own bank / bank 4 from main code (HAZEL
        code naming no label: every bank).  An opcode store makes the instruction a
        barrier (volatile), an operand store makes its operand unknown (opvolatile).
        Indexed stores count only when their base is itself inside an instruction;
        such a store also reaches base + d for every offset d the program loads into
        its index register as a difference of two code labels (`LDX #MLSA-MLSB` then
        stl_pat's `STA mlb1+1,X`: one store patches two parallel copies of the code).
        Stores to SKIP bytes are data."""
        P = self.P
        n = 0
        # index offsets between parallel code copies: LDX/LDY #label1-label2
        code_names = {s['name'] for labs in P.code_label.values() for s in labs}
        offs = {'X': set(), 'Y': set()}
        for i in P.insns.values():
            if i.mn in ('LDX', 'LDY') and i.mode == 'imm':
                mn, ot = operand_text(P.src.text(i.inner['file'], i.inner['line']))
                m = re.match(r'#\s*([A-Za-z_][\w%$]*)\s*-\s*([A-Za-z_][\w%$]*)\s*$', ot or '')
                if m and m.group(1) in code_names and m.group(2) in code_names and i.opnd:
                    offs[i.mn[2]].add(i.opnd)
        self.idx_offsets = offs
        for i in P.insns.values():
            if i.mn not in STORES and i.mn not in RMW:
                continue
            if i.mode in ('zp', 'abs'):
                rng = [i.opnd]
            elif i.mode in ('abx', 'aby'):
                if not P.cover.get(i.opnd):
                    continue
                if self._indexes_data(i):
                    continue
                rng = [i.opnd]
                if any(j.seg == i.seg for j, _ in P.cover.get(i.opnd, ())):
                    rng += [i.opnd + d for d in sorted(offs['X' if i.mode == 'abx' else 'Y'])]
            else:
                continue
            for a in rng:
                if 0x3000 <= a < 0x8000 and i.opname is None:
                    # (Master) main &3000-&7FFF by a bare address: the shadow screen or
                    # shadow &3000 (setzp's `STA &3000,X` with ACCCON X set); code here is
                    # patched only by stores that name its label
                    continue
                for (j, k) in P.cover.get(a, []):
                    if sideways(a):
                        tgt = i.tseg or P.bank_at(i.seg, a)
                        if tgt is not None and j.seg != tgt:
                            continue
                    if a in P.bss.get(j.seg, ()):
                        continue
                    if k == 0:
                        j.volatile = True
                    else:
                        j.opvolatile = True
                    n += 1
        self.smc_count = n
        self.notes.append(f"self-modifying code: {sum(1 for i in P.insns.values() if i.opvolatile)} "
                          f"instructions with patched operands (operand unknown), "
                          f"{sum(1 for i in P.insns.values() if i.volatile)} with patched opcodes (barriers)")

    def _indexes_data(self, i):
        """an indexed store whose base is a few bytes below a data label its operand
        names (`STA SOFLG-1,Y`): it indexes that data, not the code below it"""
        P = self.P
        mn, ot = operand_text(P.src.text(i.inner['file'], i.inner['line']))
        for m in _IDENT.finditer(ot):
            for v, sg in P.lab_by.get(m.group(0), ()):
                if 0 < v - i.opnd <= 3 and (sg, v) not in P.insns:
                    return True
        return False

    # ------------------------------------------------------------ CFG
    def _cross(self):
        """the rasteriser's cross-bank calls: JSR/JMP r_call7 (r_call5) after stores of
        immediates to r_hzt7 / r_hzt7+1 (r_hzt5) in the straight-line code just before:
        {key: target insn}"""
        P = self.P
        out = {}
        self.cross_bad = []
        for stub, (ptr, tseg) in gamecfg.C.CROSS_CALLS.items():
            sa, pa = P.find(stub), P.find(ptr)
            if sa is None or pa is None:
                continue
            for i in P.insns.values():
                if i.mn not in ('JSR', 'JMP') or i.mode != 'abs' or i.opnd != sa:
                    continue
                # walk back in address order (a straight line: no label between)
                lo = hi = None
                imm = {}
                seq = []
                a = i.addr
                for _ in range(16):
                    prev = None
                    for back in (1, 2, 3):
                        c = P.insns.get((i.seg, a - back))
                        if c is not None and c.len == back:
                            prev = c; break
                    if prev is None:
                        break
                    seq.append(prev)
                    if prev.mn in ('JSR', 'JMP', 'RTS', 'RTI') or prev.mode == 'rel':
                        break
                    a = prev.addr
                    if P.code_label.get(prev.key) and a != i.addr:
                        # a label: still fine if the stores are all after it
                        pass
                seq.reverse()
                regs = {}
                for j in seq:
                    if j.mn in ('LDA', 'LDX', 'LDY'):
                        regs[j.mn[2]] = j.opnd if j.mode == 'imm' else None
                    elif j.mn in ('TAX', 'TAY', 'TXA', 'TYA'):
                        regs[j.mn[2]] = regs.get(j.mn[1])
                    elif j.mn in ('STA', 'STX', 'STY') and j.mode in ('zp', 'abs') and j.opnd in (pa, pa + 1):
                        v = regs.get(j.mn[2])
                        if j.opnd == pa:
                            lo = v
                        else:
                            hi = v
                    elif j.mn in ('JSR', 'JMP', 'RTS'):
                        regs = {}; lo = hi = None
                    elif j.mn in ('INX', 'INY', 'DEX', 'DEY'):
                        regs[j.mn[2]] = None
                    elif j.mn in ('PLA', 'PLX', 'PLY'):
                        regs[j.mn[2] if j.mn != 'PLA' else 'A'] = None
                if lo is None or hi is None:
                    self.cross_bad.append(i.key)
                    continue
                tgt = (hi << 8) | lo
                c = [j for j in P.by_addr.get(tgt, []) if j.seg == tseg]
                if not c:
                    self.cross_bad.append(i.key)
                    continue
                out[i.key] = c[0]
        if out or self.cross_bad:
            self.notes.append(f"cross-bank calls: {len(out)} resolved through "
                              f"{', '.join(gamecfg.C.CROSS_CALLS)}; {len(self.cross_bad)} unresolved")
        return out

    def _cfg(self):
        P = self.P
        self.cross = self._cross()
        self.succ = {}        # key -> [(Insn, edge)]  edge: None | ('br', mn, taken)
        self.unk = set()      # keys with an unresolvable exit (everything live)
        self.call = {}        # key of JSR -> callee Insn or None
        self.helper = {}      # key of JSR -> helper tuple
        self.pred = collections.defaultdict(list)
        self.unk_edge = {}    # branch key -> [taken?] edges that lead nowhere
        self.mos = set()      # JSR into the MOS (>= MOS_LO): the MOS summary
        self.mosjmp = set()   # JMP into the MOS: a tail call (MOS summary, then RTS)
        MOS_LO = gamecfg.C.MOS_LO
        for i in P.insns.values():
            S = []
            nxt = P.insns.get((i.seg, i.addr + i.len))
            if i.volatile:
                self.unk.add(i.key)
            elif i.mn in ('RTS', 'RTI'):
                pass
            elif i.mn == 'BRK':
                self.unk.add(i.key)
            elif i.mn == 'JMP' and i.key in self.cross:
                S.append((self.cross[i.key], None))
            elif i.mn == 'JMP':
                if i.mode == 'abs' and not i.opvolatile:
                    ts = P.resolve_all(i.opnd, i.seg, i)
                    if not ts and MOS_LO is not None and i.opnd >= MOS_LO:
                        self.mosjmp.add(i.key)
                    elif not ts:
                        self.unk.add(i.key)
                    for t in ts:
                        S.append((t, None))
                else:
                    self.unk.add(i.key)
            elif i.mode == 'rel':
                t = P.resolve(i.opnd, i.seg, i)
                if t is None:
                    self.unk.add(i.key); self.unk_edge.setdefault(i.key, []).append(True)
                else:
                    S.append((t, ('br', i.mn, True)))
                if i.mn != 'BRA':
                    if nxt is None:
                        self.unk.add(i.key); self.unk_edge.setdefault(i.key, []).append(False)
                    else:
                        S.append((nxt, ('br', i.mn, False)))
            elif i.mn == 'JSR':
                ts = [] if i.opvolatile else P.resolve_all(i.opnd, i.seg, i)
                if i.key in self.cross:
                    ts = [self.cross[i.key]]
                if i.key in self.far:
                    ts = [self.far[i.key]]
                if not ts and not i.opvolatile and MOS_LO is not None and i.opnd >= MOS_LO:
                    self.mos.add(i.key)
                self.call[i.key] = ts
                h = self._helper_ops(i)
                if h:
                    self.helper[i.key] = h
                    nxt = P.insns.get((i.seg, i.addr + 3 + len(h[1])))
                if nxt is None:
                    self.unk.add(i.key)
                else:
                    S.append((nxt, None))
            else:
                if nxt is None:
                    self.unk.add(i.key)
                else:
                    S.append((nxt, None))
            self.succ[i.key] = S
            for (t, e) in S:
                self.pred[t.key].append((i, e))

    # ------------------------------------------------------------ entries
    def _entries(self):
        """Routine entries and how each is entered.  Address-taken (from the source
        text, BeebAsm keeping no references): a code label named in an immediate
        operand (#LO(x), #HI(x-1)), in a data statement (EQUW x, EQUB LO(x)), or in a
        macro invocation's arguments; also EQUW data equal to a code address (+1)."""
        P = self.P
        self.jsr_sites = collections.defaultdict(list)   # callee key -> [JSR Insn]
        for k, ts in self.call.items():
            for t in ts:
                self.jsr_sites[t.key].append(P.insns[k])
        code_lab = collections.defaultdict(list)        # name -> [insn key]
        for k, labs in P.code_label.items():
            for s in labs:
                code_lab[s['name']].append(k)
        taken = {}
        def idents(txt):
            for m in _IDENT.finditer(txt):
                nm = m.group(0)
                if nm.upper() not in _FUNCS and nm in code_lab:
                    yield nm
        seen_lines = set()
        for i in P.insns.values():
            mn, ot = operand_text(P.src.text(i.inner['file'], i.inner['line']))
            if '#' in ot:
                for nm in idents(ot[ot.index('#'):]):
                    for k in code_lab[nm]:
                        taken.setdefault(k, f"{nm} immediate at {i.inner['file']}:{i.inner['line']}")
            if i.inner != i.outer:
                key = (i.outer['file'], i.outer['line'])
                if key not in seen_lines:
                    seen_lines.add(key)
                    txt = strip_comment(P.src.text(*key) or '')
                    m = re.match(r'\s*(?:\.[\w%$]+\s+)?([A-Za-z_]\w*)\s+(.*)$', txt)
                    if m:
                        for nm in idents(m.group(2)):
                            for k in code_lab[nm]:
                                taken.setdefault(k, f"{nm} macro argument at {key[0]}:{key[1]}")
        addrs = set(P.by_addr)
        for seg, recs in P.datarec.items():
            sg = P.segs[seg]
            for a, (kind, n, f, l, sf, sl) in recs.items():
                if kind != 'D' or (seg, a) in self.far_ops:
                    continue          # (a far call's EQUW target: a resolved call)
                key = (f, l)
                txt = strip_comment(P.src.text(f, l) or '')
                if key not in seen_lines:
                    seen_lines.add(key)
                    for nm in idents(txt):
                        for k in code_lab[nm]:
                            taken.setdefault(k, f"{nm} data at {f}:{l}")
                if re.search(r'\bEQUW\b', txt, re.I) and sg['data'] is not None and n >= 2:
                    d = sg['data']
                    for o in range(a - sg['start'], a - sg['start'] + n - 1, 2):
                        w = d[o] | (d[o + 1] << 8)
                        for x in (w, w + 1):
                            if x in addrs:
                                for j in P.by_addr[x]:
                                    if not sideways(x) or j.seg == (P.bank_at(seg, x) or j.seg) or seg == j.seg:
                                        taken.setdefault(j.key, f"EQUW ${w:04X} at {f}:{l}")
        # the far-call helpers (far7, far4, ...): entered by the far calls, whose call
        # edges go to their targets instead -- entries with an unknown caller
        for nm in gamecfg.C.FAR_CALLS:
            a_ = P.find(nm)
            for j in P.by_addr.get(a_, []) if a_ is not None else ():
                if j.seg not in model_sideways_segs():
                    taken.setdefault(j.key, f"far-call helper {nm} (entered by the far calls)")
        self.taken = taken
        self.entries = {}
        for i in P.insns.values():
            k = i.key
            kinds = []
            if k in self.jsr_sites:
                kinds.append('jsr')
            if k in taken:
                kinds.append('taken')
            if not self.pred.get(k) and k not in self.jsr_sites:
                kinds.append('orphan')
            if kinds:
                self.entries[k] = kinds

    def _refs(self, s, depth=0):
        """A symbol's reference lines, following equates that alias it."""
        out = list(s['refs'])
        if depth > 4:
            return out
        for t in self.P.syms:
            if t is not s and t['type'] == 'equ' and t['val'] == s['val']:
                out += self._refs(t, depth + 1)
        return out

    def _contexts(self):
        """Entry contexts: which entries' bodies contain each instruction (an
        instruction in no entry's body has the unknown context None)."""
        self.ctx = collections.defaultdict(set)
        for ek in self.entries:
            for k in self.body(ek):
                self.ctx[k].add(ek)
        for k in self.P.insns:
            if k not in self.ctx:
                self.ctx[k].add(None)

    def _ref_kind(self, rec, val):
        """None if every instruction on the referencing line uses val only as a direct
        JSR/JMP/branch target; else why the label counts as address-taken."""
        P = self.P
        direct = False
        lo, hi = val & 0xFF, val >> 8
        for sp in rec['spans']:
            seg, off, size = P.spans[sp]
            sg = P.segs[seg]
            if sg['data'] is None:
                return 'a non-code use'
            a0 = sg['start'] + off
            a = a0
            while a < a0 + size:
                i = P.insns.get((seg, a))
                if i is None:
                    if sg['data'][a - sg['start']] in (lo, hi, (val - 1) & 0xFF, (val - 1) >> 8):
                        return 'data byte'
                    a += 1
                    continue
                if i.mn in ('JSR', 'JMP') and i.mode == 'abs' or i.mode == 'rel':
                    if i.opnd == val:
                        direct = True
                elif i.opnd is not None and i.len > 1:
                    if i.len == 3 and i.opnd in (val, val - 1, val + 1, val + 2):
                        return f'operand of {i.mn}'
                    if i.len == 2 and i.mode == 'imm' and i.opnd in (lo, hi, (val - 1) & 0xFF,
                                                                     (val - 1) >> 8):
                        return f'immediate of {i.mn}'
                a += i.len
        return None if direct else 'non-transfer use'

    # ------------------------------------------------------------ bodies
    def body(self, ek):
        """Instructions reachable from entry ek without crossing a JSR's callee."""
        bc = self.__dict__.setdefault('_body_cache', {})
        r = bc.get(ek)
        if r is not None and bc.get('_n') == len(self.succ):
            return r
        if bc.get('_n') != len(self.succ):
            bc.clear(); bc['_n'] = len(self.succ)
        r = bc[ek] = frozenset(self._body(ek))
        return r

    def _body(self, ek):
        seen = set([ek]); st = [ek]
        while st:
            k = st.pop()
            for (t, e) in self.succ[k]:
                if t.key not in seen:
                    seen.add(t.key); st.append(t.key)
        return seen

    def _isr(self):
        P = self.P
        roots = []
        for s in P.syms:
            if s['name'] in self.isr_names:
                for i in P.by_addr.get(s['val'], []):
                    if i.seg == s['seg']:
                        roots.append(i.key)
        self.isr_roots = roots
        seen = set(); st = list(roots); calls_unknown = False
        exits = {P.find(n) for n in gamecfg.C.ISR_EXITS} - {None}
        self.isr_exit_ok = set()
        while st:
            k = st.pop()
            if k in seen:
                continue
            seen.add(k)
            ii = P.insns[k]
            if k in self.unk and ii.mn == 'JMP' and ii.mode == 'ind' and ii.opnd in exits:
                self.isr_exit_ok.add(k)       # into the MOS: no game memory
            elif k in self.unk:
                calls_unknown = True
            for (t, e) in self.succ[k]:
                st.append(t.key)
            if k in self.call:
                ts = self.call[k]
                if not ts:
                    calls_unknown = True
                for t in ts:
                    st.append(t.key)
        self.isr_code = seen
        r = w = 0
        dptr = set()
        if not self.strict_isr:
            for s in P.syms:
                if s['name'].lower().replace('_', '') in \
                        {n.lower().replace('_', '') for n in gamecfg.C.ISR_DATA_POINTERS}:
                    dptr.add(s['val'])
        for k in seen:
            i = P.insns[k]
            rr, ww = self._mem_rw(i)
            if i.mode in ('inx', 'iny', 'zpi') and i.opnd in dptr and i.mn not in STORES \
                    and i.mn not in RMW:
                rr = self.mb(i.opnd) | self.mb((i.opnd + 1) & 0xFF)
            r |= rr; w |= ww
        for nm in gamecfg.C.ISR_EXTRA_WRITES:
            a_ = P.find(nm) if isinstance(nm, str) else nm
            if a_ is not None:
                w |= self.mb(a_)
        if calls_unknown or not roots:
            self.notes.append("interrupt: an unresolved exit (or no root found) -- "
                              "it is taken to read and write all memory")
            r = w = self.MALL
        self.isr_r, self.isr_w = r, w
        self.notes.append(f"interrupt roots {[P.disasm(P.insns[k]) and P.code_label[k][0]['name'] for k in roots]}: "
                          f"{len(seen)} instructions, reads {bin(r).count('1')} and writes "
                          f"{bin(w).count('1')} universe bytes")

    def _mem_rw(self, i):
        """(may-read bits, may-write bits) of one instruction's memory access."""
        mn, mode, o = i.mn, i.mode, i.opnd
        r = w = 0
        if i.opvolatile and mode in ('abs', 'abx', 'aby', 'zp', 'zpx', 'zpy'):
            acc = self.MALL
        elif mode in ('zp', 'abs'):
            acc = self.mb(o)
        elif mode in ('zpx', 'zpy'):
            acc = self.ZPALL
        elif mode in ('abx', 'aby'):
            acc = self.mbits(o, 256)
        elif mode in ('inx', 'iny', 'zpi'):
            ptr = self.mb(o) | self.mb((o + 1) & 0xFF)
            if mn in STORES:
                return ptr, self.MALL
            if mn in RMW:
                return ptr | self.MALL, self.MALL
            return ptr | self.MALL, 0
        elif mode in ('ind', 'iax'):
            return self.mbits(o, 2) if mode == 'ind' else self.MALL, 0
        else:
            return 0, 0
        if mn in STORES:
            w = acc
        elif mn in RMW:
            r = w = acc
        elif mn in READS_MEM:
            r = acc
        return r, w

    # ------------------------------------------------------------ local effects
    def effects(self, i):
        """(use, def_must, may_def_regs, mem_read, mem_write_must, mem_write_may, side)"""
        mn, mode = i.mn, i.mode
        use = d = 0
        if mode in ('zpx', 'abx', 'inx', 'iax'):
            use |= X
        if mode in ('zpy', 'aby', 'iny'):
            use |= Y
        if mn in ('LDA', 'PLA', 'TXA', 'TYA'):
            d |= A
        elif mn in ('LDX', 'TAX', 'TSX', 'PLX'):
            d |= X
        elif mn in ('LDY', 'TAY', 'PLY'):
            d |= Y
        if mn in ('STA', 'TAX', 'TAY', 'PHA', 'CMP', 'BIT', 'TSB', 'TRB'):
            use |= A
        if mn in ('STX', 'TXA', 'TXS', 'CPX', 'PHX'):
            use |= X
        if mn in ('STY', 'TYA', 'CPY', 'PHY'):
            use |= Y
        if mn in ('INX', 'DEX'):
            use |= X; d |= X
        if mn in ('INY', 'DEY'):
            use |= Y; d |= Y
        if mn in ('ADC', 'SBC', 'AND', 'ORA', 'EOR'):
            use |= A; d |= A
        if mn in ('ADC', 'SBC', 'ROL', 'ROR'):
            use |= C
        if mn in ('ASL', 'LSR', 'ROL', 'ROR', 'INC', 'DEC') and mode == 'acc':
            use |= A; d |= A
        if mn in ZNSET:
            d |= N | Z
        if mn in ('ADC', 'SBC'):
            d |= C | V
        if mn in ('ASL', 'LSR', 'ROL', 'ROR', 'CMP', 'CPX', 'CPY', 'CLC', 'SEC'):
            d |= C
        if mn == 'BIT':
            d |= Z if mode == 'imm' else (N | Z | V)
        if mn in ('TSB', 'TRB'):
            d |= Z
        if mn == 'CLV':
            d |= V
        if mn == 'PLP':
            d |= FLAGS
        if mn == 'PHP':
            use |= FLAGS
        if mode == 'rel' and mn != 'BRA':
            use |= {'BPL': N, 'BMI': N, 'BVC': V, 'BVS': V, 'BCC': C, 'BCS': C,
                    'BNE': Z, 'BEQ': Z}[mn]
        r, w = self._mem_rw(i)
        wmust = 0
        if mode in ('zp', 'abs') and (mn in STORES or mn in RMW) and not i.opvolatile:
            wmust = w
        side = False
        o = i.opnd
        if mode in ('zp', 'abs', 'abx', 'aby') and o is not None and \
                mn not in ('JSR', 'JMP') and (IO_LO <= o <= IO_HI or
                                              (mode in ('abx', 'aby') and o < IO_LO <= o + 255)):
            side = True                      # I/O: reads and writes both act
        if mode in ('zp', 'abs') and o is not None and STACK_LO <= o <= STACK_HI:
            side = True
        if mn in ('PHA', 'PHP', 'PHX', 'PHY', 'PLA', 'PLP', 'PLX', 'PLY', 'TXS', 'SEI', 'CLI',
                  'SED', 'CLD', 'BRK', 'RTI', 'RTS', 'JSR', 'JMP', 'NOP'):
            side = True
        if mode in ('inx', 'iny', 'zpi', 'abx', 'aby', 'zpx', 'zpy') and (mn in STORES or mn in RMW):
            side = True                      # an indexed/indirect write: never "dead"
        if i.volatile or i.opvolatile:
            side = True
        return use, d, d, r, wmust, w, side

    # ------------------------------------------------------------ summaries
    def _summaries(self):
        """Per JSR target: use (live-in with nothing live at RTS), must-def regs,
        may-def regs, may-read mem, may-write mem, and 'ok' (analysable)."""
        P = self.P
        targets = list(self.jsr_sites)
        self.bodies = {}
        ok = {}
        for t in targets:
            b = self.body(t)
            self.bodies[t] = b
            why = None
            push = pull = 0
            for k in b:
                i = P.insns[k]
                if k in self.unk:
                    why = f"unresolved exit at {P.where(i)} ({P.disasm(i)})"; break
                if i.mn in ('TSX', 'TXS', 'RTI', 'BRK'):
                    why = f"{i.mn} at {P.where(i)}"; break
                if i.mn in ('PHA', 'PHP', 'PHX', 'PHY'):
                    push += 1
                if i.mn in ('PLA', 'PLP', 'PLX', 'PLY'):
                    pull += 1
            if why is None and push != pull:
                why = f"pushes {push} != pulls {pull} (stack games)"
            ok[t] = why
        self.sum_why = ok
        # fixpoint: unknown callee => all
        S = {t: dict(use=0, mustdef=RF, maydef=0, mr=0, mw=0, io=False) for t in targets}
        BAD = dict(use=self.ALL, mustdef=0, maydef=RF, mr=self.MALL, mw=self.MALL, io=True)
        self.BAD = BAD
        for t in targets:
            if ok[t] is not None:
                S[t] = dict(BAD)
        self.S = S
        for rnd in range(60):
            changed = False
            for t in targets:
                if ok[t] is not None:
                    continue
                new = self._summarise(t)
                if new != S[t]:
                    S[t] = new; changed = True
            if not changed:
                break
        else:
            self.notes.append("summaries did not converge in 60 rounds")
        nb = sum(1 for t in targets if ok[t] is not None)
        self.notes.append(f"{len(targets)} JSR targets: {len(targets)-nb} summarised, {nb} unknown "
                          f"(stack games / unresolved exits)")

    def callee_eff(self, jk):
        """Summary for the JSR at key jk."""
        h = self.helper.get(jk)
        if h:
            name, roles, uses, ops = h
            mr = mw = mwm = 0
            for role, v in zip(roles, ops):
                if role == 'i':
                    continue
                bb = self.mb(v) | self.mb((v + 1) & 0xFF)
                if role in ('rw16', 'r16'):
                    mr |= bb
                if role in ('rw16', 'w16'):
                    mw |= bb; mwm |= bb
            for nm in gamecfg.C.HELPER_SCRATCH:
                for s in self.P.syms:
                    if s['name'] == nm:
                        mw |= self.mbits(s['val'], 2)
            return dict(use=uses, mustdef=A | N | Z | C | V, maydef=A | N | Z | C | V, io=False,
                        mr=mr, mw=mw, mwm=mwm)
        if jk in self.mos or jk in self.mosjmp:
            return self.mos_eff()
        ts = self.call.get(jk)
        if not ts:
            return dict(self.BAD, mwm=0)
        if jk in self.far:
            # a far call: the target's effects plus the far code's (flags and registers
            # pass both ways unchanged; it writes its scratch bytes and ROMSEL)
            s = self.S.get(ts[0].key) or self.BAD
            return dict(use=s['use'], mustdef=s['mustdef'], maydef=s['maydef'],
                        mr=s['mr'], mw=s['mw'] | self.far_scratch(), mwm=0, io=True)
        if jk in self.cross:
            s = self.S.get(ts[0].key) or self.BAD
            ex = 0
            for nm in gamecfg.C.CROSS_SCRATCH:
                a_ = self.P.find(nm)
                if a_ is not None:
                    ex |= self.mb(a_)
            return dict(use=s['use'], mustdef=s['mustdef'] | N | Z, maydef=s['maydef'] | N | Z,
                        mr=s['mr'], mw=s['mw'] | ex, mwm=0, io=True)
        r = None
        for t in ts:
            s = self.S.get(t.key) or self.BAD
            if r is None:
                r = dict(s, mwm=0)
            else:          # several banks' code at the address: any of them
                r = dict(use=r['use'] | s['use'], mustdef=r['mustdef'] & s['mustdef'],
                         maydef=r['maydef'] | s['maydef'], mr=r['mr'] | s['mr'],
                         mw=r['mw'] | s['mw'], mwm=0, io=r['io'] or s['io'])
        return r

    def far_scratch(self):
        b = 0
        for nm in gamecfg.C.FAR_SCRATCH:
            if isinstance(nm, str):
                base, _, off = nm.partition('+')
                a_ = self.P.find(base)
                if a_ is not None:
                    a_ += int(off or 0)
            else:
                a_ = nm
            if a_ is not None:
                b |= self.mb(a_)
        return b

    def mos_eff(self):
        """a MOS call (OSBYTE, OSWORD, OSWRCH...): reads A X Y and any memory (a parameter
        block), may write the registers and flags and I/O, writes no game memory but
        the config's MOS_WRITES (assumption)"""
        w = 0
        for a_ in gamecfg.C.MOS_WRITES:
            w |= self.mb(a_)
        return dict(use=A | X | Y, mustdef=0, maydef=RF, mr=self.MALL, mw=w, mwm=0, io=True)

    def _summarise(self, t):
        P = self.P
        b = self.bodies[t]
        # backward liveness over the body, nothing live at RTS
        live = {k: 0 for k in b}
        order = sorted(b, key=lambda k: -P.insns[k].idx)
        mustdef_in = {}
        maydef = 0; mr = 0; mw = 0; io = False
        for k in b:
            i = P.insns[k]
            if i.mn == 'JSR' or k in self.mosjmp:
                e = self.callee_eff(k)
                maydef |= e['maydef']; mr |= e['mr']; mw |= e['mw']; io = io or e['io']
            else:
                use, d, md, r, wm, w, side = self.effects(i)
                maydef |= md; mr |= r; mw |= w
                io = io or self._io_write(i)
        changed = True
        while changed:
            changed = False
            for k in order:
                i = P.insns[k]
                out = 0
                for (s, e) in self.succ[k]:
                    out |= live.get(s.key, 0)
                new = self._xfer_back(i, out)
                if new != live[k]:
                    live[k] = new; changed = True
        # must-def forward (intersection), greatest fixpoint
        md = {k: RF for k in b}
        md[t] = 0
        changed = True
        fwd = sorted(b, key=lambda k: P.insns[k].idx)
        indeg = collections.defaultdict(list)
        for k in b:
            for (s, e) in self.succ[k]:
                indeg[s.key].append(k)
        res = RF
        while changed:
            changed = False
            for k in fwd:
                if k == t:
                    inn = 0
                else:
                    ps = indeg.get(k, [])
                    inn = RF
                    for p in ps:
                        inn &= self._md_out(P.insns[p], md[p])
                    if not ps:
                        inn = RF
                if k != t and inn != md[k]:
                    md[k] = inn; changed = True
        for k in b:
            if P.insns[k].mn == 'RTS' or k in self.mosjmp:
                res &= md[k]
        return dict(use=live[t] & (RF | self.MALL), mustdef=res, maydef=maydef, mr=mr, mw=mw,
                    io=io)

    def _io_write(self, i):
        o = i.opnd
        return (i.mn in STORES or i.mn in RMW) and o is not None and \
            i.mode in ('abs', 'abx', 'aby') and (IO_LO <= o <= IO_HI or
                                                 (i.mode != 'abs' and o < IO_LO <= o + 255)) \
            or (i.mn in STORES or i.mn in RMW) and i.mode in ('inx', 'iny', 'zpi')

    def _md_out(self, i, inn):
        if i.mn == 'JSR':
            return inn | self.callee_eff(i.key)['mustdef']
        use, d, md, r, wm, w, side = self.effects(i)
        return inn | d

    def _xfer_back(self, i, out):
        """live-in of i given live-out, intraprocedural part (RTS/unk handled by caller)."""
        if i.key in self.unk:
            return self.ALL
        if i.key in self.mosjmp:
            e = self.mos_eff()
            return e['use'] | out | e['mr'] | self.PAGED | self.isr_r
        if i.mn == 'JSR':
            e = self.callee_eff(i.key)
            lin = e['use'] | (out & ~(e['mustdef'] | e['mwm'])) | e['mr']
            # a callee that may write I/O (ROMSEL, ACCCON) may leave another bank
            # paged: then no paged byte is killed across the call
            return lin | (self.PAGED if e['io'] else 0) | self.isr_r
        if i.mn == 'RTI':
            return self.ALL
        use, d, md, r, wm, w, side = self.effects(i)
        lin = (out & ~(d | wm)) | use | r | self.isr_r
        if self._io_write(i):
            lin |= self.PAGED
        return lin

    # ------------------------------------------------------------ global liveness
    def _liveness(self):
        P = self.P
        retlive = {}
        for ek, kinds in self.entries.items():
            retlive[ek] = RF if ('taken' in kinds or 'orphan' in kinds or ek in self.isr_roots) else 0
        retlive[None] = RF
        self.retlive = retlive
        order = sorted(P.insns, key=lambda k: -P.insns[k].idx)
        live_in = {k: 0 for k in P.insns}
        live_out = {k: 0 for k in P.insns}
        for rnd in range(40):
            changed = True
            while changed:
                changed = False
                for k in order:
                    i = P.insns[k]
                    if k in self.unk or i.mn == 'RTI':
                        out = self.ALL
                    elif i.mn == 'RTS' or k in self.mosjmp:
                        out = self.MALL
                        for ek in self.ctx[k]:
                            out |= retlive[ek]
                    else:
                        out = 0
                        for (s, e) in self.succ[k]:
                            out |= live_in[s.key]
                    live_out[k] = out
                    new = self._xfer_back(i, out)
                    if new != live_in[k]:
                        live_in[k] = new; changed = True
            # callers' needs at return
            ch = False
            for ek, sites in self.jsr_sites.items():
                if retlive[ek] == RF:
                    continue
                r = retlive[ek]
                for j in sites:
                    r |= live_out[j.key] & RF
                if r != retlive[ek]:
                    retlive[ek] = r; ch = True
            if not ch:
                break
        self.live_in, self.live_out = live_in, live_out

    def _prune(self):
        from forward import edge_feasible
        n = 0
        self.pruned = []
        for k, edges in self.unk_edge.items():
            st = self.fin.get(k)
            if st is None or k not in self.unk:
                continue
            i = self.P.insns[k]
            if all(not edge_feasible(st, i.mn, tk) for tk in edges):
                self.unk.discard(k); n += 1
                self.pruned.append(k)
        if n:
            self.notes.append(f"{n} branches whose fall-through into data is never taken "
                              f"(flag known): that edge dropped")
        return n

    # ------------------------------------------------------------ forward
    def _forward(self):
        from forward import run_forward
        self.fin, self.fout_edge = run_forward(self)
