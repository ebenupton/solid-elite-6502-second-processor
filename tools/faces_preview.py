#!/usr/bin/env python3
"""Preview the filled ships of tools/faces.py.

Renders every ship type at a few orientations into a 256 x 192 MODE 1 space
view (CMYK inks, the faces' 2x2 dithers, detail lines in the hue's detail ink)
the way the port will: Elite's projection (x = 128 + 256 x / z, y = 96 - 256 y
/ z), Elite's face visibility (tools/faces.elite_xx2 models LL9 part 5's
arithmetic), the XX2 -> level tables, far-to-near painting of the visible faces.

It also checks, per view:
  * holes: pixels inside the ship's silhouette (all faces filled) that the
    visible faces leave uncovered;
  * winding: the screen winding of every filled face (expected clockwise, x
    right / y down);
  * stale vertices: a filled face using a vertex LL9 would not have projected.

    python3 tools/faces_preview.py      -> scratch/faces/<type>_<name>.png (2x),
                                           scratch/faces/contact_1.png, contact_2.png
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import faces as F                       # noqa: E402
import swatch35 as SW                   # noqa: E402
from PIL import Image, ImageDraw        # noqa: E402

OUTDIR = os.path.join(F.ROOT, 'scratch', 'faces')
W, H = 256, 192

VIEWS = [  # (yaw, pitch, roll) in degrees applied to the ZINF orientation (nose at us)
    (35, 20, 0),
    (110, -15, 10),
    (200, 30, -20),
    (-20, 75, 0),
]


def rotm(yaw, pitch, roll):
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    cr, sr = math.cos(math.radians(roll)), math.sin(math.radians(roll))
    Ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    Rx = [[1, 0, 0], [0, cp, -sp], [0, sp, cp]]
    Rz = [[cr, -sr, 0], [sr, cr, 0], [0, 0, 1]]

    def mm(a, b):
        return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return mm(Rz, mm(Rx, Ry))


def orientation(view):
    """(sidev, roofv, nosev) in view space: ZINF's (1,0,0), (0,1,0), (0,0,-1)
    rotated; det = -1, as TIDY keeps it (sidev = nosev x roofv)."""
    R = rotm(*view)
    vecs = [(1, 0, 0), (0, 1, 0), (0, 0, -1)]
    out = [tuple(sum(R[i][k] * v[k] for k in range(3)) for i in range(3)) for v in vecs]
    side = F._cross(out[2], out[1])
    assert max(abs(side[i] - out[0][i]) for i in range(3)) < 1e-9
    return out


def project(s, pos, M):
    pts = []
    for v in s['verts']:
        m = (v['x'], v['y'], v['z'])
        q = [pos[i] + sum(m[r] * M[r][i] for r in range(3)) for i in range(3)]
        pts.append((128 + 256 * q[0] / q[2], 96 - 256 * q[1] / q[2], q[2]))
    return pts


def fill(canvas, poly, cellmap):
    """Convex polygon fill, pixel centres, cellmap = {(x&1, y&1): ink}."""
    ys = [p[1] for p in poly]
    y0, y1 = max(0, math.ceil(min(ys) - 0.5)), min(H - 1, math.floor(max(ys) - 0.5))
    n = len(poly)
    for y in range(y0, y1 + 1):
        yc = y + 0.5
        xs = []
        for i in range(n):
            (ax, ay), (bx, by) = poly[i][:2], poly[(i + 1) % n][:2]
            if (ay <= yc < by) or (by <= yc < ay):
                xs.append(ax + (yc - ay) * (bx - ax) / (by - ay))
        if len(xs) < 2:
            continue
        xa, xb = min(xs), max(xs)
        for x in range(max(0, math.ceil(xa - 0.5)), min(W - 1, math.floor(xb - 0.5)) + 1):
            canvas[y][x] = cellmap[(x & 1, y & 1)] if cellmap is not None else 1


def line(canvas, a, b, ink):
    x0, y0, x1, y1 = round(a[0]), round(a[1]), round(b[0]), round(b[1])
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        x, y = round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n)
        if 0 <= x < W and 0 <= y < H:
            canvas[y][x] = ink


def render(t, s, view, dist=None):
    M = orientation(view)
    R = max(math.sqrt(v['x'] ** 2 + v['y'] ** 2 + v['z'] ** 2) for v in s['verts'])
    z = dist if dist else R * 256 / 72
    pos = (0, 0, z)
    xx2, zn = F.elite_xx2(s, pos, M)
    xx4 = min(31, int(z) >> 7) if int(z) < 4096 else 31
    pts = project(s, pos, M)
    projected = [any((g < len(xx2) and xx2[g]) or g == 15 for g in v['faces']) and v['vis'] >= xx4
                 for v in s['verts']]
    hue = F.SHIP_HUE[t]
    ramp = F.HUES[hue][1]
    cf = F.face_c(s)
    canvas = [[0] * W for _ in range(H)]
    sil = [[0] * W for _ in range(H)]
    issues = []
    order = []
    for f, p in enumerate(s['polys']):
        if not p:
            continue
        fill(sil, [pts[v] for v in p], None)
        if xx2[f]:
            order.append((sum(pts[v][2] for v in p) / len(p), f))
    levels = {}
    for _, f in sorted(order, reverse=True):
        p = s['polys'][f]
        poly = [pts[v] for v in p]
        area = sum(poly[i][0] * poly[(i + 1) % len(p)][1] - poly[(i + 1) % len(p)][0] * poly[i][1]
                   for i in range(len(p)))
        if area < -1:
            issues.append('face %d anticlockwise on screen (area %.0f)' % (f, area))
        for v in p:
            if not projected[v]:
                issues.append('face %d uses unprojected vertex %d' % (f, v))
        lv = F.FAR_LEVEL if xx2[f] == 255 else F.level_of(xx2[f], cf[f], zn)
        levels[f] = lv
        fill(canvas, poly, SW.cell(*SW.ALL[ramp[lv]]))
    ink = F.hue_detail_ink(hue)
    for i in s['detail']:
        e = s['edges'][i]
        if e['vis'] >= xx4 and (xx2[e['f1']] or xx2[e['f2']]):
            line(canvas, pts[e['v1']], pts[e['v2']], ink)
    holes = sum(1 for y in range(H) for x in range(W) if sil[y][x] and not canvas[y][x])
    # a hole pixel can legitimately be black dither: recount with a mask of fills
    return canvas, holes, issues, levels, xx2


def coverage_holes(t, s, view):
    """Silhouette pixels not covered by any visible face (ignores dither black):
    (count, mask)."""
    M = orientation(view)
    R = max(math.sqrt(v['x'] ** 2 + v['y'] ** 2 + v['z'] ** 2) for v in s['verts'])
    pos = (0, 0, R * 256 / 72)
    xx2, zn = F.elite_xx2(s, pos, M)
    pts = project(s, pos, M)
    sil = [[0] * W for _ in range(H)]
    cov = [[0] * W for _ in range(H)]
    for f, p in enumerate(s['polys']):
        if not p:
            continue
        fill(sil, [pts[v] for v in p], None)
        if xx2[f]:
            fill(cov, [pts[v] for v in p], None)
    mask = [[sil[y][x] and not cov[y][x] for x in range(W)] for y in range(H)]
    return sum(map(sum, mask)), mask


def _enc(c):
    c = c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
    return int(round(255 * c))


def to_image(canvas, scale=1, perceived=False, holes=None):
    """The canvas in the PHYS inks, or (perceived) each pixel replaced by the
    linear-light average of its aligned 2x2 cell, i.e. the dither as the eye
    blends it; holes (a mask) are painted red."""
    img = Image.new('RGB', (W, H))
    px = img.load()
    for y in range(H):
        for x in range(W):
            if perceived:
                x0, y0 = x & ~1, y & ~1
                cols = [SW.PHYS[canvas[y0 + j][x0 + i]] for i in (0, 1) for j in (0, 1)]
                px[x, y] = tuple(_enc(sum(F._lin(c[ch]) for c in cols) / 4) for ch in range(3))
            else:
                px[x, y] = SW.PHYS[canvas[y][x]]
            if holes and holes[y][x]:
                px[x, y] = (255, 0, 0)
    if scale != 1:
        img = img.resize((W * scale, H * scale), Image.NEAREST)
    return img


def main():
    ships = F.load_ships()
    for t, s in ships:
        F.reconstruct(s)
    os.makedirs(OUTDIR, exist_ok=True)
    cells = []
    total_bad = 0
    for t, s in ships:
        row, rowd = [], []
        for vw in VIEWS:
            canvas, _, issues, levels, xx2 = render(t, s, vw)
            holes, hmask = coverage_holes(t, s, vw)
            if holes > 2 or issues:
                total_bad += 1
            print('%2d %-28s view %-14s holes %4d  levels %s %s' % (
                t, s['name'], vw, holes,
                ' '.join('f%d:%d' % kv for kv in sorted(levels.items())),
                '; '.join(issues)))
            row.append(to_image(canvas, perceived=True, holes=hmask))
            rowd.append(to_image(canvas))
        sheet = Image.new('RGB', (len(VIEWS) * (W + 4), 2 * H + 4), (60, 60, 60))
        for i, im in enumerate(rowd):
            sheet.paste(im, (i * (W + 4), 0))
        for i, im in enumerate(row):
            sheet.paste(im, (i * (W + 4), H + 4))
        name = s['name'].split(' (')[0].replace(' ', '_').lower()
        sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(
            os.path.join(OUTDIR, '%02d_%s.png' % (t, name)))
        cells.append((t, s['name'], row))
    for k, chunk in enumerate((cells[:7], cells[7:])):
        cs = Image.new('RGB', (len(VIEWS) * (W + 4) + 4, len(chunk) * (H + 16) + 4), (60, 60, 60))
        d = ImageDraw.Draw(cs)
        for r, (t, name, row) in enumerate(chunk):
            y = 4 + r * (H + 16)
            d.text((6, y), '%d %s' % (t, name), fill=(255, 255, 255))
            for i, im in enumerate(row):
                cs.paste(im, (4 + i * (W + 4), y + 12))
        cs.save(os.path.join(OUTDIR, 'contact_%d.png' % (k + 1)))
    print('views with holes/issues:', total_bad)


if __name__ == '__main__':
    main()
