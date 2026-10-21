#!/usr/bin/env node
// The cut of a film (film.mjs): the whole run, with the close fighting at its own speed and the
// rest fast-forwarded, with the game's sound, a game clock, the galaxy and the speed burnt in,
// and the highlights listed with their times in the cut.
//
// node master/tools/agentplay/edit.mjs --film DIR --run RUNDIR --out FILE.mp4 [--target MINUTES]
//      [--speeds [NEAR,]C,A,D,Q,U] [--minutes M] [--clips FILE] [--every S] [--scale 2] [--crf 26] [--preset medium] [--plan-only]
//
// Each frame is classed from frames.bin (the port's RAM as the frame was shown) and the
// session's journal (elite-agent's dull cruise, and its events for the highlights):
//   close    a ship (not the station or junk) near and in the view shown, and 3 s round it
//   action   other flying with ships about, witchspace, the hyperspace count, the safe zone
//            (docking and launching), the charts and other screens in flight
//   docked   the docked screens
//   quiet    flying with nothing about
//   dull     the agent's dull cruise (flying in to the station with nothing about)
// The speeds are --speeds, or the gentlest step of a ladder that fits --target minutes (the
// steps speed up the rest first, then count only nearer ships as close, and only then speed
// up the close fighting itself).
// Stretches under 2 s join the slower stretch before them. The sound plays where the cut runs
// at its own speed; fast-forwarded stretches are silent.
// Writes FILE.mp4 (H.264 and AAC, at the film's frame rate), FILE.plan.json (classes, speeds,
// segments and highlights, with their times in the cut and in the game).
import { parseArgs } from "../../../harness/args.mjs";
import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { dirname } from "path";
import { spawn, execFileSync } from "child_process";
import { ROOT } from "./lib.mjs";
import sharp from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/sharp/lib/index.js";

const a = parseArgs({ film: "value", run: "value", out: "value", target: "value", speeds: "value", minutes: "value", clips: "value", every: "value", scale: "value", crf: "value", preset: "value", "plan-only": "flag" });
if (!a.film || !a.run || !a.out) { console.error("--film, --run and --out are required"); process.exit(2); }
mkdirSync(dirname(a.out), { recursive: true });
const FFMPEG = "/opt/homebrew/bin/ffmpeg";
const SNSYNTH = `${ROOT}scratch/agentplay/snsynth`;
const base = a.out.replace(/\.mp4$/, "");
const film = JSON.parse(readFileSync(`${a.film}/film.json`, "utf8"));
const { W, H } = film.geom, FPS = film.fps || 50;
const REC = 48, FB = readFileSync(`${a.film}/frames.bin`);
// (the frames raw.mkv holds: those frames.bin and the video agree on; a film still running
// has written some frames' records before their pictures reach the file, or after)
const N = Math.min(Math.floor(FB.length / REC), film.frames || Infinity);
const fr = i => ({ t: FB.readDoubleLE(REC * i), it: FB.readUInt32LE(REC * i + 8), qq12: FB[REC * i + 12], qq11: FB[REC * i + 13], mj: FB[REC * i + 14],
    frin1: FB[REC * i + 17], tp: FB[REC * i + 29], gcnt: FB[REC * i + 30], hyp: FB[REC * i + 31], nView: FB.readUInt16LE(REC * i + 32), cnt: FB[REC * i + 36], escp: FB[REC * i + 39] });
const SEC = FPS;                                  // frames a second
const hms = s => { s = Math.floor(s); return `${Math.floor(s / 3600)}:${String(Math.floor(s / 60) % 60).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`; };

// ---- the journal
const journal = readFileSync(`${a.run}/journal.jsonl`, "utf8").split("\n").filter(Boolean).map(l => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
const dullAt = [], events = [];
for (const j of journal) { if (j.e?.event === "dull") dullAt.push([j.iter, j.e.on]); else if (j.e && typeof j.e === "object") events.push([j.iter, j.e]); }

// ---- classes
const CLOSE = 0, ACTION = 1, DOCKED = 2, QUIET = 3, DULL = 4;
const NAMES = ["close", "action", "docked", "quiet", "dull"];
function classify(NEAR) {
    const cls = new Uint8Array(N);
    let di = 0, dull = 0;
    for (let i = 0; i < N; i++) {
        const f = fr(i);
        while (di < dullAt.length && dullAt[di][0] <= f.it) dull = dullAt[di++][1];
        if (f.qq12) cls[i] = DOCKED;
        else if (f.nView < NEAR) cls[i] = CLOSE;
        else if (f.cnt || f.mj || f.hyp || f.qq11 || f.frin1 === 2) cls[i] = ACTION;
        else cls[i] = dull ? DULL : QUIET;
    }
    // close spreads 3 s each way (a ship coming into the picture and going out of it)
    const PAD = 3 * SEC, src = cls.slice();
    let last = -1e9;
    for (let i = 0; i < N; i++) { if (src[i] === CLOSE) last = i; else if (i - last <= PAD && cls[i] !== DOCKED) cls[i] = CLOSE; }
    last = 1e9;
    for (let i = N - 1; i >= 0; i--) { if (src[i] === CLOSE) last = i; else if (last - i <= PAD && cls[i] !== DOCKED) cls[i] = CLOSE; }
    // segments; one under 2 s joins the one before it if that is slower (a lower class number is slower)
    const segs = [];
    for (let i = 0; i < N;) {
        let j = i; while (j < N && cls[j] === cls[i]) j++;
        const p = segs.at(-1);
        if (p && (p.c === cls[i] || (j - i < 2 * SEC && cls[i] > p.c))) p.e = j;
        else segs.push({ s: i, e: j, c: cls[i] });
        i = j;
    }
    const count = [0, 0, 0, 0, 0];
    for (const g of segs) count[g.c] += g.e - g.s;
    return { segs, count };
}

// ---- speeds: [how near a ship in view makes it close, then the five classes' speeds]
const LADDER = [[2500, 1, 2, 2, 8, 16], [2500, 1, 3, 3, 8, 24], [2500, 1, 4, 4, 12, 32], [2000, 1, 6, 4, 16, 48], [1500, 1, 8, 6, 24, 64], [1200, 1, 8, 8, 32, 64],
    [1000, 1, 12, 8, 32, 96], [800, 1, 16, 12, 48, 128], [600, 1.5, 16, 12, 48, 128], [500, 2, 24, 16, 64, 192]];
const outLen = (sp, count) => count.reduce((s, n, k) => s + n / sp[k], 0);
let step, C;
if (a.speeds) { step = a.speeds.split(",").map(Number); if (step.length === 5) step.unshift(2500); C = classify(step[0]); }
else { const target = a.target ? +a.target * 60 * SEC : Infinity; for (const st of LADDER) { step = st; C = classify(st[0]); if (outLen(st.slice(1), C.count) <= target) break; } }
const speeds = step.slice(1), { segs, count } = C;
console.log(`film frames ${N} (${hms(N / SEC)} of game): ${NAMES.map((n, k) => `${n} ${hms(count[k] / SEC)}`).join(", ")}`);
console.log(`close: a ship within ${step[0]} in view; speeds ${NAMES.map((n, k) => `${n} x${speeds[k]}`).join(", ")}: the cut about ${hms(outLen(speeds, count) / SEC)}`);

// ---- the cut
const pick = [];
const segOut = [];
for (const g of segs) {
    const sp = speeds[g.c], o0 = pick.length;
    for (let x = g.s; x < g.e; x += sp) pick.push(Math.floor(x));
    segOut.push({ ...g, speed: sp, o0, o1: pick.length });
}
// (--clips FILE: instead, these stretches only, each at its own speed, captioned: [{frm, to, title}])
if (a.clips) {
    pick.length = 0; segOut.length = 0;
    for (const c of JSON.parse(readFileSync(a.clips, "utf8"))) {
        const o0 = pick.length;
        for (let x = c.frm; x < c.to; x++) pick.push(x);
        segOut.push({ s: c.frm, e: c.to, c: CLOSE, speed: 1, o0, o1: pick.length, title: c.title });
    }
}
// (--minutes: only the cut's first so many minutes)
if (a.minutes) {
    const lim = Math.round(+a.minutes * 60 * FPS);
    if (pick.length > lim) {
        pick.length = lim;
        while (segOut.length && segOut[segOut.length - 1].o0 >= lim) segOut.pop();
        const g = segOut[segOut.length - 1];
        if (g.o1 > lim) { g.e = g.s + (lim - g.o0) * g.speed; g.o1 = lim; }
    }
}
const M = pick.length;
function outOf(frame) { let lo = 0, hi = segOut.length - 1; while (lo < hi) { const m = (lo + hi + 1) >> 1; if (segOut[m].s <= frame) lo = m; else hi = m - 1; } const g = segOut[lo]; return g.o0 + Math.floor((frame - g.s) / g.speed); }
function frameOfIter(it) { let lo = 0, hi = N - 1; while (lo < hi) { const m = (lo + hi) >> 1; if (FB.readUInt32LE(REC * m + 8) < it) lo = m + 1; else hi = m; } return lo; }

// ---- highlights
const hl = [];
const add = (frame, text, kind) => { if (frame < 0 || frame >= N) return; hl.push({ cut: hms(outOf(frame) / SEC), game: hms(fr(frame).t / 2e6), text, kind, frame }); };
{
    let p = fr(0), inWitch = false;
    for (let i = 1; i < N; i++) {
        const f = fr(i);
        if (f.gcnt !== p.gcnt) add(i, `Galaxy ${f.gcnt + 1} (galactic hyperdrive)`, "galaxy");
        if (f.tp !== p.tp) add(i, `Mission state changes (TP ${p.tp} to ${f.tp})`, "mission");
        if (f.mj && !inWitch) add(i, "Witchspace: a mis-jump among the Thargoids", "witchspace");
        inWitch = !!f.mj;
        p = f;
    }
}
const firstEquip = new Set();
for (const [it, e] of events) {
    const fi = frameOfIter(it);
    switch (e.event) {
        case "died": add(fi, "Destroyed: the agent reloads its last save", "died"); break;
        case "stuck": add(fi, `Stuck (${e.why}): reloads its last save`, "stuck"); break;
        case "rank": add(fi, `Rank: ${e.rank} (tally ${e.tally})`, "rank"); break;
        case "galaxy": add(fi, `Galactic hyperdrive engaged (tally ${e.tally})`, "galaxy-jump"); break;
        case "escape_pod": add(fi, "Escape pod launched", "pod"); break;
        case "pod_dock": add(fi, "The escape pod docks", "pod"); break;
        case "bomb": add(fi, "Energy bomb", "bomb"); break;
        case "new_system": add(fi, `First visit: ${e.name} (galaxy ${e.galaxy}, system #${e.seen} seen)`, "system"); break;
        case "equip": if (!firstEquip.has(e.item)) { firstEquip.add(e.item); add(fi, `Buys ${e.item}`, "equip"); } break;
        case "session": if (e.kind === "witchspace") add(fi, `Witchspace session over: ${e.points} points in ${e.minutes} min`, "session"); break;
        case "fight_end": if (e.kills >= 3) add(fi, `A fight with ${e.kills} kills`, "fight"); break;
        case "loaded": add(fi, `Loads commander ${e.name} from disc`, "load"); break;
    }
}
hl.sort((x, y) => x.frame - y.frame);
const plan = { film: a.film, run: a.run, fps: FPS, filmFrames: N, gameTime: hms(N / SEC), counts: Object.fromEntries(NAMES.map((n, k) => [n, hms(count[k] / SEC)])),
    near: step[0], speeds: Object.fromEntries(NAMES.map((n, k) => [n, speeds[k]])), cutFrames: M, cutTime: hms(M / SEC),
    segments: segOut.map(g => ({ from: g.s, to: g.e, cls: NAMES[g.c], speed: g.speed, cut: [hms(g.o0 / SEC), hms(g.o1 / SEC)] })), highlights: hl };
writeFileSync(`${base}.plan.json`, JSON.stringify(plan, null, 1));
console.log(`cut: ${M} frames, ${hms(M / SEC)}; ${segOut.length} segments; ${hl.length} highlights`);
if (a["plan-only"]) process.exit(0);

// ---- sound: the stretches at their own speed
const SPF = 44100 / FPS;            // samples a frame
const segFile = `${base}.segments.txt`, audioFile = `${base}.s16`;
{
    const T = i => FB.readDoubleLE(REC * Math.min(i, N - 1));
    const per = (T(N - 1) - T(0)) / Math.max(1, N - 1);
    const lines = [];
    for (const g of segOut) {
        const n = g.o1 - g.o0;
        if (g.speed === 1) lines.push(`a ${T(g.s)} ${g.e < N ? T(g.e) : T(g.s) + (g.e - g.s) * per} ${n * SPF}`);
        else lines.push(`s ${n * SPF}`);
    }
    writeFileSync(segFile, lines.join("\n") + "\n");
    execFileSync("sh", ["-c", `"${SNSYNTH}" "${a.film}/sound.bin" < "${segFile}" > "${audioFile}"`]);
}

// ---- the overlay's font: Menlo, a cell a character, thresholded
const CHARS = "0123456789:>x. ABCDEFGHIJKLMNOPQRSTUVWXYZ+-/", CW = 6, CHH = 10;
const glyph = {};
for (const c of CHARS) {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${CW}" height="${CHH}"><rect width="100%" height="100%" fill="black"/><text x="0" y="8" font-family="Menlo" font-size="9.5" fill="white" xml:space="preserve">${c}</text></svg>`;
    const { data, info } = await sharp(Buffer.from(svg)).raw().toBuffer({ resolveWithObject: true });
    const g = new Uint8Array(CW * CHH);
    for (let y = 0; y < CHH; y++) for (let x = 0; x < CW; x++) g[y * CW + x] = data[(y * info.width + x) * info.channels] > 100 ? 1 : 0;
    glyph[c] = g;
}
function text(buf, x0, y0, s, rgb) {
    for (const c of s) {
        const g = glyph[c] || glyph[" "];
        for (let y = 0; y < CHH; y++) for (let x = 0; x < CW; x++) if (g[y * CW + x]) { const d = ((y0 + y) * W + x0 + x) * 3; buf[d] = rgb[0]; buf[d + 1] = rgb[1]; buf[d + 2] = rgb[2]; }
        x0 += CW;
    }
}

// ---- video: decode the film, keep the picked frames, overlay, encode with the sound
const scale = +(a.scale || 2);
const enc = spawn(FFMPEG, ["-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", `${W}x${H}`, "-r", String(FPS), "-i", "-",
    "-f", "s16le", "-ar", "44100", "-ac", "1", "-i", audioFile,
    "-vf", `scale=iw*${scale}:ih*${scale}:flags=neighbor,format=yuv420p`, "-c:v", "libx264", "-preset", a.preset || "medium", "-crf", String(a.crf || 26), "-tune", "animation",
    "-g", String(10 * FPS), "-c:a", "aac", "-b:a", "64k", "-movflags", "+faststart", "-shortest", a.out], { stdio: ["pipe", "inherit", "inherit"] });
const dec = spawn(FFMPEG, ["-loglevel", "error", "-i", `${a.film}/raw.mkv`, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], { stdio: ["ignore", "pipe", "inherit"] });
const FS = W * H * 3;
const cur = Buffer.alloc(FS);
let fill = 0, inFrame = 0, o = 0, segI = 0;
const writeOut = b => new Promise(res => { if (enc.stdin.write(b)) res(); else enc.stdin.once("drain", res); });
const t0 = Date.now();
let lastLog = 0;
outer: for await (const chunk of dec.stdout) {
    let off = 0;
    while (off < chunk.length) {
        const n = Math.min(FS - fill, chunk.length - off);
        // (only the frames the cut keeps are copied out of the stream)
        if (pick[o] === inFrame) chunk.copy(cur, fill, off, off + n);
        fill += n; off += n;
        if (fill < FS) break;
        fill = 0;
        while (o < M && pick[o] === inFrame) {
            const out = Buffer.from(cur);
            while (segI < segOut.length - 1 && o >= segOut[segI].o1) segI++;
            const g = segOut[segI], f = fr(inFrame);
            text(out, 4, 4, `GAME ${hms(f.t / 2e6)}`, [190, 190, 190]);
            text(out, 4, 16, `GALAXY ${f.gcnt + 1}`, [190, 190, 190]);
            if (g.speed !== 1) text(out, 4, 32, `>> x${g.speed}`, [255, 255, 0]);
            if (g.title && o - g.o0 < 5 * SEC) text(out, Math.floor((W - g.title.length * CW) / 2), 52, g.title, [255, 255, 0]);
            await writeOut(out);
            o++;
        }
        inFrame++;
        if (o >= M) break outer;
        if (Date.now() - lastLog > 1000 * +(a.every || 30)) { lastLog = Date.now(); console.log(`[edit] film ${inFrame}/${N} cut ${o}/${M} (${hms(o / SEC)}) wall ${((Date.now() - t0) / 1000).toFixed(0)} s`); }
    }
}
dec.kill();
enc.stdin.end();
await new Promise(res => enc.on("exit", res));
console.log(`EDIT ${a.out}: ${o} of ${M} frames (${hms(o / SEC)}), wall ${((Date.now() - t0) / 1000).toFixed(0)} s`);
