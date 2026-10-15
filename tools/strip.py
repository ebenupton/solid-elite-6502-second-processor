#!/usr/bin/env python3
# Strip BeebAsm comments, keep line numbers and routine names
import sys, re
for i, line in enumerate(open(sys.argv[1], encoding='latin-1'), 1):
    l = line.rstrip('\n')
    m = re.match(r'\\\s+Name: (.*)', l)
    if m:
        print("%d: ;;;; %s" % (i, m.group(1))); continue
    # remove comment outside quotes
    out = ''; q = False
    for ch in l:
        if ch == '"': q = not q
        if ch == '\\' and not q: break
        out += ch
    if out.strip():
        print("%d:%s" % (i, out.rstrip()))
