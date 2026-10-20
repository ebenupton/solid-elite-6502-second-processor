#!/usr/bin/env node
// Whole-code coverage of the original over any number of sessions: the union of the
// coverage-ref.json files found under the given directories (sessions or campaigns).
// node master/tools/agentplay/coverage.mjs DIR [DIR...] [--grep RE] [--cand]
// (--cand: the port's coverage-cand.json instead, its labels in every bank)
// Prints the labels reached, and the code labels (run in some session, or the target of
// a JSR/JMP in the original's image) never run in any.
import { existsSync, readFileSync, readdirSync, statSync } from "fs";
const args = process.argv.slice(2), gi = args.indexOf("--grep");
const re = gi >= 0 ? new RegExp(args.splice(gi, 2)[1]) : null;
const ci = args.indexOf("--cand"), FILE = ci >= 0 ? (args.splice(ci, 1), "coverage-cand.json") : "coverage-ref.json";
const reached = new Map(), code = new Set(); let n = 0;
function walk(d, depth = 0) {
    const f = `${d}/${FILE}`;
    if (existsSync(f)) {
        const c = JSON.parse(readFileSync(f, "utf8")); n++;
        for (const k of c.reached) { reached.set(k, (reached.get(k) || 0) + 1); code.add(k); }
        for (const k of c.unreached) code.add(k);
    }
    if (depth < 3) for (const e of readdirSync(d)) { const p = `${d}/${e}`; if (statSync(p).isDirectory()) walk(p, depth + 1); }
}
for (const d of args) walk(d);
const un = [...code].filter(k => !reached.has(k) && (!re || re.test(k)));
console.log(`${n} sessions; ${reached.size} labels reached; ${un.length} code labels never run:`);
console.log(un.join(" "));
const rare = [...reached].filter(([k, v]) => v === 1 && (!re || re.test(k))).map(([k]) => k);
console.log(`\nreached in one session only (${rare.length}):`);
console.log(rare.join(" "));
