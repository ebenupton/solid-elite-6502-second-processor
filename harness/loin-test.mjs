// Unit test for the port's line routines: calls LOIN (and HLOIN) in the port
// on random lines and checks the pixels plotted against a model of the
// original cassette LOIN/HLOIN algorithm (which works in pixel coordinates, so
// the set of pixels plotted is independent of the screen layout).
// node harness/loin-test.mjs [--n 300]
import { MachineSession } from "/Users/ebenupton/.npm/_npx/e76f2a7d329553db/node_modules/jsbeeb/src/machine-session.js";
import { readFileSync } from "fs";
const args = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => {
    if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]);
    return acc;
}, []));
const ROOT = "/Users/ebenupton/elite";
const N = +(args.n || 300);
const syms = {};
for (const m of readFileSync(`${ROOT}/build/symbols.txt`, "utf8").matchAll(/'([^']+)':(\d+)L?/g)) syms[m[1]] = +m[2];

// Model of the original LOIN: returns list of [x, y] pixels plotted (each EOR'd once)
function modelLoin(x1, y1, x2, y2) {
    const px = [];
    let S = 128, SWAP = 0;
    let P = Math.abs(x2 - x1), Q = Math.abs(y2 - y1);
    if (Q < P) {
        if (!(x1 < x2)) { SWAP = 0xff; [x1, x2] = [x2, x1]; [y1, y2] = [y2, y1]; }
        // Q = Q/P via shift-and-subtract (7 bits) -> 8-bit fraction
        let a = Q, q = 0xfe, c;
        do { let carry = a & 0x80; a = (a << 1) & 0xff; let sub = false; if (carry || a >= P) { a = (a - P) & 0xff; sub = true; } c = (q & 0x80) ? 1 : 0; q = ((q << 1) | (sub ? 1 : 0)) & 0xff; } while (c);
        const slope = q;
        let n = P + 1, x = x1, y = y1;
        const up = !(y2 - y1 - 1 >= 0); // BCS DOWN if Y2 >= Y1 - 1... (computed with C clear: Y2-Y1-1)
        const skipFirst = up ? (SWAP !== 0) : (SWAP === 0);
        let first = true;
        while (true) {
            if (!(first && skipFirst)) { if (first) n--; px.push([x, y]); }
            first = false;
            x++;
            S += slope; if (S > 255) { S &= 255; y += up ? -1 : 1; }
            n--; if (n === 0) break;
        }
    } else {
        if (y1 < y2) { SWAP = 0xff; [x1, x2] = [x2, x1]; [y1, y2] = [y2, y1]; }
        let a = P, p = 1, c;
        do { let carry = a & 0x80; a = (a << 1) & 0xff; let sub = false; if (carry || a >= Q) { a = (a - Q) & 0xff; sub = true; } c = (p & 0x80) ? 1 : 0; p = ((p << 1) | (sub ? 1 : 0)) & 0xff; } while (!c);
        const slope = p;
        let n = Q + 1, x = x1, y = y1;
        const left = x2 < x1;
        const skipFirst = SWAP === 0;
        let first = true;
        while (true) {
            if (!(first && skipFirst)) { if (first) n--; px.push([x, y]); }
            first = false;
            y--;
            S += slope; if (S > 255) { S &= 255; x += left ? -1 : 1; }
            n--; if (n === 0) break;
        }
    }
    return { px, SWAP };
}

const s = new MachineSession("Master");
await s.initialise();
await s.boot(30);
s.loadDisc(`${ROOT}/build/elite-master.ssd`);
s.keyDown(16); s.reset(true); await s.runFor(2000000); s.keyUp(16);
const cpu = s._machine.processor;
let stopAt = syms.TT170, hit = false;
cpu.debugInstruction.add(pc => { if (pc === stopAt) { hit = true; return true; } return false; });
while (!hit) { cpu.execute(20000); }
const RET = 0x0f38;   // any address; we stop when the routine returns there
function call(addr) {
    cpu.p.i = true;
    const sp = cpu.s;
    s.writeMemory(0x100 + sp, [(RET - 1) >> 8]);
    s.writeMemory(0x100 + ((sp - 1) & 255), [(RET - 1) & 255]);
    cpu.s = (sp - 2) & 255;
    cpu.pc = addr;
    stopAt = RET; hit = false;
    let guard = 0;
    while (!hit && guard++ < 1000) { if (cpu.pc === RET) { hit = true; break; } cpu.execute(2000); }
    if (!hit) throw new Error("routine did not return");
}
function screenPixels() {
    const mem = s.readMemory(0x4000, 0x3000);
    const set = new Map();
    for (let y = 0; y < 192; y++) for (let x = 0; x < 256; x++) {
        const o = (y >> 3) * 0x200 + (y & 7) + 8 * (x >> 2);
        const b = mem[o], p = x & 3;
        const v = ((b >> (7 - p)) & 1) * 2 + ((b >> (3 - p)) & 1);
        if (v) set.set(`${x},${y}`, v);
    }
    return set;
}
const zero = new Array(0x3000).fill(0);
let fails = 0;
let seed = 12345;
const rnd = n => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed % n; };
for (let t = 0; t < N; t++) {
    let x1 = rnd(256), y1 = rnd(192), x2 = rnd(256), y2 = rnd(192);
    if (t % 4 === 1) { y2 = Math.min(191, y1 + rnd(8)); }        // mostly horizontal
    if (t % 4 === 2) { x2 = Math.min(255, x1 + rnd(8)); }        // mostly vertical
    s.writeMemory(0x4000, zero);
    s.writeMemory(syms.X1, [x1]); s.writeMemory(syms.Y1, [y1]); s.writeMemory(syms.X2, [x2]); s.writeMemory(syms.Y2, [y2]);
    call(syms.LOIN);
    const got = screenPixels();
    const { px, SWAP } = modelLoin(x1, y1, x2, y2);
    const exp = new Map();
    for (const [x, y] of px) { const k = `${x},${y}`; if (exp.has(k)) exp.delete(k); else exp.set(k, 1); }
    let ok = got.size === exp.size;
    for (const [k, v] of got) if (!exp.has(k) || v !== 1) ok = false;
    const swapGot = s.readMemory(syms.SWAP, 1)[0];
    if (swapGot !== SWAP) ok = false;
    if (!ok) {
        fails++;
        if (fails <= 10) {
            const missing = [...exp.keys()].filter(k => !got.has(k));
            const extra = [...got.keys()].filter(k => !exp.has(k));
            console.log(`FAIL (${x1},${y1})-(${x2},${y2}): expected ${exp.size} got ${got.size} SWAP exp ${SWAP} got ${swapGot}; missing ${missing.slice(0, 8)}; extra ${extra.slice(0, 8)}`);
        }
    }
}
console.log(`LOIN: ${N - fails}/${N} lines match the original algorithm`);
// HLOIN: draws pixels min(X1,X2) .. max(X1,X2)-1 on row Y1 (in cyan via HLOIN)
let hfails = 0;
for (let t = 0; t < N; t++) {
    const x1 = rnd(256), x2 = t % 3 ? rnd(256) : Math.min(255, x1 + rnd(6)), y = rnd(192);
    s.writeMemory(0x4000, zero);
    s.writeMemory(syms.X1, [x1]); s.writeMemory(syms.Y1, [y]); s.writeMemory(syms.X2, [x2]);
    call(syms.HLOIN);
    const got = screenPixels();
    const lo = Math.min(x1, x2), hi = Math.max(x1, x2);
    let ok = got.size === hi - lo;
    for (let x = lo; x < hi; x++) if (got.get(`${x},${y}`) !== 1) ok = false;
    if (!ok) { hfails++; if (hfails <= 10) console.log(`HLOIN FAIL ${x1}-${x2} y=${y}: got ${got.size}`); }
}
console.log(`HLOIN: ${N - hfails}/${N} lines match the original algorithm`);
fails += hfails;
process.exit(fails ? 1 : 0);
