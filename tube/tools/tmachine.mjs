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
        t.addParHook(pc => {
            const c = self.cpu; c.oldPcIndex = (c.oldPcIndex + 1) & 255; c.oldPcArray[c.oldPcIndex] = pc;
            return self.hookTab[pc] ? self.tab(pc) : false;
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
        const lab = this.labs.m;
        let lo = 0, hi = lab.length - 1, r = null;
        while (lo <= hi) { const m = (lo + hi) >> 1; if (lab[m][1] <= a) { r = lab[m][0]; lo = m + 1; } else hi = m - 1; }
        return r && r.endsWith("_C") ? r.slice(0, -2) : r;
    }
    _at(h, pc) { return !!h && pc === h.a; }

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

    // the host's two screen buffers (main RAM's &4000-&6FFF, then shadow RAM's)
    hostScreen() {
        const m = this.host.ramRomOs;
        if (this.hostKind === "B") return [m.subarray(0x1000, 0x4000), m.subarray(0x4000, 0x7000)];   // (the Model B host: buffer 0 at &1000)
        return [m.subarray(0x4000, 0x7000), m.subarray(0xc000, 0xf000)];
    }
}
