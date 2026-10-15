// Cycle profiler: attribute CPU cycles to routines between two TT100 iterations.
// node harness/profile.mjs --which orig|port [--from 200] [--to 1000]
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { readFileSync } from "fs";

const args = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => {
    if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]);
    return acc;
}, []));
const ROOT = "/Users/ebenupton/elite";
const which = args.which || "port";
const FROM = +(args.from || 200), TO = +(args.to || 1000);
const cfg = which === "orig"
    ? { model: "B-DFS1.2", disc: `${ROOT}/ref/elite-demo-source-code-bbc-micro/5-compiled-game-discs/elite-demonstration-disc.ssd`, syms: `${ROOT}/build/orig-symbols.txt`, src: `${ROOT}/src/orig/elite-source.asm` }
    : { model: "Master", disc: `${ROOT}/build/elite-master.ssd`, syms: `${ROOT}/build/symbols.txt`, src: `${ROOT}/src/elite-source.asm` };

const syms = {};
for (const m of readFileSync(cfg.syms, "utf8").matchAll(/'([^']+)':(\d+)L?/g)) syms[m[1]] = +m[2];
// Routine start addresses: labels that are block names in the source
const names = new Set();
for (const m of readFileSync(cfg.src, "latin1").matchAll(/^\\       Name: (\S+)/gm)) names.add(m[1]);
const starts = Object.entries(syms).filter(([k, v]) => names.has(k) && v >= 0x0f40).sort((a, b) => a[1] - b[1]);
const lookup = new Array(65536).fill(null);
for (let i = 0; i < starts.length; i++) {
    const end = i + 1 < starts.length ? starts[i + 1][1] : (starts[i][1] < 0x8000 ? 0x8000 : 0xc000);
    for (let a = starts[i][1]; a < Math.min(end, 0x10000); a++) lookup[a] = starts[i][0];
}
function bucket(pc) {
    if (pc >= 0xc000) return "MOS";
    if (which === "orig" && pc >= 0x8000) return "ROM";
    if (pc < 0x0f40) return "low";
    return lookup[pc] || "?";
}

const s = new MachineSession(cfg.model);
await s.initialise();
await s.boot(30);
s.loadDisc(cfg.disc);
s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
const cpu = s._machine.processor;
let iter = 0, last = 0, lastPc = 0, done = false;
const prof = {};
const cyc = () => cpu.cycleSeconds * 2e6 + cpu.currentCycles;
let total = 0;
const handler = pc => {
    if (pc === syms.TT100) {
        iter++;
        if (iter === FROM) last = cyc();
        if (iter === TO) done = true;
    }
    if (iter >= FROM && iter < TO) {
        const now = cyc();
        const b = bucket(lastPc);
        prof[b] = (prof[b] || 0) + (now - last);
        total += now - last;
        last = now;
    }
    lastPc = pc;
    return false;
};
cpu.debugInstruction.add(handler);
while (!done && cpu.cycleSeconds < 900) for (let k = 0; k < 40 && !done; k++) { handler(cpu.pc); cpu.execute(50000); }
console.log(`${which}: iterations ${FROM}-${TO}, ${total} cycles, ${(total / (TO - FROM)).toFixed(0)} cycles/iteration`);
for (const [k, v] of Object.entries(prof).sort((a, b) => b[1] - a[1]).slice(0, +(args.top || 45)))
    console.log(`  ${k.padEnd(28)} ${String(v).padStart(10)} ${(100 * v / total).toFixed(2).padStart(6)}%  ${(v / (TO - FROM)).toFixed(0).padStart(7)}/it`);
process.exit(0);
