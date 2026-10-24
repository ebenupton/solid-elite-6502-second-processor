#!/usr/bin/env node
// tstation.mjs: the station in front of a planet just over 65536 away must be
// drawn (a docking run with the planet behind the station). The scene is the
// user's save state's (2026-10-23, the 25 fps 9369154 disc): the planet at
// z = 67125, the Coriolis station dead ahead at z = 3618, a transporter.
// f_behind compared 16 bits of the planet's z (INWK+7, INWK+6) with the
// ship's, so the planet's &10635 read as 1589, nearer than the station, and
// the station, inside the planet's disc on screen, was hidden.
//
// node tube/tools/tstation.mjs [--host Master|B] [--disc d] [--psyms s] [--out dir]
//
// New game, launch (f0), then at MLOOP the scene's ship slots (K%'s first
// three, FRIN to JUNK) are put in and the speed set to 0; over the next 8
// iterations every frame that records the station (F_STYP 2) must draw it
// (f_ship gets past f_behind to fsh_nf0). Exit 0 on success.
import { BBC } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/utils.js";
import { bootTube, ROOT } from "../../harness/tlib.mjs";
import { loadSyms } from "../../harness/mlib.mjs";
import { writeFileSync, mkdirSync } from "fs";
import { parseArgs } from "../../harness/args.mjs";
const a = parseArgs({ host: "value", disc: "value", psyms: "value", out: "value" });
const HOST = a.host || "Master";
const DISC = a.disc || `${ROOT}tube/build/elite-tube${HOST === "B" ? "-b" : ""}.ssd`;
const sy = loadSyms(a.psyms || `${ROOT}tube/build/psyms.txt`);
const OUT = a.out || `${ROOT}scratch/tstation-${HOST}`;
mkdirSync(OUT, { recursive: true });
// the scene: K% (three slots: planet, station, transporter), FRIN .. JUNK
const KS = "000000a546003606014bca1db806198eba454ab8835d12c4102d5c00007f7f100000000024000000010000230e0000000020005a9cd0852e4590b52fc14b839b0000ff001e817e0af000000000fc06001d2f0000000018005c009100dc001800dd00108d820a00008018f16b072061";
const WS = "80020a0000000000000000000000000100000000000000010000000000000000000000000000000000000000000000";
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
// at MLOOP: the scene in
let atLoop = false;
const h1 = t.addParHook(pc => pc === sy.MLOOP ? (atLoop = true) : false);
for (let k = 0; k < 200 && !atLoop; k++) t.run(20000);
h1.remove();
if (!atLoop) { console.log("FAIL: never reached MLOOP"); process.exit(1); }
Buffer.from(KS, "hex").forEach((b, i) => { pm[sy["K%"] + i] = b; });
Buffer.from(WS, "hex").forEach((b, i) => { pm[sy.FRIN + i] = b; });
pm[sy.DELTA] = 0; pm[sy.QQ11] = 0; pm[sy.VIEW] = 0;
// over 8 iterations: the station recorded, and drawn
let iters = 0, recorded = 0, drawn = 0, frames = 0;
t.addParHook(pc => {
  if (pc === sy.p_sync) iters++;
  if (pc === sy.f_ships) frames++;
  if (pc === sy.f_ship && pm[sy.F_STYP + t.par.a] === 2) recorded++;
  if (pc === sy.fsh_nf0 && pm[sy.F_STYP + pm[sy.f_si]] === 2) drawn++;
  return false;
});
for (let k = 0; k < 2000 && iters < 8; k++) t.run(20000);
writeFileSync(`${OUT}/station.png`, await s.screenshot());
const ok = recorded > 0 && drawn === recorded;
console.log(`${iters} iterations, ${frames} frames with ships: the station recorded in ${recorded}, drawn in ${drawn}: ${ok ? "ok" : "FAIL (hidden behind the planet)"}`);
process.exit(ok ? 0 : 1);
