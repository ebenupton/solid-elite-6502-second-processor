// The split probe over an agentplay session: elite-agent plays the original, the port
// replays its inputs (master/tools/agentplay), and the probe watches the port (the
// candidate) only. Takes agentplay.mjs's options, or --replay DIR to replay a session's
// input log instead of playing.
//
// node master/tools/irqprobe/play.mjs --out DIR [agentplay options ...] [--replay DIR]
// Writes DIR/irqprobe.json (the summary) besides the session's own files.
import { writeFileSync, readFileSync } from "fs";
import { Session } from "../agentplay/session.mjs";
import { MODES } from "../agentplay/styles.mjs";
import { attachProbe, summarise, marksFor } from "./probe.mjs";

const a = Object.fromEntries(process.argv.slice(2).reduce((acc, v, i, arr) => { if (v.startsWith("--")) acc.push([v.slice(2), arr[i + 1] && !arr[i + 1].startsWith("--") ? arr[i + 1] : true]); return acc; }, []));
if (!a.out) { console.error("--out DIR required"); process.exit(2); }
let cfg;
if (a.replay) {
    const log = `${a.replay}/inputs.jsonl`, h = JSON.parse(readFileSync(log, "utf8").split("\n")[0]);
    cfg = { out: a.out, replay: log, seed: h.seed, commander: h.commander, startFrame: h.startFrame, strict: h.strict, ref: h.ref, rsyms: h.rsyms,
        cand: a.cand || h.cand, csyms: a.csyms || h.csyms, workarounds: h.workarounds || [], keepGoing: 1e9, observe: false };
} else {
    const env = {};
    for (const m of String(a.mode || "efficient").split(",")) Object.assign(env, MODES[m]);
    cfg = { out: a.out, minutes: +(a.minutes || 10), seed: a.seed !== undefined ? +a.seed : undefined, commander: a.commander || "jameson",
        agentEnv: env, mode: String(a.mode || "efficient"), chaos: a.chaos || null, startFrame: +(a.start || 700), keepGoing: 1e9,
        workarounds: a.workaround ? String(a.workaround).split(",") : [], observe: false, iters: a.iters ? +a.iters : undefined };
    for (const k of ["ref", "rsyms", "cand", "csyms"]) if (a[k]) cfg[k] = a[k];
}
const t0 = Date.now();
const S = new Session(cfg);
await S.start();
const c = S.cand, sy = c.sy, ram = c.cpu.ramRomOs;
c.s._video.frameSkipCount = 0;          // (agentplay renders one frame in 25: the probe needs every fetch)
const probe = attachProbe(c.cpu, sy, { marks: marksFor(sy), tagFn: () => { const q = ram[sy.QQ11]; return q === 0 ? "space" : "qq" + q.toString(16); } });
let s;
try { s = await S.run(); } catch (e) { console.error(e.stack || e); }
const sum = summarise(probe, `agentplay ${a.out}`);
sum.session = s ? { compared: s.compared, flight: s.flight, findings: (s.findings || []).map(f => f.kind), events: s.events } : null;
sum.wallSecs = (Date.now() - t0) / 1000;
writeFileSync(`${a.out}/irqprobe.json`, JSON.stringify(sum, null, 1));
console.log(`irqprobe play ${a.out}: T1 buffer0 ${JSON.stringify({ ...sum.t1.buffer0, hist: undefined })}; late ${sum.split.buffer0Late}; frames ${sum.frames.total} (buffer 0 ${sum.frames.buffer0}), copy shown ${sum.frames.copyShown.frames}; oscli ${sum.oscli.n} (gmode set ${sum.oscli.gmodeSet}, D=0 ${sum.oscli.D0})`);
process.exit(0);
