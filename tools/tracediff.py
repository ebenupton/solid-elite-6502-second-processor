#!/usr/bin/env python3
# Diff two label traces from compare.mjs --trace (orig vs port), ignoring IRQ
# labels and the A register; single-entry insertions/deletions (an instruction
# hook firing twice around an interrupt) are ignored.
import sys, difflib
skip = {'IRQ1', 'jvec', 'LINSCN', 'VNT3', 'VNT2', 'VNT1'}
def load(f):
    out = []
    for l in open(f).read().split('\n'):
        p = l.split(' ')
        if not p[0] or p[0] in skip: continue
        out.append((p[0] + ' ' + ' '.join(x for x in p[2:] if not x.startswith('C=')), l))
    return out
a, b = load(sys.argv[1]), load(sys.argv[2])
sm = difflib.SequenceMatcher(None, [x[0] for x in a], [x[0] for x in b], autojunk=False)
shown = 0
for tag, i1, i2, j1, j2 in sm.get_opcodes():
    if tag == 'equal': continue
    if (i2 - i1) + (j2 - j1) <= 1 and tag in ('insert', 'delete'): continue
    print(f'{tag} orig[{i1}:{i2}] port[{j1}:{j2}]')
    for k in range(max(0, i1 - 8), min(len(a), i2 + 4)): print('  O', k, a[k][1])
    for k in range(max(0, j1 - 8), min(len(b), j2 + 4)): print('  P', k, b[k][1])
    shown += 1
    if shown >= 3: break
print(len(a), len(b))
