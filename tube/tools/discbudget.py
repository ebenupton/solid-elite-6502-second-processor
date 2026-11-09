#!/usr/bin/env python3
# discbudget.py: the DFS catalogue of each SSD given, as the disc budget
# (tube/build.sh prints it for the Tube's disc): each file's name, load
# and execution addresses, length and sectors, then the disc's sectors used of
# 800 (an 80-track single-sided disc, the catalogue's 2 included), the files
# of 31, and the free sectors after the last file (where DFS puts a save).
#
#   python3 tube/tools/discbudget.py DISC.ssd... [--files]
import sys

args = [x for x in sys.argv[1:] if not x.startswith("--")]
for fn in args:
    d = open(fn, "rb").read()
    n = d[0x105] // 8
    total = ((d[0x106] & 3) << 8) | d[0x107]
    files, used_top = [], 2
    for i in range(n):
        e0, e1 = d[8 + i * 8:16 + i * 8], d[0x108 + i * 8:0x110 + i * 8]
        name = (chr(e0[7] & 127) + "." + e0[:7].decode("latin-1")).rstrip()
        hi = e1[6]
        top = lambda b: 0xFF0000 if b == 3 else b << 16     # (&FFxxxx: the host's memory)
        load = e1[0] | e1[1] << 8 | top((hi >> 2) & 3)
        exe = e1[2] | e1[3] << 8 | top((hi >> 6) & 3)
        ln = e1[4] | e1[5] << 8 | ((hi >> 4) & 3) << 16
        start = ((hi & 3) << 8) | e1[7]
        secs = (ln + 255) // 256
        files.append((start, name, load, exe, ln, secs))
        used_top = max(used_top, start + secs)
    files.sort()
    used = 2 + sum(f[5] for f in files)
    print("%s: %d files of 31, %d sectors of %d used (catalogue 2), %d free after the last file"
          % (fn, n, used, total, total - used_top))
    if "--files" in sys.argv:
        for start, name, load, exe, ln, secs in files:
            print("  %-10s load &%06X exec &%06X  %6d bytes  %3d sectors  (from sector %d)" % (name, load, exe, ln, secs, start))
