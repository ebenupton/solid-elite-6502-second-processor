#!/usr/bin/env node
// tfbreplay.mjs: the pixel oracle's candidate side for the Tube build. Replays an
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

const a = parseArgs({ inject: "value", log: "value", out: "value", cand: "value", csyms: "value", from: "value", to: "value", host: "value", dumpn: "value", master: "flag", hsyms: "value" });

// --inject SPEC: forced inputs over the log (the same on any build, as they key on
// the iteration and the read's site): items separated by ";":
//   k:ITER:N:SITE:KEYS   rdkey reads from SITE in iterations ITER..ITER+N-1 get KEYS (a,b)
//   d:ITER:N:KEY         dks5 reads of KEY in those iterations: held
//   p:ITER:SYM:VALUE     at iteration ITER, poke SYM = VALUE (the build's own symbols)
const INJ = (a.inject || "").split(";").filter(Boolean).map(s => s.split(":"));
const injKeys = ctx => { for (const f of INJ) if (f[0] === "k" && ctx.iter >= +f[1] && ctx.iter < +f[1] + +f[2] && ctx.site === f[3]) return f[4].split(",").map(Number); return null; };
const injDks = ctx => INJ.some(f => f[0] === "d" && ctx.iter >= +f[1] && ctx.iter < +f[1] + +f[2] && ctx.key === +f[3]);
const injPoked = new Set();
const injPoke = (m, sy) => { for (const f of INJ) if (f[0] === "p" && m.iter >= +f[1] && !injPoked.has(f.join(":"))) { injPoked.add(f.join(":")); m.ram[sy[f[2].split("+")[0]] + (+f[2].split("+")[1] || 0)] = +f[3]; console.log(`poked ${f[2]} = ${f[3]} at iteration ${m.iter}`); } };
const DUMP = a.dumpn ? a.dumpn.split("-").map(Number) : null;
if (!a.log || !a.out || !a.cand || !a.csyms) { console.error("--log, --out, --cand and --csyms are required"); process.exit(2); }
mkdirSync(a.out, { recursive: true });
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
        rdkey(ctx) { return injKeys(ctx) || L.rlog.get(ctx.poll)?.k || []; },
        dks5(ctx) { if (injDks(ctx)) return true; const e = L.rlog.get(ctx.poll); return !!(e && e.t === "d"); },
        joy(ctx) { const l = L.rjoy[ctx.which]; while (L.ptr[ctx.which] + 1 < l.length && l[L.ptr[ctx.which] + 1][0] <= ctx.joy) L.ptr[ctx.which]++; const e = l[L.ptr[ctx.which]]; return e && e[0] <= ctx.joy ? e[1] : 0x80; },
    } });
await cand.boot();
cand.pokes = L.pokes;
const FROM = +(a.from || 0), TO = +(a.to || 1000);
const hsy = loadSyms(a.hsyms || a.csyms.replace(/psyms\.txt$/, a.host === "B" ? "hbmsyms.txt" : "hsyms.txt"));
const q = [], res = {}, dres = {};
let n = 0;
const ovls = {};
cand.t.addParHook(pc => { if (pc === csy.p_sync) q.push(cand.iter); if (pc === csy.ovl_get) { const k = cand.t.par.a; ovls[k] = (ovls[k] || 0) + 1; } return false; });
const host = cand.host;
let syncSeen = false;
host.debugInstruction.add(pc => {
    // (the Model B host: another bank may have code at h_sync's address; only
    // bank F's NOP there is C_SYNC's)
    if ((pc === hsy.h_sync || pc === hsy.h_syncb) && host.readmem(hsy.h_sync) !== 0xea) return false;
    // (jsbeeb skips this hook on a slice's first instruction: h_sync is a NOP and
    // h_syncb the instruction after it, so one of the two is always seen)
    if (pc === hsy.h_sync) syncSeen = true;
    if (pc === hsy.h_syncb && !syncSeen) pc = hsy.h_sync;
    else if (pc === hsy.h_syncb) { syncSeen = false; return false; }
    if (pc === hsy.h_sync) {
        const it = q.shift();
        if (it >= FROM) {
            const h = createHash("sha1"), [b0, b1] = cand.hostScreen();
            h.update(b0); h.update(b1);
            res[`${it}.${n}`] = h.digest("hex").slice(0, 16);
            // (and the dashboard, &7000-&7DFF: shadow RAM on the Master host, main RAM on the Model B's)
            const m = cand.host.ramRomOs, d0 = a.host === "B" ? 0x7000 : 0xf000;
            dres[`${it}.${n}`] = createHash("sha1").update(m.subarray(d0, d0 + 0xe00)).digest("hex").slice(0, 16);
            if (DUMP && it >= DUMP[0] && it <= DUMP[1]) writeFileSync(`${a.out}/it-${it}-${n}.raw`, Buffer.concat([b0, b1]));
        }
        n++;
    }
    return false;
});
const t0 = Date.now();
while (cand.iter < TO) {
    injPoke(cand, csy);
    const r = cand.run(CYCLES_PER_FRAME);
    cand.snaps.length = 0;
    if (r === "blocked" && cand.blocked && cand.blocked.kind !== "tt170") { /* (the log has run out) */ if (cand.polls > Math.max(...L.rlog.keys())) break; }
}
writeFileSync(`${a.out}/fb.json`, JSON.stringify(res));
writeFileSync(`${a.out}/dash.json`, JSON.stringify(dres));
console.log("overlay loads (ovl_get by overlay: 1 D, 2 S, 4/5 the tails):", JSON.stringify(ovls));
if (csy.hp_drops !== undefined)   // (the disc heap's drops, and frames drawn without room: p-disc.asm)
    console.log(`disc heap: ${cand.ram[csy.hp_drops] + 256 * cand.ram[csy.hp_drops + 1]} drops, ${cand.ram[csy.hp_whole] + 256 * cand.ram[csy.hp_whole + 1]} frames drawn whole (no room)`);
console.log(`${Object.keys(res).length} frames hashed, iterations ${FROM}..${cand.iter}, ${((Date.now() - t0) / 1000).toFixed(0)} s`);
process.exit(0);
