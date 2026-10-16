// Boot BBC Master Elite (master/build.sh's disc) on the emulated BBC Master and
// check that it reaches the title screen with its data in Elite's home bank
// (sideways RAM bank 4; bank 6 in the original).
//
// node harness/mboot.mjs [--disc master/build/elite-master-sng47.ssd]
//                        [--syms master/build/symbols.txt] [--out dir] [--polls N]
//
// Boots with SHIFT+BREAK, runs until the first title screen ("Load New
// Commander (Y/N)?") has drawn its rotating ship a few times (the 8th call of
// RDKEY after TITLE starts), then reports ROMSEL / ACCCON, compares the
// sideways, shadow and main RAM images the loader installs (BANK4.bin,
// ANDY.bin, COLD7.bin, TOKENS.bin, STUBS.bin; the renderer's BANK5.bin,
// BANK6.bin, RAST7.bin and HAZEL.bin; LOWCODE.bin) with what memory holds, and
// writes title.png.
// Exit status 0 if the title screen was reached and the banks match.
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { loadSyms, mapAt, mapOfLabel } from "./mlib.mjs";

const ROOT = decodeURIComponent(new URL("..", import.meta.url).pathname);
const args = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => {
    if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]);
    return acc;
}, []));
const DISC = args.disc || `${ROOT}master/build/elite-master-sng47.ssd`;
const SYMS = args.syms || `${ROOT}master/build/symbols.txt`;
const OUT = args.out || `${ROOT}scratch/master/boot`;
mkdirSync(OUT, { recursive: true });

const syms = loadSyms(SYMS);

const s = new MachineSession("Master");
await s.initialise();
await s.boot(30);
s.loadDisc(DISC);
s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
const cpu = s._machine.processor;

// Count RDKEY calls once TITLE (or its cold copy TITLE_C, in the cold area
// from Stage B) has been entered: TITLE's key loop calls RDKEY repeatedly
let titleCalls = 0, done = false, inTitle = false;
const tName = syms.TITLE_C !== undefined ? "TITLE_C" : "TITLE";
const tAddr = syms[tName], tMap = mapOfLabel(syms, tName);
const h = pc => {
    if (pc === tAddr && (tMap === "m" || tMap === mapAt(cpu.romsel, pc))) inTitle = true;
    if (pc === syms.RDKEY && inTitle && ++titleCalls >= (+args.polls || 8)) done = true;
    return done;
};
cpu.debugInstruction.add(h);
const t0 = cpu.cycleSeconds;
while (!done && cpu.cycleSeconds - t0 < 60) { h(cpu.pc); cpu.execute(20000); }
const secs = cpu.cycleSeconds + cpu.currentCycles / 2e6;
if (!done) { console.log(`FAIL: title screen key loop not reached in 60 emulated seconds (PC &${cpu.pc.toString(16)})`); process.exit(1); }
console.log(`title screen key loop reached at emulated t=${secs.toFixed(2)} s`);
console.log(`ROMSEL &${cpu.romsel.toString(16)} (bank ${cpu.romsel & 15}${cpu.romsel & 0x80 ? ", ANDY paged" : ""}), ACCCON &${cpu.acccon.toString(16)}`);
console.log(`sideways RAM banks in this model: ${cpu.model.swram.map((v, i) => v ? i : -1).filter(i => i >= 0).join(" ")}`);

// The banked images against the build: [file, ROMSEL or "shadow", start]
// (ROMSEL bit 7: ANDY at &8000-&8FFF). The game writes XX21+2/3 (the station's
// blueprint) in bank 4 and patches DETOK's JSR at DTM (DTM_C in the cold area).
const images = [["BANK4.bin", 4, 0x8000], ["ANDY.bin", 0x87, 0x8000], ["COLD7.bin", 7, 0xac40], ["TOKENS.bin", "shadow", 0x3100], ["STUBS.bin", "main", 0x7e00],
    ["BANK5.bin", 5, 0x8000], ["BANK6.bin", 6, 0x8000], ["RAST7.bin", 7, 0x8000], ["HAZEL.bin", "hazel", syms.HZ_START], ["LOWCODE.bin", "main", 0x0840], ["HICODE.bin", "main", 0x7200]];
const xx21 = syms.XX21;
let diffs = [];
for (const [f, rs, start] of images) {
    let img;
    try { img = readFileSync(`${ROOT}master/build/${f}`); } catch { continue; }
    const d = [];
    for (let i = 0; i < img.length; i++) {
        const a = start + i;
        const phys = rs === "main" ? a : rs === "shadow" ? a + 0x8000 : rs === "hazel" ? a - 0xc000 + 0x9000 : rs & 0x80 && a < 0x9000 ? a : cpu.romOffset + (rs & 15) * 16384 + a - 0x8000;
        if (rs === 4 && (a === xx21 + 2 || a === xx21 + 3)) continue;
        if (syms.DTM_C !== undefined && (rs & 15) === 7 && (a === syms.DTM_C + 1 || a === syms.DTM_C + 2)) continue;
        if (cpu.ramRomOs[phys] !== img[i]) d.push(a);
    }
    console.log(`${f} (${rs === "shadow" ? "shadow RAM" : rs === "main" ? "main RAM" : rs === "hazel" ? "HAZEL" : "ROMSEL &" + rs.toString(16)}, &${start.toString(16)}-&${(start + img.length - 1).toString(16)}): ${d.length} differing bytes` +
        (d.length ? ` (first &${d[0].toString(16)}, last &${d.at(-1).toString(16)})` : ""));
    // the renderer's banks and code hold variables and self-modified code:
    // their differences are reported but not failures
    if (!["BANK5.bin", "BANK6.bin", "RAST7.bin", "HAZEL.bin", "HICODE.bin"].includes(f)) diffs = diffs.concat(d);
}
writeFileSync(`${OUT}/title.png`, await s.screenshotActive({ scale: 1 }));
console.log(`screenshot: ${OUT}/title.png`);
process.exit(diffs.length ? 1 : 0);
