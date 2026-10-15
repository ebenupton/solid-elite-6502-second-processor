// Cycle profile of the port by routine BLOCK (Elite code grouped by the source's routine headers)
// (based on prof.mjs) (bank-aware), over a window of TT100
// iterations: node harness/prof.mjs [--from 200] [--n 200] [--disc ...]
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { readFileSync } from "fs";
const a = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => { if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1]]); return acc; }, []));
const ROOT = "/Users/ebenupton/elite";
const FROM = +(a.from || 200), N = +(a.n || 200);
const syms = {};
for (const m of readFileSync(`${ROOT}/build/symbols.txt`, "latin1").matchAll(/'([^']+)':(\d+)/g)) syms[m[1]] = +m[2];
const labelsIn = f => new Set([...readFileSync(f, "latin1").matchAll(/^\.([A-Za-z_][A-Za-z0-9_%]*)/gm)].map(m => m[1]));
const blockNames = new Set([...readFileSync(`${ROOT}/src/elite-source.asm`, "latin1").matchAll(/^\\       Name: (\S+)/gm)].map(m => m[1]));
const b5 = labelsIn(`${ROOT}/src/raster.asm`);
const b6 = new Set([...labelsIn(`${ROOT}/src/frame.asm`), ...labelsIn(`${ROOT}/src/faces.asm`)]);
const tabs = { 4: [], 5: [], 6: [], main: [] };
for (const [k, v] of Object.entries(syms)) {
  if (v < 0x0f40) continue;
  if (!(b5.has(k) || b6.has(k)) && v >= 0x0f40 && !blockNames.has(k) && !(v >= 0xc000)) continue;
  if (v >= 0x8000 && v < 0xc000) tabs[b5.has(k) ? 5 : b6.has(k) ? 6 : 4].push([v, k]);
  else tabs.main.push([v, k]);
}
for (const t of Object.values(tabs)) t.sort((x, y) => x[0] - y[0]);
const look = (t, pc) => { let lo = 0, hi = t.length - 1, r = null; while (lo <= hi) { const m = (lo + hi) >> 1; if (t[m][0] <= pc) { r = t[m][1]; lo = m + 1; } else hi = m - 1; } return r; };
const s = new MachineSession("Master");
await s.initialise(); await s.boot(30);
s.loadDisc(a.disc || `${ROOT}/build/elite-master.ssd`);
s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
const cpu = s._machine.processor;
const cyc = () => cpu.cycleSeconds * 2e6 + cpu.currentCycles;
let it = 0, last = 0, lastKey = null; const prof = {};
let total0 = 0, total1 = 0;
cpu.debugInstruction.add(pc => {
  if (pc === syms.TT100) { it++; if (it === FROM) total0 = cyc(); if (it === FROM + N) { total1 = cyc(); return true; } }
  if (it >= FROM && it < FROM + N) {
    const now = cyc();
    if (lastKey) prof[lastKey] = (prof[lastKey] || 0) + now - last;
    last = now;
    let key;
    if (pc >= 0xc000) key = pc >= 0xe000 ? "MOS" : "HAZEL:" + (look(tabs.main, pc) || "?");
    else if (pc >= 0x8000) { const bank = cpu.romsel & 15; key = `b${bank}:` + (look(tabs[bank] || [], pc) || "?"); }
    else key = look(tabs.main, pc) || "low";
    lastKey = key;
  }
  return false;
});
while (!total1) await s.runFor(2000000);
const tot = total1 - total0;
console.log(`iterations ${FROM}-${FROM + N}: ${(tot / N).toFixed(0)} cycles/iteration, ${(2e6 * N / tot).toFixed(2)} it/s`);
const grp = {};
for (const [k, v] of Object.entries(prof)) { const g = k.startsWith("b5:") ? "raster(b5)" : k.startsWith("b6:") ? "frame(b6)" : k.startsWith("HAZEL") ? "hooks(HAZEL)" : k.startsWith("b4:") ? "elite(b4)" : k === "MOS" ? "MOS" : "elite(main)"; grp[g] = (grp[g] || 0) + v; }
for (const [k, v] of Object.entries(grp).sort((x, y) => y[1] - x[1])) console.log("TOTAL " + k.padEnd(22), (v / N).toFixed(0).padStart(8), (100 * v / tot).toFixed(1).padStart(6) + "%");
const rows = Object.entries(prof).sort((x, y) => y[1] - x[1]).slice(0, +(a.top || 45));
for (const [k, v] of rows) console.log(k.padEnd(28), (v / N).toFixed(0).padStart(8), (100 * v / tot).toFixed(1).padStart(6) + "%");
