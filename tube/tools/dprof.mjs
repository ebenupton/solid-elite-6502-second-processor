#!/usr/bin/env node
// dprof.mjs: the parasite's cycles per iteration over windows of a replay, for
// comparing two builds: per iteration, the cycles by label (lab), by the routine
// on top of the call stack (cx: the routines in CTXN, entered by JSR) and by every
// routine on it (inc), those routines' calls (calls, and caller>callee pairs in
// pc2), the parasite's waits on the Tube's registers (WAIT@label), the bytes it
// wrote to each register (tx), the host's time busy, idle and in the vsync waits
// (h), and the disc layer's rows in each buffer (dr, and ch: changed since the
// last iteration). One JSON array of iterations; summarise with tube/tools/dprofcmp.mjs.
//   TUBEMHZ=4 node tube/tools/dprof.mjs --log L --cand ssd --csyms psyms
//        --windows 1000-1400,5355-5457 --out x.json [--host B]
import { EliteMachine, loadSyms, CYCLES_PER_FRAME } from "../../master/tools/agentplay/lib.mjs";
import { TubeEliteMachine } from "./tmachine.mjs";
import { DEFAULTS, seedBytes } from "../../master/tools/agentplay/session.mjs";
import { COMMANDERS } from "../../master/tools/agentplay/styles.mjs";
import { parseArgs } from "../../harness/args.mjs";
import { readFileSync, writeFileSync } from "fs";
const a = parseArgs({ log: "value", host: "value", cand: "value", csyms: "value", windows: "value", out: "value" });
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
const W = a.windows.split(",").map(s => s.split("-").map(Number));
const par = m.t.par, pm = par.memory, tube = m.t.tube, host = m.host;
const OS = sy.OVL_START, all = Object.entries(sy).filter(([k, v]) => v >= 0x0800 && !/^(CODE|LOAD)/.test(k));
const srt = l => l.sort((x, y) => x[1] - y[1]);
const LR = srt(all.filter(([k, v]) => v < OS || v >= 0xf800)), LS = srt(all.filter(([k, v]) => v >= OS && v < 0xf800 && !k.endsWith("_C"))),
    LD = srt(all.filter(([k, v]) => v >= OS && v < 0xf800 && k.endsWith("_C")));
const find = (lab, x) => { let lo = 0, hi = lab.length - 1, r = null; while (lo <= hi) { const k = (lo + hi) >> 1; if (lab[k][1] <= x) { r = lab[k][0]; lo = k + 1; } else hi = k - 1; } return r; };
const labelOf = x => x >= OS && x < 0xf800 ? (pm[sy.ovl_cur] === 1 ? find(LD, x) : find(LS, x)) : find(LR, x);
const lcache = new Map();
let added = 0, prevC = null, addedAtLast = 0, on = false, prevLab = null, cur = null;
const origExec = par.execute;
par.execute = function (c) { added += c * this.cpuMultiplier; return origExec.call(this, c); };
// routine entries (JSR targets) counted
const CTXN = ["F_FRAME","f_discs","f_disc2","T_DISCROWS","ps_fit","hp_fit","hp_move","hp_drop","ps_rows","psi","ps_outs","ps_whole","ps_strips","ps_seg","ps_gen","ps_fin","ps_spin","ps_spo","ps_row","ps_edges","ps_getn","ps_nib","pd2","pd_row","prow","pseg","prep","pk_row","fl_arm","R_FLARE","fp_emit","fp_pix","PLANET","SUN","S_SUN","L_SUN","f_ships","f_lines","f_dots","f_flt","f_text1","f_sight1","f_sight2","f_lasers","f_sort","T_STARERASE","pspan","pdiff","ptx","pirq","rpg","p_buf","pfwait","pflush","ovl_need","ovl_get","povd","p_emit","R_DOT","LL9","MVEIT","TT17","f_discspans","f_bdisc","f_discdirty","f_b0new","T_KFRAME","pbl","p_sync","p_wscan","p_dks","p_irb","p_noise"];
const CTX = new Map(); for (const n of CTXN) if (sy[n] !== undefined) CTX.set(sy[n], n);
const cst = [];
const ENT = new Map(); for (const n of ["PLANET", "SUN", "SUN4", "f_disc2", "f_discs", "f_discspans", "R_DISCROWS", "R_FLARE", "ovl_get", "ovl_need", "pflush", "F_FRAME", "f_bdisc", "f_discdirty", "fl_disc", "S_SUN", "L_SUN", "rpg", "p_buf", "pfwait", "C_SYNC"]) if (sy[n] !== undefined) ENT.set(sy[n], n);
m.t.addParHook(pc => {
    const c = par.cycles, d = prevC === null ? 0 : prevC + (added - addedAtLast) - c;
    prevC = c; addedAtLast = added;
    if (on && prevLab) { cur.lab[prevLab] = (cur.lab[prevLab] || 0) + d; const cx = cst.length ? cst[cst.length - 1][0] : "-"; cur.cx[cx] = (cur.cx[cx] || 0) + d;
        const tp = cst.length ? cst.map(z => z[0]).filter((z, i, A) => A.indexOf(z) === i) : ["-"]; for (const z of tp) cur.inc[z] = (cur.inc[z] || 0) + d; }
    while (cst.length && par.s > cst[cst.length - 1][1]) cst.pop();
    { const cn = CTX.get(pc); if (cn !== undefined && !(pc >= OS && pc < 0xf800 && pm[sy.ovl_cur] === 1)) { if (on) { cur.calls[cn] = (cur.calls[cn] || 0) + 1; const pk = (cst.length ? cst[cst.length - 1][0] : "-") + ">" + cn; cur.pc2[pk] = (cur.pc2[pk] || 0) + 1; } cst.push([cn, par.s]); } }
    if (!on) { prevLab = null; return false; }
    const op = pm[pc];
    let lab;
    if (op === 0x2c && pm[pc + 2] === 0xfe && (pm[pc + 1] & 0xf0) === 0xf0) {
        const r = (pm[pc + 1] - 0xf8) >> 1, br = pm[pc + 3], st = tube.parasiteStatus[r];
        const fail = br === 0x50 ? !(st & 0x40) : br === 0x10 ? !(st & 0x80) : br === 0x30 ? !!(st & 0x80) : br === 0x70 ? !!(st & 0x40) : false;
        lab = fail ? "WAIT@" + labelOf(pc) : labelOf(pc);
    } else if ((op === 0x50 || op === 0x10 || op === 0x30 || op === 0x70) && pm[pc - 3] === 0x2c && pm[pc - 1] === 0xfe) lab = prevLab;
    else {
        if (pc >= OS && pc < 0xf800) lab = labelOf(pc);
        else { lab = lcache.get(pc); if (lab === undefined) { lab = labelOf(pc); lcache.set(pc, lab); } }
    }
    const e = ENT.get(pc); if (e) cur.ent[e] = (cur.ent[e] || 0) + 1;
    prevLab = lab;
    return false;
});
const ptw = tube.parasiteWrite.bind(tube);
tube.parasiteWrite = (ad, v) => { if (on) { const r = (ad & 7) >> 1; cur.tx[r] = (cur.tx[r] || 0) + 1; } return ptw(ad, v); };
// host idle (polls of its registers with nothing to read), as pwait
let hlast = null, hlastC = 0, hprev = null;
const now = () => host.cycleSeconds * 2e6 + host.currentCycles;
const rd = x => host.readmem(x & 0xffff);
host.debugInstruction.add(pc => {
    const c = now();
    if (on && hlast) cur.h[hlast] = (cur.h[hlast] || 0) + c - hlastC;
    hlastC = c;
    const o0 = rd(pc); let cl = "busy";
    if (pc >= 0xfc00 && pc < 0xff00) cl = "busy";
    else if (o0 === 0x2c && rd(pc + 2) === 0xfe && (rd(pc + 1) === 0xe0 || rd(pc + 1) === 0xe2)) { cl = !(tube.hostStatus[0] & 0x80) && !(tube.hostStatus[1] & 0x80) ? "idle" : "busy"; hprev = cl; }
    else if ((o0 === 0x10 || o0 === 0x30) && rd(pc - 3) === 0x2c && rd(pc - 1) === 0xfe) cl = hprev;
    else if (o0 === 0xad && rd(pc + 3) === 0xd0 && rd(pc + 4) === 0xfb) { cl = "vs"; hprev = cl; }
    else if (o0 === 0xd0 && rd(pc + 1) === 0xfb && rd(pc - 3) === 0xad) cl = hprev;
    else if (o0 === 0xa5 && rd(pc + 2) === 0xd0 && rd(pc + 3) === 0xfc) { cl = "vs"; hprev = cl; }
    else if (o0 === 0xd0 && rd(pc + 1) === 0xfc && rd(pc - 2) === 0xa5) cl = hprev;
    hlast = cl; return false;
});
const discRows = () => {
    const out = [];
    for (const [l, r] of [[sy.R_DISCL0, sy.R_DISCR0], [sy.R_DISCL1, sy.R_DISCR1]]) {
        let n = 0; const s = [];
        for (let y = 0; y < 192; y++) { const L = pm[l + y], R = pm[r + y]; s.push(L, R); if (L !== 255 && L < R) n++; }
        out.push({ n, s: s.join(",") });
    }
    return out;
};
const iters = []; let prevDR = null, ringRead = () => 0;
m.onIter = mm => {
    if (cur) { cur.wall = added - cur.a0; cur.hw = now() - cur.h0; const dr = discRows(); cur.dr = [dr[0].n, dr[1].n];
        cur.ch = prevDR ? [dr[0].s !== prevDR[0].s, dr[1].s !== prevDR[1].s] : [true, true]; cur.ovl = pm[sy.ovl_cur]; prevDR = dr; iters.push(cur); cur = null; }
    const w = W.find(([x, y]) => mm.iter >= x && mm.iter < y);
    on = !!w;
    if (on) cur = { it: mm.iter, w: w.join("-"), lab: {}, cx: {}, inc: {}, calls: {}, pc2: {}, ent: {}, tx: {}, h: {}, a0: added, h0: now() };
    else prevDR = null;
    if (!on && mm.iter >= W[W.length - 1][1]) {}
};
const END = Math.max(...W.map(x => x[1]));
while (m.iter < END + 1) { m.run(CYCLES_PER_FRAME); m.snaps.length = 0; }
writeFileSync(a.out, JSON.stringify(iters));
console.log("done", iters.length);
process.exit(0);
