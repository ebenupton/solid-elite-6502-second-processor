#!/usr/bin/env node
// tflips.mjs (from tkind.mjs): the host's flip intervals in fields (vsyncs) over a replay window, as harness/mflips.mjs on the Master port: the histogram, by iteration range. (tkind.mjs: which planet kind each frame draws (G_PLANET with TYPE 128 or 130), and the overlay loads, over a replay. Prints the runs of each kind by iteration.
// (tfbreplay.mjs: the pixel oracle's candidate side for the Tube build. Replays an
// agentplay input log on the Tube build (as master/tools/agentplay/fbreplay.mjs does
// on the Master port) and hashes the host's two screen buffers at the end of each
// main-loop iteration's frame: where the host executes C_SYNC, which the parasite
// sends at hframe after G_FRAME (the Master port's hash point, hframe+7). The key
// is the parasite's iteration when it sent C_SYNC, then a running frame count, as
// fbreplay's ("iteration.n"); the hash is the same (the first 16 hex digits of the
// SHA-1 of buffer 0 then buffer 1, each &4000-&6FFF), so the two files compare
// directly (tube/tools/fbcmp.mjs).
//
// node tube/tools/tfbreplay.mjs --log inputs.jsonl --out DIR --cand disc --csyms syms
//      --from I --to J [--host Master|B]
import { TubeEliteMachine, loadSyms, CYCLES_PER_FRAME } from "./tmachine.mjs";
import { EliteMachine } from "../../master/tools/agentplay/lib.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { createHash } from "crypto";

const a = parseArgs({ from: "value", hsyms: "value", flip: "value", log: "value", out: "value", cand: "value", csyms: "value", from: "value", to: "value", host: "value", dumpn: "value", master: "flag", hsyms: "value" });
const DUMP = a.dumpn ? a.dumpn.split("-").map(Number) : null;
if (!a.log || !a.cand || !a.csyms) { console.error("--log, --out, --cand and --csyms are required"); process.exit(2); }

const L = { rlog: new Map(), rjoy: [[], []], ptr: [0, 0], pokes: new Map(), header: null };
for (const l of readFileSync(a.log, "utf8").split("\n")) {
    if (!l) continue;
    const e = JSON.parse(l);
    if (e.header) L.header = e; else if (e.p !== undefined) L.rlog.set(e.p, e);
    else if (e.j !== undefined) L.rjoy[e.w].push([e.j, e.v]); else if (e.poke !== undefined) L.pokes.set(e.poke, e.v);
}
const H = L.header;
const rsy = loadSyms(DEFAULTS.rsyms), csy = loadSyms(a.csyms);
const rand = H.seed !== undefined && H.seed !== null ? seedBytes(H.seed) : null;
const cmdr = COMMANDERS[H.commander || "jameson"];
const patch = cmdr.patch ? m => cmdr.patch(m) : null;
const ref = new EliteMachine({ name: "ref", disc: DEFAULTS.ref, syms: rsy, input: { rdkey: () => [], dks5: () => false, joy: () => 0x80 }, rand, patch });
await ref.boot();
for (let k = 0; k < 10000 && !ref.started; k++) ref.run(CYCLES_PER_FRAME);
const cand = new TubeEliteMachine({ host: a.host || "Master", name: "cand", disc: a.cand, syms: csy, rand, patch, seedFrom: ref,
    input: {
        rdkey(ctx) { return L.rlog.get(ctx.poll)?.k || []; },
        dks5(ctx) { const e = L.rlog.get(ctx.poll); return !!(e && e.t === "d"); },
        joy(ctx) { const l = L.rjoy[ctx.which]; while (L.ptr[ctx.which] + 1 < l.length && l[L.ptr[ctx.which] + 1][0] <= ctx.joy) L.ptr[ctx.which]++; const e = l[L.ptr[ctx.which]]; return e && e[0] <= ctx.joy ? e[1] : 0x80; },
    } });
await cand.boot();
cand.pokes = L.pokes;
const FROM = +(a.from || 0), TO = +(a.to || 1000), HB = (a.host || "Master") === "B";
const hsy = loadSyms(a.hsyms || a.csyms.replace(/psyms\.txt$/, HB ? "hbmsyms.txt" : "hsyms.txt"));
const VS = HB ? hsy.hbi_p1 : hsy.H_VSYNC, FL = HB ? hsy.hbi_flip : hsy.hv_flip;
let fields = 0, last = null, lastVs = -1e9; const hist = {}, short = [];
// (a vsync is counted at its entry or the instruction after it, once: jsbeeb
// skips the hook on a slice's first instruction)
const VS2 = VS + (HB ? 2 : 3);
cand.host.debugInstruction.add(pc => {
    if (pc === VS || pc === VS2) { const c = cand.host.cycleSeconds * 2e6 + cand.host.currentCycles; if (c - lastVs > 1000) { fields++; lastVs = c; } }
    if (pc === FL && cand.iter >= FROM) { if (last !== null) { const d = fields - last; hist[d] = (hist[d] || 0) + 1; if (d < 2) short.push(cand.iter); } last = fields; }
    return false; });
while (cand.iter < TO) {
    const r = cand.run(CYCLES_PER_FRAME);
    cand.snaps.length = 0;
    if (r === "blocked" && cand.blocked && cand.blocked.kind !== "tt170") { if (cand.polls > Math.max(...L.rlog.keys())) break; }
}
if (short.length) console.log("1-field intervals at iterations:", short.join(" "));
console.log(`flip intervals in fields, iterations ${FROM}-${TO}: ${JSON.stringify(hist)}`);
process.exit(0);
