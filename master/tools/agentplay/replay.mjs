#!/usr/bin/env node
// Replay a session's input log into both machines, without the agent: the same reads get
// the same keys, so the session (and any divergence) comes back exactly.
//
// node master/tools/agentplay/replay.mjs --run DIR [--out DIR2] [--until ITER] [--keepgoing N]
//      [--cut ITER --save FILE] [--trace FROM,TO [--tracefull]] [--shots N] [--noobserve] [--cand disc --csyms syms] [--ref disc --rsyms syms] [--log inputs.jsonl]
// Defaults: the discs and symbols in DIR/inputs.jsonl's header (the candidate can be swapped for
// another build to test a fix); --out DIR/replay. --until: stop after that iteration (a
// divergence's, for a short repro). Exit status as agentplay.mjs.
import { Session } from "./session.mjs";
import { readFileSync } from "fs";

const a = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => { if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]); return acc; }, []));
const log = a.log || `${a.run}/inputs.jsonl`;
if (!a.run && !a.out && a.cut === undefined) { console.error("--run DIR or --log FILE with --out DIR"); process.exit(2); }
const h = JSON.parse(readFileSync(log, "utf8").split("\n")[0]);
if (!h.header) { console.error("no header in", log); process.exit(2); }
// --cut ITER --save FILE: write the log cut short after iteration ITER (a minimal repro
// of a divergence there), with an end record, and stop
if (a.cut !== undefined) {
    const it = +a.cut, lines = readFileSync(log, "utf8").split("\n").filter(Boolean).map(l => JSON.parse(l));
    const keep = lines.filter(e => e.header || (!e.end && (e.i === undefined || e.i <= it) && (e.poke === undefined || e.poke <= it + 1)));
    keep.push({ end: true, iter: it + 1, cut: true });
    const { writeFileSync } = await import("fs");
    writeFileSync(a.save, keep.map(e => JSON.stringify(e)).join("\n") + "\n");
    console.log(`${a.save}: ${keep.length} records, to iteration ${it + 1}`);
    process.exit(0);
}
// (the header's paths are absolute; a log moved to another checkout falls back to its
// files of the same name under this one)
import { existsSync } from "fs";
import { ROOT } from "./lib.mjs";
const here = f => !f || existsSync(f) ? f : (() => { const m = /(master\/.*)$/.exec(f); return m && existsSync(ROOT + m[1]) ? ROOT + m[1] : f; })();
for (const k of ["ref", "rsyms", "cand", "csyms"]) h[k] = here(h[k]);
const cfg = {
    out: a.out || `${a.run}/replay`, replay: log, seed: h.seed, commander: h.commander, startFrame: h.startFrame, strict: h.strict,
    ref: a.ref || h.ref, rsyms: a.rsyms || h.rsyms, cand: a.cand || h.cand, csyms: a.csyms || h.csyms,
    trace: a.trace ? a.trace.split(",").map(Number) : undefined, traceFull: !!a.tracefull,
    workarounds: a.workaround ? String(a.workaround).split(",") : (h.workarounds || []),
    until: a.until !== undefined ? +a.until : undefined, keepGoing: +(a.keepgoing || 0), shots: +(a.shots || 0), observe: !a.noobserve,
};
try {
    const S = new Session(cfg);
    await S.start();
    const s = await S.run();
    const bad = s.findings.filter(f => f.kind !== "observable");
    console.log(`REPLAY ${bad.length ? "FINDINGS" : "CLEAN"} ${cfg.out}: ${s.compared} iterations compared, ${s.reads} reads, findings ${s.findings.length}${s.divergence ? `, first divergence at iteration ${s.divergence.iter}` : ""}`);
    for (const f of s.findings.slice(0, 20)) console.log(`  ${f.kind}: ${f.text}`);
    process.exit(bad.length ? 1 : 0);
} catch (e) { console.error(e.stack || e); process.exit(2); }
