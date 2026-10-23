// hcov.mjs: the host's labels that run over a replayed run (Tube build), and
// those that never do (the host shrink: dead code), by bank.
//   node tube/tools/thprof.mjs --log L --cand tube/build/elite-tube.ssd --csyms tube/build/psyms.txt --hsyms tube/build/hsyms.txt --from 3420 --to 3550
import { EliteMachine, loadSyms, CYCLES_PER_FRAME } from "../../master/tools/agentplay/lib.mjs";
import { TubeEliteMachine } from "./tmachine.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { readFileSync } from "fs";
const a = parseArgs({ log: "value", host: "value", cand: "value", csyms: "value", hsyms: "value", from: "value", to: "value", top: "value" });
const L = { rlog: new Map(), rjoy: [[], []], header: null };
for (const l of readFileSync(a.log, "utf8").split("\n")) { if (!l) continue; const e = JSON.parse(l); if (e.header) L.header = e; else if (e.p !== undefined) L.rlog.set(e.p, e); else if (e.j !== undefined) L.rjoy[e.w].push([e.j, e.v]); }
const H = L.header, rand = seedBytes(H.seed), cmdr = COMMANDERS[H.commander || "jameson"], patch = cmdr.patch ? m => cmdr.patch(m) : null;
const ptr = [0, 0];
const input = { rdkey: ctx => L.rlog.get(ctx.poll)?.k || [], dks5: ctx => { const e = L.rlog.get(ctx.poll); return !!(e && e.t === "d"); },
    joy(ctx) { const l = L.rjoy[ctx.which]; while (ptr[ctx.which] + 1 < l.length && l[ptr[ctx.which] + 1][0] <= ctx.joy) ptr[ctx.which]++; const e = l[ptr[ctx.which]]; return e && e[0] <= ctx.joy ? e[1] : 0x80; } };
const ref = new EliteMachine({ name: "ref", disc: DEFAULTS.ref, syms: loadSyms(DEFAULTS.rsyms), input: { rdkey: () => [], dks5: () => false, joy: () => 0x80 }, rand, patch });
await ref.boot(); for (let k = 0; k < 10000 && !ref.started; k++) ref.run(CYCLES_PER_FRAME);
const psy = loadSyms(a.csyms), hsy = loadSyms(a.hsyms);
const m = new TubeEliteMachine({ host: a.host || "Master", name: "t", disc: a.cand, syms: psy, rand, patch, seedFrom: ref, input });
await m.boot();
const FROM = +a.from, TO = +a.to;
// labels: main RAM, and the sideways banks by ROMSEL (bank 5 code, ANDY when bit 7, bank 6)
const hb = {};
for (const l of readFileSync(a.hsyms.replace(/hsyms\.txt$/, "hbanks.txt"), "utf8").split("\n")) { const [n, b] = l.split(" "); if (n) hb[n] = b; }
const mapOf = (k, v) => v < 0x8000 || v >= 0xc000 ? "m" : hb[k] === "85" ? (v < 0x9000 ? "85" : "5") : hb[k] || "?";
const LB = {};
for (const [k, v] of Object.entries(hsy)) { if (/^(CODE|LOAD|B5_|B6_|RA_)/.test(k)) continue; (LB[mapOf(k, v)] ||= []).push([k, v]); }
for (const l of Object.values(LB)) l.sort((x, y) => x[1] - y[1]);
const near = (pc, map) => { const labs = LB[map] || []; let lo = 0, hi = labs.length - 1, r = null; while (lo <= hi) { const k = (lo + hi) >> 1; if (labs[k][1] <= pc) { r = labs[k][0]; lo = k + 1; } else hi = k - 1; } return r; };
const host = m.host, cnt = new Map(); let last = null, lastC = 0, on = false, tot = 0;
const now = () => host.cycleSeconds * 2e6 + host.currentCycles;
host.debugInstruction.add(pc => {
    if (!on) return false;
    const c = now();
    if (last !== null) { cnt.set(last, (cnt.get(last) || 0) + c - lastC); tot += c - lastC; }
    if (pc >= 0xc300 && pc < 0xd000) last = "Z:" + near(pc, "m");   // (HAZEL: the kept spans, h-spank.asm)
    else if (pc >= 0xc000) last = "MOS";
    else if (pc < 0x8000) last = near(pc, "m");
    else { const map = pc < 0x9000 && host.romsel & 0x80 ? "85" : String(host.romsel & 15); last = `${map}:${near(pc, map)}`; }
    lastC = c; return false;
});
m.onIter = mm => { on = mm.iter >= FROM && mm.iter < TO; };
while (m.iter < TO) { m.run(CYCLES_PER_FRAME); m.snaps.length = 0; }
const ran = new Set(cnt.keys());
for (const [map, labs] of Object.entries(LB)) for (const [k, v] of labs) { const key = map === "m" ? (v >= 0xc300 && v < 0xd000 ? "Z:" + k : k) : map + ":" + k; console.log(ran.has(key) ? "RAN " : "DEAD", map, v.toString(16), k); }
process.exit(0);
