#!/usr/bin/env node
// tswap.mjs: overlay S swapped out in space mode (p-ovl.asm: a call into
// overlay D while GMODE bit 7 is set) over a replayed run: each swap's
// iteration and overlay D routine, the emulated time each overlay load
// takes, and the time of the iterations around each swap (--around N: the
// swap's iteration and N after it), to compare two builds' cost of a swap.
//   node tube/tools/tswap.mjs --log L --cand disc --csyms psyms [--host Master|B] [--to N] [--around N]
import { TubeEliteMachine, loadSyms, CYCLES_PER_FRAME } from "./tmachine.mjs";
import { EliteMachine } from "../../master/tools/agentplay/lib.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { readFileSync } from "fs";

const a = parseArgs({ log: "value", cand: "value", csyms: "value", host: "value", to: "value", around: "value" });
const L = { rlog: new Map(), rjoy: [[], []], ptr: [0, 0], pokes: new Map(), header: null };
for (const l of readFileSync(a.log, "utf8").split("\n")) {
    if (!l) continue;
    const e = JSON.parse(l);
    if (e.header) L.header = e; else if (e.p !== undefined) L.rlog.set(e.p, e);
    else if (e.j !== undefined) L.rjoy[e.w].push([e.j, e.v]); else if (e.poke !== undefined) L.pokes.set(e.poke, e.v);
}
const H = L.header, rand = seedBytes(H.seed), cmdr = COMMANDERS[H.commander || "jameson"], patch = cmdr.patch ? m => cmdr.patch(m) : null;
const ref = new EliteMachine({ name: "ref", disc: DEFAULTS.ref, syms: loadSyms(DEFAULTS.rsyms), input: { rdkey: () => [], dks5: () => false, joy: () => 0x80 }, rand, patch });
await ref.boot();
for (let k = 0; k < 10000 && !ref.started; k++) ref.run(CYCLES_PER_FRAME);
const sy = loadSyms(a.csyms);
const cand = new TubeEliteMachine({ host: a.host || "Master", name: "cand", disc: a.cand, syms: sy, rand, patch, seedFrom: ref,
    input: {
        rdkey(ctx) { return L.rlog.get(ctx.poll)?.k || []; },
        dks5(ctx) { const e = L.rlog.get(ctx.poll); return !!(e && e.t === "d"); },
        joy(ctx) { const l = L.rjoy[ctx.which]; while (L.ptr[ctx.which] + 1 < l.length && l[L.ptr[ctx.which] + 1][0] <= ctx.joy) L.ptr[ctx.which]++; const e = l[L.ptr[ctx.which]]; return e && e[0] <= ctx.joy ? e[1] : 0x80; },
    } });
await cand.boot();
cand.pokes = L.pokes;
const m = cand.ram, TO = +(a.to || 6000), AR = +(a.around || 3);
const cold = Object.entries(sy).filter(([k]) => k.endsWith("_C")).map(([k, v]) => [k.slice(0, -2), v]);
const name = ad => (cold.find(([, v]) => v === ad) || [`&${ad.toString(16)}`])[0];
const swaps = [], loads = { 1: [0, 0], 2: [0, 0], 3: [0, 0] };
let open = null, sw = null, swT = 0;
cand.t.addParHook(pc => {
    if (pc === sy.ovl_need && m[sy.ovl_cur] === 2 && cand.cpu.a === 1 && (m[sy.GMODE] & 0x80))
        { swaps.push({ it: cand.iter, to: name(m[sy.ot] + 256 * m[sy.ot + 1]) }); sw = cand.cyclesNow(); }
    if (pc === sy.ovn9 && sw !== null) { swT += cand.cyclesNow() - sw; sw = null; }
    if (pc === sy.ovl_get) open = { o: cand.cpu.a, t: cand.cyclesNow() };
    return false;
});
// the time of an overlay load: from ovl_get to its RTS (the last instruction)
const rts = sy.ovlen - 1;   // (p-ovl.asm: ovl_get's RTS is the byte before ovlen)
cand.t.addParHook(pc => { if (open && pc === rts) { const l = loads[open.o]; if (l) { l[0]++; l[1] += cand.cyclesNow() - open.t; } open = null; } return false; });
const itT = [];
let prev = cand.cyclesNow(), pi = cand.iter;
while (cand.iter < TO) {
    const r = cand.run(CYCLES_PER_FRAME); cand.snaps.length = 0;
    if (cand.iter !== pi) { const now = cand.cyclesNow(); for (let i = pi; i < cand.iter; i++) itT[i] = (now - prev) / (cand.iter - pi); prev = now; pi = cand.iter; }
    if (r === "blocked" && cand.blocked && cand.blocked.kind !== "tt170") { if (cand.polls > Math.max(...L.rlog.keys())) break; }
}
const by = {};
for (const s of swaps) (by[s.to] ||= []).push(s.it);
for (const [k, v] of Object.entries(by)) console.log(`${k}: ${v.length} (iterations ${v.slice(0, 12).join(" ")}${v.length > 12 ? " ..." : ""})`);
const its = [...new Set(swaps.map(s => s.it))];
let sum = 0, n = 0;
for (const i of its) for (let j = i; j <= i + AR; j++) if (itT[j] !== undefined) { sum += itT[j]; n++; }
console.log(`swaps: ${swaps.length} in ${its.length} iterations; ${n} iterations around them (each and ${AR} after): ${sum.toFixed(0)} cycles (2 MHz), ${(n ? sum / n : 0).toFixed(0)} an iteration`);
console.log(`the swaps out (ovl_need, S to D): ${(swT / Math.max(1, swaps.length)).toFixed(0)} cycles each (2 MHz)`);
for (const [o, [c, t]] of Object.entries(loads)) if (c) console.log(`overlay ${["", "D", "S", "S's state"][o]} loads: ${c}, ${(t / c).toFixed(0)} cycles each (2 MHz)`);
console.log(`to iteration ${cand.iter}`);
