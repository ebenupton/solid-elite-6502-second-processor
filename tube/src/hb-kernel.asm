\ ******************************************************************************
\
\ hb-kernel.asm - the Model B host's span kernel, in bank P after the row runs
\ (hb-layout.asm): the code that enters them, the rasteriser's blocks tagged
\ "Area: kernel" (streams.py's passes: r_rowset, r_sbruns, r_spc, the per-x
\ tables, R_SPAN, r_dspin, phase B) and phase B's set-up and entry, then the
\ run pages' tables; and the trampolines into it, in main RAM (hb-res2.asm).
\ Its names are its own: tube/build.sh assembles it in a scope (its INCLUDEs
\ flattened into build/nmos/hb-kernel.asm, as BeebAsm includes no file within
\ braces), because the per-x tables have the same names in bank F, where the
\ lines, r_pset and the stars read them; the trampolines' names are exported
\ (.*)
\
\ ******************************************************************************

.P_KSTART
 INCLUDE "build/nmos/gfx-raster-kernel.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-raster_lcold-kernel.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-raster_poly.asm"
 CPU 0
.p_polyin               \ C_SPANS (h_spans, through hb_poly): the colours and the
 HRX                    \ first row, then phase B, which reads the rows as it goes
 STA R_COLE             \ (r_pcbs)
 HRX
 STA R_COLO
 HRX
 STA R_COL2
 HRX
 STA R_COL3
 HRX
 STA R_PYS
 JMP r_pcbs
IF HI(P%) <> HI(P% + 191)  \ (each table whole in a page: r_rowset's and phase B's
 ALIGN &100                \ LDA ,Y)
ENDIF
.r_rpy0                 \ each buffer's run page per pixel row (r_sbruns points
FOR y, 0, 191           \ r_rowset's and phase B's operand at the buffer's)
 EQUB &80 + y DIV 8
NEXT
IF HI(P%) <> HI(P% + 191)
 ALIGN &100
ENDIF
.r_rpy1
FOR y, 0, 191
 EQUB &80 + 24 + y DIV 8
NEXT
.r_rpyl EQUB LO(r_rpy0), LO(r_rpy1)
.r_rpyh EQUB HI(r_rpy0), HI(r_rpy1)
.P_KEND
 PRINT "Model B bank P: the runs &8000-&AFFF, the span kernel &", ~P_KSTART, "-&", ~P_KEND-1, ", free to &C000: ", &C000-P_KEND

 ORG MR_A               \ (main RAM: the trampolines into bank P)
 GUARD MR_AEND
 INCLUDE "tsrc/hb-res2.asm"
.MR_A_END
 PRINT "Model B main RAM: &", ~MR_A, "-&", ~MR_A_END-1, " (free ", MR_AEND-MR_A_END, ")"
