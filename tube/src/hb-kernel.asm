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

\ r_rgen: the row runs, made at the host's start (hstart's s_gen): row r of
\ buffer b's at page &80 + 24b + r: 63 STA abs,Y (Y the pixel row), one per
\ byte column of the character row (column c's address, from the buffer's
\ base, &200r + 8c - 8r), an RTS, and the 'nothing planted' target (offset
\ 190); bytes 191-255 are not touched
.r_rgen
 LDA #0
 STA RZ_PP
 LDA #&80
 STA RZ_PP+1
 LDA #LO(BUF0 + 8)       \ (row 0, column 1)
 STA RZ_T0
 LDA #HI(BUF0 + 8)
 STA RZ_T1
 LDX #48                 \ (the runs to make)
.rg1
 LDA RZ_T0
 STA RZ_T2
 LDA RZ_T1
 STA RZ_T3
 LDY #0
.rg2
 LDA #r_opSTA
 STA (RZ_PP),Y
 INY
 LDA RZ_T2
 STA (RZ_PP),Y
 INY
 CLC
 ADC #8
 STA RZ_T2
 LDA RZ_T3
 STA (RZ_PP),Y
 INY
 ADC #0
 STA RZ_T3
 CPY #3 * 63
 BNE rg2
 LDA #r_opRTS
 STA (RZ_PP),Y
 INY
 LDA #0
 STA (RZ_PP),Y
 INC RZ_PP+1
 LDA RZ_T0               \ the next row: + &200 - 8
 CLC
 ADC #LO(&1F8)
 STA RZ_T0
 LDA RZ_T1
 ADC #HI(&1F8)
 STA RZ_T1
 DEX
 BEQ rg9
 CPX #24
 BNE rg1
 LDA #LO(&4000 + 8)      \ buffer 1's
 STA RZ_T0
 LDA #HI(&4000 + 8)
 STA RZ_T1
 BNE rg1
.rg9
 RTS
.*P_KEND
 PRINT "Model B bank P: the runs &8000-&AFFF, the span kernel &", ~P_KSTART, "-&", ~P_KEND-1, ", free to &C000: ", &C000-P_KEND

 ORG MR_A               \ (main RAM: the trampolines into bank P)
 GUARD MR_AEND
 INCLUDE "tsrc/hb-res2.asm"
.MR_A_END
 PRINT "Model B main RAM: &", ~MR_A, "-&", ~MR_A_END-1, " (free ", MR_AEND-MR_A_END, ")"
