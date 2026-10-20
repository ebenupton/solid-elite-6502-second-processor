// The briefings' sheet and movies, from harness/mbrief.mjs's recordings of the original
// (REF) and the port (CAND):
// node harness/mbriefsheet.mjs --ref DIR --cand DIR --out DIR
// Writes OUT/sheet.png: for each config recorded in both, the original (left) and the
// port (right), each at a mode 1 pixel to 2x2, at each key wait (just before its key press) and, for BRIEF, half-way
// through its 64 turns at the start (BRL1) and its climb (BRL2); and, for each config
// with a ship (BRIEF), OUT/NAME-ref.mp4, NAME-cand.mp4 (every frame the video chip
// painted, 50 a second, from the ship's first frame to the status screen, x2 nearest
// neighbour) and NAME-side.mp4 (the two side by side, each at its own pace). It also
// prints the briefing's timing in both machines (mbriefcmp.mjs compares the game state).
import sharp from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/sharp/lib/index.js";
import { parseArgs } from "./args.mjs";
import { readFileSync, existsSync, mkdirSync, openSync, readSync, closeSync } from "fs";
import { execFileSync } from "child_process";
const a = parseArgs({ ref: "value", cand: "value", out: "value" });
const FFMPEG = "/opt/homebrew/bin/ffmpeg";
let W = 448, H = 300, FB = W * H * 3;          // (mbrief.mjs's size, set from its json)
mkdirSync(a.out, { recursive: true });
const NAMES = ["brief1", "debrief1", "brief2", "brief3", "debrief2"];
const LABEL = { brief1: "BRIEF (mission 1)", debrief1: "DEBRIEF", brief2: "BRIEF2 (mission 2)", brief3: "BRIEF3 (the plans)", debrief2: "DEBRIEF2" };
const frame = (dir, nm, i) => { const fd = openSync(`${dir}/${nm}.raw`, "r"), b = Buffer.alloc(FB); readSync(fd, b, 0, FB, i * FB); closeSync(fd); return b; };
const at = (j, t) => { let i = j.frames.findIndex(x => x >= t); return i < 0 ? j.frames.length - 1 : i; };
const png = (b, scale = 2) => sharp(b, { raw: { width: W, height: H, channels: 3 } }).resize(W * scale, H * scale, { kernel: "nearest" }).png().toBuffer();
const rows = [];
for (const nm of NAMES) {
    const jp = d => `${d}/${nm}.json`;
    if (!existsSync(jp(a.ref)) || !existsSync(jp(a.cand))) continue;
    const J = { ref: JSON.parse(readFileSync(jp(a.ref))), cand: JSON.parse(readFileSync(jp(a.cand))) };
    [W, H] = J.ref.size; FB = W * H * 3;
    // the moments: BRIEF's turns and climb (LL9 calls 32 and 64 + 64), every key wait (2.35 s in), the end
    const moments = [];
    if (J.ref.ll9.length > 130) moments.push(["turning (BRL1)", j => j.ll9[32].t], ["climbing (BRL2)", j => j.ll9[128].t]);
    J.ref.waits.forEach((w, k) => moments.push([`key wait ${k + 1} (${w.kind})`, j => j.waits[k].t + 2.35]));
    for (const [what, tf] of moments) rows.push({ nm, what, ref: frame(a.ref, nm, at(J.ref, tf(J.ref))), cand: frame(a.cand, nm, at(J.cand, tf(J.cand))) });
    if (J.ref.ll9.length > 130) {
        for (const side of ["ref", "cand"]) {
            const j = J[side], d = a[side];
            const i0 = at(j, j.ll9[0].t - 0.1), i1 = at(j, j.times.STATUS + 0.3);
            const fd = openSync(`${d}/${nm}.raw`, "r"), b = Buffer.alloc(FB * (i1 - i0 + 1)); readSync(fd, b, 0, b.length, i0 * FB); closeSync(fd);
            execFileSync(FFMPEG, ["-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", `${W}x${H}`, "-framerate", "50", "-i", "-",
                "-vf", "scale=iw*2:ih*2:flags=neighbor", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "12", "-preset", "slow", `${a.out}/${nm}-${side}.mp4`], { input: b, maxBuffer: 1 << 30 });
            console.log(`${a.out}/${nm}-${side}.mp4: ${i1 - i0 + 1} frames, ${((i1 - i0 + 1) / 50).toFixed(2)} s`);
        }
        execFileSync(FFMPEG, ["-y", "-loglevel", "error", "-i", `${a.out}/${nm}-ref.mp4`, "-i", `${a.out}/${nm}-cand.mp4`, "-filter_complex",
            "[0:v]tpad=stop_mode=clone:stop_duration=10,pad=iw+16:ih:0:0:color=0x303030[l];[1:v]tpad=stop_mode=clone:stop_duration=10[r];[l][r]hstack=inputs=2,trim=duration=" +
            Math.max(...["ref", "cand"].map(sd => J[sd].times.STATUS + 0.4 - J[sd].ll9[0].t)).toFixed(2),
            "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "12", `${a.out}/${nm}-side.mp4`]);
        // timing
        for (const side of ["ref", "cand"]) {
            const j = J[side], ll = j.ll9.map(x => x.t), p = j.pas1;
            const per = x => ((x[x.length - 1] - x[0]) / (x.length - 1) * 1000).toFixed(1);
            console.log(`${nm} ${side}: BRIEF to BR2 ${(j.times.BR2 - j.times.BRIEF).toFixed(2)} s; BRL1 ${per(ll.slice(0, 64))} ms a turn, BRL2 ${per(ll.slice(64, 191))} ms, PAS1 ${per(p.slice(1))} ms (${p.length} calls)`);
        }
    }
}
// the sheet: a title row, then for each moment a caption and the original | the port
const S = 2, CW = W * S, CH = H * S, GAP = 16, LH = 34;
const txt = (t, w, size = 22) => Buffer.from(`<svg width="${w}" height="${LH}"><rect width="100%" height="100%" fill="#202020"/><text x="8" y="${LH - 10}" font-family="Helvetica" font-size="${size}" fill="#e0e0e0">${t}</text></svg>`);
const sheetW = 2 * CW + GAP;
const comps = [];
let y = 0;
comps.push({ input: txt("Original SNG47 (left) and the port with the renderer (right)", sheetW, 26), top: y, left: 0 }); y += LH;
for (const r of rows) {
    comps.push({ input: txt(`${LABEL[r.nm]}: ${r.what}`, sheetW), top: y, left: 0 }); y += LH;
    comps.push({ input: await png(r.ref, S), top: y, left: 0 }, { input: await png(r.cand, S), top: y, left: CW + GAP }); y += CH + 8;
}
await sharp({ create: { width: sheetW, height: y, channels: 3, background: "#202020" } }).composite(comps).png().toFile(`${a.out}/sheet.png`);
console.log(`${a.out}/sheet.png: ${rows.length} rows`);
