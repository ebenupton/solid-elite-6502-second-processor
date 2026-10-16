\ ******************************************************************************
\
\ elite-gfx.asm - the filled renderer's memory: HAZEL, banks 5 and 6, bank 7
\ below the cold area (docs/MASTER-MAP.md)
\
\ INCLUDEd at the end of elite-source.asm (after the game's code, so that the
\ layer can use Elite's symbols). From the Demonstration Disc port (tag
\ demo-final, src/gfx-build.asm), with the HAZEL layout changed for disc
\ access (docs/MASTER-MEMORY.md): DFS overwrites &C000-&C2FF, &DC00 up to
\ the end of an OSCLI command and &DF00-&DFFF, and keeps its own state in
\ &C2C0-&C2FF and &DFDA-&DFDB. So &C000-&C2BF holds only the rasteriser's
\ scratch variables (no call reads what an earlier one left there), and the
\ code and the lasting state start at &C300 and stop below &DC00. Produces:
\
\   build/HAZEL.bin  HAZEL &C300 to the end of the code (and the variables
\                    with initial values), which the loader copies into place
\                    after its last disc access
\   build/BANK5.bin  sideways RAM bank 5: the rasteriser (gfx-raster.asm)
\   build/BANK6.bin  sideways RAM bank 6: the frame layer (gfx-frame.asm),
\                    the ship faces and colours (gfx-faces.asm) and its state
\   build/RAST7.bin  sideways RAM bank 7 &8000-&AC3F: the rasteriser's cold
\                    code (gfx-raster7.asm), under the cold area at &AC40
\
\ ******************************************************************************

SINGLEBUF = 1           \ 1: the renderer draws into shadow RAM (buffer 1) only,
                        \ which stays on show, so that Master's own drawing (EOR
                        \ lines, pixels, text into the same screen, erased by
                        \ drawing again) keeps working while the primitives
                        \ move to the renderer one at a time; 0: double
                        \ buffering (main RAM and shadow RAM, flipped at vsync)
ACCY = 8                \ ACCCON bit Y: HAZEL at &C000-&DFFF
MAXSH = 13              \ ships per frame
MAXLN = 48              \ lines per frame
MAXDT = 64              \ dots per frame
RASTBANK = 5
GFXBANK = 6
ELITEBANK = HOMEBANK
MCB = 24                \ bytes of a meridian circle's constants (f_merid, planet4.asm)

CLEAR &C000, &E000
ORG &C000

INCLUDE "src/gfx-raster_scr.asm"
.HZ_SCR_END
ASSERT HZ_SCR_END <= &C2C0      \ DFS's lasting state is at &C2C0-&C2FF

ORG &C300
.HZ_START
INCLUDE "src/gfx-gvars.asm"
INCLUDE "src/gfx-tramp.asm"
INCLUDE "src/gfx-hzhooks.asm"   \ (the other hooks are in main RAM, elite-hi.asm)
INCLUDE "src/gfx-raster_hz.asm" \ the rasteriser's cross-bank stubs (bank 5 <-> 7)
.HZ_CODE_END

\ raster_vars at a fixed place, whatever the size of the code above: the
\ rows of the laser sights' scan in R_DIRTYR0/1 must not cross a page
\ (gfx-frame.asm's f_sight2 asserts it), and the code is free to grow up
\ to here
RVOFF = &182            \ R_DIRTYR0's offset in raster_vars (asserted below)
RVBASE = &C8B5 - RVOFF
ASSERT P% <= RVBASE
SKIP RVBASE - P%
INCLUDE "src/gfx-raster_vars.asm"
ASSERT R_DIRTYR0 = RVBASE + RVOFF
.HZ_END
PRINT "HAZEL: scratch &C000-", ~HZ_SCR_END-1, ", code ", ~HZ_START, "-", ~HZ_CODE_END-1, " (", RVBASE-HZ_CODE_END, " free), data ", ~RVBASE, "-", ~HZ_END-1, " (", &DC00-HZ_END, " free to &DC00)"
ASSERT HZ_END <= &DC00          \ OSCLI copies its command line to &DC00

ORG &DC40                       \ (after the longest OSCLI command the game
                                \ issues, see SVE and friends)
.R_WL    SKIP 192       \ this frame's written extents (empty: R=0)
.R_WR    SKIP 192       \ (raster_vars.asm)
.R_NDN    SKIP 192       \ (raster_vars.asm: boundaries per disc row, 0..4)
\ (raster_vars.asm: the stars)
.R_SN       SKIP 1          \ star count 0..24
.R_SX       SKIP 24
.R_SY       SKIP 24
.R_SS       SKIP 24         \ star size 1..3
.R_SCOL     SKIP 1          \ star colour byte (R_INIT: &FF)
.HZ_END2
PRINT "HAZEL: data &DC40-", ~HZ_END2-1, " free to &DF00 ", &DF00-HZ_END2
ASSERT HZ_END2 <= &DF00         \ the MOS's filing system workspace
SAVE "build/HAZEL.bin", HZ_START, HZ_CODE_END, HZ_START

CLEAR &8000, &C000
ORG &8000
INCLUDE "src/gfx-raster.asm"
.B5_END
PRINT "Bank 5: rasteriser &8000-", ~B5_END-1, " free ", &C000-B5_END
ASSERT B5_END <= &C000
SAVE "build/BANK5.bin", &8000, B5_END, &8000

CLEAR &8000, &C000
ORG &8000
INCLUDE "src/gfx-frame.asm"
INCLUDE "src/gfx-faces.asm"
.F_TM   SKIP 768        \ text map: desired characters, 24 rows of 32
.F_SH0  SKIP 768        \ what buffer 0 shows
.F_SH1  SKIP 768        \ what buffer 1 shows
.F_TMR  SKIP 24         \ non-empty cells per row
.F_SHR0 SKIP 24
.F_SHR1 SKIP 24
ALIGN &100              \ (page-aligned so code size changes never add
.F_HW   SKIP 256        \ page-crossing cycles to the indexed loads): planet half-widths
.F_HW2  SKIP 256        \ sun half-widths
.F_DL   SKIP 1536       \ ship records: XX2 then XX3 copies
.F_DLEND
INCLUDE "src/gfx-frame_cold.asm"   \ (after the data, so that nothing else moves)
.B6_END
PRINT "Bank 6: frame layer &8000-", ~B6_END-1, " free ", &C000-B6_END
ASSERT B6_END <= &C000
SAVE "build/BANK6.bin", &8000, B6_END, &8000

CLEAR &8000, &C000
ORG &8000
INCLUDE "src/gfx-raster7.asm"   \ the rasteriser's second bank (cold code)
.R7_END
PRINT "Bank 7: rasteriser (cold) &8000-", ~R7_END-1, " free to the cold area ", &AC40-R7_END
ASSERT R7_END <= &AC40
SAVE "build/RAST7.bin", &8000, R7_END, &8000
