// Cycle profile of PM_HOOK (planet4.asm, bank 4) by label, over the first
// N iterations (seeded as compare.mjs). node harness/planet-hookprof.mjs [--frames 100]
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { readFileSync } from "fs";
const a = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => { if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]); return acc; }, []));
const FRAMES = +(a.frames || 100);
const syms = {};
for (const m of readFileSync(a.syms || "build/symbols.txt", "utf8").matchAll(/'([^']+)':(\d+)L?/g)) syms[m[1]] = +m[2];
const s = new MachineSession("Master");
await s.initialise(); await s.boot(30);
s.loadDisc(a.disc || "build/elite-master.ssd");
s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
const cpu = s._machine.processor;
const cyc = () => cpu.cycleSeconds * 2e6 + cpu.currentCycles;
const lo = syms.PM_HOOK, hi = syms.BANK_END || 0xC000;
const labs = Object.entries(syms).filter(([k, v]) => v >= lo && v < 0xC000 && (k.startsWith("pm") || k.startsWith("PM") || k.startsWith("p"))).sort((x, y) => x[1] - y[1]);
const look = pc => { let b = null; for (const [k, v] of labs) { if (v <= pc) b = k; else break; } return b; };
let iter = 0, inH = false, last = 0, lastL = null, n = 0;
const tot = {};
cpu.debugInstruction.add(pc => {
    if (pc === syms.TT100) { iter++; return iter >= FRAMES; }
    const bank = cpu.romsel & 15;
    if (pc === lo && bank === 4) { inH = true; n++; last = cyc(); lastL = "PM_HOOK"; return false; }
    if (inH) {
        const now = cyc();
        tot[lastL] = (tot[lastL] || 0) + now - last; last = now;
        if (pc === syms.G_PCURVE) { inH = false; return false; }
        lastL = (bank === 4 && pc >= lo && pc < 0xC000) ? look(pc) : "other";
    }
    return false;
});
while (iter < FRAMES) cpu.execute(50000);
console.log(`${n} PM_HOOK calls`);
for (const [k, v] of Object.entries(tot).sort((x, y) => y[1] - x[1]).slice(0, 30)) console.log(`  ${k.padEnd(14)} ${(v / n).toFixed(0)}`);
process.exit(0);
