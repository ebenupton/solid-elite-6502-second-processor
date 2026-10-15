// Cycle cost of the planet's boundary construction per frame: cycles from the
// entry of f_bounds (bank 6) to the following entry of T_DISCROWS, and of
// the rasteriser's R_DISCROWS (to its return to f_discs' caller: measured as
// T_DISCROWS entry to the next f_lines entry), by window of TT100 iterations.
// node harness/planet-cost.mjs [--disc d] [--syms s] [--frames 600]
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { readFileSync } from "fs";
const a = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => { if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]); return acc; }, []));
const DISC = a.disc || "build/elite-master.ssd", SYMS = a.syms || "build/symbols.txt", FRAMES = +(a.frames || 600);
const syms = {};
for (const m of readFileSync(SYMS, "utf8").matchAll(/'([^']+)':(\d+)L?/g)) syms[m[1]] = +m[2];
// seed as compare.mjs does (RAND, T%, WP from the original at TT170)
const osy = {};
for (const m of readFileSync("/Users/ebenupton/elite/build/orig-symbols.txt", "utf8").matchAll(/'([^']+)':(\d+)L?/g)) osy[m[1]] = +m[2];
const o = new MachineSession("B-DFS1.2");
await o.initialise(); await o.boot(30);
o.loadDisc("/Users/ebenupton/elite/ref/elite-demo-source-code-bbc-micro/5-compiled-game-discs/elite-demonstration-disc.ssd");
o.keyDown(16); o.reset(true); await o.runFor(2000000); o.keyUp(16);
const oc = o._machine.processor;
let hit = false;
oc.debugInstruction.add(pc => { if (pc === osy.TT170) { hit = true; return true; } return false; });
while (!hit) oc.execute(50000);
const seed = [];
for (const [lo, hi] of [[0, 3], [0x300, 0x371], [0xd40, 0xf38]]) for (let ad = lo; ad <= hi; ad++) seed.push([ad, oc.ramRomOs[ad]]);

const s = new MachineSession("Master");
await s.initialise(); await s.boot(30);
s.loadDisc(DISC);
s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
const cpu = s._machine.processor;
const cyc = () => cpu.cycleSeconds * 2e6 + cpu.currentCycles;
const FB = syms.f_bounds, TD = syms.T_DISCROWS, FL = syms.f_lines, TT100 = syms.TT100, TT170 = syms.TT170;
const SKIPW = +(a.from || 0);
let iter = -1, started = false, t0 = 0, t1 = 0, inB = false, inR = false;
const win = {}, WIN = +(a.win || 200);
// optional phases inside f_bounds: --phases label,label,... (bank 6 labels;
// cycles are charged to the last phase label passed)
const PH = a.phases ? String(a.phases).split(",") : [];
const phAddr = new Map(PH.map(n => [syms[n], n]));
let phase = null, phT = 0;
const phTot = {};
// the meridian constants (planet4.asm PM_HOOK, bank 4, at PLS22 time): cycles
// from PM_HOOK to the following G_PCURVE, per frame with the planet layer
const PMH = syms.PM_HOOK, GPC = syms.G_PCURVE;
let inH = false, tH = 0, hookCyc = 0;
function handler(pc) {
    if (pc === TT170 && !started) { started = true; for (const [ad, v] of seed) cpu.ramRomOs[ad] = v; return false; }
    if (!started) return false;
    if (pc === TT100) { iter++; return iter >= FRAMES; }
    const bank = cpu.romsel & 15;
    if (PMH !== undefined && pc === PMH && bank === 4) { inH = true; tH = cyc(); }
    else if (inH && pc === GPC) { hookCyc += cyc() - tH; inH = false; }
    if (inB && iter >= SKIPW && phAddr.has(pc)) { const now = cyc(); if (phase) phTot[phase] = (phTot[phase] || 0) + now - phT; phase = phAddr.get(pc); phT = now; }
    if (pc === FB && bank === 6) { t0 = cyc(); inB = true; phase = "setup"; phT = t0; }
    else if (pc === TD && inB) { if (phase) phTot[phase] = (phTot[phase] || 0) + cyc() - phT; phase = null; const w = Math.floor(iter / WIN) * WIN; (win[w] ||= { n: 0, b: 0, r: 0, max: 0 }); const c = cyc() - t0; win[w].n++; win[w].b += c; win[w].max = Math.max(win[w].max, c); inB = false; inR = true; t1 = cyc(); }
    else if (pc === FL && bank === 6 && inR) { const w = Math.floor(iter / WIN) * WIN; win[w].r += cyc() - t1; inR = false; }
    return false;
}
cpu.debugInstruction.add(handler);
let done = false;
while (!done) { for (let k = 0; k < 40 && !done; k++) { if (handler(cpu.pc)) done = true; cpu.execute(50000); if (iter >= FRAMES) done = true; } }
console.log("window      frames  f_bounds avg   max   disc rows (R_DISCROWS) avg");
for (const [w, v] of Object.entries(win)) console.log(`${String(w).padStart(5)}-${String(+w + WIN - 1).padStart(5)} ${String(v.n).padStart(6)} ${(v.b / v.n).toFixed(0).padStart(12)} ${String(v.max).padStart(6)} ${(v.r / v.n).toFixed(0).padStart(12)}`);
{ let n = 0; for (const v of Object.values(win)) n += v.n; console.log(`PM_HOOK (meridian constants, game time): ${(hookCyc / n).toFixed(0)} cycles per planet frame (all windows)`); }
if (PH.length) { let n = 0; for (const [w, v] of Object.entries(win)) if (+w >= SKIPW) n += v.n; for (const [k, v] of Object.entries(phTot)) console.log(`  phase ${k.padEnd(14)} ${(v / n).toFixed(0)} cycles/frame`); }
process.exit(0);
