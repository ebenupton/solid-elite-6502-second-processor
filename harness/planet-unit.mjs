// Unit test of the meridian boundaries (planet4.asm PM_HOOK + PM_MERID)
// against the reference model, on the cases dumped by
//   python3 tools/planet_synth.py N --dump cases.json
// node harness/planet-unit.mjs cases.json [--disc d] [--syms s]
// The game is booted and stopped at a main-loop iteration (bank 4 paged);
// each case's inputs are written (INWK roofv/sidev, K4, PM_R, TGT; then the
// disc rows and PM_CX/CY) and the two routines are called directly.
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { readFileSync } from "fs";
const argv = process.argv.slice(2);
const a = Object.fromEntries(argv.reduce((acc, v, i, arr) => { if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]); return acc; }, []));
const cases = JSON.parse(readFileSync(argv[0], "utf8"));
const syms = {};
for (const m of readFileSync(a.syms || "build/symbols.txt", "utf8").matchAll(/'([^']+)':(\d+)L?/g)) syms[m[1]] = +m[2];
const S = n => { if (syms[n] === undefined) throw new Error(n); return syms[n]; };
const s = new MachineSession("Master");
await s.initialise(); await s.boot(30);
s.loadDisc(a.disc || "build/elite-master.ssd");
s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
const cpu = s._machine.processor;
let n100 = 0, stop = false, trap = S("PM_CY") + 2;
cpu.debugInstruction.add(pc => {
    if (pc === S("TT100") && ++n100 >= 5 && !stop) { stop = true; return true; }
    if (pc === trap) return true;
    return false;
});
while (!stop) cpu.execute(50000);
const w = (ad, v) => cpu.writemem(ad, v & 255);
const r = ad => cpu.readmem(ad);
function call(addr) {
    const ret = trap - 1;
    w(0x100 + cpu.s, ret >> 8); cpu.s = (cpu.s - 1) & 255;
    w(0x100 + cpu.s, ret & 255); cpu.s = (cpu.s - 1) & 255;
    cpu.pc = addr;
    let n = 0;
    while (cpu.pc !== trap) { cpu.execute(2000); if (++n > 5000) throw new Error("no return from " + addr.toString(16)); }
}
const smag = v => { const m = Math.min(Math.abs(v), 32767); return [m & 255, (m >> 8) | (v < 0 ? 128 : 0)]; };
let bad = 0, rowsBad = 0;
for (let ci = 0; ci < cases.length; ci++) {
    const c = cases[ci];
    if ((cpu.romsel & 15) !== 4) throw new Error("bank 4 not paged");
    const inwk = S("INWK");
    const vals = [...c.roof, ...c.side];
    vals.forEach((v, i) => { const [lo, hi] = smag(v); w(inwk + 15 + 2 * i, lo); w(inwk + 16 + 2 * i, hi); });
    w(S("K4"), c.cy & 255); w(S("K4") + 1, (c.cy >> 8) & 255);
    w(S("PM_R"), c.r); w(S("TGT"), 31); w(S("QQ11"), 0); w(S("GFORCE"), 0); w(S("PM_OK"), 0);
    call(S("PM_HOOK"));
    w(S("PM_CX"), c.cx & 255); w(S("PM_CX") + 1, (c.cx >> 8) & 255);
    w(S("PM_CY"), c.cy & 255); w(S("PM_CY") + 1, (c.cy >> 8) & 255);
    w(S("R_NDT"), c.top); w(S("R_NDB"), c.bot);
    for (let y = 0; y < 192; y++) { w(S("R_NDISCL") + y, c.ndl[y]); w(S("R_NDISCR") + y, c.ndr[y]); }
    call(S("PM_MERID"));
    let nb = 0, ex = null;
    for (let y = c.top; y <= c.bot; y++) {
        const n = r(S("R_NDN") + y);
        const xs = []; for (let k = 0; k < n; k++) xs.push(r(S("R_NDX0") + 192 * k + y));
        const p = r(S("R_NDP") + y) & 1;
        const [wp, wx] = c.rows[y];
        if (p !== (wp & 1) || JSON.stringify(xs) !== JSON.stringify(wx)) { nb++; if (!ex) ex = { y, got: [p, xs], want: [wp & 1, wx] }; }
    }
    if (nb) { bad++; rowsBad += nb; if (bad <= 5) console.log(`case ${ci} (c ${c.cx},${c.cy} r ${c.r} side ${c.side} roof ${c.roof}): ${nb} rows differ, e.g.`, JSON.stringify(ex)); }
}
console.log(`${cases.length} cases, ${bad} differ (${rowsBad} rows)`);
process.exit(0);
