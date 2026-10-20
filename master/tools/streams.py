#!/usr/bin/env python3
# streams.py: split the main source into its emissions (docs/MASTER-MAP.md,
# "The source and its emissions"). Run by build.sh from master/.
#
# src/elite-source.asm is the original's main source in the original's order.
# Each of its routines and tables sits once, at its original place, and the
# area it lives in is a field of its header:
#
#   \       Name: TT219
#   ...
#   \       Area: cold
#
# No Area field: the main code's run (main RAM from CODE%, then bank 4 where
# main RAM ends). "Area: bank 4": bank 4, after the run (code that runs with
# ACCCON X set, which hides main RAM at &3000-&7FFF, and the tables it reads).
# "Area: cold": the cold area, sideways RAM bank 7. A block runs from its
# header to the next header (or to a separator line of stars, which starts an
# untagged block: the original's PRINT and SAVE sections).
#
# BeebAsm assembles a file once and has one location counter, and banks 4
# and 7 share the addresses &8000-&BFFF, so each area's blocks are assembled
# from a copy of the source of their own: build/elite-source-<area>.asm is
# elite-source.asm with every line outside that area's blocks blanked (so
# that line numbers stay the source's). src/elite-layout.asm INCLUDEs the
# copies one after the other (run, bank4, cold), each at its own address, so
# every label is defined exactly once and every block is assembled once.
#
# Checks (exit status 1 on failure):
#   * every block's IF ... ENDIF nesting is balanced (a blanked block must not
#     take half of a conditional with it);
#   * a block whose code can fall through its end is followed, in the source,
#     by a block of the same area (each area is assembled in the source's
#     order, so a block falls into the next block of its own area).
import re, sys

SRC = "src/elite-source.asm"
OUT = "build/elite-source-%s.asm"
AREAS = ("run", "bank4", "cold")
STAR = re.compile(r"^\\ \*{70,}\s*$")
AREA = re.compile(r"^\\       Area: (.*)$")
TAGS = {"cold": "cold", "bank 4": "bank4"}
NOFALL = set("RTS RTI JMP BRA BRK".split())


def code_part(line):
    out, q = "", False
    for ch in line:
        if ch == '"':
            q = not q
        if ch == "\\" and not q:
            break
        out += ch
    return out.strip()


def blocks(lines):
    """[(start, end, name, area)]: a block starts at a header (a line of
    stars followed by a lone backslash) or at a separator line of stars"""
    out = [[0, None, None, "run"]]
    inh = False
    for i, l in enumerate(lines):
        if STAR.match(l):
            if inh:
                inh = False
                if (i + 2 < len(lines) and lines[i + 1].rstrip() == "\\"
                        and lines[i + 2].startswith("\\       Name:")):
                    out.append([i, None, None, "run"])     # (a banner's closing line
                    inh = True                             # opens the next header)
            elif i + 1 < len(lines) and lines[i + 1].rstrip() == "\\":
                out.append([i, None, None, "run"])
                inh = True
            else:
                out.append([i, None, None, "run"])
        elif inh:
            if not l.startswith("\\"):
                sys.exit("%s:%d: a header that is not closed" % (SRC, i + 1))
            m = re.match(r"^\\       Name: (.*)$", l)
            if m:
                out[-1][2] = m.group(1).strip()
            m = AREA.match(l)
            if m:
                t = m.group(1).strip()
                if t not in TAGS:
                    sys.exit("%s:%d: unknown area %r" % (SRC, i + 1, t))
                out[-1][3] = TAGS[t]
    for k, b in enumerate(out):
        b[1] = out[k + 1][0] if k + 1 < len(out) else len(lines)
    return [tuple(b) for b in out]


# the build options' flags (build/elite-build-options.asm, as build.sh writes
# them for the game), for the checks' view of conditional assembly
FLAGS = {"_SNG47": True, "_COMPACT": False, "_MATCH_ORIGINAL_BINARIES": True,
         "_REMOVE_CHECKSUMS": True, "_MAX_COMMANDER": False, "Q%": False}


def active_lines(lines):
    """for each line, False if it is in a branch of IF ... ENDIF that the
    flags rule out (a condition on anything else counts as either way)"""
    out, stack = [], []          # stack: [this branch on, a branch taken, known]
    for l in lines:
        c = code_part(l)
        m = re.match(r"^(IF|ELIF|ELSE|ENDIF)\b\s*(.*)$", c, re.I)
        on = all(st[0] for st in stack)
        if not m:
            out.append(on)
            continue
        kw, cond = m.group(1).upper(), m.group(2).strip()
        v = FLAGS.get(cond.replace("NOT(", "").rstrip(")")) if cond else None
        if v is not None and cond.startswith("NOT("):
            v = not v
        if kw == "IF":
            stack.append([True if v is None else v, bool(v), v is not None])
        elif kw in ("ELIF", "ELSE") and stack:
            st = stack[-1]
            if not st[2]:
                st[0] = True
            elif kw == "ELSE":
                st[0] = not st[1]
            else:
                st[0] = (not st[1]) and (True if v is None else v)
                st[1] = st[1] or st[0]
                st[2] = st[2] and v is not None
        elif kw == "ENDIF" and stack:
            stack.pop()
        out.append(False)
    return out


ACTIVE = []


def last_statement(lines, s, e):
    """the last statement of lines[s:e] that is assembled (None if none),
    passing over the lines of conditional assembly (IF, ELIF, ELSE, ENDIF)
    and the branches the build's flags rule out"""
    for i in range(e - 1, s - 1, -1):
        if ACTIVE and not ACTIVE[i]:
            continue
        c = code_part(lines[i])
        if c and not re.match(r"^(IF|ELIF|ELSE|ENDIF)\b", c, re.I):
            return c if c.upper().startswith("EQU") else c.split(" : ")[-1].strip()
    return None


def assembles(c, macros):
    """whether the statement c assembles bytes or moves the address (an
    instruction, data, a label, ORG ...), not just comments, PRINTs, SAVEs,
    ASSERTs or constants"""
    if not c or re.match(r"^(PRINT|SAVE|ASSERT|IF|ELIF|ELSE|ENDIF|MACRO|ENDMACRO|GUARD|CPU)\b", c, re.I):
        return False
    return not re.match(r"^[A-Za-z_][\w%]*\s*=", c)


def falls_through(stmt, macros):
    if stmt is None:
        return False
    w = stmt.split()
    if not w:
        return False
    op = w[0].upper()
    if w[0] in macros:
        return False                   # (a macro: the original's data macros)
    if op in NOFALL:
        return False
    if re.match(r"^(EQU[BWDS]|SKIP|INCBIN|FOR|NEXT|PRINT|SAVE|ASSERT|ORG|CLEAR|GUARD|MACRO|ENDMACRO|INCLUDE|CPU|COPYBLOCK|ALIGN)\b", op):
        return False                   # (data and directives: nothing to fall from)
    if re.match(r"^[A-Za-z_][\w%]*\s*=", stmt) or stmt.startswith("."):
        return False                   # (a constant, or a label alone)
    return True


def main():
    lines = open(SRC, encoding="latin-1").read().split("\n")
    bl = blocks(lines)
    ACTIVE[:] = active_lines(lines)
    macros = set(m.group(1) for m in (re.match(r"^\s*MACRO\s+(\w+)", l) for l in lines) if m)
    errors = []
    for s, e, name, area in bl:
        depth = 0
        for i in range(s, e):
            c = code_part(lines[i]).upper()
            if re.match(r"^IF\b", c):
                depth += 1
            elif re.match(r"^ENDIF\b", c):
                depth -= 1
        if depth and area != "run":
            errors.append("%s:%d: %s: IF ... ENDIF not balanced in an area's block" % (SRC, s + 1, name))
    # fall-through: each block that can fall through its end must be followed,
    # in the source, by a block of its own area that holds code
    for k, (s, e, name, area) in enumerate(bl):
        st = last_statement(lines, s, e)
        if not falls_through(st, macros):
            continue
        for s2, e2, name2, area2 in bl[k + 1:]:
            if not any(ACTIVE[i] and assembles(code_part(lines[i]), macros) for i in range(s2, e2)):
                continue               # (comments, PRINTs and constants only)
            if any(re.match(r"^(ORG|CLEAR|SKIPTO)\b", code_part(lines[i]), re.I) for i in range(s2, e2)):
                errors.append("%s:%d: %s (%s) can fall through its end (%s) into %s, which moves the address"
                              % (SRC, e, name, area, st, name2))
            elif area2 != area:
                errors.append("%s:%d: %s (%s) can fall through its end (%s) into %s (%s)"
                              % (SRC, e, name, area, st, name2, area2))
            break
    for a in AREAS:
        with open(OUT % a, "w", encoding="latin-1") as f:
            for s, e, name, area in bl:
                for i in range(s, e):
                    f.write((lines[i] if area == a else "") + ("\n" if i < len(lines) - 1 else ""))
    n = {a: sum(1 for b in bl if b[3] == a) for a in AREAS}
    for e in errors:
        print("streams:", e)
    print("streams: %d blocks (%s)%s" % (len(bl), ", ".join("%s %d" % (a, n[a]) for a in AREAS),
                                        ", %d error(s)" % len(errors) if errors else ""))
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
