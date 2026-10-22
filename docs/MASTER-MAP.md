# The memory map: BBC Master Elite with the filled renderer

This is the layout of the port: where each part of SNG47 Master Elite and of
the filled, dithered and lit renderer lives, why it lives there, how code in
one region reaches another, and how much room is left. The figures are from
the build (`master/build/compile.txt`, `master/build/symbols.txt`) and from
the cycle profile of the gate's run (`master/tools/grind/profile.mjs`).
docs/MASTER-MEMORY.md has the hardware side: what the MOS and DFS use, and
which spare RAM the port may take.

## The rules the layout follows

1. **ACCCON X.** With X = 1 shadow RAM appears at &3000-&7FFF and main RAM
   there is hidden. Code that runs with X = 1, and data it reads, must not be
   in main &3000-&7FFF. Master's own drawing (the docked screens' text and
   lines, CHPR, the dashboard, PIX1) and the frame layer run with X = 1 for part of their
   time. What they reach in main
   RAM is below &3000: the font and the log tables, CHPR, ADDK (DIALS and
   PIX1), UP (CATF, FLH, COMC), the dashboard's variables
   (DASHV, after WP), the renderer's shared workspace and its glue (the low
   area). The main code starts with the low area (elite-low.asm), then the
   original's head, VEC to UP, in its order; the run follows UP. The build
   asserts that the head ends below &3000 (HEAD_END%), so the low area is
   below it too: its text and IRQ hooks (to LOW_END%), and the G_ stubs and
   the drawing hooks after them, which are called from game code only
   (X = 0).
2. **Interrupts and MOS vectors.** The IRQ arrives with any bank paged and X
   either way; WRCHV (CHPR) and BRKV (NEWBRK) are entered with any ROM paged.
   Their handlers, and everything they touch, are in main RAM below &3000
   (the low area: NEWBRK, the far calls, the renderer's glue; and the
   head after it), and reach banked code only through far calls that page
   the bank and restore the caller's (NEWBRK pages bank 4 itself first). The
   MOS reads a disc command's string from a copy that DOSCLI makes in screen
   buffer 0 (DOSBUF, &6000), so the strings stay in the cold area.
3. **One sideways bank at a time.** Elite's home bank (bank 4) is paged
   whenever game code runs, so main RAM, HAZEL and bank 4 code call each other
   and read each other's data directly; the main code itself continues from
   main RAM into bank 4. Every other bank is reached through a stub that pages
   it in and the caller's bank back.
4. **ANDY** (ROMSEL bit 7) overlays &8000-&8FFF of the paged bank. It is the
   rasteriser's polygon window (R_POLY and R_LINE), paged as ROMSEL &85
   (RASTPOLY: ANDY over bank 5, whose &9000-&BFFF is the rasteriser's shared
   region); bank 5's own &8000-&8FFF, paged as ROMSEL 5, is its disc window.
   Nothing calls between the two windows, and the shared region, which runs
   with either paged in, refers to neither (but where reviewed and marked).
   **The renderer is in banks 5 and 6 and ANDY, and in one window of bank
   7**: the rasteriser in bank 5 and ANDY, the frame layer in bank 6, and the
   meridian window (gfx-merid.asm, the beach ball planet's boundaries) in
   bank 7 after the cold area, paged as ROMSEL MERIDBANK (7) by its two stubs
   only (G_MERHOOK in game context, T_MERID during the frame). Bank 7 is
   otherwise the cold area's: one run from &8000, the cold data first. (The
   meridian window is the one exception to "the renderer in banks 5, 6 and
   ANDY only", made for the beach ball, which needs about 3K that none of
   those has.)
   &F4 always matches ROMSEL, bit 7 included: every write of ROMSEL writes &F4
   first (the far calls, the G_ and T_ stubs, R_SETBUF's r_sbpoly).
5. **The game data is in HAZEL**, where every bank, the IRQ and code running
   with X = 1 see it, in the original's order from XX21 at &C000 (NWSHP reads
   past E%, E%-1,Y for the planet and the sun, into the missile's blueprint,
   as in the original), followed by the hangar's tables. Bank 4 holds code
   and the tables in it only.
6. **The screen and the split.** Main &4000-&6FFF is buffer 0 and shadow
   &4000-&6FFF buffer 1; shadow &7000-&7DFF is the dashboard. Main RAM under
   the dashboard (&7000-&7FFF) is never on show, as the split is never late
   (docs/MASTER-PLAN.md, "Dashboard split timing"), so it holds the high code
   and the main code's run, which continues there into bank 4.
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
   game's tables (IKNS) and code (LL5's caller) through their banks. The one
   address the compared state holds of data the port moves, the space
   station's line heap pointer (LSO, in WP), is compared as the original's
   (mlib.canonFor).
10. **Each bank keeps its private tables and variables**; the state that
   more than one bank, the IRQ handler or code running with ACCCON X set
   reads is the renderer's shared workspace, in main RAM below the main code
   (one block, &0E00-&1E2B, ending where the main code starts), with DFSST
   and DFSST2;
   the renderer's glue (its shared variables with initial values, the T_
   trampolines, the text and IRQ hooks) is in the main code's low area, below
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
   names the area it lives in. The build assembles each area from the
   source in the source's order ("The source and its emissions", below), so
   memory follows the original's order area by area. What is not in the
   original is the port's own files (the low area's far calls and renderer
   glue, the high code, the renderer) or, inside the source, port routines
   next to the original routine they serve. The exceptions, each with a
   `Port:` note: see "What is not in the original's order", below.

## The source and its emissions

The port's game source is the original's, in the original's order, emitted
once per area: what the user called "the 27K and bank 4 emitted twice, once
hot, once cold". A routine's header says where it lives:

    \       Name: TT219
    \       Type: Subroutine
    \   Category: Market
    \    Summary: Show the Buy Cargo screen (red key f1)
    \       Area: cold

No Area field means the main code's **run**: main RAM from the head (VEC,
&25DC, after the low area, which starts the main code at CODE%, &1E2C),
continuing in bank 4 at &8000 where main RAM ends. `Area: low` is for what
must be in main RAM below &3000 but whose original place is later in the
run: stackpt and NEWBRK (BRKV), emitted first in the low area, before the
head.
`Area: bank 4` is for code that runs with ACCCON X set and does not fit
below &3000 (Master's drawing for the docked screens' text and lines: LOIN, LOINQ, HLOIN,
PIX1, PIXEL, TTX66, CLYNS; the CMYK dashboard: SCAN, DOT, ddot, the bulbs,
MSBAR, DIALS and its helpers) and the tables it reads (ylookup, TWOS, TWOS2,
TWFL, TWFR, orange, PXCL, SPBT, ECBT): bank 4 after the run. `Area: cold`
is the cold area, sideways RAM bank 7. A block runs from its header to the
next one. elite-data.asm's blocks are tagged the same way: no Area field is
the hot data (HAZEL), `Area: cold` the token tables and their macros,
`Area: BDATA` the dashboard image (a block without a name, a banner or the
closing SAVE, goes with the next named block).

BeebAsm assembles with one location counter, and banks 4 and 7 share the
addresses &8000-&BFFF, so the build (master/tools/streams.py) writes one
copy of each source per area, build/elite-source-run.asm, -low.asm,
-bank4.asm and -cold.asm, and build/elite-data-hot.asm, -cold.asm and
-bdata.asm, with the other areas' lines blanked (so the line numbers are
the source's), and elite-layout.asm, the file that build.sh assembles,
INCLUDEs them in turn, each at its own address, in one pass (the data's
labels are the code's addresses: no separate data assembly). Each label is
defined once, in its own area's copy, and each block is assembled once.

Each emission is the original in its order, with a stub wherever a routine
lives on the other side. The hot side is the run, the low area and bank 4;
the cold side is the cold area. Where the source defines a routine of the
other side that this side calls, jumps to or falls into, this side's copy
holds that routine's far-call stub, on the routine's own line ("Calls
between regions", below). So the hot emission reads as the original with
`.TT22 JSR far7 : EQUW TT22_C` where TT22 was carved out, and the cold one
with `.x4_TT26 JSR far4 : EQUW TT26` where TT26 was. The emissions:

* **hot**: main RAM from &1E2C: the low area (elite-low.asm: the blocks
  tagged low, then the port's far calls and renderer glue), then the run:
  its head, VEC to UP in the original's order (the font and the log tables
  at their place after ADDK, page aligned there), then the rest of the main
  code, to TACTICS, where it continues in main RAM at &7400, after the
  high code (the quarter squares, &7000-&73FF), and runs on
  through &8000 into bank 4, to F%; the
  blocks tagged bank 4 after it; and in HAZEL from &C000, the hot data in
  elite-data.asm's order: XX21, E%, KWL%, KWH%, the blueprints from the
  missile's to the Dodo's, SNE and ACT. The stubs into the cold area are at
  their routines' places: 5 in main RAM below &4000 (getzp's before the
  font, DOENTRY's at the head's end), 27 in the run's part from &7400, 15 in its part
  in bank 4;
* **cold**: bank 7 from &8000, one run: the cold blocks of
  elite-source.asm in its order, with the stubs out of the cold area at
  their routines' places among them, then those of elite-data.asm in its
  order (QQ18, then the extended tokens TKN1, RUPLA, RUGAL, RUTOK). Nothing
  in bank 7 is at a fixed address but its start;
* **BDATA**: elite-data.asm's dashboard image, assembled on its own with the
  original's SAVE (&7000-&7EFF), which the loader puts in shadow RAM.

Where main RAM below buffer 0 ends is a marker at a routine boundary that
nothing falls into or branches across: the run moves from below &4000 to
&7000 before TACTICS (a banner that saves BCODE, sets ORG &7000 and
INCLUDEs the high code, elite-hi.asm),
and from there it is one run, through &8000 into bank 4 (elite-layout.asm
saves &7000-&7FFF as HICODE and bank 4 as BANK4). It ASSERTs that main RAM's
part fits, so a change that overflows it says to move the marker to an
earlier routine. The marker was before TACTICS until the kept solid rows'
KF moved from HAZEL to the shared workspace (CODE% a page up): the hangar's
HATB, HALL and HAS1 (231 bytes, after HME2's stub, which nothing falls out
of) then moved to &7400, and as many bytes of the run's end into bank 4.
With the shared workspace two pages smaller and the low area before the
head, the run starts 449 bytes lower and the marker is before TACTICS
again: 316 bytes are free below &4000, at the marker.
CODE%'s low byte is chosen so that the font starts a page with no padding
(the build prints the padding, FONTPAD%): the head's two stubs moved it
from &1EE1 to &1ED7; the hangar's removal of HANGER's moved it to &1EDC;
KF's 192 bytes in the shared workspace moved it a whole page, to &1FDC
(so the head and the low area keep their low bytes and page crossings).
With the low area first, the head starts at CODE% plus the low area's
length (&7B0), so CODE% is &1E2C and the head &25DC, the low byte the
head had.

**The checks** (streams.py, at each build): each tagged block's IF ...
ENDIF is balanced; a block whose code can fall through its end is followed,
in the source, by a block of the same area that is not a marker (each area
is assembled in the source's order, so a block falls into the next block of
its own area; the build flags decide which IF branches count), or by a
block of the other side whose first statement is its entry label: the
falling block then falls into that label's stub, which the build makes if
nothing else needs it. Any other fall-through across areas (between the
run, the low area and bank 4, or from the low area into the cold area) is
an error. Every fall-through is into the routine that follows in the
original, or into a port routine placed to follow it. Four original
fall-throughs cross the hot/cold line and fall into the stub at the next
routine's place, as in the original: RES2 (cold) into ZINF's, Ze (cold)
into DORND2's, SOLAR (cold) into NWSTARS's and BEGIN into TT170's (cold).
A stub that is fallen into calls the routine and returns to the falling
routine's caller with the caller's bank back, which is what the
fall-through did; TT170's is a jump stub, as TT170 never returns.
bankcheck.py reads the copies for its rules.

**The glue is generated from the tags.** The source calls everything by the
original's names. streams.py renames every cold label X to X_C in the cold
copy and turns each JSR or JMP from cold code to a label of the run or bank
4 (H) into a call of a stub, x4_H (far4) or, for the routines that never
return (BEGIN, GOIN, FRCE), j4_H (far4j). It writes the stubs into the
copies, each on the line that defines its routine:

* in the hot copies, `.X JSR far7 : EQUW X_C` for each cold label that the
  hot side refers to (elite-source.asm and the port's files it assembles
  with) or falls into, under X's own name (far7j for BAY, DEATH2 and TT170,
  which never return): 48. A cold block's stubs go in the copy of the hot
  area of the nearest block before it that is not cold (the run's, for the
  low area's blocks), so that a block falling into the cold block falls into
  its stubs; here all 47 are the run's;
* in the cold copy, `.x4_H JSR far4 : EQUW H` for each label cold code calls,
  jumps to or falls into: 49 (DORND2's is the one only a fall-through needs).

Labels at one place (DASC and TT26) share a stub: the earlier is a bare label
on its own line (`.x4_DASC`), the stub is on the later one's. JMTB, the table
DETOK jumps through, names its stubs itself (x4_DASC, x4_MT16, x4_CLYNS), as
it needs their addresses; the build makes a stub for any x4_H the cold code
names. The harness finds cold routines by their _C names (DOSCLI_C, TITLE_C
...), as before.

## The map

| Region | Addresses | Purpose | Free |
|---|---|---|---:|
| Zero page, stack, K% | &0000-&00E3, &0100-&01FF, &0400-&07FF | Elite's workspaces, as Master Elite | - |
| WP | main &0841-&0CCE | Elite's workspace (the original's &0E41-&12A9, each byte at the same place in its page), in the MOS's buffers below page &0D; the commander file buffer commbuf (= LSX2) at &087E; then the CMYK dashboard's variables DASHV (&0CAA-&0CCE, after JOPOS: the dashboard runs with ACCCON X set) | 50 (&0840, &0CCF-&0CFF) |
| Shared workspace | main &0E00-&1E2B | the renderer's shared state, one block ending where the main code starts: R_NDN (&0E00), the rasteriser's per-call inputs (gfx-raster_scr.asm: the vertices R_PXL..R_PYH at &0EC0, in one page; R_NDISCL at &0F00, page aligned, which the polygon edge table R_PTB shares; the line end points, colours and the polygon's rows), R_SS and R_SX (&0FD0, NDSTAR each), DFSIN (&0FFA), R_WL (&1000), DFSST (&10C0, DFS's bytes from &C2C0), R_SY (&1100), raster_vars at its fixed place, two pages below where it was measured (&1133: R_DIRTYR0 at &12B5 for f_sight2; R_NDISCR at &1135, which the polygon edge table R_PTA shares), R_SN, R_SCOL (&1BB8), the kept solid rows' KF (&1C00-&1CBF, in one page: SOLIDSPAN-REPORT.md), DFSST2 (&1CC0, the MOS's bytes from &DFC0), R_WR (&1D00-&1DBF, whole in a page) | 213 (5, 30, 70; 108 at &1DC0, before the main code) |
| Main code (BCODE) | main &1E2C-&3EC3 | the low area, the head and the run's first part, all below &3000 to HEAD_END% (&2F21). The low area (elite-low.asm, &1E2C-&25DB): the blocks tagged low (stackpt, NEWBRK), the far calls (elite-far.asm), the renderer's glue (gfx-gvars.asm with GWARP, the T_ trampolines, the text and IRQ hooks G_CHAR, G_DELCHAR, G_CLRTEXT, H_CHAR, H_DEL, H_VSYNC), LOW_END% (&227B: what runs with ACCCON X set ends), then the G_ stubs (gfx-gstubs.asm) and the hooks in Elite's drawing code (gfx-hooks.asm), game context only. The head (&25DC-&2F21): the original's VEC to UP in its order (the IRQ and sound, DOVDU19, pxpatd and pxpat, HANGFLAG, CHPR, ZES1, ZES2, ADDK, the font FONT% at &2900 and the log tables log, logL, alogh, page aligned at their place, UP at &2F00), with getzp's stub before the font. Then the run from HEAD_END% (DOENTRY's stub, M% at &2F33): the main flight loop, MALW, MALC, stardust, NA%, shpcol and scacol, the hangar's HATB, HALL and HAS1, to the marker before TACTICS (5 stubs of cold routines below &4000) | 316 (222 below &3000 after the head, used by the run) |
| Buffer 0 | main &4000-&6FFF | the screen (rule 6); during a disc command also HAZEL's stash (&4000-&5FFF) and the command's copy (DOSBUF, &6000) | - |
| High code, then the run | main &7000-&7FFF | the high code (elite-hi.asm, &7000-&73FF), with no counterpart in the original: the quarter-square tables QSL/QSH (page aligned at &7000); then the run's second part from &7400 (with 27 stubs of cold routines): TACTICS, DOCKIT and the tactics helpers, SESCP, SFS1, SFS2, STARS2, MU5, MULT3, the maths from MLS2, ..., running on into bank 4 | - (the run's free space is at its end, in bank 4) |
| Bank 4 | &8000-&B0F2 | Elite's home bank, code only: the run's continuation from main RAM, with the stubs of the cold routines whose places are in it (15), to F% (&8000-&A0BE: the maths to DVID4, DVID3B2 and its rare paths, LASLI, DOEXP, the planet and the sun, the main game loop, DEATH, WARP, DOKEY, TIDY and TIS2, SHPPT, LL5 to LL9 (recording only: its line drawing, LSPUT and LSCLR's erase are removed), LL9F and LL9B (the title's and the briefing's frames), MVEIT to PLUT, LOOK1, SIGHT, FILLKL, ZEKTRAN, the sounds, ...); then the blocks tagged bank 4 (&A0BF-&B0F2: Master's drawing, now for the docked screens' text and lines only, and the CMYK dashboard), in the original's order: ylookup, SCAN, LOIN, TWOS, TWOS2, LOINQ, HLOIN, TWFL, TWFR, orange, PIX1, PIXEL2, PIXEL, PXCL, DOT, ddot (at CPIXK's place), ECBLB2, ECBLB, SPBLB, SPBT, ECBT, MSBAR, TTX66, CLYNS, DIALS, PZW2, PZW, DIL (at DILX's place), DIL2, DILI, DSEG | 3853 |
| Cold area | bank 7 &8000-&B08F | the cold emission ("The source and its emissions"), one run: the cold routines in the original's order, with the stubs out of the cold area (49) at their routines' places among them (&8000: the zero-page save, the start-up, DOENTRY, the extended token printing, the number printing, STATUS, ESCAPE, HME2, FRS1, FRMIS, ANGRY, FR1, the launch, the missions, PAUSE, the charts and the market screens, hyperspace, the market table QQ23, equipment, the text printing (TT27 ...), SOLAR, YESNO, RESET and RES2, Ze, BAD, the title and start-up (TT170 ...), save and load (SVE, LOD, CATS, DELT ..., with RLINE, thislong, oldlong and the commands' strings CTLI, DELI, savosc, lodosc at their places), DKS3, MESS, OUCH, TT66, COLD, DOSCLI); then the cold data in the original's order: QQ18 (&9FCB), the extended tokens TKN1, RUPLA, RUGAL, RUTOK (to &B08F) | 3952 |
| Meridian window | bank 7 &B090-&BD9D (ROMSEL 7; MERID, its own image, which also holds gfx-kept7.asm from &BDA6) | gfx-merid.asm, the beach ball planet's colour boundaries: PM_HOOK (game context, from H_MERID through G_MERHOOK: the two great circles' constants, the orientation's one frame in MERIDHOLD + 1, else the radius's or the centre's only), PM_MERID (the frame, from f_bounds through T_MERID: the row loop, or pm_shift, the last rows moved), their workspace and the circles' blocks | 610 (bank 7's end; 89 since the kept solid rows' polygon part, gfx-kept7.asm, followed it: SOLIDSPAN-REPORT.md) |
| Rasteriser: polygon window | ANDY &8000-&8FE4 (ROMSEL &85) | gfx-raster_poly.asm: R_POLY, the 8-bit polygons' phase A (r_pf8, r_pcbd, r_e8, the DDA loops), every polygon's phase B; the 16-bit polygons' phase A (r7_pf16..r7_esgen, r7_e8c, its variables); then gfx-raster_line.asm: R_LINE (its fast path, rl_gen's exact clipping, the line loops, rl_lpat) | 27 |
| Rasteriser: disc window | bank 5 &8000-&8F76 (ROMSEL 5) | gfx-raster_disc.asm: R_DISCROWS and its row code (r_dbm, r_dq, r_dpe, r_dp2, r_drg ...), the dirty repair outside the disc rows (r7_crep, r7_rowrep; r7_j3 is now r_jm at 4 x the column); R_INIT (shorter: R_SETBUF and R_RESETBUF for each buffer), R_RESETBUF, r7_reset1; then gfx-raster_kept.asm, the kept solid rows' bank 5 part (k_commit, k_kill, k_clear: SOLIDSPAN-REPORT.md) | 16 |
| Rasteriser: shared region | bank 5 &9000-&BF94 (with either window) | gfx-raster.asm: the boundary arrays (R_BD*, both buffers, &9000-&997F, with r_rowset, r_dw and r_bstore in the 128 bytes between the buffers); R_SETBUF (and r_sbpoly, which pages the polygon window in for phase B's operands), r_spc; the polygon window's arithmetic (r_div8, r_dvq, rp_mul16, rp_div32 and their variables, &9B19-&9BF7); the per-x tables (&9C00); the 24 row-run pages (&A000-&B7FF, STA ...,Y with Y = the row; their 65-byte tails hold the star records, the variables, small routines such as R_SPAN, R_DOT, R_MARKDIRTY and the disc layer's r_dp1, r_bmn, the high-byte tables R_SETBUF patches from, R_LINE's variables (page 16), and the lens flare's half-width table and variables); the stars, r_lput2, r_ypg; the lens flare (gfx-flare.asm: R_FLARE); R_LINE's cold part (gfx-raster_lcold.asm: rl_mdq, rl_mdqa, rl_long, &BED9-&BF7C), then the rasteriser's private state R_PRBUF..R_PRCWB (&BF7D-&BF94: only the rasteriser uses it, with either window) | 107 (+ 8 at &9BF8; + 252 in the tails) |
| Frame layer | bank 6 &8000-&B172 code, &B173-&BFF9 data | the frame layer (gfx-frame.asm), the faces of the 33 ships (gfx-faces.asm), the lighting tables (gfx-light6.asm) and the lighting's L_SUN and L_REC (gfx-light.asm, which the frame layer calls in game context: they multiply with the quarter squares at &7000), frame_cold (with f_b0new), the flare's step (f_flt: its tests on bank 6's state, then T_FLARE) and the hangar's frame (gfx-hangar.asm: F_HANG0, F_HANGAR, f_hback); then its state: F_HW, F_HW2, F_DL (with F_INIT, gfx-finit.asm, run once before the first frame, after its first 34 bytes), the text map F_TM and the shown cells' states F_ST (one byte a cell for both buffers), the directly drawn stars (F_DSX, F_DSY, F_DSS) | 6 |
| HAZEL | &C000-&DDF3 | the game data, the hot emission of elite-data.asm in its order from &C000: XX21, E%, KWL%, KWH%, the blueprints from the missile's to the Constrictor's, the Cougar's and the Dodo's, SNE, ACT (to &DDE4); then the hangar's tables (gfx-hangar-hz.asm, &DDE5-&DDF3: HFY, HPWL, HPWH); HAZEL.bin ends there | 268 (&DDF4-&DEFF), 256 (&DF00-&DFFF: not for the game's data, which the loader would copy over the MOS's: its FS numbers and filing-system names are at &DF00-&DF47, its lasting state at &DFC0-&DFFF) |
| Shadow &3000-&3FFF | &3090-&30FF | the zero-page save (setzp/getzp) only; nothing new goes into shadow RAM | 144 (&3000-&308F), 3840 (&3100-&3FFF) |
| Buffer 1, dashboard | shadow &4000-&7DFF | the screen (rule 6) | - |
| Shadow &7E00-&7FFF | | unused (not displayed) | 512 |

The loader (`M128Elt`) loads each file to &1300 and copies it into place
(FTAB): BDATA (the dashboard image), BANK4,
COLD7 (the cold area, to bank 7 &8000), RASTA (the
rasteriser's polygon window, to ANDY with ROMSEL &85), BANK5, BANK6, HAZEL (staged at
&4000), HICODE (the high code and the run's part in main RAM, to
&7000-&7FFF); then it loads BCODE to &1E2C (its address
from the build). The loader is at &0E00, in the shared workspace's place, so
its last part runs from K% (&0400; the game sets K% up itself): it takes
DFS's and the MOS's lasting bytes into DFSST and DFSST2 after the last
disc access,
copies HAZEL into place and calls G_INIT, which sets up the rest of the
workspace.

### Why each region holds what it holds

* **Main RAM below the main code** holds the renderer's shared workspace:
  variables that the rasteriser, the frame layer, the game's hooks and the
  IRQ handler share.
  Below &3000 every one of them sees it, whatever bank is paged and whatever
  ACCCON X is; the renderer initialises it (R_INIT, F_INIT), so it needs no
  image. It is one block from &0E00 to the main code; the page &0D below it
  is never written, and below that WP (Elite's own workspace) fills the
  MOS's buffers at &0840-&0CFF that the game never uses
  (docs/MASTER-MEMORY.md).
* **The main code** runs in game context. Below &3000 (to HEAD_END%) is
  what must be visible with X = 1 or from interrupts and MOS vectors (rules
  1 and 2), or whatever bank is paged: the low area first (the blocks
  tagged low, whose original place is later, and the port's far calls and
  renderer glue, to LOW_END%; then the G_ stubs and the hooks, which need
  only game context but page bank 6 in, or are the renderer's side of
  Elite's drawing), then the original's head, VEC to UP, which its order
  puts first in the run anyway. The rest
  may be anywhere main RAM or bank 4 holds it, so the run continues past
  buffer 0 (&4000-&6FFF) at &7000, at a routine boundary where nothing falls
  through or branches across, and runs on into bank 4: main RAM from &7000
  (under the dashboard, which is shown from shadow RAM) and bank 4 make one
  run, &7000-&BFFF, followed by the game data in HAZEL from &C000, as BCODE
  is followed by BDATA in the original. The run's code above &3000 never
  runs with X = 1 (only the blocks tagged bank 4 do: harness/mlib.mjs's
  XTRACE records what runs with X set, and none of it is in main RAM
  &3000-&7FFF over the gate's runs).
* **The high code**, at &7000 before the run's second part, is what must be
  visible whatever bank is paged and cannot fit below &3000: the quarter
  squares (read with bank 4, 6 or 7 paged: the maths, and the lighting in
  bank 6). They have no place in the original. (The stubs into the cold area do have places, their routines',
  so they are in the run, in main RAM or bank 4: game context only.)
* **Bank 4** is paged whenever game code runs, so it holds the run's
  continuation and, after it, the code tagged bank 4: Master's drawing
  (the docked screens' text and lines, run with X = 1: no ship is drawn
  directly any more) and the CMYK
  dashboard (run with X = 1; its variables are at WP's end, below &3000),
  which in the original are early, below &3000, and do not fit there now.
* **The cold area** holds code that runs on docked screens or a few times in
  a flight: it costs a far call (about 100 cycles) to enter, so nothing that
  runs on most flight iterations is there.
* **Bank 5 and ANDY, and bank 6** are the renderer's, and the renderer is
  nowhere else: the rasteriser and the frame layer. They hold no game code.
  The rasteriser is three 4K-12K windows: bank 5 &9000-&BFFF, its shared
  region, is seen whichever window is paged, and holds what both use (the one
  set of row runs, the per-x tables, the boundary arrays, R_SETBUF, r_spc,
  the stars, the flare) and, for room, code of one window's that uses nothing
  of that window's (R_POLY's arithmetic, R_LINE's cold part); ANDY (ROMSEL
  &85) holds the polygons and the lines, and bank 5's &8000-&8FFF (ROMSEL 5)
  the disc layer, the dirty repair, R_INIT and R_RESETBUF, which never call
  each other. The 24 row-run pages leave 65 bytes after each run, which hold
  variables and routines of under 65 bytes.
* **Bank 7** is the cold area's: its code, then QQ18 and the extended tokens;
  then the meridian window (MERID, its own image): the beach ball's per-frame
  constants (PM_HOOK) and row loop (PM_MERID), which runs only while a
  meridian planet is on screen and has nothing to share with banks 5 and 6
  but the shared workspace (the disc layer's R_ND* arrays).
* **HAZEL** is visible whatever bank is paged, so it holds the game data
  (rule 5), in the original's order, and the hangar's tables (which bank 6,
  the hangar's frame, reads: bank 6 is full); DOSCLI's
  stash lets it sit anywhere in HAZEL (rule 8).
* **Shadow RAM** outside the screen holds only the zero-page save; nothing
  more goes there (the lens flare left it for bank 5, the extended tokens
  for bank 7).

## Calls between regions

Main RAM, HAZEL and bank 4 call each other directly. Everything else goes
through a stub; the stubs are of four kinds.

| Kind | Where | Count | Pages |
|---|---|---:|---|
| far7 / far7j stubs (`.TT22 JSR far7 : EQUW TT22_C`), generated into the hot copies | the run, each at its cold routine's place (main RAM 32: 5 below &4000, 27 from &7400; bank 4 15) | 47 | the cold area in, the caller's bank back |
| far4 / far4j stubs (`.x4_TT26 JSR far4 : EQUW TT26`), generated into the cold copy | the cold area, each at its hot routine's place | 49 | bank 4 in, the cold area back |
| G_ stubs | main: the low area (gfx-gstubs.asm, 13; G_CHAR, G_DELCHAR, G_CLRTEXT in gfx-lowhooks.asm) | 16 | bank 6 in (G_MERHOOK: the meridian window, bank 7), bank 4 (or, for the text stubs, the caller's bank) back |
| T_ trampolines | main: the low area (gfx-tramp.asm) | 13 | the rasteriser in (T_POLY, T_LINE: ROMSEL &85, ANDY over bank 5; the rest bank 5), or the meridian window (T_MERID: bank 7), bank 6 back |

far7, far4 and their jump forms are the only far-call helpers (elite-far.asm,
in the low area).
The far7 and far4 stubs are generated from the tags ("The source and its
emissions"): the source calls cold routines, and cold code calls everything
else, by the original's names, and each stub sits at its routine's place in
the other side's emission, where the routine was carved out. The helpers
read a stub's EQUW while the caller's bank is still paged in and keep the
caller's bank on the stack, so a stub in bank 4 or bank 7 works as one in
main RAM does. A stub is reached by a call, by a jump or by the fall-through
of the routine before it in the original (RES2, Ze, SOLAR, BEGIN): the stub
calls the routine, which returns to the falling routine's caller with its
bank back, which is what the original's fall-through did.
A far call costs about 100 cycles; in the gate's run the flight iterations
make about 0.5 far calls each (5280 in 10000 MLOOP iterations), nearly all of
them x4_TT26 from the cold area's token printing (the view's name on a change
of view, messages, the hyperspace countdown). The G_ and T_ stubs are the
renderer's hot path by design (about 900 cycles an iteration together).

tools/bankcheck.py checks the rules for every reference in the source (in
elite-source.asm's per-area copies, after the renaming):
branches never cross areas; cold code reaches main RAM and bank 4 only through
x4_/j4_ stubs (an address, #LO/#HI, is not a reach) and the others reach it
only through far7 stubs; the main files' labels assembled at &8000-&BFFF are
bank 4's; shadow data is read only by readers marked `bankcheck: ok`; the
renderer's banks (bank5, the shared region, with its windows bank5d and
bank5a, which never refer to each other and to which the shared region
never refers, but where marked; bank6) are entered
from elsewhere only through the stub files or by address, call nothing in
another bank, read no other bank's data and read main RAM only below &3000;
HAZEL and the shared workspace are visible to every area. Deliberate
exceptions are marked `bankcheck: ok` on the line.

## What is not in the original's order

The game side is the original's BCODE and BDATA, each block at its place in
elite-source.asm or elite-data.asm, emitted per area in the source's order.
What remains out of that order, each with a `Port:` note where it applies:

* **The low area** (`Area: low`): stackpt and NEWBRK are at their original
  place in the source but emitted first in the low area, in main RAM below
  &3000, as the MOS enters BRKV with whatever ROM raised the error and SVE
  (cold) writes stackpt. NEWBRK is one routine again, the original's with
  three lines that page bank 4 in.
* **Stubs at their routines' places**: where a routine lives on the other
  side, each emission holds its far-call stub in its place (generated by
  streams.py, not in the source). The four original fall-throughs across
  the hot/cold line fall into them, so they are the original's code again
  (RES2 into ZINF, Ze into DORND2, whose CLC is back, SOLAR into NWSTARS,
  BEGIN into TT170): no cross-area seam is left. MLU1 joins MU11 with BRA,
  as the port's MULTU falls into it.
* **Port routines placed next to the original routine they serve**: pxpatd
  and pxpat (PIXEL), ddot (at CPIXK's place), DILI and DSEG (after DIL2),
  DOSCLI and DOSNMI (at the end of the cold code), LL9F and LL9B (LL9
  then a frame of the renderer: the title's and escape pod's, the
  briefing's, before LL51L); TT51w and TT49w sit
  before ex, out of the way of its scan loop (a page-crossing measure, for
  the final alignment pass to review).
* **Removed**: the original's direct drawing of ships, as every LL9
  records (LL9's line drawing in parts 9 to 11 and its LSNUM/LSNUM2 set-up,
  LSPUT, LSCLR's erase loop and Shpt, each original routine with its
  header and a `Port: removed` note), the original's unreachable code (each with a `Port:` note),
  the workspace noise that padded QQ18 to &A000, the second unused page of
  BDATA (not assembled: the blueprints are not after it), and Master's
  dashboard tables SCTBX1, SCTBX2 and wtable, which the CMYK dashboard
  replaces.
* **Port additions outside the source**, in their own files with headers
  saying why: the far calls and the renderer's glue (the low area,
  elite-low.asm, with the G_ stubs and the hooks), the high code
  (elite-hi.asm: QSL/QSH, at &7000 before the run's second part), the
  renderer (elite-gfx.asm, with the hangar's frame,
  gfx-hangar.asm), the hangar's tables (gfx-hangar-hz.asm, after the game
  data in HAZEL, elite-layout.asm), the CMYK
  dashboard's tables (generated, build/dashtab-*.asm, each INCLUDEd in its
  routine's block) and its variables DASHV (after WP).
* **Placement by the build, not the source**: CODE% (&1E2C) is chosen so the
  font, at its place after ADDK (in the head, after the low area), starts a
  page without padding; the run's move from below buffer 0 to &7000 is a
  marker before TACTICS.

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
was taken out; what the order of things gives for nothing is kept (R_BDN,
R_BDP and R_BDX0 at low bytes &00, &40 and &00 in the boundary block; r7_jr
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
| r_bstore's stores to R_BDX1, R_BDX2, R_BDX3 (low bytes &C0, &80, &C0 in the boundary block) | 17 |
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
&7000") and now, with the lighting in bank 6 (MASTER-PLAN.md, "The lighting
in bank 6"). The renderer's banks also have room in their run pages' tails, for
variables and routines of under 66 bytes each.

| Region | At d090015 | At cb2c8e5 | At 9cafcd9 | At d23e427 | At e932f77 | At 0bd6fc4 | At b583ecc | At 7e822e5 | At 5b7b91e | Now |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Low code (then); WP's pages &0840-&0CFF (now: &0840, &0CAA-&0CFF) | 14 | 87 | 87 | 87 | 50 (DASHV at &0CAA-&0CCE) | 50 (DASHV at &0CAA-&0CCE) | 50 (DASHV at &0CAA-&0CCE) | 50 (DASHV at &0CAA-&0CCE) | 50 (DASHV at &0CAA-&0CCE) | 50 (DASHV at &0CAA-&0CCE) |
| Shared workspace &0E00-&1EFF | - | 179 (64 below it; 47, 6, 62 in it) | 179 | 179 | 148 (64; 47, 6, 31: it ends at &1EE0) | 138 (64; 47, 6, 21: it ends at &1ED6) | 143 (64; 47, 6, 26: it ends at &1EDB) | 143 (64; 47, 6, 26) | 143 (64; 47, 6, 26) | 143 (64; 47, 6, 26) |
| Main code (BCODE) | 72 | 213 (1808 below &3000) | 213 | 63 (1784 below &3000) | 218 (1376 below &3000; from &1EE1) | 183 (1376 below &3000; from &1ED7) | 188 (1376 below &3000; from &1EDC) | 192 (1371 below &3000; the briefing's H_CHAR test 5, HAS1's heap pointer 9 back) | 639 (545 below &3000: the G_ stubs and the hooks, 826, in the low area; the run split before TACTICS) | 653 (559 below &3000: G_HANG0 lost the hangar's light) |
| High code | 137 | 565 | 565 | 565 | 1077 (from &7000) | 1317 (from &7000; the far7 stubs left) | 1196 (the hangar's G_HANG0, G_HLL9 and HSUB, G_HANGAR) | 1244 (H_EE31's test, H_LSCLR and H_SHPPT gone) | - (&7000-&77E9: the quarter squares and the lighting; then the run) | - (&7000-&73FF: the quarter squares; then the run) |
| Bank 4 | 30 | 1901 | 1901 | 2054 | 1897 (to &C000: HANGHEAP left) | 1704 | 1704 | 2057 (LL9's line drawing, LSPUT, LSCLR's erase and Shpt gone; LL9B) | 2854 (the run from &77EA: the main code's and the high code's free space with it) | 3856 (the lighting gone from main RAM: the run starts at &7400) |
| ANDY (the cold area's then; the rasteriser's polygon window now) | 5 | 1313 | 38 | 38 | 38 | 38 | 38 | 38 | 38 | 38 |
| Bank 7 cold area (&8000-, from COLD7LO) | 271 | 77, 397 | 77, 397 | 3802 (one run from &8000) | 3693 | 3701 | 3952 (the wireframe hangar left) | 3952 | 3952 | 3952 |
| Bank 5 (now: disc window, shared region) | 809 (+ 350 in tails) | 317, 295 (+ 291 in tails) | 137, 131 + 8 (+ 252 in tails) | 137, 131 + 8 (+ 252 in tails) | 137, 131 + 8 (+ 252 in tails) | 137, 131 + 8 (+ 252 in tails) | 137, 131 + 8 (+ 252 in tails) | 137, 131 + 8 (+ 252 in tails) | 137, 131 + 8 (+ 252 in tails) | 137, 131 + 8 (+ 252 in tails) |
| Bank 6 | 274 | 187 | 187 | 187 | 187 | 187 | 4 (185 at 9905a11; the hangar's frame) | 5 (f_direct0's Y, f_sync's test) | 5 (f_direct0's Y, f_sync's test) | 71 (MAXPT 40, F_ST, F_INIT in F_DL, three pads and F_CPO gone; the lighting, 1002, and F_HANG0's light in) |
| Bank 7 rasteriser (then: R_LINE and bank 7's other rasteriser code; at cb2c8e5 the extended tokens and R_LINE; now the extended tokens), to COLD7LO | 43 (+ 723 in tails) | 111 | 3328 | - (in the cold area's run) | - | - | - | - | - | - |
| HAZEL scratch (then), read-only game data zone (d23e427), free (now) | 112 (to &C300) | 82 (&C2AE-&C2FF) | 82 | 82 | 283 (&DDE5-&DDFF, &DF00-&DFFF) | 283 (&DDE5-&DDFF, &DF00-&DFFF) | 268 (&DDF4-&DDFF: the hangar's tables before it; &DF00-&DFFF, the MOS's, see the map) | 268 (&DDF4-&DEFF: HANGHEAP gone; &DF00-&DFFF is the MOS's and is no longer counted) | 268 (&DDF4-&DEFF: HANGHEAP gone; &DF00-&DFFF is the MOS's and is no longer counted) | 268 (&DDF4-&DEFF: HANGHEAP gone; &DF00-&DFFF is the MOS's and is no longer counted) |
| HAZEL code (then), glue (now) | 48 | 42 (to XX21) | 42 | 42 | - (the glue is in the low area) | - | - | - | - | - |
| HAZEL state | 1726 (to &D900) | - | - | - | - | - | - | - | - | - |
| HAZEL &DC40 block | 289 (to &E000) | - | - | - | - | - | - | - | - | - |
| Shadow | 7, 3, 16 | 512, 3840, 144 | 512, 3840, 144 | 512, 3840, 144 | 512, 3840, 144 | 512, 3840, 144 | 512, 3840, 144 | 512, 3840, 144 | 512, 3840, 144 | 512, 3840, 144 |
| Total | 3856 (+ 1073 in tails) | 10262 (+ 291 in tails); 5766 outside shadow RAM | 11868 (+ 252 in tails); 7372 outside shadow RAM | 11871 (+ 252 in tails); 7375 outside shadow RAM | 12363 (+ 252 in tails); 7867 outside shadow RAM | 12373 (+ 252 in tails); 7877 outside shadow RAM | 12315 (+ 252 in tails); 7819 outside shadow RAM | 12721 (+ 252 in tails); 8225 outside shadow RAM | 12721 (+ 252 in tails); 8225 outside shadow RAM | 13803 (+ 252 in tails); 9307 outside shadow RAM |

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
