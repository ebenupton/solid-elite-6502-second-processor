#!/usr/bin/env python3
"""windows -- cut the annotated code into overlapping review windows, weighted by profile.

    python3 tools/grind/windows.py [--grind scratch/grind] [--profile scratch/grind/profile.json]
                                   [--size 32] [--overlap 8] [--context 6]

Reads insns.json (analyse.py) and profile.json (profile.mjs).  A window is SIZE code
lines (a source line that assembles to instructions; a FOR loop or macro line counts
once however many instructions it expands to) in source order, inside one routine
(the nearest global label) where possible: a routine longer than SIZE is cut into
windows overlapping by OVERLAP lines; consecutive short routines in a file are packed
together up to SIZE.  Writes:

  windows/w_NNNN.txt  the window: header, CONTEXT raw source lines before it, every
                      source line of the window (comment-only lines dropped) with its
                      line number, base cycles, measured cycles per frame and the
                      annotation; then the labels inside it and who enters them, and the
                      transfer targets outside it with their annotations
  windows.json        [{id, file, start_line, end_line, routine, seg, n_lines, n_insns,
                        bytes, est_cycles_per_frame, est_title_cycles_per_frame,
                        exec_cycles_flight}] in file order; plus 'ranking' (ids by
                        est_cycles_per_frame) and 'totals'
  windows.md          the ranking (top 200) and per-segment totals

est_cycles_per_frame: the measured cycles of the window's instructions per TT100
iteration, over the profile's flight scenarios together (TT100 iterations 300-600 and
1000-1300 by default); est_title_cycles_per_frame: per title-screen loop pass (TLL2).
Overlapping windows share lines, so the column does not sum to the total.
"""
import os, sys, json, argparse, collections

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))

SEGPFX = {'M': 'main', 'HZ': 'HZ', 'B4': 'B4', 'B5': 'B5', 'B6': 'B6', 'B7': 'B7'}


def load_profile(path, recs):
    """(seg, addr) -> (flight cycles per iteration, title cycles per iteration), meta"""
    if not path or not os.path.exists(path):
        return {}, dict(note='no profile')
    pj = json.load(open(path))
    keys = {(r['seg'], int(r['addr'], 16)) for r in recs}
    fl, ti = collections.Counter(), collections.Counter()
    nfl = 0
    tot = dict(flight=0, flight_unmapped=0, title=0, title_unmapped=0, mos=0)
    for name, sc in pj['scenarios'].items():
        it = sc['iterations'] or 0
        if name.startswith('flight'):
            nfl += it
        for k, c in sc['pcs'].items():
            pfx, a = k.split(':')
            a = int(a, 16)
            seg = SEGPFX.get(pfx)
            hit = (seg, a) in keys
            if name.startswith('flight'):
                tot['flight'] += c
                if pfx == 'MOS':
                    tot['mos'] += c
                if hit:
                    fl[(seg, a)] += c
                elif pfx != 'MOS':
                    tot['flight_unmapped'] += c
            elif name == 'title':
                tot['title'] += c
                if hit:
                    ti[(seg, a)] += c
                elif pfx != 'MOS':
                    tot['title_unmapped'] += c
    tit = pj['scenarios'].get('title', {}).get('iterations') or 1
    nfl = nfl or 1
    prof = {k: (fl[k] / nfl, ti[k] / tit) for k in set(fl) | set(ti)}
    meta = dict(flight_iterations=nfl, title_iterations=tit,
                flight_cycles_per_iteration=tot['flight'] / nfl,
                flight_unmapped_pct=100.0 * tot['flight_unmapped'] / max(1, tot['flight']),
                flight_mos_pct=100.0 * tot['mos'] / max(1, tot['flight']),
                title_cycles_per_iteration=tot['title'] / tit,
                scenarios={n: dict(iterations=s['iterations'], cycles_per_iteration=s['cycles_per_iteration'])
                           for n, s in pj['scenarios'].items()},
                disc=pj.get('disc'))
    return prof, meta


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--grind', default=os.path.join(REPO, 'scratch', 'grind'))
    ap.add_argument('--profile', default=None)
    ap.add_argument('--size', type=int, default=32)
    ap.add_argument('--overlap', type=int, default=8)
    ap.add_argument('--context', type=int, default=6)
    a = ap.parse_args()
    G = a.grind
    a.profile = a.profile or os.path.join(G, 'profile.json')
    J = json.load(open(os.path.join(G, 'insns.json')))
    recs = J['insns']
    build = J['meta']['build']
    prof, pmeta = load_profile(a.profile, recs)
    for r in recs:
        p = prof.get((r['seg'], int(r['addr'], 16)), (0.0, 0.0))
        r['prof'], r['prof_title'] = p
    # a soundness cross-check: an instruction the profile executed that the range analysis
    # never reached means the analysis missed a path
    bad = [r for r in recs if r.get('ranges_run') and r.get('ranges') is None
           and (r['prof'] or r['prof_title'])]
    pmeta['executed_but_unreached'] = [f"{r['file']}:{r['line']} {r['disasm']}" for r in bad]
    if bad:
        print(f"WARNING: {len(bad)} instructions executed in the profile were never reached by "
              f"the range analysis (see windows.md)")
    bykey = {f"{r['seg']}:{r['addr']}": r for r in recs}
    preds = collections.defaultdict(list)
    for r in recs:
        for t in r.get('targets', []):
            preds[t].append(r)
    # code lines per file
    files = collections.defaultdict(lambda: collections.defaultdict(list))
    for r in recs:
        files[r['file']][r['line']].append(r)
    src = {}
    for f in files:
        try:
            src[f] = open(os.path.join(build, 'tree', f), encoding='latin-1').read().split('\n')
        except OSError:
            src[f] = []
    wins = []
    for f in sorted(files, key=lambda f: (f != 'src/elite-source.asm', f)):
        lines = sorted(files[f])
        units = [(ln, files[f][ln]) for ln in lines]
        # routines: runs of units with the same routine name
        regions = []
        for u in units:
            rt = u[1][0]['routine']
            if regions and regions[-1][0] == rt:
                regions[-1][1].append(u)
            else:
                regions.append((rt, [u]))
        # pack short regions; cut long ones
        pending = []
        def flush():
            if pending:
                us = [u for _, rr in pending for u in rr]
                wins.append(dict(file=f, units=us, routine=','.join(dict.fromkeys(n for n, _ in pending))))
                pending.clear()
        for rt, us in regions:
            if len(us) > a.size:
                flush()
                step = a.size - a.overlap
                starts = list(range(0, len(us) - a.size + 1, step))
                if starts[-1] + a.size < len(us):
                    starts.append(len(us) - a.size)
                for s in starts:
                    wins.append(dict(file=f, units=us[s:s + a.size], routine=rt))
            else:
                if sum(len(r_) for _, r_ in pending) + len(us) > a.size:
                    flush()
                pending.append((rt, us))
        flush()
    os.makedirs(os.path.join(G, 'windows'), exist_ok=True)
    for old in os.listdir(os.path.join(G, 'windows')):
        if old.startswith('w_') and old.endswith('.txt'):
            os.remove(os.path.join(G, 'windows', old))
    out = []
    for n, w in enumerate(wins):
        wid = f"w_{n:04d}"
        f = w['file']
        ins = [r for _, rs in w['units'] for r in rs]
        lo, hi = w['units'][0][0], w['units'][-1][0]
        segs = sorted({r['seg'] for r in ins})
        est = sum(r['prof'] for r in ins)
        est_t = sum(r['prof_title'] for r in ins)
        nb = sum(r['len'] for r in ins if not r.get('pseudo'))
        rec = dict(id=wid, file=f, start_line=lo, end_line=hi, routine=w['routine'],
                   seg='/'.join(segs), n_lines=len(w['units']), n_insns=len(ins), bytes=nb,
                   est_cycles_per_frame=round(est, 1), est_title_cycles_per_frame=round(est_t, 1))
        out.append(rec)
        write_window(os.path.join(G, 'windows', wid + '.txt'), rec, w, src.get(f, []), files[f],
                     bykey, preds, a.context, J['meta'])
    ranking = sorted(out, key=lambda r: -r['est_cycles_per_frame'])
    segtot = collections.defaultdict(lambda: dict(insns=0, bytes=0, cycles_per_frame=0.0, windows=0))
    for r in recs:
        s = segtot[r['seg']]
        s['insns'] += 1
        s['bytes'] += 0 if r.get('pseudo') else r['len']
        s['cycles_per_frame'] += r['prof']
    for w in out:
        for s in w['seg'].split('/'):
            segtot[s]['windows'] += 1
    totals = dict(insns=len(recs), bytes=sum(s['bytes'] for s in segtot.values()),
                  windows=len(out), segments=segtot, profile=pmeta)
    json.dump(dict(windows=out, ranking=[r['id'] for r in ranking], totals=totals),
              open(os.path.join(G, 'windows.json'), 'w'), indent=1)
    with open(os.path.join(G, 'windows.md'), 'w') as fh:
        fh.write(f"# Grind windows\n\n{len(out)} windows of up to {a.size} code lines "
                 f"(overlap {a.overlap}); {len(recs)} instructions, {totals['bytes']} code bytes.\n\n")
        if pmeta.get('flight_iterations'):
            fh.write(f"Profile: {pmeta['flight_cycles_per_iteration']:.0f} cycles per TT100 iteration "
                     f"in flight ({pmeta['flight_iterations']} iterations; "
                     f"{pmeta['flight_mos_pct']:.1f}% in the MOS, "
                     f"{pmeta['flight_unmapped_pct']:.2f}% at other PCs that are not an analysed "
                     f"instruction); title {pmeta['title_cycles_per_iteration']:.0f} cycles per "
                     f"loop pass.\n\n")
        if pmeta.get('executed_but_unreached'):
            fh.write("**WARNING: executed in the profile but never reached by the range analysis "
                     "(a missed path: ranges there are not sound):** " +
                     '; '.join(pmeta['executed_but_unreached'][:50]) + "\n\n")
        elif pmeta.get('flight_iterations'):
            fh.write("Cross-check: every instruction the profile executed was reached by the range "
                     "analysis.\n\n")
        fh.write('| segment | insns | bytes | windows | cycles/frame |\n|---|---:|---:|---:|---:|\n')
        for s in ('main', 'B4', 'HZ', 'B5', 'B6', 'B7'):
            if s in segtot:
                v = segtot[s]
                fh.write(f"| {s} | {v['insns']} | {v['bytes']} | {v['windows']} | {v['cycles_per_frame']:.0f} |\n")
        fh.write('\n## Ranking by measured cycles per frame (flight)\n\n'
                 '| # | window | file:lines | routine | seg | insns | bytes | cyc/frame | title |\n'
                 '|---:|---|---|---|---|---:|---:|---:|---:|\n')
        for k, r in enumerate(ranking[:200], 1):
            fh.write(f"| {k} | {r['id']} | {os.path.basename(r['file'])}:{r['start_line']}-{r['end_line']} | "
                     f"{r['routine'][:40]} | {r['seg']} | {r['n_insns']} | {r['bytes']} | "
                     f"{r['est_cycles_per_frame']:.0f} | {r['est_title_cycles_per_frame']:.0f} |\n")
    print(f"{len(out)} windows -> {G}/windows/, windows.json, windows.md")


def short_ann(r):
    return r['ann']


def write_window(path, rec, w, text, flines, bykey, preds, ctx, meta):
    f = rec['file']
    lo, hi = rec['start_line'], rec['end_line']
    keys = {f"{r['seg']}:{r['addr']}" for _, rs in w['units'] for r in rs}
    o = []
    o.append(f"# {rec['id']}  {f}:{lo}-{hi}  routine {rec['routine']}  [{rec['seg']}]  "
             f"{rec['n_insns']} insns, {rec['bytes']} bytes")
    o.append(f"# measured: {rec['est_cycles_per_frame']:.0f} cycles per TT100 iteration (flight), "
             f"{rec['est_title_cycles_per_frame']:.0f} per title loop pass")
    if not meta.get('ranges_sound', False) and meta.get('ranges'):
        o.append("# WARNING: the range analysis did not finish: ranges are NOT sound")
    o.append("# columns: line | base cycles | measured cycles/frame | live in:/out: (AXYNZCV) | state "
             "before: A= X= Y= (≡m: equals byte m) flags C Z N V (0/1/?) [operand]=range, "
             "NEVER/ALWAYS = branch feasibility | source")
    o.append("## context")
    for n in range(max(1, lo - ctx), lo):
        if n - 1 < len(text):
            o.append(f"{n:5}                 | {text[n - 1].rstrip()}")
    o.append("## window")
    for n in range(lo, hi + 1):
        t = text[n - 1].rstrip() if n - 1 < len(text) else ''
        rs = flines.get(n)
        if not rs:
            s = t.strip()
            if not s or s.startswith('\\') or s.startswith(';'):
                continue
            o.append(f"{n:5}                 | {'':<60} | {t}")
            continue
        cyc = sum(r['cycles'] for r in rs)
        pr = sum(r['prof'] for r in rs)
        cx = rs[0]['cycles_extra'] if len(rs) == 1 else ''
        if len(rs) == 1:
            ann = rs[0]['ann']
        elif len(rs) <= 4:
            ann = ' ‖ '.join(f"[{r['disasm']}] {r['ann']}" for r in rs)
        else:
            ann = f"[x{len(rs)}: {rs[0]['disasm']} ...] {rs[0]['ann']}"
        flags = ''
        if any(r.get('smc') for r in rs):
            flags += ' SMC:' + rs[0].get('smc', '')
        if any(r.get('pseudo') for r in rs):
            flags += ' (BIT-skip/hidden RTS)'
        o.append(f"{n:5} {cyc:3}{cx:2} {pr:8.1f} | {ann}{flags} | {t}")
    # labels in the window and who enters them
    o.append("## labels in this window: entered from")
    for _, rs in w['units']:
        for r in rs:
            k = f"{r['seg']}:{r['addr']}"
            ps = preds.get(k, [])
            if r.get('label') or ps or r.get('entry'):
                ext = [p for p in ps if f"{p['seg']}:{p['addr']}" not in keys]
                if not ext and not r.get('entry'):
                    continue
                desc = ', '.join(f"{p['mn']} at {os.path.basename(p['file'])}:{p['line']}" for p in ext[:8])
                if len(ext) > 8:
                    desc += f" ... ({len(ext)} sites)"
                ent = ' '.join(r.get('entry', []))
                o.append(f"  .{r.get('label') or '?'} ({os.path.basename(r['file'])}:{r['line']}, "
                         f"{k}){' [' + ent + ']' if ent else ''}: {desc or '-'}")
    # targets outside
    o.append("## transfer targets outside this window")
    seen = set()
    for _, rs in w['units']:
        for r in rs:
            for t in r.get('targets', []):
                if t in keys or t in seen:
                    continue
                seen.add(t)
                tr = bykey.get(t)
                if tr is None:
                    continue
                o.append(f"  {r['disasm']} -> .{tr.get('label') or '?'} "
                         f"{os.path.basename(tr['file'])}:{tr['line']} [{t}]: {tr['ann']}")
            if 'targets' in r and not r['targets']:
                o.append(f"  {r['disasm']} (line {r['line']}): unresolved target (indirect/MOS/patched)")
    with open(path, 'w') as fh:
        fh.write('\n'.join(o) + '\n')


if __name__ == '__main__':
    main()
