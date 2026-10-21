#!/usr/bin/env node
// rlive.mjs: what the routines that move to the Tube host read and leave behind.
//
// node tube/tools/rlive.mjs --log inputs.jsonl --cand disc --csyms syms --from I --to J
//      --entries A,B,C [--out report.json]
//
// Replays an agentplay input log on a Master build (as fbreplay.mjs does) and
// watches every call the game makes to one of the given entry points (a "moved"
// call: everything executed until it returns belongs to it, helpers included).
// Per entry point it records:
//   in      the addresses the call reads that the game wrote (or the loader
//           left) before the call: what the host needs from the parasite;
//   out     the addresses the call writes that the game later reads before
//           writing them itself (with the reading routine), and those still
//           holding the call's value at the next MLOOP in the compared game
//           state (mlib's regions, less the --loose exclusions): what the
//           parasite's stub must leave as the call did;
//   regs    the registers and flags the caller reads after the call returns
//           before writing them (with the caller's site);
//   via     the labels run inside the call (the host needs them all).
// Screen memory (main RAM and shadow RAM from &4000, and shadow &3000-&3FFF) and the stack page are ignored,
// and instruction fetches are not reads.
import { EliteMachine, loadSyms, CYCLES_PER_FRAME } from "../../master/tools/agentplay/lib.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { regionsFor, excludeSet, TIMING_EXCLUDE, RELOC_EXCLUDE, DRAW_EXCLUDE, mapAt } from "../../harness/mlib.mjs";
import { OPS, regs } from "./op65.mjs";
import { readFileSync, writeFileSync } from "fs";

const a = parseArgs({ log: "value", cand: "value", csyms: "value", from: "value", to: "value", entries: "value", out: "value" });
if (!a.log || !a.cand || !a.csyms || !a.entries) { console.error("--log, --cand, --csyms and --entries are required"); process.exit(2); }
const FROM = +(a.from || 0), TO = +(a.to || 2000);

// ---- the log (as fbreplay.mjs, without following)
const L = { rlog: new Map(), rjoy: [[], []], ptr: [0, 0], pokes: new Map(), header: null };
for (const l of readFileSync(a.log, "utf8").split("\n")) {
    if (!l) continue;
    const e = JSON.parse(l);
    if (e.header) L.header = e;
    else if (e.p !== undefined) L.rlog.set(e.p, e);
    else if (e.j !== undefined) L.rjoy[e.w].push([e.j, e.v]);
    else if (e.poke !== undefined) L.pokes.set(e.poke, e.v);
}
const H = L.header;
const rsy = loadSyms(H.rsyms && !H.rsyms.includes("curious") ? H.rsyms : DEFAULTS.rsyms), csy = loadSyms(a.csyms);
const rand = H.seed !== undefined && H.seed !== null ? seedBytes(H.seed) : null;
const cmdr = COMMANDERS[H.commander || "jameson"];
const patch = cmdr.patch ? m => cmdr.patch(m) : null;
const ref = new EliteMachine({ name: "ref", disc: DEFAULTS.ref, syms: rsy, input: { rdkey: () => [], dks5: () => false, joy: () => 0x80 }, rand, patch });
await ref.boot();
for (let k = 0; k < 10000 && !ref.started; k++) ref.run(CYCLES_PER_FRAME);
const cand = new EliteMachine({ name: "cand", disc: a.cand, syms: csy, rand, patch, seedFrom: ref, workarounds: H.workarounds || [],
    input: {
        rdkey(ctx) { const e = L.rlog.get(ctx.poll); return e?.k || []; },
        dks5(ctx) { const e = L.rlog.get(ctx.poll); return !!(e && e.t === "d"); },
        joy(ctx) { const l = L.rjoy[ctx.which]; while (L.ptr[ctx.which] + 1 < l.length && l[L.ptr[ctx.which] + 1][0] <= ctx.joy) L.ptr[ctx.which]++; const e = l[L.ptr[ctx.which]]; return e && e[0] <= ctx.joy ? e[1] : 0x80; },
    } });
await cand.boot();
cand.pokes = L.pokes;
const cpu = cand.cpu, sy = csy;

// ---- the entry points (label -> mapping), with the label names for addresses
const entries = a.entries.split(",").map(n => {
    const nm = sy[n + "_C"] !== undefined ? n + "_C" : n;
    if (sy[nm] === undefined) throw new Error("no symbol " + n);
    const b = sy.__bank[nm];
    return { name: n, a: sy[nm], m: b === undefined ? "m" : (b & 0x80) && sy[nm] < 0x9000 ? "A" : b & 15 };
});
const entryAt = new Map();
for (const [i, e] of entries.entries()) entryAt.set(e.a, [...(entryAt.get(e.a) || []), i]);
const physOf = (addr, write) => {
    const so = cpu.memStatOffset + (addr >>> 8);
    return cpu.memStat[so] ? cpu.memLook[so] + addr : -1;
};
// names: per physical address, the nearest label at or below (main RAM, HAZEL, banks)
const byPhys = [];
for (const [k, v] of Object.entries(sy)) {
    if (/^(CODE|LOAD)/.test(k)) continue;
    const b = sy.__bank[k];
    let p;
    if (v < 0x8000) p = v; else if (v >= 0xc000 && v < 0xe000) p = v - 0x3000; else if (v < 0xc000 && b !== undefined) p = (b & 0x80) && v < 0x9000 ? v : cpu.romOffset + (b & 15) * 16384 + v - 0x8000; else continue;
    byPhys.push([p, k]);
}
byPhys.sort((x, y) => x[0] - y[0]);
function nameOf(p) {
    let lo = 0, hi = byPhys.length - 1, r = null;
    while (lo <= hi) { const m = (lo + hi) >> 1; if (byPhys[m][0] <= p) { r = byPhys[m]; lo = m + 1; } else hi = m - 1; }
    if (!r) return "&" + p.toString(16);
    const off = p - r[0];
    return off === 0 ? r[1] : off < 64 ? `${r[1]}+${off}` : `&${p.toString(16)}`;
}
const labelOfPc = pc => cand.labelOf(pc) || "&" + pc.toString(16);

// ---- tracking
const lastW = new Int16Array(cpu.ramRomOs.length);       // 0 load, -1 game, i+1 entry i
const ignore = p => (p >= 0x100 && p < 0x200) || (p >= 0x4000 && p < 0x8000) || (p >= 0xb000 && p < 0x10000);
const R = entries.map(() => ({ calls: 0, in: new Map(), out: new Map(), snap: new Map(), regs: new Map(), via: new Set(), exits: new Map() }));
// the far-call helpers (elite-far.asm) pass A and the flags through: what they read is not the caller's
const farLo = sy.far7 ?? 0x10000, farHi = sy.TTX66M ?? 0;
let ctx = -1, entryS = 0, curPc = 0, curLen = 0, prevMn = "", track = null, inIter = false;
// interrupts: the MOS's IRQ entry (the vector at &FFFE) to the RTI that returns to the
// interrupted code; what runs there belongs to neither the game nor a moved call
const irqEntry = cpu.readmem(0xfffe) | cpu.readmem(0xffff) << 8;
let irqS = -1;
const add = (m, k, v) => { const s = m.get(k) || new Set(); s.add(v); m.set(k, s); };
cpu.debugInstruction.add((pc, op) => {
    const o = OPS[op];
    if (irqS >= 0) {
        if (prevMn === "RTI" && cpu.s >= irqS) irqS = -1;
        else { curPc = pc; curLen = o.len; prevMn = o.mn; return false; }
    }
    if (pc === irqEntry && irqS < 0) { irqS = cpu.s + 3; curPc = pc; curLen = o.len; prevMn = o.mn; return false; }
    if (ctx >= 0) {
        if ((prevMn === "RTS" || prevMn === "RTI") && cpu.s > entryS) {
            // returned to the game: track the registers it reads before writing
            track = { e: ctx, pending: 0x7f, n: 0, site: pc >= farLo && pc < farHi ? null : labelOfPc(pc) };
            const P = (cpu.p.n ? 128 : 0) | (cpu.p.v ? 64 : 0) | (cpu.p.z ? 2 : 0) | (cpu.p.c ? 1 : 0);
            const key = `A=${cpu.a.toString(16)} X=${cpu.x.toString(16)} Y=${cpu.y.toString(16)} ${cpu.p.n ? "N" : "n"}${cpu.p.v ? "V" : "v"}${cpu.p.z ? "Z" : "z"}${cpu.p.c ? "C" : "c"}`;
            R[ctx].exits.set(key, (R[ctx].exits.get(key) || 0) + 1);
            ctx = -1;
        } else R[ctx].via.add(labelOfPc(pc));
    }
    if (ctx < 0) {
        const hits = entryAt.get(pc);
        if (hits) {
            const m = mapAt(cpu.romsel, pc);
            const i = hits.find(j => entries[j].m === "m" ? pc < 0x8000 || pc >= 0xc000 : entries[j].m === m);
            if (i !== undefined) { ctx = i; entryS = cpu.s; R[i].calls++; track = null; R[i].via.add(entries[i].name); }
        }
        if (ctx < 0 && track && !(pc >= farLo && pc < farHi)) {
            if (track.site === null) track.site = labelOfPc(pc);
            const live = o.rd & track.pending;
            if (live) add(R[track.e].regs, regs(live), track.site);
            track.pending &= ~o.wr;
            if (!track.pending || ++track.n > 40) track = null;
        }
    }
    curPc = pc; curLen = o.len; prevMn = o.mn;
    return false;
});
cpu.debugRead.add((addr, val, offset) => {
    if ((addr >= curPc && addr < curPc + curLen) || addr === cpu.pc) return false;      // (the instruction itself)
    if (irqS >= 0) return false;
    if (!offset && addr >= 0xfc00 && addr < 0xff00) return false;   // (I/O)
    const p = addr < 0x200 ? addr : offset + addr;      // (jsbeeb's zero page and stack reads pass the value third)
    if (ignore(p)) return false;
    const w = lastW[p];
    if (ctx >= 0) { if (w <= 0 && w !== ctx + 1) add(R[ctx].in, nameOf(p), w === 0 ? "load" : w === -2 ? "irq" : "game"); }
    else if (w > 0) add(R[w - 1].out, nameOf(p), labelOfPc(curPc));
    return false;
});
cpu.debugWrite.add((addr) => {
    const p = physOf(addr, true);
    if (p < 0 || ignore(p)) return false;
    lastW[p] = irqS >= 0 ? -2 : ctx >= 0 ? ctx + 1 : -1;
    return false;
});
// at each MLOOP: the compared state still holding a moved call's value
const regions = regionsFor(sy), ex = excludeSet(sy, [TIMING_EXCLUDE, RELOC_EXCLUDE, DRAW_EXCLUDE]);
cand.onIter = () => {
    for (const [s, n] of regions) for (let i = 0; i < n; i++) {
        const ad = s + i; if (ex.has(ad)) continue;
        const w = lastW[ad]; if (w > 0) add(R[w - 1].snap, nameOf(ad), "MLOOP");
    }
};
const t0 = Date.now();
while (cand.iter < TO) {
    const r = cand.run(CYCLES_PER_FRAME);
    cand.snaps.length = 0;
    if (r === "blocked") break;
    if (cand.iter % 500 === 0 && Date.now() - t0 > 0) process.stderr.write(`\r${cand.iter}  `);
}
const rep = {};
for (const [i, e] of entries.entries()) {
    const r = R[i], j = m => Object.fromEntries([...m].map(([k, v]) => [k, [...v].slice(0, 8)]));
    rep[e.name] = { calls: r.calls, in: j(r.in), out: j(r.out), snap: [...r.snap.keys()], regs: j(r.regs), via: [...r.via].slice(0, 80), exits: [...r.exits].sort((x, y) => y[1] - x[1]).slice(0, 8) };
}
if (a.out) writeFileSync(a.out, JSON.stringify(rep, null, 1));
for (const [n, r] of Object.entries(rep)) {
    console.log(`\n== ${n}: ${r.calls} calls`);
    console.log("  in:   " + Object.entries(r.in).map(([k, v]) => k + (v.includes("load") && !v.includes("game") ? "(load)" : "")).join(" "));
    console.log("  out:  " + Object.entries(r.out).map(([k, v]) => `${k}<-${v.join("/")}`).join(" "));
    console.log("  snap: " + r.snap.join(" "));
    console.log("  regs: " + Object.entries(r.regs).map(([k, v]) => `${k}@${v.join("/")}`).join(" "));
    console.log("  via:  " + r.via.join(" "));
    console.log("  exits: " + r.exits.map(([k, n]) => `${k} x${n}`).join(" | "));
}
process.exit(0);
