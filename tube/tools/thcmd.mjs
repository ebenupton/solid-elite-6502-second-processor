#!/usr/bin/env node
// thcmd.mjs: the host's cycles by command, by routine and by kind of work, and
// the parasite's waits on the host, over windows of a replayed run, on either
// host: for comparing the two hosts (or two builds of one) like for like, as
// both run the same parasite and so get the same command stream.
//
// Per window and per iteration (averaged): the host's cycles
//   * by state: a command (from hdisp, the opcode's name, to the next hloop),
//     the loop's idle polls (hloop: nothing to read), a command's waits for
//     its next byte (hrw, from HRX), the IRQ (from the MOS's
//     entry to its RTI, by the first host label it reaches: the requests,
//     the rupture's timer, vsync, sound), the MOS outside an IRQ;
//   * by routine (the host label at or below the PC, with its bank);
//   * by kind of instruction across all of them: paging (stores to ROMSEL,
//     &F4, ACCCON), the Tube's registers (any access to &FEE0-&FEE7), the
//     waits for the vsync (as pwait.mjs: LDA/BNE spins on the flip's flag);
// and the parasite's cycles by state: running, waiting for a full ring (rpg,
// ppump), for the flip (p_buf's pfwait), on register 1 full outside the
// ring, on register 4 (requests), in the overlay loads.
//   TUBEMHZ=3 node tube/tools/thcmd.mjs --log L --cand ssd --csyms psyms [--host B]
//        --windows 1000-1400,... --out x.json
// Compare two outputs with --cmp A.json --with B.json [--window W] [--top N].
import { readFileSync, writeFileSync } from "fs";
import { parseArgs } from "../../harness/args.mjs";
const a = parseArgs({ log: "value", host: "value", cand: "value", csyms: "value", hsyms: "value", windows: "value", out: "value", cmp: "value", with: "value", window: "value", top: "value" });

if (a.cmp) {
    const [fa, fb] = [a.cmp, a.with];
    const A = JSON.parse(readFileSync(fa, "utf8")), B = JSON.parse(readFileSync(fb, "utf8"));
    const top = +(a.top || 30);
    for (const w of Object.keys(A)) {
        if (a.window && w !== a.window) continue;
        const x = A[w], y = B[w]; if (!y) continue;
        console.log(`\n== window ${w}: host cycles an iteration ${x.tot.toFixed(0)} / ${y.tot.toFixed(0)} (diff ${(y.tot - x.tot).toFixed(0)}); iterations' wall ${x.wall.toFixed(0)} / ${y.wall.toFixed(0)}`);
        const show = (title, f) => {
            const X = x[f], Y = y[f], ks = [...new Set([...Object.keys(X), ...Object.keys(Y)])];
            const rows = ks.map(k => [k, X[k] || 0, Y[k] || 0]).sort((p, q) => Math.abs(q[2] - q[1]) - Math.abs(p[2] - p[1]));
            console.log(`-- ${title}`);
            for (const [k, u, v] of rows.slice(0, top)) console.log(`  ${k.padEnd(34)} ${u.toFixed(0).padStart(8)} ${v.toFixed(0).padStart(8)} ${(v - u).toFixed(0).padStart(8)}`);
        };
        show("state (host cycles an iteration: A, B, B - A)", "state");
        show("kind", "kind");
        show("command calls an iteration", "ncmd");
        show("routine", "lab");
        show("parasite (its cycles an iteration)", "par");
    }
    process.exit(0);
}

const { EliteMachine, loadSyms, CYCLES_PER_FRAME } = await import("../../master/tools/agentplay/lib.mjs");
const { TubeEliteMachine } = await import("./tmachine.mjs");
const { DEFAULTS, seedBytes } = await import("../../master/tools/agentplay/session.mjs");
const { COMMANDERS } = await import("../../master/tools/agentplay/styles.mjs");
const L = { rlog: new Map(), rjoy: [[], []], header: null };
for (const l of readFileSync(a.log, "utf8").split("\n")) { if (!l) continue; const e = JSON.parse(l); if (e.header) L.header = e; else if (e.p !== undefined) L.rlog.set(e.p, e); else if (e.j !== undefined) L.rjoy[e.w].push([e.j, e.v]); }
const H = L.header, rand = seedBytes(H.seed), cmdr = COMMANDERS[H.commander || "jameson"], patch = cmdr.patch ? m => cmdr.patch(m) : null;
const ptr = [0, 0];
const input = { rdkey: ctx => L.rlog.get(ctx.poll)?.k || [], dks5: ctx => { const e = L.rlog.get(ctx.poll); return !!(e && e.t === "d"); },
    joy(ctx) { const l = L.rjoy[ctx.which]; while (ptr[ctx.which] + 1 < l.length && l[ptr[ctx.which] + 1][0] <= ctx.joy) ptr[ctx.which]++; const e = l[ptr[ctx.which]]; return e && e[0] <= ctx.joy ? e[1] : 0x80; } };
const ref = new EliteMachine({ name: "ref", disc: DEFAULTS.ref, syms: loadSyms(DEFAULTS.rsyms), input: { rdkey: () => [], dks5: () => false, joy: () => 0x80 }, rand, patch });
await ref.boot(); for (let k = 0; k < 10000 && !ref.started; k++) ref.run(CYCLES_PER_FRAME);
const HB = a.host === "B";
const psy = loadSyms(a.csyms);
const m = new TubeEliteMachine({ host: HB ? "B" : "Master", name: "t", disc: a.cand, syms: psy, rand, patch, seedFrom: ref, input });
await m.boot();
const W = a.windows.split(",").map(s => s.split("-").map(Number));
const par = m.t.par, pm = par.memory, tube = m.t.tube, host = m.host;
const dir = a.csyms.replace(/[^/]*$/, "");

// ---- the host's labels by place: main RAM (and HAZEL, the Master's), and
// each sideways bank by ROMSEL (Master: 5 bank 5, 85 ANDY, 6 bank 6; Model B:
// the loader's banks D, P, F, S in slots 4-7)
const LB = {};
const add = (map, k, v) => (LB[map] ||= []).push([k, v]);
// (not the operands' patch labels inside routines, r_bsN and r_ptN: a
// routine's cycles go to its own name)
const skip = k => /^(CODE|LOAD|B5_|B6_|RA_|F_START|F_END|MR_)/.test(k) || /^r_(bs|pt)\d+$/.test(k);
if (HB) {
    const hm = loadSyms(a.hsyms || dir + "hbmsyms.txt"), hp = loadSyms(dir + "hbpsyms.txt");
    for (const [k, v] of Object.entries(hm)) if (!skip(k)) add(v >= 0x8000 && v < 0xc000 ? "6" : "m", k, v);
    for (const [k, v] of Object.entries(hp)) if (!skip(k) && v >= 0x8000 && v < 0xc000) add("5", k, v);
    add("m", "hrw", 0x7fe0);           // (cmds.asm's: at a fixed place, no label)
} else {
    const hsy = loadSyms(a.hsyms || dir + "hsyms.txt"), hb = {};
    for (const l of readFileSync(dir + "hbanks.txt", "utf8").split("\n")) { const [n, b] = l.split(" "); if (n) hb[n] = b; }
    for (const [k, v] of Object.entries(hsy)) { if (skip(k)) continue; add(v < 0x8000 || v >= 0xc000 ? "m" : hb[k] === "85" ? (v < 0x9000 ? "85" : "5") : hb[k] || "?", k, v); }
}
for (const l of Object.values(LB)) l.sort((x, y) => x[1] - y[1]);
const near = (pc, map) => { const labs = LB[map] || []; let lo = 0, hi = labs.length - 1, r = null; while (lo <= hi) { const k = (lo + hi) >> 1; if (labs[k][1] <= pc) { r = labs[k][0]; lo = k + 1; } else hi = k - 1; } return r; };
const BANKN = HB ? { 4: "D", 5: "P", 6: "F", 7: "S" } : { 4: "4", 5: "5", 6: "6", 7: "7" };
const labOf = pc => {
    if (pc >= 0xc000 && (HB || !(pc < 0xe000 && (host.acccon & 8)))) return "MOS";
    if (pc < 0x8000 || pc >= 0xc000) return near(pc, "m") || "?";
    const r = host.romsel & 15;
    if (!HB && pc < 0x9000 && host.romsel & 0x80) return "A:" + near(pc, "85");
    return (BANKN[r] || r) + ":" + near(pc, String(r));
};
const sym = (n, map) => { const l = LB[map].find(([k]) => k === n); if (!l) throw new Error("no host label " + n); return l[1]; };
const HMAP = HB ? "6" : "m";    // (the command loop: bank F, the Master's main RAM)
const HDISP = sym("hdisp", HMAP), HLOOP = sym("hloop", HMAP);
const inLoop = pc => !HB || (host.romsel & 15) === 6;
const CN = {};
for (const l of readFileSync(new URL("../src/cmds.asm", import.meta.url), "utf8").split("\n")) { const mm = l.match(/^(C_[A-Z0-9_]+)\s*=\s*(\d+)/); if (mm) CN[+mm[2]] = mm[1]; }
const IRQV = host.readmem(0xfffe) | host.readmem(0xffff) << 8;

// an IRQ's kind: by the first of these labels it reaches (the requests, the
// Model B's rupture timer, the vsync's sound, the Master's timer for the panel)
const IRQCLS = [["h4body", "requests"], ["hbi_t", "rupture timer"], ["hb_irq", "vsync"], ["LINSCN", "vsync"], ["T1SYNC", "timer"], ["IRQ1", "IRQ1"], ["irqm", "irqm"], ["h4irq", "h4irq"]];
const irqSeen = new Set(); let irqAcc = 0;
let on = false, act = [], state = "loop", irqS = -1, lastC = 0, last = null, hprev = "busy";
const now = () => host.cycleSeconds * 2e6 + host.currentCycles;
const acc = (f, k, d) => { for (const r of act) r[f][k] = (r[f][k] || 0) + d; };
const rd = x => host.readmem(x & 0xffff);
const ABS = new Set([0xad, 0x8d, 0x2c, 0xae, 0x8e, 0xac, 0x8c, 0x0d, 0x2d, 0x4d, 0xcd]);
host.debugInstruction.add(pc => {
    const c = now();
    if (on && last) { const d = c - lastC; const [st, lab, kind] = last;
        if (st === "IRQ") irqAcc += d; else acc("state", st, d);
        acc("lab", lab, d); acc("kind", kind, d); for (const r of act) r.tot += d;
        acc("sl", st + " " + lab, d); }
    lastC = c;
    if (irqS < 0 && pc === IRQV) { irqS = host.s; irqSeen.clear(); irqAcc = 0; }
    else if (irqS >= 0 && host.s > irqS + 2) {   // (RTI: S up by 3; the MOS's entry PLAs P and pushes it back)
        irqS = -1;
        const cls = IRQCLS.find(([k]) => irqSeen.has(k));
        if (on) acc("state", "IRQ " + (cls ? cls[1] : "other"), irqAcc);
    }   // (RTI: S up by 3; the MOS's entry PLAs P and pushes it back)
    if (pc === HDISP && inLoop()) { state = CN[host.a] || "C?" + host.a; if (on) acc("ncmd", state, 1); }
    else if (pc === HLOOP && inLoop()) state = "loop";
    const lab = labOf(pc);
    let st;
    if (irqS >= 0) { irqSeen.add(lab.replace(/^.:/, "")); st = "IRQ"; }
    else st = lab === "MOS" ? "MOS " + state : /^hrw/.test(lab) ? "hrw wait" : state;   // (hrw: a command waiting for its next byte)
    // the kind of instruction
    const o0 = rd(pc), w = rd(pc + 1) | rd(pc + 2) << 8;
    let kind = "other";
    if (ABS.has(o0) && w >= 0xfee0 && w <= 0xfee7) kind = "tube";
    else if ((o0 === 0x8d || o0 === 0x8e || o0 === 0x8c) && (w === 0xfe30 || w === 0xfe34)) kind = "paging";
    else if ((o0 === 0x85 || o0 === 0x86 || o0 === 0x84) && rd(pc + 1) === 0xf4) kind = "paging";
    else if (o0 === 0x0c && (w === 0xfe34)) kind = "paging";       // (TSB/TRB ACCCON)
    else if (o0 === 0x1c && (w === 0xfe34)) kind = "paging";
    else if (o0 === 0xad && rd(pc + 3) === 0xd0 && rd(pc + 4) === 0xfb) { kind = "vswait"; hprev = kind; }
    else if (o0 === 0xd0 && rd(pc + 1) === 0xfb && rd(pc - 3) === 0xad) kind = hprev;
    else if (o0 === 0xa5 && rd(pc + 2) === 0xd0 && rd(pc + 3) === 0xfc) { kind = "vswait"; hprev = kind; }
    else if (o0 === 0xd0 && rd(pc + 1) === 0xfc && rd(pc - 2) === 0xa5) kind = hprev;
    if (st === "loop" && kind === "tube" && !(tube.hostStatus[0] & 0x80) && !(tube.hostStatus[1] & 0x80)) st = "idle";
    else if (st === "loop" && last && last[0] === "idle" && (o0 === 0x10 || o0 === 0x30 || o0 === 0x50 || o0 === 0x70)) st = "idle";
    last = [st, lab, kind];
    return false;
});
// ---- the parasite: its cycles by state (contexts entered at these labels)
const PCTX = new Map();
for (const [n, c] of [["rpg", "ring full"], ["ppump", "ring full"], ["pfwait", "flip wait"], ["pflush", "flush"], ["ovl_need", "overlays"], ["ovl_get", "overlays"], ["p_oscli", "disc"]]) if (psy[n] !== undefined) PCTX.set(psy[n], c);
const pst = [];
// the ring's own costs (p-io.asm): its stubs (a send in ring mode), the
// switches into and out of ring mode, its IRQ (the drain)
const RQ0 = psy.RQ_START, RQ1 = psy.RQ_END, PPR = psy.ppring, PIRQ = psy.pirq, PIRE = psy.rmode;
let added = 0, prevC = null, addedAtLast = 0, plast = null;
const origExec = par.execute;
par.execute = function (c) { added += c * this.cpuMultiplier; return origExec.call(this, c); };
m.t.addParHook(pc => {
    const c = par.cycles, d = prevC === null ? 0 : prevC + (added - addedAtLast) - c;
    prevC = c; addedAtLast = added;
    if (on && plast) { acc("par", plast, d); for (const r of act) r.ptot += d; }
    while (pst.length && par.s > pst[pst.length - 1][1]) pst.pop();
    { const cn = PCTX.get(pc); if (cn) pst.push([cn, par.s]); }
    let cat = pst.length ? pst[0][0] : "run";
    if (cat === "run" && pm[pc] === 0x2c && pm[pc + 2] === 0xfe && (pm[pc + 1] & 0xf0) === 0xf0) {
        const r = (pm[pc + 1] - 0xf8) >> 1, br = pm[pc + 3], s = tube.parasiteStatus[r];
        const fail = br === 0x50 ? !(s & 0x40) : br === 0x10 ? !(s & 0x80) : false;
        if (fail) cat = r === 0 ? "r1 full" : r === 3 ? "r4 wait" : "r" + (r + 1) + " wait";
    } else if (cat === "run" && plast && plast !== "run" && (pm[pc] === 0x50 || pm[pc] === 0x10) && pm[pc - 3] === 0x2c && pm[pc - 1] === 0xfe) cat = plast;
    if (cat === "run") { if (pc >= RQ0 && pc < RQ1) cat = "ring stubs"; else if (pc >= PPR && pc < PIRQ) cat = "ring mode switch"; else if (pc >= PIRQ && pc < PIRE) cat = "ring IRQ"; }
    plast = cat;
    return false;
});
const res = {};
m.onIter = mm => {
    for (const r of act) r.n++;          // (the iteration just ended)
    for (const [x, y] of W) {
        const k = x + "-" + y;
        if (mm.iter === x) res[k] = { n: 0, tot: 0, ptot: 0, state: {}, lab: {}, kind: {}, ncmd: {}, sl: {}, par: {}, h0: now() };
        if (mm.iter === y && res[k]) res[k].wall = (now() - res[k].h0) / res[k].n;
    }
    act = W.filter(([x, y]) => mm.iter >= x && mm.iter < y).map(([x, y]) => res[x + "-" + y]).filter(Boolean);
    on = act.length > 0;
};
const END = Math.max(...W.map(x => x[1]));
while (m.iter < END + 1) { m.run(CYCLES_PER_FRAME); m.snaps.length = 0; }
for (const r of Object.values(res)) {
    for (const f of ["state", "lab", "kind", "ncmd", "sl", "par"]) for (const k of Object.keys(r[f])) r[f][k] /= r.n;
    r.tot /= r.n; r.ptot /= r.n;
    delete r.h0;
}
writeFileSync(a.out, JSON.stringify(res));
for (const [w, r] of Object.entries(res)) {
    console.log(`== ${a.host || "Master"} ${w}: ${r.n} iterations, host ${r.tot.toFixed(0)} cycles an iteration, parasite wall ${r.wall.toFixed(0)}`);
    for (const [k, v] of Object.entries(r.state).sort((x, y) => y[1] - x[1]).slice(0, 12)) console.log(`   ${k.padEnd(30)} ${v.toFixed(0)}`);
    console.log("   parasite: " + Object.entries(r.par).sort((x, y) => y[1] - x[1]).map(([k, v]) => `${k} ${v.toFixed(0)}`).join(", "));
}
process.exit(0);
