#!/usr/bin/env node
// tdock.mjs: a docking with the Constrictor mission's briefing, then the
// launch, on the Tube (the paths run1 does not reach: DOENTRY, the docking
// tunnel from the space view, HALL's frame, BRIEF and its frames, PAUSE's
// key waits, the launch). New game, launch (f0); at a TT100 the mission
// state is set as harness/mbrief.mjs's brief1 (TP = 0, TALLY+1 = 5, galaxy
// 0) with RAND fixed, and the PC set to GOIN; every key wait is answered
// with SPACE; then STATUS (the briefing's BAY), f0 again and 50 iterations
// of flight. Prints the overlay loads in each part and exits 0 if it all
// happened without a crash (p_crash). Screenshots in --out.
//
// node tube/tools/tdock.mjs [--host Master|B] [--disc d] [--psyms s] [--out dir]
import { BBC } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/utils.js";
import { bootTube, ROOT } from "../../harness/tlib.mjs";
import { loadSyms } from "../../harness/mlib.mjs";
import { writeFileSync, mkdirSync } from "fs";
import { parseArgs } from "../../harness/args.mjs";
const a = parseArgs({ host: "value", disc: "value", psyms: "value", out: "value" });
const HOST = a.host || "Master";
const DISC = a.disc || `${ROOT}tube/build/elite-tube${HOST === "B" ? "-b" : ""}.ssd`;
const sy = loadSyms(a.psyms || `${ROOT}tube/build/psyms.txt`);
const OUT = a.out || `${ROOT}scratch/tdock-${HOST}`;
mkdirSync(OUT, { recursive: true });
const t = await bootTube({ host: HOST, disc: DISC, mhz: HOST === "B" ? 3 : 4 });
const s = t.s, host = t.host, pm = t.par.memory;
s.keyDown(16); s.reset(true); host.execute(2e6 * 2); s.keyUp(16);
s._video.frameSkipCount = 0;
const secs = n => { for (let k = 0; k < n * 10; k++) host.execute(2e5); };
const key = (k, hold = 0.15, after = 0.6) => { host.sysvia.keyDownRaw(BBC[k]); secs(hold); host.sysvia.keyUpRaw(BBC[k]); secs(after); };
const snap = async n => writeFileSync(`${OUT}/${n}.png`, await s.screenshot());
// a label of overlay D's (X_C) counts only while D is in
const inD = n => sy[n + "_C"] !== undefined ? [sy[n + "_C"], 1] : [sy[n], 0];
const at = (pc, [ad, ov]) => pc === ad && (!ov || pm[sy.ovl_cur] === 1);
const L = Object.fromEntries(["DOENTRY", "BRIEF", "BRL1", "PAL1", "PAUSE2", "STATUS", "HALL", "LAUN", "HFS1", "TT110L"].map(n => [n, inD(n)]));
let phase = "fly", crashed = false, waiting = null, iters = 0;
const seen = {}, loads = {};
t.addParHook(pc => {
  if (pc === sy.p_crash) crashed = true;
  if (pc === sy.ovl_get) { const k = `${phase} ${pm[sy.ovl_cur] === 1 ? "D" : "S"}`; loads[k] = (loads[k] || 0) + 1; }
  if (pc === sy.p_sync) iters++;
  if (phase === "arm" && pc === sy.TT100) {
    [0x31, 0x5c, 0x12, 0xa7].forEach((b, i) => { pm[2 + i] = b; });
    pm[sy.TP] = 0; pm[sy.TALLY + 1] = 5; pm[sy.GCNT] = 0;
    t.par.pc = sy.GOIN; phase = "dock";
    return false;
  }
  for (const [n, l] of Object.entries(L)) if (at(pc, l)) seen[`${phase} ${n}`] = (seen[`${phase} ${n}`] || 0) + 1;
  if (phase === "dock" && (at(pc, L.PAL1) || at(pc, L.PAUSE2)) && !waiting) waiting = at(pc, L.PAL1) ? "PAL1" : "PAUSE2";
  if (phase === "dock" && at(pc, L.STATUS)) phase = "status";
  return false;
});
secs(HOST === "B" ? 34 : 28);
key("N"); secs(3);
key("SPACE"); secs(4);
key("F0", 0.2, 8);
phase = "arm";
for (let k = 0; k < 400 && phase === "arm"; k++) secs(0.05);
let n = 0;
for (let k = 0; k < 3000 && phase === "dock"; k++) {
  if (waiting) {
    secs(2.4); await snap(`wait${++n}`);
    host.sysvia.keyDownRaw(BBC.SPACE); secs(0.4); host.sysvia.keyUpRaw(BBC.SPACE); secs(0.6);
    waiting = null;
  } else secs(0.05);
}
secs(1); await snap("status");
const ok1 = phase === "status";
phase = "launch";
key("F0", 0.2, 1);
const i0 = iters;
for (let k = 0; k < 3000 && iters < i0 + 50; k++) secs(0.05);
await snap("flight");
console.log("labels reached:", JSON.stringify(seen));
console.log("overlay loads (phase, overlay loaded):", JSON.stringify(loads));
const ok = ok1 && !crashed && iters >= i0 + 50 && seen["dock BRIEF"] && seen["dock BRL1"] && seen["launch TT110L"];
console.log(`${n} key waits; ${ok1 ? "docked, briefed, STATUS" : "never reached STATUS"}; ${iters - i0} iterations after the launch${crashed ? "; CRASH (p_crash)" : ""}: ${ok ? "ok" : "FAIL"}`);
process.exit(ok ? 0 : 1);
