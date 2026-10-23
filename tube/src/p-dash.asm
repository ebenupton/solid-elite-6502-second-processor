\ ******************************************************************************
\
\ p-dash.asm - the parasite's dashboard (docs/TUBE-MAP.md): the panel is the
\ host's to draw (the Master port's CMYK dashboard routines, tagged "Tube:
\ hostb" in elite-source.asm, run in the host's sideways RAM). These are the
\ routines' parasite halves, under their names: each does the game's part of
\ the routine (the values it computes, and what it returns, as the Master
\ port's routine does, see each there) and sends the host what it draws from
\
\ ******************************************************************************

\ DIALS: the indicators' values to the host (C_PDIALS), which draws them as the
\ Master port's DIALS; then the compass (COMPAS, whose dot is DOT's below)

.DIALS
 LDA #C_PDIALS
 JSR ptx
 LDX #0
.pdi1
 LDA pdtl,X             \ the inputs' addresses
 STA pdi2+1
 LDA pdth,X
 STA pdi2+2
.pdi2
 LDA &FFFF              \ (patched)
 JSR ptx
 INX
 CPX #PDN
 BNE pdi1
 JMP COMPAS

.pdtl                   \ DIALS' inputs (h_pdials receives them in this order)
 EQUB LO(DELTA), LO(ALP1), LO(ALP2), LO(BETA), LO(BET1), LO(MCNT), LO(ENERGY)
 EQUB LO(FSH), LO(ASH), LO(QQ14), LO(CABTMP), LO(GNTMP), LO(ALTIT), LO(FLH)
PDN = P% - pdtl
.pdth
 EQUB HI(DELTA), HI(ALP1), HI(ALP2), HI(BETA), HI(BET1), HI(MCNT), HI(ENERGY)
 EQUB HI(FSH), HI(ASH), HI(QQ14), HI(CABTMP), HI(GNTMP), HI(ALTIT), HI(FLH)

\ DOT: the compass dot (COMX, COMY, COMC) to the host (C_PDOT), which EORs it
\ as the Master port's DOT; returns as DOT: X1 = COMX, COL = COMC, Y1 = COMY
\ (less one for a dot in front, COMC = YELLOW2), A = %00001001

.DOT
 LDA COMX
 STA X1
 LDA COMY
 STA Y1
 LDA COMC
 STA COL
 BEQ pdo1
 CMP #YELLOW2
 BNE pdo1
 DEC Y1
.pdo1
 LDA #C_PDOT
 JSR ptx
 LDA COMX
 JSR ptx
 LDA COMY
 JSR ptx
 LDA COMC
 JSR ptx
 LDA #%00001001
 RTS

\ SCAN: the ship on the scanner (as the Master port's SCAN, whose drawing,
\ from SCAND, is the host's: C_PSCAN, dX1, Y1, Y2, TYPE)

.pscr1
 RTS

.SCAN
 LDA INWK+31            \ not if it isn't shown on the scanner
 AND #%00010000
 BEQ pscr1
 LDX TYPE               \ or is the planet or sun
 BMI pscr1
 LDA scacol,X           \ COL = Master's scanner colour, as it leaves it
 STA COL
 LDA INWK+1             \ or is out of range
 ORA INWK+4
 ORA INWK+7
 AND #%11000000
 BNE pscr1
 LDA INWK+1             \ dX1 = 125 + x_hi, and X1 = that rounded to even
 CLC
 LDX INWK+2
 BPL psc2
 EOR #%11111111
 ADC #1
 CLC
.psc2
 ADC #125
 STA dX1
 AND #%11111110
 STA X1
 LDA INWK+7             \ Y2 = 220 - z_hi / 4
 LSR A
 LSR A
 CLC
 LDY INWK+8
 BPL psc3
 EOR #%11111111
 SEC
.psc3
 ADC #35
 EOR #%11111111
 STA Y2
 LDA INWK+4             \ Y1 = Y2 - y_hi / 2, clipped to 194..246
 LSR A
 CLC
 LDY INWK+5
 BMI psc4
 EOR #%11111111
 SEC
.psc4
 ADC Y2
 BPL psc5
 CMP #194
 BCS P%+4
 LDA #194
 CMP #247
 BCC P%+4
.psc5
 LDA #246
 STA Y1
 LDA #C_PSCAN
 JSR ptx
 LDA dX1
 JSR ptx
 LDA Y1
 JSR ptx
 LDA Y2
 JSR ptx
 LDA TYPE
 JSR ptx
 SEC                    \ the stick: dlen = Y1 - Y2, up if positive
 LDA Y1
 SBC Y2
 BEQ pscz
 BMI pscd
 LDA Y2                 \ up: Y = (Y2 - 1) AND 7, C set
 DEC A
 BRA pscx
.pscz                   \ none: Y = Y1 AND 7, C set
 LDA Y1
.pscx
 AND #7
 TAY
 LDX #0
 SEC
 LDA #%00001001
 RTS
.pscd                   \ down: Y = (Y2 + 1) AND 7, C clear
 LDA Y2
 INC A
 AND #7
 TAY
 LDX #0
 CLC
 LDA #%00001001
 RTS


\ LOIN, LOINQ: a line from (X1, Y1) to (X2, Y2) in COL, the host's to draw
\ (C_LOIN, with Master's LOINQ, into the direct-mode screen as LOIN and TTX66
\ draw it); LOIN returns as the Master port's: Y kept, A = %00001001

.LOIN
.LOINQ
 LDA #C_LOIN
 JSR ptx
 LDA X1
 JSR ptx
 LDA Y1
 JSR ptx
 LDA X2
 JSR ptx
 LDA Y2
 JSR ptx
 LDA COL
 JSR ptx
 LDA #%00001001
 RTS
