#!/usr/bin/env node
// hctx.mjs: which host code and data the Tube build's Master host uses in
// which paging context, over a replayed run: for the Model B host's layout
// (docs/TUBE-MAP.md), where ANDY, shadow RAM and HAZEL are missing and each
// sideways bank stands alone.
//
//   node tube/tools/hctx.mjs --log L --cand tube/build/elite-tube.ssd --csyms tube/build/psyms.txt
//        --hsyms tube/build/hsyms.txt [--from 0 --to 16000] --out scratch/hctx.json
//
// The context of an access is ROMSEL & &8F at the time (5: bank 5, &85: ANDY
// over bank 5, 6: bank 6, ...). Per physical location (main RAM below &8000
// by address; "b5:", "A:", "b6:" for bank 5, ANDY and bank 6) it records the
// contexts that executed it (x), read it as data (r) and wrote it (w), and
// reports per label (hsyms, hbanks.txt for the banked ones) the union.
import { EliteMachine, loadSyms, CYCLES_PER_FRAME } from "../../master/tools/agentplay/lib.mjs";
import { TubeEliteMachine } from "./tmachine.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { readFileSync, writeFileSync } from "fs";
const a = parseArgs({ log: "value", cand: "value", csyms: "value", hsyms: "value", from: "value", to: "value", out: "value" });
const FROM = +(a.from || 0), TO = +(a.to || 16000);
const L = { rlog: new Map(), rjoy: [[], []], header: null };
for (const l of readFileSync(a.log, "utf8").split("\n")) { if (!l) continue; const e = JSON.parse(l); if (e.header) L.header = e; else if (e.p !== undefined) L.rlog.set(e.p, e); else if (e.j !== undefined) L.rjoy[e.w].push([e.j, e.v]); }
const H = L.header, rand = seedBytes(H.seed), cmdr = COMMANDERS[H.commander || "jameson"], patch = cmdr.patch ? m => cmdr.patch(m) : null;
const ptr = [0, 0];
const input = { rdkey: ctx => L.rlog.get(ctx.poll)?.k || [], dks5: ctx => { const e = L.rlog.get(ctx.poll); return !!(e && e.t === "d"); },
    joy(ctx) { const l = L.rjoy[ctx.which]; while (ptr[ctx.which] + 1 < l.length && l[ptr[ctx.which] + 1][0] <= ctx.joy) ptr[ctx.which]++; const e = l[ptr[ctx.which]]; return e && e[0] <= ctx.joy ? e[1] : 0x80; } };
const ref = new EliteMachine({ name: "ref", disc: DEFAULTS.ref, syms: loadSyms(DEFAULTS.rsyms), input: { rdkey: () => [], dks5: () => false, joy: () => 0x80 }, rand, patch });
await ref.boot(); for (let k = 0; k < 10000 && !ref.started; k++) ref.run(CYCLES_PER_FRAME);
const m = new TubeEliteMachine({ host: "Master", name: "t", disc: a.cand, syms: loadSyms(a.csyms), rand, patch, seedFrom: ref, input });
await m.boot();
const h = m.host;
// physical location key
const ro = h.romOffset;
function where(addr, offset) {
    const p = offset + addr;
    if (addr < 0x8000) return addr < 0x3000 || addr >= 0x7000 ? "m:" + addr.toString(16) : null;   // (screen: ignored)
    if (addr < 0xc000) {
        if (p >= ro + 5 * 16384 && p < ro + 6 * 16384) return "b5:" + addr.toString(16);
        if (p >= ro + 6 * 16384 && p < ro + 7 * 16384) return "b6:" + addr.toString(16);
        if (p >= ro + 4 * 16384 && p < ro + 5 * 16384) return "b4:" + addr.toString(16);
        if (p >= ro + 7 * 16384 && p < ro + 8 * 16384) return "b7:" + addr.toString(16);
        if (addr < 0x9000 && (h.romsel & 0x80)) return "A:" + addr.toString(16);
        return null;
    }
    return null;
}
const use = new Map();     // key -> {x:Set, r:Set, w:Set}
const ctx = () => (h.romsel & 0x8f).toString(16);
let curPc = 0, on = false;
const note = (k, kind) => { if (!k) return; let u = use.get(k); if (!u) use.set(k, u = { x: new Set(), r: new Set(), w: new Set() }); u[kind].add(ctx()); };
h.debugInstruction.add(pc => { curPc = pc; if (on) { const st = h.memStatOffset + (pc >>> 8); note(where(pc, h.memLook[st]), "x"); } return false; });
h.debugRead.add((addr, v, off) => { if (on && !(addr >= curPc && addr < curPc + 3)) note(where(addr, off), "r"); return false; });
h.debugWrite.add((addr) => { if (on) { const st = h.memStatOffset + (addr >>> 8); note(where(addr, h.memLook[st]), "w"); } return false; });
m.onIter = mm => { on = mm.iter >= FROM && mm.iter < TO; if (mm.iter % 1000 === 0) console.error("iteration", mm.iter); };
while (m.iter < TO) { m.run(CYCLES_PER_FRAME); m.snaps.length = 0; }
// labels
const hsy = loadSyms(a.hsyms), hb = {};
for (const l of readFileSync(a.hsyms.replace(/hsyms\.txt$/, "hbanks.txt"), "utf8").split("\n")) { const [n, b] = l.split(" "); if (n) hb[n] = b; }
const mapOf = (k, v) => v < 0x8000 ? "m" : hb[k] === "85" ? (v < 0x9000 ? "A" : "b5") : hb[k] === "5" ? "b5" : hb[k] === "6" ? "b6" : "?";
const LB = {};
for (const [k, v] of Object.entries(hsy)) { if (/^(CODE|LOAD|B5_|B6_|RA_|H_END|WS_)/.test(k)) continue; (LB[mapOf(k, v)] ||= []).push([k, v]); }
for (const l of Object.values(LB)) l.sort((x, y) => x[1] - y[1]);
const near = (map, addr) => { const labs = LB[map] || []; let lo = 0, hi = labs.length - 1, r = null; while (lo <= hi) { const k = (lo + hi) >> 1; if (labs[k][1] <= addr) { r = labs[k]; lo = k + 1; } else hi = k - 1; } return r; };
const byLab = new Map();
for (const [k, u] of use) {
    const [map, hex] = k.split(":"); const addr = parseInt(hex, 16);
    const lab = near(map, addr); const name = lab ? `${map}:${lab[0]}` : k;
    let b = byLab.get(name); if (!b) byLab.set(name, b = { at: lab ? lab[1] : addr, x: new Set(), r: new Set(), w: new Set(), n: 0 });
    for (const t of ["x", "r", "w"]) for (const c of u[t]) b[t].add(c);
    b.n++;
}
const out = {};
for (const [k, b] of [...byLab].sort((p, q) => p[0] < q[0] ? -1 : 1)) out[k] = { at: b.at.toString(16), bytes: b.n, x: [...b.x], r: [...b.r], w: [...b.w] };
writeFileSync(a.out || "scratch/hctx.json", JSON.stringify(out, null, 0).replace(/},/g, "},\n"));
console.log("labels", Object.keys(out).length);
process.exit(0);
