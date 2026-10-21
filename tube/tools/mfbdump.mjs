#!/usr/bin/env node
// mfbdump.mjs: the Master port's side of tfbreplay's --dumpn: replay an input log on the
// Master build and write the two screen buffers (main RAM's &4000-&6FFF, then shadow
// RAM's) at hframe's return for frames n = LO..HI (fbreplay's running frame count).
// node tube/tools/mfbdump.mjs --log inputs.jsonl --out DIR --cand disc --csyms syms --dumpn LO-HI
import { EliteMachine, loadSyms, CYCLES_PER_FRAME } from "../../master/tools/agentplay/lib.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { readFileSync, writeFileSync, mkdirSync } from "fs";
const a = parseArgs({ log: "value", out: "value", cand: "value", csyms: "value", dumpn: "value" });
mkdirSync(a.out, { recursive: true });
const [LO, HI] = a.dumpn.split("-").map(Number);
const L = { rlog: new Map(), rjoy: [[], []], ptr: [0, 0], pokes: new Map(), header: null };
for (const l of readFileSync(a.log, "utf8").split("\n")) { if (!l) continue; const e = JSON.parse(l);
    if (e.header) L.header = e; else if (e.p !== undefined) L.rlog.set(e.p, e); else if (e.j !== undefined) L.rjoy[e.w].push([e.j, e.v]); else if (e.poke !== undefined) L.pokes.set(e.poke, e.v); }
const H = L.header, rand = seedBytes(H.seed), cmdr = COMMANDERS[H.commander || "jameson"], patch = cmdr.patch ? m => cmdr.patch(m) : null;
const ref = new EliteMachine({ name: "ref", disc: DEFAULTS.ref, syms: loadSyms(DEFAULTS.rsyms), input: { rdkey: () => [], dks5: () => false, joy: () => 0x80 }, rand, patch });
await ref.boot(); for (let k = 0; k < 10000 && !ref.started; k++) ref.run(CYCLES_PER_FRAME);
const cand = new EliteMachine({ name: "cand", disc: a.cand, syms: loadSyms(a.csyms), rand, patch, seedFrom: ref, input: {
    rdkey: ctx => L.rlog.get(ctx.poll)?.k || [], dks5: ctx => { const e = L.rlog.get(ctx.poll); return !!(e && e.t === "d"); },
    joy(ctx) { const l = L.rjoy[ctx.which]; while (L.ptr[ctx.which] + 1 < l.length && l[L.ptr[ctx.which] + 1][0] <= ctx.joy) L.ptr[ctx.which]++; const e = l[L.ptr[ctx.which]]; return e && e[0] <= ctx.joy ? e[1] : 0x80; } } });
await cand.boot(); cand.pokes = L.pokes;
const cpu = cand.cpu, HF = cand.sy.hframe + 7; let n = 0;
cpu.debugInstruction.add(pc => { if (pc === HF) { if (cand.iter >= LO && cand.iter <= HI) writeFileSync(`${a.out}/it-${cand.iter}-${n}.raw`, Buffer.concat([cpu.ramRomOs.subarray(0x4000, 0x7000), cpu.ramRomOs.subarray(0xc000, 0xf000)])); n++; } return false; });
while (cand.iter <= HI) { cand.run(CYCLES_PER_FRAME); cand.snaps.length = 0; }
console.log(`frames ${LO}..${HI} written, at iteration ${cand.iter}`);
process.exit(0);
