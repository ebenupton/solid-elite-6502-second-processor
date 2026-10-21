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
import { TubeEliteMachine, loadSyms, CYCLES_PER_FRAME } from "../tools/tmachine.mjs";
import { EliteMachine } from "../../master/tools/agentplay/lib.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { createHash } from "crypto";

const a = parseArgs({ log: "value", out: "value", cand: "value", csyms: "value", from: "value", to: "value", host: "value", dumpn: "value", master: "flag", hsyms: "value" });
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
        rdkey(ctx) { return L.rlog.get(ctx.poll)?.k || []; },
        dks5(ctx) { const e = L.rlog.get(ctx.poll); return !!(e && e.t === "d"); },
        joy(ctx) { const l = L.rjoy[ctx.which]; while (L.ptr[ctx.which] + 1 < l.length && l[L.ptr[ctx.which] + 1][0] <= ctx.joy) L.ptr[ctx.which]++; const e = l[L.ptr[ctx.which]]; return e && e[0] <= ctx.joy ? e[1] : 0x80; },
    } });
await cand.boot();
cand.pokes = L.pokes;
const FROM = +(a.from || 0), TO = +(a.to || 1000);
const hsy = loadSyms(a.hsyms || a.csyms.replace(/psyms\.txt$/, a.host === "B" ? "hbmsyms.txt" : "hsyms.txt"));
const q = [], res = {};
let n = 0;
cand.t.addParHook(pc => { if (pc === csy.p_sync) q.push(cand.iter); return false; });
const host = cand.host;
let syncSeen = false;
const polys = {}; let cur = [], cmds = {}, pend = false, seq = [];
const M = host.ramRomOs; const spans = []; let fsp = [];
host.debugInstruction.add(pc => {
    if (pc === hsy.hlp2) { const x = host.x; cmds[x] = (cmds[x] || 0) + 1; seq.push(x/2); }
    if ((pc === hsy.pb_d2_e || pc === hsy.pb_d2_o) && (host.romsel & 0x80)) { fsp.push([host.y, host.x, M[9], pc === hsy.pb_d2_e ? M[0x18] : M[0x19]]); }
    if (pc === hsy.T_LINE) { const r = []; for (let i = 0; i < 8; i += 2) { let v = M[0x1000 + i] | M[0x1001 + i] << 8; if (v > 32767) v -= 65536; r.push(v); } fsp.push(["L", ...r]); }
    if (pc === hsy.h_poly) pend = true;
    else if (pend && pc === hsy.hloop) { pend = false; cur.push([M[hsy.R_PYS], M[hsy.R_PYL1], M[hsy.R_PXC]]); }
    return false;
});
host.debugInstruction.add(pc => {
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
            polys[`${it}.${n}`] = { p: cur, c: cmds, s: seq, sp: fsp, nd: [M[hsy.R_NDT], M[hsy.R_NDB]] };
            if (DUMP && it >= DUMP[0] && it <= DUMP[1]) writeFileSync(`${a.out}/it-${it}-${n}.raw`, Buffer.concat([b0, b1]));
        }
        n++; cur = []; cmds = {}; seq = []; fsp = [];
    }
    return false;
});
const t0 = Date.now();
while (cand.iter < TO) {
    const r = cand.run(CYCLES_PER_FRAME);
    cand.snaps.length = 0;
    if (r === "blocked" && cand.blocked && cand.blocked.kind !== "tt170") { /* (the log has run out) */ if (cand.polls > Math.max(...L.rlog.keys())) break; }
}
writeFileSync(`${a.out}/fb.json`, JSON.stringify(res));
writeFileSync(`${a.out}/polys.json`, JSON.stringify(polys));
console.log(`${Object.keys(res).length} frames hashed, iterations ${FROM}..${cand.iter}, ${((Date.now() - t0) / 1000).toFixed(0)} s`);
process.exit(0);
