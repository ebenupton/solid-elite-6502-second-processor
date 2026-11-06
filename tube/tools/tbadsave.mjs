#!/usr/bin/env node
// tbadsave.mjs: SNG47's DELT bug (it copies the name to delete one byte too far, over the
// first byte of savosc's "SAVE") leaves the next save's command starting with whatever byte
// followed the name in INWK. The original answers such a command with an error (Bad string,
// Bad command); this checks that the Tube host does too, for each byte given: new game,
// docked, savosc's first byte poked as DELT leaves it, then "@" -> 2 (save) CLAUDE, drive 0.
// Pass: the parasite gets what SNG47 (master/reference, on a Master, the same keys and
// poke) gets: the same error (number and message, at NEWBRK), or none; and the host is
// back in its command loop, its stack whole, without running main RAM. (Real key presses
// on the keyboard, as tsavetest.mjs.)
// node tube/tools/tbadsave.mjs [--host Master|B] [--bytes f2,bd,0,58,...] [--natural NAME: delete NAME, then save, no poke]
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { BBC } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/utils.js";
import { bootTube, ROOT } from "../../harness/tlib.mjs";
import { loadSyms } from "../../harness/mlib.mjs";
import { parseArgs } from "../../harness/args.mjs";
const a = parseArgs({ host: "value", disc: "value", psyms: "value", bytes: "value", natural: "value" });
const HOST = a.host || "Master";
const DISC = a.disc || `${ROOT}tube/build/elite-tube${HOST === "B" ? "-b" : ""}.ssd`;
const psy = loadSyms(a.psyms || `${ROOT}tube/build/psyms.txt`);
const hsy = loadSyms((a.psyms || `${ROOT}tube/build/psyms.txt`).replace(/psyms\.txt$/, HOST === "B" ? "hbmsyms.txt" : "hsyms.txt"));
const BYTES = (a.bytes || "f2,bd,58,41,2f,0,80,18,73").split(",").map(x => parseInt(x, 16));
const rsy = loadSyms(`${ROOT}master/reference/symbols.txt`);
const errAt = (rd, p) => { let m = "&" + rd(p).toString(16) + " "; for (let k = 1; k < 80 && rd(p + k); k++) m += String.fromCharCode(rd(p + k)); return m; };
// SNG47: the same keys, savosc's first byte poked as DELT leaves it; the error NEWBRK gets
async function reference(B) {
    const s = new MachineSession("Master"); await s.initialise(); await s.boot(30);
    s.loadDisc(`${ROOT}master/reference/elite-master-sng47.ssd`); s.keyDown(16); s.reset(true); await s.runFor(2e6); s.keyUp(16);
    const cpu = s._machine.processor, rd = ad => cpu.readmem(ad), secs = n => s.runFor(2e6 * n);
    let err = null;
    cpu.debugInstruction.add(pc => { if (pc === rsy.NEWBRK && err === null) err = errAt(rd, rd(0xfd) | rd(0xfe) << 8); return false; });
    const key = async (k, hold = 0.15, after = 0.6) => { cpu.sysvia.keyDownRaw(BBC[k]); await secs(hold); cpu.sysvia.keyUpRaw(BBC[k]); await secs(after); };
    const type = async str => { for (const c of str) await key(/[0-9]/.test(c) ? "K" + c : c, 0.1, 0.3); };
    await secs(28);
    await key("N"); await secs(3); await key("SPACE"); await secs(4);
    cpu.ramRomOs[rsy.savosc] = B;
    await key("AT", 0.15, 1.5); await key("K2", 0.15, 1.5);
    await type("CLAUDE"); await key("RETURN", 0.1, 1.5);
    await type("0"); await secs(10);
    s.stop?.();
    return err;
}
let fails = 0;
for (const B of BYTES) {
    const want = a.natural ? undefined : await reference(B);
    const t = await bootTube({ host: HOST, disc: DISC, mhz: HOST === "B" ? 3 : 4 });
    const s = t.s, host = t.host, pm = t.par.memory;
    s.keyDown(16); s.reset(true); host.execute(2e6 * 2); s.keyUp(16);
    const secs = n => { for (let k = 0; k < n * 10; k++) host.execute(2e5); };
    let brks = 0, minS = 0x1ff, inCmd = false, wild = null, armed = false;
    const NEWBRK = psy.NEWBRK_C ?? psy.NEWBRK, inD = () => pm[psy.ovl_cur] === 1;
    let err = null;
    t.addParHook(pc => { if (pc === NEWBRK && inD()) { brks++; if (err === null) err = errAt(ad => pm[ad], psy.R_NDX3); } return false; });
    host.debugInstruction.add(pc => {
        if (pc === hsy.h_disc && armed) inCmd = true;   // (armed after the boot: DFS runs the same address at the boot)
        if (inCmd && host.s < minS) minS = host.s;
        if (inCmd && !wild && pc >= 0x3000 && pc < 0x8000 && HOST !== "B") wild = pc;
        return false;
    });
    const key = (k, hold = 0.15, after = 0.6) => { host.sysvia.keyDownRaw(BBC[k]); secs(hold); host.sysvia.keyUpRaw(BBC[k]); secs(after); };
    const type = str => { for (const c of str) key(/[0-9]/.test(c) ? "K" + c : c, 0.1, 0.3); };
    secs(HOST === "B" ? 34 : 28);
    armed = true;
    key("N"); secs(3); key("SPACE"); secs(4);
    if (a.natural) {                           // (--natural NAME: no poke, a delete of NAME first, as a player would)
        key("AT", 0.15, 1.5); key("K4", 0.15, 1.5); type("0"); secs(4);
        type(a.natural); key("RETURN", 0.1, 3);
        console.log(`after deleting ${a.natural}: savosc's first byte &${pm[psy.savosc_C].toString(16)}`);
        key("K6", 0.15, 1.5);
    } else { pm[psy.savosc_C] = B; if (psy.savc0 !== undefined) pm[psy.savc0] = B; }   // (as DELT leaves it: savosc, and savc0, which keeps it over loads of overlay D)
    key("AT", 0.15, 1.5); key("K2", 0.15, 1.5);
    type("CLAUDE"); key("RETURN", 0.1, 1.5);
    type("0"); secs(10);
    const ok = (a.natural ? brks > 0 : err === want && brks <= 1) && !wild && minS > 0x40;
    if (!ok) fails++;
    console.log(`byte &${B.toString(16)}: ${ok ? "ok" : "FAIL"}: the parasite's error ${err === null ? "none" : `"${err}"`}${a.natural ? "" : `, SNG47's ${want === null ? "none" : `"${want}"`}`} (errors back ${brks}), the host's lowest stack in the command &${minS.toString(16)}${wild ? `, the host ran main RAM at &${wild.toString(16)}` : ""}`);
    s.stop?.();
}
process.exit(fails ? 1 : 0);
