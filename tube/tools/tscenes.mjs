#!/usr/bin/env node
// tscenes.mjs: the disc bench's posed scenes (master/tools/discmem/bench.sh:
// harness/mplanet.mjs's planets, harness/msunnear.mjs's sun near the planet)
// on the Master port or the Tube build, for the incremental discs' check:
// the gate's pilot flies to iteration FROM, then each iteration the scene is
// put in (the planet, its type, seed and orientation; the station and the
// sun, as S_SUN's D, for the sun near the planet), and at each frame's end
// both screen buffers are hashed (the Master port at hframe + 7, the Tube's
// host at C_SYNC: tfbreplay.mjs's points, which the gate's pixel oracle
// compares). Writes OUT/<scene>.json (per iteration, the frames' hashes); on
// the Tube, also the disc heap's counts (hp_drops, hp_whole) at the end.
// Compare two runs with --cmp A.json B.json.
//
// node tube/tools/tscenes.mjs --scene NAME --out DIR --cand disc --csyms syms [--tube Master|B]
// node tube/tools/tscenes.mjs --cmp A.json B.json
// node tube/tools/tscenes.mjs --list
import { runElite, loadSyms } from "../../harness/mlib.mjs";
import { makePilot, patchCommander } from "../../harness/mpilot.mjs";
import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { createHash } from "crypto";

const a = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => { if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]); return acc; }, []));
const LEESTI = "38,BA,7C,0D,5D,41";
// the scenes: bench.sh's, by name (planet: mplanet.mjs's options; sun: msunnear.mjs's)
const SCENES = {
    beach90: { type: 128, x: 128, y: 96, r: 90, pose: "20,30,0", spin: 22.5, n: 16 },
    beach200: { type: 128, x: 128, y: 96, r: 200, pose: "20,30,0", spin: 5, n: 16 },
    beachpath: { type: 128, x0: 60, y0: 60, x1: 180, y1: 130, r0: 40, r1: 160, pose: "20,30,0", spin: 3, n: 24 },
    caps90: { type: 130, qq2: LEESTI, x: 128, y: 96, r: 90, pose: "20,30,0", spin: 22.5, n: 16 },
    caps200: { type: 130, qq2: LEESTI, x: 128, y: 96, r: 200, pose: "0,60,20", spin: 5, n: 16 },
    capspath: { type: 130, qq2: LEESTI, x0: 200, y0: 40, x1: 100, y1: 120, r0: 30, r1: 120, pose: "0,60,20", spin: 5, n: 24 },
    beachtop: { type: 128, x0: 128, y0: -60, x1: 140, y1: 20, r0: 120, r1: 125, pose: "20,30,0", spin: 5, n: 16 },
    beachleft: { type: 128, x0: 8, y0: 100, x1: 40, y1: 90, r0: 100, r1: 110, pose: "20,30,0", spin: 5, n: 16 },
    sunnear: { sun: true },
    sunedge: { sun: true, sx: 236, sx1: 290 },
    sungrow: { sun: true, sz: 393216, sz1: 131072 },
    sunswap: { sun: true, pz: 262144, psx: 120, psy: 120, sz: 393216, sz1: 131072 },
    sunsmall: { sun: true, pz: 125829, psx: 110, psy: 110, sx: 180, sy0: 150, sy1: 40 },
};
if (a.list) { console.log(Object.keys(SCENES).join(" ")); process.exit(0); }

if (a.cmp) {                            // two runs' frames, per iteration
    const [fa, fb] = [a.cmp, process.argv[process.argv.indexOf(a.cmp) + 1]];
    const A = JSON.parse(readFileSync(fa, "utf8")), B = JSON.parse(readFileSync(fb, "utf8"));
    // (from FROM + 2: the buffers hold what the flight to FROM drew until the
    // scene has drawn into each of them)
    const its = Object.keys(A.frames).filter(k => k in B.frames).map(Number).filter(i => i >= A.FROM + 2).sort((x, y) => x - y);
    const bad = its.filter(i => A.frames[i].at(-1) !== B.frames[i].at(-1));
    // a differing frame whose every differing byte is black on one side and a
    // star's pixels on the other (one or two pixels of colour 3, R_SCOL) is a
    // star's difference only (the stars are not the discs' business)
    const STAR = new Set([0x88, 0x44, 0x22, 0x11, 0xcc, 0x66, 0x33]);
    const ra = readFileSync(fa.replace(/\.json$/, ".raw")), rb = readFileSync(fb.replace(/\.json$/, ".raw"));
    const fr = (r, o, i) => r.subarray(o.rawits.indexOf(i) * 0x6000, o.rawits.indexOf(i) * 0x6000 + 0x6000);
    let starOnly = 0; const real = [];
    for (const i of bad) {
        const x = fr(ra, A, i), y = fr(rb, B, i); let ok = true;
        for (let k = 0; k < 0x6000 && ok; k++) if (x[k] !== y[k] && !((x[k] === 0 && STAR.has(y[k])) || (y[k] === 0 && STAR.has(x[k])))) ok = false;
        if (ok) starOnly++; else real.push(i);
    }
    console.log(`${A.scene}: ${its.length} iterations in both, ${bad.length} differ (${starOnly} by stars only)${real.length ? ", the discs' in: " + real.slice(0, 12).join(" ") : ""}` +
        (B.heap ? `; heap ${JSON.stringify(B.heap)}` : A.heap ? `; heap ${JSON.stringify(A.heap)}` : ""));
    process.exit(real.length ? 1 : 0);
}

const SC = SCENES[a.scene]; if (!SC) { console.error("no scene", a.scene); process.exit(2); }
mkdirSync(a.out, { recursive: true });
const sy = loadSyms(a.csyms);
const TUBE = a.tube;
const hsy = TUBE ? loadSyms(a.csyms.replace(/psyms\.txt$/, TUBE === "B" ? "hbmsyms.txt" : "hsyms.txt")) : null;
const FROM = +(SC.from || 300);
// lv_ok (gfx-light.asm's, not in the symbols): from the assembler's listing beside them
const LVOK = (() => { const L = readFileSync(a.csyms.replace(/(p?syms|symbols)\.txt$/, TUBE ? "compile-p.txt" : "compile.txt"), "latin1");
    const m = L.match(/\n\.lv_ok\s*\n\s+([0-9A-F]{4})\s/); if (!m) throw new Error("no lv_ok in the listing"); return parseInt(m[1], 16); })();
const N = SC.sun ? 12 + 64 + 12 + 56 + 12 : SC.n;
const lerp = (p, q, t) => +p + (q - p) * t;
function rot(v, ax, ang) {
    const c = Math.cos(ang), s = Math.sin(ang), [x, y, z] = v;
    if (ax === 0) return [x, y * c - z * s, y * s + z * c];
    if (ax === 1) return [x * c + z * s, y, -x * s + z * c];
    return [x * c - y * s, x * s + y * c, z];
}
function rotAxis(v, u, ang) {
    const c = Math.cos(ang), s = Math.sin(ang), d = v[0] * u[0] + v[1] * u[1] + v[2] * u[2];
    const cr = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]];
    return [0, 1, 2].map(i => v[i] * c + cr[i] * s + u[i] * d * (1 - c));
}
function orient(k, poseStr, spin) {
    const [ax, ay, az] = String(poseStr).split(",").map(x => (+x) * Math.PI / 180);
    let vs = [[0, 0, -1], [0, 1, 0], [1, 0, 0]];
    vs = vs.map(v => rot(rot(rot(v, 0, ax), 1, ay), 2, az));
    const sp = (+(spin || 0)) * Math.PI / 180 * k;
    if (sp) { let u = [0, 1, 2].map(i => vs[0][i] - vs[2][i]); const n = Math.hypot(...u); u = u.map(x => x / n); vs = vs.map(v => rotAxis(v, u, sp)); }
    return vs;
}
const ease = t => t * t * (3 - 2 * t);
function pose(ram, k) {
    const K0 = sy["K%"], K1 = K0 + 37;
    {                                   // the random seeds and the stars put in, every iteration (as
        if (k === 0) ram[sy.MCNT] = 0;  // msunnear.mjs's --pose does at the start), so that the frames
        for (let j = 0; j < 4; j++) ram[sy.RAND + j] = 0x5a ^ (j * 0x31);   // of two builds compare byte
        let r = 12345;                  // for byte, whatever the flight to FROM left (the stars stand still)
        const nx = () => { r = (r * 1103515245 + 12345) & 0x7fffffff; return (r >> 8) & 255; };
        for (let i = 1; i <= ram[sy.NOSTM]; i++) {
            ram[sy.SX + i] = nx(); ram[sy.SXL + i] = nx(); ram[sy.SY + i] = nx(); ram[sy.SYL + i] = nx();
            ram[sy.SZ + i] = 0x90 | (nx() & 0x6f); ram[sy.SZL + i] = nx();
        }
        ram[sy.DELTA] = 0;
    }
    const put = (base, o, v) => { const m = Math.abs(v); ram[base + o] = m & 255; ram[base + o + 1] = (m >> 8) & 255; ram[base + o + 2] = ((m >> 16) & 127) | (v < 0 ? 128 : 0); };
    const wv = (base, vs) => { const w = (o, v) => { const m = Math.min(32767, Math.round(Math.abs(v) * 24576)); ram[base + o] = m & 255; ram[base + o + 1] = (m >> 8) | (v < 0 ? 128 : 0); }; [9, 15, 21].forEach((o, j) => { w(o, vs[j][0]); w(o + 2, vs[j][1]); w(o + 4, vs[j][2]); }); };
    if (!SC.sun) {                      // mplanet.mjs's planet
        const t = N > 1 ? k / (N - 1) : 0;
        const [tx, ty, rr] = SC.x0 !== undefined ? [lerp(SC.x0, SC.x1, t), lerp(SC.y0, SC.y1, t), lerp(SC.r0, SC.r1, t)] : [SC.x, SC.y, SC.r];
        const z = Math.round(24576 * 256 / rr);
        put(K0, 0, Math.round((tx - 128) * z / 256)); put(K0, 3, Math.round((96 - ty) * z / 256)); put(K0, 6, z);
        ram[sy.FRIN] = SC.type;
        if (SC.qq2) SC.qq2.split(",").forEach((h, j) => { ram[sy.QQ2 + j] = parseInt(h, 16); });
        wv(K0, orient(k, SC.pose, SC.spin));
        return;
    }
    // msunnear.mjs's sunrise: the planet's limb across the lower screen, the sun
    // rising from behind it, holding, the station crossing in front
    const HOLD = 12, RISE = 64, FLY = 56;
    const PZ = +(SC.pz || 52429), PSX = +(SC.psx || 150), PSY = +(SC.psy || 222);
    const P = [Math.round((PSX - 128) * PZ / 256), Math.round((96 - PSY) * PZ / 256), PZ];
    const SZ = +(SC.sz || 6 * 65536), SX = +(SC.sx || 132), SY0 = +(SC.sy0 || 134), SY1 = +(SC.sy1 || 58);
    const TZ = 1700, TY = 58, TX0 = -60, TX1 = 330;
    let sy_ = SY0, st = null;
    if (k >= HOLD) sy_ = SY0 + (SY1 - SY0) * ease(Math.min(1, (k - HOLD) / (RISE - 1)));
    const f0 = HOLD + RISE + HOLD;
    if (k >= f0 && k < f0 + FLY) st = TX0 + (TX1 - TX0) * (k - f0) / (FLY - 1);
    put(K0, 0, P[0]); put(K0, 3, P[1]); put(K0, 6, P[2]);
    const t = Math.min(1, k / (N - 1)), SZk = SC.sz1 ? Math.round(SZ + (+SC.sz1 - SZ) * t) : SZ;
    const sx = SC.sx1 ? SX + (+SC.sx1 - SX) * t : SX;
    const S = [Math.round((sx - 128) * SZk / 256), Math.round((96 - sy_) * SZk / 256), SZk];
    for (let j = 0; j < 3; j++) { const u = (S[j] - P[j]) & 0xffffff; ram[sy.ss_d + 3 * j] = u & 255; ram[sy.ss_d + 3 * j + 1] = (u >> 8) & 255; ram[sy.ss_d + 3 * j + 2] = (u >> 16) & 255; }
    ram[sy.SS_OK] = 0xff;
    const tx = st === null ? (k < f0 ? TX0 : TX1) : st;
    put(K1, 0, Math.round((tx - 128) * TZ / 256)); put(K1, 3, Math.round((96 - TY) * TZ / 256)); put(K1, 6, TZ);
    if (k === 0) { const vec = (o, x, y, z) => { [x, y, z].forEach((c, j) => { ram[K1 + o + 2 * j] = 0; ram[K1 + o + 2 * j + 1] = c; }); }; vec(9, 0, 0, 0xe0); vec(15, 0, 0x60, 0); vec(21, 0x60, 0, 0); ram[K1 + 27] = 0; }
    ram[sy.FRIN + 1] = ram[sy.SSPR] ? ram[sy.FRIN + 1] : ram[sy.FRIN + 1];
    ram[sy.DELTA] = 0; ram[sy.VIEW] = 0;
    wv(K0, orient(k, "20,30,0", 3));
    for (let j = 2; j < 12; j++) ram[sy.FRIN + j] = 0;
}

const pilot0 = makePilot();
const pilot = { ...pilot0, keys: c => (c.iterOf() >= FROM ? [] : pilot0.keys(c)), dks: c => (c.iterOf() >= FROM ? false : pilot0.dks ? pilot0.dks(c) : false), observe: pilot0.observe, P: pilot0.P };
const frames = {}, out_st = {}, raws = {};
let cur = -1, armed = false;
const hashBoth = (b0, b1) => createHash("sha1").update(b0).update(b1).digest("hex").slice(0, 16);
const res = await runElite({ disc: a.cand, syms: sy, pilot, iters: FROM + N + 2, patch: patchCommander, tube: TUBE, maxSecs: 4000,
    onIter: (i, s, r) => {
        const cpu = r.cpu;
        if (!armed) {
            armed = true;
            if (TUBE) {                 // the host at C_SYNC (tfbreplay.mjs's: h_sync, a NOP, or h_syncb after it)
                const host = r.tube.t.host; let seen = false; const q = [];
                r.tube.t.addParHook(pc => { if (pc === sy.p_sync) q.push(cur); return false; });   // (the iteration whose frame it is: the parasite runs ahead)
                host.debugInstruction.add(pc => {
                    if ((pc === hsy.h_sync || pc === hsy.h_syncb) && host.readmem(hsy.h_sync) !== 0xea) return false;
                    if (pc === hsy.h_sync) seen = true;
                    if (pc === hsy.h_syncb && !seen) pc = hsy.h_sync; else if (pc === hsy.h_syncb) { seen = false; return false; }
                    if (pc !== hsy.h_sync) return false;
                    const it = q.shift();
                    if (it >= FROM) {
                        const m = host.ramRomOs;
                        const [b0, b1] = TUBE === "B" ? [m.subarray(0x1000, 0x4000), m.subarray(0x4000, 0x7000)] : [m.subarray(0x4000, 0x7000), m.subarray(0xc000, 0xf000)];
                        (frames[it] ||= []).push(hashBoth(b0, b1)); raws[it] = Buffer.concat([b0, b1]);
                        if (+a.dump === it) writeFileSync(`${a.out}/${a.scene}-${it}.raw`, Buffer.concat([b0, b1]));
                    }
                    return false;
                });
            } else {                    // the Master port at hframe + 7
                cpu.debugInstruction.add(pc => {
                    if (pc === sy.hframe + 7 && cur >= FROM) {
                        const m = cpu.ramRomOs;
                        (frames[cur] ||= []).push(hashBoth(m.subarray(0x4000, 0x7000), m.subarray(0xc000, 0xf000))); raws[cur] = Buffer.concat([m.subarray(0x4000, 0x7000), m.subarray(0xc000, 0xf000)]);
                        if (+a.dump === cur) writeFileSync(`${a.out}/${a.scene}-${cur}.raw`, Buffer.concat([m.subarray(0x4000, 0x7000), m.subarray(0xc000, 0xf000)]));
                    }
                    return false;
                });
            }
        }
        cur = i;
        if (i >= FROM && i < FROM + N) pose(cpu.ramRomOs, i - FROM);
        if (i === FROM) {               // the light (L_SUN's LV) as at the start, not as the flight to
            if (TUBE) cpu.ramRomOs[LVOK] = 0;   // FROM left it (its roll differs a little by build, with
            else cpu.ramRomOs[cpu.romOffset + 4 * 16384 + LVOK - 0x8000] = 0;  // the timing of the keys; Master: bank 4)
        }
        if (a.stars && i >= FROM) { const m = cpu.ramRomOs; (out_st[i] = []).push(...Array.from({ length: m[sy.NOSTM] }, (_, j) => [m[sy.SX + j + 1], m[sy.SY + j + 1], m[sy.SZ + j + 1]].join(","))); }
    } });
const out = { scene: a.scene, build: TUBE ? `tube ${TUBE}` : "master", FROM, N, frames, stars: out_st };
if (TUBE && sy.hp_drops !== undefined) {
    const m = res.cpu.ramRomOs, w = x => m[x] + 256 * m[x + 1];
    out.heap = { drops: w(sy.hp_drops), whole: w(sy.hp_whole) };
}
writeFileSync(`${a.out}/${a.scene}.json`, JSON.stringify(out));
{ const its = Object.keys(raws).map(Number).sort((x, y) => x - y); out.rawits = its;   // (the last frame of each iteration, both buffers)
  writeFileSync(`${a.out}/${a.scene}.raw`, Buffer.concat(its.map(i => raws[i]))); writeFileSync(`${a.out}/${a.scene}.json`, JSON.stringify(out)); }
if (res.error) console.log("runElite error:", res.error);
console.log(`${a.scene} (${out.build}): ${Object.keys(frames).length} iterations hashed${out.heap ? `, heap ${JSON.stringify(out.heap)}` : ""}, ${res.iters} iterations run`);
process.exit(0);
