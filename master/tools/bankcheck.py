#!/usr/bin/env python3
# bankcheck.py: check the banking rules of the relocated Master Elite
# (docs/MASTER-MAP.md, master/src/elite-far.asm). Run by build.sh from master/.
#
# Areas: "main" (elite-source.asm and the files it INCLUDEs in main RAM:
# elite-far.asm, elite-stubs7.asm), "bank4" (elite-bank4.asm, and the game data that
# build/data-addresses.asm marks bank4), "cold" (elite-andy.asm,
# elite-coldstubs.asm, elite-cold7.asm: ROMSEL &87, and the data marked cold). Main RAM and bank 4 see each other (bank 4 is paged
# whenever game code runs). The cold area is only paged during far calls.
#
# Rules, for every reference from code or data in one area to a label in
# another:
#  * branches never cross areas;
#  * cold code reaches main or bank 4 code only through stubs (x4_name,
#    j4_name: JSR far4 / far4j : EQUW name), and never reads bank 4 data;
#  * main and bank 4 code reach cold code only through stubs (JSR far7 /
#    far7j : EQUW name_C), and never read cold data;
#  * data in shadow RAM ("shadow": the extended tokens) is only read with
#    ACCCON X set, by readers marked "bankcheck: ok"; other references to it
#    must be immediate (#LO/#HI: its address);
#  * a line with the comment "bankcheck: ok" is exempt (reviewed by hand).
# Exit status 1 if any rule is broken.
import re, sys

SRC = "src/"
FILES = {"elite-source.asm": "main", "elite-far.asm": "main", "elite-stubs7.asm": "main", "elite-low.asm": "main", "elite-flight.asm": "main", "gfx-gstubs.asm": "main", "elite-hi.asm": "main", "gfx-hooks.asm": "main", "elite-hazel.asm": "main",
         "elite-bank4.asm": "bank4", "elite-andy.asm": "cold", "elite-coldstubs.asm": "cold",
         "elite-cold7.asm": "cold"}
MNEM = set(("ADC AND ASL BCC BCS BEQ BIT BMI BNE BPL BRA BRK BVC BVS CLC CLD CLI CLV CMP CPX CPY "
            "DEC DEX DEY EOR INC INX INY JMP JSR LDA LDX LDY LSR NOP ORA PHA PHP PHX PHY PLA PLP PLX "
            "PLY ROL ROR RTI RTS SBC SEC SED SEI STA STX STY STZ TAX TAY TRB TSB TSX TXA TXS TYA").split())
BRANCH = set("BCC BCS BEQ BMI BNE BPL BRA BVC BVS".split())
IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_%]*")


def code_part(line):
    out, q = "", False
    for ch in line:
        if ch == '"':
            q = not q
        if ch == "\\" and not q:
            break
        out += ch
    return out


def statements(path):
    try:
        lines = open(path).read().split("\n")
    except FileNotFoundError:
        return
    for n, line in enumerate(lines, 1):
        c = code_part(line)
        ok = "bankcheck: ok" in line
        for st in re.split(r"\s:\s", c):
            t = st.strip()
            labels = []
            while True:
                m = re.match(r"^\.([A-Za-z_][\w%]*)\s*(.*)$", t)
                if not m:
                    break
                labels.append(m.group(1))
                t = m.group(2).strip()
            mn, op = None, ""
            m = re.match(r"^([A-Za-z]{3})\b\s*(.*)$", t)
            if m and m.group(1).upper() in MNEM:
                mn, op = m.group(1).upper(), m.group(2)
            else:
                op = t
            yield n, line, labels, mn, op, ok


def idents(op):
    s = re.sub(r"'.'", "", re.sub(r'"[^"]*"', "", op))   # (strings and character literals)
    s = re.sub(r"&[0-9A-Fa-f]+", "", s)
    return IDENT.findall(s)


area = {}
for f, a in FILES.items():
    for n, line, labels, mn, op, ok in statements(SRC + f):
        for l in labels:
            area[l] = a
try:
    for line in open("build/data-addresses.asm"):
        m = re.match(r"^\s*(\S+)\s*=\s*&[0-9A-F]+\s*\\\s*(\w+)", line)
        if m:
            area[m.group(1)] = m.group(2)
except FileNotFoundError:
    pass

errors = []
for f, a in FILES.items():
    prev, prevop = None, None
    for n, line, labels, mn, op, ok in statements(SRC + f):
        if ok:
            prev, prevop = mn, op.strip()
            continue
        if mn is None and re.match(r"^EQUW\b", op.strip(), re.I) and prev in ("JSR",) and prevop in ("far4", "far4j", "far7", "far7j"):
            prev, prevop = None, None
            continue                       # the EQUW of a far-call stub
        for x in idents(op):
            b = area.get(x)
            if b is None or b == a or x in ("far4", "far4j", "far7", "far7j"):
                continue                   # (the far-call code is callable from anywhere)
            where = "%s:%d" % (f, n)
            if b == "shadow":
                if not op.strip().startswith("#"):
                    errors.append("%s: %s reads shadow RAM data %s outside a reader marked bankcheck: ok" % (where, a, x))
                continue
            if mn in BRANCH:
                errors.append("%s: branch from %s to %s %s" % (where, a, b, x))
            elif a == "cold":
                if b == "bank4":
                    errors.append("%s: cold code refers to bank 4 label %s" % (where, x))
                elif mn in ("JSR", "JMP"):
                    errors.append("%s: cold code calls %s in %s directly (use x4_%s)" % (where, x, b, x))
            else:
                if b == "cold":
                    errors.append("%s: %s refers to cold label %s (use a stub)" % (where, a, x))
        prev = mn
        prevop = op.strip()

for e in errors:
    print("bankcheck:", e)
print("bankcheck: %d labels, %s" % (len(area), "%d rule(s) broken" % len(errors) if errors else "all rules hold"))
sys.exit(1 if errors else 0)
