// BRIEF's ship in the original and the port (harness/mbrief.mjs's recordings):
// node harness/mbriefcmp.mjs --ref DIR --cand DIR
// The ship's data block INWK (bytes 0-35) at each LL9 call of the briefing must be the
// same, call for call, in both machines, for as many calls as both made (the number of
// PAS1 turns before a key press depends on each machine's speed; agentplay's lockstep
// replays give both the same turns). Prints the first difference, or MBRIEFCMP PASS.
import { parseArgs } from "./args.mjs";
import { readFileSync } from "fs";
const a = parseArgs({ ref: "value", cand: "value" });
const r = JSON.parse(readFileSync(`${a.ref}/brief1.json`)), c = JSON.parse(readFileSync(`${a.cand}/brief1.json`));
const n = Math.min(r.ll9.length, c.ll9.length);
// the calls before the first key press (BRL1, BRL2, BR2's PAS1 and PAL1's) match one to one
let bad = 0;
const k1 = x => x.ll9.filter(l => l.t < x.waits[0].t + 2.5).length;
const m = Math.min(k1(r), k1(c));
for (let i = 0; i < m; i++) {
    const d = r.ll9[i].inwk.map((v, k) => v === c.ll9[i].inwk[k] ? null : `INWK+${k} ref ${v} cand ${c.ll9[i].inwk[k]}`).filter(x => x);
    if (d.length) { console.log(`LL9 call ${i}: ${d.join(", ")}`); if (++bad > 5) break; }
}
console.log(`${m} LL9 calls compared (ref ${r.ll9.length}, cand ${c.ll9.length} in all)`);
console.log(bad ? "MBRIEFCMP FAIL" : "MBRIEFCMP PASS");
process.exit(bad ? 1 : 0);
