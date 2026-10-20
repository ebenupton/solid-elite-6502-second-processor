// agentplay's machine: BBC Master Elite on jsbeeb, with harness/mlib.mjs's input model
// (keys injected at the routine boundaries where the game reads the keyboard, so the
// game sees the same keys at the same read whatever the timing), made steppable so that
// two machines can run side by side, one fed by elite-agent and the other replaying the
// first one's reads as they happen.
//
// Every read of an input is a numbered "poll", in the order the game makes them:
//   rdkey  RDKEY+5, after FILLKL: the key logger, KL and X are set for the held keys
//          (as mlib's fillkl, the same IKNS walk and KY19 rule);
//   dks5   DKS5+17: one key tested (SHIFT on the charts, CTRL for the galactic
//          hyperdrive and a mis-jump), X gets bit 7 if it is held;
//   joy    DK15's two LDA JOPOS / JOPOS+1 (joystick configured, JSTK <> 0): JOPOS is
//          written with the stick's ADC high bytes just before each is read (so the
//          IRQ's own ADC writes cannot get in between).
// A machine's input source answers each poll, or returns null to block: the machine then
// stops at that instruction and the poll is asked again on the next run().
//
// Also as mlib (and for the same reasons, documented there): at NOISE the three SOPR
// bytes are cleared; at the LL5 call that feeds ALTIT, Q is cleared; at TT170 the
// candidate's boot leftovers are seeded from the reference (seedFrom). At every MLOOP the
// game state (mlib.regionsFor) is snapshotted.
//
// What it watches for besides: BRKs that reach the game's BRK handler (NEWBRK) with
// where they came from, writes by game code to page &0D (off limits on the Master),
// and the routine labels of each poll (control flow).
import { loadSyms, mapAt, mapOfLabel, physRead, regionsFor, canonFor, excludeSet, TIMING_EXCLUDE, RELOC_EXCLUDE, DRAW_EXCLUDE, bootMaster } from "../../../harness/mlib.mjs";
export { loadSyms, regionsFor };

export const ROOT = decodeURIComponent(new URL("../../..", import.meta.url).pathname).replace(/\/$/, "") + "/";
export const NI = 37, NOSH = 12;
export const CYCLES_PER_FRAME = 40000;          // 2 MHz, 50 Hz
// routines whose entries are counted (coverage): launch, docking, hyperspace, galactic
// hyperspace, witchspace, mis-jump, in-system jump, death, escape pod, energy bomb, E.C.M.,
// missiles (ours and theirs), explosions, Thargoids, the docked screens, save and load,
// the missions' briefings and debriefings, pause
export const ROUTINES = ["LAUN", "DOENTRY", "TT18", "Ghy", "MJP", "ptg", "WARP", "DEATH", "ESCAPE", "BOMBON", "ECBLB2", "ECMOF",
    "FRMIS", "SFRMIS", "EXNO3", "GTHG", "EQSHP", "TT219", "TT208", "TT213", "TT25", "TT167", "STATUS", "SVE", "LOD",
    "BRIEF", "BRIEF2", "BRIEF3", "DEBRIEF", "DEBRIEF2", "FREEZE"];

export class EliteMachine {
    // opts: name, disc, syms (loadSyms), input ({ rdkey(ctx), dks5(ctx), joy(ctx) }),
    //       seedFrom (another EliteMachine whose TT170 state seeds this one's boot leftovers),
    //       rand (4 bytes written to RAND at TT170), patch(m) (called once, at the first QU5),
    //       watch0d (record page &0D writes by game code)
    constructor(opts) {
        Object.assign(this, { name: opts.name, disc: opts.disc, sy: opts.syms, input: opts.input, opts });
        this.iter = 0; this.polls = 0; this.joys = 0; this.tt100 = 0;
        this.snaps = [];            // [iteration, snapshot] not yet taken by the comparison
        this.events = [];           // [iteration, kind, detail]
        this.started = false; this.blocked = null; this.patched = false; this.armPatch = false;
        this.lastProgressCycles = 0; this.page0d = []; this.brks = [];
        this.iterInfo = [];
        this.wa = Object.fromEntries((opts.workarounds || []).map(w => [w, true]));         // per iteration: [poll index at MLOOP, emulated seconds]
    }

    async boot() {
        this.s = await bootMaster(this.disc);
        const cpu = this.cpu = this.s._machine.processor;
        const sy = this.sy;
        this.regions = regionsFor(sy);
        this.canon = canonFor(sy, this.regions);   // (the station's line heap pointer, LSO)
        this.ram = cpu.ramRomOs;
        this._labels();
        // (a label in sideways RAM with no bank in banks.txt can't be told from whatever
        // else is at that address in another bank: then its stub, if it has one in main
        // RAM, or nothing)
        const hook = (name, off = 0) => {
            for (const n of [name + "_C", name]) {
                if (sy[n] === undefined) continue;
                const a = sy[n] + off, m = mapOfLabel(sy, n);
                if (a >= 0x8000 && a < 0xc000 && m === "m") continue;
                return { a, m, name };
            }
            return null;
        };
        const H = this.H = {
            RDK: hook("RDKEY", 5), DKS5: hook("DKS5", 17), NOISE: hook("NOISE"), MLOOP: hook("MLOOP"), LL5: hook("LL5"),
            TT100: hook("TT100"), QU5: hook("QU5"), BAY: hook("BAY"), TT170: hook("TT170"), NEWBRK: hook("NEWBRK"), S: hook("S%"),
        };
        // routines counted as events (coverage): what the session did, in each machine
        for (const r of ROUTINES) H[r] = hook(r);
        // the two joystick reads in DK15 (found once the game is loaded: _findJoy at TT170)
        this.dk15 = hook("DK15");
        H.JOY = [null, null];
        this.hookTab = new Uint8Array(65536);
        for (const h of [...Object.values(H).flat()]) if (h) this.hookTab[h.a] = 1;
        // boot writes (for seeding) and page &0D watch
        this.written = new Set(); this.inGame = false;
        this.bootWrites = cpu.debugWrite.add(a => { if (this.inGame && !this.started && a < 0x8000) this.written.add(a); return false; });
        if (this.opts.watch0d) cpu.debugWrite.add(a => {
            if (!this.inGame || a < 0x0d00 || a > 0x0dff) return false;
            const pc = cpu.oldPcArray[cpu.oldPcIndex], rs = cpu.romsel & 15;     // (the writing instruction's own address)
            const inRam = pc < 0x8000 || (pc < 0xc000 && rs >= 4 && rs <= 7) || (pc < 0x9000 && pc >= 0x8000 && (cpu.romsel & 0x80)) || (pc >= 0xc000 && pc < 0xe000 && (cpu.acccon & 8));
            if (pc >= 0x0d00 && pc < 0x0e00) return false;      // (the DFS NMI code itself, in page &0D during a disc access)
            if (sy.DOSNMI_C !== undefined && pc >= sy.DOSNMI_C && pc < sy.DOSNMI_END_C && rs === 7) return false;
            if (inRam && this.page0d.length < 20) { this.page0d.push([this.iter, pc, a]); this.event("page0d", `PC &${pc.toString(16)} wrote &${a.toString(16)}`); }
            return false;
        });
        this._fastExec();
        // render the picture one frame in FRAMESKIP (default 25; screenshot() renders a fresh one)
        this.s._video.frameSkipCount = +(process.env.FRAMESKIP || 25);
        this.cyclesNow = () => cpu.cycleSeconds * 2e6 + cpu.currentCycles;
    }

    // jsbeeb's execute, with this machine's hooks tested inline (a table lookup per
    // instruction rather than a chain of hook calls): about twice as fast. Other
    // debugInstruction hooks (traces) are still called.
    _fastExec() {
        const cpu = this.cpu, tab = this.hookTab, self = this;
        cpu.execute = function (n) {
            this.halted = false;
            this.targetCycles += n;
            const smaller = Math.min(this.targetCycles, this.currentCycles) & 0xfffffffe;
            if (smaller >= 2 * 1000 * 1000) { this.targetCycles -= 2 * 1000 * 1000; this.currentCycles -= 2 * 1000 * 1000; this.cycleSeconds++; }
            let first = true;
            const vis = self.vis;
            while (!this.halted && this.currentCycles < this.targetCycles) {
                const pc = this.pc;
                if (vis) {
                    if (pc < 0x8000) vis[pc] = 1;
                    else if (pc < 0xc000) vis[(this.romsel & 0x80) && pc < 0x9000 ? 0x50000 + pc - 0x8000 : 0x10000 + ((this.romsel & 15) << 14) + pc - 0x8000] = 1;
                    else if (pc < 0xe000 && (this.acccon & 8)) vis[pc] = 1;
                }
                this.oldPcIndex = (this.oldPcIndex + 1) & 0xff;
                this.oldPcArray[this.oldPcIndex] = pc;
                this.memStatOffset = this.memStatOffsetByIFetchBank & (1 << (pc >>> 12)) ? 256 : 0;
                const opcode = this.readmem(pc);
                if (!first) {
                    if (tab[pc] && self.tab(pc)) { this.halted = true; return false; }
                    if (this._debugInstruction && this._debugInstruction(pc, opcode)) return false;
                }
                first = false;
                this.incpc();
                this.runner.run(opcode);
                if (this.takeInt) this.brk(true);
                if (!this.resetLine) this.reset(false);
            }
            return !this.halted;
        };
    }
    // whole-code coverage (opts.cover): every label whose span (to the next label in the
    // same mapping) had an instruction run, and the labels that look like code (run, or
    // the target of a JSR/JMP in the image) but were never run. Main RAM, HAZEL (when
    // paged), the sideways banks and ANDY are told apart (the port's code is in all of
    // them; the original's is all in main RAM)
    static visIndex(map, a) { return map === "m" ? a : map === "A" ? 0x50000 + a - 0x8000 : 0x10000 + (map << 14) + a - 0x8000; }
    coverage() {
        if (!this.vis) return null;
        const sy = this.sy, vis = this.vis, mem = this.cpu.ramRomOs;
        const byMap = {};
        for (const [k, v] of Object.entries(sy)) {
            if (v < 0x0800 || v >= 0xe000 || /^(CODE|LOAD)/.test(k)) continue;
            const m = mapOfLabel(sy, k);
            if (m === "m" && v >= 0x8000 && v < 0xc000) continue;
            (byMap[m] ||= []).push([k, v]);
        }
        const targets = new Set();
        const scan = (base, n) => { for (let i = 0; i < n - 2; i++) { const o = mem[base + i]; if (o === 0x20 || o === 0x4c) targets.add(mem[base + i + 1] | mem[base + i + 2] << 8); } };
        scan(0x0800, 0x7800); scan(0x9000, 0x2000);             // (main RAM; HAZEL)
        for (const m of Object.keys(byMap)) if (m === "A") scan(0x8000, 0x1000); else if (m !== "m") scan(this.cpu.romOffset + (+m << 14), 0x4000);
        const reached = [], unreached = [];
        for (const [m, labs] of Object.entries(byMap)) {
            labs.sort((a, b) => a[1] - b[1]);
            for (let i = 0; i < labs.length; i++) {
                const [k, v] = labs[i], end = i + 1 < labs.length ? Math.max(v + 1, labs[i + 1][1]) : v + 1;
                const map = m === "m" || m === "A" ? m : +m;
                let hit = false;
                for (let a = v; a < end && !hit; a++) hit = vis[EliteMachine.visIndex(map, a)] === 1;
                if (hit) reached.push(k); else if (targets.has(v)) unreached.push(k);
            }
        }
        return { reached, unreached };
    }
    // (opts.hazelCheck, the port) HAZEL's read-only game data must never change: the
    // blueprints and their tables at &C000-&C2FF and from HZDATA2 (XX21) to &DFFF, but
    // for XX21's station entry (NWSPS). DOSCLI stashes HAZEL for each disc command and
    // copies it back; a byte that differs at an MLOOP from its value at the first one
    // means the stash, or something else, lost it. HAZEL is at &9000-&AFFF in jsbeeb's
    // memory. Reported once, as a "hazel" event, with the differing ranges
    _hazelCheck() {
        const mem = this.cpu.ramRomOs, sy = this.sy;
        const xx = sy.XX21 ?? sy.HZDATA2 ?? 0xc4c9;          // (XX21 starts HZDATA2)
        if (!this.hazel0) { this.hazel0 = mem.slice(0x9000, 0xb000); this.hazelBad = false; return; }
        if (this.hazelBad) return;
        const diffs = [];
        for (let a = 0xc000; a < 0xe000; a++) {
            if (a >= 0xc300 && a < xx) continue;                // (the renderer's glue)
            if (a === xx + 2 || a === xx + 3) continue;
            const i = a - 0xc000;
            if (mem[0x9000 + i] !== this.hazel0[i]) diffs.push(a);
        }
        if (!diffs.length) return;
        this.hazelBad = true;
        const ranges = []; for (const a of diffs) { const r = ranges.at(-1); if (r && a === r[1] + 1) r[1] = a; else ranges.push([a, a]); }
        this.event("hazel", `HAZEL's read-only data changed (${diffs.length} bytes: ${ranges.slice(0, 12).map(([x, y]) => x === y ? `&${x.toString(16)}` : `&${x.toString(16)}-&${y.toString(16)}`).join(" ")}${ranges.length > 12 ? " ..." : ""}), first ${diffs.slice(0, 4).map(a => `&${a.toString(16)} ${this.hazel0[a - 0xc000].toString(16)}->${mem[0x9000 + a - 0xc000].toString(16)}`).join(", ")}`);
    }
    emuSecs() { return this.cpu.cycleSeconds + this.cpu.currentCycles / 2e6; }
    rb(a) { return this.ram[a & 0xffff]; }
    rd(a, n) { return Array.from(this.ram.subarray(a, a + n)); }
    wr(a, bytes) { for (let i = 0; i < bytes.length; i++) this.ram[a + i] = bytes[i] & 255; }
    event(kind, detail) { this.events.push([this.iter, kind, detail]); }

    _labels() {
        const sy = this.sy, labs = {};
        for (const [k, v] of Object.entries(sy)) {
            if (v < 0x0800 || /^(CODE|LOAD)/.test(k)) continue;
            const m = mapOfLabel(sy, k);
            if (m === "m" && v >= 0x8000) continue;
            (labs[m] ||= []).push([k, v]);
        }
        for (const l of Object.values(labs)) l.sort((a, b) => a[1] - b[1]);
        this.labs = labs;
    }
    labelOf(a, romsel = this.cpu.romsel) {
        const lab = this.labs[mapAt(romsel, a)] || [];
        let lo = 0, hi = lab.length - 1, r = null;
        while (lo <= hi) { const m = (lo + hi) >> 1; if (lab[m][1] <= a) { r = lab[m][0]; lo = m + 1; } else hi = m - 1; }
        return r && r.endsWith("_C") ? r.slice(0, -2) : r;
    }
    _stackWord(k) { const s = this.cpu.s; return this.rb(0x100 + ((s + k) & 0xff)) | (this.rb(0x100 + ((s + k + 1) & 0xff)) << 8); }
    // the JSR whose return address is at S+k, through far-call frames (as mlib)
    _callerAt(k, romsel = this.cpu.romsel) {
        let w = this._stackWord(k);
        while (this.sy.farret !== undefined && w + 1 === this.sy.farret) {
            romsel = this.rb(0x100 + ((this.cpu.s + k + 2) & 0xff));
            k += 3;
            w = this._stackWord(k);
        }
        return { site: w + 1 - 3, romsel, k };
    }
    _at(h, pc) {
        if (!h || pc !== h.a) return false;
        if (h.m !== "m") return h.m === mapAt(this.cpu.romsel, pc);
        return pc < 0xc000 || pc >= 0xe000 || (this.cpu.acccon & 8) !== 0;     // (&C000-&DFFF: HAZEL, not the MOS)
    }

    _fillkl(keys) {
        const sy = this.sy, ram = this.ram;
        for (let i = 1; i <= 17; i++) ram[sy.JSTY + i] = 0;
        let x = 0;
        for (const k of [...new Set(keys)].filter(k => k >= 16 && k < 128).sort((a, b) => a - b)) {
            ram[sy.KL] = k;
            for (;;) {
                const ik = physRead(this.cpu, mapOfLabel(sy, "IKNS"), sy.IKNS + x);     // (IKNS may be in bank 4)
                if (k < ik) break;
                if (k === ik) { ram[sy.KY17 + x] = (this.rb(sy.KY17 + x) - 1) & 255; x++; break; }
                x++;
            }
        }
        ram[sy.KY19] = this.rb(sy.KY19) & (this.rb(sy.KY6) ^ 0xff);
        this.cpu.x = this.rb(sy.KL);
    }

    snapshot() {
        const parts = this.regions.map(([a, n]) => this.ram.subarray(a, a + n));
        const out = new Uint8Array(parts.reduce((s, p) => s + p.length, 0));
        let o = 0; for (const p of parts) { out.set(p, o); o += p.length; }
        return this.canon(out);
    }

    // the per-instruction hook; true stops the machine at pc (a blocked poll)
    tab(pc) {
        if (!this.hookTab[pc]) return false;
        const H = this.H, cpu = this.cpu, sy = this.sy;
        if (this._at(H.RDK, pc) && this.started) {
            const c = this._callerAt(2);
            const site = this.labelOf(c.site, c.romsel);
            let waitFor = null;
            if (site === "t" || site === "t2") { const w = this._callerAt(c.k + 2, c.romsel); waitFor = this.labelOf(w.site, w.romsel); }
            const ctx = { m: this, kind: "rdkey", poll: this.polls, iter: this.iter, site: waitFor ? `${site}<${waitFor}` : site };
            const keys = this.input.rdkey(ctx);
            if (keys === null) return this._block(ctx);
            this.blocked = null;
            this._fillkl(keys);
            this.polls++; this.lastProgressCycles = this.cyclesNow();
        } else if (this._at(H.DKS5, pc) && this.started) {
            const c = this._callerAt(1);
            const ctx = { m: this, kind: "dks5", poll: this.polls, iter: this.iter, key: cpu.a, site: this.labelOf(c.site, c.romsel) };
            const down = this.input.dks5(ctx);
            if (down === null) return this._block(ctx);
            this.blocked = null;
            cpu.x = down ? cpu.a | 0x80 : cpu.a;
            this.polls++; this.lastProgressCycles = this.cyclesNow();
        } else if ((this._at(H.JOY[0], pc) || this._at(H.JOY[1], pc)) && this.started) {
            const which = this._at(H.JOY[0], pc) ? 0 : 1;
            const ctx = { m: this, kind: "joy", joy: this.joys, iter: this.iter, which };
            const v = this.input.joy(ctx);
            if (v === null) return this._block(ctx);
            this.blocked = null;
            this.ram[sy.JOPOS + which] = v & 255;
            this.joys++;
        } else if (this._at(H.NOISE, pc)) {
            for (let i = 0; i < 3; i++) this.ram[sy.SOPR + i] = 0;
        } else if (this._at(H.LL5, pc)) {
            const ret = (this.rb(0x101 + cpu.s) | this.rb(0x102 + cpu.s) << 8) + 1;
            const rc = a => cpu.readmem(a & 0xffff);     // (the caller's code, as paged: it may be in bank 4)
            if (rc(ret) === 0xa5 && rc(ret + 1) === sy.Q && rc(ret + 2) === 0x8d && (rc(ret + 3) | rc(ret + 4) << 8) === sy.ALTIT)
                this.ram[sy.Q] = 0;
        } else if (this._at(H.MLOOP, pc) && this.started) {
            // harness pokes (styles.mjs chaos), at an iteration boundary in both machines
            const pk = this.pokes && this.pokes.get(this.iter);
            if (pk) for (const [sym, off, bytes] of pk) this.wr(this.sy[sym] + off, bytes);
            this.snaps.push([this.iter, this.snapshot()]);
            this.iterInfo.push([this.polls, this.emuSecs()]);
            if (this.opts.hazelCheck && this.iter % 16 === 0) this._hazelCheck();
            if (this.onIter) this.onIter(this);
            this.iter++; this.lastProgressCycles = this.cyclesNow();
        } else if (this._at(H.TT100, pc) && this.started) {
            this.tt100++;
        } else if (this._at(H.QU5, pc)) {
            // the commander patch, once: at QU5, before DFAULT copies NA% (the last-saved
            // commander) into the commander and the game sets up the current system from it
            if (!this.patched && this.opts.patch) { this.patched = true; this.opts.patch(this); this.event("patch", "commander patched at QU5"); }
        } else if (this._at(H.S, pc) && !this.inGame) {
            this.inGame = true;
            if (this.opts.cover) this.vis = new Uint8Array(0x51000);    // (whole-code coverage, from the game's start: visIndex)
            if (this.onEntry) this.onEntry(this);
        } else if (this._at(H.TT170, pc) && !this.started) {
            if (this.opts.seedFrom && !this.opts.seedFrom.init) return this._block({ kind: "tt170" });
            this.blocked = null;
            this.started = true;
            if (this.opts.seedFrom) this.seeded = this._seed(this.opts.seedFrom);
            if (this.opts.rand) this.wr(sy.RAND, this.opts.rand);
            this.bootWrites.remove();
            this._findJoy();
            this.init = this.snapshot();
            this.lastProgressCycles = this.cyclesNow();
        } else if (this._at(H.NEWBRK, pc)) {
            // the game's BRK handler: where did the BRK come from? (the MOS leaves the
            // error block's address in &FD/&FE: the byte after the BRK)
            const ep = this.rb(0xfd) | this.rb(0xfe) << 8;
            const brkAt = (ep - 1) & 0xffff;
            // a BRK in a paged ROM or sideways RAM bank: the bank is the MOS's "ROM
            // active at the last BRK" (&24A); a DFS error (bank 9 up) is expected, a
            // BRK in Elite's banks (4-7) or main RAM is not
            const paged = brkAt >= 0x8000 && brkAt < 0xc000, bank = this.rb(0x24a) & 15;
            const byte = a => paged ? physRead(cpu, bank, a) : brkAt >= 0xe000 ? cpu.ramRomOs[cpu.osOffset + (a & 0x3fff)] : this.rb(a);
            let msg = ""; for (let i = 1; i < 40; i++) { const ch = byte((ep + i) & 0xffff); if (!ch) break; msg += ch >= 32 && ch < 127 ? String.fromCharCode(ch) : "."; }
            const code = byte(ep);
            // (DFS builds some of its errors, "Not found" among them, on the stack page and
            // BRKs there: a filing-system error too)
            // (and a BRK in the MOS's own &E000-&FFFF, as for a bad OS command: an OS error)
            const fromRom = (paged && bank >= 8) || (brkAt >= 0x100 && brkAt < 0x200) || brkAt >= 0xe000;
            const rec = { iter: this.iter, at: brkAt, bank: paged ? bank : "m", code, msg, polls: this.polls, label: paged && !fromRom ? this.labelOf(brkAt, bank) : !paged ? this.labelOf(brkAt) : null, fromRom };
            this.brks.push(rec);
            this.event(fromRom ? "brk-rom" : "brk", `BRK at &${brkAt.toString(16)} (bank ${rec.bank}${rec.label ? ", " + rec.label : ""}) error ${code}: ${msg}`);
        } else if (this.wa.look1 && this._at(H.DEATH, pc) && this._look1FallThrough()) {
            // --workaround look1 (candidate only): finding LOOK1-DEATH, LOOK1 falls through
            // into DEATH where it used to fall into SIGHT; go to SIGHT, as the original does
            this.event("workaround", "LOOK1 fell through into DEATH: sent to SIGHT");
            this.redirectTo = sy.SIGHT;
            return true;
        } else if (this.started) {
            for (const k of ROUTINES) if (this._at(H[k], pc)) { this.event("routine", k); if (k === "SVE") this.sveAt = this.iter; break; }
        }
        return false;
    }
    _findJoy() {
        const dk = this.dk15, sy = this.sy, J = [];
        const op = i => physRead(this.cpu, dk.m, dk.a + i);
        for (let i = 0; i < 48 && J.length < 2; i++)
            if (op(i) === 0xad && (op(i + 1) | op(i + 2) << 8) === sy.JOPOS + J.length) J.push({ a: dk.a + i, m: dk.m });
        if (J.length !== 2) throw new Error(`${this.name}: DK15's LDA JOPOS / JOPOS+1 not found`);
        this.H.JOY = J;
        for (const h of J) this.hookTab[h.a] = 1;
    }
    // DEATH entered by falling out of the JSR WPSHPS just before it: the instruction before
    // was an RTS, and the return address it popped is DEATH-1 (legitimate entries are by
    // JSR, JMP or the far-call JMP (ft))
    _look1FallThrough() {
        const cpu = this.cpu, prev = cpu.oldPcArray[(cpu.oldPcIndex - 1) & 255];
        if (cpu.readmem(prev) !== 0x60) return false;
        const ret = this.rb(0x100 + ((cpu.s - 1) & 0xff)) | this.rb(0x100 + (cpu.s & 0xff)) << 8;
        return ret === this.H.DEATH.a - 1;
    }
    _block(ctx) { this.blocked = ctx; return true; }

    _seed(ref) {
        const out = [];
        let o = 0;
        for (const [, n, name] of ref.regions) {
            const c = this.regions.find(r => r[2] === name);
            if (c && c[1] === n) for (let i = 0; i < n; i++) if (!this.written.has(c[0] + i) && this.rb(c[0] + i) !== ref.init[o + i]) { out.push([c[0] + i, ref.init[o + i]]); this.ram[c[0] + i] = ref.init[o + i]; }
            o += n;
        }
        return out;
    }

    // Run up to `cycles` emulated cycles; stops early (returns "blocked") at a poll its
    // input cannot answer yet. The handler is called by hand for the first instruction
    // of each slice, as jsbeeb skips the hook for the first instruction it executes.
    run(cycles) {
        const cpu = this.cpu, end = this.cyclesNow() + cycles;
        for (;;) {
            // (once per instruction: a slice can end without running one, when the
            // last instruction overshot its target, and the hook must not see it twice)
            const now = this.cyclesNow();
            if (this.blocked || now !== this.tabAt) {
                this.tabAt = now;
                if (this.tab(cpu.pc)) {
                    cpu.targetCycles = cpu.currentCycles;
                    if (this.redirectTo !== undefined) { cpu.pc = this.redirectTo; this.redirectTo = undefined; this.tabAt = -1; continue; }
                    return "blocked";
                }
            }
            const left = end - now;
            if (left <= 0) return "ok";
            cpu.execute(Math.max(16, Math.min(left, 20000)));
            if (cpu.halted && this.redirectTo !== undefined) { cpu.targetCycles = cpu.currentCycles; cpu.pc = this.redirectTo; this.redirectTo = undefined; this.tabAt = -1; continue; }
            if (cpu.halted && this.blocked) { cpu.targetCycles = cpu.currentCycles; return "blocked"; }
        }
    }
    // record each labelled routine entered (and the label of each instruction run, with
    // full), with A X Y, while from <= iteration <= to
    startTrace(from, to, out, full = false) {
        const cpu = this.cpu, byAddr = new Map();
        for (const [m, l] of Object.entries(this.labs)) for (const [k, v] of l) { const key = (m === "m" ? "m" : m) + ":" + v; if (!byAddr.has(key)) byAddr.set(key, k); }
        this.traceHook = cpu.debugInstruction.add(pc => {
            if (this.iter < from || this.iter > to) return false;
            const m = mapAt(cpu.romsel, pc);
            const lab = byAddr.get((m === "m" ? "m" : m) + ":" + pc);
            if (lab || full) out.push(`${this.iter} ${lab || this.labelOf(pc) + "+"} pc=${pc.toString(16)} A=${cpu.a.toString(16)} X=${cpu.x.toString(16)} Y=${cpu.y.toString(16)} S=${cpu.s.toString(16)}`);
            return false;
        });
    }
    async screenshot() { return this.s.screenshotActive({ scale: 1 }); }
    // render every frame from now on (for screenshots that show the current picture)
    renderAll() { this.s._video.frameSkipCount = 1; }
}

// ---- comparing two machines' game state

// mask over the snapshot's offsets: 1 = excluded (mlib's exclusion lists, by the reference's symbols)
export function compareSetup(rsy, regions, loose = true) {
    const ex = excludeSet(rsy, loose ? [TIMING_EXCLUDE, RELOC_EXCLUDE, DRAW_EXCLUDE] : [TIMING_EXCLUDE, RELOC_EXCLUDE]);
    const offAddr = [];
    for (const [a, n] of regions) for (let i = 0; i < n; i++) offAddr.push(a + i);
    const mask = new Uint8Array(offAddr.length);
    offAddr.forEach((a, o) => { if (ex.has(a)) mask[o] = 1; });
    const kOff = offAddr.indexOf(rsy["K%"]), fOff = offAddr.indexOf(rsy.FRIN);
    const byAddr = {};
    for (const [k, v] of Object.entries(rsy)) if (v < 0x8000 && !(v in byAddr) && !/^(CODE|LOAD)/.test(k)) byAddr[v] = k;
    return { ex, offAddr, mask, kOff, fOff, byAddr, loose, rsy };
}

// The differing compared bytes of two snapshots (an empty K% slot's bytes, FRIN = 0 in
// the reference, don't count with loose: the line heap grows into them, as mcompare)
export function diffSnaps(cs, a, b) {
    const out = [];
    for (let o = 0; o < a.length; o++) {
        if (a[o] === b[o] || cs.mask[o]) continue;
        if (cs.loose && o >= cs.kOff && o < cs.kOff + NOSH * NI && a[cs.fOff + Math.floor((o - cs.kOff) / NI)] === 0) continue;
        out.push(o);
    }
    return out;
}

const INWK = ["x_lo", "x_hi", "x_sign", "y_lo", "y_hi", "y_sign", "z_lo", "z_hi", "z_sign",
    "nosev_x_lo", "nosev_x_hi", "nosev_y_lo", "nosev_y_hi", "nosev_z_lo", "nosev_z_hi",
    "roofv_x_lo", "roofv_x_hi", "roofv_y_lo", "roofv_y_hi", "roofv_z_lo", "roofv_z_hi",
    "sidev_x_lo", "sidev_x_hi", "sidev_y_lo", "sidev_y_hi", "sidev_z_lo", "sidev_z_hi",
    "speed", "acceleration", "roll_counter", "pitch_counter", "flags(exploding/killed/scanner/lasers)", "AI/aggression/ECM", "heap_lo", "heap_hi", "energy", "NEWB"];
export function fieldName(cs, a) {
    const k = cs.rsy["K%"];
    if (a >= k && a < k + NOSH * NI) return `K% slot ${Math.floor((a - k) / NI)} ${INWK[(a - k) % NI]}`;
    for (let b = a; b >= Math.max(0, a - 64); b--) if (cs.byAddr[b] !== undefined) return b === a ? cs.byAddr[b] : `${cs.byAddr[b]}+${a - b}`;
    return `&${a.toString(16)}`;
}

// Fields grouped for the report: what part of the game each differing byte is
export function groupOf(cs, a) {
    const sy = cs.rsy, k = sy["K%"];
    if (a >= k && a < k + NOSH * NI) return "ship slots (K%)";
    if (a >= k + NOSH * NI && a < 0x0800) return "ship line heap";
    if (a >= sy.FRIN && a < sy.FRIN + NOSH + 1) return "ship slots (FRIN)";
    if (sy.NAME !== undefined && a >= sy.NAME && a <= sy.SVC) return "commander";
    if (a >= sy["NA%"] && a < sy["NAEND%"]) return "saved commander (NA%)";
    if (sy.UP !== undefined && a >= sy.UP && a <= sy.VOL) return "configuration";
    if (a < 0x100) return "zero page";
    return "flight variables (WP)";
}
