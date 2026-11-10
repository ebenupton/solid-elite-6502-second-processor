#!/usr/bin/env node
// tsplit.mjs: where in the raster ACCCON D changes on the Master host (or in
// the Master port with --master): over a replay of an input log, every write
// that changes the display page is placed by the 6845's character row,
// scan line and character (R1 = 64 shown, then the border and blanking). The
// split at the panel's top (D = 1) must land in line 191's blanking: after
// row 23 line 7's last fetch, before row 24 line 0's first. Prints a
// histogram of the D = 1 writes' places and the count outside the window;
// at a late one, the panel's bytes shown from main RAM that differ from it.
// TRAIL=1: the host's PCs where timer 1 fired and before the write.
// PANEL=FILE: main then shadow RAM's &7000-&7DFF at the end.
//   node tube/tools/tsplit.mjs --log L --cand DISC --csyms SYMS --from I --to J [--master]
import { TubeEliteMachine, loadSyms, CYCLES_PER_FRAME } from "./tmachine.mjs";
import { EliteMachine } from "../../master/tools/agentplay/lib.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { readFileSync } from "fs";
const a = parseArgs({ log: "value", cand: "value", csyms: "value", from: "value", to: "value", master: "flag" });
const L = { rlog: new Map(), rjoy: [[], []], ptr: [0, 0], pokes: new Map(), header: null };
for (const l of readFileSync(a.log, "utf8").split("\n")) { if (!l) continue; const e = JSON.parse(l);
    if (e.header) L.header = e; else if (e.p !== undefined) L.rlog.set(e.p, e); else if (e.j !== undefined) L.rjoy[e.w].push([e.j, e.v]); else if (e.poke !== undefined) L.pokes.set(e.poke, e.v); }
const H = L.header, rand = seedBytes(H.seed), cmdr = COMMANDERS[H.commander || "jameson"], patch = cmdr.patch ? m => cmdr.patch(m) : null;
const ref = new EliteMachine({ name: "ref", disc: DEFAULTS.ref, syms: loadSyms(DEFAULTS.rsyms), input: { rdkey: () => [], dks5: () => false, joy: () => 0x80 }, rand, patch });
await ref.boot(); for (let k = 0; k < 10000 && !ref.started; k++) ref.run(CYCLES_PER_FRAME);
const input = { rdkey: ctx => L.rlog.get(ctx.poll)?.k || [], dks5: ctx => { const e = L.rlog.get(ctx.poll); return !!(e && e.t === "d"); },
    joy(ctx) { const l = L.rjoy[ctx.which]; while (L.ptr[ctx.which] + 1 < l.length && l[L.ptr[ctx.which] + 1][0] <= ctx.joy) L.ptr[ctx.which]++; const e = l[L.ptr[ctx.which]]; return e && e[0] <= ctx.joy ? e[1] : 0x80; } };
const M = a.master ? EliteMachine : TubeEliteMachine;
const cand = new M({ host: "Master", name: "cand", disc: a.cand, syms: loadSyms(a.csyms), rand, patch, seedFrom: ref, input });
await cand.boot(); cand.pokes = L.pokes;
const hm = a.master ? cand.cpu : cand.host, v = hm.video;
const FROM = +(a.from || 0), TO = +(a.to || 1000);
let last = hm.videoDisplayPage; const hist = new Map(); let late = 0, early = 0, n = 0; const ex = [];
const ring = []; let t1at = -1, t1pc = [];
hm.debugInstruction.add(pc => {
    ring.push(pc.toString(16) + (hm.p.i ? "i" : "")); if (ring.length > 40) ring.shift();
    if ((hm.sysvia.ifr & 0x40) && t1at < 0) { t1at = hm.currentCycles; t1pc = ring.slice(-8); }
    if (!(hm.sysvia.ifr & 0x40)) t1at = -1;
    const p = hm.videoDisplayPage;
    if (p !== last) {
        last = p;
        if (p === 0x8000 && cand.iter >= FROM) {
            const r = v.vertCounter, s = v.scanlineCounter, h = v.horizCounter;
            const key = `${r}.${s}.${h}`; hist.set(key, (hist.get(key) || 0) + 1); n++;
            const pos = (r * 8 + s) * 128 + h, lo = (23 * 8 + 7) * 128 + 64, hi = (24 * 8) * 128;
            if (pos >= hi && r < 30) { late++; if (ex.length < 12) ex.push(`${cand.iter}:${key}`); { const m = hm.ramRomOs, d = []; for (let l = 0; l <= s; l++) for (let c = 0; c < 64; c++) { if (l === s && c >= h) break; const o = 0x7000 + c * 8 + l; if (m[o] !== m[0x8000 + o]) d.push(`${o.toString(16)}:${m[o].toString(16)}/${m[0x8000 + o].toString(16)}`); } console.log(`late ${cand.iter} ${key}: bytes shown from main RAM that differ from the panel (main/shadow): ${d.length} ${d.slice(0, 40).join(" ")}`); }
            if (process.env.TRAIL) console.log(`late ${cand.iter} ${key}: timer 1 at ${t1pc.join(" ")}; trail ${ring.join(" ")}`); }
            else if (pos < lo && r >= 20) early++;
        }
    }
    return false;
});
while (cand.iter < TO) { const r = cand.run(CYCLES_PER_FRAME); cand.snaps.length = 0;
    if (r === "blocked" && cand.blocked && cand.blocked.kind !== "tt170") { if (cand.polls > Math.max(...L.rlog.keys())) break; } }
if (process.env.PANEL) (await import("fs")).writeFileSync(process.env.PANEL, Buffer.concat([hm.ramRomOs.subarray(0x7000, 0x7e00), hm.ramRomOs.subarray(0xf000, 0xfe00)]));   // (main RAM's &7000-&7DFF, then shadow's)
const keys = [...hist.keys()].sort((x, y) => { const f = k => k.split(".").map(Number); const [a1, b1, c1] = f(x), [a2, b2, c2] = f(y); return ((a1 * 8 + b1) * 128 + c1) - ((a2 * 8 + b2) * 128 + c2); });
console.log(keys.map(k => `${k}:${hist.get(k)}`).join(" "));
console.log(`D=1 writes ${n}, iterations ${FROM}-${cand.iter}: late (row 24 line 0 or after) ${late}, early ${early}${ex.length ? " (" + ex.join(" ") + ")" : ""}`);
process.exit(0);
