// tpprof.mjs: the parasite's time by routine (label) over a window of
// iterations of a replayed run, on the Tube build: instructions executed per
// label (a label's range runs to the next label), and how many of them are
// the polls that wait for the host (BIT on register 1 or 4 that loops).
//   node tube/tools/tpprof.mjs --log L --cand tube/build/elite-tube.ssd --csyms tube/build/psyms.txt --from 1000 --to 1400 [--host B] [--top 40]
import { EliteMachine, loadSyms, CYCLES_PER_FRAME } from "../../master/tools/agentplay/lib.mjs";
import { TubeEliteMachine } from "./tmachine.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { readFileSync } from "fs";
const a = parseArgs({ log: "value", host: "value", cand: "value", csyms: "value", from: "value", to: "value", top: "value" });
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
const FROM = +a.from, TO = +a.to, pm = m.t.par.memory;
const cnt = new Map(); let on = false, tot = 0, waits = 0;
// labels: the overlay region's by the overlay in (D: name_C), the rest as they are
const OS = sy.OVL_START, all = Object.entries(sy).filter(([k, v]) => v >= 0x0800 && !/^(CODE|LOAD)/.test(k));
const srt = l => l.sort((x, y) => x[1] - y[1]);
const LR = srt(all.filter(([k, v]) => v < OS || v >= 0xf800)), LS = srt(all.filter(([k, v]) => v >= OS && v < 0xf800 && !k.endsWith("_C"))),
    LD = srt(all.filter(([k, v]) => v >= OS && v < 0xf800 && k.endsWith("_C")));
const find = (lab, x) => { let lo = 0, hi = lab.length - 1, r = null; while (lo <= hi) { const k = (lo + hi) >> 1; if (lab[k][1] <= x) { r = lab[k][0]; lo = k + 1; } else hi = k - 1; } return r; };
const labelOf = x => x >= OS && x < 0xf800 ? (pm[sy.ovl_cur] === 1 ? find(LD, x) : find(LS, x)) : find(LR, x);
m.t.addParHook(pc => {
    if (!on) return false;
    tot++;
    if (pm[pc] === 0x2c && pm[pc + 2] === 0xfe && (pm[pc + 1] === 0xf8 || pm[pc + 1] === 0xfe)) { waits++; return false; }
    const k = labelOf(pc);
    cnt.set(k, (cnt.get(k) || 0) + 1);
    return false;
});
m.onIter = mm => { on = mm.iter >= FROM && mm.iter < TO; };
while (m.iter < TO) { m.run(CYCLES_PER_FRAME); m.snaps.length = 0; }
const it = TO - FROM;
console.log(`parasite: ${(tot / it).toFixed(0)} instructions an iteration, of them polls (waits for the host) ${(waits / it).toFixed(0)} (${(100 * waits / tot).toFixed(1)}%)`);
for (const [k, v] of [...cnt].sort((x, y) => y[1] - x[1]).slice(0, +(a.top || 40))) console.log(`${(100 * v / tot).toFixed(1).padStart(5)}% ${(v / it).toFixed(0).padStart(7)}  ${k}`);
process.exit(0);
