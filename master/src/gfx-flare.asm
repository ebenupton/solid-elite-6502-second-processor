\ ******************************************************************************
\
\ gfx-flare.asm - the lens flare (docs/MASTER-PLAN.md, "Lens flare"): the
\ part in shadow RAM, run with ACCCON X = 1
\
\ From the demo port's lens flare (src/flare*.asm, docs/FLARE.md and the
\ model tools/flare.py there), with the same recipe, arithmetic and pixels.
\ When SUN has drawn the sun this frame, in the front view, with its centre on
\ the screen (x 1..255, y 0..191) and not inside the planet's disc, eight
\ ghosts go over the frame after the lasers and before the text, sights and
\ stars: at C + k D / 8 (C = (128, 96), D = sun - C), six dithered discs and
\ two dotted rings, each pixel of a disc's 4x4 Bayer mask (its density, rows
\ shifted by the ghost's number) ORed in its ink. OR only lifts MODE 1's
\ two-bit inks (K = 00 < C = 01, M = 10 < Y = 11): additive light in this
\ palette. Three levels by |dx| + |dy| step every density down the ladder 0,
\ 1, 2, 4, 6, 8 / 16.
\
\ Every span extends this buffer's dirty extent for its row, and the rows'
\ range goes to R_MARKDIRTY, so the next frame on this buffer repairs it as
\ after any shape (the disc rows repainted, the rest blacked, the text and
\ sights redrawn over it): the flare keeps no state on the screen.
\
\ Memory (the Master port's banks have no room for it): this file is in
\ shadow RAM, which the loader fills from FLARE7, FLARE3 and FLARE0: &7E00-
\ &7FFF (not displayed: the screen ends at &7DFF), &3F00-&3FFF (after the
\ extended tokens) and &3000-&308F (below setzp's zero page save). The frame
\ layer's f_flt (gfx-flare6.asm, bank 6) sets ACCCON X around FL_MAIN, and
\ fl_or (bank 6 too) does the writing, as the back buffer may be main RAM
\ (buffer 0: ACCCON X = 0 while it writes). Everything this code reads is in
\ bank 6 (paged throughout the frame), HAZEL, the zero page or main RAM below
\ &3000.
\
\ ******************************************************************************

\ (Its zero page is defined in gfx-flare6.asm, assembled first.)

\ ------------------------------------------------------------------------------
\ Shadow &7E00-&7FFF: the flare's frame step, the ghosts' centres, a disc
\ ------------------------------------------------------------------------------

ORG &7E00

\ fl_pd: X = 0: |F_SUX - F_PLX|, X = 2: |F_SUY - F_PLY| in Y, with Z = 1 if
\ it is below 256 (Z = 0: further apart)

.fl_pd
 LDA F_SUX,X
 SEC
 SBC F_PLX,X
 TAY
 LDA F_SUX+1,X
 SBC F_PLX+1,X
 BEQ fl_ret             \ 0..255
 INC A
 BNE fl_ret             \ (not -256..-1: Z = 0)
 TYA                    \ -255..-1: Y = - low byte (-256: Z = 0)
 BEQ fpq8
 EOR #&FF
 TAY
 INY
 LDA #0
.fl_ret
 RTS
.fpq8
 DEC A
 RTS

\ FL_MAIN: the flare over this frame, if any (from f_flt, with ACCCON X = 1
\ and the sun drawn this frame). Leaves fl_xb for f_flt.

.FL_MAIN
 LDA F_BACK             \ fl_xb: 4 when the back buffer is main RAM (0)
 EOR #1
 ASL A
 ASL A
 STA fl_xb
 LDA VIEW               \ the front view, and the sun's centre on the
 ORA F_SUX+1            \ screen: x 1..255, y 0..191
 ORA F_SUY+1
 BNE fl_ret
 LDA F_SUX
 BEQ fl_ret
 EOR #&80
 STA fl_dx
 LDA F_SUY
 CMP #192
 BCS fl_ret
 SBC #95                \ (C = 0: - 96)
 STA fl_dy
 LDA F_PLON             \ behind the planet? (inside its disc: F_HW has the
 BEQ flm1               \ planet's half-widths, built this frame)
 LDX #2
 JSR fl_pd              \ |sy - py|
 BNE flm1
 CPY F_PLR
 BEQ P%+4
 BCS flm1
 LDA F_HW,Y
 STA fl_t
 LDX #0
 JSR fl_pd              \ |sx - px|
 BNE flm1
 CPY fl_t
 BCC fl_ret
 BEQ fl_ret
.flm1
 LDA fl_dx              \ level 3 if |dx| + |dy| < 96, 2 if < 192, else 1
 JSR fl_abs
 STA fl_t
 LDA fl_dy
 JSR fl_abs
 CLC
 ADC fl_t
 LDX #3
 CMP #96
 BCC flm2
 DEX
 CMP #192
 BCC flm2
 DEX
.flm2
 STX fl_lev
 LDA fsw_d1+2           \ this buffer's dirty extents (f_bufpatch)
 STA fl_dl1+2
 STA fl_dl2+2
 LDA fsw_d2+2
 STA fl_dr1+2
 STA fl_dr2+2
 LDA #255
 STA fl_ymin
 STZ fl_ymax
 LDX #1                 \ the centres' sums (x, then y): S = 32 k D, k = 8
.flm0                   \ to start (S = 256 D), stepped down by 32 D (|S| <
 LDA fl_dx,X            \ 2^15: the centre's offset k D / 8, floored, is S's
 STA fl_sh,X            \ high byte)
 STZ fl_sl,X
 CMP #&80               \ 32 D: D >> 3 (arithmetic), (D AND 7) << 5
 ROR A
 CMP #&80
 ROR A
 CMP #&80
 ROR A
 STA fl_mh,X
 LDA fl_dx,X
 AND #7
 LSR A
 ROR A
 ROR A
 ROR A
 STA fl_ml,X
 DEX
 BPL flm0
 STZ fl_i
 BRA flm3

.flm9
 LDY fl_ymin            \ the rows written, for the repair's row range
 CPY fl_ymax
 BEQ P%+4
 BCS fl_rts
 LDA #255               \ (an empty extent: only the row range grows)
 STA R_XL
 STZ R_XR
 JSR T_MARKDIRTY
 LDY fl_ymax
 JMP T_MARKDIRTY
.fl_rts
 RTS

.flm8                   \ the sums for the next ghost: S -= (k - k') 32 D
 LDY fl_dk,X
 PHX
.flc1
 LDX #1
.flc2
 SEC
 LDA fl_sl,X
 SBC fl_ml,X
 STA fl_sl,X
 LDA fl_sh,X
 SBC fl_mh,X
 STA fl_sh,X
 DEX
 BPL flc2
 DEY
 BNE flc1
 PLX
 BRA flm4

.flm3                   \ the next ghost
 LDX fl_i
 CPX #FLNG
 BCS flm9
 INC fl_i
 TXA                    \ k = 8: the ring round the sun, if the sun is small
 BNE flm8
 LDA GSUNR
 CMP #FLHMAX+1
 BCS flm3
.flm4
 LDA fl_ni,X            \ density index + level - 3 (none if 0 or less)
 AND #&7F
 CLC
 ADC fl_lev
 SBC #2                 \ (C = 0: - 3)
 BEQ flm3
 BMI flm3
 STA fl_m
 LDA fl_sh              \ centre = (128, 96) + (k D) >> 3
 EOR #&80
 STA fl_gx
 LDA fl_sh+1
 CLC
 ADC #96
 STA fl_gy
 LDA fl_ink,X
 STA fl_u
 LDA fl_ni,X
 BPL flm5
 JSR fl_dots            \ a dotted ring
 BRA flm3
.flm5
 JSR fl_disc            \ a disc
 BRA flm3

\ fl_disc: ghost X, a disc (centre fl_gx, fl_gy; ink fl_u; density index
\ fl_m): its radius, half-widths and four row masks, then rows max(gy - r,
\ 1)..min(gy + r, 191) whose mask is not zero, each the span gx - h..gx + h
\ (h = the half-width at |y - gy|) clipped to x = 2..253

.fl_disc
 LDA fl_rad,X           \ radius, half-widths
 STA fl_r
 LDA fl_hl,X
 STA fl_hw
 LDA #HI(fl_htab)
 STA fl_hw+1
 STX fl_yb              \ masks[index][(j + number) AND 3] AND ink, j = 0..3
 LDA fl_m
 ASL A
 ASL A
 STA fl_t
 LDY #3
.flm6
 TYA
 CLC
 ADC fl_yb
 AND #3
 ORA fl_t
 TAX
 LDA fl_mt,X
 AND fl_u
 STA fl_pat,Y
 DEY
 BPL flm6
 LDA fl_gy
 SEC
 SBC fl_r
 BCC P%+4
 BNE P%+4
 LDA #1
 STA fl_y
 LDA fl_gy
 CLC
 ADC fl_r
 CMP #192
 BCC P%+4
 LDA #191
 STA fl_yb
 CMP fl_y
 BCC fsd9
 CMP fl_ymax            \ the rows' range
 BCC P%+4
 STA fl_ymax
 LDA fl_y
 CMP fl_ymin
 BCS P%+4
 STA fl_ymin
.fsd1
 LDA fl_y
 AND #3
 TAX
 LDA fl_pat,X
 BEQ fsd8
 STA fl_m
 LDA fl_y
 SEC
 SBC fl_gy
 JSR fl_abs
 TAY
 LDA (fl_hw),Y
 TAX
 EOR #&FF               \ XL = max(gx - h, 2)
 SEC
 ADC fl_gx
 BCS P%+4
 LDA #0
 CMP #2
 BCS P%+4
 LDA #2
 STA R_XL
 TXA                    \ XR = min(gx + h, 253)
 CLC
 ADC fl_gx
 BCS P%+6
 CMP #254
 BCC P%+4
 LDA #253
 STA R_XR
 CMP R_XL
 BCC fsd8
 JSR fl_span
.fsd8
 LDA fl_y
 INC fl_y
 CMP fl_yb
 BCC fsd1
.fsd9
 RTS

\ fl_abs: A = |A| (A from a load: N its sign; A > -128)

.fl_abs
 BPL P%+5
 EOR #&FF
 INC A
 RTS

.SH7_END
ASSERT SH7_END <= &8000

\ ------------------------------------------------------------------------------
\ Shadow &3F00-&3FFF: the tables (tools/flare.py: GHOSTS, LADDER, BAYER,
\ RING, hw_table) and the drawing of a span
\ ------------------------------------------------------------------------------

ORG &3F00

.fl_htab                \ half-widths: the widest x with x^2 + d^2 <= r^2 + r,
MACRO FLHW r            \ d = 0..r (one page: fl_hw's high byte is fixed)
 FOR d, 0, r
  EQUB INT(SQR(r * r + r - d * d))
 NEXT
ENDMACRO
.fl_h3  FLHW 3
.fl_h4  FLHW 4
.fl_h5  FLHW 5
.fl_h7  FLHW 7
.fl_h10 FLHW 10
.fl_h18 FLHW 18
ASSERT HI(fl_htab) = HI(P% - 1)

                        \ the ghosts, by number (k = 8, 5, 3, -1, -3, -4, -6,
                        \ -8: centre C + k D / 8; 8: the ring round the sun): radius (a ring: its scale, 1
                        \ for 30, 0 for 15), ink, density index (+ &80: a
                        \ dotted ring), half-widths
.fl_rad EQUB 1, 4, 7, 3, 10, 5, 0, 18
.fl_ink EQUB &FF, &FF, &F0, &0F, &0F, &FF, &F0, &0F
.fl_ni  EQUB &83, 4, 3, 5, 3, 3, &83, 2
.fl_hl  EQUB 0, LO(fl_h4), LO(fl_h7), LO(fl_h3), LO(fl_h10), LO(fl_h5), 0, LO(fl_h18)

fl_mt = P% - 4          \ row masks of densities 1, 2, 4, 6, 8 / 16 (4x4
                        \ Bayer), by density index (1..5) and row
 EQUB &88, &00, &00, &00
 EQUB &88, &00, &22, &00
 EQUB &AA, &00, &AA, &00
 EQUB &AA, &44, &AA, &11
 EQUB &AA, &55, &AA, &55

.fl_lm  EQUB &FF, &77, &33, &11      \ pixels x AND 3..3 of a byte
.fl_rm  EQUB &88, &CC, &EE, &FF      \ pixels 0..x AND 3

.fl_ring                \ (dx, dy) of 9 points of a quarter circle of radius 15
 EQUB 15, 0, 15, 3, 14, 6, 12, 8, 11, 11, 8, 12, 6, 14, 3, 15, 0, 15

\ fl_span: OR fl_m into row fl_y, pixels R_XL..R_XR (inside the clip
\ window), after extending this buffer's dirty extent for the row (the rows'
\ range, fl_ymin..fl_ymax, is the callers'). Clobbers A, X, Y, fl_t.

.fl_span
 LDY fl_y
 LDA R_XL
.fl_dl1
 CMP R_DIRTYL0,Y        \ patched (this buffer's)
 BCS P%+5
.fl_dl2
 STA R_DIRTYL0,Y
 LDA R_XR
.fl_dr1
 CMP R_DIRTYR0,Y
 BCC P%+5
.fl_dr2
 STA R_DIRTYR0,Y
 TYA                    \ &4000 + (y DIV 8) * &200 + (y MOD 8) + 8 * (XL DIV 4)
 LSR A
 LSR A
 AND #&FE
 ORA #&40
 STA fl_sp+1
 TYA
 AND #7
 STA fl_sp
 LDA R_XL
 AND #&FC
 STA fl_t
 ASL A
 BCC P%+4
 INC fl_sp+1
 ORA fl_sp
 STA fl_sp
 LDA R_XL               \ the first byte's mask
 AND #3
 TAX
 LDA fl_lm,X
 AND fl_m
 STA flo_f+1
 LDA R_XR               \ the last's
 AND #3
 TAX
 LDA fl_rm,X
 AND fl_m
 TAX
 LDA R_XR               \ 8 * (XR DIV 4 - XL DIV 4)
 AND #&FC
 SEC
 SBC fl_t
 ASL A
 STA fl_n
 BNE fls1
 TXA                    \ one byte: both masks
 AND flo_f+1
 TAX
.fls1
 STX flo_l+1
 LDA fl_m
 STA flo_m+1
 JMP fl_or              \ (bank 6)

.SH3_END
ASSERT SH3_END <= &4000

\ ------------------------------------------------------------------------------
\ Shadow &3000-&308F (below the zero page's save area at &3090, setzp):
\ a dotted ring
\ ------------------------------------------------------------------------------

ORG &3000

\ fl_dots: ghost X, a dotted ring (centre fl_gx, fl_gy; ink fl_u; density
\ index fl_m): fl_ring's points (times 2 ^ its scale), every one at density
\ index 3 or more, else every other one, in all four quadrants (the points
\ on the axes once each), each ORed in its ink where it is inside the clip
\ window

.fl_dots
 LDY #2                 \ the step: every point (2 bytes on) at index 3 or
 LDA fl_m               \ more, else every other one (4)
 CMP #3
 BCS P%+4
 LDY #4
 STY fl_r
 LDA fl_rad,X           \ (its scale)
 STA fl_pat+1
 LDA fl_u               \ (its ink)
 STA fl_m
 LDX #0
.fsr1
 STX fl_pat+2
 LDY fl_pat+1
 LDA fl_ring,X          \ dx, dy
 CPY #0
 BEQ P%+3
 ASL A
 STA fl_hw
 LDA fl_ring+1,X
 CPY #0
 BEQ P%+3
 ASL A
 STA fl_hw+1
 LDA fl_gx              \ columns gx + dx and gx - dx
 CLC
 ADC fl_hw
 BCS P%+5
 JSR fl_dcol
 LDA fl_hw              \ (dx = 0: the same column)
 BEQ fsr2
 LDA fl_gx
 SEC
 SBC fl_hw
 BCC P%+5
 JSR fl_dcol
.fsr2
 LDA fl_pat+2
 CLC
 ADC fl_r
 TAX
 CPX #18
 BCC fsr1
 RTS

.fl_dcol                \ column A: rows gy + dy and gy - dy
 CMP #2
 BCC fsc9
 CMP #254
 BCS fsc9
 STA R_XL
 STA R_XR
 LDA fl_gy              \ (gy + dy <= 191 + 30: no carry)
 CLC
 ADC fl_hw+1
 JSR fl_drow
 LDA fl_hw+1            \ (dy = 0: the same row)
 BEQ fsc9
 LDA fl_gy
 SEC
 SBC fl_hw+1
 BCC fsc9
.fl_drow                \ row A, if inside the clip window
 CMP #1
 BCC fsc9
 CMP #192
 BCS fsc9
 STA fl_y
 CMP fl_ymax            \ the rows' range
 BCC P%+4
 STA fl_ymax
 CMP fl_ymin
 BCS P%+4
 STA fl_ymin
 JMP fl_span
.fsc9
 RTS

.SH0_END
ASSERT SH0_END <= &3090
