// Cycle profile of full Master Elite per (mapping, PC), for weighting the grind's
// windows, over exactly the run the gate (master/verify.sh) times.
//
// node master/tools/grind/profile.mjs [--root <tree>] [--disc d] [--syms s]
//                                     [--iters 10000] [--seed boot|none]
//                                     [--out <tree>/scratch/grind/profile.json]
//
// The run: harness/mlib.mjs runElite with harness/mpilot.mjs's pilot and its commander
// patch, the candidate's boot leftovers seeded from the reference disc at TT170 exactly
// as harness/mcompare.mjs --seed boot does (the reference is booted to its first MLOOP
// for that), --iters MLOOP iterations (the gate's 10000) -- so the same pilot, seeds and
// trajectory as master/verify.sh 10000.  (Defaults: <tree>'s master/build disc and
// symbols, <tree> = the tree this script is in; the harness is <tree>'s.)
//
// Attribution (as tools/grind/profile.mjs, from harness/prof.mjs): the cycles between
// two consecutive instruction hooks go to the earlier PC (its own cycles, plus an
// interrupt entry that followed it), keyed by what was mapped there:
//   M:<pc>  main RAM (&0000-&7FFF)       A:<pc>   ANDY (&8000-&8FFF, ROMSEL bit 7)
//   B<n>:<pc> sideways RAM bank n (4-7)  HZ:<pc>  HAZEL (&C000-&DFFF, ACCCON Y)
//   MOS:<pc>  the MOS (&C000- without Y, &E000-) and any other paged ROM (DFS ...)
//
// Scenarios, as the gate's speed figure (mcompare.mjs flightRates) counts:
//   "flight"   the flight iterations: TT100 to the next TT100 when exactly one MLOOP
//              iteration lies between them; iterations = their number, so
//              cycles_per_iteration = 2e6 / (the gate's "all" it/s for this build)
//   "phase:<p>" the same split by the pilot's phase at the closing TT100 (approach:
//              the station approach with the big planet, combat, hyper: the hyperspace
//              countdown and the jump, escape, ...)
//   "other"    every other cycle from the first MLOOP on (docked screens, title,
//              launch, death); iterations = MLOOP iterations that are not flight ones
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "fs";
import { dirname, resolve } from "path";
import { fileURLToPath } from "url";

const args = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => {
    if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]);
    return acc;
}, []));
const HERE = dirname(fileURLToPath(import.meta.url));
const TREE = resolve(args.root || `${HERE}/../../..`);
const DISC = resolve(args.disc || `${TREE}/master/build/elite-master-sng47.ssd`);
const SYMS = resolve(args.syms || `${TREE}/master/build/symbols.txt`);
const REF = `${TREE}/master/reference/elite-master-sng47.ssd`, RSYMS = `${TREE}/master/reference/symbols.txt`;
const OUT = resolve(args.out || `${TREE}/scratch/grind/profile.json`);
const ITERS = +(args.iters || 10000);
const SEED = args.seed || "boot";
for (const f of [DISC, SYMS]) if (!existsSync(f)) throw new Error(`${f} missing (build first)`);

const { runElite, loadSyms } = await import(`${TREE}/harness/mlib.mjs`);
const { makePilot, patchCommander } = await import(`${TREE}/harness/mpilot.mjs`);
const sy = loadSyms(SYMS);
const t0 = Date.now();

// ---- the boot leftovers (mcompare.mjs --seed boot): the reference's state at TT170
let seedBoot = null;
if (SEED === "boot") {
    const rsy = loadSyms(RSYMS);
    const ref = await runElite({ disc: REF, syms: rsy, pilot: makePilot(), iters: 1, maxSecs: 200, patch: patchCommander });
    if (!ref.init) throw new Error("reference run did not reach TT170");
    seedBoot = (cregions, written, rb) => {
        const out = [];
        let o = 0;
        for (const [ra, n, name] of ref.regions) {
            const c = cregions.find(r => r[2] === name);
            if (c && c[1] === n) for (let i = 0; i < n; i++) if (!written.has(c[0] + i) && rb(c[0] + i) !== ref.init[o + i]) out.push([c[0] + i, [ref.init[o + i]]]);
            o += n;
        }
        return out;
    };
    console.log(`reference booted to TT170 for the seed (${((Date.now() - t0) / 1000).toFixed(1)} s)`);
}

// ---- the profile
const MAPS = ["M", "A", "B4", "B5", "B6", "B7", "HZ", "MOS"];
const NM = MAPS.length, SZ = NM * 65536;
const mk = () => ({ iterations: 0, total_cycles: 0, c: new Float64Array(SZ) });
const scen = { flight: mk(), other: mk() };
const cur = new Float64Array(SZ), stamp = new Uint32Array(SZ);
let touched = [], gen = 1, curTotal = 0;
const pilot = makePilot();
let cpu = null, installed = false, on = false, last = 0, lastIdx = -1;
let myIter = 0, prevTT = -1, sw = null;
const cyc = () => cpu.cycleSeconds * 2e6 + cpu.currentCycles;
const idxOf = pc => {
    if (pc < 0x8000) return pc;
    if (pc < 0xc000) {
        const r = cpu.romsel;
        if (pc < 0x9000 && (r & 0x80)) return 65536 + pc;
        const b = r & 15;
        return b >= 4 && b <= 7 ? (2 + b - 4) * 65536 + pc : 7 * 65536 + pc;
    }
    if (pc < 0xe000 && (cpu.acccon & 8)) return 6 * 65536 + pc;
    return 7 * 65536 + pc;
};
const close = dest => {
    const ds = [dest];
    for (const sc of ds) sc.total_cycles += curTotal;
    for (const k of touched) { const v = cur[k]; for (const sc of ds) sc.c[k] += v; cur[k] = 0; }
    touched = []; gen++; curTotal = 0;
};
const closeFlight = phase => {
    const ph = (scen["phase:" + phase] ||= mk());
    ph.iterations++; scen.flight.iterations++;
    ph.total_cycles += curTotal; scen.flight.total_cycles += curTotal;
    for (const k of touched) { const v = cur[k]; ph.c[k] += v; scen.flight.c[k] += v; cur[k] = 0; }
    touched = []; gen++; curTotal = 0;
};
const r = await runElite({
    disc: DISC, syms: sy, pilot, iters: ITERS, maxSecs: 4 * ITERS, patch: patchCommander, seedBoot,
    onIter: (i, s) => {
        myIter = i + 1;          // (mlib counts the MLOOP after this call)
        if (installed) return;
        installed = true; on = true;
        cpu = s._machine.processor;
        last = cyc();
        sw = sy.TT100;
        cpu.debugInstruction.add(pc => {
            const now = cyc();
            if (lastIdx >= 0) {
                const d = now - last;
                if (stamp[lastIdx] !== gen) { stamp[lastIdx] = gen; touched.push(lastIdx); }
                cur[lastIdx] += d; curTotal += d;
            }
            last = now;
            if (pc === sw && pc < 0x8000) {
                // a TT100 entry: close the interval since the previous one
                if (prevTT >= 0 && myIter === prevTT + 1) closeFlight(pilot.P.phase);
                else close(scen.other);
                prevTT = myIter;
            }
            lastIdx = idxOf(pc);
            return false;
        });
    },
});
close(scen.other);
scen.other.iterations = r.iters - scen.flight.iterations;
const out = { disc: DISC, syms: SYMS, iters: r.iters, tt100: r.tt100, seeded: r.seeded ? r.seeded.length : 0,
    error: r.error || null, emulated_secs: r.emuSecs, wall_secs: (Date.now() - t0) / 1000,
    pilot: { ...pilot.P.stats, systems: [...pilot.P.stats.systems] }, scenarios: {} };
for (const [n, sc] of Object.entries(scen)) {
    const pcs = [];
    for (let k = 0; k < SZ; k++) if (sc.c[k]) pcs.push([`${MAPS[k >> 16]}:${(k & 0xffff).toString(16)}`, Math.round(sc.c[k])]);
    pcs.sort((x, y) => y[1] - x[1]);
    out.scenarios[n] = { iterations: sc.iterations, total_cycles: sc.total_cycles,
        cycles_per_iteration: sc.iterations ? sc.total_cycles / sc.iterations : null,
        pcs: Object.fromEntries(pcs) };
    console.log(`${n}: ${sc.iterations} iterations, ${sc.total_cycles.toFixed(0)} cycles` +
        (sc.iterations ? `, ${(sc.total_cycles / sc.iterations).toFixed(0)} cycles/iteration` +
            (n === "other" ? "" : `, ${(2e6 * sc.iterations / sc.total_cycles).toFixed(2)} it/s`) : ""));
}
mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, JSON.stringify(out));
console.log(`-> ${OUT} (${r.iters} MLOOP iterations, ${r.tt100} TT100, emulated ${out.emulated_secs.toFixed(1)} s, wall ${out.wall_secs.toFixed(1)} s${r.error ? ", STOPPED: " + r.error : ""})`);
process.exit(r.error || r.iters !== ITERS ? 1 : 0);
