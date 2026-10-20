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
keeps its workspace in HAZEL. The port keeps the game data (the blueprints) and the
renderer's glue in HAZEL, stashes DFS's and the MOS's lasting bytes (&C2C0-&C2FF and
&DFC0-&DFFF) at load time and swaps them in around its one OS call, OSCLI in DOSCLI,
invalidating DFS's catalogue cache each time, and copies all of HAZEL to screen
buffer 0 for the command and back after it (docs/MASTER-MEMORY.md,
docs/MASTER-MAP.md rule 8, "Blueprints in HAZEL" below).

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

## Stage B: done (relocation, no rendering change)

The layout is docs/MASTER-MAP.md ("As built"). In short: main RAM &4000-&7DFF
holds nothing of the game (asserted in the source, and checked at run time:
no game write to main &3000-&7FFF, and no read of main &4000-&7DFF, in 3000
piloted iterations); Elite's home bank is bank 4 (blueprints, SNE, ACT,
Master's drawing, flight overflow); the cold code is in the cold area (ANDY
plus bank 7 from &AC40, ROMSEL &87); QQ18 is in the cold area and the
extended tokens in shadow RAM &3100-&3EFF; the stubs into the cold area are
at main &7E00. Banks 5 and 6, bank 7 below &AC40 and HAZEL are untouched.

### Tree and tools

* `master/src/`: `elite-source.asm` (main code, then the bank 4, ANDY and
  bank 7 sections), `elite-bank4.asm`, `elite-andy.asm`, `elite-cold7.asm`
  (moved code; cold labels have the suffix `_C`), `elite-far.asm` (far calls:
  far7/far4 and the jump forms, the demo's far7.asm for bank 4 and ROMSEL
  &87), `elite-stubs7.asm` (stubs into the cold area, at &7E00),
  `elite-coldstubs.asm` (x4_/j4_ stubs out of it). `elite-data.asm` saves
  BDATA (dashboard), BANK4D (bank 4 data), QQ18D and TOKENS separately, and
  `build.sh` takes the data's addresses (`build/data-addresses.asm`, with each
  address's area) and the entry point S% and its bank
  (`build/game-addresses.asm`) from the symbols, so code and data move
  without edits elsewhere.
* The copy protection is gone (`_REMOVE_CHECKSUMS`, no encryption); the
  `ENCRYPT` and `VERIFY` options of build.sh went with it.
* The loader (`M128Elt`) loads each file in its table FTAB to &1300 and copies
  it into place with the given ROMSEL and ACCCON (BDATA and TOKENS to shadow
  RAM, BANK4, ANDY, COLD7, STUBS), then BCODE, then pages S%'s bank in.
* `master/tools/bankcheck.py`, run by build.sh, checks the banking rules
  over the whole source (no branch between areas; cold code calls out only
  through stubs and never reads bank 4 data; nothing outside the cold area
  refers to cold labels except stubs; shadow data only through marked
  readers). The moves themselves were made with a scratch tool that cut
  header blocks from the source, renamed cold labels and wrote the stubs,
  checking fall-through between blocks (including `EQUB &2C` skips) and
  IF/ENDIF balance.
* Harness: `mlib` reads `build/banks.txt` (bank-aware PC hooks; call sites
  looked up per bank and through far-call frames, with the caller's
  ROMSEL), seeds boot leftovers from the reference at TT170 (`--seed boot`:
  every compared byte the game has not written since S%), excludes
  relocation temporaries (P, V: pointers into the moved font and token
  tables), and compares UP as UP..VOL. `mboot` checks every installed image.

### Lessons for later moves

* Fall-through is the main hazard: blocks that end in a non-transfer (RES2
  into ZINF, BEGIN into TT170, SOLAR into NWSTARS, PLUT into LOOK1, KILLSHP
  into THERE), and `EQUB &2C` skips (TT26 skips BELL's LDA #7 into its JMP
  CHPR; FEED falls into MT16 and TT26). Branches into another routine's RTS
  (DOEXP to TT48, YESNO to PL6) need their own RTS.
* Code reached from MOS vectors or interrupts must be in main RAM below
  &3000 (IRQ1 and the sound code; CHPR as WRCHV, which reaches TTX66 in bank 4
  through a far call; NEWBRK as BRKV, which now pages the home bank itself
  because getzp, now cold, no longer sets ROMSEL).
* A far call adds three bytes to the stack, which shares page 1 with the
  XX3 vertex heap; the deepest piloted iterations go a few dozen bytes deeper
  than the reference.

### Speed

verify.sh at 10000 iterations gives the reference 13.97 flight it/s and the
relocated builds 13.96 to 13.98 (ratio 0.999 to 1.000) at every commit. The
final build over 20000 iterations (`master/verify.sh 20000`: 6 launches, 3
dockings, 5 jumps including a galactic one, 15 kills, a death; game state
identical throughout):

| phase | flight iterations | reference it/s | relocated it/s | ratio |
|---|---|---|---|---|
| combat | 2994 | 10.00 | 10.01 | 1.001 |
| hyperspace countdown | 381 | 10.01 | 10.01 | 1.000 |
| approach | 16307 | 14.91 | 14.90 | 0.999 |
| all | 19687 | 13.75 | 13.75 | 1.000 |

The far calls are all on flight-rare or docked paths (messages, charts,
hyperspace, launch and docking, screen changes), so the flight loop does not
see them; the remaining differences are page-crossing branches in code that
moved.

### What Stage C has to deal with

* Master's drawing primitives are Elite's DRAW group in bank 4
  (&9DD5-&AC4D): LOIN/LOINQ (EOR lines with self-modified code), HLOIN (sun
  and hangar rows), PIXEL/PIX1/PIXEL2/CPIXK/DOT (stardust, explosion
  particles, dashboard dots), SCAN (scanner), DIALS/DILX/DIL2/PZW/ADDK, MSBAR,
  ECBLB/SPBLB (bulbs), HANGER, TTX66 and CLYNS (screen clears), ylookup; in
  main RAM CHPR with its font (also the WRCHV handler) and IRQ1 with the
  palettes TVT1/TVT3 and the split position VSCAN.
* Frame structure: Master Elite draws everything with EOR into the one
  shadow screen and erases by redrawing: ships from the ship line heaps
  (XX19, K% down from &0800; LL9's LSCLR/LSPUT), the planet from the ball
  line heap LSX2/LSY2 (WPLS2), the sun from the LSO heap (WPLS), stardust by
  replotting, messages by reprinting (MESS, DLY). The screen is cleared only
  on a view change (TTX66, TTX66K) and CLYNS clears the bottom text rows.
  There is no vsync wait in the flight loop: the IRQ sets DL every vsync and
  WSCAN polls it only from DELAY (docked screens, the main loop's slow-down
  while docked) and DK4 (pause). The demo's frame model (display list,
  render into the back buffer at the end of the iteration, flip at vsync)
  replaces all of that; the heaps stay as game state (the harness compares
  the ship line heap unless --loose).
* The IRQ: IRQ1 splits the screen with timer 1 (VSCAN) and sets the
  dashboard palette (Master's dashboard is in shadow RAM, in its own mode);
  the renderer's dashboard is MODE 1 in main RAM &7000 with the split
  writing ACCCON D. DIALS's store to HAZEL &DDEB goes with DIALS.
* ACCCON: Master's drawing writes fixed values (%00001111 / %00001001),
  which would clobber D once it selects the displayed buffer; setzp and getzp
  do too. The new shadow-token readers already use TSB/TRB on X only; the
  renderer's IRQ must keep X when it writes D.
* Bank 4 is full (140 bytes free): the renderer's bank 4 pieces go in as
  DRAW leaves, and about 2.9K of flight code has to move back to main RAM
  (MASTER-MAP.md); main RAM &0840-&0CFF is still unused.
* Cold code reaches drawing through x4_ stubs (x4_LOIN, x4_HLOIN, x4_TT26,
  x4_SCAN, ...). Docked screens drawing directly through the renderer's
  direct routines in raster7 (bank 7 below &AC40) must unpage ANDY first if
  those routines are at &8000-&8FFF.

## Stage C: done (renderer, docked screens, disc glue)

All of Stage C's steps are in, one commit each (git log 8aed22a..): layer
files; loader checks of banks 4-7 and its 1770/NMI and vector defences; the
CMYK MODE 1 dashboard (no IRQ palette change); the frame loop with the
filled planet (disc and craters), stardust, ships with filled faces for all
33 blueprints (tools/faces.py, depth sorted), explosion particles, lasers,
the energy bomb, the text overlay, laser sights, the sun; double buffering
(buffer 0 main RAM, buffer 1 shadow RAM, flipped at vsync); save, load,
catalogue and delete through DOSCLI (HAZEL scratch invalidation, the minimal
NMI handler put back after each command and on the error path); the
hangar's ships drawn directly (GFORCE).

Checked visually (harness/mdocked.mjs, harness/mevent.mjs, mshots.mjs
--seedfile): title, status, buy, sell, equip, galactic and short range
charts, data, market, inventory, the docking tunnel and hangar, the three
mission briefings and debriefings, the escape pod, death ("GAME OVER"),
hyperspace, the disc menu (save, load, a load error, catalogue). The docked
and static screens are Master's own drawing (into buffer 1, with the CMYK
palette); their layout matches the reference's.

Known differences and open items:

* Planet meridians (the beach ball) are not drawn (G_MERID returns): the
  planet is a disc, with craters for crater planets.
* The sun is a clean filled disc (no flickering fringe).
* Face colour issues in harness/mshipshow.mjs's gallery (some faces of the
  asteroid, rock hermit, Adder, Cougar; the shuttle, Gecko and Dodo too
  small to show at the gallery's distances).
* The death screen keeps the border's two top corner bytes.
* The dashboard's first character row is drawn only in shadow RAM; main RAM
  has a static copy for a late split.

### Speed (Stage C, master/verify.sh 10000)

The ratio fell to 0.897 when double buffering went in and has been brought
back to 0.985 (4effed8): disc rows writing only the old/new difference
without fallback, clipped disc spans without f_clamp, quarter-square
multiplication (MULTS, MU11, MULT1, MULT3, MLTU2; bit-exact, checked with
py65 in master/tools/multest), PIX1 not drawing in record mode. By phase:
combat 1.59, hyperspace 1.52, approach 0.87 (big planets and the station
close-up are the slow windows: 0.6 at worst). Speed recovery is a later
stage (by the user's direction); candidates are listed in the final report.

## Ship lighting (after Stage C)

Ported from the demo port's lighting (branch `lighting`, 97c7a12..5be3f06;
docs/DESIGN.md there has the model), with the work split by context rather
than by bank:
* The rasteriser fills polygons in a 4-row colour (R_COLE, R_COLO, R_COL2,
  R_COL3 for y AND 3), so a face can take a 4x4 dither tile.
* Faces have hues: each takes its ship's hue A or B, one of nine 32-entry
  ramps shared by all ships (50% to 100% of the hue's own brightness),
  chosen by master/tools/lightramps.py and written by faces.py into
  gfx-light6.asm (bank 6: pointers, row masks, ramp 0) and gfx-lighthz.asm
  (HAZEL: ramps 1-8, the unlit colours). A face entry is n + 16 * ramp, its
  unit normal (magnitude 61) and its vertices.
* Game context (gfx-light.asm, main RAM &7A00): L_SUN, once per space-view
  iteration from F_FRAME, keeps the light towards the sun (fixed (1, 1, -1) /
  sqrt 3 on the title screen; reseeded from the sun every 32 iterations and
  rotated by roll and pitch in between; kept rotating while the station is in
  slot 1). L_REC, from F_SHIP, writes each visible face's level, round(31
  max(0, n.L)), into the record's XX2 copy (&80 + level; &C0 + level where
  XX2 was 255). Products are exact, with QSL/QSH.
* Frame time (bank 6): f_ship, f_item and f_fins read the levels; f_col
  expands the ramp entry (two packed bytes) into the four row bytes. Details
  take their face's level in the other hue, fins the brighter of their two
  faces' levels; lines, the stations' slots and distant dots are unlit.
* Checks: harness/mlight.mjs records every level L_REC writes and every
  colour f_col makes; master/tools/lightcheck.py compares them with the
  model (no mismatch over 5250 piloted iterations) and measures the light
  against the sun (median 3 degrees; up to 33 degrees for the iterations
  after an in-system jump, until the next reseed).
* Cost: verify.sh 10000 goes from 0.985 to 0.970 of the reference's speed.

## Lens flare (after the lighting)

The demo port's lens flare (its docs/FLARE.md, src/flare*.asm, model
tools/flare.py), ported with the same recipe, arithmetic and pixels: when
SUN has drawn the sun this frame, in the front view (VIEW = 0), with its
centre on the screen (x 1..255, y 0..191) and not inside the planet's disc
(F_HW, the planet's half-widths), eight ghosts at C + k D / 8 (C = (128,
96), D = sun - C, k = 8, 5, 3, -1, -3, -4, -6, -8): six dithered discs and
two dotted rings (the one round the sun only for a sun of radius 26 or
less). Each disc pixel of its 4x4 Bayer mask is ORed in its ink (OR lifts
K = 00, C = 01, M = 10, Y = 11 upwards: additive light); three levels by
|dx| + |dy| (< 96, < 192, more) step every density down the ladder 0 1 2 4
6 8 / 16. It is drawn after the lasers and before the text, sights and
stars, and every span extends this buffer's dirty extent for its row (the
rows' range goes to R_MARKDIRTY), so the next frame on this buffer repairs
it like any other shape. It never touches game state.

Layout (master/src/gfx-flare6.asm, gfx-flare.asm):
* F_FRAME's `JSR f_text2` is `JSR f_flt` (bank 6, at its end): without the
  sun a test of GSUNON (10 cycles); with it fl_xb (4 for buffer 0) and
  ACCCON X = 1 around FL_MAIN, in shadow RAM, and X put back for this buffer
  after. FL_MAIN does the tests, the level and the ghosts' centres (running
  sums S = 32 k D per coordinate, stepped by 32 D: the centre's offset is S's
  high byte), a disc's masks and rows; fl_row does a row's dirty extent and
  address, and fl_or (bank 6) ORs its bytes, clearing X around the writes
  when the back buffer is main RAM (buffer 0; buffer 1 enters past the
  switch). Discs go by row pairs gy - d, gy + d (d = r..0) sharing one span
  set-up, a pair skipped when both rows' Bayer masks are zero.
* Shadow RAM, filled by the loader from FLARE7, FLARE3, FLARE0: &7E00-&7FF8
  (frame step, centres, a disc's set-up, rings), &3F00-&3FFC (tables, the
  row-pair loop), &3000-&307F (a ring's columns and rows, fl_row). Bank 6:
  f_flt and fl_or at its end, fl_dk, fl_lmt, fl_rmt, fl_pxm and fl_ring in
  the COLD6 spare bytes. HAZEL data: fl_ml/fl_mh (32 D), fl_sl/fl_sh (S),
  fl_lev, fl_xb. Zero page: the rasteriser's &10-&27 and R_COLE, R_COLO,
  R_DCE (&06, &07, &0E), which F_FRAME saves and nothing after the flare
  reads before setting.
* Differences from the demo's code (not its pixels): the centres as running
  sums of 32 D; the rows' range is kept per disc and per dot; ring points on
  the axes are plotted once, not twice; discs by row pairs; the demo's FL4
  (one ghost at a time, called from bank 6) becomes a loop in shadow RAM
  calling the bank 6 writer instead, as the back buffer may be main RAM.

Space, paid by cycle-neutral moves (each gated at 1.236, 17.27 it/s):
F_DSS/F_DSX/F_DSY (63 bytes of bank 6 state) to HAZEL, with F_DIRECT's
clear loop folded into f_direct0's (+73 at bank 6's end); F_INIT saving
the zero page in F_DL rather than f_zsave (+34 in the COLD6 area); the
three unused shadow RAM blocks (912 bytes, 874 used). Bank 6 free goes
from 14 to 23 + 43; HAZEL data from 163 + 40 to 121 + 19.

Checks (headless, scratch scripts: the gate's pilot to iteration 1000,
then the sun placed in front of the ship along a path each iteration, the
back buffer dumped as each frame finishes, against the same run of the
build without the flare with the demo's tools/flare.py applied): 0 pixels
differ from the model over 704 frames (514 with the flare: levels 1, 2
and 3, the sun behind the planet, leaving the screen), apart from text,
sights and stars drawn after it; every frame without the flare is byte for
byte the other build's (no residue); game state identical. Screenshots:
/Users/ebenupton/elite-full/screenshots/flare/ (montage.png, compare-*.png:
port | model | differences, display-*.png: jsbeeb's display).

Cost: nothing on the gate (the pilot never has the sun in front: verify.sh
1.236, 17.27 it/s before and after). As first ported, with the sun on
screen f_flt took about 20000 cycles a frame at level 1, 31000 at level 2
and 44000 at level 3 (mean 30000 over the sweep), and the next frame on that
buffer spent about 26000 more repairing the rows (mostly r_drg, R_DISCROWS'
general disc row): 57000 a frame in all, and a sweep with the sun always in
view ran at 9.24 it/s against 12.51 without the flare (-26%). The demo
measured about 25000 + 10000 and -2 to -14% in windows where the sun was on
screen part of the time.

Speed-ups (profile by PC over the sun scene's 61 frames, the build without
the flare as reference: +54300 cycles a frame before, of which the flare's
own code 30500 (fl_span's set-up and dirty extents 9400, fl_or 6600, the
disc row loop 6500, fl_kd's centres 3500, rings 2300) and the repair 23800
(r_drg +11700, r_spc +5600, r7_rowrep, r_bmn, r_dw ...)):
* r_dmb sends an unchanged row whose dirty extent lies clear of its disc
  span to r_dp1 (black the extent) rather than r_drg (~900 cycles a row):
  -7300 a frame (the ghosts beside the planet). The ring round the sun was
  not the main repair cost in these scenes (the planet is the disc layer and
  the sun a full-span secondary disc, dirty anyway): leaving the rings
  unmarked would have saved only ~4000.
* the centres as running sums of 32 D: -2400.
* discs by row pairs with one set-up, pairs of empty rows skipped, fl_row
  and a zero-page fl_or interface: -3900.
* fl_or ANDs the end bytes' masks itself: -1000; buffer 1 skips the ACCCON
  switch: -300.

After: +39300 a frame in that profile (the flare's code 22700, the repair
16500). Over the 300-frame sweep: f_flt 22600 a frame on average (level 2
23400, level 3 32800; on the square path level 1 15100), and the frame
43900 cycles above the no-flare build's (from 56700); 9.82 it/s against
12.51 (-21%, from -26%). Sun-only scenes (the planet hidden: the sun is the
disc layer, 60 frames) cost the same order: +39200 a frame, f_flt 25800
(13.41 it/s against 18.15). The rest of
the repair is r_drg rows where the flare's extent overlaps the disc or the
disc moved (r_dp2/r_dq would need to merge R_WL/R_WR to take them) and the
blacking of the flare's own spans (r7_rowrep, r_spc). Checks after every
step: check.py 0 errors on four paths (sweep 300, square 160, planet line
160, leaving 80: 552 flared frames), frames without the flare byte for byte
the no-flare build's, game state unchanged; test_raster --quick passes.

## Review fixes (after the lens flare)

A reviewer played the full port and missed three things. Each was compared
with the original in the harness at the same game state (the gate's pilot
and seed; scratch scripts, headless jsbeeb); screenshots, original | port
before | port after: /Users/ebenupton/elite-full/screenshots/review/.

* **The compass's cross-hair** (compass.png). Master's dashboard image
  (P.DIALS2P) has a dashed cross-hair in the compass, which tells at a glance
  whether the dot is centred; ours had only the ring. dashboard.py draws it,
  dashed in magenta, clear of the centred dot (x 195..197, lines 10..12), so
  the dot (EOR) sits in its gap when the planet or station is dead ahead.
  The space view's sights were already the same.
* **The docking slot seen late** (slot.png, slot-zoom.png: the Dodo held
  with its slot facing us at z = 4200 down to 1000). The slot is a black
  polygon detail on the front face. A fill only a pixel or two across comes
  out empty, so the slot appeared at about z = 1800, against z ~ 3900 in the
  original (whose wireframe draws its edges up to XX4 = 30, XX4 = z / 128),
  and dark on the dithered face it was hard to pick out even then. Now
  f_item's polygon details go through f_poly2 (frame_cold), which for the
  slot (the only unlit polygon detail) fills it, then outlines it in yellow:
  lines always show at least a pixel. faces.py gives each slot the
  visibility of the furthest edge Elite draws (its loop rotated so that edge
  is its first side) and puts its fill visibility, the least of its
  vertices', in bits 2-6 of the colour byte (f_col reads bits 0-1 only):
  beyond it some vertices are unprojected and f_poly2 draws only the side
  from vertex 0 to 1, as Elite does (the Dodo: edge 20-21 to XX4 = 30, all
  of it to 23; it was 20 for the whole slot). No table changed size.
* **Nothing visible during in-system jumps** (jump.png: J at iterations
  716, 718 and 719). WARP calls LOOK1 with QQ11 = 1, so its TT66 clears the
  screen and redraws the view; the original does both in the same
  iteration, so the planet is seen growing. Here TTX66's G_DIRECT switched
  to direct mode, showing shadow RAM as TTX66 blanked it: every jump showed
  an empty space view until the next frame, so with J held nothing at all
  was visible. WARP now sets GWARP (HAZEL) before LOOK1; F_DIRECT, finding
  it set in space mode, keeps double buffering: it clears the text map (as
  TTX66 clears the text; LOOK1 reprints the title and redraws the sights),
  sets XC = YC = 1, X = Y = 0, and G_DIRECT's end (gdir2, after the hooks in
  elite-hi.asm) returns to TTX66's caller with TTX66's other results (A =
  %00001001, C = 0, V = 0; COL unchanged; measured over 6000 piloted
  iterations: TTX66 always returns those) without clearing shadow RAM or
  drawing the border. Every other TT66 is as before.

Room for these: FLIP, MAS1 and MAS3 (flight-rare game code at the end of
bank 6, behind far6 stubs) moved to a second block of HAZEL code at
&DB87-&DBEA, after the renderer's state (elite-hazel2.asm): HAZEL is visible
to game code with bank 4 paged, so it calls PIXEL2, pxpatd, MVT3 and SQUA2
directly and is called directly (the far6 stubs went). The disc's HAZEL
file is HAZEL.bin then HAZEL2.bin; the loader stages both at &4000 as before
and copies the second block into place after the first. Bank 6 went from 23
free to 143, and is at 28 after the slot (81) and the jump (34). No stub,
hook or HAZEL code moved (gdir2 and GWARP were put after them).

Gate (verify.sh 10000, game state identical, redock and savetest pass):
1.236 17.27 before; 1.236 17.27 after the HAZEL move; 1.229 17.18 with the
slot outline (approach 16.48 it/s: four lines a frame while the slot is in
range, much of the pilot's approach); 1.232 17.21 with the jump fix (the
pilot's in-system jumps no longer clear shadow RAM and draw a border).

## Rationalisation (after the review fixes)

The grind left code wherever bytes were free: game code in banks 5 and 6
behind far5 and far6, two blocks of game code in HAZEL, a separate stubs
region, keep-in-place padding, and alignment pads. The rationalisation
gave each region one purpose (docs/MASTER-MAP.md, rewritten as the design),
in single-purpose gated commits:

* One high code region (&7200-&7FFF, the quarter squares first, freeing
  their 224-byte alignment gap); the energy bomb, OOPS, SFRMIS, ECMOF,
  THERE and msblob back in main RAM (far5, far6, elite-cold5.asm,
  elite-cold6.asm and 33 stubs gone, and the cold area's double hops to
  ECMOF and msblob); HAZEL's game code one block (FLIP with the other
  views' stardust); MAS1, MAS3, the bomb routines and PLL4F back beside
  the code they belong with in the main code; the cold area's bank 7 part
  from COLD7LO (&AA00, one label) instead of the literal &AC40.
* All keep-in-place padding and speed-only alignment taken out (the final
  pass will put back what pays: MASTER-MAP.md lists the candidates and what
  each is worth), the font and log tables first in the main code (171
  bytes of ALIGN gone), bank 7's row runs first, dead code and data gone
  (r7_xo, r7_j, f_clamp, H_BLOIN, r_cyrow, r_wlu, GACCX, the unported
  meridians' scaffolding and gfx-planet4.asm, gfx-lighthz.asm).
* bankcheck.py covers the renderer's banks and HAZEL; profile.mjs --pagex
  measures page-crossing cycles apart from the rest.
* The exchange rate (MASTER-MAP.md): the grind's last byte purchases paid
  about 2 cycles per flight iteration per byte; three below that were
  backed out (R_STARPLOT's dispatch, r_sw's .la unroll, MAL2's unrolled
  copy), and three new speed-ups beat it (DVID4z inline in STL1, ADD
  inline in PLL4, H_BPT's test in BLINE).
* Two port bugs found by the play-testing tool were fixed: LOOK1 fell into
  DEATH on any change of view (the gate now has a view-change regression,
  mcompare --views), and the compass drew a stray dot while COMC = 0.

Free bytes went from about 230 (plus the 224-byte gap) to about 1700;
trampolines from 156 stubs and 6 far-call helpers to 134 and 4. Gate:
1.232, 17.21 it/s before; 1.235, 17.25 it/s after (115930 cycles per flight
iteration, 732 of them page crossings), with test_raster --quick and the
flare's pixel check passing.

## Memory relayout (after the rationalisation)

The renderer's banks and HAZEL were relaid so that each bank keeps its
private tables and HAZEL holds only shared, always-visible content
(docs/MASTER-MAP.md rule 10), in single-purpose gated commits:

* Bank 5 keeps what a frame calls often and the private state its inner
  loops read: the twelve boundary arrays (R_BD*) moved there from HAZEL as
  one block (each pair sharing its low byte, the most read at low bytes
  &00 and &40). Its small routines and high-byte tables fill the tails of
  its run pages; r_wclear is a loop and r_div8 too.
* Bank 7 takes what runs at most once or twice a frame or only for big and
  clipped shapes: R_LINE whole (T_LINE pages bank 7 itself), the 16-bit
  polygons' phase A (bank 5 keeps phase B, the rows passing through HAZEL
  scratch), with its own pixel plotter, arithmetic and edge loops. Its
  tables were cut to what is read (r7_fr, r7_jl, r7_rp computed, r7_lm and
  r7_rm four entries each), and its run pages' tails hold its variables and
  small routines. The cold area starts a page higher (COLD7LO &AB00).
* DOSCLI stashes DFS's lasting bytes (DFSST), which frees &C2C0-&C2FF for
  scratch and &DF00-&DFFF for state rebuilt in flight; the hangar's line
  heap moved from the rasteriser's scratch to &DF00. HAZEL's lasting state
  stays below &D900, clear of the DFS and ADFS private pages. The save
  test fills HAZEL's scratch and &DF00-&DFFF with junk before each disc
  command.
* Dead code went (R_WMERGE, T_WMERGE, T_CLEARALL), and the stars drawn
  directly (F_DSX, F_DSY) moved into bank 6, whose code alone reads them.

HAZEL's free space for code and lasting state went from 251 bytes to 2063,
bank 5's from 172 to 809, at 305 cycles per flight iteration (196 of them
instructions, 109 page crossings for the final alignment pass to recover).
Gate: 1.235, 17.25 it/s before; 1.231, 17.21 it/s after, with
test_raster (full), the flare's pixel check, the agentplay repros and a
short campaign with a save and a load passing.


## Blueprints in HAZEL (after the memory relayout)

The game data (XX21, the 33 blueprints, E%, KWL%, KWH%, SNE, ACT: 7653
bytes) moved from bank 4 to HAZEL, which every bank sees, and bank 4 holds
code only; the main code became one run in the original's order, from main
RAM on into bank 4; the renderer's shared state moved from HAZEL to main RAM
below the main code. In single-purpose gated commits:

* **Disc commands stash HAZEL in screen buffer 0.** DOSCLI copies all of
  HAZEL to main &4000-&5FFF before the command and back after it (DOSNMI,
  also on the error path), so the data may sit anywhere in HAZEL; GSTASH
  makes the next entry to space mode clear buffer 0 and forget its state
  (f_b0new). DFSST keeps DFS's and the MOS's lasting bytes (&C2C0-&C2FF and
  &DFC0-&DFFF) for the command. The save test junks HAZEL where DFS and the
  MOS write at each OSCLI, and checks the game data, the space view after
  the launch (no stale stash) and the error path.
* **What the main code must keep low, found by the audit** (static, and
  traced in jsbeeb: main-RAM code and data used with ACCCON X set, in the
  IRQ handler, or with another ROM paged, over the gate's pilot, docking with
  the hangar, and the disc menu's save, load, failed load, catalogue and
  delete): DIALS calls ADD and PIX1 MU8 with X set, so ADDK (the original's
  copy of ADD below &3000) is back; HANGER reads HANGFLAG with X set, so
  HANGFLAG is back at its original place; the IRQ handler and CHPR were
  already below &3000. The MOS enters BRKV with the ROM that raised the
  error paged in, so NEWBRK starts below &3000 (with stackpt) and pages bank
  4 itself; the MOS reads the disc commands' strings and OSWORD block, so
  they stay in main RAM (after NA%). The cold area reads QQ23, which moved
  there (after GVL: hyp1 falls through into GVL). The tools find code in
  bank 4 (banks.txt by address, the harness's IKNS and LL5 reads, profile's
  TT100 hook).
* **The relayout.** The blueprints keep the original's order from XX21 on
  (NWSHP reads E%-1,Y for the planet and the sun, i.e. into the missile's
  blueprint), so XX21 to the Constrictor fills &C4C9-&DFFF (XX21 written, so
  in &C300-&D8FF), and the Cougar, the Dodo, SNE and ACT &C000-&C2AD; the
  glue is at &C300-&C491 (the rasteriser's bank 5 <-> 7 stubs moved to the
  main code below &3000 for want of room). The shared workspace is &0840-&0CFF
  and &1300-&1ECB (the arrays keep their low bytes; R_WR is page aligned).
  The dashboard's variables went to bank 4 with the dashboard, the hangar's
  line heap to bank 4's last page. The main code starts at &1F00 and goes
  into bank 4 from DVL9a (DVID3B's rare paths); the low code (DOKEY, DK4,
  TIDY, TIS3, DVIDT, DOCKIT, the tactics helpers, HITCH, MALW), the high
  code's flight routines (SIGHT, OOPS, SFRMIS, ECMOF, THERE, msblob, MALC;
  DEATHT back into DEATH), STARS6, STARS2 and FLIP (from HAZEL) and
  elite-flight.asm's routines (TIS2, MVS5; MV40, MV1, MV2 beside MVEIT in
  elite-bank4.asm) are back at their places; elite-low.asm, elite-hazel.asm
  and elite-flight.asm, LOWCODE and the loader's copy of it are gone.
* **Cold routines home.** WARP and HLOIN2, the two cold routines flight
  calls most, which call only home code, came back to their places: 2 far7
  stubs and 5 x4_ stubs fewer, flight far calls 7624 to 5280 in the gate's
  10000 iterations, for 105 bytes. Not taken: the token printers (TT27, ex
  and their helpers with QQ18, about 1.2K) would save about 35 cycles an
  iteration (the x4_TT26 per character of the view's name on each change of
  view, of messages and of the countdown), 0.03 cycles a byte against the
  margin of 2; the rest of the cold routines that flight calls (Ze, BAD,
  OUCH, ee3) save a cycle an iteration or less each and would need x4_
  stubs of their own for their cold callers.

Bank 4 went from 30 bytes free to 1882 (and the hangar's heap), the main code
has 1778 bytes of headroom below &3000 (HEAD_END% &290E), HAZEL's 2063 free
bytes are used (55 left in the glue's gap, 82 read-only), the high code has
565 free. The original's main-code bytes in the cold area: 7560 to 7556 by
the routines' SNG47 sizes (WARP and HLOIN2 home, QQ23 out).

Gate: 1.231, 17.21 it/s before; 1.232, 17.21 it/s after (116235 to 116187
cycles per flight iteration: 11 fewer in instructions, 37 fewer in page
crossings, 841 to 804). test_raster (full), the lens flare's pixel check,
both agentplay repros and a short campaign pass.

## Low data (after the blueprints in HAZEL)

Elite's workspace went below page &0D and the renderer's shared workspace
became one block below the main code, in single-purpose gated commits:

* **The loader's last part runs from K% (&0400).** The loader is at &0E00,
  and after its last disc access it fills DFSST and calls G_INIT, which
  write the shared workspace; its last part is assembled to run at &0400
  and copied there (the game sets K% up itself, as it does WP, which was
  the loader's place in the original). M128Elt's catalogue entry is
  unchanged.
* **The harness compares the station's line heap pointer as the
  original's.** NWSPS points the station's ship data block at LSO, the sun
  and station line heap in WP, so the compared state holds WP's address;
  mlib.canonFor (also in agentplay's snapshots) puts the original's LSO in
  its place.
* **WP to &0841-&0CA9** (from &0E41-&12A9: each byte at the same place in
  its page), in the MOS's buffers that the game never uses; the commander
  file buffer (LSX2) to &087E, which the *SAVE and *LOAD commands take from
  the symbol. *SAVE gives load and execution addresses 0, so the files'
  catalogue entries do not depend on the buffer: a commander saved by the
  original and one saved by the port at the same state are identical, entry
  and contents, and each loads in the other (scratch/savecompat).
* **The shared workspace is one block, &0E40-&1EFF**, ending where the main
  code starts: its first part (R_NDN, the rasteriser's per-call scratch,
  DFSST, R_WL) moved up by &600 to sit below the second, every array at its
  place in its page; R_WR and the variables after it went to the top of the
  last page (R_WR still whole in a page). In a save, a load and a
  catalogue, nothing but the game writes &0E00-&1EFF once it has started.

The block is 4180 bytes with its alignment (R_NDISCL page aligned,
raster_vars at its fixed place), more than the 4096 that would let the main
code, which starts with the page-aligned font, start a page lower; so the
main code stays at &1F00 and HEAD_END% at &290E (1778 bytes below &3000).
Putting the rasteriser's bank 5 <-> 7 stubs (71 bytes) before the font
would start it at &1EB9, but one of R_WR, R_WL and R_NDN would then cross a
page; not done. Free bytes are unchanged: 87 in WP's pages, 64 below the
block and 105 in it (the 151 round the old WP were free but not counted).

Gate: 1.232, 17.21 it/s before and after, 116187 cycles per flight
iteration, 804 of them page crossings, both to the cycle. test_raster
(full), the lens flare's pixel check (0 errors on the four paths; every
frame byte for byte the previous tree's), both agentplay repros and the
quick campaign (with a save and a load) pass.

## Lens flare out of shadow RAM (after the low data)

Shadow RAM is being cleared out: nothing new goes there. The lens flare's
code and tables (FLARE7, FLARE3, FLARE0: 886 bytes at shadow &7E00-&7FF8,
&3F00-&3FFC and &3000-&307F) moved into bank 5, after the rasteriser, and
the "Lens flare" layout above changed so:

* f_flt (bank 6) keeps the tests that read bank 6's state (the front view,
  the sun's centre on the screen, not inside the planet's disc: F_HW), then
  enters R_FLARE (bank 5) through T_FLARE (HAZEL) with this buffer's dirty
  extents' pages in X and Y. R_FLARE does the level, the ghosts, the discs'
  and rings' rows and their spans; it calls R_MARKDIRTY directly.
* No ACCCON switching: the frame layer draws with ACCCON X mapping the back
  buffer at &4000-&7FFF, and the flare's code and data are no longer in
  &3000-&7FFF, so fl_or writes either buffer as it is (fl_xb, the patched
  jump into fl_or and the X switches around FL_MAIN and each span into
  buffer 0 are gone).
* fl_htab (one page) is in bank 5's run page 19's tail, the flare's
  variables (fl_ml, fl_mh, fl_sl, fl_sh, fl_lev) in page 20's (from the
  shared workspace), fl_or and its masks and ring from bank 6 beside the
  flare's code.

Bank 6 was the first choice (beside f_flt), but its cold code (frame_cold,
f_enter) works on bank 6's own state (the text maps, F_DSX, F_DSY), so
moving it to bank 5 to make room would have meant trampolines and copies
of that state; bank 5 had room (809 bytes) and needs one trampoline per
flared frame. Bank 5: 809 to 23 bytes free (and 72 of its tails); bank 6:
194 to 195; HAZEL's glue: 55 to 42; shared workspace: 10 more. Shadow RAM
holds only the extended tokens and the zero-page save; 912 bytes there are
free.

The pixel check (check.py, four paths, 552 flared frames): 0 errors, every
frame byte for byte as before. The flare costs 1000-1200 cycles less per
flared frame (frames matched by iteration: sweep -1189 mean, square -1108,
planet line -832, leaving -1224; at most -2900, at worst +145 in one frame).
Gate: 1.232, 17.21 it/s, unchanged (the gate's run shows no flare).

## Unreachable code removed (after the lens flare)

master/tools/grind/gcreach.py computes what code any execution can reach
from the real entry points (the loader's S% and G_INIT, IRQ1, NEWBRK and
CHPR, BRK, the far-call helpers, every data table), following every kind of
reference: flow, JSR, far and cross-bank calls, every label a reachable
source line or data statement names (immediates, patched operands, label±n,
equate aliases, EQUW words), and every copy of an unrolled statement (the
row-run pages, entered at computed offsets). Everything the gate's profile
executes and every label the overnight campaigns ran is reachable. What was
not went, in single-purpose gated commits, the original's routines keeping
their headers with a `Port: removed (unreachable: ...)` note:

| Commit | Class | Bytes |
|---|---|---:|
| R_CLEARALL, r_clrrow, r7_clearall (no caller since T_CLEARALL went); test_raster.py and replay.py clear the window themselves | port | bank 5 25, bank 7's tails 65 |
| ZEKRTS, SFRMIS's old return | port | cold 1 |
| MUT3 (never called in SNG47) and MUT2 (STARS1 sets (S R) itself, d4d1d4c) | original / orphaned | main 8 |
| HLOIN22, LL28's dead tail (LL31, LL29), WA1's spare RTS | original, dead in SNG47 too | bank 4 34 |
| DORND2's CLC (Ze does CLC : JMP x4_DORND), yetanotherrts (SFRMIS has its own RTS) | orphaned by the port | bank 4 2 |
| TT214/TT221/TT218, DVLOIN, INCYC, SWAPPZERO; backtonormal, CLDELAY, two spare RTSs, hyp1's JSR TT111 | original, dead in SNG47 too | ANDY 59, cold 7 |
| DEEOR's second half, DEEORS, DEEORL and the four "red herring" bytes (no copy protection) | orphaned by the port | cold 56 |
| OTHERFILEPR (no extended token has control code 31; JMTB 31 -> x4_DASC) | original, by the token data | cold 9 |
| SOUS9's BVC P%+3 : ASL A (NOISE clears V) | original | main below &3000 3 |

269 bytes in all; gcreach.py now finds nothing unreachable. Speed: 116190 to
116159 cycles per flight iteration with the first nine commits (all of it
page crossings, 811 to 779; instructions 1 more), 17.21 to 17.22 it/s; over
the whole 10000-iteration run 122485 to 122452 cycles per MLOOP with all
ten (crossings 811 to 772). After SOUS9's commit (3 cycles fewer a NOISE,
with interrupts off) the profile sees no TT100 entry between the MLOOPs of
iterations 1916-1917 and 4454-4455 (the game state is identical at every
MLOOP), so 4 approach iterations count as "other": 9833 flight iterations,
116140 cycles each, 773 crossings. The gate: 1.232, 17.22 it/s at every
commit; test_raster (full), the flare's pixel check (0 errors, every frame
byte for byte as before), the compass, LOOK1 and MSBAR repros and the quick
campaign (with a save and a load) pass; the TTX66 repro diverges at its last
iteration (P+3) exactly as it does on b365683.

## Dashboard split timing (after the unreachable code)

In space mode with buffer 0 (main RAM) on show, IRQ1's timer 1 interrupt sets
ACCCON D so that the dashboard (shadow &7000-&7DFF) is fetched from shadow RAM;
main &7000-&71FF holds a static copy of the dashboard's first character row in
case the split comes late. Docked screens, the disc menu, the hangar, briefings,
launch and the hyperspace countdown are in direct mode (GMODE bit 7 clear:
H_VSYNC shows shadow RAM all frame), so the split does nothing there; every
OSCLI (all through DOSCLI, all inside SVE, after token 1's {clear screen} has
made TT66 enter direct mode) runs with GMODE = 0 and D = 1, and no buffer-0
frame ever overlapped a disc command.

**Measurement** (master/tools/irqprobe: gate.mjs over the gate's run, play.mjs
over agentplay sessions; jsbeeb, nothing changed in the game). ACCCON D acts on
each CRTC fetch as it happens. The last space-view fetch is at line*128+char =
24511, the first dashboard fetch at 24576: the window for the write is 64 cycles
(line 191's horizontal blanking); docs/MASTER-MEMORY.md has the geometry. Before
this work LINSCN restarted timer 1 at each vsync (14,624 us), and IRQ1's write
landed at 24506-24516: usually 2-6 cycles early (1-5 bytes of buffer 1 at the end
of line 191; visibly different in ~1.1% of buffer-0 frames), and in ~0.9% of
buffer-0 frames 1-4 lines late (up to 498 cycles, 256 bytes of the copy shown;
never beyond the copy's 8 lines; gate 115 of 14,421, agentplay 675 of 71,879).
Every late split came from fkdet's SEI section (FILLKL's column scan, ~540
cycles with interrupts off once per iteration), holding off either the timer 1
interrupt or the vsync interrupt that restarted the timer; the other SEI
sections met in space mode were NOISE (~60 cycles), the frame flip (~20) and,
with a key held, Rd1 (~30 per key).

**The rework** (one commit each, gate 1.232-1.233, 17.22 it/s throughout):

| Commit | Change |
|---|---|
| IRQ: timer 1 runs freely | T1SYNC (called once by BEGIN) waits for vsync with interrupts off, starts timer 1 at VSCAN(0 1) and latches 19966: it fires at the same raster position every frame, whatever the vsync interrupt's latency; LINSCN no longer writes the timer |
| IRQ1 tests timer 1 first | `BIT &FE4D : BVC LINSCN` (2 cycles less), so a set but masked vsync flag can't misroute the timer interrupt |
| FILLKL | masks only CA1 in IER from before fkdet to Rd7; no SEI in fkdet and Rd1 |
| Sound | NOISE and SOFLUSH mask only CA1 |
| Frame layer | the flip masks only CA1 |
| VSCAN+1 74 -> 72 | centres the write: timer 1 fires at 24497 in this build, the write 45-53 cycles later; T1SYNC's poll loop can place the phase anywhere in ~9 cycles, so the worst-case spread (~26 cycles) is centred in the window. This subsumes simply re-centring the old scheme (VSCAN+1 30 -> 46) |

Result (gate 10000 with and without a held key, four agentplay sessions: docked
and disc menu, pods and galactic jumps and bomb, deaths and disc, all chaos;
51,000+ buffer-0 splits): timer 1 latency 45-55 cycles, write at 24542-24552,
**0 late, 0 early**; margins 30 cycles early, 24 late. Flight cost 116,140 to
116,155 cycles an iteration (profile --pagex): fkdet's loop now straddles a page
(fkc/fkc1, ~25 cycles an iteration) and the frame layer moved 8 bytes (fpr2), a
grind item. The agentplay repros (the TTX66 one diverging at its last iteration
as on aee0818) and the quick campaign pass.

**Risks.** The phase is set once: it relies on a fixed 312-line non-interlaced
frame and the VIA and CRTC sharing the crystal (zero drift in jsbeeb over
14,000+ frames); anything that rewrote timer 1 or the CRTC's R0/R4/R5/R7 would
need T1SYNC again (nothing does; DET1's R6 change doesn't alter the frame).
jsbeeb sets CA1's flag at the end of the two-line vsync pulse; if real hardware
set it at the start, every split (before this work too) would land two lines
early, showing buffer 1's last lines in buffer-0 frames. The VIA's and the
65C12's interrupt timing are worth +-1-2 cycles each, inside the margins. A
vsync masked by FILLKL with many keys held is deferred by at most ~1,500 cycles,
well inside the 4,864 cycles between CA1 and line 0, so the flip is unaffected.
DKS4 and DKS5 (single-key tests) still use short SEI sections (~30 cycles).

**The copy removed** (2026-10-20, on the order2 branch). The user chose not to
wait for the hardware canary: with option D the split is never late (the probe
measured 0 late splits over 62K frames). The loader's last FTAB entry (`EQUW
MESS1 ... EQUW &7000, &0200`, 8 bytes) is gone, and the high code starts at
&7000 (QSL/QSH page aligned there), so main &7000-&71FF, 512 bytes, is the high
code's. canary.sh is retired: without the copy every build is the canary, as a
late split would show the high code's bytes across the top of the dashboard.
irqprobe's gate.mjs on the result: 10000 iterations, split late 0, early 0,
main RAM shown in the dashboard's area in 0 of 30519 frames (T1 latency p50 47,
max 53 cycles); with --holdkey 0,1 (Q held) late 0, early 0, 0 of 30673
frames (max 53).

## The rasteriser in ANDY (after the dashboard split timing)

The audit (andy-audit) asked whether the rasteriser could live in ANDY and
bank 5 with one set of row runs, freeing bank 7 for cold code and shadow RAM
of the extended tokens. It could, with one change to the idea: R_LINE stays
in bank 7, as it uses no runs and its 3.2K did not fit beside the rest.

**Layout** (docs/MASTER-MAP.md, rules 4 and 10, the map):
* Bank 5 &9000-&BFFF, the rasteriser's shared region (gfx-raster.asm), seen
  whichever window is paged: the boundary arrays, R_SETBUF, r_spc, R_INIT,
  R_RESETBUF, the per-x tables, the 24 row runs at &A000 with their tails,
  the stars, r_lput2/r_ypg, the lens flare.
* ANDY (ROMSEL &85, RASTPOLY), the polygon window (gfx-raster_poly.asm):
  R_POLY and both its phases, including the 16-bit phase A that was bank
  7's, with its variables and a copy of the 32-bit maths. Phase A's copies
  of bank 5's helpers (the DDA loops, r_div8) are merged.
* Bank 5 &8000-&8FFF (ROMSEL 5), the disc window (gfx-raster_disc.asm):
  R_DISCROWS and the dirty repair (r7_crep, r7_rowrep), which now uses the
  shared runs and bank 5's tables.
* Bank 7 (ROMSEL 7) is the cold area's and R_LINE's: the cold area's first
  part (elite-andy.asm, 4019 bytes) at &8000-&8FB2, the same addresses it had
  in ANDY (COLDBANK 7); the extended tokens at &9000-&9DFF, read directly by
  the cold code (TKRD, RUPRD and RUGRD gone, and the TOKENS file); R_LINE
  from &9E00; the cold area's second part from COLD7LO as before.
* No rasteriser code calls between banks: r_call5, r_call7 and r_c7x are
  gone (71 bytes of main RAM below &3000). The T_ trampolines page RASTPOLY
  for R_POLY, 7 for R_LINE and 5 for the rest; R_SETBUF's last part,
  r_sbpoly, pages the polygon window in for phase B's 8 DIRTY operands and
  bank 5 back, &F4 first each time.

**Commits** (each gated by master/tools/grind/verify.sh):
1. bank 5's runs indexed by the row (STA ...,Y, as bank 7's repair had
   them): same bytes, cycle-identical;
2. the tools: ROMSEL as a whole byte in test_raster (ANDY paging, each entry
   with its trampoline's ROMSEL, &F4 checked at every ROMSEL write),
   build/images.txt for mboot, bankcheck's windows rule, the grind model's
   map as data (gcreach, windows, master_config read it), and an ANDY CRC
   around every disc command in the save test;
3. the move itself (the plan's steps 3-5 in one commit, with no bridge);
4. the extended tokens into bank 7;
5. these docs (and comments in the sources: no change to the binaries).

**Speed** (profile.mjs --pagex, the gate's run, against c5feb02): 116155 to
116050 cycles per flight iteration (17.22 to 17.23 it/s): page crossings
817 to 688 (r_dla's straddle gone, main RAM's code 71 bytes lower), 24 more
in instructions (r_sbpoly's paging, about 29 cycles a buffer change, against
the r_call7 calls it no longer makes). The new crossings are listed in
MASTER-MAP's alignment candidates; no padding was added.

**Free space** (outside shadow RAM, against c5feb02): 3701 (+ 1066 in run
page tails) to 5766 (+ 291): ANDY 1313 (the rasteriser's), bank 5 317 (disc
window) and 295 (shared region; + 291 in tails), bank 7 77, 111 (between
R_LINE and COLD7LO) and 397, main code 213. Shadow RAM holds only the
zero-page save; its 3584 bytes of tokens are free and stay so.

**Checks.** At each commit verify.sh 10000 (game state identical at all
10000 iterations; redock, savetest with the ANDY check unchanged over 4
disc commands, views); test_raster --quick on the rasteriser commits and
the full test_raster at the end; the lens flare's pixel check (four scenes,
552 flared frames, 0 errors, every frame byte for byte as before); the
docked screens byte for byte as before (harness/mdocked.mjs, apart from
the title ship's rotation phase); the compass, LOOK1 and MSBAR repros
clean and TTX66 as before (P+3 at its last iteration); the quick campaign
clean; analyse.py, gcreach.py (0 unreachable, every profiled PC matched)
and windows.py on the new map.

**Risks.** ANDY now holds code that runs every frame: a stray MOS write
there (VDU workspace, soft keys) would break the space view at once rather
than a rarely used cold routine. Nothing in the game writes it, and the
save test checks it over disc commands. R_SETBUF's r_sbpoly must keep &F4
in step with ROMSEL (test_raster checks it). Bank 7 is fuller (585 free in
three places), so the cold area has less room to grow; the renderer has
1925 bytes (+ 291 in tails) for speed-ups.

## R_LINE in the polygon window (after the rasteriser in ANDY)

R_LINE was the last of the rasteriser outside bank 5 and ANDY: 3217 bytes in
bank 7 (&9E00-&AA90, gfx-raster7.asm), paged by T_LINE, with its own copies
of what the rest of the rasteriser has. The aim: the renderer in banks 5 and
6 and ANDY only, and bank 7 the cold area's alone.

**The audit.** R_LINE's bytes, by part: the fast path and the old long path
(R_LINE, 868); r7_lgo (1067: the 8-bit set-up, the clip stepping, four
unclipped and four clipped loops); r7_lc16 and its helpers r7_cab, r7_cswap,
r7_cmul, r7_cdiv (778, with their variables); the operand patcher r7_lpat
(118); r7_lstart, r7_lswap (73); and copies of what the polygon window and
the shared region have: the 32-bit multiply and divide with their variables
(120, the same as phase A's rp_ ones), a pixel plotter r7_pset/r7_pclip with
r7_pm (114: bank 5's r_pset/r_pclip), the 4-entry masks (8: the per-x r_lm,
r_rm) and the DIRTY arrays' high bytes (4: R_SETBUF's r_sbh_dl, r_sbh_dr):
246 bytes in all. R_LINE uses no runs and nothing of the disc window's, so
the polygon window (ROMSEL &85: ANDY and the shared region) is its home:
T_LINE pages it as T_POLY does, and it reaches the shared region directly.

Without the copies R_LINE was about 2960 bytes. The room it could use: ANDY
1313, the shared region 295 and the 51 before the per-x tables, the disc
window's 317 only by moving code that only ROMSEL 5's entry points reach out
of the shared region, and the run pages' tails (291, in pieces of 1 to 40
bytes: variables, not code). That is about 2000 bytes for code: the real
shortfall was about 950 bytes, not 0.5K. Bank 6's 187 could take only code
that needs neither bank 5 nor ANDY.

The profile (profile.mjs --pagex, the gate's run) put R_LINE at 1572 cycles
per flight iteration, about 1300 of them in the four unclipped loops (both
ends inside the window: about 1.2 lines an iteration). Lines with an end
outside are rare (about one in 25 iterations), and their cost was mostly
the clip stepping and the clipped loops' tests (about 200 cycles an
iteration), the long path's per-pixel window tests and r7_pset (about 50),
r7_lc16's maths (about 20).

| Option | Bytes | Cycles per iteration | Rate | |
|---|---:|---:|---:|---|
| clip every clipped line exactly (first and last pixel from the window's sides), then the unclipped loops (d <= 255) or a 16-bit error loop (d > 255): no clip stepping, clipped loops, r7_lc16, old long path | -1305 | -64 | - | made |
| R_LINE's copies gone | -211 | -5 | - | made |
| R_INIT, R_RESETBUF to the disc window; the polygon window's arithmetic (r_div8, r_dvq, the 32-bit maths) and R_LINE's cold part (rl_mdq, rl_long) to the shared region; R_LINE's variables to a tail | moves | 0 (crossings -14) | - | made |
| the clipped loops as the unclipped ones plus tests (keeping the stepping) | about -380 | about +250 | 0.7 | superseded |
| the fast path through rl_gen (no 8-bit set-up) | about -177 | about +200 | 1.1 | not needed |
| R_INIT in bank 7 behind a far call | -102 | 0 | - | not needed (and the renderer would be in bank 7 again) |

**Commits** (each gated by master/tools/grind/verify.sh; test_raster --quick
in each gate, the full test_raster at the end):

| Commit | Change | Gate | Cycles per flight iteration (crossings) |
|---|---|---|---:|
| 9918ac8 | raster: R_LINE clips exactly, one path for every clipped line (bank 7: R_LINE 3217 -> 1912 bytes) | 1.234, 17.24 | 116050 (688) -> 115986 (689) |
| 666d7d7 | tests: test_raster's lines aimed at R_LINE's clipping, with the row range | 1.234, 17.24 | - |
| 97dc7d1 | raster: R_INIT and R_RESETBUF into the disc window | 1.234, 17.24 | 115986 (689) |
| 9ad939c | raster: the polygon window's arithmetic into the shared region | 1.234, 17.25 | 115971 (675) |
| d562f68 | bankcheck: the shared region refers to neither window (binaries as before) | 1.234, 17.25 | - |
| e2e8bb5 | raster: R_LINE into the polygon window; bank 7 is the cold area's | 1.234, 17.25 | 115966 (674) |
| 173f07d | build: bank 7's tokens file is TOKENS, not RAST7 | 1.234, 17.25 | 115966 (674) |

**R_LINE now** (gfx-raster_line.asm, 1498 bytes in ANDY after R_POLY;
gfx-raster_lcold.asm, 164 bytes at the shared region's end; its variables,
39 bytes, in run page 16's tail). A line with both ends inside the window
(8-bit) goes to the line loops as before. Any other goes to rl_gen: the
buffer's row range from its clamped y extent; then, from the left or top end
(major m0, minor n0, d = |d major|, a = |d minor|, h = d DIV 2; pixel i at
minor n0 +- (i * a + h) DIV d, the original's rounding), the first pixel
inside, c_i = max(0, lo - m0, ceil((k * d - h) / a)) with k the distance to
the minor side it enters by, and the last, c_j = min(d, hi - m0, ((K + 1) *
d - h - 1) DIV a) with K the distance to the side it leaves by, each term
only when it binds (rl_mdq, on the shared 32-bit maths; most clipped lines
need one multiply-divide or none). The pixels between are drawn by the
unclipped loops from (q, r) = (c_i * a + h) DIV / MOD d when d <= 255, or by
rl_long with a 16-bit error term. R_SETBUF patches r_pset's DIRTY operands;
rl_lpat patches the loops' when the buffer has changed.

**Speed.** 116050 to 115966 cycles per flight iteration (17.23 to 17.25
it/s): instructions -70 (R_LINE's clipped and long lines, its new long-line
loop on r_pset, r7_lstart without clamps), page crossings 688 to 674 (phase
B's moved away; the new ones are in MASTER-MAP's alignment candidates; no
padding added). In the old-against-new run below, whose lines are mostly
clipped, R_LINE takes 22-26% fewer cycles.

**Free space.** ANDY 1313 -> 38; the disc window 317 -> 137; the shared
region 295 -> 131 (+ 8 before the per-x tables, which the build now prints;
there were 51); the tails 291 -> 252; bank 6 187; bank 7 111 -> 3328
(&9E00-&AAFF, contiguous with COLD7LO). In all 1516 bytes more outside shadow
RAM (7372; the table in MASTER-MAP.md); the cold area itself is unchanged,
its new room recorded for it to grow into.

**Checks.** At each commit verify.sh 10000 (game state identical at all
10000 iterations; redock, savetest, views). test_raster --quick in each
gate and the full test_raster at the end. An old-against-new run of R_LINE
(a scratch script on test_raster's machine: 27,000 lines on 9918ac8 and
48,000 on the final build, six seeds, two of them with colours held across
lines; ends around the window, on its sides, far off, long; points,
horizontal, vertical and diagonal lines; random clip windows): pixels and
DIRTY identical; the row range differs only for a line
wholly outside the window with 8-bit ends, which the old path added to the
range without drawing (a superset either way: rows with nothing to repair).
The only DIRTY difference found was an old bug: with R_CT = 0 (the
interface allows it; the game always sets 1) the old clipped loop lxuc ran
on past row 0, writing outside the screen and DIRTY; test_raster's new line
test catches it on cb2c8e5 and passes now. The lens flare's pixel check
(four scenes, 552 flared frames): 0 errors, every frame byte for byte
cb2c8e5's. The agentplay repros: compass, LOOK1 and MSBAR clean, TTX66 as
before (P+3 at its last iteration). The quick campaign: 3 sessions clean
(with a save and a load). gcreach.py: 0 unreachable, every profiled PC
matched. bankcheck: all rules hold, with the new one.

**Risks.** R_LINE's clipping is new code on a cold path: lines with an end
off screen (lasers from the screen's edge, ships partly in view, the
sights). It is checked pixel for pixel against the reference and against
the old code, but the gate's run draws few such lines (one in 25
iterations). The polygon window is nearly full (38 bytes), so R_POLY or
R_LINE has little room to grow without moving more cold code into the
shared region (131 + 8) or the disc window (137). R_LINE's cold part and
R_POLY's arithmetic in the shared region must keep using nothing of either
window's: bankcheck now checks that. R_LINE's variables share page 16's
tail with R_SPAN (one byte left there).

## The source in the original's order (after R_LINE in the polygon window)

The user asked for the cold area, and the rest, to be back in the original's
order, so that upstream the port's source reads as Mark Moxon's
elite-source.asm and elite-data.asm "emitted twice, once hot, once cold".

**Mechanism** (docs/MASTER-MAP.md, "The source and its emissions"). Each
routine sits once, at its original place in elite-source.asm, and its header
names its area (`Area: cold`, `Area: bank 4`; none: the run). BeebAsm has one
location counter and no way to tell two INCLUDEs of a file apart (no
reassignable symbols, no INCLUDE in a FOR or a macro, no forward ORG or IF),
and banks 4 and 7 overlap, so master/tools/streams.py writes one copy of the
source per area with the other areas' lines blanked, and elite-layout.asm
(the file build.sh now assembles) INCLUDEs them in turn. Considered and not
taken: IF guards on a pass flag (the flag cannot change between INCLUDEs);
per-routine ORG switching (needs a counter per area, i.e. reassignable
symbols); two assemblies with exported symbols (circular: each needs the
other's addresses, so three runs and a bootstrap list of labels); staging
through COPYBLOCK (32K of spare assembler memory). The copies keep the
source's line numbers, so errors, bankcheck and the grind's provenance map
point at elite-source.asm's lines.

The far-call glue is generated from the tags: the source uses the
original's names everywhere, the cold copy renames cold labels X to X_C and
its calls out to x4_H/j4_H, and streams.py writes the 48 + 48 stubs
(build/elite-stubs7.asm, build/elite-stubs4.asm). Only the six routines that
never return (BAY, DEATH2, TT170; BEGIN, GOIN, FRCE) are listed by hand, and
JMTB names its three stubs.

**Commits** (each gated by master/tools/grind/verify.sh against 9cafcd9's
reference, all PASS at 1.234):
1. the mechanism, with FRS1, FRMIS and FR1 as the prototype (byte-identical);
2. elite-andy.asm's and elite-cold7.asm's routines back at their places,
   tagged cold (1.234, 17.25);
3. the cold area one run from &8000, the cold data first (QQ18 and the
   tokens, build/COLDD.bin), one image COLD7 (1.234, 17.25);
4. elite-bank4.asm's routines back: X = 1 drawing and the dashboard tagged
   bank 4, the rest into the run; LOOK1 falls into SIGHT again; the file
   banners at their places; main RAM ends before MLS2 (1.234, 17.24);
5. the original's names in the cold code (1450 lines), the stubs generated
   (byte-identical in the old stubs' order, checked; then reordered by first
   reference) (1.234, 17.24);
6. ZEKTRAN back at its place, notes on MULTU and stackpt (1.234, 17.24);
7. these docs.

**Seams.** Original fall-throughs that now cross an area are explicit, each
with a `Port:` note: BEGIN into TT170 (JMP), RES2 into ZINF (JMP), Ze into
DORND (CLC : JMP), SOLAR into NWSTARS (JMP); MLU1/MLU2/MULTU into MU11 (the
port's MLU1 falls into MU11, MULTU joins with BRA). MT26's "fall-through"
into the disc data is not one (its loop always branches). Every other
routine that falls through falls into its original successor (checked
against the pristine source) or into a port routine placed to follow it
(pxpatd into pxpat). Fixed points kept out of order, with notes: the font
and the log tables first (page aligned), stackpt and NEWBRK's start below
&3000 (BRKV), the disc commands' data in main RAM (the MOS reads it),
QSL/QSH at &7200, HANGHEAP at &BF00, the CMYK dashboard as one module
(elite-dash.asm) at DIALS's place. The data's HAZEL wrap (Cougar, Dodo, SNE,
ACT at &C000) is as before.

**Speed** (profile.mjs --pagex): 115966 to 116044 cycles per flight
iteration (17.25 to 17.23 it/s): instructions 115292 to 115295 (LOOK1's
JMP SIGHT gone), page crossings 674 to 749 (MASTER-MAP's alignment
candidates; no padding added).

**Free space.** Bank 7: 3802 in one block at the cold area's end
(&B126-&BFFF). Main RAM 63 (1784 below &3000), bank 4 2054 (2117 together,
3 more than before). The diff against Mark's elite-source.asm went from
54871 lines to 8279.

**Checks.** At each commit the gate; streams.py's fall-through and IF
checks and bankcheck at every build. At the end: test_raster (full) passes;
the lens flare's pixel check, four scenes, 552 flared frames, 0 errors,
every frame byte for byte 9cafcd9's; the agentplay repros (compass, LOOK1,
MSBAR clean, TTX66 as before: P+3 at its last iteration), with --cand and
--csyms spelled out; the quick campaign, 3 sessions clean (with a save and
a load); the docked screens (harness/mdocked.mjs) byte for byte 9cafcd9's
apart from the title ship's rotation phase.

**Left out of order.** The things above with fixed places; elite-dash.asm as
a module; the high code (QSL/QSH and the renderer's game half, which have
no place in the original); the cold area's data before its code (the data
is a separate assembly, elite-data.asm, so its addresses must be known
before the code's: it starts the cold area).

## The original's order, continued (after the source in the original's order)

The user asked to chase down what d23e427 still left out of the original's
order, so that upstream the game side reads as "the original BCODE plus
BDATA, emitted twice, once hot, once cold", with as few exceptions as
possible (docs/MASTER-MAP.md, "What is not in the original's order").

**The fixed points in the hot run.** The rule that forces something below
&3000 (visible with ACCCON X = 1, from the IRQ or from a MOS vector) asks
for "below &3000", not "first":
* the font and the log tables are back at their place after ADDK: the
  original's order puts them in the head anyway. They must be page aligned
  (FONT% is a page number; MLTU2g reads log through an operand whose low
  byte is the argument); one ALIGN before the font does for all four, and
  CODE% is &1EE1, chosen so that it pads nothing (the build prints
  FONTPAD%; the shared workspace ends at CODE%);
* stackpt and NEWBRK: their original place is late in the run, in bank 4,
  so they cannot sit there; a new tag, `Area: low`, leaves them at their
  place in the source and emits them at the end of the head (the low area,
  elite-low.asm, which also holds the port's far calls and, now, the
  renderer's glue). NEWBRK is one routine again (NEWBRK2 went);
* the disc commands' data: RLINE, thislong and oldlong are read only by
  cold code, and the OSCLI strings (CTLI, DELI, savosc, lodosc) are read by
  the MOS from a copy DOSCLI makes in screen buffer 0 (DOSBUF, &6000, after
  HAZEL's stash), so all are back at their places in the cold area;
* QSL/QSH are a port addition with no place in the original: they start the
  high code (page aligned there, as their users patch their operands' low
  bytes), now at &7000;
* HANGHEAP is a port addition (the original's &0B00 is WP's in the port):
  the page after the game data in HAZEL, &DE00, so bank 4 holds code only.

**The CMYK dashboard** (elite-dash.asm) is split up: SCAN, DOT, ddot (at
CPIXK's place), ECBLB2, ECBLB, SPBLB, SPBT, ECBT, MSBAR, DIALS, PZW2, PZW,
DIL (at DILX's place) and DIL2 at their original routines' places, tagged
bank 4, with the port's helpers DILI and DSEG after DIL2; dashboard.py
writes its tables per routine (build/dashtab-*.asm); its variables DASHV
are at WP's end (&0CAA-&0CCE), visible with ACCCON X set.

**The high code** (elite-hi.asm) is one region with a header saying what it
holds and why: the port's game-context glue (QSL/QSH, the renderer's game
half, the far7 stubs). Nothing in it is better elsewhere: the G_ stubs page
bank 6 and the lighting runs with bank 6 paged, so neither may be in a
bank; none of it runs with X set or from the IRQ, so it needs no room below
&3000; bank 4's room is the run's. Then (at the user's request, its own
commit) the dashboard's first-row copy at main &7000-&71FF went, as with
IRQ option D the split is never late, and the high code starts at &7000
("Dashboard split timing").

**The cold data after the cold code.** elite-data.asm is now emitted like
elite-source.asm (tools/streams.py): its blocks are hot (no tag), `Area:
cold` or `Area: BDATA`, and elite-layout.asm assembles the hot and cold
copies in the same pass as the code (no separate data assembly, no
data-addresses.asm). The cold emission is the cold code, then QQ18 and the
extended tokens, then the stubs out; BDATA (the dashboard image) is its own
small assembly with the original's SAVE.

**HAZEL in order.** The renderer's glue (415 bytes), which forced the wrap,
is in the low area now: main RAM below &3000 is visible whatever is paged
and whatever ACCCON X is, disc commands never write it, and the shared
workspace is already there. The hot data runs from XX21 at &C000 in BDATA's
order to ACT (&DDE4). The old constraint that XX21 be in &C300-&D8FF, as
NWSPS writes it, dates from before DOSCLI stashed all of HAZEL: a write
before a command goes out with the copy and comes back; nothing the IRQ or
the catalogue's printing reads is in HAZEL any more (the save test junks
&C000-&C27F, &D900-&DAFF and &DC00-&DFBF at each OSCLI and passes). NWSHP's
read past E% into the missile's blueprint is as in the original (the order
from XX21 is the original's).

**Also back in order:** MULTU after MLU1 (both rare in flight now; MLU1
joins MU11 with BRA and MULTU falls into it).

**Commits** (each gated by master/tools/grind/verify.sh, all VERIFY PASS
1.234): 740e733 the low area, stackpt and NEWBRK (17.24); 85a1258 the disc
commands' data home, DOSCLI's copy (17.24); 1dbcede the font and the log
tables (17.24); c433ac3 the glue to the low area (17.25); 5ac1a8f the data
in the layout's pass, HAZEL in order, the cold data after the cold code
(17.25); 75a43b3 HANGHEAP into HAZEL (17.25); 3bcc00c the dashboard split
(17.24); 92b5c6d the high code's region (byte-identical, 17.24); 1c943e8
the dashboard copy removed (17.24; irqprobe late 0, early 0, with and
without --holdkey); ba54a60 MULTU (17.25); 4df93ce irqprobe's glue reads;
then the tools' test_raster fix and these docs.

**Speed** (profile.mjs --pagex): 116044 to 115978 cycles per flight
iteration (17.23 to 17.24 it/s): instructions 115295 to 115291 (the
trampolines and hooks cost the same in main RAM), page crossings 749 to 688
(the candidates: MASTER-MAP, "Alignment candidates"); no padding added.

**Free space** (MASTER-MAP, "Free space"): main 218 (1376 below &3000), high
code 1077, bank 4 1897, the cold area 3693, HAZEL 283, WP 50, the shared
workspace 148: 7867 outside shadow RAM, 492 more than d23e427 (the
dashboard copy's 512). The diff of elite-source.asm and elite-data.asm
against Mark's went from 8387 lines (git diff --numstat, added + deleted) to
8249, with elite-dash.asm's 1003 lines of port code now inside the source.

**Checks.** At each commit the gate; streams.py's checks and bankcheck at
every build. At the end: test_raster (full); the lens flare's pixel check,
four scenes, 704 frames (552 flared), 0 errors against the model, and
every frame byte for byte d23e427's; the save test (in the gate: HAZEL
junked at each OSCLI, the ANDY CRC); the agentplay repros with --cand and
--csyms spelled out (compass, LOOK1, MSBAR clean; TTX66 as before, P+3 at
its last iteration); the quick campaign, 3 sessions clean (4644 iterations compared, with a save and a load); the docked screens
(harness/mdocked.mjs) byte for byte d23e427's apart from the title ship's
rotation phase.

## Far-call stubs inline (after the original's order, continued)

The user asked for the far-call stubs to sit where each routine was carved
out to the other side, in both directions, so that each emission reads as
the original in its order with a stub wherever a routine lives on the other
side (docs/MASTER-MAP.md, "The source and its emissions").

**The stubs at their places.** tools/streams.py no longer writes stub files
(build/elite-stubs7.asm in the high code, build/elite-stubs4.asm at the cold
area's end). It writes each stub into the copy of the other side, on the
line that defines its routine: in the hot copies `.TT22 JSR far7 : EQUW
TT22_C` under the cold routine's own name (48, far7j for BAY, DEATH2 and
TT170), in the cold copy `.x4_TT26 JSR far4 : EQUW TT26` (49, j4_/far4j for
BEGIN, GOIN and FRCE). Which stubs exist is generated from the references
as before; JMTB still names x4_DASC, x4_MT16 and x4_CLYNS, and labels at one
place share a stub (x4_DASC is a bare label before x4_TT26's). A cold
block's stubs go in the copy of the hot area of the nearest non-cold block
before it (all are the run's), so a block that falls into a cold routine
falls into its stub. The far helpers read the EQUW with the caller's bank
still paged in and keep the caller's bank on the stack, so the stubs work
in bank 4 and bank 7 as in main RAM; the hot ones are in the run (main RAM
and bank 4), game context only, as before. The high code keeps QSL/QSH and
the renderer's game-context glue.

getzp's and HANGER's stubs are in the head before the font, so CODE% went
from &1EE1 to &1ED7 to keep the font page aligned without padding (the
shared workspace's last gap 31 to 21 bytes). Main RAM took 9 stubs and
still ends before STARS2 (the marker did not move); bank 4 took 39.

**The seams closed.** A routine that fell through into a routine now on the
other side falls into its stub: the stub calls the body, and the body's RTS
returns, through farret, to the falling routine's caller with the caller's
bank back: what the fall-through did. streams.py's check allows a block to
fall into a block of the other side whose first statement is its entry
label (and makes that stub), and still forbids any other cross-area
fall-through. So, as in the original:
* RES2 (cold) falls into x4_ZINF;
* Ze (cold) falls into x4_DORND2, and DORND2's CLC is back before DORND
  (Ze's CLC : JMP DORND went; DORND2 was removed as unreachable before);
* SOLAR (cold) falls into x4_NWSTARS;
* BEGIN falls into TT170's jump stub (far7j: TT170 never returns and resets
  the stack, as JMP TT170 into the stub did);
* FRMIS falls into ANGRY again: both are cold and adjacent, and its JMP
  ANGRY (with a note from when ANGRY was in ANDY) was stale.
DELT's JMP SVE is the original's. No seam is left open.

**Commits** (each gated by master/tools/grind/verify.sh): 0a9ff32 the gate
always runs test_raster --quick (about 10 s more per gate; 1.234, 17.25);
722ea6f the stubs inline, seams unchanged (1.234, 17.24: game state
identical at all 10000 iterations, so the move alone is behaviour-identical);
f61c1f4 the seams closed (1.234, 17.24).

**Speed** (profile.mjs --pagex): 115978 to 115995 cycles per flight
iteration (17.24 it/s both): instructions 115290 to 115289, page crossings
688 to 706 (702 with the stubs inline, 706 with the seams closed; the
candidates: MASTER-MAP, "Alignment candidates"); no padding added.

**Free space** (MASTER-MAP, "Free space"): main 218 to 183 (1376 below
&3000 as before), the shared workspace 148 to 138, high code 1077 to 1317,
bank 4 1897 to 1704, the cold area 3693 to 3701: 7867 to 7877 outside shadow
RAM. The diff of elite-source.asm and elite-data.asm against Mark's went
from 8249 lines (git diff --numstat, added + deleted) to 8223.

**Checks.** At each commit the gate; streams.py's checks and bankcheck at
every build. At the end: test_raster (full); the lens flare's pixel check,
four scenes, 704 frames (552 flared), 0 errors against the model, every
frame byte for byte e932f77's; the agentplay repros with --cand and --csyms
spelled out (compass, LOOK1, MSBAR clean; TTX66 as before, P+3 at its last
iteration); the quick campaign, 3 sessions clean (4644 iterations compared,
with a save and a load); the docked screens (harness/mdocked.mjs) byte for
byte e932f77's apart from the title ship's rotation phase; gcreach.py: 0
unreachable, every profiled PC matched.
