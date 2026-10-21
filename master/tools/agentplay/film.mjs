#!/usr/bin/env node
// A film of a session on the candidate alone: the port replays a session's input log read for
// read (as replay.mjs's candidate does, but with no reference beside it: the log gives every
// read's keys and every stick change), and every frame it displays is recorded, with its sound.
// It can follow a live session's log as it grows (--follow: it replays as far as the session's
// latest mark record, and waits for more), so the film is made while the session runs.
//
// The candidate's game state is hashed at every iteration and checked against the session's
// cand-hash.bin (agentplay.mjs --hashes): the film shows the very run that was compared with the
// original, iteration for iteration. (The candidate's boot leftovers are seeded from a
// reference booted only as far as TT170, as in a session.)
//
// node master/tools/agentplay/film.mjs --log RUN/inputs.jsonl --out DIR --cand DISC --csyms SYMS
//      [--ref DISC --rsyms SYMS] [--hashes RUN/cand-hash.bin] [--follow] [--crf N] [--fps 50|25]
//
// Writes, in DIR:
//   raw.mkv     every displayed frame, at the port's native pixel size (each mode 1 pixel one
//               pixel; each scan line one line), 50 fps (or 25), H.264 (Matroska, so a cut-short file
//               plays as far as it got). edit.mjs cuts the film from it.
//   frames.bin  a 48-byte record per frame in raw.mkv: f64 the frame's time (emulated cycles),
//               u32 iteration, then QQ12 (docked), QQ11 (view type), MJ (witchspace), VIEW, the
//               twelve FRIN slots' ship types, ENERGY, TP (missions), GCNT (galaxy), QQ22+1
//               (hyperspace count); then u16 the distance of the nearest ship (missiles, pods
//               and ships: not the station or junk) in the view shown, u16 the nearest anywhere
//               (65535: none), u8 how many ships, u8 how many in view, SSPR, ESCP, u8 the step
//               (50 Hz frames from this frame to the next recorded), u8 the class (--sparse;
//               255 not), u32 the 50 Hz frame number, 2 spare
//   sound.bin   every write to the sound chip: f64 emulated cycle, u8 value (9 bytes a write)
//   film.json   geometry, counts, the hash check
import { EliteMachine, loadSyms, CYCLES_PER_FRAME } from "./lib.mjs";
import { DEFAULTS, seedBytes, snapHash } from "./session.mjs";
import { COMMANDERS } from "./styles.mjs";
import { parseArgs } from "../../../harness/args.mjs";
import { readFileSync, writeFileSync, mkdirSync, openSync, readSync, fstatSync, closeSync, existsSync, appendFileSync } from "fs";
import { spawn } from "child_process";

const a = parseArgs({ log: "value", out: "value", cand: "value", csyms: "value", ref: "value", rsyms: "value", hashes: "value", follow: "flag", crf: "value", maxframes: "value", fps: "value", sparse: "value", journal: "value" });
if (!a.log || !a.out || !a.cand || !a.csyms) { console.error("--log, --out, --cand and --csyms are required"); process.exit(2); }
if (!a.ref !== !a.rsyms) { console.error("--ref and --rsyms go together"); process.exit(2); }
const FFMPEG = "/opt/homebrew/bin/ffmpeg";
const OUT = a.out;
mkdirSync(OUT, { recursive: true });

// ---- the log, read as it grows
const L = { off: 0, rest: "", rlog: new Map(), rjoy: [[], []], ptr: [0, 0], pokes: new Map(), header: null, safePolls: 0, safeJoys: 0, end: null };
function readLog() {
    const fd = openSync(a.log, "r"), size = fstatSync(fd).size;
    if (size > L.off) {
        const buf = Buffer.alloc(size - L.off);
        readSync(fd, buf, 0, buf.length, L.off);
        L.off = size;
        const text = L.rest + buf.toString("utf8"), lines = text.split("\n");
        L.rest = lines.pop();
        for (const l of lines) {
            if (!l) continue;
            const e = JSON.parse(l);
            if (e.header) L.header = e;
            else if (e.p !== undefined) L.rlog.set(e.p, e);
            else if (e.j !== undefined) L.rjoy[e.w].push([e.j, e.v]);
            else if (e.poke !== undefined) L.pokes.set(e.poke, e.v);
            else if (e.mark) { L.safePolls = Math.max(L.safePolls, e.polls); L.safeJoys = Math.max(L.safeJoys, e.joys); }
            else if (e.end) { L.end = e; L.safePolls = e.polls ?? Infinity; L.safeJoys = e.joys ?? Infinity; }
        }
    }
    closeSync(fd);
    // (not following: the log is all there is)
    if (!a.follow && !L.end) { L.safePolls = Infinity; L.safeJoys = Infinity; }
}
readLog();
if (!L.header) { console.error("no header in", a.log); process.exit(2); }
const H = L.header;

// ---- the hashes, read as they grow
const HS = { off: 0, list: [], checked: 0, bad: 0, firstBad: null };
function readHashes() {
    if (!a.hashes || !existsSync(a.hashes)) return;
    const fd = openSync(a.hashes, "r"), size = fstatSync(fd).size & ~3;
    if (size > HS.off) {
        const buf = Buffer.alloc(size - HS.off);
        readSync(fd, buf, 0, buf.length, HS.off);
        HS.off = size;
        for (let i = 0; i < buf.length; i += 4) HS.list.push(buf.readUInt32LE(i));
    }
    closeSync(fd);
}

// ---- the machines
const rsy = loadSyms(a.rsyms || H.rsyms || DEFAULTS.rsyms), csy = loadSyms(a.csyms);
const rand = H.seed !== undefined && H.seed !== null ? seedBytes(H.seed) : null;
const cmdr = COMMANDERS[H.commander || "jameson"];
const patch = cmdr.patch ? m => cmdr.patch(m) : null;
const ref = new EliteMachine({ name: "ref", disc: a.ref || H.ref || DEFAULTS.ref, syms: rsy, input: { rdkey: () => [], dks5: () => false, joy: () => 0x80 }, rand, patch });
await ref.boot();
for (let k = 0; k < 10000 && !ref.started; k++) ref.run(CYCLES_PER_FRAME);
if (!ref.started) { console.error("the reference never reached TT170"); process.exit(2); }
const pending = [];     // the candidate's hashes not yet checked
const cand = new EliteMachine({ name: "cand", disc: a.cand, syms: csy, rand, patch, seedFrom: ref, workarounds: H.workarounds || [],
    input: {
        rdkey(ctx) {
            if (ctx.poll >= L.safePolls) return null;
            const e = L.rlog.get(ctx.poll);
            if (e && (e.t !== "r" || e.s !== ctx.site)) mismatch(ctx, e);
            return e?.k || [];
        },
        dks5(ctx) {
            if (ctx.poll >= L.safePolls) return null;
            const e = L.rlog.get(ctx.poll);
            if (e && (e.t !== "d" || e.key !== ctx.key)) mismatch(ctx, e);
            return !!(e && e.t === "d");
        },
        joy(ctx) {
            if (ctx.joy >= L.safeJoys) return null;
            const l = L.rjoy[ctx.which];
            while (L.ptr[ctx.which] + 1 < l.length && l[L.ptr[ctx.which] + 1][0] <= ctx.joy) L.ptr[ctx.which]++;
            const e = l[L.ptr[ctx.which]];
            return e && e[0] <= ctx.joy ? e[1] : 0x80;
        },
    } });
let mismatches = 0;
function mismatch(ctx, e) { if (mismatches++ < 5) console.log(`read ${ctx.poll} (iteration ${ctx.iter}): the log has ${JSON.stringify(e)}, the candidate made a ${ctx.kind} from ${ctx.site}`); }
await cand.boot();
cand.pokes = L.pokes;
console.log(`film: ${a.log} on ${a.cand}; seed ${H.seed}, commander ${H.commander}, mode ${H.mode}`);

// ---- capture
const sy = cand.sy, ram = cand.ram;
const at = (n, o = 0) => ram[(sy[n] + o) & 0xffff];
const video = cand.s._video, chip = cand.s._soundChip;
// (--fps 25: every other frame painted, which halves the cost of the picture; the game itself
// draws at about 13 frames a second, so nothing it draws is lost)
const FPS = +(a.fps || 50);
if (FPS !== 50 && FPS !== 25) { console.error("--fps is 50 or 25"); process.exit(2); }
video.frameSkipCount = 50 / FPS;

// --sparse A,D,Q,U,C: the picture is painted (and recorded) only every so many 50 Hz frames by
// what is going on, as the cut will play it: C (close: a ship near and in the view shown, and 3 s
// after) every 2nd frame, so at its own speed at 25 fps; A (action: ships about, witchspace,
// the hyperspace count, the safe zone, screens other than the space view) every A-th; D docked;
// Q quiet flight; U the agent's dull cruise (its journal). Painting is most of the film's cost,
// so this keeps the film up with the session it follows. Each frame's step is in frames.bin.
const SPARSE = a.sparse ? a.sparse.split(",").map(Number) : null;      // [action, docked, quiet, dull, close]
const CLOSE = 2500;                     // (a ship nearer than this, in the view: about 30 pixels across and up)
const J = { path: a.journal || a.log.replace(/inputs\.jsonl$/, "journal.jsonl"), off: 0, rest: "", dull: [], di: 0, on: 0 };
function readJournal() {
    if (!existsSync(J.path)) return;
    const fd = openSync(J.path, "r"), size = fstatSync(fd).size;
    if (size > J.off) {
        const buf = Buffer.alloc(size - J.off);
        readSync(fd, buf, 0, buf.length, J.off);
        J.off = size;
        const lines = (J.rest + buf.toString("utf8")).split("\n");
        J.rest = lines.pop();
        for (const l of lines) if (l.includes('"dull"')) { const e = JSON.parse(l); J.dull.push([e.iter, e.e.on]); }
    }
    closeSync(fd);
}
if (SPARSE) readJournal();
function dullNow() { while (J.di < J.dull.length && J.dull[J.di][0] <= cand.iter) J.on = J.dull[J.di++][1]; return J.on; }
// the ships about: how near, and whether in the view shown (a cone of 45 degrees each way)
function ships() {
    let nView = 65535, nAny = 65535, cnt = 0, cntView = 0;
    const view = at("VIEW"), K = sy["K%"];
    for (let i = 2; i < 12; i++) {
        const t = at("FRIN", i);
        if (!(t === 1 || t === 3 || (t >= 9 && t < 128))) continue;
        const c = k => { const b = K + 37 * i + 3 * k, m = ram[b] | ram[b + 1] << 8 | (ram[b + 2] & 0x7f) << 16; return ram[b + 2] & 0x80 ? -m : m; };
        const x = c(0), y = c(1), z = c(2);
        const d = Math.min(65535, Math.max(Math.abs(x), Math.abs(y), Math.abs(z)));
        cnt++; nAny = Math.min(nAny, d);
        // (the axis the view looks along, and its direction)
        const [fwd, s1, s2] = view === 0 ? [z, x, y] : view === 1 ? [-z, x, y] : view === 2 ? [-x, z, y] : [x, z, y];
        if (fwd > 0 && Math.abs(s1) < fwd && Math.abs(s2) < fwd) { cntView++; nView = Math.min(nView, d); }
    }
    return { nView, nAny, cnt, cntView };
}
const C_ACTION = 0, C_DOCKED = 1, C_QUIET = 2, C_DULL = 3, C_CLOSE = 4;
let closeUntil = -1, frame50 = 0, nextPaint = 0, curStep = 1, curCls = 0;
function classify() {
    if (at("QQ12")) return C_DOCKED;
    const sh = ships();
    if (sh.nView < CLOSE) closeUntil = frame50 + 150;
    if (frame50 < closeUntil) return C_CLOSE;
    if (sh.cnt || at("MJ") || at("QQ22", 1) || at("QQ11") || at("FRIN", 1) === 2) return C_ACTION;
    return dullNow() ? C_DULL : C_QUIET;
}
if (SPARSE) {
    const pac = video.paintAndClear.bind(video);
    video.paintAndClear = function () {
        // (called at the end of each frame: whether the next is painted)
        frame50++;
        let paint = true;
        if (cand.started) {
            curCls = classify();
            const step = curCls === C_CLOSE ? 2 : SPARSE[curCls];
            if (frame50 >= nextPaint || step < curStep && frame50 >= nextPaint - curStep + step) { nextPaint = frame50 + step; curStep = step; paint = true; }
            else paint = false;
        }
        this.frameSkipCount = paint ? 1 : this.frameCount + 1;
        pac();
    };
}
// the picture: a fixed window, found from the first frames painted in the game (the border's
// size changes with the mode; the game keeps one mode throughout)
let geom = null, ff = null, frames = 0, drops = 0, frameRecs = [], soundRecs = [];
const FRAMES = `${OUT}/frames.bin`, SOUND = `${OUT}/sound.bin`;
writeFileSync(FRAMES, ""); writeFileSync(SOUND, "");
let waitDrain = null;
const origPaint = video.paint_ext;
video.paint_ext = (...args) => {
    origPaint.apply(video, args);
    if (!cand.started) return;
    if (!geom) {
        const l = video.leftBorder, t = video.topBorder, w = 1024 - l - video.rightBorder, h = 625 - t - video.bottomBorder;
        geom = { l, t, W: w >> 1, H: h >> 1 };
        geom.W -= geom.W & 1; geom.H -= geom.H & 1;
        console.log(`picture: ${geom.W} x ${geom.H} from (${l}, ${t})`);
        ff = spawn(FFMPEG, ["-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", `${geom.W}x${geom.H}`, "-r", String(FPS), "-i", "-",
            "-c:v", "libx264", "-preset", "veryfast", "-crf", String(a.crf || 12), "-g", "500", "-pix_fmt", "yuv444p", `${OUT}/raw.mkv`], { stdio: ["pipe", "inherit", "inherit"] });
        ff.stdin.on("drain", () => { if (waitDrain) { const w = waitDrain; waitDrain = null; w(); } });
        chip.catchUp();
        soundBase = chip.scheduler.epoch - chip._totalCycles;
        chip.startCapture();
    }
    const { l, t, W, H: Hh } = geom, src = cand.s._completeFb8, buf = Buffer.allocUnsafe(W * Hh * 3);
    for (let y = 0; y < Hh; y++) {
        let s = ((t + 2 * y) * 1024 + l) * 4, d = y * W * 3;
        for (let x = 0; x < W; x++, s += 8, d += 3) { buf[d] = src[s]; buf[d + 1] = src[s + 1]; buf[d + 2] = src[s + 2]; }
    }
    if (!ff.stdin.write(buf)) drops++;
    const r = Buffer.alloc(48);
    r.writeDoubleLE(chip.scheduler.epoch, 0);
    r.writeUInt32LE(cand.iter, 8);
    r[12] = at("QQ12"); r[13] = at("QQ11"); r[14] = at("MJ"); r[15] = at("VIEW");
    for (let i = 0; i < 12; i++) r[16 + i] = at("FRIN", i);
    r[28] = at("ENERGY"); r[29] = at("TP"); r[30] = at("GCNT"); r[31] = at("QQ22", 1);
    const { nView, nAny, cnt, cntView } = ships();
    r.writeUInt16LE(nView, 32); r.writeUInt16LE(nAny, 34); r[36] = cnt; r[37] = cntView; r[38] = at("SSPR"); r[39] = at("ESCP");
    r[40] = SPARSE ? curStep : 50 / FPS; r[41] = SPARSE ? curCls : 255; r.writeUInt32LE(frame50, 42);
    frameRecs.push(r);
    frames++;
};
let soundBase = 0;
function flush() {
    if (frameRecs.length) { appendFileSync(FRAMES, Buffer.concat(frameRecs)); frameRecs = []; }
    const w = chip.getCapturedWrites();
    if (w.length) {
        const b = Buffer.alloc(9 * w.length);
        w.forEach((x, i) => { b.writeDoubleLE(x.cycle + soundBase, 9 * i); b[9 * i + 8] = x.value; });
        appendFileSync(SOUND, b);
        chip.clearCapture();
    }
}

// ---- run
const t0 = Date.now();
let lastLog = 0, idle = 0;
const sleep = ms => new Promise(r => setTimeout(r, ms));
const maxFrames = a.maxframes ? +a.maxframes : Infinity;
for (;;) {
    const r = cand.run(CYCLES_PER_FRAME);
    // the hashes: each iteration's snapshot against the session's
    while (cand.snaps.length) { const [it, s] = cand.snaps.shift(); pending.push([it, snapHash(s)]); }
    if (pending.length > 2000 || r === "blocked") {
        readHashes();
        while (pending.length && pending[0][0] < HS.list.length) {
            const [it, h] = pending.shift();
            HS.checked++;
            if (HS.list[it] !== h) { HS.bad++; if (!HS.firstBad) { HS.firstBad = it; console.log(`HASH DIFFERS at iteration ${it}`); } }
        }
        if (!a.hashes) pending.length = 0;
    }
    if (ff && ff.stdin.writableNeedDrain) await new Promise(res => { waitDrain = res; });
    if (frameRecs.length > 1000) flush();
    if (r === "blocked") {
        if (L.end && cand.polls >= L.safePolls) break;
        readLog(); readJournal();
        if (cand.blocked && cand.blocked.kind !== "tt170" && (cand.blocked.kind === "joy" ? cand.blocked.joy >= L.safeJoys : cand.blocked.poll >= L.safePolls)) {
            if (L.end) break;
            flush(); idle++; await sleep(2000);
        }
    } else idle = 0;
    if (L.end && cand.iter >= L.end.iter + 2) break;
    if (frames >= maxFrames) break;
    if (Date.now() - lastLog > 30000) {
        lastLog = Date.now();
        if (SPARSE) readJournal();
        console.log(`[film] cand it ${cand.iter} reads ${cand.polls} frames ${frames} (${(frames / 3000).toFixed(1)} min) hashes ${HS.checked} ok, ${HS.bad} differ; wall ${((Date.now() - t0) / 1000).toFixed(0)} s; log to read ${L.safePolls}`);
        writeFileSync(`${OUT}/film.json`, JSON.stringify(info(false), null, 1));
    }
}
flush();
if (ff) { ff.stdin.end(); await new Promise(res => ff.on("exit", res)); }
// the hashes not yet checked: the session's last ones
readHashes();
for (const [it, h] of pending) if (it < HS.list.length) { HS.checked++; if (HS.list[it] !== h) { HS.bad++; HS.firstBad ??= it; } }
writeFileSync(`${OUT}/film.json`, JSON.stringify(info(true), null, 1));
console.log(`FILM ${HS.bad || mismatches ? "DIFFERS" : "OK"} ${OUT}: ${frames} frames (${(frames / 50 / 60).toFixed(1)} min), iterations ${cand.iter}, reads ${cand.polls}; hashes checked ${HS.checked}, differing ${HS.bad}; log mismatches ${mismatches}; wall ${((Date.now() - t0) / 1000).toFixed(0)} s`);
process.exit(HS.bad || mismatches ? 1 : 0);

function info(done) {
    return { done, log: a.log, cand: a.cand, geom, fps: FPS, frames, iters: cand.iter, reads: cand.polls, hashes: { file: a.hashes || null, checked: HS.checked, differing: HS.bad, firstBad: HS.firstBad },
        logMismatches: mismatches, soundBase, wall: (Date.now() - t0) / 1000 };
}
