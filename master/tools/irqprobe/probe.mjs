// irqprobe: measures the dashboard split of full Master Elite on jsbeeb, without
// touching the game: the System VIA timer 1 interrupt that IRQ1 answers with
// TSB &FE34 (ACCCON D = 1, shadow RAM shown for the dashboard), its latency and
// what caused it, and what the CRTC actually fetched from which RAM in every frame.
//
// attachProbe(cpu, sy) hooks a booted jsbeeb Master (cpu = machine.processor):
//   * cpu.debugInstruction: per instruction, a ring of (epoch, pc, ROMSEL, ACCCON,
//     I flag) for blame; timer 1 and vsync flag edges; the vsync handler's T1 write
//     (LINSCN's STA &FE45) and the timer handler's TSB &FE34;
//   * cpu.brk: interrupt entries (IRQ, NMI, BRK) with the pending sources;
//   * cpu.videoRead: every CRTC fetch, with the RAM it came from (ACCCON D at that
//     moment), per frame and per scanline.
// Times are scheduler epochs (2 MHz cycles). The raster position "pos" is
// (line * 128 + character) with line = R4 row * 8 + scanline: one character per
// 2 MHz cycle (R0 = 127), 312 lines, 39936 cycles a frame; line 0 is the first
// displayed line, vsync starts at line 272 (R7 = 34) and jsbeeb sets CA1's flag at its
// end (line 274: the MOS's PCR makes CA1 negative-edge).
// The window: the last space-view fetch is at pos 191 * 128 + 63, the first dashboard
// fetch at 192 * 128; ACCCON D written in between gives a clean split.
// summarise(probe) gives the summary (latency of the timer 1 and vsync paths with their
// causes, the split's raster position against the window, per-frame counts of main-RAM
// dashboard bytes and early shadow bytes, disc commands against GMODE, transitions);
// probe.events / probe.vsEvents / probe.frames are the raw records.
// gate.mjs runs it over the gate's piloted run, play.mjs over an agentplay session.
import { mapAt, mapOfLabel } from "../../../harness/mlib.mjs";

export const FRAME = 312 * 128, VSYNC_POS = 272 * 128, CA1_POS = 274 * 128, DASH_LINE = 192, DASH_POS = 192 * 128;

export function attachProbe(cpu, sy, opts = {}) {
    const ram = cpu.ramRomOs, via = cpu.sysvia, vid = cpu.video, sch = cpu.scheduler;
    const rb = a => cpu.readmem(a);
    const now = () => sch.epoch;
    const pos = () => (vid.vertCounter * 8 + vid.scanlineCounter) * 128 + vid.horizCounter;
    // the two instructions that matter, found in the code (main RAM: IRQ1 is at &2652)
    const find = (from, bytes, n = 80) => { for (let a = from; a < from + n; a++) if (bytes.every((b, i) => ram[a + i] === b)) return a; return -1; };
    // (found when IRQ1 first runs: the probe may be attached before the game is loaded)
    let TSB = -1, T1W = -1;                                 // IRQ1: TSB VIA+&34; LINSCN: STA VIA+&45
    const IRQV = rb(0xfffe) | rb(0xffff) << 8, NMIV = rb(0xfffa) | rb(0xfffb) << 8;

    // ---- labels (game: symbols per mapping; else MOS / ROM n)
    const labs = {};
    for (const [k, v] of Object.entries(sy)) {
        if (v < 0x0100 || /^(CODE|LOAD)/.test(k)) continue;
        const m = mapOfLabel(sy, k);
        if (m === "m" && v >= 0x8000 && v < 0xc000) continue;
        (labs[m] ||= []).push([k, v]);
    }
    for (const l of Object.values(labs)) l.sort((a, b) => a[1] - b[1]);
    const labelOf = (a, romsel, acccon) => {
        const hex = "&" + a.toString(16).toUpperCase();
        if (a >= 0xe000 || (a >= 0xc000 && !(acccon & 8))) return "MOS:" + hex;
        if (a >= 0x8000 && a < 0xc000) {
            const m = mapAt(romsel, a);
            if (m !== "A" && (m < 4 || m > 7)) return `ROM${m}:${hex}`;
        }
        if (a >= 0x0d00 && a < 0x0e00) return "NMI page &0D:" + hex;
        const lab = labs[mapAt(romsel, a)] || [];
        let lo = 0, hi = lab.length - 1, r = null;
        while (lo <= hi) { const m = (lo + hi) >> 1; if (lab[m][1] <= a) { r = lab[m]; lo = m + 1; } else hi = m - 1; }
        if (!r) return hex;
        const n = r[0].endsWith("_C") ? r[0].slice(0, -2) : r[0];
        return a === r[1] ? n : `${n}+${a - r[1]}`;
    };
    const rout = s => s.replace(/\+\d+$/, "");

    // ---- instruction ring
    const RN = 1 << 17, RM = RN - 1;
    const rE = new Float64Array(RN), rPC = new Uint16Array(RN), rRS = new Uint8Array(RN), rAC = new Uint8Array(RN), rI = new Uint8Array(RN), rK = new Uint8Array(RN);
    let rH = 0;          // next slot; rK: 0 instruction, 1 IRQ entry, 2 NMI entry, 3 BRK entry
    const push = (e, pc, k) => { rE[rH] = e; rPC[rH] = pc; rRS[rH] = cpu.romsel; rAC[rH] = cpu.acccon; rI[rH] = cpu.p.i ? 1 : 0; rK[rH] = k; rH = (rH + 1) & RM; };

    let entries = { irq: 0, nmi: 0, brk: 0 };
    const origBrk = cpu.brk;
    cpu.brk = function (isIrq) {
        detect(now());       // (a flag that rose in the instruction just run: the entry comes before the next hook)
        const e = now(), from = this.pc, ifr = via.ifr & via.ier & 0x7f, uifr = cpu.uservia.ifr & cpu.uservia.ier & 0x7f;
        const r = origBrk.call(this, isIrq);
        const kind = this.pc === NMIV ? 2 : isIrq ? 1 : 3;
        push(e, from, kind);
        if (kind === 1) { entries.irq++; for (const ev of pend) if (ev && ev.entry === undefined && (ifr & ev.bit)) { ev.entry = e; ev.entryIfr = ifr; ev.entryUifr = uifr; } }
        else if (kind === 2) { entries.nmi++; frNmis++; for (const ev of pend) if (ev && ev.entry === undefined) ev.nmis = (ev.nmis || 0) + 1; }
        else entries.brk++;
        return r;
    };

    // ---- per split event
    const events = [];
    const vsEvents = [];        // the same for the vsync interrupt (CA1 -> LINSCN's T1 write)
    const pend = [null, null];  // [timer 1, vsync] being followed
    let frTop = -1;
    let prevIfr = via.ifr, lastVsLat = null, lastT1W = -1, prevPc = -1;
    const vsLat = [];           // vsync start -> LINSCN's T1 write (cycles)
    const stray = [];           // TSBs at IRQ1 with no timer 1 pending, other D writes
    let prevI = 0;

    function blame(ev) {
        // index of the instruction during which the flag rose, and of the IRQ entry
        let ie = -1, ih = -1;
        for (let k = 1; k < RN; k++) {
            const i = (rH - k) & RM;
            if (rE[i] === 0 && k > 1) break;
            if (ie < 0 && rK[i] === 1 && rE[i] === ev.entry) ie = i;
            if (rK[i] === 0 && rE[i] <= ev.hit) { ih = i; break; }
        }
        if (ih < 0 || ie < 0) { ev.cause = "ring overflow"; return; }
        ev.atHit = labelOf(rPC[ih], rRS[ih], rAC[ih]);
        ev.iAtHit = rI[ih];
        // the instruction before the entry: what let it in (CLI, PLP, RTI) or was in progress
        let ib = (ie - 1) & RM;
        ev.before = labelOf(rPC[ib], rRS[ib], rAC[ib]);
        ev.beforeOp = rb_at(rPC[ib], rRS[ib], rAC[ib]);
        if (!rI[ih]) { ev.cause = "instruction in progress"; ev.where = rout(ev.atHit); return; }
        // I was set at the hit: who set it (walk back to the last I 0->1 edge or entry)
        let is = ih, n = 0;
        for (; n < RN - 2; n++) {
            const j = (is - 1) & RM;
            if (rE[j] === 0) break;
            if (rK[j] !== 0) { is = j; break; }        // an interrupt entry set I
            if (!rI[j]) { is = j; break; }             // the instruction that set I (I clear before it)
            is = j;
        }
        ev.setBy = rK[is] === 1 ? "IRQ entry" : rK[is] === 2 ? "NMI entry" : rK[is] === 3 ? "BRK entry" : labelOf(rPC[is], rRS[is], rAC[is]);
        ev.setOp = rK[is] ? null : rb_at(rPC[is], rRS[is], rAC[is]);
        // where the time went between the hit and the entry: routine counts
        const cnt = {};
        for (let j = ih; j !== ie; j = (j + 1) & RM) if (rK[j] === 0) { const r = rout(labelOf(rPC[j], rRS[j], rAC[j])); cnt[r] = (cnt[r] || 0) + 1; }
        ev.during = Object.entries(cnt).sort((a, b) => b[1] - a[1]).slice(0, 4).map(([k, v]) => `${k}x${v}`).join(" ");
        if (rK[is] !== 0) {
            // I set by an interrupt entry: inside that handler (named by its first game label)
            let h = "?";
            for (let j = (is + 1) & RM, n2 = 0; n2 < 64 && j !== ih; j = (j + 1) & RM, n2++) { const l = rout(labelOf(rPC[j], rRS[j], rAC[j])); if (!/^(MOS|ROM)/.test(l)) { h = l; break; } }
            ev.cause = `inside ${ev.setBy.replace(" entry", "")} handler`; ev.where = h;
        } else { ev.cause = "I set (SEI section)"; ev.where = rout(ev.setBy); }
    }
    const OPN = { 0x58: "CLI", 0x28: "PLP", 0x40: "RTI", 0x78: "SEI", 0x08: "PHP" };
    function rb_at(pc, rs, ac) {
        // the opcode at pc as it was mapped (sideways banks / HAZEL via the current mapping only
        // if unchanged; good enough for naming CLI/PLP/RTI)
        const op = cpu.readmem(pc);
        return OPN[op] || "&" + op.toString(16);
    }

    function finish(ev, w, list) {
        ev.done = w; ev.lat = w - ev.hit; ev.wait = ev.entry !== undefined ? ev.entry - ev.hit : null;
        ev.top = frTop; ev.tag = tagNow() + (fno - markFrame < 150 ? " after " + lastMark : "");
        blame(ev);
        list.push(ev);
        if (list.length > (opts.maxEvents || 2e6)) list.shift();
    }
    const tagNow = () => opts.tagFn ? opts.tagFn() : probe.tag;
    const hz = a => a >= 0xc000 ? ram[a - 0x3000] : ram[a];   // HAZEL whatever ACCCON Y is, or main RAM (the glue, now)
    const markTab = new Map();
    for (const [a, m, name] of opts.marks || []) { if (!markTab.has(a)) markTab.set(a, []); markTab.get(a).push([m, name]); }
    let lastMark = "-", markFrame = 0, frNmis = 0;
    const oscli = [];
    const DOSCLI = sy.DOSCLI_C ?? sy.DOSCLI;
    const live = () => TSB >= 0 && (ram[0x204] | ram[0x205] << 8) === sy.IRQ1;   // the game's IRQ1 installed
    function detect(e) {
    const ifr = via.ifr;
    if (!live()) { prevIfr = ifr; return; }
    if ((ifr & 0x40) && !(prevIfr & 0x40)) {
        // timer 1 fired: the epoch it did, from the VIA's lazily updated counter (jsbeeb
        // leaves the counter at -3 at the hit and reloads it on the next tick)
        const k = via.t1c < 0 ? -3 - via.t1c : via.t1l + 1 - via.t1c;
        const hit = via.lastPolltime - k;
        if (pend[0]) { pend[0].missed = true; events.push(pend[0]); }
        pend[0] = { src: "T1", bit: 0x40, hit, hitPos: (pos() - (e - hit) + 2 * FRAME) % FRAME, t1w: lastT1W, vsLat: lastVsLat };
    }
    if ((ifr & 0x02) && !(prevIfr & 0x02)) {
        // CA1 (vsync): set at an exact raster position; the hit epoch from the raster
        if (pend[1]) { pend[1].missed = true; vsEvents.push(pend[1]); }
        const hp = pos(), hit = e - ((hp - CA1_POS + FRAME) % FRAME);
        pend[1] = { src: "VS", bit: 0x02, hit, hitPos: CA1_POS, seenPos: hp };
    }
    prevIfr = ifr;
    }
    cpu.debugInstruction.add(pc => {
        const e = now();
        push(e, pc, 0);
        const ml = markTab.get(pc);
        if (ml) for (const [m, name] of ml) if (m === "m" || m === mapAt(cpu.romsel, pc)) { lastMark = name; markFrame = fno; }
        if ((pc === DOSCLI && (cpu.romsel & 15) === 7) || pc === 0xfff7) {
            if (oscli.length < 5000) oscli.push({ live: live(), at: pc === 0xfff7 ? "OSCLI" : "DOSCLI", gmode: hz(sy.GMODE), gfront: hz(sy.GFRONT), D: cpu.acccon & 1, frameTop: frTop, tag: tagNow(), mark: lastMark });
        }
        detect(e);
        if (TSB < 0 && pc === sy.IRQ1) {
            TSB = find(sy.IRQ1, [0x0c, 0x34, 0xfe]); T1W = find(sy.LINSCN, [0x8d, 0x45, 0xfe]);
            if (TSB < 0) throw new Error("irqprobe: TSB &FE34 not found in IRQ1");
            if (T1W < 0) T1W = -2;            // (a build whose LINSCN leaves timer 1 alone)
            probe.TSB = TSB; probe.T1W = T1W;
        }
        if (pc < 0x8000) {
            if (prevPc === T1W) {           // LINSCN's STA &FE45 just ran (its write: the last cycle)
                lastT1W = e - 1;
                if (pend[1]) { const ev = pend[1]; pend[1] = null; ev.tsbPos = (pos() - 1 + FRAME) % FRAME; finish(ev, e - 1, vsEvents); lastVsLat = ev.lat; }
            } else if (prevPc === TSB) {
                const w = e - 1, p = (pos() - 1 + FRAME) % FRAME;
                if (pend[0]) { const ev = pend[0]; pend[0] = null; ev.tsbPos = p; finish(ev, w, events); }
                else if (stray.length < 200) stray.push({ e: w, pos: p, why: "TSB with no timer 1 pending" });
            } else if (pc === sy.IRQ1) { for (const ev of pend) if (ev && ev.irq1 === undefined && ev.entry !== undefined) ev.irq1 = e; }
        }
        prevPc = pc;
        return false;
    });

    // ---- the CRTC's fetches
    const frames = [];
    let fr = null, lastLine = 1e9;
    const newFrame = () => ({ gmode: hz(sy.GMODE), dfsin: ram[sy.DFSIN] & 0x80, mark: lastMark, since: fno - markFrame, top: -1, trans: [], dashMain: 0, dashMainBytes: 0, beyondCopy: 0, earlyBytes: 0, earlyShadow: 0, lastDiff: 127, earlyDiff: 0, lateMainLines: [], e: now(), tag: tagNow() });
    const lineSeen = new Int32Array(320);      // last frame number a line was counted in (per category)
    let fno = 0;
    const origVR = cpu.videoRead;
    cpu.videoRead = function (addr) {
        const page = this.videoDisplayPage, v = this.ramRomOs[addr | page] | 0;
        const line = vid.vertCounter * 8 + vid.scanlineCounter;
        if (vid.horizCounter >= vid.regs[1]) return v;       // (jsbeeb's fetch at R1: never displayed)
        if (line < lastLine) { if (fr && fr.live) finishFrame(); fr = newFrame(); fr.live = live() && vid.regs[6] === 31 && vid.regs[9] === 7; fno++; }
        lastLine = line;
        if (fr.top < 0) fr.top = frTop = page ? 1 : 0, fr.page = page;
        if (page !== fr.page) { if (fr.trans.length < 6) fr.trans.push([line * 128 + vid.horizCounter, page ? 1 : 0]); fr.page = page; }
        if (addr >= 0x7000 && addr < 0x7e00) {
            if (!page) {
                fr.dashMainBytes++;
                if (addr >= (sy.QSL ?? 0x7200)) fr.beyondCopy++;   // (the high code: from &7000 since the copy of the dashboard's first row went)
                if (lineSeen[line] !== fno) { lineSeen[line] = fno; fr.dashMain++; fr.lateMainLines.push(line); }
            }
        }
        if (fr.top === 0 && line >= 128 && addr >= 0x4000 && addr < 0x7000 && this.ramRomOs[addr] !== this.ramRomOs[addr | 0x8000] && line > fr.lastDiff) fr.lastDiff = line;
        if (addr >= 0x7000) {
        } else if (addr >= 0x4000 && addr < 0x7000 && fr.top === 0 && page) {
            fr.earlyBytes++;
            if (lineSeen[line] !== -fno) { lineSeen[line] = -fno; fr.earlyShadow++; }
            if (this.ramRomOs[addr] !== v) fr.earlyDiff++;
        }
        return v;
    };
    function finishFrame() {
        frames.push({ same: 191 - fr.lastDiff, gmode: fr.gmode, dfsin: fr.dfsin | (ram[sy.DFSIN] & 0x80), nmis: frNmis, mark: fr.mark, since: fr.since, top: fr.top, trans: fr.trans, dashMain: fr.dashMain, dashMainBytes: fr.dashMainBytes, beyondCopy: fr.beyondCopy, earlyBytes: fr.earlyBytes, earlyShadow: fr.earlyShadow, earlyDiff: fr.earlyDiff, lines: fr.lateMainLines.slice(0, 10), e: fr.e, tag: fr.tag });
        frNmis = 0;
        if (frames.length > (opts.maxFrames || 3e6)) frames.shift();
    }

    const probe = {
        TSB, T1W, IRQV, NMIV, events, vsEvents, frames, oscli, vsLat, stray, entries, tag: "", labelOf,
        detach() { cpu.videoRead = origVR; cpu.brk = origBrk; },
    };
    return probe;
}

// ---- summaries
export const LAST_SPACE_FETCH = 191 * 128 + 63, FIRST_DASH_FETCH = 192 * 128;
const hist = (xs, w) => { const h = {}; for (const x of xs) { const b = Math.floor(x / w) * w; h[b] = (h[b] || 0) + 1; } return Object.entries(h).map(([k, v]) => [+k, v]).sort((a, b) => a[0] - b[0]); };
const pct = (xs, p) => { if (!xs.length) return null; const s = [...xs].sort((a, b) => a - b); return s[Math.min(s.length - 1, Math.floor(p * s.length))]; };
const stats = (xs, w) => xs.length ? { n: xs.length, min: Math.min(...xs), p50: pct(xs, .5), p99: pct(xs, .99), p999: pct(xs, .999), max: Math.max(...xs), hist: w ? hist(xs, w) : undefined } : { n: 0 };
function causes(ev) {
    const by = {};
    for (const e of ev) {
        const k = `${e.cause}: ${e.where}`;
        const b = (by[k] ||= { n: 0, max: 0, sum: 0, ex: null });
        b.n++; b.sum += e.lat; if (e.lat > b.max) { b.max = e.lat; b.ex = e; }
    }
    return Object.entries(by).map(([k, b]) => ({ cause: k, n: b.n, max: b.max, mean: +(b.sum / b.n).toFixed(1), worst: slim(b.ex) })).sort((a, b) => b.max - a.max);
}

export function summarise(probe, label = "") {
    const all = probe.events.filter(e => !e.missed), b0 = all.filter(e => e.top === 0);
    const vs = probe.vsEvents.filter(e => !e.missed), vsb0 = vs.filter(e => e.top === 0);
    const out = { label, entries: probe.entries, missed: { t1: probe.events.length - all.length, vs: probe.vsEvents.length - vs.length } };
    out.t1 = { all: stats(all.map(e => e.lat), 8), buffer0: stats(b0.map(e => e.lat), 8),
        parts: { entryToIRQ1: stats(all.filter(e => e.irq1).map(e => e.irq1 - e.entry)), irq1ToTSB: stats(all.filter(e => e.irq1).map(e => e.done - e.irq1)) },
        causesBuffer0: causes(b0).slice(0, 25), causesAll: causes(all).slice(0, 25), worstBuffer0: [...b0].sort((a, b) => b.lat - a.lat).slice(0, 25).map(slim) };
    out.vs = { all: stats(vs.map(e => e.lat), 4), buffer0: stats(vsb0.map(e => e.lat), 4),
        parts: { entryToIRQ1: stats(vs.filter(e => e.irq1).map(e => e.irq1 - e.entry)), irq1ToT1write: stats(vs.filter(e => e.irq1).map(e => e.done - e.irq1)) },
        causesBuffer0: causes(vsb0).slice(0, 25), worstBuffer0: [...vsb0].sort((a, b) => b.lat - a.lat).slice(0, 15).map(slim) };
    out.t1HitPos = { all: stats(all.map(e => e.hitPos), 4), buffer0: stats(b0.map(e => e.hitPos), 4) };
    // the split as written: raster position of the ACCCON write, against the window
    const lateBy = e => e.tsbPos - FIRST_DASH_FETCH, earlyBy = e => LAST_SPACE_FETCH + 1 - e.tsbPos;
    out.split = { window: [LAST_SPACE_FETCH + 1, FIRST_DASH_FETCH], buffer0: stats(b0.map(e => e.tsbPos), 8),
        buffer0Late: b0.filter(e => lateBy(e) > 0).length, buffer0Early: b0.filter(e => earlyBy(e) > 0).length,
        lateCycles: stats(b0.filter(e => lateBy(e) > 0).map(lateBy), 64), earlyCycles: stats(b0.filter(e => earlyBy(e) > 0).map(earlyBy), 1) };
    // frames, from the CRTC's fetches
    const F = probe.frames, main = F.filter(f => f.top === 0);
    out.frames = { total: F.length, buffer0: main.length, shadowTop: F.length - main.length };
    const cs = F.filter(f => f.dashMain > 0);
    out.frames.copyShown = { frames: cs.length, buffer0Frames: cs.filter(f => f.top === 0).length, lines: hist(cs.map(f => f.dashMain), 1), bytes: stats(cs.map(f => f.dashMainBytes), 64),
        beyondCopyFrames: F.filter(f => f.beyondCopy > 0).length,
        examples: cs.slice(0, 12).map(f => ({ top: f.top, lines: f.lines, bytes: f.dashMainBytes, trans: f.trans, tag: f.tag })) };
    out.frames.early = { framesWithShadowBytes: main.filter(f => f.earlyBytes > 0).length, bytes: hist(main.map(f => f.earlyBytes), 1),
        framesWithDifferingBytes: main.filter(f => f.earlyDiff > 0).length, diffBytes: hist(main.filter(f => f.earlyDiff > 0).map(f => f.earlyDiff), 1),
        diffExamples: main.filter(f => f.earlyDiff > 0).slice(0, 8).map(f => ({ trans: f.trans, diff: f.earlyDiff, tag: f.tag })) };
    out.frames.early.identicalBottomLines = hist(main.map(f => f.same), 1);
    const odd = F.filter(f => f.trans.length > (f.top === 0 ? 1 : 0));
    out.frames.oddTransitions = { count: odd.length, examples: odd.slice(0, 12).map(f => ({ top: f.top, trans: f.trans, tag: f.tag })) };
    out.frames.byTag = {};
    for (const f of F) { const t = (out.frames.byTag[f.tag || "-"] ||= { frames: 0, buffer0: 0, copyShown: 0, earlyShown: 0 }); t.frames++; if (f.top === 0) t.buffer0++; if (f.dashMain) t.copyShown++; if (f.top === 0 && f.earlyBytes) t.earlyShown++; }
    // disc commands and space mode
    const OS = probe.oscli.filter(o => o.live);
    out.oscli = { n: OS.length, beforeGame: probe.oscli.length - OS.length, gmodeSet: OS.filter(o => o.gmode & 0x80).length, D0: OS.filter(o => !o.D).length,
        frameTopBuffer0: OS.filter(o => o.frameTop === 0).length, byMark: {} };
    for (const o of OS) out.oscli.byMark[`${o.at} ${o.mark} gmode=${o.gmode.toString(16)} D=${o.D}`] = (out.oscli.byMark[`${o.at} ${o.mark} gmode=${o.gmode.toString(16)} D=${o.D}`] || 0) + 1;
    out.frames.buffer0WithDisc = main.filter(f => f.dfsin || f.nmis).length;
    out.frames.buffer0NotSpaceMode = main.filter(f => !(f.gmode & 0x80)).length;
    out.frames.spaceModeFrames = F.filter(f => f.gmode & 0x80).length;
    // transitions: frames within 150 of a marked routine (launch, docking, hyperspace, death ...)
    out.frames.byMark = {};
    for (const f of F) {
        const k = f.since < 150 ? f.mark : "(other)";
        const t = (out.frames.byMark[k] ||= { frames: 0, buffer0: 0, copyShown: 0, maxCopyLines: 0, earlyShown: 0, earlyDiff: 0, odd: 0 });
        t.frames++; if (f.top === 0) t.buffer0++; if (f.dashMain) { t.copyShown++; t.maxCopyLines = Math.max(t.maxCopyLines, f.dashMain); }
        if (f.top === 0 && f.earlyBytes) t.earlyShown++; if (f.earlyDiff) t.earlyDiff++; if (f.trans.length > (f.top === 0 ? 1 : 0)) t.odd++;
    }
    out.stray = probe.stray.slice(0, 20);
    out.addr = { TSB: probe.TSB.toString(16), T1W: probe.T1W.toString(16), IRQV: probe.IRQV.toString(16), NMIV: probe.NMIV.toString(16) };
    return out;
}
function slim(e) {
    if (!e) return e;
    const { src, lat, wait, hit, entry, irq1, done, hitPos, tsbPos, cause, where, atHit, iAtHit, setBy, setOp, before, beforeOp, during, nmis, entryIfr, tag, top, vsLat } = e;
    return { src, lat, wait, toIRQ1: irq1 && entry !== undefined ? irq1 - entry : null, toWrite: irq1 ? done - irq1 : null, hitPos, writePos: tsbPos, line: Math.floor(tsbPos / 128), chr: tsbPos % 128, vsLat, cause, where, atHit, iAtHit, setBy, setOp, before, beforeOp, during, nmis, entryIfr, tag, top };
}

// marks for attachProbe: the routines whose entry starts a "transition" (frames up to 150
// after are summarised under its name)
export const MARKS = ["LAUN", "TT110", "DOENTRY", "TT18", "Ghy", "MJP", "WARP", "DEATH", "ESCAPE", "BOMBON", "BAY", "SVE", "T_FLARE", "TITLE", "HANGER", "BRIEF", "DEBRIEF", "DEBRIEF2", "BRIEF2", "BRIEF3", "LOOK1"];
export function marksFor(sy, names = MARKS) {
    const out = [];
    for (const name of names) for (const n of [name + "_C", name]) {
        if (sy[n] === undefined) continue;
        const m = mapOfLabel(sy, n), a = sy[n];
        if (a >= 0x8000 && a < 0xc000 && m === "m") continue;
        out.push([a, m, name]); break;
    }
    return out;
}
