\ ******************************************************************************
\
\ hb-p.asm - the Model B host's bank P (docs/TUBE-MAP.md): the rasteriser's
\ polygon side, as the Master port's ROMSEL RASTPOLY (ANDY over bank 5): the
\ polygon window (gfx-raster_poly.asm, gfx-raster_line.asm) at &8000, the
\ shared region (gfx-raster.asm) from &9000 with the stars, then the flare
\ and the lines' cold part; the polygon inputs at PDATA (hb-ws.asm), where
\ bank D has the boundary arrays. NMOS code (build/nmos/).
\
\ ******************************************************************************

_TPART = 2
_HOSTB = TRUE
_RBANK = 2

 INCLUDE "tsrc/cmds.asm"
 INCLUDE "build/elite-source-ws.asm"
 INCLUDE "tsrc/hb-ws.asm"

 CLEAR &8000, &C000
 GUARD &C000
 ORG &9000
 INCLUDE "build/nmos/gfx-raster.asm"
 CPU 0
.P_SHEND
 INCLUDE "build/nmos/gfx-raster_line.asm"
 CPU 0
.P_HIEND
 ORG &8000
 GUARD PDATA
 INCLUDE "build/nmos/gfx-raster_poly.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-raster_lineb.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-raster_rep.asm"
 CPU 0
.p_polyin               \ h_poly's receiving part: n, the four colours, the
 HRX                    \ vertices, then R_POLY
 STA R_PN
 STA ppn
 HRX
 STA &06                \ (R_COLE, R_COLO)
 HRX
 STA &07
 HRX
 STA R_COL2
 HRX
 STA R_COL3
 LDX #0
.ppo1
 CPX ppn
 BCS ppo9
 HRX
 STA R_PXL,X
 HRX
 STA R_PXH,X
 HRX
 STA R_PYL,X
 HRX
 STA R_PYH,X
 INX
 BNE ppo1
.ppo9
 JMP R_POLY
.ppn EQUB 0
.p_linein               \ h_line's: the four colours, the end points, then R_LINE
 HRX
 STA &06
 HRX
 STA &07
 HRX
 STA R_COL2
 HRX
 STA R_COL3
 LDX #0
.pli1
 HRX
 STA R_X0,X
 INX
 CPX #8
 BNE pli1
 JMP R_LINE
.P_LOEND
 ORG JT
 GUARD &C000
 JMP r_pgfix
 JMP r7_rowrep
 JMP R_POLY
 JMP R_LINE
 JMP R_SETBUF
 JMP R_SPAN
 JMP R_MARKDIRTY
 JMP R_DOT
 JMP R_STARERASE
 JMP R_STARPLOT
 JMP R_FLARE
 JMP p_polyin
 JMP p_linein
 PRINT "Model B bank P: &8000-&", ~P_LOEND-1, " (free ", PDATA-P_LOEND, "), &9000-&", ~P_HIEND-1, " (free ", &C000-P_HIEND, ")"
 SAVE "build/HBP.bin", &8000, &C000, &8000
