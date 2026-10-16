// Regression test: dock, launch, dock again (the docking computer), from a
// fresh boot, with real key presses. node harness/mredock.mjs [--disc d]
// [--syms s] [--out dir]. Exit status 0 if both dockings happen (DOENTRY
// reached twice) within 90 emulated seconds each; screenshots of each stage.
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { BBC } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/utils.js";
import { loadSyms, ROOT } from "./mlib.mjs";
import { writeFileSync, mkdirSync } from "fs";
const a = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => { if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1]]); return acc; }, []));
const sy = loadSyms(a.syms || `${ROOT}master/build/symbols.txt`);
const OUT = a.out || `${ROOT}scratch/master/redock`; mkdirSync(OUT, { recursive: true });
const s = new MachineSession("Master"); await s.initialise(); await s.boot(30);
s.loadDisc(a.disc || `${ROOT}master/build/elite-master-sng47.ssd`); s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
const cpu = s._machine.processor; const secs = n => s.runFor(2000000 * n);
const key = async (k, hold = 0.2, after = 1) => { cpu.sysvia.keyDownRaw(BBC[k]); await secs(hold); cpu.sysvia.keyUpRaw(BBC[k]); await secs(after); };
const snap = async n => writeFileSync(`${OUT}/${n}.png`, await s.screenshotActive({ scale: 1 }));
const DOE = sy.DOENTRY_C ?? sy.DOENTRY;
let docks = 0;
cpu.debugInstruction.add(pc => { if (pc === DOE && (sy.DOENTRY_C === undefined || (cpu.romsel & 15) === 7)) docks++; return false; });
await secs(28); await key("N"); await secs(3); await key("SPACE"); await secs(4);
cpu.ramRomOs[sy.DKCMP] = 0xff;
let ok = true;
for (let n = 1; n <= 2; n++) {
    await key("F0", 0.2, 10); await snap(`${n}-launched`);
    await key("C", 0.2, 1);
    let t = 0; while (docks < n && t < 90) { await secs(1); t++; if (t === 10) await snap(`${n}-docking`); }
    console.log(`docking ${n}: ${docks >= n ? `docked after ${t} s` : "NOT DOCKED after 90 s"}`);
    if (docks < n) { ok = false; await snap(`${n}-failed`); break; }
    await secs(8); await key("SPACE", 0.2, 3); await snap(`${n}-docked`);
}
console.log(ok ? "REDOCK PASS" : "REDOCK FAIL");
process.exit(ok ? 0 : 1);
