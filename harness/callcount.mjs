// Count calls of named routines over a window of TT100 iterations in the port
// node harness/callcount.mjs [--from 1000] [--n 300] NAME...
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { readFileSync } from "fs";
const argv = process.argv.slice(2);
const opt = (k, d) => { const i = argv.indexOf("--" + k); if (i < 0) return d; const v = argv[i + 1]; argv.splice(i, 2); return v; };
const FROM = +opt("from", 1000), N = +opt("n", 300);
const syms = {};
for (const m of readFileSync("/Users/ebenupton/elite/build/symbols.txt", "latin1").matchAll(/'([^']+)':(\d+)/g)) syms[m[1]] = +m[2];
const names = argv;
const addr = new Map(names.map(n => [syms[n], n]));
const s = new MachineSession("Master");
await s.initialise(); await s.boot(30);
s.loadDisc("/Users/ebenupton/elite/build/elite-master.ssd");
s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
const cpu = s._machine.processor;
let it = 0, done = false; const cnt = {};
const h = pc => {
  if (pc === syms.TT100) { it++; if (it === FROM + N) done = true; }
  if (it >= FROM && addr.has(pc)) { const n = addr.get(pc); cnt[n] = (cnt[n] || 0) + 1; }
  return false;
};
cpu.debugInstruction.add(h);
while (!done) { h(cpu.pc); cpu.execute(20000); }
for (const n of names) console.log(n.padEnd(10), ((cnt[n] || 0) / N).toFixed(1).padStart(8), "calls/iteration");
process.exit(0);
