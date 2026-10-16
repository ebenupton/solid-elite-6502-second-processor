// Boot BBC Master Elite (master/build.sh's disc) on the emulated BBC Master and
// check that it reaches the title screen with its data in sideways RAM bank 6.
//
// node harness/mboot.mjs [--disc master/build/elite-master-sng47.ssd]
//                        [--syms master/build/symbols.txt] [--out dir]
//
// Boots with SHIFT+BREAK, runs until the first title screen ("Load New
// Commander (Y/N)?") has drawn its rotating ship a few times (the 8th call of
// RDKEY from TITLE's key loop), then reports ROMSEL / ACCCON, compares bank 6
// &8000-&B1FF with master/build/BDATA.unprot.bin (the game decrypts BDATA in
// place at start-up, so this is what bank 6 should hold) and writes
// title.png. Exit status 0 if the title screen was reached and bank 6 matches.
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { readFileSync, writeFileSync, mkdirSync } from "fs";

const ROOT = decodeURIComponent(new URL("..", import.meta.url).pathname);
const args = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => {
    if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]);
    return acc;
}, []));
const DISC = args.disc || `${ROOT}master/build/elite-master-sng47.ssd`;
const SYMS = args.syms || `${ROOT}master/build/symbols.txt`;
const OUT = args.out || `${ROOT}scratch/master/boot`;
mkdirSync(OUT, { recursive: true });

const syms = {};
for (const m of readFileSync(SYMS, "utf8").matchAll(/'([^']+)':(\d+)L?/g)) syms[m[1]] = +m[2];

const s = new MachineSession("Master");
await s.initialise();
await s.boot(30);
s.loadDisc(DISC);
s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
const cpu = s._machine.processor;

// RDKEY's caller is the return address on the stack at RDKEY's first instruction
let titleCalls = 0, done = false;
const titleLo = syms.TITLE, titleHi = syms.CHECK;
const h = pc => {
    if (pc === syms.RDKEY) {
        const ret = (cpu.readmem(0x101 + cpu.s) | (cpu.readmem(0x102 + cpu.s) << 8)) + 1;
        if (ret >= titleLo && ret < titleHi && ++titleCalls >= 8) done = true;
    }
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

// Bank 6 contents against the assembled BDATA (&7000-&B1FF; the bank holds &8000 on)
const bdata = readFileSync(`${ROOT}master/build/BDATA.unprot.bin`);
const off = (6 << 14) + cpu.romOffset - 0x8000;
let diffs = [];
for (let a = 0x8000; a < 0xb200; a++) if (cpu.ramRomOs[off + a] !== bdata[a - 0x7000]) diffs.push(a);
console.log(`bank 6 &8000-&B1FF against BDATA.unprot.bin: ${diffs.length} differing bytes` +
    (diffs.length ? ` (first &${diffs[0].toString(16)}, last &${diffs.at(-1).toString(16)})` : ""));
writeFileSync(`${OUT}/title.png`, await s.screenshotActive({ scale: 1 }));
console.log(`screenshot: ${OUT}/title.png`);
process.exit(diffs.length ? 1 : 0);
