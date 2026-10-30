#!/usr/bin/env node
// tcrash.mjs: a deliberate BRK on the parasite must reach the crash reporter
// (p_crash, p-layout.asm: the vector at &FFFE, no client OS after the boot).
// Boots, runs 40 iterations, puts a BRK at p_sync, then checks that the
// parasite sits in p_crash's loop with the BRK's address on its stack.
//
// node tube/tools/tcrash.mjs [--host Master|B] [--disc d] [--psyms s]
import { bootTube, ROOT } from "../../harness/tlib.mjs";
import { loadSyms } from "../../harness/mlib.mjs";
import { parseArgs } from "../../harness/args.mjs";
const a = parseArgs({ host: "value", disc: "value", psyms: "value" });
const HOST = a.host || "Master";
const DISC = a.disc || `${ROOT}tube/build/elite-tube${HOST === "B" ? "-b" : ""}.ssd`;
const psy = loadSyms(a.psyms || `${ROOT}tube/build/psyms.txt`);
const t = await bootTube({ host: HOST, disc: DISC });
const s = t.s, host = t.host, pm = t.par.memory;
s.keyDown(16); s.reset(true); host.execute(2e6 * 2); s.keyUp(16);
let iters = 0, armed = false;
t.addParHook(pc => { if (pc === psy.p_sync && ++iters === 40 && !armed) { armed = true; pm[psy.p_sync] = 0; } return false; });
for (let k = 0; k < 600 && !(armed && t.par.pc >= psy.pcrsh && t.par.pc < psy.pcrsh + 3); k++) host.execute(2e5);
host.execute(2e5);
const S = pm[psy.pcrs], ret = pm[0x102 + S] | pm[0x103 + S] << 8;
const ok = armed && t.par.pc >= psy.pcrsh && t.par.pc < psy.pcrsh + 3 && ret === psy.p_sync + 2;
console.log(`iterations ${iters}, parasite pc &${t.par.pc.toString(16)} (pcrsh &${psy.pcrsh.toString(16)}), S &${S.toString(16)}, BRK's return &${ret.toString(16)} (p_sync+2 &${(psy.p_sync + 2).toString(16)}): ${ok ? "the crash reporter" : "NOT REACHED"}`);
process.exit(ok ? 0 : 1);
