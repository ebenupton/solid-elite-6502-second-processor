// The ship gallery: each ship type rotating on the title screen, as the
// renderer draws it (the title's ship type replaced by the harness).
//
// node harness/mshipshow.mjs [--types 1-33] [--polls 230] [--out dir]
//                            [--disc d] [--syms s]
//
// For each type, boots the disc, sets X = type at TITLE's entry (the ship
// TITLE spawns), lets the ship come in for --polls key polls and saves
// <out>/type-NN.png (the space view), then a montage <out>/gallery.png.
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { loadSyms, mapAt, mapOfLabel, ROOT } from "./mlib.mjs";
import { writeFileSync, mkdirSync } from "fs";
import { execFileSync } from "child_process";
const a = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => { if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]); return acc; }, []));
const DISC = a.disc || `${ROOT}master/build/elite-master-sng47.ssd`;
const sy = loadSyms(a.syms || `${ROOT}master/build/symbols.txt`);
const OUT = a.out || `${ROOT}scratch/master/ships`;
mkdirSync(OUT, { recursive: true });
const [t0, t1] = (a.types || "1-33").split("-").map(Number);
const POLLS = +(a.polls || 230);
const tName = sy.TITLE_C !== undefined ? "TITLE_C" : "TITLE";
const tAddr = sy[tName], tMap = mapOfLabel(sy, tName);
const files = [];
for (let t = t0; t <= (t1 || t0); t++) {
    const s = new MachineSession("Master"); await s.initialise(); await s.boot(30);
    s.loadDisc(DISC); s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
    const cpu = s._machine.processor;
    let polls = 0, inT = false, done = false;
    cpu.debugInstruction.add(pc => {
        if (pc === tAddr && (tMap === "m" || tMap === mapAt(cpu.romsel, pc))) { if (!inT) cpu.x = t; inT = true; }
        if (inT && pc === sy.RDKEY && ++polls >= POLLS) done = true;
        return done;
    });
    while (!done) await s.runFor(200000);
    const f = `${OUT}/type-${String(t).padStart(2, "0")}.png`;
    writeFileSync(f, await s.screenshotActive({ scale: 1 }));
    files.push(f);
    console.log(f);
}
try { execFileSync("python3", ["-c", `
import sys
from PIL import Image
fs=sys.argv[2:]; ims=[Image.open(f).crop((186,70,694,450)).resize((254,190)) for f in fs]
cols=6; rows=(len(ims)+cols-1)//cols
m=Image.new('RGB',(254*cols,190*rows))
for k,im in enumerate(ims): m.paste(im,((k%cols)*254,(k//cols)*190))
m.save(sys.argv[1])`, `${OUT}/gallery.png`, ...files]); console.log(`${OUT}/gallery.png`); } catch (e) { console.log("no montage: " + e.message); }
