// ttext.mjs: the text's share of the Tube's command stream over a replayed run.
// Per screen (each TT66, the screen's clear, starts one; named by QQ11): the
// bytes through register 1, of them the text's (C_CHAR and C_GLYPH), the
// recursive tokens' fetches through register 4 (ex's C_TOKEN, both ways), and
// the draw time: from TT66 to
// the parasite's next key poll, and to the host's drain after it (the host in
// hloop with register 1 empty and the parasite out of ring mode). Per flight
// window: bytes an iteration, text bytes an iteration.
//   TUBEMHZ=4 node tube/tools/ttext.mjs --log L --cand D/elite-tube.ssd --csyms D/psyms.txt --hsyms D/hsyms.txt [--host B] --to 6000 [--windows 1000-1400]
import { EliteMachine, loadSyms, CYCLES_PER_FRAME } from "../../master/tools/agentplay/lib.mjs";
import { TubeEliteMachine } from "./tmachine.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { readFileSync } from "fs";
const a = parseArgs({ log: "value", host: "value", cand: "value", csyms: "value", hsyms: "value", to: "value", windows: "value", json: "value" });
const L = { rlog: new Map(), rjoy: [[], []], header: null };
for (const l of readFileSync(a.log, "utf8").split("\n")) { if (!l) continue; const e = JSON.parse(l); if (e.header) L.header = e; else if (e.p !== undefined) L.rlog.set(e.p, e); else if (e.j !== undefined) L.rjoy[e.w].push([e.j, e.v]); }
const H = L.header, rand = seedBytes(H.seed), cmdr = COMMANDERS[H.commander || "jameson"], patch = cmdr.patch ? m => cmdr.patch(m) : null;
const ptr = [0, 0];
const input = { rdkey: ctx => L.rlog.get(ctx.poll)?.k || [], dks5: ctx => { const e = L.rlog.get(ctx.poll); return !!(e && e.t === "d"); },
    joy(ctx) { const l = L.rjoy[ctx.which]; while (ptr[ctx.which] + 1 < l.length && l[ptr[ctx.which] + 1][0] <= ctx.joy) ptr[ctx.which]++; const e = l[ptr[ctx.which]]; return e && e[0] <= ctx.joy ? e[1] : 0x80; } };
const ref = new EliteMachine({ name: "ref", disc: DEFAULTS.ref, syms: loadSyms(DEFAULTS.rsyms), input: { rdkey: () => [], dks5: () => false, joy: () => 0x80 }, rand, patch });
await ref.boot(); for (let k = 0; k < 10000 && !ref.started; k++) ref.run(CYCLES_PER_FRAME);
const sy = loadSyms(a.csyms), hs = loadSyms(a.hsyms || a.csyms.replace(/psyms/, a.host === "B" ? "hbmsyms" : "hsyms"));
const m = new TubeEliteMachine({ host: a.host || "Master", name: "t", disc: a.cand, syms: sy, rand, patch, seedFrom: ref, input });
await m.boot();
const par = m.t.par, pm = par.memory, tube = m.t.tube, host = m.host;
const TO = +(a.to || 6000);
const W = (a.windows || "1000-1400").split(",").map(s => s.split("-").map(Number));

// the text's send sites: each a [pc, bytes] (bytes: a number, or a function
// of the parasite's state at the site)
const TEXT = new Map();
const site = (n, b) => { if (sy[n] !== undefined) TEXT.set(sy[n], b); };
site("pchr", 9);                   // C_CHAR (the original's form: 9 bytes)
if (sy.f_glyph !== undefined) {    // C_GLYPH: f_glyph's LDA #C_GLYPH in overlay S
    for (let p = sy.f_glyph; p < sy.f_glyph + 64; p++) if (pm[p] === 0xa9 && pm[p + 1] === 88 && pm[p + 2] === 0x20) { TEXT.set(-p, 4); break; }
}
const glyphAt = [...TEXT.keys()].find(k => k < 0);
const SCR = {};
for (const n of ["TT167", "STATUS", "TT25", "TT213", "TT22", "TT23", "EQSHP", "TT219", "TT208", "BRIEF", "DEBRIEF", "BRIEF2", "BRIEF3", "DEBRIEF2", "TITLE", "SVE", "TT110", "hyp", "MT23", "TBRIEF", "PDESC", "BRP", "BRPS"]) if (sy[n] !== undefined) SCR[sy[n]] = n;

let total = 0, text = 0, tok = 0;   // (tok: the token fetches' bytes through register 4, both ways: ex's C_TOKEN)
const QN = { 0: "space", 1: "data", 2: "buy", 3: "misjump", 4: "sell", 8: "status/inv", 13: "ship", 16: "market", 32: "equip", 64: "long chart", 128: "short chart", 255: "launch" };
const eps = []; let ep = null;
m.t.addParHook(pc => {
    const op = pm[pc];   // (a byte through register 1: STA, STX or STY &FEF9, as every send site and the ring's IRQ write it)
    if ((op === 0x8d || op === 0x8e || op === 0x8c) && pm[pc + 1] === 0xf9 && pm[pc + 2] === 0xfe) total++;
    if (pc === sy.ex && sy.ext1 !== undefined) tok += 2;
    if (pc === sy.ext1) tok++;
    let b = TEXT.get(pc);
    if (b === undefined && glyphAt !== undefined && pc === -glyphAt && pm[sy.ovl_cur] !== 1) b = 4;
    if (b !== undefined) text += typeof b === "function" ? b() : b;
    if (pc === sy.TT66 && m.started) {
        ep = { tok0: tok, hidle0: hidle, iter: m.iter, t0: m.cyclesNow(), tot0: total, txt0: text, polls: m.polls, names: [], poll: null, drain: null };
        eps.push(ep);
    }
    if (ep && SCR[pc] && !ep.names.includes(SCR[pc])) ep.names.push(SCR[pc]);
    return false;
});
const hloop = hs.hloop, rmode = sy.rmode;
// the host's idle cycles (in hloop with nothing in registers 1 and 2) while a screen is drawn
let hidle = 0, hlastC = 0, hwasIdle = false;
host.debugInstruction.add(pc => {
    const c = m.cyclesNow();
    if (hwasIdle) hidle += c - hlastC;
    hlastC = c;
    hwasIdle = pc >= hloop && pc < hloop + 8 && !(tube.hostStatus[0] & 0x80) && !(tube.hostStatus[1] & 0x80);
    return false;
});
const at = [], tt = [], tx = [];
m.onIter = mm => { at[mm.iter] = mm.cyclesNow(); tt[mm.iter] = total; tx[mm.iter] = text; };
while (m.iter <= TO) {
    m.run(ep && ep.drain === null ? 2000 : CYCLES_PER_FRAME);
    m.snaps.length = 0;
    if (ep && ep.poll === null && m.polls !== ep.polls) { ep.poll = m.cyclesNow() - ep.t0; ep.qq11 = pm[sy.QQ11]; }
    if (ep && ep.poll !== null && ep.drain === null && host.pc >= hloop && host.pc < hloop + 8 && !(tube.hostStatus[0] & 0x80) && !(pm[rmode] & 0x80)) {
        ep.drain = m.cyclesNow() - ep.t0; ep.hid = hidle - ep.hidle0; ep.tk = tok - ep.tok0; ep.tot = total - ep.tot0; ep.txt = text - ep.txt0;
    }
}
const ms = c => (c / 2000).toFixed(1);
console.log("iter   screen        bytes   text  to-poll-ms  drained-ms  host-idle-ms  token-R4");
for (const e of eps) if (e.drain !== null) console.log(`${String(e.iter).padStart(5)}  ${(QN[e.qq11] ?? "&" + e.qq11.toString(16)).padEnd(12)} ${String(e.tot).padStart(6)} ${String(e.txt).padStart(6)}  ${ms(e.poll).padStart(9)}  ${ms(e.drain).padStart(9)}  ${ms(e.hid).padStart(9)}  ${String(e.tk).padStart(6)}`);
for (const [x, y] of W) if (at[y] !== undefined)
    console.log(`flight ${x}-${y}: ${((tt[y] - tt[x]) / (y - x)).toFixed(0)} bytes an iteration, text ${((tx[y] - tx[x]) / (y - x)).toFixed(1)}; ${((y - x) * 2e6 / (at[y] - at[x])).toFixed(2)} it/s`);
console.log(`0-${TO}: ${total} bytes, text ${text} (${(100 * text / total).toFixed(1)}%); token fetches through register 4: ${tok} bytes`);
process.exit(0);
