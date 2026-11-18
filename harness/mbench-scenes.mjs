// mbench's frozen scenes (harness/mbench.mjs, tube/tools/tbench.mjs): the
// scenes and pose(sy, ram, scene), which puts a scene's state in at an MLOOP
// (the ship slots, the planet, slot 1, the parked sun, the view, our speed
// and rotation), in a build's own memory (its K%, LSO, SUNPK; the ships' line
// heaps down from its K% + &400)
export const NI = 37;
// ship types (elite-source.asm)
const SST = 2, CYL = 11, ADA = 21, MAM = 18, KRA = 19, SIDE = 17, VIPER = 16, PYTHON = 12, ASP = 26;

// a block: position, orientation (nosev, roofv, sidev as unit vectors), and the rest
const unit = 0x6000;
export function blockBytes({ x, y, z, nose = [0, 0, -1], roof = [0, 1, 0], side = [1, 0, 0], speed = 0, roll = 0, pitch = 0, ai = 0, newb = 0, energy = 100, heap = 0x0800 }) {
    const b = new Array(NI).fill(0);
    const c = (o, v) => { const m = Math.abs(Math.round(v)); b[o] = m & 255; b[o + 1] = (m >> 8) & 255; b[o + 2] = ((m >> 16) & 127) | (v < 0 ? 128 : 0); };
    c(0, x); c(3, y); c(6, z);
    const v = (o, w) => w.forEach((q, j) => { const m = Math.min(32767, Math.round(Math.abs(q) * unit)); b[o + 2 * j] = m & 255; b[o + 2 * j + 1] = (m >> 8) | (q < 0 ? 128 : 0); });
    v(9, nose); v(15, roof); v(21, side);
    b[27] = speed; b[29] = roll; b[30] = pitch; b[32] = ai; b[33] = heap & 255; b[34] = heap >> 8; b[35] = energy; b[36] = newb;
    return b;
}
const HEAP = { [CYL]: 157, [ADA]: 93, [MAM]: 97, [KRA]: 89, [SIDE]: 65, [VIPER]: 81, [PYTHON]: 89, [ASP]: 105, [SST]: 0 };
// the scenes: planet (type 128, its block), slot 1 (the sun 129 or the station SST), ships
const R = r => 24576 * 256 / r;                    // the z for a disc of radius r (PLANET: 24576 / z)
export const SCENES = {
    flight: { planet: { x: -R(20) * 0.3, y: R(20) * 0.2, z: R(20) }, slot1: { type: 129, x: R(8), y: R(8) * 0.4, z: -R(8) },
        ships: [[CYL, { x: 900, y: 300, z: 3000, speed: 10, roll: 2 }], [ADA, { x: -1200, y: -400, z: 4500, speed: 12 }], [VIPER, { x: 300, y: 900, z: 6000, speed: 14 }]], view: 0, delta: 15, alpha: 2, beta: 0 },
    combat: { planet: { x: R(15), y: R(15) * 0.5, z: R(15) }, slot1: { type: 129, x: -R(6), y: 0, z: -R(6) },
        ships: [[CYL, { x: 300, y: 200, z: 900, speed: 20, roll: 3, pitch: 2 }], [MAM, { x: -500, y: 100, z: 1200, speed: 25, roll: 130 }], [KRA, { x: 200, y: -600, z: 1500, speed: 22, pitch: 3 }],
            [SIDE, { x: -900, y: -200, z: 800, speed: 30, roll: 4 }], [ASP, { x: 700, y: 500, z: 2000, speed: 18, pitch: 130 }]], view: 0, delta: 20, alpha: 3, beta: 2 },
    beachball: { planet: { x: 0, y: -R(110) * 0.3, z: R(110) }, slot1: { type: 129, x: R(10), y: R(10), z: -R(10) },
        ships: [[PYTHON, { x: 800, y: 600, z: 2500, speed: 10 }]], view: 0, delta: 12, alpha: 1, beta: 0 },
    sun: { planet: { x: -R(60) * 0.4, y: -R(60) * 0.3, z: R(60) }, slot1: { type: 129, x: R(32) * 0.25, y: R(32) * 0.15, z: R(32) },
        ships: [], view: 0, delta: 1, alpha: 0, beta: 0 },
    docking: { planet: { x: 0, y: 0, z: 80000 }, slot1: { type: SST, x: 0, y: 0, z: 1500, roll: 255 }, park: { x: R(8), y: R(8), z: -R(8) },
        ships: [], view: 0, delta: 10, alpha: 0, beta: 0 },
    zone: { planet: { x: 0, y: -30000, z: 60000 }, slot1: { type: SST, x: 400, y: -500, z: 4000, roll: 255 }, park: { x: -R(7), y: R(7) * 0.2, z: -R(7) },
        ships: [[VIPER, { x: 500, y: 300, z: 2000, speed: 15, roll: 2 }], [CYL, { x: -800, y: 200, z: 3500, speed: 12 }]], view: 0, delta: 15, alpha: 2, beta: 1 },
    rear: { planet: { x: 0, y: R(100) * 0.3, z: -R(100) }, slot1: { type: 129, x: R(10), y: 0, z: R(10) },
        ships: [[CYL, { x: 500, y: 300, z: -2500, speed: 10, roll: 2 }], [ADA, { x: -700, y: -300, z: -3500, speed: 12 }]], view: 1, delta: 10, alpha: 2, beta: 0 },
};

export function pose(sy, ram, sc) {
    const K = sy["K%"];
    const put = (slot, type, b) => { for (let i = 0; i < NI; i++) ram[K + NI * slot + i] = b[i]; ram[sy.FRIN + slot] = type; };
    for (let i = 0; i <= 12; i++) ram[sy.FRIN + i] = 0;
    for (let i = 0; i < 40; i++) if (sy.MANY + i < sy.MANY + 34) ram[sy.MANY + i] = 0;
    ram[sy.JUNK] = 0;
    put(0, 128, blockBytes({ ...sc.planet, roll: 1, pitch: 1, heap: sy["K%"] + 0x400 }));
    put(1, sc.slot1.type, blockBytes({ ...sc.slot1, heap: sy.LSO }));
    if (sc.slot1.type === SST) ram[sy.SSPR] = 1;
    if (sc.park && sy.SUNPK !== undefined) { const b = blockBytes(sc.park); for (let i = 0; i < NI; i++) ram[sy.SUNPK + i] = b[i]; ram[sy.SUNPF] = 0x80; }
    let heap = sy["K%"] + 0x400, n = 2;      // (LS%: the heap's top, &0800 on the Master)
    for (const [t, d] of sc.ships) { heap -= HEAP[t]; put(n++, t, blockBytes({ ...d, heap })); ram[sy.MANY + t]++; }
    ram[sy.SLSP] = heap & 255; ram[sy.SLSP + 1] = heap >> 8;
    ram[sy.VIEW] = sc.view; ram[sy.DELTA] = sc.delta; ram[sy.ALPHA] = sc.alpha; ram[sy.BETA] = sc.beta;
    ram[sy.ENERGY] = 255; ram[sy.FSH] = 255; ram[sy.ASH] = 255; ram[sy.MCNT] = 1;
}

