// Determinism and speed comparison: original Elite demo (B-DFS1.2) vs BBC Master port.
//
// node harness/compare.mjs [--frames 3000] [--orig disc] [--port disc]
//                          [--osyms file] [--psyms file] [--seed rand|state|none]
//                          [--lasct] [--out dir] [--shots N]
//
// Each machine is booted with SHIFT+BREAK. At every entry to TT100 (the start
// of the main flight loop) we record a snapshot of the game state; at the first
// entry to TT170 (the game's entry point, which the loaders jump to via S%) we
// record the initial state. The two sequences are then compared.
//
// The game takes its random seed from whatever the loader leaves in RAND
// (&00-&03; the cassette loader sets RAND+1 from the VIA timer), and it also
// reads some workspace that nothing initialises (e.g. the stardust low bytes
// SXL/SYL/SZL), so by default (--seed rand,0300-0371,0d40-0f38) the original's
// RAND, T% block and WP workspace at TT170 are copied into the port at its
// TT170. --seed takes a comma-separated list of "rand" and hex ranges, or
// "state" (all snapshot regions) or "none".
//
// LASCT (laser pulse countdown) is decremented by the vertical sync interrupt,
// i.e. in real time, so it is an external input to the game logic: whenever
// the port's main loop runs at a different speed to the original, the laser
// pulse timing differs. --lasct makes the port read the same LASCT values as
// the original: every game instruction that reads LASCT (LDA LASCT) is hooked
// in both machines, the original's values are recorded in order and the port's
// LASCT is set to the next recorded value just before each of its reads.
//
// Speed: TT100 iterations per emulated second are reported per window of 200
// iterations for both machines.

import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "fs";
import { execSync } from "child_process";

// Symbol dump of the original demo (assembled from the reference source, which
// must have been built with its Makefile so the build options file exists)
function origSymbols() {
    const f = "/Users/ebenupton/elite/build/orig-symbols.txt";
    if (!existsSync(f)) execSync(`cd /Users/ebenupton/elite/ref/elite-demo-source-code-bbc-micro && /Users/ebenupton/elite/tools/beebasm -i 1-source-files/main-sources/elite-source.asm -d > ${f} 2>/dev/null`);
    return f;
}

const args = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => {
    if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]);
    return acc;
}, []));
const ROOT = "/Users/ebenupton/elite";
const FRAMES = +(args.frames || 3000);
const ORIG_DISC = args.orig || `${ROOT}/ref/elite-demo-source-code-bbc-micro/5-compiled-game-discs/elite-demonstration-disc.ssd`;
const PORT_DISC = args.port || `${ROOT}/build/elite-master.ssd`;
const OSYMS = args.osyms || origSymbols();
const PSYMS = args.psyms || `${ROOT}/build/symbols.txt`;
const SEED = args.seed || "rand,0300-0371,0d40-0f38";
const LASCT_INJECT = !!args.lasct;
const OUT = args.out || `${ROOT}/scratch/port/compare`;
const SHOTS = +(args.shots || 0);
const MAXSECS = +(args.maxsecs || 900);
mkdirSync(OUT, { recursive: true });

// Parse a beebasm -d symbol dump (Python dict syntax, possibly several dicts)
function loadSyms(path) {
    const txt = readFileSync(path, "utf8");
    const syms = {};
    for (const m of txt.matchAll(/'([^']+)':(\d+)L?/g)) syms[m[1]] = +m[2];
    return syms;
}
const osyms = loadSyms(OSYMS), psyms = loadSyms(PSYMS);
const byAddr = {};
for (const [k, v] of Object.entries(psyms)) if (v < 0x1000 && !(v in byAddr)) byAddr[v] = k;
function symName(a) {
    let best = null;
    for (let b = a; b >= Math.max(0, a - 40); b--) if (byAddr[b] !== undefined) { best = b; break; }
    if (best === null) return `&${a.toString(16)}`;
    return best === a ? byAddr[best] : `${byAddr[best]}+${a - best}`;
}

// Game state regions (addresses are the same in both builds)
const REGIONS = [
    [0x0000, 0xe2],   // zero page (RAND, INWK, flight variables, temporaries)
    [0x0300, 0x72],   // T% commander
    [0x0900, 0x1b0],  // K% ship slots
    [0x0ab0, 0x290],  // ship line heaps (XX19), growing down from WP
    [0x0d40, 0x1f9],  // WP workspace
    [0x0f48, 0x09],   // S% configuration variables (COMC..JSTK)
];
const SNAPLEN = REGIONS.reduce((a, r) => a + r[1], 0);
function offsetToAddr(o) {
    for (const [a, n] of REGIONS) { if (o < n) return a + o; o -= n; }
    return -1;
}

// Addresses excluded from the "pure game state" comparison: zero page
// temporaries and screen pointers that the drawing routines legitimately use
// differently, and the IRQ's line counter. Filled in from the per-address diff
// report (see the report for the reasons).
const EXCLUDE = new Set();
function excl(name, len = 1) { const a = psyms[name]; if (a === undefined) throw new Error(name); for (let i = 0; i < len; i++) EXCLUDE.add(a + i); }
for (const n of ["SC", "SCH", "T1", "DL"]) excl(n);
excl("TRTB%", 2);
excl("P", 3); excl("Q"); excl("R"); excl("S"); excl("T"); excl("SWAP"); excl("COL");
excl("XX15", 6); excl("XX12", 6); excl("K", 4); excl("YSAV"); excl("XSAV");
excl("K3", 14); excl("K4", 2); excl("XX16", 18); excl("K5", 4); excl("K6", 5);
excl("XSAV2"); excl("YSAV2"); excl("U"); excl("XX13"); excl("CNT"); excl("CNT2"); excl("STP");
excl("XX4"); excl("XX20"); excl("XX14"); excl("XX17"); excl("ZZ"); excl("V", 2); excl("XX", 2); excl("YY", 2);
excl("Y1"); excl("X1"); excl("Y2"); excl("X2");
excl("K2", 4); excl("XX0", 2); excl("XX18", 4);
excl("XC"); excl("YC"); excl("QQ17");   // text cursor: printing is identical, but see report
excl("LSO", 192); excl("LSX2", 78); excl("LSY2", 78);  // sun and planet line heaps
for (let a = 0x0ab0; a < 0x0d40; a++) EXCLUDE.add(a);    // ship line heaps
excl("COMX"); excl("COMY"); excl("COMC");                 // compass dot position (display)
for (let a = 0xb0; a < 0xd1; a++) EXCLUDE.add(a);         // zero page &B0-&D0 is not used by the game
if (LASCT_INJECT) excl("LASCT");
excl("LSP");                                              // ball line heap pointer (drawing only)                          // real-time input, injected at each read

async function makeMachine(model, disc) {
    const s = new MachineSession(model);
    await s.initialise();
    await s.boot(30);
    s.loadDisc(disc);
    s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
    return s;
}

function emuSecs(cpu) { return cpu.cycleSeconds + cpu.currentCycles / 2e6; }

// Find the addresses of game instructions that read LASCT (LDA LASCT, &AD lo hi)
// in the game code, excluding the IRQ handler
function findLasctReads(s, lo, hi, lasct, irqLo, irqHi) {
    const mem = s.readMemory(lo, hi - lo);
    const res = [];
    for (let i = 0; i < mem.length - 2; i++) {
        const a = lo + i;
        if (mem[i] === 0xad && mem[i + 1] === (lasct & 255) && mem[i + 2] === (lasct >> 8) && !(a >= irqLo && a < irqHi)) res.push(a);
    }
    return res;
}

async function run(label, model, disc, syms, opts) {
    const s = await makeMachine(model, disc);
    const cpu = s._machine.processor;
    const tt100 = syms.TT100, tt170 = syms.TT170;
    const snaps = [], times = [];
    let init = null, started = false, done = false;
    const lasctLog = opts.lasctLog || null;
    let lasctPtr = 0, lasctReads = new Set();
    const trace = [];
    const labelAt = {};
    if (opts.traceIter !== undefined) for (const [k, v] of Object.entries(syms)) if (v >= 0x0f40 && !(v in labelAt)) labelAt[v] = k;
    // Optional cycle profile by routine between two TT100 iterations
    const prof = {}, PF = args.profile ? String(args.profile).split("-").map(Number) : null;
    let lookup = null, lastCyc = 0, lastPc = 0;
    if (PF) {
        const names = new Set();
        for (const m of readFileSync(opts.src, "latin1").matchAll(/^\\       Name: (\S+)/gm)) names.add(m[1]);
        const st = Object.entries(syms).filter(([k, v]) => names.has(k) && v >= 0x0f40).sort((a, b) => a[1] - b[1]);
        lookup = new Array(65536).fill(null);
        for (let i = 0; i < st.length; i++) {
            const end = i + 1 < st.length ? st[i + 1][1] : (st[i][1] < 0x8000 ? 0x8000 : 0xc000);
            for (let a = st[i][1]; a < Math.min(end, 0x10000); a++) lookup[a] = st[i][0];
        }
    }
    // --fine: port profile by every label, bank-aware (bank 4/5/6/7 label sets from their source files)
    let fineTabs = null;
    if (PF && args.fine && model === "Master") {
        const labelsIn = f => new Set([...readFileSync(f, "latin1").matchAll(/^\.\^?([A-Za-z_][A-Za-z0-9_%]*)/gm)].map(m => m[1]));
        const SRC = decodeURIComponent(new URL("..", import.meta.url).pathname);
        const b5 = labelsIn(`${SRC}/src/raster.asm`), b7 = labelsIn(`${SRC}/src/raster7.asm`);
        const b6 = new Set([...labelsIn(`${SRC}/src/frame.asm`), ...labelsIn(`${SRC}/src/faces.asm`)]);
        fineTabs = { 4: [], 5: [], 6: [], 7: [], main: [] };
        for (const [k, v] of Object.entries(syms)) {
            if (v < 0x0f40) continue;
            if (v >= 0x8000 && v < 0xc000) fineTabs[b5.has(k) ? 5 : b6.has(k) ? 6 : b7.has(k) ? 7 : 4].push([v, k]);
            else fineTabs.main.push([v, k]);
        }
        for (const t of Object.values(fineTabs)) t.sort((x, y) => x[0] - y[0]);
    }
    const look = (t, pc) => { let lo = 0, hi = t.length - 1, r = null; while (lo <= hi) { const m = (lo + hi) >> 1; if (t[m][0] <= pc) { r = t[m][1]; lo = m + 1; } else hi = m - 1; } return r; };
    const fineBucket = pc => {
        if (pc >= 0xe000) return "MOS";
        if (pc >= 0xc000) return "HZ:" + (look(fineTabs.main, pc) || "?");
        if (pc >= 0x8000) { const b = cpu.romsel & 15; return `b${b}:` + (look(fineTabs[b] || [], pc) || "?"); }
        return pc < 0x0f40 ? "low" : (look(fineTabs.main, pc) || "?");
    };
    const bucket = fineTabs ? fineBucket : pc => pc >= 0xc000 ? "MOS" : (model !== "Master" && pc >= 0x8000) ? "ROM" : pc < 0x0f40 ? "low" : (lookup[pc] || "?");
    const cyc = () => cpu.cycleSeconds * 2e6 + cpu.currentCycles;
    const handler = pc => {
        if (PF && snaps.length >= PF[0] && snaps.length < PF[1]) {
            const now = cyc();
            if (lastCyc) { const b = bucket(lastPc); prof[b] = (prof[b] || 0) + now - lastCyc; }
            lastCyc = now; lastPc = pc;
        }
        if (opts.traceIter !== undefined && snaps.length === opts.traceIter + 1 && labelAt[pc] !== undefined && trace.length < 200000)
            trace.push(labelAt[pc] + " A=" + cpu.a.toString(16) + " RAND=" + s.readMemory(0, 4).map(x => x.toString(16)).join(",") + " Q=" + s.readMemory(0x90, 1)[0].toString(16) + " P=" + s.readMemory(0x1b, 3).map(x => x.toString(16)).join(",") + " C=" + (cpu.p.c ? 1 : 0));
        if (args.dtrace && started && snaps.length === +args.dtrace && pc === syms.DORND && trace.length < 400000) {
            const sp = cpu.s, ret = (s.readMemory(0x101 + sp, 1)[0] | (s.readMemory(0x102 + sp, 1)[0] << 8)) - 2;
            let best = null; for (const [k, v] of Object.entries(syms)) if (v <= ret && v >= 0x0f40 && (!best || v > best[1]) && (ret < 0x8000) === (v < 0x8000)) best = [k, v];
            trace.push((best ? best[0] + "+" + (ret - best[1]) : ret.toString(16)) + " RAND=" + s.readMemory(0, 4).map(x => x.toString(16)).join(","));
        }
        if (pc === tt170 && !started) {
            started = true;
            init = Buffer.from(snapshot(s));
            if (opts.onStart) opts.onStart(s);
            if (lasctLog || opts.recordLasct) {
                lasctReads = new Set(findLasctReads(s, 0x0f40, 0x5800, syms.LASCT, syms.LINSCN, syms.AttackTarget || syms.TACTICS));
                if (opts.bankReads) for (const a of findLasctReads(s, 0x8000, 0xc000, syms.LASCT, -1, -1)) lasctReads.add(a);
            }
            return false;
        }
        if (started && lasctReads.has(pc)) {
            if (opts.recordLasct) opts.recordLasct.push(s.readMemory(syms.LASCT, 1)[0]);
            else if (lasctLog) {
                if (lasctPtr < lasctLog.length) s.writeMemory(syms.LASCT, [lasctLog[lasctPtr]]);
                lasctPtr++;
            }
        }
        if (pc === tt100 && started && !done) {
            snaps.push(Buffer.from(snapshot(s)));
            times.push(emuSecs(cpu));
            if (snaps.length >= FRAMES) { done = true; return true; }
        }
        return false;
    };
    if (args.watch) {
        const wa = parseInt(args.watch, 16);
        cpu.debugWrite.add((addr, val) => {
            if (addr === wa && opts.traceIter !== undefined && snaps.length === opts.traceIter + 1) {
                let best = null; for (const [k, v] of Object.entries(syms)) if (v <= cpu.pc && v >= 0x0f40 && (!best || v > best[1])) best = [k, v];
                trace.push(`WRITE ${args.watch}=${val.toString(16)} at ${cpu.pc.toString(16)} ${best ? best[0] + "+" + (cpu.pc - best[1]) : ""}`);
            }
            return false;
        });
    }
    cpu.debugInstruction.add(handler);
    const t0 = Date.now();
    let lastShot = 0;
    while (!done && emuSecs(cpu) < MAXSECS) {
        // jsbeeb doesn't call the instruction hook for the first instruction
        // of each execute() call, so call it ourselves
        for (let k = 0; k < 40 && !done; k++) { handler(cpu.pc); cpu.execute(50000); }
        if (SHOTS && snaps.length > 0 && snaps.length >= lastShot + SHOTS) {
            lastShot = snaps.length;
            writeFileSync(`${OUT}/${label}-${String(snaps.length).padStart(5, "0")}.png`, await s.screenshotActive({ scale: 1 }));
        }
    }
    console.log(`${label}: ${snaps.length} TT100 snapshots, emulated ${emuSecs(cpu).toFixed(1)} s, wall ${((Date.now() - t0) / 1000).toFixed(1)} s, LASCT reads hooked ${lasctReads.size}`);
    return { s, snaps, times, init, lasctPtr, trace, prof };
}

function snapshot(s) {
    const out = [];
    for (const [a, n] of REGIONS) out.push(...s.readMemory(a, n));
    return out;
}

// --- Run the original -------------------------------------------------------
const lasctRec = [];
const orig = await run("orig", "B-DFS1.2", ORIG_DISC, osyms, { src: `${ROOT}/src/orig/elite-source.asm`, recordLasct: LASCT_INJECT ? lasctRec : null, traceIter: args.trace !== undefined ? +args.trace : undefined });

// --- Run the port, seeded from the original's initial state -----------------
const TRACE = args.trace !== undefined ? +args.trace : undefined;
const port = await run("port", "Master", PORT_DISC, psyms, {
    traceIter: TRACE,
    src: `${ROOT}/src/elite-source.asm`,
    lasctLog: LASCT_INJECT ? lasctRec : null,
    bankReads: true,
    onStart: s => {
        if (SEED === "none") return;
        if (SEED.split(",").includes("rand")) s.writeMemory(0, [...orig.init.subarray(0, 4)]);
        if (SEED !== "state") {
            // comma-separated list of "rand" or hex ranges "aaaa-bbbb" (inclusive)
            for (const tok of SEED.split(",")) {
                if (tok === "rand") continue;
                const [lo, hi] = tok.split("-").map(x => parseInt(x, 16));
                for (let a = lo; a <= hi; a++) { const v = valAt(orig.init, a); if (v >= 0) s.writeMemory(a, [v]); }
            }
        }
        if (SEED === "state") {
            let o = 0;
            for (const [a, n] of REGIONS) { s.writeMemory(a, [...orig.init.subarray(o, o + n)]); o += n; }
        }
    },
});

// --- Optional control-flow trace of one iteration ---------------------------
if (args.dtrace) {
    writeFileSync(`${OUT}/dtrace-orig.txt`, orig.trace.join("\n"));
    writeFileSync(`${OUT}/dtrace-port.txt`, port.trace.join("\n"));
}
if (TRACE !== undefined) {
    const a = orig.trace, b = port.trace;
    writeFileSync(`${OUT}/trace-orig.txt`, a.join("\n"));
    writeFileSync(`${OUT}/trace-port.txt`, b.join("\n"));
    let i = 0;
    while (i < a.length && i < b.length && a[i] === b[i]) i++;
    console.log(`Trace of iteration ${TRACE}: orig ${a.length} labels, port ${b.length}; first mismatch at ${i}`);
    for (let j = Math.max(0, i - 15); j < i + 10; j++) console.log(`  ${j}: ${a[j] || "-"}    |    ${b[j] || "-"}`);
}

// --- Compare ----------------------------------------------------------------
const n = Math.min(orig.snaps.length, port.snaps.length);
const report = [];
const log = (...x) => { const l = x.join(" "); console.log(l); report.push(l); };
log(`Compared ${n} TT100 iterations (orig ${orig.snaps.length}, port ${port.snaps.length}); seed=${SEED} lasct=${LASCT_INJECT}`);
if (LASCT_INJECT) log(`LASCT values recorded in original: ${lasctRec.length}, consumed by port: ${port.lasctPtr}`);

function diffs(a, b, excludeSet) {
    const d = [];
    for (let o = 0; o < SNAPLEN; o++) if (a[o] !== b[o]) { const ad = offsetToAddr(o); if (!excludeSet || !excludeSet.has(ad)) d.push(ad); }
    return d;
}
const fmt = (ad, a, b) => `${symName(ad)}(&${ad.toString(16)}): orig &${a.toString(16)} port &${b.toString(16)}`;
function valAt(buf, ad) { let o = 0; for (const [a, nn] of REGIONS) { if (ad >= a && ad < a + nn) return buf[o + ad - a]; o += nn; } return -1; }

// Initial state at TT170 (after seeding the port's RAND)
{
    const d0 = diffs(orig.init, port.init, EXCLUDE);
    log(`Initial state at TT170: ${d0.length} differing game-state bytes (before seeding): ` + d0.map(a => symName(a)).join(" "));
}

let firstDiv = -1, firstAll = -1;
const perAddr = {};
for (let i = 0; i < n; i++) {
    const dAll = diffs(orig.snaps[i], port.snaps[i], null);
    for (const ad of dAll) perAddr[ad] = (perAddr[ad] || 0) + 1;
    if (dAll.length && firstAll < 0) firstAll = i;
    const d = dAll.filter(ad => !EXCLUDE.has(ad));
    if (d.length && firstDiv < 0) {
        firstDiv = i;
        log(`FIRST DIVERGENCE of game state at TT100 iteration ${i} (orig t=${orig.times[i].toFixed(2)} s, port t=${port.times[i].toFixed(2)} s):`);
        for (const ad of d.slice(0, 200)) log("  " + fmt(ad, valAt(orig.snaps[i], ad), valAt(port.snaps[i], ad)));
    }
}
if (firstDiv < 0) log(`Game state identical at all ${n} TT100 iterations`);
log(`First iteration with any difference (including excluded temporaries/heaps): ${firstAll}`);
log("Per-address count of iterations that differ (all addresses, excluded marked *):");
for (const [ad, c] of Object.entries(perAddr).sort((a, b) => b[1] - a[1]).slice(0, 80)) log(`  ${EXCLUDE.has(+ad) ? "*" : " "} ${symName(+ad)} (&${(+ad).toString(16)}): ${c}`);

// Speed
log("Speed (TT100 iterations per emulated second):");
log("  window        orig     port");
for (let w = 0; w + 200 <= n; w += 200) {
    const ro = 200 / (orig.times[w + 199] - orig.times[w]) * (199 / 200);
    const rp = 200 / (port.times[w + 199] - port.times[w]) * (199 / 200);
    log(`  ${String(w).padStart(5)}-${String(w + 199).padStart(5)}  ${ro.toFixed(2).padStart(6)}   ${rp.toFixed(2).padStart(6)}`);
}
const tot = (r) => (n - 1) / (r.times[n - 1] - r.times[0]);
log(`  all ${n}       ${tot(orig).toFixed(2).padStart(6)}   ${tot(port).toFixed(2).padStart(6)}`);
log(`  first TT100 at emulated t: orig ${orig.times[0]?.toFixed(1)} s, port ${port.times[0]?.toFixed(1)} s`);
if (args.profile) {
    log(`Cycle profile for TT100 iterations ${args.profile} (cycles per iteration):`);
    const keys = new Set([...Object.keys(orig.prof), ...Object.keys(port.prof)]);
    const [a, b] = String(args.profile).split("-").map(Number);
    const tot = p => Object.values(p).reduce((x, y) => x + y, 0);
    log(`  ${"TOTAL".padEnd(20)} ${(tot(orig.prof) / (b - a)).toFixed(0).padStart(8)} ${(tot(port.prof) / (b - a)).toFixed(0).padStart(8)}`);
    for (const k of [...keys].sort((x, y) => Math.max(port.prof[y] || 0, orig.prof[y] || 0) - Math.max(port.prof[x] || 0, orig.prof[x] || 0)).slice(0, 60))
        log(`  ${k.padEnd(20)} ${((orig.prof[k] || 0) / (b - a)).toFixed(0).padStart(8)} ${((port.prof[k] || 0) / (b - a)).toFixed(0).padStart(8)} ${(((port.prof[k] || 0) - (orig.prof[k] || 0)) / (b - a)).toFixed(0).padStart(8)}`);
}
if (args.profile) writeFileSync(`${OUT}/prof.json`, JSON.stringify({ orig: orig.prof, port: port.prof, n: (([a, b]) => b - a)(String(args.profile).split("-").map(Number)) }));
writeFileSync(`${OUT}/report.txt`, report.join("\n") + "\n");
process.exit(0);
