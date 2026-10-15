#!/usr/bin/env python3
"""One-off helper used to create src/elite-source.asm from the demo source
(src/orig/elite-source.asm): drops the per-file SAVE stanzas of the original
ELTA..ELTG/SHIPS/PYTHON split and regroups the code into two regions:
  main RAM  &0F40-&3FFF : ELITE A, B, C, F, G
  bank 4    &8000-&BFFF : ELITE D, E, ship blueprints (incl. Python)
Kept in tools/ for reference; src/elite-source.asm is hand-edited afterwards."""
import re, sys
src = open(sys.argv[1], encoding='latin-1').read().split('\n')
out_path = sys.argv[2]

def find(pat, start=0):
    for i in range(start, len(src)):
        if re.search(pat, src[i]):
            return i
    raise SystemExit("not found: " + pat)

def stanza_start(i):
    # back up to the "\ ****" line that starts the comment header before line i
    j = i
    while not src[j].startswith('\\ ****'):
        j -= 1
    return j

secs = {}
names = "ABCDEFG"
for n in names:
    if n == 'A':
        b = find(r'^ LOAD_A% = LOAD%') + 1
    else:
        b = find(r'^ LOAD_%s%% = LOAD%%' % n) + 1
    e = stanza_start(find(r'^\\ Save ELT%s\.bin' % n))
    secs[n] = (b, e)

head_end = stanza_start(find(r'^\\ ELITE A FILE'))
chk = stanza_start(find(r'^\\       Name: checksum0'))
ships_b = find(r'^ LOAD_SHIPS% = ') + 1
ships_e = stanza_start(find(r'^\\ Save SHIPS\.bin'))
py_b = find(r'^ ORG CODE_PYTHON%') + 1
py_e = stanza_start(find(r'^\\ Save PYTHON\.bin'))

def lines(r):
    return src[r[0]:r[1]]

out = []
out += src[:head_end]
out += ['', '\\ ' + '*'*78, '\\', '\\ MAIN CODE (main RAM, &0F40 to &3FFF)', '\\', '\\ ' + '*'*78, '',
        ' ORG CODE%              \\ Set the assembly address to CODE%', '']
for n in "ABCFG":
    out += ['', '\\ --- Original ELITE %s file ' % n + '-'*50, '']
    out += lines(secs[n])
out += ['', ' MAIN_END% = P%', '',
        '\\ ' + '*'*78, '\\', '\\ SIDEWAYS RAM BANK 4 (&8000 to &BFFF)', '\\', '\\ ' + '*'*78, '',
        ' ORG BANK%              \\ Set the assembly address to BANK%', '']
for n in "DE":
    out += ['', '\\ --- Original ELITE %s file ' % n + '-'*50, '']
    out += lines(secs[n])
out += ['', '\\ --- Ship blueprints ' + '-'*56, '']
out += src[ships_b:ships_e]
out += src[py_b:py_e]
out += ['', ' BANK_END% = P%', '']
open(out_path, 'w', encoding='latin-1').write('\n'.join(out) + '\n')
print({k: (v[0]+1, v[1]) for k, v in secs.items()}, head_end, chk, ships_b, ships_e, py_b, py_e)
