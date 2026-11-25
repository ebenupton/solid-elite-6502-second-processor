#!/usr/bin/env node
// tdockview.mjs: the last seconds of a docking run, posed (harness/
// mdockview.mjs, for the Tube's hosts): the space station dead ahead with its
// slot towards us and level, the sun (parked, as in the safe zone) ahead
// beyond it, and the stardust, flown in at a steady speed until we dock.
//
// node tube/tools/tdockview.mjs [--host Master|B] [--disc d] [--psyms s]
//      [--out dir] [--z z0] [--speed s] [--sx x] [--sy y] [--every n]
//      [--at k --out2 z] [--n iterations]
//
// New game, launch (f0), then the scene is put in on the parasite at an
// MLOOP (from the instruction hook, so that it lands between two iterations)
// and flown on. At each MLOOP the station's z is noted, and every n
// iterations (and every one once the station is nearer than 400) a
// screenshot of the host's screen is written to <out>/dv-<iteration>-z<z>.png.
// With --at k --out2 z the station is put at z at iteration k (with --speed 0
// and --z between 128 and the slot's face, 160, we sit inside the station
// until then, out of docking range).
import { BBC } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/utils.js";
import { bootTube, ROOT } from "../../harness/tlib.mjs";
import { loadSyms } from "../../harness/mlib.mjs";
import { writeFileSync, mkdirSync } from "fs";
import { parseArgs } from "../../harness/args.mjs";
const a = parseArgs({ host: "value", disc: "value", psyms: "value", out: "value", z: "value", speed: "value", sx: "value", sy: "value", every: "value", at: "value", out2: "value", n: "value" });
const HOST = a.host || "Master";
const DISC = a.disc || `${ROOT}tube/build/elite-tube.ssd`;
const sy = loadSyms(a.psyms || `${ROOT}tube/build/psyms.txt`);
const OUT = a.out || `${ROOT}scratch/tdockview-${HOST}`;
mkdirSync(OUT, { recursive: true });
const NI = 37, SST = 2, unit = 0x6000;
const Z0 = +(a.z || 1400), SPEED = +(a.speed ?? 12), EVERY = +(a.every || 4), NMAX = +(a.n || 400);
function blockBytes({ x, y, z, nose = [0, 0, -1], roof = [0, 1, 0], side = [1, 0, 0], heap = 0 }) {
  const q = new Array(NI).fill(0);
  const c = (o, v) => { const m = Math.abs(Math.round(v)); q[o] = m & 255; q[o + 1] = (m >> 8) & 255; q[o + 2] = ((m >> 16) & 127) | (v < 0 ? 128 : 0); };
  c(0, x); c(3, y); c(6, z);
  const v = (o, w) => w.forEach((t, j) => { const m = Math.min(32767, Math.round(Math.abs(t) * unit)); q[o + 2 * j] = m & 255; q[o + 2 * j + 1] = (m >> 8) | (t < 0 ? 128 : 0); });
  v(9, nose); v(15, roof); v(21, side);
  q[33] = heap & 255; q[34] = heap >> 8; q[35] = 100;
  return q;
}
const R = r => 24576 * 256 / r;
const t = await bootTube({ host: HOST, disc: DISC, mhz: HOST === "B" ? 3 : 4 });
const s = t.s, host = t.host, pm = t.par.memory;
s.keyDown(16); s.reset(true); host.execute(2e6 * 2); s.keyUp(16);
s._video.frameSkipCount = 0;
const secs = n => { for (let k = 0; k < n * 10; k++) host.execute(2e5); };
const key = (k, hold = 0.15, after = 0.6) => { host.sysvia.keyDownRaw(BBC[k]); secs(hold); host.sysvia.keyUpRaw(BBC[k]); secs(after); };
secs(HOST === "B" ? 34 : 28);
key("N"); secs(3);
key("SPACE"); secs(4);
key("F0", 0.2, 12);
function pose() {
  const K = sy["K%"];
  const put = (slot, type, q) => { for (let i = 0; i < NI; i++) pm[K + NI * slot + i] = q[i]; pm[sy.FRIN + slot] = type; };
  for (let i = 0; i <= 12; i++) pm[sy.FRIN + i] = 0;
  for (let i = 0; i < 34; i++) pm[sy.MANY + i] = 0;
  pm[sy.JUNK] = 0;
  put(0, 128, blockBytes({ x: 0, y: -20000, z: -80000 }));
  put(1, SST, blockBytes({ x: 0, y: 0, z: Z0, roof: [1, 0, 0], side: [0, -1, 0], heap: sy.LSO }));   // the slot level (ISDK: |roofv_x| large)
  pm[sy.SSPR] = 1;
  const p = blockBytes({ x: R(24) * +(a.sx || 0.05), y: R(24) * +(a.sy || 0.03), z: R(24) });
  for (let i = 0; i < NI; i++) pm[sy.SUNPK + i] = p[i];
  pm[sy.SUNPF] = 0x80;
  pm[sy.VIEW] = 0; pm[sy.DELTA] = SPEED; pm[sy.ALPHA] = 0; pm[sy.BETA] = 0; pm[sy.ALP1] = 0; pm[sy.ALP2] = 0; pm[sy.BET1] = 0; pm[sy.BET2] = 0;
  pm[sy.ENERGY] = 255; pm[sy.FSH] = 255; pm[sy.ASH] = 255; pm[sy.MCNT] = 1;
}
const z1 = () => { const q = sy["K%"] + NI; return (pm[q + 6] | pm[q + 7] << 8 | (pm[q + 8] & 127) << 16) * (pm[q + 8] & 128 ? -1 : 1); };
let posed = false, k = 0, docked = false, pending = null;
const log = [];
t.addParHook(pc => {
  if (pc !== sy.MLOOP) return false;
  if (!posed) { pose(); posed = true; return false; }
  if (pm[sy.QQ11] !== 0) { docked = true; return false; }
  k++;
  if (a.at && k === +a.at) { const q = sy["K%"] + NI, v = +a.out2; pm[q + 6] = v & 255; pm[q + 7] = v >> 8; }
  pending = { k, z: z1() };
  return false;
});
for (let q = 0; q < 400000 && !docked && log.length < NMAX; q++) {
  t.run(20000);
  if (pending) {
    const p = pending; pending = null; log.push(p);
    if (p.k % EVERY === 0 || p.z < 400) writeFileSync(`${OUT}/dv-${String(p.k).padStart(3, "0")}-z${p.z}.png`, await s.screenshot());
  }
}
for (const p of log) console.log(`it ${p.k} z ${p.z}`);
console.log(docked ? "DOCKED" : "not docked");
process.exit(0);
