// Cycle profile of BBC Master Elite (reference or a build) under the pilot, by
// routine (bank-aware), over a range of main-loop iterations.
//
// node harness/mprof.mjs [--disc d] [--syms s] [--from 0] [--n 1000] [--top 50]
//                        [--grep str] [--groups file.json]
//
// Defaults: the released SNG47 disc with master/reference/symbols.txt. Cycles
// are charged to the label at or below the PC, in the mapping that is paged
// (main RAM, ANDY, sideways bank, HAZEL, MOS).
import { runElite, loadSyms, mapAt, ROOT } from "./mlib.mjs";
import { makePilot, patchCommander } from "./mpilot.mjs";

const a = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => { if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]); return acc; }, []));
const DISC = a.disc || `${ROOT}master/reference/elite-master-sng47.ssd`;
const sy = loadSyms(a.syms || `${ROOT}master/reference/symbols.txt`);
const FROM = +(a.from || 0), N = +(a.n || 1000);
// extra label tables for files assembled outside the symbol dump's banks.txt
const labs = {};
for (const [k, v] of Object.entries(sy)) {
    if (v < 0x0100 || /^(CODE|LOAD)/.test(k)) continue;
    const b = sy.__bank[k];
    const m = b === undefined ? (v >= 0x8000 && v < 0xc000 ? "x" : "m") : mapAt(b, v);
    (labs[m] ||= []).push([v, k]);
}
for (const l of Object.values(labs)) l.sort((x, y) => x[0] - y[0]);
const look = (t, pc) => { if (!t) return null; let lo = 0, hi = t.length - 1, r = null; while (lo <= hi) { const m = (lo + hi) >> 1; if (t[m][0] <= pc) { r = t[m][1]; lo = m + 1; } else hi = m - 1; } return r; };
const prof = {};
let on = false, last = 0, lastKey = null, c0 = 0, c1 = 0, installed = false, cpu;
const cyc = () => cpu.cycleSeconds * 2e6 + cpu.currentCycles;
const pilot = makePilot();
await runElite({
    disc: DISC, syms: sy, pilot, iters: FROM + N + 1, patch: patchCommander,
    onIter: (i, s) => {
        cpu = s._machine.processor;
        if (!installed) {
            installed = true;
            cpu.debugInstruction.add(pc => {
                if (!on) return false;
                const now = cyc();
                if (lastKey) prof[lastKey] = (prof[lastKey] || 0) + now - last;
                last = now;
                let key;
                if (pc >= 0xc000) key = pc >= 0xe000 ? "MOS" : "HZ:" + (look(labs.m, pc) || "?");
                else if (pc >= 0x8000) { const m = mapAt(cpu.romsel, pc); key = (m === "A" ? "A:" : "b" + m + ":") + (look(labs[m], pc) || look(labs.x, pc) || "?"); }
                else key = look(labs.m, pc) || "low";
                lastKey = key;
                return false;
            });
        }
        if (i === FROM) { on = true; c0 = cyc(); last = c0; }
        if (i === FROM + N) { on = false; c1 = cyc(); }
    },
});
const tot = c1 - c0;
console.log(`iterations ${FROM}-${FROM + N}: ${(tot / N).toFixed(0)} cycles/iteration`);
// --src a.asm,b.asm: charge each label to the routine whose header ("Name:")
// precedes it, and report per routine and per category ("Category:")
const rout = {}, cat = {};
if (a.src) for (const f of a.src.split(",")) {
    let name = null, c = null, pend = null;
    for (const l of (await import("fs")).readFileSync(f, "latin1").split("\n")) {
        let m;
        if ((m = l.match(/^\\\s+Name: (\S+)/))) pend = m[1];
        else if ((m = l.match(/^\\\s+Category: (.*)/)) && pend) { name = pend; c = m[1].trim(); pend = null; }
        else if ((m = l.match(/^\.([A-Za-z_][\w%]*)/)) && name) { rout[m[1]] = name; cat[name] = c; }
    }
}
if (a.src) {
    const r = {}, cg = {};
    for (const [k, v] of Object.entries(prof)) {
        const lab = k.replace(/^[^:]*:/, "").replace(/_C$/, "");
        const rn = rout[lab] || k;
        r[rn] = (r[rn] || 0) + v;
        const cn = cat[rn] || (k.startsWith("MOS") ? "MOS" : "?");
        cg[cn] = (cg[cn] || 0) + v;
    }
    for (const [k, v] of Object.entries(cg).sort((x, y) => y[1] - x[1])) console.log("CAT " + k.padEnd(30), (v / N).toFixed(0).padStart(8), (100 * v / tot).toFixed(1).padStart(6) + "%");
    for (const [k, v] of Object.entries(r).sort((x, y) => y[1] - x[1]).slice(0, +(a.top || 50))) console.log("ROUTINE " + k.padEnd(24), (v / N).toFixed(0).padStart(8), (100 * v / tot).toFixed(1).padStart(6) + "%");
}
let groups = null;
if (a.groups) groups = JSON.parse((await import("fs")).readFileSync(a.groups, "utf8"));
if (groups) {
    const g = {};
    for (const [k, v] of Object.entries(prof)) {
        const name = k.replace(/^[^:]*:/, "");
        let grp = "other";
        for (const [gn, list] of Object.entries(groups)) if (list.includes(name)) { grp = gn; break; }
        g[grp] = (g[grp] || 0) + v;
    }
    for (const [k, v] of Object.entries(g).sort((x, y) => y[1] - x[1])) console.log("GROUP " + k.padEnd(20), (v / N).toFixed(0).padStart(8), (100 * v / tot).toFixed(1).padStart(6) + "%");
}
const rows = Object.entries(prof).sort((x, y) => y[1] - x[1]).filter(([k]) => !a.grep || k.includes(a.grep)).slice(0, +(a.top || 50));
for (const [k, v] of rows) console.log(k.padEnd(28), (v / N).toFixed(0).padStart(8), (100 * v / tot).toFixed(1).padStart(6) + "%");
