\ ============================================================================
\ raster_poly.asm -- the rasteriser's polygon window: R_POLY (both phases;
\ phase A for 16-bit coordinates, r7_pf16, came from bank 7), in ANDY
\ (ROMSEL &85: ANDY over bank 5's &8000-&8FFF; bank 5's &9000-&BFFF, the
\ shared region gfx-raster.asm, stays visible: its arithmetic, r_div8,
\ r_dvq, rp_mul16 and rp_div32, is there).  The frame layer's T_POLY
\ pages it in.  R_SETBUF (shared) pages it in to patch phase B's DIRTY
\ operands.  INCLUDE it at &8000 in an assembly of its own (ANDY), after
\ gfx-raster.asm: it starts with phase B's rows, whose pb_ret is r_xw, the
\ row runs' exit.
\ ============================================================================

\       Area: kernel

IF _TPART <> 1             \ (Tube: phase B is the host's)
\ ----------------------------------------------------------------------------
\ Phase B: rows RZ_Y.., to the end row (pb_ye); left table r_pbl1, right
\ (exclusive) r_pbr1/r_pbr2.  Row pointers, the run page (pb_j_e+2,
\ pb_j_o+2, RZ_PP+1; RZ_PP = 190), RZ_CE/RZ_CO (this row pair's colours) and
\ RZ_XE/RZ_XO set.  Even rows take RZ_CE, odd rows RZ_CO; at each even row
\ (a new pair) pb_tg toggles both to the other pair (a 4-row dither).  A
\ row's whole bytes are stored by its character row's run, entered by a JMP
\ (r_spc's header has the entries) and left by its fixed exit, r_xw, which
\ is pb_ret here: a row makes no call.  The even rows' code reaches pb_ret
\ with C = 1, the odd rows' with C = 0.  pb_ret is the window's first byte.
\ (The Tube's hosts: each row's ends come from the parasite as it makes them,
\ p-emit.asm; r_xw is a JMP in the host's kernel that r_pcbs points here and
\ pb_end back at r_spret; a long row's H exit is pointed through operands of
\ the host's own, gfx-raster.asm's pb_lx_e and pb_lx_o; the Master host's
\ runs are one per line, each row's run page and bank are set as it starts,
\ and its run's index is 8 cl, with no line in it, h-sta.asm.)
\ ----------------------------------------------------------------------------
.pb_ret                   \ (= r_xw) back from the run: A = the row's colour,
  BIT R_XR                \ X = R_XR; N = (XR >= &80)
  BMI pb_rbx
  LDY r_xo,X              \ right edge
  EOR (RZ_PA),Y
  AND r_rm,X
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
  BCC pb_skip_o
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
IF _TDUMB AND _TPART = 2 AND _HOSTB = 0
  LDA s_pg,Y              \ (the Tube's Master host: the line's run's page and
  STA pb_j_o+2            \ bank)
  LDA s_bk,Y
  STA &FE30
ENDIF
IF _TPART = 2 AND _TDUMB   \ (the dumb host: the row's span from the parasite as it
.r_pbx_o                  \ makes it, p-emit.asm: left, then right exclusive; a
  BIT HR1S                \ left of &FF ends the polygon)
  BMI P%+5               \ (empty: the doorbell, tube/src/p-io.asm)
  JSR hrw
  LDX HR1D
  CPX #&FF
  BNE pbr_o
  JMP pb_end
.pbr_o
  BIT HR1S
  BMI P%+5               \ (empty: the doorbell, tube/src/p-io.asm)
  JSR hrw
  LDA HR1D
  DEC A
  STA R_XR
  CPX R_XR
  BEQ pb_d2_o
  BCS pb_skip_o+2         \ empty row (left > right): Y = RZ_Y already
ELSE
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
ENDIF
.pb_d2_o
  TXA
  EOR R_XR
  CMP #4
  BCC pb_one_o
  LDY r_xo,X
  CPX #&80
IF _TDUMB AND _TPART = 2 AND _HOSTB = 0
  BCC P%+5                \ (the Tube's Master host: out of a branch's reach)
  JMP pb_lb_o
ELSE
  BCS pb_lb_o
ENDIF
  LDA (RZ_PA),Y           \ left edge (C = 0 on)
  EOR RZ_CO
  AND r_lm,X
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
IF _TDUMB AND _TPART = 2 AND _HOSTB = 0
                          \ (the Tube's Master host: Y = 8 cl, the run's index)
ELSE
  TYA                     \ Y = 8 cl + line: the run's index
  ORA RZ_PA
  TAY
ENDIF
  LDA r_j,X               \ (C = 0) 255 - 3n, C = 0
  LDX R_XR
  SBC r_jm,X
  ADC #97                 \ L's store of column cl + n: 96 - 3n, C = 1 if n <= 32
  BCC pb_lng_o
.pb_go_o
  STA pb_j_o+1
  LDA RZ_CO
  CLC                     \ (pb_ret: an odd row)
.pb_j_o
  JMP &FF00               \ (the run's page) back at pb_ret
.pb_rbx                   \ right edge, columns 32..63 (C kept)
  LDY r_xo,X
  EOR (RZ_PB),Y
  AND r_rm,X
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
  BCS pb_skip_e
.pb_skip_o
  LDY RZ_Y
  INY
.pb_ye_o
  CPY #0                  \ (patched: the end row)
.pb_end_j                 \ (also BEQ pb_end_j from the even half: Z = 1)
  BEQ pb_end
.pb_c_o
  STY RZ_Y
IF _TDUMB AND _TPART = 2 AND _HOSTB = 0
  LDA s_pg,Y              \ (the Tube's Master host: the line's run's page and
  STA pb_j_e+2            \ bank)
  LDA s_bk,Y
  STA &FE30
ENDIF
  TYA                     \ RZ_PA/RZ_PB lo = row AND 7
  AND #7
  BEQ pb_cr               \ (pb_cr zeroes them itself)
  STA RZ_PA
  STA RZ_PB
  JMP pb_tg
IF _TPART <> 2
.pb_end
  RTS
ENDIF
.pb_one_o
  LDY r_xo,X
  CPX #&80                \ XL, XR differ only in bits 0-1 (XL EOR XR < 4)
  BCS pb_ob_o
  LDA (RZ_PA),Y
  EOR RZ_CO
  AND r_lm,X
  LDX R_XR
  AND r_rm,X
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
  BRA pb_skip_o
.pb_ob_o
  LDA (RZ_PB),Y
  EOR RZ_CO
  AND r_lm,X
  LDX R_XR
  AND r_rm,X
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
  BRA pb_skip_o
.pb_lb_o                  \ left edge, columns 32..63 (C = 1)
  LDA (RZ_PB),Y
  EOR RZ_CO
  AND r_lm,X
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
IF _TDUMB AND _TPART = 2 AND _HOSTB = 0
                          \ (the Tube's Master host: Y = 8 (cl - 32))
ELSE
  TYA                     \ Y = 8 (cl - 32) + line
  ORA RZ_PA
  TAY
ENDIF
  LDA r_jm,X              \ (C = 1) 253 - 3n, C = 0
  LDX R_XR
  SBC r_jm,X
  ADC #192                \ H's store of column cl + n: 189 - 3n (C = 1)
  BRA pb_go_o
.pb_lng_o                 \ (C = 0) A = 352 - 3n, n >= 33
  SBC #66                 \ H's store of column cl + n: 285 - 3n
  STA pb_j_o+1
IF _TPART = 2
  LDA pb_j_o+2            \ (the Tube's hosts: H's exit to pb_lx_o, which puts
  STA pb_lpo+2            \ it back and enters L; gfx-raster.asm)
  STA pb_lxp_o+2
  LDA #LO(pb_lx_o)
.pb_lpo
  STA &FF00 + 190
  LDA RZ_CO
  CLC
  JMP pb_j_o
ELSE
  LDA #LO(pb_lx_o)        \ H's exit to pb_lx_o, which puts it back and enters L
  STA (RZ_PP)
  LDA RZ_CO
  CLC
  BRA pb_j_o
ENDIF
IF _TPART = 2
.pb_end
  LDA #LO(r_spret)        \ (the Tube's hosts: the runs' exit back to r_spc's)
  STA r_xw+1
  LDA #HI(r_spret)
  STA r_xw+2
  RTS
ELSE
.pb_lx_o
  LDA #LO(r_xw)
  STA (RZ_PP)
  STZ pb_j_o+1
  LDA RZ_CO
  JMP pb_j_o
.pb_lx_e
  LDA #LO(r_xw)
  STA (RZ_PP)
  STZ pb_j_e+1
  LDA RZ_CE
  JMP pb_j_e
ENDIF
.pb_cr
  STZ RZ_PA               \ next character row: its run page
  STZ RZ_PB
  LDA RZ_PA+1
  CLC
  ADC #2
  STA RZ_PA+1
  INC A
  STA RZ_PB+1
IF _HOSTB
.^r_bs13                  \ (Model B: the buffer's run page for the row, Y = RZ_Y
  LDA r_rpy1,Y            \ still: r_rowset's)
  STA pb_j_e+2
  STA pb_j_o+2
ELIF _TPART <> 2
  INC RZ_PP+1
  INC pb_j_e+2
  INC pb_j_o+2            \ (Y = RZ_Y still)
ENDIF
.pb_tg                    \ (Y = RZ_Y) the next row pair's colours
  LDA RZ_CE
  EOR RZ_XE
  STA RZ_CE
  LDA RZ_CO
  EOR RZ_XO
  STA RZ_CO
IF _TPART = 2 AND _TDUMB   \ (the dumb host: the row's span from the parasite as it
.r_pbx_e                  \ makes it, p-emit.asm: left, then right exclusive; a
  BIT HR1S                \ left of &FF ends the polygon)
  BMI P%+5               \ (empty: the doorbell, tube/src/p-io.asm)
  JSR hrw
  LDX HR1D
  CPX #&FF
  BNE pbr_e
  JMP pb_end
.pbr_e
  BIT HR1S
  BMI P%+5               \ (empty: the doorbell, tube/src/p-io.asm)
  JSR hrw
  LDA HR1D
  DEC A
  STA R_XR
  CPX R_XR
  BEQ pb_d2_e
  BCS pb_emp_e            \ empty row (left > right)
ELSE
.r_pbx_e
.r_pbl1_e
  LDA &FFFF,Y
.r_pbr1_e
  CMP &FFFF,Y
  BCS pb_emp_e            \ empty row
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
ENDIF
.pb_d2_e
  TXA
  EOR R_XR
  CMP #4
  BCC pb_one_e
  LDY r_xo,X
  CPX #&80
  BCS pb_lb_e
  LDA (RZ_PA),Y           \ left edge (C = 0 on)
  EOR RZ_CE
  AND r_lm,X
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
IF _TDUMB AND _TPART = 2 AND _HOSTB = 0
                          \ (the Tube's Master host: Y = 8 cl, the run's index)
ELSE
  TYA                     \ Y = 8 cl + line: the run's index
  ORA RZ_PA
  TAY
ENDIF
  LDA r_j,X               \ (C = 0) 255 - 3n, C = 0
  LDX R_XR
  SBC r_jm,X
  ADC #97                 \ L's store of column cl + n: 96 - 3n, C = 1 if n <= 32
  BCC pb_lng_e
.pb_go_e
  STA pb_j_e+1
  LDA RZ_CE
.pb_j_e
  JMP &FF00               \ (the run's page) back at pb_ret, C = 1: an even row
.pb_lng_e                 \ (C = 0) A = 352 - 3n, n >= 33
  SBC #66                 \ H's store of column cl + n: 285 - 3n (C = 1)
  STA pb_j_e+1
IF _TPART = 2
  LDA pb_j_e+2            \ (the Tube's hosts: H's exit to pb_lx_e, which puts
  STA pb_lpe+2            \ it back and enters L; gfx-raster.asm)
  STA pb_lxp_e+2
  LDA #LO(pb_lx_e)
.pb_lpe
  STA &FF00 + 190
  LDA RZ_CE
  JMP pb_j_e
ELSE
  LDA #LO(pb_lx_e)        \ H's exit to pb_lx_e, which puts it back and enters L
  STA (RZ_PP)
  LDA RZ_CE
  BRA pb_j_e
ENDIF
.pb_lb_e                  \ left edge, columns 32..63 (C = 1)
  LDA (RZ_PB),Y
  EOR RZ_CE
  AND r_lm,X
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
IF _TDUMB AND _TPART = 2 AND _HOSTB = 0
                          \ (the Tube's Master host: Y = 8 (cl - 32))
ELSE
  TYA                     \ Y = 8 (cl - 32) + line
  ORA RZ_PA
  TAY
ENDIF
  LDA r_jm,X              \ (C = 1) 253 - 3n, C = 0
  LDX R_XR
  SBC r_jm,X
  ADC #192                \ H's store of column cl + n: 189 - 3n (C = 1)
  BRA pb_go_e
.pb_emp_e
  JMP pb_skip_e+2         \ (Y = RZ_Y already: past the LDY RZ_Y)
.pb_one_e
  LDY r_xo,X
  LDA r_lm,X
  LDX R_XR
  AND r_rm,X
  STA RZ_T7
  CPX #&80
  BCS pb_ob_e
  LDA (RZ_PA),Y
  EOR RZ_CE
  AND RZ_T7
  EOR (RZ_PA),Y
  STA (RZ_PA),Y
  JMP pb_skip_e
.pb_ob_e
  LDA (RZ_PB),Y
  EOR RZ_CE
  AND RZ_T7
  EOR (RZ_PB),Y
  STA (RZ_PB),Y
  JMP pb_skip_e
IF _TPART <> 2
ASSERT pb_ret = r_xw
ASSERT HI(pb_lx_e) = HI(r_xw) AND HI(pb_lx_o) = HI(r_xw)   \ (a long row's H exit:
                          \ its low byte changed)
ENDIF
ENDIF

\       Area: ovl S

IF _TPART <> 2 OR _TDUMB = FALSE   \ (the dumb host: phase B only; phase A is the parasite's)
\ ============================================================================
\ R_POLY
\ ============================================================================
.R_POLY
{
IF _TPART <> 1
  STZ F_DROK              \ (its edge tables are R_NDISCL/R: f_discspans' rows
ENDIF                     \ are not kept; the Tube's are R_NDX2/3, p-poly.asm)
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
  TAX
  BNE p16
IF OPTUBE
  JSR r_pf8               \ (the Tube: r_pf8's set-up, then one pass, each row's span
  JMP p_spend             \ to the host as it is made: tube/src/p-onepass.asm,
.p16                      \ tube/src/p-emit.asm; the same for 16-bit polygons
  JSR r7_pf16             \ after r7_pf16's set-up)
  JMP p_spend
.^r_pout                  \ (r_pf8's: no rows)
  RTS
ELSE
  JMP r_pf8
.p16                      \ some coordinate outside 0..255: phase A (r7_pf16)
  JSR r7_pf16
  CMP #0                  \ (A = 0: nothing to draw)
  BEQ r_pout
  JMP r_pcbd
.^r_pout                  \ (also r_pf8's: no rows)
  RTS
ENDIF
}

\ ============================================================================
\ R_POLY 8-bit path: every vertex x, y in 0..255.
\ Phase A walks both chains from the top vertex, running each edge's exact
\ DDA (x = x0 + ceil(dx*k/dy)) down a per-row table: chain A (forward) into
\ r_ta, chain B (backward) into r_tb.  Phase B fills each row from the left
\ table to the right one (exclusive), its whole bytes through the character
\ row's run.
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
  BCS r_pout
  CMP R_CB
  BEQ y2
  BCS r_pout
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
IF OPTUBE
  JMP op_8                \ (the Tube: the one-pass generator from here; its
}                         \ edges' set-up, r_e8, is resident: p-poly.asm)
ELSE
  \ chain A: forward into r_ta
  LDA #LO(r_ta)
  STA r_lsh_t+1
  STA r_lz_t+1
  DEC A
  STA RZ_T5               \ (the steep loops' table's low byte, less 1)
  LDA #HI(r_ta)
  STA r_lsh_t+2
  STA r_lz_t+2
  STA r_sp_t+2
  STA r_sn_t+2
  LDA #LO(ca)             \ (the edges' exit: ca, cb and r_exr share a page)
  STA r_exj+1
  LDX r_top
  BRA ca
.cad
  \ chain B: backward into r_tb
  LDA #LO(r_tb)
  STA r_lsh_t+1
  STA r_lz_t+1
  DEC A
  STA RZ_T5
  LDA #HI(r_tb)
  STA r_lsh_t+2
  STA r_lz_t+2
  STA r_sp_t+2
  STA r_sn_t+2
  LDA #LO(cb)
  STA r_exj+1
  LDX r_top
.cb
  LDA R_PYL,X
  CMP r_ymaxL
  BEQ cbd
  TXA
  TAY                     \ Y = i0
  DEX
  BPL cb1
  LDX r_n
  DEX
.cb1
  STX r_i1
  JMP r_e8
.cbd
  JMP r_pcbd
ENDIF
ENDIF

\       Area: frame

IF _TPART <> 2 OR _TDUMB = FALSE
IF OPTUBE
{
.^r_ex                    \ (the Tube: an edge with no rows, back from fedge,
  SEC                     \ p-onepass.asm, with C = 1)
  RTS
ELSE
.^r_ex                    \ an edge is done: on along its chain (or, for the
  LDX r_i1                \ 16-bit path, back to r7_pf16b: r_exr)
.^r_exj
  JMP ca                  \ (its low byte patched: ca, cb or r_exr)
.^r_exr
  RTS
ENDIF
.cl                       \ y0 < ystart: out if the end row <= ystart, else
  LDA r_ystart            \ clipped
  CMP RZ_T2
  BCS r_ex
  JMP clipped
IF OPTUBE = FALSE
.ca                       \ (from the top vertex, a vertex at ymax, the
  LDA R_PYL,X             \ largest of the vertices' y, comes within n - 1
  CMP r_ymaxL             \ edges either way: no count is needed)
  BEQ cad
  TXA
  TAY                     \ Y = i0
  INX
  CPX r_n
  BCC ca1
  LDX #0
.ca1
  STX r_i1
  ASSERT HI(ca) = HI(r_exj) AND HI(cb) = HI(r_exj) AND HI(r_exr) = HI(r_exj)
ENDIF

\ r_e8: the edge from vertex Y (i0) to vertex X (i1 = r_i1) of an 8-bit
\ polygon into the chain's table, then r_ex.  Its set-up is in line in its
\ chain (chain A falls into it, chain B jumps), the division is reached and
\ left by jumps (r_pdiv, in the shared region; the sign of dx kept in Y's
\ bit 7), and the DDA loops end with a jump back to the chain: an edge
\ makes no call unless it starts above the window (r7_esgen) or has a
\ quotient of 16 or more with a divisor under 16 (r_div8b).  There are four loops: r_lz (no remainder: x += a a row),
\ r_lsh (x += a, the error -= b, and on a borrow += dy, x += 1) and a steep
\ edge's own, r_sp (dx > 0) and r_sn (dx < 0), with x in X and the error
\ in A.  (The Tube's
\ parasite: its one-pass generator jumps here from fedge, p-onepass.asm, with
\ Y = r_i0, X = r_i1, and r_e8 leaves it at r_ex with C = 1 (no rows) or
\ through fz or fsh, which load the side's DDA in the row loop, with C = 0:
\ its DDA loops are not assembled.)
.^r_e8
  LDA R_PYL,X
  CMP R_PYL,Y
  BCC r_ex
  BEQ r_ex                \ not going down
  CMP r_yend
  BCC e1
  LDA r_yend
.e1
  STA RZ_T2               \ end row (exclusive)
  LDA R_PYL,Y
  CMP RZ_T2
  BCS r_ex                \ y0 >= end row
  CMP r_ystart
  BCC cl                  \ y0 < ystart (if y0 >= ystart then RZ_T2 > y0 >= ystart)
  STA RZ_T3               \ start row (A = y0, C = 1)
  EOR #&FF
  ADC R_PYL,X             \ dy = y1 - y0; C stays 1 (y1 > y0)
  STA RZ_T1               \ dy
  LDA R_PXL,Y
  STA RZ_T0               \ S = x0
  EOR #&FF
  ADC R_PXL,X             \ dx = x1 - x0, C = (x1 >= x0)
  BCS pos
  EOR #&FF
  ADC #1                  \ |dx| (C = 0 here)
  LDY #&80                \ (Y's bit 7: dx < 0; i0 has it clear)
.pos
  CMP RZ_T1
  BCC steep
  JMP r_pdiv              \ (the division, in the shared region: gfx-raster.asm;
.steep                    \ it comes back at r_prnz or r_prz)
IF OPTUBE
  TAX                     \ steep: q = 0, r = |dx| (vertical: r = 0; the Tube's
  BEQ r_prz               \ one-pass generator has the steep edges' own steps,
  LDX #0                  \ fload, tube/src/p-onepass.asm)
ELSE
  TAX                     \ steep: q = 0, r = |dx|
  BNE st
  STX r_lz_a+1            \ vertical: the loop with no remainder, a = 0
  JMP r_lzgo
.st
  CPY #&80
  BCS sneg
  STX r_sp_b+1            \ dx > 0: each row the error -= |dx|, and on a borrow
  LDA RZ_T1               \ += dy, x += 1
  STA r_sp_d+1
  SEC                     \ Y = the rows: the end row - the first (C = 1 after)
  LDA RZ_T2
  SBC RZ_T3
  TAY
  LDA RZ_T3               \ the table's first row
  ADC RZ_T5
  STA r_sp_t+1
  LDX RZ_T0
  LDA #0
  SEC
.r_sp                     \ X = x, A = the error, Y = rows to go, C = 1
.r_sp_t
  STX &FF00               \ (the table's row: its low byte counts up)
  INC r_sp_t+1
.r_sp_b
  SBC #0                  \ |dx|
  BCS sp1
.r_sp_d
  ADC #0                  \ dy (C = 0, then 1)
  INX
.sp1
  DEY
  BNE r_sp
  ASSERT HI(P%) = HI(r_sp)
  JMP r_ex
.sneg                     \ dx < 0: each row the error -= dy - |dx|, and x -= 1
  EOR #&FF                \ unless it borrows (then the error += dy)
  ADC RZ_T1               \ (C = 1: dy - |dx|)
  STA r_sn_b+1
  LDA RZ_T1
  STA r_sn_d+1
  SEC                     \ (as above)
  LDA RZ_T2
  SBC RZ_T3
  TAY
  LDA RZ_T3
  ADC RZ_T5
  STA r_sn_t+1
  LDX RZ_T0
  LDA #0
  SEC
.r_sn                     \ X = x, A = the error, Y = rows to go, C = 1
.r_sn_t
  STX &FF00               \ (the table's row: its low byte counts up)
  INC r_sn_t+1
.r_sn_b
  SBC #0                  \ dy - |dx|
  BCC sn1
  DEX
  DEY
  BNE r_sn
  JMP r_ex
.sn1
.r_sn_d
  ADC #0                  \ dy (C = 0, then 1)
  DEY
  BNE r_sn
  ASSERT HI(P%) = HI(r_sn)
  JMP r_ex
ENDIF
\ x = x0 + ceil(dx * k / dy) per row: x += a, the error -= b, and on a
\ borrow the error += dy, x += 1, with a = floor(dx / dy), b = dx - a * dy
.^r_prnz                  \ the remainder is not 0: X = q, A = r
IF OPTUBE
  STZ RZ_TA               \ (the Tube: the error 0, then fsh: A = a, X = b)
  CPY #&80
  BCC prp
  EOR #&FF                \ dx < 0: b = dy - r, a = NOT q (C = 1)
  ADC RZ_T1
  STA RZ_T6
  TXA
  EOR #&FF
  LDX RZ_T6
  JMP fsh
.prp
  STA RZ_T6               \ dx > 0: a = q, b = r
  TXA
  LDX RZ_T6
  JMP fsh
ELSE
  CPY #&80
  BCS nr
  TAY                     \ dx > 0: a = q, b = r (the loop's operands hold
  DEY                     \ a - 1 and b - 1)
  STY r_lsh_b+1
  DEX
  STX r_lsh_a+1
  BCC lsh0                \ (always: from the CPY)
.nr                       \ dx < 0: a = NOT q, b = dy - r (C = 1)
  SBC RZ_T1               \ r - dy = -b: NOT it is b - 1
  EOR #&FF
  STA r_lsh_b+1
  TXA
  EOR #&FF
  SBC #0                  \ (C = 0: - 1)
  STA r_lsh_a+1
.lsh0
  STZ RZ_TA               \ the error
  BRA r_lshgo
ENDIF
.^r_prz                   \ the remainder is 0: X = q; a = q, or -q for dx < 0
  CPY #&80
  BCC rzp
  TXA
  EOR #&FF
  ADC #0                  \ (C = 1: + 1)
  TAX
.rzp
IF OPTUBE
  TXA                     \ (the Tube: fz, A = a)
  JMP fz
ELSE
  STX r_lz_a+1
  BRA r_lzgo
ENDIF
.clipped                  \ starts above the window: r7_esgen's general set-up
  STA RZ_Y                \ at ystart (A)
  STA RZ_T3
  JSR r7_esgen            \ (Y = i0, X = i1: S, t -> RZ_SA, RZ_TA; a, b, dy
.^r7_go8s                 \ -> r7_ea, r7_eb, r7_edy)
  LDA RZ_SA
  STA RZ_T0
.^r7_go8                  \ the 8-bit DDA with r7_esgen's a, b and dy from row
  LDA r7_edy              \ RZ_T3 (RZ_T0 = S, RZ_TA = t; also r7_e16's)
  STA RZ_T1
  LDA r7_ea
  LDX r7_eb
  BNE r_psh1
\ b = 0: A = a  (falls into r_lz)
.r_pzl1
IF OPTUBE                 \ (the Tube's one-pass generator loads the side's DDA
  JMP fz                  \ instead: tube/src/p-onepass.asm; no tables)
ELSE
IF ONEPASS                \ (the one-pass generator loads the DDA instead,
  BIT fdiv                \ gfx-raster_onepass.asm)
  BPL zl0
  JMP fz
.zl0
ENDIF
  STA r_lz_a+1
.r_lzgo
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
  ASSERT HI(P%) = HI(r_lz)   \ (the loops cross no page)
  JMP r_ex
ENDIF
\ shallow: X = b, A = a, RZ_TA = the error
.r_psh1
IF OPTUBE
  JMP fsh
ELSE
IF ONEPASS
  BIT fdiv
  BPL sh0
  JMP fsh
.sh0
ENDIF
  DEC A
  STA r_lsh_a+1
  DEX
  STX r_lsh_b+1
.r_lshgo
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
  ASSERT HI(P%) = HI(r_lsh)
  JMP r_ex
ENDIF
}
ENDIF

IF _TPART <> 1
\ ----------------------------------------------------------------------------
\ r_pcbd: both chains' tables are made (phase A): the rows, then phase B
\ (the Tube's hosts: r_pcbs, the rows come one by one from the parasite,
\ already clipped)
\ ----------------------------------------------------------------------------
{
IF _TDUMB = FALSE
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
  LDX R_PRBUF
  LDA r_ystart
  CMP R_PRDYT,X
  BCS d1
  STA R_PRDYT,X
.d1
  LDA r_ylast
  CMP R_PRDYB,X
  BCC d2
  STA R_PRDYB,X
.d2
  BIT KMODE               \ K mode: the kept rows' pass (gfx-raster_kept.asm)
  BPL d3
  LDA r_pbl1_e+1
  JSR T_KPRE              \ (the glue area: k_pre in bank 7)
.d3
ELSE
.^r_pcbs                  \ (the dumb host: C_SPANS, rows from r_ystart, each read
  LDA #R_ROWS             \ from the parasite in phase B's loop until its end mark,
  STA r_yend              \ or past row 191, which has none: h-main.asm)
ENDIF
  \ phase B set-up
  LDY r_ystart
  JSR r_rowset            \ (A = the run page)
  STA pb_j_e+2
  STA pb_j_o+2
IF _TPART = 2
  LDA #LO(pb_ret)         \ (the Tube's hosts: the runs' exit to phase B's, until
  STA r_xw+1              \ pb_end)
  LDA #HI(pb_ret)
  STA r_xw+2
ELSE
  STA RZ_PP+1             \ RZ_PP: the run's H exit operand, for a long row
  LDA #190
  STA RZ_PP
ENDIF
  LDA r_yend
  STA pb_ye_e+1
  STA pb_ye_o+1
  LDA R_COLE              \ rows 4k, 4k+1 take COLE, COLO; rows 4k+2, 4k+3
  EOR R_COL2              \ COL2, COL3: RZ_CE/RZ_CO = this row pair's, toggled
  STA RZ_XE               \ by RZ_XE/RZ_XO at each pair
  LDA R_COLO
  EOR R_COL3
  STA RZ_XO
  TYA
  AND #2
  BEQ p01
  LDA R_COL2
  LDX R_COL3
  BRA pc
.p01
  LDA R_COLE
  LDX R_COLO
.pc
  STA RZ_CE
  STX RZ_CO
  TYA
  LSR A
  BCC ev
IF _TDUMB AND _TPART = 2 AND _HOSTB = 0
  JMP s_pbxo              \ (the Tube's Master host: the line's bank in, h-sta.asm)
ELSE
  JMP r_pbx_o             \ odd first row (Y = RZ_Y)
ENDIF
.ev
IF _TDUMB AND _TPART = 2 AND _HOSTB = 0
  JMP s_pbxe
ELSE
  JMP r_pbx_e             \ even first row
ENDIF
IF _TDUMB = FALSE
.otab
  EQUW r_ta, r_tb, r_ta
ENDIF
}
ENDIF



IF _TPART <> 1
IF _TDUMB AND _TPART = 2 AND _HOSTB = 0     \ (the Tube's Master host: its own place's pass;
 INCLUDE "build/gfx-raster_polyb-frame.asm"        \ phase B is in the kernel, h-layout.asm)
ELSE
 INCLUDE "src/gfx-raster_polyb.asm"
ENDIF
ENDIF
