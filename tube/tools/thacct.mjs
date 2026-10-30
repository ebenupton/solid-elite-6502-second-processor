#!/usr/bin/env node
// thacct.mjs: the gap between two hosts (or builds) accounted for, from two of
// thcmd.mjs's outputs (A the faster, B the slower), per window, in host cycles
// an iteration (2 MHz): the wall time is the host's busy time plus its idle
// time, so the gap is the sum of the differences of the categories below
// (exactly, by construction: "other" is the residual of the named ones); then
// the parasite's side (its cycles an iteration, by state, over the parasite's
// clock ratio): which side waits on which.
//   node tube/tools/thacct.mjs --a A.json --b B.json [--mhz 3]
import { readFileSync } from "fs";
import { parseArgs } from "../../harness/args.mjs";
const a = parseArgs({ a: "value", b: "value", mhz: "value", md: "flag" });
const A = JSON.parse(readFileSync(a.a, "utf8")), B = JSON.parse(readFileSync(a.b, "utf8"));
const R = (+(a.mhz || 3)) / 2;          // parasite cycles a host cycle
const RAST = /^C_(DSPANS|SPANS|SPAN|LINE|DOT|STARS|STARERASE|ORSPAN|EORDOT)$/;
const TEXT = /^C_(GLYPH|CHAR|CLS|BOXC|CLYNS|LOIN|HLOIN|PIXEL|PDIALS|PDOT|PSCAN|PMSBAR|PBULB)$/;
const STORE = /^C_(OVLGET|OVLPUT|DISC)$/;
const cats = [
    ["the run pages patched for the buffer (r_pgfix)", r => sumLab(r, /^.:r_pgfix$/)],
    ["the flip's wait at C_BUF", r => r.state.C_BUF || 0],
    ["timer IRQs (the rupture's; the Master's IRQ1)", r => (r.state["IRQ rupture timer"] || 0) + (r.state["IRQ IRQ1"] || 0) + (r.state["IRQ timer"] || 0)],
    ["other IRQs (vsync and sound, requests)", r => Object.entries(r.state).filter(([k]) => k.startsWith("IRQ ") && !/rupture|IRQ1|timer/.test(k)).reduce((s, [, v]) => s + v, 0)],
    ["drawing commands' code (NMOS, bases), less r_pgfix", r => stateSum(r, RAST) - sumLab(r, /^.:r_pgfix$/)],
    ["text, panel and direct-mode commands", r => stateSum(r, TEXT)],
    ["overlay storage and disc commands", r => stateSum(r, STORE)],
    ["other commands, the loop's dispatch, the MOS", r => Object.entries(r.state).filter(([k]) => !k.startsWith("IRQ ") && !["idle", "hrw wait", "C_BUF"].includes(k) && !RAST.test(k) && !TEXT.test(k) && !STORE.test(k)).reduce((s, [, v]) => s + v, 0)],
    ["commands waiting for their next byte (hrw)", r => r.state["hrw wait"] || 0],
    ["the loop idle (nothing from the parasite)", r => r.state.idle || 0],
];
function sumLab(r, re) { return Object.entries(r.lab).filter(([k]) => re.test(k)).reduce((s, [, v]) => s + v, 0); }
function stateSum(r, re) { return Object.entries(r.state).filter(([k]) => re.test(k.replace(/^MOS /, ""))).reduce((s, [, v]) => s + v, 0); }
const f = x => x.toFixed(0);
for (const w of Object.keys(A)) {
    const x = A[w], y = B[w]; if (!y) continue;
    const gap = y.wall - x.wall;
    console.log(`\n== ${w}: wall ${f(x.wall)} -> ${f(y.wall)} host cycles an iteration, gap ${f(gap)} (${(100 * gap / x.wall).toFixed(1)}%)`);
    let sa = 0, sb = 0;
    const rows = cats.map(([n, fn]) => { const u = fn(x), v = fn(y); sa += u; sb += v; return [n, u, v]; });
    rows.push(["other (residual)", x.tot - sa, y.tot - sb]);
    for (const [n, u, v] of rows) console.log(`  ${n.padEnd(52)} ${f(u).padStart(8)} ${f(v).padStart(8)} ${f(v - u).padStart(8)}`);
    console.log(`  ${"total (= the wall)".padEnd(52)} ${f(x.tot).padStart(8)} ${f(y.tot).padStart(8)} ${f(y.tot - x.tot).padStart(8)}`);
    console.log(`  the parasite (its cycles an iteration / ${R}):`);
    const ks = [...new Set([...Object.keys(x.par), ...Object.keys(y.par)])].sort((p, q) => Math.abs((y.par[q] || 0) - (x.par[q] || 0)) - Math.abs((y.par[p] || 0) - (x.par[p] || 0)));
    for (const k of ks) { const u = (x.par[k] || 0) / R, v = (y.par[k] || 0) / R; console.log(`    ${k.padEnd(50)} ${f(u).padStart(8)} ${f(v).padStart(8)} ${f(v - u).padStart(8)}`); }
}
