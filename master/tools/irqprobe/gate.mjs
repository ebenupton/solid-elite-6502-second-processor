// The split probe over the gate's run: harness/mlib.mjs runElite with mpilot's pilot,
// commander patch and boot seed, exactly as master/tools/grind/profile.mjs (and so
// master/verify.sh) fly it.
//
// node master/tools/irqprobe/gate.mjs [--root <tree>] [--iters 10000] [--out file.json] [--seed boot|none]
//      [--disc d --syms s] [--holdkey col,row]
// --holdkey: hold that key on the emulated keyboard from the first MLOOP on (e.g. 0,1 = Q),
// so FILLKL's per-key scan (Rd1, a SEI section per key) runs as it does while a player
// holds a key; the pilot's injected keys still decide what the game sees
import { writeFileSync, existsSync } from "fs";
import { dirname, resolve } from "path";
import { fileURLToPath } from "url";
import { attachProbe, summarise, marksFor } from "./probe.mjs";

const args = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => {
    if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]);
    return acc;
}, []));
const HERE = dirname(fileURLToPath(import.meta.url));
const TREE = resolve(args.root || `${HERE}/../../..`);
const DISC = resolve(args.disc || `${TREE}/master/build/elite-master-sng47.ssd`);
const SYMS = resolve(args.syms || `${TREE}/master/build/symbols.txt`);
const REF = `${TREE}/master/reference/elite-master-sng47.ssd`, RSYMS = `${TREE}/master/reference/symbols.txt`;
const ITERS = +(args.iters || 10000);
const OUT = resolve(args.out || `${TREE}/scratch/irqprobe/gate.json`);
for (const f of [DISC, SYMS]) if (!existsSync(f)) throw new Error(`${f} missing (build first)`);
const { runElite, loadSyms } = await import(`${TREE}/harness/mlib.mjs`);
const { makePilot, patchCommander } = await import(`${TREE}/harness/mpilot.mjs`);
const sy = loadSyms(SYMS);
const t0 = Date.now();

let seedBoot = null;
if ((args.seed || "boot") === "boot") {
    const ref = await runElite({ disc: REF, syms: loadSyms(RSYMS), pilot: makePilot(), iters: 1, maxSecs: 200, patch: patchCommander });
    if (!ref.init) throw new Error("reference run did not reach TT170");
    seedBoot = (cregions, written, rb) => {
        const out = []; let o = 0;
        for (const [ra, n, name] of ref.regions) {
            const c = cregions.find(r => r[2] === name);
            if (c && c[1] === n) for (let i = 0; i < n; i++) if (!written.has(c[0] + i) && rb(c[0] + i) !== ref.init[o + i]) out.push([c[0] + i, [ref.init[o + i]]]);
            o += n;
        }
        return out;
    };
}
const pilot = makePilot();
let probe = null, cpu = null;
const r = await runElite({
    disc: DISC, syms: sy, pilot, iters: ITERS, maxSecs: 4 * ITERS, patch: patchCommander, seedBoot,
    onIter: (i, s) => {
        if (!probe) {
            cpu = s._machine.processor; probe = attachProbe(cpu, sy, { marks: marksFor(sy) });
            if (args.holdkey) cpu.sysvia.keyDownRaw(String(args.holdkey).split(",").map(Number));
        }
        const q = cpu.ramRomOs[sy.QQ11];
        probe.tag = `${pilot.P.phase}/${q === 0 ? "space" : "qq" + q.toString(16)}`;
    },
});
const sum = summarise(probe, `gate ${ITERS}`);
sum.iters = r.iters; sum.emuSecs = r.emuSecs; sum.wallSecs = (Date.now() - t0) / 1000; sum.error = r.error || null;
sum.pilot = { ...pilot.P.stats, systems: [...(pilot.P.stats.systems || [])].length };
writeFileSync(OUT, JSON.stringify(sum, null, 1));
console.log(`irqprobe gate: ${r.iters} iterations; T1 latency buffer0 ${JSON.stringify({...sum.t1.buffer0, hist: undefined})}; split late ${sum.split.buffer0Late} early ${sum.split.buffer0Early}; frames ${sum.frames.total} (buffer 0 ${sum.frames.buffer0}), copy shown in ${sum.frames.copyShown.frames} -> ${OUT}`);
