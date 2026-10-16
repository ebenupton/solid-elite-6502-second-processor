// Screenshots of an event: node harness/mevent.mjs out label "sym+off=val,..." nshots interval [keys]
// New game (N, SPACE), the pokes, launch (f0); then at the first TT100 with bank 4
// paged (ANYBANK=1: any) the PC is set to label (e.g. GOIN: dock, with the hangar
// and any mission briefing; DEATH; ESCAPE; TT18), and nshots screenshots are
// taken interval seconds apart (keys: comma-separated BBC key names to press
// after each). DISC and SYMS override the build (e.g. the reference).
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { BBC } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/utils.js";
import { loadSyms, ROOT } from "./mlib.mjs";
import { writeFileSync, mkdirSync } from "fs";
const [OUT, GOTO, POKES, NS, IV, KEYS] = process.argv.slice(2); mkdirSync(OUT, { recursive: true });
const sy = loadSyms(process.env.SYMS || `${ROOT}master/build/symbols.txt`);
const s = new MachineSession("Master"); await s.initialise(); await s.boot(30);
s.loadDisc(process.env.DISC || `${ROOT}master/build/elite-master-sng47.ssd`); s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
const cpu = s._machine.processor; const secs = n => s.runFor(2000000 * n);
const key = async (k, hold = 0.15, after = 1.5) => { cpu.sysvia.keyDownRaw(BBC[k]); await secs(hold); cpu.sysvia.keyUpRaw(BBC[k]); await secs(after); };
await secs(28); await key("N"); await secs(3); await key("SPACE"); await secs(4);
for (const p of (POKES || "").split(",").filter(x => x)) { const [a, v] = p.split("="); const ad = isNaN(+a) ? sy[a.split("+")[0]] + (+(a.split("+")[1] || 0)) : +a; cpu.ramRomOs[ad] = +v; }
await key("F0", 0.2, 12);
let armed = true;
cpu.debugInstruction.add(pc => { if (armed && pc === sy.TT100 && (process.env.ANYBANK || (cpu.romsel & 15) === 4)) { armed = false; cpu.pc = sy[GOTO]; } return false; });
await secs(0.5);
for (let i = 0; i < +NS; i++) { await secs(+IV); writeFileSync(`${OUT}/${String(i).padStart(2, "0")}.png`, await s.screenshotActive({ scale: 1 }));
  console.log(i, "pc", cpu.pc.toString(16), "romsel", cpu.romsel, "QQ11", cpu.ramRomOs[sy.QQ11], "acccon", cpu.acccon);
  if (KEYS && KEYS.split(",")[i]) await key(KEYS.split(",")[i], 0.15, 0.5); }
process.exit(0);
