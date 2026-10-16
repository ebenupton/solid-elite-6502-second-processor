// The loader's sideways RAM check, made to fail: boots the build with bank 6
// treated as not RAM (at CHK1's first read of bank 6 the PC goes to CHKF) and
// saves a screenshot of what the user sees. node harness/mbankcheck.mjs [out.png]
// Exit status 0 if the machine ends in CHKF's stop loop.
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { ROOT } from "./mlib.mjs";
import { readFileSync, writeFileSync } from "fs";
const lst = readFileSync(`${ROOT}master/build/compile.txt`, "latin1").split("\n");
const addrAfter = (lab, k) => { const i = lst.findIndex(l => l.trim() === "." + lab); return parseInt(lst[i + k].trim().split(/\s+/)[0], 16); };
const CHK1b = addrAfter("CHK1", 2), CHKF = addrAfter("CHKF", 1), CHK3 = addrAfter("CHK3", 1);
const s = new MachineSession("Master"); await s.initialise(); await s.boot(30);
s.loadDisc(`${ROOT}master/build/elite-master-sng47.ssd`); s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
const cpu = s._machine.processor;
cpu.debugInstruction.add(pc => { if (pc === CHK1b && cpu.x === 6) cpu.pc = CHKF; return false; });
await s.runFor(2000000 * 15);
writeFileSync(process.argv[2] || "/tmp/bankcheck.png", await s.screenshotActive({ scale: 1 }));
const ok = cpu.pc === CHK3;
console.log(ok ? "BANKCHECK PASS (stopped at the message)" : `BANKCHECK FAIL (pc ${cpu.pc.toString(16)})`);
process.exit(ok ? 0 : 1);
