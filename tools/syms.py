#!/usr/bin/env python3
# Parse beebasm -d symbol dump; print sorted "addr name" lines (last dict wins)
import sys, re, ast
txt = open(sys.argv[1]).read()
d = {}
for m in re.finditer(r"\[\{.*?\}\]", txt):
    s = re.sub(r"(\d+)L", r"\1", m.group(0))
    for dd in ast.literal_eval(s):
        d.update(dd)
for k, v in sorted(d.items(), key=lambda kv: kv[1]):
    print("%04X %s" % (v, k))
