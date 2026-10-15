// Headless jsbeeb runner: boot a disc, run, take screenshots, count PC hits.
// node run.mjs --model Master --disc x.ssd --secs 60 --shots 5 --out dir --count ADDR[,ADDR] [--every N]
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { writeFileSync, mkdirSync } from "fs";
const a = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => { if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]); return acc; }, []));
const model = a.model || "Master", secs = +(a.secs || 30), every = +(a.every || 5), out = a.out || "shots";
mkdirSync(out, { recursive: true });
const s = new MachineSession(model);
await s.initialise();
await s.boot(30);
s.loadDisc(a.disc);
s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
const cpu = s._machine.processor;
const counts = {};
const addrs = (a.count ? String(a.count).split(",") : []).map(x => parseInt(x, 16));
for (const ad of addrs) counts[ad.toString(16)] = 0;
const log = [];
if (addrs.length) cpu.debugInstruction.add(pc => { if (addrs.includes(pc)) counts[pc.toString(16)]++; return false; });
let t = 0;
while (t < secs) {
  await s.runFor(2000000 * every); t += every;
  const png = await s.screenshotActive({ scale: 1 });
  writeFileSync(`${out}/t${String(t).padStart(4, "0")}.png`, png);
  log.push(`t=${t} ` + JSON.stringify(counts));
  console.log(log[log.length - 1]);
}
if (a.dump) { const [ad, len] = String(a.dump).split(":").map(x => parseInt(x, 16)); writeFileSync(`${out}/dump.bin`, Buffer.from(s.readMemory(ad, len))); }
