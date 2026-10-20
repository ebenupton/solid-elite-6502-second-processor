#!/usr/bin/env node
// Regression test: CHPR's screen clear with the text off the bottom (RR2: YC >= 24 calls
// TTX66, through TTX66M) and for control code 11 (cls). CHPR has ACCCON's X bit set (shadow
// RAM at &3000-&7FFF) when it calls TTX66; the port's TTX66 calls G_DIRECT, a stub in main
// RAM above &3000, which the CPU then fetched from shadow RAM and crashed (found by
// agentplay: a commander's name ended with ESCAPE leaves it unterminated, and the Status
// screen's garbage runs off the bottom). Both machines are booted to the docked Status
// screen; then, in each, CHPR is called with YC = 24 and a letter, and with code 11. Each
// call must return within a second, with the screen cleared (XC = YC = 1 after the
// letter, as RR2 leaves them; the same after code 11) and ACCCON's X bit clear.
// node master/tools/agentplay/test-chpr-overflow.mjs [--cand disc --csyms syms]
import { Session } from "./session.mjs";
import { parseArgs } from "../../../harness/args.mjs";
import { ROOT } from "./lib.mjs";
import { writeFileSync, mkdirSync } from "fs";
const a = parseArgs({ out: "value", cand: "value", csyms: "value" });
const out = a.out || ROOT + "scratch/agentplay/test-chpr-overflow";
mkdirSync(out, { recursive: true });
const log = out + "/inputs.jsonl";
writeFileSync(log, JSON.stringify({ header: true, ref: ROOT + "master/reference/elite-master-sng47.ssd", rsyms: ROOT + "master/reference/symbols.txt", seed: 1, commander: "jameson", startFrame: 700 }) + "\n");
const S = new Session({ out, replay: log, ref: ROOT + "master/reference/elite-master-sng47.ssd", rsyms: ROOT + "master/reference/symbols.txt",
    cand: a.cand || ROOT + "master/build/elite-master-sng47.ssd", csyms: a.csyms || ROOT + "master/build/symbols.txt", startFrame: 700, observe: false });
await S.start();
while (S.frame < 900) await S.step();
let fail = 0;
for (const m of [S.ref, S.cand]) {
    const cpu = m.cpu, sy = m.sy;
    // call CHPR as a subroutine: push a return address whose target we stop at
    const call = (ch, xc, yc) => {
        const RET = 0xfff0;                                // (stopped at before it runs)
        m.ram[sy.XC] = xc; m.ram[sy.YC] = yc;
        const s = cpu.s;
        cpu.writemem(0x100 + s, (RET - 1) >> 8); cpu.writemem(0x100 + ((s - 1) & 255), (RET - 1) & 255); cpu.s = (s - 2) & 255;
        cpu.a = ch; cpu.pc = sy.CHPR;
        let back = false;
        const h = cpu.debugInstruction.add(pc => { if (pc === RET) { back = true; return true; } return false; });
        for (let n = 0; n < 2e6 && !back; n += 2000) cpu.execute(2000);
        cpu.debugInstruction.remove(h);
        const r = { back, xc: m.rb(sy.XC), yc: m.rb(sy.YC), x: (cpu.acccon & 4) !== 0, s: cpu.s };
        cpu.s = s; cpu.pc = RET;                         // (a resumable state is not needed: the test ends)
        return r;
    };
    // (resume from where the machine is: save PC and restore it between calls)
    const pc0 = cpu.pc, s0 = cpu.s;
    const r1 = call(0x41, 5, 24); cpu.pc = pc0; cpu.s = s0;
    const r2 = call(11, 5, 10); cpu.pc = pc0; cpu.s = s0;
    const ok1 = r1.back && r1.xc === 1 && r1.yc === 1 && !r1.x, ok2 = r2.back && r2.xc === 1 && r2.yc === 1 && !r2.x;
    console.log(`${m.name}: CHPR "A" at row 24: ${JSON.stringify(r1)} ${ok1 ? "ok" : "FAIL"}; CHPR 11: ${JSON.stringify(r2)} ${ok2 ? "ok" : "FAIL"}`);
    if (!ok1 || !ok2) fail++;
}
console.log(fail ? "CHPR OVERFLOW TEST: FAIL" : "CHPR OVERFLOW TEST: PASS");
process.exit(fail ? 1 : 0);
