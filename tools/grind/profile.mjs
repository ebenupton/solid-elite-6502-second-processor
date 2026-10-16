// Cycle profile of the port per (bank, PC), for weighting the grind's windows.
// Adapted from harness/prof.mjs: runs the game headless in jsbeeb on the Master and
// attributes the cycles between consecutive instruction hooks to the earlier PC (so an
// instruction's own cycles, plus any interrupt entry that followed it).
//
// node tools/grind/profile.mjs [--disc build/elite-master.ssd] [--syms build/symbols.txt]
//                              [--windows 300-600,1000-1300] [--title 1]
//                              [--out scratch/grind/profile.json]
//
// Scenarios: "flight<a>-<b>": TT100 iterations a..b (cycles per iteration = the
// window's total / (b - a)); "title": from the first entry to TITLE to the first
// TT100 (the two rotating-ship title screens; per iteration = per pass of the title
// loop, label titl1 -- 255 passes a screen).
// Keys: "M:<pc>" main RAM (&0000-&7FFF), "B<n>:<pc>" sideways bank n (ROMSEL & 15),
// "HZ:<pc>" HAZEL (&C000-&DFFF), "MOS:<pc>" (&E000-), all PCs in hex.
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { dirname } from "path";

const args = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => {
    if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]);
    return acc;
}, []));
const ROOT = "/Users/ebenupton/elite";
const DISC = args.disc || `${ROOT}/build/elite-master.ssd`;
const SYMS = args.syms || `${ROOT}/build/symbols.txt`;
const OUT = args.out || `${ROOT}/scratch/grind/profile.json`;
const WINDOWS = String(args.windows || "300-600,1000-1300").split(",").map(w => w.split("-").map(Number));
const TITLE = args.title === undefined ? true : args.title !== "0";
const MAXSECS = +(args.maxsecs || 900);

const syms = {};
for (const m of readFileSync(SYMS, "latin1").matchAll(/'([^']+)':(\d+)L?/g)) syms[m[1]] = +m[2];
// TITLE and its loop may have moved to bank 7 (cold7.asm: TITLE_7, titl1_7)
const IN7 = syms.TITLE === undefined && syms.TITLE_7 !== undefined;
if (IN7) { syms.TITLE = syms.TITLE_7; syms.titl1 = syms.titl1_7; }
const TLOOP = syms.titl1 !== undefined ? "titl1" : "TLL2";
const bankOK = () => !IN7 || (s._machine.processor.romsel & 15) === 7;
for (const k of ["TT100", "TITLE", TLOOP]) if (syms[k] === undefined) throw new Error(`symbol ${k} not found in ${SYMS}`);

const s = new MachineSession("Master");
await s.initialise();
await s.boot(30);
s.loadDisc(DISC);
s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
const cpu = s._machine.processor;
const cyc = () => cpu.cycleSeconds * 2e6 + cpu.currentCycles;
const emuSecs = () => cpu.cycleSeconds + cpu.currentCycles / 2e6;

const scen = {};
const mk = name => (scen[name] = { iterations: 0, total_cycles: 0, pcs: new Map() });
const last = WINDOWS.reduce((m, w) => Math.max(m, w[1]), 0);
let it = 0, titleOn = false, titleSeen = false, done = false;
let lastPc = -1, lastKey = null, lastCyc = 0;
const active = [];       // scenarios currently recording
const keyOf = pc => {
    if (pc < 0x8000) return "M:" + pc.toString(16);
    if (pc < 0xc000) return "B" + (cpu.romsel & 15) + ":" + pc.toString(16);
    if (pc < 0xe000) return "HZ:" + pc.toString(16);
    return "MOS:" + pc.toString(16);
};
const handler = pc => {
    const now = cyc();
    if (lastKey !== null && active.length) {
        const d = now - lastCyc;
        for (const sc of active) { sc.pcs.set(lastKey, (sc.pcs.get(lastKey) || 0) + d); sc.total_cycles += d; }
    }
    lastCyc = now;
    if (pc === syms.TITLE && TITLE && !titleSeen && bankOK()) { titleSeen = titleOn = true; active.push(mk("title")); }
    if (pc === syms[TLOOP] && titleOn && bankOK()) scen.title.iterations++;
    if (pc === syms.TT100) {
        if (titleOn) { titleOn = false; active.splice(active.indexOf(scen.title), 1); }
        it++;
        for (const [a, b] of WINDOWS) {
            const n = `flight${a}-${b}`;
            if (it === a) active.push(mk(n));
            if (it === b && scen[n]) { active.splice(active.indexOf(scen[n]), 1); scen[n].iterations = b - a; }
        }
        if (it >= last) done = true;
    }
    lastKey = keyOf(pc);
    return false;
};
cpu.debugInstruction.add(handler);
const t0 = Date.now();
while (!done && emuSecs() < MAXSECS) for (let k = 0; k < 40 && !done; k++) { handler(cpu.pc); cpu.execute(50000); }
const out = { disc: DISC, syms: SYMS, emulated_secs: emuSecs(), wall_secs: (Date.now() - t0) / 1000, scenarios: {} };
for (const [n, sc] of Object.entries(scen)) {
    out.scenarios[n] = { iterations: sc.iterations, total_cycles: sc.total_cycles,
        cycles_per_iteration: sc.iterations ? sc.total_cycles / sc.iterations : null,
        pcs: Object.fromEntries([...sc.pcs.entries()].sort((x, y) => y[1] - x[1])) };
    console.log(`${n}: ${sc.iterations} iterations, ${sc.total_cycles} cycles` +
        (sc.iterations ? `, ${(sc.total_cycles / sc.iterations).toFixed(0)} cycles/iteration, ${(2e6 * sc.iterations / sc.total_cycles).toFixed(2)} it/s` : ""));
}
mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, JSON.stringify(out));
console.log(`-> ${OUT} (emulated ${out.emulated_secs.toFixed(1)} s, wall ${out.wall_secs.toFixed(1)} s)`);
process.exit(0);
