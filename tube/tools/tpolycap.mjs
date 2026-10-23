// tpolycap.mjs: the polygons the parasite's R_POLY is given over a replayed
// run (each T_POLY's inputs: vertices, clip window, colours), one JSON object
// a line, distinct ones only, for test_onepass.py --tube --corpus
//   node tube/tools/tpolycap.mjs --log L --cand tube/build/elite-tube.ssd --csyms tube/build/psyms.txt --from 0 --to 6000 --out F
import { EliteMachine, loadSyms, CYCLES_PER_FRAME } from "../../master/tools/agentplay/lib.mjs";
import { TubeEliteMachine } from "./tmachine.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { readFileSync, writeFileSync } from "fs";
const a = parseArgs({ log: "value", host: "value", cand: "value", csyms: "value", from: "value", to: "value", out: "value" });
const L = { rlog: new Map(), rjoy: [[], []], header: null };
for (const l of readFileSync(a.log, "utf8").split("\n")) { if (!l) continue; const e = JSON.parse(l); if (e.header) L.header = e; else if (e.p !== undefined) L.rlog.set(e.p, e); else if (e.j !== undefined) L.rjoy[e.w].push([e.j, e.v]); }
const H = L.header, rand = seedBytes(H.seed), cmdr = COMMANDERS[H.commander || "jameson"], patch = cmdr.patch ? m => cmdr.patch(m) : null;
const ptr = [0, 0];
const input = { rdkey: ctx => L.rlog.get(ctx.poll)?.k || [], dks5: ctx => { const e = L.rlog.get(ctx.poll); return !!(e && e.t === "d"); },
    joy(ctx) { const l = L.rjoy[ctx.which]; while (ptr[ctx.which] + 1 < l.length && l[ptr[ctx.which] + 1][0] <= ctx.joy) ptr[ctx.which]++; const e = l[ptr[ctx.which]]; return e && e[0] <= ctx.joy ? e[1] : 0x80; } };
const ref = new EliteMachine({ name: "ref", disc: DEFAULTS.ref, syms: loadSyms(DEFAULTS.rsyms), input: { rdkey: () => [], dks5: () => false, joy: () => 0x80 }, rand, patch });
await ref.boot(); for (let k = 0; k < 10000 && !ref.started; k++) ref.run(CYCLES_PER_FRAME);
const sy = loadSyms(a.csyms);
const m = new TubeEliteMachine({ host: a.host || "Master", name: "t", disc: a.cand, syms: sy, rand, patch, seedFrom: ref, input });
await m.boot();
const FROM = +a.from, TO = +a.to, pm = m.t.par.memory, seen = new Set(), out = [];
let on = false, total = 0;
m.t.addParHook(pc => {
    if (!on || pc !== sy.T_POLY) return false;
    total++;
    const n = pm[sy.R_PN], k = Math.min(n, 16), s16 = (lo, hi) => { const v = lo | hi << 8; return v >= 0x8000 ? v - 0x10000 : v; };
    const xs = [], ys = [];
    for (let j = 0; j < k; j++) { xs.push(s16(pm[sy.R_PXL + j], pm[sy.R_PXH + j])); ys.push(s16(pm[sy.R_PYL + j], pm[sy.R_PYH + j])); }
    const d = { xs, ys, clip: [pm[0x0a], pm[0x0b], pm[0x0c], pm[0x0d]], cols: [pm[6], pm[7], pm[sy.R_COL2], pm[sy.R_COL3]], n, it: m.iter, k: pm[sy.KMODE] >> 7 };
    const key = JSON.stringify([xs, ys, d.clip]);
    if (!seen.has(key)) { seen.add(key); out.push(JSON.stringify(d)); }
    return false;
});
m.onIter = mm => { on = mm.iter >= FROM && mm.iter < TO; };
while (m.iter < TO) { m.run(CYCLES_PER_FRAME); m.snaps.length = 0; }
writeFileSync(a.out, out.join("\n") + "\n");
console.log(`T_POLY calls ${total}, distinct ${out.length}, iterations ${FROM}-${TO}`);
process.exit(0);
