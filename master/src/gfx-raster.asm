\ ============================================================================
\ raster.asm -- filled-polygon / disc-layer / line / dot / star rasteriser for
\ the double-buffered CMYK MODE 1 Elite (BBC Master, 65C02).  See
\ docs/DESIGN.md for the screen layout and the frame model.
\
\ Four files: raster_vars.asm holds every variable and array the caller
\ reads or writes (and state shared by the two banks; assemble it anywhere
\ both sides can see, e.g. HAZEL &C000-&DFFF; no alignment); raster_hz.asm
\ holds two cross-bank call stubs (code: HAZEL, inside the copied region);
\ this file holds the code, tables and private state (INCLUDE it at &8000
\ in sideways bank 5, R_BANK_MAIN; it ALIGNs itself to a page, so another
\ start costs up to 255 bytes); raster7.asm is bank 7 (R_BANK_AUX): cold
\ code, paged in by the stubs (R_INIT, R_CLEARALL, R_RESETBUF).  The caller
\ only ever calls this file's entry points with bank 5 paged; they return
\ with bank 5 paged.  It references
\ no Elite symbol; all labels start with r_ / R_ / RZ_.  CPU 1 is selected.
\ The store runs are self-modified (an RTS is planted and removed again), so
\ it must run from RAM.
\
\ ---------------------------------------------------------------- zero page
\ &06-&27 are used (the caller saves/restores them around rendering).
\   R_COLE, R_COLO  fill colour pair: byte for even rows, byte for odd rows
\   R_XL, R_XR      span ends for R_SPAN / R_MARKDIRTY (inclusive pixels)
\   R_CL, R_CR      clip window x min/max (inclusive). 1 <= CL <= CR <= 254
\   R_CT, R_CB      clip window y min/max (inclusive). 0 <= CT <= CB <= 191
\   R_DCE, R_DCO    disc colour pair (R_DISCROWS)
\   everything else in &10-&27 is internal scratch (RZ_*), clobbered by calls.
\ The clip window should stay constant from frame to frame; R_CLEARALL (or
\ black the window and R_RESETBUF) both buffers after changing it.
\
\ ---------------------------------------------------------------- variables
\ (raster_vars.asm; empty span: L = 255, R = 0; for R_WL/R_WR, R = 0)
\   R_PN               polygon vertex count (1..16; more are ignored)
\   R_PXL/R_PXH/R_PYL/R_PYH  16-entry vertex arrays (signed 16-bit, y down)
\   R_X0,R_Y0,R_X1,R_Y1      line end points, signed 16-bit words (lo, hi)
\   R_SN               star count (0..24)
\   R_SX,R_SY,R_SS     24-entry star arrays: x, y (8-bit), size 1..3 (0: none)
\   R_SCOL             star colour byte (R_INIT sets &FF = logical colour 3)
\   R_NDT, R_NDB       new disc rows for R_DISCROWS (NDT > NDB: no disc)
\   R_NDISCL/R_NDISCR  new disc spans (rows NDT..NDB only) [192 each]
\   R_DIRTYL0/R0, R_DIRTYL1/R1  per-buffer dirty extents  [192 each]
\   R_DISCL0/R0,  R_DISCL1/R1   per-buffer disc spans     [192 each]
\   R_WL, R_WR         this frame's written extents (see R_DISCROWS) [192]
\   R_NDF              0: this frame's disc is plain colour A (the arrays
\                      below are ignored); else each disc row has:
\   R_NDN              boundaries in the row, 0..4                 [192]
\   R_NDX0..R_NDX3     their x, ascending, inside (NDISCL, NDISCR]: pixels
\                      >= x take the other colour (flips at or left of
\                      NDISCL are folded into R_NDP by the caller)   [192]
\   R_NDP              bit 0: colour at the span's left end before any
\                      flip (0 = A = R_DCE/R_DCO, 1 = B = R_DBE/R_DBO) [192]
\   R_DBE, R_DBO       colour B pair
\   (R_PTA/R_PTB, R_BD*: private to this file.)
\ Coordinates passed to R_POLY / R_LINE must lie in -16384..16383.
\
\ ---------------------------------------------------------------- routines
\ Registers A, X, Y are not preserved unless stated.  Decimal mode must be off.
\
\ R_INIT       once at startup: clip window = 1..254 x 1..191, R_SCOL = &FF,
\              all per-buffer state empty, R_SETBUF 0.  Does not touch the
\              screen: follow with R_CLEARALL (or R_RESETBUF on a black
\              window) for each buffer.
\ R_SETBUF     A = buffer 0/1 whose state arrays (dirty, disc, stars) the
\              following calls use.  Call it before drawing each frame.  It
\              self-modifies the code: ~85 operand high bytes are stored
\              (~400 cycles) when the buffer changes.
\ R_RESETBUF   forget the current buffer's state (no dirty, no disc, no
\              stars) without touching the screen; the caller guarantees the
\              buffer's clip window is black.  ~5000 cycles.  No R_INIT needed.
\ R_CLEARALL   black the whole clip window and R_RESETBUF (~115000 cycles).
\ R_SPAN       Y = row, fill pixels R_XL..R_XR (within the clip window, XL<=XR)
\              with the colour pair.  Pure drawing: no state is updated.
\              Pass R_COLE = R_COLO = 0 for black.
\ R_POLY       filled convex polygon (R_PN, R_PXL..R_PYH, colour pair), either
\              winding.  Pixel (x,y) (centre at integer x,y) is filled when it
\              is inside, using a top-left rule: rows y0 <= y < y1 of each
\              edge, pixels ceil(xleft) <= x < ceil(xright), exact integer
\              edge stepping from the upper end point, so polygons sharing an
\              edge tile with no gaps or overlaps.  Clipped to the window.
\              Extends DIRTY of the current buffer.  Fast path when every
\              coordinate is 0..255.
\ R_LINE       1-pixel line R_X0,R_Y0 - R_X1,R_Y1 (inclusive), clipped; pixel
\              colour = the dither at its position.  Bresenham along the major
\              axis stepped in the increasing direction; minor coordinate =
\              round-half-up.  Extends DIRTY.  Fast path when both ends are
\              inside the window.
\ R_DOT        X = x, Y = y, A = size: 1 = 1x1, 2 = 2x1, 3 = 2x2 (right/down).
\              Clipped.  Extends DIRTY.
\ R_STARERASE  black every star pixel R_STARPLOT set last time in this buffer.
\ R_STARPLOT   plot stars R_SX/SY/SS (R_SN of them) in R_SCOL.  A star row's
\              pixels within one screen byte are set only if all of them are
\              black there (else that byte is left alone); remembered for
\              R_STARERASE.  It must be the frame's last drawing (after the
\              text overlay): stars then only ever replace black that stays
\              black, so neither plotting nor erasing them touches R_WL/R_WR.
\ R_DISCROWS   the incremental disc layer for the current buffer (see below).
\ R_MARKDIRTY  Y = row, extend this buffer's DIRTY[y] by R_XL..R_XR (use it
\              for anything else drawn into the buffer, e.g. text, so the next
\              R_DISCROWS on this buffer repairs it).
\ R_WMERGE     fold DIRTY of the current buffer into R_WL/R_WR (optional).
\
\ Frame order for buffer b:  R_SETBUF b; R_STARERASE; (fill R_NDISC*, R_NDT,
\ R_NDB, R_DCE/R_DCO) R_DISCROWS; R_POLY/R_LINE/R_DOT ...; text; R_STARPLOT.
\
\ R_DISCROWS first hands the dirty rows that are neither old nor new disc rows
\ to bank 7 (r7_crep): those rows hold only shapes over black there (text
\ cells under them are redrawn through R_WL/R_WR), so
\ the extent is widened to whole bytes and blacked by one row run, R_WL/R_WR
\ set to it; the row loop below then only visits the disc rows.
\ R_DISCROWS, per row y of the clip window: writes the disc colour on the new
\ span minus the intact part of the old one (old span minus old dirty) and
\ black on (old span + old dirty) minus the new span; then DISC[b][y] = new,
\ DIRTY[b][y] = empty.  Where the old disc is intact and an end moves, the
\ bytes between the old and new end are rewritten whole (black / disc / disc
\ from the new end on): pixels outside the disc there are black anyway.  It
\ also starts the frame's R_WL/R_WR (clearing last frame's rows): afterwards
\ they hold, per row, the extent of the disc-layer writes (and of the
\ dirty repair).  Shapes are NOT added to R_WL/R_WR: what was written this
\ frame is R_WL/R_WR[y] union DIRTY[b][y] (or call R_WMERGE at the end).
\ Rows of R_NDISCL/R in NDT..NDB with NDISCL = 255 (or L > R) are empty;
\ spans are clamped to the clip window.
\ Two-colour discs (R_NDF <> 0): pixel x of a disc row has colour R_NDP
\ EOR (the number of its boundaries <= x).  Each buffer remembers its rows'
\ boundaries.  A changed row with no dirty extent is a list of edges (span
\ start, flips, span end + 1), each with an old and a new position; a flip
\ that crossed an end is matched by a virtual one there.  When the strips
\ between each edge's positions are in order, only they are written (r_dq
\ if only boundaries moved, else r_dpe); otherwise, and for rows with a
\ dirty extent, the row is repainted whole (r_drg).  New spans are clamped to the clip window; pass
\ them already clamped (with flips at or left of NDISCL folded into R_NDP)
\ so unchanged rows are recognised by the cheap comparison.  A change of
\ the colours A/B must be handled by the caller as now: fold the old disc
\ into DIRTY (R_MARKDIRTY) first.
\ ============================================================================

CPU 1

R_COLE  = &06
R_COLO  = &07
R_XL    = &08
R_XR    = &09
R_CL    = &0A
R_CR    = &0B
R_CT    = &0C
R_CB    = &0D
R_DCE   = &0E
R_DCO   = &0F
RZ_PA   = &10           \ (lo = y AND 7, hi = row page)  bytes of columns 0..31
RZ_PB   = &12           \ (lo = y AND 7, hi = row page+1) columns 32..63
RZ_PP   = &14           \ RTS plant pointer / pixel pointer
RZ_COL  = &16           \ this row's colour byte
RZ_Y    = &17           \ current row
RZ_SA   = &18           \ edge A: x (16)            } side 0 (offset 0)
RZ_TA   = &1A           \ edge A: error term (16)   }
RZ_SB   = &1C           \ edge B: x (16)            } side 1 (offset 4)
RZ_TB   = &1E           \ edge B: error term (16)   }
RZ_T0   = &20
RZ_T1   = &21
RZ_T2   = &22
RZ_T3   = &23
RZ_T4   = &24
RZ_T5   = &25
RZ_T6   = &26
RZ_T7   = &27

r_opSTA = &9D           \ STA abs,X
r_opRTS = &60

\ ============================================================================
\ Page-aligned per-x tables
\ ============================================================================
ALIGN &100
.r_start
.r_xo                   \ (8 * (x DIV 4)) AND &FF : edge byte offset
FOR x, 0, 255
  EQUB (x * 2) AND &F8
NEXT
.r_j                    \ 3 * (x DIV 4): run entry offset (column x DIV 4 + 1)
FOR x, 0, 255
  EQUB 3 * (x DIV 4)
NEXT
.r_lm                   \ pixels (x AND 3)..3 of a byte
FOR x, 0, 255
  EQUB ((&F0 >> (x AND 3)) AND &F0) OR (&0F >> (x AND 3))
NEXT
.r_rm                   \ pixels 0..(x AND 3) of a byte
FOR x, 0, 255
  EQUB ((&F0 << (3 - (x AND 3))) AND &F0) OR ((&0F << (3 - (x AND 3))) AND &0F)
NEXT

\ ============================================================================
\ The store runs: one page per character row r (24), STA &4000+&200r+8c,X for
\ c = 1..63 then RTS (190 bytes).  The 66 bytes after each run hold variables.
\ ============================================================================
MACRO R_RUN r
  FOR c, 1, 63
    STA &4000 + r * &200 + c * 8, X
  NEXT
  RTS
  EQUB 0                  \ spare: the 'nothing planted' target (offset 190)
ENDMACRO

MACRO R_ENDPAGE r
  ASSERT P% <= r_run0 + (r + 1) * &100
  ALIGN &100
ENDMACRO

.r_run0 R_RUN 0
.r_s0y SKIP 48          \ star records, buffer 0: row
.r_dsz EQUB 0           \ R_DOT
.r_dx EQUB 0
.r_dy EQUB 0
.r_k EQUB 0             \ stars
.r_si EQUB 0
R_ENDPAGE 0
.r_run1 R_RUN 1
.r_s0x SKIP 48          \ buffer 0: x of first pixel
R_ENDPAGE 1
.r_run2 R_RUN 2
.r_s0a SKIP 48          \ buffer 0: mask set in column x DIV 4
R_ENDPAGE 2
.r_run3 R_RUN 3
.r_s1y SKIP 48          \ buffer 1 (= buffer 0 + &300)
R_ENDPAGE 3
.r_run4 R_RUN 4
.r_s1x SKIP 48
R_ENDPAGE 4
.r_run5 R_RUN 5
.r_s1a SKIP 48
R_ENDPAGE 5
.r_run6 R_RUN 6
.r_s0b SKIP 48          \ buffer 0: mask set in column x DIV 4 + 1
R_ENDPAGE 6
.r_run7 R_RUN 7
.r_s0r SKIP 48          \ star records, buffer 0: row
R_ENDPAGE 7
.r_run8 R_RUN 8
.r_s1r SKIP 48          \ buffer 1: row
.r_m0 EQUB 0            \ 32-bit dividend / product; quotient m0,m1
.r_m1 EQUB 0
.r_m2 EQUB 0            \ remainder m2,m3
.r_m3 EQUB 0
.r_v0 EQUB 0            \ divisor
.r_v1 EQUB 0
.r_ma EQUW 0            \ multiplicand
.r_mb EQUW 0            \ multiplier
.r_sbd EQUB 0           \ R_SETBUF delta
R_ENDPAGE 8
.r_run9 R_RUN 9
.r_s1b SKIP 48
R_ENDPAGE 9
.r_run10 R_RUN 10
.r_cx EQUB 0            \ COLE EOR COLO
.r_cr1 EQUB 0           \ CR + 1
.r_cb1 EQUB 0           \ CB + 1
.r_n EQUB 0
.r_slow EQUB 0
.r_sbbdb EQUB &FF       \ buffer r_dbm's operands are patched for
.r_dsub EQUB 0          \ r_dmb -> r_drg: repaint only the dirty part
.r_side EQUB 0
.r_side4 EQUB 0
.r_i0 EQUB 0
.r_i1 EQUB 0
.r_yminL EQUB 0
.r_yminH EQUB 0
.r_ymaxL EQUB 0
.r_ymaxH EQUB 0
.r_ystart EQUB 0
.r_top EQUB 0
.r_ylast EQUB 0
.r_yend EQUB 0
.r_xclip EQUB 0
.r_bon EQUB 0           \ R_DISCROWS: this frame uses boundaries
.r_cc EQUB 0
.r_cidx EQUB 0, 0
.r_ccnt EQUB 0, 0
.r_cend EQUB 0, 0
R_ENDPAGE 10
.r_run11 R_RUN 11
.r_ov SKIP 59           \ variables of routines never active together
R_ENDPAGE 11
.r_run12 R_RUN 12
.r_s1k SKIP 48          \ buffer 1: star's first pixel
R_ENDPAGE 12
\ overlay: edge set-up (r_eset)
r_edy = r_ov + 0
r_ek0 = r_ov + 2
r_ex0 = r_ov + 4
r_eadx = r_ov + 6
r_eneg = r_ov + 8
r_eq = r_ov + 9
r_er = r_ov + 11
r_ea = r_ov + 13
r_eb = r_ov + 15
\ overlay: R_DISCROWS rows
r_nt = R_PRNT           \ (HAZEL: bank 7's r7_crep reads them)
r_nb = R_PRNB
r_lo = R_PRLO
r_hi = R_PRHI
r_oL = r_ov + 4
r_oR = r_ov + 5
r_dL = r_ov + 6
r_dR = r_ov + 7
r_nL = r_ov + 8
r_nR = r_ov + 9
r_iL = r_ov + 10
r_iR = r_ov + 11
r_wmin = r_ov + 12
r_wmax = r_ov + 13
r_dcol = r_ov + 14
r_ba = r_ov + 15
r_bb = r_ov + 16
r_tl = r_ov + 17
r_dya = R_PRDYA
r_dyz = R_PRDYZ
r_fe = r_ov + 20
r_fo = r_ov + 21
r_bv = r_ov + 22        \ boundaries: new (4), then old (4) at r_bv+4
r_ev = r_ov + 45        \ r_dpe: edges new (7), then old (7) at r_ev+7
r_nn = r_ov + 30        \ new count / colour; old count / colour
r_np = r_ov + 31
r_on = r_ov + 32
r_op = r_ov + 33
r_ns = r_ov + 34        \ strips to write (r_dp2)
r_cA = r_ov + 35        \ this row's colour A, B bytes
r_cB = r_ov + 36
r_dcr = r_ov + 37       \ r_dp2: right end colour
r_segs = r_ov + 38      \ r_drg: repaint the new span segment by segment
r_cl = r_ov + 39        \ r_canon: span, count in
r_cr = r_ov + 40
r_cn = r_ov + 41
\ overlay: R_LINE
r_lxm = r_ov + 0
r_maj0 = r_ov + 1
r_min0 = r_ov + 3
r_dmaj = r_ov + 5
r_admin = r_ov + 7
r_smin = r_ov + 9
r_wlo = r_ov + 10
r_whi = r_ov + 11
r_vlo = r_ov + 12
r_vhi = r_ov + 13
r_ilo = r_ov + 14
r_ihi = r_ov + 16
r_err = r_ov + 18
r_e2maj = r_ov + 20
r_e2min = r_ov + 22
r_cmaj = r_ov + 24
r_cmin = r_ov + 25
r_lcnt = r_ov + 27
.r_run13 R_RUN 13
.r_s0k SKIP 48          \ buffer 0: star's first pixel
R_ENDPAGE 13
.r_run14 R_RUN 14
.r_addr
  TYA
  AND #7
  ORA r_xo,X
  STA RZ_PP
  TYA
  LSR A
  LSR A
  AND #&FE
  ORA #&40
  CPX #&80
  ADC #0
  STA RZ_PP+1
  RTS
.r_pclip
{
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
  JSR r_pset
  JMP r_cyrow
.out
  RTS
}
R_ENDPAGE 14
.r_run15 R_RUN 15
.r_pset
{
  JSR r_addr
  LDA r_lm,X
  AND r_rm,X
  STA RZ_T6
  TYA
  LSR A
  LDA R_COLE
  BCC ev
  LDA R_COLO
.ev
  EOR (RZ_PP)
  AND RZ_T6
  EOR (RZ_PP)
  STA (RZ_PP)
  TXA
.^r_pt01 CMP r_dl,Y
  BCS n1
.^r_pt02 STA r_dl,Y
.n1
.^r_pt03 CMP r_dr,Y
  BCC n2
.^r_pt04 STA r_dr,Y
.n2
  RTS
}
R_ENDPAGE 15
.r_run16 R_RUN 16
.r_cyrow
{
  PHX
  LDX r_buf
  TYA
  CMP r_dyt,X
  BCS n3
  STA r_dyt,X
.n3
  CMP r_dyb,X
  BCC n4
  STA r_dyb,X
.n4
  PLX
  RTS
}
.R_SPAN
{
  LDA R_XR
  CMP R_XL
  BCC out
  JSR r_rowset
  TYA
  LSR A
  LDA R_COLE
  BCC ev
  LDA R_COLO
.ev
  STA RZ_COL
  LDX R_XL
  JMP r_spc
.out
  RTS
}
R_ENDPAGE 16
.r_run17 R_RUN 17
.R_DOT
{
  STA r_dsz
  STX r_dx
  STY r_dy
  JSR r_pclip
  LDA r_dsz
  CMP #2
  BCC done
  LDX r_dx
  INX
  BEQ row2
  LDY r_dy
  JSR r_pclip
.row2
  LDA r_dsz
  CMP #3
  BCC done
  LDY r_dy
  INY
  BEQ done
  LDX r_dx
  JSR r_pclip
  LDX r_dx
  INX
  BEQ done
  JSR r_pclip
.done
  RTS
}
R_ENDPAGE 17
.r_run18 R_RUN 18
.R_MARKDIRTY
{
  LDA R_XL
.^r_pt05 CMP r_dl,Y
  BCS n1
.^r_pt06 STA r_dl,Y
.n1
  LDA R_XR
.^r_pt07 CMP r_dr,Y
  BCC n2
.^r_pt08 STA r_dr,Y
.n2
  LDX r_buf
  TYA
  CMP r_dyt,X
  BCS n3
  STA r_dyt,X
.n3
  CMP r_dyb,X
  BCC n4
  STA r_dyb,X
.n4
  RTS
}
.R_WMERGE                 \ (bank 7: r7_wmerge)
  LDX #LO(r7_wmerge)
  BRA r_c7
.r_c7                     \ X = low byte of a bank-7 routine in page HI(r7_wmerge)
  TXA
  LDX #HI(r7_wmerge)
.r_c7x                    \ A, X = bank-7 routine (low, high)
  STA r_hzt7
  STX r_hzt7+1
  JMP r_call7
R_ENDPAGE 18
.r_run19 R_RUN 19
.r_div32
{
  LDX #16
.lp
  ASL r_m0
  ROL r_m1
  ROL r_m2
  ROL r_m3
  BCS sb
  LDA r_m2
  CMP r_v0
  LDA r_m3
  SBC r_v1
  BCC ns
.sb
  LDA r_m2
  SBC r_v0
  STA r_m2
  LDA r_m3
  SBC r_v1
  STA r_m3
  INC r_m0
.ns
  DEX
  BNE lp
  RTS
}
R_ENDPAGE 19
.r_run20 R_RUN 20
.r_mul16
{
  LDA #0
  STA r_m2
  STA r_m3
  LDX #16
.lp
  LSR r_mb+1
  ROR r_mb
  BCC ns
  CLC
  LDA r_m2
  ADC r_ma
  STA r_m2
  LDA r_m3
  ADC r_ma+1
  STA r_m3
.ns
  ROR r_m3
  ROR r_m2
  ROR r_m1
  ROR r_m0
  DEX
  BNE lp
  RTS
}
R_ENDPAGE 20
.r_run21 R_RUN 21
.r_dp1
{
  JSR r_rowset
  STZ RZ_COL
.^r_pt46 LDA r_dl,Y
  STA R_XL
  STA R_WL,Y
.^r_pt47 LDA r_dr,Y
  STA R_XR
  STA R_WR,Y
  LDA #&FF
.^r_pt48 STA r_dl,Y
  LDA #0
.^r_pt49 STA r_dr,Y
  CPY r_wt
  BCS w1
  STY r_wt
.w1
  CPY r_wb
  BCC w2
  STY r_wb
.w2
  LDX R_XL
  JMP r_spc
}
R_ENDPAGE 21
.r_run22 R_RUN 22
.r_wlu
{
  STA RZ_T0
  LDA R_WR,Y
  BNE ne
  LDA RZ_T0
  STA R_WL,Y
  TXA
  STA R_WR,Y
  BRA rg
.ne
  LDA RZ_T0
  CMP R_WL,Y
  BCS u1
  STA R_WL,Y
.u1
  TXA
  CMP R_WR,Y
  BCC rg
  STA R_WR,Y
.rg
  CPY r_wt
  BCS u2
  STY r_wt
.u2
  CPY r_wb
  BCC u3
  STY r_wb
.u3
  RTS
}
R_ENDPAGE 22
.r_run23 R_RUN 23
.r_crep5                  \ R_DISCROWS: r7_crep (returns X = r_buf)
  STZ R_PRCWB
  LDA r_dyz
  CMP r_dya
  BCC c4                  \ (no dirty rows)
  LDX #LO(r7_crep)
  JSR r_c7
.c4
  LDX r_buf
  RTS
.r_cwb5                   \ R_DISCROWS: the repair's rows into r_wt..r_wb
  LDA R_PRCWB             \ (the disc rows' code assumes rows go upwards)
  CMP r_wb
  BCC c5
  STA r_wb
.c5
  RTS
R_ENDPAGE 23

ASSERT r_s1y = r_s0y + &300 AND r_s1x = r_s0x + &300
ASSERT r_s1a = r_s0a + &300 AND r_s1b = r_s0b + &300

\ ============================================================================
\ Per-buffer row arrays: buffer 1's are buffer 0's + &300 (R_SETBUF adds 3 to
\ the high byte of every patched operand).
\ ============================================================================
r_ta = R_PTA            \ polygon edge tables (raster_vars)
r_tb = R_PTB

\ the API arrays live in raster_vars.asm, and so does the state both banks
\ (5 and 7) need
r_buf = R_PRBUF         \ current buffer
r_dyt = R_PRDYT         \ per buffer: rows that may have a dirty extent
r_dyb = R_PRDYB
r_dst = R_PRDST         \ per buffer: rows of its disc
r_dsb = R_PRDSB
r_scnt = R_PRSCNT       \ per buffer: star records
r_ecnt = R_PRECNT       \ per buffer: star records erased, not yet in WL
r_wt = R_PRWT           \ rows of WL/WR that may be non-empty
r_wb = R_PRWB
r_bmode = R_PRBMODE     \ per buffer: its rows may hold boundaries
r_dl = R_DIRTYL0
r_dr = R_DIRTYR0
r_sl = R_DISCL0
r_sr = R_DISCR0
r_dl1 = R_DIRTYL1
r_dr1 = R_DIRTYR1
r_sl1 = R_DISCL1
r_sr1 = R_DISCR1
r_bdn = R_BDN0          \ per-buffer boundary rows (patched like r_dl)
r_bdp = R_BDP0
r_bdx0 = R_BDX00
r_bdx1 = R_BDX10
r_bdx2 = R_BDX20
r_bdx3 = R_BDX30

\ ============================================================================
\ R_SETBUF: A = buffer.  Patches every buffer-dependent operand (high byte).
\ ============================================================================
.R_SETBUF
{
  AND #1
  CMP r_buf
  BNE go
  RTS
.go
  STA r_buf
  TAX
  LDA r_sbh_dl,X          \ group r_dl
  STA r_pt408+2
  STA r_pt409+2
  STA r_pt01+2
  STA r_pt02+2
  STA r_pt05+2
  STA r_pt06+2
  STA r_pt19+2
  STA r_pt23+2
  STA r_pt25+2
  STA r_pt46+2
  STA r_pt48+2
  STA r_pt60+2
  STA r_pt410+2
  STA r_pt61+2
  STA r_pt411+2
  STA r_pt88+2
  LDA r_sbh_dr,X          \ group r_dr
  STA r_pt03+2
  STA r_pt04+2
  STA r_pt07+2
  STA r_pt08+2
  STA r_pt20+2
  STA r_pt24+2
  STA r_pt47+2
  STA r_pt49+2
  STA r_pt62+2
  STA r_pt412+2
  STA r_pt63+2
  STA r_pt413+2
  LDA r_sbh_s0a,X          \ group r_s0a
  STA r_pt32+2
  STA r_pt36+2
  STA r_pt416+2
  STA r_pt418+2
  LDA r_sbh_s0b,X          \ group r_s0b
  STA r_pt33+2
  STA r_pt37+2
  LDA r_sbh_s0x,X          \ group r_s0x
  STA r_pt31+2
  STA r_pt35+2
  STA r_pt415+2
  LDA r_sbh_s0y,X          \ group r_s0y
  STA r_pt30+2
  STA r_pt34+2
  STA r_pt414+2
  LDA r_sbh_sl,X          \ group r_sl
  STA r_pt17+2
  STA r_pt21+2
  STA r_pt26+2
  STA r_pt45+2
  STA r_pt50+2
  STA r_pt53+2
  STA r_pt54+2
  STA r_pt89+2
  STA r_pt97+2
  STA r_pt131+2
  STA r_pt132+2
  STA r_pt144+2
  STA r_pt150+2
  STA r_pt152+2
  STA r_pt399+2
  LDA r_sbh_sr,X          \ group r_sr
  STA r_pt18+2
  STA r_pt22+2
  STA r_pt27+2
  STA r_pt51+2
  STA r_pt52+2
  STA r_pt55+2
  STA r_pt90+2
  STA r_pt133+2
  STA r_pt140+2
  STA r_pt145+2
  STA r_pt151+2
  STA r_pt153+2
  RTS
}
.r_sbh_dl EQUB HI(R_DIRTYL0), HI(R_DIRTYL1)
ASSERT LO(R_DIRTYL0) = LO(R_DIRTYL1)
.r_sbh_dr EQUB HI(R_DIRTYR0), HI(R_DIRTYR1)
ASSERT LO(R_DIRTYR0) = LO(R_DIRTYR1)
.r_sbh_s0a EQUB HI(r_s0a), HI(r_s1a)
ASSERT LO(r_s0a) = LO(r_s1a)
.r_sbh_s0x EQUB HI(r_s0x), HI(r_s1x)
ASSERT LO(r_s0x) = LO(r_s1x)
.r_sbh_s0y EQUB HI(r_s0y), HI(r_s1y)
ASSERT LO(r_s0y) = LO(r_s1y)
.r_sbh_sl EQUB HI(R_DISCL0), HI(R_DISCL1)
.r_sbh_s0k EQUB HI(r_s0k), HI(r_s1k)
ASSERT LO(r_s0k) = LO(r_s1k)
.r_sbh_s0r EQUB HI(r_s0r), HI(r_s1r)
ASSERT LO(r_s0r) = LO(r_s1r)
.r_sbh_s0b EQUB HI(r_s0b), HI(r_s1b)
ASSERT LO(r_s0b) = LO(r_s1b)
.r_sbh_bdx3 EQUB HI(R_BDX30), HI(R_BDX31)
ASSERT LO(R_BDX30) = LO(R_BDX31)
.r_sbh_bdx2 EQUB HI(R_BDX20), HI(R_BDX21)
ASSERT LO(R_BDX20) = LO(R_BDX21)
.r_sbh_bdx1 EQUB HI(R_BDX10), HI(R_BDX11)
ASSERT LO(R_BDX10) = LO(R_BDX11)
.r_sbh_bdx0 EQUB HI(R_BDX00), HI(R_BDX01)
ASSERT LO(R_BDX00) = LO(R_BDX01)
.r_sbh_bdp EQUB HI(R_BDP0), HI(R_BDP1)
ASSERT LO(R_BDP0) = LO(R_BDP1)
.r_sbh_bdn EQUB HI(R_BDN0), HI(R_BDN1)
ASSERT LO(R_BDN0) = LO(R_BDN1)
ASSERT LO(R_DISCL0) = LO(R_DISCL1)
.r_sbh_sr EQUB HI(R_DISCR0), HI(R_DISCR1)
ASSERT LO(R_DISCR0) = LO(R_DISCR1)

\ ============================================================================
\ Row set-up.  Y = row (0..191; kept).  Sets RZ_Y, RZ_PA, RZ_PB, the run page
\ (RZ_PP+1 and r_jsr+2).  Clobbers A.
\ ============================================================================
.r_rowset
  STY RZ_Y
  TYA
  AND #7
  STA RZ_PA
  STA RZ_PB
  TYA
  LSR A
  LSR A
  AND #&FE
  ORA #&40
  STA RZ_PA+1
  INC A
  STA RZ_PB+1
  TYA
  LSR A
  LSR A
  LSR A
  CLC
  ADC #HI(r_run0)
  STA RZ_PP+1
  STA r_jsr+2
  RTS

\ ============================================================================
\ r_spc: the span core.  Row set up (r_rowset), RZ_COL = colour byte,
\ X = R_XL = left pixel, R_XR = right pixel, R_XL <= R_XR.  Clobbers A, X, Y,
\ RZ_T7, RZ_PP.
\ ============================================================================
.r_spc
{
  TXA
  EOR R_XR
  CMP #4
  BCC one                 \ both ends in one byte
  LDY r_xo,X
  CPX #&80
  BCC la
  LDA (RZ_PB),Y           \ left edge, columns 32..63
  EOR RZ_COL
  AND r_lm,X
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
  BRA run
.la
  LDA (RZ_PA),Y           \ left edge, columns 0..31
  EOR RZ_COL
  AND r_lm,X
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
.run
  LDA r_j,X               \ entry: column xl DIV 4 + 1
  STA r_jsr+1
  LDX R_XR
  LDA r_j-4,X             \ plant: column xr DIV 4
  CMP r_jsr+1
  BEQ norun
  STA RZ_PP
  LDA #r_opRTS
  STA (RZ_PP)
  LDX RZ_PA
  LDA RZ_COL
.^r_jsr
  JSR &FFFF
  LDA #r_opSTA
  STA (RZ_PP)
  LDX R_XR
.norun
  LDY r_xo,X              \ right edge
  CPX #&80
  BCS rb
  LDA (RZ_PA),Y
  EOR RZ_COL
  AND r_rm,X
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
  RTS
.rb
  LDA (RZ_PB),Y
  EOR RZ_COL
  AND r_rm,X
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
  RTS
.one
  LDY r_xo,X
  LDA r_lm,X
  LDX R_XR
  AND r_rm,X
  STA RZ_T7
  CPX #&80
  BCS ob
  LDA (RZ_PA),Y
  EOR RZ_COL
  AND RZ_T7
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
  RTS
.ob
  LDA (RZ_PB),Y
  EOR RZ_COL
  AND RZ_T7
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
  RTS
}

\ ============================================================================
\ R_SPAN: Y = row, R_XL..R_XR, colour pair R_COLE/R_COLO.
\ ============================================================================

\ ============================================================================
\ Pixel address: X = x, Y = y -> RZ_PP = address of the byte.  Keeps X, Y.
\ ============================================================================

\ ============================================================================
\ r_pset: X = x, Y = y (inside the clip window): pixel in the colour pair's
\ dither, extends DIRTY[y] and the buffer's row range.  Clobbers A; keeps X, Y.
\ ============================================================================

\ r_cyrow: extend the current buffer's row range by row Y (keeps X, Y)

\ r_pclip: X = x, Y = y: r_pset (and row range) if inside the clip window

\ ============================================================================
\ R_DOT: X = x, Y = y, A = size (1 = 1x1, 2 = 2x1, 3 = 2x2)
\ ============================================================================

\ ============================================================================
\ R_MARKDIRTY: Y = row, extend DIRTY[b][y] by R_XL..R_XR.
\ ============================================================================

\ ============================================================================
\ Arithmetic.  r_div8: A / r_v0 -> r_m0 quotient, A remainder (clobbers X).
\ r_div32: (r_m3..r_m0) / (r_v1,r_v0), needs r_m3,r_m2 < divisor -> quotient
\ r_m1,r_m0, remainder r_m3,r_m2 (clobbers A, X).
\ r_mul16: r_ma * r_mb -> r_m3..r_m0 (r_mb destroyed; clobbers A, X).
\ ============================================================================
.r_div8
{
  STA RZ_T6               \ dividend, becoming the quotient
  LDA r_v0
  STA RZ_T7
  LDA #0
  FOR i, 1, 8
    ASL RZ_T6
    ROL A
    BCS P%+6
    CMP RZ_T7
    BCC P%+6
    SBC RZ_T7
    INC RZ_T6
  NEXT
  LDX RZ_T6
  STX r_m0
  RTS
}



\ ============================================================================
\ R_POLY
\ ============================================================================
.R_POLY
{
  LDA R_PN
  BNE pn1
  RTS
.pn1
  CMP #17
  BCC n_ok
  LDA #16
.n_ok
  STA r_n
  \ fast path when every high byte is zero
  TAX
  DEX
  LDA #0
.hl
  ORA R_PXH,X
  ORA R_PYH,X
  DEX
  BPL hl
  STA r_slow
  TAX
  BNE scan16
  JMP r_pf8
.scan16
  \ reject when every x is left of CL or every x is right of CR
  STZ RZ_T0
  LDX r_n
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
  RTS
.xok
  LDA R_PYL
  STA r_yminL
  STA r_ymaxL
  LDA R_PYH
  STA r_yminH
  STA r_ymaxH
  STZ r_top
  LDX #1
  CPX r_n
  BEQ rows
.vl
  LDA R_PYL,X             \ y < ymin ?
  CMP r_yminL
  LDA R_PYH,X
  SBC r_yminH
  BVC v1
  EOR #&80
.v1
  BPL notless
  LDA R_PYL,X
  STA r_yminL
  LDA R_PYH,X
  STA r_yminH
  STX r_top
  BRA notmore
.notless
  LDA r_ymaxL             \ ymax < y ?
  CMP R_PYL,X
  LDA r_ymaxH
  SBC R_PYH,X
  BVC v2
  EOR #&80
.v2
  BPL notmore
  LDA R_PYL,X
  STA r_ymaxL
  LDA R_PYH,X
  STA r_ymaxH
.notmore
  INX
  CPX r_n
  BNE vl
.rows
  \ row range
  LDA r_yminH
  BMI ys_ct
  BNE out0                \ ymin > 255
  LDA r_yminL
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
  LDX r_ymaxH
  BMI out0
  BNE yl_cb
  CMP r_ymaxL
  BCS out0                \ ystart >= ymax : no rows
  LDA r_ymaxL
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
  RTS
.go
  JMP r_pf16
}

\ ----------------------------------------------------------------------------
\ r_eset: set up edge r_i0 -> r_i1 (y1 > row >= y0) for side r_side at row
\ RZ_Y: x = x0 + ceil(dx*k/dy) with k = row - y0, kept as S and error t with
\ dx*k = dy*(S-x0) - t, 0 <= t < dy; per row S += a, t -= b (a = floor(dx/dy),
\ b = dx - a*dy), borrow: t += dy, S += 1.  Installs a, b, dy into the row loop.
\ ----------------------------------------------------------------------------
.r_eset
{
  LDY r_i0
  LDX r_i1
.^r_esgen
  SEC
  LDA R_PYL,X
  SBC R_PYL,Y
  STA r_edy
  LDA R_PYH,X
  SBC R_PYH,Y
  STA r_edy+1
  SEC
  LDA RZ_Y
  SBC R_PYL,Y
  STA r_ek0
  LDA #0
  SBC R_PYH,Y
  STA r_ek0+1
  LDA R_PXL,Y
  STA r_ex0
  LDA R_PXH,Y
  STA r_ex0+1
  STZ r_eneg
  SEC
  LDA R_PXL,X
  SBC R_PXL,Y
  STA r_eadx
  LDA R_PXH,X
  SBC R_PXH,Y
  STA r_eadx+1
  BPL pos
  DEC r_eneg
  SEC
  LDA #0
  SBC r_eadx
  STA r_eadx
  LDA #0
  SBC r_eadx+1
  STA r_eadx+1
.pos
  \ q, r = adx / dy
  LDA r_eadx
  CMP r_edy
  LDA r_eadx+1
  SBC r_edy+1
  BCS ndiv
  LDA r_eadx
  STA r_er
  LDA r_eadx+1
  STA r_er+1
  STZ r_eq
  STZ r_eq+1
  BRA ddone
.ndiv
  LDA r_eadx+1
  ORA r_edy+1
  BNE d16
  LDA r_edy
  STA r_v0
  LDA r_eadx
  JSR r_div8
  STA r_er
  STZ r_er+1
  LDA r_m0
  STA r_eq
  STZ r_eq+1
  BRA ddone
.d16
  LDA r_eadx
  STA r_m0
  LDA r_eadx+1
  STA r_m1
  STZ r_m2
  STZ r_m3
  LDA r_edy
  STA r_v0
  LDA r_edy+1
  STA r_v1
  JSR r_div32
  LDA r_m0
  STA r_eq
  LDA r_m1
  STA r_eq+1
  LDA r_m2
  STA r_er
  LDA r_m3
  STA r_er+1
.ddone
  LDA r_eneg
  BNE negab
  LDA r_eq
  STA r_ea
  LDA r_eq+1
  STA r_ea+1
  LDA r_er
  STA r_eb
  LDA r_er+1
  STA r_eb+1
  BRA abdone
.negab
  LDA r_er
  ORA r_er+1
  BNE rnz
  SEC                     \ a = -q, b = 0
  LDA #0
  SBC r_eq
  STA r_ea
  LDA #0
  SBC r_eq+1
  STA r_ea+1
  STZ r_eb
  STZ r_eb+1
  BRA abdone
.rnz
  LDA r_eq                \ a = -q-1, b = dy - r
  EOR #&FF
  STA r_ea
  LDA r_eq+1
  EOR #&FF
  STA r_ea+1
  SEC
  LDA r_edy
  SBC r_er
  STA r_eb
  LDA r_edy+1
  SBC r_er+1
  STA r_eb+1
.abdone
  LDX r_side4
  LDA r_ek0
  ORA r_ek0+1
  BNE k0nz
  LDA r_ex0
  STA RZ_SA,X
  LDA r_ex0+1
  STA RZ_SA+1,X
  STZ RZ_TA,X
  STZ RZ_TA+1,X
  JMP install
.k0nz                     \ clipped start: q2, r2 = adx*k / dy
  LDA r_eadx
  STA r_ma
  LDA r_eadx+1
  STA r_ma+1
  LDA r_ek0
  STA r_mb
  LDA r_ek0+1
  STA r_mb+1
  JSR r_mul16
  LDA r_edy
  STA r_v0
  LDA r_edy+1
  STA r_v1
  JSR r_div32
  LDX r_side4
  LDA r_eneg
  BNE kneg
  LDA r_m2
  ORA r_m3
  BEQ kz
  SEC                     \ S = x0 + q2 + 1, t = dy - r2
  LDA r_ex0
  ADC r_m0
  STA RZ_SA,X
  LDA r_ex0+1
  ADC r_m1
  STA RZ_SA+1,X
  SEC
  LDA r_edy
  SBC r_m2
  STA RZ_TA,X
  LDA r_edy+1
  SBC r_m3
  STA RZ_TA+1,X
  JMP install
.kz
  CLC                     \ S = x0 + q2, t = 0
  LDA r_ex0
  ADC r_m0
  STA RZ_SA,X
  LDA r_ex0+1
  ADC r_m1
  STA RZ_SA+1,X
  STZ RZ_TA,X
  STZ RZ_TA+1,X
  JMP install
.kneg
  SEC                     \ S = x0 - q2, t = r2
  LDA r_ex0
  SBC r_m0
  STA RZ_SA,X
  LDA r_ex0+1
  SBC r_m1
  STA RZ_SA+1,X
  LDA r_m2
  STA RZ_TA,X
  LDA r_m3
  STA RZ_TA+1,X
.install
  RTS
}


\ ============================================================================
\ R_POLY 8-bit path: every vertex x, y in 0..255.
\ Phase A walks both chains from the top vertex, running each edge's exact
\ DDA (x = x0 + ceil(dx*k/dy)) down a per-row table: chain A (forward) into
\ r_ta, chain B (backward) into r_tb.  Phase B fills each row from the left
\ table to the right one (exclusive), keeping the RTS planted in the current
\ character row's store run until its position changes.
\ ============================================================================
.r_pf8
{
  LDA R_CR
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
  CMP R_CL
  BCC s3
  CMP r_cr1
  BCC s4
.s3
  INC r_xclip
.s4
  DEX
  BPL sc
  \ rows ystart..ylast
  LDA r_yminL
  CMP R_CT
  BCS y1
  LDA R_CT
.y1
  STA r_ystart
  CMP r_ymaxL
  BCS out
  CMP R_CB
  BEQ y2
  BCS out
.y2
  LDA r_ymaxL
  DEC A
  CMP R_CB
  BCC y3
  LDA R_CB
.y3
  STA r_ylast
  INC A
  STA r_yend
  \ chain A: forward into r_ta
  LDA #LO(r_ta)
  STA r_lsh_t+1
  STA r_lz_t+1
  LDA #HI(r_ta)
  STA r_lsh_t+2
  STA r_lz_t+2
  LDA r_n
  STA r_cc
  LDX r_top
.ca
  LDA R_PYL,X
  CMP r_ymaxL
  BEQ cad
  DEC r_cc
  BMI cad
  STX r_i0
  INX
  CPX r_n
  BCC ca1
  LDX #0
.ca1
  STX r_i1
  JSR r_e8
  LDX r_i1
  BRA ca
.out
  RTS
.cad
  \ chain B: backward into r_tb
  LDA #LO(r_tb)
  STA r_lsh_t+1
  STA r_lz_t+1
  LDA #HI(r_tb)
  STA r_lsh_t+2
  STA r_lz_t+2
  LDA r_n
  STA r_cc
  LDX r_top
.cb
  LDA R_PYL,X
  CMP r_ymaxL
  BEQ cbd
  DEC r_cc
  BMI cbd
  STX r_i0
  DEX
  BPL cb1
  LDX r_n
  DEX
.cb1
  STX r_i1
  JSR r_e8
  LDX r_i1
  BRA cb
.cbd
.^r_pcbd
  \ which table is the left one?
  LDA r_ystart
  CLC
  ADC r_ylast
  ROR A
  TAY
  LDA r_ta,Y
  CMP r_tb,Y
  BCC aleft
  BNE bleft
  LDY r_ystart
.os
  LDA r_ta,Y
  CMP r_tb,Y
  BCC aleft
  BNE bleft
  INY
  CPY r_yend
  BCC os
  RTS                     \ no pixels
.aleft
  LDX #0
  BRA ori
.bleft
  LDX #2
.ori
  LDA otab,X
  STA r_pbl1_e+1
  STA r_pbl1_o+1
  LDA otab+1,X
  STA r_pbl1_e+2
  STA r_pbl1_o+2
  LDA otab+2,X
  STA r_pbr1_e+1
  STA r_pbr2_e+1
  STA r_pbr1_o+1
  STA r_pbr2_o+1
  LDA otab+3,X
  STA r_pbr1_e+2
  STA r_pbr2_e+2
  STA r_pbr1_o+2
  STA r_pbr2_o+2
  \ horizontal clip: clamp both tables into CL..CR+1
  LDA r_xclip
  BEQ nocl
  LDY r_ystart
.cl
  LDA r_ta,Y
  CMP R_CL
  BCS cl1
  LDA R_CL
.cl1
  CMP r_cr1
  BCC cl2
  LDA r_cr1
.cl2
  STA r_ta,Y
  LDA r_tb,Y
  CMP R_CL
  BCS cl3
  LDA R_CL
.cl3
  CMP r_cr1
  BCC cl4
  LDA r_cr1
.cl4
  STA r_tb,Y
  INY
  CPY r_yend
  BCC cl
.nocl
  \ rows clamped to nothing at the top / bottom (ta = tb): trim them
  LDY r_ystart
.tt
  LDA r_ta,Y
  CMP r_tb,Y
  BNE tt1
  INY
  CPY r_yend
  BCC tt
  RTS                     \ (no pixels at all)
.tt1
  STY r_ystart
  LDY r_ylast
.tb
  LDA r_ta,Y
  CMP r_tb,Y
  BNE tb1
  DEY
  BRA tb
.tb1
  STY r_ylast
  INY
  STY r_yend
  \ this buffer's dirty row range
  LDX r_buf
  LDA r_ystart
  CMP r_dyt,X
  BCS d1
  STA r_dyt,X
.d1
  LDA r_ylast
  CMP r_dyb,X
  BCC d2
  STA r_dyb,X
.d2
  \ phase B set-up
  SEC
  LDA r_yend
  SBC r_ystart
  STA RZ_SA               \ rows to do
  LDA R_COLE
  EOR R_COLO
  STA RZ_SB
  LDY r_ystart
  JSR r_rowset
  LDA RZ_PP+1
  STA r_jsr2_e+2
  STA r_jsr2_o+2
  LDA r_yend
  STA pb_ye_e+1
  STA pb_ye_o+1
  LDA #190                \ nothing planted
  STA RZ_PP
  TYA
  LSR A
  LDA R_COLE
  BCC ev
  LDA R_COLO
  STA RZ_COL
  JMP r_pbx_o             \ odd first row (Y = RZ_Y)
.ev
  STA RZ_COL
  JMP r_pbx_e             \ even first row
.otab
  EQUW r_ta, r_tb, r_ta
}

\ r_e8: edge r_i0 -> r_i1 of an 8-bit polygon into the table at (RZ_T4)
.r_e8
{
  LDY r_i0
                          \ X = r_i1 already: both callers (1416/1445) STX r_i1 : JSR r_e8
  LDA R_PYL,X
  CMP R_PYL,Y
  BCC out
  BEQ out                 \ not going down
  CMP r_yend
  BCC e1
  LDA r_yend
.e1
  STA RZ_T2               \ end row (exclusive)
  LDA R_PYL,Y
  CMP RZ_T2
  BCS out                 \ y0 >= end row
  CMP r_ystart
  BCC cl                  \ y0 < ystart (if y0 >= ystart then RZ_T2 > y0 >= ystart)
.e2
  STA RZ_T3               \ start row (A = y0 = R_PYL,Y, C = 1 from BCC cl not taken)
  EOR #&FF
  ADC R_PYL,X             \ dy = y1 - y0; C stays 1 (y1 > y0)
  STA RZ_T1               \ dy
  LDA R_PXL,Y
  STA RZ_T0               \ S = x0
  EOR #&FF
  ADC R_PXL,X             \ dx = x1 - x0, C = (x1 >= x0)
  BCC neg
  CMP RZ_T1
  BCS pdiv
  TAX                     \ steep, a = 0, b = dx (Z from TAX)
  BEQ z0
  LDA #0
  JMP shallow
.z0
  JMP zloop               \ A = X = 0
.cl                       \ y0 < ystart: out if end row <= ystart, else clipped
  LDA RZ_T2
  CMP r_ystart
  BEQ out
  BCC out
  JMP clipped
.out
  RTS
.pdiv
  JSR r_dvq               \ A = r, r_m0 = q
  TAX
  BEQ pz
  LDA r_m0
  JMP shallow
.pz
  LDA r_m0
  JMP zloop
.neg
  EOR #&FF
  INC A                   \ adx
  CMP RZ_T1
  BCS ndiv
  EOR #&FF                \ steep, a = -1, b = dy - adx
  SEC
  ADC RZ_T1
  TAX
  LDA #&FF                \ a = -1
  JMP shallow
.ndiv
  JSR r_dvq
  CMP #0
  BNE nr
  SEC                     \ a = -q
  SBC r_m0
  JMP zloop
.nr
  EOR #&FF                \ b = dy - r, a = NOT q
  SEC
  ADC RZ_T1
  TAX
  LDA r_m0
  EOR #&FF
  JMP shallow
.clipped                  \ starts above the window: general set-up at ystart
  LDA r_ystart
  STA RZ_Y
  STA RZ_T3
  STZ r_side4
  STZ r_side
  JSR r_esgen             \ S, t -> RZ_SA, RZ_TA; a, b, dy -> r_ea, r_eb, r_edy
  LDA RZ_SA
  STA RZ_T0
  LDA r_edy
  STA RZ_T1
  LDX r_eb
  BNE c1
  LDA r_ea
  JMP zloop1
.c1
  LDA r_ea
  JMP shallow1
\ b = 0: A = a  (falls into r_lz)
.zloop
.zloop1
.^r_pzl1
  STA r_lz_a+1
  LDA RZ_T2
  STA r_lz_e+1
  LDY RZ_T3
  LDA RZ_T0
  CLC
\ The DDA loops (Y = row, run to the patched end row)
.^r_lz                    \ b = 0: A = x
.^r_lz_t
  STA &FFFF,Y
  INY
.^r_lz_a
  ADC #0                  \ a (C = 0)
.^r_lz_e
  CPY #0
  BCC r_lz
  RTS
\ shallow: X = b, A = a  (falls into r_lsh)
.shallow
  STZ RZ_TA
.shallow1
.^r_psh1
  DEC A
  STA r_lsh_a+1
  DEX
  STX r_lsh_b+1
  LDA RZ_T1
  STA r_lsh_d+1
  LDA RZ_T2
  STA r_lsh_e+1
  LDY RZ_T3
  LDA RZ_T0
  CLC
.^r_lsh                   \ |dx| >= dy: A = x, RZ_TA = error
.^r_lsh_t
  STA &FFFF,Y
  INY
  TAX
  LDA RZ_TA
.^r_lsh_b
  SBC #0                  \ b - 1 (C = 0)
  BCS lsh1
.^r_lsh_d
  ADC #0                  \ dy
  INX
.lsh1
  STA RZ_TA
  TXA
.^r_lsh_a
  ADC #0                  \ a - 1 (C = 1)
.^r_lsh_e
  CPY #0
  BCC r_lsh
  RTS
}


\ r_dvq: A / RZ_T1 (A >= RZ_T1 >= 1) -> r_m0 quotient, A remainder.
\ Repeated subtraction when the quotient is small (divisor >= 16).
.r_dvq
{
  LDX RZ_T1
  CPX #16
  BCC small
  LDX #&FF                \ divisor >= 16: quotient < 16
  SEC
.lp
  INX
  SBC RZ_T1
  BCS lp
  ADC RZ_T1
  STX r_m0
  RTS
.small
  STA RZ_T6               \ divisor < 16: quotient < 16 unless A >= 16 * d
  TXA
  ASL A
  ASL A
  STA RZ_T7               \ 4d
  ASL A
  ASL A                   \ 16d (< 256)
  CMP RZ_T6
  BEQ long
  BCC long
  LDA RZ_T6
  LDX #&FC
  SEC
.l4
  INX
  INX
  INX
  INX
  SBC RZ_T7
  BCS l4
  ADC RZ_T7
  DEX
.l1
  INX
  SBC RZ_T1
  BCS l1
  ADC RZ_T1
  STX r_m0
  RTS
.long
  LDA RZ_T6
  LDX RZ_T1
  STX r_v0
  JMP r_div8
}
  SKIP 6                  \ the two JMPs removed above: keeps later bank-5 addresses unchanged

\ ----------------------------------------------------------------------------
\ Phase B: rows RZ_Y.., RZ_SA of them; left table r_pbl1, right (exclusive)
\ r_pbr1/r_pbr2.  Row pointers, run page (RZ_PP+1, r_jsr2+2), RZ_COL set;
\ RZ_PP = the planted RTS (190: none).
\ ----------------------------------------------------------------------------

.pb_one_e
  LDY r_xo,X
  LDA r_lm,X
  LDX R_XR
  AND r_rm,X
  STA RZ_T7
  CPX #&80
  BCS pb_ob_e
  LDA (RZ_PA),Y
  EOR R_COLE
  AND RZ_T7
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
  JMP pb_skip_e
.pb_ob_e
  LDA (RZ_PB),Y
  EOR R_COLE
  AND RZ_T7
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
  JMP pb_skip_e
.pb_plant_e
  TAY
  LDA #r_opSTA
  STA (RZ_PP)
  STY RZ_PP
  LDA #r_opRTS
  STA (RZ_PP)
  JMP pb_go_e
.pb_lb_e
  LDA (RZ_PB),Y
  EOR R_COLE
  AND r_lm,X
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
  JMP pb_l2_e
.pb_rb_e
  LDY r_xo,X
  LDA (RZ_PB),Y
  EOR R_COLE
  AND r_rm,X
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
  JMP pb_skip_e
.r_pb_e
  LDY RZ_Y
.r_pbx_e
.r_pbl1_e
  LDA &FFFF,Y
.r_pbr1_e
  CMP &FFFF,Y
  BCS pb_skip_e+2         \ empty row: Y = RZ_Y already, skip the LDY RZ_Y
  TAX
.r_pt60 CMP r_dl,Y
  BCS pb_d1_e
.r_pt61 STA r_dl,Y
.pb_d1_e
.r_pbr2_e
  LDA &FFFF,Y
  DEC A
  STA R_XR
.r_pt62 CMP r_dr,Y
  BCC pb_d2_e
.r_pt63 STA r_dr,Y
.pb_d2_e
  TXA
  EOR R_XR
  CMP #4
  BCC pb_one_e
  LDY r_xo,X
  CPX #&80
  BCS pb_lb_e
  LDA (RZ_PA),Y
  EOR R_COLE
  AND r_lm,X
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
.pb_l2_e
  LDY R_XR
  LDA r_j-4,Y
  CMP r_j,X
  BEQ pb_norun_e
  LDY r_j,X
  STY r_jsr2_e+1
  CMP RZ_PP
  BNE pb_plant_e
.pb_go_e
  LDX RZ_PA
  LDA R_COLE
.r_jsr2_e
  JSR &FFFF
.pb_norun_e
  LDX R_XR                \ N = (XR >= &80)
  BMI pb_rb_e
  LDY r_xo,X
  LDA (RZ_PA),Y
  EOR R_COLE
  AND r_rm,X
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
.pb_skip_e
  LDY RZ_Y
  INY
.pb_ye_e
  CPY #0                  \ (patched: the end row)
  BEQ pb_end_j
.pb_c_e
  STY RZ_Y
  INC RZ_PA
  INC RZ_PB
.r_pbx_o
.r_pbl1_o
  LDA &FFFF,Y
.r_pbr1_o
  CMP &FFFF,Y
  BCS pb_skip_o+2         \ empty row: Y = RZ_Y already, skip the LDY RZ_Y
  TAX
.r_pt410 CMP r_dl,Y
  BCS pb_d1_o
.r_pt411 STA r_dl,Y
.pb_d1_o
.r_pbr2_o
  LDA &FFFF,Y
  DEC A
  STA R_XR
.r_pt412 CMP r_dr,Y
  BCC pb_d2_o
.r_pt413 STA r_dr,Y
.pb_d2_o
  TXA
  EOR R_XR
  CMP #4
  BCC pb_one_o
  LDY r_xo,X
  CPX #&80
  BCS pb_lb_o
  LDA (RZ_PA),Y
  EOR R_COLO
  AND r_lm,X
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
.pb_l2_o
  LDY R_XR
  LDA r_j-4,Y
  CMP r_j,X
  BEQ pb_norun_o
  LDY r_j,X
  STY r_jsr2_o+1
  CMP RZ_PP
  BNE pb_plant_o
.pb_go_o
  LDX RZ_PA
  LDA R_COLO
.r_jsr2_o
  JSR &FFFF
.pb_norun_o
  LDX R_XR                \ N = (XR >= &80)
  BMI pb_rb_o
  LDY r_xo,X
  LDA (RZ_PA),Y
  EOR R_COLO
  AND r_rm,X
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
.pb_skip_o
  LDY RZ_Y
  INY
.pb_ye_o
  CPY #0                  \ (patched: the end row)
.pb_end_j                 \ (also BEQ pb_end_j from the even half: Z = 1)
  BEQ pb_end
.pb_c_o
  STY RZ_Y
  TYA                     \ RZ_PA/RZ_PB lo = row AND 7
  AND #7
  BEQ pb_cr               \ (pb_cr zeroes them itself)
  STA RZ_PA
  STA RZ_PB
  JMP r_pbx_e
.pb_one_o
  LDY r_xo,X
  CPX #&80                \ XL, XR differ only in bits 0-1 (XL EOR XR < 4)
  BCS pb_ob_o
  LDA (RZ_PA),Y
  EOR R_COLO
  AND r_lm,X
  LDX R_XR
  AND r_rm,X
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
  BRA pb_skip_o
.pb_ob_o
  LDA (RZ_PB),Y
  EOR R_COLO
  AND r_lm,X
  LDX R_XR
  AND r_rm,X
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
  BRA pb_skip_o
.pb_lb_o
  LDA (RZ_PB),Y
  EOR R_COLO
  AND r_lm,X
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
  BRA pb_l2_o
.pb_rb_o
  LDY r_xo,X
  LDA (RZ_PB),Y
  EOR R_COLO
  AND r_rm,X
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
  BRA pb_skip_o
.pb_plant_o
  TAY
  LDA #r_opSTA
  STA (RZ_PP)
  STY RZ_PP
  LDA #r_opRTS
  STA (RZ_PP)
  JMP pb_go_o
.pb_end
  LDA #r_opSTA            \ take the RTS out again
  STA (RZ_PP)
  RTS
.pb_cr
  LDA #r_opSTA            \ next character row: new run page
  STA (RZ_PP)
  LDA #190
  STA RZ_PP
  STZ RZ_PA
  STZ RZ_PB
  LDA RZ_PA+1
  CLC
  ADC #2
  STA RZ_PA+1
  INC A
  STA RZ_PB+1
  INC RZ_PP+1
  INC r_jsr2_e+2
  INC r_jsr2_o+2
  JMP r_pb_e

\ ----------------------------------------------------------------------------
\ r_pf16: R_POLY with some coordinate outside 0..255 (rows r_ystart..r_ylast
\ already found).  Phase A as r_pf8 (chain A forward into r_ta, chain B
\ backward into r_tb) with 16-bit edges whose x is clamped into CL..CR+1 per
\ row; then r_pf8's phase B.
\ ----------------------------------------------------------------------------
.r_pf16
{
  LDA R_CR
  INC A
  STA r_cr1
  LDA #LO(r_ta)
  STA r_lsh_t+1
  STA r_lz_t+1
  STA r_x16_t+1
  STA r_x16_f+1
  LDA #HI(r_ta)
  STA r_lsh_t+2
  STA r_lz_t+2
  STA r_x16_t+2
  STA r_x16_f+2
  LDA r_n
  STA r_cc
  LDX r_top
.ca
  LDA R_PYL,X
  CMP r_ymaxL
  BNE ca0
  LDA R_PYH,X
  CMP r_ymaxH
  BEQ cad
.ca0
  DEC r_cc
  BMI cad
  STX r_i0
  INX
  CPX r_n
  BCC ca1
  LDX #0
.ca1
  STX r_i1
  JSR r_e16
  LDX r_i1
  BRA ca
.cad
  LDA #LO(r_tb)
  STA r_lsh_t+1
  STA r_lz_t+1
  STA r_x16_t+1
  STA r_x16_f+1
  LDA #HI(r_tb)
  STA r_lsh_t+2
  STA r_lz_t+2
  STA r_x16_t+2
  STA r_x16_f+2
  LDA r_n
  STA r_cc
  LDX r_top
.cb
  LDA R_PYL,X
  CMP r_ymaxL
  BNE cb0
  LDA R_PYH,X
  CMP r_ymaxH
  BEQ cbd
.cb0
  DEC r_cc
  BMI cbd
  STX r_i0
  DEX
  BPL cb1
  LDX r_n
  DEX
.cb1
  STX r_i1
  JSR r_e16
  LDX r_i1
  BRA cb
.cbd
  STZ r_xclip
  JMP r_pcbd
}

\ r_e16: edge r_i0 -> r_i1 (16-bit) into the table (rows r_ystart..r_ylast)
.r_e16
{
  LDY r_i0
  LDX r_i1
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
  STZ r_side4
  JSR r_esgen             \ S, t -> RZ_SA, RZ_TA; a, b, dy -> r_ea, r_eb, r_edy
  LDY r_i0                \ both ends' x inside CL..CR+1 and dy < 256:
  LDX r_i1                \ the 8-bit DDA
  LDA r_edy+1
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
  LDA r_edy
  STA RZ_T1
  LDX r_eb
  LDA r_ea
  CPX #0
  BNE sh
  JMP r_pzl1
.sh
  JMP r_psh1
.gen                      \ general: 16-bit S, t; x clamped into CL..CR+1
  LDA r_eb
  STA bl+1
  LDA r_eb+1
  STA bh+1
  LDA r_edy
  STA dl+1
  LDA r_edy+1
  STA dh+1
  LDA r_ea
  STA al+1
  LDA r_ea+1
  STA ah+1
  LDA RZ_T2
  STA ye+1
  STZ RZ_T4               \ bit 7: the far end is inside CL..CR+1 and dy < 256,
  LDX r_i1                \ so once inside, x stays inside: the 8-bit DDA
  LDA r_edy+1
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
  BIT r_ea+1              \ right of the window, moving right: stays there
  BPL fh
  LDA r_cr1
  BRA st
.lo
  BIT r_ea+1              \ left of it, moving left: stays there
  BMI fl
  LDA R_CL
.st
.^r_x16_t
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
.^r_x16_f
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
  LDA r_edy
  STA RZ_T1
  LDX r_eb
  LDA r_ea
  CPX #0
  BNE sw1
  JMP r_pzl1
.sw1
  JMP r_psh1
}

\ ============================================================================
\ R_DISCROWS
\ ============================================================================
.R_DISCROWS
{
  LDA R_NDT
  CMP R_CT
  BCS t1
  LDA R_CT
.t1
  STA r_nt
  LDA R_NDB
  CMP R_CB
  BCC t2
  LDA R_CB
.t2
  STA r_nb
  CMP r_nt
  BCS t3
  LDA #&FF
  STA r_nt
  STZ r_nb
.t3
  JSR r_wclear            \ clear last frame's WL/WR rows
  LDA #&FF
  STA r_wt
  STZ r_wb
  \ lo..hi = old disc rows + dirty rows + new disc rows
  LDX r_buf
  LDA r_dst,X
  CMP r_dyt,X
  BCC t4
  LDA r_dyt,X
.t4
  CMP r_nt
  BCC t5
  LDA r_nt
.t5
  STA r_lo
  LDA r_dsb,X
  CMP r_dyb,X
  BCS t6
  LDA r_dyb,X
.t6
  CMP r_nb
  BCS t7
  LDA r_nb
.t7
  STA r_hi
  LDA r_dyt,X             \ dirty rows (for the loop split)
  STA r_dya
  LDA r_dyb,X
  STA r_dyz
  JSR r_crep5             \ dirty rows that are no disc rows: bank 7
  LDA r_nt
  STA r_dst,X
  LDA r_nb
  STA r_dsb,X
  LDA #&FF
  STA r_dyt,X
  STZ r_dyb,X
  LDA r_hi
  CMP r_lo
  BCS go
  JMP stars
.go
  \ rows of lo..hi outside nt..nb: new = empty
  LDX r_hi
  INX
  STX RZ_T0               \ hi + 1
  LDA r_nt                \ lo .. min(nt, hi+1) - 1
  CMP RZ_T0
  BCC pa
  LDA RZ_T0
.pa
  STA pe1+1
  LDX r_lo
  CPX pe1+1
  BCS pb
  LDA #&FF
.pf1
  STA R_NDISCL,X
  STZ R_NDISCR,X
  INX
.pe1
  CPX #0
  BNE pf1
.pb
  LDA r_nt                \ no new disc: done
  CMP #&FF
  BEQ pf5
  LDX r_nb                \ max(nb+1, lo) .. hi
  INX
  CPX r_lo
  BCS pc
  LDX r_lo
.pc
  CPX RZ_T0
  BCS pf5
  LDA RZ_T0
  STA pe2+1
  LDA #&FF
.pf4
  STA R_NDISCL,X
  STZ R_NDISCR,X
  INX
.pe2
  CPX #0
  BNE pf4
.pf5
  LDX r_buf               \ boundaries this frame or last time: r_dbm
  LDA R_NDF
  ORA r_bmode,X
  BEQ plain
  JMP r_dbm
.plain
  \ split lo..hi at the dirty rows: A-loop (no dirty) / B-loop
  LDA r_dyz
  CMP r_dya
  BCC alla                \ no dirty rows
  LDA r_dya               \ clip the dirty rows to lo..hi
  CMP r_lo
  BCS s1
  LDA r_lo
  STA r_dya
.s1
  LDA r_dyz
  CMP r_hi
  BCC s2
  LDA r_hi
  STA r_dyz
.s2
  LDX r_lo                \ lo .. dyt-1
  LDA r_dya
  JSR r_dla
  LDX r_dya               \ dyt .. dyb
  LDA r_dyz
  INC A
  JSR r_dlb
  LDX r_dyz               \ dyb+1 .. hi
  INX
  BRA tail
.alla
  LDX r_lo
.tail
  LDA r_hi
  INC A
  JSR r_dla
.stars
.^r_dstars
  JMP r_cwb5              \ (erased stars need no WL/WR: R_STARPLOT comes last)
}



\ ============================================================================
\ Two-colour discs.  r_dbm: R_DISCROWS' rows lo..hi when this frame or this
\ buffer's last one has boundaries.
\ ============================================================================
.r_dbm
{
  LDX r_buf               \ the boundary arrays' operands: patched only here
  CPX r_sbbdb             \ (two-colour discs only)
  BNE pp
  JMP pt
.pp
  STX r_sbbdb
  LDA r_sbh_bdn,X          \ group r_bdn
  STA r_pt86+2
  STA r_pt92+2
  STA r_pt420+2
  STA r_pt98+2
  STA r_pt110+2
  STA r_pt130+2
  STA r_pt139+2
  STA r_pt142+2
  STA r_pt154+2
  LDA r_sbh_bdp,X          \ group r_bdp
  STA r_pt87+2
  STA r_pt91+2
  STA r_pt99+2
  STA r_pt111+2
  STA r_pt138+2
  STA r_pt141+2
  STA r_pt143+2
  STA r_pt155+2
  LDA r_sbh_bdx0,X          \ group r_bdx0
  STA r_pt93+2
  STA r_pt100+2
  STA r_pt134+2
  STA r_pt400+2
  STA r_pt401+2
  LDA r_sbh_bdx1,X          \ group r_bdx1
  STA r_pt94+2
  STA r_pt101+2
  STA r_pt135+2
  STA r_pt402+2
  STA r_pt403+2
  LDA r_sbh_bdx2,X          \ group r_bdx2
  STA r_pt95+2
  STA r_pt102+2
  STA r_pt136+2
  STA r_pt404+2
  STA r_pt405+2
  LDA r_sbh_bdx3,X          \ group r_bdx3
  STA r_pt96+2
  STA r_pt103+2
  STA r_pt137+2
  STA r_pt406+2
  STA r_pt407+2
.pt
  LDX r_buf
  LDA r_bmode,X           \ plain last time: its rows had no boundaries
  BNE m1
  LDX r_lo
.m0
.^r_pt110 STZ r_bdn,X
.^r_pt111 STZ r_bdp,X
  CPX r_hi
  INX
  BCC m0
  LDX r_buf
.m1
  LDA R_NDF
  STA r_bmode,X
  LDA #1
  STA r_bon
  LDA R_NDF               \ rows without new boundaries: count 0, colour A
  BNE z0
  LDX r_lo                \ (no boundaries this frame: all of lo..hi)
  LDY r_hi
  JSR zr
  BRA z9
.z0
  LDX r_lo                \ lo .. nt-1
  LDY r_nt
  BEQ z5
  DEY
  CPY r_hi
  BCC z4
  LDY r_hi
.z4
  JSR zr
.z5
  LDX r_nb                \ nb+1 .. hi
  INX
  LDY r_hi
  JSR zr
  BRA z9
.zr                       \ rows X .. Y (none if X > Y)
  STY zre+1
  CPX zre+1
  BEQ zl
  BCS zx
.zl
  STZ R_NDN,X
  STZ R_NDP,X
  INX
.zre
  CPX #0
  BCC zl
  BEQ zl
.zx
  RTS
.z9
  LDX r_lo
  LDA r_hi
  INC A
  JSR r_dmb
  STZ r_bon
  JMP r_dstars
}

\ r_dmb: rows X .. A-1 with boundaries: unchanged rows cost a few compares
.r_dmb
{
  STA end+1
  STX st+1
.lp
  LDA R_NDISCL,X
.^r_pt89 CMP r_sl,X
  BNE ch
  LDA R_NDISCR,X
.^r_pt90 CMP r_sr,X
  BNE ch
  LDA R_NDP,X             \ (R_NDP and r_bdp only ever hold 0 or 1)
.^r_pt91 CMP r_bdp,X
  BNE ch
  LDA R_NDN,X             \ (no boundaries, the usual case: no TAY/BEQ)
  BNE nz
.^r_pt420 CMP r_bdn,X     \ (A = 0; patched with r_pt92)
  BNE ch
.sm
.^r_pt88 LDA r_dl,X       \ unchanged: dirty? then repaint only the dirty part
  INC A
  BNE smd
.nx
  INX
.end
  CPX #0
  BNE lp
  DEX                     \ rows st .. end-1 may have WL/WR (r_dq leaves
  CPX r_wb                \ r_wt/r_wb to this)
  BCC e1
  STX r_wb
.e1
.st
  LDX #0
  CPX r_wt
  BCS e2
  STX r_wt
.e2
  RTS
.smd
  INC r_dsub
  BRA gd
.nz                       \ 1..4 boundaries
.^r_pt92 CMP r_bdn,X
  BNE ch
  TAY
  LDA R_NDX0,X
.^r_pt93 CMP r_bdx0,X
  BNE chb
  DEY
  BEQ sm
  LDA R_NDX1,X
.^r_pt94 CMP r_bdx1,X
  BNE chb
  DEY
  BEQ sm
  LDA R_NDX2,X
.^r_pt95 CMP r_bdx2,X
  BNE chb
  DEY
  BEQ sm
  LDA R_NDX3,X
.^r_pt96 CMP r_bdx3,X
  BEQ sm
.chb
.^r_pt408 LDA r_dl,X
  INC A
  BNE gd                  \ dirty
  JMP r_dq
.^r_dmbx
  LDX RZ_Y
  BRA nx
.ch
.^r_pt409 LDA r_dl,X
  INC A
  BNE gd                  \ dirty
  JSR r_dpe
  LDX RZ_Y
  BRA nx
.gd
  TXA
  TAY
  LDA R_NDISCL,Y
.^r_pt97 AND r_sl,Y
  INC A
  BNE gg
  STZ r_dsub
  JSR r_dp1               \ no disc, old or new: black the dirty extent
  LDX RZ_Y
  BRA nx
.gg
  JSR r_drg
  LDX RZ_Y
  JMP nx                  \ (out of BRA range; JMP is 3 cycles too)
}






\ r_dq: X = row of a two-colour disc whose span, colour and boundary count
\ are unchanged (no dirty): each moved boundary's strip (old .. new) is
\ written in the colour on the side it moved from.  Strips out of order:
\ r_drg (a full repaint; partial writes are harmless).
.r_dq
{
  STX RZ_Y
  TXA                     \ row pointers
  AND #7
  STA RZ_PA
  STA RZ_PB
  TXA
  LSR A
  LSR A
  AND #&FE
  ORA #&40
  STA RZ_PA+1
  INC A
  STA RZ_PB+1
  TXA                     \ colours: T2 even segments, T1 odd
  LSR A
  BCS od
  LDA R_DCE
  LDY R_DBE
  BRA ev
.od
  LDA R_DCO
  LDY R_DBO
.ev
  STA RZ_T2
  STY RZ_T1
  LDA R_NDP,X
  LSR A
  BCC np
  LDA RZ_T2
  STY RZ_T2
  STA RZ_T1
.np
  LDA R_NDN,X
  STA RZ_T5
.^r_pt399 LDA r_sl,X
  INC A
  STA RZ_T6               \ strips must start at or after this
  STZ RZ_T4               \ extent of the writes (none)
  STZ RZ_T3
  DEC RZ_T5               \ boundary 0
  BMI done0
.^r_pt400 LDY r_bdx0,X      \ Y = old, A = new
  STY RZ_T0
  LDA R_NDX0,X
  CMP RZ_T0
  BEQ s0
.^r_pt401 STA r_bdx0,X
  BCC l0
  CPY RZ_T6               \ moved right: old .. new-1 in the colour left of it
  BCC g0
  STA RZ_T6
  DEC A
  TAY
  LDX RZ_T0
  STY RZ_T3               \ (extent of the writes)
  LDA RZ_T4
  BNE r0
  STX RZ_T4
.r0
  LDA RZ_T2
  JSR r_sw
  LDX RZ_Y
  BRA n0
.l0
  CMP RZ_T6               \ moved left: new .. old-1 in the colour right of it
  BCC g0
  STY RZ_T6
  DEY
  TAX
  STY RZ_T3
  LDA RZ_T4
  BNE q0
  STX RZ_T4
.q0
  LDA RZ_T1
  JSR r_sw
  LDX RZ_Y
  BRA n0
.s0
  STA RZ_T6               \ unmoved: the next strip starts after it
  BRA n0
.done0
  JMP done
.g0
  JMP gen
.n0
  DEC RZ_T5               \ boundary 1
  BMI done1
.^r_pt402 LDY r_bdx1,X      \ Y = old, A = new
  STY RZ_T0
  LDA R_NDX1,X
  CMP RZ_T0
  BEQ s1
.^r_pt403 STA r_bdx1,X
  BCC l1
  CPY RZ_T6               \ moved right: old .. new-1 in the colour left of it
  BCC g1
  STA RZ_T6
  DEC A
  TAY
  LDX RZ_T0
  STY RZ_T3               \ (extent of the writes)
  LDA RZ_T4
  BNE r1
  STX RZ_T4
.r1
  LDA RZ_T1
  JSR r_sw
  LDX RZ_Y
  BRA n1
.l1
  CMP RZ_T6               \ moved left: new .. old-1 in the colour right of it
  BCC g1
  STY RZ_T6
  DEY
  TAX
  STY RZ_T3
  LDA RZ_T4
  BNE q1
  STX RZ_T4
.q1
  LDA RZ_T2
  JSR r_sw
  LDX RZ_Y
  BRA n1
.s1
  STA RZ_T6               \ unmoved: the next strip starts after it
  BRA n1
.done1
  JMP done
.g1
  JMP gen
.n1
  DEC RZ_T5               \ boundary 2
  BMI done2
.^r_pt404 LDY r_bdx2,X      \ Y = old, A = new
  STY RZ_T0
  LDA R_NDX2,X
  CMP RZ_T0
  BEQ s2
.^r_pt405 STA r_bdx2,X
  BCC l2
  CPY RZ_T6               \ moved right: old .. new-1 in the colour left of it
  BCC g2
  STA RZ_T6
  DEC A
  TAY
  LDX RZ_T0
  STY RZ_T3               \ (extent of the writes)
  LDA RZ_T4
  BNE r2
  STX RZ_T4
.r2
  LDA RZ_T2
  JSR r_sw
  LDX RZ_Y
  BRA n2
.l2
  CMP RZ_T6               \ moved left: new .. old-1 in the colour right of it
  BCC g2
  STY RZ_T6
  DEY
  TAX
  STY RZ_T3
  LDA RZ_T4
  BNE q2
  STX RZ_T4
.q2
  LDA RZ_T1
  JSR r_sw
  LDX RZ_Y
  BRA n2
.s2
  STA RZ_T6               \ unmoved: the next strip starts after it
  BRA n2
.done2
  JMP done
.g2
  JMP gen
.n2
  DEC RZ_T5               \ boundary 3
  BMI done3
.^r_pt406 LDY r_bdx3,X      \ Y = old, A = new
  STY RZ_T0
  LDA R_NDX3,X
  CMP RZ_T0
  BEQ s3
.^r_pt407 STA r_bdx3,X
  BCC l3
  CPY RZ_T6               \ moved right: old .. new-1 in the colour left of it
  BCC g3
  STA RZ_T6
  DEC A
  TAY
  LDX RZ_T0
  STY RZ_T3               \ (extent of the writes)
  LDA RZ_T4
  BNE r3
  STX RZ_T4
.r3
  LDA RZ_T1
  JSR r_sw
  LDX RZ_Y
  BRA n3
.l3
  CMP RZ_T6               \ moved left: new .. old-1 in the colour right of it
  BCC g3
  STY RZ_T6
  DEY
  TAX
  STY RZ_T3
  LDA RZ_T4
  BNE q3
  STX RZ_T4
.q3
  LDA RZ_T2
  JSR r_sw
  LDX RZ_Y
  BRA n3
.s3
  STA RZ_T6               \ unmoved: the next strip starts after it
  BRA n3
.done3
  JMP done
.g3
  JMP gen
.n3
.done
  LDY RZ_Y
  LDA RZ_T3
  BEQ none
  STA R_WR,Y
  LDA RZ_T4
  STA R_WL,Y
.none
  JMP r_dmbx
.gen
  LDY RZ_Y
  JSR r_drg
  JMP r_dmbx
}

\ r_sw: pixels X .. Y (X <= Y) of the row (RZ_PA/RZ_PB set) in colour A.
\ Clobbers A, X, Y, RZ_COL, RZ_SA, RZ_SA+1, RZ_T7.
.r_sw
{
  STA RZ_COL
  STY RZ_SA
  TXA
  EOR RZ_SA
  CMP #4
  BCS multi
  LDA r_lm,X              \ one byte
  AND r_rm,Y
  STA RZ_T7
  LDY r_xo,X
  CPX #&80
  BCS h1
  LDA RZ_COL
  EOR (RZ_PA),Y
  AND RZ_T7
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
  RTS
.h1
  LDA RZ_COL
  EOR (RZ_PB),Y
  AND RZ_T7
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
  RTS
.multi
  CPY #&80
  BCS mb
  LDA r_xo,Y              \ both in columns 0..31
  STA RZ_SA+1
  LDY r_xo,X
  LDA RZ_COL
  EOR (RZ_PA),Y
  AND r_lm,X
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
  CPY RZ_SA+1             \ (C = 0)
.la
  TYA
  ADC #8
  TAY
  CPY RZ_SA+1
  BCS lsa
  LDA RZ_COL
  STA (RZ_PA),Y
  BRA la
.lsa
  LDX RZ_SA
  LDA RZ_COL
  EOR (RZ_PA),Y
  AND r_rm,X
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
  RTS
.mb
  CPX #&80
  BCC cross
  LDA r_xo,Y              \ both in columns 32..63
  STA RZ_SA+1
  LDY r_xo,X
  LDA RZ_COL
  EOR (RZ_PB),Y
  AND r_lm,X
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
  CPY RZ_SA+1             \ (C = 0)
.lb
  TYA
  ADC #8
  TAY
  CPY RZ_SA+1
  BCS lsb
  LDA RZ_COL
  STA (RZ_PB),Y
  BRA lb
.lsb
  LDX RZ_SA
  LDA RZ_COL
  EOR (RZ_PB),Y
  AND r_rm,X
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
  RTS
.cross
  STX RZ_SB
  STY RZ_TA+1
  JMP r_lput2
}




\ ============================================================================
\ r_dpe: X = row of a two-colour disc, no dirty, changed.  The row is a list
\ of edges, each with an old and a new position: the span's left end, the
\ boundaries, the end after its right end.  When old and new have the same
\ boundary count and left colour and each edge's strip (old .. new) lies
\ before the next edge's, only the strips are written (masked): pixels
\ outside them keep their colour.  Relies on boundaries being inside their
\ span.  Otherwise r_drg (a full repaint).
\ ============================================================================
.r_dpeg
  JMP r_dpgl
.r_dpe
{
  STX RZ_Y
.^r_pt132 LDA r_sl,X
  CMP #&FF
  BEQ r_dpeg
  LDA R_NDN,X             \ (early out: counts differing by 2 or more, or
  CLC                     \ the same count with the colour flipped)
  ADC #1
  SEC
.^r_pt154 SBC r_bdn,X
  CMP #3
  BCS r_dpeg
  CMP #1
  BNE e9
  LDA R_NDP,X
.^r_pt155 EOR r_bdp,X
  LSR A
  BCS r_dpeg
  LDA R_NDN,X             \ no boundaries, old or new, and colour A (R_DCE /
  BNE e9                  \ R_DCO) both times: a one-colour row, which r_dp2
  LDA R_NDP,X             \ does in less time (the stored boundaries, count 0,
  LSR A                   \ are never read)
  BCS e9
  JMP r_dp2
.e9
.^r_pt131 LDA r_sl,X
  STA r_ev+7              \ old left end
  LDA R_NDISCL,X          \ new left end (clamped to the window)
  CMP R_CL
  BCS e0
  LDA R_CL
.e0
  STA r_ev
  LDA R_NDX0,X            \ boundaries: new at r_ev+1, old at r_ev+8
  STA r_ev+1
  LDA R_NDX1,X
  STA r_ev+2
  LDA R_NDX2,X
  STA r_ev+3
  LDA R_NDX3,X
  STA r_ev+4
.^r_pt134 LDA r_bdx0,X
  STA r_ev+8
.^r_pt135 LDA r_bdx1,X
  STA r_ev+9
.^r_pt136 LDA r_bdx2,X
  STA r_ev+10
.^r_pt137 LDA r_bdx3,X
  STA r_ev+11
  LDA R_NDP,X
  AND #1
  STA r_np                \ (the colour at the left end, both sides)
  LDA R_NDN,X
  CMP #5
  BCS gen0
  STA r_cn
.^r_pt130 CMP r_bdn,X
  BEQ same
  BCC fewer
  SBC #1                  \ one more boundary than before
  LDA R_NDP,X
.^r_pt138 EOR r_bdp,X
  LSR A
  BCS moreL
.^r_pt139 LDA r_bdn,X     \ it came in at the right: old gets one at oR+1
  TAY
.^r_pt140 LDA r_sr,X
  INC A
  STA r_ev+8,Y
  BRA ends
.moreL
  LDY #3                  \ it came in at the left: old gets one at oL
.ml
  LDA r_ev+8,Y
  STA r_ev+9,Y
  DEY
  BPL ml
  LDA r_ev+7
  STA r_ev+8
  BRA ends
.same
  LDA R_NDP,X
.^r_pt141 EOR r_bdp,X
  LSR A
  BCC ends
.gen0
  JMP r_dpeg
.fewer
  INC A                   \ one fewer:
.^r_pt142 CMP r_bdn,X
  BNE gen0
  STA r_cn
  LDA R_NDP,X
.^r_pt143 EOR r_bdp,X
  LSR A
  BCS fewL
  LDY r_cn                \ it left at the right: new gets one at nR+1
  LDA R_NDISCR,X
  CMP R_CR
  BCC f1
  LDA R_CR
.f1
  INC A
  STA r_ev,Y
  BRA ends
.fewL
  LDA r_np                \ it left at the left: new gets one at nL, and
  EOR #1                  \ the left colour is the old one
  STA r_np
  LDY #3
.fl
  LDA r_ev+1,Y
  STA r_ev+2,Y
  DEY
  BPL fl
  LDA r_ev
  STA r_ev+1
.ends
  LDY r_cn
  INY                     \ Y = index of the right end (after them)
  LDA R_NDISCR,X          \ new right end (clamped)
  CMP R_CR
  BCC e1
  LDA R_CR
.e1
  CMP r_ev
  BCC gen
  INC A
  STA r_ev,Y
.^r_pt133 LDA r_sr,X
  INC A
  STA r_ev+7,Y
  STY r_ns                \ edges - 1
  LDA r_ev,Y              \ old and new spans apart (a gap between them): the
  CMP r_ev+7              \ strips would write into the gap, which r_drg (the
  BCC gen                 \ fallback after a partial write) doesn't cover
  LDA r_ev+7,Y
  CMP r_ev
  BCC gen
  TXA                     \ row pointers, colours
  AND #7
  STA RZ_PA
  STA RZ_PB
  TXA
  LSR A
  LSR A
  AND #&FE
  ORA #&40
  STA RZ_PA+1
  INC A
  STA RZ_PB+1
  TXA
  TAY
  JSR r_bcols
  LDA #&FF
  STA r_wmin
  STZ r_wmax
  STZ RZ_T6               \ strips must start at or after this (in order;
  LDY #0                  \ else r_dpeg: partial writes are harmless)
.st
  STY r_cl
  LDA r_ev+7,Y
  STA RZ_T0
  LDA r_ev,Y
  CMP RZ_T0
  BEQ eq
  BCC lt
  LDX RZ_T0               \ moved right: old .. new-1 take the colour left
  CPX RZ_T6               \ of the edge
  BCC gen
  STA RZ_T6
  DEC A
  STA RZ_TA+1
  STX RZ_SB
  DEY                     \ (colour index edge-1; the left end: black)
  BRA col
.eq
  CMP RZ_T6
  BCC gen
  STA RZ_T6
  BRA nx
.gen
  JMP r_dpeg
.lt
  CMP RZ_T6               \ moved left: new .. old-1 take the colour right
  BCC gen                 \ of the edge (the right end: black)
  STA RZ_SB
  LDX RZ_T0
  STX RZ_T6
  DEX
  STX RZ_TA+1
  CPY r_ns
  BNE col
  LDY #&FF
.col
  LDA #0                  \ colour index Y: -1 black, else P EOR (Y AND 1)
  CPY #&FF
  BEQ c2
  TYA
  EOR r_np
  LSR A
  LDA r_cA
  BCC c2
  LDA r_cB
.c2
  STA RZ_COL
  LDA RZ_SB
  CMP r_wmin
  BCS c3
  STA r_wmin
.c3
  LDA RZ_TA+1
  CMP r_wmax
  BCC c4
  STA r_wmax
.c4
  LDX RZ_SB
  LDY RZ_TA+1
  LDA RZ_COL
  JSR r_sw
.nx
  LDY r_cl
  INY
  CPY r_ns
  BCC st
  BEQ st
  LDX RZ_Y                \ remember the new row
  LDA r_ev
.^r_pt144 STA r_sl,X
  LDY r_ns
  LDA r_ev,Y
  DEC A
.^r_pt145 STA r_sr,X
  TXA
  TAY
  JSR r_bstore
  LDX RZ_Y
  TXA
  TAY
  LDA r_wmax
  BEQ none
  STA R_WR,Y
  LDA r_wmin
  STA R_WL,Y
  CPY r_wt
  BCS wz
  STY r_wt
.wz
  STY r_wb
.none
  RTS
}

\ r_dpgl: r_dpe's fallback (row RZ_Y, not dirty)
.r_dpgl
{
  LDY RZ_Y                \ not dirty: if the span did not shrink, repaint
.^r_pt150 LDA r_sl,Y        \ the new one segment by segment (no black)
  CMP #&FF
  BEQ none                \ (no old span: likewise, the row is black)
  STA r_oL
  LDA R_NDISCL,Y
  CMP R_CL
  BCS l1
  LDA R_CL
.l1
  CMP r_oL
  BEQ l2
  BCS full
.l2
  STA r_nL
  LDA R_NDISCR,Y
  CMP R_CR
  BCC r1
  LDA R_CR
.r1
  STA r_nR
.^r_pt151 CMP r_sr,Y
  BCC full
.paint
  LDA r_nR
  CMP r_nL
  BCC full
  JSR r_rowset
  JSR r_bcols
  LDA #&FF
  STA r_wmin
  STZ r_wmax
  JSR r_segw
  LDY RZ_Y
  LDA r_nL
.^r_pt152 STA r_sl,Y
  LDA r_nR
.^r_pt153 STA r_sr,Y
  JSR r_bstore
  LDA r_wmax
  BEQ x
  STA R_WR,Y
  LDA r_wmin
  STA R_WL,Y
.x
  RTS
.full
  JMP r_drg
.none
  LDA R_NDISCL,Y
  CMP R_CL
  BCS l3
  LDA R_CL
.l3
  STA r_nL
  LDA R_NDISCR,Y
  CMP R_CR
  BCC r3
  LDA R_CR
.r3
  STA r_nR
  BRA paint
}

\ r_bcols: Y = row: r_cA, r_cB = colour A, B bytes of the row (keeps X, Y)
.r_bcols
  TYA
  LSR A
  BCS bc1
  LDA R_DCE
  STA r_cA
  LDA R_DBE
  STA r_cB
  RTS
.bc1
  LDA R_DCO
  STA r_cA
  LDA R_DBO
  STA r_cB
  RTS

\ r_bstore: Y = row: remember the row's new boundaries (raw) in this buffer
.r_bstore
  LDA R_NDN,Y
  CMP #5
  BCC bs1
  LDA #4
.bs1
.^r_pt98 STA r_bdn,Y
  LDA R_NDP,Y
  AND #1
.^r_pt99 STA r_bdp,Y
  LDA R_NDX0,Y
.^r_pt100 STA r_bdx0,Y
  LDA R_NDX1,Y
.^r_pt101 STA r_bdx1,Y
  LDA R_NDX2,Y
.^r_pt102 STA r_bdx2,Y
  LDA R_NDX3,Y
.^r_pt103 STA r_bdx3,Y
  RTS

\ r_segw: r_drg with boundaries: the whole new span r_nL..r_nR, segment by
\ segment in colours A / B (row RZ_Y, r_cA/r_cB set)
.r_segw
{
  LDA r_nR
  CMP r_nL
  BCS go
  RTS
.go
  LDY RZ_Y
  LDA R_NDN,Y
  CMP #5
  BCC s1
  LDA #4
.s1
  STA r_cn
  LDA R_NDX0,Y
  STA r_bv
  LDA R_NDX1,Y
  STA r_bv+1
  LDA R_NDX2,Y
  STA r_bv+2
  LDA R_NDX3,Y
  STA r_bv+3
  LDA R_NDP,Y
  AND #1
  STA r_np                \ colour now
  LDA r_nL
  STA r_ba                \ segment start
  LDX #0
.lp
  CPX r_cn
  BCS last
  LDA r_bv,X
  CMP r_nL
  BEQ flip
  BCC flip
  CMP r_nR
  BEQ s2
  BCS last
.s2
  CMP r_ba
  BEQ flip                \ empty segment
  STX r_nn
  DEC A
  TAX
  JSR seg
  LDX r_nn
  LDA r_bv,X
  STA r_ba
.flip
  LDA r_np
  EOR #1
  STA r_np
  INX
  BRA lp
.last
  LDX r_nR
.seg                      \ r_ba .. X in colour r_np
  LDA r_np
  LSR A
  LDA r_cA
  BCC c1
  LDA r_cB
.c1
  STA RZ_COL
  LDA r_ba
  JMP r_dw
}

\ r_dp1: Y = row with dirty extent and no disc (old or new)


\ ============================================================================
\ r_wclear: R_WR[r_wt .. r_wb] = 0 (an unrolled STZ run entered at row r_wt,
\ stopped by an RTS planted after row r_wb).  Clobbers A, RZ_T0, RZ_T1.
\ ============================================================================
.r_wclear
{
  LDA r_wb
  CMP r_wt
  BCC none
  INC A                   \ the RTS goes at row wb + 1 (3 bytes a row)
  STA RZ_T0
  STZ RZ_T1
  ASL A
  ROL RZ_T1
  ADC RZ_T0
  STA RZ_T0
  LDA RZ_T1
  ADC #HI(r_wcrun)
  STA RZ_T1
  LDA RZ_T0
  CLC
  ADC #LO(r_wcrun)
  STA RZ_T0
  BCC p1
  INC RZ_T1
.p1
  LDA #&60
  STA (RZ_T0)
  LDA r_wt                \ enter at row wt
  STA ent+1
  STZ ent+2
  ASL A
  ROL ent+2
  ADC r_wt
  STA ent+1
  LDA ent+2
  ADC #HI(r_wcrun)
  STA ent+2
  LDA ent+1
  CLC
  ADC #LO(r_wcrun)
  STA ent+1
  BCC p2
  INC ent+2
.p2
.ent
  JSR &FFFF
  LDA #&9C                \ STZ abs
  STA (RZ_T0)
.none
  RTS
}
.r_wcrun
FOR y, 0, 191
  STZ R_WR + y
NEXT
  STZ r_wspare            \ row 192: where an RTS may be planted
  RTS
.r_wspare
  EQUB 0

\ r_dla: rows X .. A-1 with no dirty extent.  r_dlb: rows X .. A-1, any.
.r_dla
{
  STA end+1
  CPX end+1
  BCS done
.lp
  LDA R_NDISCL,X
.^r_pt26 CMP r_sl,X
  BNE ch
  LDA R_NDISCR,X
.^r_pt27 CMP r_sr,X
  BNE ch
.nx
  INX
.end
  CPX #0
  BNE lp
.done
  RTS
.ch
  JSR r_dp2
  LDX RZ_Y
  BRA nx
}

.r_dlb
{
  STA end+1
  CPX end+1
  BCS done
.lp
.^r_pt25 LDA r_dl,X
  INC A
  BNE gd                  \ dirty
  LDA R_NDISCL,X
.^r_pt54 CMP r_sl,X
  BNE ch
  LDA R_NDISCR,X
.^r_pt55 CMP r_sr,X
  BNE ch
.nx
  INX
.end
  CPX #0
  BNE lp
.done
  RTS
.ch
  JSR r_dp2
  LDX RZ_Y
  BRA nx
.gd
  TXA
  TAY
  LDA R_NDISCL,Y
.^r_pt45 AND r_sl,Y
  INC A
  BNE gg
  JSR r_dp1               \ no disc, old or new: black the dirty extent
  LDX RZ_Y
  BRA nx
.gg
  JSR r_drg
  LDX RZ_Y
  BRA nx
}

\ r_dp2: X = row, dirty empty, disc changed (one colour, R_DCE / R_DCO by
\ row parity).  The old span is intact, so only the difference between it
\ and the new one is written: pixels in the new span but not the old take
\ the disc colour, pixels in the old but not the new go black, each piece by
\ r_sw (masked at its end bytes, so the pieces can share bytes, and the
\ window's border columns keep their pixels).  At most two pieces: the two
\ ends' strips when the spans overlap, else the old span and the new one.
\ R_WL/R_WR = the bytes written (none: left as they are).
.r_dp2
{
  STX RZ_Y
  TXA                     \ row pointers
  AND #7
  STA RZ_PA
  STA RZ_PB
  LDA r_ypg,X
  STA RZ_PA+1
  INC A
  STA RZ_PB+1
  TXA
  LSR A
  LDA R_DCE
  BCC ev
  LDA R_DCO
.ev
  STA RZ_T5               \ the row's disc colour
  LDA #&FF
  STA r_wmin
  STZ r_wmax
.^r_pt50 LDA r_sl,X
  STA RZ_T0               \ oL
.^r_pt51 LDA r_sr,X
  STA RZ_T1               \ oR
  LDA R_NDISCL,X          \ nL, nR: clamped to the window (empty: 255, 0)
  CMP R_CL
  BCS c0
  LDA R_CL
.c0
  STA RZ_T2
  LDA R_NDISCR,X
  CMP R_CR
  BCC c1
  LDA R_CR
.c1
  STA RZ_T3
  CMP RZ_T2
  BCS c2
  LDA #&FF
  STA RZ_T2
  STZ RZ_T3
.c2
  LDA RZ_T2
.^r_pt53 STA r_sl,X
  LDA RZ_T3
.^r_pt52 STA r_sr,X
  LDA RZ_T1               \ old empty: the new span
  CMP RZ_T0
  BCC jonew
  LDA RZ_T3               \ new empty: the old span black
  CMP RZ_T2
  BCC joold
  LDA RZ_T3               \ apart (nR < oL or nL > oR): both
  CMP RZ_T0
  BCC jboth
  LDA RZ_T1
  CMP RZ_T2
  BCS ovl
.jboth
  JMP both
.jonew
  JMP onew
.joold
  JMP oold
.ovl
  LDA RZ_T2               \ overlapping: the left end (R_WL/R_WR noted here,
  CMP RZ_T0               \ the left end's strip before the right end's)
  BEQ right
  BCS lshr
  AND #&FC                \ grown: nL .. oL-1 in the disc colour
  STA r_wmin
  LDY RZ_T0
  DEY
  TYA
  ORA #3
  STA r_wmax
  LDX RZ_T2
  LDA RZ_T5
  JSR r_sw
  BRA right
.lshr
  DEC A                   \ shrunk: oL .. nL-1 black
  TAY
  ORA #3
  STA r_wmax
  LDA RZ_T0
  TAX
  AND #&FC
  STA r_wmin
  LDA #0
  JSR r_sw
.right
  LDA RZ_T3
  CMP RZ_T1
  BEQ fin
  BCC rshr
  ORA #3                  \ grown: oR+1 .. nR in the disc colour
  STA r_wmax
  LDX RZ_T1
  INX
  LDA r_wmin
  CMP #&FF
  BNE rg1
  TXA
  AND #&FC
  STA r_wmin
.rg1
  LDY RZ_T3
  LDA RZ_T5
  JSR r_sw
  BRA fin
.rshr
  INC A                   \ shrunk: nR+1 .. oR black
  TAX
  LDA r_wmin
  CMP #&FF
  BNE rs1
  TXA
  AND #&FC
  STA r_wmin
.rs1
  LDA RZ_T1
  TAY
  ORA #3
  STA r_wmax
  LDA #0
  JSR r_sw
  BRA fin
.both
  JSR oblk
.onew
  LDA RZ_T3
  CMP RZ_T2
  BCC fin
  LDX RZ_T2
  TAY
  LDA RZ_T5
  JSR put
  BRA fin
.oold
  JSR oblk
.fin
  LDA r_wmax              \ R_WL/R_WR: the bytes written
  BEQ none
  LDY RZ_Y
  STA R_WR,Y
  LDA r_wmin
  STA R_WL,Y
  CPY r_wt
  BCS w1
  STY r_wt
.w1
  STY r_wb                \ rows go upwards
.none
  RTS
.oblk                     \ the old span black
  LDX RZ_T0
  LDY RZ_T1
  LDA #0
.put                      \ pixels X .. Y in colour A (X <= Y), noted
  PHA
  TXA
  AND #&FC
  CMP r_wmin
  BCS p1
  STA r_wmin
.p1
  TYA
  ORA #3
  CMP r_wmax
  BCC p2
  STA r_wmax
.p2
  PLA
  JMP r_sw
}

\ r_drg: general disc row, Y = row
.r_drg
{
  JSR r_rowset
  LDA #&FF
  STA r_wmin
  STZ r_wmax
  TYA
  LSR A
  LDA R_DCE
  BCC e
  LDA R_DCO
.e
  STA r_dcol
  STZ r_segs
  LDA r_bon
  BEQ dn
  JSR r_bcols             \ boundaries: plain only if none, old and new,
  LDA R_NDN,Y             \ and the same colour
.^r_pt86 ORA r_bdn,Y
  BNE sg
  LDA R_NDP,Y
.^r_pt87 EOR r_bdp,Y
  LSR A
  BCS sg
  LDA R_NDP,Y
  LSR A
  LDA r_cA
  BCC sg1
  LDA r_cB
.sg1
  STA r_dcol
  BRA dn
.sg
  INC r_segs
.dn
.^r_pt17 LDA r_sl,Y
  STA r_oL
.^r_pt18 LDA r_sr,Y
  STA r_oR
.^r_pt19 LDA r_dl,Y
  STA r_dL
.^r_pt20 LDA r_dr,Y
  STA r_dR
  LDA R_NDISCL,Y
  CMP R_CL
  BCS n1
  LDA R_CL
.n1
  STA r_nL
  LDA R_NDISCR,Y
  CMP R_CR
  BCC n2
  LDA R_CR
.n2
  STA r_nR
  CMP r_nL
  BCS n3
  LDA #&FF
  STA r_nL
  STZ r_nR
.n3
.gen1
  \ intact = old - dirty (the larger piece)
  LDA r_oR
  CMP r_oL
  BCC iempty
  LDA r_dR
  CMP r_dL
  BCC iwhole
  LDA r_dR
  CMP r_oL
  BCC iwhole
  LDA r_oR
  CMP r_dL
  BCC iwhole
  LDA r_dL
  SEC
  SBC r_oL
  BCS i1
  LDA #0
.i1
  STA r_tl
  LDA r_oR
  SEC
  SBC r_dR
  BCS i2
  LDA #0
.i2
  CMP r_tl
  BEQ usel
  BCC usel
  LDX r_dR
  INX
  STX r_iL
  LDA r_oR
  STA r_iR
  BRA idone
.usel
  LDA r_tl
  BEQ iempty
  LDA r_oL
  STA r_iL
  LDX r_dL
  DEX
  STX r_iR
  BRA idone
.iwhole
  LDA r_oL
  STA r_iL
  LDA r_oR
  STA r_iR
  BRA idone
.iempty
  LDA #&FF
  STA r_iL
  STZ r_iR
.idone
  LDX r_dsub
  STZ r_dsub
  LDA r_segs
  BEQ dc0
  TXA                     \ span and boundaries unchanged (r_dmb): only the
  BEQ whole               \ dirty part of the span
  LDA r_nL
  PHA
  LDA r_nR
  PHA
  LDA r_dL
  CMP r_nL
  BCC sb1
  STA r_nL
.sb1
  LDA r_dR
  CMP r_nR
  BCS sb2
  STA r_nR
.sb2
  JSR r_segw
  PLA
  STA r_nR
  PLA
  STA r_nL
  JMP nodisc
.whole
  JSR r_segw              \ boundaries: repaint the whole new span
  JMP nodisc
.dc0
  \ disc colour on new - intact
  LDA r_nR
  CMP r_nL
  BCC nodisc
  LDA r_dcol
  STA RZ_COL
  LDA r_iR
  CMP r_iL
  BCC full
  LDA r_iR
  CMP r_nL
  BCC full
  LDA r_nR
  CMP r_iL
  BCC full
  LDA r_nL
  CMP r_iL
  BCS d2
  LDX r_iL
  DEX
  JSR r_dw
.d2
  LDA r_iR
  CMP r_nR
  BCS nodisc
  INC A
  LDX r_nR
  JSR r_dw
  BRA nodisc
.full
  LDA r_nL
  LDX r_nR
  JSR r_dw
.nodisc
  \ black on (old + dirty) - new
  STZ RZ_COL
  LDA r_oR
  CMP r_oL
  BCC oe
  LDA r_dR
  CMP r_dL
  BCC de
  LDX r_oR
  INX
  CPX r_dL
  BCC sep
  LDX r_dR
  INX
  CPX r_oL
  BCC sep
  LDA r_oL
  CMP r_dL
  BCC h1
  LDA r_dL
.h1
  STA r_ba
  LDA r_oR
  CMP r_dR
  BCS h2
  LDA r_dR
.h2
  STA r_bb
  JSR r_bmn
  BRA fin
.sep
  LDA r_dL
  STA r_ba
  LDA r_dR
  STA r_bb
  JSR r_bmn
.de
  LDA r_oL
  STA r_ba
  LDA r_oR
  STA r_bb
  JSR r_bmn
  BRA fin
.oe
  LDA r_dR
  CMP r_dL
  BCC fin
  LDA r_dL
  STA r_ba
  LDA r_dR
  STA r_bb
  JSR r_bmn
.fin
  LDY RZ_Y
  LDA r_nL
.^r_pt21 STA r_sl,Y
  LDA r_nR
.^r_pt22 STA r_sr,Y
  LDA #&FF
.^r_pt23 STA r_dl,Y
  LDA #0
.^r_pt24 STA r_dr,Y
  LDA r_bon
  BEQ nb1
  JSR r_bstore            \ remember this row's boundaries
  LDY RZ_Y
.nb1
  LDA r_wmax
  STA R_WR,Y
  BEQ nw
  LDA r_wmin
  STA R_WL,Y
  CPY r_wt
  BCS w1
  STY r_wt
.w1
  CPY r_wb
  BCC nw
  STY r_wb
.nw
  RTS
}

\ r_bmn: black on [r_ba, r_bb] minus [r_nL, r_nR]
.r_bmn
{
  LDA r_nR
  CMP r_nL
  BCC whole
  LDA r_nR
  CMP r_ba
  BCC whole
  LDA r_bb
  CMP r_nL
  BCC whole
  LDA r_ba
  CMP r_nL
  BCS b2
  LDX r_nL
  DEX
  JSR r_dw
.b2
  LDA r_nR
  CMP r_bb
  BCS done
  INC A
  LDX r_bb
  JMP r_dw
.whole
  LDA r_ba
  LDX r_bb
  JMP r_dw
.done
  RTS
}


\ r_dw: span A..X (A <= X) in RZ_COL on the row set up; tracks wmin/wmax
.r_dw
{
  STA R_XL
  STX R_XR
  CMP r_wmin
  BCS w1
  STA r_wmin
.w1
  CPX r_wmax
  BCC w2
  STX r_wmax
.w2
  LDX R_XL
  JMP r_spc
}

\ r_wlu: Y = row, A = xmin, X = xmax: WL/WR[y] |= [A, X]; extends r_wt/r_wb.
\ Keeps Y.

\ ============================================================================
\ R_WMERGE: WL/WR |= DIRTY[b] over the clip rows.
\ ============================================================================




\ ============================================================================
\ Cold entry points: the code is in bank 7 (raster7.asm)
\ ============================================================================
MACRO R_TO7 target
  LDX #LO(target)
  STX r_hzt7
  LDX #HI(target)
  STX r_hzt7+1
  JMP r_call7
ENDMACRO
\ r_clrrow: (for bank 7's R_CLEARALL) Y = row: black from CL to CR
.r_clrrow
  JSR r_rowset
  STZ RZ_COL
  LDA R_CL
  STA R_XL
  LDA R_CR
  STA R_XR
  LDX R_CL
  JMP r_spc
.R_INIT
  R_TO7 r7_init
.R_CLEARALL
  R_TO7 r7_clearall
.R_RESETBUF
  R_TO7 r7_resetbuf


\ ============================================================================
\ R_STARERASE: black the pixels R_STARPLOT set last time in this buffer.
\ Records: row (+&80: also the next byte), x, mask set in x's byte.
\ ============================================================================
.R_STARERASE
{
  LDX r_buf
  LDA r_scnt,X
  STA r_k
  STZ r_scnt,X
  LDX #0
  CPX r_k
  BCS edone
.el
.^r_pt30 LDA r_s0y,X      \ byte address (bit 7 of the high byte: one byte)
  STA RZ_PP
.^r_pt31 LDA r_s0x,X
  BMI e1
  STA RZ_PP+1
  LDA (RZ_PP)
.^r_pt32 AND r_s0a,X      \ inverse mask
  STA (RZ_PP)
.^r_pt33 LDA r_s0b,X
  CMP #&FF
  BEQ en
  LDY #8
  AND (RZ_PP),Y
  STA (RZ_PP),Y
  BRA en
.e1
  AND #&7F
  STA RZ_PP+1
  LDA (RZ_PP)
.^r_pt418 AND r_s0a,X
  STA (RZ_PP)
.en
  INX
  CPX r_k
  BCC el
.edone
  RTS
}

\ ============================================================================
\ Stars
\ ============================================================================

{
.sdone
  LDX r_buf
  LDA r_k
  STA r_scnt,X
  RTS
.slow
  STX RZ_SA               \ (X = x, Y = y on every branch here)
  STY RZ_SA+1
  JSR r_strow
  LDA RZ_TA
  CMP #3
  BCC sd1
  INC RZ_SA+1
  BEQ sd1
  JSR r_strow
.sd1
  LDX RZ_TA+1
  BRA snext
.^R_STARPLOT
  STZ r_k
  LDA R_CB
  INC A
  STA cb1+1
  LDA R_SN                \ star count (only ever 0 or 19, so <= 24)
  STA sl+1                \ (patched: the loop limit)
  LDX #&FF
.snext
  INX
.sl
  CPX #0                  \ (R_SN)
  BCS sdone
  LDA R_SS,X
  BEQ snext
.some
  STX RZ_TA+1
  STA RZ_TA
  LDY R_SY,X
  LDA R_SX,X
  TAX                     \ fast path: x .. x+1 inside the window, in one byte,
  CPX R_CL                \ the row(s) inside
  BCC slow
  CPX R_CR
  BCS slow
  CPY R_CT                \ (two pixels split across bytes, x AND 3 = 3 with
  BCC slow                \ size >= 2: caught by the mask being 0 at .two)
.cb1
  CPY #0                  \ (CB + 1)
  BCS slow
  LDA RZ_TA
  CMP #2                  \ size 1: one pixel; 2, 3: two
  BCS two
  LDA r_lm,X
  AND r_rm,X
.msk
  STA RZ_SB               \ the mask
.row
  TYA                     \ RZ_PP = byte of (x, y)
  AND #7
  ORA r_xo,X
  STA RZ_PP
  LDA r_ypg,Y
  CPX #&80
  ADC #0
  STA RZ_PP+1
  LDA (RZ_PP)             \ all black there?
  AND RZ_SB
  BNE nx
  LDX r_k                 \ (< 48 always: R_SN <= 24, <= 2 records a star)
  LDA R_SCOL
  AND RZ_SB
  ORA (RZ_PP)
  STA (RZ_PP)
  LDA RZ_PP
.^r_pt414 STA r_s0y,X
  LDA RZ_PP+1
  ORA #&80                \ (bit 7: no second byte)
.^r_pt415 STA r_s0x,X
  LDA RZ_SB
  EOR #&FF
.^r_pt416 STA r_s0a,X
  INC r_k
.nx
  LDA RZ_TA               \ size 3: the next row
  CMP #3
  BEQ third
  LDX RZ_TA+1             \ (snext inlined: INX, then the loop test)
  INX
  JMP sl
.third
  STZ RZ_TA
  LDX RZ_SA
  INY
  BRA row
.two
  BEQ two2                \ (Z from CMP #2: size 2)
  STX RZ_SA               \ (x for the second row at nx)
  CPY R_CB                \ size 3: the second row inside too? (y + 1 <= CB)
  BCS jslow
.two2
  LDA r_lm,X
  AND r_rm+1,X            \ two pixels: 0 only when split across bytes
  BNE msk                 \ (x AND 3 = 3: r_lm = &11, r_rm(x+1) = &88)
.jslow
  JMP slow
  SKIP 12                 \ (keeps r_strow onward, and r_ypg's page, in place)
}

\ one row of a star: row RZ_SA+1, pixel RZ_SA (and RZ_SA+1 if size >= 2).
\ Each of the (one or two) bytes it touches is set only if all its star
\ pixels there are black; the byte address and inverse masks are recorded.
.r_strow
{
  LDY RZ_SA+1
  CPY R_CT
  BCC o1
  CPY R_CB
  BEQ r1
  BCC r1
.o1
  RTS
.r1
  LDX RZ_SA
  STZ RZ_SB+1
  LDA RZ_TA
  CMP #2
  BCS two
  CPX R_CL                \ one pixel
  BCC o1
  CPX R_CR
  BEQ one
  BCS o1
.one
  LDA r_lm,X
  AND r_rm,X
  BRA mset
.two
  CPX R_CL                \ two pixels, both inside: the fast case
  BCC clip
  CPX R_CR
  BCS clip
  TXA
  AND #3
  CMP #3
  BEQ split
  LDA r_lm,X
  AND r_rm+1,X
  BRA mset
.split
  LDA #&88
  STA RZ_SB+1
  LDA #&11
  BRA mset
.clip
  STZ RZ_SB               \ general: pixel by pixel
  CPX R_CL
  BCC c2
  CPX R_CR
  BEQ c1
  BCS c2
.c1
  LDA r_lm,X
  AND r_rm,X
  STA RZ_SB
.c2
  INX
  BEQ c4
  CPX R_CL
  BCC c4
  CPX R_CR
  BEQ c3
  BCS c4
.c3
  LDA r_lm,X
  AND r_rm,X
  PHA
  TXA
  AND #3
  BEQ c5
  PLA
  ORA RZ_SB
  STA RZ_SB
  BRA c4
.c5
  PLA
  STA RZ_SB+1
.c4
  LDX RZ_SA
  LDA RZ_SB
  ORA RZ_SB+1
  BNE ms2
  RTS
.ms2
  LDA RZ_SB
.mset
  STA RZ_SB
  TYA                     \ RZ_PP = byte of (X, Y)
  AND #7
  ORA r_xo,X
  STA RZ_PP
  TYA
  LSR A
  LSR A
  AND #&FE
  ORA #&40
  CPX #&80
  ADC #0
  STA RZ_PP+1
  LDX r_k                 \ (record slot; X = x is in RZ_SA)
  CPX #48
  BCS o2
  LDA #&FF                \ byte A
  STA RZ_T0
  LDA RZ_SB
  BEQ ba
  AND (RZ_PP)
  BNE ba
  LDA R_SCOL
  AND RZ_SB
  ORA (RZ_PP)
  STA (RZ_PP)
  LDA RZ_SB
  EOR #&FF
  STA RZ_T0
.ba
  LDA #&FF                \ byte B (next column)
  LDY RZ_SB+1
  BEQ bb
  TYA
  LDY #8
  AND (RZ_PP),Y
  BNE bf
  LDA R_SCOL
  AND RZ_SB+1
  ORA (RZ_PP),Y
  STA (RZ_PP),Y
  LDA RZ_SB+1
  EOR #&FF
  BRA bb
.bf
  LDA #&FF
.bb
.^r_pt37 STA r_s0b,X
  AND RZ_T0
  CMP #&FF
  BEQ o2                  \ nothing set
  LDA RZ_PP
.^r_pt34 STA r_s0y,X
  LDA RZ_PP+1
.^r_pt35 STA r_s0x,X
  LDA RZ_T0
.^r_pt36 STA r_s0a,X
  INC r_k
.o2
  RTS
}

\ ============================================================================
\ R_LINE
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
  LDA #LO(r7_line)        \ (bank 7)
  LDX #HI(r7_line)
  JMP r_c7x
.slow0
  LDA R_X0+1              \ 8-bit end points: bank 7 (clipped)
  ORA R_X1+1
  ORA R_Y0+1
  ORA R_Y1+1
  BNE slow1
  LDA #LO(r7_linec)
  LDX #HI(r7_linec)
  JMP r_c7x
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
  LDX r_buf
  CMP r_dyb,X
  BCC yb2
  STA r_dyb,X
.yb2
  LDA RZ_T0
  CMP r_dyt,X
  BCS yno
  STA r_dyt,X
.yno
  LDA #LO(r7_lc16)        \ short lines: clipped exactly, drawn by bank 7
  LDX #HI(r7_lc16)
  JSR r_c7x
  CMP #0
  BNE yn1
  RTS
.yn1
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
  JMP r_pclip
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
  STA r_v0
  LDA r_dmaj+1
  ROL A
  STA r_e2maj+1
  STA r_v1
  LDA r_admin
  ASL A
  STA r_e2min
  LDA r_admin+1
  ROL A
  STA r_e2min+1
  LDA r_ilo
  ORA r_ilo+1
  BNE fullq
  STZ r_m0                \ starts in the window: q = 0, r = dmaj
  STZ r_m1
  LDA r_dmaj
  STA r_m2
  LDA r_dmaj+1
  STA r_m3
  BRA qdone
.fullq
  \ q, r = (2*ilo*admin + dmaj) / (2*dmaj)
  LDA r_ilo
  STA r_ma
  LDA r_ilo+1
  STA r_ma+1
  LDA r_admin
  STA r_mb
  LDA r_admin+1
  STA r_mb+1
  JSR r_mul16
  ASL r_m0
  ROL r_m1
  ROL r_m2
  ROL r_m3
  CLC
  LDA r_m0
  ADC r_dmaj
  STA r_m0
  LDA r_m1
  ADC r_dmaj+1
  STA r_m1
  BCC a1
  INC r_m2
  BNE a1
  INC r_m3
.a1
  JSR r_div32
.qdone
  LDA r_m2
  STA r_err
  LDA r_m3
  STA r_err+1
  LDA r_smin
  BMI qneg
  CLC
  LDA r_min0
  ADC r_m0
  STA r_cmin
  LDA r_min0+1
  ADC r_m1
  STA r_cmin+1
  BRA lp
.qneg
  SEC
  LDA r_min0
  SBC r_m0
  STA r_cmin
  LDA r_min0+1
  SBC r_m1
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
  JSR r_pset
  BRA step
.pym
  LDX r_cmin
  LDY r_cmaj
  JSR r_pset
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




\ r_lput2: pixels RZ_SB .. RZ_TA+1 of row RZ_Y in RZ_COL (row pointers set).
\ Clobbers A, X, Y.
.r_lput2
{
  LDA RZ_TA+1
  TAY                     \ Y = last pixel
  LDX RZ_SB               \ X = first
  EOR RZ_SB
  CMP #4
  BCS two
  LDA r_lm,X              \ one byte
  AND r_rm,Y
  STA RZ_T7
  LDY r_xo,X
  CPX #&80
  BCS h1
  LDA RZ_COL
  EOR (RZ_PA),Y
  AND RZ_T7
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
  RTS
.h1
  LDA RZ_COL
  EOR (RZ_PB),Y
  AND RZ_T7
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
  RTS
.two
  STY R_XR
  TYA                     \ adjacent bytes?
  AND #&FC
  STA RZ_T7
  TXA
  AND #&FC
  ADC #3                  \ (C = 1 from the CMP)
  CMP RZ_T7
  BNE long
  LDY r_xo,X              \ first byte: from X on
  CPX #&80
  BCS h2
  LDA RZ_COL
  EOR (RZ_PA),Y
  AND r_lm,X
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
  BRA s2
.h2
  LDA RZ_COL
  EOR (RZ_PB),Y
  AND r_lm,X
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
.s2
  LDX R_XR                \ second byte: up to the last
  LDY r_xo,X
  CPX #&80
  BCS h3
  LDA RZ_COL
  EOR (RZ_PA),Y
  AND r_rm,X
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
  RTS
.h3
  LDA RZ_COL
  EOR (RZ_PB),Y
  AND r_rm,X
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
  RTS
.long
  STX R_XL                \ up to 12 bytes: masked ends, whole bytes stored
  TYA                     \ through a byte pointer
  SEC
  SBC R_XL
  CMP #48
  BCS span
  LDA RZ_PP               \ (RZ_PP holds a planted RTS's address: keep it)
  PHA
  LDA RZ_PP+1
  PHA
  LDA r_xo,X
  ORA RZ_PA
  STA RZ_PP
  LDA RZ_PA+1
  CPX #&80
  ADC #0
  STA RZ_PP+1
  LDA RZ_COL              \ first byte: from X on
  EOR (RZ_PP)
  AND r_lm,X
  EOR (RZ_PP)
  STA (RZ_PP)
  LDA R_XR                \ whole bytes: last/4 - first/4 - 1
  LSR A
  LSR A
  STA RZ_T7
  TXA
  LSR A
  LSR A
  SEC
  SBC RZ_T7
  EOR #&FF
  TAY
  BEQ lb
.wl
  LDA RZ_PP
  CLC
  ADC #8
  STA RZ_PP
  BCC wl1
  INC RZ_PP+1
.wl1
  LDA RZ_COL
  STA (RZ_PP)
  DEY
  BNE wl
.lb
  LDA RZ_PP               \ last byte: up to the last pixel
  CLC
  ADC #8
  STA RZ_PP
  BCC lb1
  INC RZ_PP+1
.lb1
  LDX R_XR
  LDA RZ_COL
  EOR (RZ_PP)
  AND r_rm,X
  EOR (RZ_PP)
  STA (RZ_PP)
  PLA
  STA RZ_PP+1
  PLA
  STA RZ_PP
  RTS
.span
  LDY RZ_Y                \ a span (r_rowset for the run page)
  JSR r_rowset
  LDX R_XL
  JMP r_spc
}



.r_ypg                    \ high byte of row y's byte 0
FOR y, 0, 191
  EQUB &40 + 2 * (y DIV 8)
NEXT
.r_end
PRINT "raster.asm: ", r_end - r_start, " bytes from ", ~r_start, " to ", ~r_end
