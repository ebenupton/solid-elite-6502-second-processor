// Screenshots of a Master Elite build flown by the pilot (harness/mpilot.mjs).
//
// node harness/mshots.mjs [--disc d] [--syms s] [--at 100,250,...] [--every N]
//                         [--iters N] [--out dir] [--tag name] [--title]
//
// --at: main-loop iterations (MLOOP counts) to take a screenshot at; --every:
// one every N iterations; --title: also one of the first title screen after
// its ship has come in. Files are <out>/<tag>-<iteration>.png, and the
// pilot's phase and the view (QQ11) at each are printed.
import { runElite, loadSyms, ROOT } from "./mlib.mjs";
import { makePilot, patchCommander } from "./mpilot.mjs";
import { writeFileSync, mkdirSync } from "fs";

const a = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => { if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]); return acc; }, []));
const DISC = a.disc || `${ROOT}master/build/elite-master-sng47.ssd`;
const sy = loadSyms(a.syms || `${ROOT}master/build/symbols.txt`);
const OUT = a.out || `${ROOT}scratch/master/shots`, TAG = a.tag || "shot";
mkdirSync(OUT, { recursive: true });
const at = new Set((a.at ? String(a.at).split(",") : []).map(Number));
const every = +(a.every || 0);
const last = Math.max(+(a.iters || 0), ...at, 0);
// (with --ships, give --iters as the last iteration to look at)
const pilot = makePilot();
const pending = [];
await runElite({
    disc: DISC, syms: sy, pilot, iters: last + 1, patch: patchCommander,
    onIter: (i, s, res) => {
        // --ships N: up to N shots, at least 40 iterations apart, of the space
        // view with a ship on screen (bit 3 of byte #31 in a ship's slot)
        let ship = false;
        if (a.ships && res.cpu.ramRomOs[sy.QQ11] === 0 && i - (globalThis.lastShip ?? -99) >= 40 && (globalThis.nShips ?? 0) < +a.ships)
            for (let k = 1; k < 12; k++) {
                const t = res.cpu.ramRomOs[sy.FRIN + k];
                if (t > 0 && t < 128 && (res.cpu.ramRomOs[sy["K%"] + 37 * k + 31] & 8)) ship = true;
            }
        if (ship) { globalThis.lastShip = i; globalThis.nShips = (globalThis.nShips ?? 0) + 1; }
        if (ship || at.has(i) || (every && i % every === 0)) {
            const qq11 = res.cpu.ramRomOs[sy.QQ11];
            pending.push(s.screenshotActive({ scale: 1 }).then(png => {
                const f = `${OUT}/${TAG}-${String(i).padStart(6, "0")}.png`;
                writeFileSync(f, png);
                console.log(`${f}  phase ${pilot.P.phase}  QQ11 ${qq11}`);
            }));
        }
    },
});
await Promise.all(pending);
