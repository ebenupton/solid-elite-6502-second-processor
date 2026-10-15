// Load a jsbeeb save state (web UI .json[.gz]), dump both screen buffers as
// PNGs and the planet/disc-layer state, optionally run on N frames.
// node harness/state-inspect.mjs STATE.json.gz SYMS OUTDIR [--frames N] [--every K]
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { restoreSnapshot, snapshotFromJSON } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/snapshot.js";
import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { gunzipSync, inflateSync } from "zlib";
import sharp from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/sharp/lib/index.js";
const argv = process.argv.slice(2);
const a = Object.fromEntries(argv.reduce((acc, v, i, arr) => { if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]); return acc; }, []));
const [STATE, SYMS, OUT] = argv;
mkdirSync(OUT, { recursive: true });
const syms = {};
for (const m of readFileSync(SYMS, "utf8").matchAll(/'([^']+)':(\d+)L?/g)) syms[m[1]] = +m[2];
let raw = readFileSync(STATE);
if (STATE.endsWith(".gz")) raw = gunzipSync(raw);
// The web UI's version-4 state deflates the 128K RAM image and doesn't hold
// the sideways RAM banks: reload those from the build (--build dir: its
// ELTBANK.bin -> bank 4, BANK5/6/7.bin -> 5/6/7). Bank 6's data (F_BACK,
// F_DCOL, text maps) is then the image's, not the saved machine's.
const js = JSON.parse(raw.toString());
const ramb = js.state.ram;
const ram = ramb.encoding === "deflate" ? new Uint8Array(inflateSync(Buffer.from(ramb.data, "base64"))) : new Uint8Array(Buffer.from(ramb.data, "base64"));
delete js.state.ram;
const snap = snapshotFromJSON(JSON.stringify(js));
snap.state.ram = ram;
const s = new MachineSession("Master");
await s.initialise(); await s.boot(30);
const cpu = s._machine.processor;
cpu.restoreState(snap.state);   // (the web UI writes version 4; the state layout is compatible enough)
const R = cpu.ramRomOs, ROM = cpu.romOffset;
if (a.build) for (const [b, f] of [[4, "ELTBANK.bin"], [5, "BANK5.bin"], [6, "BANK6.bin"], [7, "BANK7.bin"]]) R.set(readFileSync(`${a.build}/${f}`), ROM + b * 16384);
if (a.back !== undefined) R[ROM + 6 * 16384 + syms.F_BACK - 0x8000] = +a.back;
const hz = (n, k = 1) => Array.from(R.subarray(syms[n] - 0x3000, syms[n] - 0x3000 + k));
const b6 = (n, k = 1) => Array.from(R.subarray(ROM + 6 * 16384 + syms[n] - 0x8000, ROM + 6 * 16384 + syms[n] - 0x8000 + k));
const RGB = [[0, 0, 0], [0, 255, 255], [255, 0, 255], [255, 255, 0]];
async function dumpBuf(buf, name) {
    const base = buf ? 0x8000 : 0;
    const img = Buffer.alloc(256 * 192 * 3);
    for (let y = 0; y < 192; y++) for (let x = 0; x < 256; x++) {
        const b = R[base + 0x4000 + (y >> 3) * 512 + (y & 7) + 8 * (x >> 2)], p = x & 3;
        const v = ((b >> (7 - p)) & 1) * 2 + ((b >> (3 - p)) & 1);
        img.set(RGB[v], (y * 256 + x) * 3);
    }
    await sharp(img, { raw: { width: 256, height: 192, channels: 3 } }).resize(768, 576, { kernel: "nearest" }).png().toFile(`${OUT}/${name}.png`);
}
function state(tag) {
    const o = { tag, pc: cpu.pc.toString(16), romsel: cpu.romsel, acccon: cpu.acccon };
    for (const n of ["F_BACK", "F_PLON", "F_PLT", "F_PLR", "F_NCV", "F_NPT", "f_lay", "F_DCOL"]) if (syms[n] !== undefined) o[n] = b6(n, n === "F_DCOL" ? 2 : 1);
    for (const n of ["F_PLX", "F_PLY"]) if (syms[n] !== undefined) o[n] = b6(n, 2);
    for (const n of ["GFRONT", "GPEND", "GFLIP", "R_NDT", "R_NDB", "R_NDF", "GSUNON", "PM_OK"]) if (syms[n] !== undefined) o[n] = hz(n)[0];
    o.QQ11 = R[syms.QQ11];
    return o;
}
function rows(tag) {
    const out = [tag];
    for (const b of [0, 1]) {
        const L = hz(`R_DISCL${b}`, 192), Rr = hz(`R_DISCR${b}`, 192), DL = hz(`R_DIRTYL${b}`, 192), DR = hz(`R_DIRTYR${b}`, 192);
        const rr = [];
        for (let y = 0; y < 192; y++) if (L[y] <= Rr[y] || DR[y]) rr.push(`${y}:${L[y]}-${Rr[y]}${DR[y] ? ` d${DL[y]}-${DR[y]}` : ""}`);
        out.push(`buf${b} disc rows: ${rr.join(" ")}`);
    }
    return out.join("\n");
}
console.log(JSON.stringify(state("loaded")));
writeFileSync(`${OUT}/rows0.txt`, rows("loaded"));
await dumpBuf(0, "f000_buf0"); await dumpBuf(1, "f000_buf1");
const FR = +(a.frames || 0), EV = +(a.every || 1);
let n = 0, ff = syms.F_FRAME;
let hit = false;
cpu.debugInstruction.add(pc => { if (pc === ff && (cpu.romsel & 15) === 6) { hit = true; return true; } return false; });
while (n < FR) {
    hit = false;
    while (!hit) cpu.execute(20000);
    cpu.execute(1); // step off
    n++;
    if (n % EV === 0) {
        console.log(JSON.stringify(state(`frame ${n}`)));
        await dumpBuf(0, `f${String(n).padStart(3, "0")}_buf0`); await dumpBuf(1, `f${String(n).padStart(3, "0")}_buf1`);
        writeFileSync(`${OUT}/rows${n}.txt`, rows(`frame ${n}`));
    }
}
process.exit(0);
