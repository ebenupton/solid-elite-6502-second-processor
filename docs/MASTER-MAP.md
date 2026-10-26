# The memory map: BBC Master Elite with the filled renderer

This is the layout of the port: where each part of SNG47 Master Elite and of
the filled, dithered and lit renderer lives, why it lives there, how code in
one region reaches another, and how much room is left. The figures are from
the build (`master/build/compile.txt`, `master/build/symbols.txt`) and from
the cycle profile of the gate's run (`master/tools/grind/profile.mjs`); the
hot pass's containers and units are listed in `master/build/flow.txt`.
docs/MASTER-MEMORY.md has the hardware side: what the MOS and DFS use, and
which spare RAM the port may take.

## The rules the layout follows

1. **ACCCON X.** With X = 1 shadow RAM appears at &3000-&7FFF and main RAM
   there is hidden. Code that runs with X = 1, and data it reads, must not be
   in main &3000-&7FFF. Master's own drawing (the docked screens' text and
   lines, CHPR, the dashboard, PIX1) and the frame layer run with X = 1 for
   part of their time. What they reach in main RAM is below &3000: the glue
   area (the text and IRQ hooks, TTX66M, the renderer's shared variables),
   the low pass (CHPR and its font, cls, ZES1 and ZES2, UP: CATF, FLH, COMC),
   the dashboard's variables (DASHV, after WP) and the renderer's shared
   workspace. The hot pass's code that runs with X = 1, and the tables it
   reads (Master's drawing and the CMYK dashboard: ylookup ... DSEG, ADDK, the
   log tables), is tagged "Area: hot, ACCCON X", and the flow puts it in bank
   4, which X does not hide. The build asserts that the low pass ends below
   &3000 (LOW_END%), and XTRACE (harness/mlib.mjs) records what runs with X
   set: none of it is in main &3000-&7FFF.
2. **Interrupts and MOS vectors.** The IRQ arrives with any bank paged and X
   either way; WRCHV (CHPR) and BRKV (NEWBRK) are entered with any ROM paged.
   Their handlers, and everything they touch, are in main RAM below &3000
   (the low pass: IRQ1 and the sound code, CHPR, NEWBRK; the glue area: the
   IRQ's H_VSYNC, the text hooks), and reach banked code only through stubs
   that page the bank and restore the caller's (NEWBRK pages bank 4 itself
   first; CHPR reaches TTX66 through TTX66M, which keeps the caller's bank).
   No interrupt handler pages a bank. The MOS reads a disc command's string
   from a copy that DOSCLI makes in screen buffer 0 (DOSBUF, &6000), so the
   strings stay in the cold pass.
3. **One sideways bank at a time.** Elite's home bank (bank 4) is paged
   whenever game code runs, so main RAM, HAZEL and bank 4 code call each other
   and read each other's data directly: the low and hot passes, the glue area
   and the game data are one side, the hot side. The cold pass (bank 7) is the
   other, reached through a stub of its own for each target, in the glue area
   ("Calls between the passes"); every other bank (the renderer's) is reached
   through a stub that pages it in and the caller's bank back.
4. **ANDY** (ROMSEL bit 7) overlays &8000-&8FFF of the paged bank. It is the
   rasteriser's polygon window (R_POLY and R_LINE), paged as ROMSEL &85
   (RASTPOLY: ANDY over bank 5, whose &9000-&BFFF is the rasteriser's shared
   region); bank 5's own &8000-&8FFF, paged as ROMSEL 5, is its disc window.
   Nothing calls between the two windows, and the shared region, which runs
   with either paged in, refers to neither (but where reviewed and marked).
   **The renderer is in banks 5 and 6 and ANDY, and in one window of bank
   7**: the rasteriser in bank 5 and ANDY, the frame layer in bank 6, and the
   meridian window (gfx-merid.asm, the beach ball planet's boundaries) in
   bank 7 after the cold pass, paged as ROMSEL MERIDBANK (7) by its two stubs
   only (G_MERHOOK in game context, T_MERID during the frame). Bank 7 is
   otherwise the cold pass's: one run from &8000, the cold code, then the
   cold data. (The meridian window is the one exception to "the renderer in
   banks 5, 6 and ANDY only", made for the beach ball, which needs about 3K
   that none of those has.)
   &F4 always matches ROMSEL, bit 7 included: every write of ROMSEL writes &F4
   first (the stubs, the G_ and T_ stubs, R_SETBUF's r_sbpoly).
5. **The game data is in HAZEL**, where every bank, the IRQ and code running
   with X = 1 see it, in the original's order from XX21 at &C000 (NWSHP reads
   past E%, E%-1,Y for the planet and the sun, into the missile's blueprint,
   as in the original), as far as it fits: the hot data flows through HAZEL,
   then bank 4 after the hot code. QQ18 (the recursive tokens, which the hot
   text printers read), SNE and ACT, which only hot code reads, are in bank 4.
6. **The screen and the split.** Main &4000-&6FFF is buffer 0 and shadow
   &4000-&6FFF buffer 1; shadow &7000-&7DFF is the dashboard. Main RAM under
   the dashboard (&7000-&7FFF) is never on show, as the split is never late
   (docs/MASTER-PLAN.md, "Dashboard split timing"), so it holds the
   quarter-square tables and the hot pass's second container.
   Nothing else lives in the buffers, except that a disc command borrows
   buffer 0 to stash HAZEL and to hand the MOS its command (rule 8).
   In space mode with buffer 0 on show, IRQ1's timer 1 interrupt sets ACCCON D
   in line 191's horizontal blanking; timer 1 runs freely, once a frame
   (T1SYNC), and only timer 1 and vsync (CA1) are enabled. Code that must not
   be interrupted by the vsync handler (its sound-chip writes, its IRA read,
   H_VSYNC's flip variables) masks only CA1 in the System VIA's IER
   (`LDA #%00000010 : STA &FE4E` ... `LDA #%10000010 : STA &FE4E`), never SEI,
   which would hold the split off: FILLKL, NOISE, SOFLUSH and the frame flip
   do. IRQ1 tests timer 1's flag first, so a masked vsync flag is harmless.
7. **Page &0D** (&0D00-&0DFF) is never written: the DFS NMI routine, the
   extended vectors and the ROM workspace table are there
   (docs/MASTER-MEMORY.md). The build asserts that nothing is assembled there
   and the gate checks that only DFS writes it (DOSNMI's six bytes at &0D00
   apart).
8. **HAZEL and disc access.** During a disc command DFS and the MOS
   overwrite HAZEL &C000-&C2FF, &D900-&DAFF (the DFS and ADFS private
   pages), &DC00 up to the end of the OSCLI command and &DF00-&DFFF, and keep
   their own lasting state at &C2C0-&C2FF and &DFC0-&DFFF. DOSCLI, through
   which every OSCLI goes, copies all of HAZEL to buffer 0 (main
   &4000-&5FFF), puts DFS's and the MOS's lasting bytes back from DFSST
   and DFSST2,
   copies the command to buffer 0 (&6000), makes the command, stashes those
   bytes again and copies HAZEL back (DOSNMI, also on the error path); the
   next entry to space mode starts buffer 0 afresh (GSTASH, f_b0new). What
   runs during a command (the IRQ's H_VSYNC, the catalogue's text hooks) is
   in main RAM below &3000 and reads nothing in HAZEL, and a write the game
   makes to HAZEL (XX21+2/3, NWSPS) goes out and back with the copy, so the
   data may sit anywhere in HAZEL.
9. **The harness** reads the compared game state (zero page, K%, WP, UP,
   NA%, the sound buffers) by symbol, wherever the build puts it, and the
   game's tables (IKNS) and code (LL5's caller) through their banks
   (build/banks.txt). The one
   address the compared state holds of data the port moves, the space
   station's line heap pointer (LSO, in WP), is compared as the original's
   (mlib.canonFor).
10. **Each bank keeps its private tables and variables**; the state that
   more than one bank, the IRQ handler or code running with ACCCON X set
   reads is the renderer's shared workspace, in main RAM below the main code
   (one block, &0E00-&1DD4, below CODE%), with DFSST and DFSST2;
   the renderer's glue (its shared variables with initial values, the T_
   trampolines, the text and IRQ hooks) is in the glue area, below
   &3000 too. The rasteriser's windows share
   their private state through its shared region (bank 5 &9000-&BFFF, paged
   with either window): the row runs and their tails, the per-x tables, the
   boundary arrays. Code a window needs that uses nothing of that window's
   may sit in the shared region for room (R_POLY's arithmetic, R_LINE's cold
   part); code that only one window's entry points reach goes in that window
   (R_INIT and R_RESETBUF in the disc window).
11. **The source reads as the original.** elite-source.asm is Mark Moxon's
   main source in the original's order, and elite-data.asm his data source:
   every routine and table sits once, at its original place, and its header
   names the pass it is emitted in. The build emits each pass in the
   source's order ("The source and its passes", below), so memory follows
   the original's order container by container. What is not in the original
   is the port's own files (the glue area, the quarter-square tables, the
   renderer) or, inside the source, port routines next to the original
   routine they serve. The exceptions, each with a `Port:` note: see "What
   is not in the original's order", below.

## The source and its passes

The game source is the original's, in the original's order, emitted in three
passes: **low**, **hot** and **cold**. A routine's header says which:

    \       Name: TT219
    \       Type: Subroutine
    \   Category: Market
    \    Summary: Show the Buy Cargo screen (red key f1)
    \       Area: cold

* `Area: low`: the low pass, Elite's code that must be in main RAM below
  &3000 (rule 1 and 2): it runs with shadow RAM paged and is not in bank 4,
  the IRQ or a MOS vector reaches it with any bank paged, such code reads it,
  or it falls or branches into a block that must be low. That is the IRQ and
  the sound code it calls (with BEEP, which CHPR calls, and LASNO and ELASNO,
  which fall or branch into NOISE), CHPR and what it uses (cls, ZES1 and
  ZES2, TT67K, the font, UP), stackpt and NEWBRK (BRKV), and the small
  routines the cold pass calls directly (WSCAN, DELAY, BOOP, SOFLUSH,
  DOVDU19). 29 blocks.
* No Area field (or `Area: hot`): the hot pass, the rest of the game code,
  which runs with bank 4 paged. It flows through main RAM and then bank 4
  (below). `Area: hot, ACCCON X` is hot code that runs with ACCCON X set,
  and the tables it reads (ylookup, SCAN, LOIN ... DSEG: Master's drawing for
  the docked screens and the CMYK dashboard; ADDK; the log tables log, logL,
  alogh): the flow puts it in bank 4. 347 blocks, 41 of them ACCCON X.
* `Area: cold`: the cold pass, sideways RAM bank 7 from &8000. 161 blocks.
* `, runs on` after any of these: a table that code reads past its end into
  the next block, which must therefore follow it as a fall-through does
  (TKN2, `Area: hot, runs on`: DETOK2 reads the pairs of tokens 228-255 in
  QQ16, which follows it).

A block runs from its header to the next one (or to a separator line of
stars, which starts an untagged block: the original's PRINT and SAVE
sections). The blocks before the head (the configuration and the
workspaces ZP, XX3, K%, WP) are the configuration, assembled first, and a
block that assembles nothing (a banner, constants, PRINTs) goes with the
block before it. elite-data.asm's blocks are tagged the same way: no Area
field is hot data, `Area: cold` the cold data (the extended tokens TKN1,
RUPLA, RUGAL, RUTOK and their macros), `Area: BDATA` the dashboard image (a
block without a name, a banner or the closing SAVE, goes with the next named
block).

**The containers.** Each pass goes into its containers in the source's
order, and memory, from the shared workspace up, is:

* main RAM from CODE%: the **glue area** (elite-glue.asm), the port's own
  code: the stubs between the passes (elite-stubs.asm, with build/elite-stubs.asm),
  the renderer's shared variables, the T_ trampolines, the text and IRQ
  hooks, the G_ stubs and the drawing hooks; then the **low pass**, to
  LOW_END%, below &3000; CODE% is chosen so that the font starts a page with
  no padding (the build prints the padding, FONTPAD%);
* the hot pass's first container, main RAM from LOW_END% to &4000 (screen
  buffer 0 is above), from T1SYNC and G%;
* the quarter-square tables (elite-qs.asm, &7000-&73FF), then the hot pass's
  second container, main RAM from &7400 to &8000;
* the hot pass's third container, bank 4 from &8000: the ACCCON X blocks
  first, as they come first in the source, then the rest; then the hot data
  that HAZEL has no room for;
* HAZEL from &C000: the hot data;
* the cold pass, bank 7 from &8000: the cold code, then the cold data; the
  meridian window follows it.

**The flow.** The hot pass is cut into units: runs of blocks that must stay
together, because one falls through into the next (its last statement can
continue, or is a BIT skip, `EQUB &2C` or `&24`), branches into another
(the blocks from the one to the other: a branch reaches 128 bytes), or runs
on into the next. In the source's order, each unit goes into the container
the flow has reached if it fits, and the flow moves to the next container
when it does not, so each container holds its units in the source's order
and the containers follow each other in it; an ACCCON X unit goes into bank
4 whatever the flow has reached. A block that starts by aligning itself (the
log tables' `ALIGN &100`) is placed at the next boundary, the padding counted
in its container. The hot data flows the same way, HAZEL then bank 4, a block
with no bytes (QQ18's macros) going with the next.

The sizes are measured, not estimated. build.sh runs tools/streams.py twice:
`measure` writes the hot pass as one copy (build/elite-source-measure.asm,
with a label FLOW_<n> at each block) and the hot data as one
(build/elite-data-measure.asm, DFLOW_<n>), which src/elite-measure.asm
assembles past the containers' limits (build/measure-symbols.txt); `place`
then flows the units by those sizes and writes the copies elite-layout.asm
assembles. A block's size does not depend on where it goes (no block but the
log tables aligns itself, and a seam's JMP is the same size anywhere).
build/flow.txt lists every container and its units.

**The copies.** BeebAsm assembles with one location counter, and banks 4 and
7 share &8000-&BFFF, so streams.py writes one copy of elite-source.asm per
container, with the other lines blanked (so the line numbers are the
source's): build/elite-source-config.asm, -low, -hot1 (main RAM to &4000),
-hot2 (main RAM from &7400), -hot3 (bank 4) and -cold; and of
elite-data.asm, build/elite-data-hot.asm (HAZEL), -hot4 (bank 4), -cold and
-bdata. elite-layout.asm INCLUDEs them in turn, each at its own address, in
one pass. Each label is defined once, in its own copy, and each block is
assembled once.

**The checks** (streams.py, at each build): each block's IF ... ENDIF is
balanced; a block that can fall through its end is followed, in the source,
by a block of its own pass (the hot pass's: in its unit), or by a block of
the other side whose first statement is its entry label, which the falling
block then falls into through a seam, a JMP to that label's stub, written at
the label's place (the original's fall-throughs that cross the line: RES2
into ZINF, SOLAR into NWSTARS, LAUN into HFS2 and TTX69 into TT69, cold into
hot, and BEGIN into TT170, hot into cold); any other fall-through across
passes, any branch across passes, and any reference from the hot side to a
cold label that is not a call, a jump or its address (a stub has no data) is
an error; every unit fits a container. bankcheck.py reads the copies for its
rules ("Calls between the passes").

## The map

| Region | Addresses | Purpose | Free |
|---|---|---|---:|
| Zero page, stack, K% | &0000-&00E3, &0100-&01FF, &0400-&07FF | Elite's workspaces, as Master Elite | - |
| WP | main &0841-&0CCE | Elite's workspace (the original's &0E41-&12A9, each byte at the same place in its page), in the MOS's buffers below page &0D; the commander file buffer commbuf (= LSX2) at &087E; then the CMYK dashboard's variables DASHV (&0CAA-&0CCE, after JOPOS: the dashboard runs with ACCCON X set) | 50 (&0840, &0CCF-&0CFF) |
| Shared workspace | main &0E00-&1DD4 | the renderer's shared state, one block below the main code: R_NDN (&0E00), the rasteriser's per-call inputs, R_SS and R_SX, DFSIN, R_WL (&1000), DFSST, R_SY, raster_vars (&1133), R_SN, R_SCOL, KF (&1C00-&1CBF), DFSST2, R_WR (&1D00-&1DBF), F_DSS (&1DC0) | 105 (5, 30, 70) and 65 before CODE% |
| Glue area | main &1E16-&2868 | the port's own code (elite-glue.asm): to7 and to4, TTX66M, the stubs between the passes (STUBS7 &1E42-&1F8E, 38 into the cold pass; STUBS4 &1F8F-&2189, 57 out of it), the renderer's shared variables (gfx-gvars.asm, GMODE at &218A), the T_ trampolines (gfx-tramp.asm), the text and IRQ hooks (gfx-gluehooks.asm), the G_ stubs (gfx-gstubs.asm) and the drawing hooks (gfx-hooks.asm) | - |
| Low pass | main &2869-&2E48 | Elite's code that must be below &3000, in the source's order: WSCAN, DELAY, the sound (BOOP, BEEP, SOFH ... SOINT, the sound variables and the SFX tables), IRQ1 (&29CA), VSCAN, DOVDU19, cls, TT67K, CHPR (&2A19), ZES1, ZES2, the font (FONT%, &2B00-&2DFF), UP (&2E00), stackpt, NEWBRK | 439 below &3000 (used by the hot pass) |
| Hot pass: main RAM | main &2E49-&3F92 | the hot pass's first container (BCODE ends here): T1SYNC, pxpatd, pxpat, HANGFLAG, G%, the main flight loop, MALW, MALC, MT14, MT15, TKN2 and QQ16, NA%, shpcol, scacol, UNIV, HLOIN2, BLINE, the stardust, MVT3, MVS5, TENS, pr2, TT11, BPRNT, DTW1-8, FEED, MT16, TT26, BELL, ESCAPE, HATB, HALL, HAS1 | 109 |
| Buffer 0 | main &4000-&6FFF | the screen (rule 6); during a disc command also HAZEL's stash (&4000-&5FFF) and the command's copy (DOSBUF, &6000) | - |
| Quarter-square tables, then the hot pass | main &7000-&7F3D | QSL and QSH (elite-qs.asm, &7000-&73FF); the hot pass's second container from &7400: TACTICS, DOCKIT, the tactics helpers, HITCH, FRS1, FRMIS, ANGRY, FR1, SESCP, SFS1, SFS2, HFS2, STARS2, MU5, MULT3, the maths from MLS2 to DVID3B2 | 194 |
| Bank 4 | &8000-&BCD5 | Elite's home bank: the hot pass's third container, the ACCCON X blocks first (&8000-&9074: ylookup, SCAN, LOIN, TWOS, TWOS2, LOINQ, HLOIN, TWFL, TWFR, orange, PIX1, PIXEL2, PIXEL, PXCL, DOT, ddot, ECBLB2, ECBLB, SPBLB, SPBT, ECBT, MSBAR, TTX66, CLYNS, DIALS, PZW2, PZW, DILX, DIL2, DILI, DSEG, ADDK; log, logL, alogh page aligned at &9100-&93FF), then the rest of the hot pass in the source's order (cntr ... LASLI, GINF, TT69, TT67, TT24, ee3, the text printers cpl to ex and QQ18IX, DOEXP, the planet and the sun, the main game loop, Ze, BAD, DEATH, WARP, DOKEY, TT217, me1, MESS, mes9, OUCH, TIDY ... LL9, MVEIT to PLUT, LOOK1, SIGHT, TT66, TTX66K, FILLKL, ZEKTRAN ... EXNO, F% at &B8C6); then the hot data HAZEL has no room for (QQ18 &B8C6, SNE &BC86, ACT &BCB6) | 810 |
| Cold pass | bank 7 &8000-&A65C | the cold pass, one run: the cold routines in the original's order (the zero-page save, the start-up, DOENTRY, the extended token printing DETOK ... MT29, STATUS, HME2, the launch, the missions, PAUSE, the charts and the market screens, hyperspace, QQ23, the equipment, SOLAR, YESNO, RESET and RES2, the title and start-up, save and load, DKS3, COLD, DOSCLI ...); then the cold data in the original's order (the extended tokens TKN1, RUPLA, RUGAL, RUTOK) | - (bank 7's end) |
| Meridian window | bank 7 &A65D-&B573 (ROMSEL 7; MERID, its own image, with gfx-kept7.asm after it) | gfx-merid.asm, the beach ball planet's boundaries (PM_HOOK, PM_MERID) | 2700 (bank 7's end) |
| Rasteriser: polygon window | ANDY &8000-&8FE4 (ROMSEL &85) | gfx-raster_poly.asm, gfx-raster_line.asm | 27 |
| Rasteriser: disc window | bank 5 &8000-&8F2F (ROMSEL 5) | gfx-raster_disc.asm, gfx-raster_kept.asm | 208 |
| Rasteriser: shared region | bank 5 &9000-&BF94 (with either window) | gfx-raster.asm, gfx-flare.asm, gfx-raster_lcold.asm | 107 (+ 808 at &98D8, below the per-x tables at &9C00; + 256 in the tails) |
| Frame layer | bank 6 &8000-&BFF9 | gfx-frame.asm, faces, lighting, frame_cold, the flare's step, the hangar's frame and tables | 6 |
| HAZEL | &C000-&DD94 | the hot data, elite-data.asm's order from &C000: XX21, E%, KWL%, KWH%, the blueprints from the missile's to the Dodo's | 363 (&DD95-&DEFF), 256 (&DF00-&DFFF: the MOS's) |
| Shadow &3000-&3FFF | &3090-&30FF | the zero-page save (setzp/getzp) only; nothing new goes into shadow RAM | 144 (&3000-&308F), 3840 (&3100-&3FFF) |
| Buffer 1, dashboard | shadow &4000-&7DFF | the screen (rule 6) | - |
| Shadow &7E00-&7FFF | | unused (not displayed) | 512 |

The loader (`M128Elt`) loads each file to &1300 and copies it into place
(FTAB): BDATA (the dashboard image), BANK4,
COLD7 (the cold pass, to bank 7 &8000), RASTA (the
rasteriser's polygon window, to ANDY with ROMSEL &85), BANK5, BANK6, HAZEL (staged at
&4000), HICODE (the quarter-square tables and the hot pass's part from &7400, to
&7000-&7FFF); then it loads BCODE (the glue area, the low pass and the hot
pass's main RAM part) to CODE% (&1E16, from the build). The loader is at &0E00, in the shared workspace's place, so
its last part runs from K% (&0400; the game sets K% up itself): it takes
DFS's and the MOS's lasting bytes into DFSST and DFSST2 after the last
disc access,
copies HAZEL into place and calls G_INIT, which sets up the rest of the
workspace.

### Why each region holds what it holds

* **Main RAM below the main code** holds the renderer's shared workspace:
  variables that the rasteriser, the frame layer, the game's hooks and the
  IRQ handler share. Below &3000 every one of them sees it, whatever bank is
  paged and whatever ACCCON X is; the renderer initialises it (R_INIT,
  F_INIT), so it needs no image. The page &0D below it is never written, and
  below that WP fills the MOS's buffers at &0840-&0CFF that the game never
  uses (docs/MASTER-MEMORY.md).
* **The glue area** is the port's own code, below &3000: what runs with X =
  1, from the IRQ or with any ROM paged (the text and IRQ hooks, TTX66M, the
  renderer's shared variables), and what pages banks (the stubs between the
  passes, the G_ stubs and the T_ trampolines), which must be in main RAM.
  No original code is in it.
* **The low pass** is the original's code that must be below &3000 (rules 1
  and 2), in the source's order; it is what the head was, less what does not
  need to be there.
* **The hot pass** is the rest of the game code, which runs with bank 4
  paged: main RAM below buffer 0 and under the dashboard and bank 4 are one
  space to it, so it flows through them in the source's order; only its
  ACCCON X code and tables need bank 4 (rule 1). Main RAM from &7000 (under
  the dashboard, shown from shadow RAM) holds the quarter-square tables first,
  as they are read with bank 4, 6 or 7 paged (the maths, and the lighting in
  bank 6). The text printers (TT27, ex, BPRNT, MESS ...) are hot, so they call
  TT26 directly; the extended-token printer DETOK stays cold with its 3.5K of
  tables, which bank 4 has no room for.
* **The cold pass** holds the code that runs on docked screens or a few
  times a flight, where the crossings are rare (0.015 a flight iteration
  now): what crosses often went hot (crossings.py, "Calls between the
  passes").
* **Bank 5 and ANDY, and bank 6** are the renderer's, and the renderer is
  nowhere else (but the meridian window, in bank 7 after the cold pass).
* **HAZEL** is visible whatever bank is paged, so it holds the game data
  (rule 5), in the original's order; DOSCLI's stash lets it sit anywhere in
  HAZEL (rule 8).
* **Shadow RAM** outside the screen holds only the zero-page save; nothing
  more goes there.

## Calls between the passes

The hot side (the low and hot passes, the glue area, the game data) calls
and reads itself directly, as bank 4 is paged whenever game code runs; the
cold pass calls and reads itself directly. Every call from one side to the
other goes through a stub of its own, in the glue area (main RAM below
&3000, seen with either bank paged), one per target, which tools/streams.py
writes (build/elite-stubs.asm):

    .TT22                     the hot side calls cold TT22 by its name
     JSR to7                  page bank 7 in, A and the flags kept
     JSR TT22_C               the body, in the cold pass
     JMP to4                  page bank 4 back, A and the flags kept, and return

    .x4_LL5                   the cold pass calls hot LL5 through x4_LL5
     JSR to4
     JSR LL5
     JMP to7

    .TT170                    a jump, for a target that never returns
     JSR to7                  (TT170, BAY, DEATH2; j4_BEGIN, j4_GOIN, j4_FRCE)
     JMP TT170_C

A stub knows its caller's bank: every caller of a stub into the cold pass
runs with bank 4 paged (NEWBRK, which the MOS enters with any ROM paged,
pages bank 4 first), and every caller of a stub out of it runs with bank 7
paged. So a stub keeps no frame: the target sees only the stub's return
address above its caller's (two bytes more than a direct call). A, X, Y and
every flag reach the target as they were and come back unchanged. to7 and
to4 write &F4 before ROMSEL, from main RAM, so an interrupt between the two
writes that paged a bank and put ROMSEL back from &F4 would page the bank the
stub is about to page anyway (no handler pages a bank now). The one stub that
keeps the caller's bank is TTX66M, for CHPR, written in elite-stubs.asm.

A call through a stub costs 85 cycles more than a JSR: 6 for the JSR to the
stub, 35 for to7's JSR and body, 6 and 6 for the JSR to the target and its
RTS, 3 for the JMP and 29 for to4's body and RTS. Written out in full
(streams.py's INLINE, empty: nothing crosses often enough) a stub would
cost 70, for 17 bytes more. The far calls it replaced (far7, far4: the
target's address read through the stack and a self-modified operand, the
caller's bank kept on the stack) cost about 171.

The cold pass calls the low pass's routines that need nothing of the hot
side directly, with no stub: BEEP, BOOP, CHPR, DELAY, DOVDU19, NOISE,
SOFLUSH, TT67K and WSCAN (streams.py's direct_calls: the block, and every
low block it calls, branches to or falls into, refers to nothing hot or cold
and to no glue code but the bank-keeping text hooks and TTX66M; listed in
build/direct.txt, which bankcheck.py reads).

| Kind | Where | Count | Pages |
|---|---|---:|---|
| stubs into the cold pass (`.X`, STUBS7) | the glue area | 38 | bank 7 in, bank 4 back |
| stubs out of the cold pass (`.x4_H`, `.j4_H`, STUBS4) | the glue area | 57 | bank 4 in, bank 7 back |
| TTX66M | the glue area | 1 | bank 4 in, the caller's bank back |
| G_ stubs | the glue area (gfx-gstubs.asm, 13; G_CHAR, G_DELCHAR, G_CLRTEXT in gfx-gluehooks.asm) | 16 | bank 6 in (G_MERHOOK: the meridian window, bank 7), bank 4 (or, for the text stubs, the caller's bank) back |
| T_ trampolines | the glue area (gfx-tramp.asm) | 13 | the rasteriser in (T_POLY, T_LINE: ROMSEL &85, ANDY over bank 5; the rest bank 5), or the meridian window (T_MERID: bank 7), bank 6 back |

A routine that falls through into a routine of the other side falls into a
seam: a JMP to that routine's stub, at its place in the falling routine's
pass. The stub calls the routine, which returns to the falling routine's
caller with the caller's bank back, as the fall-through did: RES2 into
ZINF, SOLAR into NWSTARS, LAUN into HFS2, TTX69 into TT69 (cold into hot),
BEGIN into TT170 (hot into cold, a jump). The harness (harness/mlib.mjs callerAt, agentplay's _callerAt) sees
through a stub by its address range: a return address in STUBS7..STUBS7_END
belongs to a stub whose caller ran with bank 4, in STUBS4..STUBS4_END with
bank 7.

**Which side a routine is on** is measured. master/tools/grind/crossings.py
reads a build's analysis (analyse.py --no-ranges) and the gate's profile of
it, counts every call by its caller's and its callee's block, and gives for
each cold block the crossings that moving it hot would remove (its calls of
the hot side and the hot side's calls of it) and create (its calls of the
cold pass and the cold pass's calls of it). In the gate's run, 87cf524 made
0.703 crossings a flight iteration (171 cycles each: 120 an iteration) and
11455 off flight, 98% of them x4_TT26 from the cold text printers; with the
direct stubs and the text printers and their tables hot, 0.098 a flight
iteration and 4562 off flight (85 cycles each: 8 an iteration); after the
blocks crossings.py ranked best (MT14 and MT15, HFS2, ee3, Ze, FRS1, FRMIS,
ANGRY, FR1, TT66 and TTX66K, TT69 and TT67, BAD, ESCAPE, TT24), 0.015 a
flight iteration and 3738 off flight.
What would create more crossings than it removes stays cold: TT20 and TT54,
which the charts call 256 times a screen, TT111, which calls them, DETOK
(tables too big), the chart and market screens.

tools/bankcheck.py checks the rules for every reference in the source (in
elite-source.asm's per-container copies): branches never cross areas; cold
code reaches main RAM and bank 4 code only through stubs (or the low labels
in build/direct.txt, which must be below &3000) and never reads bank 4 data
(an address, #LO/#HI, is not a reach); the hot side reaches cold code only
through stubs and never reads cold data; the stubs may refer to anything and
anything may call them; shadow data is read only by readers marked
`bankcheck: ok`; the renderer's banks (bank5, the shared region, with its
windows bank5d and bank5a, which never refer to each other and to which the
shared region never refers, but where marked; bank6) are entered from
elsewhere only through the stub files or by address, call nothing in another
bank, read no other bank's data and read main RAM only below &3000; HAZEL and
the shared workspace are visible to every area. Deliberate exceptions are
marked `bankcheck: ok` on the line.

## What is not in the original's order

The game side is the original's BCODE and BDATA, each block at its place in
elite-source.asm or elite-data.asm, emitted per pass in the source's order.
What remains out of that order, each with a `Port:` note where it applies:

* **The passes themselves**: memory follows the source's order within each
  pass and container, not across them: the low pass is first, the hot pass's
  ACCCON X blocks lead bank 4 (they come first in the source but cannot be in
  main RAM), and the cold pass is apart. The low pass holds what the head held
  less VEC, T1SYNC, pxpatd and pxpat, HANGFLAG (now hot), ADDK and the log
  tables (hot, ACCCON X), and stackpt and NEWBRK, at their place at its end.
* **Seams**: the original fall-throughs that cross the hot/cold line fall
  into a JMP to the stub at the next routine's place (RES2 into ZINF, SOLAR
  into NWSTARS, LAUN into HFS2, TTX69 into TT69, BEGIN into TT170); the
  stubs themselves are in the glue
  area, not in the source. MLU1 joins MU11 with BRA, as the port's MULTU falls
  into it.
* **Port routines placed next to the original routine they serve**: pxpatd
  and pxpat (PIXEL), ddot (at CPIXK's place), DILI and DSEG (after DIL2),
  DOSCLI and DOSNMI (at the end of the cold code), LL9F and LL9B (LL9 then a
  frame of the renderer: the title's and escape pod's, the briefing's, before
  LL51L); TT51w and TT49w sit before ex, out of the way of its scan loop.
* **Port lines in original routines that the layout needs**: NEWBRK pages
  bank 4 itself; the log tables align themselves (`ALIGN &100`: they followed
  the three-page font); JMTB names its hot targets' stubs (x4_TT27, x4_MT14,
  x4_MT15, x4_DASC, x4_MT16, x4_CLYNS); TKN2 runs on into QQ16.
* **Removed**: the original's direct drawing of ships, as every LL9
  records (LL9's line drawing in parts 9 to 11 and its LSNUM/LSNUM2 set-up,
  LSPUT, LSCLR's erase loop and Shpt, each original routine with its
  header and a `Port: removed` note), the original's unreachable code (each
  with a `Port:` note), the workspace noise that padded QQ18 to &A000, the
  second unused page of BDATA (not assembled: the blueprints are not after
  it), and Master's dashboard tables SCTBX1, SCTBX2 and wtable, which the CMYK
  dashboard replaces.
* **Port additions outside the source**, in their own files with headers
  saying why: the glue area (elite-glue.asm: elite-stubs.asm and the
  renderer's glue), the quarter-square tables (elite-qs.asm: QSL/QSH, at
  &7000), the renderer (elite-gfx.asm, with the hangar's frame, gfx-hangar.asm,
  and its tables, gfx-hangar6.asm, at the end of bank 6's image), the CMYK
  dashboard's tables (generated, build/dashtab-*.asm, each INCLUDEd in its
  routine's block) and its variables DASHV (after WP).
* **Placement by the build, not the source**: CODE% (&1E16) is chosen so the
  font starts a page without padding; the hot pass's containers and the hot
  data's are filled by the flow (build/flow.txt), not by markers.

## The exchange rate: cycles per byte

Every region is close to full, so a speed-up that costs bytes has to be paid
for by bytes found elsewhere. The exchange rate says what a byte is worth.

**Method.** For each of the grind's commits (c46cd31..4737aab, 254 commits):

* *bytes*: the build's free bytes in every region (the free figures that
  compile.txt prints, and &4000 minus BCODE's end) before and after the
  commit, summed; a fall is bytes spent. Commits that padded their code to
  keep later code in place report the padding as spent; for the six largest
  (MVS5's demo form, MALC, MALW, LL51's inline products, PLL4F, STL1's
  inlined DV42) the cost is instead the size of the code as it is now
  against the original's.
* *cycles*: the flight cycles per iteration of the gate's run, measured
  exactly with profile.mjs on the commit and its parent (the emulation is
  deterministic: the same build gives the same cycles to the cycle) for 52
  commits, the rest from the commit message's own estimate (which the
  measured ones match: median measured/estimated 1.01 over 40 commits).
  Moves, features and the flare (which the gate never shows) are left out.

**Result.** 67 commits spent bytes: 1581 bytes for 18220 cycles per
iteration, 11.5 cycles a byte on average (median 10.9). Ranked best first,
the first 340 bytes bought 14000 cycles (better than 7 cycles a byte), the
next 340 bytes 2000 more, and the last 900 bytes 2200 more, at 1 to 3 cycles
a byte (MALW 2.1, MALC 2.2, MVS5 2.4, LL51 2.7): the transfer wave's large
unrolled and inlined routines, paid for by moving code into banks 5 and 6
and HAZEL behind far5 and far6.

**The margin is 2 cycles per flight iteration per byte.** That is what the
grind was paying at the end. A change that buys cycles for bytes is worth
making when it beats it; one below it should give its bytes back; a byte
found for nothing is worth 2 cycles an iteration to the next speed-up.

**Applied.**

| Change | Cycles per iteration | Bytes | Rate |
|---|---:|---:|---:|
| backed out: R_STARPLOT's size dispatch (6d22763) | +26 | -28 (bank 5) | 0.9 |
| backed out: r_sw's twice-unrolled .la (5def376) | +21 | -11 (bank 5) | 1.9 |
| backed out: MAL2's unrolled copy (c93537e, d0ebe66, 4599656), worthless since MALC took slots 0-5 | about 0 | -33 (main) | 0 |
| new: STL1 does DVID4z inline | -231 | +28 (main) | 8.2 |
| new: PLL4 does ADD inline twice | -123 | +48 (main) | 2.6 |
| new: BLINE makes H_BPT's test itself | -42 (est.) | -2 | - |

The rest of the bytes came for nothing (no cycles lost except to page
crossings, see below): far5, far6 and their 33 stubs, alignment and
keep-in-place padding, dead code (r7_xo, r7_j, f_clamp, H_BLOIN, r_cyrow,
r_wlu, the meridians' scaffolding), the alignment gap before QSL, and the
rasteriser's bank 7 layout. MALW, MALC, MVS5 and LL51's products sit at the
margin: they are the first to give their bytes back if a speed-up beating
2 cycles a byte needs main RAM or bank 4.

The memory relayout bought room in the renderer's banks and HAZEL with
cycles below the margin, as bytes are worth more there than the cycles they
cost:

| Change | Cycles per iteration | Bytes | Rate |
|---|---:|---:|---:|
| r_wclear: an 8-row loop, not 192 unrolled STZs | +127 | -629 (bank 5) | 0.2 |
| bank 7's dirty repair computes a row's run page (r7_rp) | +68 (est.) | -192 (bank 7) | 0.35 |
| r_div8 a loop (divisions with a small divisor only) | a few | -83 (bank 5) | - |
| R_LINE whole in bank 7 (no r_call7 hop on the fast path) | -12 (est.) | -871 (bank 5), +825 (bank 7) | - |
| the 16-bit polygons' phase A in bank 7 (a cold path) | about +5 | -1241 (bank 5), +988 (bank 7) | - |

and for nothing: x DIV 4 (r7_fr) and r7_jl computed from r7_jr, r7_lm and
r7_rm cut to their four distinct entries, the dead R_WMERGE, T_WMERGE and
T_CLEARALL, and the keep-in-place SKIPs.

R_LINE's move into the polygon window (MASTER-PLAN.md, "R_LINE in the
polygon window") found its bytes without spending cycles:

| Change | Cycles per iteration | Bytes | Rate |
|---|---:|---:|---:|
| R_LINE clips exactly, one path for every clipped line (no clip stepping, clipped loops, r7_lc16 or old long path) | -64 | -1305 (bank 7) | - |
| R_LINE's copies of the 32-bit maths, r_pset, the masks and the DIRTY high bytes gone (it uses the polygon window's and the shared region's) | -5 | -211 | - |
| R_INIT and R_RESETBUF into the disc window; the polygon window's arithmetic and R_LINE's cold part into the shared region; R_LINE's variables into a tail | 0 (page crossings -14) | - | - |
| not made: R_LINE builds its colour table only when the colours change | -16 | +22 (ANDY) | 0.7 |

The last is below the margin (and ANDY has 38 bytes left), so it was
measured and left out.

Page crossings are measured apart (profile.mjs --pagex), so that a layout
change's crossings do not count against an optimisation. Over the
rationalisation the gate's run went from 116253 to 115930 cycles per flight
iteration (17.20 to 17.25 it/s): 387 cycles less in instructions, 64 more in
page crossings (668 to 732). Over the memory relayout it went to 116235
(17.21 it/s): 196 cycles more in instructions, 109 more in page crossings
(to 841, mostly r_dla's loop and r_ypg, which the code's new positions left
across page boundaries). With the blueprints in HAZEL (MASTER-PLAN.md) it
went to 116187 (17.21 it/s): 11 cycles fewer in instructions (the far calls
that WARP and HLOIN2 no longer make, less what other moves cost), 37 fewer
in page crossings (to 804: R_WR page aligned, the maths and stardust code at
new places). The final alignment pass recovers what crossings it can.

## Alignment candidates for the final pass

The layout keeps alignment only where correctness needs it: the font and the
log tables (operands' low bytes are the argument), QSL/QSH (patched low
bytes), the row-run pages of bank 5, F_HW and F_HW2 sharing a low
byte, fl_or and fl_or1 sharing a page, each pair of boundary arrays (R_BD*)
sharing a low byte, raster_vars' fixed place (f_sight2), R_NDISCL page
aligned (R_NDISCL,X), and the zero-page and table
assertions next to the code that depends on them. Alignment for speed alone
was taken out; what the order of things gives for nothing is kept (R_BDN
and R_BDX0 at low bytes &00 and &40 in the boundary block; r7_jr
four bytes into a page; the shared workspace's arrays at the low bytes they
had in HAZEL, R_NDN, R_WL and R_WR whole in a page). This is what alignment
would be worth now, from profile.mjs --pagex (cycles per flight iteration of
the gate's run, 804 in all):

| Candidate | Cycles |
|---|---:|
| the stardust multiplies' quarter squares (QSL/QSH +- b, patched; mlq3, mlq5, mla3, mla5, mlb3, mlb5, madq): data-dependent, not alignable | 111 |
| r_dla's row loop within one page (it straddles &B500: its BNEs at r_dla+17, +22, +30, +39) | 96 |
| raster_vars' arrays read across a page (R_DIRTYL0 at &13F5: r_dmb, phase B's r_pt60/62/410/412; R_NDP at &19F8: r_dmb, r_dpe; R_DISCR0 at &1575: r_dla, r_dp2, r_dmb): raster_vars moves only by &100, so by reordering its arrays | about 90 |
| F_HW, F_HW2 page-aligned, with f_disc's loops (fpr16 BCC fpr2 28, fsy_cp BNE fsyl 23, fpr_ld2 10, fpr_b2 8, fsyl 8, fpr_b1 7) | 89 |
| bank 7's dirty repair (r7_rowrep) and line loops (r7_lgo) (now: see "With the rasteriser in ANDY" and "With R_LINE in the polygon window" below) | 62 |
| branches across a page in r_dp2 (its BRA at +107 13, +166 6) and R_STARERASE (+253 12, +193 7) | 45 |
| the frame layer's ft_sr1 10, fsg_m2 7 and fwc2 5 (new: bank 6's data moved by f_b0new's 80 bytes) | 31 |
| STL1's SZ,Y (WP: the stardust's z) and stl_dvr, stld (the stardust loop, at a new place) | 28 |
| bank 4: EE3K 11, LL51L's LDY lfr2s table 10 | 27 |
| phase B's reads of r_tb (R_PTB at &10CB: r_pbr1/r_pbr2) | 20 |
| r_bstore's stores to R_BDX1 (low byte &C0 in the boundary block; R_BDX2 and R_BDX3 are gone, two boundaries are kept) | 17 before |
| MU8, DVID3B, DVL9a, mad1's BPL add1, SOUL8/SOUL3 (the sound IRQ) | 14 |
| new with the lighting in bank 6 (bank 6's code moved): f_text1's row loop, its BEQ ft18x and BPL ft11 across a page (about 23 each), and the run's code from &7400 and in bank 4 moved by 1K (MLTU2c, MAD, PLL4F, DVL9l: about 70) | about 115 |
| new with the garbage collection (bank 4's code moved down 1-36 bytes): LL132 2.9, DOT 1.1, MV3 0.8 (it removed more crossings than it made: LL57S 10.8, r_pt416 11.5, R_STARPLOT 5.7, r_dp2 5.2, mlt3 2.5, LL69 1.9, scd2 1.4 fewer) | 5 |
| the rest (about 400 places, each under 5) | about 174 |

**With the rasteriser in ANDY** (MASTER-PLAN.md, "The rasteriser in ANDY"),
the crossings went from 817 to 688 cycles per flight iteration (on c5feb02's
tree). Most code moved by whole pages or kept its low bytes (phase B's
crossings are now ANDY's), and the new places removed r_dla's straddle (96 ->
10), r_dp2's 17 and 55 in main RAM (BCODE moved down by r_call5/r_call7's 71
bytes: fkc, fkc1, mlb6, MVS5 ...). The new or larger crossings, the
candidates now: r_dpe 41 (+12), the dirty repair r7_rowrep 26 (it was 31 in
bank 7), r_dq 26 (+21), r_dp2 25, r_segw 16 (+5), r_drg 8 (+4), R_STARERASE
10 (+3), all in bank 5 (the disc window and the shared region); in the
polygon window nothing new (r_pf8 4).

**With R_LINE in the polygon window** (MASTER-PLAN.md, "R_LINE in the
polygon window"), the crossings went from 688 to 674 cycles per flight
iteration. Phase B moved down 105 bytes (r_div8 and r_dvq left ANDY), which
took away its crossings at pb_norun_e/o, pb_rb_o, pb_d2_e, pb_l2_e, pb_lb_o
and pb_c_o (19 in all). The new ones, the candidates now: r_pf8's loop
(its BEQ at r_pf8+&C5, BPL at +&D0 and BRA at +&DF, 4.2 more, 8.0 in all),
phase B's BCS at r_pt410+3 (2.6), and R_LINE's loop lyr, whose BCCs back to
lyr at lyr+&36, +&40 and +&4C cross into the page before (4.4; in bank 7 it
was lxu's, about 4). R_LINE's reads of R_DIRTYL/R_DIRTYR,X cross as they did in
bank 7 (26, with raster_vars' arrays above).

**With the source in the original's order** (MASTER-PLAN.md, "The source in
the original's order"), the crossings went from 674 to 749 cycles per flight
iteration (9cafcd9 to now; instructions 115292 to 115295). The main code
from TACTICS on moved (TACTICS, SESCP, SFS1 and SFS2 went into main RAM,
so the maths from MLS2 to DVID4 went into bank 4), and the routines of
bank 4's old tail went back into the run. The new or larger crossings, the
candidates now: the multiplications' mla6 11, mlp 9.5, madq 8.4, mad1 5.3,
mla1 3.1, mlar 3.1, FMLTU 5.1, MULT3 5.0; MVS5 6.3; LL66 3.1, LL130 2.6,
LL132 2.7, MAL3e 2.6 (some fell: mvs5a -3.6, MVS4 -2.9, dll9 -3.0, LL69, DV4r8,
KILL1, LL49 about -1.8 each). On the docked screens and the title ("other"
in the profile) the crossings went from 686 to 1423 cycles per iteration
(0.1% of their cycles), nearly all in the cold area's loops at their new
places: DTL1 +504 (DETOK's), TT51 +245 (the Data on System text), TT59 +39.

**With the exceptions chased down** (MASTER-PLAN.md, "The original's order,
continued"), the crossings went from 749 to 688 cycles per flight iteration
(d23e427 to now; instructions 115295 to 115291). Most of the fall is the
code that moved by the glue's 415 bytes or into bank 4 (DIL -10.9, mla6
-10.9, mlp -9.5, MVS5 -6.3, DVID3B -6.2, SOUL3 -5.8, DVL9a -5.8, FMLTU
-5.1, MULT3 -5.0, LL66 -3.1). The new or larger crossings, the candidates
now: DVL9l 12.7, pl4db 6.9, BL5 3.9, PLUT 2.6, DVL9 2.5, LL86 2.1, MAL2e
2.0, DV14 and DV14z 1.9 each, ddl (the dashboard's dot loop) 1.6, MVT6 1.5,
LL54 1.5, DK4 1.0. On the docked screens ("other") 1423 to 1369.

**With the stubs inline** (MASTER-PLAN.md, "Far-call stubs inline"), the
crossings went from 688 to 706 cycles per flight iteration (e932f77 to now;
instructions 115290 to 115289). The run's code from the first moved stub on
moved by up to 45 bytes in main RAM (9 stubs) and up to 195 in bank 4 (39),
and the cold area's code by the stubs at their places. The new or larger
crossings, the candidates now: DIL 10.9 (its branch at DIL+46), lf3s 5.1
and lf2s 4.9 (the stardust's), dll28 3.9, MVT1 3.4, LL55 3.1, MA26 2.6,
LL21 2.1, LL69 1.9, LL83 1.3; gone: pl4db 6.9, SOUL8 5.8, PLUT 2.6, LL86
2.1, PX21 and PX23 1.8 each, MVT6 1.5, LL54 1.5, DK4 1.0. On the docked
screens ("other") 1369 to 1496: EE2 +218 (its branch at EE2+3, the docked
screens' wait), PLFL2 and PLF13 +60 together, TT27_C +10, DAL6 +9, TT184_C
+9; DTL1_C -61, TT51_C -30, SOUL8 -24, TT135_C -22, TT43_C -18, BL8 and BL10
-29 together.

## Free space

Bytes free in each region before the blueprints moved to HAZEL (d090015),
with the rasteriser in ANDY (cb2c8e5), with R_LINE in the polygon window
(9cafcd9), with the source in the original's order (d23e427), with the
exceptions chased down (e932f77), with the far-call stubs at their
routines' places (0bd6fc4, MASTER-PLAN.md, "Far-call stubs inline"), with
the hangar drawn by the renderer (b583ecc, MASTER-PLAN.md, "The hangar"),
with the briefing's ship drawn by the renderer and the direct drawing of
ships removed (7e822e5, MASTER-PLAN.md, "The briefings"), with the run
continuing from &7000 into bank 4 (5b7b91e, MASTER-PLAN.md, "One run from
&7000"), with the lighting in bank 6 (MASTER-PLAN.md, "The lighting
in bank 6"), at 87cf524 (after the beach ball, the kept solid rows and the
smaller shared workspace, below) and now, with the source in three passes
(MASTER-PLAN.md, "Three passes"). The renderer's banks also have room in
their run pages' tails, for variables and routines of under 66 bytes each.

| Region | At d090015 | At cb2c8e5 | At 9cafcd9 | At d23e427 | At e932f77 | At 0bd6fc4 | At b583ecc | At 7e822e5 | At 5b7b91e | At the lighting in bank 6 | At 87cf524 | Now |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Low code (then); WP's pages &0840-&0CFF (now: &0840, &0CAA-&0CFF) | 14 | 87 | 87 | 87 | 50 (DASHV at &0CAA-&0CCE) | 50 (DASHV at &0CAA-&0CCE) | 50 (DASHV at &0CAA-&0CCE) | 50 (DASHV at &0CAA-&0CCE) | 50 (DASHV at &0CAA-&0CCE) | 50 (DASHV at &0CAA-&0CCE) | 50 (DASHV at &0CAA-&0CCE) | 50 (DASHV at &0CAA-&0CCE) |
| Shared workspace &0E00-&1EFF | - | 179 (64 below it; 47, 6, 62 in it) | 179 | 179 | 148 (64; 47, 6, 31: it ends at &1EE0) | 138 (64; 47, 6, 21: it ends at &1ED6) | 143 (64; 47, 6, 26: it ends at &1EDB) | 143 (64; 47, 6, 26) | 143 (64; 47, 6, 26) | 143 (64; 47, 6, 26) | 192 (5, 30, 70; 87 below CODE%) | 170 (5, 30, 70; 65 below CODE%, &1E16) |
| Main code (BCODE) | 72 | 213 (1808 below &3000) | 213 | 63 (1784 below &3000) | 218 (1376 below &3000; from &1EE1) | 183 (1376 below &3000; from &1ED7) | 188 (1376 below &3000; from &1EDC) | 192 (1371 below &3000; the briefing's H_CHAR test 5, HAS1's heap pointer 9 back) | 639 (545 below &3000: the G_ stubs and the hooks, 826, in the low area; the run split before TACTICS) | 653 (559 below &3000: G_HANG0 lost the hangar's light) | 316 (222 below &3000 after the head, used by the run) | 109 (the hot pass in main RAM, from &2E49; 439 below &3000, after the glue area and the low pass, used by it) |
| High code | 137 | 565 | 565 | 565 | 1077 (from &7000) | 1317 (from &7000; the far7 stubs left) | 1196 (the hangar's G_HANG0, G_HLL9 and HSUB, G_HANGAR) | 1244 (H_EE31's test, H_LSCLR and H_SHPPT gone) | - (&7000-&77E9: the quarter squares and the lighting; then the run) | - (&7000-&73FF: the quarter squares; then the run) | - (&7000-&73FF: the quarter squares; then the run, into bank 4) | 194 (the hot pass from &7400: its units end there, before bank 4) |
| Bank 4 | 30 | 1901 | 1901 | 2054 | 1897 (to &C000: HANGHEAP left) | 1704 | 1704 | 2057 (LL9's line drawing, LSPUT, LSCLR's erase and Shpt gone; LL9B) | 2854 (the run from &77EA: the main code's and the high code's free space with it) | 3856 (the lighting gone from main RAM: the run starts at &7400) | 3853 | 810 (the ACCCON X blocks first, the log tables page aligned, 140 bytes of padding; the text printers; QQ18, SNE, ACT) |
| ANDY (the cold area's then; the rasteriser's polygon window now) | 5 | 1313 | 38 | 38 | 38 | 38 | 38 | 38 | 38 | 38 | 27 | 27 |
| Bank 7 cold area (&8000-, from COLD7LO) | 271 | 77, 397 | 77, 397 | 3802 (one run from &8000) | 3693 | 3701 | 3952 (the wireframe hangar left) | 3952 | 3952 | 3952 | 89 (bank 7's end, after the meridian window) | 2700 (bank 7's end, after the meridian window: the text printers and the blocks crossings.py ranked went hot) |
| Bank 5 (now: disc window, shared region) | 809 (+ 350 in tails) | 317, 295 (+ 291 in tails) | 137, 131 + 8 (+ 252 in tails) | 137, 131 + 8 (+ 252 in tails) | 137, 131 + 8 (+ 252 in tails) | 137, 131 + 8 (+ 252 in tails) | 137, 131 + 8 (+ 252 in tails) | 137, 131 + 8 (+ 252 in tails) | 137, 131 + 8 (+ 252 in tails) | 137, 131 + 8 (+ 252 in tails) | 16, 107 + 8 (+ 252 in tails) | 16, 107 + 8 (+ 252 in tails) |
| Bank 6 | 274 | 187 | 187 | 187 | 187 | 187 | 4 (185 at 9905a11; the hangar's frame) | 5 (f_direct0's Y, f_sync's test) | 5 (f_direct0's Y, f_sync's test) | 71 (MAXPT 40, F_ST, F_INIT in F_DL, three pads and F_CPO gone; the lighting, 1002, and F_HANG0's light in) | 12 |6 (F_PLANET's planet z test) |
| Bank 7 rasteriser (then: R_LINE and bank 7's other rasteriser code; at cb2c8e5 the extended tokens and R_LINE; now the extended tokens), to COLD7LO | 43 (+ 723 in tails) | 111 | 3328 | - (in the cold area's run) | - | - | - | - | - | - | - | - |
| HAZEL scratch (then), read-only game data zone (d23e427), free (now) | 112 (to &C300) | 82 (&C2AE-&C2FF) | 82 | 82 | 283 (&DDE5-&DDFF, &DF00-&DFFF) | 283 (&DDE5-&DDFF, &DF00-&DFFF) | 268 (&DDF4-&DDFF: the hangar's tables before it; &DF00-&DFFF, the MOS's, see the map) | 268 (&DDF4-&DEFF: HANGHEAP gone; &DF00-&DFFF is the MOS's and is no longer counted) | 268 (&DDF4-&DEFF: HANGHEAP gone; &DF00-&DFFF is the MOS's and is no longer counted) | 268 (&DDF4-&DEFF: HANGHEAP gone; &DF00-&DFFF is the MOS's and is no longer counted) | 283 (&DDE5-&DEFF) | 363 (&DD95-&DEFF: SNE and ACT went to bank 4 after QQ18) |
| HAZEL code (then), glue (now) | 48 | 42 (to XX21) | 42 | 42 | - (the glue is in the low area) | - | - | - | - | - | - | - |
| HAZEL state | 1726 (to &D900) | - | - | - | - | - | - | - | - | - | - | - |
| HAZEL &DC40 block | 289 (to &E000) | - | - | - | - | - | - | - | - | - | - | - |
| Shadow | 7, 3, 16 | 512, 3840, 144 | 512, 3840, 144 | 512, 3840, 144 | 512, 3840, 144 | 512, 3840, 144 | 512, 3840, 144 | 512, 3840, 144 | 512, 3840, 144 | 512, 3840, 144 | 512, 3840, 144 | 512, 3840, 144 |
| Total | 3856 (+ 1073 in tails) | 10262 (+ 291 in tails); 5766 outside shadow RAM | 11868 (+ 252 in tails); 7372 outside shadow RAM | 11871 (+ 252 in tails); 7375 outside shadow RAM | 12363 (+ 252 in tails); 7867 outside shadow RAM | 12373 (+ 252 in tails); 7877 outside shadow RAM | 12315 (+ 252 in tails); 7819 outside shadow RAM | 12721 (+ 252 in tails); 8225 outside shadow RAM | 12721 (+ 252 in tails); 8225 outside shadow RAM | 13803 (+ 252 in tails); 9307 outside shadow RAM | 9449 (+ 252 in tails); 4953 outside shadow RAM | 9056 (+ 252 in tails); 4560 outside shadow RAM |

The three passes (MASTER-PLAN.md, "Three passes") moved code between every
region and cost 373 free bytes outside shadow RAM against 87cf524 (4953 to
4580). The stubs between the passes are 884 bytes (to7, to4, TTX66M and 95
stubs) against elite-far.asm's 184, all in the glue area below &3000; the
low pass gave the room (the head's 2413 bytes, with stackpt and NEWBRK,
became 1504: ADDK and the log tables went to bank 4, VEC, T1SYNC, pxpatd,
pxpat and HANGFLAG to the hot pass), so the hot pass starts at &2E49 and
bank 4 holds the rest. The log tables' alignment in bank 4 costs 140 bytes
(they followed the page-aligned font), and the flow leaves what its next
unit could not use at the end of the two main RAM containers (109 and 194,
counted free). The text printers, QQ18, QQ16 and TKN2 and the blocks
crossings.py ranked moved from bank 7 to the hot pass (bank 7 89 to 2700,
bank 4 3853 to 810, with the stubs' cost and the padding); SNE and ACT
followed QQ18 into bank 4 (HAZEL 283 to 363); CODE% moved from &1E2C to
&1E24, keeping the font page aligned (the shared workspace 192 to 184 free).
The 25 fps cap (MASTER-PLAN.md, "The 25 fps cap") added 14 bytes to the glue
area (H_VSYNC's test, GVLAST), and CODE% moved from &1E24 to &1E16 to keep
the font page aligned (the shared workspace 184 to 170 free); nothing after
the glue area moved.
The planet's z in the depth test (MASTER-PLAN.md, "The planet's z in the
depth test") added 6 bytes to F_PLANET in bank 6 (12 to 6 free); bank 6's
labels after it moved up 6, and only the G_ stubs' targets and the loader's
bank 6 length changed outside it.

The beach ball (branch beachball, BEACHBALL-REPORT.md) added the meridian
window to bank 7 after the cold area (3,342 bytes: bank 7's free space went
from 3952 to 610), H_MERID, G_MERHOOK, T_MERID and four shared variables
to the low area (free below &3000 509 -> 479), H_MERID's call in PL25 to
bank 4 (3856 -> 3853) and f_bounds' test of PM_OK to bank 6 (65 -> 64).

The kept solid rows (SOLIDSPAN-REPORT.md) took bank 7 602 -> 89, bank 5's
disc window 137 -> 16, ANDY 38 -> 27, bank 6 64 -> 30 and the low area
479 -> 46, and put their per-row state KF (192 bytes) in HAZEL (268 -> 76).
KF then moved to the shared workspace (&1E00, where its gap began), and
CODE% a page up to &1FDC: the "below &3000" assert moved from HEAD_END% to
LOW_END%, after the text and IRQ hooks, as the G_ stubs and the drawing
hooks after it run in game context only (every call to them is outside
Elite's ACCCON X windows, which call only the head, the text and IRQ hooks
and the bank 4 dashboard). HAZEL went back to 268 free, below &3000 to 655
(to LOW_END%), the workspace's last gap to 90; the run's marker moved from
TACTICS to HATB (main RAM below &4000: 115 free) and bank 4 went 3853 -> 3622.

The shared workspace then shrank by two pages, with no cycle on any hot path:
the polygon edge tables R_PTA and R_PTB (384 bytes) share R_NDISCR's and
R_NDISCL's places (the new disc spans are live only from f_discs to
R_DISCROWS and f_disc2, before any polygon, and are written afresh each
frame; the tables only within one R_POLY call; R_PTB's reads no longer
cross a page); raster_vars moved down two whole pages (&1333 -> &1133, its
page crossings as measured); DFSST split into two halves of 64 that fill
gaps; the rasteriser's private state R_PRBUF..R_PRCWB (24) went to the end
of bank 5's shared region (131 -> 107 free) and F_DSS (21) to bank 6 (30
-> 6), with its own clears in F_INIT and f_direct0; the star arrays are
NDSTAR (21) long, not 24. The workspace starts at &0E00 and ends at &1E2B
(213 free in it). The main code now starts with the low area, then the
head (VEC to UP), then the run from UP, all of the low area and the head
below &3000 (asserted at HEAD_END%, &2F22): CODE% &1E2C, the head at &25DC
(the font at &2900, padding 0), M% at &2F33, 449 bytes lower than before.
The run's marker went back to TACTICS (316 free below &4000) and bank 4
went 3622 -> 3853. Gate: VERIFY PASS 0.857 11.98 (unchanged).

The lighting in bank 6 (MASTER-PLAN.md, "The lighting in bank 6") gained
1082 bytes outside shadow RAM against 5b7b91e: bank 6 found 1082 (the
planet's curve points 390, 400 less fsg_jj's high byte; the shown text maps
600, their 1536 bytes for 768 of state bytes, less the code that keeps
those; F_INIT in F_DL 79; three pads 6; F_CPO 7) and took the lighting,
1002, and F_HANG0's light, 14, for 66; the lighting left main
RAM, so the run starts at &7400 and bank 4 gained 1002; G_HANG0 lost the
light, 14, in the low area.

The run continuing from &7000 (MASTER-PLAN.md, "One run from &7000")
moved bytes without gaining or losing any: the G_ stubs and the hooks (826
bytes) went from the high code to the low area, below &3000 (545 left
there), and the run's split moved from STARS2 to TACTICS, so the high
code's free space and most of the main code's joined bank 4's, at the run's
end (192 + 1244 + 2057 = 639 + 2854).

The briefing's ship drawn by the renderer and the direct drawing of ships
removed (MASTER-PLAN.md, "The briefings") gained 662 bytes outside shadow
RAM against b583ecc: bank 4 353 (LL9's line drawing, LSPUT, LSCLR's erase
loop and Shpt, 367, less LL9B's 11 and part 1's LDY #0), the high code 48
(H_EE31's record-mode test, H_LSCLR and H_SHPPT), HAZEL 256 (HANGHEAP),
the main code 4 (HAS1's heap pointer, 9, less H_CHAR's space-mode test, 5,
in the low area) and bank 6 1 (f_direct0 lost 6 bytes, f_sync's test took
5). The total above counts HAZEL's &DF00 page no longer (it was counted
free since d23e427, but is the MOS's), so it rose by 406.

The hangar drawn by the renderer (MASTER-PLAN.md, "The hangar") cost 56
bytes outside shadow RAM, against 9905a11: bank 6 181 (the hangar's frame,
gfx-hangar.asm), the high code 121 (G_HANG0, G_HLL9 with HSUB, G_HANGAR),
HAZEL 15 (the floor's rows and the two tans, before HANGHEAP); the cold area
gained 251 (HANGER, HAS2, HAL3, HAS3 and DVID4K removed), the main code 5
and the shared workspace 5 (HANGER's far7 stub in the head went, so CODE%
moved up five bytes, to &1EDC, keeping the font page aligned). Bank 6 is
now full (4 bytes). HAZEL's &DF00-&DFFF, counted free since d23e427, is
the MOS's (its FS numbers and filing-system names, &DF00-&DF47, then its
lasting state): a draft that put the hangar's tables at &DF00, which the
loader copies, hung a disc command.

Putting the far-call stubs at their routines' places (MASTER-PLAN.md,
"Far-call stubs inline") gained 10 bytes: the high code got the 240 bytes
of the far7 stubs back; the run took them at their places (main RAM 45, 35
of it from its free bytes and 10 from the shared workspace's last gap, as
CODE% moved down to keep the font page aligned; bank 4 195, less the 2
bytes the closed seams gave back: 193); the cold area's 48 stubs moved to
their places and got a 49th (DORND2's), and the closed seams gave back 13
bytes (8 more free).

HAZEL's 2063 free bytes for lasting content went to the game data; bank 4's
room grew from 30 bytes to 1882, 1912 now (with the hangar's line heap at &BF00 and
the dashboard's variables), and the high code's from 137 to 565.

WP's move below page &0D (MASTER-PLAN.md, "Low data") left the free bytes
as they were: the 151 now counted in the two rows above (&0E00-&0E40 and
&12AA-&12FF round WP, and WP's pages' ends) were free before too, but not
counted. The shared workspace is 4170 bytes with its alignment, more than
the 16 pages from &0E00 to the main code's first page less one, so the main
code, which starts with the page-aligned font, stays at &1F00; to start it
lower, the rasteriser's bank 5 <-> 7 stubs (71 bytes) could go before the
font, but then R_WR (or R_NDN or R_WL) would cross a page.

The lens flare moved from shadow RAM into bank 5 (MASTER-PLAN.md, "Lens
flare out of shadow RAM"): bank 5 gave 786 bytes and 72 of its tails, HAZEL's
glue 13 (T_FLARE), and the shared workspace got 10 back (the flare's
variables went to bank 5's tails). Shadow RAM outside the screen now holds
only the extended tokens and the zero-page save: 912 bytes there are free
and stay so.

The garbage collection (MASTER-PLAN.md, "Unreachable code removed") took out
the code no execution can reach (master/tools/grind/gcreach.py): 269 bytes,
main RAM 11 (3 below &3000), bank 4 36, ANDY 59, bank 7's cold area 73, bank
5 25 and 65 of bank 7's run page tails. The figures above are after it (bank
4's 1876 before it; the table's 1882 was an earlier build's).

The rasteriser in ANDY (MASTER-PLAN.md) took the cold area's first part out
of ANDY into bank 7 (same addresses), put the rasteriser's polygons in ANDY,
made one set of row runs serve the whole rasteriser (bank 7's 24 went) and
moved the extended tokens from shadow RAM into bank 7. Against c5feb02's
build: outside shadow RAM 3701 free bytes (+ 1066 in the run pages' tails)
became 5766 (+ 291 in tails), 1290 more in all; the rasteriser's own room
went from 48 + 43 (+ 1066 in tails) to 1925 (+ 291), and shadow RAM's
3584 bytes of tokens are free (and stay so).

R_LINE's move into the polygon window (MASTER-PLAN.md, "R_LINE in the
polygon window") made R_LINE 1516 bytes smaller (3217 to 1701: its exact
clipping, and its copies of what the polygon window and the shared region
have gone): bank 7 gained 3217 bytes, &9E00-&AAFF, contiguous with the cold
area's second part at COLD7LO (the cold area itself was as it was); the
rasteriser's windows gave 1701 (ANDY 1275, the disc window 180, the shared
region's end 164, 43 of the 51 bytes before the per-x tables, which the
build now counts, and 39 of page 16's tail). The rasteriser now has 314
bytes free in its windows (+ 252 in the tails) and bank 6 187.

The source in the original's order (MASTER-PLAN.md, "The source in the
original's order") made the cold area one run from &8000 (the cold data,
then the cold code, then its stubs): its 474 free bytes and the 3328 that
R_LINE left are one block of 3802 at its end, &B126-&BFFF. Main RAM fills
to MLS2, the routine before which the run moves to bank 4 (63 bytes free,
against 213); bank 4 has 2054 free (1901). The run and bank 4 together have
2117 free against 2114: LOOK1 gave 3 bytes back (it falls into SIGHT again).

Chasing the remaining exceptions (MASTER-PLAN.md, "The original's order,
continued") gained 492 bytes: the dashboard's first-row copy gave the high
code 512; HAZEL lost its glue (415) to the low area and got 159 back (283 free
round the hangar's heap, against 124); bank 4 lost 157 (the run's head grew by
the glue, so STARS2, MU5 and MULT3 moved to bank 4; it gained HANGHEAP's page
and the dashboard's variables); the cold area lost 109 (the disc commands'
strings and variables are home, and DOSCLI copies the command); WP and the
shared workspace gave 68 to DASHV and to the main code's earlier start.

The two parts of the low area are one: LOW_END%, which marked where the
part used with ACCCON X set ended, is gone, as the whole low area, with the
head, is below &3000 (asserted at HEAD_END%). No address changed.

The hangar's tables (HFY, HPWL, HPWH: 15 bytes) left HAZEL for the end of
bank 6's image, where f_hback reads them; F_DSS (21 bytes, bank 6's only
variable outside it) moved to the shared workspace's top gap to make the
room, so bank 6's other data keeps its addresses (and page crossings).
HAZEL now holds the game data only (283 free to &DF00), bank 6 has 12 free,
the workspace 192.

"High code" is renamed the quarter-square tables (elite-hi.asm is elite-qs.asm,
HI_RUN% is QS_RUN%): QSL and QSH are all it holds. The disc file keeps its
name, HICODE, as it is main RAM &7000-&7FFF: the tables, then the run's
second part. Earlier paragraphs keep the old name.

The low area is renamed the glue area (elite-glue.asm, gfx-gluehooks.asm),
and "low" now names the low pass, Elite's own code below &3000 (MASTER-PLAN.md,
"Three passes"). Earlier paragraphs keep the old name.
