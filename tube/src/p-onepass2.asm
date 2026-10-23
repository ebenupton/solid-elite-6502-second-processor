\ ******************************************************************************
\
\ p-onepass2.asm - the one-pass polygons' second part (p-onepass.asm), in the
\ parasite's high area: the scan of a polygon's vertices (oo_scan) and the
\ 16-bit polygons' edges (oe16, o16cur, o16adv, o16s0, o16s1)
\
\ ******************************************************************************

\ oo_scan: the polygon's vertices in order (n >= 4), their y clamped into
\ 0..192 (OCY: as far as rows 0..191 go, an edge covers the same rows), with
\ OCY + n = OCY: fgen bit 7 unless y is unimodal (cyclically, one run up and
\ one down, flat edges aside), when both chains are monotone in the rows;
\ and each run's edge across the middle row: an edge going down (in y) is
\ chain A's (ow), one going up chain B's (ow+1, its lower vertex: chain B
\ walks backward)

.oo_scan
 LDX r_n
 DEX
 BIT op16
 BMI ocp1
.ocp0                   \ (8-bit: y as it is, at most 255: the same)
 LDA R_PYL,X
 STA OCY,X
 DEX
 BPL ocp0
 BMI ocp5
.ocp1
 LDA R_PYH,X
 BMI ocp2
 BNE ocp3
 LDA R_PYL,X
 CMP #193
 BCC ocp4
.ocp3
 LDA #192
 BNE ocp4
.ocp2
 LDA #0
.ocp4
 STA OCY,X
 DEX
 BPL ocp1
.ocp5
 LDX r_n
 LDA OCY
 STA OCY,X
 STZ olast
 STZ ofirst
 STZ ochg
 LDX #0
.osc1
 LDA OCY+1,X
 CMP OCY,X
 BEQ osc9               \ (flat)
 BCC osc4
 LDA oym                \ down: chain A's if y0 <= oym < y1
 CMP OCY,X
 BCC osc5
 CMP OCY+1,X
 BCS osc5
 STX ow
.osc5
 LDA #1
 BNE osc6
.osc4
 LDA oym                \ up: chain B's if y1 <= oym < y0
 CMP OCY+1,X
 BCC osc7
 CMP OCY,X
 BCS osc7
 TXA
 INC A
 CMP r_n
 BCC P%+4
 LDA #0
 STA ow+1
.osc7
 LDA #2
.osc6
 LDY olast              \ a change of direction (the first edge with one: kept)
 BNE osc8
 STA ofirst
 BEQ osc8a
.osc8
 CMP olast
 BEQ osc9
 INC ochg
.osc8a
 STA olast
.osc9
 INX
 CPX r_n
 BCC osc1
 LDA ofirst             \ (and from the last edge round to the first)
 CMP olast
 BEQ P%+5
 INC ochg
 LDA ochg
 CMP #3
 BCC osc0
 LDA #&80
 STA fgen
.osc0
 RTS

\ oe16: a 16-bit polygon's edge (phase A's r7_e16)

.oe16
 LDY r_i0
 LDX r_i1
 LDA R_PYL,Y            \ going down? (y0 < y1)
 CMP R_PYL,X
 LDA R_PYH,Y
 SBC R_PYH,X
 BVC P%+4
 EOR #&80
 BPL oen
 LDA R_PYH,X            \ end row = min(y1, yend)
 BMI oen
 BNE oe0
 LDA R_PYL,X
 CMP r_yend
 BCC oe1
.oe0
 LDA r_yend
.oe1
 STA RZ_T2
 LDA R_PYH,Y            \ start row = max(y0, ystart)
 BMI oe2
 BNE oen
 LDA R_PYL,Y
 CMP r_ystart
 BCS oe3
.oe2
 LDA r_ystart
.oe3
 STA RZ_T3
 CMP RZ_T2
 BCC oe4
.oen
 SEC
 RTS
.oe4
 STA RZ_Y
 STZ r7_side4
 JSR r7_esgen           \ S, t -> RZ_SA, RZ_TA; a, b, dy -> r7_ea, r7_eb, r7_edy
 LDY r_i0
 LDX r_i1
 LDA r7_edy+1           \ dy < 256 and both ends inside CL..CR+1: 8-bit
 BNE oeg
 LDA R_PXH,Y
 ORA R_PXH,X
 BNE oeg
 LDA R_PXL,Y
 CMP R_CL
 BCC oeg
 CMP r_cr1
 BEQ P%+4
 BCS oeg
 LDA R_PXL,X
 CMP R_CL
 BCC oeg
 CMP r_cr1
 BEQ P%+4
 BCS oeg
 LDA RZ_SA
 STA RZ_T0
 LDA r7_edy
 STA RZ_T1
 LDX r7_eb
 LDA r7_ea
 JSR fload
 JMP oe9
.oeg                    \ general: a 16-bit DDA, x clamped
 LDA #0                 \ (bit 7: the far end inside and dy < 256: once x is
 LDY r7_edy+1           \ inside, it stays)
 BNE oeg1
 LDY R_PXH,X
 BNE oeg1
 LDY R_PXL,X
 CPY R_CL
 BCC oeg1
 CPY r_cr1
 BEQ P%+4
 BCS oeg1
 LDA #&80
.oeg1
 PHA
 LDA #LO(O16)           \ (RZ_T6/7: the side's block)
 BIT fside
 BPL P%+4
 LDA #LO(O16+11)
 STA RZ_T6
 LDA #HI(O16)
 STA RZ_T7
 LDY #10
 PLA
 STA (RZ_T6),Y
 DEY
 LDA r7_edy+1
 STA (RZ_T6),Y
 DEY
 LDA r7_edy
 STA (RZ_T6),Y
.oeg4
 DEY                    \ x, error
 LDA RZ_SA-4,Y
 STA (RZ_T6),Y
 CPY #4
 BNE oeg4
.oeg5
 DEY                    \ a, b
 LDA r7_ea,Y
 STA (RZ_T6),Y
 TYA
 BNE oeg5
 LDA fside              \ the side's step: JMP o16s0 / o16s1
 ASL A
 ROL A
 ASL A
 TAY
 LDX #0
 TYA
 BEQ P%+4
 LDX #s1-s0
 LDA #&4C
 STA s0,X
 LDA o16tab,Y
 STA s0+1,X
 LDA o16tab+1,Y
 STA s0+2,X
 LDA RZ_T6              \ this row's x (X = the side's block)
 SEC
 SBC #LO(O16)
 TAX
 JSR o16cur
 LDX #f_x0
 BIT fside
 BPL P%+4
 LDX #f_x1
 STA 0,X
.oe9
 LDX ofch
 LDA RZ_T2
 STA fe,X
 CLC
 RTS

\ o16cur: side X's 16-bit x (o16sl/sh) for this row: A = it clamped into
\ CL..CR+1. Outside and moving away (or not moving): the constant from here
\ (the side's 8-bit DDA with a = b = 0); inside with o16t4: the 8-bit DDA
\ from here (as r7_e16's lp)

.o16cur
 LDA o16sh,X
 BMI o16lo
 BNE o16hi
 LDA o16sl,X
 CMP R_CL
 BCC o16lo
 CMP r_cr1
 BCC o16in
.o16hi
 LDA o16ah,X            \ right of the window, moving right: it stays there
 BPL o16kr
 LDA r_cr1
 RTS
.o16lo
 LDA o16ah,X            \ left of it, moving left: it stays there
 BMI o16kl
 LDA R_CL
 RTS
.o16in
 LDA o16t4,X
 BMI o16to8
 LDA o16sl,X
 RTS
.o16kr
 LDA r_cr1
 BRA o16k
.o16kl
 LDA R_CL
.o16k
 STA RZ_T0              \ the constant
 STZ RZ_TA
 LDA #1
 STA RZ_T1
 LDX #0
 LDA #0
 BRA o16l
.o16to8
 LDA o16sl,X
 STA RZ_T0
 LDA o16tl,X
 STA RZ_TA
 LDA o16dl,X
 STA RZ_T1
 LDA o16al,X
 PHA
 LDA o16bl,X
 TAX
 PLA
.o16l
 JSR fload
 LDA RZ_T0
 RTS

.o16tab
 EQUW o16s0, o16s1
.o16s0                  \ side 0's step while it is 16-bit
 STZ fside
 LDX #0
 JSR o16adv
 JSR o16cur
 STA f_x0
 JMP ost1
.o16s1                  \ side 1's
 LDA #&80
 STA fside
 LDX #11
 JSR o16adv
 JSR o16cur
 STA f_x1
 JMP ost2

