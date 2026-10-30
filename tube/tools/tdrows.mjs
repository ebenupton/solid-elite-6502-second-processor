#!/usr/bin/env node
// tdrows.mjs: the disc layer's rows checked one by one (p-rast.asm's R_DISCROWS,
// p-disc.asm's surface), on any build of the Tube: replays an agentplay input log
// and, at each frame's disc layer (pdr0 .. ps_end), works out from the frame's
// inputs what each row of the band must show (the new span in colour A, flipping
// to B and back at each boundary; black where the old span or the dirty extent
// was) and checks the spans the parasite sent (psb) against it, starting from
// what this model says the buffer showed (its last frame's rows; the dirty
// extents unknown). A row is wrong if a pixel of the new span, the old span or
// the dirty extent ends other than it must, or a pixel outside them is written;
// unverified if it ends on a pixel the model does not know (the first frames).
// The model takes the parasite's own result as the buffer's next state, so one
// error is counted once. The colours are compared as the bytes sent.
//
//   TUBEMHZ=4 node tube/tools/tdrows.mjs --log L --cand ssd --csyms psyms
//        --windows 300-403,1000-1400,5355-5457 [--host B] [--verbose N]
import { EliteMachine, loadSyms, CYCLES_PER_FRAME } from "../../master/tools/agentplay/lib.mjs";
import { TubeEliteMachine } from "./tmachine.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { readFileSync } from "fs";

const a = parseArgs({ log: "value", host: "value", cand: "value", csyms: "value", windows: "value", verbose: "value" });
const L = { rlog: new Map(), rjoy: [[], []], header: null };
for (const l of readFileSync(a.log, "utf8").split("\n")) { if (!l) continue; const e = JSON.parse(l); if (e.header) L.header = e; else if (e.p !== undefined) L.rlog.set(e.p, e); else if (e.j !== undefined) L.rjoy[e.w].push([e.j, e.v]); }
const H = L.header, rand = seedBytes(H.seed), cmdr = COMMANDERS[H.commander || "jameson"], patch = cmdr.patch ? m => cmdr.patch(m) : null;
const ptr = [0, 0];
const input = { rdkey: ctx => L.rlog.get(ctx.poll)?.k || [], dks5: ctx => { const e = L.rlog.get(ctx.poll); return !!(e && e.t === "d"); },
    joy(ctx) { const l = L.rjoy[ctx.which]; while (ptr[ctx.which] + 1 < l.length && l[ptr[ctx.which] + 1][0] <= ctx.joy) ptr[ctx.which]++; const e = l[ptr[ctx.which]]; return e && e[0] <= ctx.joy ? e[1] : 0x80; } };
const ref = new EliteMachine({ name: "ref", disc: DEFAULTS.ref, syms: loadSyms(DEFAULTS.rsyms), input: { rdkey: () => [], dks5: () => false, joy: () => 0x80 }, rand, patch });
await ref.boot(); for (let k = 0; k < 10000 && !ref.started; k++) ref.run(CYCLES_PER_FRAME);
const sy = loadSyms(a.csyms);
const m = new TubeEliteMachine({ host: a.host || "Master", name: "t", disc: a.cand, syms: sy, rand, patch, seedFrom: ref, input });
await m.boot();
const W = a.windows.split(",").map(s => s.split("-").map(Number));
const par = m.t.par, pm = par.memory;
let VERB = +(a.verbose || 0);

// the zero page and constants the tool reads (p-io.asm, p-rast.asm)
const R_DCE = 0x0e, R_DCO = 0x0f, pr_y = 0xf0, pr_a = 0xec, pr_b = 0xed, pr_ce = 0xf1, pr_co = 0xf2;
const need = ["pdr0", "ps_end", "psb", "T_RESETBUF", "R_INIT", "r_buf", "r_bt", "r_bb", "R_NDT", "R_NDB", "R_NDF", "R_NDN", "R_NDX0", "R_NDX1", "R_NDX2", "R_NDX3",
    "R_NDISCL", "R_NDISCR", "R_DBE", "R_DBO", "R_DISCL0", "R_DISCR0", "R_DISCL1", "R_DISCR1", "R_DIRTYL0", "R_DIRTYR0", "R_DIRTYL1", "R_DIRTYR1", "ovl_cur", "OVL_START"];
for (const n of need) if (sy[n] === undefined) { console.error("no symbol " + n); process.exit(2); }
const inS = pc => pc < sy.OVL_START || pc >= 0xf800 || pm[sy.ovl_cur] !== 1;   // (overlay S's labels: not while D is in)

// the model: per buffer, row and pixel, the byte it shows (UNK: not known)
const UNK = 256;
const model = [new Uint16Array(192 * 256).fill(UNK), new Uint16Array(192 * 256).fill(UNK)];
let snap = null, spans = null, on = false;
const st = { frames: 0, rows: 0, wrong: 0, unver: 0, stray: 0, blank: 0, desync: 0, spans: 0 };
const span = (lo, hi, y) => { const L = pm[lo + y], R = pm[hi + y]; return L === 255 || L > R ? null : [L, R]; };
m.t.addParHook(pc => {
    if (pc === sy.pdr0 && inS(pc)) {
        const b = pm[sy.r_buf] & 1, o = b ? [sy.R_DISCL1, sy.R_DISCR1, sy.R_DIRTYL1, sy.R_DIRTYR1] : [sy.R_DISCL0, sy.R_DISCR0, sy.R_DIRTYL0, sy.R_DIRTYR0];
        snap = { b, old: [], dirty: [], it: m.iter };
        for (let y = 0; y < 192; y++) { snap.old.push(span(o[0], o[1], y)); snap.dirty.push(span(o[2], o[3], y)); }
        spans = [];
    } else if (pc === sy.psb && snap && inS(pc)) {
        const y = pm[pr_y]; spans.push([y, pm[pr_a], pm[pr_b], (y & 1) ? pm[pr_co] : pm[pr_ce]]);
    } else if (pc === sy.ps_end && snap && inS(pc)) {
        check(); snap = null;
    } else if ((pc === sy.T_RESETBUF || pc === sy.R_INIT) && inS(pc)) {
        // (the buffer's state forgotten, as the screen is cleared: nothing known)
        if (pc === sy.R_INIT) { model[0].fill(UNK); model[1].fill(UNK); } else model[pm[sy.r_buf] & 1].fill(UNK);
    }
    return false;
});
function check() {
    const b = snap.b, M = model[b], bt = pm[sy.r_bt], bb = pm[sy.r_bb], nt = pm[sy.R_NDT], nb = pm[sy.R_NDB], ndf = pm[sy.R_NDF];
    const A = [pm[R_DCE], pm[R_DCO]], B = [pm[sy.R_DBE], pm[sy.R_DBO]];
    const byRow = new Map();
    for (const s of spans) { if (!byRow.has(s[0])) byRow.set(s[0], []); byRow.get(s[0]).push(s); }
    st.frames += on; st.spans += on ? spans.length : 0;
    if (bb < bt) return;
    for (let y = bt; y <= bb; y++) {
        const os = snap.old[y], ds = snap.dirty[y];
        // the model's old row against the parasite's own record of its span
        const row = new Uint16Array(256);
        for (let x = 0; x < 256; x++) row[x] = os && x >= os[0] && x <= os[1] ? M[y * 256 + x] : UNK;
        if (on && os) { let mo = null; for (let x = 0; x < 256; x++) if (M[y * 256 + x] !== UNK && M[y * 256 + x] !== 0) { mo ||= [x, x]; mo[1] = x; }
            if (mo && (mo[0] !== os[0] || mo[1] !== os[1])) st.desync++; }
        if (ds) for (let x = ds[0]; x <= ds[1]; x++) row[x] = UNK;
        // what the row must show: the new span, colour A flipping at each boundary
        const ns = y >= nt && y <= nb ? span(sy.R_NDISCL, sy.R_NDISCR, y) : null;
        const want = new Int16Array(256).fill(-1);       // -1: outside (untouched)
        if (os) for (let x = os[0]; x <= os[1]; x++) want[x] = 0;
        if (ds) for (let x = ds[0]; x <= ds[1]; x++) want[x] = 0;
        if (ns) {
            const n = ndf ? pm[sy.R_NDN + y] : 0, cnt = n & 0x7f, bx = [sy.R_NDX0, sy.R_NDX1, sy.R_NDX2, sy.R_NDX3].slice(0, cnt).map(z => pm[z + y]);
            for (let x = ns[0]; x <= ns[1]; x++) { let c = n >> 7; for (const v of bx) if (v <= x) c ^= 1; want[x] = c ? B[y & 1] : A[y & 1]; }
        }
        let wrong = false, unver = false, stray = false;
        // (black written outside the old span and the dirty extent, where the
        // row is black already, is no stray write: the strips between two
        // spans apart do so)
        let blank = false;
        for (const [, l, r, c] of byRow.get(y) || []) for (let x = l; x <= r; x++) { if (want[x] < 0) { if (c) stray = true; else blank = true; } row[x] = c; }
        for (let x = 0; x < 256; x++) if (want[x] >= 0) { if (row[x] === UNK) unver = true; else if (row[x] !== want[x]) wrong = true; }
        if (on) { st.rows++; st.wrong += wrong; st.unver += unver && !wrong; st.stray += stray; st.blank += blank;
            if ((wrong || stray) && VERB-- > 0) console.log(`iteration ${snap.it} buffer ${b} row ${y}: ${wrong ? "wrong" : ""} ${stray ? "stray write" : ""} old ${os} dirty ${ds} new ${ns} n ${pm[sy.R_NDN + y].toString(16)} spans ${JSON.stringify(byRow.get(y) || [])}`); }
        // the buffer now: the row as written, outside the spans unknown
        for (let x = 0; x < 256; x++) M[y * 256 + x] = want[x] >= 0 && want[x] !== 0 ? row[x] : (want[x] === 0 && row[x] === 0 ? 0 : UNK);
    }
}
m.onIter = mm => { const w = W.find(([x, y]) => mm.iter >= x && mm.iter < y); on = !!w; };
const END = Math.max(...W.map(x => x[1]));
while (m.iter < END) { m.run(CYCLES_PER_FRAME); m.snaps.length = 0; }
console.log(`disc layer rows, iterations ${a.windows}: ${st.frames} frames, ${st.rows} band rows, ${st.spans} spans; ${st.wrong} wrong, ${st.stray} with a stray write (${st.blank} with black over black outside), ${st.unver} unverified (the model unsure), ${st.desync} spans unlike the model's`);
process.exit(st.wrong || st.stray ? 1 : 0);
