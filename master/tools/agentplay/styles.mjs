// Play styles for agentplay: the commanders a session starts with (patched into both
// machines' NA%, the last-saved commander, at the first QU5: DFAULT then copies it into the
// commander, and the game sets up the current system from it; a death goes back to it too),
// elite-agent's own modes (environment for agentd), and the chaos overlay: extra keys
// and pokes, chosen from the reference's state with a seeded random number generator,
// that drive the game into what the agent rarely does on its own (escape pod, energy
// bomb, E.C.M., galactic hyperdrive, the views, deaths). Everything the overlay does goes
// through the same input log, so a session replays exactly.

// A commander patch: { symbol: bytes } written into the live commander and into NA% (the
// last-saved copy; NA%+8 lines up with TP, as elite-agent's save check assumes)
// The original checks NA%'s checksum in DFAULT and loops for ever if it is wrong (the
// port has the checksums removed), so the patch sets CHK as CHECK computes it, and CHK2 to
// CHK EOR &A9 (or the game marks the commander as tampered with in COK)
function patcher(fields) {
    return m => {
        const sy = m.sy, na = sy["NA%"];
        for (const [k, v] of Object.entries(fields)) {
            m.wr(sy[k], v);
            if (sy[k] >= sy.TP && sy[k] <= sy.SVC) m.wr(na + 8 + sy[k] - sy.TP, v);
        }
        // CHECK: X = NT% - 3, A = X, C = 0; A = A + NA%+7+X + C, A = A EOR NA%+8+X, for X down to 1
        let x = sy.SVC - sy.TP, a = x, c = 0;
        for (; x > 0; x--) { const t = a + m.rb(na + 7 + x) + c; a = t & 255; c = t > 255 ? 1 : 0; a ^= m.rb(na + 8 + x); }
        m.wr(sy.CHK, [a]); m.wr(sy.CHK2, [a ^ 0xa9]);
    };
}
const cash = cr => { const t = Math.round(cr * 10); return [t >>> 24 & 255, t >>> 16 & 255, t >>> 8 & 255, t & 255]; };
// the galaxy seeds QQ21 of galaxy g (0-7): Lave's galaxy's, each byte rotated left g times
const twist = (b, n) => { for (let i = 0; i < n; i++) b = ((b << 1) | (b >> 7)) & 255; return b; };
const galaxy = g => ({ GCNT: [g], QQ21: [0x4a, 0x5a, 0x48, 0x02, 0x53, 0xb7].map(b => twist(b, g)) });
const ALL = { ECM: [0xff], BST: [0xff], BOMB: [0x7f], ENGY: [1], DKCMP: [0xff], GHYP: [0xff], ESCP: [0xff], NOMSL: [4], CRGO: [37], QQ14: [70] };

export const COMMANDERS = {
    jameson: { what: "the default commander: 100 Cr, a pulse laser, 3 missiles" },
    trader: { what: "5000 Cr and a large cargo bay", patch: patcher({ CASH: cash(5000), CRGO: [37] }) },
    equipped: { what: "every piece of equipment, a beam laser, 4 missiles, 3000 Cr", patch: patcher({ ...ALL, LASER: [0x8f, 0, 0, 0], CASH: cash(3000) }) },
    rich: { what: "100000 Cr, nothing fitted", patch: patcher({ CASH: cash(100000) }) },
    // a tally of 5000 (Deadly): the missions come up as soon as the agent docks in
    // galaxy 1 (Constrictor) and after (Thargoid plans, galaxy 3)
    deadly: { what: "Deadly (tally 5000), military laser, everything fitted, 20000 Cr", patch: patcher({ ...ALL, LASER: [0x97, 0x8f, 0, 0], CASH: cash(20000), TALLY: [5000 & 255, 5000 >> 8] }) },
    // the Thargoid plans mission due (Constrictor mission done: TP bits 0-1 = 2), in galaxy 1 with the hyperdrive
    mission2: { what: "Constrictor mission done, tally 1400, all fitted: the Thargoid plans mission next", patch: patcher({ ...ALL, LASER: [0x97, 0, 0, 0], CASH: cash(20000), TALLY: [1400 & 255, 1400 >> 8], TP: [2] }) },
    // mission 1 done but not yet debriefed (TP bits 0-1 = 3): the next dock debriefs
    debrief1: { what: "the Constrictor destroyed, not yet debriefed (TP = 3): debriefing at the first dock", patch: patcher({ ...ALL, LASER: [0x97, 0, 0, 0], CASH: cash(5000), TALLY: [1000 & 255, 1000 >> 8], TP: [3] }) },
    // galaxy 3 at Ceerdi (215, 84) with mission 1 done and tally 1400: the Thargoid plans
    // briefing at the first dock, then Ceerdi (BRIEF3) and Birera (DEBRIEF2)
    galaxy3: { what: "galaxy 3 at Ceerdi, mission 1 done, tally 1400, all fitted: the Thargoid plans mission", patch: patcher({ ...ALL, ...galaxy(2), QQ0: [215], QQ1: [84], LASER: [0x97, 0x8f, 0, 0], CASH: cash(20000), TALLY: [1400 & 255, 1400 >> 8], TP: [2] }) },
    // galaxy 3 at Birera (63, 72) with the Thargoid plans aboard (TP = %1010): the agent
    // takes them to Birera, where docking debriefs mission 2
    debrief2: { what: "galaxy 3 at Birera with the Thargoid plans (TP = 10): mission 2's debriefing at Birera", patch: patcher({ ...ALL, ...galaxy(2), QQ0: [63], QQ1: [72], LASER: [0x97, 0x8f, 0, 0], CASH: cash(20000), TALLY: [1500 & 255, 1500 >> 8], TP: [10] }) },
    wanted: { what: "a fugitive (legal status 80), 2000 Cr, ECM and pod", patch: patcher({ FIST: [80], CASH: cash(2000), ECM: [0xff], ESCP: [0xff] }) },
};

// elite-agent's modes, as agentd's environment
export const MODES = {
    efficient: {},
    curious: { CURIOUS: "1" },
    fair: { FAIR: "1" },
    keyboard: { JOYSTICK: "0" },          // keys for roll and pitch instead of the stick
    nosave: { SAVE: "0" },
    nomission: { NOMISSION: "1" },
    load: { LOAD: "CLAUDE" },           // load commander CLAUDE from the disc when first docked (a disc from --savediscs)
};

// ---- the chaos overlay
// Keys (BBC internal numbers)
const K = { E: 0x22, TAB: 0x60, ESC: 0x70, F0: 0x20, F1: 0x71, F2: 0x72, F3: 0x73, F4: 0x14, F5: 0x74, T: 0x23, M: 0x65, U: 0x35, J: 0x45, H: 0x54, CTRL: 0x01, C: 0x52, SPACE: 0x62, SLASH: 0x68, X: 0x42, S: 0x51 };
// actions: when they may happen (the reference's RAM), the keys and for how many frames,
// and how often (mean frames between, while allowed)
const ACTIONS = {
    ecm:     { every: 1500, when: (r, sy) => flying(r, sy) && r[sy.ECM], keys: [[K.E, 4]] },
    bomb:    { every: 6000, when: (r, sy) => flying(r, sy) && r[sy.BOMB], keys: [[K.TAB, 3]] },
    pod:     { every: 20000, when: (r, sy) => flying(r, sy) && r[sy.ESCP], keys: [[K.ESC, 6]] },
    views:   { every: 1200, when: flying, keys: () => [[[K.F1, K.F2, K.F3][Math.floor(rng() * 3)], 3], [null, 120], [K.F0, 3]] },
    missile: { every: 2500, when: (r, sy) => flying(r, sy) && r[sy.NOMSL], keys: [[K.T, 3], [null, 25], [K.M, 3]] },
    unarm:   { every: 4000, when: (r, sy) => flying(r, sy) && r[sy.NOMSL], keys: [[K.T, 3], [null, 25], [K.U, 3]] },
    ghyp:    { every: 30000, when: (r, sy) => flying(r, sy) && r[sy.GHYP] && !r[sy.QQ22 + 1], keys: [[K.CTRL, 1], [[K.CTRL, K.H], 4], [K.CTRL, 2]] },
    hyper:   { every: 15000, when: (r, sy) => flying(r, sy) && !r[sy.QQ22 + 1], keys: [[K.H, 4]] },
    jump:    { every: 2000, when: flying, keys: [[K.J, 30]] },
    dock:    { every: 8000, when: (r, sy) => flying(r, sy) && r[sy.DKCMP], keys: [[K.C, 3]] },
    charts:  { every: 3000, when: flying, keys: () => [[[K.F4, K.F5][Math.floor(rng() * 2)], 3], [null, 100], [K.F0, 3]] },
    spin:    { every: 2500, when: flying, keys: () => [[[[0x66, K.X], [0x67, K.S], [0x66, K.S]][Math.floor(rng() * 3)], 40]] },
};
// pokes (both machines, at an iteration boundary): drained shields and energy (a fight
// then kills us), cabin heat near the limit
const POKES = {
    hurt: { every: 15000, when: flying, poke: () => [["FSH", 0, [0]], ["ASH", 0, [0]], ["ENERGY", 0, [12]]] },
    heat: { every: 20000, when: flying, poke: () => [["CABTMP", 0, [230]]] },
    fuel: { every: 20000, when: flying, poke: () => [["QQ14", 0, [3]]] },
};
// the disc menu, while docked on the Status screen (one such action a dock, and the
// agent's keys are held back while it runs): catalogues, deletes, loads of a missing
// file, invalid and empty drives, saves under other names (until the catalogue is full),
// the default commander. Steps: [keys, frames], or { until(r, sy), keys, max } (hold
// keys until the condition, at most max frames), or { pulse, until, max } (tap a key
// every 12 frames until the condition)
const D = { 0: 0x27, 1: 0x30, 2: 0x31, 3: 0x11, 4: 0x12, 5: 0x13, 6: 0x34, 7: 0x24, 8: 0x15, 9: 0x26, RET: 0x49, Y: 0x44, N: 0x55, AT: 0x47 };
const LETTER = { A: 0x41, B: 0x64, C: 0x52, D: 0x32, E: 0x22, F: 0x43, G: 0x53, H: 0x54, I: 0x25, J: 0x45, K: 0x46, L: 0x56, M: 0x65, N: 0x55, O: 0x36, P: 0x37, Q: 0x10, R: 0x33, S: 0x51, T: 0x23, U: 0x35, V: 0x63, W: 0x21, X: 0x42, Y: 0x44, Z: 0x61 };
const press = k => [[k, 3], [null, 5]];
const typed = t => [...t].flatMap(ch => press(LETTER[ch] ?? D[ch]));
const inMenu = (r, sy) => r[sy.QQ11] === 1;
const atStatus = (r, sy) => r[sy.QQ12] && r[sy.QQ11] === 8;
const menu = () => [{ until: inMenu, keys: [D.AT], max: 150 }, [null, 20]];
const leave = () => [[null, 20], { pulse: D[6], until: atStatus, max: 1500 }];
const drive = k => [...press(k), [null, 10]];
let saveNo = 0;
const DISC = {
    dcat:   () => [...menu(), ...press(D[3]), ...drive(D[0]), [null, 250], ...press(0x62), ...leave()],
    dcat1:  () => [...menu(), ...press(D[3]), ...drive(D[1]), [null, 400], ...press(0x62), ...leave()],
    dbad:   () => [...menu(), ...press(D[rng() < 0.5 ? 3 : 1]), ...(rng() < 0.5 ? [] : [[null, 12], ...typed("BAD"), ...press(D.RET), [null, 6]]), ...drive(D[rng() < 0.5 ? 7 : 9]), [null, 30], ...leave()],
    dnoload: () => [...menu(), ...press(D[1]), [null, 12], ...typed("NOFILE"), ...press(D.RET), [null, 6], ...drive(D[0]), [null, 200], ...leave()],
    dnodel: () => [...menu(), ...press(D[4]), ...drive(D[0]), [null, 250], ...typed("NOFILE"), ...press(D.RET), [null, 200], ...leave()],
    dsave:  () => { const n = "CH" + (saveNo++ % 40); return [...menu(), ...press(D[2]), [null, 12], ...typed(n), ...press(D.RET), [null, 6], ...drive(D[0]), [null, 250], ...leave()]; },
    ddel:   () => { const n = "CH" + Math.floor(rng() * Math.max(1, saveNo)); return [...menu(), ...press(D[4]), ...drive(D[0]), [null, 250], ...typed(n), ...press(D.RET), [null, 200], ...leave()]; },
    ddefault: () => [...menu(), ...press(D[5]), [null, 10], ...press(rng() < 0.5 ? D.Y : D.N), [null, 30], ...leave()],
    dexit:  () => [...menu(), ...press(D[6]), ...leave()],
};
for (const [nm, f] of Object.entries(DISC)) ACTIONS[nm] = { every: 150, disc: true, exclusive: true, when: atStatus, keys: f };

function flying(r, sy) { return !r[sy.QQ12] && !r[sy.QQ11] && r[sy.MCNT] !== 0xff; }

let rng = Math.random;
function mulberry(a) { return () => { a |= 0; a = a + 0x6d2b79f5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }

// spec: "all" or a comma list of action and poke names, with an optional *factor on the
// rate ("ecm,bomb*2")
export function makeChaos(spec, seed) {
    const r = mulberry(seed * 7919 + 17);
    const names = spec === "all" ? [...Object.keys(ACTIONS).filter(n => !ACTIONS[n].disc), ...Object.keys(POKES)]
        : spec === "disc" ? Object.keys(DISC) : spec.split(",");
    const acts = names.map(n => { const [nm, f] = n.split("*"); const a = ACTIONS[nm] || POKES[nm]; if (!a) throw new Error(`unknown chaos ${nm}`); return { nm, a, rate: (+f || 1) / a.every }; });
    let seq = null, seqLeft = 0, cur = [], step = null, excl = false, discDone = false;
    const done = {};
    const next = (ram, sy) => {
        if (!seq.length) { seq = null; cur = []; step = null; excl = false; return; }
        const e = seq.shift();
        if (Array.isArray(e)) { const [k, n] = e; cur = k === null ? [] : Array.isArray(k) ? k : [k]; seqLeft = n; step = null; }
        else { step = e; seqLeft = e.max; cur = e.keys || []; }
    };
    return {
        counts: done,
        exclusive() { return excl; },
        // once a frame (after the agent): maybe start an action
        frame(S) {
            rng = r;
            const ram = S.ref.ram, sy = S.rsy;
            if (flying(ram, sy)) discDone = false;
            if (seq) {
                if (step) {
                    if (step.until(ram, sy) || --seqLeft <= 0) { next(ram, sy); return; }
                    if (step.pulse !== undefined) cur = (step.max - seqLeft) % 12 < 3 ? [step.pulse] : [];
                    return;
                }
                if (--seqLeft > 0) return;
                next(ram, sy);
                return;
            }
            for (const { nm, a, rate } of acts) {
                if (a.disc && discDone) continue;
                if (r() >= rate || !a.when(ram, sy)) continue;
                if (a.disc) discDone = true;
                excl = !!a.exclusive;
                done[nm] = (done[nm] || 0) + 1;
                S.logInput({ chaos: nm, frame: S.frame, i: S.ref.iter });
                if (a.poke) {
                    const at = S.ref.iter + 3;
                    const pk = a.poke();
                    for (const m of [S.ref, S.cand]) { (m.pokes ||= new Map()).set(at, pk); }
                    S.logInput({ poke: at, v: pk });
                    return;
                }
                seq = (typeof a.keys === "function" ? a.keys() : a.keys).map(x => Array.isArray(x) ? [...x] : { ...x });
                next(ram, sy);
                return;
            }
        },
        keys() { return cur; },
    };
}
