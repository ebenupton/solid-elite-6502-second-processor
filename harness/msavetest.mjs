// Save and load a commander on the emulated Master, through the game's own
// disc menu, with real key presses (not the deterministic pilot).
//
// node harness/msavetest.mjs [--disc d] [--syms s] [--out dir]
//
// New game (title: N, then SPACE), docked: CASH is set to a marker, "@" ->
// 2 (save) as TESTA; CASH is changed; "@" -> 1 (load) TESTA; CASH must be
// the marker again. Then a load of a file that isn't there (the error path),
// "@" -> 3 (catalogue, drive 0), and a launch (f0) to check that the
// renderer is intact after the disc access. HAZEL's &C000-&C2FF and &DF00-&DFFF are
// filled with junk before each disc command (DOSCLI's stash of DFS's bytes). Checks the minimal NMI handler is
// back at &0D00 and that the disc's catalogue holds E.TESTA and every file. Screenshots of
// each step go to <out>. Exit status 0 on success.
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { BBC } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/utils.js";
import { toSsdOrDsd } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/disc.js";
import { loadSyms, ROOT } from "./mlib.mjs";
import { writeFileSync, mkdirSync } from "fs";
const a = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => { if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]); return acc; }, []));
const DISC = a.disc || `${ROOT}master/build/elite-master-sng47.ssd`;
const sy = loadSyms(a.syms || `${ROOT}master/build/symbols.txt`);
const OUT = a.out || `${ROOT}scratch/master/save`;
mkdirSync(OUT, { recursive: true });
const s = new MachineSession("Master"); await s.initialise(); await s.boot(30);
s.loadDisc(DISC); s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
const cpu = s._machine.processor;
const secs = n => s.runFor(2000000 * n);
const hits = { NEWBRK: 0, DOSNMI_C: 0, DOSCLI_C: 0 };
cpu.debugInstruction.add(pc => { for (const k in hits) if (pc === sy[k] && (k === "NEWBRK" || (cpu.romsel & 15) === 7)) hits[k]++; return false; });
let shot = 0;
const snap = async name => writeFileSync(`${OUT}/${String(shot++).padStart(2, "0")}-${name}.png`, await s.screenshotActive({ scale: 1 }));
// keys by their place in the BBC keyboard matrix (jsbeeb's BBC table)
const key = async (k, hold = 0.15, after = 0.6) => { cpu.sysvia.keyDownRaw(BBC[k]); await secs(hold); cpu.sysvia.keyUpRaw(BBC[k]); await secs(after); };
const slowType = async t => { for (const c of t) { await s.type(c); await secs(0.3); } };
const cash = () => [0, 1, 2, 3].map(i => cpu.ramRomOs[sy.CASH + i]);
const setCash = v => v.forEach((b, i) => { cpu.ramRomOs[sy.CASH + i] = b; });
// The game may use HAZEL's &C000-&C2FF (the rasteriser's scratch) and &DF00-&DFFF
// (state rebuilt on re-entering flight) between disc commands, as DOSCLI puts DFS's and
// the MOS's lasting bytes there (&C2C0-&C2FF, &DFDA-&DFDB) back from its stash (DFSST)
// for each command: fill them with junk before each one. (jsbeeb keeps HAZEL at &9000
// in its RAM array.)
const HZ = a => 0x9000 + a - 0xc000;
let seed = 12345;
const junk = () => {
    if (cpu.ramRomOs[HZ(sy.GDRAWON)] !== 0xff) { console.log("HAZEL is not where expected"); process.exit(1); }
    for (const [lo, hi] of [[0xc000, 0xc300], [0xdf00, 0xe000]]) for (let a = lo; a < hi; a++) { seed = (seed * 1103515245 + 12345) >>> 0; cpu.ramRomOs[HZ(a)] = seed >>> 24; } };
await secs(28);
await snap("title");
await key("N");                       // N: no commander to load
await secs(3);
await key("SPACE");                       // SPACE
await secs(4);
await snap("docked");
const MARK = [0x00, 0x01, 0xe2, 0x40];   // 12345.6 Cr
setCash(MARK);
junk(); await key("AT", 0.15, 1.5);           // @: the disc menu
await snap("menu");
console.log("QQ11 after @:", cpu.ramRomOs[sy.QQ11]);
await key("K2", 0.15, 1.5);            // 2: save
await s.type("TESTA"); await key("RETURN", 0.1, 1.5);
await s.type("0"); await secs(6);       // drive 0
await snap("saved");
setCash([0, 0, 0, 7]);
junk(); await key("AT", 0.15, 1.5);
await key("K1", 0.15, 1.5);            // 1: load
await s.type("TESTA"); await key("RETURN", 0.1, 1.5);
await s.type("0"); await secs(6);       // drive 0
await snap("loaded");
const got = cash();
const ok = got.every((b, i) => b === MARK[i]);
console.log("CASH after load:", got.map(b => b.toString(16)).join(" "), ok ? "matches" : "DOES NOT MATCH");
await key("F8", 0.15, 2);             // (another key first: the game ignores a
                                       // key pressed again straight away)
junk(); await key("AT", 0.15, 1.5);           // the error path: load a file that
await snap("e-menu");
await key("K1", 0.15, 1.5);            // isn't there ("File not found",
await s.type("QQ"); await key("RETURN", 0.1, 1.5); // through BRKV, NEWBRK)
await snap("e-name");
await s.type("0"); await secs(1);
await snap("e-err");
await secs(5);
await snap("error");
await key("SPACE", 0.15, 2);
await key("F8", 0.15, 2);
junk(); await key("AT", 0.15, 1.5);
await key("K3", 0.15, 1.5);            // 3: catalogue
await s.type("0"); await key("RETURN", 0.1, 5);
await snap("catalogue");
await key("SPACE", 0.15, 2);
await key("ESCAPE", 0.15, 2);              // ESCAPE out of the menu if needed
await key("F0", 0.2, 12);             // f0: launch
await snap("launched");
await secs(4);
await snap("flight");
console.log("disc commands (DOSCLI):", hits.DOSCLI_C, " errors (NEWBRK):", hits.NEWBRK, " NMI handler reinstalls (DOSNMI):", hits.DOSNMI_C);
const nmi = [0, 1, 2, 3, 4, 5].map(i => cpu.ramRomOs[0x0d00 + i].toString(16)).join(" ");
console.log("&0D00 after the disc accesses:", nmi, nmi === "48 ad 28 fe 68 40" ? "(the minimal NMI handler)" : "(NOT the minimal handler)");
// the disc's catalogue, as written (DFS: names at sector 0, 8 bytes each)
const img = toSsdOrDsd(cpu.fdc._drives[0].disc);
writeFileSync(`${OUT}/disc-after.ssd`, img);
const nf = img[0x105] / 8, names = [];
for (let i = 0; i < nf; i++) { const o = 8 + 8 * i; names.push(String.fromCharCode(img[o + 7] & 0x7f) + "." + String.fromCharCode(...img.slice(o, o + 7)).trim()); }
console.log("disc catalogue:", names.join(" "));
const saved = names.includes("E.TESTA");
console.log(saved ? "E.TESTA is on the disc" : "E.TESTA is NOT on the disc");
process.exit(ok && saved ? 0 : 1);
