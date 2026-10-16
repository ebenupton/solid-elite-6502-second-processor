// Deterministic driver for BBC Master Elite on the emulated BBC Master (jsbeeb).
//
// Shared by harness/mcompare.mjs and the pilot (harness/mpilot.mjs).
//
// Input injection
// ---------------
// Master Elite reads the keyboard in three places only (SNG47, keyboard
// configuration; the joystick and Bitstik are never enabled):
//  * FILLKL, called only from RDKEY (and RDKEY-1, its BCD-only variant used by
//    DOKEY), scans the keyboard matrix directly through the System VIA, fills
//    the key logger (KY1-KY20 at &C4-&D3, via the IKNS table) and returns the
//    highest pressed key's internal number in KL and X. RDKEY then translates
//    it to ASCII through TRTB%.
//  * DKS5 (and CTRL, which falls into it) tests one key (SHIFT on the charts,
//    CTRL for the galactic hyperdrive and for a mis-jump on arrival).
//  * MT26 reads a line with OSWORD 0 (commander names: load/save only; the
//    pilot never goes there, and mlib stops with an error if it does).
// The hardware keyboard is never pressed after boot (all scans see no key), and
// keys are injected at fixed routine boundaries, before the code that consumes
// them:
//  * at RDKEY+5 (the PLA after JSR FILLKL returns) the key logger, KL and X are
//    overwritten with exactly what FILLKL would have produced for the pilot's
//    set of pressed keys (same ZEKTRAN clear, same IKNS walk, same KY19 ghost
//    rule);
//  * at DKS5+17 (the LDA #%00001011 after the LDX VIA+&4F that reads the key)
//    X is set to the key number with bit 7 set if the pilot says it is down.
// The pilot is asked at every such read, with the call site (the label of the
// JSR) and, for TT217/t waits, the routine that called the wait. So both runs
// see the same keys at the same main-loop iteration (DOKEY is called once per
// iteration), the same nth poll of a title loop, and the same nth key wait,
// whatever the wall or emulated timing.
//
// Timing-dependent state (see docs/MASTER-PLAN.md, Stage A): the IRQ handler
// (IRQ1/LINSCN) writes only DL (the vsync flag WSCAN polls), JOPOS (ADC; the
// loader disables conversions and the game reads it only with the joystick
// configured), and the sound buffers (SOINT counts each sound down once per
// vsync, and frees its channel, SOPR = 0, when it ends). LASCT is counted down by
// MLOOP, not by the IRQ, in this version. The sound buffers do leak into game
// state, through NOISE: it picks a channel and accepts or drops the new sound
// by comparing its priority with SOPR, so its returned X, A and C flag depend on
// how many vsyncs have passed since the last sounds; and LASNO's NOISE call is
// followed directly by LASLI, whose first JSR DORND takes that C flag into the
// random number seed (DORND's ROL A). A build that runs at a different speed
// then gets different laser line positions and a different RAND (found with a
// build slowed by one WSCAN per iteration: divergence after 7334 iterations).
// So at every NOISE entry the three SOPR bytes are set to 0 (all channels free):
// NOISE then always takes a channel chosen only by the sound number and returns
// A = &80, X = that channel, C = 1 (or returns at once if sound is off), in both
// runs. The sound mix changes (no priority between sounds); game state does
// not otherwise depend on the sound buffers (only the sound routines and the
// IRQ read them), so they are excluded from the comparison.
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { readFileSync } from "fs";

export const ROOT = decodeURIComponent(new URL("..", import.meta.url).pathname);

export function loadSyms(path) {
    const syms = {};
    for (const m of readFileSync(path, "utf8").matchAll(/'([^']+)':(\d+)L?/g)) if (!(m[1] in syms)) syms[m[1]] = +m[2];
    return syms;
}

// Game state compared per iteration: [start, length, name]. All of these are at
// fixed addresses in the original; a relocated build supplies its own symbols
// and the regions are located by symbol (see regionsFor).
export function regionsFor(sy) {
    return [
        [0x0000, sy.NOSTM + 1 - 0x0000, "ZP"],                  // zero page game variables (&00-&E3)
        [sy["K%"], 0x0800 - sy["K%"], "K%"],                    // ship data blocks + ship line heap (down from &0800)
        [sy.WP, sy.JOPOS + 3 - sy.WP, "WP"],                    // FRIN, flight variables, sun/planet heaps, stardust, commander (NAME..SVC), JOPOS
        [sy.UP, sy["S%"] - sy.UP, "UP"],                        // configuration (COMC..VOL, TGINT)
        [sy["NA%"], sy["NAEND%"] - sy["NA%"], "NA%"],           // last saved commander (template) and checksums
        [sy.SOFLG, sy.SFXPR - sy.SOFLG, "SOUND"],               // sound buffers (written by the IRQ)
    ];
}

// Addresses excluded from the comparison, by symbol: name -> [length, reason]
export const TIMING_EXCLUDE = {
    DL: [1, "set to 30 by the vsync IRQ (LINSCN), cleared and polled by WSCAN: real time"],
    JOPOS: [3, "ADC values written by the IRQ (conversions disabled; only read with the joystick configured)"],
    SOFLG: [sy => sy.SFXPR - sy.SOFLG, "sound buffers SOFLG..SOFRQ, counted down by SOINT in the IRQ"],
};
// Drawing temporaries and heaps: excluded with --loose (for builds whose drawing
// differs; the pilot and the game logic never read them across iterations)
export const DRAW_EXCLUDE = {
    SC: [2, "screen address"], T1: [1, "temp"], T2: [1, "temp"], T3: [1, "temp"], T4: [1, "temp"],
    P: [3, "temp"], Q: [1, "temp"], R: [1, "temp"], S: [1, "temp"], T: [1, "temp"], U: [1, "temp"],
    XX15: [6, "line ends"], XX12: [6, "temp"], K: [4, "temp"], K2: [4, "temp"], K3: [14, "temp"], K4: [2, "temp"],
    K5: [4, "temp"], K6: [5, "temp"], XX16: [18, "temp"], XX0: [2, "blueprint ptr"], XX: [2, "temp"], YY: [2, "temp"],
    XSAV: [1, "temp"], YSAV: [1, "temp"], XX17: [1, "temp"], XX13: [1, "temp"], CNT: [1, "temp"], CNT2: [1, "temp"],
    STP: [1, "temp"], XX4: [1, "temp"], XX20: [1, "temp"], ZZ: [1, "temp"], V: [2, "temp"], LSP: [1, "ball heap ptr"],
    LSNUM: [1, "line heap"], LSNUM2: [1, "line heap"], XX14: [1, "temp"], SWAP: [1, "temp"], COL: [1, "colour"],
    XC: [1, "text cursor"], YC: [1, "text cursor"], LSX2: [256, "planet line heap"], LSY2: [256, "planet line heap"],
    LSO: [200, "sun line heap"], BUF: [90, "line buffer"], XSAV2: [1, "temp"], YSAV2: [1, "temp"],
    COMX: [1, "compass dot"], COMY: [1, "compass dot"], widget: [1, "temp"], dontclip: [1, "temp"], Yx2M1: [1, "temp"],
    newzp: [1, "temp"], XX18: [4, "temp"],
};

export function excludeSet(sy, lists) {
    const ex = new Map();
    for (const list of lists) for (const [n, [len0, why]] of Object.entries(list)) {
        if (sy[n] === undefined) continue;
        const len = typeof len0 === "function" ? len0(sy) : len0;
        for (let i = 0; i < len; i++) ex.set(sy[n] + i, `${n}: ${why}`);
    }
    // with the drawing exclusions, also the ship line heap below &0800 (the K%
    // blocks end at K% + NOSH * NI%)
    if (lists.includes(DRAW_EXCLUDE)) for (let a = sy["K%"] + 12 * 37; a < 0x0800; a++) ex.set(a, "ship line heap");
    return ex;
}

// Machine set-up: boot the Master, insert the disc, SHIFT+BREAK
export async function bootMaster(disc) {
    const s = new MachineSession("Master");
    await s.initialise();
    await s.boot(30);
    s.loadDisc(disc);
    s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
    return s;
}

// Run one build under the pilot.
//   opts.disc, opts.syms (symbol table), opts.pilot (object with keys(ctx), dks(ctx)),
//   opts.iters (MLOOP iterations to record), opts.maxSecs (emulated), opts.seed (array of
//   [addr, bytes] to write at TT170), opts.patch({ wr, rb, sy }) (called at BAY after QU5,
//   i.e. after the title screens' DFAULT: the commander patch), opts.onIter(i, s, res),
//   opts.trace (log injected keys), opts.shots / opts.onShot(s, i) (screenshot every N)
// Returns { snaps (per iteration, regions concatenated), iterTimes, tt100Times
//   ([emulated s, iteration] per TT100), init (snapshot at TT170), initRand, keyLog,
//   events, iters, tt100, emuSecs, error }
export async function runElite(opts) {
    const sy = opts.syms;
    const s = await bootMaster(opts.disc);
    const cpu = s._machine.processor;
    const regions = regionsFor(sy);
    const rd = (a, n = 1) => { const r = new Array(n); for (let i = 0; i < n; i++) r[i] = cpu.ramRomOs[(a + i) & 0xffff]; return r; };
    const rb = a => cpu.ramRomOs[a & 0xffff];
    const wr = (a, bytes) => { for (let i = 0; i < bytes.length; i++) cpu.ramRomOs[a + i] = bytes[i] & 255; };
    // label lookup for call sites (main RAM code only)
    const lab = Object.entries(sy).filter(([k, v]) => v >= 0x1300 && v < 0x8000).sort((a, b) => a[1] - b[1]);
    const labelOf = a => { let lo = 0, hi = lab.length - 1, r = null; while (lo <= hi) { const m = (lo + hi) >> 1; if (lab[m][1] <= a) { r = lab[m][0]; lo = m + 1; } else hi = m - 1; } return r; };
    const stackWord = k => rb(0x100 + ((cpu.s + k) & 0xff)) | (rb(0x100 + ((cpu.s + k + 1) & 0xff)) << 8);

    const RDK_POST = sy.RDKEY + 5, DKS5_POST = sy.DKS5 + 17;
    const res = { snaps: [], iterTimes: [], tt100Times: [], tt100AtIter: [], init: null, keyLog: [], events: [], s, cpu, sy, regions };
    let started = false, done = false, armPatch = false, iter = 0, tt100 = 0, checked = false;
    const ctxBase = { rb, rd, sy, iterOf: () => iter, tt100Of: () => tt100 };

    function fillkl(keys) {
        // as FILLKL: ZEKTRAN clears JSTY+1..JSTY+17, then each pressed key in increasing
        // internal number sets KL and, if it is in IKNS, decrements its logger byte
        for (let i = 1; i <= 17; i++) cpu.ramRomOs[sy.JSTY + i] = 0;
        let x = 0;
        for (const k of [...new Set(keys)].filter(k => k >= 16 && k < 128).sort((a, b) => a - b)) {
            cpu.ramRomOs[sy.KL] = k;
            for (;;) {
                const ik = rb(sy.IKNS + x);
                if (k < ik) break;
                if (k === ik) { cpu.ramRomOs[sy.KY17 + x] = (rb(sy.KY17 + x) - 1) & 255; x++; break; }
                x++;
            }
        }
        cpu.ramRomOs[sy.KY19] = rb(sy.KY19) & (rb(sy.KY6) ^ 0xff);
        cpu.x = rb(sy.KL);
    }

    const handler = pc => {
        if (pc === RDK_POST && started) {
            const callSite = stackWord(2) + 1 - 3;
            const site = labelOf(callSite);
            // for waits (t, t2 in TT217), the routine that called the wait
            let waitFor = null;
            if (site === "t" || site === "t2") waitFor = labelOf(stackWord(4) + 1 - 3);
            const ctx = { ...ctxBase, kind: "rdkey", site, callSite, waitFor };
            const keys = opts.pilot.keys(ctx) || [];
            fillkl(keys);
            if (keys.length) res.keyLog.push([iter, site + (waitFor ? "<" + waitFor : ""), keys.map(k => k.toString(16)).join("+")]);
            if (opts.trace && keys.length) console.log(`iter ${iter} ${site}${waitFor ? "<" + waitFor : ""}: ${keys.map(k => "&" + k.toString(16)).join(" ")}`);
        } else if (pc === DKS5_POST && started) {
            const key = cpu.a;
            const site = labelOf(stackWord(1) + 1 - 3);
            const down = opts.pilot.dks ? opts.pilot.dks({ ...ctxBase, kind: "dks5", key, site }) : false;
            cpu.x = down ? key | 0x80 : key;
            if (down) res.keyLog.push([iter, "DKS5:" + site, key.toString(16)]);
        } else if (pc === sy.NOISE) {
            for (let i = 0; i < 3; i++) cpu.ramRomOs[sy.SOPR + i] = 0;
        } else if (pc === sy.MLOOP && started) {
            res.snaps.push(snapshot());
            res.iterTimes.push(emuSecs());
            res.tt100AtIter.push(tt100);
            if (opts.pilot.observe) opts.pilot.observe({ ...ctxBase, kind: "iter" });
            if (opts.onIter) opts.onIter(iter, s, res);
            iter++;
            if (iter >= opts.iters) { done = true; return true; }
        } else if (pc === sy.TT100 && started) {
            res.tt100Times.push([emuSecs(), iter]);
            tt100++;
        } else if (pc === sy.QU5) {
            armPatch = true;
        } else if (pc === sy.BAY && armPatch) {
            armPatch = false;
            if (opts.patch) opts.patch({ wr, rb, sy });
            res.events.push([iter, "commander patched at BAY"]);
        } else if (pc === sy.MT26 && started) {
            res.events.push([iter, "MT26 (OSWORD line input) reached: not supported"]);
            res.error = "MT26";
            done = true; return true;
        } else if (pc === sy.TT170 && !started) {
            started = true;
            if (!checked) {
                checked = true;
                if (rb(RDK_POST) !== 0x68) throw new Error(`RDKEY+5 is not PLA (&${rb(RDK_POST).toString(16)})`);
                if (rb(DKS5_POST) !== 0xa9 || rb(DKS5_POST + 1) !== 0x0b) throw new Error("DKS5+17 is not LDA #&0B");
            }
            if (opts.seed) for (const [a, bytes] of opts.seed) wr(a, bytes);
            res.init = snapshot();
            res.initRand = rd(sy.RAND, 4);
        }
        return false;
    };
    function snapshot() {
        const out = [];
        for (const [a, n] of regions) out.push(...rd(a, n));
        return Uint8Array.from(out);
    }
    function emuSecs() { return cpu.cycleSeconds + cpu.currentCycles / 2e6; }
    cpu.debugInstruction.add(handler);
    const maxSecs = opts.maxSecs || 7200;
    let shotAt = 0;
    while (!done && emuSecs() < maxSecs) {
        for (let k = 0; k < 40 && !done; k++) { if (handler(cpu.pc)) break; cpu.execute(50000); }
        if (opts.shots && iter >= shotAt + opts.shots) { shotAt = iter; await opts.onShot(s, iter); }
    }
    res.emuSecs = emuSecs();
    res.iters = iter; res.tt100 = tt100;
    handler.remove();
    return res;
}

// Snapshot helpers
export function offsetToAddr(regions, o) {
    for (const [a, n] of regions) { if (o < n) return a + o; o -= n; }
    return -1;
}
export function valAt(regions, buf, ad) {
    let o = 0;
    for (const [a, n] of regions) { if (ad >= a && ad < a + n) return buf[o + ad - a]; o += n; }
    return -1;
}
