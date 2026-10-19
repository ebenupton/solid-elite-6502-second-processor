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

Both bugs are still in full-grind's tip (28fb67b).

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
