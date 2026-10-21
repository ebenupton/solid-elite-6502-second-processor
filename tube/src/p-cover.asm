\ ******************************************************************************
\
\ p-cover.asm - phase 4 (docs/TUBE-PLAN.md, TUBE-MAP.md): the frame's
\ coverage, so that the host does not erase what this frame's ships will
\ paint over anyway
\
\ Before the disc layer, F_FRAME runs f_ships once in a coverage pass
\ (cv_on): T_POLY sends nothing but adds the polygon to CVL/CVR, per
\ character row (8 pixel rows) the byte columns (1..62) that it certainly
\ paints whole in all eight rows, and the other T_ calls do nothing. p_cover
\ sends them (C_COVER: first and last character row, then first and last
\ byte column per character row, first > last for none), and the host's
\ repair of the old dirty rows (R_DISCROWS' r7_rowrep) leaves those bytes
\ alone. The second, real run of f_ships draws the polygons as before.
\
\ A polygon's coverage is conservative. Its two chains are walked from the
\ top vertex and sampled at the first row of each character row, with a
\ 16.8 DDA (set up exactly at the row where each edge comes in, with a 16x16
\ multiply and a divide, then stepped 8 rows at a time: under 2 pixels of
\ error over 192 rows). The left boundary of a convex polygon is a convex
\ function of the row and the right one concave, so over rows 8c..8c+8 the
\ polygon holds max(left at 8c, at 8c+8) .. min(right at 8c, at 8c+8); each
\ keeps 2 pixels of margin inside both ends and only whole bytes. Character
\ rows count when rows 8c..8c+8 are in the polygon (strictly below its top
\ vertex and not below its bottom one) and 8c..8c+7 in the clip window. A
\ polygon with a coordinate outside -16384..16383, or whose chains cross (not
\ convex), adds nothing. Each character row keeps one interval: the union
\ with what it has if they touch, else the wider.
\
\ ******************************************************************************

CVL = R_NDX0            \ per character row: first and last byte column
CVR = R_NDX1            \ covered (CVL = &FF: none); R_NDX0-3 are scratch until
CVA = R_NDX2            \ f_bounds. The coverage pass: chain F's x per sample
CVB = R_NDX3            \ (0..255), and chain B's

\ (the zero page cv_ variables: p-io.asm, as they are used before here)

\ p_cover: the coverage pass, then C_COVER (after p_fb, before the discs)

.p_cover
 LDA F_NSHIP
 BEQ pcv9
 LDX #23
 LDA #&FF
.pcv1
 STA CVL,X
 STZ CVR,X
 DEX
 BPL pcv1
 STA cv_rt
 STZ cv_rb
 LDA #&80
 STA cv_on
 JSR f_ships
 STZ cv_on
 LDA cv_rb
 CMP cv_rt
 BCC pcv9               \ (none: rt = &FF)
 LDA #C_COVER
 PSEND
 LDA cv_rt
 PSEND
 LDA cv_rb
 PSEND
 LDX cv_rt
.pcv2
 LDA CVL,X
 PSEND
 LDA CVR,X
 PSEND
 CPX cv_rb
 INX
 BCC pcv2
.pcv9
 RTS

\ cv_poly: T_POLY in the coverage pass (keeps A, X, Y)

.cv_poly
 PHA
 PHX
 PHY
 TSX
 STX cv_sp
 LDA R_PN
 CMP #17
 BCC P%+4
 LDA #16
 STA cv_n
 CMP #3
 BCS P%+5
 JMP cvp9
 ASL A                  \ the guard: 2n + 2 edge advances
 ADC #2
 STA cv_g
 LDX cv_n               \ the top vertex (least y) and the y range, in
 DEX                    \ cv_d0/d1 (ymin) and cv_d2/d3 (ymax)
 STX cvJ
 LDA R_PYL,X
 STA cv_d0
 STA cv_d2
 LDA R_PYH,X
 STA cv_d1
 STA cv_d3
 BRA cvp1
.cvq
 JMP cvp9
.cvp1
 LDA R_PXH,X            \ every coordinate in -16384..16383
 CLC
 ADC #&40
 BMI cvq
 LDA R_PYH,X
 CLC
 ADC #&40
 BMI cvq
 LDA R_PYL,X            \ y < ymin?
 CMP cv_d0
 LDA R_PYH,X
 SBC cv_d1
 BVC P%+4
 EOR #&80
 BPL cvp2
 LDA R_PYL,X
 STA cv_d0
 LDA R_PYH,X
 STA cv_d1
 STX cvJ
.cvp2
 LDA cv_d2              \ ymax < y?
 CMP R_PYL,X
 LDA cv_d3
 SBC R_PYH,X
 BVC P%+4
 EOR #&80
 BPL cvp3
 LDA R_PYL,X
 STA cv_d2
 LDA R_PYH,X
 STA cv_d3
.cvp3
 DEX
 BPL cvp1
 LDA cv_d0              \ first character row: c0 = (max(ymin + 1, CT) + 7)
 CLC                    \ DIV 8
 ADC #1
 TAY
 LDA cv_d1
 ADC #0
 BMI cvp4
 BNE cvp8
 CPY R_CT
 BCS cvp5
.cvp4
 LDY R_CT
.cvp5
 TYA
 CLC
 ADC #7
 BCS cvp8
 LSR A
 LSR A
 LSR A
 STA cv_c0
 LDA cv_d3              \ last: c1 = min((ymax - 8) DIV 8, (CB - 7) DIV 8)
 BMI cvp8
 BNE cvp6
 LDA cv_d2
 SEC
 SBC #8
 BCC cvp8
 LSR A
 LSR A
 LSR A
 BRA cvp7
.cvp6
 LDA #31
.cvp7
 STA cv_c1
 LDA R_CB
 SEC
 SBC #7
 LSR A
 LSR A
 LSR A
 CMP cv_c1
 BCS P%+4
 STA cv_c1
 LDA cv_c1
 CMP cv_c0
 BCS cvpa
.cvp8
 JMP cvp9
.cvpa
 LDX cvJ                \ both chains start at the top vertex, their edge
 STX cvJ+1              \ "ending" there
 LDA cv_d0
 STA cvYEL
 STA cvYEL+1
 LDA cv_d1
 STA cvYEH
 STA cvYEH+1
 STZ cv_or

 \ pass A: each chain's x at rows 8c, c = c0 .. c1 + 1, into CVA (F) and
 \ CVB (B), indexed c - c0
 LDA cv_c0
 ASL A
 ASL A
 ASL A
 STA cv_y
 LDY #0
.cva1
 STY cv_t
 LDX #1
.cva2
 JSR cv_adv             \ (set up where an edge comes in, else 8 rows on)
 LDA cvX2,X             \ x, clamped into 0..255
 BMI cva3
 BNE cva4
 LDA cvX1,X
 BRA cva5
.cva3
 LDA #0
 BRA cva5
.cva4
 LDA #255
.cva5
 LDY cv_t
 CPX #0
 BNE cva9
 STA CVA,Y
 BRA cvaa
.cva9
 STA CVB,Y
.cvaa
 CLC                    \ x += 8 * slope
 LDA cvX0,X
 ADC cvS0,X
 STA cvX0,X
 LDA cvX1,X
 ADC cvS1,X
 STA cvX1,X
 LDA cvX2,X
 ADC cvS2,X
 STA cvX2,X
 DEX
 BPL cva2
 LDA CVB,Y              \ which is left? (by 3 pixels or more)
 SEC
 SBC CVA,Y
 BCC cva7
 CMP #3
 BCC cva8
 LDA #1
 TSB cv_or
 BRA cva8
.cva7
 CMP #&FE
 BCS cva8
 LDA #2
 TSB cv_or
.cva8
 LDA cv_y
 CLC
 ADC #8
 STA cv_y
 INY
 TYA
 CLC
 ADC cv_c0
 SEC
 SBC #1
 CMP cv_c1              \ samples c0 .. c1 + 1: on while Y + c0 - 1 <= c1
 BCC cva1
 BEQ cva1

 \ pass B: per character row, the inner whole bytes of both samples' extent
 \ (CVA left: if B is, the two exchange)
 LDA cv_or
 CMP #1
 BEQ cvb2
 CMP #2
 BEQ P%+5
 JMP cvp9               \ none, or both: not convex
 TYA                    \ (Y = the number of samples)
 TAX
.cvb1
 LDA CVA-1,X
 PHA
 LDA CVB-1,X
 STA CVA-1,X
 PLA
 STA CVB-1,X
 DEX
 BNE cvb1
.cvb2
 LDY #0
.cvb3
 LDA CVA+1,Y            \ L = max of the two samples' left
 CMP CVA,Y
 BCS P%+5
 LDA CVA,Y
 CLC                    \ a = (L + 2 + 3) DIV 4 (9 bits), at least 1
 ADC #5
 ROR A
 LSR A
 BNE P%+4
 LDA #1
 STA cv_t
 LDA CVB+1,Y            \ R = min of the two samples' right
 CMP CVB,Y
 BCC P%+5
 LDA CVB,Y
 SEC                    \ b = (R - 2) DIV 4 - 1 (R exclusive), at most 62
 SBC #6
 BCC cvb8
 LSR A
 LSR A
 CMP #63
 BCC P%+4
 LDA #62
 CMP cv_t
 BCC cvb8
 TAX                    \ X = b, cv_t = a: merge into character row c
 STY cv_t+1
 TYA
 CLC
 ADC cv_c0
 TAY
 LDA CVL,Y
 CMP #&FF
 BEQ cvb6               \ empty: take it
 LDA cv_t               \ touching (a <= CVR + 1 and b + 1 >= CVL)? union
 SEC
 SBC #1
 CMP CVR,Y
 BEQ P%+4
 BCS cvb5
 INX
 TXA
 DEX
 CMP CVL,Y
 BCC cvb5
 LDA cv_t
 CMP CVL,Y
 BCS P%+5
 STA CVL,Y
 TXA
 CMP CVR,Y
 BCC cvb7
 STA CVR,Y
 BRA cvb7
.cvb5
 TXA                    \ apart: keep the wider (b - a > CVR - CVL?)
 SEC
 SBC cv_t
 STA cv_k
 LDA CVR,Y
 SEC
 SBC CVL,Y
 CMP cv_k
 BCS cvb7
.cvb6
 LDA cv_t
 STA CVL,Y
 TXA
 STA CVR,Y
.cvb7
 CPY cv_rt              \ the character rows with coverage
 BCS P%+4
 STY cv_rt
 CPY cv_rb
 BCC P%+4
 STY cv_rb
 LDY cv_t+1
.cvb8
 TYA
 CLC
 ADC cv_c0
 CMP cv_c1
 INY
 BCS cvp9
 JMP cvb3
.cvp9
 PLY
 PLX
 PLA
 RTS

\ cv_adv: chain X at row cv_y: if the row is at or past its edge's end, on to
\ the edge holding it (set up there), else on 8 rows. Keeps X.

.cv_adv
 STZ cv_t+1
.cad1
 LDA cvYEH,X            \ row >= the edge's end row? next edge
 BMI cad2
 BNE cad5
 LDA cv_y
 CMP cvYEL,X
 BCC cad5
.cad2
 DEC cv_g
 BNE cad3
 LDX cv_sp              \ (malformed: give the polygon up)
 TXS
 JMP cvp9
.cad3
 LDA cvJ,X
 STA cvI,X
 CLC
 ADC cvD,X              \ (D = 1 or -1)
 CMP #&FF
 BNE cad4
 LDA cv_n
 DEC A
 BRA cad6
.cad4
 CMP cv_n
 BCC cad6
 LDA #0
.cad6
 STA cvJ,X
 TAY
 LDA R_PYL,Y
 STA cvYEL,X
 LDA R_PYH,Y
 STA cvYEH,X
 DEC cv_t+1
 BRA cad1
.cad5
 LDA cv_t+1
 BNE cv_setup
 RTS

\ cv_setup: chain X's edge cvI -> cvJ at row cv_y: its x (16.8) and 8 times
\ its slope. Keeps X.

.cv_setup
 PHX
 LDY cvJ,X
 LDA cvI,X
 TAX
 SEC                    \ dy
 LDA R_PYL,Y
 SBC R_PYL,X
 STA cv_v
 LDA R_PYH,Y
 SBC R_PYH,X
 STA cv_v+1
 SEC                    \ k = row - y0
 LDA cv_y
 SBC R_PYL,X
 STA cv_k
 LDA #0
 SBC R_PYH,X
 STA cv_k+1
 SEC                    \ dx (sign in cv_t+1)
 LDA R_PXL,Y
 SBC R_PXL,X
 STA cv_a
 LDA R_PXH,Y
 SBC R_PXH,X
 STA cv_a+1
 STA cv_t+1
 BPL cvs1
 LDA #0
 SEC
 SBC cv_a
 STA cv_a
 LDA #0
 SBC cv_a+1
 STA cv_a+1
.cvs1
 STZ cv_d0              \ slope = |dx| * 256 / dy (24 bits)
 LDA cv_a
 STA cv_d1
 LDA cv_a+1
 STA cv_d2
 STZ cv_r0
 STZ cv_r1
 LDY #24
 JSR cv_div
 LDY #3                 \ times 8
.cvs5
 ASL cv_d0
 ROL cv_d1
 ROL cv_d2
 DEY
 BNE cvs5
 PLX
 PHX
 LDA cv_t+1
 BPL cvs2
 SEC
 LDA #0
 SBC cv_d0
 STA cv_d0
 LDA #0
 SBC cv_d1
 STA cv_d1
 LDA #0
 SBC cv_d2
 STA cv_d2
.cvs2
 LDA cv_d0
 STA cvS0,X
 LDA cv_d1
 STA cvS1,X
 LDA cv_d2
 STA cvS2,X
 LDA #&80               \ x = x0 +- |dx| * k / dy, and a half
 STA cvX0,X
 STZ cv_d0
 STZ cv_d1
 LDA cv_k
 ORA cv_k+1
 BEQ cvs3
 JSR cv_mul             \ (the product's high word < dy: 16 steps of the
 LDA cv_d3              \ divide, from it as the remainder)
 STA cv_r1
 LDA cv_d2
 STA cv_r0
 LDA cv_d1
 STA cv_d2
 LDA cv_d0
 STA cv_d1
 STZ cv_d0
 LDY #16
 JSR cv_div
.cvs3
 PLX
 LDY cvI,X
 LDA cv_t+1
 BMI cvs4
 CLC
 LDA R_PXL,Y
 ADC cv_d0
 STA cvX1,X
 LDA R_PXH,Y
 ADC cv_d1
 STA cvX2,X
 RTS
.cvs4
 SEC
 LDA R_PXL,Y
 SBC cv_d0
 STA cvX1,X
 LDA R_PXH,Y
 SBC cv_d1
 STA cvX2,X
 RTS

\ cv_mul: cv_d0-3 = cv_a * cv_k (unsigned)

.cv_mul
 STZ cv_d2
 STZ cv_d3
 LDA cv_k
 STA cv_d0
 LDA cv_k+1
 STA cv_d1
 LDY #16
 LSR cv_d1
 ROR cv_d0
.cvm1
 BCC cvm2
 CLC
 LDA cv_d2
 ADC cv_a
 STA cv_d2
 LDA cv_d3
 ADC cv_a+1
 STA cv_d3
.cvm2
 ROR cv_d3
 ROR cv_d2
 ROR cv_d1
 ROR cv_d0
 DEY
 BNE cvm1
 RTS

\ cv_div: Y steps of dividing cv_r1/r0 (remainder so far) : cv_d2/d1/d0 by
\ cv_v: the quotient into cv_d2/d1/d0 from the bottom

.cv_div
.cvd1
 ASL cv_d0
 ROL cv_d1
 ROL cv_d2
 ROL cv_r0
 ROL cv_r1
 BCS cvd2
 LDA cv_r0
 CMP cv_v
 LDA cv_r1
 SBC cv_v+1
 BCC cvd3
.cvd2
 LDA cv_r0
 SBC cv_v
 STA cv_r0
 LDA cv_r1
 SBC cv_v+1
 STA cv_r1
 INC cv_d0
.cvd3
 DEY
 BNE cvd1
 RTS

\ the two chains (0: F, forward from the top vertex; 1: B, backward)
.cvJ   EQUB 0, 0        \ the edge's end vertex
.cvI   EQUB 0, 0        \ and start
.cvD   EQUB 1, &FF      \ the step through the vertices
.cvYEL EQUB 0, 0        \ the end vertex's y
.cvYEH EQUB 0, 0
.cvX0  EQUB 0, 0        \ x (16.8)
.cvX1  EQUB 0, 0
.cvX2  EQUB 0, 0
.cvS0  EQUB 0, 0        \ 8 times the slope (16.8)
.cvS1  EQUB 0, 0
.cvS2  EQUB 0, 0
