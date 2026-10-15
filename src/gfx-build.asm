\ ******************************************************************************
\
\ gfx-build.asm - the filled renderer's memory: HAZEL, bank 5, bank 6
\
\ INCLUDEd at the end of elite-source.asm (after the main code and bank 4 have
\ been SAVEd). Produces:
\
\   build/BANK5.bin  sideways RAM bank 5: the rasteriser (raster.asm)
\   build/BANK6.bin  sideways RAM bank 6: the frame layer (frame.asm), the ship
\                    faces and colours (faces.asm), and at &B800 an image of
\                    HAZEL's code, which the loader copies to &C000
\
\ HAZEL (&C000-&DFFF, ACCCON bit Y set permanently once loading is done) holds
\ the call stubs, trampolines and hooks, then the shared data.
\
\ ******************************************************************************

ACCY = 8                \ ACCCON bit Y: HAZEL at &C000-&DFFF
MAXSH = 13              \ ships per frame
MAXLN = 48              \ lines per frame
MAXDT = 64              \ dots per frame
RASTBANK = 5
GFXBANK = 6
ELITEBANK = 4
HZIMG = &B800           \ where bank 6 carries the HAZEL code image

CLEAR &C000, &E000
ORG &C000

.HZ_START
INCLUDE "src/gstubs.asm"
INCLUDE "src/tramp.asm"
INCLUDE "src/hooks.asm"
.HZ_CODE_END

INCLUDE "src/raster_vars.asm"
.HZ_END
PRINT "HAZEL: code ", ~HZ_START, "-", ~HZ_CODE_END-1, " data to ", ~HZ_END-1, " free ", &E000-HZ_END
ASSERT HZ_END <= &E000
ASSERT HZ_CODE_END - HZ_START <= &C000 - HZIMG

CLEAR &8000, &C000
ORG &8000
INCLUDE "src/raster.asm"
.B5_END
PRINT "Bank 5: rasteriser &8000-", ~B5_END-1, " free ", &C000-B5_END
ASSERT B5_END <= &C000
SAVE "build/BANK5.bin", &8000, B5_END, &8000

CLEAR &8000, &C000
ORG &8000
INCLUDE "src/frame.asm"
INCLUDE "src/faces.asm"
.F_TM   SKIP 768        \ text map: desired characters, 24 rows of 32
.F_SH0  SKIP 768        \ what buffer 0 shows
.F_SH1  SKIP 768        \ what buffer 1 shows
.F_TMR  SKIP 24         \ non-empty cells per row
.F_SHR0 SKIP 24
.F_SHR1 SKIP 24
.F_HW   SKIP 256        \ planet half-widths
.F_HW2  SKIP 256        \ sun half-widths
.F_DL   SKIP 1536       \ ship records: XX2 then XX3 copies
.F_DLEND
.B6_END
PRINT "Bank 6: frame layer &8000-", ~B6_END-1, " free to HAZEL image ", HZIMG-B6_END
ASSERT B6_END <= HZIMG
COPYBLOCK HZ_START, HZ_CODE_END, HZIMG
SAVE "build/BANK6.bin", &8000, HZIMG + HZ_CODE_END - HZ_START, &8000
