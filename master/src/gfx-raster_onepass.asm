\ ============================================================================
\ gfx-raster_onepass.asm -- PROTOTYPE (branch onepass): R_POLY's polygons as
\ a one-pass span generator.  The two chains are walked in lockstep, one row
\ at a time, and each row's span is handed on as soon as both ends are known:
\ no per-row edge tables (R_PTA/R_PTB), no orientation scan, no clip or trim
\ pass.  The per-row hand-off is the seam:
\
\     JSR emit  with  Y = row, X = xl (first pixel), A = xr + 1 (exclusive)
\
\ (fem/fem2's operand: the emitter must keep Y).  On the Master it would fill
\ the row (phase B's body); on the Tube the parasite would send the span to
\ the host instead.
\
\ R_SPANS: R_PN vertices in R_PXL/PXH/PYL/PYH, the clip window R_CL..R_CR,
\ R_CT..R_CB.  C = 1: not handled (some coordinate outside 0..255, or a
\ chain that is not monotone in y: R_POLY's two-phase path does those);
\ C = 0: done.  Runs with the polygon window (ANDY) paged, as R_POLY: the
\ edge set-up is R_POLY's own (r_e8, with r7_e8c's exact clipped start),
\ diverted at its DDA entries (r_pzl1, r_psh1: gfx-raster_poly.asm, under
\ ONEPASS) into fz / fsh here, which load the side's DDA instead of running
\ it down a table.  Pixel-exact: the same x = x0 + ceil(dx*k/dy) per row.
\
\ Per row (no clipping): the two DDAs (x and the error term in zero page,
\ a, b and dy as immediates patched per edge), the span's ends, an empty
\ test and the hand-off; one compare per row for the next edge change
\ (fseg, the nearer of the two edges' end rows).  The orientation is taken
\ as chain A on the left and swapped the first time a row says otherwise
\ (dswap), so the per-row work does not pay for a min/max.
\ ============================================================================

CPU 1                   \ (65C02: STZ, BRA)

f_x0 = &1C              \ side 0 (chain A, forward): x, error
f_t0 = &1D
f_x1 = &1E              \ side 1 (chain B, backward): x, error
f_t1 = &1F
fseg = &24              \ the row at which an edge (or the polygon) ends
ftmp = &25

\ (the rasteriser's zero page, as gfx-raster.asm has it: that is assembled
\ after this in the test, and forward zero-page symbols are not allowed)
oR_CL = &0A
oR_CR = &0B
oR_CT = &0C
oR_CB = &0D
oRZ_T0 = &20
oRZ_T1 = &21
oRZ_T2 = &22
oRZ_T3 = &23
oRZ_TA = &1A

.fdiv   EQUB 0          \ bit 7: r_e8's DDA entries divert here (fz, fsh)
.fside  EQUB 0          \ bit 7: the side being set up is side 1
.fcc    EQUB 0, 0       \ per side: edges left, current vertex, end row
.fcur   EQUB 0, 0
.fe     EQUB 0, 0
.frow   EQUB 0
.fprev  EQUB 0

{                         \ (the generator's own labels: fz, fsh and r_sp8b are its
                          \ entries from outside)

IF OPTUBE = FALSE          \ (the Tube's parasite: entered at r_sp8b from r_pf8,
.R_SPANS                   \ gfx-raster_poly.asm, which has done the set-up)
ENDIF
{
IF OPTUBE = FALSE
  LDA R_PN
  BNE p1
  CLC
  RTS
.p1
  CMP #17
  BCC p2
  LDA #16
.p2
  STA r_n
  TAX
  DEX
  LDA #0
.hl
  ORA R_PXH,X
  ORA R_PYH,X
  DEX
  BPL hl
  TAX
  BEQ p8
.no
  SEC                     \ not handled
  RTS
.none
  CLC                     \ no rows
  RTS
.p8                       \ as r_pf8: the top vertex, y range, clipping
  LDA oR_CR
  INC A
  STA r_cr1
  LDX r_n
  DEX
  STX r_top
  LDA R_PYL,X
  STA r_yminL
  STA r_ymaxL
  STZ r_xclip
.sc
  LDA R_PYL,X
  CMP r_yminL
  BCS s1
  STA r_yminL
  STX r_top
.s1
  CMP r_ymaxL
  BCC s2
  STA r_ymaxL
.s2
  LDA R_PXL,X
  CMP oR_CL
  BCC s3
  CMP r_cr1
  BCC s4
.s3
  INC r_xclip
.s4
  DEX
  BPL sc
  LDA r_yminL
  CMP oR_CT
  BCS y1
  LDA oR_CT
.y1
  STA r_ystart
  CMP r_ymaxL
  BCS none
  CMP oR_CB
  BEQ y2
  BCS none
.y2
  LDA r_ymaxL
  DEC A
  CMP oR_CB
  BCC y3
  LDA oR_CB
.y3
  STA r_ylast
  INC A
  STA r_yend
ENDIF
.*r_sp8b
  \ clipping in x: the row loop's branch
  LDA r_xclip
  BEQ c0
  LDA #dcl - (ck + 2)
.c0
  STA ck + 1
  \ chain A on the left until a row says otherwise
  LDA #f_x0
  STA dl + 1
  LDA #f_x1
  STA dc + 1
  STA dr + 1
  STA dr2 + 1
  \ the first edge of each chain: both start at ystart
  LDA r_n
  STA fcc
  STA fcc + 1
  LDA r_top
  STA fcur
  STA fcur + 1
  LDA #&80
  STA fdiv
  JSR fadv0               \ (each starts at ystart, RZ_T3, unless the polygon
  BCS out                 \ is not monotone in y)
  LDA oRZ_T3
  CMP r_ystart
  BNE out
  JSR fadv1
  BCS out
  LDA oRZ_T3
  CMP r_ystart
  BNE out
  LDA fe
  CMP fe + 1
  BCC f1
  LDA fe + 1
.f1
  STA fseg
  LDY r_ystart
  JMP drow
.out
  STZ fdiv
  CLC                     \ (a monotone polygon with rows has both)
  RTS
}

\ fadv0, fadv1: set up chain A's (forward) / chain B's (backward) next edge
\ that has rows (r_e8, its DDA entry diverted into fz / fsh); C = 1 if the chain has none
.fadv0
{
  STZ fside
.lp
  LDY fcur
  LDA R_PYL,Y
  CMP r_ymaxL
  BEQ fend
  DEC fcc
  BMI fend
  STY r_i0
  INY
  CPY r_n
  BCC nx
  LDY #0
.nx
  STY fcur
  STY r_i1
  TYA
  TAX                     \ (r_e8: X = r_i1, Y = r_i0 from r_i0)
  JSR r_e8                \ (returns here only if it had no rows)
  BRA lp
}
.fend
  SEC
  RTS
.fadv1
{
  LDA #&80
  STA fside
.lp
  LDY fcur + 1
  LDA R_PYL,Y
  CMP r_ymaxL
  BEQ fend
  DEC fcc + 1
  BMI fend
  STY r_i0
  DEY
  BPL nx
  LDY r_n
  DEY
.nx
  STY fcur + 1
  STY r_i1
  TYA
  TAX
  JSR r_e8
  BRA lp
}

\ fz, fsh: r_e8's edge, diverted at its DDA entry: start row RZ_T3, end row
\ RZ_T2 (exclusive), x RZ_T0, A = a; fsh also X = b, error RZ_TA, dy RZ_T1
\ (b = 0 for fz: x moves by a every row).  They load the side's DDA and
\ return from fadv0 / fadv1 with C = 0
.*fz
  STZ oRZ_TA
  LDX #0
.*fsh
  BIT fside
  BMI fsh1
.fsh0
  STA fa0 + 1             \ a (+1 with the borrow's carry)
  STA fn0 + 1             \ a
  STX fb0 + 1             \ b
  LDA oRZ_T1
  STA fd0 + 1             \ dy
  LDA oRZ_T0
  STA f_x0
  LDA oRZ_TA
  STA f_t0
  LDA oRZ_T2
  STA fe
  PLA                     \ (r_e8's return into fadv0)
  PLA
  CLC
  RTS
.fsh1
  STA fa1 + 1
  STA fn1 + 1
  STX fb1 + 1
  LDA oRZ_T1
  STA fd1 + 1
  LDA oRZ_T0
  STA f_x1
  LDA oRZ_TA
  STA f_t1
  LDA oRZ_T2
  STA fe + 1
  PLA
  PLA
  CLC
  RTS

\ the row loop: Y = row
.drow
.dl
  LDX f_x0                \ (patched: the left side's x)
.dc
  CPX f_x1                \ (patched: the right side's x)
  BEQ dempty
  BCS dswap
.ck
  BRA dnc                 \ (patched: to dcl when clipping in x)
.dnc
.dr
  LDA f_x1                \ (patched with dc)
.fem
IF OPTUBE
  JSR p_emit              \ Y = row, X = xl, A = xr + 1 (tube/src/p-emit.asm)
ELSE
  JSR f_emitnull          \ Y = row, X = xl, A = xr + 1
ENDIF
.dempty
  LDA f_t0                \ side 0: t -= b; borrow: t += dy, x += a + 1
  SEC
.fb0
  SBC #0
  BCS n0
.fd0
  ADC #0
  STA f_t0
  LDA f_x0
.fa0
  ADC #0                  \ (C = 1)
  STA f_x0
  BRA st1
.n0
  STA f_t0
  LDA f_x0
  CLC
.fn0
  ADC #0
  STA f_x0
.st1
  LDA f_t1                \ side 1, the same
  SEC
.fb1
  SBC #0
  BCS n1
.fd1
  ADC #0
  STA f_t1
  LDA f_x1
.fa1
  ADC #0
  STA f_x1
  BRA st2
.n1
  STA f_t1
  LDA f_x1
  CLC
.fn1
  ADC #0
  STA f_x1
.st2
  INY
  CPY fseg
  BCC drow
  JMP fnext
.dswap                    \ the right side was the left: swap them, redo the row
  LDA dl + 1
  LDX dc + 1
  STA dc + 1
  STA dr + 1
  STA dr2 + 1
  STX dl + 1
  JMP drow
.dcl                      \ clipping in x: X = xl
  CPX oR_CL
  BCS cl1
  LDX oR_CL
.cl1
.dr2
  LDA f_x1                \ (patched with dc)
  CMP r_cr1
  BCC cl2
  LDA r_cr1
.cl2
  STA ftmp
  CPX ftmp
  BCS dempty
.fem2
IF OPTUBE
  JSR p_emit
ELSE
  JSR f_emitnull          \ (patched with fem)
ENDIF
  JMP dempty

\ fnext: Y = fseg: the polygon's end, or a side's next edge (which starts
\ there: the polygon is monotone)
.fnext
{
  CPY r_yend
  BCS done
  STY frow
  CPY fe
  BNE n1
  JSR fadv0
  BCS done
  LDA oRZ_T3              \ (the next edge starts here unless the polygon is
  CMP frow                \ not monotone in y: then stop)
  BNE done
.n1
  LDA fe + 1
  CMP frow
  BNE n2
  JSR fadv1
  BCS done
  LDA oRZ_T3
  CMP frow
  BNE done
.n2
  LDA fe
  CMP fe + 1
  BCC n3
  LDA fe + 1
.n3
  STA fseg
  LDY frow
  JMP drow
.done
  STZ fdiv
  CLC
  RTS
}

IF OPTUBE = FALSE
.f_emitnull
  RTS
ENDIF

}

ASSERT oR_CL = R_CL AND oR_CR = R_CR AND oR_CT = R_CT AND oR_CB = R_CB AND oRZ_T0 = RZ_T0 AND oRZ_T1 = RZ_T1 AND oRZ_T2 = RZ_T2 AND oRZ_T3 = RZ_T3 AND oRZ_TA = RZ_TA
