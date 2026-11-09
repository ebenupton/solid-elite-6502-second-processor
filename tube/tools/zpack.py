#!/usr/bin/env python3
# zpack.py: the Master host's images packed for the disc (tube/build.sh), and
# unpacked again to check them. The format is the Master host's loader's
# (tube/src/loader.asm, LDC): a run of tokens, each
#   1-127      that many bytes follow, copied
#   128-255    (token - 127) zero bytes, 1-128
#   0          the end
# The images are sideways RAM banks and overlay storage, mostly empty pages and
# pages of the STA runs (which hstart's s_gen writes at the host's start, the
# disc holding only their pages' tails), so only their zero runs are packed.
#
#   python3 tube/tools/zpack.py IN OUT      pack IN into OUT
#   python3 tube/tools/zpack.py -u IN OUT   unpack
import sys


def pack(d):
    out, i, n = bytearray(), 0, len(d)
    while i < n:
        z = i
        while z < n and d[z] == 0 and z - i < 128:
            z += 1
        if z - i >= 2 or z == n:                # a zero run (two or more, or the tail)
            out.append(127 + z - i)
            i = z
            continue
        j = i                                   # literals, up to a run of two zeros
        while j < n and j - i < 127 and not (d[j] == 0 and j + 1 < n and d[j + 1] == 0):
            j += 1
        out.append(j - i)
        out += d[i:j]
        i = j
    out.append(0)
    return bytes(out)


def unpack(p):
    out, i = bytearray(), 0
    while p[i]:
        t = p[i]
        i += 1
        if t < 128:
            out += p[i:i + t]
            i += t
        else:
            out += bytes(t - 127)
    return bytes(out)


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[0] == "-u":
        open(a[2], "wb").write(unpack(open(a[1], "rb").read()))
    else:
        d = open(a[0], "rb").read()
        p = pack(d)
        assert unpack(p) == d, a[0]
        open(a[1], "wb").write(p)
