# agentplay: elite-agent plays the original and the port side by side

19 October 2026. This report covers:

- **The port tested:** branch full-master at 4737aab. Its build is byte-identical to the
  released `elite-master-full-latest.ssd`.
- **The original:** Acornsoft's BBC Master Elite (SNG47), `master/reference/elite-master-sng47.ssd`.
- **The player:** [elite-agent](https://github.com/8bitkick/elite-agent) at 261bfb5.
- **The tooling:** `master/tools/agentplay/`, on branch agent-play.

## Summary

elite-agent played the original wireframe Master Elite in 34 campaign sessions. While it
did, our filled port replayed every keyboard and joystick read in step. The campaigns ran
**530 game minutes** in all:

- **440,799 main-loop iterations compared** (419,448 of them in flight);
- **709,927 input reads replayed**;
- **401,657 dashboard comparisons**;
- **143 save-file comparisons**.

The game state never diverged except where a port bug made it. In every session the port's
game logic matched the original byte for byte, through all of these:

- trading, buying equipment, and saving and loading to disc;
- hyperspace, galactic hyperspace, mis-jumps into witchspace, and Thargoids;
- fights, missiles, E.C.M. and the energy bomb;
- the escape pod, death and restart;
- the Constrictor and Thargoid plans missions' briefings and debriefing.

Two port bugs were found.

| # | Finding | Severity | Repro |
|---|---|---|---|
| 1 | **LOOK1 falls through into DEATH.** Any change of space view in flight kills the commander. | Critical | `node master/tools/agentplay/replay.mjs --log master/tools/agentplay/repro/look1-death.jsonl --out scratch/agentplay/r1` |
| 2 | **A stray compass dot.** The port's DOT draws a dot when COMC = 0, where the original draws nothing. A green dot is left at the top-left of the compass ring for the whole game, and the real compass dot vanishes when it meets it. | Minor (cosmetic) | `node master/tools/agentplay/replay.mjs --log master/tools/agentplay/repro/compass-stray-dot.jsonl --out scratch/agentplay/r2` |

Both bugs have since been fixed: LOOK1 in be18285, the compass dot in 268fe8a. A second campaign, on 20 October against the blueprints-in-HAZEL relayout, found and fixed two more bugs (section 6).

The campaigns could reach past finding 1 because of a harness-side workaround,
`--workaround look1`. The port's source is untouched. With the workaround on, the sessions
changed view 234 times, and each of those would have been a death in the port.

Everything else the comparisons flagged was triaged as one of two things:

- **Harness artefacts.** Each was fixed in the tool (see "Harness artefacts found and fixed").
- **Expected differences.** Overlapping scanner dots mix differently under EOR in mode 1
  and mode 2 (see "Expected differences").

## 1. What elite-agent is

elite-agent is a rule-based player for BBC Master Elite, written in pure C by 8bitkick.

- It has no model, network or heap: about 100 KB of code.
- It was written for Mark Moxon's flicker-free SNG47 build.
- It runs on an RP2350 microcontroller (a Pimoroni Presto) beside a BBC Master emulator,
  and natively on a Mac or Pi for development.
- It reaches the Elite rank in about 27 game hours.

Its interface (`cplayer/player.h`) is one call a frame:

- **In:** read-only access to the Master's 32 KB of main RAM.
- **Out:** held keys and taps on the BBC keyboard matrix, and values on the analogue port.

It never reads the screen and never writes RAM.

The player runs a whole career:

- launch, trading and equipment;
- bounty hunting, and Thargoid farming by forced mis-jumps into witchspace;
- both missions, saving at every dock, and reloading after a death.

It flies with the analogue stick and aims a few loops ahead with a planner that simulates
Elite's rotation maths. It has three modes:

- **efficient** goes straight for Elite;
- **fair** limits itself to what the screen would show, but computes that from RAM;
- **curious** explores and stages fights for the camera, including watching flybys from
  the side views.

Its own development build drives a different emulator, the kc-beeb Master core from the
rp2350-bbc-micro submodule. agentplay uses neither that emulator nor its run_sim driver.
It compiles only `cplayer/*.c` into `agentd`, a subprocess that talks over a pipe (see the
next section).

The agent reads 64 RAM locations by name (`cplayer/elite_ram.h`), and eleven more as
literals. Every one of them is at the same address in the SNG47 disc as in the flicker-free
build it was written for, which was checked against both symbol tables. So the agent plays
the original unmodified.

The agent never sees the port. It decides from the original's RAM only. So the agent's
choices are the same in both machines, and any divergence is the port's.

On reading the port's display: elite-agent has no screen reading to try on the port's
display, because it never reads the screen. Its fair mode limits itself to what the
dashboard would show, but it works that out from RAM. The agentplay observables do that
job instead (section 2).

## 2. How the harness works

```
          RAM, each frame                  read n: keys/stick, routine
 agentd  <---------------  reference (SNG47)  ------------------------->  candidate (port)
 (elite-agent) --------->  answers each read   queue of reads             replays read n,
          keys, stick                          (blocks until made)       blocks if ahead
                                 |  MLOOP snapshot                            |  MLOOP snapshot
                                 +------------------->  compare  <------------+
                                                     state, dashboards, discs
```

**Machines.** Both run on jsbeeb, headless, in one node process (`lib.mjs`). Each boots its
disc with SHIFT+BREAK.

**Inputs at the read.** The emulated keyboard is never pressed. The input model is
`harness/mlib.mjs`'s, the same as the existing gate's. Every point where the game reads an
input is a numbered read:

- RDKEY+5, where the key logger, KL and X are written as FILLKL would;
- DKS5+17, one key;
- DK15's two `LDA JOPOS`, the joystick. JOPOS is written immediately before each runs, so
  the IRQ's own ADC writes can't get in between.

The reference runs one 50 Hz frame at a time. Before each frame, agentd gets its main RAM
and answers with key changes and stick values, after elite-agent's own two-frame key
latency. The reference answers each read from those, and queues the answer with the routine
that made the read, for example `DOKEY` or `t2<TT223`. It also queues the joystick bytes.

The candidate runs as far as the queue allows. At a read the reference hasn't made yet, it
stops on that instruction until it has. So the port gets the same keys at the same read,
whatever its speed. Its speed differs from the original's, by design.

mlib's other determinism measures are kept:

- SOPR is cleared at NOISE;
- Q is cleared before ALTIT's square root;
- the candidate's boot leftovers are seeded from the reference at TT170.

**Commanders** are patched into NA% at QU5, before DFAULT copies NA% into the commander.
The original's checksum CHK and CHK2 are recomputed, because the original's DFAULT loops for
ever on a bad checksum.

**What is compared:**

- **Game state, at every MLOOP.** The regions are mlib's:
  - zero page;
  - the K% slots;
  - WP: FRIN, the flight variables, the commander (cash, cargo, fuel, missiles, equipment,
    legal status, galaxy and system and their seeds), JOPOS;
  - UP: the configuration;
  - NA%;
  - the sound buffers.

  The exclusions are the gate's `--loose` ones. The first divergent iteration is reported
  field by field, for example `K% slot 3 z_hi` or `QQ14`.
- **Control flow.** Every read's kind and calling routine, and DKS5's key, must match.
- **Observables** (`observe.mjs`). The dashboards are read back out of shadow RAM, at every
  MLOOP in flight:
  - every bar's length (the original's 16 steps against the port's 32) and colour class;
  - the roll and pitch markers;
  - the missile indicators;
  - the E.C.M. and station bulbs;
  - every scanner and compass dot. This is the screen XORed with the dashboard image as the
    loader left it at S%, matched within 3 units and a line.

  Pixels are never compared.
- **Save files.** Once both machines are past the MLOOP after a disc access, the commander
  files in directory E on the two discs must match, catalogue and bytes.
- **Health:**
  - BRKs into the game's NEWBRK, by bank. DFS errors are expected; anything else is a
    finding.
  - Writes to page &0D by the port's code.
  - Hangs: no read and no iteration for 30 emulated seconds.
  - A PC in page 0 or 1.

**Variety:**

- **`--seed`** sets RAND at TT170 and seeds the chaos overlay.
- **`--commander`** starts from a patched commander:
  - `jameson`, `trader`, `equipped`, `rich` and `wanted`;
  - `deadly`, which gets mission 1;
  - `mission2`;
  - `debrief1`, the Constrictor destroyed;
  - `galaxy3`, Ceerdi with mission 1 done;
  - `debrief2`, Birera with the plans aboard.
- **`--mode`** chooses elite-agent's mode: efficient, curious, fair, keyboard (keys rather
  than the stick), nosave, or load, which loads CLAUDE from discs a previous session saved.
- **`--chaos`** is a seeded overlay of extra keys and pokes, for things the agent rarely
  does. Every chaos action goes into the input log.
  - Keys: E.C.M., the energy bomb, the escape pod, the views, missiles, the galactic
    hyperdrive, hyperspace, in-system jumps, the docking computer and the charts.
  - Pokes: drained shields and energy, cabin heat, an empty tank. They are applied at an
    iteration boundary in both machines.

**Reports and repros.** Each session writes:

- `inputs.jsonl`: every read that had a key down, every stick change, every chaos action and
  poke, and an end record;
- the agent's log and journal;
- `events.jsonl`;
- `summary.json`;
- screenshots of both machines, a few frames after a finding and at the end.

`replay.mjs` plays an input log back into both machines from boot, without the agent, and
gets the same session read for read. These options help:

| Option | What it does |
|---|---|
| `--until` | stop after a given iteration |
| `--trace A,B` | write each machine's routine entries to diff |
| `--cand` | try a fixed build against the same inputs |
| `--cut ITER --save FILE` | write a log cut short after the divergence |

`campaign.mjs` runs a plan of sessions a few at a time, and groups the findings.

**Speed.** On an idle machine, a session runs both Masters and the agent at about 1 to 1.5
times real time. Under the grind loop's load it fell to about 0.25 times. The harness tests
its hooks inline and skips video rendering on 24 frames in 25, which cut about 40% of the
CPU time.

## 3. The campaign

Two plans were run in `scratch/agentplay/campaign1` and `campaign2`. The 34 sessions ran 10
to 40 game minutes each.

| Session | Commander | Mode | Chaos | Game min | Iterations | Result |
|---|---|---|---|---|---|---|
| eff-s1 | jameson | efficient |  | 20.2 | 16,814 | clean (saved discs for load-s21) |
| eff-s2 | jameson | efficient |  | 15.2 | 12,800 | clean |
| curious-s3 | jameson | curious |  | 20.2 | 17,507 | clean |
| fair-s4 | jameson | fair |  | 15.2 | 12,476 | clean |
| keyboard-s5 | jameson | keyboard |  | 15.2 | 12,455 | clean |
| nosave-s6 | jameson | nosave |  | 12.2 | 9,841 | clean |
| trader-s7 | trader | efficient |  | 15.2 | 11,532 | clean |
| rich-s8 | rich | curious |  | 15.2 | 12,704 | clean |
| deadly-s9 | deadly | efficient |  | 20.2 | 16,523 | clean (saved discs for load-s22) |
| mission2-s10 | mission2 | efficient |  | 20.2 | 17,287 | clean |
| wanted-s11 | wanted | efficient |  | 12.2 | 8,775 | clean |
| chaos-all-s12 | equipped | efficient | all | 12.2 | 11,114 | clean |
| chaos-all-s13 | equipped | keyboard | all | 12.2 | 10,688 | clean |
| chaos-gear-s14 | equipped | efficient | ghyp, pod, bomb, ecm, missile, unarm | 12.2 | 9,447 | clean |
| chaos-gear-s15 | deadly | efficient | ghyp, pod, bomb, ecm, hyper | 12.2 | 9,496 | clean |
| chaos-death-s16 | equipped | efficient | hurt, heat, fuel | 12.2 | 9,883 | clean |
| chaos-death-s17 | jameson | nosave | hurt, spin, jump | 12.2 | 10,291 | clean |
| chaos-views-s18 | equipped | efficient | views, charts, dock | 10.2 | 8,742 | clean |
| nowork-s19 | jameson | curious (no workaround) |  | 10.2 | 8,639 | clean (no view change in 10 minutes) |
| nowork-s20 | equipped | efficient (no workaround) | views | 0.7 | 137 | **finding 1**: the port died on its first view change |
| load-s21 | jameson | load (eff-s1's discs) |  | 12.2 | 10,110 | clean |
| load-s22 | jameson | load, curious (deadly-s9's discs) | views, ecm, bomb | 12.2 | 9,130 | clean* |
| galaxy3-s40 | galaxy3 | efficient |  | 30.2 | 22,425 | clean |
| galaxy3-s41 | galaxy3 | curious |  | 20.2 | 19,952 | clean |
| debrief1-s42 | debrief1 | efficient |  | 12.2 | 9,949 | clean |
| deadly-s43 | deadly | curious |  | 20.2 | 23,184 | clean |
| long-s44 | jameson | efficient |  | 40.2 | 33,296 | clean |
| death-s45 | equipped | efficient | hurt×8, heat×4 | 15.2 | 12,185 | clean |
| death-s46 | jameson | keyboard | hurt×8, spin×3 | 15.2 | 11,348 | clean |
| pods-s47 | deadly | efficient | pod×8, ghyp×6, bomb×2 | 15.2 | 12,363 | clean |
| fairchaos-s48 | equipped | fair | all | 15.2 | 13,456 | clean |
| wanted-s49 | wanted | efficient | ecm×2, missile×2 | 15.2 | 11,809 | clean |
| load-s50 | jameson | load (galaxy3-s40's discs) | views, ecm | 15.2 | 11,301 | clean |
| load-s51 | jameson | load, curious (long-s44's discs) |  | 15.2 | 13,140 | clean |

"Clean" means:

- no game-state divergence;
- no control-flow divergence;
- no crash, hang, BRK or page &0D write;
- no save-file difference;
- no unexplained observable difference, apart from finding 2, which is present in every
  session.

All the sessions but the two nowork ones ran with `--workaround look1`.

\* load-s22 reported a save-file difference at its very end. Triage showed that the session
stopped while a save was being written, and that is a harness artefact (artefact 7 below).

**Coverage.** These figures are routine entries in the original, summed over the 34
sessions; the port's counts were identical.

| Area | What was covered |
|---|---|
| Docked screens | 401 Status screens, 220 Inventory, 26 Data on System, 125 Buy Cargo, 95 Sell Cargo, 285 Equip Ship |
| Flight | 258 launches, 111 dockings |
| Jumps | 171 hyperspace jumps, 6 galactic hyperspace jumps, 14 witchspace arrivals (13 forced mis-jumps), 1,318 in-system jumps |
| Combat | 886 explosions, 21 missiles fired and 6 fired at us, 235 E.C.M. activations, 348 iterations of energy-bomb flash, 55 Thargoid spawns |
| Escape and death | 10 escape-pod launches, 5 deaths with restarts from the title |
| Disc | 110 disc menus: 105 saves and 4 loads |
| Pause | 1,550 pause-menu loop entries, from the agent setting damping and joystick |
| Missions | mission 1 briefing ×4, mission 2 briefings (BRIEF2 ×2, BRIEF3 ×1), mission 1 debriefing ×1 (and once more in a test session) |

The agent's journal recorded these events:

| Event | Count |
|---|---|
| fights | 185 |
| dockings | 110 |
| saves | 105 |
| new systems | 114 |
| deaths | 5 |
| escape pods | 3, plus 7 from chaos |
| galactic jumps | 2, plus 4 from chaos |
| equipment purchases | 32 |
| loads | 4 |

Mission 2's debriefing at Birera (DEBRIEF2) was not reached in the campaign. A follow-up
session (`debrief2-s52`, commander `debrief2`) was run for it. Its result is under "Coverage
notes" at the end.

## 4. Findings

### Finding 1: LOOK1 falls through into DEATH. A change of space view kills the commander.

**Severity: critical.** Pressing f1, f2 or f3 in flight kills the commander. So does f0
from another space view. The ship explodes and the game returns to the title screen. Any
player who looks behind kills himself. elite-agent does this whenever it fights with the
rear laser or watches a flyby from a side view.

**First divergence.** The port's game state at the MLOOP before the key is identical to the
original's. Inside the next iteration the control flow parts:

- the original's next keyboard read is from DOKEY, still in flight;
- the port's next keyboard read is from TL1, the title screen.

In nowork-s20 this happened at iteration 137, read 2317. In the repro below it is at
iteration 265, read 2446. The port's routine trace shows the order:

1. `LOOK1` (bank 4, &BE61);
2. `TT66`, `FLIP` and `WPSHPS`;
3. `DEATH` at &BE83, entered with S = &FD after the RTS from WPSHPS, with no JSR or JMP;
4. `DEATH2`, the title.

**Cause.** In `master/src/elite-bank4.asm`, LOOK1 (line 10034) ends with `JSR WPSHPS` at
line 10064, and the comment after it reads "And fall through into SIGHT to draw the laser
crosshairs". In the original, SIGHT follows LOOK1. Commit 7e92d36, "LL51 tests each term's
sign before the multiply", 17 October, moved SIGHT out of bank 4 to make room. SIGHT is now
at `master/src/elite-source.asm:19444`. DEATH (line 10084) is now the next routine in bank
4, so LOOK1 falls into it.

The likely fix is `JMP SIGHT` after `JSR WPSHPS`. That is also what `--workaround look1`
does at run time. With it, the port's state stays identical to the original's through 234
view changes. The gate's pilot never changes view, which is why `verify.sh` passes.

**Repro:**

```sh
node master/tools/agentplay/replay.mjs --log master/tools/agentplay/repro/look1-death.jsonl --out scratch/agentplay/r1
# REPLAY FINDINGS ...: control-flow: read 2446 (iteration 265): reference RDKEY from DOKEY (iteration 266), candidate RDKEY from TL1
```

The log has 219 records, from boot: an equipped commander, the agent and a chaos `views`
overlay. The f2 key is at read 2445. To see the port's routines, add `--trace 263,265`, which
writes `trace-cand.txt` and `trace-ref.txt` to diff. Screenshots:
`scratch/agentplay/repro-look1/finding-{ref,cand}.png`. The port is at "Load New Commander
(Y/N)?" while the original is still flying.

### Finding 2: a stray compass dot at the top-left of the compass ring

**Severity: minor (cosmetic).** From the first flight onwards, the port shows a green
three-pixel dot just outside the top-left of the compass ring, at dashboard (186, 195). It
stays there for the whole game. In deadly-s43 the real compass dot passed that corner and
became invisible for 2 iterations, because the two EORs cancel. The original shows nothing
there.

**Observable.** `compass 186,3 dot extra in port`. It was seen in every session, at about
99% of the iterations compared in flight. It starts at the first iteration in flight: 45 in
eff-s1.

**Cause.** BEGIN zeroes the configuration block, which includes COMC, so the first COMPAS
call erases a dot that was never drawn: `DOT` with COMX = COMY = COMC = 0.

- **In the original,** CPIXK ANDs the dot's bytes with COL = COMC = 0, so that EOR changes
  nothing.
- **In the port,** DOT (`master/src/elite-dash.asm:796`, lines 819-830) uses COMC only to
  choose a front or behind shape: `CMP #YELLOW2 / BNE dot1`. It then clamps COMX and COMY
  into the ring (186..204, 195..213). So it EORs a green behind-dot onto the screen at the
  clamp corner, and nothing ever erases it.

The fix is to return from DOT, or skip the plot, when COMC = 0, as the original
effectively does. Game state is unaffected.

**Repro:**

```sh
node master/tools/agentplay/replay.mjs --log master/tools/agentplay/repro/compass-stray-dot.jsonl --out scratch/agentplay/r2
# observable: iteration 45: compass 186,3 dot extra in port ref null cand [[186,3,1]]
```

Crops of both compasses at iteration 51 are in `docs/agentplay/compass-stray-dot-port.png`
and `docs/agentplay/compass-stray-dot-original.png`.

### Expected differences

- **Overlapping scanner dots.** When two ships' scanner dots overlap, EOR mixes them.
  - In the original, two same-coloured mode 2 dashes cancel. For example, a Thargoid and the
    Thargon it has just launched vanish from the scanner.
  - The port's dots are 2×2 dither cells in per-class patterns, so they don't cancel, and
    adjacent sticks merge differently.

  The same happens to a pack of ships whose sticks share a column. The comparator works out
  each ship's dot and stick from the K% slots, with SCAN's own arithmetic. It counts a
  difference where two or more ships' dots or sticks fall in the same blob as `scanner dots
  overlapping (expected)`.

  All 11 sessions that showed a scanner or bulb difference live were replayed with the final
  checker: curious-s3, nosave-s6, deadly-s9, mission2-s10, wanted-s11, load-s21,
  galaxy3-s40, galaxy3-s41, debrief1-s42, deadly-s43 and death-s45. 163 iterations were
  counted as overlaps, for example 45 in galaxy3-s40 and 22 in mission2-s10. One of them was
  death-s45's iteration 9577, a pack of four ships whose sticks share a column; it was checked
  with the final rule. The only other difference left was deadly-s43's compass dot vanishing
  for 2 iterations, which is finding 2.
- **Dot shape and clamping.** The port's dots are two lines tall, and the original's is a
  dash and a stick. The port clamps scanner and compass dots off the dashboard's first two
  lines. Dots are therefore matched within a line, and a compass dot at line 2 in the
  original matches the port's at line 3.
- **Bar resolution.** The port's bars have twice the original's resolution. The original's
  length must equal the port's halved, and it did in every comparison.

### Harness artefacts found and fixed

These came up while the tooling was built and were fixed in it, so the campaign doesn't
have them.

1. **A double hook on an empty slice.** A run slice that ended on an overshot target ran no
   instruction, and the reference's hook saw the same instruction twice. In one session this
   made a joystick read count twice, and BETA and JSTY appeared to diverge. The machine now
   hooks each instruction only once.
2. **Page &0D false alarms.** These came from the DFS NMI code running in page &0D, and from
   the write PC being taken after the instruction. The check now uses the instruction's own
   PC and ignores code in page &0D.
3. **The NA% checksum.** A patched NA% without its checksum hangs the original in DFAULT's
   `doitagain` loop. The checksum is now recomputed.
4. **Hooks in sideways RAM.** A hook with no bank in banks.txt (for example SFRMIS_C) fired
   for whatever was at that address in another bank. Such hooks now use their main-RAM stub
   or aren't hooked, and HAZEL hooks fire only with HAZEL paged in.
5. **The port's bar colours.** A port bar shorter than a byte read its colour class wrongly.
   Classes are now read from the first two pixels.
6. **Bulbs under dots.** A scanner dot over the E.C.M. bulb area read as the bulb lit. Bulbs
   are now matched against their bitmaps, ECBT and SPBT.
7. **Saves still being written.** At load-s22's end, the final save-file check found
   E.CLAUDE differing in 34 bytes. The session had stopped part-way through a save: the
   reference had entered SVE a fifth time, after the agent's last save note. Each machine's
   disc controller runs on its own clock, so one machine had written more of the file than
   the other. The session's four completed disc accesses compared identical, and so did its
   replay. Discs are now compared only once both machines are past the MLOOP after a disc
   access (SVE returns before it), and the final check is skipped if either machine hasn't
   got that far.

## 5. Limits

- **Timing and sound.** These aren't compared. NOISE is made deterministic as in the gate,
  and the sound buffers are excluded. Each machine runs at its own speed.
- **Iterations, not frames.** Observables are compared at each main-loop iteration. The
  dashboard is drawn once an iteration in both builds, so a per-frame comparison would add
  nothing but the in-between states.
- **Repros replay from boot.** jsbeeb's snapshots don't hold the disc controller. Repros of
  a few hundred iterations take under a minute.
- **The original's rendering.** The original's own rendering quirks are mirrored, not
  judged. For example, the original's same-coloured dots cancel, and the original also
  leaves the compass erase at COMC = 0 alone.
- **Time spent.** About 8.8 game hours were played. Career phases that take elite-agent
  many hours were only reached by patched commanders, not by playing through. These include
  Elite rank, galaxies 4 to 8, and the full Thargoid plans run.

## Coverage notes

- **Mission 2's debriefing.** This was not reached in the two campaigns. It was covered by
  `debrief2-s52` (commander `debrief2`, 15.2 game minutes, 12,397 iterations): the agent
  flew to Birera and docked, and DEBRIEF2 ran in both machines. The state was identical and
  TP ended at %1110. The session is in `scratch/agentplay/campaign2/debrief2-s52`.
- **Mission 1's debriefing.** This was also run in the test session `t8-debrief`
  (8.2 game minutes, 6,516 iterations), which was clean.
- **The galaxy-3 commanders.** These took the agent through 8 forced mis-jumps and 37
  Thargoid spawns (GTHG), and through mission 2's first two briefings.
- **Development sessions not counted.** About 40 game minutes of development sessions
  (`scratch/agentplay/t1`…`t9`) aren't counted above. They found finding 1 first, and most
  of the harness artefacts.
- **Commands.** These reproduce the campaigns:

  ```sh
  sh master/build.sh && sh master/tools/agentplay/build.sh
  node master/tools/agentplay/campaign.mjs --out scratch/agentplay/campaign1 --jobs 4
  node master/tools/agentplay/campaign.mjs --out scratch/agentplay/campaign2 --plan extra --jobs 3
  node master/tools/agentplay/agentplay.mjs --out scratch/agentplay/campaign2/debrief2-s52 --minutes 15 --seed 52 --commander debrief2 --workaround look1
  ```

  Any session replays with `node master/tools/agentplay/replay.mjs --run <session dir>`.

## 6. The second campaign: 20 October, the blueprints in HAZEL

This campaign ran overnight on 19-20 October, against the relayout that put the ship
blueprints in HAZEL. It ran in the tree full-grind.

- **The port tested:** full-grind at 7c25608, which equals full-master after the "blueprints
  in HAZEL" relayout. In that relayout:
  - the blueprints are in HAZEL;
  - the renderer's workspace is in main RAM at &0840-&0CFF and &1300-&1EFF;
  - BCODE runs from &1F00 on into bank 4;
  - DOSCLI stashes all of HAZEL in screen buffer 0 around each OSCLI.

  Two fixes were made during the night (below). The build at 7c25608 was byte-identical to
  `elite-master-full-latest.ssd`. The gate passed there at 17.21 it/s, ratio 1.232.
- **The workaround:** `--workaround look1` was dropped. LOOK1 was fixed in be18285, and the
  stray compass dot in 268fe8a. So no session played past a known bug.
- **The aim:** the routines that the relayout touched. These are:
  - the disc menu (catalogue, delete, save, load, and disc errors);
  - NWSPS/NWSHP, and the station's blueprint pointer in XX21 (now in HAZEL);
  - the hangar;
  - launching after a save or load (the reset of buffer 0);
  - the docking computer, the views, the escape pod, the missions and galactic hyperspace.

### What was run

| Campaign | What | Sessions | Game minutes | Iterations compared | Sessions with findings |
|---|---|---|---|---|---|
| default | the existing plan, no workaround | 22 | 310.1 | 254,523 | 0 |
| extra | the existing second plan, no workaround | 12 | 229.8 | 194,408 | 0 |
| nightplan | `night`: the disc menu, docking computer, views, pods, missions | 17 | 237.4 | 182,374 | 0 |
| night2 | `night2`: the docked screens and the disc menu | 16 | 298.7 | 179,268 | 0 |
| night3 | `night3`: 40 generated sessions (partly on the build before the fixes) | 39 | 507.7 | 400,879 | 11 |
| night3b | `night3` again, on the fixed build | 40 | 625.3 | 500,079 | 1 |
| night4 | `night4`: 40 generated sessions, missiles and fights | 40 | 657.2 | 529,927 | 0 |
| night5 | `night5`: 24 generated sessions | 24 | 333.5 | 261,923 | 0 |
| night6 | `night6`: as night5 with other seeds, sessions 3/4 as long | 24 | 251.5 | 195,565 | 0 |
| night7 | `night7`: as night5 with other seeds, sessions 0.6 as long | 24 | 202.3 | 153,866 | 0 |

Notes on the table:

- **default and extra:** the existing plans, without the workaround.
- **night and night2:** new plans for the disc menu and the docked screens.
- **night3 to night7:** generated plans. Each covers every commander, mode and chaos mix,
  then loads its own discs.
- **night3:** ran partly on the build before the first fix, and partly across a rebuild (see
  harness artefact 9). night3b is the same plan run again on the fixed build.

In all: **258 sessions, 3653 game minutes (60.9 game hours), 2,852,812 main-loop iterations compared** (2,588,416 in flight), 8,350,209 input reads replayed, 2,407,640 dashboard comparisons and 2,169 save-file comparisons.

### New in the harness

- **Chaos while docked.** These actions start from the Status screen. Up to three run a
  dock, and the agent's keys are held back while each one runs.
  - `disc` drives the disc menu:
    - catalogue a disc;
    - delete a missing file, or a file saved earlier;
    - load a missing file;
    - give a bad drive number, or type a bad name;
    - save under other names;
    - type names with slips and DELETEs;
    - the default commander, and exit.
  - `docked` visits the screens the agent never uses, or never gets wrong:
    - the market;
    - the system data and inventory;
    - the charts, with the cursor moved (sometimes with SHIFT) and hyperspace asked for
      while docked;
    - equipment that is already fitted or that it can't afford;
    - Y/N answers on the sell screen.
- **HAZEL check.** Every 16 iterations, the port's read-only game data in HAZEL is checked.
  This covers the blueprints and their tables (&C000-&C2FF, and XX21 to &DFFF), except for
  XX21's station entry. Each byte must keep its value from the first MLOOP. It never fired
  in a session. A test that flips a byte in the candidate does make it fire.
- **Whole-code coverage of both machines.** coverage-ref.json and coverage-cand.json (by
  bank for the port) list:
  - the labels whose code ran;
  - the JSR/JMP targets that never ran.

  `coverage.mjs` unions these files over any set of directories.
- **Two regression tests that call routines directly in both machines.**
  - `test-chpr-overflow.mjs` covers CHPR's screen clear.
  - `test-exit-flags.mjs` covers the registers and flags that MSBAR, ECBLB and SPBLB
    return.
- **Campaign hygiene.** A campaign now copies the candidate build when it starts. A BRK loop
  ends a session. A hang is judged against the other machine (`hang-both`).

### Coverage

Over the 252 sessions with whole-code coverage, **1,348 of the original's labels had code run**. Of the labels that look like code (a JSR/JMP target in the image, or a label with code run in any session), only 6 never ran: DETOK3, DIDGIT, DVLOIN, OTHERFILEPR, log, shpcol. DETOK3 prints RUTOK's system descriptions, which only a few special systems show on the Data on System screen; DVLOIN has no caller in the source; OTHERFILEPR (the other medium's name, disc or tape) is unused in the Master version; the others are data tables that the JSR/JMP scan mistakes for code.

Everything the relayout touched ran in both machines:

- **The disc menu:**
  - SVE 2,889 times;
  - LOD 186 times;
  - CATS, DELT and DELL1, and the menu's jan18/feb10/feb13 branches;
  - YESNO, GTDRV and its invalid-drive returns;
  - MT26's DELETE (OSW05) and ESCAPE (OSW04);
  - NEWBRK and BRBRLOOP for disc errors.
- **NWSPS and NWSHP.** NWSPS writes the station's blueprint pointer into XX21, in HAZEL,
  each time it runs. Both ran at every launch and every arrival in a system, and the HAZEL
  check stayed quiet.
- **The hangar** (HALL, HANGER), at every one of 603 dockings.
- **Launching:** 1,568 launches, many of them straight after a disc access.
- **Galactic hyperspace:** 45 times.
- **The escape pod:** 98 times.
- **Deaths:** 158.
- **The docking computer:** DOCKIT and DOKEY.
- **The rear and side views:** from the agent, and from chaos.
- **The missions:** BRIEF ×47, BRIEF2 ×24, BRIEF3 ×6,
  DEBRIEF ×23 and DEBRIEF2 ×12.
- **The market screen** (TT167, first reached tonight).
- **Hyperspace while docked** (dockEd), and **out of range** (TT147).

Chaos actions, over these campaigns: docked dcat 128, dsave 151, dnoload 120, dnodel 138, ddel 122, dbad 106, dname 68, ddefault 96, dexit 130, dmarket 224, dchart 247, dequip 213, dsell 218; in flight views 3,346, missile 3,051, unarm 407, ecm 2,192, bomb 113, pod 63, ghyp 46, hyper 73, jump 1,710, dock 277, charts 855, spin 928, hurt 391, heat 89, fuel 82.

On the port's side (202 sessions), 2,230 labels had code run, in main RAM, HAZEL, ANDY and banks 4-7. The 79 code-like labels never run are mostly start-up code (TT170, R_INIT, F_INIT, SETINTS, COLD), data and workspace, and original routines the renderer replaces (LASLI's `las`, WPL1). Worth noting: FILLKL's key-matrix loop `fkr` (the harness injects keys after FILLKL, so it never runs with a key down; see "Needs a human"), F_DSTAR/G_DSTAR (stardust drawn outside record mode), and the stubs x4_BOOP, j4_BEGIN, x4_SOFLUSH, TT103, TT15 and ping (their bodies run, called directly) and the trampoline r_call5/r_hzj5. The full list: BEGIN, COLD_C, DEEOR_C, DETOK3_C, DTW2, DTW6, FC_S11_D, FC_S18_D, FC_S1_F, FC_S2_D, FC_S3_D, FC_S3_F, FC_S4_F, FILEPR_C, F_BACK, F_DC, F_DLP, F_DSTAR, F_INIT, F_LY0, F_NLINE, F_NSHIP, F_ORD, F_PXL, F_SPL, F_SX4, F_SZH, F_SZL, F_TCH, G_DSTAR, JAMESON, QSL, R_BDN0, R_BDN1, R_BDX00, R_INIT, R_PYH, R_WR, R_X0, Rd2, SETINTS_C, SFXPR, TENS_C, TT103, TT15, TT170, T_INIT, WPL1, XX24, YP, alogh, c_hi, c_m0, f_nv4, f_wr, fkn, fkr, fl_h3, j4_BEGIN, las, logL, msbpars, ping, r7_cb1, r7_lm, r7_m2, r_call5, r_hzj5, r_jm, r_lm, r_rm, r_start, r_xo, savosc, setzp_C, sg_y1, sz1_C, x4_BOOP, x4_SOFLUSH.

### Findings

Two port bugs were found and fixed. Both were found in night3, and its rerun on the fixed
build (night3b) had no findings but the expected one noted under finding 3.

| # | Finding | Severity | Status | Repro |
|---|---|---|---|---|
| 3 | **TTX66 fetched from shadow RAM.** CHPR's screen clear (text off the bottom, or code 11) crashed the port in a BRK loop. | Critical (a hang or crash where the original goes on) | Fixed in 3db0b1c | `repro/ttx66-shadow-crash.jsonl` |
| 4 | **MSBAR returned C set.** The original's returns C clear. With a missile lock and a new explosion in the same iteration, the explosion's random seeds, and from then on the whole game, diverged. | Major (game state diverges) | Fixed in 275ec01 | `repro/msbar-carry.jsonl` |

#### Finding 3: CHPR's screen clear ran G_DIRECT from shadow RAM

**What happened.** CHPR sets ACCCON's X bit, which puts shadow RAM at &3000-&7FFF. It then
calls TTX66, through TTX66M, to clear the screen in two cases:

- when the text runs off the bottom (RR2, YC ≥ 24);
- for control code 11 (cls).

In the original, TTX66 is at &2157, below &3000, so X doesn't matter. The port's TTX66 is in
bank 4. It starts by calling G_DIRECT, a stub in main RAM at &7655. With X set, the CPU
fetched that stub from shadow RAM, ran screen bytes, and ended in a BRK loop at &7D62 (the
stub `getzp`).

**How it was found.** The candidate also raised a "Channel" disc error, and the reference
raised none. The trigger is in the disc menu. If the commander's name is abandoned with
ESCAPE, the original leaves it without a RETURN (MT26's OSW04). The Status screen then
prints NAME onwards until it finds one, and that runs off the bottom of the screen. Any
text long enough to run off the bottom would do the same. Three night3 sessions hit it:
n3-debrief2-curious-s119, n3-trader-curious-s131, and esc/s208, which was used to cut the
repro.

**The fix.** TTX66 clears X before it calls G_DIRECT. TTX66 sets the whole of ACCCON itself
straight afterwards. The fix adds 5 bytes, in bank 4. Gate: 1.232, 17.21 it/s, unchanged.

**The test.** `test-chpr-overflow.mjs` calls CHPR with YC = 24 and with code 11 in both
machines. It fails on 7c25608 (no return, X still set) and passes now.

**The repro.** The repro now replays without the crash. One expected difference remains:
P+3 differs from iteration 151 to iteration 347, then the two agree again. P+3 is the screen
page of the last character printed. NAME's unterminated text continues past the commander
block into &1300 on. That is TVT3 and the code in the original, and the renderer's
workspace in the port. So the garbage text on the Status screen differs between the two.
That difference comes from the original's own bug and the new layout, not from a port bug.

For the same reason, the ESCAPE case is now its own chaos action, `dnameesc`, and isn't part
of `disc`. One night3b session, n3-rich-keyboard-s103, started before that change and ended
on this P+3 difference.

#### Finding 4: MSBAR returned C set

**What happened.** The original's MSBAR ends by adding 8 to SC, which never carries, so it
returns with C clear. The port's MSBAR, in elite-dash.asm, ended after `CPY #6` with C set.

ABORT2 calls MSBAR when a missile locks on. Suppose a ship started exploding in the same
iteration. Then LL9's EE55 went into DORND for the explosion cloud's seeds with C still set.
DORND's result depends on C. So RAND, then the stardust, and then everything after it
diverged.

This was n3-debrief2-nomission-s129, at iteration 9029. It was traced by logging the carry
at every routine between the last matching DORND and the first differing one.

**The fix.** MSBAR now ends with CLC. That adds 1 byte. Gate: 1.232, 17.21 it/s, unchanged.

**The test.** `test-exit-flags.mjs` calls MSBAR (X = 1-4, four colours), ECBLB and SPBLB in
both machines, with C clear and C set on entry. It compares A, X, Y, C, Z, N and V at the
return.

- On 7c25608, 64 of the 72 calls differ.
- Now, none differ.
- With `--info` it also runs DOT. DOT returns X = 2 where the original returns X = 0 (with
  COMC = 0). No caller uses X after DOT, so this was left alone and is noted under "Open".

**The repro.** It is long: 9,030 iterations, about five minutes to replay. It replays clean
now.

#### The original's own behaviour, seen tonight

Each of these happened in both machines alike. None is a port bug.

- **DFS waits for ever on an empty drive.** Cataloguing drive 1 with no disc in it hangs DFS
  at &8E3A in bank 9, in both machines. It waits for the 1770 and only Escape gets it out,
  and the harness's keys can't raise Escape. A real Master with no disc in the drive behaves
  the same way. The session is ended as `hang-both`, so `dcat1` isn't part of `disc`.
- **DELT corrupts the save command.** DELT copies a deleted name with X = 9 (Moxon's notes
  call it a bug). That overwrites the first character of `savosc`, so every later save fails
  with "Bad string".
- **An unterminated name.** An ESCAPE in the name prompt leaves the name unterminated. See
  finding 3.

#### Harness artefacts found and fixed tonight

All of these are in agentplay's commits. The port was not changed for any of them.

8. **BRK classification.**
   - DFS builds some errors on the stack page ("Not found"), and the MOS raises errors in
     &E000-&FFFF ("Bad string", "Bad command"). These were reported as game BRKs, and MOS
     error text was read from RAM. Both are now OS errors, read from the MOS ROM.
   - A disc error in the candidate ahead of the reference was reported as a mismatch. The
     disc menu runs no MLOOP, so both machines sit at one iteration. Errors are now matched
     by input reads.
9. **A rebuild during a campaign.** night3's eight phase 2 (load) sessions all diverged at
   ALTIT, because master/build had been rebuilt with the first fix. Those sessions load a
   phase 1 disc, so they ran the old game. But they read the new symbols, so every hook in
   bank 4 after TTX66 was 5 bytes off, the Q-clearing hook among them. Replaying them with
   the old symbols is clean. Campaigns now copy the candidate into `DIR/cand-build` when they
   start.
10. **Hangs.**
    - The candidate runs ahead of the reference between reads. Its stall was reported before
      the reference had reached the same place. It now counts only once the reference has
      gone past it; if both machines stall at the same place, it is `hang-both`.
    - A BRK loop wrote millions of findings and never ended. Now 20 identical BRKs end the
      session.
11. **The chaos overlay's exits.**
    - A docked action could leave the Equip Ship screen on a number prompt, which f8
      doesn't leave. docked-s82 spent 15 minutes there.
    - Leaving the disc menu with 6 alone could fill a name prompt with 6s (load-s94).
    - Both now cycle through f8, RETURN and 0, or 6 and RETURN.
    - `all` and `disc` now work as items of a list.

### Needs a human

- **Real hardware: the screen clear.** On a real Master, check that a disc catalogue or
  text that runs off the bottom of a docked screen clears the screen and carries on, rather
  than hanging. Try ESCAPE at "Commander's name?" under Save, then exit to the Status
  screen. Before 3db0b1c this hung the port.
- **Real hardware: the keyboard.** FILLKL's column detection (fkdet, through CA2) can't be
  exercised by agentplay, because keys are injected after FILLKL. In jsbeeb, with keys held
  on the emulated keyboard and the harness's key hooks off, it gave the same key logger and
  KL as the original for 13 combinations of one to three keys. These included SHIFT, CTRL,
  the f-keys and keys in the same column. A check with a real keyboard, including several
  keys at once, is still worth doing.

### Open

- **DOT's X at return.** DOT returns a different X from the original's (see finding 4). No
  caller was found that uses it.
- **Flags of other rewritten routines.** A general audit of the flags that the port's
  rewritten routines return was not done. MSBAR's carry showed that this kind of difference
  can matter, but rarely. Finding 4 needed a missile lock and a new explosion in the same
  iteration, and it turned up once in thousands of game minutes. A test like
  `test-exit-flags.mjs` could cover DIALS, COMPAS and the hooks.
- **Never-run port code.** The port-only code that never ran is listed under "Coverage".
