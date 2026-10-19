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
   in main &3000-&7FFF. Master's own drawing (the docked screens, CHPR, the
   dashboard) and the frame layer run with X = 1 for part of their time.
2. **Interrupts and MOS vectors.** The IRQ arrives with any bank paged and X
   either way; WRCHV (CHPR) and BRKV (NEWBRK) are entered with any ROM paged.
   Their handlers, and everything they touch, are in main RAM below &3000 or
   in HAZEL, and reach banked code only through far calls that page the bank
   and restore the caller's.
3. **One sideways bank at a time.** Elite's home bank (bank 4) is paged
   whenever game code runs, so main RAM, HAZEL and bank 4 code call each other
   and read each other's data directly. Every other bank is reached through a
   stub that pages it in and the caller's bank back.
4. **ANDY** (ROMSEL bit 7) overlays &8000-&8FFF of the paged bank. The cold
   area is ANDY plus bank 7 from COLD7LO, paged together as ROMSEL &87; &F4
   always matches ROMSEL, bit 7 included.
5. **Bank 4 is written.** NWSPS stores the station's blueprint address in
   XX21+2/3, so XX21 is in bank 4 with the blueprints.
6. **The screen.** Main &4000-&6FFF is buffer 0 and shadow &4000-&6FFF
   buffer 1; shadow &7000-&7DFF is the dashboard and main &7000-&71FF a copy
   of its first character row (for a late split). Nothing else lives there.
7. **Page &0D** (&0D00-&0DFF) is never written: the DFS NMI routine, the
   extended vectors and the ROM workspace table are there
   (docs/MASTER-MEMORY.md). The build asserts that nothing is assembled there
   and the gate checks that only DFS writes it.
8. **HAZEL and disc access.** DFS and the MOS overwrite HAZEL &C000-&C2FF,
   &DC00 up to the end of an OSCLI command and &DF00-&DFFF during disc
   commands, and keep their own state at &C2C0-&C2FF and &DFDA-&DFDB. So
   &C000-&C2BF holds only the rasteriser's scratch (nothing kept between
   calls), code and lasting state start at &C300 and stop below &DC00, and
   the &DC40 block holds only state that disc commands may lose.
9. **The harness** reads the compared game state straight from main RAM (zero
   page, K%, WP, UP, NA%, the sound buffers): those stay where Master Elite
   has them.

## The map

| Region | Addresses | Purpose | Free |
|---|---|---|---:|
| Zero page, stack, K%, WP | &0000-&00E3, &0100-&01FF, &0400-&07FF, &0E41-&12A9 | Elite's workspaces, as Master Elite | - |
| Low code | main &0840-&0CF1 | flight code: the keyboard (DOKEY, DK4), TIDY and TIS3, the docking computer and its tactics helpers (DOCKIT, TAS1-TAS7, HITCH), MALW; the stubs for FRMIS, ANGRY and fq1 | 14 |
| Main code (BCODE) | main &1300-&3FB7 | Elite's main code and data in the original's order: the font and log tables first (page-aligned), then the IRQ and sound, CHPR, the main loop, stardust, the planet and sun, maths, UP, NA%, ..., ending with elite-flight.asm (MV40, MVS5, TIS2, LL9F) | 72 |
| Buffer 0, dashboard copy | main &4000-&71FF | the screen (rule 6) | - |
| High code | main &7200-&7F76 | the quarter-square tables QSL/QSH (page-aligned at &7200); the renderer's game-context side (G_ stubs, hooks, the lighting's L_SUN and L_REC); the far7 stubs into the cold area; flight code that does not fit in BCODE: SIGHT, DEATHT, OOPS, SFRMIS, ECMOF, THERE, msblob, MALC | 137 |
| Bank 4 | &8000-&9DE4 data, &9DE5-&BFE1 code | Elite's home bank: XX21, the 33 blueprints, E%, KWL%, KWH%, SNE, ACT; Master's drawing (still used by the docked screens: LOIN, HLOIN, PIXEL, PIX1, TTX66, CLYNS, ...); flight code (TACTICS, LL5, LL9 and LL51L, MVEIT, LOOK1, DEATH, pl4pat); the CMYK dashboard (elite-dash.asm: DIALS, SCAN, DOT, the bulbs, MSBAR) | 30 |
| Cold area: ANDY | ANDY &8000-&8FFA | cold code, docked and flight-rare: market, equipment, charts, system data, status, missions, pause, messages, number printing, TT66, ESCAPE, ANGRY | 5 |
| Cold area: bank 7 | bank 7 COLD7LO (&AA00)-&BDB3 | QQ18, the x4_/j4_ stubs out of the cold area, the cold code (text and tokens, title and start-up, save and load, hyperspace, launch and docking, the hangar, FRMIS, FRS1, FR1, Ze) | 588 |
| Rasteriser | bank 5 &8000-&BF53 | the rasteriser (gfx-raster.asm): its per-x tables, the 24 row-run pages (with its variables in the runs' spare bytes), polygons, discs, spans, lines, stars | 172 |
| Frame layer | bank 6 &8000-&AD7B code, &AD7C-&BEC3 data | the frame layer (gfx-frame.asm), the faces of the 33 ships (gfx-faces.asm), the lighting tables (gfx-light6.asm), frame_cold and the flare's bank 6 part (f_flt, fl_or and its tables); then its state: F_HW, F_HW2, F_DL, the text maps | 316 |
| Rasteriser cold code | bank 7 &8000-&A984 | the rasteriser's second bank (gfx-raster7.asm): the 24 row-run pages first (they must be whole pages), its tables (page-aligned by construction), then R_INIT, R_CLEARALL, R_RESETBUF, the dirty repair, lines | 123 (to COLD7LO) |
| HAZEL scratch | &C000-&C28A | the rasteriser's scratch (R_NDISCL, the polygon's vertices, ...): rule 8 | - |
| HAZEL code | &C300-&C728 | the renderer's glue, visible whatever is paged: shared variables (gfx-gvars), the T_ trampolines into bank 5, the text and IRQ hooks, the rasteriser's bank 5 <-> 7 stubs; game code: the rear and side views' stardust (STARS6, STARS2) and FLIP; GWARP | 10 |
| HAZEL state | &C733-&DB90 | raster_vars (at a fixed address: f_sight2 patches R_DIRTYR's high byte for rows in the next page), the dashboard's scalars (DASHV), F_DSX/F_DSY, the flare's variables | 111 (to &DC00) + 61 (the gap in raster_vars) |
| HAZEL state, disc-volatile | &DC40-&DEDE | R_NDN, R_WL, stars, R_WR, R_SS, F_DSS (rebuilt on re-entering flight) | 33 (to &DF00) |
| Shadow &3000-&3FFF | &3000-&307F, &3090-&30FF, &3100-&3EFF, &3F00-&3FFC | the flare (FLARE0), the zero-page save (setzp/getzp), the extended tokens (TOKENS), the flare (FLARE3) | 16, 3 |
| Buffer 1, dashboard | shadow &4000-&7DFF | the screen (rule 6) | - |
| Shadow &7E00-&7FF8 | | the flare (FLARE7; not displayed) | 7 |

The loader (`M128Elt`) loads each file to &1300 and copies it into place
(FTAB): BDATA (the dashboard image), FLARE7, FLARE3, FLARE0, TOKENS, BANK4,
ANDY, COLD7, BANK5, BANK6, RAST7, HAZEL (staged at &4000 and copied after the
last disc access), HICODE, LOWCODE (staged at &4800), then BCODE.

### Why each region holds what it holds

* **Main RAM** holds game code and data that run in game context. Below
  &3000 (the low code and BCODE up to UP) is what must be visible with X = 1
  or from interrupts and MOS vectors: the IRQ and sound, CHPR and the font,
  NEWBRK, the far-call code (elite-far.asm). BCODE keeps the original's order
  so that it reads against the original source; the routines that left it
  say where they went in a `Port:` note at their old place.
* **The high code** is main RAM above the screen: game-context only (X = 0).
  It holds what is called from game code and needs no X = 1 visibility: the
  renderer's game half and the quarter squares it and the maths share, the
  stubs into the cold area, and flight code for which BCODE has no room.
* **Bank 4** is paged whenever game code runs, so flight code can live there
  as well as in main RAM. Master's drawing stays there because the docked
  screens still use it, and the dashboard because it runs with X = 1.
* **The cold area** holds code that runs on docked screens or a few times in
  a flight: it costs a far call (about 100 cycles) to enter, so nothing that
  runs on most flight iterations is there.
* **Banks 5, 6 and bank 7 below COLD7LO** are the renderer's: the rasteriser,
  the frame layer and the rasteriser's cold code. They hold no game code.
* **HAZEL** is visible whatever bank is paged, so it holds the renderer's
  cross-bank glue and its lasting state, and a little game code that bank 4
  code calls directly.
* **Shadow RAM** outside the screen holds data read only with X = 1 (the
  extended tokens, through TKRD, RUPRD and RUGRD) and the lens flare's code,
  which runs with X = 1 from the frame layer.

## Calls between regions

Main RAM, HAZEL and bank 4 call each other directly. Everything else goes
through a stub; the stubs are of four kinds.

| Kind | Where | Count | Pages |
|---|---|---:|---|
| far7 / far7j stubs (`.TT22 JSR far7 : EQUW TT22_C`) | main: the high code (47) and the low code (3) | 50 | the cold area in, the caller's bank back |
| far4 / far4j stubs (`.x4_TT26 JSR far4 : EQUW TT26`) | the cold area (elite-coldstubs.asm), and TTX66M in main | 54 | bank 4 in, the cold area back |
| G_ stubs | main (gfx-gstubs.asm, 12) and HAZEL (G_CHAR, G_DELCHAR, G_CLRTEXT) | 15 | bank 6 in, bank 4 (or, from HAZEL, the caller's bank) back |
| T_ trampolines; r_call7 / r_call5 | HAZEL | 13; 2 | bank 5 in, bank 6 back; bank 7 <-> bank 5 |

far7, far4 and their jump forms are the only far-call helpers (elite-far.asm).
A far call costs about 100 cycles; per flight iteration of the gate's run the
far calls cost about 70 cycles in all, nearly all of it x4_TT26 (cold-area
text printing a character through main RAM, 0.6 times an iteration). The G_
and T_ stubs are the renderer's hot path by design (about 900 cycles an
iteration together).

tools/bankcheck.py checks the rules for every reference in the source:
branches never cross areas; cold code reaches main RAM and bank 4 only through
x4_/j4_ stubs and the others reach it only through far7 stubs; shadow data is
read only by readers marked `bankcheck: ok`; the renderer's banks (bank5,
bank6, bank7r, the flare's shadow code) are entered from elsewhere only
through the stub files or by address, call nothing in another bank, read no
other bank's data and read main RAM only below &3000. Deliberate exceptions
are marked `bankcheck: ok` on the line.

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

Page crossings are measured apart (profile.mjs --pagex), so that a layout
change's crossings do not count against an optimisation. Over the
rationalisation the gate's run went from 116253 to 115930 cycles per flight
iteration (17.20 to 17.25 it/s): 387 cycles less in instructions, 64 more in
page crossings (668 to 732), which the final alignment pass recovers.

## Alignment candidates for the final pass

The layout keeps alignment only where correctness needs it: the font and the
log tables (operands' low bytes are the argument), QSL/QSH (patched low
bytes), the row-run pages of banks 5 and 7, F_HW and F_HW2 sharing a low
byte, fl_or and fl_or1 sharing a page, r7_crep and r7_wmerge sharing a page,
raster_vars' fixed address (f_sight2), and the zero-page and table
assertions next to the code that depends on them. Alignment for speed alone
was taken out; this is what it is worth now, from profile.mjs --pagex (cycles
per flight iteration of the gate's run, 732 in all):

| Candidate | Cycles |
|---|---:|
| MVS5 within one page (was: start mvs5n on a page boundary when it would straddle one) | 12 |
| R_NDN, R_WL, R_WR rows within a page (was: ALIGN before R_WR in the &DC40 block) | 8 |
| F_HW, F_HW2 page-aligned, with f_disc's loops (fpr16 BCC fpr2 28, fsy_cp BNE fsyl 23, fpr_b2 8, fpr_b1 7, ...) | 79 |
| r_ypg, R_NDISCL, R_SX/R_SY/R_SS, F_DSX/F_DSY within a page | 0 now |
| the stardust multiplies' quarter squares (QSL/QSH +- b, patched): data-dependent, not alignable | 111 |
| MLSA's BMI mln (mla5) | 18 |
| the rasteriser's r_dl,X (r_pt409 14, r_pt88 6), R_NDP,X (r_pt154 11, r_pt90 9, r_pt98 6), r_sr,X (r_pt27 10, r_pt51 9), r_bdn,X (9), the BCC sl2 at r_pt416 (12) | 92 |
| DIL's BEQ dil9 | 11 |
| LL51L's LDY lfr2s table (bank 4) | 10 |
| STL1's SZ,Y (three loads, WP: the stardust's z) | 26 |
| MU8's BPL mu8b, DVID3B's BEQ DVL9a, mad1's BPL add1, SOUL8/SOUL3 (the sound IRQ) | 34 |
| the rest (440 places, each under 5) | about 330 |

## Free space

| Region | At 4737aab | Now |
|---|---:|---:|
| Low code | 14 | 14 |
| Main code (BCODE) | 6 | 72 |
| High code (and the old stubs region) | 22 + 28 (+ 224 alignment gap) | 137 |
| Bank 4 | 4 | 30 |
| ANDY | 5 | 5 |
| Bank 7 cold area | 7 | 588 |
| Bank 5 | 30 | 172 |
| Bank 6 | 13 (+ 5 in COLD6, 16 at sg_ax) | 316 |
| Bank 7 rasteriser | 3 | 123 |
| HAZEL code | 11 + 11 (block 2) | 10 |
| HAZEL state to &DC00 | 0 | 111 |
| raster_vars' gap | 8 | 61 |
| HAZEL &DC40 block | 19 | 33 |
| Shadow | 7, 3, 16 | 7, 3, 16 |
| Total | about 230 (+ 224 in the gap) | 1698 |
