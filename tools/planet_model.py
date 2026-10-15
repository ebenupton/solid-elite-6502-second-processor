#!/usr/bin/env python3
"""Idealised model of the filled planet, and artefact statistics.

python3 tools/planet_model.py CAPDIR [--crops OUTDIR] [--hemi +1|-1] [--json F]

CAPDIR is the output of harness/planet-capture.mjs (frames.jsonl, screens.bin).
For every captured planet frame we build, per pixel of the disc as drawn
(R_NDISCL/R, which equal the exact disc |dx|^2+|dy|^2 <= r^2 clamped to the
clip window):

  S  the screen: colour A, B, ambiguous (A and B dither agree at this
     position) or other (covered by a ship/text/line: excluded)
  Q  the disc layer's request: R_NDP EOR (number of boundaries <= x)
  T  the true-geometry ideal: the visible hemisphere point p above the pixel
     centre, colour = [p.side > 0] EOR [p.roof > 0] (meridian planet) or
     [p.roof > 0.867 r] (crater), from the planet's orientation vectors
     (INWK) normalised; for the meridian planet the polarity is chosen per
     frame to fit best, and polarity changes between frames are counted
  E  the Elite-faithful ideal: Elite's own recorded polyline points, exact
     even-odd: each half ellipse is closed outside the disc (its two ends
     extended radially past the limb and joined round the outside on the
     side the frame layer's closure uses), a crater is a closed polygon

and count wrong pixels S vs T, S vs E, S vs Q (rasteriser) and Q vs E
(boundary construction), classified as
  near   within one pixel (3x3) of an ideal boundary: sub-pixel placement
  limb   within 2 pixels of the limb (and not near a boundary): slivers
  gross  elsewhere: wrong-colour runs (parity errors, closure cutting
         through the disc, dropped crossings)
"""
import json, sys, math, argparse, os
import numpy as np

ap = argparse.ArgumentParser()
ap.add_argument("cap")
ap.add_argument("--crops")
ap.add_argument("--hemi", type=float, default=0)
ap.add_argument("--json")
ap.add_argument("--worst", type=int, default=6)
ap.add_argument("--frames")
ap.add_argument("--sort", default="ST")
ap.add_argument("--sim", help="replace the screen and request by a simulated construction: 'analytic'")
args = ap.parse_args()

CL, CR, CT, CB = 2, 253, 1, 191


def s16(lo, hi):
    v = lo | (hi << 8)
    return v - 65536 if v >= 32768 else v


def sm16(lo, hi):  # sign-magnitude (INWK orientation vectors)
    v = lo | ((hi & 127) << 8)
    return -v if hi & 128 else v


def pattern(be, bo):
    """2x(4) pixel values of a dither pair: [row parity][x & 3]"""
    out = np.zeros((2, 4), np.int8)
    for r, b in enumerate((be, bo)):
        for p in range(4):
            out[r, p] = ((b >> (7 - p)) & 1) * 2 + ((b >> (3 - p)) & 1)
    return out


PA = pattern(0x05, 0x5A)
YY, XX = np.mgrid[0:192, 0:256]
# the laser sights (drawn over everything, not in the dirty extents)
SIGHTS = ((XX >= 106) & (XX <= 150) & (YY >= 94) & (YY <= 98)) | ((XX >= 126) & (XX <= 130) & (YY >= 74) & (YY <= 118))


def decode(scr):
    b = np.frombuffer(scr, np.uint8)
    # offset (y>>3)*512 + (y&7) + 8*c
    off = (YY >> 3) * 512 + (YY & 7) + 8 * (XX >> 2)
    byte = b[off].astype(np.int16)
    p = XX & 3
    return (((byte >> (7 - p)) & 1) * 2 + ((byte >> (3 - p)) & 1)).astype(np.int8)


def row_parity(edges, shape_rows):
    """even-odd inside test at pixel centres for a closed polygon given as a
    list of (x0, y0, x1, y1) edges; returns bool array [192, 256]"""
    ins = np.zeros((192, 256), bool)
    E = np.array(edges, float)
    if len(E) == 0:
        return ins
    x0, y0, x1, y1 = E.T
    for y in shape_rows:
        lo = np.minimum(y0, y1); hi = np.maximum(y0, y1)
        m = (lo <= y) & (y < hi)
        if not m.any():
            continue
        t = (y - y0[m]) / (y1[m] - y0[m])
        xc = x0[m] + t * (x1[m] - x0[m])
        cnt = (XX[0][None, :] >= xc[:, None]).sum(0)  # pixel centre x >= crossing
        ins[y] = cnt & 1
    return ins


def frame_model(f, scr):
    cx, cy, r = s16(*f["plx"]), s16(*f["ply"]), f["plr"]
    typ = f["plt"]
    # disc as requested
    disc = np.zeros((192, 256), bool)
    for y in range(f["ndt"], f["ndb"] + 1):
        l, rr = f["ndl"][y], f["ndr"][y]
        if l <= rr:
            disc[y, l:rr + 1] = True
    # exact disc for comparison
    dx = XX - cx; dy = YY - cy
    udisc = dx * dx + dy * dy <= r * r
    edisc = udisc & (XX >= CL) & (XX <= CR) & (YY >= CT) & (YY <= CB)
    # screen classes
    S = decode(scr)
    PB = pattern(f["dbe"], f["dbo"])
    ea = PA[YY & 1, XX & 3]; eb = PB[YY & 1, XX & 3]
    isA = S == ea; isB = S == eb
    # occluded: dirty extents of this buffer (ships, lines, dots, text) or
    # matching neither colour
    dirty = np.zeros((192, 256), bool)
    for y in range(192):
        l, rr = f["dirl"][y], f["dirr"][y]
        if rr and l <= rr:
            dirty[y, l:rr + 1] = True
    amb = isA & isB
    other = disc & ~dirty & ~(isA | isB)
    # overlay pixels (text, sights: not in the dirty extents) can match a
    # disc colour by chance: exclude everything within 2 pixels of one
    valid = disc & ~dirty & (isA | isB) & ~neighbourhood(other, 2) & ~SIGHTS
    Scol = isB & ~isA  # True = B (ambiguous counted as A, masked below)
    # request
    Q = np.zeros((192, 256), bool)
    if f["ndf"]:
        for y in range(f["ndt"], f["ndb"] + 1):
            c = np.full(256, f["ndp"][y] & 1, np.int8)
            for k in range(f["ndn"][y]):
                c[f["ndx"][k][y]:] ^= 1
            Q[y] = c.astype(bool)
    if args.sim == "analytic" and typ == 128 and f["ncv"] > 0:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import planet_analytic as PA_
        rows = PA_.analytic_rows(cx, cy, r, PA_.frame_normals(f["pl"]["inwk"]), f["ndt"], f["ndb"], f["ndl"], f["ndr"])
        Q = np.zeros((192, 256), bool)
        for y, (p0, xs) in rows.items():
            c = np.full(256, p0 & 1, np.int8)
            for x0 in xs:
                c[x0:] ^= 1
            Q[y] = c.astype(bool)
        Scol = Q.copy()
        valid = disc & ~SIGHTS
        amb = np.zeros_like(amb)
    # true geometry
    iw = f["pl"]["inwk"] if f["pl"] else None
    T = None; Tinfo = {}
    if iw is not None:
        nose = np.array([sm16(iw[9], iw[10]), sm16(iw[11], iw[12]), sm16(iw[13], iw[14])], float)
        roof = np.array([sm16(iw[15], iw[16]), sm16(iw[17], iw[18]), sm16(iw[19], iw[20])], float)
        side = np.array([sm16(iw[21], iw[22]), sm16(iw[23], iw[24]), sm16(iw[25], iw[26])], float)
        nose /= np.linalg.norm(nose); roof /= np.linalg.norm(roof); side /= np.linalg.norm(side)
        X = (XX - cx).astype(float); Y = (cy - YY).astype(float)
        Z = np.sqrt(np.maximum(r * r - X * X - Y * Y, 0)) * HEMI
        if typ == 128:
            a = X * side[0] + Y * side[1] + Z * side[2] > 0
            b = X * roof[0] + Y * roof[1] + Z * roof[2] > 0
            T = a ^ b
        else:
            T = (X * roof[0] + Y * roof[1] + Z * roof[2]) > 0.867 * r
        Tinfo = dict(nose=nose, roof=roof, side=side)
    # Elite-faithful
    E = np.zeros((192, 256), bool)
    rows = range(max(0, f["ndt"]), min(191, f["ndb"]) + 1)
    px = [s16(l, h) for l, h in zip(f["pxl"], f["pxh"])]
    py = [s16(l, h) for l, h in zip(f["pyl"], f["pyh"])]
    for ci in range(f["ncv"]):
        s, e = f["cvs"][ci], f["cve"][ci]
        pts = list(zip(px[s:e], py[s:e]))
        if len(pts) < 2:
            continue
        edges = [(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1]) for i in range(len(pts) - 1)]
        if f["cvt"][ci] < 40:
            (x1, y1), (x2, y2) = pts[0], pts[-1]
            n = np.array([-(y2 - y1), x2 - x1], float)
            R = 2.0 * r + 8
            th1 = math.atan2(y1 - cy, x1 - cx); th2 = math.atan2(y2 - cy, x2 - cx)
            # go from th2 to th1 round the side n points to
            d = (th1 - th2) % (2 * math.pi)  # ccw sweep (in screen coords)
            mid = th2 + d / 2
            if math.cos(mid) * n[0] + math.sin(mid) * n[1] < 0:
                d -= 2 * math.pi
            path = [(x2, y2)]
            for k in range(25):
                th = th2 + d * k / 24
                path.append((cx + R * math.cos(th), cy + R * math.sin(th)))
            path.append((x1, y1))
            edges += [(path[i][0], path[i][1], path[i + 1][0], path[i + 1][1]) for i in range(len(path) - 1)]
        else:
            if pts[0] != pts[-1]:
                edges.append((pts[-1][0], pts[-1][1], pts[0][0], pts[0][1]))
        E ^= row_parity(edges, rows)
    return dict(cx=cx, cy=cy, r=r, typ=typ, disc=disc, edisc=edisc, udisc=udisc, valid=valid, amb=amb, other=other,
                S=Scol, Q=Q, T=T, E=E, Tinfo=Tinfo)


def neighbourhood(m, k=1):
    """dilate a bool mask by a (2k+1)^2 box"""
    out = m.copy()
    for dy in range(-k, k + 1):
        for dx in range(-k, k + 1):
            if dx == 0 and dy == 0:
                continue
            out |= np.roll(np.roll(m, dy, 0), dx, 1)
    return out


def boundary_mask(I, disc):
    """pixels within 1 (3x3) of a colour change of ideal I (inside the disc)"""
    ch = np.zeros_like(I)
    ch[:, 1:] |= I[:, 1:] != I[:, :-1]
    ch[:, :-1] |= I[:, 1:] != I[:, :-1]
    ch[1:, :] |= I[1:, :] != I[:-1, :]
    ch[:-1, :] |= I[1:, :] != I[:-1, :]
    return neighbourhood(ch, 1)


def classify(wrong, I, m):
    near = wrong & boundary_mask(I, m["disc"])
    limbzone = neighbourhood(~m["udisc"], 2)
    limb = wrong & ~near & limbzone
    gross = wrong & ~near & ~limb
    return near.sum(), limb.sum(), gross.sum(), gross


frames = [json.loads(l) for l in open(os.path.join(args.cap, "frames.jsonl"))]
scrs = open(os.path.join(args.cap, "screens.bin"), "rb").read()
sel = None
if args.frames:
    a, b = map(int, args.frames.split("-"))
    sel = (a, b)

# hemisphere: decide from the data if not given (the one T fits E best)
HEMI = args.hemi
if HEMI == 0:
    best = {}
    for h in (1.0, -1.0):
        HEMI = h; tot = 0
        for i, f in enumerate(frames[:400]):
            if f["ncv"] == 0 or not f["pl"] or f["plt"] != 128:
                continue
            m = frame_model(f, scrs[i * 12288:(i + 1) * 12288])
            v = m["valid"]
            w = ((m["T"] != m["E"]) & v).sum(); w2 = ((~m["T"] != m["E"]) & v).sum()
            tot += min(w, w2)
        best[h] = tot
    HEMI = min(best, key=best.get)
    print(f"hemisphere: z sign {HEMI:+.0f} (T vs E wrong pixels {best})")

stats = []
prevpol = None
for i, f in enumerate(frames):
    if sel and not (sel[0] <= f["iter"] <= sel[1]):
        continue
    m = frame_model(f, scrs[i * 12288:(i + 1) * 12288])
    v = m["valid"]
    nv = v.sum()
    st = dict(iter=f["iter"], i=i, r=m["r"], cx=m["cx"], cy=m["cy"], typ=m["typ"], ncv=f["ncv"], npix=int(nv),
              other=int(m["other"].sum()), discmis=int((m["disc"] != m["edisc"]).sum()))
    ambm = m["amb"]
    vv = v & ~ambm
    # rasteriser: screen vs request
    wq = (m["S"] != m["Q"]) & vv
    st["SQ"] = int(wq.sum())
    if f["ncv"] > 0:
        # construction: request vs Elite-faithful, and screen vs E
        for name, I in (("E", m["E"]),):
            wr = (m["S"] != I) & vv
            n_, l_, g_, gm = classify(wr, I, m)
            st[f"S{name}"] = (int(n_), int(l_), int(g_))
            wr = (m["Q"] != I) & m["disc"]
            n_, l_, g_, _ = classify(wr, I, m)
            st[f"Q{name}"] = (int(n_), int(l_), int(g_))
        if m["T"] is not None:
            T = m["T"]
            if m["typ"] == 128:
                w1 = ((m["S"] != T) & vv).sum(); w2 = ((m["S"] != ~T) & vv).sum()
                pol = 0 if w1 <= w2 else 1
                if pol:
                    T = ~T
                st["pol"] = pol
            wr = (m["S"] != T) & vv
            n_, l_, g_, gm = classify(wr, T, m)
            st["ST"] = (int(n_), int(l_), int(g_))
            wr = (m["E"] != T) & m["disc"]
            n_, l_, g_, _ = classify(wr, T, m)
            st["ET"] = (int(n_), int(l_), int(g_))
            st["_gm"] = gm
    st["_m"] = m
    stats.append(st)

# polarity flips between consecutive frames of the same meridian planet
flips = 0; pp = None; pit = None
for st in stats:
    if "pol" in st:
        if pp is not None and st["iter"] == pit + 1 and st["pol"] != pp:
            flips += 1
        pp = st["pol"]; pit = st["iter"]

curved = [s for s in stats if s["ncv"] > 0]
print(f"frames with the planet as disc layer: {len(stats)}, with curves: {len(curved)} "
      f"(meridian {sum(1 for s in curved if s['typ']==128)}, crater {sum(1 for s in curved if s['typ']!=128)})")
print(f"disc shape mismatches (request vs exact disc): {sum(s['discmis'] for s in stats)} pixels")
print(f"screen vs request (rasteriser, all planet frames): {sum(s['SQ'] for s in stats)} pixels in "
      f"{sum(1 for s in stats if s['SQ'])} frames")
print(f"meridian polarity changes between consecutive frames: {flips}")


def summ(key, lab):
    arr = np.array([s[key] for s in curved if key in s])
    if len(arr) == 0:
        return
    tot = arr.sum(0)
    npx = sum(s["npix"] for s in curved if key in s)
    fr_g = (arr[:, 2] > 0).sum()
    print(f"{lab:34s} near {tot[0]:7d}  limb {tot[1]:7d}  gross {tot[2]:7d}   per frame: "
          f"{tot[0]/len(arr):7.1f} {tot[1]/len(arr):6.1f} {tot[2]/len(arr):7.1f}  "
          f"frames with gross {fr_g}/{len(arr)}  max gross {arr[:,2].max()}  ({npx} disc px)")


summ("ST", "screen vs true ideal")
summ("SE", "screen vs Elite-faithful ideal")
summ("QE", "request vs Elite-faithful")
summ("ET", "Elite-faithful vs true (limit)")
for typ, nm in ((128, "meridian"), (130, "crater")):
    sub = [s for s in curved if s["typ"] == typ]
    if not sub:
        continue
    for key in ("ST", "SE"):
        arr = np.array([s[key] for s in sub if key in s])
        if len(arr):
            print(f"  {nm:8s} {key}: near/limb/gross per frame {arr[:,0].mean():.1f} {arr[:,1].mean():.1f} {arr[:,2].mean():.1f}")

# by iteration window
print("gross (screen vs true) by window:")
for w in range(0, 3000, 200):
    sub = [s for s in curved if w <= s["iter"] < w + 200 and "ST" in s]
    if sub:
        a = np.array([s["ST"] for s in sub])
        print(f"  {w:5d}-{w+199:5d}: {len(sub):4d} frames r {min(s['r'] for s in sub)}-{max(s['r'] for s in sub)} "
              f"near {a[:,0].mean():6.1f} limb {a[:,1].mean():5.1f} gross {a[:,2].mean():7.1f}")

if args.json:
    json.dump([{k: v for k, v in s.items() if not k.startswith("_")} for s in stats], open(args.json, "w"))

if args.crops:
    from PIL import Image
    os.makedirs(args.crops, exist_ok=True)
    pal = {0: (0, 0, 0), 1: (0, 255, 255), 2: (255, 0, 255), 3: (255, 255, 0)}

    def img_of(m, which):
        im = np.zeros((192, 256, 3), np.uint8)
        I = m[which]
        im[m["disc"] & ~I] = (40, 60, 160)
        im[m["disc"] & I] = (40, 160, 60)
        return im

    key = args.sort
    pool = stats if key == "SQ" else [s for s in curved if key in s]
    worst = sorted(pool, key=lambda s: -(s[key] if key == "SQ" else s[key][2]))[:args.worst]
    for s in worst:
        m = s["_m"]
        rows = []
        for which in ("S", "Q", "E", "T"):
            if which == "T" and m["T"] is None:
                I = np.zeros((192, 256), bool)
            else:
                I = m[which] if which != "T" else (m["T"] if not s.get("pol") else ~m["T"])
            im = np.zeros((192, 256, 3), np.uint8)
            im[m["disc"] & ~I] = (40, 60, 160)
            im[m["disc"] & I] = (40, 170, 60)
            if which == "S":
                im[m["other"]] = (200, 200, 200)
                if key == "SQ":
                    im[m["valid"] & ~m["amb"] & (m["S"] != m["Q"])] = (255, 40, 40)
                elif "_gm" in s:
                    im[m["valid"] & s["_gm"]] = (255, 40, 40)
            rows.append(im)
        big = np.concatenate(rows, 1)
        Image.fromarray(big).resize((big.shape[1] * 2, big.shape[0] * 2), Image.NEAREST).save(
            os.path.join(args.crops, f"worst{key}_it{s['iter']:05d}.png"))
    print("crops: screen (red = gross vs T), request, Elite-faithful, true ->", args.crops)
