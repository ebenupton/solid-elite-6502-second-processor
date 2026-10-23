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
 INCLUDE "build/povl.asm"
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
.r_bs7                  \ (the repair is the parasite's: r_sbuf's patch of its
                        \ operand lands here)
 SKIP 3
.p_polyin               \ h_poly's receiving part: phase A's rows (p-polya.asm),
 HRX                    \ then the rasteriser from r_pcbd
 STA &06                \ (R_COLE, R_COLO)
 HRX
 STA &07
 HRX
 STA R_COL2
 HRX
 STA R_COL3
 LDA #0                 \ (C_SPANS: the parasite has clipped the rows)
 STA R_PXC
 HRX
 STA R_PYS
 TAY
 HRX
 STA R_PYL1
 CLC
 ADC #1
 STA R_PYE
 LDA &0B                \ (R_CR)
 CLC
 ADC #1
 STA R_PCR1
.ppo1
 HRX
 STA R_PTA,Y
 HRX
 STA R_PTB,Y
 CPY R_PYL1
 INY
 BCC ppo1
 JMP r_pcbd0
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
 BRK                    \ (P_ROWREP: the repair is the parasite's, gone)
 EQUW 0
 BRK                    \ (P_POLY: phase A is the parasite's, gone)
 EQUW 0
 JMP R_LINE
 JMP R_SETBUF
 JMP R_SPAN
 BRK                    \ (P_MARKDIRTY: the parasite's, gone)
 EQUW 0
 JMP R_DOT
 JMP R_STARERASE
 JMP R_STARPLOT
 BRK                    \ (P_FLARE: the parasite's, gone)
 EQUW 0
 JMP p_polyin
 JMP p_linein
 JMP r_stout
 JMP r_stin
 PRINT "Model B bank P: &8000-&", ~P_LOEND-1, " (free ", PDATA-P_LOEND, "), &9000-&", ~P_HIEND-1, " (free ", &C000-P_HIEND, ")"
 SAVE "build/HBP.bin", &8000, &C000, &8000
