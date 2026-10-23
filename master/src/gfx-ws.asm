\ ******************************************************************************
\
\ gfx-ws.asm - the renderer's constants and its shared workspace in main RAM
\ below the main code (docs/MASTER-MAP.md), split from elite-gfx.asm so that
\ the Tube build (tube/src) can place the same workspace at the same
\ addresses in both the parasite (the frame layer's inputs to the
\ rasteriser) and the host (the rasteriser's state)
\
\ ******************************************************************************

ACCY = 8                \ ACCCON bit Y: HAZEL at &C000-&DFFF
MAXSH = 13              \ ships per frame
MAXLN = 48              \ lines per frame
MAXDT = 64              \ dots per frame
RASTBANK = 5            \ the rasteriser: bank 5, its disc window (&8000-&8FFF) and
RASTPOLY = &85          \ the shared region (&9000-&BFFF); ANDY over bank 5, its
                        \ polygon window
GFXBANK = 6
MERIDBANK = 7           \ the meridian window (gfx-merid.asm): bank 7, after the
                        \ cold area
MERIDHOLD = 0           \ a beach ball's orientation is taken one frame in
                        \ MERIDHOLD + 1 (gfx-merid.asm, PM_HOOK): its spin (1/16
                        \ radian an iteration) shows in steps; its position and
                        \ size follow every frame (0: as the demo port)
ELITEBANK = HOMEBANK
ONEPASS = FALSE         \ the one-pass span generator (gfx-raster_onepass.asm): the
OPTUBE = FALSE          \ Tube's parasite only (tube/src/p-ws.asm), and the prototype's
                        \ test (master/tools/grind/test_onepass.py)

NDSTAR = NOST+1         \ stars 1..NOSTM (Master port: NOSTM <= NOST = 20)

\ The shared workspace: the state that the rasteriser's two banks, the frame
\ layer, the game's hooks and the IRQ handler share, in one block in main
\ RAM from &0E00 (above page &0D, off limits, docs/MASTER-MEMORY.md) to the
\ main code (CODE%), below &3000, where all of them see it. Variables only
\ (the renderer initialises them: R_INIT, F_INIT), except DFSST and DFSST2,
\ which the loader fills (from &0400, as the loader itself is here). Each
\ array's page crossings are as they were measured, or fewer: raster_vars
\ at a fixed place, moved only by whole pages (the rows of the laser sights'
\ scan in R_DIRTYR0/1 must not cross a page, gfx-frame.asm's f_sight2),
\ R_NDISCL page aligned (gfx-raster_scr.asm), the other row arrays from a
\ low byte of &40 or less or whole in a page (KF, R_WR), the star arrays
\ whole in a page. The polygon edge tables share the new disc spans' places
\ (R_PTA = R_NDISCR, R_PTB = R_NDISCL: gfx-raster_scr.asm)

ORG &0E00               \ (from here to WS_END: test_raster.py assembles it too)
.WS_START
.R_NDN      SKIP 192        \ (raster_vars.asm: boundaries per disc row, 0..4)
INCLUDE "src/gfx-raster_scr.asm"   \ the vertices (&0EC0), R_NDISCL (&0F00) ...
.R_SS       SKIP NDSTAR     \ star size 1..3 (raster_vars.asm: the stars)
.R_SX       SKIP NDSTAR
.DFSIN      SKIP 1          \ bit 7: a disc command is under way (DOSCLI, DOSNMI)
ASSERT HI(R_SS) = HI(R_SX + NDSTAR - 1)
ASSERT P% <= &1000
ORG &1000
.R_WL       SKIP 192        \ this frame's written extents (empty: R=0)
.DFSST  SKIP 64         \ DFS's and the MOS's lasting bytes in HAZEL, &C2C0-&C2FF
                        \ (here) and &DFC0-&DFFF (DFSST2: the MOS's FSCV copy
                        \ at &DFDA-&DFDB, the ACCCON its error path puts back at
                        \ &DFDC-&DFDD), while the game uses those places: put
                        \ back for each disc command (DOSCLI; the loader takes
                        \ them first)
.R_SY       SKIP NDSTAR
RVOFF = &182            \ R_DIRTYR0's offset in raster_vars (asserted below)
RVBASE = &12B5 - RVOFF  \ (&14B5 when it was measured: two pages lower)
ASSERT P% <= RVBASE
SKIP RVBASE - P%
INCLUDE "src/gfx-raster_vars.asm"
ASSERT R_DIRTYR0 = RVBASE + RVOFF
R_PTA = R_NDISCR        \ the polygon edge tables (gfx-raster_scr.asm)
R_PTB = R_NDISCL
ASSERT LO(R_PTA) <> LO(R_PTB) AND LO(R_PTA) + 191 < 256   \ (k_pre tells them apart)
.R_SN       SKIP 1          \ star count 0..NDSTAR
.R_SCOL     SKIP 1          \ star colour byte (R_INIT: &FF)
ALIGN &100
.KF         SKIP 192        \ the kept solid rows (gfx-raster_kept.asm), per row:
                            \ bit b set if the row is kept in buffer b, bit 7 if
                            \ it is pending this frame (R_INIT clears it)
.DFSST2 SKIP 64         \ (DFSST's second half: &DFC0-&DFFF)
.R_WR       SKIP 192        \ (raster_vars.asm; whole in a page)
.F_DSS      SKIP NDSTAR     \ the directly drawn stars' sizes (bank 6's: 0 = none,
                            \ cleared with R_SS by F_INIT and f_direct0)
ASSERT HI(F_DSS) = HI(F_DSS + NDSTAR - 1)
.WS_GAP                     \ (free to the main code)
SKIP CODE% - P%
.WS_END
PRINT "Shared workspace: ", ~WS_START, "-", ~WS_GAP-1, " (free ", &1000-DFSIN-1, ", ", RVBASE-R_SY-NDSTAR, ", ", KF-R_SCOL-1, " and ", CODE%-WS_GAP, " to the main code at ", ~CODE%, ")"
ASSERT WS_END = CODE%   \ (one block, ending where the main code starts)
ASSERT HI(KF) = HI(KF + 191)    \ (KF,Y: no page crossing)
ASSERT HI(R_WR) = HI(R_WR + 191)
