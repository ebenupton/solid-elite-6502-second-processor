#!/usr/bin/env node
// dprofcmp.mjs: two of tube/tools/dprof.mjs's profiles of the same replay window
// compared, per iteration on average: the wall time, then a field's entries (cx:
// the routine on top of the call stack, the default; lab: the label; inc: every
// routine on the stack; calls; tx; h) by their difference, with their calls in
// brackets. --class none|still|moving takes only the iterations whose disc rows
// in the second profile are none, unchanged or changed since the last.
//   node tube/tools/dprofcmp.mjs A.json B.json --window 5355-5457 [--field cx]
//        [--top 30] [--class moving]
import { parseArgs } from "../../harness/args.mjs";
import { readFileSync } from "fs";

const a = parseArgs({ window: "value", field: "value", top: "value", class: "value" }, process.argv.slice(2), { positional: true });
if (a._.length !== 2 || !a.window) { console.error("dprofcmp.mjs A.json B.json --window I-J [--field F] [--top N] [--class C]"); process.exit(2); }
const [fa, fb] = a._;
const field = a.field || "cx", top = +(a.top || 30), cls = a.class;
const klass = x => { if (!Math.max(...x.dr)) return "none"; return x.ch[0] || x.ch[1] ? "moving" : "still"; };
const load = f => JSON.parse(readFileSync(f, "utf8")).filter(x => x.w === a.window);
const A = load(fa), bm = new Map(load(fb).map(x => [x.it, x]));
const As = A.filter(x => bm.has(x.it) && (!cls || klass(bm.get(x.it)) === cls)), Bs = As.map(x => bm.get(x.it));
const agg = (d, f) => { const t = {}; for (const x of d) for (const [k, v] of Object.entries(x[f] || {})) t[k] = (t[k] || 0) + v; for (const k in t) t[k] /= d.length; return t; };
const fA = agg(As, field), fB = agg(Bs, field), cA = agg(As, "calls"), cB = agg(Bs, "calls");
const wall = d => d.reduce((s, x) => s + x.wall, 0) / d.length, wa = wall(As), wb = wall(Bs);
console.log(`${a.window} ${cls || "all"} n=${As.length} ${field}: wall ${wa.toFixed(0)} -> ${wb.toFixed(0)}, ${(wb - wa).toFixed(0)} (${(100 * (wb - wa) / wa).toFixed(2)}%)`);
const ks = [...new Set([...Object.keys(fA), ...Object.keys(fB)])].map(k => [k, fA[k] || 0, fB[k] || 0]).sort((x, y) => Math.abs(y[2] - y[1]) - Math.abs(x[2] - x[1]));
for (const [k, x, y] of ks.slice(0, top))
    console.log(`  ${(y - x).toFixed(0).padStart(8)}  ${x.toFixed(0).padStart(7)} (${(cA[k] || 0).toFixed(1)})  ${y.toFixed(0).padStart(7)} (${(cB[k] || 0).toFixed(1)})  ${k}`);
