#!/usr/bin/env node
// The moon movie: Commander Claude (elite-agent with the moon mode, MOON=1) plays the original
// and the port in lockstep from the "diso" commander (docked at Diso, a full tank, with the
// moon system Quator (14, 137) selected), or, with --start X,Y and --to X,Y, docked at X,Y
// with the system --to selected (the published film: --start 156,57 --to 155,60). It flies
// there itself (or, if it is still flying clear of the station 30 iterations after the
// launch, the script takes the controls for a moment, makes the jump and hands back). On the
// arrival the tank is emptied (a poke), so that the agent docks there rather than flying on
// to a destination of its own. From the arrival to the docking, the port's screen is
// recorded (every second frame the video chip paints: 25 fps), with, per iteration, the
// moon's centre from us (as the port's MOONHIT places it), whether the port drew the sun near
// the planet (S_SUN) and the moon. Everything the script does is in the session's input log
// (replay.mjs replays it).
//
// node master/tools/agentplay/moonmovie.mjs --out DIR --cand DISC --csyms SYMS
//      [--seed N] [--minutes 30] [--name moon] [--start X,Y] [--to X,Y]
//      [--target 80] (the film's seconds) [--need 8] (the seconds of moon and of sun it must
//      show) [--probe] (where the moon and the planet are just after the arrival)
//   (AGENTD: an agentd built from elite-agent's moon-avoid branch: build.sh ELITE_AGENT=...)
// Writes DIR/NAME.mp4 (H.264, 25 fps, x2 nearest-neighbour), NAME.gif (if small), NAME.json
// (the iterations, the system, the moon's nearest approach, the frames with the sun and the
// moon on screen), and DIR/stills/.
import { Session } from "./session.mjs";
import { MODES, COMMANDERS, patcher, cash, ALL } from "./styles.mjs";
import { parseArgs } from "../../../harness/args.mjs";
import { writeFileSync, mkdirSync, openSync, writeSync, readSync, closeSync, rmSync, statSync } from "fs";
import { execFileSync } from "child_process";
import sharp from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/sharp/lib/index.js";

const a = parseArgs({ out: "value", cand: "value", csyms: "value", ref: "value", rsyms: "value", seed: "value", minutes: "value", name: "value",
    start: "value", to: "value", target: "value", need: "value", probe: "flag" });
if (!a.out || !a.cand || !a.csyms) { console.error("--out, --cand and --csyms are required"); process.exit(2); }
const FFMPEG = "/opt/homebrew/bin/ffmpeg";
const OUT = a.out, NAME = a.name || "moon";
mkdirSync(OUT, { recursive: true });
const [TX, TY] = String(a.to || "14,137").split(",").map(Number);     // the target system
const TARGET = +(a.target || 80), NEED = +(a.need || 8);   // the film's seconds; the seconds of moon and of sun it must show
if (a.start) {                                  // the start: docked there, all fitted, the target selected
    const [SX, SY] = String(a.start).split(",").map(Number);
    COMMANDERS.moonstart = { what: `at (${SX}, ${SY}), (${TX}, ${TY}) selected`, patch: patcher({ ...ALL, QQ0: [SX], QQ1: [SY], QQ9: [TX], QQ10: [TY], LASER: [0x8f, 0, 0, 0], CASH: cash(20000), TALLY: [800 & 255, 800 >> 8] }) };
}
const K = { H: 0x54, F0: 0x20, F1: 0x71, F2: 0x72, F3: 0x73 };
const VIEWKEY = [K.F0, K.F1, K.F2, K.F3];      // front, rear, left, right
const cfg = { out: OUT, seed: a.seed !== undefined ? +a.seed : 1, commander: a.start ? "moonstart" : "diso", agentEnv: { ...MODES.efficient, ...MODES.moon }, mode: "efficient,moon",
    startFrame: 700, minutes: +(a.minutes || 30), observe: false, cand: a.cand, csyms: a.csyms };
if (a.ref) { cfg.ref = a.ref; cfg.rsyms = a.rsyms; }
const S = new Session(cfg);
await S.start();
const { ref, cand } = S;
const word = (m, s, o = 0) => m.rb(m.sy[s] + o);

const P = { phase: "wait", calm: 0, takeover: -1, hFrom: -1, arrive: -1, docked: -1, log: [] };
const orig = { keys: S.keysFor.bind(S), dks: S.dksFor.bind(S), joy: S.joyFor.bind(S) };
const scripted = () => (P.hFrom >= 0 && ref.iter >= P.hFrom && ref.iter < P.hFrom + 4 ? [K.H] : []);
const mine = () => P.phase === "jump";
// the camera: on the approach the script picks the view (front, rear, left or right) that has the moon and the
// sun in it, and presses its key (the agent's keys pass on with it; views don't change how it flies)
const cam = { view: 0, want: 0, since: 0, press: -1, sunShot: 0 };
const SUNSHOT = 300;
const camKeys = ctx => (cam.press >= 0 && ref.iter < cam.press + 3 ? [VIEWKEY[cam.want]] : []);
// the director: two shots taken over from the agent for a moment, the stick turning the ship until the subject
// (the moon as we come near it, the sun once S_SUN draws it) is in the front view, then holding it there for HOLD
// iterations, the speed down; then the agent flies on (its inputs and ours are all in the input log)
const HOLD = 220, ACQ = 500;
const dir = { shot: null, start: -1, held: 0, done: { moon: false, sun: false }, jx: 0x80, jy: 0x80, sr: 1, sp: 1, last: null };
const shooting = () => dir.shot !== null;
S.keysFor = ctx => mine() ? scripted() : shooting() ? camKeys(ctx).concat(dir.slow ? [0x68] : []) : [...orig.keys(ctx), ...camKeys(ctx)];
S.dksFor = ctx => mine() ? scripted().includes(ctx.key) : shooting() ? (camKeys(ctx).includes(ctx.key) || (dir.slow && ctx.key === 0x68)) : (orig.dks(ctx) || camKeys(ctx).includes(ctx.key));
S.joyFor = ctx => mine() ? 0x80 : shooting() ? (ctx.which ? dir.jy : dir.jx) : orig.joy(ctx);
function direct(m, target, name) {
    if (!dir.shot) {
        if (dir.done[name] || !target) return false;
        dir.shot = name; dir.start = m.iter; dir.held = 0; dir.last = null; dir.sr = dir.sr || 1;
        console.log(`director ${m.iter}: the ${name} shot`);
        cam.want = 0; cam.view = 0; cam.press = m.iter + 1; cam.since = m.iter;
    }
    if (dir.shot !== name) return true;
    const [x, y, z] = target, n = Math.hypot(x, y, z), ex = x / n, ey = y / n, ez = z / n;
    const onScreen = ez > 0 && Math.abs(x / z) < 0.3 && Math.abs(y / z) < 0.22;
    dir.slow = word(m, "DELTA") > 3;
    if (onScreen) { dir.held++; dir.jx = dir.jy = 0x80; }
    else {
        // roll until the subject is straight up or down, then pitch towards it; a sign is turned round if
        // its error grows over 8 iterations
        const rollErr = Math.abs(ex) / (Math.hypot(ex, ey) || 1), pitchErr = Math.acos(Math.max(-1, Math.min(1, ez)));
        if (dir.last && m.iter - dir.last.it >= 8) {
            if (dir.last.mode === "roll" && rollErr > dir.last.err + 0.02) dir.sr = -dir.sr;
            if (dir.last.mode === "pitch" && pitchErr > dir.last.err + 0.01) dir.sp = -dir.sp;
            dir.last = null;
        }
        if (rollErr > 0.25 && Math.abs(ex) > 0.05) {
            dir.jx = 0x80 + dir.sr * Math.sign(ex) * Math.sign(ey || 1) * 0x50; dir.jy = 0x80;
            if (!dir.last) dir.last = { it: m.iter, mode: "roll", err: rollErr };
        } else {
            dir.jx = 0x80; dir.jy = 0x80 + dir.sp * Math.sign(ey || 1) * 0x50;
            if (!dir.last) dir.last = { it: m.iter, mode: "pitch", err: pitchErr };
        }
    }
    if (dir.held >= HOLD || m.iter - dir.start > ACQ + HOLD) {
        console.log(`director ${m.iter}: the ${name} shot over (held ${dir.held})`);
        dir.done[name] = true; dir.shot = null; dir.jx = dir.jy = 0x80; dir.slow = false;
    }
    return true;
}
function setPokes(at, pk) { for (const m of [ref, cand]) (m.pokes ||= new Map()).set(at, pk); S.logInput({ poke: at, v: pk }); }

// the moon's centre from us (the coordinates' high bytes), as MOONHIT places it: the planet (the reference's slot
// 0, which the port's is) + the port's MN_E (gfx-ssun.asm's MN_TURN: the moon's place, fixed in space)
function moon(m) {
    const h = word(m, "QQ2", 1) ^ word(m, "QQ2", 3) ^ word(m, "QQ2", 5);
    if ((h & 3) !== 1 || !(word(m, "FRIN") & 0x80) || !(cand.rb(cand.sy.MN_OK) & 0x80)) return null;
    const k = m.sy["K%"], rd = o => m.rb(k + o);
    const P0 = [0, 3, 6].map(o => (rd(o + 1) | (rd(o + 2) & 0x7f) << 8) * (rd(o + 2) & 0x80 ? -1 : 1));
    const E = [0, 3, 6].map(o => { const a = cand.sy.MN_E + o; let v = cand.rb(a) | cand.rb(a + 1) << 8 | cand.rb(a + 2) << 16; if (v & 0x800000) v -= 1 << 24; return v / 256; });
    const M = P0.map((c, i) => c + E[i]);
    return { M, r: [48, 56, 64, 72][(h >> 5) & 3] * 96 / 256, d: Math.hypot(...M) };
}

// a point's direction in each view's frame: front (x, y, z), rear (-x, y, -z), left (z, y, -x), right (-z, y, x)
const inView = (v, p) => { const [x, y, z] = v === 0 ? p : v === 1 ? [-p[0], p[1], -p[2]] : v === 2 ? [p[2], p[1], -p[0]] : [-p[2], p[1], p[0]];
    return z > 0 && Math.abs(x / z) < 0.45 && Math.abs(y / z) < 0.33; };
function sunPos() {                             // S_SUN's sun: the planet + its D (ss_d, the shared workspace), the station in slot 1
    const sy = cand.sy;
    if (!(cand.rb(sy.SS_OK) & 0x80) || word(cand, "FRIN", 1) !== 2 || sy.ss_d === undefined) return null;
    const b4 = x => cand.rb(x);
    const k = sy["K%"], rd = o => cand.rb(k + o);
    const P = [0, 3, 6].map(o => (rd(o) | rd(o + 1) << 8 | (rd(o + 2) & 0x7f) << 16) * (rd(o + 2) & 0x80 ? -1 : 1));
    return P.map((c0, j) => { let d = b4(sy.ss_d + 3 * j) | b4(sy.ss_d + 3 * j + 1) << 8 | b4(sy.ss_d + 3 * j + 2) << 16; if (d & 0x800000) d -= 1 << 24; return c0 + d; });
}
function camera(m, mo) {
    const objs = [];
    if (mo) objs.push(mo.M.map(c => c * 256));
    const sp = sunPos(); if (sp) objs.push(sp);
    const score = v => objs.filter(o => inView(v, o)).length + (v === 0 ? 0.5 : 0);   // (the front, on a tie)
    let best = 0;
    for (const v of [1, 2, 3]) if (score(v) > score(best)) best = v;
    // the sun near the planet is behind us on the way in (SOLAR puts every sun behind the arrival): once S_SUN
    // draws it, a stretch (SUNSHOT iterations) in the view that has it, then the front again
    if (sp && cam.sunShot < SUNSHOT) for (const v of [1, 2, 3, 0]) if (inView(v, sp)) { best = v; cam.sunShot++; break; }
    const docking = word(m, "SSPR") !== 0;      // (the station's safe zone: the front, to see the docking)
    if (docking) best = 0;
    if (m.iter % 200 === 0) console.log(`camera ${m.iter}: moon ${mo ? mo.M.map(c => c.toFixed(0)) : "-"} sun ${sp ? sp.map(c => (c / 256).toFixed(0)) : "-"} scores ${[0, 1, 2, 3].map(score)}`);
    if (best !== cam.view && (m.iter - cam.since > 60 || docking)) { cam.want = best; cam.view = best; cam.since = m.iter; cam.press = m.iter + 1; console.log(`camera ${m.iter}: view ${best}`); }
}

let rawfd = -1, nframes = 0, odd = 0, W = 0, H = 0;
const seen = { iters: 0 };
let nearest = 1e9, nearestAt = -1;
ref.onIter = m => {
    const it = m.iter;
    if (P.phase === "wait" && word(m, "QQ0") === TX && word(m, "QQ1") === TY && word(m, "QQ12") === 0 && word(m, "QQ11") === 0 && word(m, "FRIN") & 0x80) {
        P.phase = "approach"; P.arrive = it;          // (the agent went there itself: the system it had selected)
        console.log(`iteration ${it}: arrived at (${TX}, ${TY}) by the agent's own jump: filming`);
        setPokes(it + 1, [["QQ14", 0, [0]]]);
        startCapture();
    } else if (P.phase === "wait") {
        const flying = word(m, "QQ12") === 0 && word(m, "QQ11") === 0 && word(m, "FRIN", 1) === 2 && word(m, "QQ22", 1) === 0 && word(m, "auto") === 0;
        P.calm = flying ? P.calm + 1 : 0;
        if (P.calm >= 20) {             // clear of the station: the jump to the target
            P.phase = "jump"; P.hFrom = it + 2;
            setPokes(it + 1, [["QQ9", 0, [TX]], ["QQ10", 0, [TY]]]);
            console.log(`iteration ${it}: taking the controls for the jump to (${TX}, ${TY})`);
        }
    } else if (P.phase === "jump") {
        if (word(m, "QQ0") === TX && word(m, "QQ1") === TY && word(m, "QQ11") === 0 && word(m, "FRIN") & 0x80) {
            P.phase = "approach"; P.arrive = it;
            console.log(`iteration ${it}: arrived at (${TX}, ${TY}): handing back, filming`);
            setPokes(it + 1, [["QQ14", 0, [0]]]);     // (the tank emptied: the agent docks here, not on to its own plan)
            startCapture();
        } else if (it > P.hFrom + 2000) { P.phase = "failed"; console.log("no jump"); }
    } else if (P.phase === "approach") {
        const mo = moon(m);
        if (mo && mo.d < nearest) { nearest = mo.d; nearestAt = it; }
        const sp = sunPos();
        if (!shooting() || dir.shot === "moon") direct(m, mo && mo.d < 700 ? mo.M : null, "moon");
        if (!shooting() || dir.shot === "sun") direct(m, sp ? sp.map(c => c / 256) : null, "sun");
        if (!shooting()) camera(m, mo);
        if (a.probe && it === P.arrive + 5) {          // (--probe: where the moon and the planet are, just after the arrival)
            const k = m.sy["K%"], rd = o => m.rb(k + o);
            const Pp = [0, 3, 6].map(o => (rd(o + 1) | (rd(o + 2) & 0x7f) << 8) * (rd(o + 2) & 0x80 ? -1 : 1));
            console.log(`PROBE (${TX}, ${TY}): planet ${Pp} moon ${mo ? mo.M.map(c => c.toFixed(0)) + " r " + mo.r : "-"}`);
            P.phase = "failed";
        }
        // the port's last frames: the moon drawn in either buffer (MO_ON, which lasts, as MN_ON does not past
        // the frame), and the sun near the planet known to S_SUN (SS_OK) with the station in slot 1
        const mn = ((cand.rb(cand.sy.MO_ON) | cand.rb(cand.sy.MO_ON + 1)) & 0x80) !== 0;
        const sun = (cand.rb(cand.sy.SS_OK) & 0x80) !== 0 && word(cand, "FRIN", 1) === 2;
        seen.iters++;
        if (it % 200 === 0) console.log(`iteration ${it}: moon ${mo ? mo.d.toFixed(0) + " (r " + mo.r + ")" : "-"}, sun ${sun}, moon drawn ${mn}, docked ${word(m, "QQ12")}`);
        if (word(m, "QQ12") !== 0) { P.docked = it; P.phase = "tail"; P.endIter = it + 30; console.log(`iteration ${it}: docked`); }
    }
};
// what the port's frame drew, sampled at f_reset (F_FRAME's end, before it empties the lists): the moon (MN_ON,
// its centre and radius) and the sun (GSUNON, F_SUX, F_SUY, GSUNR) each with some of its disc on the screen
const vis = { moon: false, sun: false };
{
    const c = cand.cpu, sy = cand.sy, rb = x => c.ramRomOs[x];
    const s16 = x => { const v = rb(x) | rb(x + 1) << 8; return v > 32767 ? v - 65536 : v; };
    const on = (x, y, r) => r >= 2 && x + r >= 2 && x - r <= 253 && y + r >= 1 && y - r <= 191;
    c.debugInstruction.add(pc => {
        if (pc === sy.f_reset && (c.romsel & 15) === 6) {
            vis.moon = (rb(sy.MN_ON) & 0x80) !== 0 && on(s16(sy.MN_X), s16(sy.MN_Y), rb(sy.MN_R));
            vis.sun = rb(sy.GSUNON) !== 0 && on(s16(sy.F_SUX), s16(sy.F_SUY), rb(sy.GSUNR));
        }
        return false;
    });
}
const flags = [];                               // per filmed frame: 1 the moon on the screen, 2 the sun
function startCapture() {
    cand.renderAll();
    rawfd = openSync(`${OUT}/${NAME}.rgb`, "w");
    const v = cand.s._video, orig = v.paint_ext;
    v.paint_ext = (...args) => {
        orig.apply(v, args);
        if (rawfd < 0 || (odd++ & 1)) return;
        const l = v.leftBorder, t = v.topBorder, w = 1024 - l - v.rightBorder, h = 625 - t - v.bottomBorder;
        W = (w >> 1) & ~1; H = (h >> 1) & ~1;
        const buf = Buffer.alloc(W * H * 3), src = cand.s._completeFb8;
        for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
            const s = ((t + 2 * y) * 1024 + l + 2 * x) * 4, d = (y * W + x) * 3;
            buf[d] = src[s]; buf[d + 1] = src[s + 1]; buf[d + 2] = src[s + 2];
        }
        writeSync(rawfd, buf); nframes++;
        flags.push((vis.moon ? 1 : 0) | (vis.sun ? 2 : 0));
    };
}

while (S.frame < cfg.startFrame + cfg.minutes * 3000) {
    await S.step();
    if (P.phase === "failed") break;
    if (P.phase === "tail" && ref.iter > P.endIter) break;
    if (S.stopNow) { console.log("the session stopped:", JSON.stringify(S.findings.slice(-1))); break; }
}
if (rawfd >= 0) closeSync(rawfd);
rawfd = -1;
S.logInput({ end: true, iter: ref.iter, polls: ref.polls, frames: S.frame });
const meta = { system: [TX, TY], start: a.start || "19,151", arrive: P.arrive, docked: P.docked, phase: P.phase, frames: nframes, seconds: +(nframes / 25).toFixed(1), size: [W, H],
    moonNearest: nearest < 1e9 ? +nearest.toFixed(0) : null, moonNearestIter: nearestAt, findings: S.findings.length, seed: cfg.seed, cand: a.cand };
// the film: every frame within a second of one with the moon or the sun on the screen, at its own pace; of the
// rest (the cruise, the docking), one in K, K the least that brings the film to TARGET seconds or under
const keep = [];
if (nframes) {
    const near = flags.map((_, i) => flags.slice(Math.max(0, i - 25), i + 26).some(f => f));
    const live = near.filter(x => x).length;
    let K = 1;
    while (K < 64 && live + Math.ceil((nframes - live) / K) > TARGET * 25) K++;
    let dull = 0;
    for (let i = 0; i < nframes; i++) if (near[i] || dull++ % K === 0) keep.push(i);
    meta.speedup = K;
}
meta.seen = { moonSeconds: +(flags.filter(f => f & 1).length / 25).toFixed(1), sunSeconds: +(flags.filter(f => f & 2).length / 25).toFixed(1),
    bothSeconds: +(flags.filter(f => f === 3).length / 25).toFixed(1), iters: seen.iters };
meta.film = { frames: keep.length, seconds: +(keep.length / 25).toFixed(1) };
console.log(JSON.stringify(meta));
if (keep.length) {
    const fd = openSync(`${OUT}/${NAME}.rgb`, "r"), out = openSync(`${OUT}/${NAME}-cut.rgb`, "w"), fsz = W * H * 3, buf = Buffer.alloc(fsz);
    for (const i of keep) { readSync(fd, buf, 0, fsz, i * fsz); writeSync(out, buf); }
    closeSync(fd); closeSync(out);
    execFileSync(FFMPEG, ["-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", `${W}x${H}`, "-framerate", "25", "-i", `${OUT}/${NAME}-cut.rgb`,
        "-vf", "scale=iw*2:ih*2:flags=neighbor", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "16", "-preset", "slow", `${OUT}/${NAME}.mp4`]);
    mkdirSync(`${OUT}/stills`, { recursive: true });
    execFileSync(FFMPEG, ["-y", "-loglevel", "error", "-i", `${OUT}/${NAME}.mp4`, "-vf", "fps=1/4", `${OUT}/stills/${NAME}-%03d.png`]);
    execFileSync(FFMPEG, ["-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", `${W}x${H}`, "-framerate", "25", "-i", `${OUT}/${NAME}-cut.rgb`,
        "-vf", "fps=10,split[s0][s1];[s0]palettegen=max_colors=32[p];[s1][p]paletteuse=dither=none", `${OUT}/${NAME}.gif`]);
    rmSync(`${OUT}/${NAME}.rgb`); rmSync(`${OUT}/${NAME}-cut.rgb`);
    if (statSync(`${OUT}/${NAME}.gif`).size > 15e6) rmSync(`${OUT}/${NAME}.gif`);
}
writeFileSync(`${OUT}/${NAME}.json`, JSON.stringify(meta, null, 1));
S.agent?.close();
// the film's own check: docked, and the moon and the sun each on the screen for NEED seconds or more
const ok = P.phase === "tail" && meta.seen.moonSeconds >= NEED && meta.seen.sunSeconds >= NEED;
console.log(`MOONMOVIE ${ok ? "PASS" : "FAIL"}: moon ${meta.seen.moonSeconds} s, sun ${meta.seen.sunSeconds} s, both ${meta.seen.bothSeconds} s; film ${meta.film.seconds} s (cruise x${meta.speedup || 1})`);
process.exit(ok ? 0 : 1);
