// A session: the reference (original Master Elite) and the candidate (our port) side by
// side. The reference runs a frame at a time; its inputs come from elite-agent (live) or
// from an input log (replay). Every input read it makes is queued, with the routine that
// made it, and the candidate replays the queue read for read: it blocks at a read the
// reference hasn't made yet. So the candidate always gets the same inputs at the same
// read, and any difference is the port's.
//
// Checked as it goes:
//  * game state at every MLOOP (mlib's regions and exclusions, --loose as the gate);
//  * control flow: each read's kind and routine (and DKS5's key) must match;
//  * BRKs into the game's handler, page &0D writes (candidate), hangs (no read and no
//    iteration for HANG_SECS emulated seconds), the PC in zero page or the stack;
//  * observables (observe.mjs): the dashboard, scanner and compass as drawn, decoded from
//    each machine's screen memory into values, compared when they are deterministic.
// The input log (inputs.jsonl) holds every read that had a key down or a stick change, by
// read number; it replays the session exactly, without the agent (replay.mjs).
import { writeFileSync, appendFileSync, mkdirSync, readFileSync, existsSync } from "fs";
import { createHash } from "crypto";
import { EliteMachine, loadSyms, compareSetup, diffSnaps, fieldName, groupOf, ROOT, CYCLES_PER_FRAME } from "./lib.mjs";
import { Agent } from "./agent.mjs";
import { COMMANDERS, makeChaos } from "./styles.mjs";
import { Observer } from "./observe.mjs";
import { toSsdOrDsd } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/disc.js";

// the files on a machine's drive 0, as written so far: { "D.NAME": { load, exec, len, data } }
export function discFiles(m) {
    const img = toSsdOrDsd(m.cpu.fdc._drives[0].disc);
    const n = img[0x105] / 8, out = {};
    for (let i = 0; i < n; i++) {
        const o = 8 + 8 * i, b = img.subarray(0x100 + o, 0x108 + o);
        const name = String.fromCharCode(img[o + 7] & 0x7f) + "." + String.fromCharCode(...img.subarray(o, o + 7)).trim();
        const len = b[4] | b[5] << 8 | ((b[6] >> 4) & 3) << 16, sec = b[7] | (b[6] & 3) << 8;
        out[name] = { load: b[0] | b[1] << 8 | ((b[6] >> 2) & 3) << 16, exec: b[2] | b[3] << 8 | ((b[6] >> 6) & 3) << 16, len, data: img.subarray(sec * 256, sec * 256 + len) };
    }
    return { img, files: out };
}

export const DEFAULTS = {
    ref: `${ROOT}master/reference/elite-master-sng47.ssd`, rsyms: `${ROOT}master/reference/symbols.txt`,
    cand: `${ROOT}master/build/elite-master-sng47.ssd`, csyms: `${ROOT}master/build/symbols.txt`,
};
const HANG_SECS = +(process.env.HANG_SECS || 30);
const sha1 = f => createHash("sha1").update(readFileSync(f)).digest("hex").slice(0, 12);

export class Session {
    // cfg: out, ref, rsyms, cand, csyms, seed (RAND), commander, agentEnv, chaos, startFrame,
    //      minutes (of the reference's emulated time), iters, shots (every N iterations), replay (input log path),
    //      until (replay: stop at this iteration), keepGoing (iterations to run on after a divergence), observe
    constructor(cfg) {
        this.cfg = cfg = { ...DEFAULTS, startFrame: 700, minutes: 10, shots: 0, keepGoing: 0, observe: true, ...cfg };
        mkdirSync(cfg.out, { recursive: true });
        this.rsy = loadSyms(cfg.rsyms); this.csy = loadSyms(cfg.csyms);
        this.q = []; this.qBase = 0;          // reads the reference has made that the candidate hasn't
        this.jq = []; this.jqBase = 0;
        this.held = new Set(); this.stick = [0x80, 0x80];   // the agent's keys and stick (ADC high bytes)
        this.frame = 0;
        this.findings = [];                   // divergences and errors
        this.stats = { iters: 0, polls: 0, keyPolls: 0, events: {}, notes: {}, agentStatus: 0 };
        this.lastJoy = [-1, -1];
        this.div = null;
        this.files = { inputs: `${cfg.out}/inputs.jsonl`, log: `${cfg.out}/agent.log`, journal: `${cfg.out}/journal.jsonl`, events: `${cfg.out}/events.jsonl` };
        if (!cfg.replay) for (const f of Object.values(this.files)) writeFileSync(f, "");
        else { writeFileSync(`${cfg.out}/events.jsonl`, ""); }
    }

    async start() {
        const cfg = this.cfg;
        const rand = cfg.seed !== undefined ? seedBytes(cfg.seed) : null;
        const cmdr = COMMANDERS[cfg.commander || "jameson"];
        if (!cmdr) throw new Error(`unknown commander ${cfg.commander}`);
        const patch = cmdr.patch ? m => cmdr.patch(m) : null;
        // the builds as booted (summary.json's builds: which discs a session or replay ran)
        this.builds = { ref: cfg.ref, refSha: sha1(cfg.ref), rsyms: cfg.rsyms, cand: cfg.cand, candSha: sha1(cfg.cand), csyms: cfg.csyms };
        this.ref = new EliteMachine({ name: "ref", disc: cfg.ref, syms: this.rsy, input: this.refInput(), rand, patch, cover: true });
        this.cand = new EliteMachine({ name: "cand", disc: cfg.cand, syms: this.csy, input: this.candInput(), rand, patch, seedFrom: null, watch0d: true, hazelCheck: true, cover: true, workarounds: cfg.workarounds || [] });
        await this.ref.boot();
        await this.cand.boot();
        this.cand.opts.seedFrom = this.ref;
        this.cs = compareSetup(this.rsy, this.ref.regions, !cfg.strict);
        for (let k = 0; k < this.ref.regions.length; k++) {
            const [, n, nm] = this.ref.regions[k], c = this.cand.regions[k];
            if (!c || c[1] !== n || c[2] !== nm) throw new Error(`region ${nm} differs in size: ref ${n}, cand ${c && c[1]}`);
        }
        if (cfg.observe) { this.obsR = new Observer(this.ref); this.obsC = new Observer(this.cand); this.obsQ = []; this.obsDiffs = 0; this.obsChecked = 0; }
        if (cfg.trace) {
            this.traces = { ref: [], cand: [] };
            this.ref.startTrace(cfg.trace[0], cfg.trace[1], this.traces.ref, cfg.traceFull);
            this.cand.startTrace(cfg.trace[0], cfg.trace[1], this.traces.cand, cfg.traceFull);
        }
        if (cfg.replay) this.loadLog(cfg.replay);
        else {
            this.agent = new Agent(cfg.agentEnv || {});
            this.chaos = cfg.chaos ? makeChaos(cfg.chaos, cfg.seed || 0) : null;
            const header = { header: true, ...this.builds,
                seed: cfg.seed, commander: cfg.commander || "jameson", mode: cfg.mode || "efficient", agentEnv: cfg.agentEnv || {}, chaos: cfg.chaos || null, startFrame: cfg.startFrame, strict: !!cfg.strict, workarounds: cfg.workarounds || [] };
            appendFileSync(this.files.inputs, JSON.stringify(header) + "\n");
            writeFileSync(`${cfg.out}/config.json`, JSON.stringify({ ...header, minutes: cfg.minutes, iters: cfg.iters }, null, 1));
        }
    }

    // ---- inputs
    refInput() {
        const S = this;
        const push = e => { S.q.push(e); S.stats.polls++; };
        return {
            rdkey(ctx) {
                const keys = S.keysFor(ctx);
                push({ t: "r", s: ctx.site, k: keys, i: ctx.iter });
                if (keys.length) { S.stats.keyPolls++; if (!S.cfg.replay) S.logInput({ p: ctx.poll, t: "r", s: ctx.site, k: keys, i: ctx.iter }); }
                return keys;
            },
            dks5(ctx) {
                const down = S.dksFor(ctx);
                push({ t: "d", s: ctx.site, key: ctx.key, d: down, i: ctx.iter });
                if (down && !S.cfg.replay) S.logInput({ p: ctx.poll, t: "d", s: ctx.site, key: ctx.key, i: ctx.iter });
                return down;
            },
            joy(ctx) {
                const v = S.joyFor(ctx);
                S.jq.push(v);
                if (!S.cfg.replay && v !== S.lastJoy[ctx.which]) { S.lastJoy[ctx.which] = v; S.logInput({ j: ctx.joy, w: ctx.which, v, i: ctx.iter }); }
                return v;
            },
        };
    }
    candInput() {
        const S = this;
        const take = ctx => {
            const k = ctx.poll - S.qBase;
            if (k >= S.q.length || S.cfDiverged) return null;      // (after a control-flow divergence the candidate stays where it is)
            const e = S.q[k];
            if (e.t !== (ctx.kind === "rdkey" ? "r" : "d") || e.s !== ctx.site || (e.t === "d" && e.key !== ctx.key)) {
                S.finding("control-flow", `read ${ctx.poll} (iteration ${ctx.iter}): reference ${e.t === "r" ? "RDKEY" : "DKS5 key &" + e.key.toString(16)} from ${e.s} (iteration ${e.i}), candidate ${ctx.kind === "rdkey" ? "RDKEY" : "DKS5 key &" + ctx.key.toString(16)} from ${ctx.site}`, { poll: ctx.poll, iter: ctx.iter });
                S.stopNow = true; S.cfDiverged = true;
                return null;
            }
            return e;
        };
        return {
            rdkey(ctx) { const e = take(ctx); return e === null ? null : (e.k || []); },
            dks5(ctx) { const e = take(ctx); return e === null ? null : !!e.d; },
            joy(ctx) { const k = ctx.joy - S.jqBase; return k >= S.jq.length ? null : S.jq[k]; },
        };
    }
    keysFor(ctx) {
        if (this.cfg.replay) return this.rlog.get(ctx.poll)?.k || [];
        const k = this.chaos?.exclusive() ? [] : [...this.held];
        if (this.chaos) for (const c of this.chaos.keys(this, ctx)) if (!k.includes(c)) k.push(c);
        return k.sort((a, b) => a - b);
    }
    dksFor(ctx) {
        if (this.cfg.replay) { const e = this.rlog.get(ctx.poll); return !!(e && e.t === "d"); }
        return (this.held.has(ctx.key) && !this.chaos?.exclusive()) || (this.chaos ? this.chaos.keys(this, ctx).includes(ctx.key) : false);
    }
    joyFor(ctx) {
        if (this.cfg.replay) {
            const l = this.rjoy[ctx.which];
            while (this.rjoyPtr[ctx.which] + 1 < l.length && l[this.rjoyPtr[ctx.which] + 1][0] <= ctx.joy) this.rjoyPtr[ctx.which]++;
            const e = l[this.rjoyPtr[ctx.which]];
            return e && e[0] <= ctx.joy ? e[1] : (ctx.which ? 0x80 : 0x80);
        }
        return this.stick[ctx.which];
    }
    logInput(e) { appendFileSync(this.files.inputs, JSON.stringify(e) + "\n"); }
    loadLog(path) {
        const lines = readFileSync(path, "utf8").split("\n").filter(Boolean).map(l => JSON.parse(l));
        this.rlog = new Map(); this.rjoy = [[], []]; this.rjoyPtr = [0, 0];
        this.header = lines.find(l => l.header) || {};
        for (const e of lines) {
            if (e.p !== undefined) this.rlog.set(e.p, e);
            else if (e.j !== undefined) this.rjoy[e.w].push([e.j, e.v]);
            else if (e.poke !== undefined) for (const m of [this.ref, this.cand]) (m.pokes ||= new Map()).set(e.poke, e.v);
            else if (e.end) this.logEnd = e;
        }
        this.lastPoll = Math.max(-1, ...this.rlog.keys());
    }

    finding(kind, text, extra = {}) {
        const f = { kind, text, frame: this.frame, refIter: this.ref?.iter, candIter: this.cand?.iter, ...extra };
        this.findings.push(f);
        appendFileSync(this.files.events, JSON.stringify({ finding: f }) + "\n");
        console.log(`FINDING ${kind}: ${text}`);
        return f;
    }

    // ---- one frame of the reference, then the candidate as far as it can go
    async step() {
        const { ref, cand, cfg } = this;
        if (!cfg.replay && this.frame >= cfg.startFrame) {
            const r = await this.agent.frame(ref.ram.subarray(0, 0x8000));
            for (const [code, down] of r.keys) down ? this.held.add(code) : this.held.delete(code);
            for (const [ch, v] of r.analogue) if (ch < 2) this.stick[ch] = v >> 8;
            for (const [lv, t] of r.logs) { appendFileSync(this.files.log, `${(this.frame / 3000).toFixed(2)} ${lv === 0 ? "STATUS " : lv === 2 ? "  " : ""}${t}\n`); if (lv === 0) this.stats.agentStatus++; }
            for (const n of r.notes) {
                appendFileSync(this.files.journal, JSON.stringify({ frame: this.frame, iter: ref.iter, e: safeJson(n) }) + "\n");
                const ev = /"event": "([^"]+)"/.exec(n); if (ev) this.stats.notes[ev[1]] = (this.stats.notes[ev[1]] || 0) + 1;

            }
            if (this.chaos) this.chaos.frame(this);
        }
        // after each disc access (the reference entering SVE, the disc menu), once both machines
        // are past the next MLOOP (the access is over in both: SVE returns before it)
        const sve = this.ref.sveAt;
        if (sve !== undefined && sve !== this.checkedSve && this.ref.iter > sve && this.cand.iter > sve) { this.checkedSve = sve; this.compareDiscs(); }
        ref.run(CYCLES_PER_FRAME);
        this.frame++;
        // the candidate: until it blocks at a read the reference hasn't made (or 2 s, to keep both responsive)
        for (let k = 0; k < 100; k++) if (cand.run(CYCLES_PER_FRAME) === "blocked" || this.stopNow) break;
        this.trim();
        this.compare();
        this.checkHealth();
    }

    trim() {
        // drop reads both have made
        const n = this.cand.polls - this.qBase;
        if (n > 4096) { this.q = this.q.slice(n); this.qBase += n; }
        const j = this.cand.joys - this.jqBase;
        if (j > 4096) { this.jq = this.jq.slice(j); this.jqBase += j; }
    }

    compare() {
        const { ref, cand, cs } = this;
        while (ref.snaps.length && cand.snaps.length) {
            const [ri, a] = ref.snaps.shift(), [ci, b] = cand.snaps.shift();
            if (ri !== ci) { this.finding("internal", `iteration mismatch ${ri} vs ${ci}`); this.stopNow = true; return; }
            this.stats.iters = ri + 1;
            const d = diffSnaps(cs, a, b);
            if (d.length && !this.div) this.reportDivergence(ri, a, b, d);
            else if (d.length) {
                // (with --keepgoing: how long the difference lasts, and what else comes to differ)
                const k = this.div.after ||= { iters: 0, last: ri, fields: {} };
                k.iters++; k.last = ri;
                for (const o of d.slice(0, 50)) { const f = fieldName(cs, cs.offAddr[o]); k.fields[f] = (k.fields[f] || 0) + 1; }
            }
            if (this.div && ri >= this.div.iter + this.cfg.keepGoing) { this.stopNow = true; return; }
            if (this.cfg.shots && ri % this.cfg.shots === 0) this.shotsDue = ri;
        }
        if (this.obsR) this.compareObs();
    }
    reportDivergence(iter, a, b, d) {
        const { cs } = this;
        const fields = d.slice(0, 200).map(o => ({ addr: cs.offAddr[o], field: fieldName(cs, cs.offAddr[o]), group: groupOf(cs, cs.offAddr[o]), ref: a[o], cand: b[o] }));
        const groups = {};
        for (const f of fields) (groups[f.group] ||= []).push(f.field);
        const refT = this.ref.iterInfo[iter], candT = this.cand.iterInfo[iter];
        this.div = { iter, fields, groups, refSecs: refT?.[1], candSecs: candT?.[1], poll: refT?.[0], qq11: a[cs.offAddr.indexOf(this.rsy.QQ11)], qq12: a[cs.offAddr.indexOf(this.rsy.QQ12)] };
        this.finding("divergence", `game state differs at iteration ${iter} (read ${refT?.[0]}): ${Object.entries(groups).map(([g, fs]) => `${g}: ${[...new Set(fs)].slice(0, 8).join(", ")}${fs.length > 8 ? " ..." : ""}`).join("; ")}`, { iter, poll: refT?.[0] });
        this.divShots = true;
    }
    compareObs() {
        // observables are decoded at MLOOP into each machine's queue: compare the pairs
        const { obsR, obsC } = this;
        while (obsR.q.length && obsC.q.length) {
            const r = obsR.q.shift(), c = obsC.q.shift();
            if (r.iter !== c.iter) continue;
            this.obsChecked++;
            const all = Observer.compare(r, c);
            // expected differences (overlapping scanner dots) are counted, not reported
            for (const x of all.filter(x => x.expected)) { this.obsExpected ||= {}; const k = this.obsExpected[x.what] ||= { n: 0, first: r.iter, example: x }; k.n++; }
            const diffs = all.filter(x => !x.expected);
            if (diffs.length) {
                this.obsDiffs++;
                const key = diffs.map(x => x.what).join(",");
                this.obsKinds ||= {};
                const k = this.obsKinds[key] ||= { n: 0, first: r.iter, example: diffs.slice(0, 6) };
                k.n++;
                if (k.n === 1) this.finding("observable", `iteration ${r.iter}: ${diffs.slice(0, 6).map(x => `${x.what} ref ${JSON.stringify(x.ref)} cand ${JSON.stringify(x.cand)}`).join("; ")}`, { iter: r.iter, observable: key });
            }
        }
    }
    checkHealth() {
        const { ref, cand } = this;
        for (const m of [ref, cand]) {
            const pc = m.cpu.pc;
            if (m.started && pc < 0x200 && !m.healthBad) { m.healthBad = true; this.finding("crash", `${m.name}: PC &${pc.toString(16)} in zero page or the stack`); this.stopNow = true; }
            // a hang: no read for HANG_SECS emulated seconds. The candidate runs ahead of the
            // reference between reads, so its stall counts only once the reference has made a
            // read past it (the port hangs where the original didn't), or has stalled at the
            // same read too (both hang: the original's own behaviour, hang-both)
            const stalled = x => x.started && !x.blocked && x.cyclesNow() - x.lastProgressCycles > HANG_SECS * 2e6 && !x.healthBad;
            const where = x => { const c = x.cpu, recent = [...new Set(Array.from({ length: 64 }, (_, i) => c.oldPcArray[(c.oldPcIndex - i) & 0xff]))].slice(0, 24).map(y => y.toString(16)); return `PC &${c.pc.toString(16)}, ${x.labelOf(c.pc) || "?"}, iteration ${x.iter}, read ${x.polls}, ROMSEL &${c.romsel.toString(16)}, ACCCON &${c.acccon.toString(16)}; recent PCs ${recent.join(" ")}`; };
            if (m === cand && stalled(cand)) {
                if (stalled(ref) && ref.polls === cand.polls) {
                    ref.healthBad = cand.healthBad = true;
                    this.finding("hang-both", `both machines: no input read for ${HANG_SECS} emulated seconds at the same read (the original hangs here too). ref ${where(ref)}; cand ${where(cand)}`);
                    this.stopNow = true;
                } else if (ref.polls > cand.polls) {
                    cand.healthBad = true;
                    this.finding("hang", `cand: no input read and no main-loop iteration for ${HANG_SECS} emulated seconds, where the reference went on (${where(cand)})`);
                    this.stopNow = true;
                }
            } else if (m === ref && stalled(ref) && !stalled(cand) && cand.blocked && cand.polls >= ref.polls) {
                ref.healthBad = true;
                this.finding("hang", `ref: no input read and no main-loop iteration for ${HANG_SECS} emulated seconds, where the candidate went on (${where(ref)})`);
                this.stopNow = true;
            }
            while (m.evSeen === undefined ? (m.evSeen = 0, false) : m.evSeen < m.events.length) {
                const [it, kind, detail] = m.events[m.evSeen++];
                this.stats.events[`${m.name}:${kind}${kind === "routine" ? ":" + detail : ""}`] = (this.stats.events[`${m.name}:${kind}${kind === "routine" ? ":" + detail : ""}`] || 0) + 1;
                if (kind !== "routine") appendFileSync(this.files.events, JSON.stringify({ m: m.name, iter: it, kind, detail }) + "\n");
                if (kind === "workaround") this.stats.workarounds = (this.stats.workarounds || 0) + 1;
                if (kind === "brk" || kind === "page0d" || kind === "hazel") {
                    // (a BRK loop: report the first few, then stop the session)
                    this.brkSeen ||= {};
                    const n = this.brkSeen[detail] = (this.brkSeen[detail] || 0) + 1;
                    if (n <= 3) this.finding(kind, `${m.name} iteration ${it}: ${detail}`, { iter: it });
                    if (n === 20) { this.finding("brk-loop", `${m.name} iteration ${it}: the same BRK 20 times: ${detail}`, { iter: it }); this.stopNow = true; }
                }
            }
        }
        // a BRK from a disc error (a ROM) in one machine and not the other shows as a divergence;
        // compare the lists of ROM BRKs as they come
        // (by input reads, not iterations: the disc menu runs no MLOOP, and either machine can
        // be ahead between two reads. The n-th error is missing from a machine once that
        // machine has made a read past the one the other made it after)
        const rl = ref.brks.filter(b => b.fromRom), cl = cand.brks.filter(b => b.fromRom);
        if (!this.brkMismatch && cl.length > rl.length && ref.polls > cl[rl.length].polls) { this.brkMismatch = true; this.finding("brk-mismatch", `candidate disc error (${cl[rl.length].msg}) after read ${cl[rl.length].polls} (iteration ${cl[rl.length].iter}) with none in the reference`); }
        if (!this.brkMismatch && rl.length > cl.length && cand.polls > rl[cl.length].polls) { this.brkMismatch = true; this.finding("brk-mismatch", `reference disc error (${rl[cl.length].msg}) after read ${rl[cl.length].polls} (iteration ${rl[cl.length].iter}) with none in the candidate`); }
    }

    // the commander files (directory E) the two machines have written must be the same
    compareDiscs(final = false) {
        // (not while a disc access is under way: the two machines' disc controllers run on
        // their own clocks, so one can be part way through writing a file the other has
        // finished. At the end, if a machine hasn't passed the MLOOP after the reference's
        // last SVE, the access may be in progress: skip)
        const sve = this.ref.sveAt;
        if (final && sve !== undefined && !(this.ref.iter > sve && this.cand.iter > sve)) this.stats.discSkipped = (this.stats.discSkipped || 0) + 1;
        let r, c;
        try { r = discFiles(this.ref); c = discFiles(this.cand); } catch (e) { this.finding("internal", `disc read: ${e.message}`); return; }
        this.stats.discChecks = (this.stats.discChecks || 0) + 1;
        const names = new Set([...Object.keys(r.files), ...Object.keys(c.files)].filter(n => n.startsWith("E.")));
        if (final && this.stats.discSkipped) names.clear();
        for (const n of names) {
            const a = r.files[n], b = c.files[n];
            const key = `disc:${n}`;
            if (!a || !b) { this.onceFinding(key, "save-file", `${n} is on the ${a ? "reference's" : "candidate's"} disc only`); continue; }
            const diffs = [];
            if (a.load !== b.load || a.exec !== b.exec || a.len !== b.len) diffs.push(`catalogue load/exec/length ref &${a.load.toString(16)}/&${a.exec.toString(16)}/${a.len} cand &${b.load.toString(16)}/&${b.exec.toString(16)}/${b.len}`);
            const bad = [];
            for (let i = 0; i < Math.min(a.len, b.len); i++) if (a.data[i] !== b.data[i]) bad.push(i);
            if (bad.length) diffs.push(`${bad.length} bytes differ, first at offset ${bad[0]} (ref &${a.data[bad[0]].toString(16)} cand &${b.data[bad[0]].toString(16)})`);
            if (diffs.length) this.onceFinding(key, "save-file", `${n}: ${diffs.join("; ")}`);
            else this.stats.saveFilesSame = (this.stats.saveFilesSame || 0) + 1;
        }
        if (final && this.cfg.saveDiscs) { writeFileSync(`${this.cfg.out}/ref-disc.ssd`, r.img); writeFileSync(`${this.cfg.out}/cand-disc.ssd`, c.img); }
    }
    onceFinding(key, kind, text) { this.once ||= new Set(); if (this.once.has(key)) return; this.once.add(key); this.finding(kind, text); }

    async shots(tag) {
        const { cfg } = this;
        try {
            writeFileSync(`${cfg.out}/${tag}-ref.png`, await this.ref.screenshot());
            writeFileSync(`${cfg.out}/${tag}-cand.png`, await this.cand.screenshot());
        } catch (e) { console.log("screenshot failed:", e.message); }
    }

    async run() {
        const { cfg } = this;
        const maxFrames = cfg.replay ? Infinity : cfg.startFrame + Math.round(cfg.minutes * 3000);
        const t0 = Date.now();
        let lastLog = 0;
        if (cfg.shots) { this.ref.renderAll(); this.cand.renderAll(); }
        while (this.frame < maxFrames) {
            if (this.stopNow && this.stopFrame === undefined) { this.stopFrame = this.frame + 3; this.ref.renderAll(); this.cand.renderAll(); }
            if (this.stopFrame !== undefined && this.frame >= this.stopFrame) break;
            await this.step();
            if (cfg.iters && this.stats.iters >= cfg.iters) break;
            // (a replay runs to where the session ended, or 50 reads past its last key without an end record)
            if (cfg.replay && cfg.until === undefined && (this.logEnd ? this.ref.iter >= this.logEnd.iter : this.ref.polls > this.lastPoll + 50)) break;
            if (cfg.replay && cfg.until !== undefined && this.ref.iter > cfg.until + (cfg.keepGoing || 0) + 1) break;
            if (this.divShots && this.divShotFrame === undefined) { this.divShotFrame = this.frame + 3; this.ref.renderAll(); this.cand.renderAll(); }
            if (this.divShots && this.frame >= this.divShotFrame) { this.divShots = false; await this.shots(`divergence-${String(this.div.iter).padStart(6, "0")}`); }
            if (this.shotsDue !== undefined) { await this.shots(`it${String(this.shotsDue).padStart(6, "0")}`); this.shotsDue = undefined; }
            if (Date.now() - lastLog > 30000) {
                lastLog = Date.now();
                console.log(`[${cfg.out.split("/").pop()}] frame ${this.frame} (${(this.frame / 3000).toFixed(1)} min) ref it ${this.ref.iter} cand it ${this.cand.iter} reads ${this.ref.polls} wall ${((Date.now() - t0) / 1000).toFixed(0)} s` +
                    ` cash ${cashOf(this.ref)} tally ${this.ref.rb(this.rsy.TALLY) | this.ref.rb(this.rsy.TALLY + 1) << 8} galaxy ${this.ref.rb(this.rsy.GCNT) + 1}`);
            }
        }
        if (!cfg.replay) this.logInput({ end: true, iter: this.ref.iter, polls: this.ref.polls, frames: this.frame });
        this.compareDiscs(true);
        this.ref.renderAll(); this.cand.renderAll();
        if (this.findings.some(f => f.kind !== "observable") && !this.div) await this.shots("finding");
        else await this.shots("end");
        if (this.traces) for (const k of ["ref", "cand"]) writeFileSync(`${cfg.out}/trace-${k}.txt`, this.traces[k].join("\n") + "\n");
        this.agent?.close();
        return this.summary((Date.now() - t0) / 1000);
    }

    summary(wall) {
        const { ref, cand, cfg } = this;
        const s = {
            out: cfg.out, builds: this.builds, wall, frames: this.frame, gameMinutes: +(Math.max(0, this.frame) / 3000).toFixed(2),
            refIters: ref.iter, candIters: cand.iter, compared: this.stats.iters, flight: ref.tt100, reads: ref.polls, keyReads: this.stats.keyPolls,
            divergence: this.div, findings: this.findings, events: this.stats.events, agentNotes: this.stats.notes,
            observables: this.obsR ? { checked: this.obsChecked, differing: this.obsDiffs, kinds: this.obsKinds || {}, expected: this.obsExpected || {} } : null,
            discChecks: this.stats.discChecks || 0, saveFilesSame: this.stats.saveFilesSame || 0, discFinalSkipped: !!this.stats.discSkipped,
            seeded: cand.seeded?.length, workaroundHits: this.stats.workarounds || 0, workarounds: cfg.workarounds || [], final: finalState(ref, this.rsy),
        };
        const cov = ref.coverage();
        if (cov) writeFileSync(`${cfg.out}/coverage-ref.json`, JSON.stringify(cov));
        const ccov = cand.coverage();
        if (ccov) writeFileSync(`${cfg.out}/coverage-cand.json`, JSON.stringify(ccov));
        writeFileSync(`${cfg.out}/summary.json`, JSON.stringify(s, null, 1));
        return s;
    }
}

function safeJson(s) { try { return JSON.parse(s); } catch { return s; } }
export function seedBytes(seed) {
    // four RAND bytes from a seed number (any seed but 0 gives a different game)
    let x = (seed * 2654435761) >>> 0;
    const out = [];
    for (let i = 0; i < 4; i++) { x ^= x << 13; x >>>= 0; x ^= x >>> 17; x ^= x << 5; x >>>= 0; out.push(x & 255); }
    return out;
}
function cashOf(m) { const a = m.sy.CASH; return ((m.rb(a) << 24 | m.rb(a + 1) << 16 | m.rb(a + 2) << 8 | m.rb(a + 3)) >>> 0) / 10; }
function finalState(m, sy) {
    return { cash: cashOf(m), tally: m.rb(sy.TALLY) | m.rb(sy.TALLY + 1) << 8, galaxy: m.rb(sy.GCNT) + 1, system: [m.rb(sy.QQ0), m.rb(sy.QQ1)],
        mission: m.rb(sy.TP), fuel: m.rb(sy.QQ14), legal: m.rb(sy.FIST), missiles: m.rb(sy.NOMSL), laser: m.rb(sy.LASER),
        docked: m.rb(sy.QQ12), view: m.rb(sy.QQ11), ecm: m.rb(sy.ECM), bomb: m.rb(sy.BOMB), pod: m.rb(sy.ESCP), ghyp: m.rb(sy.GHYP) };
}
