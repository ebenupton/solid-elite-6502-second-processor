#!/usr/bin/env node
// tadcrace.mjs: the Model B host's split against another interrupt that its
// IRQ1V handler (irqm, hb-res3.asm) passes to the MOS. irqm takes timer 1
// (the CRTC rupture's two points a field), the vsync and register 4's
// requests itself and passes anything else to the MOS's handler; if timer 1
// fired after irqm had read the flags and before the MOS read them, the MOS
// would take it for its 100 Hz clock and clear it, and the point would be
// lost (the picture broken for fields). Nothing the game enables reaches the
// MOS today, so the test makes such an interrupt: it turns on the system
// VIA's CB1 interrupt (the ADC's end of conversion, which the MOS services)
// and, before each firing of timer 1, raises CB1's flag d cycles before the
// timer fires, d going 0, 1 ... N in turn, so that the MOS is looking at the
// flags at every offset across the window. Every field (from one vsync to
// the next, the host's hb_irq) must have both points (their writes of timer
// 1's latch, &FE47), and the host must have answered every frame.
//
// node tube/tools/tadcrace.mjs [--disc d] [--psyms s] [--race N] [--fields F]
// Prints the fields counted, those without two points, and PASS or FAIL.
import { BBC } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/utils.js";
import { bootTube, ROOT } from "../../harness/tlib.mjs";
import { loadSyms } from "../../harness/mlib.mjs";
import { parseArgs } from "../../harness/args.mjs";

const a = parseArgs({ disc: "value", psyms: "value", race: "value", fields: "value" });
const DISC = a.disc || `${ROOT}tube/build/elite-tube.ssd`;
const PS = a.psyms || `${ROOT}tube/build/psyms.txt`;
const sy = loadSyms(PS), hsy = loadSyms(PS.replace(/psyms\.txt$/, "hbmsyms.txt"));
const RACE = +(a.race ?? 400), FIELDS = +(a.fields || 1500);

const t = await bootTube({ host: "B", disc: DISC, mhz: 3 });
const s = t.s, host = t.host, ram = t.par.memory, via = host.sysvia;
s.keyDown(16); s.reset(true); host.execute(2e6 * 2); s.keyUp(16);
const secs = n => { for (let k = 0; k < n * 10; k++) t.run(2e5); };
const key = (k, hold = 0.2, after = 1) => { host.sysvia.keyDownRaw(BBC[k]); secs(hold); host.sysvia.keyUpRaw(BBC[k]); secs(after); };
secs(34); key("N"); secs(3); key("SPACE"); secs(4);
for (let k = 0; k < 6 && ram[sy.QQ12]; k++) key("F0", 0.2, 6);
if (ram[sy.QQ12]) { console.log("never launched"); process.exit(1); }

// the fields: the vsync's handler (hb_irq, bank 7) reads &FE41; the points
// write the latch's high byte (&FE47: hbi_t, main RAM, and hbi_p1, bank 7)
let fields = 0, pts = 0, bad = 0, raised = 0, judging = true;
const odd = new Map();
host.debugRead.add(addr => {
    if (addr !== 0xfe41 || host.pc < hsy.hb_irq || host.pc > hsy.hb_irq + 4) return false;
    if (fields > 0) { if (pts !== 2) { bad++; odd.set(pts, (odd.get(pts) || 0) + 1); } }
    fields++; pts = 0;
    return false;
});
host.debugWrite.add(addr => { if (addr === 0xfe47) pts++; return false; });
let n = 0, last = -1e9, armed = false, d = 0;
host.debugInstruction.add(() => {
    if (!judging) return false;
    via._catchUp();
    if (!(via.ier & 0x10)) { via.ier |= 0x10; via.updateIFR(); }   // (CB1's interrupt on)
    const c = via.t1c;
    if (c > last + 4) { armed = true; d = n % (RACE + 1); }      // (a new period)
    last = c;
    if (armed && c + 3 <= d) { armed = false; n++; raised++; via.ifr |= 0x10; via.updateIFR(); }
    return false;
});
const f0 = fields;
let lastF = fields, stall = 0;                      // (no field for 4 emulated seconds: stopped)
for (let q = 0; fields - f0 < FIELDS && stall < 400; q++) { t.run(20000); if (fields !== lastF) { lastF = fields; stall = 0; } else stall++; }
if (stall >= 400) console.log(`no vsync for 4 seconds after ${fields - f0} fields (host pc &${host.pc.toString(16)})`);
judging = false;
const nf = fields - f0;
console.log(`ADC race (Model B host): CB1 raised 0-${RACE} cycles before timer 1, ${raised} times; ${nf} fields, ${bad} without both points${bad ? " (" + [...odd.entries()].map(([k, v]) => `${k} points: ${v}`).join(", ") + ")" : ""}`);
const ok = nf >= FIELDS && bad === 0 && raised > 0;
console.log(ok ? "ADCRACE PASS" : "ADCRACE FAIL");
process.exit(ok ? 0 : 1);
