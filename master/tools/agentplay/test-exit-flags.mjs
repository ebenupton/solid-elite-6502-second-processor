#!/usr/bin/env node
// Regression test: the port's rewritten dashboard routines must return the registers and
// flags the original's do, as callers carry them on (agentplay found the port's MSBAR
// returning C set where the original's returns it clear: ABORT2's caller went on into
// DORND, whose result depends on C, when a ship started exploding in the iteration of a
// missile lock, and the random numbers diverged). Both machines are booted to the docked
// Status screen; then, in each, every routine below is called with each set of inputs and
// both values of C on entry, and A, X, Y and the C, Z, N and V flags at its return are
// compared. --info also reports routines known to differ (DOT).
// node master/tools/agentplay/test-exit-flags.mjs [--cand disc --csyms syms] [--info]
import { Session } from "./session.mjs";
import { ROOT } from "./lib.mjs";
import { writeFileSync, mkdirSync } from "fs";
const argv = process.argv.slice(2);
const a = Object.fromEntries(argv.reduce((acc, v, i, arr) => { if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1]]); return acc; }, []));
const out = a.out || ROOT + "scratch/agentplay/test-exit-flags";
mkdirSync(out, { recursive: true });
const log = out + "/inputs.jsonl";
writeFileSync(log, JSON.stringify({ header: true, seed: 1, commander: "jameson", startFrame: 700 }) + "\n");
const S = new Session({ out, replay: log, seed: 1, commander: "jameson", ref: ROOT + "master/reference/elite-master-sng47.ssd", rsyms: ROOT + "master/reference/symbols.txt",
    cand: a.cand || ROOT + "master/build/elite-master-sng47.ssd", csyms: a.csyms || ROOT + "master/build/symbols.txt", startFrame: 700, observe: false });
await S.start();
while (S.frame < 900) await S.step();
// [routine, [[X, Y], ...]] (each routine is called twice per input, so EOR drawing undoes itself)
const CASES = [
    ["MSBAR", [1, 2, 3, 4].flatMap(x => [0, 0xf0, 0x0f, 0xff].map(y => [x, y]))],      // (Y: colour bytes as the original's callers pass)
    ["ECBLB", [[0, 0]]], ["SPBLB", [[0, 0]]],
    ...(argv.includes("--info") ? [["DOT", [[0, 0]]]] : []),
];
function call(m, name, x, y, c) {
    const cpu = m.cpu, addr = m.sy[name], RET = 0xfff0, pc0 = cpu.pc, s0 = cpu.s;
    cpu.writemem(0x100 + s0, (RET - 1) >> 8); cpu.writemem(0x100 + ((s0 - 1) & 255), (RET - 1) & 255); cpu.s = (s0 - 2) & 255;
    cpu.x = x; cpu.y = y; cpu.a = 0; cpu.p.c = !!c; cpu.p.v = false; cpu.pc = addr;
    let back = false;
    const h = cpu.debugInstruction.add(pc => { if (pc === RET) { back = true; return true; } return false; });
    for (let n = 0; n < 2e6 && !back; n += 2000) cpu.execute(2000);
    h.remove();
    const r = back ? { A: cpu.a, X: cpu.x, Y: cpu.y, C: +cpu.p.c, Z: +cpu.p.z, N: +cpu.p.n, V: +cpu.p.v } : { back: false };
    cpu.pc = pc0; cpu.s = s0;
    return r;
}
let fail = 0, n = 0;
for (const [name, inputs] of CASES) {
    for (const [x, y] of inputs) for (const c of [0, 1]) for (let rep = 0; rep < 2; rep++) {
        const r = call(S.ref, name, x, y, c), k = call(S.cand, name, x, y, c);
        n++;
        if (JSON.stringify(r) !== JSON.stringify(k)) { fail++; if (fail <= 12) console.log(`${name} X=${x} Y=${y} C=${c}: ref ${JSON.stringify(r)} cand ${JSON.stringify(k)}`); }
    }
}
console.log(`${n} calls compared, ${fail} differ`);
console.log(fail ? "EXIT FLAGS TEST: FAIL" : "EXIT FLAGS TEST: PASS");
process.exit(fail ? 1 : 0);
