# agentplay: the original and the port, played side by side by elite-agent

agentplay has [elite-agent](https://github.com/8bitkick/elite-agent) play the original BBC
Master Elite (SNG47, wireframe) while our full Master port with the filled renderer replays
the same inputs at the same moments. It compares the two machines' game state at every
main-loop iteration, and their dashboards as drawn. It reports the first divergence, with
the input log that reproduces it, and catches crashes, hangs, BRKs, page &0D writes and
differing save files.

It runs headless, on jsbeeb (the same emulator as `harness/`), and needs no window.

## Quick start

```sh
git clone https://github.com/8bitkick/elite-agent ~/elite-agent      # the player (C), read-only use
sh master/build.sh                                                    # master/build: the port and its symbols
sh master/tools/agentplay/build.sh                                    # scratch/agentplay/agentd
node master/tools/agentplay/agentplay.mjs --out scratch/agentplay/s1 --minutes 10 --seed 1
node master/tools/agentplay/replay.mjs --run scratch/agentplay/s1     # the same session again, without the agent
node master/tools/agentplay/campaign.mjs --out scratch/agentplay/c1 --jobs 3
```

By default the reference is `master/reference/elite-master-sng47.ssd`, with its symbols in
`master/reference/symbols.txt`. The candidate is `master/build/elite-master-sng47.ssd`, with
its symbols in `master/build/symbols.txt`. To compare another build, pass `--cand`/`--csyms`.
The released `elite-master-full-latest.ssd` is byte-identical to a build of full-master at
4737aab, so `master/build`'s symbols fit it.

## How it works

**The agent.** elite-agent's player (`cplayer/`) is pure C. Once per 50 Hz frame it reads
the machine's 32 KB of main RAM and presses keys and moves the joystick. `agentd.c` links
the player without elite-agent's own emulator and speaks a pipe protocol. The harness sends
the reference's RAM each frame. agentd answers with key changes, joystick values, log lines
and journal events. Every variable the agent reads (`cplayer/elite_ram.h`) is at the same
address in SNG47 as in Moxon's flicker-free build, which the agent was written for. So the
agent plays the original as it is. It never sees the port.

**Inputs at the read, not the frame.** The input model is `harness/mlib.mjs`'s. Keys are
never pressed on the emulated keyboard. They are written into the game's key logger at the
points where the game reads the keyboard:

- RDKEY+5, after FILLKL;
- DKS5+17, a single-key test;
- DK15's two `LDA JOPOS`, the joystick, written just before each one runs.

`lib.mjs` numbers every such read. The reference answers each read from the agent's
current keys and stick, and queues the answer with the routine that made the read. The
candidate takes the queue read for read. When it reaches a read the reference hasn't made
yet, it stops at that instruction and waits. So the port always gets the same input at the
same read, whatever its speed. Any difference after that is the port's own. The kind and
routine of every read must also match, which checks control flow.

The rest of mlib's determinism measures are kept:

- SOPR is cleared at NOISE;
- Q is cleared before the ALTIT square root;
- the candidate's boot leftovers are seeded from the reference at TT170.

**Game state.** At every MLOOP both machines' state is snapshotted, using mlib's regions:

- zero page;
- the K% ship slots;
- WP, which holds FRIN, the flight variables, the commander and JOPOS;
- UP, the configuration;
- NA%;
- the sound buffers.

The snapshots are compared with the gate's `--loose` exclusions. The first difference is
reported field by field. Ship-slot bytes are named by slot and INWK field, for example
`K% slot 3 z_hi`.

**Observables** (`observe.mjs`). The dashboard is read back out of each machine's shadow
RAM at every MLOOP in flight, and turned into values that should agree although the two
dashboards look nothing alike:

- **Bars:** each bar's length must be exactly the port's length halved. The original has 16
  steps and the port has 32, from the same values. The colour class must match: normal,
  danger or flashing.
- **Roll and pitch markers:** each must be within 2 of double the original's position.
- **Missile indicators and the E.C.M. and station bulbs:** their states must match.
- **Scanner and compass dots:** every dot EORed onto the scanner or the compass is read.
  This is the screen XORed with the dashboard image as the loader left it at S%. Each dot
  in one machine must have something drawn within 3 units and a line in the other.

Pixels are never compared.

**Other checks:**

- **BRKs:** every BRK that reaches the game's NEWBRK is logged with its bank. A
  filing-system or OS error is expected: a BRK in a ROM bank, on the stack page (DFS builds
  some errors there, "Not found" among them) or in the MOS's &E000-&FFFF. Such errors must
  come in both machines at the same read (else `brk-mismatch`). A BRK from game code is a
  finding; the same one 20 times is a `brk-loop`, which ends the session.
- **Page &0D writes:** the candidate's game code must not write page &0D.
- **Hangs:** a machine that makes no read and no iteration for 30 emulated seconds
  (`HANG_SECS` in the environment). The candidate runs ahead of the reference between
  reads, so its stall counts only once the reference has made a read past it; if both
  stall at the same read it is `hang-both`, the original's own behaviour (DFS waiting for
  ever on an empty drive), which ends the session but is not a port finding.
- **HAZEL:** the port's read-only game data in HAZEL (the blueprints and their tables, but
  for XX21's station entry) must keep its values; checked every 16 iterations (`hazel`).
- **Crashes:** a machine with its PC in page 0 or 1.
- **Save files:** after every disc access, once both machines are past the next MLOOP (SVE
  returns before it), and at the end, the commander files in directory E on the two discs
  must match, catalogue and bytes.

**Play styles** (`styles.mjs`):

- `--commander`: the starting commander, patched into both machines at the first BAY,
  The patch goes into NA% (with its checksum) at the first QU5, before DFAULT copies it.
  The choices are:
  - `jameson`, `trader`, `equipped`, `rich`, `deadly`, `mission2` and `wanted`;
  - for the missions: `debrief1` (the Constrictor destroyed), `galaxy3` (Ceerdi, with mission
    1 done) and `debrief2` (Birera, with the plans);
  - `diso`: at Diso, all fitted, with Quator (14, 137), a system with a moon, selected (the
    moon movie's start, `moonmovie.mjs`).
- `--mode`: elite-agent's own modes. The choices are `efficient`, `curious`, `fair`,
  `keyboard` (keys rather than the stick), `nosave`, `nomission`, `load`, which loads
  CLAUDE from a disc that `--savediscs` wrote, and `moon` (MOON=1): the port's moons are
  solid (elite-moon.asm), so the agent works out where each is, as the port places it
  (from the system's seeds and the planet's spin axis at the arrival or launch, then
  fixed in space), and steers clear of it. The moon mode is in
  elite-agent's branch `moon-avoid` (its docs/MOON.md): build an agentd from it with
  `ELITE_AGENT=<that checkout> OUT=<path> sh master/tools/agentplay/build.sh` and run with
  `AGENTD=<path>`. The original has no moons, so with the mode on the agent steers round
  the port's moons in both machines alike and the lockstep holds; without it, a flight
  into a moon kills the port's commander only, a divergence (MASTER-PLAN, "The moon is
  solid": or build the port with MOON=scenery). build.sh compiles the elite-agent it is
  given: newer ones need a C23 compiler (gcc-15 from Homebrew, if there), are told they are
  on a Master, and take its address table as they find it (they look for Moxon's
  flicker-free build's bytes, not the release's).
- `--chaos`: a seeded overlay of extra keys and pokes, for what the agent rarely does on
  its own. It covers E.C.M., the energy bomb, the escape pod, the views, missiles, the
  galactic hyperdrive, hyperspace, in-system jumps, the docking computer and the charts.
  Pokes drain the shields and energy, heat the cabin or empty the tank, at an iteration
  boundary in both machines. Docked, from the Status screen (up to three a dock, the agent's
  keys held back meanwhile): `disc` is the disc menu (`dcat`, `dnoload`, `dnodel`, `dsave`,
  `ddel`, `dbad`, `dname`, `ddefault`, `dexit`; `dcat1`, an empty drive, and `dnameesc`, a
  name abandoned with ESCAPE, only by name), and `docked` the screens the agent never visits
  or gets wrong (`dmarket`, `dchart`, `dequip`, `dsell`). `all`, `disc` and `docked` can be
  items of a list.
- `--seed`: sets RAND at TT170. It also seeds the chaos overlay.

All of this goes through the input log, so every session replays exactly.

**Workarounds.** `--workaround look1` got past the first port bug this found (fixed in
be18285, so no longer needed). LOOK1 fell through into DEATH, so any change of space view
killed the commander. With the workaround,
the candidate is sent to SIGHT instead, as in the original, so a session can play on and
look for more. This is done at run time, in the harness. The port's source is not changed.
Each use is logged as a `workaround` event, and summary.json counts them.

## Files a session writes

| File | Contents |
|---|---|
| `config.json` | the session's settings, and the discs' hashes |
| `inputs.jsonl` | the input log. A header, then every read with a key down (`p` the read number, `t` r/d, `s` the routine, `k` the keys), every stick change (`j`, `w`, `v`), chaos actions and pokes, and an `end` record |
| `agent.log`, `journal.jsonl` | elite-agent's log and its journal of events |
| `events.jsonl` | machine events (BRKs, workarounds, page &0D) and findings |
| `summary.json` | iterations compared, the first divergence with every differing field (and with `--keepgoing`, how long it lasted: `divergence.after`), findings, routine counts for each machine, the observables, save-file checks and the final state |
| `coverage-ref.json`, `coverage-cand.json` | whole-code coverage: the labels with code run, and the code labels never run (by bank for the port) |
| `*-ref.png`, `*-cand.png` | screenshots of both machines: at a divergence, at a finding, at the end, and with `--shots N` every N iterations |
| `ref-disc.ssd`, `cand-disc.ssd` | with `--savediscs`, both discs as the game left them |

## Repros

`replay.mjs --run DIR` (or `--log inputs.jsonl --out DIR`) plays a session's input log into
both machines again, without the agent. It needs no saved state: the log, from boot, gives
the same session, read for read.

| Option | What it does |
|---|---|
| `--until N` | stop after iteration N |
| `--trace A,B` | write every labelled routine each machine enters in iterations A to B, to `trace-ref.txt` and `trace-cand.txt`, to diff |
| `--cand`/`--csyms` | try a fixed build against the same inputs (always the two together) |
| `--workaround none` | turn off a workaround the session used |
| `--cut N --save FILE` | write the log cut short after iteration N, as a minimal repro |

Without `--cand`, a replay uses the discs named in the log's header, but only while they
are still the builds the log was recorded with (their sha1s are in the header). Otherwise
it stops with exit status 2 and asks for `--cand`/`--csyms`. The builds a run used are
printed, and kept in `summary.json` as `builds`.

`repro/` holds the input logs of the port bugs found, cut short after the divergence.
`replay.mjs --log repro/<name>.jsonl --out DIR --cand DISC --csyms SYMS` shows each one
again (most in under a minute; `msbar-carry` takes about five). The headers of
`compass-stray-dot` and `look1-death` name a build from before both fixes, so they replay
the bugs without `--cand` (while that build is left alone). `msbar-carry` and
`ttx66-shadow-crash` were recorded on full-master's 3db0b1c^, so they need `--cand`.

Two regression tests call routines directly in both machines, docked:
`test-chpr-overflow.mjs` (CHPR's screen clear with the text off the bottom and for code 11)
and `test-exit-flags.mjs` (the dashboard routines' registers and flags at return).

`coverage.mjs DIR...` (`--cand` for the port) unions the coverage files under any
directories: what was reached, and the code labels no session ran.

## Campaigns

`campaign.mjs` runs a plan of sessions a few at a time (`--jobs`), and can be resumed. It
writes `campaign.json` and `campaign.md`, which give:

- each session's settings and result;
- coverage, as the original's routine entries summed over the campaign, and the original's
  whole-code coverage;
- every finding, grouped across sessions.

Plans are lists in campaign.mjs: `default` (22 sessions), `extra` (12 more: the missions'
later stages, deaths, pods, a long career), `night`, `night2` (the disc menu and docked
screens), `night3`, `night4` (40 generated sessions each) and `quick`. No workaround is
used unless `--workaround` asks for one. The candidate (master/build's disc, symbols and
banks, or `--cand`/`--csyms`) is copied into `DIR/cand-build` when the campaign first
starts, and every session runs that copy, so a rebuild during a campaign changes nothing.

## Limits

- elite-agent reads RAM only, never the screen. Its fair mode limits itself to what the
  dashboard and scanner would show, but it computes that from RAM. So there is no screen
  reading to try on the port's display. The observables do that job instead.
- Sounds aren't compared. NOISE is made deterministic by clearing SOPR, as in the gate, and
  the sound buffers are excluded.
- Timing isn't compared. Each machine runs at its own speed.
- Replays are deterministic: the same log and builds give the same result, byte for byte,
  whatever the host's clock or time zone, the working directory, relative or absolute
  paths, and other runs at the same time. This was checked on every repro, from two
  working directories, two runs at a time, with the host clock shifted by up to years and
  in four time zones (two for `msbar-carry`). The emulated Master's real-time clock always
  reads 1 January 2000 (`harness/mlib.mjs` `pinRtc`), and each machine has its own CMOS
  bytes. In jsbeeb the clock would read the host's time, but neither the MOS nor the game
  reads it in a session. Nothing else in a replay reads the host's time, a random number
  or a shared file.
- What made replays look nondeterministic was the build, not the emulation. An option
  that a tool didn't recognise used to be skipped. In zsh, `C="--cand X --csyms Y";
  replay.mjs $C` passes one argument, so the replay quietly ran the header's build, from
  another worktree. That build was either stale or being rebuilt. Unknown options are now
  an error (`harness/args.mjs`, used by the gate's tools too), and so is a header build that
  has changed since the log was recorded.
- jsbeeb snapshots don't hold the disc controller, so repros replay from boot. Sessions
  are a few thousand iterations long, and a replay runs at about real time or better on a
  quiet machine.
