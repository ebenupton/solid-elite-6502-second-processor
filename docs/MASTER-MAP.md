# The final memory map: BBC Master Elite plus the filled renderer

This is the target layout for the finished port (docs/MASTER-PLAN.md, Stage B
onwards): every piece of SNG47 Master Elite and of the demo port's renderer,
where it goes, and what is left over. Stage B implements the Elite half of it
(with Master's own drawing still in place, see "Stage B placement" below);
Stage C fills in the renderer half; Stage D closes the deficit.

Sources of the numbers:
* Master Elite: the SNG47 build (`master/build/symbols.txt`), split per routine
  by the source's `Name:` headers, and a profile of 20000 piloted iterations of
  the released game (instructions executed per routine in flight and docked,
  reads and writes per data byte; 19693 iterations in flight).
* Renderer: the demo port's build (`./build.sh`, `build/symbols.txt`), at tag
  `demo-final` plus the grind waves on this branch.
* Spare RAM: docs/MASTER-MEMORY.md.

Byte counts are measured unless marked "est.".

## Rules the map has to respect

1. ACCCON X = 1 maps shadow RAM at &3000-&7FFF and hides main RAM there. Code
   that runs, and data that is read, while X = 1 must not be in main
   &3000-&7FFF. In the final port the renderer draws into buffer B (shadow
   &4000-&6FFF) with X = 1; in Stage B Master's own drawing routines run with
   X = 1 (SCAN, LOIN/LOINQ, HLOIN, PIXEL, DOT, ECBLB, SPBLB, MSBAR, HANGER,
   CHPR, TTX66, CLYNS, DIALS, setzp, getzp and everything they call).
2. Interrupts arrive with X = 1 and with any sideways bank paged (bank 7 during
   a far call, the DFS ROM during disc I/O). So the IRQ handler and everything
   it touches (IRQ1, SOINT, SOUS1, the sound buffers and tables, the palette
   tables) must be in main RAM below &3000 (or in HAZEL).
3. MOS vectors are entered with any ROM paged: WRCHV (CHPR: the MOS prints
   through it during `*CAT` and error messages, with DFS paged), BRKV (NEWBRK),
   the NMI RTI. These handlers live in main RAM below &3000 and reach banked
   code only through far calls that page the bank and restore the caller's.
4. One sideways bank is visible at a time. Elite's home bank (bank 4) is paged
   whenever game code runs, so main RAM and bank 4 code call each other and read
   each other's data freely. Code elsewhere (the cold area) is reached only
   through far-call stubs, and calls out only through stubs (rule 6).
5. ANDY (ROMSEL bit 7) overlays &8000-&8FFF of the paged bank. The cold area is
   ANDY plus bank 7 above the rasteriser's cold code, paged together as ROMSEL
   &87; &F4 always matches ROMSEL, bit 7 included (MOS 3.20 restores ROMSEL from
   &F4 after paged-ROM calls with bit 7 intact: docs/MASTER-MEMORY.md).
6. Far calls (the demo's src/far7.asm model): a 5-byte stub `JSR far7 : EQUW
   target` keeps the routine's name where its callers are; from the cold area,
   `JSR far4 : EQUW target` stubs. A, X, Y and the flags pass both ways
   unchanged, the caller's bank (&F4 at the call) comes back. A far call costs
   about 100 cycles, so nothing on a per-iteration flight path goes through
   one. A routine that pulls its caller's return address, resets the stack or
   never returns is entered with the jump form (`far7j`/`far4j`) or not moved.
7. Master Elite writes into its data bank: NWSPS stores the station's blueprint
   address in XX21+2/3 on every station spawn. XX21 goes with the blueprints in
   bank 4, and NWSPS runs with bank 4 paged.
8. DIALS stores 1 to HAZEL &DDEB every iteration (no known reason). It is in the
   renderer's HAZEL state; DIALS is replaced in Stage C (the store goes with it).
   Until then nothing else uses HAZEL.
9. Main &4000-&6FFF is buffer A and shadow &4000-&6FFF is buffer B: nothing
   else may live there. Main &7000-&7DFF is the dashboard (the split shows main
   RAM below line 192) and shadow &7000-&7DFF its static copy.
10. The harness reads the compared state straight from main RAM (zero page, K%,
   WP, UP, NA%, the sound buffers): those stay in main RAM.

## What has to be placed

### The renderer (demo port, measured)

| Piece | Bytes | Needs |
|---|---|---|
| Rasteriser (src/raster.asm) | 16333 | a whole bank (bank 5), paged during the frame |
| Frame layer code (frame.asm, incl. its 768-byte font) | 8530 | bank 6, paged during the frame and by the record hooks |
| Frame layer state (text maps F_TM/F_SH0/F_SH1 and row counts 2376, half-width rows 512, ship records F_DL 1536, alignment 205) | 4629 | bank 6 |
| frame_cold.asm | 363 | bank 6 |
| Face and colour tables: demo, 13 types | 1177 | bank 6 |
| Face and colour tables: Master, 33 types (per face 3 + vertices bytes from the blueprints = 2027, pointer and per-type tables 238, fins and details est. 300) | est. 2565 | bank 6 (+1388 over the demo) |
| HAZEL code (gstubs, tramp, hooks, raster_hz) | 1270 | HAZEL &C000-; plus an image of it in bank 6 (the demo re-copies it at load) |
| HAZEL state (raster_vars, planet meridian blocks) | 6509 | HAZEL |
| Rasteriser cold code (raster7.asm) | 11325 | bank 7 &8000-&AC3C |
| Planet meridian constants (planet4.asm) | 2776 | bank 4 (called from the planet hook in game context) |
| Quarter-square tables SQ1L/SQ1H/SQ2L/SQ2H (used by planet4) | 2048 | bank 4 |
| Dashboard: routines in main RAM in the demo (BULB..SCAN, ddot, DIL, DIL2, DSEG) | est. 1200 | main or bank 4 (they write main &7000-&7DFF with X = 0) |
| Dashboard: DOT, MSBAR, generated tables, DWR, DSEGD, LCOL, HFCOL | est. 750 | bank 4 (DWR switches X) |

The renderer replaces these Master Elite pieces (counted below as "Elite
drawing"): the IRQ and palettes, the line, pixel, bulb, dashboard and scanner
routines, the screen clears, CHPR and its font, the laser sights.

### Master Elite (SNG47, measured)

BCODE is &1300-&7F47 (27720 bytes); BDATA's game data is &8000-&B1FF of bank 6
(12800 bytes, of which 648 unused). Split by role (the profile decides hot or
cold; routines the pilot never reaches were classified from the source):

| Group | Bytes | Contents |
|---|---|---|
| Flight, hot and warm (HOT) | 13590 | main loop (TT100 parts 1-16, MLOOP parts 1-6, TT102), MVEIT/MVT/MVS/MV40/PLUT, LL9 and its helpers (SHPPT, LL5..LL145, LSPUT), TACTICS, DOCKIT and missiles, all the maths (MULT*, DV*, ARCTAN, NORM, TIS*, log tables 768), stardust (STARS1/2/6, FLIP), planet and sun (PROJ, PL9, PLS*, CIRCLE*, BLINE, SUN, WPLS*, CHKON, EDGES), explosions (DOEXP), ship spawning and removal (NWSHP, NWSPS, Ze, KILLSHP, KS*), energy bomb, compass, keyboard (DOKEY, DK4, TT17, FILLKL, RDKEY, ZEKTRAN, DKS5), TT26, sound effects front ends (EXNO*), NEWBRK, NMI |
| Flight data (HOTDATA) | 527 | UP, NA%..NA2% (commander template and checksums), UNIV, DTW1-8, keyboard tables (KTRAN, TRTB%, IKNS), OSCLI strings and OSFILE blocks (CTLI, DELI, DIRI, savosc, lodosc, RLINE), small variables |
| IRQ and sound (LOWIRQ) | 535 | IRQ1, TVT1, TVT3, VSCAN, DOVDU19, VEC, WSCAN, DELAY, SOINT, SOUS1, NOISE, BEEP/BOOP, sound buffers and SFX tables |
| CHPR and its font (LOWCHPR) | 1000 | CHPR, TT67K, cls, ZES1, ZES2, FONT% (768) |
| Elite drawing, X = 1 (DRAW) | 3622 | ylookup, SCAN, LOIN, LOINQ, HLOIN, TWOS*, PIX*, PIXEL*, DOT, CPIXK, ECBLB*, SPBLB, MSBAR, HANGER (+HAS2, HAL3, HAS3, DVID4K), TTX66, CLYNS, DIALS, PZW*, DILX, DIL2, ADDK (a duplicate of ADD), shpcol, scacol, SIGHT |
| Cold code (COLD): docked-only and flight-rare | 7531 | text (TT27, ex, TT41..TT74, DETOK, MT*, cpl..plf, BPRNT, TT11), charts and system data (TT22, TT23, TT25, TT24, TT15/16, TT103..TT128, TT111, TT146..TT70, HME2), market and equipment (TT167, TT151.., TT219, gnum, TT208, TT210, TT213, LCASH, MCASH, EQSHP, dn, eq, prx, qv, refund), status, missions (BRIEF*, DEBRIEF*, PDESC, THERE), hyperspace and launch (hyp, Ghy, TT18, TT110, hyp1, GVL, MJP, LL164, LAUN, HFS2, SOS1, SOLAR, WARP), title, death, escape pod, start-up (S%, BEGIN, TT170, BR1, BAY, DFAULT, TITLE, COLD, SETINTS), save and load (SVE, LOD, CATS, DELT, MT26, GTNMEW, setzp, getzp), pause, messages (MESS, me1, OUCH), LOOK1, TT66/TTX66K, YESNO, TT217 |
| Cold data (COLDDATA) | 339 | QQ23 (market), PRXS (prices), JMTB, TKN2, QQ16, MTIN, HATB, TGINT |
| Unused Apple II tables (DEAD) | 576 | SCTBX1, SCTBX2, wtable |
| Ship blueprints, XX21, E%, KWL%, KWH% | 7573 | read in flight (LL9, MVEIT, TACTICS, spawning); XX21+2/3 written |
| SNE, ACT | 64 | sine and arctan tables, read in flight |
| QQ18 (recursive tokens) | 960 | read by TT27/ex (text), in flight too (messages) |
| TKN1, RUTOK (extended tokens) | 3612 | read by DETOK (docked: missions, title, system descriptions) |

The flight profile is very skewed: per flight iteration the hot group executes
about 47000 instructions; the cold group's flight entries (messages, view
changes, hyperspace, charts) run a few hundred times in 20000 iterations.

## The final map

| Region | Contents | Used | Free |
|---|---|---|---|
| &0000-&00E3 | Elite zero page (as Master); the renderer saves and restores its own | 228 | - |
| &0100-&01FF | XX3 heap and stack | - | - |
| &0400-&07FF | K% ship slots, ship line heap | - | - |
| &0840-&0CFF | far-call glue (far7/far4, est. 170), DFS HAZEL stash (66 bytes + est. 50 of code), flight code overflow | est. 1216 | 0 |
| &0E41-&12A9 | WP workspace (as Master) | - | - |
| main &1300-&2FFF | IRQ and sound (338 after IRQ1 and the palettes go), flight code and data | 7424 | 0 |
| main &3000-&3FFF | flight code (never runs with X = 1) | 4096 | 0 |
| main &4000-&6FFF | buffer A | 12288 | - |
| main &7000-&7DFF | dashboard | 3584 | - |
| main &7E00-&7FFF | flight code (never runs with X = 1) | 512 | 0 |
| shadow &3000-&3FFF | &3090-&30FF zero-page save (getzp/setzp); &3100-&3F1B TKN1 and RUTOK | 3724 | 372 (&3000-&308F, &3F1C-&3FFF) |
| shadow &4000-&6FFF | buffer B | 12288 | - |
| shadow &7000-&7DFF | static dashboard copy | 3584 | - |
| shadow &7E00-&7FFF | spare (cold data that only a few routines read) | 0 | 512 |
| ANDY &8000-&8FFF | cold code (docked-only first) | 4096 | 0 |
| bank 4 | blueprints and XX21 tables 7573, SNE/ACT 64, planet4 2776, SQ tables 2048, dashboard est. 1950, flight code overflow est. 1973 | 16384 | 0 |
| bank 5 | rasteriser | 16333 | 51 |
| bank 6 | frame layer code 8530, state 4629, frame_cold 363, faces est. 2565 (no HAZEL image: see below) | est. 16087 | est. 297 |
| bank 7 &8000-&AC3C | rasteriser cold code (under ANDY at &8000-&8FFF when the cold area is paged) | 11325 | - |
| bank 7 &AC40-&BFFF | QQ18 960, cold code and data 4099 | 5059 | 0 |
| HAZEL &C000-&DFFF | renderer code 1270, state 6509 | 7779 | 413 |

Elite's totals against the space:

| | Needed | Space | Balance |
|---|---|---|---|
| Flight (HOT 13590 + HOTDATA 527 + sound/WSCAN 338 + far glue est. 170 + hot-side stubs est. 300 + DFS stash est. 116 + Elite-side renderer hooks est. 300) | est. 15341 | main 11520 + &0840-&0CFF 1216 + &7E00-&7FFF 512 + bank 4 1973 = 15221 | est. -120 |
| Cold code and data (COLD 7531 + COLDDATA 339 + cold-side stubs est. 600) | est. 8470 | ANDY 4096 + bank 7 4099 = 8195 | est. -275 |
| Tokens (TKN1/RUTOK 3612, QQ18 960) | 4572 | shadow &3100-&3FFF 3840 + bank 7 960 | +228 |

So the map closes only with ANDY and shadow RAM used for cold code and data,
and bank 6 only without the HAZEL image (below). What is left is a deficit of
about 400 bytes (flight side about 120, cold side about 275), of the order of
the error in the estimates (stubs, hooks, the Master faces), so Stage D has to
provide a margin. COLDDATA could go to the spare shadow &7E00-&7FFF, but
shadow data needs an ACCCON X switch around every read (as the token reads
do), and the market and equipment tables have many readers.

### Closing the deficit (Stage D), in order

1. Drop the unused Apple II tables SCTBX1, SCTBX2, wtable: 576 bytes in main
   (done in Stage B; not counted above).
2. Drop the SQ quarter-square tables from bank 4: planet4's multiplies (a few
   per planet per frame) use Master's MULT/FMLTU or its log tables: +2048 in bank
   4. That closes both sides: the flight overflow goes there, and so can some
   flight-rare code from the cold area (hyperspace, launch, escape pod: any code
   may live in bank 4), leaving a margin of about 1.6K.
3. No HAZEL image in bank 6 (+1270 there, already assumed above): lay out HAZEL
   so its code avoids what DFS overwrites (&C000-&C2FF, &DC00 up to the command
   line's end, &DF00-&DF05, &DFC6) and the 66 bytes DFS needs kept (&C2C0-&C2FF,
   &DFDA-&DFDB); put only launch-reset renderer state at &C000-&C2BF. Then disc
   I/O needs the 66-byte stash but no rebuild, and the loader installs the code
   once. If that fails, the image (1270) goes to bank 7's cold area instead,
   and the cold side needs Stage D grinds of the same size.
4. Face tables: one colour-pair index byte per face instead of two colour bytes
   (-327 for the 327 faces) and shared vertex lists for the ships that share
   blueprints, if bank 6 is short.
5. Byte grinds (bytes objective, no cycle regression) on cold code, then on
   flight code that is warm rather than hot. ADDK (137) disappears with DIALS.
6. Last resort: a docked-only overlay loaded from disc on docking (as the
   original disc Elite does), e.g. the save/load and mission code (about 1.5K).

## Stage B placement (Master Elite alone)

Stage B moves every Elite group to its final region, with one difference: the
Elite drawing group (DRAW, 3622) still exists, and lives in bank 4 in the space
the renderer's bank 4 pieces will take (planet4, SQ tables, dashboard: est.
6774), as it must be outside main &3000-&7FFF (it runs with X = 1) and bank 4 is
always paged when it runs. LOWIRQ and LOWCHPR stay in main below &3000 (rules
2 and 3); CHPR reaches TTX66 in bank 4 through a far call (it can be entered
with DFS paged). The flight code that will move into main RAM once DRAW,
LOWCHPR and the IRQ go (est. 1.5K) sits in bank 4 meanwhile. Stage C then frees
the DRAW space group by group as the renderer's primitives replace them.

| Region | Stage B contents |
|---|---|
| main &1300-&3FFF | LOWIRQ, LOWCHPR, HOT and HOTDATA (as much as fits), far glue, hot-side stubs |
| main &4000-&7FFF | nothing (buffer A, dashboard) |
| shadow &3000-&3FFF | zero-page save, TKN1/RUTOK at &3100 |
| shadow &7000-&7EFF | Master's dashboard (loaded there as before) |
| bank 4 | blueprints, SNE, ACT, DRAW, the rest of HOT |
| bank 7 &AC40-&BFFF and ANDY | QQ18, COLD, COLDDATA, cold-side stubs |
| banks 5, 6, bank 7 &9000-&AC3F, HAZEL | empty (reserved for the renderer) |

The relocated build's measured layout and its speed against the reference
are recorded in docs/MASTER-PLAN.md (Stage B results).
