#!/usr/bin/env node
// pcov.mjs: the parasite's code coverage by display mode, over a replayed run
// (for the overlay split: which code runs in space mode, which in direct mode).
// Each executed parasite address gets a bit per mode it ran in:
//   1: space mode (GMODE bit 7 set), 2: direct mode (GMODE bit 7 clear),
//   4: QQ11 = 0, 8: QQ11 <> 0
// node tube/tools/pcov.mjs --log inputs.jsonl --cand disc --csyms psyms --to N --out cov.bin [--host Master|B]
import { TubeEliteMachine, loadSyms, CYCLES_PER_FRAME } from "./tmachine.mjs";
import { EliteMachine } from "../../master/tools/agentplay/lib.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { readFileSync, writeFileSync } from "fs";

const a = parseArgs({ log: "value", cand: "value", csyms: "value", to: "value", out: "value", host: "value" });
const L = { rlog: new Map(), rjoy: [[], []], ptr: [0, 0], header: null };
for (const l of readFileSync(a.log, "utf8").split("\n")) {
    if (!l) continue;
    const e = JSON.parse(l);
    if (e.header) L.header = e; else if (e.p !== undefined) L.rlog.set(e.p, e);
    else if (e.j !== undefined) L.rjoy[e.w].push([e.j, e.v]);
}
const H = L.header, csy = loadSyms(a.csyms);
const rand = H.seed !== undefined && H.seed !== null ? seedBytes(H.seed) : null;
const cmdr = COMMANDERS[H.commander || "jameson"], patch = cmdr.patch ? m => cmdr.patch(m) : null;
const ref = new EliteMachine({ name: "ref", disc: DEFAULTS.ref, syms: loadSyms(DEFAULTS.rsyms), input: { rdkey: () => [], dks5: () => false, joy: () => 0x80 }, rand, patch });
await ref.boot();
for (let k = 0; k < 10000 && !ref.started; k++) ref.run(CYCLES_PER_FRAME);
const cand = new TubeEliteMachine({ host: a.host || "Master", name: "cand", disc: a.cand, syms: csy, rand, patch, seedFrom: ref,
    input: {
        rdkey(ctx) { return L.rlog.get(ctx.poll)?.k || []; },
        dks5(ctx) { const e = L.rlog.get(ctx.poll); return !!(e && e.t === "d"); },
        joy(ctx) { const l = L.rjoy[ctx.which]; while (L.ptr[ctx.which] + 1 < l.length && l[L.ptr[ctx.which] + 1][0] <= ctx.joy) L.ptr[ctx.which]++; const e = l[L.ptr[ctx.which]]; return e && e[0] <= ctx.joy ? e[1] : 0x80; },
    } });
await cand.boot();
const cov = new Uint8Array(65536);
const mem = cand.t.par.memory, GM = csy.GMODE, Q11 = csy.QQ11;
cand.t.addParHook(pc => { if (cand.started) cov[pc] |= (mem[GM] & 0x80 ? 1 : 2) | (mem[Q11] ? 8 : 4); return false; });
// data accesses (reads and writes, instruction fetches too) by mode, in acc
const acc = new Uint8Array(65536), par = cand.t.par;
const rm = par.readmem.bind(par), wm = par.writemem.bind(par);
par.readmem = x => { if (cand.started) acc[x & 0xffff] |= mem[GM] & 0x80 ? 1 : 2; return rm(x); };
par.writemem = (x, v) => { if (cand.started) acc[x & 0xffff] |= mem[GM] & 0x80 ? 1 : 2; return wm(x, v); };
const TO = +(a.to || 16000), t0 = Date.now();
while (cand.iter < TO) {
    const r = cand.run(CYCLES_PER_FRAME);
    cand.snaps.length = 0;
    if (r === "blocked" && cand.blocked && cand.blocked.kind !== "tt170") { if (cand.polls > Math.max(...L.rlog.keys())) break; }
}
writeFileSync(a.out, cov);
writeFileSync(a.out + ".acc", acc);
console.log(`coverage to iteration ${cand.iter}: ${cov.reduce((n, x) => n + (x ? 1 : 0), 0)} addresses, ${((Date.now() - t0) / 1000).toFixed(0)} s`);
process.exit(0);
