#!/usr/bin/env node
// tloadcmp.mjs: what a disc's boot leaves in the host, and how long it takes.
// SHIFT+BREAK on the given host, then the times (host seconds from the BREAK)
// at which the parasite reaches p_start (the loader is done: every image in
// place) and TITLE (the host's start, hstart, is done too: the STA runs, the
// tables). With --ref, a second disc's boot on the same host, and at TITLE
// the host's memory compared byte for byte: the main RAM the host's images
// use (the Master's HMAIN, &3000-&3DFF and &7000-&7FFF; the Model B's
// &0E00-&0FFF and &7000-&7FFF), shadow RAM, ANDY, HAZEL and the sideways RAM
// banks (the Master's 4-7; the Model B's slots 0-15, the stash bank's from
// &8E00, overlay D's image), and the parasite's
// &0200-&FFFF (the regions the loaders stage files in, the zero page, stack
// and MOS workspace are not compared: they hold the loader's leftovers and
// the MOS's own state).
//
//   node tube/tools/tloadcmp.mjs --host Master|B --disc D [--ref R] [--psyms S]
//   node tube/tools/tloadcmp.mjs --host B --disc D --swram none   (no sideways RAM)
//   node tube/tools/tloadcmp.mjs --host B --disc D --notube       (no co-processor)
// The last two print what the screen shows after 10 seconds (mode 7's text;
// --shot F: the screen as a PNG too).
import { bootTube, tubeModel, ROOT } from "../../harness/tlib.mjs";
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { loadSyms } from "../../harness/mlib.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { statSync } from "fs";
const a = parseArgs({ host: "value", disc: "value", ref: "value", psyms: "value", swram: "value", notube: "flag", shot: "value" });
const HOST = a.host || "Master";
const psy = loadSyms(a.psyms || `${ROOT}tube/build/psyms.txt`);

// the mode 7 screen's text (the loaders' messages), from the MOS's screen start
function mode7(cpu) {
    const base = 0x7c00, L = [];
    for (let r = 0; r < 25; r++) {
        let s = "";
        for (let c = 0; c < 40; c++) { const b = cpu.ramRomOs[base + r * 40 + c] & 127; s += b >= 32 ? String.fromCharCode(b) : " "; }
        if (s.trim()) L.push(s.trimEnd());
    }
    return L.join("\n");
}

if (a.notube || a.swram === "none") {
    const base = HOST === "Master" ? "Master" : "B-DFS1.2";
    let s;
    if (a.notube) {
        s = new MachineSession(base);
        await s.initialise();
    } else {
        s = new MachineSession(tubeModel(base, Array(16).fill(false)));
        await s.initialise();
    }
    await s._machine.runFor(2e6 * 3);
    s.loadDisc(a.disc);
    s.keyDown(16); s.reset(true); await s._machine.runFor(2e6 * 2); s.keyUp(16);
    await s._machine.runFor(2e6 * 8);
    const cpu = s._machine.processor;
    console.log(`${HOST}${a.notube ? ", no co-processor" : ", no sideways RAM"}: host pc &${cpu.pc.toString(16)}, the screen:\n${mode7(cpu)}`);
    if (a.shot) (await import("fs")).writeFileSync(a.shot, await s.screenshot());
    process.exit(0);
}

async function boot(disc) {
    const t = await bootTube({ host: HOST, disc, mhz: +(process.env.TUBEMHZ || 3) });
    const marks = {}, dumps = {};
    const take = () => ({ h: t.hmem.slice(0, t.host.romOffset + 16 * 16384), p: t.pmem.slice(0, 65536) });   // (the host's RAM and banks)
    let t0;
    t.addParHook(pc => {
        if (pc === psy.p_start && !marks.p_start) marks.p_start = (t.hostCycles() - t0) / 2e6;
        if (pc === psy.TITLE && !marks.TITLE) { marks.TITLE = (t.hostCycles() - t0) / 2e6; dumps.TITLE = take(); return true; }
        return false;
    });
    t.s.keyDown(16); t.s.reset(true); t0 = t.hostCycles(); t.run(2e6 * 2); t.s.keyUp(16);
    for (let k = 0; k < 60 && !marks.TITLE; k++) t.run(2e6);
    return { t, marks, dumps };
}

const RO = 128 * 1024;
const regions = HOST === "Master"
    ? [["main: HMAIN", 0x1edc, 0x1edc + statSync(`${ROOT}tube/build/HMAIN.bin`).size], ["main &3000-&3DFF", 0x3000, 0x3e00], ["main &7000-&7FFF", 0x7000, 0x8000], ["ANDY", 0x8000, 0x9000], ["HAZEL &C000-&DEFF", 0x9000, 0x9000 + 0x1f00],
       ["shadow &3000-&7FFF", 0xb000, 0x10000], ...[4, 5, 6, 7].map(b => [`bank ${b}`, RO + b * 16384, RO + (b + 1) * 16384])]
    : [["main &0E00-&0FFF", 0x0e00, 0x1000], ["main &7000-&7FFF", 0x7000, 0x8000], ...Array.from({ length: 16 }, (_, b) =>
        // (the stash bank S, the fourth RAM slot (tlib.mjs's default: 4-7), from &8E00: below that it
        // holds the MOS's main RAM as hstart found it, with its clocks, DFS's catalogue and the boot's leftovers)
        b === 7 ? [`slot ${b} from &8E00`, RO + b * 16384 + 0xe00, RO + (b + 1) * 16384] : [`slot ${b}`, RO + b * 16384, RO + (b + 1) * 16384])];

const A = await boot(a.disc);
console.log(`${HOST} ${a.disc}: the parasite started at ${A.marks.p_start?.toFixed(2)} s, the title at ${A.marks.TITLE?.toFixed(2)} s`);
if (a.ref) {
    const B = await boot(a.ref);
    console.log(`${HOST} ${a.ref}: the parasite started at ${B.marks.p_start?.toFixed(2)} s, the title at ${B.marks.TITLE?.toFixed(2)} s`);
    let bad = 0;
    const at = "TITLE";
    if (!A.dumps[at] || !B.dumps[at]) { console.log(`${at}: not reached`); bad++; }
    else {
        for (const [n, lo, hi] of regions) {
            let d = 0;
            const runs = [];
            for (let i = lo; i < hi; i++) if (A.dumps[at].h[i] !== B.dumps[at].h[i]) {
                d++;
                const r = runs[runs.length - 1];
                if (r && i - r[1] <= 16) r[1] = i; else runs.push([i, i]);
            }
            if (d) { bad++; console.log(`${at}: ${n}: ${d} bytes differ, at offsets ${runs.slice(0, 8).map(([x, y]) => `&${(x - lo).toString(16)}-&${(y - lo).toString(16)}`).join(" ")}${runs.length > 8 ? " ..." : ""}`); }
        }
        let d = 0;
        for (let i = 0x0200; i < 0x10000; i++) if (A.dumps[at].p[i] !== B.dumps[at].p[i]) d++;
        if (d) { bad++; console.log(`${at}: the parasite's &0200-&FFFF: ${d} bytes differ`); }
    }
    console.log(bad ? "LOADCMP FAIL" : "LOADCMP PASS: the host's images and the parasite identical at TITLE");
}
process.exit(0);
