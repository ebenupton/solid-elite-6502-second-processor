\ ******************************************************************************
\
\ hb-d.asm - the Model B host's bank D (docs/TUBE-MAP.md): the rasteriser's
\ disc side, as the Master port's bank 5 seen with ROMSEL RASTBANK: the disc
\ window (gfx-raster_disc.asm) at &8000, the shared region (gfx-raster.asm)
\ from &9000, less the stars (bank P's), and the disc inputs from DDATA
\ (hb-ws.asm), which h_disc receives here. NMOS code (build/nmos/: the
\ Master port's sources through tube/tools/nmos.py).
\
\ ******************************************************************************

_TPART = 2
_HOSTB = TRUE
_RBANK = 1

 INCLUDE "tsrc/cmds.asm"
 INCLUDE "build/elite-source-ws.asm"
 INCLUDE "tsrc/hb-ws.asm"
r_jsr = RUNPJ           \ (bank D's r_spc runs bank P's runs through runp)
runp = RUNP
p_rowrep = P_ROWREPT

 CLEAR &8000, &C000
 GUARD DDATA
 ORG &9000
 INCLUDE "build/nmos/gfx-raster-d.asm"
 CPU 0
.D_HIEND
 ORG &8000
 GUARD &9000
 INCLUDE "build/nmos/gfx-raster_disc.asm"
 CPU 0
.D_LOEND
 ORG DDATA_END           \ h_disc's receiving part: the disc rows into DDATA
.d_disc
 HRX
 STA R_NDT
 HRX
 STA R_NDB
 HRX
 STA &0E                \ (R_DCE, R_DCO)
 HRX
 STA &0F
 HRX
 STA R_NDF
 BEQ ddi1
 HRX
 STA R_DBE
 HRX
 STA R_DBO
.ddi1
 LDY R_NDT
.ddi2
 CPY R_NDB
 BEQ P%+4
 BCS ddi9
 HRX
 STA R_NDISCL,Y
 HRX
 STA R_NDISCR,Y
 LDA R_NDF
 BEQ ddi4
 HRX
 STA R_NDP,Y
 HRX
 STA R_NDN,Y
 CMP #5
 BCC P%+4
 LDA #4
 TAX
 BEQ ddi4
 HRX
 STA R_NDX0,Y
 DEX
 BEQ ddi4
 HRX
 STA R_NDX1,Y
 DEX
 BEQ ddi4
 HRX
 STA R_NDX2,Y
 DEX
 BEQ ddi4
 HRX
 STA R_NDX3,Y
.ddi4
 INY
 BNE ddi2
.ddi9
 JMP R_DISCROWS
.D_CODE_END
 GUARD &C000
 ORG JT                 \ the jump table (hb-ws.asm)
 JMP R_DISCROWS
 JMP R_SETBUF
 JMP R_INIT
 JMP R_RESETBUF
 JMP r_wclear
 JMP d_disc
 PRINT "Model B bank D: &8000-&", ~D_LOEND-1, " (free ", &9000-D_LOEND, "), &9000-&", ~D_HIEND-1, " (free ", DDATA-D_HIEND, "), data &", ~DDATA, "-&", ~DDATA_END-1
 ASSERT D_CODE_END <= JT
 SAVE "build/HBD.bin", &8000, &C000, &8000
