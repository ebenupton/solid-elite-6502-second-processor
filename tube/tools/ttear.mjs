#!/usr/bin/env node
// ttear.mjs (from tflips.mjs): tearing check. Over a replay window, every host
// write into the 3D view's memory of the buffer on show (Master: &4000-&6FFF of
// main RAM, or of shadow RAM when ACCCON D shows it; Model B: BUF0-&3FFF or
// &4000-&6FFF, as the 6845's address shows) while the 6845 is in the 3D view
// (its address is in a buffer, not the panel) and the host is in space mode
// (GMODE bit 7: double buffered) is counted: a front-buffer write the beam can
// still show. Prints the count and the first iterations.
//   node tube/tools/ttear.mjs --log L --cand DISC --csyms SYMS --host Master|B --from I --to J

import { TubeEliteMachine, loadSyms, CYCLES_PER_FRAME } from "./tmachine.mjs";
import { EliteMachine } from "../../master/tools/agentplay/lib.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { readFileSync } from "fs";

const a = parseArgs({ log: "value", cand: "value", csyms: "value", hsyms: "value", from: "value", to: "value", host: "value" });
if (!a.log || !a.cand || !a.csyms) { console.error("--log, --cand and --csyms are required"); process.exit(2); }

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
const GM = hsy.GMODE, video = cand.host.video, hm = cand.host;
const BLO = HB ? 0x1000 : 0x4000;
let bad = 0; const at = [];
hm.debugWrite.add((addr, b) => {
    if (cand.iter < FROM || addr < BLO || addr >= 0x7000) return false;
    if (!(hm.readmem(GM) & 0x80)) return false;
    // (the line on show: its start address, and only while the 6845 displays
    // it; the running address passes the line's end in the borders, which on
    // the Model B host reads as the other buffer, and counted back-buffer
    // writes there as tearing)
    if ((video.dispEnabled & 3) !== 3) return false;
    const scr = (video.lineStartAddr & 0xfff) << 3;
    if (scr < BLO || scr >= 0x7000) return false;   // (the panel)
    let front;
    if (HB) { front = scr < 0x4000 ? 0 : 1; if ((addr < 0x4000 ? 0 : 1) !== front) return false; }
    else {   // (physical page of this write: shadow is ramRomOs &8000-&FFFF; the video's page)
        const off = hm.memLook[hm.memStatOffset + (addr >>> 8)];
        const shadow = off === 0x8000 ? 1 : 0;
        if ((shadow ? 0x8000 : 0) !== hm.videoDisplayPage) return false;
    }
    bad++; if (at.length < 20) at.push(`${cand.iter}:${addr.toString(16)}@${scr.toString(16)}`);
    return false;
});
while (cand.iter < TO) {
    const r = cand.run(CYCLES_PER_FRAME);
    cand.snaps.length = 0;
    if (r === "blocked" && cand.blocked && cand.blocked.kind !== "tt170") { if (cand.polls > Math.max(...L.rlog.keys())) break; }
}
console.log(`front-buffer writes in the 3D view, iterations ${FROM}-${TO}: ${bad}${at.length ? " (" + at.join(" ") + ")" : ""}`);
process.exit(0);
