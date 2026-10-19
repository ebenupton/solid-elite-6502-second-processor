// Behavioural observables: the dashboard as each machine has drawn it, read back out of its
// screen memory (shadow RAM &7000-&7DFF) at every MLOOP in flight, and turned into values
// that the two dashboards should agree on although they look different:
//   * the 11 bars (shields, fuel, temperatures, altitude, speed, four energy banks): their
//     length and colour class (normal, danger, flashing). The original's mode 2 bars are
//     16 pixels long, the port's mode 1 bars 32, from the same values: the original's
//     length must be the port's halved, exactly, and the colour classes must match;
//   * the roll and pitch markers' positions (16 against 32 steps: within 2 of double);
//   * the four missile indicators (none, unarmed, armed, locked);
//   * the E.C.M. and space station bulbs (on or off);
//   * the scanner's and compass's dots: every EOR-drawn dot in the scanner area (the
//     screen XOR the dashboard image as the loader left it, at S%), as (x, line), x in
//     the 256-wide dashboard coordinates both use; matched within 3 in x and 1 line.
// The original's dashboard (P.DIALS2P, mode 2: two pixels a byte) and the port's
// (DIALS1, mode 1 CMYK: four pixels a byte) share the layout: 7 character rows of &200
// bytes from &7000, 8 bytes a character, so a pixel x (0-255) is in byte x DIV 4.
const ROWB = 0x200, BASE = 0x7000, SHADOW = 0x8000;
// bars: [name, row, panel byte offset, is it a marker]
export const DIALS = [
    ["FSH", 0, 0x20], ["ASH", 1, 0x20], ["FUEL", 2, 0x20], ["CABTMP", 3, 0x20], ["GNTMP", 4, 0x20], ["ALT", 5, 0x20],
    ["SPEED", 0, 0x1a0], ["ROLL", 1, 0x1a0, true], ["PITCH", 2, 0x1a0, true], ["ENERGY1", 3, 0x1a0], ["ENERGY2", 4, 0x1a0], ["ENERGY3", 5, 0x1a0], ["ENERGY4", 6, 0x1a0],
];
// the scanner and compass area: x from the left panel's bars' end to the right panel's start
const AREA = { x0: 50, x1: 206, y0: 0, y1: 56 };
// EOR bulbs: [name, address of the 16 bytes (two characters, lines 0-7)]
const BULBS = [["ECM", 0x7a70], ["STATION", 0x7b80]];

export class Observer {
    // m: an EliteMachine (lib.mjs); its kind ("mode2" for the original, "mode1" for the port)
    // is told by whether its symbols have the port's DILQ
    constructor(m) {
        this.m = m; this.q = [];
        this.mode = m.sy.DILQ !== undefined ? 1 : 2;
        const prev = m.onIter;
        m.onIter = mm => { if (prev) prev(mm); this.onIter(); };
        // the dashboard image as the loader left it, at the game's entry (S%)
        this.bg = null;
        m.onEntry = () => this.captureBackground();
    }
    scr(a) { return this.m.ram[SHADOW + a]; }
    // the colour number of pixel x (0-255 coordinates) on dashboard line y (0-55)
    pix(x, y, mem = null) {
        const a = BASE + (y >> 3) * ROWB + (x >> 2) * 8 + (y & 7);
        const b = mem ? mem[a - BASE] : this.scr(a);
        if (this.mode === 1) { const p = x & 3; return ((b >> (7 - p)) & 1) << 1 | ((b >> (3 - p)) & 1); }
        const p = (x >> 1) & 1;   // mode 2: two pixels a byte, each 2 units wide
        return p === 0 ? ((b >> 7) & 1) << 3 | ((b >> 5) & 1) << 2 | ((b >> 3) & 1) << 1 | ((b >> 1) & 1)
            : ((b >> 6) & 1) << 3 | ((b >> 4) & 1) << 2 | ((b >> 2) & 1) << 1 | (b & 1);
    }
    // the residual (screen XOR image) pixel, non-zero where something was EORed on
    rpix(x, y) {
        const a = BASE + (y >> 3) * ROWB + (x >> 2) * 8 + (y & 7);
        const b = this.scr(a) ^ this.bg[a - BASE];
        if (this.mode === 1) { const p = x & 3; return ((b >> (7 - p)) & 1) << 1 | ((b >> (3 - p)) & 1); }
        const p = (x >> 1) & 1;
        return p === 0 ? (b & 0xaa) && ((b >> 7) & 1) << 3 | ((b >> 5) & 1) << 2 | ((b >> 3) & 1) << 1 | ((b >> 1) & 1) : ((b >> 6) & 1) << 3 | ((b >> 4) & 1) << 2 | ((b >> 2) & 1) << 1 | (b & 1);
    }
    captureBackground() { this.bg = this.m.ram.slice(SHADOW + BASE, SHADOW + BASE + 0xe00); }

    onIter() {
        const m = this.m, sy = m.sy;
        if (!this.bg) return;
        // in flight (not docked, not on the title or the death screen), in a space view
        if (m.rb(sy.QQ12) || m.rb(sy.QQ11) || m.rb(sy.MCNT) === 0xff) return;
        this.q.push({ iter: m.iter, ...this.decode() });
    }

    decode() {
        const step = this.mode === 1 ? 1 : 2, max = this.mode === 1 ? 32 : 16;
        const out = { dials: {}, missiles: [], bulbs: {}, dots: [] };
        for (const [name, row, off, marker] of DIALS) {
            const x0 = (off / 8) * 4, y = row * 8 + 2;
            if (marker) {
                let pos = -1;
                for (let i = 0; i < max && pos < 0; i++) if (this.pix(x0 + i * step, y)) pos = i;
                out.dials[name] = { pos };
            } else {
                let len = 0;
                while (len < max && this.pix(x0 + len * step, y)) len++;
                // colour class of the first pixel
                const c = len ? this.pix(x0, y) : -1;
                out.dials[name] = { len, cls: this.colourClass(c, x0, y) };
            }
        }
        // missiles 1-4: SC = &7C60 - 16 X, line 3 (the full-width line of the shape)
        for (let X = 1; X <= 4; X++) {
            const a = 0x7c60 - 16 * X + 3, b = this.scr(a);
            out.missiles.push(this.missileClass(b));
        }
        for (const [name, a] of BULBS) {
            let on = 0;
            for (let i = 0; i < 16; i++) if (this.scr(a + i) !== this.bg[a + i - BASE]) on++;
            out.bulbs[name] = on > 0;
        }
        const d = this.dots();
        out.dots = d.dots; out.lit = d.lit;
        out.ships = this.shipDots();
        return out;
    }
    colourClass(c, x0, y) {
        if (c < 0) return "none";
        if (this.mode === 2) return c === 1 ? "danger" : c === 2 ? "flash" : "normal";
        // the port's colours are 2 x 2 dither cells, on an even line: danger &F5 (pixels
        // 2 3 2 3), flash &5F (1 3 1 3), the others solid (yellow 3, cyan 1): told by the
        // bar's first two pixels
        const c1 = this.pix(x0 + 1, y);
        return c === 2 && c1 === 3 ? "danger" : c === 1 && c1 === 3 ? "flash" : "normal";
    }
    missileClass(b) {
        if (this.mode === 2) {
            const c = ((b >> 7) & 1) << 3 | ((b >> 5) & 1) << 2 | ((b >> 3) & 1) << 1 | ((b >> 1) & 1);
            return c === 0 ? "none" : c === 2 ? "unarmed" : c === 3 ? "armed" : c === 1 ? "locked" : `c${c}`;
        }
        return b === 0 ? "none" : b === 0x0f ? "unarmed" : b === 0xff ? "armed" : (b === 0xfa || b === 0xf5) ? "locked" : `b${b.toString(16)}`;
    }
    // dots: runs of 3 or more lit residual units on a line (a stick is 1 unit in the port
    // and 2 in the original), runs on adjacent lines overlapping in x merged into one dot,
    // reported as (left x, lowest line, lines); and every lit residual unit (lit), for
    // matching dots that overlap (two dots EORed on top of each other no longer look
    // like dots, and do so differently in mode 1 and mode 2)
    dots() {
        const runs = [], lit = [];
        const skip = (x, y) => (y >= 40 && y < 48 && ((x >= 56 && x < 64) || (x >= 192 && x < 200)));   // the bulbs
        for (let y = AREA.y0; y < AREA.y1; y++) {
            let x = AREA.x0;
            while (x < AREA.x1) {
                if (skip(x, y) || !this.rpix(x, y)) { x++; continue; }
                let e = x;
                while (e < AREA.x1 && !skip(e, y) && this.rpix(e, y)) { lit.push(y * 256 + e); e++; }
                if (e - x >= 3) runs.push([x, e, y]);
                x = e;
            }
        }
        const dots = [];
        for (const [x, e, y] of runs) {
            const d = dots.find(d => d.y === y - 1 && x < d.e && e > d.x);
            if (d) { d.y = y; d.n++; d.x = Math.min(d.x, x); d.e = Math.max(d.e, e); }
            else dots.push({ x, e, y, n: 1 });
        }
        return { dots: dots.map(d => [d.x, d.y, d.n, d.e]).sort((a, b) => a[1] - b[1] || a[0] - b[0]), lit };
    }

    // where SCAN puts each ship's dot, from the K% slots as they are at MLOOP (both
    // machines' state is the same): [x, dashboard line], as the original's SCAN computes
    // X1 and Y1 (8-bit arithmetic and all)
    shipDots() {
        const m = this.m, sy = m.sy, out = [];
        for (let i = 0; i < 12; i++) {
            const type = m.rb(sy.FRIN + i);
            if (!type) break;
            if (type & 0x80) continue;
            const b = sy["K%"] + 37 * i, r = k => m.rb(b + k);
            if (!(r(31) & 0x10) || ((r(1) | r(4) | r(7)) & 0xc0)) continue;
            const x1 = (125 + (r(2) & 0x80 ? (-r(1)) & 255 : r(1))) & 0xfe;
            let a = r(7) >> 2, c = 0;
            if (r(8) & 0x80) { a ^= 255; c = 1; }
            const y2 = ((a + 35 + c) & 255) ^ 255;
            a = r(4) >> 1; c = 0;
            if (!(r(5) & 0x80)) { a ^= 255; c = 1; }
            let y1 = a + y2 + c; const neg = (y1 & 0x80) !== 0; y1 &= 255;
            y1 = !neg ? 246 : Math.min(246, Math.max(194, y1));
            out.push([x1, y1 - 192, type]);
        }
        return out;
    }

    // differences between the original's record r and the port's c
    static compare(r, c) {
        const out = [];
        for (const [name, , , marker] of DIALS) {
            const a = r.dials[name], b = c.dials[name];
            if (marker) {
                if ((a.pos < 0) !== (b.pos < 0) || (a.pos >= 0 && Math.abs(2 * a.pos - b.pos) > 2)) out.push({ what: `${name} marker`, ref: a.pos, cand: b.pos });
            } else {
                if (a.len !== b.len >> 1) out.push({ what: `${name} length`, ref: a.len, cand: b.len });
                else if (a.len && b.len > 1 && a.cls !== b.cls) out.push({ what: `${name} colour`, ref: a.cls, cand: b.cls });
            }
        }
        for (let i = 0; i < 4; i++) if (r.missiles[i] !== c.missiles[i]) out.push({ what: `missile ${i + 1}`, ref: r.missiles[i], cand: c.missiles[i] });
        for (const k of Object.keys(r.bulbs)) if (r.bulbs[k] !== c.bulbs[k]) out.push({ what: `${k} bulb`, ref: r.bulbs[k], cand: c.bulbs[k] });
        // dots: each one's area (x - 3 .. x + 4, its line and the ones either side: the port's
        // dots are two lines tall, the original's one line and a stick) must have
        // something EORed on in the other's screen; the compass's (x >= 184, lines < 24)
        // are told apart from the scanner's
        const near = (lit, [x, y]) => { const L = new Set(lit); for (let yy = y - 1; yy <= y + 1; yy++) for (let xx = x - 3; xx <= x + 4; xx++) if (L.has(yy * 256 + xx)) return true; return false; };
        const where = ([x, y]) => x >= 184 && y < 24 ? `compass ${x},${y}` : "scanner";
        let miss = r.dots.filter(d => !near(c.lit, d)), extra = c.dots.filter(d => !near(r.lit, d));
        // two or more ships' dots on top of each other: EOR mixes them, and the mixes differ
        // (the original's same-coloured dots cancel; the port's dither patterns don't): not a
        // difference in what the scanner shows (an expected difference)
        // (a blob of dots and sticks side by side: count the ships whose dots fall in its box)
        const overlap = ([x, y, n = 1, e = x + 3]) => (r.ships || []).filter(([sx, sy]) => sx >= x - 4 && sx <= e + 4 && sy >= y - n - 1 && sy <= y + 2).length >= 2;
        const ov = [...miss.filter(overlap), ...extra.filter(overlap)];
        if (ov.length) out.push({ what: "scanner dots overlapping (expected)", ref: miss.filter(overlap), cand: extra.filter(overlap), expected: true });
        miss = miss.filter(d => !overlap(d)); extra = extra.filter(d => !overlap(d));
        for (const w of new Set(miss.map(where))) out.push({ what: `${w} dot missing in port`, ref: miss.filter(d => where(d) === w), cand: null });
        for (const w of new Set(extra.map(where))) out.push({ what: `${w} dot extra in port`, ref: null, cand: extra.filter(d => where(d) === w) });
        return out;
    }
}
