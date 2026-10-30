#!/usr/bin/env node
// tstream.mjs: the command stream's bytes (parasite to host, register 1) over
// windows of a replayed run, by command and by field, from the host's side:
// every byte the host reads from register 1 (LDA, LDX or LDY HR1D), each
// command's from the dispatch of its opcode (hdisp) to the next. The stream
// is the parasite's, so it is the same on either host (--host B checks that).
//   TUBEMHZ=4 node tube/tools/tstream.mjs --log L --cand ssd --csyms psyms
//        [--host B] --windows 1000-1400,... [--out x.json]
// Per window, per iteration: bytes and commands by command, and the host's
// cycles by command (from hdisp to the next hloop, less the waits for the
// next byte, hrw, as thcmd.mjs); for C_DSPANS (cmds.asm) its fields (the
// opcode, the row bytes, the spans' XL, XR and colour, the next-row zeros,
// the &FF row marks, the end), how the rows follow each other, the spans per
// row and how often a span's colour, or its place, repeats an earlier span's;
// for C_SPANS the head, the rows and the empty rows. And at the parasite's
// psb, every disc span is checked against C_DSPANS's ranges (rows 1-191, XL
// 2-253, XL <= XR): "BAD" entries (from the host's side, a byte the
// instruction hook missed on a slice's first instruction can show as one).
import { readFileSync, writeFileSync } from "fs";
import { parseArgs } from "../../harness/args.mjs";
const a = parseArgs({ log: "value", host: "value", cand: "value", csyms: "value", hsyms: "value", windows: "value", out: "value" });
const { EliteMachine, loadSyms, CYCLES_PER_FRAME } = await import("../../master/tools/agentplay/lib.mjs");
const { TubeEliteMachine } = await import("./tmachine.mjs");
const { DEFAULTS, seedBytes } = await import("../../master/tools/agentplay/session.mjs");
const { COMMANDERS } = await import("../../master/tools/agentplay/styles.mjs");
const L = { rlog: new Map(), rjoy: [[], []], header: null };
for (const l of readFileSync(a.log, "utf8").split("\n")) { if (!l) continue; const e = JSON.parse(l); if (e.header) L.header = e; else if (e.p !== undefined) L.rlog.set(e.p, e); else if (e.j !== undefined) L.rjoy[e.w].push([e.j, e.v]); }
const H = L.header, rand = seedBytes(H.seed), cmdr = COMMANDERS[H.commander || "jameson"], patch = cmdr.patch ? m => cmdr.patch(m) : null;
const ptr = [0, 0];
const input = { rdkey: ctx => L.rlog.get(ctx.poll)?.k || [], dks5: ctx => { const e = L.rlog.get(ctx.poll); return !!(e && e.t === "d"); },
    joy(ctx) { const l = L.rjoy[ctx.which]; while (ptr[ctx.which] + 1 < l.length && l[ptr[ctx.which] + 1][0] <= ctx.joy) ptr[ctx.which]++; const e = l[ptr[ctx.which]]; return e && e[0] <= ctx.joy ? e[1] : 0x80; } };
const ref = new EliteMachine({ name: "ref", disc: DEFAULTS.ref, syms: loadSyms(DEFAULTS.rsyms), input: { rdkey: () => [], dks5: () => false, joy: () => 0x80 }, rand, patch });
await ref.boot(); for (let k = 0; k < 10000 && !ref.started; k++) ref.run(CYCLES_PER_FRAME);
const HB = a.host === "B";
const m = new TubeEliteMachine({ host: HB ? "B" : "Master", name: "t", disc: a.cand, syms: loadSyms(a.csyms), rand, patch, seedFrom: ref, input });
await m.boot();
const host = m.host;
const dir = a.csyms.replace(/[^/]*$/, "");
const hs = loadSyms(a.hsyms || dir + (HB ? "hbmsyms.txt" : "hsyms.txt"));
const HDISP = hs.hdisp, HLOOP = hs.hloop;
const HRW = HB ? 0x7fe0 : hs.hrw;
const inLoop = () => !HB || (host.romsel & 15) === 6;
const CN = {};
for (const l of readFileSync(new URL("../src/cmds.asm", import.meta.url), "utf8").split("\n")) { const mm = l.match(/^(C_[A-Z0-9_]+)\s*=\s*(\d+)/); if (mm) CN[+mm[2]] = mm[1]; }
const W = a.windows.split(",").map(s => s.split("-").map(Number));
const rd = x => host.readmem(x & 0xffff);
const now = () => host.cycleSeconds * 2e6 + host.currentCycles;

let act = [], on = false, cur = null, buf = [], viaReq = false, pendRead = 0, lastC = 0, inHrw = false, hrwS = 0;
const add = (o, k, d) => { o[k] = (o[k] || 0) + d; };
const acc = (f, k, d) => { for (const r of act) add(r[f], k, d); };
// a command's bytes, parsed
function flush() {
    if (cur === null || !on) { buf = []; return; }
    const name = CN[cur] || "C?" + cur, n = buf.length + (viaReq ? 0 : 1);
    acc("bytes", name, n); acc("ncmd", name, 1);
    if (name === "C_DSPANS") {
        // the opcode, the first row, then (xl, xr, col)*, each row's spans
        // followed by 0 (the next row) or &FF and the row (0: the end)
        let i = 0, prow = -9, r = -1, pcol = [-1, -1], spans = [], ps = null; const pspc = [null, null];
        acc("ds", "opcode", 1);
        const rowStart = nr => {
            if (r >= 0) { acc("dsr", "spans/row=" + Math.min(spans.length, 4), 1);
                if (ps && r === prow + 1 && spans.length === 1 && ps.length === 1) { const dl = spans[0][0] - ps[0][0], dr = spans[0][1] - ps[0][1];
                    acc("dsr", Math.abs(dl) < 8 && Math.abs(dr) < 8 ? "1-span after 1-span: both deltas in -8..7" : "1-span after 1-span: larger", 1); }
                prow = r; ps = spans; pspc[r & 1] = spans.map(q => q[2]); }
            r = nr; spans = []; if (nr < 0) return; acc("dsr", "rows", 1);
            acc("dsr", r === prow + 1 ? "row +1" : r === prow + 2 ? "row +2" : r === prow - 1 ? "row -1" : prow < 0 ? "first row" : "row other", 1);
            if (r === 0 || r > 191) acc("dsx", "BAD row " + r, 1);
        };
        const span = () => {
            const xl = buf[i], xr = buf[i + 1], c = buf[i + 2]; i += 3;
            acc("ds", "xl", 1); acc("ds", "xr", 1); acc("ds", "colour", 1); acc("dsr", "spans", 1);
            if (xl < 2 || xl > 253) acc("dsx", "BAD xl " + xl, 1);
            acc("dsr", c === pcol[r & 1] ? "colour same as last on parity" : "colour new", 1);
            pcol[r & 1] = c;
            if (spans.length) { const q = spans[spans.length - 1]; acc("dsx", xl === q[1] + 1 ? "contiguous with previous" : "gap from previous", 1); acc("dsx", c === q[2] ? "colour = previous in row" : "colour != previous in row", 1); }
            if (spans.length > 1) acc("dsx", c === spans[spans.length - 2][2] ? "colour = two back in row" : "colour != two back in row", 1);
            if (pspc[r & 1] && pspc[r & 1][spans.length] !== undefined) acc("dsx", c === pspc[r & 1][spans.length] ? "colour = same index, last row of parity" : "colour != same index, last row of parity", 1);
            spans.push([xl, xr, c]);
        };
        acc("ds", "row byte", 1); rowStart(buf[i++]);
        while (i < buf.length) {
            if (buf[i] === 0) { i++; acc("ds", "next row 0", 1); rowStart(r + 1); continue; }
            if (buf[i] === 0xff) { i++; acc("ds", "FF", 1); const nr = buf[i++]; if (nr === 0) { acc("ds", "end 0", 1); break; } acc("ds", "row byte", 1); rowStart(nr); continue; }
            span();
        }
        rowStart(-1);
        if (i !== buf.length) acc("dsx", "BAD length", 1);
    } else if (name === "C_SPANS") {
        acc("sp", "head (op, 4 colours, row)", 6);
        let rows = 0, empty = 0, i = 5;
        while (i < buf.length) { if (buf[i] === 0xff) { acc("sp", "end FF", 1); break; } if (buf[i] === 1 && buf[i + 1] === 1) empty++; rows++; i += 2; }
        acc("sp", "row pairs", rows * 2); acc("spr", "rows", rows); acc("spr", "empty rows", empty);
    }
    buf = [];
}
host.debugInstruction.add(pc => {
    const c = now();
    if (on && cur !== null && !inHrw && lastC) acc("hcyc", CN[cur] || "?", c - lastC);
    lastC = c;
    if (pendRead) { buf.push(pendRead === 0xad ? host.a : pendRead === 0xae ? host.x : host.y); pendRead = 0; }
    if (inHrw && host.s > hrwS) inHrw = false;
    if (pc === HRW && !inHrw) { inHrw = true; hrwS = host.s; }
    if (pc === HDISP && inLoop()) { flush(); cur = host.a; viaReq = rd(host.pc - 3) === 0xad && rd(host.pc - 2) === 0xe3; }
    else if (pc === HLOOP && inLoop()) { flush(); cur = null; }
    { const o = rd(pc); if ((o === 0xad || o === 0xae || o === 0xac) && rd(pc + 1) === 0xe1 && rd(pc + 2) === 0xfe && cur !== null) pendRead = o; }   // (LDA, LDX, LDY HR1D)
    return false;
});
// the parasite's side: every span psb sends (its row, XL and XR) checked
// against the stream's assumptions (rows 1-191, XL 2-253, XL <= XR)
const psy = loadSyms(a.csyms), pm = m.t.par.memory;
if (psy.psb !== undefined) m.t.addParHook(pc => {
    if (pc !== psy.psb || !on || pm[psy.ovl_cur] === 1) return false;   // (not while overlay D is in)
    const y = pm[0xf0], l = pm[0xec], r = pm[0xed];   // (pr_y, pr_a, pr_b: p-rast.asm)
    acc("psb", "spans", 1);
    if (y < 1 || y > 191) acc("psb", "BAD row " + y, 1);
    if (l < 2 || l > 253 || r < l || r > 253) acc("psb", "BAD span " + l + "-" + r, 1);
    return false;
});
const res = {};
m.onIter = mm => {
    for (const r of act) r.n++;
    for (const [x, y] of W) { const k = x + "-" + y; if (mm.iter === x) res[k] = { n: 0, bytes: {}, ncmd: {}, ds: {}, dsr: {}, dsx: {}, psb: {}, sp: {}, spr: {}, hcyc: {} }; }
    act = W.filter(([x, y]) => mm.iter >= x && mm.iter < y).map(([x, y]) => res[x + "-" + y]).filter(Boolean);
    on = act.length > 0;
};
const END = Math.max(...W.map(x => x[1]));
while (m.iter < END + 1) { m.run(CYCLES_PER_FRAME); m.snaps.length = 0; }
for (const r of Object.values(res)) for (const f of ["bytes", "ncmd", "ds", "dsr", "dsx", "psb", "sp", "spr", "hcyc"]) for (const k of Object.keys(r[f])) r[f][k] /= r.n;
if (a.out) writeFileSync(a.out, JSON.stringify(res));
const f1 = v => v.toFixed(1).padStart(9);
for (const [w, r] of Object.entries(res)) {
    const tot = Object.values(r.bytes).reduce((s, v) => s + v, 0);
    console.log(`== ${a.host || "Master"} ${w}: ${r.n} iterations, ${tot.toFixed(0)} bytes an iteration`);
    console.log(`   ${"command".padEnd(14)} ${"bytes".padStart(9)} ${"cmds".padStart(9)} ${"host cyc".padStart(9)} ${"cyc/byte".padStart(9)}`);
    for (const [k, v] of Object.entries(r.bytes).sort((x, y) => y[1] - x[1])) console.log(`   ${k.padEnd(14)} ${f1(v)} ${f1(r.ncmd[k])} ${f1(r.hcyc[k] || 0)} ${f1((r.hcyc[k] || 0) / v)}`);
    for (const f of ["ds", "dsr", "dsx", "psb", "sp", "spr"]) if (Object.keys(r[f]).length) console.log(`   ${f}: ` + Object.entries(r[f]).map(([k, v]) => `${k} ${v.toFixed(1)}`).join(", "));
}
process.exit(0);
