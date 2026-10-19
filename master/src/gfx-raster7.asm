\ ============================================================================
\ raster7.asm -- the rasteriser's second sideways bank (R_BANK_AUX = 7): its
\ cold code (R_INIT, R_CLEARALL, R_RESETBUF, the dirty repair outside the
\ disc rows) and R_LINE.  INCLUDE it at &8000 in its own bank, after
\ raster_vars.asm, raster_hz.asm and raster.asm (it uses their symbols).
\ The caller calls R_LINE with bank 7 paged; raster.asm's other entry points
\ page the rest in through raster_hz.asm's stubs.
\ ============================================================================

\ R_LINE's zero page (r7_line's loops; here, before the code in the run
\ pages' tails that uses it)
l_x0 = &18
l_y0 = &19
l_x1 = &1A
l_y1 = &1B
l_e  = &1C
l_m  = &1D
l_n  = &1E
l_a  = &1F
l_b  = &20
l_x  = &21
l_k  = &22              \ kind (0..3)
l_c  = &23              \ 0: inside, 8: clipped

\ (The bank starts on a page boundary: the runs need whole pages.)
.r7_start
\ the row runs: one page per character row r: STA &4000+&200r+8k-8r,Y (Y = row) for byte
\ columns k = 1..63, then RTS
ALIGN &100
.r7_rrun
ASSERT (HI(r7_rrun) AND 31) = 0  \ (the row's run page is Y DIV 8 OR HI(r7_rrun))
MACRO R7_RUN r
  FOR k, 1, 63
    STA &4000 + r * &200 + k * 8 - r * 8, Y
  NEXT
  RTS                     \ (offset 189: nothing is planted after it, so the
ENDMACRO                  \ 66 bytes from offset 190 hold variables and code)
MACRO R7_ENDPAGE r
  ASSERT P% <= r7_rrun + (r + 1) * &100
  ALIGN &100
ENDMACRO

R7_RUN 0
.r7_lct SKIP 8          \ R_LINE: colour byte by row AND 7
.r7_ldl EQUB HI(R_DIRTYL0), HI(R_DIRTYL1)
.r7_ldr EQUB HI(R_DIRTYR0), HI(R_DIRTYR1)
.r7_lbuf EQUB &FF       \ buffer R_LINE's DIRTY operands are patched for
.r7_cr1 EQUB 0          \ CR + 1
.r7_cb1 EQUB 0          \ CB + 1
.r7_pm EQUB &88, &44, &22, &11  \ pixel x AND 3 of a byte
.r7_m0 EQUB 0           \ 32-bit dividend / product; quotient m0,m1
.r7_m1 EQUB 0
.r7_m2 EQUB 0           \ remainder m2,m3
.r7_m3 EQUB 0
.r7_v0 EQUB 0           \ divisor
.r7_v1 EQUB 0
.r7_ma EQUW 0           \ multiplicand
.r7_mb EQUW 0           \ multiplier
R7_ENDPAGE 0
R7_RUN 1
.r7_ov SKIP 28          \ R_LINE's variables (r7_lc16's, the long path's)
R7_ENDPAGE 1
R7_RUN 2
.r7_mul16
{
  LDA #0
  STA r7_m2
  STA r7_m3
  LDX #16
.lp
  LSR r7_mb+1
  ROR r7_mb
  BCC ns
  CLC
  LDA r7_m2
  ADC r7_ma
  STA r7_m2
  LDA r7_m3
  ADC r7_ma+1
  STA r7_m3
.ns
  ROR r7_m3
  ROR r7_m2
  ROR r7_m1
  ROR r7_m0
  DEX
  BNE lp
  RTS
}
R7_ENDPAGE 2
R7_RUN 3
.r7_div32
{
  LDX #16
.lp
  ASL r7_m0
  ROL r7_m1
  ROL r7_m2
  ROL r7_m3
  BCS sb
  LDA r7_m2
  CMP r7_v0
  LDA r7_m3
  SBC r7_v1
  BCC ns
.sb
  LDA r7_m2
  SBC r7_v0
  STA r7_m2
  LDA r7_m3
  SBC r7_v1
  STA r7_m3
  INC r7_m0
.ns
  DEX
  BNE lp
  RTS
}
R7_ENDPAGE 3
R7_RUN 4
.r7_pclip                 \ X = x, Y = y: r7_pset (and the row range) if inside
{                         \ the clip window
  CPX R_CL
  BCC out
  CPX R_CR
  BEQ ok1
  BCS out
.ok1
  CPY R_CT
  BCC out
  CPY R_CB
  BEQ ok2
  BCS out
.ok2
  TYA                     \ extend the buffer's row range by row Y
  LDY R_PRBUF
  CMP R_PRDYT,Y
  BCS n3
  STA R_PRDYT,Y
.n3
  CMP R_PRDYB,Y
  BCC n4
  STA R_PRDYB,Y
.n4
  TAY
  JMP r7_pset
.out
  RTS
}
R7_ENDPAGE 4
R7_RUN 5
.r7_pset                  \ X = x, Y = y (inside the window): the pixel in the
{                         \ colour pair's dither, DIRTY[y] extended (keeps X, Y)
  TYA
  LSR A
  LSR A
  AND #&FE
  ORA #&40
  STA RZ_PP+1
  TXA
  AND #&FC
  ASL A
  BCC h
  INC RZ_PP+1
.h
  STA RZ_PP
  TYA
  AND #7
  TSB RZ_PP
  TXA
  AND #3
  PHX
  TAX
  TYA
  LSR A
  LDA R_COLE
  BCC ev
  LDA R_COLO
.ev
  EOR (RZ_PP)
  AND r7_pm,X
  EOR (RZ_PP)
  STA (RZ_PP)
  PLA
.^r7_ps0 CMP R_DIRTYL0,Y
  BCS n1
.^r7_ps1 STA R_DIRTYL0,Y
.n1
.^r7_ps2 CMP R_DIRTYR0,Y
  BCC n2
.^r7_ps3 STA R_DIRTYR0,Y
.n2
  TAX
  RTS
}
R7_ENDPAGE 5
R7_RUN 6
.r7_n EQUB 0            \ R_POLY's phase A (16-bit): vertices, top vertex,
.r7_top EQUB 0          \ y range, chain count, edge, side
.r7_yminL EQUB 0
.r7_yminH EQUB 0
.r7_ymaxL EQUB 0
.r7_ymaxH EQUB 0
.r7_cc EQUB 0
.r7_i0 EQUB 0
.r7_i1 EQUB 0
.r7_side4 EQUB 0
.r7_e8c                   \ bank 5's r_e8, an edge starting above the window: Y = i0,
  LDX RZ_T7               \ RZ_T7 = i1, RZ_Y = ystart -> S in RZ_T0 (t in RZ_TA), dy
  STZ r7_side4            \ in RZ_T1, A = a, X = b
  JSR r7_esgen
  LDA RZ_SA
  STA RZ_T0
  LDA r7_edy
  STA RZ_T1
  LDX r7_eb
  LDA r7_ea
  RTS
R7_ENDPAGE 6
R7_RUN 7
\ b = 0: A = a  (falls into r7_lz)
.r7_pzl1
  STA r7_lz_a+1
  LDA RZ_T2
  STA r7_lz_e+1
  LDY RZ_T3
  LDA RZ_T0
  CLC
\ The DDA loops (Y = row, run to the patched end row)
.r7_lz                    \ b = 0: A = x
.r7_lz_t
  STA &FFFF,Y
  INY
.r7_lz_a
  ADC #0                  \ a (C = 0)
.r7_lz_e
  CPY #0
  BCC r7_lz
  RTS
R7_ENDPAGE 7
R7_RUN 8
\ shallow: X = b, A = a  (falls into r7_lsh)
.r7_psh1
  DEC A
  STA r7_lsh_a+1
  DEX
  STX r7_lsh_b+1
  LDA RZ_T1
  STA r7_lsh_d+1
  LDA RZ_T2
  STA r7_lsh_e+1
  LDY RZ_T3
  LDA RZ_T0
  CLC
.r7_lsh                   \ |dx| >= dy: A = x, RZ_TA = error
.r7_lsh_t
  STA &FFFF,Y
  INY
  TAX
  LDA RZ_TA
.r7_lsh_b
  SBC #0                  \ b - 1 (C = 0)
  BCS r7_lsh1
.r7_lsh_d
  ADC #0                  \ dy
  INX
.r7_lsh1
  STA RZ_TA
  TXA
.r7_lsh_a
  ADC #0                  \ a - 1 (C = 1)
.r7_lsh_e
  CPY #0
  BCC r7_lsh
  RTS
R7_ENDPAGE 8
R7_RUN 9
.r7_div8                  \ A / r7_v0 -> r7_m0 quotient, A remainder (clobbers X)
{
  STA RZ_T6
  LDA r7_v0
  STA RZ_T7
  LDA #0
  LDX #8
.lp
  ASL RZ_T6
  ROL A
  BCS sb
  CMP RZ_T7
  BCC ns
.sb
  SBC RZ_T7
  INC RZ_T6
.ns
  DEX
  BNE lp
  LDX RZ_T6
  STX r7_m0
  RTS
}
R7_ENDPAGE 9
R7_RUN 10
.r7_j3                    \ run offset of byte column k (1..63)
FOR k, 0, 63
  EQUB LO(3 * (k - 1))
NEXT
R7_ENDPAGE 10
R7_RUN 11
\ ============================================================================
\ R_RESETBUF (bank 7 part): the current buffer's state, not the screen
\ ============================================================================
.r7_resetbuf
{
  LDY #191
  LDX R_PRBUF
  BNE b1
.c0
  LDA #&FF
  STA R_DIRTYL0,Y
  STA R_DISCL0,Y
  LDA #0
  STA R_DIRTYR0,Y
  STA R_DISCR0,Y
  DEY
  CPY #&FF
  BNE c0
  BRA done
.b1
  LDA #&FF
  STA R_DIRTYL1,Y
  STA R_DISCL1,Y
  LDA #0
  STA R_DIRTYR1,Y
  STA R_DISCR1,Y
  DEY
  CPY #&FF
  BNE b1
.done
  JMP r7_reset1
}
R7_ENDPAGE 11
R7_RUN 12
\ r7_reset1: buffer X's scalars (keeps X)
.r7_reset1
  LDA #&FF
  STA R_PRDYT,X
  STA R_PRDST,X
  STZ R_PRDYB,X
  STZ R_PRDSB,X
  STZ R_PRSCNT,X
  STZ R_PRECNT,X
  STZ R_PRBMODE,X
  RTS


\ r7_lc16's variables
.c_m0 SKIP 2            \ major start
.c_n0 SKIP 2            \ minor start
.c_d  SKIP 1
.c_a  SKIP 1
.c_s  SKIP 1            \ bit 7: minor decreases
.c_k  SKIP 1            \ kind
.c_i  SKIP 2            \ first index
.c_t  SKIP 2
.c_lo SKIP 1            \ major window lo, hi, minor lo, hi
.c_hi SKIP 1
.c_nl SKIP 1
.c_nh SKIP 1
.c_m0w SKIP 2           \ mul / div: 16-bit value, 8-bit operand, remainder
.c_op SKIP 1
.c_r  SKIP 1
R7_ENDPAGE 12
R7_RUN 13
\ ============================================================================
\ R_CLEARALL (bank 7 part): black the clip window, reset the buffer's state
\ ============================================================================
.r7_clearall
{
  LDX #LO(r_clrrow)       \ each row by bank 5's span code
  STX r_hzt5
  LDX #HI(r_clrrow)
  STX r_hzt5+1
  LDY R_CT
.row
  STY RZ_T0
  JSR r_call5
  LDY RZ_T0
  CPY R_CB
  INY
  BCC row
  JSR r7_resetbuf
  LDY R_CT                \ WL/WR: the whole window was written
.cw
  LDA R_CL
  STA R_WL,Y
  LDA R_CR
  STA R_WR,Y
  CPY R_CB
  INY
  BCC cw
  LDA R_CT
  CMP R_PRWT
  BCS w1
  STA R_PRWT
.w1
  LDA R_CB
  CMP R_PRWB
  BCC w2
  STA R_PRWB
.w2
  RTS
}
R7_ENDPAGE 13
R7_RUN 14
\ ab: X = 0 / 2: |T(X), T(X+1)| -> A, C = 1 if >= 256
.r7_cab
{
  LDA RZ_T1,X
  BMI n
  BNE n9
  LDA RZ_T0,X
  CLC
  RTS
.n
  CMP #&FF
  BNE n9
  LDA RZ_T0,X
  BEQ n9                 \ (-256)
  EOR #&FF
  INC A
  CLC
  RTS
.n9
  SEC
  RTS
}
\ swap: r7_lc16's ends exchanged
.r7_cswap
{
  LDX #3
.l1
  LDA R_X0,X
  LDY R_X1,X
  STA R_X1,X
  TYA
  STA R_X0,X
  DEX
  BPL l1
  LDX #2                  \ the differences change sign
.l2
  SEC
  LDA #0
  SBC RZ_T0,X
  STA RZ_T0,X
  LDA #0
  SBC RZ_T1,X
  STA RZ_T1,X
  DEX
  DEX
  BPL l2
  RTS
}
R7_ENDPAGE 14
R7_RUN 15
\ mul: c_m0w = A * X
.r7_cmul
{
  STA c_op
  STX c_t+1
  STZ c_m0w
  STZ c_m0w+1
  LDX #8
.l1
  ASL c_m0w
  ROL c_m0w+1
  ASL c_op
  BCC l2
  LDA c_t+1
  CLC
  ADC c_m0w
  STA c_m0w
  BCC l2
  INC c_m0w+1
.l2
  DEX
  BNE l1
  RTS
}
R7_ENDPAGE 15
R7_RUN 16
\ div: c_m0w = c_m0w DIV A, c_r = MOD (A >= 1)
.r7_cdiv
{
  STA c_op
  STZ c_r
  LDX #16
.l1
  ASL c_m0w
  ROL c_m0w+1
  ROL c_r
  BCS l2
  LDA c_r
  CMP c_op
  BCC l3
.l2
  LDA c_r
  SBC c_op
  STA c_r
  INC c_m0w
.l3
  DEX
  BNE l1
  RTS
}
R7_ENDPAGE 16
R7_RUN 17
\ r7_lstart: A = steps: l_n = A, l_e = (A DIV 2) - l_b, l_x = x0, the buffer's
\ dirty rows += y0..y1 (in the window)
.r7_lstart
{
  STA l_n
  LSR A
  SEC
  SBC l_b
  STA l_e
  LDA l_x0
  STA l_x
  LDX R_PRBUF
  LDA l_y0
  LDY l_y1
  CMP l_y1
  BCC t0
  TAY
  LDA l_y1
.t0
  CMP R_CT                \ A = top, Y = bottom (clamped to the window)
  BCS t1
  LDA R_CT
.t1
  CMP R_PRDYT,X
  BCS t2
  STA R_PRDYT,X
.t2
  TYA
  CMP R_CB
  BCC t3
  LDA R_CB
.t3
  CMP R_PRDYB,X
  BCC t4
  STA R_PRDYB,X
.t4
  RTS
}
R7_ENDPAGE 17
R7_RUN 18
\ r7_lswap: R_LINE's 8-bit ends exchanged
.r7_lswap
  LDX l_x1
  LDY l_x0
  STX l_x0
  STY l_x1
  LDX l_y1
  LDY l_y0
  STX l_y0
  STY l_y1
  RTS
R7_ENDPAGE 18
R7_RUN 19
R7_ENDPAGE 19
R7_RUN 20
R7_ENDPAGE 20
R7_RUN 21
R7_ENDPAGE 21
R7_RUN 22
R7_ENDPAGE 22
R7_RUN 23
R7_ENDPAGE 23
.r7_lm                    \ pixels x..3 of a byte (x = 0..3)
FOR x, 0, 3
  EQUB ((&F0 >> x) AND &F0) OR (&0F >> x)
NEXT
.r7_jr                    \ run offset of byte column x DIV 4 + 1 (the RTS); read
                          \ as r7_jr-4,X (x >= 4): the offset of column x DIV 4
FOR x, 0, 255             \ (4 bytes into a page: neither read crosses one)
  EQUB LO(3 * (x DIV 4))
NEXT
ASSERT LO(r7_jr) = 4
.r7_rm                    \ pixels 0..x of a byte (x = 0..3)
FOR x, 0, 3
  EQUB ((&F0 << (3 - x)) AND &F0) OR ((&0F << (3 - x)) AND &0F)
NEXT



\ ============================================================================
\ R_POLY's phase A for polygons with some coordinate outside 0..255: chain A
\ into r_ta, chain B into r_tb, rows r_ystart..r_ylast (HAZEL scratch); bank
\ 5 calls r7_pf16 (through r_call7) and does phase B (r_pcbd)
\ ============================================================================
\ phase A's edge set-up (r7_ov, shared with R_LINE: never active together)
r7_edy = r7_ov + 0
r7_ek0 = r7_ov + 2
r7_ex0 = r7_ov + 4
r7_eadx = r7_ov + 6
r7_eneg = r7_ov + 8
r7_eq = r7_ov + 9
r7_er = r7_ov + 11
r7_ea = r7_ov + 13
r7_eb = r7_ov + 15

.r7_pf16                  \ R_POLY, some coordinate outside 0..255: phase A (bank
{                         \ 5's r_pcbd does phase B); A = 0: nothing to draw
  LDA R_PN
  CMP #17
  BCC n_ok
  LDA #16
.n_ok
  STA r7_n
  \ reject when every x is left of CL or every x is right of CR
  STZ RZ_T0
  LDX r7_n
  DEX
.xl
  LDA R_PXH,X
  BMI xlt
  BNE xgt
  LDA R_PXL,X
  CMP R_CL
  BCC xlt
  CMP R_CR
  BEQ xin
  BCC xin
.xgt
  LDA #2
  BRA xor
.xin
  LDA #3
  BRA xor
.xlt
  LDA #1
.xor
  ORA RZ_T0
  STA RZ_T0
  DEX
  BPL xl
  CMP #3
  BEQ xok
  LDA #0
  RTS
.xok
  LDA R_PYL
  STA r7_yminL
  STA r7_ymaxL
  LDA R_PYH
  STA r7_yminH
  STA r7_ymaxH
  STZ r7_top
  LDX #1
  CPX r7_n
  BEQ rows
.vl
  LDA R_PYL,X             \ y < ymin ?
  CMP r7_yminL
  LDA R_PYH,X
  SBC r7_yminH
  BVC v1
  EOR #&80
.v1
  BPL notless
  LDA R_PYL,X
  STA r7_yminL
  LDA R_PYH,X
  STA r7_yminH
  STX r7_top
  BRA notmore
.notless
  LDA r7_ymaxL             \ ymax < y ?
  CMP R_PYL,X
  LDA r7_ymaxH
  SBC R_PYH,X
  BVC v2
  EOR #&80
.v2
  BPL notmore
  LDA R_PYL,X
  STA r7_ymaxL
  LDA R_PYH,X
  STA r7_ymaxH
.notmore
  INX
  CPX r7_n
  BNE vl
.rows
  \ row range
  LDA r7_yminH
  BMI ys_ct
  BNE out0                \ ymin > 255
  LDA r7_yminL
  CMP R_CB
  BEQ ys_ok
  BCS out0                \ ymin > CB
.ys_ok
  CMP R_CT
  BCS ys_set
.ys_ct
  LDA R_CT
.ys_set
  STA r_ystart
  LDX r7_ymaxH
  BMI out0
  BNE yl_cb
  CMP r7_ymaxL
  BCS out0                \ ystart >= ymax : no rows
  LDA r7_ymaxL
  DEC A
  CMP R_CB
  BCC yl_set
.yl_cb
  LDA R_CB
.yl_set
  STA r_ylast
  INC A
  STA r_yend
  BRA go
.out0
  LDA #0
  RTS
.go                       \ (into r7_pf16b)
}


\ ----------------------------------------------------------------------------
\ r7_pf16b: R_POLY with some coordinate outside 0..255 (rows r_ystart..r_ylast
\ already found).  Phase A as r_pf8 (chain A forward into r_ta, chain B
\ backward into r_tb) with 16-bit edges whose x is clamped into CL..CR+1 per
\ row; then bank 5's phase B (r_pcbd).
\ ----------------------------------------------------------------------------
.r7_pf16b
{
  LDA R_CR
  INC A
  STA r_cr1
  LDA #LO(r_ta)
  STA r7_lsh_t+1
  STA r7_lz_t+1
  STA r7_x16_t+1
  STA r7_x16_f+1
  LDA #HI(r_ta)
  STA r7_lsh_t+2
  STA r7_lz_t+2
  STA r7_x16_t+2
  STA r7_x16_f+2
  LDA r7_n
  STA r7_cc
  LDX r7_top
.ca
  LDA R_PYL,X
  CMP r7_ymaxL
  BNE ca0
  LDA R_PYH,X
  CMP r7_ymaxH
  BEQ cad
.ca0
  DEC r7_cc
  BMI cad
  STX r7_i0
  INX
  CPX r7_n
  BCC ca1
  LDX #0
.ca1
  STX r7_i1
  JSR r7_e16
  LDX r7_i1
  BRA ca
.cad
  LDA #LO(r_tb)
  STA r7_lsh_t+1
  STA r7_lz_t+1
  STA r7_x16_t+1
  STA r7_x16_f+1
  LDA #HI(r_tb)
  STA r7_lsh_t+2
  STA r7_lz_t+2
  STA r7_x16_t+2
  STA r7_x16_f+2
  LDA r7_n
  STA r7_cc
  LDX r7_top
.cb
  LDA R_PYL,X
  CMP r7_ymaxL
  BNE cb0
  LDA R_PYH,X
  CMP r7_ymaxH
  BEQ cbd
.cb0
  DEC r7_cc
  BMI cbd
  STX r7_i0
  DEX
  BPL cb1
  LDX r7_n
  DEX
.cb1
  STX r7_i1
  JSR r7_e16
  LDX r7_i1
  BRA cb
.cbd
  STZ r_xclip
  LDA #1                  \ (bank 5: phase B)
  RTS
}

\ r7_e16: edge r7_i0 -> r7_i1 (16-bit) into the table (rows r_ystart..r_ylast)
.r7_e16
{
  LDY r7_i0
  LDX r7_i1
  LDA R_PYL,Y             \ going down? (y0 < y1)
  CMP R_PYL,X
  LDA R_PYH,Y
  SBC R_PYH,X
  BVC v1
  EOR #&80
.v1
  BPL out
  LDA R_PYH,X             \ end row = min(y1, yend)
  BMI out
  BNE e0
  LDA R_PYL,X
  CMP r_yend
  BCC e1
.e0
  LDA r_yend
.e1
  STA RZ_T2
  LDA R_PYH,Y             \ start row = max(y0, ystart)
  BMI s0
  BNE out
  LDA R_PYL,Y
  CMP r_ystart
  BCS s1
.s0
  LDA r_ystart
.s1
  STA RZ_T3
  CMP RZ_T2
  BCC go
.out
  RTS
.go
  STA RZ_Y
  STZ r7_side4
  JSR r7_esgen             \ S, t -> RZ_SA, RZ_TA; a, b, dy -> r7_ea, r7_eb, r7_edy
  LDY r7_i0                \ both ends' x inside CL..CR+1 and dy < 256:
  LDX r7_i1                \ the 8-bit DDA
  LDA r7_edy+1
  BNE gen
  LDA R_PXH,Y
  ORA R_PXH,X
  BNE gen
  LDA R_PXL,Y
  CMP R_CL
  BCC gen
  CMP r_cr1
  BEQ x1
  BCS gen
.x1
  LDA R_PXL,X
  CMP R_CL
  BCC gen
  CMP r_cr1
  BEQ x2
  BCS gen
.x2
  LDA RZ_SA
  STA RZ_T0
  LDA r7_edy
  STA RZ_T1
  LDX r7_eb
  LDA r7_ea
  CPX #0
  BNE sh
  JMP r7_pzl1
.sh
  JMP r7_psh1
.gen                      \ general: 16-bit S, t; x clamped into CL..CR+1
  LDA r7_eb
  STA bl+1
  LDA r7_eb+1
  STA bh+1
  LDA r7_edy
  STA dl+1
  LDA r7_edy+1
  STA dh+1
  LDA r7_ea
  STA al+1
  LDA r7_ea+1
  STA ah+1
  LDA RZ_T2
  STA ye+1
  STZ RZ_T4               \ bit 7: the far end is inside CL..CR+1 and dy < 256,
  LDX r7_i1                \ so once inside, x stays inside: the 8-bit DDA
  LDA r7_edy+1
  BNE g1
  LDA R_PXH,X
  BNE g1
  LDA R_PXL,X
  CMP R_CL
  BCC g1
  CMP r_cr1
  BEQ g0
  BCS g1
.g0
  DEC RZ_T4
.g1
  LDY RZ_T3
.lp
  LDA RZ_SA+1
  BMI lo
  BNE hi
  LDA RZ_SA
  CMP R_CL
  BCC lo
  CMP r_cr1
  BCC inw
.hi
  BIT r7_ea+1              \ right of the window, moving right: stays there
  BPL fh
  LDA r_cr1
  BRA st
.lo
  BIT r7_ea+1              \ left of it, moving left: stays there
  BMI fl
  LDA R_CL
.st
.^r7_x16_t
  STA &FFFF,Y
  INY
.ye
  CPY #0
  BCS done
  LDA RZ_TA               \ t -= b; borrow: t += dy, S += 1
  SEC
.bl
  SBC #0
  STA RZ_TA
  LDA RZ_TA+1
.bh
  SBC #0
  STA RZ_TA+1
  BCS nb
  LDA RZ_TA
.dl
  ADC #0
  STA RZ_TA
  LDA RZ_TA+1
.dh
  ADC #0
  STA RZ_TA+1
  BRA ad
.nb
  CLC
.ad
  LDA RZ_SA               \ S += a
.al
  ADC #0
  STA RZ_SA
  LDA RZ_SA+1
.ah
  ADC #0
  STA RZ_SA+1
  BRA lp
.done
  RTS
.fh
  LDA r_cr1
  BRA fi
.fl
  LDA R_CL
.fi
.^r7_x16_f
  STA &FFFF,Y
  INY
  CPY ye+1
  BCC fi
  RTS
.inw
  BIT RZ_T4
  BMI sw
  JMP st
.sw                       \ inside for good: the 8-bit DDA from row Y
  STA RZ_T0
  STY RZ_T3
  LDA r7_edy
  STA RZ_T1
  LDX r7_eb
  LDA r7_ea
  CPX #0
  BNE sw1
  JMP r7_pzl1
.sw1
  JMP r7_psh1
}

\ ----------------------------------------------------------------------------
\ r7_esgen: set up edge r7_i0 -> r7_i1 (y1 > row >= y0) for side r7_side4 at row
\ RZ_Y: x = x0 + ceil(dx*k/dy) with k = row - y0, kept as S and error t with
\ dx*k = dy*(S-x0) - t, 0 <= t < dy; per row S += a, t -= b (a = floor(dx/dy),
\ b = dx - a*dy), borrow: t += dy, S += 1.  Installs a, b, dy into the row loop.
\ ----------------------------------------------------------------------------
.r7_esgen                  \ Y = r7_i0, X = r7_i1
{
  SEC
  LDA R_PYL,X
  SBC R_PYL,Y
  STA r7_edy
  LDA R_PYH,X
  SBC R_PYH,Y
  STA r7_edy+1
  SEC
  LDA RZ_Y
  SBC R_PYL,Y
  STA r7_ek0
  LDA #0
  SBC R_PYH,Y
  STA r7_ek0+1
  LDA R_PXL,Y
  STA r7_ex0
  LDA R_PXH,Y
  STA r7_ex0+1
  STZ r7_eneg
  SEC
  LDA R_PXL,X
  SBC R_PXL,Y
  STA r7_eadx
  LDA R_PXH,X
  SBC R_PXH,Y
  STA r7_eadx+1
  BPL pos
  DEC r7_eneg
  SEC
  LDA #0
  SBC r7_eadx
  STA r7_eadx
  LDA #0
  SBC r7_eadx+1
  STA r7_eadx+1
.pos
  \ q, r = adx / dy
  LDA r7_eadx
  CMP r7_edy
  LDA r7_eadx+1
  SBC r7_edy+1
  BCS ndiv
  LDA r7_eadx
  STA r7_er
  LDA r7_eadx+1
  STA r7_er+1
  STZ r7_eq
  STZ r7_eq+1
  BRA ddone
.ndiv
  LDA r7_eadx+1
  ORA r7_edy+1
  BNE d16
  LDA r7_edy
  STA r7_v0
  LDA r7_eadx
  JSR r7_div8
  STA r7_er
  STZ r7_er+1
  LDA r7_m0
  STA r7_eq
  STZ r7_eq+1
  BRA ddone
.d16
  LDA r7_eadx
  STA r7_m0
  LDA r7_eadx+1
  STA r7_m1
  STZ r7_m2
  STZ r7_m3
  LDA r7_edy
  STA r7_v0
  LDA r7_edy+1
  STA r7_v1
  JSR r7_div32
  LDA r7_m0
  STA r7_eq
  LDA r7_m1
  STA r7_eq+1
  LDA r7_m2
  STA r7_er
  LDA r7_m3
  STA r7_er+1
.ddone
  LDA r7_eneg
  BNE negab
  LDA r7_eq
  STA r7_ea
  LDA r7_eq+1
  STA r7_ea+1
  LDA r7_er
  STA r7_eb
  LDA r7_er+1
  STA r7_eb+1
  BRA abdone
.negab
  LDA r7_er
  ORA r7_er+1
  BNE rnz
  SEC                     \ a = -q, b = 0
  LDA #0
  SBC r7_eq
  STA r7_ea
  LDA #0
  SBC r7_eq+1
  STA r7_ea+1
  STZ r7_eb
  STZ r7_eb+1
  BRA abdone
.rnz
  LDA r7_eq                \ a = -q-1, b = dy - r
  EOR #&FF
  STA r7_ea
  LDA r7_eq+1
  EOR #&FF
  STA r7_ea+1
  SEC
  LDA r7_edy
  SBC r7_er
  STA r7_eb
  LDA r7_edy+1
  SBC r7_er+1
  STA r7_eb+1
.abdone
  LDX r7_side4
  LDA r7_ek0
  ORA r7_ek0+1
  BNE k0nz
  LDA r7_ex0
  STA RZ_SA,X
  LDA r7_ex0+1
  STA RZ_SA+1,X
  STZ RZ_TA,X
  STZ RZ_TA+1,X
  JMP install
.k0nz                     \ clipped start: q2, r2 = adx*k / dy
  LDA r7_eadx
  STA r7_ma
  LDA r7_eadx+1
  STA r7_ma+1
  LDA r7_ek0
  STA r7_mb
  LDA r7_ek0+1
  STA r7_mb+1
  JSR r7_mul16
  LDA r7_edy
  STA r7_v0
  LDA r7_edy+1
  STA r7_v1
  JSR r7_div32
  LDX r7_side4
  LDA r7_eneg
  BNE kneg
  LDA r7_m2
  ORA r7_m3
  BEQ kz
  SEC                     \ S = x0 + q2 + 1, t = dy - r2
  LDA r7_ex0
  ADC r7_m0
  STA RZ_SA,X
  LDA r7_ex0+1
  ADC r7_m1
  STA RZ_SA+1,X
  SEC
  LDA r7_edy
  SBC r7_m2
  STA RZ_TA,X
  LDA r7_edy+1
  SBC r7_m3
  STA RZ_TA+1,X
  JMP install
.kz
  CLC                     \ S = x0 + q2, t = 0
  LDA r7_ex0
  ADC r7_m0
  STA RZ_SA,X
  LDA r7_ex0+1
  ADC r7_m1
  STA RZ_SA+1,X
  STZ RZ_TA,X
  STZ RZ_TA+1,X
  JMP install
.kneg
  SEC                     \ S = x0 - q2, t = r2
  LDA r7_ex0
  SBC r7_m0
  STA RZ_SA,X
  LDA r7_ex0+1
  SBC r7_m1
  STA RZ_SA+1,X
  LDA r7_m2
  STA RZ_TA,X
  LDA r7_m3
  STA RZ_TA+1,X
.install
  RTS
}



\ ============================================================================
\ Dirty repair outside the disc rows (R_DISCROWS calls r7_crep before its row
\ loop).  The dirty rows that are in neither this buffer's old disc rows nor
\ the new ones hold nothing but black under their dirty extents, so each such
\ row's extent, widened to whole bytes, is blacked by one row run through
\ r7_rrun, its R_WL/R_WR set to that and its DIRTY emptied; R_DISCROWS' row
\ loop then only visits the disc rows (r_lo..r_hi and r_dya..r_dyz are
\ narrowed to them).  Byte columns 0 and 63 hold the border: their bytes are
\ masked.  (Byte-column runs were measured against these row runs on a
\ capture of the game, with the same row handling either side: rows won; see
\ the columns-experiments branch.)
\ ============================================================================
c_L   = &18
c_R   = &19
c_NL  = &1A
c_YE  = &1E
c_M   = &23
c_CO  = &22
c_BT  = &24
c_BB  = &25


.r7_crep
{
  STZ R_PRCWB
  LDA R_PRDYZ
  CMP R_PRDYA
  BCC none
  LDX R_PRBUF             \ band = old disc rows + new disc rows
  LDA R_PRDST,X
  CMP R_PRNT
  BCC b1
  LDA R_PRNT
.b1
  STA c_BT
  LDA R_PRDSB,X
  CMP R_PRNB
  BCS b2
  LDA R_PRNB
.b2
  STA c_BB
  LDY R_PRDYA
  CMP c_BT
  BCS band
  LDA R_PRDYZ             \ no disc rows: all the dirty rows
  JSR rep
  LDA #&FF                \ and no disc rows to loop over
  STA R_PRLO
  STZ R_PRHI
.none
  RTS
.band
  CPY c_BT                \ dya .. min(dyz, bt - 1)
  BCS p2
  LDA c_BT
  DEC A
  CMP R_PRDYZ
  BCC p1
  LDA R_PRDYZ
.p1
  JSR rep
.p2
  LDA c_BB                \ max(dya, bb + 1) .. dyz
  INC A
  BEQ nar
  TAY
  CPY R_PRDYA
  BCS p3
  LDY R_PRDYA
.p3
  LDA R_PRDYZ
  STY c_NL
  CMP c_NL
  BCC nar
  JSR rep
.nar                      \ the row loop: disc rows only
  LDA R_PRLO
  CMP c_BT
  BCS n1
  LDA c_BT
  STA R_PRLO
.n1
  LDA R_PRHI
  CMP c_BB
  BCC n2
  LDA c_BB
  STA R_PRHI
.n2
  LDA R_PRDYA
  CMP R_PRLO
  BCS n3
  LDA R_PRLO
  STA R_PRDYA
.n3
  LDA R_PRDYZ
  CMP R_PRHI
  BCC n4
  LDA R_PRHI
  STA R_PRDYZ
.n4
  LDA R_PRDYZ
  CMP R_PRDYA
  BCS n5
  LDA #&FF
  STA R_PRDYA
  STZ R_PRDYZ
.n5
  RTS
\ rep: rows Y .. A
.rep
  STA R_PRCWB
  INC A
  STA c_YE
  CPY R_PRWT
  BCS r1
  STY R_PRWT
.r1
  JMP r7_rowrep
}

\ r7_rowrep: rows Y .. c_YE - 1 (see above)
.r7_rowrep
{
  LDX R_PRBUF
  LDA dlh,X
  STA ld1+2
  STA sd1+2
  STA fl1+2
  STA fs1+2
  LDA drh,X
  STA ld2+2
  STA sd2+2
  STA fl2+2
  STA fs2+2
.frow                     \ fast path: extent inside columns 1..62
.fl2
  LDA R_DIRTYR0,Y
  BEQ fnx
  CMP #252
  BCS slow
  TAX
  ORA #3
  STA R_WR,Y
  LDA r7_jr,X             \ plant the RTS after column R DIV 4
  STA RZ_PP
.fl1
  LDA R_DIRTYL0,Y
  AND #&FC                \ L AND &FC = 0 <=> L < 4
  BEQ slow
  STA R_WL,Y
  TAX
  LDA r7_jr-4,X           \ enter at column L DIV 4
  STA fj+1
  LDA #&FF
.fs1
  STA R_DIRTYL0,Y
  TYA                     \ the run page of row Y
  LSR A
  LSR A
  LSR A
  ORA #HI(r7_rrun)        \ (= ADC: Y DIV 8 < 32)
  STA fj+2
  STA RZ_PP+1
  LDA #&60
  STA (RZ_PP)
  LDA #0
.fs2
  STA R_DIRTYR0,Y
.fj
  JSR &FFFF               \ patched: straight into the row run (the run keeps Y)
  LDA #&99
  STA (RZ_PP)
.fnx
  INY
  CPY c_YE
  BCC frow
  RTS
.slow                     \ an end in column 0 or 63: the general row code
  JSR row1
  BRA fnx
\ row1: row Y, general (the border columns' bytes masked)
.row1
.ld2
  LDA R_DIRTYR0,Y
  STA c_R
  ORA #3
  STA R_WR,Y
.ld1
  LDX R_DIRTYL0,Y
  STX c_L
  TXA
  AND #&FC
  STA R_WL,Y
  LDA #&FF
.sd1
  STA R_DIRTYL0,Y
  LDA #0
.sd2
  STA R_DIRTYR0,Y
  TXA                     \ first byte column (0: the border's)
  LSR A
  LSR A
  BEQ e0
.nl1
  STA c_NL
  LDA c_R                 \ last byte column (63: the border's)
  LSR A
  LSR A
  CMP #63
  BEQ e63
.nr1
  INC A
  CMP c_NL
  BEQ nx
  BCC nx
  TAX                     \ plant the RTS at column NR
  LDA r7_j3,X
  STA RZ_PP
  TYA                     \ the run page of row Y
  LSR A
  LSR A
  LSR A
  ORA #HI(r7_rrun)        \ (= ADC: Y DIV 8 < 32)
  STA RZ_PP+1
  STA rj+2
  LDX c_NL
  LDA r7_j3,X
  STA rj+1
  LDA #&60
  STA (RZ_PP)
  STY RZ_Y
  LDA #0
  JSR rj
  LDA #&99
  STA (RZ_PP)
  LDY RZ_Y
.nx
  RTS
.rj
  JMP &FFFF
.e0
  STY RZ_Y
  JSR edge0
  LDY RZ_Y
  LDA #1
  BRA nl1
.e63
  STY RZ_Y
  JSR edge63
  LDY RZ_Y
  LDA #62
  BRA nr1
\ edge0 / edge63: black pixels c_L .. c_R of row RZ_Y within column 0 / 63
.edge0
  LDX c_R
  CPX #4
  BCC e0a
  LDX #3
.e0a
  LDA r7_rm,X
  LDX c_L
  AND r7_lm,X
  LDX #0
  BRA eg
.edge63
  LDA c_L
  CMP #252
  BCS e6a
  LDA #252
.e6a
  AND #3
  TAX
  LDA c_R                 \ (>= 252)
  AND #3
  TAY
  LDA r7_lm,X
  AND r7_rm,Y
  LDX #&F8
.eg
  EOR #&FF
  STA c_M
  STX c_CO
  LDA RZ_Y
  AND #7
  ORA c_CO
  STA RZ_PA
  LDA RZ_Y
  LSR A
  LSR A
  AND #&FE
  ORA #&40
  CPX #0
  BEQ eg1
  INC A
.eg1
  STA RZ_PA+1
  LDA (RZ_PA)
  AND c_M
  STA (RZ_PA)
  RTS
.dlh EQUB HI(R_DIRTYL0), HI(R_DIRTYL1)
.drh EQUB HI(R_DIRTYR0), HI(R_DIRTYR1)
}


\ ============================================================================
\ R_INIT (bank 7 part)
\ ============================================================================
.r7_init
{
  LDA #1
  STA R_CL
  STA R_CT
  LDA #254
  STA R_CR
  LDA #191
  STA R_CB
  LDA #&FF
  STA R_SCOL
  STA R_NDT
  STZ R_NDB
  STZ R_NDF
  STZ R_SN
  STZ R_PN
  LDA #1                  \ R_SETBUF 0 (forcing the patch)
  STA R_PRBUF
  LDX #LO(R_SETBUF)
  STX r_hzt5
  LDX #HI(R_SETBUF)
  STX r_hzt5+1
  LDA #0
  JSR r_call5
  LDY #191
.il
  LDA #&FF
  STA R_DIRTYL0,Y
  STA R_DISCL0,Y
  STA R_DIRTYL1,Y
  STA R_DISCL1,Y
  STA R_WL,Y
  LDA #0
  STA R_DIRTYR0,Y
  STA R_DISCR0,Y
  STA R_DIRTYR1,Y
  STA R_DISCR1,Y
  STA R_WR,Y
  DEY
  CPY #&FF
  BNE il
  LDX #1
.ib
  JSR r7_reset1
  DEX
  BPL ib
  LDA #&FF
  STA R_PRWT
  STZ R_PRWB
  RTS
}






\ R_LINE's variables (r7_ov, in run page 1's tail): the long path's
r_lxm = r7_ov + 0
r_maj0 = r7_ov + 1
r_min0 = r7_ov + 3
r_dmaj = r7_ov + 5
r_admin = r7_ov + 7
r_smin = r7_ov + 9
r_wlo = r7_ov + 10
r_whi = r7_ov + 11
r_vlo = r7_ov + 12
r_vhi = r7_ov + 13
r_ilo = r7_ov + 14
r_ihi = r7_ov + 16
r_err = r7_ov + 18
r_e2maj = r7_ov + 20
r_e2min = r7_ov + 22
r_cmaj = r7_ov + 24
r_cmin = r7_ov + 25
r_lcnt = r7_ov + 27

\ ============================================================================
\ R_LINE (the frame layer's T_LINE pages bank 7 and calls it)
\ ============================================================================
.R_LINE
{
  LDA R_X0+1              \ both ends in the window: the fast path
  ORA R_X1+1
  ORA R_Y0+1
  ORA R_Y1+1
  BNE slow0
  LDA R_X0
  CMP R_CL
  BCC slow0
  CMP R_CR
  BEQ f1
  BCS slow0
.f1
  LDA R_X1
  CMP R_CL
  BCC slow0
  CMP R_CR
  BEQ f2
  BCS slow0
.f2
  LDA R_Y0
  CMP R_CT
  BCC slow0
  CMP R_CB
  BEQ f3
  BCS slow0
.f3
  LDA R_Y1
  CMP R_CT
  BCC slow0
  CMP R_CB
  BEQ f4
  BCS slow0
.f4
  JMP r7_line
.slow0
  LDA R_X0+1              \ 8-bit end points: bank 7 (clipped)
  ORA R_X1+1
  ORA R_Y0+1
  ORA R_Y1+1
  BNE slow1
  JMP r7_linec
.slow1
  LDA R_Y0                \ rows touched -> this buffer's row range
  CMP R_Y1
  LDA R_Y0+1
  SBC R_Y1+1
  BVC yc0
  EOR #&80
.yc0
  BMI y0top
  LDX #4
  LDY #0
  BRA yc1
.y0top
  LDX #0
  LDY #4
.yc1
  LDA R_Y0+1,X            \ top
  BMI yt_ct
  BNE yno
  LDA R_Y0,X
  CMP R_CT
  BCS yt1
.yt_ct
  LDA R_CT
.yt1
  STA RZ_T0
  LDA R_Y0+1,Y            \ bottom
  BMI yno
  BNE yb_cb
  LDA R_Y0,Y
  CMP R_CB
  BCC yb1
.yb_cb
  LDA R_CB
.yb1
  CMP RZ_T0
  BCC yno
  LDX R_PRBUF
  CMP R_PRDYB,X
  BCC yb2
  STA R_PRDYB,X
.yb2
  LDA RZ_T0
  CMP R_PRDYT,X
  BCS yno
  STA R_PRDYT,X
.yno
  JSR r7_lc16             \ short lines: clipped exactly, and drawn
  BNE yn1
  RTS
.yn1
  LDX R_PRBUF             \ r7_pset's DIRTY operands
  CPX r7_lbuf
  BEQ yn2
  JSR r7_lpat
.yn2
  LDX #2                  \ d = P1 - P0 -> T0,T1 (x) T2,T3 (y); |d| -> T4..T7
.dl
  SEC
  LDA R_X1,X
  SBC R_X0,X
  STA RZ_T0,X
  STA RZ_T4,X
  LDA R_X1+1,X
  SBC R_X0+1,X
  STA RZ_T1,X
  STA RZ_T5,X
  BPL dp
  SEC
  LDA #0
  SBC RZ_T0,X
  STA RZ_T4,X
  LDA #0
  SBC RZ_T1,X
  STA RZ_T5,X
.dp
  DEX
  DEX
  BPL dl
  LDX #0                  \ X = major axis offset (0 = x, 2 = y)
  LDY #2                  \ Y = minor
  LDA RZ_T4
  CMP RZ_T6
  LDA RZ_T5
  SBC RZ_T7
  BCS mx
  LDX #2
  LDY #0
.mx
  STX RZ_PA               \ major axis offset
  STY RZ_PA+1             \ minor axis offset
  LDA R_CL,X
  STA r_wlo
  LDA R_CR,X
  STA r_whi
  LDA R_CL,Y
  STA r_vlo
  LDA R_CR,Y
  STA r_vhi
  LDA RZ_T4,X
  STA r_dmaj
  LDA RZ_T5,X
  STA r_dmaj+1
  LDA RZ_T4,Y
  STA r_admin
  LDA RZ_T5,Y
  STA r_admin+1
  STZ r_smin              \ minor step: sign(d minor), negated if swapped
  ORA RZ_T4,Y
  BEQ sdone
  LDA RZ_T1,Y
  EOR RZ_T1,X
  BMI sneg
  LDA #1
  BRA sst
.sneg
  LDA #&FF
.sst
  STA r_smin
.sdone
  LDA #0                  \ start at P1 when d major < 0
  BIT RZ_T1,X
  BPL ns
  LDA #4
.ns
  STA RZ_PB
  CLC
  ADC RZ_PA
  TAY
  LDA R_X0,Y
  STA r_maj0
  LDA R_X0+1,Y
  STA r_maj0+1
  LDA RZ_PB
  CLC
  ADC RZ_PA+1
  TAY
  LDA R_X0,Y
  STA r_min0
  LDA R_X0+1,Y
  STA r_min0+1
  LDA RZ_PA
  EOR #2
  STA r_lxm               \ non-zero: x major
.mdone
  LDA r_dmaj
  ORA r_dmaj+1
  BNE nz
  LDA r_maj0+1            \ a single point
  ORA r_min0+1
  BNE out1
  LDX r_maj0
  LDY r_min0
  LDA r_lxm
  BNE pt
  LDX r_min0
  LDY r_maj0
.pt
  JMP r7_pclip
.out1
  RTS
.nz
  SEC                     \ ilo = max(0, wlo - maj0)
  LDA r_wlo
  SBC r_maj0
  STA r_ilo
  LDA #0
  SBC r_maj0+1
  STA r_ilo+1
  BPL il1
  STZ r_ilo
  STZ r_ilo+1
.il1
  SEC                     \ ihi = min(dmaj, whi - maj0)
  LDA r_whi
  SBC r_maj0
  STA r_ihi
  LDA #0
  SBC r_maj0+1
  STA r_ihi+1
  BMI out1
  LDA r_dmaj
  CMP r_ihi
  LDA r_dmaj+1
  SBC r_ihi+1
  BCS ih1
  LDA r_dmaj
  STA r_ihi
  LDA r_dmaj+1
  STA r_ihi+1
.ih1
  LDA r_ihi
  CMP r_ilo
  LDA r_ihi+1
  SBC r_ilo+1
  BCC out1
  SEC
  LDA r_ihi
  SBC r_ilo
  INC A
  STA r_lcnt
  CLC
  LDA r_maj0
  ADC r_ilo
  STA r_cmaj
  LDA r_dmaj
  ASL A
  STA r_e2maj
  STA r7_v0
  LDA r_dmaj+1
  ROL A
  STA r_e2maj+1
  STA r7_v1
  LDA r_admin
  ASL A
  STA r_e2min
  LDA r_admin+1
  ROL A
  STA r_e2min+1
  LDA r_ilo
  ORA r_ilo+1
  BNE fullq
  STZ r7_m0                \ starts in the window: q = 0, r = dmaj
  STZ r7_m1
  LDA r_dmaj
  STA r7_m2
  LDA r_dmaj+1
  STA r7_m3
  BRA qdone
.fullq
  \ q, r = (2*ilo*admin + dmaj) / (2*dmaj)
  LDA r_ilo
  STA r7_ma
  LDA r_ilo+1
  STA r7_ma+1
  LDA r_admin
  STA r7_mb
  LDA r_admin+1
  STA r7_mb+1
  JSR r7_mul16
  ASL r7_m0
  ROL r7_m1
  ROL r7_m2
  ROL r7_m3
  CLC
  LDA r7_m0
  ADC r_dmaj
  STA r7_m0
  LDA r7_m1
  ADC r_dmaj+1
  STA r7_m1
  BCC a1
  INC r7_m2
  BNE a1
  INC r7_m3
.a1
  JSR r7_div32
.qdone
  LDA r7_m2
  STA r_err
  LDA r7_m3
  STA r_err+1
  LDA r_smin
  BMI qneg
  CLC
  LDA r_min0
  ADC r7_m0
  STA r_cmin
  LDA r_min0+1
  ADC r7_m1
  STA r_cmin+1
  BRA lp
.qneg
  SEC
  LDA r_min0
  SBC r7_m0
  STA r_cmin
  LDA r_min0+1
  SBC r7_m1
  STA r_cmin+1
.lp
  LDA r_cmin+1
  BMI lowside
  BNE highside
  LDA r_cmin
  CMP r_vlo
  BCC lowside
  CMP r_vhi
  BEQ inwin
  BCS highside
.inwin
  LDA r_lxm
  BEQ pym
  LDX r_cmaj
  LDY r_cmin
  JSR r7_pset
  BRA step
.pym
  LDX r_cmin
  LDY r_cmaj
  JSR r7_pset
  BRA step
.lowside
  LDA r_smin
  BEQ out
  BMI out
  BRA step
.highside
  LDA r_smin
  BEQ out
  BPL out
.step
  DEC r_lcnt
  BEQ out
  INC r_cmaj
  CLC
  LDA r_err
  ADC r_e2min
  STA r_err
  LDA r_err+1
  ADC r_e2min+1
  STA r_err+1
  BCS sb
  LDA r_err
  CMP r_e2maj
  LDA r_err+1
  SBC r_e2maj+1
  BCS sb
  JMP lp
.sb
  LDA r_err
  SBC r_e2maj
  STA r_err
  LDA r_err+1
  SBC r_e2maj+1
  STA r_err+1
  LDA r_smin
  BMI dm
  INC r_cmin
  BNE back
  INC r_cmin+1
  BRA back
.dm
  LDA r_cmin
  BNE d1
  DEC r_cmin+1
.d1
  DEC r_cmin
  BRA back
.back
  JMP lp
.out
  RTS
}

\ ============================================================================
\ r7_line: R_LINE for 8-bit end points (0..255), R_LINE's pixels (Bresenham
\ along the major axis from the left / top end).  Pointer RZ_PP (+ Y = row
\ AND 7), pixel mask l_m, colour by row AND 7 (r7_lct); X = row; DIRTY[b][row]
\ extended per pixel; the buffer's row range per line.  r7_line: both ends
\ inside the window.  r7_linec: otherwise; the pixels before the first one
\ inside the window are stepped over, and the loops stop at the first one
\ past it (the pixels inside are one run: x and y are monotonic).
\ ============================================================================


\ r7_lpat: X = buffer: patch R_LINE's DIRTY operands for it
.r7_lpat
  STX r7_lbuf
  LDA r7_ldl,X
  STA lyl_p0+2
  STA lyl_p1+2
  STA lyr_p0+2
  STA lyr_p1+2
  STA lxu_p0+2
  STA lxu_p1+2
  STA lxd_p0+2
  STA lxd_p1+2
  STA lylc_p0+2
  STA lylc_p1+2
  STA lyrc_p0+2
  STA lyrc_p1+2
  STA lxuc_p0+2
  STA lxuc_p1+2
  STA lxdc_p0+2
  STA lxdc_p1+2
  STA r7_ps0+2
  STA r7_ps1+2
  LDA r7_ldr,X
  STA lyl_p2+2
  STA lyl_p3+2
  STA lyr_p2+2
  STA lyr_p3+2
  STA lxu_p2+2
  STA lxu_p3+2
  STA lxd_p2+2
  STA lxd_p3+2
  STA lylc_p2+2
  STA lylc_p3+2
  STA lyrc_p2+2
  STA lyrc_p3+2
  STA lxuc_p2+2
  STA lxuc_p3+2
  STA lxdc_p2+2
  STA lxdc_p3+2
  STA r7_ps2+2
  STA r7_ps3+2
  RTS

.r7_lines                 \ prepared by r7_lc16 (l_x, l_y0, l_e, l_a, l_b, l_n, l_k)
  LDA #&10
  BRA r7_lgo
.r7_linec
  LDA #8
  BRA r7_lgo
.r7_line
  LDA #0
.r7_lgo
{
  STA l_c
  LDX R_PRBUF
  CPX r7_lbuf
  BEQ pd
  JSR r7_lpat
.pd
  LDY #6
.ct
  LDA R_COLE
  STA r7_lct,Y
  LDA R_COLO
  STA r7_lct+1,Y
  DEY
  DEY
  BPL ct
  LDA l_c
  CMP #&10
  BNE nprep
  LDA #8                  \ prepared: clipped loops from the given pixel
  STA l_c
  LDA R_CR
  INC A
  STA r7_cr1
  LDA R_CB
  INC A
  STA r7_cb1
  LDX l_y0
  JMP in
.nprep
  LDA R_X0
  STA l_x0
  LDA R_Y0
  STA l_y0
  LDA R_X1
  STA l_x1
  LDA R_Y1
  STA l_y1
  SEC
  LDA l_x1
  SBC l_x0
  BCS a1
  EOR #&FF
  INC A
.a1
  STA l_a                 \ |dx|
  SEC
  LDA l_y1
  SBC l_y0
  BCS a2
  EOR #&FF
  INC A
.a2
  STA l_b                 \ |dy|
  CMP l_a
  BCC xm
  BEQ xm
  LDA l_y1                \ y major: from the top end
  CMP l_y0
  BCS y1
  JSR r7_lswap
.y1
  LDA l_b                 \ steps = dy, e = (dy DIV 2) - dy, a = |dx|, b = dy
  JSR r7_lstart
  LDA l_x1
  CMP l_x0
  LDA #0
  ROL A                   \ 0: x decreases, 1: increases
  BRA go
.xm
  LDA l_x1                \ x major: from the left end
  CMP l_x0
  BCS x1
  JSR r7_lswap
.x1
  LDX l_a                 \ a = |dy|, b = |dx|
  LDY l_b
  STX l_b
  STY l_a
  TXA
  JSR r7_lstart
  LDA l_y1
  CMP l_y0
  LDA #1
  ROL A                   \ 2: y decreases, 3: increases
.go
  STA l_k
  INC l_n                 \ pixels = steps + 1 (0: 256)
  LDX l_y0                \ X = row, l_x = x
  LDA l_c
  BEQ in
  JSR clip                \ clipped: to the first pixel inside (C = 1: none)
  BCC in
  RTS
.in
  LDA l_y0                \ the byte of (l_x, row X): RZ_PP + Y
  LSR A
  LSR A
  AND #&FE
  ORA #&40
  STA RZ_PP+1
  LDA l_x
  AND #&FC
  ASL A
  STA RZ_PP
  BCC s1
  INC RZ_PP+1
.s1
  LDA l_x
  AND #3
  TAY
  LDA r7_lm,Y             \ pixels x..3 AND pixels 0..x = pixel x
  AND r7_rm,Y
  STA l_m
  LDA l_k
  ORA l_c
  ASL A
  TAY
  LDA tab,Y
  STA jp+1
  LDA tab+1,Y
  STA jp+2
  TXA
  AND #7
  TAY
.jp
  JMP &FFFF
.tab
  EQUW lyl, lyr, lxu, lxd, 0, 0, 0, 0, lylc, lyrc, lxuc, lxdc
\ clip: step from pixel 0 (l_x, row X) over the pixels outside the window
\ (l_n counting down, l_e as the loops); C = 1 if none is inside.  Then
\ l_y0 = the row.  Bounds for the loops: r7_cr1, r7_cb1.
.clip
  LDA R_CR
  INC A
  STA r7_cr1
  LDA R_CB
  INC A
  STA r7_cb1
.cl
  CPX R_CT                \ inside?
  BCC out
  CPX r7_cb1
  BCS out
  LDA l_x
  CMP R_CL
  BCC out
  CMP r7_cr1
  BCS out
  STX l_y0
  CLC
  RTS
.out
  DEC l_n
  BNE step
  SEC
  RTS
.step
  LDA l_k                 \ major step, then minor if the error carries
  CMP #2
  BCS sx
  INX                     \ y major: y + 1
  LDA l_e
  CLC
  ADC l_a
  STA l_e
  BCC cl
  SBC l_b
  STA l_e
  LDA l_k
  BEQ sxl
  INC l_x
  BRA cl
.sxl
  DEC l_x
  BRA cl
.sx
  INC l_x                 \ x major: x + 1
  LDA l_e
  CLC
  ADC l_a
  STA l_e
  BCC cl
  SBC l_b
  STA l_e
  LDA l_k
  CMP #3
  BEQ syd
  DEX
  BRA cl
.syd
  INX
  BRA cl
.lyl
  LDA (RZ_PP),Y
  EOR r7_lct,Y
  AND l_m
  EOR (RZ_PP),Y
  STA (RZ_PP),Y
  LDA l_x
.^lyl_p0 CMP R_DIRTYL0,X
  BCS lyl_1
.^lyl_p1 STA R_DIRTYL0,X
.lyl_1
.^lyl_p2 CMP R_DIRTYR0,X
  BCC lyl_2
.^lyl_p3 STA R_DIRTYR0,X
.lyl_2
  DEC l_n
  BEQ lyl_d
  INX
  INY
  CPY #8
  BNE lyl_y
  LDY #0
  LDA RZ_PP+1
  ADC #1
  STA RZ_PP+1
.lyl_y
  LDA l_e
  CLC
  ADC l_a
  STA l_e
  BCC lyl
  SBC l_b
  STA l_e
  DEC l_x
  ASL l_m
  BCC lyl
  LDA #&11
  STA l_m
  LDA RZ_PP
  SEC
  SBC #8
  STA RZ_PP
  BCS lyl
  DEC RZ_PP+1
  BRA lyl
.lyl_d
  RTS
.lyr
  LDA (RZ_PP),Y
  EOR r7_lct,Y
  AND l_m
  EOR (RZ_PP),Y
  STA (RZ_PP),Y
  LDA l_x
.^lyr_p0 CMP R_DIRTYL0,X
  BCS lyr_1
.^lyr_p1 STA R_DIRTYL0,X
.lyr_1
.^lyr_p2 CMP R_DIRTYR0,X
  BCC lyr_2
.^lyr_p3 STA R_DIRTYR0,X
.lyr_2
  DEC l_n
  BEQ lyr_d
  INX
  INY
  CPY #8
  BNE lyr_y
  LDY #0
  LDA RZ_PP+1
  ADC #1
  STA RZ_PP+1
.lyr_y
  LDA l_e
  CLC
  ADC l_a
  STA l_e
  BCC lyr
  SBC l_b
  STA l_e
  INC l_x
  LSR l_m
  BCC lyr
  LDA #&88
  STA l_m
  LDA RZ_PP
  ADC #7
  STA RZ_PP
  BCC lyr
  INC RZ_PP+1
  BRA lyr
.lyr_d
  RTS
.lxu
  LDA (RZ_PP),Y
  EOR r7_lct,Y
  AND l_m
  EOR (RZ_PP),Y
  STA (RZ_PP),Y
  LDA l_x
.^lxu_p0 CMP R_DIRTYL0,X
  BCS lxu_1
.^lxu_p1 STA R_DIRTYL0,X
.lxu_1
.^lxu_p2 CMP R_DIRTYR0,X
  BCC lxu_2
.^lxu_p3 STA R_DIRTYR0,X
.lxu_2
  DEC l_n
  BEQ lxu_d
  LDA l_e
  CLC
  ADC l_a
  STA l_e
  BCC lxu_x
  SBC l_b
  STA l_e
  DEX
  DEY
  BPL lxu_y
  LDY #7
  LDA RZ_PP+1
  SEC
  SBC #2
  STA RZ_PP+1
.lxu_y
.lxu_x
  INC l_x
  LSR l_m
  BCC lxu
  LDA #&88
  STA l_m
  LDA RZ_PP
  ADC #7
  STA RZ_PP
  BCC lxu
  INC RZ_PP+1
  BRA lxu
.lxu_d
  RTS
.lxd
  LDA (RZ_PP),Y
  EOR r7_lct,Y
  AND l_m
  EOR (RZ_PP),Y
  STA (RZ_PP),Y
  LDA l_x
.^lxd_p0 CMP R_DIRTYL0,X
  BCS lxd_1
.^lxd_p1 STA R_DIRTYL0,X
.lxd_1
.^lxd_p2 CMP R_DIRTYR0,X
  BCC lxd_2
.^lxd_p3 STA R_DIRTYR0,X
.lxd_2
  DEC l_n
  BEQ lxd_d
  LDA l_e
  CLC
  ADC l_a
  STA l_e
  BCC lxd_x
  SBC l_b
  STA l_e
  INX
  INY
  CPY #8
  BNE lxd_y
  LDY #0
  LDA RZ_PP+1
  ADC #1
  STA RZ_PP+1
.lxd_y
.lxd_x
  INC l_x
  LSR l_m
  BCC lxd
  LDA #&88
  STA l_m
  LDA RZ_PP
  ADC #7
  STA RZ_PP
  BCC lxd
  INC RZ_PP+1
  BRA lxd
.lxd_d
  RTS
.lylc
  LDA (RZ_PP),Y
  EOR r7_lct,Y
  AND l_m
  EOR (RZ_PP),Y
  STA (RZ_PP),Y
  LDA l_x
.^lylc_p0 CMP R_DIRTYL0,X
  BCS lylc_1
.^lylc_p1 STA R_DIRTYL0,X
.lylc_1
.^lylc_p2 CMP R_DIRTYR0,X
  BCC lylc_2
.^lylc_p3 STA R_DIRTYR0,X
.lylc_2
  DEC l_n
  BEQ lylc_d
  INX
  CPX r7_cb1
  BCS lylc_d
  INY
  CPY #8
  BNE lylc_y
  LDY #0
  LDA RZ_PP+1
  ADC #1
  STA RZ_PP+1
.lylc_y
  LDA l_e
  CLC
  ADC l_a
  STA l_e
  BCC lylc
  SBC l_b
  STA l_e
  DEC l_x
  LDA l_x
  CMP R_CL
  BCC lylc_d
  ASL l_m
  BCC lylc
  LDA #&11
  STA l_m
  LDA RZ_PP
  SEC
  SBC #8
  STA RZ_PP
  BCS lylc
  DEC RZ_PP+1
  BRA lylc
.lylc_d
  RTS
.lyrc
  LDA (RZ_PP),Y
  EOR r7_lct,Y
  AND l_m
  EOR (RZ_PP),Y
  STA (RZ_PP),Y
  LDA l_x
.^lyrc_p0 CMP R_DIRTYL0,X
  BCS lyrc_1
.^lyrc_p1 STA R_DIRTYL0,X
.lyrc_1
.^lyrc_p2 CMP R_DIRTYR0,X
  BCC lyrc_2
.^lyrc_p3 STA R_DIRTYR0,X
.lyrc_2
  DEC l_n
  BEQ lyrc_d
  INX
  CPX r7_cb1
  BCS lyrc_d
  INY
  CPY #8
  BNE lyrc_y
  LDY #0
  LDA RZ_PP+1
  ADC #1
  STA RZ_PP+1
.lyrc_y
  LDA l_e
  CLC
  ADC l_a
  STA l_e
  BCC lyrc
  SBC l_b
  STA l_e
  INC l_x
  LDA l_x
  CMP r7_cr1
  BCS lyrc_d
  LSR l_m
  BCC lyrc
  LDA #&88
  STA l_m
  LDA RZ_PP
  ADC #7
  STA RZ_PP
  BCC lyrc
  INC RZ_PP+1
  BRA lyrc
.lyrc_d
  RTS
.lxuc
  LDA (RZ_PP),Y
  EOR r7_lct,Y
  AND l_m
  EOR (RZ_PP),Y
  STA (RZ_PP),Y
  LDA l_x
.^lxuc_p0 CMP R_DIRTYL0,X
  BCS lxuc_1
.^lxuc_p1 STA R_DIRTYL0,X
.lxuc_1
.^lxuc_p2 CMP R_DIRTYR0,X
  BCC lxuc_2
.^lxuc_p3 STA R_DIRTYR0,X
.lxuc_2
  DEC l_n
  BEQ lxuc_d
  LDA l_e
  CLC
  ADC l_a
  STA l_e
  BCC lxuc_x
  SBC l_b
  STA l_e
  DEX
  CPX R_CT
  BCC lxuc_d
  DEY
  BPL lxuc_y
  LDY #7
  LDA RZ_PP+1
  SEC
  SBC #2
  STA RZ_PP+1
.lxuc_y
.lxuc_x
  INC l_x
  LDA l_x
  CMP r7_cr1
  BCS lxuc_d
  LSR l_m
  BCC lxuc
  LDA #&88
  STA l_m
  LDA RZ_PP
  ADC #7
  STA RZ_PP
  BCC lxuc
  INC RZ_PP+1
  BRA lxuc
.lxuc_d
  RTS
.lxdc
  LDA (RZ_PP),Y
  EOR r7_lct,Y
  AND l_m
  EOR (RZ_PP),Y
  STA (RZ_PP),Y
  LDA l_x
.^lxdc_p0 CMP R_DIRTYL0,X
  BCS lxdc_1
.^lxdc_p1 STA R_DIRTYL0,X
.lxdc_1
.^lxdc_p2 CMP R_DIRTYR0,X
  BCC lxdc_2
.^lxdc_p3 STA R_DIRTYR0,X
.lxdc_2
  DEC l_n
  BEQ lxdc_d
  LDA l_e
  CLC
  ADC l_a
  STA l_e
  BCC lxdc_x
  SBC l_b
  STA l_e
  INX
  CPX r7_cb1
  BCS lxdc_d
  INY
  CPY #8
  BNE lxdc_y
  LDY #0
  LDA RZ_PP+1
  ADC #1
  STA RZ_PP+1
.lxdc_y
.lxdc_x
  INC l_x
  LDA l_x
  CMP r7_cr1
  BCS lxdc_d
  LSR l_m
  BCC lxdc
  LDA #&88
  STA l_m
  LDA RZ_PP
  ADC #7
  STA RZ_PP
  BCC lxdc
  INC RZ_PP+1
  BRA lxdc
.lxdc_d
  RTS
}


\ ----------------------------------------------------------------------------
\ r7_lc16: R_LINE with 16-bit end points and both |dx|, |dy| <= 255: the
\ first pixel inside the window found exactly (pixel i along the major axis
\ from the left / top end has minor offset s * floor((i * a + h) / d), h =
\ d DIV 2), then bank 7's clipped loops from there (r7_lines: they stop at
\ the first pixel past the window).  A <> 0: not handled (the general path), else A = 0.
\ ----------------------------------------------------------------------------
.r7_lc16
{
  SEC                     \ dx -> T0,T1; dy -> T2,T3
  LDA R_X1
  SBC R_X0
  STA RZ_T0
  LDA R_X1+1
  SBC R_X0+1
  STA RZ_T1
  SEC
  LDA R_Y1
  SBC R_Y0
  STA RZ_T2
  LDA R_Y1+1
  SBC R_Y0+1
  STA RZ_T3
  LDX #0                  \ |dx| -> T4, |dy| -> T5 (both must be < 256)
  JSR r7_cab
  BCS no
  STA RZ_T4
  LDX #2
  JSR r7_cab
  BCS no
  STA RZ_T5
  CMP RZ_T4
  BCC xm
  BEQ xm
  LDA RZ_T3               \ y major: from the top end
  BPL y1
  JSR r7_cswap
.y1
  LDA R_Y0
  STA c_m0
  LDA R_Y0+1
  STA c_m0+1
  LDA R_X0
  STA c_n0
  LDA R_X0+1
  STA c_n0+1
  LDA RZ_T5
  STA c_d
  LDA RZ_T4
  STA c_a
  LDA RZ_T1               \ minor sign: dx's
  STA c_s
  ROL A                   \ kind 0: x decreases, 1: increases
  LDA #0
  ROL A
  EOR #1
  STA c_k
  LDA R_CT
  STA c_lo
  LDA R_CB
  STA c_hi
  LDA R_CL
  STA c_nl
  LDA R_CR
  STA c_nh
  BRA go
.no
  LDA #1
  RTS

.xm
  LDA RZ_T1               \ x major: from the left end
  BPL x1
  JSR r7_cswap
.x1
  LDA R_X0
  STA c_m0
  LDA R_X0+1
  STA c_m0+1
  LDA R_Y0
  STA c_n0
  LDA R_Y0+1
  STA c_n0+1
  LDA RZ_T4
  STA c_d
  LDA RZ_T5
  STA c_a
  LDA RZ_T3               \ minor sign: dy's
  STA c_s
  ROL A                   \ kind 2: y decreases, 3: increases
  LDA #0
  ROL A
  EOR #3
  STA c_k
  LDA R_CL
  STA c_lo
  LDA R_CR
  STA c_hi
  LDA R_CT
  STA c_nl
  LDA R_CB
  STA c_nh
.go
  \ i = max(0, lo - m0)
  SEC
  LDA c_lo
  SBC c_m0
  STA c_i
  LDA #0
  SBC c_m0+1
  STA c_i+1
  BPL g1
  STZ c_i
  STZ c_i+1
.g1
  \ the minor bound it must reach: k = nl - n0 (increasing) / n0 - nh
  BIT c_s
  BMI dec
  SEC
  LDA c_nl
  SBC c_n0
  STA c_t
  LDA #0
  SBC c_n0+1
  STA c_t+1
  BRA kk
.dec
  SEC
  LDA c_n0
  SBC c_nh
  STA c_t
  LDA c_n0+1
  SBC #0
  STA c_t+1
.kk
  LDA c_t+1               \ k <= 0: from the start
  BMI k0
  ORA c_t
  BEQ k0
  LDA c_t+1               \ k > a: never
  BEQ P%+5
  JMP none
  LDA c_a
  CMP c_t
  BCS P%+5
  JMP none
  LDA c_t                 \ i >= ceil((k * d - h) / a) = (k*d - h + a - 1) DIV a
  LDX c_d
  JSR r7_cmul
  LDA c_d
  LSR A
  STA c_t
  SEC
  LDA c_m0w
  SBC c_t
  STA c_m0w
  LDA c_m0w+1
  SBC #0
  STA c_m0w+1
  LDA c_a
  CLC
  SBC #0                  \ (a - 1)
  CLC
  ADC c_m0w
  STA c_m0w
  BCC k1
  INC c_m0w+1
.k1
  LDA c_a
  JSR r7_cdiv
  LDA c_m0w+1             \ i = max(i, that)
  CMP c_i+1
  BCC k0
  BNE k2
  LDA c_m0w
  CMP c_i
  BCC k0
.k2
  LDA c_m0w
  STA c_i
  LDA c_m0w+1
  STA c_i+1
.k0
  LDA c_i+1               \ i <= d?
  BEQ P%+5
  JMP none
  LDA c_d
  CMP c_i
  BCS P%+5
  JMP none
  \ q, r = (h + i * a) DIV / MOD d
  LDA c_i
  LDX c_a
  JSR r7_cmul
  LDA c_d
  LSR A
  CLC
  ADC c_m0w
  STA c_m0w
  BCC q1
  INC c_m0w+1
.q1
  LDA c_d
  BNE q2
  STZ c_m0w               \ (d = 0: one pixel)
  STZ c_m0w+1
  STZ c_r
  BRA q3
.q2
  JSR r7_cdiv
.q3
  \ start: major m0 + i, minor n0 +/- q: inside the window?
  CLC
  LDA c_m0
  ADC c_i
  STA c_t
  LDA c_m0+1
  ADC #0
  BEQ P%+5
  JMP none
  LDA c_t
  CMP c_lo
  BCS P%+5
  JMP none
  CMP c_hi
  BEQ s1
  BCC P%+5
  JMP none
.s1
  BIT c_s
  BMI sd
  CLC
  LDA c_n0
  ADC c_m0w
  STA c_t+1
  LDA c_n0+1
  ADC c_m0w+1
  BRA s2
.none
  LDA #0                  \ (nothing inside the window: done)
  RTS
.sd
  SEC
  LDA c_n0
  SBC c_m0w
  STA c_t+1
  LDA c_n0+1
  SBC c_m0w+1
.s2
  BEQ P%+5
  JMP none
  LDA c_t+1
  CMP c_nl
  BCS P%+5
  JMP none
  CMP c_nh
  BEQ s3
  BCC P%+5
  JMP none
.s3
  \ hand over: x, y, e = r - d, a, b = d, n = d - i + 1, kind
  LDX c_k
  CPX #2
  BCS sx
  STA l_x                 \ y major: minor = x
  LDA c_t
  STA l_y0
  BRA s4
.sx
  STA l_y0
  LDA c_t
  STA l_x
.s4
  LDA c_r
  SEC
  SBC c_d
  STA l_e
  LDA c_a
  STA l_a
  LDA c_d
  STA l_b
  SEC
  SBC c_i
  INC A
  STA l_n
  STX l_k
  JSR r7_lines
  LDA #0
  RTS
}

.r7_end
PRINT "raster7.asm: ", r7_end - r7_start, " bytes"
