#!/usr/bin/env python3
"""raw2png.py IN.raw OUT.png [--diff OTHER.raw]: decode a frame dump (two 12K
MODE 1 buffers, as tfbreplay/mfbdump write them) to a PNG, buffers side by
side, CMYK palette; with --diff, pixels that differ from OTHER are red"""
import sys, zlib, struct
def load(p):
    d = open(p, "rb").read(); out = []
    for b in range(2):
        img = [[0]*256 for _ in range(192)]
        for y in range(192):
            for c in range(64):
                v = d[b*0x3000 + (y//8)*0x200 + c*8 + y%8]
                for p in range(4):
                    img[y][c*4+p] = ((v >> (7-p)) & 1) << 1 | ((v >> (3-p)) & 1)
        out.append(img)
    return out
pal = [(0,0,0),(0,255,255),(255,0,255),(255,255,0)]
a = load(sys.argv[1]); other = load(sys.argv[sys.argv.index("--diff")+1]) if "--diff" in sys.argv else None
W, H = 256*2+8, 192
rows = []
for y in range(H):
    r = bytearray([0])
    for b in range(2):
        for x in range(256):
            px = pal[a[b][y][x]]
            if other and other[b][y][x] != a[b][y][x]: px = (255,0,0)
            r += bytes(px)
        if b == 0: r += bytes((80,80,80))*8
    rows.append(bytes(r))
raw = b"".join(rows)
def chunk(t, d): return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t+d) & 0xffffffff)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")
open(sys.argv[2], "wb").write(png)
