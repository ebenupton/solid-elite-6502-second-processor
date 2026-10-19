#!/usr/bin/env node
// One agentplay session: elite-agent plays the original Master Elite (SNG47) while our
// port replays its inputs read for read; game state compared every iteration.
//
// node master/tools/agentplay/agentplay.mjs --out DIR [--minutes 10] [--seed N]
//      [--commander jameson|trader|equipped|rich|deadly|mission2|debrief1|galaxy3|wanted]
//      [--mode efficient,curious,fair,keyboard,nosave,nomission,load]
//      [--chaos all|ecm,bomb,...] [--start FRAMES] [--shots N] [--keepgoing N] [--strict] [--noobserve]
//      [--workaround look1] (candidate-side runtime workaround for a known port bug, to play on past it)
//      [--savediscs] (write both machines' discs, with their saves, at the end: ref-disc.ssd, cand-disc.ssd)
//      [--ref disc --rsyms syms] [--cand disc --csyms syms] [--iters N]
// Writes DIR/{config.json, inputs.jsonl, agent.log, journal.jsonl, events.jsonl, summary.json, *.png}.
// Exit status: 0 no findings, 1 a finding (divergence, crash, hang, BRK, page &0D), 2 error.
import { Session } from "./session.mjs";
import { MODES } from "./styles.mjs";

const a = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => { if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]); return acc; }, []));
if (!a.out) { console.error("--out DIR required"); process.exit(2); }
const env = {};
for (const m of String(a.mode || "efficient").split(",")) { if (!MODES[m]) { console.error(`unknown mode ${m}`); process.exit(2); } Object.assign(env, MODES[m]); }
const cfg = {
    out: a.out, minutes: +(a.minutes || 10), seed: a.seed !== undefined ? +a.seed : undefined, commander: a.commander || "jameson",
    agentEnv: env, mode: String(a.mode || "efficient"), chaos: a.chaos || null, startFrame: +(a.start || 700), shots: +(a.shots || 0), keepGoing: +(a.keepgoing || 0),
    strict: !!a.strict, saveDiscs: !!a.savediscs, workarounds: a.workaround ? String(a.workaround).split(",") : [], observe: !a.noobserve, iters: a.iters ? +a.iters : undefined,
};
for (const k of ["ref", "rsyms", "cand", "csyms"]) if (a[k]) cfg[k] = a[k];
try {
    const S = new Session(cfg);
    await S.start();
    const s = await S.run();
    const bad = s.findings.filter(f => f.kind !== "observable");
    console.log(`AGENTPLAY ${bad.length ? "FINDINGS" : "CLEAN"} ${cfg.out}: ${s.gameMinutes} game min, ${s.compared} iterations compared (${s.flight} in flight), ${s.reads} reads (${s.keyReads} with keys), findings ${s.findings.length}` +
        `${s.divergence ? `, first divergence at iteration ${s.divergence.iter}` : ""}; final ${JSON.stringify(s.final)}`);
    console.log(`events ${JSON.stringify(s.events)} agent ${JSON.stringify(s.agentNotes)}`);
    process.exit(bad.length ? 1 : 0);
} catch (e) { console.error(e.stack || e); process.exit(2); }
