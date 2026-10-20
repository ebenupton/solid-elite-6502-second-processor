\ ******************************************************************************
\
\ elite-gfx.asm - the filled renderer's memory: its shared workspace in main
\ RAM, its glue in HAZEL, banks 5 and 6 and ANDY
\ (docs/MASTER-MAP.md)
\
\ INCLUDEd at the end of elite-source.asm (after the game's code, so that the
\ layer can use Elite's symbols). From the Demonstration Disc port (tag
\ demo-final, src/gfx-build.asm), with the memory laid out for the full
\ game. The state that more than one bank, the IRQ handler or code running
\ with ACCCON X set reads is in main RAM below &3000 (the shared workspace,
\ below the main code), which every bank sees whatever ACCCON X is. HAZEL
\ holds the game data (the ship blueprints, elite-data.asm) and the glue
\ (the cross-bank stubs and hooks, the shared variables with initial
\ values), at &C300 on, which disc commands leave alone: the IRQ and text
\ hooks run during them (DOSCLI stashes the rest of HAZEL in screen buffer
\ 0 for the command, docs/MASTER-MEMORY.md). Produces:
\
\   build/HAZEL.bin  HAZEL &C000-&DFFF: the game data and the glue, which the
\                    loader copies into place after its last disc access
\   build/BANK5.bin  sideways RAM bank 5: the rasteriser's shared region and
\                    disc window (gfx-raster.asm, gfx-flare.asm,
\                    gfx-raster_lcold.asm; gfx-raster_disc.asm)
\   build/RASTA.bin  ANDY: the rasteriser's polygon window (gfx-raster_poly.asm,
\                    gfx-raster_line.asm)
\   build/BANK6.bin  sideways RAM bank 6: the frame layer (gfx-frame.asm),
\                    the ship faces and colours (gfx-faces.asm) and its state
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

\ HAZEL: the Cougar's and the Dodo's blueprints, SNE and ACT (elite-data.asm),
\ the glue at &C300 (the shared variables with initial values, the T_
\ trampolines, the text and IRQ hooks), then XX21 and the other blueprints to
\ the end of HAZEL (elite-data.asm, "Blueprints in HAZEL" in
\ docs/MASTER-PLAN.md)

CLEAR &C000, &E000
ORG &C000
.HZ_START
INCBIN "build/HZDATA1.bin"
ORG &C300
.HZ_GLUE
INCLUDE "src/gfx-gvars.asm"
INCLUDE "src/gfx-tramp.asm"
INCLUDE "src/gfx-hzhooks.asm"   \ (the other hooks are in main RAM, elite-hi.asm)
.GWARP   EQUB 0         \ bit 7: TT66 is an in-system jump's (WARP sets it,
                        \ F_DIRECT clears it)
.HZ_GLUE_END
PRINT "HAZEL: game data &C000-", ~HZDATA1END%-1, ", glue &C300-", ~HZ_GLUE_END-1, " (", XX21-HZ_GLUE_END, " free), game data ", ~XX21, "-&DFFF"
ASSERT HZ_GLUE_END <= XX21
ASSERT HZDATA1END% <= &C300
ORG XX21
INCBIN "build/HZDATA2.bin"
.HZ_END
ASSERT HZ_END = &E000
SAVE "build/HAZEL.bin", HZ_START, HZ_END, HZ_START

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
WS_TOP = &1F00 - 2 - 192   \ the rest ends at the main code (asserted below)
ASSERT P% <= WS_TOP
ORG WS_TOP
.R_SN       SKIP 1          \ star count 0..24
.R_SCOL     SKIP 1          \ star colour byte (R_INIT: &FF)
.R_WR       SKIP 192        \ (raster_vars.asm; whole in a page)
.WS_END
PRINT "Shared workspace: ", ~WS_START, "-", ~WS_END-1, " (free ", WS_START-&0E00, " below it, ", &1240-DFSIN-1, ", ", RVBASE-F_DSS-NDSTAR, " and ", WS_TOP-WS_GAP, " in it)"
ASSERT WS_START >= &0E00 AND WS_END = CODE%    \ (one block, ending where the main code starts)
ASSERT HI(R_WR) = HI(R_WR + 191)

CLEAR &8000, &C000      \ bank 5: the shared region from &9000 (the per-x tables,
ORG &9000               \ the row runs, the boundary arrays, the stars, the lens
INCLUDE "src/gfx-raster.asm"   \ flare ...), then the disc window at &8000
INCLUDE "src/gfx-flare.asm"    \ the lens flare (its step in bank 6: gfx-flare6.asm)
INCLUDE "src/gfx-raster_lcold.asm"   \ R_LINE's cold part
.B5_END
ASSERT B5_END <= &C000
ORG &8000
INCLUDE "src/gfx-raster_disc.asm"
.B5LO_END
ASSERT B5LO_END <= &9000
PRINT "Bank 5: rasteriser: disc window &8000-", ~B5LO_END-1, " (free ", &9000-B5LO_END, "), shared &9000-", ~B5_END-1, " free ", &C000-B5_END, " (+ ", r_tables-r_tfree, " at ", ~r_tfree, ")"
SAVE "build/BANK5.bin", &8000, B5_END, &8000

CLEAR &8000, &9000      \ ANDY (ROMSEL &85): the rasteriser's polygon window
ORG &8000
INCLUDE "src/gfx-raster_poly.asm"
INCLUDE "src/gfx-raster_line.asm"   \ R_LINE
.RA_END
ASSERT RA_END <= &9000
PRINT "ANDY: rasteriser polygon window &8000-", ~RA_END-1, " free ", &9000-RA_END
SAVE "build/RASTA.bin", &8000, RA_END, &8000

CLEAR &8000, &C000
ORG &8000
INCLUDE "src/gfx-frame.asm"
INCLUDE "src/gfx-faces.asm"
INCLUDE "src/gfx-light6.asm"   \ the lighting tables (and the first ramps)
INCLUDE "src/gfx-frame_cold.asm"
INCLUDE "src/gfx-flare6.asm"   \ the lens flare's step (the flare: gfx-flare.asm, bank 5)
.B6_CODE_END
.F_HW   SKIP 256        \ planet half-widths
.F_HW2  SKIP 256        \ sun half-widths
.F_DL   SKIP 1536       \ ship records: XX2 then XX3 copies
.F_DLEND
.F_TM   SKIP 768        \ text map: desired characters, 24 rows of 32
.F_SH0  SKIP 768        \ what buffer 0 shows
.F_SH1  SKIP 768        \ what buffer 1 shows
.F_TMR  SKIP 24         \ non-empty cells per row
.F_SHR0 SKIP 24
.F_SHR1 SKIP 24
.F_DSX  SKIP NDSTAR     \ the stars drawn directly (gfx-frame_cold.asm's F_DSTAR,
.F_DSY  SKIP NDSTAR     \ f_unstar): x and y (F_DSS, their sizes, in the
                        \ shared workspace after R_SS, cleared with it)
.B6_END
PRINT "Bank 6: frame layer &8000-", ~B6_CODE_END-1, ", data ", ~F_HW, "-", ~B6_END-1, " free ", &C000-B6_END
ASSERT B6_END <= &C000
SAVE "build/BANK6.bin", &8000, B6_END, &8000
