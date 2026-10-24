// Tube machines for the 6502 Second Processor version (docs/TUBE-PLAN.md):
// jsbeeb's host (a BBC Model B with sideways RAM, or a BBC Master) with its
// 65C02 parasite (jsbeeb's Tube65C02 model) attached.
//
//   const t = await bootTube({ host: "B" | "Master", mhz: 3, disc })
//   t.s       the MachineSession (host video, sound, keyboard)
//   t.host    the host CPU (jsbeeb Cpu6502; t.host.ramRomOs is its memory)
//   t.par     the parasite CPU (jsbeeb Tube6502; t.par.memory is its 64K)
//   t.tube    the Tube ULA (t.par.tube)
//   t.addParHook(fn)  fn(pc) before each parasite instruction; true stops the
//             current host slice (the parasite stops at that instruction too)
//
// jsbeeb runs the parasite inside the host's polltime, cpuMultiplier parasite
// cycles per host cycle (default 2: 4 MHz). The real 6502 Second Processor
// runs at 3 MHz, so the multiplier here is mhz / 2 (1.5), and the parasite's
// execute() is replaced by one that keeps the fractional cycles (jsbeeb's
// truncates each slice's count to an integer, which at 1.5 and slices of 2-7
// host cycles loses a large fraction of the parasite's time) and calls the
// parasite hooks.
//
// The Model B is jsbeeb's "BBC B with DFS 1.2". jsbeeb gives it sideways RAM
// in slots 0-7; opts.swram (an array of 16 booleans) chooses which slots are
// RAM instead, as boards differ (the loader detects them). The Master is
// jsbeeb's "BBC Master 128 (DFS)" (sideways RAM in banks 4-7).
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { findModel, allModels } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/models.js";

export const ROOT = decodeURIComponent(new URL("..", import.meta.url).pathname);
export const JSBEEB = "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src";

// A copy of a jsbeeb model with the Tube attached (and, optionally, its own
// sideways RAM map), registered under its own name: jsbeeb's Cpu6502 decides
// at every polltime whether to run the parasite from its model's .tube, so a
// tube machine needs a model object of its own (a reference Master without a
// Tube can then run in the same process).
let modelSeq = 0;
export function tubeModel(base, swram) {
    const m = findModel(base), nm = `${base}+Tube#${modelSeq++}`;
    const t = Object.assign(Object.create(Object.getPrototypeOf(m)), m, { name: nm, synonyms: [nm], tube: findModel("Tube65C02") });
    if (swram) t.swram = swram;
    allModels.push(t);
    return nm;
}

// The parasite's execute(), with fractional cycles and hooks. Returns false if a
// hook stopped it (the host's slice is cut short too, through t.stop).
function patchParasite(t) {
    const par = t.par;
    par.cycles = 0;
    par.cpuMultiplier = t.mult;
    par.execute = function (cycles) {
        this.cycles += cycles * this.cpuMultiplier;
        if (t.stopped) return;
        const hooks = t.parHooks;
        while (this.cycles > 0) {
            if (hooks.length) {
                const pc = this.pc;
                for (let i = 0; i < hooks.length; i++) if (hooks[i](pc)) { t.stopped = true; t.host.targetCycles = t.host.currentCycles; return; }
            }
            const opcode = this.readmem(this.pc);
            this.incpc();
            this.runner.run(opcode);
            if (this.takeInt) this.brk(true);
        }
    };
}

export async function bootTube(opts = {}) {
    const host = opts.host || "B";
    const base = host === "Master" ? "Master" : "B-DFS1.2";
    let swram = opts.swram;
    if (!swram && host !== "Master") {
        // a Model B with 64K of sideways RAM: four 16K banks, by default in slots 4-7
        swram = Array.from({ length: 16 }, (_, i) => i >= 4 && i <= 7);
    }
    const s = new MachineSession(tubeModel(base, swram));
    await s.initialise();
    const t = { s, hostKind: host, host: s._machine.processor, mhz: opts.mhz || 3, parHooks: [], stopped: false };
    t.par = t.host.tube;
    t.tube = t.par.tube;
    t.mult = t.mhz / 2;
    patchParasite(t);
    // opts.intube (or TUBEINT=1): the Master's internal co-processor, as a real
    // Master (and b2) has it. jsbeeb's Tube answers at &FEE0-&FEFF whatever
    // ACCCON holds; a Master reaches its internal co-processor only while
    // ACCCON's ITU (bit 4) is set, and with ITU clear reaches the Tube
    // connector (nothing there: the bus floats, read here as &FE). The CMOS is
    // made INTUBE (byte 30, bit 2 clear: jsbeeb's default is EXTUBE), so the
    // MOS sets ITU at its reset
    if (host === "Master" && (opts.intube ?? process.env.TUBEINT === "1")) {
        const cm = t.host.cmos;
        cm.store = cm.store.slice();    // (jsbeeb's default array is shared)
        cm.store[30] &= ~4;
        const rd = t.par.read.bind(t.par), wr = t.par.write.bind(t.par);
        t.par.read = a => (t.host.acccon & 0x10 ? rd(a) : 0xfe);
        t.par.write = (a, b) => { if (t.host.acccon & 0x10) wr(a, b); };
        t.intube = true;
    }
    // TEDGETRAP=psyms.txt: count the parasite's reads of the ships' edge lists
    // (SHIP_x_EDGES up to SHIP_x_FACES), reported when the process exits
    if (process.env.TEDGETRAP) {
        const { readFileSync } = await import("fs");
        const sy = {};
        for (const m of readFileSync(process.env.TEDGETRAP, "utf8").matchAll(/'([^']+)':(\d+)/g)) if (!(m[1] in sy)) sy[m[1]] = +m[2];
        const R = [];
        for (const k of Object.keys(sy)) { const m = /^SHIP_(.*)_EDGES$/.exec(k); if (m && sy[`SHIP_${m[1]}_FACES`] > sy[k]) R.push([sy[k], sy[`SHIP_${m[1]}_FACES`], m[1]]); }
        const hit = new Uint8Array(65536); for (const [lo, hi] of R) hit.fill(1, lo, hi);
        const reads = new Map(); const rm = t.par.readmem.bind(t.par);
        let shown = 0; const lastPcs = [];
        t.addParHook0 = pc => { lastPcs.push(pc); if (lastPcs.length > 6) lastPcs.shift(); };
        t.par.readmem = a => { if (hit[a & 0xffff]) { const k = `${(a & 0xffff).toString(16)}@${t.par.pc.toString(16)}`; reads.set(k, (reads.get(k) || 0) + 1);
            if ((t.par.pc < 0x7000 || t.par.pc >= 0x9000) && t.par.pc < 0xf800 && shown++ < 12 && process.env.TEDGEDBG) console.log(`edge read &${(a & 0xffff).toString(16)}: pc &${t.par.pc.toString(16)} a ${t.par.a.toString(16)} x ${t.par.x.toString(16)} y ${t.par.y.toString(16)}; last pcs ${lastPcs.map(p => p.toString(16)).join(" ")}; mem ${[...t.pmem.slice(0xe95c, 0xe976)].map(b => b.toString(16)).join(" ")}`); }
            return rm(a); };
        process.on("exit", () => { const top = [...reads.entries()].sort((x, y) => y[1] - x[1]).slice(0, 10); console.log(`edge-list trap: ${R.length} ships' edge lists, ${hit.reduce((x, y) => x + y, 0)} bytes; reads: ${[...reads.values()].reduce((x, y) => x + y, 0)} ${JSON.stringify(top)}`); });
    }
    // TWTRAP=addr: report the parasite's writes to that address (pc, value)
    if (process.env.TWTRAP) {
        const wa = parseInt(process.env.TWTRAP, 16), wm = t.par.writemem.bind(t.par); let n = 0;
        t.par.writemem = (a, b) => { if ((a & 0xffff) === wa && n++ < 20) console.log(`write &${wa.toString(16)} = ${b.toString(16)} from pc &${t.par.pc.toString(16)}`); return wm(a, b); };
    }
    t.addParHook = fn => { t.parHooks.push(fn); return { remove: () => { const i = t.parHooks.indexOf(fn); if (i >= 0) t.parHooks.splice(i, 1); } }; };
    // run the machine for n host cycles (2 MHz), or until a parasite hook stops it
    t.run = n => { t.stopped = false; t.host.execute(n); return !t.stopped; };
    t.hostSecs = () => t.host.cycleSeconds + t.host.currentCycles / 2e6;
    t.hostCycles = () => t.host.cycleSeconds * 2e6 + t.host.currentCycles;
    // memory helpers
    t.pmem = t.par.memory;
    t.hmem = t.host.ramRomOs;
    t.hostRead = a => t.host.readmem(a);
    // write a file's bytes into host RAM (main RAM only), or into a sideways bank
    t.hostPoke = (a, bytes) => { for (let i = 0; i < bytes.length; i++) t.hmem[a + i] = bytes[i]; };
    t.bankPoke = (bank, a, bytes) => { for (let i = 0; i < bytes.length; i++) t.hmem[t.host.romOffset + bank * 16384 + a - 0x8000 + i] = bytes[i]; };
    t.parPoke = (a, bytes) => { for (let i = 0; i < bytes.length; i++) t.pmem[(a + i) & 0xffff] = bytes[i]; };
    if (t.addParHook0 && process.env.TEDGEDBG) t.addParHook(pc => { t.addParHook0(pc); return false; });
    if (opts.boot !== false) {
        await s._machine.runFor(2e6 * (opts.bootSecs || 3));
        s.drainOutput();
    }
    if (opts.disc) s.loadDisc(opts.disc);
    return t;
}
