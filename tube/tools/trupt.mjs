#!/usr/bin/env node
// trupt.mjs: the Model B host's split screen (the CRTC vertical rupture,
// tube/src/hb-irq.asm, tube/spike/rupture.asm) checked over a replay window.
// Per field (vsync to vsync) it records the 6845's frames as jsbeeb runs them:
// each frame's start address, its length in scan lines, the character row where
// its display ended (R6), and where in the field the vsync came; and every write
// to R4, R6, R7, R12 and R13 with its line in the field. A field's signature is
// its frames and vsync; the report gives each signature's count (the rupture
// is right when there are only the two, frame A of a buffer then frame B of
// the panel, whichever buffer is shown) and each register write's earliest and
// latest line, by the frame it was written in. With --shots I,J,... it also
// saves the rendered picture (jsbeeb's, as the monitor shows it) at those
// iterations, to DIR/rupt-I.png, and its raw pixels to DIR/rupt-I.raw.
//   TUBEMHZ=3 node tube/tools/trupt.mjs --log L --cand DISC --csyms SYMS
//        --from I --to J [--shots I,J] [--out DIR]
import { TubeEliteMachine, loadSyms, CYCLES_PER_FRAME } from "./tmachine.mjs";
import { EliteMachine } from "../../master/tools/agentplay/lib.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { readFileSync, writeFileSync, mkdirSync } from "fs";

const a = parseArgs({ log: "value", cand: "value", csyms: "value", from: "value", to: "value", shots: "value", out: "value" });
if (!a.log || !a.cand || !a.csyms) { console.error("--log, --cand and --csyms are required"); process.exit(2); }
const FROM = +(a.from || 1000), TO = +(a.to || 1100);
const SHOTS = new Set((a.shots || "").split(",").filter(Boolean).map(Number));
const OUT = a.out || "scratch/trupt"; mkdirSync(OUT, { recursive: true });

const L = { rlog: new Map(), rjoy: [[], []], header: null };
for (const l of readFileSync(a.log, "utf8").split("\n")) { if (!l) continue; const e = JSON.parse(l); if (e.header) L.header = e; else if (e.p !== undefined) L.rlog.set(e.p, e); else if (e.j !== undefined) L.rjoy[e.w].push([e.j, e.v]); }
const H = L.header, rand = seedBytes(H.seed), cmdr = COMMANDERS[H.commander || "jameson"], patch = cmdr.patch ? m => cmdr.patch(m) : null;
const input = () => { const ptr = [0, 0]; return { rdkey: ctx => L.rlog.get(ctx.poll)?.k || [], dks5: ctx => { const e = L.rlog.get(ctx.poll); return !!(e && e.t === "d"); },
    joy(ctx) { const l = L.rjoy[ctx.which]; while (ptr[ctx.which] + 1 < l.length && l[ptr[ctx.which] + 1][0] <= ctx.joy) ptr[ctx.which]++; const e = l[ptr[ctx.which]]; return e && e[0] <= ctx.joy ? e[1] : 0x80; } }; };
const ref = new EliteMachine({ name: "ref", disc: DEFAULTS.ref, syms: loadSyms(DEFAULTS.rsyms), input: { rdkey: () => [], dks5: () => false, joy: () => 0x80 }, rand, patch });
await ref.boot(); for (let k = 0; k < 10000 && !ref.started; k++) ref.run(CYCLES_PER_FRAME);
const m = new TubeEliteMachine({ host: "B", name: "t", disc: a.cand, syms: loadSyms(a.csyms), rand, patch, seedFrom: ref, input: input() });
await m.boot();

const v = m.s._video, LINE = 128;          // (host cycles a scan line: 64 us at 2 MHz)
let on = false, field = null, frame = null;
const sigs = new Map(), writes = new Map(), bad = [];
let fields = 0;
const now = () => m.cyclesNow();
const line = () => field ? Math.round((now() - field.t0) / LINE) : -1;
function endField(t) {
    if (field && on) {
        if (frame) { frame.len = Math.round((t - frame.t0) / LINE); field.frames.push(frame); }
        const sig = field.frames.map(f => `${f.kind}:${f.len}${f.dend !== undefined ? "/d" + f.dend : ""}`).join(" ");
        const e = sigs.get(sig) || { n: 0, first: m.iter }; e.n++; sigs.set(sig, e); fields++;
        if (sigs.size > 8 && bad.length < 5) bad.push(`${m.iter}: ${sig}`);
    }
    field = { t0: t, frames: [] }; frame = null;
}
const kindOf = sa => sa === (0x1000 >> 3) ? "buf0" : sa === (0x4000 >> 3) ? "buf1" : sa === (0x7000 >> 3) ? "panel" : "&" + (sa << 3).toString(16);
const eof = v.endOfFrame.bind(v);
v.endOfFrame = function () {
    const t = now();
    eof();
    if (!field) return;
    if (frame) { frame.len = Math.round((t - frame.t0) / LINE); field.frames.push(frame); }
    frame = { t0: t, kind: kindOf(v.lineStartAddr) + `@${Math.round((t - field.t0) / LINE)}`, r: [v.regs[4], v.regs[6], v.regs[7]] };
};
const dc = v.dispEnableClear.bind(v);
v.dispEnableClear = function (x) { if (frame && frame.dend === undefined && v.vertCounter === v.regs[6] && v.vertCounter > 0) frame.dend = v.vertCounter; return dc(x); };
const sv = v.sysvia, svb = sv.setVBlankInt.bind(sv);
sv.setVBlankInt = function (lvl) { if (lvl) endField(now()); return svb(lvl); };
const cw = v.crtc.write.bind(v.crtc);
v.crtc.write = function (addr, val) {
    if ((addr & 1) && on && field && [4, 6, 7, 12, 13].includes(v.crtc.curReg)) {
        const k = `R${v.crtc.curReg}=${val} in ${frame ? frame.kind.split("@")[0].replace(/buf./, "buf") : "?"}`;
        const l = line(), e = writes.get(k) || { n: 0, lo: 1e9, hi: -1 };
        e.n++; e.lo = Math.min(e.lo, l); e.hi = Math.max(e.hi, l); writes.set(k, e);
    }
    return cw(addr, val);
};

m.onIter = mm => { if (mm.iter >= FROM) on = true; };
while (m.iter <= TO) {
    m.run(CYCLES_PER_FRAME); m.snaps.length = 0;
    if (SHOTS.has(m.iter)) {
        SHOTS.delete(m.iter);
        v.frameSkipCount = 1; m.run(CYCLES_PER_FRAME * 2); v.frameSkipCount = 25;
        writeFileSync(`${OUT}/rupt-${m.iter}.png`, await m.s.screenshot());
        writeFileSync(`${OUT}/rupt-${m.iter}.raw`, Buffer.from(m.s._completeFb8 || []));
    }
}
console.log(`fields ${fields} (iterations ${FROM}-${TO}); signatures (frame:lines/display end row; @ the line in the field where it starts):`);
for (const [s, e] of [...sigs.entries()].sort((x, y) => y[1].n - x[1].n)) console.log(`  ${String(e.n).padStart(6)}  ${s}   (first at iteration ${e.first})`);
console.log("register writes (lines in the field: earliest-latest):");
for (const [k, e] of [...writes.entries()].sort()) console.log(`  ${k.padEnd(22)} ${String(e.n).padStart(6)}  ${e.lo}-${e.hi}`);
if (bad.length) console.log("unexpected:", bad.join("; "));
process.exit(0);
