#!/usr/bin/env python3
"""Helpers for editing src/elite-source.asm by routine block.
A block starts at the '\\ ****' line before '\\       Name: <name>' and runs to
the line before the next such header.
  blocks.py list                      list blocks with line numbers
  blocks.py get NAME                  print block
  blocks.py replace NAME FILE         replace block NAME with contents of FILE
  blocks.py replace-range FIRST LAST FILE  replace blocks FIRST..LAST inclusive
  blocks.py move FIRST LAST AFTER     move blocks FIRST..LAST to after block AFTER
"""
import sys, re
P = '/Users/ebenupton/elite/src/elite-source.asm'
def load():
    return open(P, encoding='latin-1').read().split('\n')
def save(L):
    open(P, 'w', encoding='latin-1').write('\n'.join(L))
def heads(L):
    h = []
    for i, l in enumerate(L):
        m = re.match(r'\\       Name: (.*?)\s*$', l)
        if m:
            j = i
            while not L[j].startswith('\\ ****'):
                j -= 1
            h.append((m.group(1), j))
    return h
def span(L, name):
    h = heads(L)
    for k, (n, j) in enumerate(h):
        if n == name:
            end = h[k+1][1] if k+1 < len(h) else len(L)
            # stop at non-block structural markers (section comments) before next header
            return j, end
    raise SystemExit('no block ' + name)
def trim_end(L, a, b):
    # don't swallow region markers like '\ --- Original ELITE' or ORG lines
    for i in range(a+1, b):
        if L[i].startswith('\\ --- Original ELITE') or L[i].startswith(' ORG ') or L[i].startswith(' MAIN_END%') or L[i].startswith(' BANK_END%'):
            # back up over the preceding comment banner if any
            k = i
            while k > a and (L[k-1].strip() == '' or L[k-1].startswith('\\ ****') or L[k-1] == '\\' or L[k-1].startswith('\\ MAIN') or L[k-1].startswith('\\ SIDEWAYS')):
                k -= 1
            return k
    return b
cmd = sys.argv[1]
L = load()
if cmd == 'list':
    for n, j in heads(L):
        print(j+1, n)
elif cmd == 'get':
    a, b = span(L, sys.argv[2]); b = trim_end(L, a, b)
    print('\n'.join(L[a:b]))
elif cmd in ('replace', 'replace-range'):
    if cmd == 'replace':
        a, b = span(L, sys.argv[2]); f = sys.argv[3]
    else:
        a, _ = span(L, sys.argv[2]); _, b = span(L, sys.argv[3]); f = sys.argv[4]
    b = trim_end(L, a, b)
    new = open(f, encoding='latin-1').read().rstrip('\n').split('\n') + ['']
    L[a:b] = new
    save(L)
    print('replaced lines', a+1, b)
elif cmd == 'move':
    a, _ = span(L, sys.argv[2]); _, b = span(L, sys.argv[3]); b = trim_end(L, a, b)
    blk = L[a:b]
    del L[a:b]
    c, d = span(L, sys.argv[4]); d = trim_end(L, c, d)
    L[d:d] = blk
    save(L)
    print('moved', b-a, 'lines')
