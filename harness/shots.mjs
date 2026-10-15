// Take a series of screenshots.
// node harness/shots.mjs MODEL DISC OUTDIR START_SECS [DT_SECS] [COUNT] [LABEL SYMFILE]
// If LABEL is given, wait until the CPU reaches that label (looked up in the
// beebasm -d symbol dump SYMFILE) after START_SECS, then take the screenshots.
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { writeFileSync, mkdirSync, readFileSync } from "fs";
const [model, disc, out, t0, dt0, count0, label, symfile] = process.argv.slice(2);
const dt = +(dt0 || 0.37), count = +(count0 || 8);
mkdirSync(out, { recursive: true });
const s = new MachineSession(model);
await s.initialise(); await s.boot(30); s.loadDisc(disc);
s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
await s.runFor(2000000 * +t0);
if (label) {
    const m = readFileSync(symfile, "utf8").match(new RegExp(`'${label.replace(/[%$]/g, "\\$&")}':(\\d+)`));
    const addr = +m[1];
    const cpu = s._machine.processor;
    let hit = false;
    const h = pc => { if (pc === addr) hit = true; return false; };
    cpu.debugInstruction.add(h);
    while (!hit && cpu.cycleSeconds < 3000) { h(cpu.pc); cpu.execute(20000); }
    console.log(`${label} reached at ${cpu.cycleSeconds} s`);
}
for (let i = 0; i < count; i++) {
    await s.runFor(2000000 * dt);
    writeFileSync(`${out}/t${String(i).padStart(3, "0")}.png`, await s.screenshotActive({ scale: 1 }));
}
process.exit(0);
