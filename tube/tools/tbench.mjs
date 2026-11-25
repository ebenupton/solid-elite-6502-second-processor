#!/usr/bin/env node
// tbench.mjs: harness/mbench.mjs's frozen scenes on the Tube build, either
// host. Boots the build (SHIFT+BREAK, a new commander, launch with f0), then
// for each scene puts mbench's scene in at an MLOOP (the ship slots, the
// planet, the sun or the station and the parked sun, the view, our speed and
// rotation), lets it run WARM iterations and snapshots the game state
// (mlib.regionsFor, the parasite's); then runs N iterations in windows of M,
// the snapshot put back at each window's start, and within a window RAND,
// MANY and SLSP put back and the slots after the scene's ships emptied at
// every MLOOP, as mbench.mjs does, so that the scene is the same in any build.
//
// Per scene: the host's cycles (2 MHz) from one MLOOP to the next, averaged
// over the N iterations, and the iterations a second; and the parasite's
// work: its own cycles in those iterations less those spent waiting for the
// host (p_buf's pfwait, the flip's turn; rpg, the ring full), in host cycles
// (the parasite's divided by its clock's multiple). The 25 a second cap and
// where the flips fall move the first figure by about 1% either way for a
// small change (mbench.mjs's note): quote small changes by the work, or by
// the cycles of the routines a change touches.
//
// node tube/tools/tbench.mjs [--host Master|B] [--disc d] [--psyms s]
//      [--scene a,b] [--n 128] [--warm 8] [--out file.json] [--pin]
// --pin also puts in the stardust (a fixed pseudo-random field) and RAND at
// the pose, as harness/mbench.mjs --pin does, so that what the boot and
// launch left (which moves with the build's speed) is not carried into the
// scenes; one scene a run (--scene) for figures independent of the others.
// (the parasite at 4 MHz with the Master host, 3 MHz with the Model B host,
// as the gate's speed windows)
import { BBC } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/utils.js";
import { bootTube, ROOT } from "../../harness/tlib.mjs";
import { loadSyms, regionsFor } from "../../harness/mlib.mjs";
import { SCENES, pose } from "../../harness/mbench-scenes.mjs";
import { writeFileSync } from "fs";
import { parseArgs } from "../../harness/args.mjs";

const a = parseArgs({ host: "value", disc: "value", psyms: "value", scene: "value", n: "value", warm: "value", out: "value", pin: "flag" });
const HOST = a.host || "Master", MHZ = HOST === "B" ? 3 : 4;
const DISC = a.disc || `${ROOT}tube/build/elite-tube.ssd`;
const sy = loadSyms(a.psyms || `${ROOT}tube/build/psyms.txt`);
const N = +(a.n || 128), WARM = +(a.warm || 8), M = 32;

const t = await bootTube({ host: HOST, disc: DISC, mhz: MHZ });
const s = t.s, host = t.host, par = t.par, ram = par.memory;
s.keyDown(16); s.reset(true); host.execute(2e6 * 2); s.keyUp(16);
const secs = n => { for (let k = 0; k < n * 10; k++) t.run(2e5); };
const key = (k, hold = 0.2, after = 1) => { host.sysvia.keyDownRaw(BBC[k]); secs(hold); host.sysvia.keyUpRaw(BBC[k]); secs(after); };
secs(HOST === "B" ? 34 : 28); key("N"); secs(3); key("SPACE"); secs(4);
for (let k = 0; k < 6 && ram[sy.QQ12]; k++) key("F0", 0.2, 6);
if (ram[sy.QQ12]) { console.log("never launched"); process.exit(1); }
const regions = regionsFor(sy);
const MULT = par.cpuMultiplier;
// the parasite's cycles run so far: what its execute() has been given less
// what it has left (tlib.mjs's patchParasite counts its budget down)
let granted = 0;
{ const ex = par.execute; par.execute = function (c) { granted += c * this.cpuMultiplier; return ex.call(this, c); }; }
const pcyc = () => granted - par.cycles;
// the waits for the host: from the entry of each to the return to its caller
const WAITS = ["pfwait", "rpg"].map(n => sy[n]).filter(v => v !== undefined);

const results = {};
for (const name of (a.scene || Object.keys(SCENES).join(",")).split(",")) {
    const sc = SCENES[name];
    let k = -1, snap = null, times = [], works = [], posed = false, done = false, rand, many, slsp;
    let waitSum = 0, wait = null;
    const h = t.addParHook(pc => {
        if (wait && pc === wait.ret && par.s === wait.s) { waitSum += pcyc() - wait.c; wait = null; }
        else if (!wait && WAITS.includes(pc)) {
            const ret = ((ram[0x100 + ((par.s + 1) & 255)] | ram[0x100 + ((par.s + 2) & 255)] << 8) + 1) & 0xffff;
            wait = { ret, s: (par.s + 2) & 255, c: pcyc() };
        }
        if (pc !== sy.MLOOP || done) return false;
        k++;
        if (!posed) {
            pose(sy, ram, sc); posed = true; k = 0;
            if (a.pin) {                            // --pin: the stardust and RAND put in too
                let q = 12345; const r8 = () => (q = (q * 1103515245 + 12345) & 0x7fffffff, (q >> 16) & 255);
                for (let i = 0; i < sy.SXL - sy.SX; i++) { ram[sy.SX + i] = r8(); ram[sy.SXL + i] = r8(); ram[sy.SY + i] = r8();
                    ram[sy.SYL + i] = r8(); ram[sy.SZ + i] = r8() | 17; ram[sy.SZL + i] = r8(); }
                [0x49, 0x53, 0x7A, 0x2E].forEach((v, i) => { ram[sy.RAND + i] = v; });
            }
            return false;
        }
        if (k === WARM) { snap = regions.map(([b, n]) => Array.from(ram.subarray(b, b + n))); rand = Array.from(ram.subarray(sy.RAND, sy.RAND + 4));
            many = Array.from(ram.subarray(sy.MANY, sy.MANY + 34)); slsp = [ram[sy.SLSP], ram[sy.SLSP + 1]]; }
        if (snap) {
            if (times.length % M === 0) regions.forEach(([b], j) => snap[j].forEach((v, i) => { ram[b + i] = v; }));
            else {
                rand.forEach((v, i) => { ram[sy.RAND + i] = v; }); many.forEach((v, i) => { ram[sy.MANY + i] = v; });
                ram[sy.SLSP] = slsp[0]; ram[sy.SLSP + 1] = slsp[1];
                for (let i = 2 + sc.ships.length; i <= 12; i++) ram[sy.FRIN + i] = 0;
            }
            times.push(t.hostCycles()); works.push(pcyc() - waitSum);
        }
        if (times.length > N) done = true;
        return false;
    });
    for (let q = 0; q < 400000 && !done; q++) t.run(20000);
    h.remove();
    const n = times.length - 1;
    const per = (times[n] - times[0]) / n, work = (works[n] - works[0]) / n / MULT;
    results[name] = { cycles: Math.round(per), its: +(2e6 / per).toFixed(3), work: Math.round(work), n };
    console.log(`${name.padEnd(10)} ${String(Math.round(per)).padStart(7)} cycles/iteration  ${(2e6 / per).toFixed(2).padStart(6)} it/s  ${String(Math.round(work)).padStart(7)} parasite work`);
}
if (a.out) writeFileSync(a.out, JSON.stringify({ disc: DISC, host: HOST, N, WARM, results }, null, 1));
process.exit(0);
