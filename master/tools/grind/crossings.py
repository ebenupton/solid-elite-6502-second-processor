#!/usr/bin/env python3
"""crossings.py: the calls between the hot side and the cold pass, and what moving a
cold block into the hot pass would do to them (docs/MASTER-MAP.md, "Calls between the
passes").

    python3 master/tools/grind/crossings.py --insns scratch/grind/insns.json \\
        --profile scratch/grind/profile.json [--src master/src/elite-source.asm] \\
        [--stubs master/build/elite-stubs.asm] [--top 40] [--blocks "TT111 DKS3 ..."]

Reads the analysis of a build (analyse.py --no-ranges: insns.json, one record per
instruction with its source line and disassembly) and the gate's profile of the same
build (profile.mjs: cycles per PC, flight and other). Every JSR or JMP in
elite-source.asm's code is counted from the cycles at its PC (6 a JSR, 3 a JMP), in the
flight iterations and in the rest of the run (docked screens, title, launch). A call
whose target is a stub (x4_H, j4_H, or a cold routine's name on the hot side) is
attributed to its target's block, so each call is (caller's block, callee's block).

For each cold block it prints what moving it into the hot pass would do: the crossings
it removes (its calls of hot blocks and the hot side's calls of it) and the crossings it
creates (its calls of cold blocks and the cold pass's calls of it), in flight and other,
and the net. A crossing costs a stub's 85 cycles (master/src/elite-stubs.asm). Calls
between blocks moved together count twice, and fall-throughs (seams) are not counted:
check a candidate's neighbours too (streams.py makes a seam stub for a fall-through
across the passes, which costs a crossing each time it runs).
"""
import argparse, collections, json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
import streams as S                                      # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument('--insns', required=True)
ap.add_argument('--profile', required=True)
ap.add_argument('--src', default=os.path.join(HERE, '..', '..', 'src', 'elite-source.asm'))
ap.add_argument('--stubs', default=os.path.join(HERE, '..', '..', 'build', 'elite-stubs.asm'))
ap.add_argument('--top', type=int, default=40)
ap.add_argument('--blocks', default='')
a = ap.parse_args()

insns = json.load(open(a.insns))['insns']
prof = json.load(open(a.profile))['scenarios']
lines = open(a.src, encoding='latin-1').read().split('\n')
bl = S.blocks(lines)
S.ACTIVE[:] = S.active_lines(lines)
blk = [None] * len(lines)
lab = {}
for k, (s, e, n, ar) in enumerate(bl):
    for i in range(s, e):
        blk[i] = k
    for nm, i in S.defined(lines[s:e]):
        lab.setdefault(nm, k)
        lab.setdefault(nm + '_C', k)
seg = {'main': 'M', 'B4': 'B4', 'C7': 'B7'}
calls = collections.defaultdict(lambda: [0.0, 0.0])      # (caller block, callee block) -> [flight, other]
for x in insns:
    if x['mn'] not in ('JSR', 'JMP') or 'elite-source' not in x['file']:
        continue
    t = x['disasm'].split()[-1]
    t = re.sub(r'^(x4_|j4_)', '', t)
    if t not in lab:
        t = re.sub(r'_\d+$', '', t)                      # (x4_pr2_2: pr2+2)
    if t not in lab:
        continue
    k = '%s:%s' % (seg.get(x['seg'], x['seg']), x['addr'].lower().lstrip('0') or '0')
    cyc = 3 if x['mn'] == 'JMP' else 6
    f, o = prof['flight']['pcs'].get(k, 0) / cyc, prof['other']['pcs'].get(k, 0) / cyc
    if f or o:
        c = calls[(blk[x['line'] - 1], lab[t])]
        c[0] += f
        c[1] += o
cold = lambda k: bl[k][3] == 'cold'
it = prof['flight']['iterations']
cross = [0.0, 0.0]
for (c1, c2), (f, o) in calls.items():
    if cold(c1) != cold(c2):
        cross[0] += f
        cross[1] += o
print('crossings now: %.0f in flight (%.4f an iteration), %.0f other' % (cross[0], cross[0] / it, cross[1]))
res = []
for k, (s, e, n, ar) in enumerate(bl):
    if ar != 'cold' or not n:
        continue
    rem, add = [0.0, 0.0], [0.0, 0.0]
    for (c1, c2), (f, o) in calls.items():
        if c1 == c2 or k not in (c1, c2):
            continue
        other = c2 if c1 == k else c1
        tgt = rem if not cold(other) else add
        tgt[0] += f
        tgt[1] += o
    res.append((rem[0] - add[0], rem[1] - add[1], n, rem, add))
res.sort(key=lambda r: -(r[0] * 20 + r[1]))
sel = a.blocks.split()
for nf, no, n, rem, add in ([r for r in res if r[2] in sel] if sel else res[:a.top]):
    print('%-16s net flight %7.0f other %7.0f   (removes %.0f / %.0f, creates %.0f / %.0f)'
          % (n, nf, no, rem[0], rem[1], add[0], add[1]))
