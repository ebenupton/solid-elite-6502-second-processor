#!/usr/bin/env python3
# covsum.py cov.bin psyms.txt: classify each labelled range of the parasite's
# code by the display modes it ran in (pcov.mjs): space only, direct only,
# both, never; sums per region
import re, sys
cov = open(sys.argv[1], 'rb').read()
sy = {}
for m in re.finditer(r"'([^']+)':(\d+)", open(sys.argv[2]).read()):
    sy.setdefault(m.group(1), int(m.group(2)))
regs = [l.split() for l in sys.argv[3:]] if len(sys.argv) > 3 else None
labs = sorted(set(v for k, v in sy.items() if 0x1500 <= v < 0xFF00))
def cls(a, b):
    m = 0
    for x in cov[a:b]: m |= x
    return {0: 'never', 1: 'space', 2: 'direct', 3: 'both'}[m & 3]
names = {}
for k, v in sy.items(): names.setdefault(v, k)
out = []
for i, a in enumerate(labs[:-1]):
    out.append((a, labs[i + 1], names[a], cls(a, labs[i + 1])))
import json
json.dump(out, open(sys.argv[1] + '.json', 'w'))
R = [('low',0x1500,0x2712),('run',0x2712,0x6776),('mdraw',0x6776,0x778F),('data',0x778F,0x9583),('cold',0x9583,0xB2FF),('colddata',0xB2FF,0xC4BF),('frame',0xC4BF,0xF798),('high',0xF800,0xFEF0)]
for n, a0, b0 in R:
    t = {}
    for a, b, nm, c in out:
        if a >= a0 and a < b0:
            t[c] = t.get(c, 0) + min(b, b0) - a
    print("%-9s %s" % (n, "  ".join("%s %d" % kv for kv in sorted(t.items()))))
