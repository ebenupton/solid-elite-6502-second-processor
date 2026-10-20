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
   dashboard, PIX1) and the frame layer run with X = 1 for part of their
   time, and so does HANGER's drawing of the hangar. What they reach in main
   RAM is below &3000: the font and the log tables, CHPR, ADDK (DIALS and
   PIX1), HANGFLAG (HANGER), UP (CATF, FLH, COMC) and the renderer's shared
   workspace. The build asserts that the main code is below &3000 up to the
   end of UP (HEAD_END%).
2. **Interrupts and MOS vectors.** The IRQ arrives with any bank paged and X
   either way; WRCHV (CHPR) and BRKV (NEWBRK) are entered with any ROM paged.
   Their handlers, and everything they touch, are in main RAM below &3000 or
   in HAZEL's &C300-&D8FF, and reach banked code only through far calls that
   page the bank and restore the caller's (NEWBRK pages bank 4 itself and
   carries on at NEWBRK2). The MOS reads the disc commands' strings and
   OSWORD block, so they are in main RAM.
3. **One sideways bank at a time.** Elite's home bank (bank 4) is paged
   whenever game code runs, so main RAM, HAZEL and bank 4 code call each other
   and read each other's data directly; the main code itself continues from
   main RAM into bank 4. Every other bank is reached through a stub that pages
   it in and the caller's bank back.
4. **ANDY** (ROMSEL bit 7) overlays &8000-&8FFF of the paged bank. The cold
   area is ANDY plus bank 7 from COLD7LO, paged together as ROMSEL &87; &F4
   always matches ROMSEL, bit 7 included.
5. **The game data is in HAZEL**, where every bank, the IRQ and code running
   with X = 1 see it; bank 4 holds code (and the dashboard's variables and the
   hangar's line heap). The blueprints keep the original's order from XX21 on,
   as NWSHP reads past E% (E%-1,Y for the planet and the sun) into the
   missile's blueprint.
6. **The screen.** Main &4000-&6FFF is buffer 0 and shadow &4000-&6FFF
   buffer 1; shadow &7000-&7DFF is the dashboard and main &7000-&71FF a copy
   of its first character row (for a late split). Nothing else lives there,
   except that a disc command borrows buffer 0 to stash HAZEL (rule 8).
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
   &4000-&5FFF), puts DFS's and the MOS's lasting bytes back from DFSST,
   makes the command, stashes those bytes again and copies HAZEL back (DOSNMI,
   also on the error path); the next entry to space mode starts buffer 0
   afresh (GSTASH, f_b0new). What runs during a command (the IRQ's H_VSYNC,
   the catalogue's text hooks) and what the game writes in HAZEL (XX21+2/3)
   is in &C300-&D8FF, which disc commands leave alone; read-only blueprint
   bytes fill the rest.
9. **The harness** reads the compared game state (zero page, K%, WP, UP,
   NA%, the sound buffers) by symbol, wherever the build puts it, and the
   game's tables (IKNS) and code (LL5's caller) through their banks. The one
   address the compared state holds of data the port moves, the space
   station's line heap pointer (LSO, in WP), is compared as the original's
   (mlib.canonFor).
10. **Each bank keeps its private tables and variables**; the state that
   more than one bank, the IRQ handler or code running with ACCCON X set
   reads is the renderer's shared workspace, in main RAM below the main code
   (one block, &0E40-&1EFF, ending where the main code starts), with DFSST;
   HAZEL holds the game data and
   the renderer's glue (its shared variables with initial values, the T_
   trampolines, the text and IRQ hooks).
11. **The main code reads as the original.** BCODE is one run in the
   original's source order, from &1F00 in main RAM on into bank 4, minus what
   is elsewhere for a reason: the cold routines (the cold area), Master's
   drawing, some flight code and the dashboard (elite-bank4.asm), and a few
   things moved within the run, each with a `Port:` note at its old place:
   the font and the log tables first (page aligned), the far-call code, the
   rasteriser's bank 5 <-> 7 stubs and NEWBRK's start below &3000 (rules 1
   and 2), and the disc commands' data after NA% (rule 2).

## The map

| Region | Addresses | Purpose | Free |
|---|---|---|---:|
| Zero page, stack, K% | &0000-&00E3, &0100-&01FF, &0400-&07FF | Elite's workspaces, as Master Elite | - |
| WP | main &0841-&0CA9 | Elite's workspace (the original's &0E41-&12A9, each byte at the same place in its page), in the MOS's buffers below page &0D; the commander file buffer commbuf (= LSX2) at &087E | 87 (&0840, &0CAA-&0CFF) |
| Free | main &0E00-&0E3F | | 64 |
| Shared workspace | main &0E40-&1EFF | the renderer's shared state, one block ending where the main code starts: R_NDN (&0E40), the rasteriser's per-call scratch (&0F00-&118F, R_NDISCL page aligned), DFSST and DFSIN (&1190-&1210), R_WL (&1240), R_SS and F_DSS (&1300), raster_vars at its fixed place (&1333: R_DIRTYR0 at &14B5 for f_sight2), R_SX, R_SY, R_SN, R_SCOL, the lens flare's variables, R_WR (&1E40) | 105 (47, 6, 52) |
| Main code (BCODE) | main &1F00-&3F52 | Elite's main code and data in the original's order, from the font and the log tables (page aligned) on: below &3000 (to &290D) the IRQ and sound, the far-call code, the raster stubs, NEWBRK's start, HANGFLAG, CHPR, ADDK, UP; then the main flight loop, MALW, MALC, stardust, the planet and sun, maths, NA% and the disc commands' data, DOCKIT and the tactics helpers, ... up to DVID4 | 173 (1778 below &3000) |
| Buffer 0, dashboard copy | main &4000-&71FF | the screen (rule 6); &4000-&5FFF also HAZEL's stash during a disc command | - |
| High code | main &7200-&7DCA | the quarter-square tables QSL/QSH (page-aligned at &7200); the renderer's game-context side (G_ stubs, hooks, the lighting's L_SUN and L_REC); the far7 stubs into the cold area | 565 |
| Bank 4 | &8000-&B7A5, &BF00-&BFFF | Elite's home bank, code only: the main code from DVL9a (DVID3B's rare paths) to F% (&8000-&9480: the maths after DVID4, LASLI, DOEXP, the planet, the main game loop, WARP, DOKEY, TIDY and TIS2, FILLKL, SIGHT, the sounds, ...); then elite-bank4.asm: Master's drawing (still used by the docked screens: LOIN, HLOIN, PIXEL, PIX1, TTX66, CLYNS, ...), flight code (TACTICS, LL5, LL9F and LL9, MVEIT, MV40, LOOK1, DEATH, pl4pat), the CMYK dashboard (elite-dash.asm: DIALS, SCAN, DOT, the bulbs, MSBAR, and their variables DASHV); the hangar's line heap HANGHEAP at &BF00 | 1882 |
| Cold area: ANDY | ANDY &8000-&8FED | cold code, docked and flight-rare: market, equipment, charts, system data, status, missions, pause, messages, number printing, TT66, ESCAPE, ANGRY | 18 |
| Cold area: bank 7 | bank 7 COLD7LO (&AB00)-&BEEC | QQ18, the x4_/j4_ stubs out of the cold area, the cold code (text and tokens, title and start-up, save and load and DOSCLI, hyperspace, launch and docking, the hangar, the market table QQ23, FRMIS, FRS1, FR1, Ze) | 275 |
| Rasteriser | bank 5 &8000-&BCD6 | the rasteriser (gfx-raster.asm): its per-x tables; the 24 row-run pages, whose 66-byte tails hold its variables, small routines and the high-byte tables R_SETBUF patches from; the boundary arrays (R_BD*, both buffers, &9C00-&A57F, with r_rowset, r_dw and r_bstore in the 128 bytes between the buffers); 8-bit polygons and every polygon's phase B, discs, spans, dots, stars | 809 (+ 350 in the tails) |
| Frame layer | bank 6 &8000-&ADCB code, &ADCC-&BF3D data | the frame layer (gfx-frame.asm), the faces of the 33 ships (gfx-faces.asm), the lighting tables (gfx-light6.asm), frame_cold (with f_b0new) and the flare's bank 6 part (f_flt, fl_or and its tables); then its state: F_HW, F_HW2, F_DL, the text maps, the directly drawn stars (F_DSX, F_DSY) | 194 |
| Rasteriser bank 7 | bank 7 &8000-&AAD4 | the rasteriser's second bank (gfx-raster7.asm): the 24 row-run pages first (they must be whole pages), their tails holding R_LINE's and the 16-bit polygons' variables and the small routines; its tables; R_LINE (all of it: T_LINE pages bank 7), the 16-bit polygons' phase A, the dirty repair, R_INIT | 43 (to COLD7LO; + 723 in the tails) |
| HAZEL | &C000-&C2AD | the game data: the Cougar's and the Dodo's blueprints, SNE, ACT (read only: DFS writes here during a command) | 82 (to &C300) |
| HAZEL glue | &C300-&C491 | the renderer's glue, visible whatever is paged: shared variables (gfx-gvars: GMODE, GFRONT, GFLIP, ..., GSTASH), the T_ trampolines into banks 5 and 7, the text and IRQ hooks (G_CHAR, G_DELCHAR, G_CLRTEXT, H_CHAR, H_DEL, H_VSYNC), GWARP | 55 (to XX21) |
| HAZEL | &C4C9-&DFFF | the game data: XX21 (written: &C300-&D8FF), E%, KWL%, KWH%, the missile's to the Constrictor's blueprints (from &D900 on in places DFS and the MOS overwrite during a command) | - |
| Shadow &3000-&3FFF | &3000-&307F, &3090-&30FF, &3100-&3EFF, &3F00-&3FFC | the flare (FLARE0), the zero-page save (setzp/getzp), the extended tokens (TOKENS), the flare (FLARE3) | 16, 3 |
| Buffer 1, dashboard | shadow &4000-&7DFF | the screen (rule 6) | - |
| Shadow &7E00-&7FF8 | | the flare (FLARE7; not displayed) | 7 |

The loader (`M128Elt`) loads each file to &1300 and copies it into place
(FTAB): BDATA (the dashboard image), FLARE7, FLARE3, FLARE0, TOKENS, BANK4,
ANDY, COLD7, BANK5, BANK6, RAST7, HAZEL (8K, staged at &4000), HICODE, BDATA
again (the first row in main RAM); then it loads BCODE to &1F00 (its address
from the build). The loader is at &0E00, in the shared workspace's place, so
its last part runs from K% (&0400; the game sets K% up itself): it takes
DFS's and the MOS's lasting bytes into DFSST after the last disc access,
copies HAZEL into place and calls G_INIT, which sets up the rest of the
workspace.

### Why each region holds what it holds

* **Main RAM below the main code** holds the renderer's shared workspace:
  variables that the rasteriser's two banks, the frame layer, the game's
  hooks, the IRQ handler and the lens flare (which runs with X = 1) share.
  Below &3000 every one of them sees it, whatever bank is paged and whatever
  ACCCON X is; the renderer initialises it (R_INIT, F_INIT), so it needs no
  image. It is one block from &0E40 to the main code; the page &0D below it
  is never written, and below that WP (Elite's own workspace) fills the
  MOS's buffers at &0840-&0CFF that the game never uses
  (docs/MASTER-MEMORY.md).
* **The main code** runs in game context. Below &3000 (to HEAD_END%) is what
  must be visible with X = 1 or from interrupts and MOS vectors (rules 1 and
  2). The rest may be anywhere main RAM or bank 4 holds it, so the run simply
  continues into bank 4 where main RAM ends (before buffer 0 at &4000), at a
  routine boundary where nothing falls through or branches across.
* **The high code** is main RAM above the screen: game-context only (X = 0).
  It holds what is not part of the main code but is called from it: the
  renderer's game half and the quarter squares it and the maths share, and
  the stubs into the cold area.
* **Bank 4** is paged whenever game code runs, so it holds the main code's
  continuation and the game code that elite-bank4.asm gathers: Master's
  drawing (still used by the docked screens, and run with X = 1), flight
  code, and the dashboard (run with X = 1, so its variables are in bank 4
  too, not main RAM above &3000).
* **The cold area** holds code that runs on docked screens or a few times in
  a flight: it costs a far call (about 100 cycles) to enter, so nothing that
  runs on most flight iterations is there.
* **Banks 5, 6 and bank 7 below COLD7LO** are the renderer's: the rasteriser,
  the frame layer and the rasteriser's second bank. They hold no game code.
  Bank 5 has everything a frame calls often, and the private state it reads
  in its inner loops (the boundary arrays); bank 7 the rest: what runs at
  most once or twice a frame, or for big and clipped shapes (R_LINE, the
  16-bit polygons' phase A, the dirty repair, start-up and resets). Each
  bank's 24 row-run pages leave 66 bytes after each run, which hold the
  bank's variables and its routines of under 66 bytes.
* **HAZEL** is visible whatever bank is paged, so it holds the game data
  (rule 5) and the renderer's glue (rule 10), laid out for disc commands
  (rule 8).
* **Shadow RAM** outside the screen holds data read only with X = 1 (the
  extended tokens, through TKRD, RUPRD and RUGRD) and the lens flare's code,
  which runs with X = 1 from the frame layer.

## Calls between regions

Main RAM, HAZEL and bank 4 call each other directly. Everything else goes
through a stub; the stubs are of four kinds.

| Kind | Where | Count | Pages |
|---|---|---:|---|
| far7 / far7j stubs (`.TT22 JSR far7 : EQUW TT22_C`) | main: the high code | 48 | the cold area in, the caller's bank back |
| far4 / far4j stubs (`.x4_TT26 JSR far4 : EQUW TT26`) | the cold area (elite-coldstubs.asm), and TTX66M in main | 49 | bank 4 in, the cold area back |
| G_ stubs | main (gfx-gstubs.asm, 12) and HAZEL (G_CHAR, G_DELCHAR, G_CLRTEXT) | 15 | bank 6 in, bank 4 (or, from HAZEL, the caller's bank) back |
| T_ trampolines; r_call7 / r_call5 | HAZEL; main below &3000 | 11; 2 | bank 5 (T_LINE: bank 7) in, bank 6 back; bank 7 <-> bank 5 |

far7, far4 and their jump forms are the only far-call helpers (elite-far.asm).
A far call costs about 100 cycles; in the gate's run the flight iterations
make about 0.5 far calls each (5280 in 10000 MLOOP iterations), nearly all of
them x4_TT26 from the cold area's token printing (the view's name on a change
of view, messages, the hyperspace countdown). The G_ and T_ stubs are the
renderer's hot path by design (about 900 cycles an iteration together).

tools/bankcheck.py checks the rules for every reference in the source:
branches never cross areas; cold code reaches main RAM and bank 4 only through
x4_/j4_ stubs (an address, #LO/#HI, is not a reach) and the others reach it
only through far7 stubs; the main files' labels assembled at &8000-&BFFF are
bank 4's; shadow data is read only by readers marked `bankcheck: ok`; the
renderer's banks (bank5, bank6, bank7r, the flare's shadow code) are entered
from elsewhere only through the stub files or by address, call nothing in
another bank, read no other bank's data and read main RAM only below &3000;
HAZEL and the shared workspace are visible to every area. Deliberate
exceptions are marked `bankcheck: ok` on the line.

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
bytes), the row-run pages of banks 5 and 7, F_HW and F_HW2 sharing a low
byte, fl_or and fl_or1 sharing a page, each pair of boundary arrays (R_BD*)
sharing a low byte, raster_vars' fixed place (f_sight2), R_NDISCL page
aligned (R_NDISCL,X), HANGHEAP page aligned, and the zero-page and table
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
| bank 7's dirty repair (r7_rowrep) and line loops (r7_lgo) | 62 |
| branches across a page in r_dp2 (its BRA at +107 13, +166 6) and R_STARERASE (+253 12, +193 7) | 45 |
| the frame layer's ft_sr1 10, fsg_m2 7 and fwc2 5 (new: bank 6's data moved by f_b0new's 80 bytes) | 31 |
| STL1's SZ,Y (WP: the stardust's z) and stl_dvr, stld (the stardust loop, at a new place) | 28 |
| bank 4: EE3K 11, LL51L's LDY lfr2s table 10 | 27 |
| phase B's reads of r_tb (R_PTB at &10CB: r_pbr1/r_pbr2) | 20 |
| r_bstore's stores to R_BDX1, R_BDX2, R_BDX3 (low bytes &C0, &80, &C0 in the boundary block) | 17 |
| MU8, DVID3B, DVL9a, mad1's BPL add1, SOUL8/SOUL3 (the sound IRQ) | 14 |
| the rest (about 400 places, each under 5) | about 174 |

## Free space

Bytes free in each region before the blueprints moved to HAZEL (d090015) and
now. The renderer's banks also have room in their run pages' tails, for
variables and routines of under 66 bytes each.

| Region | At d090015 | Now |
|---|---:|---:|
| Low code (then); WP's pages &0840-&0CFF (now: &0840, &0CAA-&0CFF) | 14 | 87 |
| Shared workspace &0E00-&1EFF | - | 169 (64 below it; 47, 6, 52 in it) |
| Main code (BCODE) | 72 | 173 (1778 below &3000) |
| High code | 137 | 565 |
| Bank 4 | 30 | 1882 |
| ANDY | 5 | 18 |
| Bank 7 cold area | 271 | 275 |
| Bank 5 | 809 (+ 350 in tails) | 809 (+ 350 in tails) |
| Bank 6 | 274 | 194 |
| Bank 7 rasteriser | 43 (+ 723 in tails) | 43 (+ 723 in tails) |
| HAZEL scratch (then), read-only game data zone (now) | 112 (to &C300) | 82 (&C2AE-&C2FF) |
| HAZEL code (then), glue (now) | 48 | 55 (to XX21) |
| HAZEL state | 1726 (to &D900) | - |
| HAZEL &DC40 block | 289 (to &E000) | - |
| Shadow | 7, 3, 16 | 7, 3, 16 |
| Total | 3856 (+ 1073 in tails) | 4378 (+ 1073 in tails) |

HAZEL's 2063 free bytes for lasting content went to the game data; bank 4's
room grew from 30 bytes to 1882 (with the hangar's line heap at &BF00 and
the dashboard's variables), and the high code's from 137 to 565.

WP's move below page &0D (MASTER-PLAN.md, "Low data") left the free bytes
as they were: the 151 now counted in the two rows above (&0E00-&0E40 and
&12AA-&12FF round WP, and WP's pages' ends) were free before too, but not
counted. The shared workspace is 4180 bytes with its alignment, more than
the 16 pages from &0E00 to the main code's first page less one, so the main
code, which starts with the page-aligned font, stays at &1F00; to start it
lower, the rasteriser's bank 5 <-> 7 stubs (71 bytes) could go before the
font, but then R_WR (or R_NDN or R_WL) would cross a page.
