\ ============================================================================
\ raster7.asm -- the rasteriser's second sideways bank (R_BANK_AUX = 7):
\ cold code (R_INIT, R_CLEARALL, R_RESETBUF); room for more.  INCLUDE it at &8000
\ in its own bank, after raster_vars.asm, raster_hz.asm and raster.asm (it
\ uses their symbols).  The caller never calls it directly: raster.asm's
\ entry points page it in through raster_hz.asm's stubs.
\ ============================================================================

ALIGN &100
.r7_start
.r7_xo
FOR x, 0, 255
  EQUB (x * 2) AND &F8
NEXT
.r7_j
FOR x, 0, 255
  EQUB 3 * (x DIV 4)
NEXT
.r7_lm
FOR x, 0, 255
  EQUB ((&F0 >> (x AND 3)) AND &F0) OR (&0F >> (x AND 3))
NEXT
.r7_rm
FOR x, 0, 255
  EQUB ((&F0 << (3 - (x AND 3))) AND &F0) OR ((&0F << (3 - (x AND 3))) AND &0F)
NEXT


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

ALIGN &100
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

\ ============================================================================
\ R_WMERGE (bank 7 part): WL/WR |= DIRTY[b] over the clip rows
\ ============================================================================
.r7_wmerge
{
  LDX R_PRBUF
  LDA dlh,X
  STA l1+2
  LDA drh,X
  STA l2+2
  LDY R_CT
.lp
.l2
  LDA R_DIRTYR0,Y
  BEQ nx
  STA c_R
.l1
  LDA R_DIRTYL0,Y
  LDX R_WR,Y
  BNE mg
  STA R_WL,Y
  LDA c_R
  STA R_WR,Y
  BRA rg
.mg
  CMP R_WL,Y
  BCS m1
  STA R_WL,Y
.m1
  LDA c_R
  CMP R_WR,Y
  BCC rg
  STA R_WR,Y
.rg
  CPY R_PRWT
  BCS m2
  STY R_PRWT
.m2
  CPY R_PRWB
  BCC nx
  STY R_PRWB
.nx
  CPY R_CB
  INY
  BCC lp
  RTS
.dlh EQUB HI(R_DIRTYL0), HI(R_DIRTYL1)
.drh EQUB HI(R_DIRTYR0), HI(R_DIRTYR1)
}

\ r7_rowrep: rows Y .. c_YE - 1 (see above)
.r7_rowrep
{
  LDX R_PRBUF
  LDA dlh,X
  STA ld1+2
  STA sd1+2
  LDA drh,X
  STA ld2+2
  STA sd2+2
.row
.ld2
  LDA R_DIRTYR0,Y
  BEQ nx
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
  LDA r7_fr,X             \ first byte column (0: the border's)
  BEQ e0
.nl1
  STA c_NL
  LDX c_R
  LDA r7_fr,X             \ last byte column (63: the border's)
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
  LDA r7_rp,Y
  STA RZ_PP+1
  STA rj+2
  LDX c_NL
  LDA r7_j3,X
  STA rj+1
  LDA #&60
  STA (RZ_PP)
  STY RZ_Y
  TYA
  AND #7
  TAX
  LDA #0
.rj
  JSR &FFFF
  LDA #&9D
  STA (RZ_PP)
  LDY RZ_Y
.nx
  INY
  CPY c_YE
  BCC row
  RTS
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
  LDX c_L
  CPX #252
  BCS e6a
  LDX #252
.e6a
  LDA r7_lm,X
  LDX c_R
  AND r7_rm,X
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

ASSERT HI(r7_crep) = HI(r7_wmerge)
.r7_fr                    \ x DIV 4
FOR x, 0, 255
  EQUB x DIV 4
NEXT
.r7_j3                    \ run offset of byte column k (1..63)
FOR k, 0, 63
  EQUB LO(3 * (k - 1))
NEXT
.r7_rp                    \ run page of row y
FOR y, 0, 191
  EQUB HI(r7_rrun) + (y DIV 8)
NEXT
\ the row runs: one page per character row r: STA &4000+&200r+8k,X for byte
\ columns k = 1..63, then RTS
ALIGN &100
.r7_rrun
FOR r, 0, 23
  FOR k, 1, 63
    STA &4000 + r * &200 + k * 8, X
  NEXT
  RTS
  ALIGN &100
NEXT

\ ============================================================================
\ r7_line: R_LINE's fast path (both ends inside the window, 8-bit), R_LINE's
\ pixels (Bresenham along the major axis from the left / top end).  Pointer
\ RZ_PP (+ Y = row AND 7), pixel mask l_m, colour by row AND 7 (r7_lct); X =
\ row; DIRTY[b][row] extended per pixel; the buffer's row range per line.
\ ============================================================================
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

.r7_lct SKIP 8          \ colour byte by row AND 7
.r7_ldl EQUB HI(R_DIRTYL0), HI(R_DIRTYL1)
.r7_ldr EQUB HI(R_DIRTYR0), HI(R_DIRTYR1)
.r7_lbuf EQUB &FF       \ buffer the loops are patched for

.r7_line
{
  LDX R_PRBUF
  CPX r7_lbuf
  BEQ pd
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
  LDA r7_ldr,X
  STA lyl_p2+2
  STA lyl_p3+2
  STA lyr_p2+2
  STA lyr_p3+2
  STA lxu_p2+2
  STA lxu_p3+2
  STA lxd_p2+2
  STA lxd_p3+2
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
  LDA R_X0
  STA l_x0
  LDA R_Y0
  STA l_y0
  LDA R_X1
  STA l_x1
  LDA R_Y1
  STA l_y1
  LDX R_PRBUF             \ the buffer's dirty rows
  LDA l_y0
  LDY l_y1
  CMP l_y1
  BCC o1
  TAY
  LDA l_y1
.o1
  CMP R_PRDYT,X
  BCS o2
  STA R_PRDYT,X
.o2
  TYA
  CMP R_PRDYB,X
  BCC o3
  STA R_PRDYB,X
.o3
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
  JSR swap
.y1
  LDA l_b                 \ steps = dy, e = (dy DIV 2) - dy, a = |dx|, b = dy
  JSR start
  LDA l_x1
  CMP l_x0
  LDA #0
  ROL A                   \ 0: x decreases, 1: increases
  BRA go
.xm
  LDA l_x1                \ x major: from the left end
  CMP l_x0
  BCS x1
  JSR swap
.x1
  LDX l_a                 \ a = |dy|, b = |dx|
  LDY l_b
  STX l_b
  STY l_a
  TXA
  JSR start
  LDA l_y1
  CMP l_y0
  LDA #1
  ROL A                   \ 2: y decreases, 3: increases
.go
  ASL A
  TAX
  LDA tab,X
  STA jp+1
  LDA tab+1,X
  STA jp+2
  LDA l_y0
  AND #7
  TAY
  INC l_n                 \ pixels = steps + 1 (0: 256)
  LDX l_y0
.jp
  JMP &FFFF
.tab
  EQUW lyl, lyr, lxu, lxd
.swap
  LDX l_x1
  LDY l_x0
  STX l_x0
  STY l_x1
  LDX l_y1
  LDY l_y0
  STX l_y0
  STY l_y1
  RTS
\ start: A = steps: l_n = A, l_e = (A DIV 2) - l_b; l_x = x0; RZ_PP = byte
\ of column x0 in row y0's character row (its row 0), l_m = pixel mask
.start
  STA l_n
  LSR A
  SEC
  SBC l_b
  STA l_e
  LDA l_x0
  STA l_x
  AND #3
  TAX
  LDA r7_lm,X             \ pixels x..3 AND pixels 0..x = pixel x
  AND r7_rm,X
  STA l_m
  LDA l_y0
  LSR A
  LSR A
  AND #&FE
  ORA #&40
  STA RZ_PP+1
  LDA l_x0
  AND #&FC
  ASL A
  STA RZ_PP
  BCC s1
  INC RZ_PP+1
.s1
  RTS
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
}

.r7_end
PRINT "raster7.asm: ", r7_end - r7_start, " bytes"
