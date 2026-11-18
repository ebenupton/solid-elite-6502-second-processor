// A speed benchmark that does not move when the game's random numbers do:
// frozen scenes. Boots the build (SHIFT+BREAK, a new commander, launch with
// f0, as harness/msunnear.mjs), then for each scene puts the scene's state in
// at an MLOOP (the ship slots, the planet, the sun, the view, our speed and
// rotation), lets it run WARM iterations and snapshots the game state
// (mlib.regionsFor). Then it runs N iterations in windows of M: the snapshot
// is put back at the start of each window, so the scene starts the same in
// any build and moves for M iterations (the renderer does real work, and
// its memos hit as in play); within a window, at every MLOOP, RAND is put
// back and every slot after the scene's ships emptied (with MANY and SLSP
// as in the snapshot), so that no ship spawns and no random number taken
// before (the original's sun's edge, explosion clouds ...) changes what
// follows. The figure is the emulated cycles from one MLOOP to the next,
// averaged over the N iterations, and the iterations a second; and the work:
// those cycles less the frame layer's wait for the flip (7 cycles a turn of
// ff2's LDA GFLIP : BNE ff2), as the 25 a second cap makes the first figure
// move with the vsync's phase, by about 1% either way for a small change.
//
// The scenes (the front view unless said; positions in the game's units):
//   flight     cruising: the planet far off (radius about 20), three ships
//              ahead at 3000-6000, rolling a little
//   combat     five ships close round us (800-2000), turning, our rolling and
//              pitching; the planet small
//   beachball  the approach: the planet's beach ball filling the view
//              (radius about 110), one ship
//   sun        a visible sun (radius 32) beside the planet (radius 60)
//   docking    the station ahead at 1500, the planet behind it
//   zone       the safe zone: the station near and ahead, the sun parked
//              behind us (in a build without SUNPK the sun is S_SUN's or
//              none), two ships
//   rear       the beach ball in the rear view, with ships
//
// node harness/mbench.mjs [--disc d] [--syms s] [--scene a,b] [--n 128] [--warm 8] [--out file.json]
// Prints "scene: cycles/iteration it/s work" per scene.
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { BBC } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/utils.js";
import { loadSyms, ROOT, regionsFor, pinRtc } from "./mlib.mjs";
import { writeFileSync } from "fs";
import { SCENES, pose } from "./mbench-scenes.mjs";
import { parseArgs } from "./args.mjs";

const a = parseArgs({ disc: "value", syms: "value", scene: "value", n: "value", warm: "value", out: "value" });
const SYMS = a.syms || `${ROOT}master/build/symbols.txt`, DISC = a.disc || `${ROOT}master/build/elite-master-sng47.ssd`;
const sy = loadSyms(SYMS);
const N = +(a.n || 128), WARM = +(a.warm || 8), M = 32;
const which = (a.scene || Object.keys(SCENES).join(",")).split(",");

const s = new MachineSession("Master"); await s.initialise(); pinRtc(s); await s.boot(30);
s.loadDisc(DISC); s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
const cpu = s._machine.processor, ram = cpu.ramRomOs, secs = n => s.runFor(2000000 * n);
const key = async (k, hold = 0.2, after = 1) => { cpu.sysvia.keyDownRaw(BBC[k]); await secs(hold); cpu.sysvia.keyUpRaw(BBC[k]); await secs(after); };
await secs(28); await key("N"); await secs(3); await key("SPACE"); await secs(4); await key("F0", 0.2, 12);
const regions = regionsFor(sy);
const at = (pc, n) => pc === sy[n] && (sy.__bank[n] === undefined || sy[n] < 0x8000 || (cpu.romsel & 15) === (sy.__bank[n] & 15));
const cyc = () => cpu.cycleSeconds * 2e6 + cpu.currentCycles;
const FF2 = sy.ff2;                                 // the frame layer's wait for the flip: LDA GFLIP : BNE ff2

const results = {};
for (const name of which) {
    const sc = SCENES[name];
    let k = -1, snap = null, times = [], posed = false, done = false, rand, many, slsp, spins = 0, lastPc = -1, spinAt = [];
    const h = cpu.debugInstruction.add(pc => {
        if (FF2 !== undefined && pc === FF2 && lastPc === FF2 + 3 && at(pc, "ff2")) spins++;
        lastPc = pc;
        if (!at(pc, "MLOOP") || done) return false;
        k++;
        if (!posed) { pose(sy, ram, sc); posed = true; k = 0; return false; }
        if (k === WARM) { snap = regions.map(([b, n]) => Array.from(ram.subarray(b, b + n))); rand = Array.from(ram.subarray(sy.RAND, sy.RAND + 4));
            many = Array.from(ram.subarray(sy.MANY, sy.MANY + 34)); slsp = [ram[sy.SLSP], ram[sy.SLSP + 1]]; }
        if (snap) {
            if (times.length % M === 0) regions.forEach(([b], j) => snap[j].forEach((v, i) => { ram[b + i] = v; }));
            else {
                rand.forEach((v, i) => { ram[sy.RAND + i] = v; }); many.forEach((v, i) => { ram[sy.MANY + i] = v; });
                ram[sy.SLSP] = slsp[0]; ram[sy.SLSP + 1] = slsp[1];
                for (let i = 2 + sc.ships.length; i <= 12; i++) ram[sy.FRIN + i] = 0;
            }
            times.push(cyc()); spinAt.push(spins);
        }
        if (times.length > N) done = true;
        return false;
    });
    for (let q = 0; q < 200000 && !done; q++) await s.runFor(20000);
    h.remove();
    const per = (times[times.length - 1] - times[0]) / (times.length - 1);
    const work = per - 7 * (spinAt[spinAt.length - 1] - spinAt[0]) / (times.length - 1);
    results[name] = { cycles: Math.round(per), its: +(2e6 / per).toFixed(3), work: Math.round(work), n: times.length - 1 };
    console.log(`${name.padEnd(10)} ${String(Math.round(per)).padStart(7)} cycles/iteration  ${(2e6 / per).toFixed(2).padStart(6)} it/s  ${String(Math.round(work)).padStart(7)} work`);
}
if (a.out) writeFileSync(a.out, JSON.stringify({ disc: DISC, N, WARM, results }, null, 1));
process.exit(0);
