#!/usr/bin/env node
// tdock.mjs: dockings with the missions' briefings and debriefings, and an
// escape pod, each followed by the launch, on the Tube (the paths run1 does
// not reach: DOENTRY, the docking tunnel from the space view, HALL's frame,
// BRIEF and its frames, PAUSE's rotating ship and PAUSE2's key waits, the
// mission 2 messages, ESCAPE's frames, the launch). New game, launch (f0);
// then for each config, at a TT100 the mission state is set as
// harness/mbrief.mjs's (RAND fixed) and the PC set to GOIN (or, for escape,
// to ESCAPE); every key wait is answered with SPACE 2.4 s after it starts;
// then STATUS (the BAY at the end), f0 again and 30 iterations of flight
// (50 after the last). The configs (--configs, default all):
//   brief1    TP = 0, TALLY+1 = 5, galaxy 1: BRIEF, the Constrictor
//   debrief1  TP = 3: DEBRIEF
//   brief2    TP = 2, galaxy 3: BRIEF2
//   brief3    TP = 6, galaxy 3 at Ceerdi: BRIEF3
//   debrief2  TP = 10, galaxy 3 at Birera: DEBRIEF2
//   escape    TP = 0, TALLY+1 = 0: ESCAPE (the Cobra's 97 frames), the hangar
//             and BAY
// Prints the overlay loads in each part, the frame rates of the rotating
// ships (BRIEF's 64 frames, PAUSE's key waits, ESCAPE's frames) and the
// overlay loads between frames: a load between two frames (p_flip) with no
// TT66 and no text printed (TT26) between them, which is a swap within a
// sequence of frames (the briefing's ship, the title's, ESCAPE's, the space
// view), not a change of screen or text printed over the frames. Exits 0 if it all
// happened, with no crash (p_crash) and no load between frames (--max N:
// at most N). Screenshots in --out.
//
// node tube/tools/tdock.mjs [--host Master|B] [--disc d] [--psyms s] [--out dir] [--configs a,b] [--max N]
import { BBC } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/utils.js";
import { bootTube, ROOT } from "../../harness/tlib.mjs";
import { loadSyms } from "../../harness/mlib.mjs";
import { writeFileSync, mkdirSync } from "fs";
import { parseArgs } from "../../harness/args.mjs";
const a = parseArgs({ host: "value", disc: "value", psyms: "value", out: "value", configs: "value", max: "value" });
const HOST = a.host || "Master";
const DISC = a.disc || `${ROOT}tube/build/elite-tube.ssd`;
const sy = loadSyms(a.psyms || `${ROOT}tube/build/psyms.txt`);
const OUT = a.out || `${ROOT}scratch/tdock-${HOST}`;
const MAX = +(a.max || 0);
mkdirSync(OUT, { recursive: true });
const CONFIGS = {
  brief1: { st: { TP: 0, "TALLY+1": 5, GCNT: 0 }, need: ["BRIEF", "BRL1"] },
  debrief1: { st: { TP: 3, "TALLY+1": 5, GCNT: 0 }, need: ["DEBRIEF"] },
  brief2: { st: { TP: 2, "TALLY+1": 5, GCNT: 2 }, need: ["BRIEF2"] },
  brief3: { st: { TP: 6, "TALLY+1": 5, GCNT: 2, QQ0: 215, QQ1: 84 }, need: ["BRIEF3"] },
  debrief2: { st: { TP: 10, "TALLY+1": 5, GCNT: 2, QQ0: 63, QQ1: 72 }, need: ["DEBRIEF2"] },
  escape: { st: { TP: 0, "TALLY+1": 0, GCNT: 0 }, need: ["ESL1"], pc: "ESCAPE" },
};
const names = (a.configs || Object.keys(CONFIGS).join(",")).split(",");
const t = await bootTube({ host: HOST, disc: DISC, mhz: HOST === "B" ? 3 : 4 });
const s = t.s, host = t.host, pm = t.par.memory;
s.keyDown(16); s.reset(true); host.execute(2e6 * 2); s.keyUp(16);
s._video.frameSkipCount = 0;
const secs = n => { for (let k = 0; k < n * 10; k++) host.execute(2e5); };
const key = (k, hold = 0.15, after = 0.6) => { host.sysvia.keyDownRaw(BBC[k]); secs(hold); host.sysvia.keyUpRaw(BBC[k]); secs(after); };
const snap = async n => writeFileSync(`${OUT}/${n}.png`, await s.screenshot());
const sym = n => { const m = n.match(/^(\w+)\+(\d+)$/); return m ? sy[m[1]] + +m[2] : sy[n]; };
// a label of overlay D's (X_C) counts only while D is in
const inD = n => sy[n + "_C"] !== undefined ? [sy[n + "_C"], 1] : [sy[n], 0];
const at = (pc, [ad, ov]) => pc === ad && (!ov || pm[sy.ovl_cur] === 1);
const L = Object.fromEntries(["DOENTRY", "BRIEF", "BRL1", "BR2", "PAL1", "PAUSE2", "STATUS", "HALL", "LAUN", "HFS1", "TT110L",
  "DEBRIEF", "BRIEF2", "BRIEF3", "DEBRIEF2", "ESCAPE", "ESL1"].map(n => [n, inD(n)]));
let phase = "fly", cfg = null, crashed = false, waiting = null, iters = 0;
const seen = {}, loads = {};
// overlay loads between frames: since the last p_flip, the loads and whether
// TT66 or TT26 (text printed, which overlay D's extended tokens need) ran
let sinceLoads = 0, sinceTT66 = true;
const between = [];
// frame rates: [flips, seconds] by kind
const rate = {};
let flips = 0, brl1 = null, esl1 = null;
const flipsAt = () => flips;
const addRate = (k, f, sec) => { const r = rate[k] ||= [0, 0]; r[0] += f; r[1] += sec; };
t.addParHook(pc => {
  if (pc === sy.p_crash) crashed = true;
  if (pc === sy.ovl_get) { const k = `${phase} ${pm[sy.ovl_cur] === 1 ? "D" : "S"}`; loads[k] = (loads[k] || 0) + 1; sinceLoads++; }
  if (pc === sy.TT66 || pc === sy.TT26) sinceTT66 = true;
  if (pc === sy.p_flip) {
    flips++;
    if (sinceLoads && !sinceTT66) between.push(`${phase} (${sinceLoads})`);
    sinceLoads = 0; sinceTT66 = false;
  }
  if (pc === sy.p_sync) iters++;
  if (phase === "arm" && pc === sy.TT100) {
    [0x31, 0x5c, 0x12, 0xa7].forEach((b, i) => { pm[2 + i] = b; });
    for (const [k, v] of Object.entries(CONFIGS[cfg].st)) pm[sym(k)] = v;
    t.par.pc = sy[CONFIGS[cfg].pc || "GOIN"]; phase = `dock:${cfg}`;
    return false;
  }
  for (const [n, l] of Object.entries(L)) if (at(pc, l)) seen[`${phase} ${n}`] = (seen[`${phase} ${n}`] || 0) + 1;
  if (phase.startsWith("dock")) {
    if (at(pc, L.BRL1) && !brl1) brl1 = [flips, t.hostSecs()];
    if (at(pc, L.BR2) && brl1 && brl1.length === 2) { addRate("BRIEF's frames (BRL1, BRL2)", flips - brl1[0], t.hostSecs() - brl1[1]); brl1.push(0); }
    if (at(pc, L.ESL1) && !esl1) esl1 = [flips, t.hostSecs()];
    if (pc === sy.GOIN && esl1 && esl1.length === 2) { addRate("ESCAPE's frames (ESL1)", flips - esl1[0], t.hostSecs() - esl1[1]); esl1.push(0); }
    if ((at(pc, L.PAL1) || at(pc, L.PAUSE2)) && !waiting) waiting = at(pc, L.PAL1) ? "PAL1" : "PAUSE2";
    if (at(pc, L.STATUS)) phase = `status:${cfg}`;
  }
  return false;
});
secs(HOST === "B" ? 34 : 28);
key("N"); secs(3);
key("SPACE"); secs(4);
key("F0", 0.2, 8);
let n = 0, ok = true;
const done = [];
for (const [ci, c] of names.entries()) {
  cfg = c; brl1 = esl1 = null; phase = "arm";
  for (let k = 0; k < 400 && phase === "arm"; k++) secs(0.05);
  for (let k = 0; k < 3000 && phase.startsWith("dock"); k++) {
    if (waiting) {
      const f0 = flipsAt(), s0 = t.hostSecs(), w = waiting;
      secs(2.4); await snap(`${c}-wait${++n}`);
      if (w === "PAL1") addRate("PAUSE's key waits (PAL1)", flipsAt() - f0, t.hostSecs() - s0);
      host.sysvia.keyDownRaw(BBC.SPACE); secs(0.4); host.sysvia.keyUpRaw(BBC.SPACE); secs(0.6);
      waiting = null;
    } else secs(0.05);
  }
  secs(1); await snap(`${c}-status`);
  const ok1 = phase === `status:${c}`;
  phase = `launch:${c}`;
  key("F0", 0.2, 1);
  const i0 = iters, N = ci === names.length - 1 ? 50 : 30;
  for (let k = 0; k < 3000 && iters < i0 + N; k++) secs(0.05);
  await snap(`${c}-flight`);
  const okc = ok1 && iters >= i0 + N && CONFIGS[c].need.every(l => seen[`dock:${c} ${l}`]) && seen[`launch:${c} TT110L`];
  done.push(`${c} ${okc ? "ok" : "FAIL"}`);
  ok &&= okc;
}
console.log("labels reached:", JSON.stringify(seen));
console.log("overlay loads (phase, overlay loaded):", JSON.stringify(loads));
for (const [k, [f, sec]] of Object.entries(rate)) console.log(`${k}: ${f} frames in ${sec.toFixed(2)} s, ${(f / sec).toFixed(2)} a second`);
console.log(`overlay loads between frames (no TT66 or TT26 between them): ${between.length}${between.length ? ` (${between.slice(0, 8).join(", ")}${between.length > 8 ? " ..." : ""})` : ""}`);
ok &&= !crashed && between.length <= MAX;
console.log(`${n} key waits; ${done.join(", ")}${crashed ? "; CRASH (p_crash)" : ""}; ${between.length} loads between frames: ${ok ? "ok" : "FAIL"}`);
process.exit(ok ? 0 : 1);
