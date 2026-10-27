#!/usr/bin/env node
// tstore.mjs: the Master host's overlay storage checked against its image
// (build/hstore.bin, tube/build.sh) after a replay to iteration --to: any
// page that differs (S's state, stored elsewhere, aside) was written by
// something else on the host.
//   node tube/tools/tstore.mjs --log L --cand disc --csyms psyms --store hstore.bin [--to N]
import { TubeEliteMachine, loadSyms, CYCLES_PER_FRAME } from "./tmachine.mjs";
import { EliteMachine } from "../../master/tools/agentplay/lib.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { createHash } from "crypto";

const a = parseArgs({ store: "value", flip: "value", log: "value", out: "value", cand: "value", csyms: "value", from: "value", to: "value", host: "value", dumpn: "value", master: "flag", hsyms: "value" });
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
const TO = +(a.to || 1000);
while (cand.iter < TO) { const r = cand.run(CYCLES_PER_FRAME); cand.snaps.length = 0; if (r === "blocked" && cand.blocked && cand.blocked.kind !== "tt170") { if (cand.polls > Math.max(...L.rlog.keys())) break; } }
const st = readFileSync(a.store), h = cand.host, m = h.ramRomOs;
let bad = 0, n = 0;
for (let i = 0; i < st.length; i += 258, n++) {
    const rom = st[i], hi = st[i + 1], want = st.subarray(i + 2, i + 258);
    let base;
    if (hi < 0x80) base = hi * 256;                                   // main RAM
    else if (hi >= 0xC0) base = hi * 256 - 0x3000;                    // HAZEL (jsbeeb's ramRomOs &9000-&AFFF)
    else if (rom & 0x80 && hi < 0x90) base = hi * 256;                // ANDY (ramRomOs &8000-&8FFF)
    else base = h.romOffset + (rom & 15) * 16384 + (hi * 256 - 0x8000);
    let d = 0;
    if (rom & 0x40) {                                                 // (four 64-byte pieces: bytes 192-255
        const b7 = h.romOffset + (rom & 15) * 16384 + (hi * 256 - 0x8000);   // of four pages, h-main.asm's hov_pg)
        for (let k = 0; k < 256; k++) if (m[b7 + (k >> 6) * 256 + 192 + (k & 63)] !== want[k]) d++;
    } else for (let k = 0; k < 256; k++) if (m[base + k] !== want[k]) d++;
    if (d) { bad++; console.log(`slot ${n}: ROMSEL &${rom.toString(16)}, page &${hi.toString(16)}: ${d} bytes differ`); }
}
console.log(`storage: ${n} pages checked after iteration ${cand.iter}, ${bad} differ`);
process.exit(bad ? 1 : 0);
