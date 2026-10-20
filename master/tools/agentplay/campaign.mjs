#!/usr/bin/env node
// A campaign: many agentplay sessions with varied seeds and play styles, run a few at a
// time, then one table of what they covered and every finding, grouped.
//
// node master/tools/agentplay/campaign.mjs --out DIR [--jobs 3] [--plan default|quick]
//      [--only name,name] [--scale 1.0] [--summarise] [--workaround look1] [--cand disc --csyms syms]
// Each session runs as agentplay.mjs in DIR/<name>/; a session already finished there
// (summary.json) is not run again, so a campaign can be resumed. --scale multiplies every
// session's length. --summarise only rewrites the summary (DIR/campaign.json, DIR/campaign.md).
// Sessions in phase 2 start from discs a phase 1 session saved (--savediscs), and load
// the agent's commander from them.
import { spawn } from "child_process";
import { existsSync, readFileSync, writeFileSync, mkdirSync } from "fs";

const a = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => { if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]); return acc; }, []));
if (!a.out) { console.error("--out DIR required"); process.exit(2); }
const OUT = a.out, JOBS = +(a.jobs || 3), SCALE = +(a.scale || 1);
const HERE = decodeURIComponent(new URL(".", import.meta.url).pathname);
mkdirSync(OUT, { recursive: true });

// name, minutes, then agentplay options. W: a workaround only when asked for (--workaround
// look1 played on past the LOOK1 bug, fixed in be18285); off by default, so a regression
// shows rather than being masked
const W = a.workaround && a.workaround !== true ? ["--workaround", a.workaround] : [];
// night5 and night6: 20 generated sessions from seed base on, then 4 loads from their discs
function wave5(pre, base) {
    const cmdrs = ["deadly", "galaxy3", "equipped", "wanted", "mission2", "debrief1", "rich", "trader"];
    const modes = ["efficient", "curious", "keyboard", "fair"];
    const mixes = ["all,docked,disc", "missile*4,views*3,docked", "pod*3,ghyp*3,hurt*2,disc", "dock*4,charts*2,docked,disc", "missile*3,ecm*3,bomb*2,jump*2"];
    const out = [];
    for (let i = 0; i < 20; i++) {
        const seed = base + i;
        out.push([`${pre}-${cmdrs[i % 8]}-${modes[(i * 3) % 4]}-s${seed}`, 12 + (i % 2) * 4, "--seed", String(seed), "--commander", cmdrs[i % 8], "--mode", modes[(i * 3) % 4], "--chaos", mixes[i % 5], ...(i % 5 === 2 ? ["--savediscs"] : [])]);
    }
    for (let i = 0; i < 4; i++) out.push([`${pre}-load-s${base + 20 + i}`, 12, "--seed", String(base + 20 + i), "--mode", "load", "--from", out[i * 5 + 2][0], "--chaos", mixes[(i + 1) % 5]]);
    return out;
}
const PLANS = {
    default: [
        // elite-agent's own modes, from Jameson
        ["eff-s1", 20, "--seed", "1", "--savediscs", ...W],
        ["eff-s2", 15, "--seed", "2", ...W],
        ["curious-s3", 20, "--seed", "3", "--mode", "curious", ...W],
        ["fair-s4", 15, "--seed", "4", "--mode", "fair", ...W],
        ["keyboard-s5", 15, "--seed", "5", "--mode", "keyboard", ...W],
        ["nosave-s6", 12, "--seed", "6", "--mode", "nosave", ...W],
        // other commanders
        ["trader-s7", 15, "--seed", "7", "--commander", "trader", ...W],
        ["rich-s8", 15, "--seed", "8", "--commander", "rich", "--mode", "curious", ...W],
        ["deadly-s9", 20, "--seed", "9", "--commander", "deadly", "--savediscs", ...W],
        ["mission2-s10", 20, "--seed", "10", "--commander", "mission2", ...W],
        ["wanted-s11", 12, "--seed", "11", "--commander", "wanted", ...W],
        // the chaos overlay: what the agent rarely does
        ["chaos-all-s12", 12, "--seed", "12", "--commander", "equipped", "--chaos", "all", ...W],
        ["chaos-all-s13", 12, "--seed", "13", "--commander", "equipped", "--chaos", "all", "--mode", "keyboard", ...W],
        ["chaos-gear-s14", 12, "--seed", "14", "--commander", "equipped", "--chaos", "ghyp*4,pod*4,bomb*3,ecm*3,missile*2,unarm", ...W],
        ["chaos-gear-s15", 12, "--seed", "15", "--commander", "deadly", "--chaos", "ghyp*4,pod*4,bomb*3,ecm*3,hyper*2", ...W],
        ["chaos-death-s16", 12, "--seed", "16", "--commander", "equipped", "--chaos", "hurt*4,heat*2,fuel*2", ...W],
        ["chaos-death-s17", 12, "--seed", "17", "--chaos", "hurt*4,spin*2,jump", "--mode", "nosave", ...W],
        ["chaos-views-s18", 10, "--seed", "18", "--commander", "equipped", "--chaos", "views*3,charts*3,dock*3", ...W],
        // without the workaround: how soon the LOOK1 bug ends a session by itself
        ["nowork-s19", 10, "--seed", "19", "--mode", "curious"],
        ["nowork-s20", 10, "--seed", "20", "--commander", "equipped", "--chaos", "views"],
        // phase 2: from phase 1's discs, loading the saved commander
        ["load-s21", 12, "--seed", "21", "--mode", "load", "--from", "eff-s1", ...W],
        ["load-s22", 12, "--seed", "22", "--mode", "load,curious", "--from", "deadly-s9", "--chaos", "views,ecm,bomb", ...W],
    ],
    // a second round: the missions' later stages, more deaths, pods and galactic jumps, a long career
    extra: [
        ["galaxy3-s40", 30, "--seed", "40", "--commander", "galaxy3", "--savediscs", ...W],
        ["galaxy3-s41", 20, "--seed", "41", "--commander", "galaxy3", "--mode", "curious", ...W],
        ["debrief1-s42", 12, "--seed", "42", "--commander", "debrief1", ...W],
        ["deadly-s43", 20, "--seed", "43", "--commander", "deadly", "--mode", "curious", ...W],
        ["long-s44", 40, "--seed", "44", "--savediscs", ...W],
        ["death-s45", 15, "--seed", "45", "--commander", "equipped", "--chaos", "hurt*8,heat*4", ...W],
        ["death-s46", 15, "--seed", "46", "--chaos", "hurt*8,spin*3", "--mode", "keyboard", ...W],
        ["pods-s47", 15, "--seed", "47", "--commander", "deadly", "--chaos", "pod*8,ghyp*6,bomb*2", ...W],
        ["fairchaos-s48", 15, "--seed", "48", "--commander", "equipped", "--mode", "fair", "--chaos", "all", ...W],
        ["wanted-s49", 15, "--seed", "49", "--commander", "wanted", "--chaos", "ecm*2,missile*2", ...W],
        ["load-s50", 15, "--seed", "50", "--mode", "load", "--from", "galaxy3-s40", "--chaos", "views,ecm", ...W],
        ["load-s51", 15, "--seed", "51", "--mode", "load,curious", "--from", "long-s44", ...W],
    ],
    // 2026-10-20: aimed at the blueprints-in-HAZEL relayout (the disc menu through DOSCLI's
    // HAZEL stash, NWSPS/NWSHP and the station's blueprint, the hangar, launch after a
    // save or load, the docking computer, views, pods, galactic jumps, missions)
    night: [
        ["disc-s60", 15, "--seed", "60", "--chaos", "disc", "--savediscs"],
        ["disc-s61", 15, "--seed", "61", "--commander", "equipped", "--chaos", "disc,dock*2,views", "--savediscs"],
        ["disc-s62", 15, "--seed", "62", "--commander", "trader", "--chaos", "dsave*3,ddel*2,dcat,dnoload,dnodel", "--mode", "curious"],
        ["disc-s63", 12, "--seed", "63", "--commander", "deadly", "--chaos", "disc,pod*4,ghyp*3"],
        ["disc-s64", 12, "--seed", "64", "--chaos", "dcat1,dbad,dexit,ddefault", "--mode", "keyboard"],
        ["dock-s65", 15, "--seed", "65", "--commander", "equipped", "--chaos", "dock*6,views*2"],
        ["dock-s66", 15, "--seed", "66", "--commander", "deadly", "--chaos", "dock*6,jump*2,charts", "--mode", "fair"],
        ["views-s67", 12, "--seed", "67", "--commander", "equipped", "--chaos", "views*6,missile,ecm", "--mode", "curious"],
        ["pods-s68", 15, "--seed", "68", "--commander", "equipped", "--chaos", "pod*10,ghyp*8,hurt*2"],
        ["galaxy3-s69", 20, "--seed", "69", "--commander", "galaxy3", "--chaos", "disc,views"],
        ["debrief2-s70", 15, "--seed", "70", "--commander", "debrief2", "--chaos", "dock*2"],
        ["debrief1-s71", 12, "--seed", "71", "--commander", "debrief1", "--chaos", "disc"],
        ["nomission-s72", 15, "--seed", "72", "--commander", "deadly", "--mode", "nomission", "--chaos", "all"],
        ["death-s73", 15, "--seed", "73", "--commander", "equipped", "--chaos", "hurt*8,heat*3,disc", "--savediscs"],
        ["load-s74", 15, "--seed", "74", "--mode", "load", "--from", "disc-s60", "--chaos", "dcat,views,dock"],
        ["load-s75", 15, "--seed", "75", "--mode", "load,curious", "--from", "disc-s61", "--chaos", "pod*3,ghyp*2"],
        ["load-s76", 12, "--seed", "76", "--mode", "load", "--from", "death-s73", "--chaos", "disc"],
    ],
    // the second wave: the docked screens with the disc menu, more seeds and commanders
    night2: [
        ["docked-s80", 15, "--seed", "80", "--chaos", "docked,disc", "--savediscs"],
        ["docked-s81", 15, "--seed", "81", "--commander", "rich", "--chaos", "docked,disc", "--mode", "curious"],
        ["docked-s82", 15, "--seed", "82", "--commander", "trader", "--chaos", "docked,disc", "--mode", "keyboard"],
        ["docked-s83", 15, "--seed", "83", "--commander", "equipped", "--chaos", "docked,views,dock*3", "--mode", "fair"],
        ["docked-s84", 15, "--seed", "84", "--commander", "wanted", "--chaos", "docked,disc,ecm,missile"],
        ["mission-s85", 20, "--seed", "85", "--commander", "mission2", "--chaos", "docked,disc,views"],
        ["mission-s86", 20, "--seed", "86", "--commander", "galaxy3", "--chaos", "docked,dock*3,pod*2", "--savediscs"],
        ["debrief2-s87", 15, "--seed", "87", "--commander", "debrief2", "--chaos", "docked,disc"],
        ["allchaos-s88", 20, "--seed", "88", "--commander", "deadly", "--chaos", "all,docked,disc", "--savediscs"],
        ["allchaos-s89", 20, "--seed", "89", "--commander", "equipped", "--chaos", "all,docked,disc", "--mode", "keyboard"],
        ["long-s90", 40, "--seed", "90", "--chaos", "docked,disc", "--savediscs"],
        ["nomission-s91", 15, "--seed", "91", "--commander", "mission2", "--mode", "nomission", "--chaos", "ghyp*6,hyper*3,docked"],
        ["load-s92", 15, "--seed", "92", "--mode", "load", "--from", "docked-s80", "--chaos", "docked,disc"],
        ["load-s93", 15, "--seed", "93", "--mode", "load,curious", "--from", "mission-s86", "--chaos", "views,docked"],
        ["load-s94", 20, "--seed", "94", "--mode", "load", "--from", "allchaos-s88", "--chaos", "all,docked,disc"],
        ["load-s95", 20, "--seed", "95", "--mode", "load", "--from", "long-s90", "--chaos", "docked,disc,pod*2"],
    ],
    // the third wave: generated, seeds 100-131 over every commander, mode and chaos mix
    night3: (() => {
        const cmdrs = ["jameson", "trader", "equipped", "rich", "deadly", "mission2", "wanted", "galaxy3", "debrief1", "debrief2"];
        const modes = ["efficient", "curious", "fair", "keyboard", "efficient", "nomission"];
        const mixes = ["docked,disc", "all,docked,disc", "views*3,dock*3,docked", "pod*4,ghyp*4,hurt*2,disc", "ecm*3,missile*3,bomb*2,docked", "hurt*6,heat*2,fuel*2,docked,disc", "jump*3,charts*3,spin*2,docked", "all"];
        const out = [];
        for (let i = 0; i < 32; i++) {
            const seed = 100 + i, c = cmdrs[i % cmdrs.length], m = modes[(i * 7) % modes.length], x = mixes[(i * 3) % mixes.length];
            out.push([`n3-${c}-${m}-s${seed}`, 12 + (i % 3) * 4, "--seed", String(seed), "--commander", c, "--mode", m, "--chaos", x, ...(i % 4 === 0 ? ["--savediscs"] : [])]);
        }
        for (let i = 0; i < 8; i++) out.push([`n3-load-s${140 + i}`, 15, "--seed", String(140 + i), "--mode", i % 2 ? "load,curious" : "load", "--from", out[i * 4][0], "--chaos", mixes[(i * 5) % mixes.length]]);
        return out;
    })(),
    // the fourth wave: seeds 200-239, missiles and fights (MSBAR's path) with the docked
    // screens and the disc menu, every commander and mode
    night4: (() => {
        const cmdrs = ["equipped", "deadly", "wanted", "mission2", "galaxy3", "trader", "jameson", "rich", "debrief1", "debrief2"];
        const modes = ["curious", "efficient", "keyboard", "fair", "nomission"];
        const mixes = ["missile*4,unarm*2,ecm*2,docked,disc", "all,docked,disc", "missile*3,views*3,hurt*2", "missile*3,bomb*2,pod*2,ghyp*2,docked", "views*4,charts*2,dock*2,disc", "missile*4,jump*3,spin*2,docked"];
        const out = [];
        for (let i = 0; i < 32; i++) {
            const seed = 200 + i, c = cmdrs[(i * 3) % cmdrs.length], m = modes[i % modes.length], x = mixes[(i * 5) % mixes.length];
            out.push([`n4-${c}-${m}-s${seed}`, 12 + (i % 4) * 3, "--seed", String(seed), "--commander", c, "--mode", m, "--chaos", x, ...(i % 4 === 1 ? ["--savediscs"] : [])]);
        }
        for (let i = 0; i < 8; i++) out.push([`n4-load-s${240 + i}`, 15, "--seed", String(240 + i), "--mode", i % 2 ? "load,curious" : "load", "--from", out[i * 4 + 1][0], "--chaos", mixes[(i * 7) % mixes.length]]);
        return out;
    })(),
    // the fifth wave: seeds 300-323, as night4 with other pairings
    night5: wave5("n5", 300),
    // the sixth wave: as night5, seeds 400-423
    night6: wave5("n6", 400),
    quick: [
        ["q-eff", 2, "--seed", "1", "--savediscs", ...W],
        ["q-chaos", 2, "--seed", "2", "--commander", "equipped", "--chaos", "all", ...W],
        ["q-load", 2, "--seed", "3", "--mode", "load", "--from", "q-eff", ...W],
    ],
};
// The candidate is copied into DIR/cand-build/ when the campaign first starts (disc,
// symbols.txt, banks.txt), and every session runs that copy: a rebuild of master/build
// while a campaign runs would otherwise give later sessions another build, or a disc and
// symbols from different builds (phase 2 loads a phase 1 disc, whose game is that copy).
// --cand DISC --csyms SYMS choose another build to copy.
import { copyFileSync } from "fs";
const CB = `${OUT}/cand-build`;
if (!existsSync(`${CB}/symbols.txt`)) {
    mkdirSync(CB, { recursive: true });
    const ROOTD = decodeURIComponent(new URL("../../..", import.meta.url).pathname);
    const disc = a.cand || `${ROOTD}master/build/elite-master-sng47.ssd`, syms = a.csyms || `${ROOTD}master/build/symbols.txt`;
    copyFileSync(disc, `${CB}/elite-master-sng47.ssd`);
    copyFileSync(syms, `${CB}/symbols.txt`);
    const banks = syms.replace(/symbols\.txt$/, "banks.txt");
    if (existsSync(banks)) copyFileSync(banks, `${CB}/banks.txt`);
}
const plan = PLANS[a.plan || "default"].filter(([n]) => !a.only || a.only.split(",").includes(n));

function runOne([name, minutes, ...opts]) {
    const dir = `${OUT}/${name}`;
    if (existsSync(`${dir}/summary.json`)) { console.log(`${name}: done already`); return Promise.resolve(); }
    const args = [`${HERE}agentplay.mjs`, "--out", dir, "--minutes", String(+(minutes * SCALE).toFixed(2))];
    for (let i = 0; i < opts.length; i++) {
        if (opts[i] === "--from") { const f = `${OUT}/${opts[++i]}`; args.push("--ref", `${f}/ref-disc.ssd`, "--cand", `${f}/cand-disc.ssd`); }
        else args.push(opts[i]);
    }
    if (!args.includes("--cand")) args.push("--cand", `${CB}/elite-master-sng47.ssd`);
    args.push("--csyms", `${CB}/symbols.txt`);
    mkdirSync(dir, { recursive: true });
    console.log(`${name}: start (${args.slice(1).join(" ")})`);
    return new Promise(res => {
        const p = spawn(process.execPath, args, { stdio: ["ignore", "pipe", "pipe"] });
        let log = "";
        p.stdout.on("data", d => { log += d; });
        p.stderr.on("data", d => { log += d; });
        p.on("exit", code => {
            writeFileSync(`${dir}/run.log`, log);
            const last = log.split("\n").filter(l => /^AGENTPLAY/.test(l)).pop() || `exit ${code}`;
            console.log(`${name}: ${last}`);
            res();
        });
    });
}

if (!a.summarise) {
    const phase1 = plan.filter(p => !p.includes("--from")), phase2 = plan.filter(p => p.includes("--from"));
    for (const phase of [phase1, phase2]) {
        const queue = [...phase];
        await Promise.all(Array.from({ length: Math.max(1, JOBS) }, async () => { while (queue.length) await runOne(queue.shift()); }));
    }
}

// ---- the summary
const rows = [], groups = new Map();
const cover = {}, reached = new Set(), codeLabels = new Set();
for (const [name] of plan) {
    const cf = `${OUT}/${name}/coverage-ref.json`;
    if (existsSync(cf)) { const c = JSON.parse(readFileSync(cf, "utf8")); for (const k of c.reached) { reached.add(k); codeLabels.add(k); } for (const k of c.unreached) codeLabels.add(k); }
    const f = `${OUT}/${name}/summary.json`;
    if (!existsSync(f)) { rows.push({ name, status: "not run" }); continue; }
    const s = JSON.parse(readFileSync(f, "utf8"));
    const cfg = existsSync(`${OUT}/${name}/config.json`) ? JSON.parse(readFileSync(`${OUT}/${name}/config.json`, "utf8")) : {};
    const ev = {};
    for (const [k, v] of Object.entries(s.events || {})) { const m = /^ref:routine:(.*)$/.exec(k); if (m) { ev[m[1]] = v; cover[m[1]] = (cover[m[1]] || 0) + v; } }
    const real = s.findings.filter(f => f.kind !== "observable" && f.kind !== "hang-both");
    rows.push({ name, status: real.length ? "FINDINGS" : "clean", minutes: s.gameMinutes, iters: s.compared, flight: s.flight, reads: s.reads,
        commander: cfg.commander, mode: cfg.mode || modeOf(cfg.agentEnv || {}), chaos: cfg.chaos || "", workaround: (cfg.workarounds || []).join(","),
        workaroundHits: s.workaroundHits, divergence: s.divergence ? s.divergence.iter : null, findings: s.findings.length, events: ev, notes: s.agentNotes,
        observables: s.observables && { checked: s.observables.checked, differing: s.observables.differing }, saves: s.saveFilesSame, final: s.final });
    for (const f of s.findings) {
        const key = fingerprint(f);
        if (!groups.has(key)) groups.set(key, { key, kind: f.kind, sessions: [], first: { session: name, ...f } });
        const g = groups.get(key);
        if (!g.sessions.includes(name)) g.sessions.push(name);
    }
    for (const [k, v] of Object.entries(s.observables?.kinds || {})) {
        const key = `observable: ${k}`;
        if (!groups.has(key)) groups.set(key, { key, kind: "observable", sessions: [], iterations: 0, first: { session: name, iter: v.first, example: v.example } });
        const g = groups.get(key);
        if (!g.sessions.includes(name)) g.sessions.push(name);
        g.iterations += v.n;
    }
}
function modeOf(env) {
    const names = { CURIOUS: "curious", FAIR: "fair", JOYSTICK: "keyboard", SAVE: "nosave", NOMISSION: "nomission", LOAD: "load" };
    return Object.keys(env).map(k => names[k] || k).join(",") || "efficient";
}
function fingerprint(f) {
    if (f.kind === "observable") return null;
    if (f.kind === "divergence") return `divergence: ${(f.text.split(": ").slice(1).join(": ")).replace(/\d+/g, "#")}`;
    if (f.kind === "control-flow") return `control-flow: ${f.text.replace(/read \d+ \(iteration \d+\)/, "").replace(/\(iteration \d+\)/g, "").trim()}`;
    return `${f.kind}: ${f.text.replace(/iteration \d+/g, "iteration #").replace(/&[0-9a-f]+/g, m => m)}`;
}
groups.delete(null);
const tot = rows.reduce((t, r) => ({ minutes: t.minutes + (r.minutes || 0), iters: t.iters + (r.iters || 0), flight: t.flight + (r.flight || 0) }), { minutes: 0, iters: 0, flight: 0 });
writeFileSync(`${OUT}/campaign.json`, JSON.stringify({ rows, coverage: cover, totals: tot, groups: [...groups.values()] }, null, 1));
const md = [];
md.push(`# agentplay campaign: ${OUT}`, "", `${rows.length} sessions, ${tot.minutes.toFixed(1)} game minutes, ${tot.iters} iterations compared (${tot.flight} in flight).`, "");
md.push("| session | commander | mode | chaos | min | iterations | status | first divergence | findings | LOOK1 workaround hits |", "|---|---|---|---|---|---|---|---|---|---|");
for (const r of rows) md.push(`| ${r.name} | ${r.commander || ""} | ${r.mode || ""} | ${r.chaos || ""} | ${r.minutes ?? ""} | ${r.iters ?? ""} | ${r.status} | ${r.divergence ?? ""} | ${r.findings ?? ""} | ${r.workaround ? r.workaroundHits : "off"} |`);
md.push("", "Coverage (reference machine, routine entries over all sessions):", "", Object.entries(cover).sort((x, y) => y[1] - x[1]).map(([k, v]) => `${k} ${v}`).join(", "), "");
if (codeLabels.size) {
    const un = [...codeLabels].filter(k => !reached.has(k));
    md.push(`Whole-code coverage (reference machine): ${reached.size} labels with code run; ${un.length} code labels (run in a session, or a JSR/JMP target) never run:`, "", un.join(" "), "");
}
md.push("Findings, grouped:", "");
for (const g of groups.values()) md.push(`- **${g.key}** in ${g.sessions.length} session(s) (${g.sessions.join(", ")})${g.iterations ? `, ${g.iterations} iterations` : ""}; first: ${g.first.session} ${g.first.iter !== undefined ? "iteration " + g.first.iter : ""} ${g.first.text || JSON.stringify(g.first.example || "")}`.slice(0, 1200));
writeFileSync(`${OUT}/campaign.md`, md.join("\n") + "\n");
console.log(md.join("\n"));
