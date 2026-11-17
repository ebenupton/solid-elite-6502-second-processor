#!/usr/bin/env node
// tbitstik.mjs: the Bitstik's twist sets the speed, as in the original. With
// the Bitstik configured (B in the pause screen: BSTK), the main loop's part
// 2 sets DELTA from JOPOS+2, the high byte of ADC channel 3, which the IRQ
// samples: DELTA = min(40, JOPOS+2 / 4). On the Tube the parasite's JOPOS is
// the host's (p-io.asm's p_keyq asks for it, a C_DKS with key &FF, while the
// joystick or the Bitstik is configured). Boots the build (a new game, launch with f0),
// pauses (COPY), presses B, unpauses (DELETE), then puts each twist value in
// turn on the host's ADC channel 3 (jsbeeb's adconverter) and reads DELTA
// once the game has run with it (the IRQ samples the channels in turn, so
// JOPOS+2 follows the twist only now and then, on the original as on the
// hosts); the same on the released SNG47 (--ref). Exit 0 when BSTK toggles,
// JOPOS+2 follows the twist (three values at least) and every DELTA is the
// original's rule's for the JOPOS+2 the game read.
//
// node tube/tools/tbitstik.mjs [--host Master|B] [--disc d] [--psyms s] [--ref]
import { BBC } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/utils.js";
import { bootTube, ROOT } from "../../harness/tlib.mjs";
import { loadSyms, bootMaster } from "../../harness/mlib.mjs";
import { parseArgs } from "../../harness/args.mjs";
const a = parseArgs({ host: "value", disc: "value", psyms: "value", ref: "flag" });
const HOST = a.host || "Master";
const VALUES = [0x00, 0x14, 0x40, 0x7f, 0x9c, 0xa3, 0xc8, 0xff];
const want = v => Math.min(40, v >> 2);

async function machine() {
    if (a.ref) {
        const s = await bootMaster(`${ROOT}master/reference/elite-master-sng47.ssd`);
        const cpu = s._machine.processor;
        return { sy: loadSyms(`${ROOT}master/reference/symbols.txt`), mem: cpu.ramRomOs, host: cpu, run: n => cpu.execute(n),
            hook: f => cpu.debugInstruction.add(f), name: "SNG47" };
    }
    const t = await bootTube({ host: HOST, disc: a.disc || `${ROOT}tube/build/elite-tube.ssd`, mhz: HOST === "B" ? 3 : 4 });
    t.s.keyDown(16); t.s.reset(true); t.host.execute(2e6 * 2); t.s.keyUp(16);
    return { sy: loadSyms(a.psyms || `${ROOT}tube/build/psyms.txt`), mem: t.par.memory, host: t.host, run: n => t.run(n),
        hook: f => t.addParHook(f), name: `Tube, ${HOST} host`, now: () => t.hostSecs() };
}

const M = await machine();
const { sy, mem, host } = M;
const secs = n => { for (let k = 0; k < n * 10; k++) M.run(2e5); };
const key = (k, hold = 0.15, after = 0.6) => { host.sysvia.keyDownRaw(BBC[k]); secs(hold); host.sysvia.keyUpRaw(BBC[k]); secs(after); };
let twist = 0x80;
host.adconverter.setChannelSource(2, { getValue: () => twist << 8, dispose() {} });
secs(a.ref ? 6 : HOST === "B" ? 34 : 28);
key("N"); secs(3);
key("SPACE"); secs(4);
// MLOOP's count, to run whole iterations with each value
let iters = 0;
let frz = 0, dk4 = 0, joyT = 0, joyN = 0, t0 = 0;
M.hook(pc => {
    if (pc === sy.MLOOP) iters++; if (pc === sy.FREEZE) frz++; if (pc === sy.DK4) dk4++;
    if (M.now && pc === sy.p_keyq) t0 = M.now();                    // (the Tube: the JOPOS request's time,
    if (M.now && pc === sy.pkq9 && t0) { if (mem[sy.BSTK]) { joyT += M.now() - t0; joyN++; } t0 = 0; }   // p_keyq to pkq9)
    return false;
});
const iterate = n => { const i0 = iters; for (let k = 0; k < 4000 && iters < i0 + n; k++) M.run(2e4); };
for (let k = 0; k < 6 && mem[sy.QQ12]; k++) key("F0", 0.2, 6);   // (launch, again until in flight)
if (mem[sy.QQ12]) { console.log(`${M.name}: never launched`); console.log("BITSTIK FAIL"); process.exit(1); }
iterate(4);
const before = mem[sy.BSTK];
key("COPY", 0.2, 1);
host.sysvia.keyDownRaw(BBC.B);                    // (B held until it toggles: the pause
for (let k = 0; k < 400 && mem[sy.BSTK] === before; k++) M.run(2e3);   // loop toggles BSTK each
host.sysvia.keyUpRaw(BBC.B); secs(1);             // pass while it is held)
key("DELETE", 0.2, 1);
iterate(4);
const after = mem[sy.BSTK];
let ok = after !== before && after !== 0;
const rows = [], seen = new Set();
for (const v of VALUES) {
    twist = v;
    for (let k = 0; k < 100 && mem[sy.JOPOS + 2] !== v; k++) iterate(1);   // (the IRQ samples the
    iterate(4);                                                              // channels in turn)
    const d = mem[sy.DELTA], j = mem[sy.JOPOS + 2];
    seen.add(j);
    rows.push(`twist &${v.toString(16).padStart(2, "0")}: JOPOS+2 &${j.toString(16).padStart(2, "0")}, DELTA ${d} (the original's rule: ${want(j)})`);
    if (d !== want(j)) ok = false;
}
if (seen.size < 3) { ok = false; rows.push(`JOPOS+2 took only ${seen.size} values: the twist does not reach the game`); }
if (process.env.TBDEBUG) console.log(`FREEZE ${frz}, DK4 ${dk4}, iterations ${iters}, QQ12 ${mem[sy.QQ12]}, QQ11 ${mem[sy.QQ11]}, MCNT ${mem[sy.MCNT]}`);
console.log(`${M.name}: BSTK &${before.toString(16)} -> &${after.toString(16)} (B in the pause screen)`);
for (const r of rows) console.log("  " + r);
if (joyN) console.log(`  JOPOS from the host: ${joyN} requests, ${(joyT / joyN * 1e6).toFixed(1)} us each (p_keyq to pkq9, the Bitstik on), ${iters} iterations in all`);
console.log(ok ? "BITSTIK PASS" : "BITSTIK FAIL");
process.exit(ok ? 0 : 1);
