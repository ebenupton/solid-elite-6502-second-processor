#!/usr/bin/env node
import { EliteMachine, loadSyms, CYCLES_PER_FRAME } from "./lib.mjs";
import { DEFAULTS, seedBytes, snapHash } from "./session.mjs";
import { COMMANDERS } from "./styles.mjs";
import { parseArgs } from "../../../harness/args.mjs";
import { readFileSync, writeFileSync, mkdirSync, openSync, readSync, fstatSync, closeSync, existsSync, appendFileSync } from "fs";
import { spawn } from "child_process";
import { mapAt } from "../../../harness/mlib.mjs";

const a = parseArgs({ log: "value", out: "value", cand: "value", csyms: "value", ref: "value", rsyms: "value", from: "value", to: "value", hashes: "value", follow: "flag", crf: "value", maxframes: "value", fps: "value", sparse: "value", journal: "value" });
if (!a.log || !a.from || !a.to || !a.cand || !a.csyms) { console.error("--log, --out, --cand and --csyms are required"); process.exit(2); }
if (!a.ref !== !a.rsyms) { console.error("--ref and --rsyms go together"); process.exit(2); }
const FFMPEG = "/opt/homebrew/bin/ffmpeg";
const OUT = a.out;
mkdirSync(OUT, { recursive: true });

// ---- the log, read as it grows
const L = { off: 0, rest: "", rlog: new Map(), rjoy: [[], []], ptr: [0, 0], pokes: new Map(), header: null, safePolls: 0, safeJoys: 0, end: null };
function readLog() {
    const fd = openSync(a.log, "r"), size = fstatSync(fd).size;
    if (size > L.off) {
        const buf = Buffer.alloc(size - L.off);
        readSync(fd, buf, 0, buf.length, L.off);
        L.off = size;
        const text = L.rest + buf.toString("utf8"), lines = text.split("\n");
        L.rest = lines.pop();
        for (const l of lines) {
            if (!l) continue;
            const e = JSON.parse(l);
            if (e.header) L.header = e;
            else if (e.p !== undefined) L.rlog.set(e.p, e);
            else if (e.j !== undefined) L.rjoy[e.w].push([e.j, e.v]);
            else if (e.poke !== undefined) L.pokes.set(e.poke, e.v);
            else if (e.mark) { L.safePolls = Math.max(L.safePolls, e.polls); L.safeJoys = Math.max(L.safeJoys, e.joys); }
            else if (e.end) { L.end = e; L.safePolls = e.polls ?? Infinity; L.safeJoys = e.joys ?? Infinity; }
        }
    }
    closeSync(fd);
    // (not following: the log is all there is)
    if (!a.follow && !L.end) { L.safePolls = Infinity; L.safeJoys = Infinity; }
}
readLog();
if (!L.header) { console.error("no header in", a.log); process.exit(2); }
const H = L.header;

// ---- the hashes, read as they grow
const HS = { off: 0, list: [], checked: 0, bad: 0, firstBad: null };
function readHashes() {
    if (!a.hashes || !existsSync(a.hashes)) return;
    const fd = openSync(a.hashes, "r"), size = fstatSync(fd).size & ~3;
    if (size > HS.off) {
        const buf = Buffer.alloc(size - HS.off);
        readSync(fd, buf, 0, buf.length, HS.off);
        HS.off = size;
        for (let i = 0; i < buf.length; i += 4) HS.list.push(buf.readUInt32LE(i));
    }
    closeSync(fd);
}

// ---- the machines
const rsy = loadSyms(a.rsyms || H.rsyms || DEFAULTS.rsyms), csy = loadSyms(a.csyms);
const rand = H.seed !== undefined && H.seed !== null ? seedBytes(H.seed) : null;
const cmdr = COMMANDERS[H.commander || "jameson"];
const patch = cmdr.patch ? m => cmdr.patch(m) : null;
const ref = new EliteMachine({ name: "ref", disc: a.ref || H.ref || DEFAULTS.ref, syms: rsy, input: { rdkey: () => [], dks5: () => false, joy: () => 0x80 }, rand, patch });
await ref.boot();
for (let k = 0; k < 10000 && !ref.started; k++) ref.run(CYCLES_PER_FRAME);
if (!ref.started) { console.error("the reference never reached TT170"); process.exit(2); }
const pending = [];     // the candidate's hashes not yet checked
const cand = new EliteMachine({ name: "cand", disc: a.cand, syms: csy, rand, patch, seedFrom: ref, workarounds: H.workarounds || [],
    input: {
        rdkey(ctx) {
            if (ctx.poll >= L.safePolls) return null;
            const e = L.rlog.get(ctx.poll);
            if (e && (e.t !== "r" || e.s !== ctx.site)) mismatch(ctx, e);
            return e?.k || [];
        },
        dks5(ctx) {
            if (ctx.poll >= L.safePolls) return null;
            const e = L.rlog.get(ctx.poll);
            if (e && (e.t !== "d" || e.key !== ctx.key)) mismatch(ctx, e);
            return !!(e && e.t === "d");
        },
        joy(ctx) {
            if (ctx.joy >= L.safeJoys) return null;
            const l = L.rjoy[ctx.which];
            while (L.ptr[ctx.which] + 1 < l.length && l[L.ptr[ctx.which] + 1][0] <= ctx.joy) L.ptr[ctx.which]++;
            const e = l[L.ptr[ctx.which]];
            return e && e[0] <= ctx.joy ? e[1] : 0x80;
        },
    } });
let mismatches = 0;
function mismatch(ctx, e) { if (mismatches++ < 5) console.log(`read ${ctx.poll} (iteration ${ctx.iter}): the log has ${JSON.stringify(e)}, the candidate made a ${ctx.kind} from ${ctx.site}`); }
await cand.boot();
cand.pokes = L.pokes;
console.log(`film: ${a.log} on ${a.cand}; seed ${H.seed}, commander ${H.commander}, mode ${H.mode}`);

// ---- capture
const sy = cand.sy, ram = cand.ram;
const at = (n, o = 0) => ram[(sy[n] + o) & 0xffff];

// ---- profile: cycles between consecutive instructions go to the earlier one, keyed by mapping and PC
const cpu = cand.cpu, FROM = +a.from, TO = +a.to;
const prof = new Map();
let last = -1, lastKey = 0, hook = null, c0 = 0, t0c = 0;
const startIter = new Map();
// (a row run's stores are charged to the routine that entered the run: "run<-caller")
const RUN0 = cand.sy.r_run0, runs = new Map();
let inRun = false, lastCtx = 0;
function onInstr(pc) {
    const now = cand.cyclesNow();
    if (last >= 0) { const m = inRun ? runs : prof; const k = inRun ? lastCtx : lastKey; m.set(k, (m.get(k) || 0) + now - last); }
    last = now;
    const hz = pc >= 0xc000 && pc < 0xe000 && (cpu.acccon & 8) ? 1 : 0;
    const key = (cpu.romsel & 0xff) * 0x40000 + hz * 0x10000 + pc;
    inRun = RUN0 !== undefined && (cpu.romsel & 15) === 5 && pc >= RUN0 && pc < RUN0 + 0x1800 && ((pc - RUN0) & 0xff) < 190;
    if (!inRun) { lastKey = key; lastCtx = key; }
    else lastKey = key;
}
for (;;) {
    const r = cand.run(CYCLES_PER_FRAME);
    cand.snaps.length = 0;
    if (!hook && cand.iter >= FROM) { hook = cpu.debugInstruction.add(onInstr); t0c = cand.cyclesNow(); c0 = cand.iter; console.log(`profiling from iteration ${cand.iter}`); }
    if (cand.iter >= TO) break;
    if (r === "blocked") { readLog(); if (L.end && cand.polls >= L.safePolls) break; }
}
const total = cand.cyclesNow() - t0c, iters = cand.iter - c0;
const byLab = new Map();
for (const [k, c] of prof) {
    const romsel = Math.floor(k / 0x40000), hz = (k >> 16) & 3, pc = k & 0xffff;
    let m = mapAt(romsel, pc);
    if (pc >= 0xc000 && pc < 0xe000) m = hz ? "hazel" : "mos";
    const lab = (m === "mos" ? "MOS" : (cand.labelOf(pc, hz ? romsel : romsel) || "?")) ;
    const key = `${m}:${lab}`;
    byLab.set(key, (byLab.get(key) || 0) + c);
}
for (const [k, c] of runs) {
    const romsel = Math.floor(k / 0x40000), pc = k & 0xffff;
    const key = `RUN<-${mapAt(romsel, pc)}:${cand.labelOf(pc, romsel) || "?"}`;
    byLab.set(key, (byLab.get(key) || 0) + c);
}
const rows = [...byLab].sort((x, y) => y[1] - x[1]);
const out = { from: c0, to: cand.iter, iters, cycles: total, seconds: total / 2e6, perIter: total / iters, rows: rows.map(([k, c]) => [k, c, +(100 * c / total).toFixed(2)]) };
writeFileSync(`${OUT}/prof.json`, JSON.stringify(out, null, 1));
console.log(`${iters} iterations, ${(total / 2e6).toFixed(2)} s, ${(total / iters).toFixed(0)} cycles an iteration`);
for (const [k, c] of rows.slice(0, 40)) console.log(`${(100 * c / total).toFixed(2).padStart(6)}%  ${(c / iters).toFixed(0).padStart(7)}  ${k}`);
process.exit(0);
