// Capture the filled planet's parameters and the rendered frames, for
// tools/planet_model.py (idealised model and artefact statistics).
//
// node harness/planet-capture.mjs [--disc build/elite-master.ssd]
//      [--syms build/symbols.txt] [--frames 3000] [--out dir] [--seed file]
//
// For every space-view frame with the planet as the disc layer, at f_reset
// (the end of F_FRAME, after the flip request) we record:
//   * the planet as PL9 saw it: INWK (orientation vectors with z), K, K3, K4,
//     TYPE; and per curve (H_PCURVE): CNT2, TGT, STP, K2/XX16 (u, v), K3, K4
//   * the frame layer's recording: F_PLX/Y/R/T, curves and points
//   * the disc-layer request: R_NDT/NDB, R_NDISCL/R, R_NDF, R_NDN/P/X0-3,
//     R_DBE/DBO, and this buffer's dirty extents
//   * the screen bytes of the buffer just drawn (&4000-&6FFF)
// Output: <out>/frames.jsonl (one JSON object per frame) and <out>/screens.bin
// (12288 bytes per frame, same order).
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { readFileSync, writeFileSync, mkdirSync, openSync, writeSync, closeSync } from "fs";

const a = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => { if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]); return acc; }, []));
const DISC = a.disc || "build/elite-master.ssd";
const SYMS = a.syms || "build/symbols.txt";
const FRAMES = +(a.frames || 3000);
const OUT = a.out || "/Users/ebenupton/elite/scratch/planet/cap";
mkdirSync(OUT, { recursive: true });
const syms = {};
for (const m of readFileSync(SYMS, "utf8").matchAll(/'([^']+)':(\d+)L?/g)) syms[m[1]] = +m[2];
const S = n => { if (syms[n] === undefined) throw new Error("no symbol " + n); return syms[n]; };

const s = new MachineSession("Master");
await s.initialise();
await s.boot(30);
s.loadDisc(DISC);
s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
const cpu = s._machine.processor;
const R = cpu.ramRomOs, ROMOFF = cpu.romOffset;

// optional: seed RAND etc. as compare.mjs does, from a file of "addr byte" lines
// (--seed orig: boot the original demo to TT170 and copy RAND, T% and WP into
// the port at its TT170, as compare.mjs does, so the same game is played)
let seed = null;
if (a.seed === "orig") {
    const osy = {};
    for (const m of readFileSync("/Users/ebenupton/elite/build/orig-symbols.txt", "utf8").matchAll(/'([^']+)':(\d+)L?/g)) osy[m[1]] = +m[2];
    const o = new MachineSession("B-DFS1.2");
    await o.initialise(); await o.boot(30);
    o.loadDisc("/Users/ebenupton/elite/ref/elite-demo-source-code-bbc-micro/5-compiled-game-discs/elite-demonstration-disc.ssd");
    o.keyDown(16); o.reset(true); await o.runFor(2000000); o.keyUp(16);
    const oc = o._machine.processor;
    let hit = false;
    oc.debugInstruction.add(pc => { if (pc === osy.TT170) { hit = true; return true; } return false; });
    while (!hit) oc.execute(50000);
    seed = [];
    for (const [lo, hi] of [[0, 3], [0x300, 0x371], [0xd40, 0xf38]]) for (let ad = lo; ad <= hi; ad++) seed.push([ad, oc.ramRomOs[ad]]);
    o.destroy?.();
}

const zp = (ad, n = 1) => Array.from(R.subarray(ad, ad + n));
const bank = (b, ad, n = 1) => Array.from(R.subarray(ROMOFF + b * 16384 + ad - 0x8000, ROMOFF + b * 16384 + ad - 0x8000 + n));
const hz = (ad, n = 1) => Array.from(R.subarray(ad - 0x3000, ad - 0x3000 + n));
const B6 = (n, k = 1) => bank(6, S(n), k);
const HZ = (n, k = 1) => hz(S(n), k);
const curBank = () => cpu.romsel & 15;

const PL9 = S("PL9"), HPC = S("H_PCURVE"), FRES = S("f_reset"), TT100 = S("TT100"), TT170 = S("TT170");
let orbitPhase = 0;
let iter = -1, started = false, pl = null, curves = [], nframes = 0;
const jf = openSync(`${OUT}/frames.jsonl`, "w"), sf = openSync(`${OUT}/screens.bin`, "w");

function handler(pc) {
    if (pc === TT170 && !started) {
        started = true;
        if (seed) for (const [ad, v] of seed) R[ad] = v;
        return false;
    }
    if (pc === TT100 && started) { iter++; if (iter >= FRAMES) return true; return false; }
       // --orbit SPEED: (stress test, not the real game) move the planet's
    // circle along a Lissajous path at G_PLANET, SPEED radians per frame, and
    // --orbitr R sets its radius
    if (a.orbit && pc === S("G_PLANET") && (R[S("TYPE")] & 1) === 0) {
        orbitPhase += +a.orbit;
        const x = Math.round(128 + 110 * Math.sin(orbitPhase)), y = Math.round(96 + 80 * Math.cos(orbitPhase * 1.37));
        R[S("K3")] = x & 255; R[S("K3") + 1] = (x >> 8) & 255;
        R[S("K4")] = y & 255; R[S("K4") + 1] = (y >> 8) & 255;
        if (a.orbitr) { R[S("K")] = +a.orbitr + Math.round(6 * Math.sin(orbitPhase * 0.7)); R[S("K") + 1] = 0; }
    }
    if (pc === PL9 && curBank() === 4) {
        pl = { inwk: zp(S("INWK"), 36), k: zp(S("K"), 4), k3: zp(S("K3"), 2), k4: zp(S("K4"), 2), type: zp(S("TYPE"))[0] };
        curves = [];
        return false;
    }
    if (pc === HPC) {
        curves.push({ cnt2: zp(S("CNT2"))[0], tgt: zp(S("TGT"))[0], stp: zp(S("STP"))[0], k2: zp(S("K2"), 4), xx16: zp(S("XX16"), 6), k3: zp(S("K3"), 2), k4: zp(S("K4"), 2) });
        return false;
    }
    if (pc === FRES && curBank() === 6 && R[S("QQ11")] === 0) {
        const plon = B6("F_PLON")[0];
        const lay = B6("f_lay")[0];
        if (plon && lay === 2) {
            const buf = HZ("GPEND")[0];
            const np = B6("F_NPT")[0], nc = B6("F_NCV")[0];
            const fr = {
                iter, buf, pl, curves,
                plx: B6("F_PLX", 2), ply: B6("F_PLY", 2), plr: B6("F_PLR")[0], plt: B6("F_PLT")[0],
                ncv: nc, cvs: B6("F_CVS", nc), cve: B6("F_CVE", nc), cvt: B6("F_CVT", nc),
                pxl: B6("F_PXL", np), pxh: B6("F_PXH", np), pyl: B6("F_PYL", np), pyh: B6("F_PYH", np),
                ndt: HZ("R_NDT")[0], ndb: HZ("R_NDB")[0], ndl: HZ("R_NDISCL", 192), ndr: HZ("R_NDISCR", 192),
                ndf: HZ("R_NDF")[0], dbe: HZ("R_DBE")[0], dbo: HZ("R_DBO")[0],
                ndn: HZ("R_NDN", 192), ndp: HZ("R_NDP", 192),
                ndx: [HZ("R_NDX0", 192), HZ("R_NDX1", 192), HZ("R_NDX2", 192), HZ("R_NDX3", 192)],
                dirl: HZ(buf ? "R_DIRTYL1" : "R_DIRTYL0", 192), dirr: HZ(buf ? "R_DIRTYR1" : "R_DIRTYR0", 192),
                discl: HZ(buf ? "R_DISCL1" : "R_DISCL0", 192), discr: HZ(buf ? "R_DISCR1" : "R_DISCR0", 192),
            };
            writeSync(jf, JSON.stringify(fr) + "\n");
            const base = buf ? 0x8000 : 0;
            writeSync(sf, R.subarray(base + 0x4000, base + 0x7000));
            nframes++;
        }
        pl = null; curves = [];
    }
    return false;
}
cpu.debugInstruction.add(handler);
let done = false;
const t0 = Date.now();
while (!done) {
    for (let k = 0; k < 40 && !done; k++) { if (handler(cpu.pc)) done = true; cpu.execute(50000); if (iter >= FRAMES) done = true; }
    if (cpu.cycleSeconds > 1200) break;
}
closeSync(jf); closeSync(sf);
console.log(`captured ${nframes} planet frames over ${iter} iterations, wall ${((Date.now() - t0) / 1000).toFixed(0)} s`);
process.exit(0);
