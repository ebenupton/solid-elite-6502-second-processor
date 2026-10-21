// tspeed.mjs: iterations per emulated second over windows of a replayed run,
// for SNG47 (--kind ref), the Master port (--kind m) or the Tube build
// (--kind t, --host Master|B).
//   node tube/tools/tspeed.mjs --log L --kind t --cand tube/build/elite-tube.ssd --csyms tube/build/psyms.txt --windows 1000-1400,3420-3550
import { EliteMachine, loadSyms, CYCLES_PER_FRAME } from "../../master/tools/agentplay/lib.mjs";
import { TubeEliteMachine } from "./tmachine.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { readFileSync } from "fs";
const a = parseArgs({ log: "value", kind: "value", host: "value", cand: "value", csyms: "value", windows: "value" });
const L = { rlog: new Map(), rjoy: [[], []], header: null };
for (const l of readFileSync(a.log, "utf8").split("\n")) { if (!l) continue; const e = JSON.parse(l); if (e.header) L.header = e; else if (e.p !== undefined) L.rlog.set(e.p, e); else if (e.j !== undefined) L.rjoy[e.w].push([e.j, e.v]); }
const H = L.header, rand = seedBytes(H.seed), cmdr = COMMANDERS[H.commander || "jameson"], patch = cmdr.patch ? m => cmdr.patch(m) : null;
const input = () => { const ptr = [0, 0]; return { rdkey: ctx => L.rlog.get(ctx.poll)?.k || [], dks5: ctx => { const e = L.rlog.get(ctx.poll); return !!(e && e.t === "d"); },
    joy(ctx) { const l = L.rjoy[ctx.which]; while (ptr[ctx.which] + 1 < l.length && l[ptr[ctx.which] + 1][0] <= ctx.joy) ptr[ctx.which]++; const e = l[ptr[ctx.which]]; return e && e[0] <= ctx.joy ? e[1] : 0x80; } }; };
const W = (a.windows || "1000-1400,3420-3550").split(",").map(s => s.split("-").map(Number));
const last = Math.max(...W.map(w => w[1]));
const ref = new EliteMachine({ name: "ref", disc: DEFAULTS.ref, syms: loadSyms(DEFAULTS.rsyms), input: a.kind === "ref" ? input() : { rdkey: () => [], dks5: () => false, joy: () => 0x80 }, rand, patch });
await ref.boot(); for (let k = 0; k < 10000 && !ref.started; k++) ref.run(CYCLES_PER_FRAME);
let m = ref;
if (a.kind === "m") m = new EliteMachine({ name: "m", disc: a.cand, syms: loadSyms(a.csyms), rand, patch, seedFrom: ref, input: input() });
if (a.kind === "t") m = new TubeEliteMachine({ host: a.host || "Master", name: "t", disc: a.cand, syms: loadSyms(a.csyms), rand, patch, seedFrom: ref, input: input() });
if (m !== ref) await m.boot();
const at = [];
m.onIter = mm => { at[mm.iter] = mm.cyclesNow(); };
while (m.iter <= last) { m.run(CYCLES_PER_FRAME); m.snaps.length = 0; }
for (const [x, y] of W) {
    const cyc = at[y] - at[x];
    console.log(`${a.kind}${a.host ? "/" + a.host : ""} iterations ${x}-${y}: ${(cyc / (y - x)).toFixed(0)} cycles an iteration, ${((y - x) * 2e6 / cyc).toFixed(2)} it/s`);
}
process.exit(0);
