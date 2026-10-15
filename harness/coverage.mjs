// Code coverage of the port: which routine blocks are never executed in a run.
// node harness/coverage.mjs [--secs 1200]
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { readFileSync } from "fs";
const args = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => {
    if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]);
    return acc;
}, []));
const ROOT = "/Users/ebenupton/elite";
const SECS = +(args.secs || 1200);
const syms = {};
for (const m of readFileSync(`${ROOT}/build/symbols.txt`, "utf8").matchAll(/'([^']+)':(\d+)L?/g)) syms[m[1]] = +m[2];
const names = new Set();
for (const m of readFileSync(`${ROOT}/src/elite-source.asm`, "latin1").matchAll(/^\\       Name: (\S+)/gm)) names.add(m[1]);
const st = Object.entries(syms).filter(([k, v]) => names.has(k) && v >= 0x0f40).sort((a, b) => a[1] - b[1]);
const s = new MachineSession("Master");
await s.initialise();
await s.boot(30);
s.loadDisc(`${ROOT}/build/elite-master.ssd`);
s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
const cpu = s._machine.processor;
const hit = new Uint8Array(65536);
const handler = pc => { hit[pc] = 1; return false; };
cpu.debugInstruction.add(handler);
while (cpu.cycleSeconds < SECS) for (let k = 0; k < 40; k++) { handler(cpu.pc); cpu.execute(50000); }
const res = [];
for (let i = 0; i < st.length; i++) {
    const a = st[i][1], e = i + 1 < st.length ? st[i + 1][1] : a + 1;
    if (e - a > 4000) continue;
    let n = 0; for (let x = a; x < e; x++) n += hit[x];
    res.push([st[i][0], a, e - a, n]);
}
let dead = 0;
for (const [k, a, len, n] of res) if (n === 0) { dead += len; console.log(`never executed: ${k.padEnd(24)} &${a.toString(16)} ${len} bytes`); }
console.log(`total never-executed block bytes: ${dead}`);
process.exit(0);
