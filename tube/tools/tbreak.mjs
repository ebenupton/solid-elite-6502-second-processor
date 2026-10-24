#!/usr/bin/env node
// tbreak.mjs: BREAK during play. Boots the disc (SHIFT+BREAK), starts a game
// (title: N, then SPACE, docked), launches (f0), flies a few seconds, then
// presses BREAK (--shift: SHIFT+BREAK) and runs on; screenshots and the PCs
// at each step go to --out. --host Master|B for the Tube build, or --port for
// the Master port's disc (no co-processor).
//   node tube/tools/tbreak.mjs --disc D [--host Master|B | --port] [--shift] --out DIR
import { bootTube } from "../../harness/tlib.mjs";
import { BBC } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/utils.js";
import { parseArgs } from "../../harness/args.mjs";
import { writeFileSync, mkdirSync } from "fs";
const a = parseArgs({ disc: "value", host: "value", port: "flag", shift: "flag", out: "value", after: "value" });
mkdirSync(a.out, { recursive: true });
let t, s, host;
if (a.port) {
    const { MachineSession } = await import("/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js");
    const { findModel } = await import("/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/models.js");
    s = new MachineSession("Master"); await s.initialise(); await s._machine.runFor(2e6 * 3); s.loadDisc(a.disc);
    host = s._machine.processor;
} else { t = await bootTube({ host: a.host || "Master", disc: a.disc }); s = t.s; host = t.host; }
const secs = n => { for (let k = 0; k < n * 10; k++) host.execute(2e5); };
const key = (k, hold = 0.15, after = 0.6) => { host.sysvia.keyDownRaw(BBC[k]); secs(hold); host.sysvia.keyUpRaw(BBC[k]); secs(after); };
let shot = 0;
const snap = async name => { writeFileSync(`${a.out}/${String(shot++).padStart(2, "0")}-${name}.png`, await s.screenshot()); console.log(`${name}: host pc &${host.pc.toString(16)} romsel ${host.romsel?.toString(16)}${t ? `, parasite pc &${t.par.pc.toString(16)}` : ""}`); };
s.keyDown(16); s.reset(true); host.execute(2e6 * 2); s.keyUp(16);
secs(a.host === "B" ? 34 : 28); await snap("title");
key("N"); secs(3); key("SPACE"); secs(4); await snap("docked");
key("F0", 0.2, 12); await snap("flight");
let hb = 0;
if (t) { const { loadSyms } = await import("../../harness/mlib.mjs"); const hs = loadSyms(a.disc.replace(/elite-tube(-b)?\.ssd$/, a.host === "B" ? "hbmsyms.txt" : "hsyms.txt")); if (hs.hbreak) host.debugInstruction.add(pc => { if (pc === hs.hbreak) hb++; return false; }); }
if (a.shift) s.keyDown(16);
s.reset(false); host.execute(2e6 * 1);
if (a.shift) s.keyUp(16);
console.log("BREAK intercept calls so far:", hb);
for (const n of (a.after || "3,10,30").split(",").map(Number)) { secs(n); await snap(`break+${n}s`); console.log("  intercept calls:", hb);
    const m = host.ramRomOs, txt = []; for (let r = 0; r < 25; r++) { let l = ""; for (let c = 0; c < 40; c++) { const ch = m[0x7c00 + r * 40 + c] & 0x7f; l += ch >= 32 && ch < 127 ? String.fromCharCode(ch) : "."; } if (l.replace(/[. ]/g, "")) txt.push(l); } console.log("  mode 7 screen:", JSON.stringify(txt.slice(0, 8))); }
process.exit(0);
