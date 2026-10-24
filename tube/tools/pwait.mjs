// pwait.mjs: the parasite's wall time by category, and the host's idle share,
// over windows of a replayed run (scratch analysis tool).
//   TUBEMHZ=4 node tube/tools/pwait.mjs --log L --cand tube/build/elite-tube.ssd --csyms tube/build/psyms.txt --windows 1000-1400,... [--host B]
import { EliteMachine, loadSyms, CYCLES_PER_FRAME } from "../../master/tools/agentplay/lib.mjs";
import { TubeEliteMachine } from "./tmachine.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { readFileSync } from "fs";
const a = parseArgs({ log: "value", host: "value", cand: "value", csyms: "value", windows: "value" });
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
const par = m.t.par, pm = par.memory, tube = m.t.tube, host = m.host;

// ---- parasite contexts: entered at these addresses, left when S rises above
// the entry S (the routine returned)
const CTX = {};
const setc = (names, c) => { for (const n of names) if (sy[n] !== undefined) CTX[sy[n]] = c; else console.log("no sym", n); };
setc(["p_wscan"], "e");
setc(["p_dks", "p_fillkl", "p_irb", "p_noise", "p_soflush", "p_det1"], "d");
setc(["ovl_need", "ovl_get", "p_oscli", "p_dosnmi"], "f");
const SEND = new Set(["ptx", "preq", "preq4", "ptxv"].filter(n => sy[n] !== undefined).flatMap(n => [0, 1, 2, 3, 4, 5, 6].map(i => sy[n] + i)));
const ctxStack = [];
let added = 0, prevC = null, prevCat = null, prevPc = 0, on = false, cur = null, lastClass = null;
const origExec = par.execute;
par.execute = function (c) { added += c * this.cpuMultiplier; return origExec.call(this, c); };
let addedAtLast = 0;
// host state, for attributing the parasite's R1 stalls
let hostState = "busy";
const pollers = new Map();
m.t.addParHook(pc => {
    // cycles of the previous instruction
    const c = par.cycles, d = prevC === null ? 0 : prevC + (added - addedAtLast) - c;
    prevC = c; addedAtLast = added;
    if (on && prevCat) { cur.p[prevCat] = (cur.p[prevCat] || 0) + d; cur.pt += d; if (prevCat.startsWith("c")) pollers.set(m.labelOf(prevPc), (pollers.get(m.labelOf(prevPc)) || 0) + d); }
    // context
    while (ctxStack.length && par.s > ctxStack[ctxStack.length - 1][1]) ctxStack.pop();
    if (CTX[pc]) ctxStack.push([CTX[pc], par.s]);
    const ctx = ctxStack.length ? ctxStack[0][0] : null;
    const op = pm[pc];
    let cat;
    if (op === 0x2c && pm[pc + 2] === 0xfe && (pm[pc + 1] & 0xf0) === 0xf0) {
        const r = (pm[pc + 1] - 0xf8) >> 1, br = pm[pc + 3];
        const st = tube.parasiteStatus[r];
        const fail = br === 0x50 ? !(st & 0x40) : br === 0x10 ? !(st & 0x80) : false;
        if (fail) cat = ctx ? ctx + ".wait" : r === 0 ? "c.r1full" + (hostState === "vs" ? ".hostflip" : hostState === "idle" ? ".hostidle?" : "") : r === 3 && br === 0x10 ? "d.r4data" : "d.req";
        else cat = ctx ? ctx : "b";
        lastClass = cat;
    } else if ((op === 0x50 || op === 0x10) && pm[pc - 3] === 0x2c && pm[pc - 1] === 0xfe) cat = lastClass;
    else if (ctx) cat = ctx;
    else if (SEND.has(pc) || ((op === 0x8d || op === 0x8e || op === 0x8c) && pm[pc + 2] === 0xfe && (pm[pc + 1] & 0xf9) === 0xf9)) cat = "b";
    else if (op === 0x20 && SEND.has(pm[pc + 1] | pm[pc + 2] << 8)) cat = "b";
    else cat = "a";
    prevCat = cat; prevPc = pc;
    return false;
});
// ---- host: idle polls of register 1/2 (hloop, HRX), spins on a flag (h_buf's GFLIP)
let hlast = null, hlastC = 0, hprevClass = null;
const now = () => host.cycleSeconds * 2e6 + host.currentCycles;
const rd = x => host.readmem(x & 0xffff);
host.debugInstruction.add(pc => {
    const c = now();
    if (on && hlast) { cur.h[hlast] = (cur.h[hlast] || 0) + c - hlastC; cur.ht += c - hlastC; }
    hlastC = c;
    const o0 = rd(pc);
    let cl = "busy";
    if (pc >= 0xfc00 && pc < 0xff00) cl = "busy";
    else if (o0 === 0x2c && rd(pc + 2) === 0xfe && (rd(pc + 1) === 0xe0 || rd(pc + 1) === 0xe2)) {
        const empty = !(tube.hostStatus[0] & 0x80) && !(tube.hostStatus[1] & 0x80);
        cl = empty ? "idle" : "busy";
        hprevClass = cl;
    } else if ((o0 === 0x10 || o0 === 0x30) && rd(pc - 3) === 0x2c && rd(pc - 1) === 0xfe) cl = hprevClass;
    else if (o0 === 0xad && rd(pc + 3) === 0xd0 && rd(pc + 4) === 0xfb) { cl = "vs"; hprevClass = cl; }
    else if (o0 === 0xd0 && rd(pc + 1) === 0xfb && rd(pc - 3) === 0xad) cl = hprevClass;
    else if (o0 === 0xa5 && rd(pc + 2) === 0xd0 && rd(pc + 3) === 0xfc) { cl = "vs"; hprevClass = cl; }
    else if (o0 === 0xd0 && rd(pc + 1) === 0xfc && rd(pc - 2) === 0xa5) cl = hprevClass;
    hlast = cl; hostState = cl;
    return false;
});
const res = [];
let wi = 0;
m.onIter = mm => {
    const w = W.find(([x, y]) => mm.iter >= x && mm.iter < y);
    if (w && !on) { cur = { w: w.join("-"), p: {}, h: {}, pt: 0, ht: 0, added0: added }; res.push(cur); pollers.clear(); }
    if (!w && on) { cur.wall = added - cur.added0; cur.pol = [...pollers].sort((x, y) => y[1] - x[1]).slice(0, 4); }
    on = !!w;
};
const END = Math.max(...W.map(x => x[1]));
while (m.iter < END + 1) { m.run(CYCLES_PER_FRAME); m.snaps.length = 0; }
for (const r of res) {
    const pct = (v, t) => (100 * v / t).toFixed(1);
    console.log(`\n== ${a.host || "Master"} window ${r.w}: parasite wall ${r.wall.toFixed(0)} cycles (counted ${r.pt}), host ${r.ht}`);
    const g = {};
    for (const [k, v] of Object.entries(r.p)) g[k] = v;
    for (const [k, v] of Object.entries(g).sort((x, y) => y[1] - x[1])) console.log(`  P ${k.padEnd(24)} ${pct(v, r.pt).padStart(5)}%`);
    for (const [k, v] of Object.entries(r.h).sort((x, y) => y[1] - x[1])) console.log(`  H ${k.padEnd(24)} ${pct(v, r.ht).padStart(5)}%`);
    console.log("  R1-full stall sites:", r.pol.map(([k, v]) => `${k} ${pct(v, r.pt)}%`).join(", "));
}
process.exit(0);
