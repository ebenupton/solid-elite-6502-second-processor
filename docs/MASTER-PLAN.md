# Filled renderer on full BBC Master Elite: plan

Goal: move the filled, double-buffered CMYK renderer from the Demonstration Disc
port (tag `demo-final`, disc `elite-master-demo.ssd`) onto the full BBC Master
Elite (ref/elite-source-code-bbc-master, SNG47 variant), so the game is playable.
Do it as a long series of single-purpose commits, each of which builds and passes
the gate for its stage.

## Why Master Elite (and the space budget)

Measured from the reference build (source symbols plus the routines' Category
headers):

* BCODE &1300-&7F48 (27.7K) plus BDATA &8000-&B1FF in sideways bank 6 (12.8K: ship
  blueprints 8.1K for 33 types, tokens QQ18/TKN1/RUTOK 4.5K). The 4K dashboard
  image at &7000 is screen data and gets replaced.
* The renderer replaces Master Elite's drawing (lines/LOINQ 2.7K, pixels 0.5K, sun
  0.3K, circles part, screen tables and IRQ ~1K, dashboard ~1K), about 4.5K, so the
  game needs about 36K resident, plus hooks and face data for 33 ships.
* The renderer layer (demo port) is about 42K loadable (bank 5 rasteriser 16.3K,
  bank 6 frame layer 16.4K, raster7 cold and lines, bank 4 tables) plus 7.4K of
  runtime state in HAZEL.
* Loadable space on the Master: main RAM &1300-&3FFF (11.5K) plus &7E00-&7FFF, four
  sideways RAM banks (64K), and HAZEL. Main &4000-&6FFF is double-buffer A, and
  shadow &4000-&6FFF is buffer B.

So about 78K is needed against about 76K available: a deficit of roughly 3-5K.
Ways to recover it, in order of preference:
 1. Share instead of duplicating: Master Elite's own maths and helper routines
    replace the demo copies, and the layer's direct-mode drawing replaces Master's.
 2. Cycle-neutral byte-recovery grinds (the grind tooling with a bytes objective
    and a no-cycle-regression rule), mostly on cold code.
 3. Spare RAM for cold data: ANDY (&8000-&8FFF private RAM, ROMSEL bit 7; check
    what MOS 3.20 keeps there); shadow &3000-&3FFF and &7E00-&7FFF (visible only
    with ACCCON X=1, so suitable for data read by docked-only code).
 4. Last resort: a docked-only overlay loaded from disc on docking (as the original
    Model B disc Elite does). Disc access means DFS uses HAZEL, which the port also
    uses; that has to be solved anyway for SAVE/LOAD (see below).

Cassette Elite would fit easily (the demo derives from it), but it lacks the Master
version's ships, missions and extended text. Master is the user's preferred base.

## HAZEL and the filing system

The port uses HAZEL (&C000-&DFFF) because the MOS never touches it during flight.
Full Elite does disc I/O (commander save/load and catalogue) while docked, and DFS
keeps its workspace in HAZEL. One of these is required:
* stash DFS's HAZEL workspace at load time and swap it in around every OSFILE/OSCLI;
* or reinitialise the filing system before disc I/O and rebuild the port's HAZEL
  contents afterwards. Rebuilding is cheap: the code image is in bank 6 (HZIMG),
  and the flight runtime state can be reset on launch.

Decide this by experiment in jsbeeb.

## Verification

Reference: the original Master Elite (built from ref, SNG47) on the emulated Master.
Port: our build on the same machine. Both are driven by the same deterministic
input:
* the harness injects the key logger and joystick state at the same main-loop
  iteration in both runs, at the routine boundary where Master Elite has finished
  scanning the keyboard;
* the pilot is a pure function of game state at the start of the iteration, for
  example "steer towards the nearest hostile and fire when in the sights, otherwise
  towards the planet or station; dock with the docking computer; buy and sell;
  hyperspace". Equal states therefore give equal keys.
* key waits on docked screens (title, Y/N, menus) go through the same injection,
  counted per wait.
* the commander can be patched identically in both runs (cash, docking computer,
  galactic hyperdrive) to reach more of the game.
Compare game state per TT100 iteration (zero page game variables, K% slots, FRIN,
commander block, as compare.mjs does for the demo), excluding sound and the
renderer's own state. Speed table: iterations per emulated second per window. The
target is the original Master Elite's speed in every window (no Model B reference
any more).

## Stages (each a run of single-purpose commits)

A. Infrastructure
   1. Import pristine Master Elite sources and build them in-tree, bit-identical to
      the reference binaries (CRC check).
   2. Disc and boot that run the in-tree build on the emulated Master.
   3. Input-injection harness, the state-driven pilot script, and the compare and
      speed tool for Master Elite against itself (passing trivially for the
      unmodified build).
B. Relocation, no rendering change (the target layout is docs/MASTER-MAP.md)
   1. Move Master Elite's code out of main &4000-&7FFF into sideways banks (with
      far-call stubs where code crosses banks) and its data out of bank 6, keeping
      Master's own drawing. Gate: identical state to the original.
   2. Free main &4000-&6FFF and shadow &4000-&6FFF for the two buffers. Master's
      drawing targets shadow, and its screen is still single-buffered.
C. Renderer, one primitive at a time (each commit gated by state identity, plus
   screenshots)
   1. Bring the layer files (raster, frame, faces, HAZEL stubs, tables) into the
      build, unused.
   2. Frame loop and double buffering (FRAME at the end of each iteration, flip at
      vsync). Then, one per commit: stars, sun, planet (disc, beach ball, craters),
      ships (LL9 record and fill), ship faces and colours for all 33 Master ships
      (tools/faces.py), explosions, lines (lasers, hyperspace and launch rings),
      text overlay, sights, the CMYK MODE 1 dashboard (tools/dashboard.py), the
      split, scanner and compass.
   3. Docked screens: direct-mode drawing via the layer's direct routines.
   4. Filing system and HAZEL coexistence (see above).
D. Space recovery grinds as each stage needs them, then speed grinds (the
   annotated-window grind adapted to the new tree).

## Stage A: done (infrastructure)

### Tree and tools

* `master/src/`: the pristine SNG47 sources (elite-source, elite-data,
  elite-loader, elite-disc, elite-readme; font and dashboard image), with only
  their paths changed to `src/` and `build/`. `master/build.sh` assembles them into
  `master/build/` and checks all five binaries with crc32.py against
  `master/reference/sng47` (all match, and the disc image is identical to the
  released `elite-master-sng47.ssd`). `ENCRYPT=no`, `MATCH=no`, `VERIFY=no` as
  upstream's Makefile options; the checksum script takes the F%, G% and NA2%
  that the assembler prints, so a changed source still gets a correct commander
  checksum and encryption range. `build/symbols.txt` (main code and workspaces)
  and `build/symbols-data.txt` (bank 6) are beebasm `-d` dumps;
  `master/reference/symbols*.txt` are those of the pristine build.
* `harness/mboot.mjs`: boots the disc (model "Master"), runs to the title
  screen, checks bank 6 against BDATA, takes `title.png`. The title loop is
  reached at 11.2 emulated seconds.
* `harness/mlib.mjs`: input injection and state recording (below).
* `harness/mpilot.mjs`: the pilot (below).
* `harness/mcompare.mjs`: reference against candidate, per-iteration state
  comparison, first divergence, speed per window and per pilot phase.
* `master/verify.sh [N] [mcompare options]`: the gate. Build (reports how many
  binaries still match), compare the released disc against the build for N
  iterations (default 10000, ~4 minutes), `VERIFY PASS <ref> <cand> <ratio>`.

### Input injection

Master Elite reads keys only in FILLKL (via RDKEY / RDKEY-1), in DKS5 (and
CTRL) and with OSWORD 0 in MT26 (commander names; the pilot never goes there,
and the harness stops if it does). The real keyboard is never pressed after
boot. At RDKEY+5 (just after JSR FILLKL) the harness writes the key logger, KL
and X exactly as FILLKL would have for the pilot's keys; at DKS5+17 it sets X
for the tested key. The pilot is told the call site: DOKEY (once per main-loop
iteration, docked or in flight), `t`/`t2` (the TT217 waits, with the routine
that called the wait: gnum, YESNO, ...), the title loop (TLL2), PAUSE2. So both
runs see the same keys at the same iteration or the same nth poll of a wait,
whatever their speed. An iteration is counted at MLOOP (docked iterations
included; TT100 runs only in flight), and the state is compared there.

### Timing dependence (findings)

* The IRQ (IRQ1/LINSCN) writes DL (vsync flag), JOPOS (ADC; conversions are
  off and it is read only with the joystick on) and the sound buffers. All
  three are excluded from the comparison. LASCT is counted down by MLOOP in this
  version, not by the IRQ (unlike the demo), so it needs no injection.
* The sound buffers do leak into game state. NOISE accepts or drops a sound
  and picks its channel by comparing priorities with SOPR, which the IRQ
  clears when a sound ends (real time); it returns C (and A, X) accordingly,
  and LASNO's NOISE is followed by LASLI, whose first JSR DORND rolls that C
  into RAND. A build slowed by one WSCAN per iteration diverged from the
  original at iteration 7334 (RAND, then the laser line and everything after).
  The harness therefore clears SOPR at every NOISE entry, in both runs: every
  sound gets a channel chosen by its number only, NOISE returns A = &80, C = 1,
  and the leak is gone. (The sound mix differs from the real game; game state
  does not otherwise read the sound buffers.)
* With that, the original against itself, against the in-tree rebuild, against
  a build with an extra WSCAN per iteration (13% slower) and against a build
  with a 1280-cycle busy loop per iteration: identical game state for 20000
  iterations each.
* The title screens' length is the pilot's poll count (25 polls each), not
  time. The title also reads the joystick fire button (PB4): never pressed in
  jsbeeb. RAND at TT170 is identical for the same loader; mcompare seeds the
  candidate's RAND from the reference's anyway (`--seed rand`).
* In perturbed builds NEWB differs at TT170 (left over from the decryption); it
  is written before it is read, and the state is identical from iteration 0.

### What the pilot exercises (20000 iterations, reference)

Commander patched at BAY in both runs: beam laser front, 10000 Cr, docking
computer, galactic hyperdrive, 4 missiles, E.C.M., energy unit, escape pod,
energy bomb, full fuel. In 20000 iterations (19693 in flight, 1518 emulated
seconds, ~5.5 minutes wall per run): 6 launches, 3 dockings by docking
computer, 5 hyperspace jumps (1 galactic), 5 systems in 2 galaxies, 37
engagements, 15 ships destroyed (missiles, boulder, asteroids, shuttles,
transporters, Sidewinder, Mambas), 4 missiles fired, E.C.M. used, 1 death (and
the title screens again), buy/sell/equip screens 6/3/9 times, Status, Market
Prices, Short-range Chart and Data on System on every docking, 322 key waits.
The approach to the station (planet + 4 and + 2 nosev, in-system jumps while
far, then ~1600 iterations of flight at speed 40 into the safe zone) dominates
the iteration count.

### Reference speed table

Flight-loop iterations (TT100 to TT100, only intervals with no docked
iteration in between) per emulated second, released SNG47 disc on jsbeeb's
Master, pilot as above (`node harness/mcompare.mjs --iters 20000 --window
1000`):

| iterations | flight | it/s | phases |
|---|---|---|---|
| 0-999 | 937 | 11.41 | combat 500, approach 352, hyper 86, docked 62 |
| 1000-1999 | 1000 | 14.92 | approach |
| 2000-2999 | 1000 | 15.59 | approach |
| 3000-3999 | 1000 | 16.50 | approach |
| 4000-4999 | 1000 | 16.99 | approach |
| 5000-5999 | 950 | 13.41 | combat 500, approach 364, hyper 86, docked 50 |
| 6000-6999 | 1000 | 15.44 | approach |
| 7000-7999 | 950 | 11.50 | approach 762, combat 188, docked 50 |
| 8000-8999 | 1000 | 12.60 | approach 602, combat 312, hyper 86 |
| 9000-9999 | 1000 | 13.56 | approach |
| 10000-10999 | 1000 | 10.72 | approach |
| 11000-11999 | 1000 | 15.82 | approach |
| 12000-12999 | 1000 | 15.52 | approach |
| 13000-13999 | 950 | 10.93 | combat 500, approach 449, docked 50 |
| 14000-14999 | 950 | 12.19 | approach 736, combat 214, docked 50 |
| 15000-15999 | 1000 | 13.38 | approach 628, combat 286, hyper 86 |
| 16000-16999 | 1000 | 15.88 | approach |
| 17000-17999 | 1000 | 14.76 | approach |
| 18000-18999 | 1000 | 14.97 | approach |
| 19000-19999 | 950 | 13.66 | combat 500, approach 414, docked 50 |
| all | 19687 | 13.75 | |

By phase: combat (near the station after launch, and dogfights) 10.00 it/s
over 2994 iterations; hyperspace countdown 10.01 (381); approach 14.91
(16307). The 10000-iteration gate run gives 13.97 it/s overall. Per 200
iterations the windows range from about 9.2 (station in view) to 22 (open
space).

### Master Elite's memory use (for Stage B)

Measured over 6000 piloted iterations (write/read hooks per memory) and from
the source:
* ROMSEL is &06 throughout: bank 6 is paged in permanently (the loader checks
  it is RAM, then copies BDATA into &8000-&B1FF). ANDY is never paged (ROMSEL
  bit 7 never set). Banks 4, 5 and 7 are not used at all (48K free), nor is bank
  6 above &B1FF (3.5K).
* Bank 6 is read for blueprints (XX21 and the ship data), QQ18/TKN1/RUTOK
  tokens, SNE and ACT. It is also written: NWSPS stores the station's blueprint
  address into XX21+2/3 (Coriolis or Dodo) on every station spawn.
* ACCCON is &09 or &0F at every instruction: Y = 1 (HAZEL RAM at &C000-&DFFF)
  and D = 1 (shadow displayed) always, and X = 1 (shadow at &3000-&7FFF) only
  inside the drawing routines (about a third of all instructions). So the MOS
  VDU code at &C000-&DFFF is never visible during the game. The only HAZEL
  access in play is DIALS storing 1 to &DDEB on every iteration (the
  commentary does not know why; docs/MASTER-MEMORY.md finds &DD00-&DEFF
  unreferenced by MOS 3.20 and DFS 2.24, so it looks harmless, but the port's
  HAZEL layout should leave &DDEB alone or drop the store deliberately).
  docs/MASTER-MEMORY.md has the full MOS/DFS picture for HAZEL, ANDY and the
  spare main RAM.
* Shadow RAM: the screen, pages &40-&7D written (space view &4000-&6FFF,
  dashboard &7000-&7EFF, copied there by the loader), and &3F read; &3000-&30FF
  holds the swapped top half of zero page (&90-&EF) during disc access
  (setzp/getzp); the rest of shadow &3000-&3FFF is unused.
* Main RAM: zero page &00-&E3, XX3 and the stack, K% &0400-&05BB with the ship
  line heap growing down from &0800, WP &0E41-&12A9 (FRIN, flight variables,
  LSX2/LSY2/LSO heaps, stardust, the commander NAME..SVC, JOPOS), and code from
  &1300 to &7F48 (F%), including &4000-&7FFF of main RAM. Variables live inside
  the code area too: the sound buffers (&144D-&14A5), VNT3+1 (DOVDU19), self-
  modified LOIN code (&18xx-&19xx, written by DOWN and LIlog6 on every line),
  DETOK and DTW1-DTW8 (&32xx, &3B66-&3B6C), UP &2C40-&2C61 and NA% &3468-&352D.
  Stage B's relocation has to keep these (and the encryption range G%..F%,
  handled by build.sh) in mind. &7F49-&7FFF holds BDATA's unused page.
