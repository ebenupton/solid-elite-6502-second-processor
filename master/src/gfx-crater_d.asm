\ gfx-crater_d.asm - f_bounds's crater branch, f_seg16, f_segment, f_parity
\ (included by gfx-frame.asm; on the Tube parasite, see the IFs there)

.f_crater               \ (f_bounds's crater branch: A = 1)
 STA R_NDF
 JSR f_zerobounds
 LDA #&50
 STA R_DBE
 LDA #&A0
 STA R_DBO
.fbd2
 LDX F_NCV              \ the last curve ends at F_NPT (F_NCV >= 1 here)
 LDA F_NPT
 STA F_CVE-1,X
 LDA #0
 STA f_ci
.fbd3                   \ for each curve
 LDX f_ci
 CPX F_NCV
 BCC P%+5
 JMP f_parity
 LDA F_CVE,X            \ its segments: points F_CVS .. F_CVE-1
 STA fbd_e+1
 LDA F_CVS,X
 TAX
 BRA fbd5               \ loop test at the bottom
.fbd4
 LDA F_PXL-1,X          \ segment start = point X-1
 STA sg_ax
 LDA F_PXH-1,X
 STA sg_ax+1
 LDA F_PYL-1,X
 STA sg_ay
 LDA F_PYH-1,X
 STA sg_ay+1
 LDA F_PXL,X            \ segment end = point X
 STA sg_bx
 LDA F_PXH,X
 STA sg_bx+1
 LDA F_PYL,X
 STA sg_by
 LDA F_PYH,X
 STA sg_by+1
 PHX
 JSR f_seg16
 PLX
.fbd5
 INX                    \ segment X-1 -> X
.fbd_e
 CPX #0                 \ patched: F_CVE of this curve
 BCC fbd4
.fbd6
                        \ (a crater's full ellipse is closed)
.fbd7
 INC f_ci
 JMP fbd3

.f_ci EQUB 0

\ f_seg16: boundary crossings of the segment (sg_ax, sg_ay) - (sg_bx, sg_by)
\ (16-bit) for rows y with min(y) <= y < max(y) within R_NDT..R_NDB. A crossing
\ left of the row's disc span flips the row's starting colour (R_NDP), one
\ right of it is ignored, one inside is added to the row's boundaries. Long
\ segments (|dx| or |dy| > 255) are halved, recursively.

.f_seg16
 LDA sg_bx              \ |dx| > 255 or |dy| > 255?
 SEC
 SBC sg_ax
 LDA sg_bx+1
 SBC sg_ax+1
 BEQ fs16a
 CMP #&FF
 BNE fs16s
 LDA sg_bx
 CMP sg_ax
 BEQ fs16s              \ dx = -256
.fs16a
 LDA sg_by
 SEC
 SBC sg_ay
 LDA sg_by+1
 SBC sg_ay+1
 BEQ fs16b
 CMP #&FF
 BNE fs16s
 LDA sg_by
 CMP sg_ay
 BEQ fs16s
.fs16b
 JMP f_segment
.fs16s                  \ split at the midpoint: push the second half
 LDA sg_bx+1
 PHA
 LDA sg_bx
 PHA
 LDA sg_by+1
 PHA
 LDA sg_by
 PHA
 LDA sg_ax              \ mid = (a + b) / 2 (arithmetic: the true sign of the
 CLC                    \ 17-bit sum is N EOR V)
 ADC sg_bx
 STA fz_t
 LDA sg_ax+1
 ADC sg_bx+1
 STA fz_u
 BVC P%+4
 EOR #&80
 ASL A
 ROR fz_u
 ROR fz_t
 LDA fz_u
 STA sg_bx+1
 LDA fz_t
 STA sg_bx
 LDA sg_ay
 CLC
 ADC sg_by
 STA fz_t
 LDA sg_ay+1
 ADC sg_by+1
 STA fz_u
 BVC P%+4
 EOR #&80
 ASL A
 ROR fz_u
 ROR fz_t
 LDA fz_u
 STA sg_by+1
 LDA fz_t
 STA sg_by
 JSR f_seg16            \ first half: a -> mid
 LDA sg_bx              \ second half: mid -> b
 STA sg_ax
 LDA sg_bx+1
 STA sg_ax+1
 LDA sg_by
 STA sg_ay
 LDA sg_by+1
 STA sg_ay+1
 PLA
 STA sg_by
 PLA
 STA sg_by+1
 PLA
 STA sg_bx
 PLA
 STA sg_bx+1
 JMP f_seg16

\ f_segment: as f_seg16 for |dx|, |dy| <= 255

.f_segment
 LDA sg_ay              \ order the end points by y: (sg_x, sg_y) is the top
 CMP sg_by
 LDA sg_ay+1
 SBC sg_by+1
 BVC P%+4
 EOR #&80
 BMI fsg_ok             \ a above b
 LDA sg_ay              \ equal rows: nothing
 CMP sg_by
 BNE fsg_sw
 LDA sg_ay+1
 CMP sg_by+1
 BNE fsg_sw
.fsg_x                  \ (also f_segment's other early exits)
 RTS
.fsg_sw
 LDX #3                 \ swap a and b
.fsg_w
 LDA sg_ax,X
 LDY sg_bx,X
 STA sg_bx,X
 TYA
 STA sg_ax,X
 DEX
 BPL fsg_w
.fsg_ok
 LDA sg_ax              \ start at a; dy = by - ay, dx = bx - ax
 STA sg_x
 LDA sg_ax+1
 STA sg_x+1
 LDA sg_ay
 STA sg_y
 LDA sg_ay+1
 STA sg_y+1
 LDA sg_by
 SEC
 SBC sg_ay
 STA sg_dy
 LDA sg_by+1
 STA sg_y1+1
 LDA sg_bx
 SEC
 SBC sg_ax
 STA sg_dx
 LDA sg_bx+1
 SBC sg_ax+1
 STA sg_sx              \ sign of dx (bit 7)
 BPL fsg_p
 LDA sg_dx              \ |dx|
 EOR #&FF
 CLC
 ADC #1
 STA sg_dx
.fsg_p
 LDA sg_y+1             \ the segment must reach rows NDT..NDB:
 BMI fsg_a              \ y1 > NDT and y0 <= NDB
 BNE fsg_x
 LDA R_NDB
 CMP sg_y
 BCC fsg_x              \ NDB < y0: misses
.fsg_a
 LDA sg_y1+1
 BMI fsg_x
 BNE fsg_bh             \ y1 > 255: the loop ends at NDB+1
 LDA sg_by
 CMP R_NDT
 BEQ fsg_x
 BCC fsg_x              \ y1 > NDT: reaches the span
.fsg_cb
 CMP #0                 \ patched: R_NDB+1 <= 192 (f_zerobounds)
 BCC fsg_bs
.fsg_bh
 LDA fsg_cb+1
.fsg_bs                 \ the loop's end row E = min(y1, NDB+1) lives in the
 STA fsg_ya+1           \ operands of the two hot exit tests (and fsg_c): rows
 STA fsg_yb+1           \ run from y0 (<= NDB) up, so Y reaches E before
                        \ passing NDB, and above the screen Y >= LO(y0) > E
                        \ (|dy| <= 255), so no other row there matches it
.fsg_b
 LDA sg_dx              \ q = |dx| DIV dy, r = |dx| MOD dy
 LDX #0
.fsg_d
 CMP sg_dy
 BCC fsg_e
 SBC sg_dy
 INX
 BNE fsg_d
.fsg_e
 STA sg_r
 STX sg_q
 STZ sg_err
.fsg_row                \ row sg_y: record the crossing if it's in range
 LDY sg_y               \ Y = sg_y (low byte) for the whole loop: sg_y itself
 LDA sg_y+1             \ is not updated after this (only read before here)
 BMI fsg_hi             \ y < 0 (0 or negative here: fsg_p): rows above
.fsg_ry                 \ the screen. From here on sg_y+1 = 0, and Y <= NDB
.fsg_ct                 \ <= 191 at fsg_n, so Y never wraps in this loop
 CPY #0                 \ patched: R_NDT (f_zerobounds)
 BCC fsg_n
 LDA sg_x+1             \ left of the span? (x <= NDISCL, x 16-bit)
 BMI fsg_l
 BNE fsg_n              \ x > 255: right of it
 LDA sg_x               \ x <= NDISCL: left of the span
 CMP R_NDISCL,Y
 BCC fsg_l
 BEQ fsg_l
 CMP R_NDISCR,Y         \ x > NDISCR: right of the span
 BCC P%+4              \ x < NDISCR: inside (x = NDISCR falls through BNE)
 BNE fsg_n
 LDX R_NDN,Y            \ inside: append (up to four)
 BNE fsg_k1
 STA R_NDX0,Y           \ n = 0
 LDA #1
 STA R_NDN,Y
 INY                    \ (fsg_n inlined)
.fsg_ya
 CPY #0                 \ patched: E = min(y1, NDB+1) (fsg_bs)
 BNE fsg_m
 RTS
.fsg_k1
 CPX #2
 BCS fsg_k2
 STA R_NDX1,Y           \ n = 1
 LDA #2
 STA R_NDN,Y
 INY                    \ (fsg_n inlined)
.fsg_yb
 CPY #0                 \ patched: E = min(y1, NDB+1) (fsg_bs)
 BNE fsg_m
 RTS
.fsg_k2
 BNE fsg_k3
 STA R_NDX2,Y           \ n = 2
 LDA #3
 STA R_NDN,Y
 BRA fsg_n
.fsg_k3
 CPX #4
 BCS fsg_n              \ n >= 4: full
 STA R_NDX3,Y           \ n = 3
 LDA #4
 STA R_NDN,Y
 BRA fsg_n
.fsg_l
 LDA R_NDP,Y            \ left of the span: flip the starting colour
 EOR #1
 STA R_NDP,Y
.fsg_n
 INY                    \ next row: y++, x += sx * (q + carry of the error)
.fsg_c
 CPY fsg_ya+1           \ done at y1
 BNE fsg_m
 RTS
.fsg_hi                 \ rows above the screen: the step returns to fsg_up
 LDX #LO(fsg_up)        \ (not fsg_ry) until y reaches 0 (y >= -254 here as
 STX fsg_jj+1           \ |dy| <= 255 and y1 > 0, so sg_y+1 = &FF, and Y
 LDX #HI(fsg_up)        \ never equals E above the screen: see fsg_bs)
 STX fsg_jj+2
.fsg_up
 INY
 BNE fsg_m
 INC sg_y+1             \ y = 0: back to fsg_ry from the next row
 LDX #LO(fsg_ry)        \ (and Y = 0 < E: no exit here)
 STX fsg_jj+1
 LDX #HI(fsg_ry)
 STX fsg_jj+2
 BRA fsg_m
.fsg_m
 LDA sg_err
 CLC
 ADC sg_r
 STA sg_err
 LDX sg_q
 BCS fsg_m1             \ (err + r can exceed 255 only if dy > 128)
 CMP sg_dy
 BCC fsg_m2
.fsg_m1
 SBC sg_dy
 STA sg_err
 INX
.fsg_m2
 BIT sg_sx              \ N = sign of dx
 BMI fsg_m3
 TXA
 CLC
 ADC sg_x
 STA sg_x
 BCC fsg_jj
 INC sg_x+1
.fsg_jj
 JMP fsg_ry             \ patched: fsg_up while y < 0
.fsg_m3
 TXA                    \ x - step = x + ~step + 1 (same A, C, V as SBC)
 EOR #&FF
 SEC
 ADC sg_x
 STA sg_x
 BCS fsg_jj
 DEC sg_x+1
 BRA fsg_jj

.sg_ax  EQUW 0          \ segment end points: ax, ay, bx, by would be
.sg_ay  EQUW 0          \ contiguous with this order for the swap: ax, ay
.sg_bx  EQUW 0
.sg_by  EQUW 0
.sg_x   EQUW 0
.sg_y   EQUW 0
.sg_y1  EQUW 0
.sg_dx  EQUB 0
.sg_dy  EQUB 0
.sg_sx  EQUB 0
.sg_q   EQUB 0
.sg_r   EQUB 0
.sg_err EQUB 0

\ f_parity: per row, sort the boundaries and set the colour at the left end

.f_parity
 LDY R_NDT
.fpa1
 LDA R_NDN,Y            \ sort up to four (insertion sort by hand)
 CMP #2
 BCC fpa5
 LDA R_NDX0,Y
 CMP R_NDX1,Y
 BCC fpa2
 LDX R_NDX1,Y
 STA R_NDX1,Y
 TXA
 STA R_NDX0,Y
.fpa2
 LDA R_NDN,Y
 CMP #3
 BCC fpa5
 LDA R_NDX1,Y           \ insert X2
 CMP R_NDX2,Y
 BCC fpa3
 LDX R_NDX2,Y
 STA R_NDX2,Y
 TXA
 STA R_NDX1,Y
 LDA R_NDX0,Y
 CMP R_NDX1,Y
 BCC fpa3
 LDX R_NDX1,Y
 STA R_NDX1,Y
 TXA
 STA R_NDX0,Y
.fpa3
 LDA R_NDN,Y
 CMP #4
 BCC fpa5
 LDA R_NDX2,Y           \ insert X3
 CMP R_NDX3,Y
 BCC fpa5
 LDX R_NDX3,Y
 STA R_NDX3,Y
 TXA
 STA R_NDX2,Y
 LDA R_NDX1,Y
 CMP R_NDX2,Y
 BCC fpa5
 LDX R_NDX2,Y
 STA R_NDX2,Y
 TXA
 STA R_NDX1,Y
 LDA R_NDX0,Y
 CMP R_NDX1,Y
 BCC fpa5
 LDX R_NDX1,Y
 STA R_NDX1,Y
 TXA
 STA R_NDX0,Y
.fpa5
.fpa8
 CPY R_NDB
 INY
 BCC P%+3
 RTS
 JMP fpa1

