#!/usr/bin/env node
// tsavetest.mjs: harness/msavetest.mjs for the Tube build: save and load a
// commander through the game's own disc menu, with real key presses on the
// host's keyboard (so the host's keyboard scan, C_KEYS and C_DKS, carry them),
// on either host.
//
// node tube/tools/tsavetest.mjs [--host Master|B] [--disc d] [--psyms s] [--out dir]
//
// New game (title: N, then SPACE), docked: CASH (the parasite's) is set to a
// marker, "@" -> 2 (save) as TESTA; CASH is changed; "@" -> 1 (load) TESTA;
// CASH must be the marker again. Then a load of a file that isn't there (the
// error path: NEWBRK, then the host back in the command loop), "@" -> 3 (the
// catalogue, printed by the host's CHPR through hwrch), and a launch (f0): the
// game must still run (iterations go on) after the disc commands. The saved
// file must be the original's format: E.TESTA, 256 bytes, the commander block
// as the parasite holds it (NA%'s layout). Screenshots go to <out>. Exit 0 on
// success.
import { BBC } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/utils.js";
import { toSsdOrDsd } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/disc.js";
import { bootTube, ROOT } from "../../harness/tlib.mjs";
import { loadSyms } from "../../harness/mlib.mjs";
import { writeFileSync, mkdirSync } from "fs";
import { parseArgs } from "../../harness/args.mjs";
const a = parseArgs({ host: "value", disc: "value", psyms: "value", out: "value" });
const HOST = a.host || "Master";
const DISC = a.disc || `${ROOT}tube/build/elite-tube${HOST === "B" ? "-b" : ""}.ssd`;
const psy = loadSyms(a.psyms || `${ROOT}tube/build/psyms.txt`);
const OUT = a.out || `${ROOT}scratch/tsave-${HOST}`;
mkdirSync(OUT, { recursive: true });
const t = await bootTube({ host: HOST, disc: DISC });
const s = t.s, host = t.host, pm = t.par.memory;
s.keyDown(16); s.reset(true); host.execute(2e6 * 2); s.keyUp(16);
s._video.frameSkipCount = 0;
const secs = n => { for (let k = 0; k < n * 10; k++) host.execute(2e5); };
let iters = 0, brks = 0, oscli = 0;
t.addParHook(pc => { if (pc === psy.p_sync) iters++; if (pc === psy.NEWBRK) brks++; if (pc === psy.p_oscli) oscli++; return false; });
let shot = 0;
const snap = async name => writeFileSync(`${OUT}/${String(shot++).padStart(2, "0")}-${name}.png`, await s.screenshot());
const key = (k, hold = 0.15, after = 0.6) => { host.sysvia.keyDownRaw(BBC[k]); secs(hold); host.sysvia.keyUpRaw(BBC[k]); secs(after); };
const type = str => { for (const c of str) { const k = /[0-9]/.test(c) ? "K" + c : c; key(k, 0.1, 0.3); } };
const cash = () => [0, 1, 2, 3].map(i => pm[psy.CASH + i]);
const setCash = v => v.forEach((b, i) => { pm[psy.CASH + i] = b; });
secs(HOST === "B" ? 34 : 28);
await snap("title");
key("N"); secs(3);
key("SPACE"); secs(4);
await snap("docked");
const MARK = [0x00, 0x01, 0xe2, 0x40];   // 12345.6 Cr
setCash(MARK);
key("AT", 0.15, 1.5); await snap("menu");
key("K2", 0.15, 1.5);                    // 2: save
type("TESTA"); key("RETURN", 0.1, 1.5);
type("0"); secs(6);
await snap("saved");
setCash([0, 0, 0, 7]);
key("AT", 0.15, 1.5);
key("K1", 0.15, 1.5);                    // 1: load
type("TESTA"); key("RETURN", 0.1, 1.5);
type("0"); secs(6);
await snap("loaded");
const got = cash();
const ok = got.every((b, i) => b === MARK[i]);
console.log("CASH after load:", got.map(b => b.toString(16)).join(" "), ok ? "matches" : "DOES NOT MATCH");
key("F8", 0.15, 2);
key("AT", 0.15, 1.5);
key("K1", 0.15, 1.5);                    // a file that isn't there
type("QQ"); key("RETURN", 0.1, 1.5);
type("0"); secs(6);
await snap("error");
key("SPACE", 0.15, 2);
key("F8", 0.15, 2);
key("AT", 0.15, 1.5);
key("K3", 0.15, 1.5);                    // 3: catalogue
type("0"); key("RETURN", 0.1, 5);
await snap("catalogue");
key("SPACE", 0.15, 2);
key("ESCAPE", 0.15, 2);
const i0 = iters;
key("F0", 0.2, 12);                      // f0: launch
await snap("launched");
secs(4);
await snap("flight");
const flying = iters - i0;
{ const hs = loadSyms(`${ROOT}tube/build/${HOST === "B" ? "hbmsyms" : "hsyms"}.txt`);
  const near = (sy, pc) => { let b = null; for (const [n, v] of Object.entries(sy)) if (v <= pc && (!b || v > b[1])) b = [n, v]; return b ? `${b[0]}+${pc - b[1]}` : pc.toString(16); };
  console.log(`at the end: host ${near(hs, host.pc)} (&${host.pc.toString(16)}, ROMSEL ${host.romsel.toString(16)}), parasite ${near(psy, t.par.pc)}`); }
const img = toSsdOrDsd((host.fdc._drives || host.fdc.drives)[0].disc);
writeFileSync(`${OUT}/disc-after.ssd`, img);
const nf = img[0x105] / 8, files = {};
for (let i = 0; i < nf; i++) {
    const o = 8 + 8 * i, name = String.fromCharCode(img[o + 7] & 0x7f) + "." + String.fromCharCode(...img.slice(o, o + 7)).trim();
    const m = 0x108 + 8 * i, len = img[m + 4] | img[m + 5] << 8 | ((img[m + 6] >> 4) & 3) << 16, sec = img[m + 7] | (img[m + 6] & 3) << 8;
    files[name] = img.slice(sec * 256, sec * 256 + len);
}
console.log("disc catalogue:", Object.keys(files).join(" "));
const f = files["E.TESTA"];
const fmt = f && f.length === 256;
const blockOk = fmt && [...f.slice(9, 13)].every((b, i) => b === MARK[i]);
console.log("E.TESTA:", f ? `${f.length} bytes` : "missing", blockOk ? "(the commander block: CASH at offset 9)" : "(CASH NOT at offset 9)");
console.log(`disc commands (p_oscli): ${oscli}, errors (NEWBRK): ${brks}, frames in the 16 s after the launch: ${flying}`);
process.exit(ok && fmt && blockOk && brks === 1 && oscli >= 4 && flying > 20 ? 0 : 1);
