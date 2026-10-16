// Screenshots of the docked screens (title, status, buy, sell, equip, charts,
// data, market, inventory with cargo): node harness/mdocked.mjs [outdir]
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { BBC } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/utils.js";
import { loadSyms, ROOT } from "./mlib.mjs";
import { writeFileSync, mkdirSync } from "fs";
const OUT = process.argv[2] || "/tmp/dock"; mkdirSync(OUT, { recursive: true });
const sy = loadSyms(`${ROOT}master/build/symbols.txt`);
const s = new MachineSession("Master"); await s.initialise(); await s.boot(30);
s.loadDisc(`${ROOT}master/build/elite-master-sng47.ssd`); s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
const cpu = s._machine.processor; const secs = n => s.runFor(2000000 * n);
const snap = async n => writeFileSync(`${OUT}/${n}.png`, await s.screenshotActive({ scale: 1 }));
const key = async (k, hold = 0.15, after = 1.5) => { cpu.sysvia.keyDownRaw(BBC[k]); await secs(hold); cpu.sysvia.keyUpRaw(BBC[k]); await secs(after); };
await secs(28); await snap("00-title");
await key("N"); await secs(3); await key("SPACE"); await secs(4); await snap("01-status");
for (const [k, n] of [["F4","05-galchart"],["F1","02-buy"],["RETURN",""],["F2","03-sell"],["F3","04-equip"],["RETURN",""],["F5","06-shortchart"],["F6","07-data"]]) { await key(k, 0.15, 3); if (n) await snap(n); }
// buy some cargo then sell screen: 
await key("F1", 0.15, 2); await s.type("5"); await key("RETURN", 0.1, 2); for (let i = 0; i < 16; i++) await key("RETURN", 0.1, 0.5);
await key("F9", 0.15, 3); await snap("11-inventory-cargo"); await key("F2", 0.15, 3); await snap("12-sell");
process.exit(0);
