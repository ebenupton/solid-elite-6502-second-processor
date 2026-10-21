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
ELITEBANK = HOMEBANK

NDSTAR = NOST+1         \ stars 1..NOSTM (Master port: NOSTM <= NOST = 20)

\ The shared workspace: the state that the rasteriser's two banks, the frame
\ layer, the game's hooks and the IRQ handler share, in one block in main
\ RAM below the main code (CODE%) and below &3000, where all of them see it,
\ above page &0D (off limits, docs/MASTER-MEMORY.md). Variables only (the renderer initialises
\ them: R_INIT, F_INIT), except DFSST, which the loader fills (from &0400,
\ as the loader itself is here). The arrays keep their low bytes from HAZEL,
\ where their page crossings were measured: raster_vars at a fixed place
\ (the rows of the laser sights' scan in R_DIRTYR0/1 must not cross a page,
\ gfx-frame.asm's f_sight2), R_NDISCL page aligned (gfx-raster_scr.asm)

ORG &0E40               \ (from here to WS_END: test_raster.py assembles it too)
.WS_START
.R_NDN      SKIP 192        \ (raster_vars.asm: boundaries per disc row, 0..4)
INCLUDE "src/gfx-raster_scr.asm"
ASSERT LO(R_NDISCL) = 0
.DFSST  SKIP 128        \ DFS's and the MOS's lasting bytes in HAZEL, &C2C0-&C2FF
                        \ and &DFC0-&DFFF (the MOS's FSCV copy at &DFDA-&DFDB, the
                        \ ACCCON its error path puts back at &DFDC-&DFDD), while
                        \ the game uses those places: put back for each disc
                        \ command (DOSCLI; the loader takes them first)
.DFSIN  SKIP 1          \ bit 7: a disc command is under way (DOSCLI, DOSNMI)
ASSERT DFSIN = DFSST + 128      \ (the loader clears it)
ASSERT P% <= &1240
ORG &1240
.R_WL       SKIP 192        \ this frame's written extents (empty: R=0)
.R_SS       SKIP 24         \ star size 1..3 (raster_vars.asm: the stars)
.F_DSS      SKIP NDSTAR     \ the directly drawn stars' sizes (0 = none; see
                            \ F_DSX): cleared with R_SS (F_INIT, f_direct0)
ASSERT F_DSS = R_SS + 24
RVOFF = &182            \ R_DIRTYR0's offset in raster_vars (asserted below)
RVBASE = &14B5 - RVOFF
ASSERT P% <= RVBASE
SKIP RVBASE - P%
INCLUDE "src/gfx-raster_vars.asm"
ASSERT R_DIRTYR0 = RVBASE + RVOFF
.R_SX       SKIP 24         \ (raster_vars.asm: the stars)
.R_SY       SKIP 24
.WS_GAP                     \ (free to WS_TOP)
WS_TOP = CODE% - 2 - 192   \ the rest ends at the main code (asserted below)
ASSERT P% <= WS_TOP
ORG WS_TOP
.R_SN       SKIP 1          \ star count 0..24
.R_SCOL     SKIP 1          \ star colour byte (R_INIT: &FF)
.R_WR       SKIP 192        \ (raster_vars.asm; whole in a page)
.WS_END
PRINT "Shared workspace: ", ~WS_START, "-", ~WS_END-1, " (free ", WS_START-&0E00, " below it, ", &1240-DFSIN-1, ", ", RVBASE-F_DSS-NDSTAR, " and ", WS_TOP-WS_GAP, " in it)"
ASSERT WS_START >= &0E00 AND WS_END = CODE%    \ (one block, ending where the main code starts)
ASSERT HI(R_WR) = HI(R_WR + 191)
