\ gfx-crater_b.asm - F_PCURVE and F_PPOINT: a crater's curves, recorded
\ (included by gfx-frame.asm; on the Tube parasite, see the IFs there)

.F_PCURVE
 PHX
 LDX F_NCV
 CPX #MAXCV
 BCS fpc9
 LDA F_NPT
 STA F_CVS,X
 STA F_CVE-1,X          \ ends the previous curve (X = 0: writes F_CVS+2, unused or overwritten later)
 LDA TGT
 STA F_CVT,X
 INC F_NCV
.fpc9
 PLX
 RTS

.F_PPOINT               \ (the current curve's F_CVE is set from F_NPT at fbd2)
IF _TPART = 1
 LDA F_NCV
 BEQ fpp9
 LDY F_NPT              \ (Y is not preserved: BLINE, the only caller, reloads
ELSE                    \ Y on every path
 LDA #0                 \ operand = F_NCV
F_NCV = P%-1
 BEQ fpp9
 LDY #0                 \ operand = F_NPT (Y is not preserved: BLINE, the
F_NPT = P%-1            \ only caller, reloads Y on every path
ENDIF
 CPY #MAXPT             \ before reading it; CLIP2 only saves/restores it)
 BCS fpp9
 LDA K6
 STA F_PXL,Y
 LDA K6+1
 STA F_PXH,Y
 LDA K5+2               \ (Master port: BLINE has the new point's y in K5(3 2))
 STA F_PYL,Y
 LDA K5+3
 STA F_PYH,Y
 INY
 STY F_NPT
.fpp9
 JMP gback              \ (G_PPOINT tail-jumps here: page Elite's bank back in
                        \ and return to BLINE)

