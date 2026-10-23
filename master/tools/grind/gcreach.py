#!/usr/bin/env python3
"""gcreach -- provable reachability of the full Master Elite build's code (garbage collection).

    python3 master/tools/grind/gcreach.py [--build DIR] [--out DIR] [--cov FILE...] [--profile FILE]

Reads the build that analyse.py / mkbuild.sh leaves (default scratch/grind/build), models it
with df/model.py and df/analysis.py (CFG with BIT skips, hidden RTSs, far calls, the
rasteriser's cross-bank calls), and computes the instructions reachable from the real
entry points only (unlike the range analysis, which also seeds every instruction with no
known predecessor):

  roots   the loader's calls into the game (S% with SBANK paged, G_INIT), the IRQ (IRQ1)
          and the MOS vectors the game installs (NEWBRK, CHPR), every data statement's
          mentions (tables, EQUW, split LO/HI tables) except a far call's own EQUW, and
          every EQUW word (or word+1) equal to a code address (analysis.taken);
  edges   fall-through, branches, JMP, JSR (and its return), far-call and cross-bank call
          targets; and *every* identifier that a reachable instruction's source line (the
          macro body line and the invocation line) mentions: a code label so named is
          reachable (an immediate #LO/#HI, a patched operand `STA x+1`, a table base ...),
          an equate so named is followed to the labels its definition mentions (and to code
          at its value);
          a resolved JSR/JMP/branch alone on its line reaches only its exact target (so
          `JSR hyp1_C+3` does not keep hyp1_C's first instruction); label+-n reaches that
          address (and the next, for an RTS-pushed address); every copy of an unrolled
          statement (a FOR loop or macro body: R_RUN's 24 row-run pages, entered at
          computed offsets) is reached when one is; an instruction whose opcode is patched
          (volatile) is taken to fall through; a cross-bank call reaches its stub too;
          a BRK reaches NEWBRK.

Everything else is unreachable: no execution from any entry can reach it, as long as the
mentions are complete -- which they are for the assembler: a code address can only get
into the program through a label's name, an expression on a source line, or a literal
(the EQUW scan; the dynamic cross-checks catch the rest).

Outputs (--out, default scratch/gc): dead.json, dead.md (runs of unreachable instructions,
by region and routine); weak.md (reached only through weak edges: EQUW-valued words,
equate values, non-immediate mentions); dataonly.md (reached only through data tables);
dyncheck.txt, the dynamic cross-checks: every PC of the gate profile (--profile, default
scratch/grind/profile.json) and every label of the agentplay campaigns' coverage-cand.json
files (--cov ...; label spans run to the next global label, so a dead fragment just
before live code can show as run) must be reachable.
"""
import os, sys, re, json, collections, argparse
sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'df'))
import gamecfg
gamecfg.load(os.path.join(HERE, 'master_config.py'))
import model, analysis
from model import strip_comment, _IDENT, _FUNCS, sideways

REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
KEYWORDS = {'EQUB', 'EQUW', 'EQUD', 'EQUS', 'SKIP', 'FOR', 'NEXT', 'IF', 'ELIF', 'ELSE', 'ENDIF',
            'MACRO', 'ENDMACRO', 'ORG', 'GUARD', 'ALIGN', 'PRINT', 'ASSERT', 'SAVE', 'CLEAR',
            'INCLUDE', 'INCBIN', 'SKIPTO', 'MAPCHAR', 'TRUE', 'FALSE', 'PAGE', 'CPU', 'STEP',
            'COPYBLOCK', 'PUTFILE', 'PUTBASIC', 'PUTTEXT', 'RANDOMIZE', 'ERROR', 'TIME$',
            'STR$', 'CHR$', 'ASC', 'LEN', 'MID$', 'UPPER$', 'LOWER$', 'STRING$', 'VAL',
            'EVAL', 'P%', 'PI', 'DEG', 'RAD', 'TAN', 'ACS', 'ASN', 'ATN', 'LN', 'LOG', 'EXP',
            'SGN'} | _FUNCS
MNEM = {m.upper() for m in model.MNEMONICS}


FUNCS = {'LO', 'HI', 'SIN', 'COS', 'TAN', 'ACS', 'ASN', 'ATN', 'INT', 'ABS', 'SQR', 'RND', 'LN',
         'LOG', 'EXP', 'SGN', 'DEG', 'RAD', 'LEFT$', 'RIGHT$', 'MID$', 'STR$', 'CHR$', 'ASC', 'LEN',
         'UPPER$', 'LOWER$', 'STRING$', 'VAL', 'EVAL', 'TIME$'}
OPS = {'AND', 'OR', 'EOR', 'DIV', 'MOD', 'NOT', 'TRUE', 'FALSE', 'PI', 'P%', 'STEP', 'TO'}


def idents(txt):
    """identifiers a source line mentions (strings, comments, literals, statement keywords,
    mnemonics, functions and register names dropped; a definition `.name` is no mention)"""
    t = strip_comment(txt or '')
    t = re.sub(r'"[^"]*"', ' ', t)
    t = re.sub(r"'[^']'", ' ', t)
    t = re.sub(r'&[0-9A-Fa-f]+', ' ', t)          # hex literals (&C0DE)
    out = []
    for stmt in t.split(':'):
        st = stmt.strip()
        first = True
        for m in _IDENT.finditer(st):
            nm = m.group(0)
            before = st[:m.start()].rstrip()
            after = st[m.end():].lstrip()
            if before.endswith('.') and before[:-1].strip() == '':
                continue                                  # .label definition
            lead = before == '' or (before.startswith('.') and _IDENT.fullmatch(before[1:].strip() or '-') is not None)
            if lead and (nm.upper() in KEYWORDS or nm.upper() in MNEM):
                continue                                  # a directive or mnemonic
            if nm.upper() in FUNCS and after.startswith('('):
                continue
            if nm.upper() in OPS:
                continue
            if nm.upper() in ('X', 'Y') and (before.endswith(',') or before.endswith(',(') ) and not after[:1].isalnum():
                continue                                  # an index register
            if nm.upper() == 'A' and after == '' and before.upper()[-3:] in MNEM:
                continue                                  # ASL A ...
            if re.match(r'^[0-9]', nm):
                continue
            out.append(nm)
    return out


class GC:
    def __init__(self, build):
        root = REPO
        self.P = P = model.Program(root, build)
        self.an = an = analysis.Analysis(P)
        self.build = build
        # every source line the assembler read (gmap's records and equates)
        self.lines = {}
        for (k, pc, n, f, l, sf, sl, ep) in P.grecs:
            P.src.load(f); P.src.load(sf)
        # code labels by name -> [insn key]; equates by name -> [(val, file, line)]
        self.code_lab = collections.defaultdict(list)
        for k, labs in P.code_label.items():
            for s in labs:
                self.code_lab[s['name']].append(k)
        self.equ = collections.defaultdict(list)
        for name, v, f, l in P.gequs:
            P.src.load(f)
            self.equ[name].append((v, f, l))
        # data label names -> [(seg, addr)] (non-code labels with an image)
        self.data_lab = collections.defaultdict(list)
        for s in P.syms:
            if s['type'] == 'lab' and (s['seg'], s['val']) not in P.insns:
                self.data_lab[s['name']].append((s['seg'], s['val']))
        self.why = {}
        P.lines_insns = collections.defaultdict(set)
        for i in P.insns.values():
            P.lines_insns[(i.outer['file'], i.outer['line'])].add(i.key)
            P.lines_insns[(i.inner['file'], i.inner['line'])].add(i.key)

    # -------------------------------------------------------------- mentions
    def resolve_name(self, nm, ctx=None, depth=0):
        """insn keys a mention of nm may reach (code labels, equates followed)"""
        P = self.P
        out = []
        ks = self.code_lab.get(nm)
        if ks:
            if len(ks) > 1 and ctx is not None:
                # a local label name several scopes share: those whose address relates to
                # the mentioning statement's bytes (operand, LO/HI, +-1), else all
                vals = ctx
                f = [k for k in ks if self._rel(k[1], vals)]
                if f:
                    ks = f
            out += ks
        if nm in self.equ and depth < 6 and not ks:
            for v, f, l in self.equ[nm]:
                for m in idents(self.P.src.text(f, l) or ''):
                    if m != nm:
                        out += self.resolve_name(m, None, depth + 1)
                for j in P.by_addr.get(v, []) if (v >= 0x100 and not getattr(self, 'strict', False)) else []:
                    out.append(j.key)
        return out

    @staticmethod
    def _rel(a, vals):
        for v in vals:
            if v in (a, a - 1, a + 1, a & 0xFF, a >> 8, (a - 1) & 0xFF, (a - 1) >> 8):
                return True
        return False

    def ctx_vals(self, i):
        if i.opnd is None:
            return []
        return [i.opnd]

    def line_mentions(self, f, l):
        return idents(self.P.src.text(f, l) or '')

    # -------------------------------------------------------------- reachability
    def run(self, extra_roots=(), strict=False, data_roots=True):
        self.strict = strict
        P, an = self.P, self.an
        reached = {}
        wl = []

        def mark(k, why):
            if k in P.insns and k not in reached:
                reached[k] = why
                wl.append(k)

        def find_insn(name, seg=None):
            out = []
            for k in self.code_lab.get(name, []):
                if seg is None or k[0] == seg:
                    out.append(k)
            return out

        # roots: the loader (S%, G_INIT), the interrupt and the vectors
        for nm in ('S%', 'G_INIT', 'IRQ1', 'NEWBRK', 'CHPR') + tuple(extra_roots):
            ks = find_insn(nm)
            if not ks and nm in self.equ:
                ks = self.resolve_name(nm)
            if not ks:
                print('root not found:', nm)
            for k in ks:
                mark(k, f'root {nm}')
        # data statements: every mention (except the far calls' own EQUWs, which go with
        # their JSR), and EQUW words equal to code addresses
        skip_data = set()
        for k in an.far_ops:
            skip_data.add(k)
        self.data_root_names = collections.defaultdict(list)
        seen = set()
        for seg, recs in P.datarec.items():
            for a, (kind, n, f, l, sf, sl) in recs.items():
                if kind != 'D' or (seg, a) in skip_data or (seg, a) in P.insns or not data_roots:
                    continue
                for (ff, ll) in ((f, l), (sf, sl)):
                    if (ff, ll) in seen:
                        continue
                    seen.add((ff, ll))
                    for nm in self.line_mentions(ff, ll):
                        for k in self.resolve_name(nm):
                            self.data_root_names[k].append(f'{ff}:{ll}')
                            mark(k, f'data {nm} at {ff}:{ll}')
                    txt = strip_comment(P.src.text(ff, ll) or '')
                    for m in re.finditer(r'([A-Za-z_][\w%$]*)\s*([+-])\s*(\d+)\b', txt):
                        for t in self.code_lab.get(m.group(1), []):
                            v = t[1] + (int(m.group(3)) if m.group(2) == '+' else -int(m.group(3)))
                            for w in (v, v + 1):
                                for j in P.by_addr.get(w, []):
                                    if j.seg == t[0]:
                                        mark(j.key, f'data {m.group(0)} at {ff}:{ll}')
        for k, why in an.taken.items():
            if why.startswith('EQUW') and not strict:
                mark(k, f'taken {why}')
            if why.startswith('far-call helper'):
                mark(k, why)
        newbrk = find_insn('NEWBRK')
        # unrolled code (a FOR loop or macro repeating one statement): entered at a computed
        # offset (the row-run pages' STA abs,X), so reaching one copy reaches every copy
        grp = collections.defaultdict(list)
        for i in P.insns.values():
            grp[(i.seg, i.inner['file'], i.inner['line'], i.outer['file'], i.outer['line'])].append(i.key)
        # and the copies of an unrolled macro body (R_RUN's 24 row-run pages, entered at a
        # computed page) form one group
        big = collections.defaultdict(list)
        for key, g in grp.items():
            if len(g) > 1:
                big[(key[0], key[1], key[2])] += g
        self.group = {k: g for g in big.values() for k in g}
        # propagate
        self.mention_src = collections.defaultdict(set)
        while wl:
            k = wl.pop()
            i = P.insns[k]
            for (t, e) in an.succ.get(k, []):
                mark(t.key, f'flow from {P.where(i)}')
            for t in an.call.get(k, []) or []:
                mark(t.key, f'call from {P.where(i)}')
            if k in an.cross:
                # a cross-bank call: the stub runs too (its target is the call's)
                for t in P.resolve_all(i.opnd, i.seg, i):
                    mark(t.key, f'cross-bank stub from {P.where(i)}')
            if i.volatile or (k in an.unk and i.mn not in ('RTS', 'RTI', 'JMP', 'BRK')):
                nx = P.insns.get((i.seg, i.addr + i.len))
                if nx is not None:
                    mark(nx.key, f'after patched/unresolved {P.where(i)}')
            if i.mn == 'BRK':
                for t in newbrk:
                    mark(t, 'BRK')
            for t in self.group.get(k, ()):
                mark(t, f'unrolled with {P.where(i)}')
            if k in an.far_ops:
                continue
            xfer = (i.mn in ('JSR', 'JMP') and i.mode == 'abs' or i.mode == 'rel') and not i.opvolatile \
                and not i.volatile and k not in an.unk
            ctx = self.ctx_vals(i)
            for (ff, ll) in {(i.inner['file'], i.inner['line']), (i.outer['file'], i.outer['line'])}:
                if strict and i.mode != 'imm' and (ff, ll) == (i.inner['file'], i.inner['line']) \
                        and i.inner == i.outer:
                    continue        # (strict: only an immediate's mention, or a macro's argument)
                if xfer and i.inner == i.outer and len(P.lines_insns.get((ff, ll), ())) == 1:
                    continue        # a resolved transfer, alone on its line: the CFG has its exact target
                for nm in self.line_mentions(ff, ll):
                    for t in self.resolve_name(nm, ctx):
                        self.mention_src[t].add(k)
                        mark(t, f'mention {nm} at {ff}:{ll}')
                # label +- constant (#LO(PLL4F+2), JSR SFS1-2 ...): that address too, and
                # the next (an RTS-pushed address minus one)
                txt = strip_comment(P.src.text(ff, ll) or '')
                for m in re.finditer(r'([A-Za-z_][\w%$]*)\s*([+-])\s*(\d+)\b', txt):
                    for t in self.code_lab.get(m.group(1), []):
                        v = t[1] + (int(m.group(3)) if m.group(2) == '+' else -int(m.group(3)))
                        for w in (v, v + 1):
                            for j in P.by_addr.get(w, []):
                                if j.seg == t[0]:
                                    mark(j.key, f'mention {m.group(0)} at {ff}:{ll}')
        self.reached = reached
        return reached


def region(P, i):
    s = i.seg
    if s == 'main':
        if i.addr < 0x3000:
            return 'main <&3000'
        if i.addr < 0x7000:
            return 'BCODE >=&3000'
        return 'quarter squares and run part 2'
    return {'B4': 'bank 4', 'ANDY': 'ANDY', 'C7A': 'bank 7 cold (&8000-)', 'C7': 'bank 7 cold',
            'R7': 'bank 7 tokens', 'B5': 'bank 5', 'RA': 'ANDY (rasteriser)', 'B6': 'bank 6', 'HZ': 'HAZEL', 'SHF': 'shadow (flare)'}.get(s, s)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--build', default=os.path.join(REPO, 'scratch', 'grind', 'build'))
    ap.add_argument('--out', default=os.path.join(REPO, 'scratch', 'gc'))
    ap.add_argument('--profile', default=os.path.join(REPO, 'scratch', 'grind', 'profile.json'))
    ap.add_argument('--cov', nargs='*', default=[])
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    G = GC(a.build)
    P = G.P
    R = G.run()
    Rfull = dict(R)
    G2 = GC(a.build)
    Rs = G2.run(strict=True)
    weak = [i for i in P.order if i.key in R and (i.seg, i.addr) not in Rs]
    with open(os.path.join(a.out, 'weak.md'), 'w') as fh:
        fh.write('# Reached only through weak edges (EQUW-valued words, equate values, non-immediate mentions)\n\n')
        last = None
        for i in weak:
            r = P.routine_of(i)
            lab = ','.join(s['name'] for s in P.code_label.get(i.key, []))
            fh.write(f"- {i.seg}:{i.addr:04X} {r} {lab} {P.where(i)} `{P.disasm(i)}` <- {R[i.key]}\n")
    print(f'weak-only: {len(weak)} instructions, {sum(i.len for i in weak)} bytes')
    G3 = GC(a.build)
    Rd = G3.run(data_roots=False)
    dw = [i for i in P.order if i.key in R and (i.seg, i.addr) not in Rd]
    with open(os.path.join(a.out, 'dataonly.md'), 'w') as fh:
        for i in dw:
            lab = ','.join(s['name'] for s in P.code_label.get(i.key, []))
            if lab or 'data' in R[i.key]:
                fh.write(f"- {i.seg}:{i.addr:04X} {P.routine_of(i)} {lab} {P.where(i)} `{P.disasm(i)}` <- {R[i.key]}\n")
    print(f'data-only: {len(dw)} instructions, {sum(i.len for i in dw)} bytes')
    dead = [i for i in P.order if i.key not in R]
    print(f"{len(P.order)} instructions, {len(R)} reachable, {len(dead)} unreachable "
          f"({sum(i.len for i in dead)} bytes)")
    # runs of consecutive unreachable instructions (data between them joins a run only if
    # it is not referenced... we keep instructions only)
    runs = []
    cur = None
    for i in P.order:
        if i.key in R:
            cur = None
            continue
        if cur and cur['seg'] == i.seg and cur['end'] == i.addr:
            cur['insns'].append(i); cur['end'] = i.addr + i.len
        else:
            # allow a gap of data bytes between unreachable instructions of the same routine
            cur = dict(seg=i.seg, start=i.addr, end=i.addr + i.len, insns=[i])
            runs.append(cur)
    out = []
    for r in runs:
        i0 = r['insns'][0]
        labs = []
        for i in r['insns']:
            lb = [s['name'] for s in P.code_label.get(i.key, [])]
            labs += lb
        prev = P.insns.get((i0.seg, i0.addr - 1)) or P.insns.get((i0.seg, i0.addr - 2)) or P.insns.get((i0.seg, i0.addr - 3))
        out.append(dict(seg=r['seg'], region=region(P, i0), start=f"{r['start']:04X}", end=f"{r['end']:04X}",
                        bytes=sum(i.len for i in r['insns']), n=len(r['insns']),
                        routine=P.routine_of(i0), labels=labs,
                        file=i0.outer['file'], line=i0.outer['line'],
                        lastline=r['insns'][-1].outer['line'],
                        first=P.disasm(i0), text=P.text(i0).strip()[:80],
                        pseudo=all(getattr(i, 'skip', False) for i in r['insns'])))
    json.dump(out, open(os.path.join(a.out, 'dead.json'), 'w'), indent=1)
    with open(os.path.join(a.out, 'dead.md'), 'w') as fh:
        tot = collections.Counter()
        for o in out:
            tot[o['region']] += o['bytes']
        fh.write('# Unreachable instruction runs\n\n')
        for k, v in sorted(tot.items()):
            fh.write(f'- {k}: {v} bytes\n')
        fh.write('\n')
        for o in out:
            fh.write(f"- {o['region']} {o['seg']}:{o['start']}-{o['end']} {o['bytes']}B {o['n']}i "
                     f"routine {o['routine']} labels {','.join(o['labels'])} "
                     f"{o['file']}:{o['line']}-{o['lastline']} `{o['first']}`{' PSEUDO' if o['pseudo'] else ''}\n")
    # dynamic cross-checks
    bad = []
    if os.path.exists(a.profile):
        pj = json.load(open(a.profile))
        keys = set()
        def walk(x):
            if isinstance(x, dict):
                for k2, v2 in x.items():
                    if isinstance(k2, str) and re.match(r'^(M|A|B[4-7]|HZ):[0-9A-Fa-f]{4}$', k2):
                        keys.add(k2)
                    walk(v2)
            elif isinstance(x, list):
                for v2 in x:
                    walk(v2)
        walk(pj)
        nexec = 0
        for kk in keys:
            m, pc = kk.split(':'); pc = int(pc, 16)
            for s in [model.profile_seg(m, pc)]:
                i = P.insns.get((s, pc))
                if i is not None:
                    nexec += 1
                    if i.key not in R:
                        bad.append(f'profile {kk} {P.where(i)} {P.disasm(i)}')
            if m == 'M' and 0x3000 <= pc < 0x8000:
                i = P.insns.get(('SHF', pc))
                if i is not None and i.key not in R:
                    bad.append(f'profile {kk} (flare) {P.where(i)}')
        print(f'profile: {len(keys)} PCs, {nexec} matched instructions')
    if a.cov:
        names = set()
        for f in a.cov:
            names |= set(json.load(open(f))['reached'])
        dl = set()
        for i in dead:
            for s in P.code_label.get(i.key, []):
                dl.add(s['name'])
        for n in sorted(names & dl):
            bad.append(f'coverage: label {n} ran but is unreachable')
        print(f'coverage: {len(names)} labels ran')
    with open(os.path.join(a.out, 'dyncheck.txt'), 'w') as fh:
        fh.write('\n'.join(bad) + '\n')
    print(f'dynamic cross-check: {len(bad)} executed-but-unreachable')
    for b in bad[:40]:
        print(' ', b)


if __name__ == '__main__':
    main()
