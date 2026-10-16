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
B. Relocation, no rendering change
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
