// Capture the rasteriser's API calls from a compare.mjs-equivalent run (seeded
// from the original's TT170 state, LASCT injected), for offline replay.
//
// node harness/capture.mjs [--frames 3000] [--port disc] [--psyms file]
//                          [--out file.jsonl] [--orig-cache file.json]
//
// One JSON line per TT100 iteration:
//   {it, cyc, grp: {raster, frame, ...}, calls: [[name, cycles, hex], ...]}
// where cycles is the in-game cost of the call (trampoline entry to return,
// including any interrupts taken meanwhile) and hex its inputs (see INPUTS).
// The original's TT170 state and LASCT log are cached (they don't change).

import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { readFileSync, writeFileSync, existsSync, openSync, writeSync, closeSync } from "fs";
import { execSync } from "child_process";

const args = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => {
    if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]);
    return acc;
}, []));
const MAIN = "/Users/ebenupton/elite";
const ROOT = process.env.ROOT || decodeURIComponent(new URL("..", import.meta.url).pathname).replace(/\/$/, "");
const FRAMES = +(args.frames || 3000);
const PORT_DISC = args.port || `${ROOT}/build/elite-master.ssd`;
const PSYMS = args.psyms || `${ROOT}/build/symbols.txt`;
const OUTF = args.out || `${ROOT}/scratch/capture.jsonl`;
const CACHE = args["orig-cache"] || `${ROOT}/build/orig-cache-${FRAMES}.json`;
const ORIG_DISC = `${MAIN}/ref/elite-demo-source-code-bbc-micro/5-compiled-game-discs/elite-demonstration-disc.ssd`;

function loadSyms(path) {
    const syms = {};
    for (const m of readFileSync(path, "utf8").matchAll(/'([^']+)':(\d+)L?/g)) syms[m[1]] = +m[2];
    return syms;
}
const psyms = loadSyms(PSYMS);

async function makeMachine(model, disc) {
    const s = new MachineSession(model);
    await s.initialise();
    await s.boot(30);
    s.loadDisc(disc);
    s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
    return s;
}
function findLasctReads(s, lo, hi, lasct, irqLo, irqHi) {
    const mem = s.readMemory(lo, hi - lo), res = [];
    for (let i = 0; i < mem.length - 2; i++) {
        const a = lo + i;
        if (mem[i] === 0xad && mem[i + 1] === (lasct & 255) && mem[i + 2] === (lasct >> 8) && !(a >= irqLo && a < irqHi)) res.push(a);
    }
    return res;
}

// --- the original: TT170 state + LASCT log (cached) -------------------------
let orig;
if (existsSync(CACHE)) orig = JSON.parse(readFileSync(CACHE, "utf8"));
else {
    const of = `${MAIN}/build/orig-symbols.txt`;
    if (!existsSync(of)) execSync(`cd ${MAIN}/ref/elite-demo-source-code-bbc-micro && ${MAIN}/tools/beebasm -i 1-source-files/main-sources/elite-source.asm -d > ${of} 2>/dev/null`);
    const osyms = loadSyms(of);
    const s = await makeMachine("B-DFS1.2", ORIG_DISC);
    const cpu = s._machine.processor;
    let started = false, n = 0, done = false, reads = new Set();
    const lasct = [], init = {};
    const h = pc => {
        if (pc === osyms.TT170 && !started) {
            started = true;
            init.rand = s.readMemory(0, 4);
            init.t = s.readMemory(0x300, 0x72);
            init.wp = s.readMemory(0xd40, 0x1f9);
            reads = new Set(findLasctReads(s, 0x0f40, 0x5800, osyms.LASCT, osyms.LINSCN, osyms.AttackTarget || osyms.TACTICS));
            return false;
        }
        if (started && reads.has(pc)) lasct.push(s.readMemory(osyms.LASCT, 1)[0]);
        if (started && pc === osyms.TT100 && ++n >= FRAMES + 5) { done = true; return true; }
        return false;
    };
    cpu.debugInstruction.add(h);
    while (!done) for (let k = 0; k < 40 && !done; k++) { h(cpu.pc); cpu.execute(50000); }
    orig = { init, lasct, frames: FRAMES + 5 };
    writeFileSync(CACHE, JSON.stringify(orig));
    console.log(`orig: cached ${lasct.length} LASCT values`);
}

// --- the port -----------------------------------------------------------------
const s = await makeMachine("Master", PORT_DISC);
const cpu = s._machine.processor;
const rb = a => cpu.readmem(a);
const rbs = (a, n) => { let h = ""; for (let i = 0; i < n; i++) h += rb(a + i).toString(16).padStart(2, "0"); return h; };
const zp = () => rbs(0x06, 10);
const S = psyms;
// inputs per entry point
const INPUTS = {
    T_SETBUF: () => cpu.a.toString(16).padStart(2, "0"),
    T_RESETBUF: () => "", T_STARERASE: () => "", T_WMERGE: () => "", T_CLEARALL: () => zp(), T_INIT: () => "",
    T_POLY: () => zp() + rbs(S.R_PN, 65),
    T_LINE: () => zp() + rbs(S.R_X0, 8),
    T_DOT: () => zp() + [cpu.a, cpu.x, cpu.y].map(v => v.toString(16).padStart(2, "0")).join(""),
    T_SPAN: () => zp() + cpu.y.toString(16).padStart(2, "0"),
    T_MARKDIRTY: () => zp() + cpu.y.toString(16).padStart(2, "0"),
    T_STARPLOT: () => zp() + rbs(S.R_SN, 73) + rbs(S.R_SCOL, 1),
    T_DISCROWS: () => {
        const t = rb(S.R_NDT), b = rb(S.R_NDB);
        let h = zp() + rbs(S.R_NDT, 2) + rbs(S.R_NDF, 3);
        if (t <= b) {
            const n = b - t + 1;
            for (const a of ["R_NDISCL", "R_NDISCR", "R_NDN", "R_NDP", "R_NDX0", "R_NDX1", "R_NDX2", "R_NDX3"]) h += rbs(S[a] + t, n);
        }
        return h;
    },
};
const entry = {}, exitpc = {};
for (const k of Object.keys(INPUTS)) { entry[S[k]] = k; exitpc[S[k] + 16] = k; }
const fdd = S.f_discdirty;
// groups for per-iteration accounting
const labelsIn = f => new Set([...readFileSync(f, "latin1").matchAll(/^\.([A-Za-z_][A-Za-z0-9_%]*)/gm)].map(m => m[1]));

let started = false, done = false, it = 0, lasctPtr = 0, reads = new Set();
let cur = null, curName = null, c0 = 0;
const cyc = () => cpu.cycleSeconds * 2e6 + cpu.currentCycles;
const fd = openSync(OUTF, "w");
let rec = null, itStart = 0, lastC = 0, lastBank = "";
const flushRec = () => { if (rec) writeSync(fd, JSON.stringify(rec) + "\n"); };
const h = pc => {
    if (pc === S.TT170 && !started) {
        started = true;
        s.writeMemory(0, orig.init.rand);
        s.writeMemory(0x300, orig.init.t);
        s.writeMemory(0xd40, orig.init.wp);
        reads = new Set(findLasctReads(s, 0x0f40, 0x5800, S.LASCT, S.LINSCN, S.AttackTarget || S.TACTICS));
        for (const a of findLasctReads(s, 0x8000, 0xc000, S.LASCT, -1, -1)) reads.add(a);
        return false;
    }
    if (!started) return false;
    if (reads.has(pc)) { if (lasctPtr < orig.lasct.length) s.writeMemory(S.LASCT, [orig.lasct[lasctPtr]]); lasctPtr++; }
    const now = cyc();
    if (rec) {   // group accounting
        const g = lastBank;
        rec.grp[g] = (rec.grp[g] || 0) + now - lastC;
    }
    lastC = now;
    lastBank = pc >= 0xc000 ? (pc >= 0xe000 ? "mos" : "hazel") : pc >= 0x8000 ? "b" + (cpu.romsel & 15) : "main";
    if (pc === S.TT100) {
        if (rec) { rec.cyc = now - itStart; flushRec(); }
        if (it >= FRAMES) { done = true; return true; }
        rec = { it, cyc: 0, grp: {}, calls: [] }; itStart = now; it++;
        return false;
    }
    if (pc >= 0xc000 && pc < 0xe000) {
        const e = entry[pc];
        if (e && rec) { cur = [e.slice(2), 0, INPUTS[e]()]; c0 = now; return false; }
        const x = exitpc[pc];
        if (x && cur && rec) { cur[1] = now - c0; rec.calls.push(cur); cur = null; return false; }
    } else if (pc === fdd && (cpu.romsel & 15) === 6 && rec) rec.calls.push(["DISCDIRTY", 0, ""]);
    return false;
};
cpu.debugInstruction.add(h);
const t0 = Date.now();
while (!done) for (let k = 0; k < 40 && !done; k++) { h(cpu.pc); cpu.execute(50000); }
closeSync(fd);
console.log(`port: ${it} iterations captured to ${OUTF} in ${((Date.now() - t0) / 1000).toFixed(0)} s; LASCT consumed ${lasctPtr}/${orig.lasct.length}`);
process.exit(0);
