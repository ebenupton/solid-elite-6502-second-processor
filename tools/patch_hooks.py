#!/usr/bin/env python3
"""One-off: insert the frame-layer hooks into src/elite-source.asm (the Master
port). Each patch replaces an exact block of lines (comments included) and
must match exactly once."""
import re, sys
p = 'src/elite-source.asm'
s = open(p).read()

def rep(old, new, count=1):
    global s
    n = s.count(old)
    if n != count:
        sys.exit(f'patch anchor found {n} times (want {count}):\n{old}')
    s = s.replace(old, new)

def line_after(label, text):
    """Insert text right after the line '.label' (exact label line)."""
    rep(f'\n.{label}\n', f'\n.{label}\n\n{text}\n')

H = ' JSR {}                \\ Frame layer hook (see hooks.asm)'

# Primitives
line_after('LOIN', H.format('H_LOIN'))
rep(""" STA HCOL               \\ Store the colour byte in HCOL
""", """ STA HCOL               \\ Store the colour byte in HCOL

 JSR H_SKIP             \\ Frame layer hook: nothing to draw in record mode
""")
line_after('LL155', H.format('H_SKIP'))
line_after('PIXEL', H.format('H_DOT'))
rep(""" CMP #96                \\ If |Y1| >= 96 then it's off the screen (as 96 is half
 BCS PX4 """, """ CMP #96                \\ If |Y1| >= 96 then it's off the screen (as 96 is half
 BCS px4s """)
rep("""\n.PIXEL\n""", """\n JSR H_STAR             \\ Frame layer hook: record star Y in record mode

.PIXEL\n""")
rep("""\n.PX4\n""", """\n.PX4\n""")
open(p, 'w').write(s)
print('ok so far')
