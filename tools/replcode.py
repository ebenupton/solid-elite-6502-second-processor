#!/usr/bin/env python3
"""Replace the code of routine block NAME (from its first line that starts
with START_LABEL, default '.NAME', to the end of the block) with FILE.
  replcode.py NAME FILE [START_LABEL]"""
import sys, subprocess
sys.path.insert(0, '/Users/ebenupton/elite/tools')
import importlib.util
spec = importlib.util.spec_from_file_location('blocks', '/Users/ebenupton/elite/tools/blocks.py')
name, f = sys.argv[1], sys.argv[2]
start = sys.argv[3] if len(sys.argv) > 3 else '.' + name
P = '/Users/ebenupton/elite/src/elite-source.asm'
L = open(P, encoding='latin-1').read().split('\n')
# reuse span logic
import re
def heads(L):
    h = []
    for i, l in enumerate(L):
        m = re.match(r'\\       Name: (.*?)\s*$', l)
        if m:
            j = i
            while not L[j].startswith('\\ ****'): j -= 1
            h.append((m.group(1), j))
    return h
h = heads(L)
for k, (n, j) in enumerate(h):
    if n == name:
        a, b = j, (h[k+1][1] if k + 1 < len(h) else len(L))
        break
else:
    raise SystemExit('no block ' + name)
for i in range(a + 1, b):
    if L[i].startswith('\\ --- Original ELITE') or L[i].startswith(' ORG ') or L[i].startswith(' MAIN_END%') or L[i].startswith(' BANK_END%'):
        b = i
        while L[b-1].strip() == '' or L[b-1].startswith('\\ ****') or L[b-1] == '\\': b -= 1
        break
s = [i for i in range(a, b) if L[i].startswith(start)][0]
new = open(f, encoding='latin-1').read().rstrip('\n').split('\n') + ['']
L[s:b] = new
open(P, 'w', encoding='latin-1').write('\n'.join(L))
print('replaced', s + 1, b)
