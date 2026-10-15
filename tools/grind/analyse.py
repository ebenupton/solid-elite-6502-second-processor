#!/usr/bin/env python3
"""analyse -- static analysis of the Elite port for the micro-optimisation grind.

    python3 tools/grind/analyse.py [--root DIR] [--build DIR] [--out DIR]
                                   [--no-build] [--no-ranges] [--budget N]

1. builds <root> (default: the grind worktree /Users/ebenupton/elite-grind, else this
   repo) in a private copy with the provenance-recording BeebAsm (mkbuild.sh -> --build,
   default scratch/grind/build);
2. models the program (df/model.py: segments main/B4/HZ/B5/B6/B7, instructions with
   their source file:line, data, labels, equates);
3. runs the beebgame dataflow analyses adapted to it (df/analysis.py: CFG, routine
   summaries, liveness of A X Y N Z C V and of memory; df/forward.py: constants;
   df/ranges.py: value ranges by abstract interpretation; df/findings.py: mechanical
   byte-saving findings);
4. writes (--out, default scratch/grind):
     insns.json          one record per instruction (below)
     annotated/<f>.txt   each source file, line for line, code lines prefixed with
                         their annotation (see README)
     findings.md/json    dataflow.py's cycle-neutral findings
     summary.md          model notes, assumptions, unresolved exits, coverage

insns.json: {"meta": {...}, "insns": [{seg, addr, file, line, mfile?, mline?, text,
  disasm, bytes, cycles, cycles_extra, routine, label, live_in, live_out, known,
  ranges: {A, X, Y, C, Z, N, V, eq: {reg: mem}, mem, branch}, pseudo?}]}
"""
import os, sys, json, time, argparse, collections, subprocess
sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'df'))
import gamecfg
gamecfg.load(os.path.join(HERE, 'elite_config.py'))
import model, analysis, ranges, findings, dom
from analysis import rf_str, RF
from ranges import collapse, vjoin, vfmt

REPO = os.path.dirname(os.path.dirname(HERE))

# the range analysis's knobs (df/ranges.py; the environment overrides): beebgame's defaults
# (150, 64, 400, 1024) take ~4x as long on Elite for little the grind uses
RANGES_DEFAULTS = dict(RANGES_CLONE_MAX='40', RANGES_PARTS='16', RANGES_VISITS='60',
                       RANGES_PTR_READ_MAX='16')
for _k, _v in RANGES_DEFAULTS.items():
    os.environ.setdefault(_k, _v)
WT = '/Users/ebenupton/elite-grind'


def log(*a):
    print(*a, flush=True)


def run_ranges(P, an, notes, budget=None):
    sc = {P.find(n) for n in gamecfg.C.SCREEN_POINTERS} - {None}
    hints = dict(op=None, O_TYPE=None, screen_ptrs=sc, soa=False)
    mos = gamecfg.C.MOS_LO
    ext = lambda a: frozenset() if (mos is not None and a >= mos) else None

    def make():
        r = ranges.Ranges(P, an, [0], objst=None, iread={}, notes=notes, hints=hints, external=ext)
        if budget:
            r.budget = budget
        return r
    R = ranges.run_phased(make, an, [0], notes, 'ranges')
    R.converged = not R.exhausted
    if R.exhausted:
        notes.append(f"WARNING: the step budget ({R.budget:,}) ran out: the range states are NOT sound")
    return R


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', default=WT if os.path.isdir(WT) else REPO)
    ap.add_argument('--build', default=os.path.join(REPO, 'scratch', 'grind', 'build'))
    ap.add_argument('--out', default=os.path.join(REPO, 'scratch', 'grind'))
    ap.add_argument('--no-build', action='store_true')
    ap.add_argument('--no-ranges', action='store_true')
    ap.add_argument('--budget', type=int, default=None)
    a = ap.parse_args()
    T = {}
    t0 = time.time()
    if not a.no_build:
        subprocess.run(['sh', os.path.join(HERE, 'mkbuild.sh'), a.root, a.build], check=True)
    T['build'] = time.time() - t0
    t = time.time()
    P = model.Program(a.root, a.build)
    an = analysis.Analysis(P)
    T['liveness'] = time.time() - t
    log(f"model+liveness: {len(P.insns)} instructions, {T['liveness']:.1f}s")
    t = time.time()
    F = findings.find(an)
    T['findings'] = time.time() - t
    R = None
    rnotes = []
    if not a.no_ranges:
        t = time.time()
        R = run_ranges(P, an, rnotes, a.budget)
        T['ranges'] = time.time() - t
        log(f"ranges: {len(R.reached)} reached, {R.steps} steps, {T['ranges']:.1f}s")
    t = time.time()
    write_all(a, P, an, F, R, rnotes, T)
    T['write'] = time.time() - t
    T['total'] = time.time() - t0
    log('timings: ' + ', '.join(f"{k} {v:.1f}s" for k, v in T.items()))


# ---------------------------------------------------------------- per instruction
def range_rows(P, R):
    """insn key -> (joined state, [states]) over every analysis node"""
    by, nodes = {}, collections.defaultdict(list)
    for (proc, k, part), st in R.IN.items():
        nodes[k].append(st)
        if k in by:
            by[k], _ = R.join_into(by[k], st)
        else:
            by[k] = st.clone()
    return by, nodes


def operand_value(R, i, sts):
    v = None
    for st in sts:
        try:
            x = R.read_operand(st, i)
        except Exception:
            x = dom.TOP
        v = vjoin(v, x)
    return v


def rstate(P, R, by, nodes, i):
    """the ranges part of an instruction's record (None: never reached)"""
    st = by.get(i.key)
    if st is None:
        return None
    out = {}
    for r in 'AXY':
        out[r] = vfmt(st.r[r])
    for fl in 'CZNV':
        v = st.f[fl]
        out[fl] = '?' if v is None else str(v)
    eq = {r: P.name(m, i.seg) for r, m in st.mir.items()}
    if eq:
        out['eq'] = eq
    if i.mode not in ('imp', 'acc', 'imm', 'rel') and i.mn not in ('JSR', 'JMP'):
        out['mem'] = vfmt(operand_value(R, i, nodes[i.key]))
    if i.mode == 'rel' and i.mn != 'BRA':
        ok_t = any(R.branch(s, i, True) is not None for s in nodes[i.key])
        ok_f = any(R.branch(s, i, False) is not None for s in nodes[i.key])
        if not ok_t:
            out['branch'] = 'never'
        elif not ok_f:
            out['branch'] = 'always'
    return out


def ann_text(rec):
    """the one-line annotation of an instruction record"""
    p = [f"in:{rec['live_in']} out:{rec['live_out']}"]
    rg = rec.get('ranges')
    if rg is None:
        p.append('UNREACHED' if rec.get('ranges_run') else f"k:{rec['known']}")
    else:
        eq = rg.get('eq', {})
        regs = ' '.join(f"{r}={rg[r]}" + (f"≡{eq[r]}" if r in eq else '') for r in 'AXY')
        fl = ''.join(f"{f}{rg[f]}" for f in 'CZNV')
        s = f"{regs} {fl}"
        if 'mem' in rg:
            s += f" [{rec['opname'] or 'mem'}]={rg['mem']}"
        if 'branch' in rg:
            s += f" {rg['branch'].upper()}"
        p.append(s)
    return ' | '.join(p)


def write_all(a, P, an, F, R, rnotes, T):
    out = a.out
    os.makedirs(os.path.join(out, 'annotated'), exist_ok=True)
    by, nodes = (range_rows(P, R) if R is not None else ({}, {}))
    recs = []
    for i in P.order:
        c, cx = model.cycles(i.mn, i.mode)
        rec = dict(seg=i.seg, addr=f"{i.addr:04X}", file=i.outer['file'], line=i.outer['line'],
                   text=P.text(i).strip(), disasm=P.disasm(i), bytes=i.bytes.hex().upper(),
                   len=i.len, mn=i.mn, mode=i.mode, opname=i.opname,
                   cycles=c, cycles_extra=cx, routine=P.routine_of(i), label=P.label_of(i),
                   live_in=rf_str(an.live_in[i.key] & RF), live_out=rf_str(an.live_out[i.key] & RF),
                   known=findings.known_str(P, an.fin.get(i.key)))
        if i.inner != i.outer:
            rec['mfile'] = i.inner['file']; rec['mline'] = i.inner['line']
            rec['mtext'] = P.text(i, inner=True).strip()
        if getattr(i, 'skip', False):
            rec['pseudo'] = True        # an EQUB &2C BIT-skip or a hidden RTS
        if i.opvolatile:
            rec['smc'] = 'operand'
        if i.volatile:
            rec['smc'] = 'opcode'
        if i.key in an.entries:
            rec['entry'] = an.entries[i.key]
        # transfer targets ("seg:ADDR"): JSR callees, JMP / taken-branch destinations
        tg = []
        if i.mn == 'JSR':
            tg = [t_.key for t_ in an.call.get(i.key) or []]
        elif i.mn == 'JMP' or i.mode == 'rel':
            tg = [t_.key for (t_, e) in an.succ.get(i.key, []) if e is None or e[2]]
        if tg:
            rec['targets'] = [f"{s}:{a_:04X}" for s, a_ in tg]
        elif i.mn in ('JSR', 'JMP') or i.mode == 'rel':
            rec['targets'] = []      # unresolved (indirect, MOS, patched)
        if R is not None:
            rec['ranges_run'] = True
            rec['ranges'] = rstate(P, R, by, nodes, i)
        rec['ann'] = ann_text(rec)
        recs.append(rec)
    meta = dict(root=a.root, build=a.build, n=len(recs), notes=an.notes + rnotes,
                timings=T, ranges=R is not None,
                ranges_sound=bool(R is not None and getattr(R, 'converged', False)),
                head=_git_head(a.root))
    with open(os.path.join(out, 'insns.json'), 'w') as fh:
        json.dump(dict(meta=meta, insns=recs), fh)
    # annotated sources
    byline = collections.defaultdict(lambda: collections.defaultdict(list))
    for r in recs:
        byline[r['file']][r['line']].append(r)
    W = 64
    for fid, lines in byline.items():
        text = P.src.lines.get(fid)
        if text is None:
            continue
        o = []
        if text and text[-1] == '':
            text = text[:-1]          # (the file's final newline)
        for n, t in enumerate(text, 1):
            t = t.rstrip('\r')
            rs = lines.get(n)
            if not rs:
                o.append(' ' * W + ' | ' + t if t.strip() else '')
                continue
            if len(rs) == 1:
                ann = rs[0]['ann']
            elif len(rs) <= 4:
                ann = ' ‖ '.join(f"[{r['disasm']}] {r['ann']}" for r in rs)
            else:
                # a FOR loop / macro expanding to many instructions: the first and a count
                ann = f"[x{len(rs)}: {rs[0]['disasm']} ...] {rs[0]['ann']}"
            o.append(f"{ann:<{W}} | {t}")
        with open(os.path.join(out, 'annotated', os.path.basename(fid) + '.txt'), 'w') as fh:
            fh.write('\n'.join(o) + '\n')
    # findings
    F.sort(key=lambda f: (-f['bytes'], f['file'], f['line']))
    with open(os.path.join(out, 'findings.json'), 'w') as fh:
        json.dump(F, fh, indent=1)
    with open(os.path.join(out, 'findings.md'), 'w') as fh:
        fh.write('# Dataflow findings (tools/grind, beebgame dataflow.py rules)\n\n'
                 'Each holds on every modelled path (see README: model/assumptions); '
                 'each is a candidate to check and gate.\n\n')
        for f in F:
            fh.write(f"- **{f['cat']}** {f['file']}:{f['line']} `{f['insn']}` (-{f['bytes']} B, "
                     f"-{f['cycles']} cyc) in {f['routine']}: {f['detail']}  \n  evidence: {f['evidence']}\n")
    # summary
    with open(os.path.join(out, 'summary.md'), 'w') as fh:
        fh.write(f"# Grind analysis summary\n\nroot {a.root} ({meta['head']}), build {a.build}\n\n")
        segc = collections.Counter(r['seg'] for r in recs)
        segb = collections.Counter()
        for r in recs:
            segb[r['seg']] += r['len']
        fh.write('| segment | instructions | code bytes |\n|---|---:|---:|\n')
        for s in ('main', 'B4', 'HZ', 'B5', 'B6', 'B7'):
            if segc[s]:
                fh.write(f"| {s} | {segc[s]} | {segb[s]} |\n")
        fh.write('\n## Model notes\n\n' + ''.join(f'- {n}\n' for n in an.notes + rnotes))
        fh.write('\n## Unresolved exits (everything live there; the range analysis stops)\n\n')
        for k in sorted(an.unk, key=lambda k: P.insns[k].idx):
            i = P.insns[k]
            fh.write(f"- {P.where(i)} `{P.disasm(i)}` ({P.routine_of(i)})\n")
        fh.write('\n## Routines whose summary is unknown (callers assume they read and clobber everything)\n\n')
        for k, w in sorted(an.sum_why.items(), key=lambda kv: P.insns[kv[0]].idx):
            if w:
                fh.write(f"- {P.label_of(P.insns[k]) or P.where(P.insns[k])} ({k[0]}): {w}\n")
        fh.write('\n## Self-modified instructions (operand unknown)\n\n')
        for i in P.order:
            if i.opvolatile or i.volatile:
                fh.write(f"- {P.where(i)} `{P.disasm(i)}`{' (opcode)' if i.volatile else ''}\n")
        if R is not None:
            fh.write('\n## Stores through pointers the range analysis could not bound '
                     '(assumed not to hit a tracked byte)\n\n')
            for k, c in sorted(R.ptr_unknown.items(), key=lambda x: P.insns[x[0]].idx):
                i = P.insns[k]
                fh.write(f"- {P.where(i)} `{P.disasm(i)}` ({P.routine_of(i)})\n")
            ur = [i for i in P.order if i.key not in R.reached]
            fh.write(f"\n## Range coverage\n\n{len(P.order) - len(ur)} of {len(P.order)} "
                     f"instructions reached.  Unreached (first 400):\n\n")
            for i in ur[:400]:
                fh.write(f"- {P.where(i)} `{P.disasm(i)}` ({P.routine_of(i)})\n")
    log(f"-> {out}/insns.json, annotated/, findings.md, summary.md")


def _git_head(root):
    try:
        h = subprocess.run(['git', '-C', root, 'rev-parse', '--short', 'HEAD'], capture_output=True,
                           text=True).stdout.strip()
        d = subprocess.run(['git', '-C', root, 'status', '--porcelain', 'src'], capture_output=True,
                           text=True).stdout.strip()
        return h + (' +uncommitted src changes' if d else '')
    except Exception:
        return '?'


if __name__ == '__main__':
    main()
