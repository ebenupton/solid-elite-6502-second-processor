\ ============================================================================
\ raster7.asm -- the rasteriser's second sideways bank (R_BANK_AUX = 7):
\ cold code (R_INIT, R_CLEARALL, R_RESETBUF); room for more.  INCLUDE it at &8000
\ in its own bank, after raster_vars.asm, raster_hz.asm and raster.asm (it
\ uses their symbols).  The caller never calls it directly: raster.asm's
\ entry points page it in through raster_hz.asm's stubs.
\ ============================================================================

\ (The bank starts on a page boundary: the runs need whole pages.)
.r7_start
\ the row runs: one page per character row r: STA &4000+&200r+8k-8r,Y (Y = row) for byte
\ columns k = 1..63, then RTS
ALIGN &100
.r7_rrun
FOR r, 0, 23
  FOR k, 1, 63
    STA &4000 + r * &200 + k * 8 - r * 8, Y
  NEXT
  RTS
  ALIGN &100
NEXT
.r7_jr                    \ run offset of byte column x DIV 4 + 1 (the RTS); read
                          \ as r7_jr-4,X (x >= 4): the offset of column x DIV 4
FOR x, 0, 255
  EQUB LO(3 * (x DIV 4))
NEXT
.r7_j3                    \ run offset of byte column k (1..63)
FOR k, 0, 63
  EQUB LO(3 * (k - 1))
NEXT
.r7_rp                    \ run page of row y
FOR y, 0, 191
  EQUB HI(r7_rrun) + (y DIV 8)
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
  LDA r7_rp,Y
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
  LDA r7_rp,Y
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
\ r7_line: R_LINE for 8-bit end points (0..255), R_LINE's pixels (Bresenham
\ along the major axis from the left / top end).  Pointer RZ_PP (+ Y = row
\ AND 7), pixel mask l_m, colour by row AND 7 (r7_lct); X = row; DIRTY[b][row]
\ extended per pixel; the buffer's row range per line.  r7_line: both ends
\ inside the window.  r7_linec: otherwise; the pixels before the first one
\ inside the window are stepped over, and the loops stop at the first one
\ past it (the pixels inside are one run: x and y are monotonic).
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
l_k  = &22              \ kind (0..3)
l_c  = &23              \ 0: inside, 8: clipped

.r7_lct SKIP 8          \ colour byte by row AND 7
.r7_ldl EQUB HI(R_DIRTYL0), HI(R_DIRTYL1)
.r7_ldr EQUB HI(R_DIRTYR0), HI(R_DIRTYR1)
.r7_lbuf EQUB &FF       \ buffer the loops are patched for
.r7_cr1 EQUB 0          \ CR + 1
.r7_cb1 EQUB 0          \ CB + 1

.r7_lines                 \ prepared by bank 5's r_lc16 (r7_lp*)
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
  LDA r7_lpx
  STA l_x
  LDA r7_lpy
  STA l_y0
  LDA r7_lpe
  STA l_e
  LDA r7_lpa
  STA l_a
  LDA r7_lpb
  STA l_b
  LDA r7_lpn
  STA l_n
  LDA r7_lpk
  STA l_k
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
\ start: A = steps: l_n = A, l_e = (A DIV 2) - l_b, l_x = x0, the buffer's
\ dirty rows += y0..y1 (in the window)
.start
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
  JSR ab
  BCS no
  STA RZ_T4
  LDX #2
  JSR ab
  BCS no
  STA RZ_T5
  CMP RZ_T4
  BCC xm
  BEQ xm
  LDA RZ_T3               \ y major: from the top end
  BPL y1
  JSR swap
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
  JSR swap
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
  JSR mul
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
  JSR div
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
  JSR mul
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
  JSR div
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
  STA r7_lpx              \ y major: minor = x
  LDA c_t
  STA r7_lpy
  BRA s4
.sx
  STA r7_lpy
  LDA c_t
  STA r7_lpx
.s4
  LDA c_r
  SEC
  SBC c_d
  STA r7_lpe
  LDA c_a
  STA r7_lpa
  LDA c_d
  STA r7_lpb
  SEC
  SBC c_i
  INC A
  STA r7_lpn
  STX r7_lpk
  JSR r7_lines
  LDA #0
  RTS
\ ab: X = 0 / 2: |T(X), T(X+1)| -> A, C = 1 if >= 256
.ab
  LDA RZ_T1,X
  BMI abn
  BNE ab9
  LDA RZ_T0,X
  CLC
  RTS
.abn
  CMP #&FF
  BNE ab9
  LDA RZ_T0,X
  BEQ ab9                 \ (-256)
  EOR #&FF
  INC A
  CLC
  RTS
.ab9
  SEC
  RTS
\ mul: c_m0w = A * X
.mul
  STA c_op
  STX c_t+1
  STZ c_m0w
  STZ c_m0w+1
  LDX #8
.mu1
  ASL c_m0w
  ROL c_m0w+1
  ASL c_op
  BCC mu2
  LDA c_t+1
  CLC
  ADC c_m0w
  STA c_m0w
  BCC mu2
  INC c_m0w+1
.mu2
  DEX
  BNE mu1
  RTS
\ div: c_m0w = c_m0w DIV A, c_r = MOD (A >= 1)
.div
  STA c_op
  STZ c_r
  LDX #16
.dv1
  ASL c_m0w
  ROL c_m0w+1
  ROL c_r
  BCS dv2
  LDA c_r
  CMP c_op
  BCC dv3
.dv2
  LDA c_r
  SBC c_op
  STA c_r
  INC c_m0w
.dv3
  DEX
  BNE dv1
  RTS
.swap
  LDX #3
.sw1
  LDA R_X0,X
  LDY R_X1,X
  STA R_X1,X
  TYA
  STA R_X0,X
  DEX
  BPL sw1
  LDX #2                  \ the differences change sign
.sw2
  SEC
  LDA #0
  SBC RZ_T0,X
  STA RZ_T0,X
  LDA #0
  SBC RZ_T1,X
  STA RZ_T1,X
  DEX
  DEX
  BPL sw2
  RTS
}

.r7_end
PRINT "raster7.asm: ", r7_end - r7_start, " bytes"
