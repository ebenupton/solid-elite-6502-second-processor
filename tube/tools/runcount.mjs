import { EliteMachine, loadSyms, CYCLES_PER_FRAME } from "../../master/tools/agentplay/lib.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { readFileSync } from "fs";
const L = { rlog: new Map(), rjoy: [[], []], ptr: [0, 0], header: null };
for (const l of readFileSync("scratch/curious/run1/inputs.jsonl", "utf8").split("\n")) { if (!l) continue; const e = JSON.parse(l); if (e.header) L.header = e; else if (e.p !== undefined) L.rlog.set(e.p, e); else if (e.j !== undefined) L.rjoy[e.w].push([e.j, e.v]); }
const H = L.header, rand = seedBytes(H.seed), cmdr = COMMANDERS[H.commander || "jameson"], patch = cmdr.patch ? m => cmdr.patch(m) : null;
const ref = new EliteMachine({ name: "ref", disc: DEFAULTS.ref, syms: loadSyms(DEFAULTS.rsyms), input: { rdkey: () => [], dks5: () => false, joy: () => 0x80 }, rand, patch });
await ref.boot(); for (let k = 0; k < 10000 && !ref.started; k++) ref.run(CYCLES_PER_FRAME);
const cand = new EliteMachine({ name: "cand", disc: "master/build/elite-master-sng47.ssd", syms: loadSyms("master/build/symbols.txt"), rand, patch, seedFrom: ref,
  input: { rdkey: ctx => L.rlog.get(ctx.poll)?.k || [], dks5: ctx => { const e = L.rlog.get(ctx.poll); return !!(e && e.t === "d"); }, joy(ctx) { const l = L.rjoy[ctx.which]; while (L.ptr[ctx.which] + 1 < l.length && l[L.ptr[ctx.which] + 1][0] <= ctx.joy) L.ptr[ctx.which]++; const e = l[L.ptr[ctx.which]]; return e && e[0] <= ctx.joy ? e[1] : 0x80; } } });
await cand.boot();
const cpu = cand.cpu; const win = [[1000,1400,"flight"],[3000,3100,"3000"],[3100,3200,"3100"],[3200,3300,"3200"],[3300,3420,"3300"],[3420,3550,"docking"]]; const cnt = {}; for (const w of win) cnt[w[2]] = [0, 0];
let curOp = 0, curPc = 0, inRun = false;
cpu.debugInstruction.add((pc, op) => { curOp = op; curPc = pc; const r = op === 0x99 && pc >= 0xa000 && pc < 0xb800 && (cpu.romsel & 15) === 5; if (r && !inRun) for (const [x,y,n] of win) if (cand.iter >= x && cand.iter < y) cnt[n][2] = (cnt[n][2] || 0) + 1; inRun = r; return false; });
cpu.debugWrite.add(a => { if (a >= 0x4000 && a < 0x7000) for (const [x,y,n] of win) if (cand.iter >= x && cand.iter < y) { cnt[n][1]++; if (curOp === 0x99 && curPc >= 0xa000 && curPc < 0xb800) cnt[n][0]++; } return false; });
while (cand.iter < 3550) { cand.run(CYCLES_PER_FRAME); cand.snaps.length = 0; }
for (const [a,b,n] of win) console.log(n, "screen writes per iteration:", (cnt[n][1]/(b-a)).toFixed(0), "of which row-run STA abs,Y:", (cnt[n][0]/(b-a)).toFixed(0), "in runs entered:", ((cnt[n][2]||0)/(b-a)).toFixed(0));
process.exit(0);
