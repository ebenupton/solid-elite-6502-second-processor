// Determinism and speed comparison for BBC Master Elite: a reference build
// against a candidate build, both on the emulated BBC Master, both driven by the
// same deterministic pilot (harness/mpilot.mjs) through harness/mlib.mjs's input
// injection.
//
// node harness/mcompare.mjs [--iters 5000] [--ref disc] [--rsyms file]
//                           [--cand disc] [--csyms file] [--seed rand|none]
//                           [--loose] [--window 200] [--out dir] [--shots N]
//                           [--maxsecs S] [--nopatch]
//
// Defaults: reference = master/reference/elite-master-sng47.ssd (the released
// SNG47 disc) with master/reference/symbols.txt (the symbols of the pristine
// in-tree build, which is bit-identical to it: see master/build.sh); candidate =
// master/build/elite-master-sng47.ssd with master/build/symbols.txt.
//
// An iteration is one pass of the main loop, counted at MLOOP (so docked
// iterations count too; the flight loop proper, TT100 to MLOOP, runs only in
// space). At every MLOOP the game state (mlib.regionsFor: zero page, K% ship
// slots and line heap, WP: FRIN, flight variables, stardust, the commander
// NAME..SVC, JOPOS; UP: configuration; NA%: the last saved commander; the sound
// buffers) is recorded and the two runs are compared iteration by iteration.
// Addresses that depend on real time are excluded (mlib.TIMING_EXCLUDE: DL, the
// IRQ's vsync flag; JOPOS, the IRQ's ADC values; the sound buffers, counted down
// by the IRQ). --loose also excludes drawing temporaries and line heaps
// (mlib.DRAW_EXCLUDE), for candidates whose drawing differs. The first
// divergence is reported with symbol names, then per-address counts.
//
// --seed rand (default) copies the reference's RAND (&02-&05) at TT170 into the
// candidate at its TT170, as the loader leaves it (it is identical for the same
// loader, so this matters only when the loader changes).
//
// Speed: flight-loop iterations (TT100 to TT100, only those with no docked
// iteration in between) per emulated second, per window of --window
// iterations, for both runs, with the pilot's phase mix for the window.
//
// Exit status 0 if the game state is identical at every compared iteration
// (and both runs completed); prints "MCOMPARE PASS <ref it/s> <cand it/s>" or
// "MCOMPARE FAIL <reason>".
import { runElite, loadSyms, regionsFor, excludeSet, TIMING_EXCLUDE, DRAW_EXCLUDE, ROOT } from "./mlib.mjs";
import { makePilot, patchCommander } from "./mpilot.mjs";
import { writeFileSync, mkdirSync } from "fs";

const args = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => {
    if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]);
    return acc;
}, []));
const ITERS = +(args.iters || 5000);
const REF = args.ref || `${ROOT}master/reference/elite-master-sng47.ssd`;
const RSYMS = args.rsyms || `${ROOT}master/reference/symbols.txt`;
const CAND = args.cand || `${ROOT}master/build/elite-master-sng47.ssd`;
const CSYMS = args.csyms || `${ROOT}master/build/symbols.txt`;
const SEED = args.seed || "rand";
const WINDOW = +(args.window || 200);
const OUT = args.out || `${ROOT}scratch/master/compare`;
const SHOTS = +(args.shots || 0);
mkdirSync(OUT, { recursive: true });

const rsy = loadSyms(RSYMS), csy = loadSyms(CSYMS);

async function run(label, disc, sy, seed) {
    const pilot = makePilot();
    const phases = [];
    const t0 = Date.now();
    const r = await runElite({
        disc, syms: sy, pilot, iters: ITERS, maxSecs: +(args.maxsecs || 4 * ITERS),
        patch: args.nopatch ? null : patchCommander, seed,
        onIter: () => phases.push(pilot.P.phase),
        shots: SHOTS, onShot: async (s, i) => writeFileSync(`${OUT}/${label}-${String(i).padStart(6, "0")}.png`, await s.screenshotActive({ scale: 1 })),
    });
    r.phases = phases; r.stats = pilot.P.stats; r.wall = (Date.now() - t0) / 1000;
    console.log(`${label}: ${r.iters} iterations (${r.tt100} in flight), emulated ${r.emuSecs.toFixed(1)} s, wall ${r.wall.toFixed(1)} s${r.error ? ", STOPPED: " + r.error : ""}`);
    return r;
}

const ref = await run("ref", REF, rsy, null);
const cand = await run("cand", CAND, csy, SEED === "rand" ? [[csy.RAND, [...ref.initRand]]] : null);

const report = [];
const log = (...x) => { const l = x.join(" "); console.log(l); report.push(l); };

// ---- Pilot coverage
function statLine(st) {
    return `launches ${st.launches}, dockings ${st.dockings}, hyperspace jumps ${st.jumps} (galactic ${st.galactic}), systems ${st.systems.size} [${[...st.systems].join(" ")}], ` +
        `engagements ${st.engagements}, ships destroyed ${st.kills} ${JSON.stringify(st.killTypes)}, missiles fired ${st.missiles}, ECM ${st.ecm}, deaths ${st.deaths}, ` +
        `trades: buy ${st.buys} sell ${st.sells} equip ${st.equips}, key waits ${st.waits}`;
}
log(`Iterations: ref ${ref.iters} (flight ${ref.tt100}), cand ${cand.iters} (flight ${cand.tt100}); seed=${SEED}${args.loose ? " loose" : ""}`);
log(`Pilot (ref):  ${statLine(ref.stats)}`);
log(`Pilot (cand): ${statLine(cand.stats)}`);

// ---- Compare
const rreg = ref.regions, creg = cand.regions;
let ok = true;
for (let k = 0; k < rreg.length; k++) if (rreg[k][1] !== creg[k][1] || rreg[k][2] !== creg[k][2]) { log(`region ${rreg[k][2]} differs in size: ref ${rreg[k][1]}, cand ${creg[k][1]}`); ok = false; }
const ex = excludeSet(rsy, args.loose ? [TIMING_EXCLUDE, DRAW_EXCLUDE] : [TIMING_EXCLUDE]);
// offset -> ref address
const offAddr = [];
for (const [a, n] of rreg) for (let i = 0; i < n; i++) offAddr.push(a + i);
const byAddr = {};
for (const [k, v] of Object.entries(rsy)) if (v < 0x8000 && !(v in byAddr)) byAddr[v] = k;
function symName(a) {
    for (let b = a; b >= Math.max(0, a - 64); b--) if (byAddr[b] !== undefined) return b === a ? byAddr[b] : `${byAddr[b]}+${a - b}`;
    return `&${a.toString(16)}`;
}
const n = Math.min(ref.snaps.length, cand.snaps.length);
let firstDiv = -1, firstAny = -1, printed = false;
const perAddr = {};
if (ok) {
    const ri = ref.init, ci = cand.init;
    const d0 = [];
    for (let o = 0; o < ri.length; o++) if (ri[o] !== ci[o] && !ex.has(offAddr[o])) d0.push(symName(offAddr[o]));
    log(`State at TT170 (after seeding): ${d0.length} differing bytes${d0.length ? ": " + d0.slice(0, 40).join(" ") : ""}`);
    for (let i = 0; i < n; i++) {
        const a = ref.snaps[i], b = cand.snaps[i];
        for (let o = 0; o < a.length; o++) if (a[o] !== b[o]) {
            const ad = offAddr[o];
            perAddr[ad] = (perAddr[ad] || 0) + 1;
            if (firstAny < 0) firstAny = i;
            if (!ex.has(ad) && firstDiv !== i && firstDiv < 0) firstDiv = i;
        }
        if (firstDiv === i && !printed) {
            printed = true;
            log(`FIRST DIVERGENCE of game state at iteration ${i} (phase ${ref.phases[i]}, ref t=${ref.iterTimes[i].toFixed(2)} s, cand t=${cand.iterTimes[i].toFixed(2)} s):`);
            let shown = 0;
            for (let o = 0; o < a.length && shown < 100; o++) if (a[o] !== b[o] && !ex.has(offAddr[o])) { log(`  ${symName(offAddr[o])} (&${offAddr[o].toString(16)}): ref &${a[o].toString(16)} cand &${b[o].toString(16)}`); shown++; }
            const kr = ref.keyLog.filter(k => k[0] >= i - 3 && k[0] <= i), kc = cand.keyLog.filter(k => k[0] >= i - 3 && k[0] <= i);
            log(`  keys (ref) ${JSON.stringify(kr)}`);
            log(`  keys (cand) ${JSON.stringify(kc)}`);
        }
    }
}
const complete = ref.iters === ITERS && cand.iters === ITERS && !ref.error && !cand.error;
if (ok && firstDiv < 0) log(`Game state identical at all ${n} iterations${complete ? "" : " (INCOMPLETE run)"}`);
log(`First iteration with any difference (including excluded addresses): ${firstAny}`);
const pa = Object.entries(perAddr).sort((x, y) => y[1] - x[1]).slice(0, 40);
if (pa.length) {
    log("Per-address count of differing iterations (* = excluded):");
    for (const [ad, c] of pa) log(`  ${ex.has(+ad) ? "*" : " "} ${symName(+ad)} (&${(+ad).toString(16)}): ${c}${ex.has(+ad) ? "  [" + ex.get(+ad) + "]" : ""}`);
}

// ---- Speed
// flight iterations: consecutive TT100 entries one MLOOP iteration apart
function flightRates(r) {
    const dts = [];   // [iteration, dt]
    const t = r.tt100Times;
    for (let k = 1; k < t.length; k++) if (t[k][1] === t[k - 1][1] + 1) dts.push([t[k][1], t[k][0] - t[k - 1][0]]);
    return dts;
}
function windows(r) {
    const out = [];
    const dts = flightRates(r);
    for (let w = 0; w < ITERS; w += WINDOW) {
        const ds = dts.filter(([i]) => i >= w && i < w + WINDOW);
        const sum = ds.reduce((a, [, d]) => a + d, 0);
        out.push({ w, n: ds.length, rate: ds.length ? ds.length / sum : NaN });
    }
    const all = dts.reduce((a, [, d]) => a + d, 0);
    return { win: out, all: dts.length / all, n: dts.length };
}
const rs = windows(ref), cs = windows(cand);
function phaseMix(w) {
    const c = {};
    for (let i = w; i < Math.min(w + WINDOW, ref.phases.length); i++) c[ref.phases[i]] = (c[ref.phases[i]] || 0) + 1;
    return Object.entries(c).sort((a, b) => b[1] - a[1]).map(([p, k]) => `${p} ${k}`).join(", ");
}
log(`Speed: flight iterations per emulated second, per window of ${WINDOW} iterations`);
log(`  window          flight    ref     cand   cand/ref  phases (ref)`);
for (let k = 0; k < rs.win.length; k++) {
    const a = rs.win[k], b = cs.win[k] || { rate: NaN };
    log(`  ${String(a.w).padStart(5)}-${String(Math.min(a.w + WINDOW, ITERS) - 1).padStart(5)}   ${String(a.n).padStart(5)}  ${a.rate.toFixed(2).padStart(6)}  ${b.rate.toFixed(2).padStart(6)}   ${(b.rate / a.rate).toFixed(3).padStart(6)}   ${phaseMix(a.w)}`);
}
log(`  all              ${String(rs.n).padStart(5)}  ${rs.all.toFixed(2).padStart(6)}  ${cs.all.toFixed(2).padStart(6)}   ${(cs.all / rs.all).toFixed(3).padStart(6)}`);
// by the pilot's phase at the iteration
{
    const byPhase = r => { const o = {}; for (const [i, d] of flightRates(r)) { const p = ref.phases[i] || "?"; (o[p] ||= [0, 0]); o[p][0]++; o[p][1] += d; } return o; };
    const pr = byPhase(ref), pc = byPhase(cand);
    log(`Speed by pilot phase (flight it/s): phase, iterations, ref, cand, cand/ref`);
    for (const [p, [k, d]] of Object.entries(pr)) { const c = pc[p] || [0, 1]; log(`  ${p.padEnd(9)} ${String(k).padStart(6)}  ${(k / d).toFixed(2).padStart(6)}  ${(c[0] / c[1]).toFixed(2).padStart(6)}   ${((c[0] / c[1]) / (k / d)).toFixed(3)}`); }
}
log(`  emulated time to iteration ${n - 1}: ref ${ref.iterTimes[n - 1]?.toFixed(1)} s, cand ${cand.iterTimes[n - 1]?.toFixed(1)} s`);
writeFileSync(`${OUT}/report.txt`, report.join("\n") + "\n");
writeFileSync(`${OUT}/keys-ref.txt`, ref.keyLog.map(k => k.join(" ")).join("\n") + "\n");
writeFileSync(`${OUT}/keys-cand.txt`, cand.keyLog.map(k => k.join(" ")).join("\n") + "\n");
if (ok && firstDiv < 0 && complete) { log(`MCOMPARE PASS ${rs.all.toFixed(2)} ${cs.all.toFixed(2)}`); process.exit(0); }
log(`MCOMPARE FAIL ${!ok ? "regions" : firstDiv >= 0 ? "divergence at " + firstDiv : "incomplete"}`);
process.exit(1);
