// TubeEliteMachine: agentplay's EliteMachine (master/tools/agentplay/lib.mjs)
// for the Tube build: the game runs on the parasite, so the input injection,
// the snapshots and the hooks are the parasite's, while the host (a Master or
// a Model B with sideways RAM, harness/tlib.mjs) runs the display. Everything
// that drives an EliteMachine (session.mjs, fbreplay.mjs, rlive.mjs...) can
// drive this one: it has the same fields (cpu, ram, sy, iter, polls, ...)
// and methods (boot, run, tab, snapshot).
//
// The differences from the Master build's machine:
//  * the parasite has no banks and no ACCCON: every label is in its flat 64K
//    (this.cpu is an adapter with romsel 0 and acccon &08, so that
//    EliteMachine's mapping tests treat &C000-&DFFF as RAM);
//  * DKS5's injection point is DKS5T (tube's DKS5: X holds the answer, A the
//    key), not DKS5+17;
//  * the boot leftovers (seedFrom) are tracked through the parasite's writes;
//  * the host's screen is this.host.ramRomOs (hostScreen() returns its two
//    buffers, as the Master port's: main and shadow RAM &4000-&6FFF).
import { EliteMachine, loadSyms, CYCLES_PER_FRAME } from "../../master/tools/agentplay/lib.mjs";
import { regionsFor, canonFor } from "../../harness/mlib.mjs";
import { bootTube } from "../../harness/tlib.mjs";
import { existsSync } from "fs";
export { loadSyms, CYCLES_PER_FRAME };

export class TubeEliteMachine extends EliteMachine {
    constructor(opts) { super(opts); this.hostKind = opts.host || "Master"; }

    async boot() {
        const t = this.t = await bootTube({ host: this.hostKind, disc: this.disc, mhz: +(process.env.TUBEMHZ || 3) });
        // SHIFT+BREAK: the host boots the disc, its loader starts the parasite
        t.s.keyDown(16); t.s.reset(true); t.host.execute(2e6 * 2); t.s.keyUp(16);
        const par = t.par, host = t.host, self = this;
        this.host = host;
        // the parasite seen as EliteMachine's cpu
        this.cpu = {
            get a() { return par.a; }, set a(v) { par.a = v; },
            get x() { return par.x; }, set x(v) { par.x = v; },
            get y() { return par.y; }, set y(v) { par.y = v; },
            get s() { return par.s; }, get pc() { return par.pc; }, set pc(v) { par.pc = v; },
            get p() { return par.p; },
            romsel: 0, acccon: 8, ramRomOs: par.memory,
            readmem: a => par.readmem(a),
            get cycleSeconds() { return host.cycleSeconds; }, get currentCycles() { return host.currentCycles; },
            oldPcArray: new Uint16Array(256), oldPcIndex: 0,
            get fdc() { return host.fdc; },
        };
        const sy = this.sy;
        this.regions = regionsFor(sy);
        this.canon = canonFor(sy, this.regions);
        this.ram = par.memory;
        this._labels();
        const hook = (name, off = 0) => {
            for (const n of [name + "_C", name]) if (sy[n] !== undefined) return { a: sy[n] + off, m: "m", name };
            return null;
        };
        const H = this.H = {
            RDK: hook("RDKEY", 5), DKS5: hook("DKS5T"), NOISE: hook("NOISE"), MLOOP: hook("MLOOP"), LL5: hook("LL5"),
            TT100: hook("TT100"), QU5: hook("QU5"), BAY: hook("BAY"), TT170: hook("TT170"), NEWBRK: hook("NEWBRK"), S: hook("S%"),
        };
        for (const r of (await import("../../master/tools/agentplay/lib.mjs")).ROUTINES) H[r] = hook(r);
        this.dk15 = hook("DK15");
        H.JOY = [null, null];
        this.hookTab = new Uint8Array(65536);
        for (const h of [...Object.values(H).flat()]) if (h) this.hookTab[h.a] = 1;
        // the boot leftovers: the parasite's writes from S% to TT170
        this.written = new Set(); this.inGame = false;
        const wm = par.writemem.bind(par);
        par.writemem = (a, b) => { if (self.inGame && !self.started) self.written.add(a & 0xffff); return wm(a, b); };
        this.bootWrites = { remove: () => { par.writemem = wm; } };
        // the hooks, on the parasite (one table test per instruction)
        // (whole-code coverage, opts.cover: self.vis, from the game's start (S%), one byte per
        // parasite address, overlay D's code in the overlay region at &10000 up, as coverage())
        const OVS = sy.OVL_START ?? 0x10000, OVC = sy.ovl_cur;
        t.addParHook(pc => {
            const c = self.cpu; c.oldPcIndex = (c.oldPcIndex + 1) & 255; c.oldPcArray[c.oldPcIndex] = pc;
            const vis = self.vis;
            if (vis) vis[pc >= OVS && pc < 0xf800 && par.memory[OVC] === 1 ? 0x10000 + pc : pc] = 1;
            if (!self.hookTab[pc]) return false;
            // (a hook in the overlay region, p-ovl.asm: only while the overlay
            // it was set in, D, is there)
            if (sy.OVL_START !== undefined && pc >= sy.OVL_START && pc < 0xf800 && par.memory[sy.ovl_cur] !== 1) return false;
            return self.tab(pc);
        });
        // page &0D (the NMI routine, the extended vectors, the ROM table) on the host: no
        // write from the host's own code (main RAM or sideways RAM, not the MOS or DFS)
        // once the game has started (as EliteMachine's watch0d for the Master port)
        if (this.opts.watch0d) host.debugWrite.add(a => {
            if (!self.inGame || a < 0x0d00 || a > 0x0dff) return false;
            const pc = host.oldPcArray[host.oldPcIndex], rs = host.romsel & 15;
            if (pc >= 0x0d00 && pc < 0x0e00) return false;      // (the DFS's NMI code itself)
            const hs = self.hostSyms();                         // (HNMI, h-cold.asm: the minimal NMI handler put back after a disc command, as the port's DOSNMI)
            if (hs && hs.HNMI !== undefined && pc >= hs.HNMI && pc < hs.HNMI_END) return false;
            const swr = this.hostKind === "B" ? !!(host.model?.swram?.[rs]) : rs >= 4 && rs <= 7;
            const inRam = pc < 0x8000 || (pc < 0xc000 && swr) || (this.hostKind !== "B" && ((pc < 0x9000 && pc >= 0x8000 && (host.romsel & 0x80)) || (pc >= 0xc000 && pc < 0xe000 && (host.acccon & 8))));
            if (inRam && self.page0d.length < 20) { self.page0d.push([self.iter, pc, a]); self.event("page0d", `host PC &${pc.toString(16)} (bank ${rs}) wrote &${a.toString(16)}`); }
            return false;
        });
        this.s = t.s;
        this.s._video.frameSkipCount = +(process.env.FRAMESKIP || 25);
        this.cyclesNow = () => host.cycleSeconds * 2e6 + host.currentCycles;
    }

    // every label is in the parasite's flat 64K
    _labels() {
        const labs = [];
        for (const [k, v] of Object.entries(this.sy)) if (v >= 0x0800 && !/^(CODE|LOAD)/.test(k)) labs.push([k, v]);
        labs.sort((a, b) => a[1] - b[1]);
        this.labs = { m: labs };
    }
    labelOf(a) {
        // (the overlay region, p-ovl.asm: the labels of the overlay in it, D's
        // being the cold copy's, name_C, S's the others)
        const sy = this.sy;
        if (sy.OVL_START !== undefined && a >= sy.OVL_START && a < 0xf800) {
            const d = this.ram[sy.ovl_cur] === 1;
            const lab = (this.labsOvl ||= this.labs.m.filter(([k, v]) => v >= sy.OVL_START && v < 0xf800));
            let r = null;
            for (const [k, v] of lab) if (v <= a && k.endsWith("_C") === d) r = k;
            return r && r.endsWith("_C") ? r.slice(0, -2) : r;
        }
        const lab = this.labs.m;
        let lo = 0, hi = lab.length - 1, r = null;
        while (lo <= hi) { const m = (lo + hi) >> 1; if (lab[m][1] <= a) { r = lab[m][0]; lo = m + 1; } else hi = m - 1; }
        return r && r.endsWith("_C") ? r.slice(0, -2) : r;
    }
    // (a label in the overlay region is overlay D's, name_C, and is reached only
    // while D is in: ovl_cur 1, p-ovl.asm; S's code shares its addresses)
    _at(h, pc) {
        if (!h || pc !== h.a) return false;
        const sy = this.sy;
        return !(sy.OVL_START !== undefined && pc >= sy.OVL_START && pc < (sy.RING ?? 0xF400)) || this.ram[sy.ovl_cur] === 1;
    }

    // as EliteMachine.tab, but DKS5's answer goes into X at DKS5T (A is the key)
    tab(pc) {
        if (this._at(this.H.DKS5, pc) && this.started) {
            const c = this._callerAt(1);
            const ctx = { m: this, kind: "dks5", poll: this.polls, iter: this.iter, key: this.cpu.a, site: this.labelOf(c.site, 0) };
            const down = this.input.dks5(ctx);
            if (down === null) return this._block(ctx);
            this.blocked = null;
            this.cpu.x = down ? this.cpu.a | 0x80 : this.cpu.a;
            this.polls++; this.lastProgressCycles = this.cyclesNow();
            return false;
        }
        return super.tab(pc);
    }
    _callerAt(k, romsel = 0) {
        const w = this._stackWord(k);
        return { site: w + 1 - 3, romsel: 0, k };
    }
    _findJoy() {
        const dk = this.dk15, sy = this.sy, J = [];
        if (dk) for (let i = 0; i < 48 && J.length < 2; i++) {
            const op = j => this.ram[(dk.a + j) & 0xffff];
            if (op(i) === 0xad && (op(i + 1) | op(i + 2) << 8) === sy.JOPOS + J.length) J.push({ a: dk.a + i, m: "m" });
        }
        this.H.JOY = J;
        for (const h of J) this.hookTab[h.a] = 1;
    }

    // run up to `cycles` host cycles, or to a poll the input cannot answer
    run(cycles) {
        const t = this.t, end = this.cyclesNow() + cycles;
        for (;;) {
            // (a blocked poll is asked again by the parasite's hook, as the
            // parasite is stopped at it)
            const left = end - this.cyclesNow();
            if (left <= 0) return "ok";
            t.stopped = false;
            t.host.execute(Math.max(16, Math.min(left, 20000)));
            if (t.stopped && this.blocked) return "blocked";
            if (process.env.TUBEDBG && !this.dbgDone && this.started && this.cyclesNow() - this.lastProgressCycles > 20 * 2e6) {
                this.dbgDone = true;
                const hs = loadSyms(this.opts.disc.replace(/elite-tube\.ssd$/, "hsyms.txt"));
                const near = (sy, pc) => { let b = null; for (const [n, v] of Object.entries(sy)) if (v <= pc && (!b || v > b[1])) b = [n, v]; return b ? `${b[0]}+${pc - b[1]}` : pc.toString(16); };
                console.log(`TUBEDBG stall: parasite ${near(this.sy, t.par.pc)}, host ${near(hs, t.host.pc)} (&${t.host.pc.toString(16)}), host I ${t.host.p.i}, R1 host status &${t.tube.hostStatus[0].toString(16)}, R4 par status &${t.tube.parasiteStatus[3].toString(16)}`);
            }
        }
    }

    // whole-code coverage of the parasite: every label whose span (to the next label) had an
    // instruction run; overlay D's labels (name_C) in the overlay region apart from S's.
    // Code labels never run: those that are the target of a JSR or JMP in the parasite's
    // memory as it is at the end (with the overlay then in)
    coverage() {
        if (!this.vis) return null;
        const sy = this.sy, vis = this.vis, mem = this.ram, OVS = sy.OVL_START ?? 0x10000;
        const sets = { m: [], D: [], S: [] };
        for (const [k, v] of Object.entries(sy)) {
            if (v < 0x0800 || v > 0xffff || /^(CODE|LOAD)/.test(k)) continue;
            if (v >= OVS && v < 0xf800) sets[k.endsWith("_C") ? "D" : "S"].push([k, v]); else sets.m.push([k, v]);
        }
        const targets = new Set();
        for (let i = 0x0800; i < 0xfffd; i++) { const o = mem[i]; if (o === 0x20 || o === 0x4c) targets.add(mem[i + 1] | mem[i + 2] << 8); }
        const reached = [], unreached = [];
        for (const [set, labs] of Object.entries(sets)) {
            labs.sort((a, b) => a[1] - b[1]);
            const base = set === "D" ? 0x10000 : 0;
            for (let i = 0; i < labs.length; i++) {
                const [k, v] = labs[i], end = i + 1 < labs.length ? Math.max(v + 1, labs[i + 1][1]) : v + 1;
                let hit = false;
                for (let a = v; a < end && !hit; a++) hit = vis[base + a] === 1;
                if (hit) reached.push(k); else if (targets.has(v)) unreached.push(k);
            }
        }
        return { reached, unreached };
    }

    // the dashboard for observe.mjs: the host draws the Master port's mode 1 panel at
    // &7000-&7DFF, in shadow RAM on the Master host, in main RAM on the Model B host
    get dashMode() { return 1; }
    dashMem() {
        const m = this.host.ramRomOs, a = this.hostKind === "B" ? 0x7000 : 0x8000 + 0x7000;
        return m.subarray(a, a + 0xe00);
    }
    // fn(iteration) where the host reaches the end of that iteration's frame: C_SYNC, which
    // the parasite sends at p_sync (hframe, after G_FRAME), as tfbreplay.mjs keys its hashes.
    // The host's symbols are its build's (hsyms.txt, or hbmsyms.txt for the Model B host)
    // beside the parasite's
    hostSyms() {
        if (this._hsy === undefined) {
            const sp = this.opts.symsPath, f = sp && sp.replace(/[^/]*$/, this.hostKind === "B" ? "hbmsyms.txt" : "hsyms.txt");
            this._hsy = f && existsSync(f) ? loadSyms(f) : null;
        }
        return this._hsy;
    }
    onDashSync(fn) {
        const hsy = this.hostSyms();
        if (!hsy) throw new Error("TubeEliteMachine.onDashSync: no host symbols beside the parasite's (symsPath)");
        const q = [], P = this.sy.p_sync, host = this.host, HS = hsy.h_sync, HSB = hsy.h_syncb;
        this.t.addParHook(pc => { if (pc === P) q.push(this.iter); return false; });
        let seen = false;
        host.debugInstruction.add(pc => {
            if (pc !== HS && pc !== HSB) return false;
            // (the Model B host: another bank may have code at h_sync's address; only bank F's
            // NOP there is C_SYNC's. jsbeeb skips this hook on a slice's first instruction:
            // h_sync is a NOP and h_syncb the instruction after it, so one of the two is seen)
            if (host.readmem(HS) !== 0xea) return false;
            if (pc === HS) seen = true;
            else if (!seen) pc = HS;
            else { seen = false; return false; }
            if (q.length) fn(q.shift());
            return false;
        });
    }

    // the bulbs' EOR bitmaps, as the port's (build/dashtab-spbt.asm, dashtab-ecbt.asm,
    // made by tools/dashboard.py; both hosts draw the same)
    bulbPattern(sym) {
        return { SPBT: [0x07, 0x0C, 0x0D, 0x0E, 0x0F, 0x0C, 0x07, 0x00, 0x0E, 0x03, 0x0F, 0x07, 0x0B, 0x03, 0x0E, 0x00],
            ECBT: [0x77, 0xCC, 0xDD, 0xCC, 0xDD, 0xCC, 0x77, 0x00, 0xEE, 0x33, 0xFF, 0x77, 0xFF, 0x33, 0xEE, 0x00] }[sym];
    }

    // the host's two screen buffers (main RAM's &4000-&6FFF, then shadow RAM's)
    hostScreen() {
        const m = this.host.ramRomOs;
        if (this.hostKind === "B") return [m.subarray(0x1000, 0x4000), m.subarray(0x4000, 0x7000)];   // (the Model B host: buffer 0 at &1000)
        return [m.subarray(0x4000, 0x7000), m.subarray(0xc000, 0xf000)];
    }
}
