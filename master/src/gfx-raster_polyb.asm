\ (gfx-raster_poly.asm's last part, R_POLY's phase A for 16-bit coordinates,
\ from rp_ov: its own file so that the Tube's parasite can place it apart,
\ resident, tube/src/p-poly.asm)

IF _TPART <> 2 OR _TDUMB = FALSE   \ (the dumb host: phase B only; phase A is the parasite's)
\ R_POLY's phase A for 16-bit coordinates: its variables (its 32-bit maths,
\ rp_mul16 and rp_div32, are in the shared region, gfx-raster.asm)
.rp_ov SKIP 13          \ phase A's edge set-up (r7_edy .. r7_er)
.r7_n EQUB 0            \ R_POLY's phase A (16-bit): vertices, top vertex,
.r7_top EQUB 0          \ y range, chain count, edge, side
.r7_yminL EQUB 0
.r7_yminH EQUB 0
.r7_ymaxL EQUB 0
.r7_ymaxH EQUB 0
.r7_cc EQUB 0
.r7_i0 EQUB 0
.r7_i1 EQUB 0

\ ============================================================================
\ R_POLY's phase A for polygons with some coordinate outside 0..255: chain A
\ into r_ta, chain B into r_tb, rows r_ystart..r_ylast (the shared workspace); bank
\ R_POLY calls r7_pf16 and does phase B (r_pcbd)
\ ============================================================================
\ phase A's edge set-up (rp_ov)
r7_edy = rp_ov + 0
r7_ek0 = rp_ov + 2
r7_ex0 = rp_ov + 4
r7_eadx = rp_ov + 6
r7_eneg = rp_ov + 8
r7_eq = rp_ov + 9
r7_er = rp_ov + 11
r7_ea = r7_eq           \ (a and b replace q and r: r7_esgen's ddone)
r7_eb = r7_er

IF OPTUBE = FALSE          \ (the Tube: p-onepass.asm's oe16 instead)
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
  JMP r7_go8s
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
  BPL st
.sw                       \ inside for good: the 8-bit DDA from row Y
  STA RZ_T0
  STY RZ_T3
  JMP r7_go8
  ASSERT HI(lp) = HI(sw)  \ (the rows' loop crosses no page)
}
ENDIF

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
IF OPTUBE
  JMP op_16               \ (the Tube: the one-pass generator, tube/src/p-onepass.asm)
ENDIF
}


\ ----------------------------------------------------------------------------
\ r7_pf16b: R_POLY with some coordinate outside 0..255 (rows r_ystart..r_ylast
\ already found).  Phase A as r_pf8 (chain A forward into r_ta, chain B
\ backward into r_tb) with 16-bit edges whose x is clamped into CL..CR+1 per
\ row; then bank 5's phase B (r_pcbd).
IF OPTUBE = FALSE          \ (the Tube: p-onepass.asm walks the chains)
\ ----------------------------------------------------------------------------
.r7_pf16b
{
  LDA R_CR
  INC A
  STA r_cr1
  LDA #LO(r_exr)          \ (the edges' exit: back here, r_exr)
  STA r_exj+1
  LDA #LO(r_ta)
  STA r_lsh_t+1
  STA r_lz_t+1
  STA r7_x16_t+1
  STA r7_x16_f+1
  LDA #HI(r_ta)
  STA r_lsh_t+2
  STA r_lz_t+2
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
  STA r_lsh_t+1
  STA r_lz_t+1
  STA r7_x16_t+1
  STA r7_x16_f+1
  LDA #HI(r_tb)
  STA r_lsh_t+2
  STA r_lz_t+2
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
ENDIF

\ ----------------------------------------------------------------------------
\ r7_esgen: set up edge r7_i0 -> r7_i1 (y1 > row >= y0) at row
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
  STA r_v0                \ (bank 5's r_div8, which uses r_v0 and r_m0)
  LDA r7_eadx
  JSR r_div8
  STA r7_er
  STZ r7_er+1
  LDA r_m0
  STA r7_eq
  STZ r7_eq+1
  BRA ddone
.d16
  LDA r7_eadx
  STA rp_m0
  LDA r7_eadx+1
  STA rp_m1
  STZ rp_m2
  STZ rp_m3
  LDA r7_edy
  STA rp_v0
  LDA r7_edy+1
  STA rp_v1
  JSR rp_div32
  LDA rp_m0
  STA r7_eq
  LDA rp_m1
  STA r7_eq+1
  LDA rp_m2
  STA r7_er
  LDA rp_m3
  STA r7_er+1
.ddone                    \ (a, b share q's and r's places: dx >= 0, a = q,
  LDA r7_eneg             \ b = r)
  BEQ abdone
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
  LDA r7_ek0
  ORA r7_ek0+1
  BNE k0nz
  LDA r7_ex0
  STA RZ_SA
  LDA r7_ex0+1
  STA RZ_SA+1
  STZ RZ_TA
  STZ RZ_TA+1
  RTS
.k0nz                     \ clipped start: q2, r2 = adx*k / dy
  LDA r7_eadx
  STA rp_ma
  LDA r7_eadx+1
  STA rp_ma+1
  LDA r7_ek0
  STA rp_mb
  LDA r7_ek0+1
  STA rp_mb+1
  JSR rp_mul16
  LDA r7_edy
  STA rp_v0
  LDA r7_edy+1
  STA rp_v1
  JSR rp_div32
  LDA r7_eneg
  BNE kneg
  LDA rp_m2
  ORA rp_m3
  BEQ kz
  SEC                     \ S = x0 + q2 + 1, t = dy - r2
  LDA r7_ex0
  ADC rp_m0
  STA RZ_SA
  LDA r7_ex0+1
  ADC rp_m1
  STA RZ_SA+1
  SEC
  LDA r7_edy
  SBC rp_m2
  STA RZ_TA
  LDA r7_edy+1
  SBC rp_m3
  STA RZ_TA+1
  RTS
.kz
  CLC                     \ S = x0 + q2, t = 0
  LDA r7_ex0
  ADC rp_m0
  STA RZ_SA
  LDA r7_ex0+1
  ADC rp_m1
  STA RZ_SA+1
  STZ RZ_TA
  STZ RZ_TA+1
  RTS
.kneg
  SEC                     \ S = x0 - q2, t = r2
  LDA r7_ex0
  SBC rp_m0
  STA RZ_SA
  LDA r7_ex0+1
  SBC rp_m1
  STA RZ_SA+1
  LDA rp_m2
  STA RZ_TA
  LDA rp_m3
  STA RZ_TA+1
  RTS
}
ENDIF
