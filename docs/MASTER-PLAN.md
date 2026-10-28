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

* Planet meridians are drawn as the demo port's beach ball (branch
  beachball, BEACHBALL-REPORT.md), from the meridian window in bank 7; the
  planet's spin (1/16 radian an iteration) shows in steps, one frame in
  MERIDHOLD + 1 (3: four), where the demo showed it every frame.
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
tools/flare.py, which is master/tools/flare.py here), ported with the same
recipe, arithmetic and pixels: when SUN has drawn the sun this frame, in
the front view (VIEW = 0), with its centre on the screen (x 1..255, y
0..191) and not inside the planet's disc (F_HW, the planet's half-widths),
eight ghosts at C + k D / 8 (C = (128, 96), D = sun - C, k = 8, 5, 3, -1,
-3, -4, -6, -8): six dithered discs and two dotted rings (the one round
the sun only for a sun of radius 26 or less). Each disc pixel of its 4x4
Bayer mask is ORed in its ink (OR lifts K = 00, C = 01, M = 10, Y = 11
upwards: additive light); three levels by |dx| + |dy| (< 96, < 192, more)
step every density down the ladder 0 1 2 4 6 8 / 16. It is drawn after the
lasers and before the text, sights and stars, and every span extends this
buffer's dirty extent for its row (the rows' range goes to R_MARKDIRTY),
so the next frame on this buffer repairs it like any other shape. It never
touches game state.

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
build without the flare with the model, master/tools/flare.py, applied): 0
pixels differ from the model over 704 frames (514 with the flare: levels
1, 2 and 3, the sun behind the planet, leaving the screen), apart from
text, sights and stars drawn after it; every frame without the flare is
byte for byte the other build's (no residue); game state identical.
Screenshots: /Users/ebenupton/elite-full/screenshots/flare/ (montage.png,
compare-*.png: port | model | differences, display-*.png: jsbeeb's
display).

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

## The hangar (after the far-call stubs inline)

The ship hangar, shown on docking (DOENTRY's HALL), was the last screen with
ships that Master's direct drawing still drew: HALL and HAS1 drew up to
three ships with LL9 as wireframes, and HANGER drew the hangar's lines in
from the screen's edges until each met something already drawn. The user
asked for a filled version and, from drafts of several bay styles (grid
lines on black, blue and red dithered panels, tan panels with and without
lines), chose flat tan panels with HANGER's grid in black, without the
ships that blend into the tan.

**One frame of the renderer.** The hangar is a space-view frame
(gfx-hangar.asm, bank 6), drawn once:
* HALL stays in record mode (QQ11 = 0, GFORCE = 0). TT66 clears the screen
  as before, and the view's name it prints goes into the text map;
* G_HANG0 (high code) empties the frame's lists, as a docking leaves the
  last flight iteration's records in them, and sets the hangar's light
  (LLT: the title screen's, from the top right and the viewer);
* HAS1 places each ship as before and calls LL9 through G_HLL9, which sets
  TYPE (the renderer takes a ship's faces by TYPE, and HAS1 sets only XX0:
  G_HLL9 finds the type whose XX21 entry is XX0) and, for the two types that
  blend in, the type and blueprint drawn in their place (below), and puts
  TYPE and XX0 back afterwards. LL9 records the ship (H_EE31), lit as in
  flight;
* HALL ends with G_HANGAR in place of HANGER: it runs F_FRAME once with its
  call of f_lines (ff_lin) pointed at f_hback, and back. f_hback draws the
  background after the (empty) disc layer and before the ships, so the ships
  hide it where the original's lines stopped at them; the frame then flips to
  buffer 0, and the next TT66 goes back to direct mode as after any space
  view. The flight's frames run exactly as before: nothing is tested on
  their path.

**The background** keeps HANGER's geometry. The wall, from row 16 to the
floor's furthest line, is a darker tan, two yellow, a magenta and a black
pixel in each 2x2 cell (RGB about 191, 128, 64); the floor below it a light
tan, two yellow, a magenta and a cyan (about 191, 191, 128). Both are flat
R_POLY rectangles in f_col's packed colours; ink counts in quarters make
f_col's 4x4 Bayer tile a 2x2 one with yellow on a diagonal, a regular
pattern that neither shimmers nor bands. Over them, in black, the floor's
11 lines at #Y + 130 DIV Q, Q = 12 to 2 (HFY, as HANGER's DVID4K computed
them), x = 2 to 253, as one-row R_POLY rectangles (R_LINE costs about 80
cycles a pixel), and the wall's 31 lines every 8 pixels, x = 8 to 248
(R_LINE). Rows 1 to 15 stay black: TT66's yellow view name, on the tan
(half yellow), was nearly invisible; on the black band it reads as in
SNG47 (screenshots/hangar/title-before-after.png in the main worktree).

**HAZEL's &DF00 page is the MOS's.** The tables (HFY, HPWL, HPWH: 15
bytes) are in HAZEL between the game data and HANGHEAP (gfx-hangar-hz.asm),
as bank 6 is full. A draft put them after HANGHEAP, at &DF00, which the
MASTER-MAP counted free since d23e427: the loader then copied them over the
MOS's current FS numbers and filing-system names (&DF00-&DF47,
docs/MASTER-MEMORY.md), and the agentplay repro msbar-carry hung in DFS on
its first disc command. HAZEL.bin ends at &DEFF again, and the map now says
that &DF00-&DFFF is not for the game's data.

**Ships that blend in.** Every type was rendered at the four groups' places
(harness/mhangar.mjs, master/tools/hangarinks.py: 12 placements each) and
its pixels compared with the empty hangar. The Sidewinder's and the Mamba's
faces are dithered from yellow, magenta and black alone (yellow 48% and 60%
of their pixels, cyan 0% and 4%), the wall's own inks, and they read as the
wall's texture; every other type HALL can choose has 20% (the Krait) to 64%
(the Viper) cyan. (A blurred colour difference ranks them mid-table, dE 51
and 61, as their yellow faces are light: it is the texture that hides them.)
G_HLL9 draws them as the nearest types of their size class (HAS1 places a
ship by its targetable area) that stand out, through HSUB (high code): the
Sidewinder (area 4225) as an Asp Mk II (3600), the Mamba (4900) as a Viper
(5625). HALL and HAS1 run as before, with the same random numbers, and
place the ship by its own type's size: a draft that swapped the type in
HAS1 placed it by the substitute's size, which left INWK+3 different from
the original's after a docking (the msbar-carry repro diverged there,
though the gate's run did not see it). HATB is unchanged, as none of its
ships blends.

**Removed.** HANGER, HAS2, HAL3, HAS3 and DVID4K (only HANGER called it) are
unreachable and gone, each with a "Port: removed" note under Mark's header;
HANGFLAG is still set by HALL and read by nothing. HANGER's far7 stub went
from the head, so CODE% moved up five bytes, to &1EDC, keeping the font page
aligned. gcreach.py: 23390 instructions, 0 unreachable.

**Known.** A ship whose LL9 visibility cutoff (XX4) leaves some of its face
vertices unprojected is not drawn by the frame layer (f_ship's F_SX4 test, as
in flight): the furthest canister of HATB's second group is missing, where
SNG47 draws its edges.

**Time.** HALL to its DELAY, over the eight standard configurations
(harness/mhangar.mjs): 0.43 to 0.76 s, against SNG47's 0.25 to 0.63 s; the
frame itself 555,000 to 639,000 cycles (0.28 to 0.32 s), of which the wall's
lines (R_LINE) are about half. The flight loop is unchanged (17.24 it/s).

**Bytes** (against 9905a11; MASTER-MAP, "Free space"): bank 6 181 (4 left),
the high code 121, HAZEL 15; the cold area gained 251, the main code 5 and
the shared workspace 5: 56 bytes in all.

**The redock regression's timings.** The gate's redock (harness/mredock.mjs:
real key presses at fixed emulated times, the docking computer) docks after
26 s and 71 s on full-master, and after 26 or 55 s and 49, 51 or 71 s on
these commits; once (55 s, 51 s) with the legal status Fugitive at the
second docking. It is the key timing, not a change of behaviour: on
full-master (9905a11), starting the same key presses 0.01 to 0.3 s later
gives 26 or 55 s for the first docking and 47, 49 or 71 s for the second; a
commit that only removes unreachable code moved the result from (26, 71) to
(55, 51); on these commits, the same offsets give (26, 47), (55, 49) and
(55, 51), Fugitive only with (55, 51); and the Fugitive status is FIST's bit
6, set at MA15 when a cop is destroyed, here a Viper rammed on the docking
computer's approach (the test presses no fire key). The game-state
comparison, which replays its inputs in step, is identical at every commit.

**Commits** (each gated by master/tools/grind/verify.sh: game state
identical at all 10000 iterations, which include a docking and so a
hangar; 1.234, 17.24 it/s): 9a00795 harness/mhangar.mjs; 790104c the hangar
drawn by the renderer; 81559c5 the wireframe hangar's routines removed;
c58af4f the Sidewinder and the Mamba drawn as an Asp Mk II and a Viper;
6ef952b the view's name on a black band; then these docs. (The Front View
fix that came first, ddf5b3e: HALL set GFORCE after TT66, so the name went
into the text map and was never drawn.)

**Checks** at the end: test_raster (full) passes; the lens flare's pixel
check, four scenes, 704 frames (532 flared), 0 errors against the model,
every frame byte for byte 9905a11's; the agentplay repros with --cand and
--csyms spelled out: compass, LOOK1 and MSBAR clean (msbar-carry, 9031
iterations, docks), TTX66 as on 9905a11 (P+3 at its last iteration); the
quick campaign, 3 sessions clean (4644 iterations compared, with a save
and a load); gcreach.py: 23406 instructions, 0 unreachable.

## The briefings (after the hangar)

Mission 1's briefing (BRIEF, then PAUSE and PAS1 through token 10's two
"{display ship, wait for key press}" codes) was the last place where a
ship was drawn directly: the Constrictor turning in view types 13 and 1,
drawn by LL9 as a wireframe and erased by EOR through its ship line heap.
It is the only briefing or debriefing with a ship: DEBRIEF (token 15),
BRIEF2 (11), BRIEF3 (222) and DEBRIEF2 (223) are text with PAUSE2 key
waits, and no other code uses PAUSE or PAS1 (the token tables: EJMP 22
appears only in token 10). The user asked for the briefing's ship to be
drawn by the renderer, and then for the direct drawing of ships, which
nothing else used, to go.

**One frame of the renderer per LL9.** BRIEF, PAUSE and PAS1 call LL9B
(bank 4, after LL9F) where they called LL9: QQ11 is set to 0 while LL9
records the ship and F_FRAME draws it (LL9F, as the title screen does),
and put back afterwards, so QQ11 is the original's whenever game code
reads it (nothing in the briefing reads it but the hooks and the frame).
LL9B returns LL9's C, X and Y (hframe keeps them; MVEIT and MT23, which
follow, start with LDA). The first frame after each TT66 (BRIEF's TT66(13),
PAUSE's TT66(1)) enters space mode as after any docked screen (f_enter2:
the direct-mode stars, a disc command's stash in buffer 0, GSTASH, the
border copied); from then on the frames flip between the two buffers and
H_VSYNC shows the front one (GMODE bit 7), with the dashboard split as in
flight; PAUSE's TT66(1) and BAY's status screen go back to direct mode as
any TT66 does.

**The text around the ship.** The briefing prints its text with QQ11 = 13
or 1, outside record mode, while the frames are running: CHPR would draw
it into shadow RAM (buffer 1) behind the frame layer's back. So H_CHAR
(low area) and f_sync (bank 6) treat space mode as record mode: with GMODE
bit 7 set the character goes into the text map only, and the frames draw
it (in both buffers, over the ship). Everywhere else GMODE bit 7 at a text
change implies QQ11 = 0 and GFORCE = 0 (a TT66 always clears GMODE, and
F_FRAME enters space mode only when QQ11 = 0), so nothing else changes.
The text in the frames is in colour 3, as Master's direct text in the
port's palette; the clear of PAUSE's TT66 shows for a frame, as in SNG47.

**Timing.** The logic is the original's: 64 turns (BRL1), the climb until
z_lo wraps (BRL2, 127 turns), then PAS1 until a key is pressed and
released. A turn takes longer, as the Constrictor close up (z = 256 to
512) is a large polygon load: 68, 53 and 56 ms (BRL1, BRL2, PAS1) against
SNG47's 46, 39 and 42 ms and the wireframe port's 42, 35 and 36 ms; BRIEF
to the briefing's text 13.2 s against 10.1 s (harness/mbrief.mjs). The
profile of BRL1 and BRL2 is the rasteriser's (r_e8 12%, r7_rowrep 7%,
phase B ...), with no wait for the flip. In agentplay's lockstep replays
the number of PAS1 turns before each key is the reference's, read for
read, so the game state is the original's whatever the speed;
harness/mbriefcmp.mjs finds the ship's INWK identical at each of the 247
LL9 calls before the first key press in both machines.

**The direct drawing of ships removed.** LL9's callers are now the flight
loop's MA8 (QQ11 = 0), LL9F (the title and the escape pod, QQ11 = 0),
G_HLL9 (the hangar, after TT66(0)) and LL9B, never with GFORCE set (only
HFS1's rings set it): every LL9 records. So EE31 jumps to H_EE31, which no
longer tests for record mode; the rest of part 9 (the enemy's beam on the
heap), part 10 (the edges clipped and put on the heap), part 11's edge
loop, LSPUT, LSCLR's erase loop and SHPPT's dashes (Shpt) are removed,
each original routine with Mark's header and a `Port: removed` note;
H_LSCLR and H_SHPPT are gone (SHPPT calls G_SHPPT). LSCLR returns as LSC2
did (A = 1, Y = 0, C set: LL9's callers go on to DORND, which takes in C).
Nothing writes the heap's byte #0 but DOEXP (H_EE31 and H_LSCLR wrote 1
there only so that a later direct-mode LL9 had nothing to erase), and LL9
no longer reads it into LSNUM2; LSNUM and LSNUM2 are unused, kept in place
in zero page; part 1 keeps the Y = 0 that set-up left for EE51's RTS. The
explosion clouds (bytes #0 to #6 and the vertices) are written and read as
before, and the heap's allocation (NWSHP's INWK+33/34 and SLSP) is the
original's: it is game state (a full heap stops NWSHP). CLIP stays (the
enemy's beam in H_EE31, BLINE's CLIP2), as do LOIN and Master's other line
and text drawing for the docked screens. gcreach.py: 23198 instructions, 0
unreachable; in analyse.py's model no instruction refers to LSNUM or LSNUM2
and the only (XX19) accesses are DOEXP's, PTCLS's and LL9's explosion
set-up.

**HANGHEAP.** As LL9 writes no ship line heap for the hangar's ships, HAS1
no longer points INWK+34 at HANGHEAP around its LL9: it keeps the
original's LDA #&0B : STA INWK+34 (&0B00 is in WP in the port, but nothing
uses it) and ends with a tail call again (JMP G_HLL9 for JMP LL9). The
page is free; HAZEL.bin ends after the hangar's tables (&DDF3), and the
build asserts that HAZEL's contents end below &DF00, the MOS's page.

**Bytes** (against b583ecc; MASTER-MAP, "Free space"): bank 4 353 (367
removed, LL9B 11 and the LDY #0 2 added: 2057 free), the high code 48 (1244),
HAZEL 256 (268), the main code 4 (HAS1 9, H_CHAR's test 5 in the low area:
192), bank 6 1 (f_direct0's needless save of Y, 6, paid for f_sync's test,
5: 5 free); 662 bytes in all. Bank 6 stays nearly full.

**Speed.** The gate's flight run: 115980 to 115935 cycles per iteration
(profile.mjs --pagex: 41 fewer in instructions, H_EE31's record-mode test
gone, and 4 fewer in page crossings, 671 to 667), 17.24 to 17.25 it/s;
ratio 1.235.

**Commits** (each gated by master/tools/grind/verify.sh: game state
identical at all 10000 iterations, test_raster --quick, redock, savetest
and views pass): ae7b96a harness/mbrief.mjs, mbriefsheet.mjs and
mbriefcmp.mjs (no change to the build); c4c27ae the briefing's ship drawn
by the renderer (1.234, 17.25); 5c20230 the direct drawing of ships removed
(1.235, 17.25); 067b7eb HANGHEAP and HAS1's workaround removed (1.235,
17.25); then these docs.

**Checks.** The agentplay sessions that reach the briefings, replayed in
lockstep against SNG47 with --cand and --csyms spelled out, all clean (on
5c20230; the two marked also on 067b7eb): campaign2's deadly-s43* (BRIEF,
23184 iterations, 32240 reads), debrief1-s42 (DEBRIEF, 9949), galaxy3-s40*
(BRIEF2 and BRIEF3, 22425), galaxy3-s41 (BRIEF2, 19952) and debrief2-s52
(DEBRIEF2, 12397), campaign1's deadly-s9 (BRIEF, 16523) and mission2-s10
(17287). At the end: test_raster (full) passes; the lens flare's pixel
check, four scenes, 704 frames (532 flared), 0 errors against the model,
every frame byte for byte b583ecc's; the repros: compass, LOOK1 and MSBAR
clean (msbar-carry 9031 iterations), TTX66 as before (P+3 at its last
iteration); the quick campaign, 3 sessions clean (4644 iterations); the
sheet and movies at ~/elite-full/screenshots/briefing (sheet.png: SNG47
beside the port at BRIEF's turns, its climb and every key wait of the five
briefings and debriefings; brief1-ref.mp4, brief1-cand.mp4 and
brief1-side.mp4, every frame from the ship's first to the status screen,
x2); the trial disc ~/elite-full/elite-master-full-briefings.ssd.

## One run from &7000 (after the briefings)

The user asked for the high code's stubs and hooks to move to the low area
and for the high code to join bank 4 (and HAZEL after it) as one long run:
main RAM from &7000 is never on show (the dashboard is shown from shadow
RAM) and bank 4 is paged whenever game code runs, so &7000-&BFFF is one
stretch of code for the game, followed by the game data in HAZEL at &C000,
as the original's BCODE is followed by BDATA.

**What moved.** The G_ stubs (gfx-gstubs.asm) and the hooks in Elite's
drawing code (gfx-hooks.asm), 826 bytes, went from the high code to the
low area (elite-low.asm), after the text and IRQ hooks: below &3000 they
are visible with any bank paged, which is all they need (they run in game
context, X = 0). That left 545 bytes of the head's room below &3000.
The quarter squares (1K) and the lighting's game half (L_SUN, L_REC and
their tables, 1002 bytes) stay at &7000-&77E9: both must be visible with
bank 4, 6 or 7 paged (the frame layer calls the lighting with bank 6 in,
and the quarter squares' users run under all three), and together they do
not fit below &3000. The run's marker moved from STARS2 to TACTICS: the
run stops below buffer 0 at HAS1's end, continues at &77EA with TACTICS
(ORG &7000 and the INCLUDE of elite-hi.asm are in the marker's banner),
and runs on across &8000 into bank 4, where the blocks tagged bank 4
follow it as before. HICODE is now main RAM &7000-&7FFF whole (the high
code and the run's part there), BANK4 bank 4 as before.

**Why TACTICS.** The marker needs a routine boundary that nothing falls
into or branches across, at which the run before it fits below &4000.
TACTICS's seven parts branch into one another (part 2 back into part 1,
parts 4 and 5 forward into part 6), so it moves as a whole; with it below
&4000, the next boundary, DOCKIT, overflows by 24 bytes. So 639 bytes are
free at the marker, below &4000, and 2854 at the run's end in bank 4: the
same 3493 as before (192 in main RAM, 1244 in the high code, 2057 in bank
4), now in two places instead of three.

**X = 1.** Code in main RAM at &3000-&7FFF must never run with ACCCON X
set. The run's part below &4000 was already there; the part moving from
bank 4 to &77EA-&7FFF (TACTICS to the start of STARS2) is untagged code,
and only the blocks tagged bank 4 run with X set: XTRACE (harness/mlib.mjs,
an environment variable naming a file) records every instruction address
run with X set, and over the gate's runs (the 10000-iteration comparison,
the redock, save and views regressions) none is in main RAM &3000-&7FFF,
before or after the move (17920 in all, all below &3000 or in a sideways
bank).

**Checks.** The gate (VERIFY PASS 1.235, 17.25 it/s, as before; game state
identical at all 10000 iterations); test_raster --quick; bankcheck.

## The lighting in bank 6 (after one run from &7000)

The user asked for room in bank 6 (the frame layer, 5 bytes free) so that
the lighting's game half (gfx-light.asm: L_SUN, L_REC and their tables and
variables, 1002 bytes), which the frame layer calls, could move there from
the high code, leaving the high code the quarter squares only. A survey of
bank 6 ranked the candidates; the user ruled out merging the planet's and
the sun's half-width tables (F_HW, F_HW2). What was done:

* **The planet's curve points** (MAXPT 140 to 40, 400 bytes): PLS22's step
  STP is at least 2 (CIRCLE's PL89), so a crater's full ellipse has at most
  33 points and the meridian and equator's half ellipses 17 each (the
  gate's peak is 33); a point past the end is dropped, as before.
  f_segment's fsg_up and fsg_ry are no longer in one page, so fsg_jj's
  patch writes both bytes of its target (10 bytes).
* **The shown text maps.** F_SH0 and F_SH1 (768 bytes each: the character
  each buffer shows in each cell) became F_ST (768: a state byte per cell,
  at F_TM + &300). For buffer b, bit b+2 (N) says it shows a character in
  the cell, bit b (M) that this is the cell's character; and a cleared cell
  of F_TM (f_clrtext0, f_delchar0, f_char0's second print, f_tmclear) keeps
  its character as &80 + it, so M still says whether a buffer shows it.
  f_text1 erases where a buffer shows a character that is not the cell's
  (N, and not M or the cell empty), f_text2 draws a non-empty cell where it
  shows none; a cell given a new character (f_tmstore) clears M unless it is
  the one the cell has or remembers. So a cell cleared and given its
  character back, as TT66 and a view's title do, is left alone, as the
  original's shown maps left it: a first version, with a bit for "shows the
  text map's character" only, redrew the title after every view change
  (179 erases in 3000 iterations against 48) and cost 255 cycles an
  iteration. f_stset (f_sync) and f_stand (f_tmclear, f_enter, f_b0new) set
  or clear a buffer's bits for the whole map; f_clrtext0 skips the rows
  that are empty, and only marks the others' cells. The characters are
  &20-&7F (CHPR's, the font's), so bit 7 is free.
* **F_INIT in F_DL** (gfx-finit.asm, 79 bytes): it runs once, from the
  loader, before the first frame, and keeps Elite's &06-&27 in F_DL's first
  34 bytes, so it is assembled after them; from the first frame on F_DL
  holds the ship records.
* **Three keep-in-place pads** (6 bytes) and F_CPO, the same bytes as F_CPE
  (7), now an alias.
* **The lighting** is INCLUDEd after the lighting tables; its eight reads of
  QSL/QSH are marked "bankcheck: ok" (L_SUN runs before F_FRAME sets ACCCON
  X, L_REC from F_SHIP in game context). F_HANG0 sets the hangar's light
  (LLT, now in bank 6) that G_HANG0 used to set.

Bank 6 has 71 bytes free, bank 4 3856 (the run starts at &7400, after the
quarter squares), the main code 653: 1082 bytes more outside shadow RAM.

**Cost.** 57 cycles a flight iteration (115987 against 115930, profile.mjs:
17.24 it/s against 17.25), well inside the exchange rate for 600 bytes:
the text steps' masks, patched each frame (about 38), and f_text1's row
loop, whose two branches now cross a page (about 46, an alignment
candidate), less what f_stand saves on view changes, with the page
crossings in the run's code, which moved by 1K, about even (657 cycles an
iteration against 656). Entering a docked
screen's text (f_tmclear's 768 cells) takes 10 to 20 ms longer.

**Checks.** The gate (VERIFY PASS 1.234, 17.24 it/s; game state identical
at all 10000 iterations); XTRACE: nothing run with X set in main RAM
&3000-&7FFF; mfbcmp over the gate's run, 3000 iterations, every fifth
frame's buffers byte for byte 5b7b91e's (587 frames; it caught a bug the
gate cannot see, as the text map is not game state: f_clrtext0's new code
used f_tmp, which holds its last row, and cleared rows past it); mbrief,
every briefing's and debriefing's key-wait and end screens identical to
5b7b91e's.

## Three passes (after the kept solid rows, 87cf524; branch threepass)

The original's source is emitted in three passes, each in the source's
order: **low** (Elite's code that must be below &3000), **hot** (the rest
of the game code, flowed through main RAM and then bank 4) and **cold**
(bank 7). docs/MASTER-MAP.md, "The source and its passes" and "Calls between
the passes", has the result. What changed, commit by commit:

* **The glue area** (c9f534a): the port's own code below the head was the
  "low area"; it is the glue area (elite-glue.asm, gfx-gluehooks.asm), so
  that "low" names the pass. It is first at CODE%, below the low pass.
* **Three passes, the hot pass flowed** (8acb21a): one rule instead of the
  run, the low area's two blocks, the "bank 4" blocks hoisted after F% and
  the marker before TACTICS. The head's blocks are tagged low, stackpt and
  NEWBRK join them, and Master's drawing and dashboard blocks are ordinary
  hot blocks tagged "Area: hot, ACCCON X", which the flow puts in bank 4.
  streams.py measures the hot pass (elite-measure.asm) and flows its units
  (runs of blocks that fall or branch into each other) through main RAM to
  &4000, main RAM from &7400, then bank 4: the old layout came out, in the
  new form.
* **The low pass, only what must be low** (7840b34): VEC, T1SYNC, pxpatd,
  pxpat, HANGFLAG to the hot pass; ADDK and the log tables (which align
  themselves now; the flow is alignment-aware) to bank 4 as ACCCON X. 1207
  bytes below &3000 for the stubs.
* **Fast direct stubs** (4d020cb): one stub per target in the glue area (JSR
  to7 : JSR X_C : JMP to4), 85 cycles a crossing against the far calls'
  171; elite-far.asm goes. The cold pass calls the low routines that need
  nothing of the hot side directly. TTX66M keeps the caller's bank for CHPR.
  The harness sees through a stub by its address range.
* **Checks the moves needed** (103e927, 9196653): a hot reference to a cold
  label must be a call, a jump or its address, as a stub has no data (QQ16
  was read through its stub); banks.txt names each label once, the game's
  first (a scoped .t2 in the rasteriser made TT217's t2 look like bank 5's,
  and the pilot waited at the Buy Cargo prompt).
* **Text hot** (540d423): the token and number printers (TT27, ex, BPRNT,
  MESS ...), QQ18, QQ16 and TKN2, which DETOK2 reads on into QQ16 ("Area: hot,
  runs on"). The hot data flows past HAZEL into bank 4 (QQ18, SNE, ACT).
  DETOK stays cold: its tables are 3.5K.
* **More hot by measured heat** (560d29e): master/tools/grind/crossings.py
  ranks the cold blocks by the crossings their move removes less those it
  creates; the positive ones whose neighbours allow it moved (ee3, MT14 and
  MT15, HFS2, Ze, FRS1 ... FR1, TT66 and TTX66K, TT69 and TT67, BAD, ESCAPE,
  TT24). TT20 and TT54 (the charts call them 256 times a screen) and TT111
  would create more than they remove.

**Results.** Gate: VERIFY PASS 13.97 11.99 0.858 (87cf524: 11.98, 0.857).
Flight 166769 cycles an iteration against 166935 (profile.mjs). Crossings
between the passes: 0.0149 a flight iteration and 3738 off flight, at 85
cycles, against 0.703 and 11455 at 171. The docked screens (harness/
mdocktime.mjs, the busy cycles from the key to the screen drawn): 5152363
against 5411007 (-4.8%), 3314.7 ms against 3454.6 ms. 373 bytes fewer free
outside shadow RAM (the stubs' 700 bytes more than the far calls, the log
tables' alignment), bank 7 2700 free (89), bank 4 810 (3853).

Page crossings (profile.mjs --pagex): 1108 cycles a flight iteration
against 1140 at 87cf524, 1421 off flight against 1697.

**Not done.** The alignment pass (the page crossings are measured, above,
but nothing was aligned). DETOK and its tables in the
hot pass would remove the docked screens' remaining DASC crossings, but
need 3.5K more of bank 4. INLINE stubs (70 cycles) are not worth it at
0.015 crossings a flight iteration.

## The 25 fps cap (after the three passes, e878d4a; branch cap25)

The double-buffered space view is capped at 25 frames a second: a frame is
on show for at least two fields. Before, a frame quicker than a field was
shown for one field and the next for two or more, so motion judders, and
10.7% of the gate's frames were shown for a single field (1062 of 9929).

**How.** H_VSYNC (gfx-gluehooks.asm), which the vsync interrupt calls every
field, holds a pending flip for one field when the vsync before it flipped
(GVLAST, set at a flip and cleared at every vsync that does not flip). The
wait is at the flip only: F_FRAME queues the flip and returns, the next
main-loop iteration's game code and its frame's set-up run, and only the
drawing waits (F_FRAME's existing wait for GFLIP before it touches the back
buffer). A frame slower than two fields flips at the first vsync after it
is queued, as before. Cost: 4 cycles at a vsync with nothing to flip, 15
at a flip, 1 fewer at a held flip; 13 bytes and one variable in the glue
area, with CODE% 14 bytes lower (&1E16) to keep the font page aligned, so
nothing after the glue area moved. The timer 1 split is untouched
(irqprobe over the gate's 10,000 iterations: late 0, early 0, T1 latency
p99 51, max 53).

**Every flip follows it**: the flight loop, the escape pod's drift, the
title screens and the briefing's Constrictor all flip through F_FRAME and
H_VSYNC. The docked screens draw directly and never flip (QQ11 non-zero:
F_FRAME only empties its lists), and the hangar flips once a visit. The
title's ship is the one visible difference outside flight: its approach
from z = 96, quicker than two fields a frame while the ship is small, ran
at about 48 frames a second for the first second and now runs at 25, so it
arrives in about 3.5 s rather than 2.3 s (the original, drawing wireframes,
takes about 1 s); from then on the title runs below 25 frames a second and
is unchanged.

**Measured** (harness/mflips.mjs: each flip's interval in fields over the
gate's 10,000 iterations, flown as the gate flies them):

| | e878d4a | cap |
|---|---:|---:|
| frames shown 1 field | 1062 (10.7%) | 0 |
| frames shown 2 fields | 1608 (16.2%) | 2741 (27.6%) |
| shown 3 fields or more | 7259 (73.1%) | 7186 (72.4%) |
| mean (fields; frames a second) | 4.28 (11.7) | 4.38 (11.4) |
| approach / combat / hyperspace, frames a second | 13.0 / 7.8 / 8.3 | 12.7 / 7.7 / 8.1 |
| verify (ref, cand it/s, ratio) | 13.97 11.99 0.858 | 13.97 11.73 0.840 |
| docked screens' busy cycles (mdocktime) | 5152363 | 5153018 (+655: 4 a vsync) |

The game state still matches SNG47 at every iteration (the cap changes
only when frames are shown, and the game is iteration-driven), and the
pilot's run takes 902.1 emulated seconds rather than 881.5. A dozen
intervals in each run span a vsync interrupt held off for over a field,
before and after alike; mflips lists them, and they only lengthen a
frame.

**Checked**: test_raster seeds 1-14, master/verify.sh (above), irqprobe,
mdocktime, and an agentplay campaign against SNG47 with fresh seeds
(6000-6103: flight, combat, docking, the docked screens and the disc
menu): 19 sessions, 256 game minutes, 207,193 iterations compared, no
findings, 163 save-file checks identical.

## The planet's z in the depth test (after the 25 fps cap, e695bc2; branch planetz)

A ship drawn with faces is hidden when it is further away than the planet
and the first vertex of its first visible face is inside the planet's disc
(f_behind, gfx-frame.asm; since e1aa028, 2026-10-15, "Depth: hide ships
behind the planet"). F_PLANET recorded the planet's z as (INWK+7 INWK+6)
only and dropped INWK+8, so a planet 65536 or more away read as its z less
65536. A ship drawn with faces is always nearer than 4096, so the station
was hidden whenever the planet was 65536-69631 away and the station was
over its disc: typical on a docking run with the planet behind the station
(found on the Tube build, branch stationfix f05ec0e; the user's save state
had the planet at z = &10636, read as 1590, and the station at 3619).

**Fix.** A planet with INWK+8 non-zero is recorded with z_hi = &FF, further
than any ship drawn with faces (the Tube's f05ec0e code, without its
_TPART = 1 condition). 6 bytes in bank 6 (12 to 6 free); bank 6's labels
after F_PLANET move up 6, and outside bank 6 only the G_ stubs' targets
and the loader's bank 6 length change. CODE%, the glue area, the three
passes and the font are where they were.

**Regression**: harness/mstation.mjs (in master/verify.sh) puts the save
state's ship slots into a freshly launched game, as the Tube's tstation.mjs
does, and checks that every frame recording the station draws it: before,
0 of 8; after, 8 of 8.

**Checked**: test_raster seeds 1-14; master/verify.sh: VERIFY PASS 13.97
11.73 0.839 (game state identical to SNG47 at all 10,000 iterations, page
&0D, redock, save/load, station, views); irqprobe: split late 0, early 0, T1
latency p99 51, max 55 (55 before as well, in buffer 1); mdocktime
5,153,381 busy cycles (5,153,018; +363, bank 6's code after F_PLANET moved
6 bytes); an agentplay campaign against SNG47 with fresh seeds (7000-7103:
docking, flight, combat, the disc menu, loads): 15 sessions, 199 game
minutes, 164,232 iterations compared, no findings, 134 save-file checks
identical. Over run1 (scratch/curious/run1, the Tube's pixel oracle) the
frames change only in iterations 13973-14037: the station, a few pixels at
the sights during a docking run, is now drawn in front of the planet (the
fix's build and the Tube tree's Master build with it give the same pixels
there; screenshots/planetz).

## Lessons from the Tube (after the planet's z, edd060d; branch lessons)

The Tube build (branch dumbhost, TUBE-REPORT.md) measured and tried
things on its parasite and hosts that this port shares or could share.
Each was judged here, measured on this port, and made where it won
(LESSONS-REPORT.md in the branch's worktree has the numbers in full):

* **Two boundaries a row, not four** (the disc layer's per-buffer state
  for the beach ball): over the gate's run 2.5% of a beach ball's rows
  have three boundaries and 0.004% four; keeping two, with an unknown
  count for more (a full repaint next time), costs less than the stores
  and loads of the other two: the gate's beach rows -1.8%, run1's beach
  windows +0.6% and +2.1%, and bank 5 1,039 bytes freed. (Three
  boundaries was measured too and is slower.)
* **One-colour rows of a two-colour frame** (the Tube's R_BST) were
  already drawn as changes here; colour B rows and rows the disc leaves
  took slow paths, now r_dp2's: the gate's beach rows -0.9%.
* **The ships' edge lists** are read by nothing (a read watch over the
  gate and the forced paths): 2,596 bytes of HAZEL; the hot data now all
  fits there, so bank 4 has 1,850 bytes free and HAZEL 1,919.
* **ACCCON**: no whole writes in the game (TSB/TRB of X and E, as the
  original's comments say), the loader's masked: ITU and IFJ are kept.
* **The span core's trims**: r_spc had them; phase B's empty-run test
  went (docking -0.46%).
* **BREAK**: the port hung in the MOS's reset after BREAK or SHIFT+BREAK;
  with *FX200,3 BREAK is a power-on reset and SHIFT+BREAK reboots the
  game, as the original does.
* **Not done**: full STA runs, one page a line (37.6K, or 48K page per
  line, against about 7.7K free in all; at most 3.5% in docking, 0.2% in
  flight, 1 cycle a byte stored); one-pass polygons (rejected before).

## The lens flare and occlusion (after the lessons, fa36d40; branch flarevis)

The flare used to be all or nothing on one test: the sun's centre on the
screen and not inside the planet's disc. A ship in front of the sun, the
planet over most of it, or a sun half off the screen still got the full
flare. Now R_FLARE (gfx-flare.asm, bank 5) first looks at the back buffer
as drawn so far, at nine points of the sun's disc. These are the centre and
eight points round it at about 0.62 R (left, right, up, down and the
diagonals; offsets a = R/2 + R/8 and b = R/2 - R/16, with R capped at 127).
The planet, ships, dots and lasers are drawn by then; the text, sights and
stars come after the flare.

* A probe outside the clip window (x 2..253, y 1..191) is out of sight.
* A probe inside is in sight if its pixel is still the sun's colour for its
  row: FC_SUNE on even rows, FC_SUNO on odd ones. A dithered row is compared
  with its own colour byte, pixel by pixel (fl_pxm).
* ACCCON X is as the frame layer has it, so the reads see this buffer.
* None in sight: no flare, and nothing marked dirty. In K mode the kept rows
  are forgotten only when the flare draws (k_clear moved from T_FLARE into
  R_FLARE, after the probes).
* Otherwise every ghost's density steps down the ladder by 0 (all 9 in
  sight), 1 (7 or 8), 2 (4 to 6) or 3 (1 to 3) more rungs (fl_vred). fl_lev
  now holds the level less 3 less that, and the ghost's density is its index
  plus fl_lev.

f_flt's tests in bank 6 are unchanged: the front view, the centre on the
screen, and the centre not inside the planet's disc. (When the planet is
the bigger disc, the sun is drawn over it as the secondary disc, so the
probes alone would see it.)

Space: the probes are 184 bytes in bank 5's shared region, which had 107
free. R_LINE's cold part (gfx-raster_lcold.asm, 188 bytes, with the
rasteriser's private state) moved to the room below the per-x tables:
elite-gfx.asm assembles it from r_tfree after a CLEAR. The shared region
then has 111 free, and the room below the tables 620. The glue is 8 bytes
shorter (T_FLARE's K-mode test), and the font's padding takes them up.

Cost: the probes take 1,200-1,280 cycles a flared frame (636-960 when the
sun is half off the screen; up to 1,450 when an interrupt lands in them).
A fully hidden sun's flare now costs about 1,440 cycles, against
14,000-28,000 for a drawn flare, before the repair the next frame on the
buffer would need. Nothing on the gate: its pilot never has the sun in front.

Scenes (harness/mflarevis.mjs, the gate's pilot, then the sun placed on a
path; master/tools/flarevis.py draws the dumped back buffers):
screenshots/flarevis/planet-full-reduced-off.png (the sun sliding behind
the planet: 9, 6, then off by f_flt's centre test),
ship-full-reduced-off.png (an asteroid across the sun: 9, 4, 0),
edge-full-reduced-off.png (the sun leaving the screen: 9, 6, 3, then off),
ship-hidden-before-after.png (the same hidden frame before and after).

Seen in passing, and not changed: when the planet is hidden in one step
while the sun stays (scene.mjs --hideplanet), planet-coloured pixels stay
on the sun's disc for many frames. fa36d40 does the same.

**Checked**: test_raster seeds 1-14; master/verify.sh: VERIFY PASS 13.97
11.82 0.846, as before (game state identical to SNG47 at all 10,000
iterations; redock, save/load, station, views); irqprobe: split late 0,
early 0, T1 latency p99 51, max 57 (fa36d40: the same); mdocktime
5,157,674 busy cycles (fa36d40: the same); mflips min=2, the histogram
identical to fa36d40's.

## Saves byte-identical (after the lens flare and occlusion)

harness/msavetest.mjs only round-trips a save on our build.
harness/msavebytes.mjs makes the same commander on SNG47 and on the build
(new game, docked at Lave; CASH, fuel, two cargo bays and the legal status
poked by each disc's own symbols), saves it through the disc menu with real
key presses and compares E.TESTB, read from the emulated drive's image, and
its catalogue entry: identical (256 bytes, load and execution addresses
&0). master/verify.sh runs it with the regressions, with the discs and
symbols passed explicitly.

## HAZEL holds the game data only (after the saves)

HAZEL (&C000-&DFFF) holds the game data only: XX21 and the blueprints from
&C000 and the rest of BDATA's hot data. The renderer makes no use of it (no
code, tables, variables or stubs), and &DF00-&DFFF, the MOS's, is off
limits to everything. bankcheck.py fails the build on any label or
constant of elite-gfx.asm or a gfx- file in &C000-&DFFF, and on any label
in &DF00-&DFFF (docs/MASTER-MAP.md, rule 5). The test harness's stand-ins
at &DF00 are the test machine's only; bankcheck's stale gfx-kept-hz.asm
entry is gone.

## RUPLA, RUGAL and RUTOK in HAZEL (after the HAZEL rule)

The extended descriptions' overrides (RUPLA, RUGAL and RUTOK: 696 bytes of
elite-data.asm, read only by the cold pass's PDESC and DETOK3) have no
`Area: cold` tag: they are hot data, flowing into HAZEL after ACT
(&D781-&DA38), where the cold pass reads them as it reads QQ18. That gives
bank 7 their 696 bytes for the renderer. RUTOK uses the extended tokens'
macros (ETOK, ECHR ..., defined in the cold data's blocks), so
elite-layout.asm assembles HAZEL after the cold pass, as elite-measure.asm
does.

## The lens flare in bank 7 (after RUPLA, RUGAL and RUTOK)

R_FLARE and its tables (gfx-flare.asm, 1,014 bytes) are in the meridian
window in bank 7, after gfx-kept7.asm, with the half-width table fl_htab
and the flare's variables (74 bytes that were in bank 5's run pages'
tails), instead of at the end of bank 5's shared region, which they leave
to the second disc. T_FLARE pages bank 7 for R_FLARE, and does its two
bank 5 calls afterwards: in K mode k_clear (the flare's rows are not
kept), and R_MARKDIRTY for the rows written, which R_FLARE returns (C set:
the sun was in sight, Y .. X the rows). bankcheck checks gfx-flare.asm as
bank 7's, and build.sh's banks.txt lists it in bank 7 (with
gfx-raster_kept.asm and gfx-kept7.asm), for the harness. The pixels are
the same (harness/mfbcmp.mjs: 1,961 frames over 6,000 gate iterations, the
flare's windows included, identical).

## The lens flare's tables: flare.py (after the lens flare in bank 7)

gfx-flare.asm's tables come from the demo port's model, which is
master/tools/flare.py, with --tables (fl_rad, fl_ink, fl_ni, fl_mt, fl_dk,
fl_ring and fl_htab from its GHOSTS, LADDER, BAYER, RING and hw_table) and
--verify (the source's literal tables, and fl_htab as assembled into
MERID.bin, byte for byte: all identical); master/verify.sh runs --verify
after the build.

## L_SUN at bank 4's end (after flare.py)

L_SUN (the light towards the sun for the next iteration's ships) runs once
a space-view iteration in game context, before F_FRAME sets ACCCON X, and
reads only game state (K%, FRIN, ALPHA, BETA) and the quarter squares. It
is at bank 4's end, after the hot pass and the hot data, instead of in
bank 6: G_FRAME calls it with bank 4 paged (in a space view, QQ11 = 0),
before it pages bank 6 for F_FRAME, and G_HANGAR (the hangar's frame, from
HALL) calls it under the same test. Its result LLT, which L_REC reads in
bank 6, is in the glue area (gfx-gvars.asm, with its initial value).

gfx-light.asm stays one file, assembled in two passes: its L_SUN half and
its L_REC half are IF LIGHTPASS = 4 / 6 blocks, and build.sh writes a copy
for each pass (build/gfx-light-4.asm for elite-layout.asm and
elite-measure.asm, build/gfx-light-6.asm for elite-gfx.asm) with the other
block assembled out and the source's line numbers. L_SUN's scratch is its
own (lv_t, lv_s, in bank 4). streams.py keeps bank 4's room for the
renderer's routines there (R4_START% .. R4_END%), and the measure
assembles them once for their size. Bank 6 gains 649 bytes. The light is
the same: LLT at each of 2,938 frames of the gate's run as at b0abf71.

## One circle engine for the planet's surface (after L_SUN)

Every feature of a planet's surface is a circle on its sphere, the boundary
of {p : m.p >= d}: a meridian or the equator is a great circle (d = 0), a
crater a small cap, a band the region between two latitude circles about
the spin axis. The beach ball's code (PM_HOOK, PM_MERID) is replaced by one
engine (gfx-merid.asm) and a few lines of style each (gfx-planet7.asm):

* **pc_circ** (game context, from PF_HOOK) makes one circle's record (24
  bytes) from its axis, cosine and the body: the ellipse's a, K0, K2 and
  s0 (as the beach ball had them: pms_core is unchanged), its centre line
  C0 at the centre row Yc (to the nearest pixel, so that rows Yc +/- k are
  symmetric about it), and **two threshold rows**. Along a row f = m.p - d
  is concave on the visible hemisphere, so the X- crossing is a boundary
  iff f <= 0 at the row's left limb point, X+ iff at its right one, and the
  row starts in the region iff f > 0 at its left limb point; along the limb
  f changes sign only at the circle's two nodes, Ys = A -/+ sqrt(B)
  (A = m^y' d / q2, B = v (r^2 - d^2 / q2), q2 = m^x^2 + m^y'^2), each on
  the left limb or the right. So every per-row test becomes one rule: from
  the top of the disc, each node toggles one limb's flag (which one from
  the signs of f at the top and the bottom). For d = 0 this is exactly the
  beach ball's uP/uM rule.
* **PC_ROWS** (the frame) fills the rows with the base colour EOR the left
  limbs' toggles (one pass, a list of at most six toggle rows), then for
  each record walks k from Yc out, stepping D, s and C as the beach ball's
  loop did, with the flags of rows Yc + k and Yc - k recomputed only at the
  k where one changes (pr_seg: eight thresholds in k). A hidden circle (no
  node, the limb wholly inside) keeps no record.
* **The styles** are records and a base colour (PF_HOOK): the beach ball is
  the great circles normal to roofv and sidev with base 1 (colour B where
  the surface is on the same side of both).

The unit axis is m >> 3 times 2^24 over its nominal length (Elite keeps its
vectors of length &6000), not divided by its measured length; pf_tilt
shifts a magnitude before applying its sign, so a vector alone is exactly
halved. tools/planet_caps.py models the engine bit for bit.

PF_HOOK runs from H_CIRC through G_PFHOOK, in game context, and makes the
class (PF_CLS: 0 a meridian planet, 1 craters, 2 bands; bit 7 the detail
made this frame) and the records; f_bounds runs T_CAPS (PC_ROWS) when
PF_CLS bit 7 is set. Gone with the beach ball's own code: the held
orientation and row shifting (MERIDHOLD was 0), PM_OK, PS_VALID, PM_R,
G_MERHOOK, T_MERID.

The beach ball's rows are those of tools/planet_analytic.py pixel for pixel
(but for a pair of equal boundaries where both of a row's crossings meet,
which PM_MERID gave and the engine leaves out). The gate's run
(harness/mfbcmp.mjs, 3,000 iterations, every fifth frame, both buffers: 587
frames, Lave's beach ball and the crater system) is pixel for pixel as at
b0abf71. test_raster: merid (PF_HOOK and PC_ROWS against both models),
beachball, and caps (the engine alone: random circles). The beach ball's
hook costs a little more (22.7K to 25.5K cycles at Lave), its rows about
the same.

Keeping rows between frames would be cheap for a body whose records did
not change (the rows depend only on the records and the spans), but the
planet spins every frame, so it would only pay for a hidden or edge-on
circle; not done.

## Craters: spherical caps (after the circle engine)

A crater planet's crater is a spherical cap, {p : m.p >= r c}, a circle
record of the engine, its edge drawn where it is seen and cut by the limb
where it is not, in place of Elite's polygon (PL26's ellipse, recorded
point by point through BLINE and filled by f_seg16). There are up to three,
from the system's seed (QQ2; pf_craters, class 1, base 0): the first on
roofv, 30 degrees across, as Elite's crater (222/256 of the radius out,
half the radius across); then, as s2_lo bits 0-1 have it, one on nosev
tilted towards sidev and one on sidev tilted towards roofv (s2_lo bits 2-7:
signs and tilts; s2_hi bits 0-3: 15 to 30 degrees). No two axes are within
63 degrees, so they never overlap; if they did, they would combine as XOR.
Against the float truth (each pixel's point on the sphere) about 1% of
pixels are wrong, all within a pixel or two of an edge.

PF_HOOK runs for every planet. PL26 still computes its K2, K3, K4 and TGT
(MV40 reads K2); the crater's ellipse is no longer computed or recorded,
and BLINE no longer records points. Bank 6 loses F_PCURVE, F_PPOINT, the
curve and point arrays, f_zerobounds, f_seg16, f_segment and f_parity
(1,145 bytes), and the glue G_PCURVE and G_PPOINT.

Every planet has the beach ball's colours: colour A, the disc, is its sea
(FC_PLANE, FC_PLANO), and colour B, the detail, its land green (FC_PLLE,
FC_PLLO = &5F, &AF, gfx-frame.asm), so a crater planet is a blue body with
green craters (the polygon crater was dark grey, &50/&A0). The disc layer's
colour id is f_lay itself (1 the sun, 2 the planet).

Tests: test_raster's pfhook (PF_HOOK on random crater and meridian planets:
the class, and the rows against tools/planet_caps.py's pf_caps) and capball
(a spinning crater planet's rows through R_DISCROWS, pixel for pixel).
harness/mplanet.mjs poses planet scenes with the planet routines' cycles
(master/tools/planetvis.py draws them). mcompare --crater (the commander's
tech level made to give Lave a crater planet) keeps game state identical
for 1500 iterations; the gate's second system is a crater planet (two
caps), whose frames the gate flies for about 4000 iterations, and stays
identical to SNG47 there too.

## The original's planet maths: Area: none (after the craters)

With the circle engine drawing every style, the original's meridian and
crater path (PL9 parts 2 and 3, PLS2, PLS22 and its curve loop, pl4pat and
PLL4F, PLS3, PLS4, PLS5) only produced values the renderer ignores. Those
blocks are `Area: none` (streams.py: the text stays, each copy assembles
only the block's labels and an RTS, so a reference still assembles and
returns at once), and H_CIRC returns from PL9 itself in record mode,
leaving what the game reads of that path: K2 (MV40 adds it into the next
object's y without setting it; PLS1 of nosev_x, halved for a crater planet
whose crater faces us), TGT (31 or 64) and FLAG (0). The hooks H_MERID and
H_PCURVE are gone. Planets are never drawn outside record mode (GFORCE is
only set for the hyperspace rings, which use CIRCLE2), so the direct path
is never taken. Recovered: 682 bytes of the hot pass.

The planet's surface code (the engine, the styles and the glue, H_CIRC's
PL9 tail included) is about 3,830 bytes, against 3,431 for the beach ball
alone at b0abf71 (gfx-merid.asm 3,350, G_MERHOOK, T_MERID, H_CIRC's and
f_bounds' parts 81); with the original's maths that b0abf71 also emitted
(about 680 bytes, and its H_MERID, H_PCURVE and G_PCURVE hooks), the planet
path is about 320 bytes smaller.

## The sun near the planet (after the original's planet maths)

**Why the sun goes.** It is the original's slot sharing, not a renderer
choice. Elite has one slot, FRIN+1, for the sun and the space station
(SSPR's slot). Every 32 iterations, part 15 of the main flight loop
(elite-source.asm, before MA23S) checks whether we are near the planet
(MAS2, then MAS1 and FAROF2 on the point 2 nosev above it). If so, it
calls WPLS to remove the sun from the screen, then NWSPS, which empties
FRIN+1 and puts the station there. The sun's data block is gone. When the
station is out of range, KS4 makes a new sun in the slot, at (0, 6 sign
units, 0): overhead, not where the old one was. After a launch, TT110's
RES2, SOS1 and NWSPS make the station and no sun at all. The game state
must stay SNG47's, so none of this changes.

**The design: the sun drawn as scenery.** S_SUN (master/src/gfx-ssun.asm,
at bank 4's end with L_SUN) runs after every main-loop iteration, from
G_FRAME with bank 4 paged, before F_FRAME. It writes only its own variables
and the frame's (F_SUX, F_SUY, GSUNR, GSUNON, SS_OK); the zero page and the
game's variables that MV40 and SOLAR use are kept and put back.

* Slot 1 is the sun, and the planet is within one sign unit on every axis
  (the station can only appear at zero, in an iteration with MCNT AND 31 =
  0, and TT100 decrements MCNT after the frame): in the frames with MCNT
  AND 31 = 1 or 0 it takes D = sun - planet (ss_d, 24-bit two's
  complement, in the shared workspace). Further out, D is forgotten.
  (Taking D every frame would cost up to 0.5% on the gate's approaches.)
* Slot 1 is the station: D is turned by ALPHA and BETA by MV40 itself, as
  the game turns the planet and the sun (our own movement moves them
  alike, so D only turns). ss_turn puts D into INWK's coordinates
  (sign-magnitude) and calls MV40 with TYPE 129 (the sun: MV45, which MV40
  jumps to, returns after moving z) and DELTA 0 (z moved by nothing), K2's
  low byte 0 (MV40 reads it in step 3 without setting it); the zero page
  that MV40, MULT3, MVT3, MV45 and MVT1 use (INWK's coordinates, P, Q, R,
  S, T, K, K2, TYPE, DELTA: 26 bytes, ss_zpa) is kept and put back. In
  record mode the sun is recorded at planet + D, as PLANET would draw it:
  the view's axes as PLUT; PLANET's tests on z; PROJ (x / z and y / z under
  1024); the radius 24576 / z, or 248 if it is 256 or more; CHKON.
* Slot 1 is the station and D is unknown (we launched, so this system's sun
  was never in the slot): D comes from the system's seeds by SOLAR's own
  code (ss_seed). The SOLAR block's header says "Area: cold, again", and
  streams.py emits it a second time (build/elite-source-again.asm, no
  stubs, its labels and the targets of its JSRs and JMPs named A_<name>),
  which gfx-ssun.asm INCLUDEs: it enters at A_nobirths (past the Trumbles,
  which the Master never has), A_ZINF = ZINF, and A_SOS1 and A_NWSHP are
  stand-ins that note INWK's coordinates (the planet, the sun; ss_pl,
  ss_su). INWK and FIST are kept and put back; FIST's bit 0 is taken as
  clear.
* Docked (F_DIRECT with QQ12 set clears SS_OK), in witchspace, or with no
  planet in slot 0: no sun.

When KS4 brings the game's sun back, it is overhead, as in the original:
the drawn sun jumps there. The lighting (L_SUN) keeps turning its light
while the station has the slot, so it is unaffected.

**Sorting.** PLANET gives the sun and the planet the same radius at the
same z (24576 / z), so the bigger disc is the nearer one. f_discs makes the
bigger disc the layer, and f_disc2 draws the smaller disc (always the
further one) only where the layer's span on each row leaves room: up to
two pieces a row (R_DISC2, below). So a sun behind a bigger planet is cut
by its limb (b0abf71's f_disc2 drew the secondary disc on top), a planet
behind a bigger, nearer sun is cut by the sun, and ships are drawn after
both, in front; f_behind and F_PLANET's z for far planets are unchanged.
A planet that is the secondary disc is a plain disc, without its detail.

**The lens flare.** The planet's colours could pass the flare's colour
probes, so a probe inside the planet's span on its row is out of sight
when the sun is the secondary disc (FL_BEH, set by f_flt from f_sec).
R_FLARE reads this buffer's disc spans (R_DISCL/R), picking the buffer
from the dirty page it is given, and its half-width table is kept whole in
a page by a skip (a correctness skip, not alignment for speed). f_flt's
test that the sun's centre is outside the planet's disc is gone: the
probes see the planet, so a sun rising over the limb turns the flare up in
steps.

**Cost.** A frame with the sun in view costs S_SUN about 3,200 cycles,
the second disc 2,500-17,600 (below), the planet layer's repair of the
sun's rows 3,000-5,000, and, in the front view, the flare 30,000-35,000
plus its repair on the planet (about 30,000 in f_discs): the flare is two
thirds of the cost, as it is anywhere. The posed scene (harness/msunnear.mjs:
a planet of radius 120, a sun of radius 16, the station crossing; on
b0abf71 the same scene has no sun):

| | b0abf71 | the sun drawn | without the flare |
|---|---:|---:|---:|
| sun hidden behind the limb | 7.90 it/s | 7.53 | 7.63 |
| sun rising | 9.17 | 6.61 | 8.48 |
| sun clear | 8.61 | 6.33 | 8.44 |
| station flyby | 6.93 | 5.47 | 6.67 |

On the gate, the docking approach has a radius 7 sun in the front view,
with no planet on the screen, and so the flare (f_flt 36,000 cycles a frame
there): the windows 4800-4999 and 5000-5199 run at 9.43 and 5.71 it/s
against 9.73 and 6.14 without S_SUN (-3.1%, -7.0%). Elsewhere it is within
0.1%. harness/msunprof.mjs profiles a stretch of the gate's run (S_SUN, the
disc layer, the second disc, the flare and the whole frame, per frame).

**Checked**: the station appearing in the game's own way
(harness/msunnear.mjs --spawn: the game's sun in slot 1 at (180, 50),
radius 19, the planet placed for part 15): the frame after NWSPS draws
S_SUN's sun at (180, 51), radius 19, and carries on from there
(screenshots/sunnear/spawn.png). The movie (harness/msunnear.mjs, rendered
by master/tools/sunnear.py): screenshots/sunnear/sunnear.mp4 and
sunnear.gif, the frames, and sheet.png. The sun rises from behind the
planet's limb, with the flare's probes going 0, 1, 2 ... 9. The station
then crosses it: 8, 5, 3, 0, 1, 0, 0, 3, 4, 7, 7, 9, so the flare dims,
goes out and comes back.

## The second disc, incremental (with the sun near the planet)

The original Elite keeps each row's sun span (SUNX, the LSO heap) and only
changes the ends that move; the second disc (the smaller of the sun and
the planet, behind the disc layer) is drawn the same way.

**The design** (R_DISC2, master/src/gfx-raster_disc2.asm). Each buffer keeps
the second disc's span a..b per row as drawn, its rows (R_S2T..R_S2B) and
its colour (R_S2C, the even rows' byte). What the row shows is that span
less this buffer's disc layer span L..R, up to two pieces. After
R_DISCROWS, everything that can have happened to the old pieces since the
buffer's last frame is in R_WL..R_WR (W): shapes over them were in DIRTY
and were repaired, the layer's old span never held them, and where the
layer moved off it wrote black. So per row, with the old span a0..b0 and
the new a1..b1, every write less the layer's span:

* same span, nothing written over it: a few compares;
* same span, written over (W): max(a, WL) .. min(b, WR) drawn again;
* the spans overlap: the ends that shrank black, the ends that grew in the
  disc's colour; with W over the new span too, one span over the grown ends
  and that part (pixels still the disc's between them are written again);
  with no layer on the row and nothing written over it (the commonest
  case), the two end strips go straight to r_sw;
* apart, one span empty, or the colour changed (the sun and the planet
  swapped which is bigger, or a disc came or went): the old span black, the
  new one whole;
* both spans empty or behind the layer: only the new span remembered.

The writes are masked to their pixels (r_sw, or r_spc for 17 pixels or
more) and go into R_WL/R_WR (R_PRWT..R_PRWB take the rows lo..hi), so the
text and the sights see them as written; nothing goes into DIRTY, so the
next frame does not repair them. In K mode a row is settled (k_kill) before
it is written, as T_SPAN does. R_RESETBUF (on a buffer just blacked) sets
the buffer's rows to none and its colour to 0, which no disc is; R_DISC2
empties the buffer's spans the next time it draws there (so a reset that
no disc follows costs nothing). R_SETBUF patches R_DISC2's operands (r_s2l,
r_s2r and the layer's r_sl, r_sr). f_disc2 computes the spans, fills the
old rows outside the new ones with empty spans, and calls T_DISCROWS with C
set (R_DISCROWS' first instruction sends it to R_DISC2), so the glue area
has no new trampoline. With no second disc, f_disc2 calls it only while
this buffer still holds one. The flare's probes, the stars (erased before,
plotted after, on black only), the 25 fps cap and the flips are untouched.

r_lput2 hands spans of 16 pixels or more to the run (r_spc, 5 cycles a byte
and about 90 to set up) rather than 48 (its byte-pointer loop is 26 cycles
a byte); this is r_sw's path for spans across the screen's middle, the
layer's too. The pixels are the same.

**Where.** R_DISC2 is at the end of bank 5's shared region (&BBC7-&BEE9),
in the bank it runs in. Its spans: R_S2L0 &9A00, R_S2L1 &9B00 (the room
below the per-x tables), R_S2R0 &8F40 (the disc window's end), R_S2R1
&BF40 (after R_DISC2 and R_WSPAN): each whole in a page, a buffer's and the
other's at the same low byte, the high bytes from two tables in R_SETBUF.
R_S2T, R_S2B and R_S2C are in the shared workspace (f_disc2 reads the
rows). bankcheck checks gfx-raster_disc2.asm as bank 5's and gfx-ssun.asm
as bank 4's, build.sh's banks.txt lists them, and msunnear.mjs and
msunprof.mjs take S_SUN's and the flare's banks from the symbols.

**Cost** (f_disc2 a frame, a radius 16 sun, the posed scene's averages):
held still 2,500-3,400 cycles (9,300-10,600 with the flare, whose ring
round the sun dirties every row of it each frame, so each is drawn again);
rising, about 1.5 pixels a frame, 12,800-17,600 (two end strips a row, some
420 cycles), 25,000 with the flare; hidden behind the limb 3,800-6,000. The
planet layer (radius 120, a beach ball) is 110,000-230,000 cycles a frame
there, so the second disc's share is small.

**Checked**: test_raster's disc2 (two discs drifting, growing, crossing
(the colours swap), coming and going and jumping, on two buffers, with
ships, lines, dots, text marks, stars, resets and K mode; each frame against
the reference, every changed pixel in WL/WR or DIRTY); the pixels are those
of the disc drawn whole each frame (the posed scene's 156 frames with and
without the flare, and the gate's run, harness/mfbcmp.mjs, 9,836 frames,
both buffers).

## Banded planets (after the sun near the planet)

A quarter of the crater planets (s1_hi bits 0-1 clear; Lave is a meridian
planet, so it keeps its beach ball) can be class 2: two latitude circles
about the axis the planet spins about, nosev - sidev (MVEIT part 8 pitches
roofv and nosev and rolls roofv and sidev alike, so that axis stays where
it is), north of one latitude (14 to 36 degrees, s2_hi bits 4-5) and south
of another (-7 to -30 degrees, bits 6-7), EOR'd (pf_bands, base 0): three
bands, the polar zones colour A and the belt between them colour B. Two
parallels can put four crossings in a row, which the disc layer holds; a
third would need six. As the axis does not turn, the belt stands still
while the planet spins. pf_tilt's bit 3 gives the equal-weight sum (nominal
length 1536 sqrt 2).

They are a build switch, BANDS=on (master/build.sh, _PLANET_BANDS), off by
default: PF_HOOK makes no class 2, and pf_bands, its tables and the
dispatch are assembled out (81 bytes of bank 7). test_raster assembles the
planet code with bands on (BANDS=off in its environment for the default;
pfhook checks the class), and tools/planet_caps.py's BANDS follows it.

## The moon (after the banded planets)

A quarter of the systems (h = s0_hi EOR s1_hi EOR s2_hi, bits 0-1 = 1;
none of the gate's three) have a moon: scenery only (no ship slot, no
random number, no saved state), 0.19 to 0.28 of the planet's radius (h bits
5-6), drawn for planets of radius 16 or more, light grey with a dark grey
crater (on roofv, 40 degrees across, from a moon radius of 10: a circle
record of the engine in slot PCMAX, its rows made by PC_MROWS through
T_MCAPS). Its colours are the palette's nearest greys: light grey C M Y K /
Y K C M (&6A, &9A: equal parts cyan, magenta, yellow and black, a neutral
mid grey) and dark grey C K M K / K Y K K (&28, &44: one pixel in four lit,
a neutral dark grey).

**Its place** is a point fixed in space, as S_SUN keeps the sun: MN_TURN
(gfx-ssun.asm, bank 4, game context) keeps E = moon - planet (MN_E, 24-bit
two's complement, in the coordinates, the front view's axes, in the shared
workspace beside S_SUN's ss_d) and turns it with our roll and pitch once an
iteration, by MV40 itself (ss_turnx: D or E). The first call with a new
MCNT turns it: G_PFHOOK (before the planet's detail), MOONHIT, or S_SUN
after the iteration, whichever comes first. E is made in the first
iteration after we arrive or launch, when the planet still has ZINF's
orientation, so its spin axis then is (-1, 0, -1) / sqrt(2): E = +/- (c, 0,
c), c = D 24576 / sqrt(2), on the side h bit 4 gives (set: +), D = 3 to
5.25 radii (h bits 2-3). MN_OK is cleared in witchspace, with no planet,
while docked (MN_TURN, and F_DIRECT with SS_OK) and when QQ2 changes.

The planet's spin axis itself would not do as the moon's place: MVEIT's
MVS5 steps are first-order rotations, and TIDY renormalises the planet's
orientation every 16 iterations with one-byte precision. harness/
mmoonpath.mjs (a planet held still in a moon system, the game spinning it)
shows the axis precessing 0.11 degrees an iteration and jumping 1.7 degrees
on average (up to 3.3) on TIDY's iteration (MCNT AND 15 = 15 for slot 0),
6.3 degrees from its mean over 600 iterations; in a 1,600-iteration flight
with our roll and pitch it turns 21 degrees against a vector the game keeps
fixed in space (the station less the planet). A moon on the axis would jump
by several pixels.

**Drawn.** pf_moon (gfx-planet7.asm, bank 7, from PF_HOOK) projects M = P +
E in the view's axes as PLUT has them (pfm_vs, pfm_vn): x = 128 + 256 M_x /
M_z, y = 96 - 256 M_y / M_z, radius rho 96 256 / M_z, at most 63 (M
shifted right until M_z fits 15 bits, pfm_div's divisor); behind the planet
if E_z > 0, behind the sun (slot 1) if further than it. What the frame
reads (MN_ON, MN_X, MN_Y, MN_R, MN_Z, MN_INV, MN_N: gfx-planetv.asm) is in
the shared workspace (main RAM below &3000, which PF_HOOK in bank 7 and the
frame layer both see). tools/planet_caps.py's pf_moon models it bit for bit
(test_raster's pfhook test: random MN_E, views and positions, and the
crater's rows).

The frame layer's f_moon (after f_disc2) draws it as a third disc of spans
(its half-widths in F_HW3), less the planet's and the sun's spans where
they are in front; f_behind hides a ship further than the moon whose first
vertex is inside its disc, as it does for the planet. It is drawn
incrementally: each buffer keeps the moon as it drew it (MO_ON ... MO_CB in
the shared workspace: its centre, radius and depth bits, its rows and its
crater's rows), and only the rows that changed since that buffer's last
frame are drawn:

* the same place, size and depth: a row with no crater, old or new, is
  drawn only where this frame wrote over it (R_WL..R_WR as the layer's
  repair and the layer's and the second disc's changes left them, read
  before the moon's own writes); a crater row, old or new, whole (the
  crater turns with the planet);
* moved, resized, its depth against the planet or the sun changed, or gone
  (all its rows changed): f_moon0, before the disc layer, puts the old
  moon's spans into DIRTY (from MO_X, MO_Y and F_HW3; its box's rows if
  F_HW3 no longer holds its radius's half-widths), so the layer's repair
  restores what was under it in this frame (black, the layer, or the
  second disc, which R_DISC2 then draws again over what the repair wrote),
  and the moon is drawn whole.

Its writes go through T_WSPAN (R_WSPAN, bank 5: R_SPAN that notes the span
in R_WL/R_WR and R_PRWT..R_PRWB, as R_DISC2's writes are noted), never into
DIRTY, so the text, the sights and the moon itself see them as written.
Ships drawn over it are repaired by the layer (DIRTY), which the moon then
sees in R_WL..R_WR. The row is the unit, not the strip (the ends that
moved, as R_DISC2 draws): from bank 6 each strip is a trampoline call and a
span set-up, and a moving moon would cost about twice a whole redraw.
R_WSPAN is 56 bytes in bank 5's shared region, T_WSPAN 22 in the glue, the
moon's state 20 bytes in the shared workspace.

**Checked.** The place: master/tools/moonpath.py on harness/mmoonpath.mjs's
recording of 1,600 iterations of turning flight (radius 40): |E| within
0.8% (MV40's shears; the station less the planet varies 0.4%), its angle to
the station less the planet within about 0.3 degrees, the drawn centre
within 1.4 pixels of planet + E projected (mean 0.8), and each step on the
screen the projected point's to 1.6 pixels (the moon's largest step 6.7
pixels, the planet's 4.0). The held planet scene: one moon position over
600 iterations. The pixels: harness/mplanet.mjs scenes, the frame-end back
buffer of every frame byte for byte against the moon drawn whole each
frame: 6 fixed scenes (moving, still, still with the planet spinning, in
front of the planet, behind it, off the screen's side) and 18 random ones
(seeds, poses, spins, paths and radii): 1,044 frames, all identical. The
cost (f_moon, f_moon0 and T_DISCROWS, the frame's mean): a still moon
25,603 cycles, 29% less than drawn whole; moving, within -6% to +8% of
drawn whole.

## The moon is solid (after the moon)

Flying into the moon kills us as flying into the planet does: the main
flight loop's part 15 (MA22) calls MOONHIT (master/src/elite-moon.asm, at
bank 4's end with S_SUN and L_SUN) before the planet's altitude test, and
on C set jumps to MA28, the planet's crash (DEATH: the same sound, the same
death screen). MOONHIT tests on the planet's altitude iteration (MCNT mod
32 = 10), in systems with a moon (h bits 0-1 = 1): the moon's centre M = P
+ (MN_E >> 8) (P the planet's position; MN_TURN's place, turned first if
this iteration has not turned it), in the coordinates' high bytes, and we
have crashed if |M|^2 < (rho 96)^2 (the radius 18, 21, 24 or 27). Between
two tests a ship moves at most 5 of these units. It writes no zero page and
nothing of the game's but by crashing: in a system without a moon it
returns at once.

harness/mmoonhit.mjs puts the moon's centre at (0, 0, m) from us (the
planet placed accordingly, our speed 0): for seeds covering every D, rho
and side, m = +/-(radius - 2) crashes and m = radius + 2 does not; seeds
without a moon never crash.

**The lockstep waiver.** SNG47 has no moons, so in a system with one a run
that flies into the moon diverges from SNG47 at that iteration (our DEATH);
nothing else differs (MOONHIT reads game state only). The gate's systems
have no moon (Lave, h = &EF; the crater system and the third likewise), so
master/verify.sh is unaffected and needs no waiver. For a lockstep
comparison in a moon system (an agentplay campaign against SNG47), build
with MOON=scenery (build.sh: _MOON_SOLID FALSE, no call of MOONHIT): the
moon is drawn but is not solid, and the game state stays SNG47's there
too.

## Planet rings (after the solid moon)

An eighth of the systems (h bits 4-6 = 4; none of the gate's) can have a
ring: a dotted ellipse in the plane of the planet's equator, normal to the
spin axis nosev - sidev (MVEIT's pitch and roll turn the planet about it),
so its shape on the screen stays put while the planet turns. pf_ring uses
conjugate diameters: no angle, no table of angles, no latch. Two conjugate
radii, roofv and (nosev + sidev) / sqrt(2), scaled to the ring's radius on
the screen (1.6 to 2.2 planet radii, h bits 2-3; 12.4 pixels), give its
points P(t) = cos t A1 + sin t A2 and -P(t), t = i pi / 32 (i in steps of
2, or of 1 for a ring of radius 120 pixels or more: 32 or 64 dots); the
points at t and pi - t share their products. A point is behind the
planet's centre if its z (from the radii's high bytes) is negative. The
dots on the screen go to RG_X, RG_Y, RG_F (the shared workspace); the frame
layer's f_ring draws them in yellow (T_DOT, marked dirty) after the moon,
but a dot behind the planet's centre and inside its disc, which the planet
hides: the back half is hidden behind the disc and the front half crosses
it. The ring is not a region, so it is not a circle of the engine, though
pf_ring uses pf_tilt and the engine's arithmetic.

Rings are a build switch, RINGS=on (master/build.sh, _PLANET_RINGS), off by
default, as the bands are: pf_ring and its helpers, tables and variables
(bank 7, 1,024 bytes), f_ring and its call and reset (bank 6, 169) and
RG_N, RG_X, RG_Y, RG_F (the shared workspace, 193) are assembled out.
test_raster assembles them with rings on (RINGS=off in its environment for
the default; pfhook checks the dots against tools/planet_caps.py's pf_ring,
or none), and the model's RINGS follows it.

## Commander Claude's moon mode, and the film (after the rings)

elite-agent's moon mode (MOON=1, its branch moon-avoid: docs/MOON.md there)
places the moon as the port does (moon_track: made at the arrival or
launch, turned by ALPHA and BETA for each MCNT step it sees) and steers
clear of it; agentplay runs it as --mode moon (master/tools/agentplay:
build.sh, agentd.c, styles.mjs). moonmovie.mjs films an arrival in a moon
system to the docking, reading the port's MN_E and ss_d. The system was
chosen by search: the moon's place at the arrival (SOLAR puts the planet
ahead to the upper right, and the moon on its spin axis on the side h bit 4
gives: with bit 4 set, behind the planet and towards the view's centre) for
every moon system with a start in jump range, checked against probes of the
real arrivals; (155, 60) from (156, 57) (h = &71: D = 3, the biggest
radius) puts the moon beside the planet in the front view at the arrival.
The film's own director takes the stick for two shots, the moon as we come
near it and the sun once S_SUN draws it (a stretch each, held in the front
view; the agent flies the rest), and empties the tank at the arrival so
that the agent docks there. Every sun is behind the arrival point, so the
sun is never in one frame with the planet on the way in: the sun shot
shows it beside the station, with the flare, before the docking. The film
fails its own check unless the moon and the sun are each on the screen for
8 s or more (this one: the moon 59.6 s, the sun 43.8 s; frames are flagged
at F_FRAME's end); the cruise between the shots is sped up (1 frame in 64)
and the published film 1.6 times: screenshots/moon/approach.mp4 (85.5 s),
approach.gif, approach-sheet.png, approach.json.

## What each style costs (after the film)

harness/mplanet.mjs, the planet at the screen's centre, pose 20,30,0, 16
frames at 22.5 degrees of spin each about the spin axis, the mean cycles a
frame: set-up is G_PFHOOK (PF_HOOK and its pc_circ calls), rows T_CAPS
(PC_ROWS), disc T_DISCROWS (the disc layer's spans and boundaries,
incremental between frames), total their sum. Crater planets of 1, 2 and 3
caps are as the seed gives them (a cap on the far side costs its set-up
only: crater 1's cap is hidden in 6 of the 16 frames, 2's and 3's caps in
some). The plain disc is the frames with no detail (a crater planet whose
only crater is hidden; its set-up is that crater's pc_circ, about 17K: a
featureless planet's hook is about 1K). The bands are a BANDS=on build's.

| style | r | set-up | rows | disc | total |
|---|---|---|---|---|---|
| plain disc | 30 / 60 / 90 | 18.0K | 0 | 27.5K / 34.8K / 43.0K | 45.5K / 52.8K / 60.9K |
| beach ball | 30 / 60 / 90 | 25.6K | 29.4K / 53.4K / 77.7K | 69.2K / 132.9K / 200.6K | 124.2K / 211.9K / 303.9K |
| crater, 1 cap | 30 / 60 / 90 | 18.2K | 6.8K / 11.4K / 16.3K | 33.6K / 56.3K / 80.6K | 58.7K / 85.9K / 115.0K |
| crater, 2 caps | 30 / 60 / 90 | 36.1K | 11.7K / 19.6K / 27.5K | 46.6K / 83.8K / 125.2K | 94.5K / 139.5K / 188.8K |
| crater, 3 caps | 30 / 60 / 90 | 53.8K | 18.0K / 29.8K / 41.6K | 56.6K / 104.4K / 156.7K | 128.5K / 187.9K / 252.0K |
| bands | 30 / 60 / 90 | 38.7K | 33.8K / 60.3K / 87.1K | 26.7K / 43.5K / 59.4K | 99.3K / 142.5K / 185.1K |

The beach ball is the dearest: its two great circles cross every row, and
as the planet spins every boundary moves, so the disc layer repaints most
of the disc each frame. The bands cost about as much in rows (two circles
across every row) but stand still under the spin, so the disc layer has
little to repair. A cap's rows scale with its size, not the disc's.

## Every disc, incremental (after what each style costs)

* The planet and the sun as the disc layer (R_DISCROWS): incremental (each
  buffer's spans and boundaries).
* The smaller of them, the second disc (R_DISC2, bank 5): incremental.
* The moon: incremental by rows ("The moon", above).
* The ring: dots, not a disc (drawn and marked dirty each frame).
* Explosions: particles (dots); the explode branch's clouds are not merged.
* The hangar: rectangles and lines, no discs.
* The lens flare: its ghosts are dithered discs and dotted rings ORed over
  the frame (additive light), marked dirty and repaired by the layer next
  frame. Not incremental: an OR over whatever is under it has to be
  redrawn wherever that changes, and it keeps nothing on the screen by
  design.
* The hyperspace and launch rings, the charts' circles: lines.

## Free space (after every disc incremental)

In bytes, as master/build.sh prints them: bank 4 6 (S_SUN, MN_TURN, L_SUN
and MOONHIT at its end); bank 5 2 in the disc window (before R_S2R0), 7 in
the shared region (before R_S2R1), 42 + 64 + 64 in the room below the
per-x tables, and the run pages' tails; bank 6 472; bank 7 1,218 (the
meridian window to the bank's end); ANDY 37; main RAM 183 below &3000 (used
by the hot pass), 53 to &4000, 180 to &8000, and the shared workspace 44 in
its gaps and 210 before CODE% (&1EE8); HAZEL 1,223 (&DA39-&DEFF), with
&DF00-&DFFF the MOS's, off limits. BANDS=on takes 81 bytes of bank 7;
RINGS=on 1,024 of bank 7, 169 of bank 6 and 193 of the shared workspace.

The gate: VERIFY PASS 13.97 10.29 0.736 (game state identical to SNG47 at
all 10,000 iterations; the regressions redock, savetest, savebytes,
station, views and shippose), against 11.82 and 0.846 at b0abf71; most of the difference is
the crater system's windows (800-2799), where two caps cost more than the
polygon crater did.

## Stills (after the free space)

master/tools/stills.sh [planets] [sunnear] makes the stills from the build
in master/build, headless (jsbeeb): each planet still is the last frame of
a short posed scene (harness/mplanet.mjs, master/tools/planetvis.py), the
seeds those of systems with craters, a moon or a ring; the banded planets
and the rings come from a copy of the tree built with BANDS=on RINGS=on
(scratch/stills/bandstree), as the default build has neither.
screenshots/planets: beach.png, caps.png, caps2.png, nobands.png (a banded
seed as the default build draws it, a crater planet), bands.png,
bands2.png, moon1-3.png, ring.png, ring2.png, ringmoon.png, ringmoon2.png.
screenshots/sunnear: the posed scene's 156 frames, sheet.png, spawn.png,
sunnear.mp4 and sunnear.gif (harness/msunnear.mjs, master/tools/sunnear.py).

## Stars only into black bytes (after the stills)

R_STARPLOT sets a star's pixels in a screen byte only when the whole byte
is black. Every fill the frame layer can draw that is not pure black (the
ships' ramps and unlit colours, the planet's, the sun's and the moon's
colours, colour B, the second disc, the hangar's panels, the distant dots)
has a coloured pixel in every byte of every row of its dither, so no star
shows through a dithered fill; master/tools/starocc.py proves it from the
bank 6 image and the sources on every build (build.sh runs it, and it
fails on a colour source it does not know). It is also about 6 cycles a
star cheaper (no AND, no ORA).

The one pure black fill is a station's docking slot. f_poly2 copies its
four vertices to F_SLV (bank 6) when it fills one; F_FRAME then plots the
stars through f_slot (gfx-frame_cold.asm), which takes those in the
vertices' bounding box out of R_SS for the plot and puts them back, and
f_reset marks F_SLV empty. Bank 5 had no room for this, bank 6 had: 221
bytes free after it. harness/mstarocc.mjs poses stars over the planet's
sea, a dark ship, the slot and the sun beside the planet (its grid goes in
at F_FRAME's ff_stars, before f_slot); ff_stars9, after the stars, is the
harness's frame end.
