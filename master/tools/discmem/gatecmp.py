#!/usr/bin/env python3
"""master/tools/discmem/gatecmp.py A.log B.log: the gate's per-window speeds
(master/verify.sh's scratch/master-verify/compare.log) of two builds side by
side; prints the windows where B is slower and the overall it/s."""
import re, sys
def ld(f):
    d = {}
    for l in open(f):
        m = re.match(r'\s+(\d+)-\s*(\d+)\s+(\d+)\s+([\d.]+)\s+([\d.]+)', l)
        if m:
            d[int(m.group(1))] = float(m.group(5))
        m = re.match(r'speed .*all\s+\d+\s+([\d.]+)\s+([\d.]+)', l)
        if m:
            d['all'] = float(m.group(2))
    return d
a, b = ld(sys.argv[1]), ld(sys.argv[2])
worse = [(k, a[k], b[k]) for k in a if k != 'all' and k in b and b[k] < a[k]]
better = [(k, a[k], b[k]) for k in a if k != 'all' and k in b and b[k] > a[k]]
print('windows: %d, slower %d, faster %d, same %d' % (len(a) - 1, len(worse), len(better), len(a) - 1 - len(worse) - len(better)))
for k, x, y in sorted(worse):
    print('  slower %5d: %.2f -> %.2f it/s (%+.2f%%)' % (k, x, y, 100 * (y - x) / x))
print('all: %.2f -> %.2f it/s' % (a.get('all', 0), b.get('all', 0)))
