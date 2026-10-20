\ ============================================================================
\ raster7.asm -- R_LINE, the rasteriser's line drawing, in bank 7 (R_BANK_AUX)
\ with the cold area (docs/MASTER-MAP.md).  The frame layer's T_LINE pages
\ bank 7 in and calls R_LINE.  The rest of the rasteriser is in ANDY and bank
\ 5 (gfx-raster.asm, gfx-raster_poly.asm, gfx-raster_disc.asm); R_LINE uses
\ only the shared workspace (main RAM) and its own code, tables and variables
\ here.  INCLUDE it after them (it uses their symbols).
\
\ The line from P0 to P1 is Bresenham's along its major axis (x when |dx| >=
\ |dy|) from its left or top end: with d = |d major|, a = |d minor| and h = d
\ DIV 2, pixel i = 0..d is at major m0 + i, minor n0 +- (i * a + h) DIV d.
\ Its pixels inside the clip window are one run (x and y are monotonic).  A
\ line with both ends inside (8-bit) goes straight to the line loops (r7_line);
\ any other is clipped exactly (rl_gen: the first and last pixels inside, from
\ the window's four sides), then drawn by the same loops from the first pixel
\ when d <= 255, or pixel by pixel with a 16-bit error term when d > 255.
\ ============================================================================

\ R_LINE's zero page (the line loops')
l_x0 = &18              \ (rl_gen's pixel-by-pixel loop: x, y, as l_x0,X)
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

\ (The bank starts on a page boundary: the runs need whole pages.)
.r7_start
\ R_LINE's variables, tables and small routines
.r7_lct SKIP 8          \ R_LINE: colour byte by row AND 7
.r7_ldl EQUB HI(R_DIRTYL0), HI(R_DIRTYL1)
.r7_ldr EQUB HI(R_DIRTYR0), HI(R_DIRTYR1)
.r7_lbuf EQUB &FF       \ buffer R_LINE's DIRTY operands are patched for
.r7_pm EQUB &88, &44, &22, &11  \ pixel x AND 3 of a byte
.r7_m0 EQUB 0           \ 32-bit dividend / product; quotient m0,m1
.r7_m1 EQUB 0
.r7_m2 EQUB 0           \ remainder m2,m3
.r7_m3 EQUB 0
.r7_v0 EQUB 0           \ divisor
.r7_v1 EQUB 0
.r7_ma EQUW 0           \ multiplicand
.r7_mb EQUW 0           \ multiplier
\ rl_gen's variables (16-bit: lo, hi)
.c_dx SKIP 2            \ P1 - P0: x, y (c_dx + 2)
.c_dy SKIP 2
.c_ax SKIP 2            \ |dx|, |dy| (c_ax + 2)
.c_ay SKIP 2
.c_d  SKIP 2            \ |d major|
.c_a  SKIP 2            \ |d minor|
.c_h  SKIP 2            \ d DIV 2
.c_m0 SKIP 2            \ the left / top end: major, minor
.c_n0 SKIP 2
.c_i  SKIP 2            \ the first pixel inside, the last (i)
.c_j  SKIP 2
.c_t  SKIP 2            \ rl_mdq's signed addend
.c_mo SKIP 1            \ major axis: 0 = x, 2 = y (an offset into R_X0.., R_CL..)
.c_s  SKIP 1            \ bit 7: the minor coordinate decreases
.c_lo SKIP 1            \ major window lo, hi; minor window lo, hi
.c_hi SKIP 1
.c_nl SKIP 1
.c_nh SKIP 1
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
\ rl_mdq: (r7_ma * r7_mb + c_t) DIV / MOD r7_v -> quotient r7_m0,m1,
\ remainder r7_m2,m3 (c_t signed; the quotient must fit 16 bits).  Clobbers
\ r7_mb.
.rl_mdq
{
  JSR r7_mul16
  CLC
  LDA r7_m0
  ADC c_t
  STA r7_m0
  LDA r7_m1
  ADC c_t+1
  STA r7_m1
  LDX #0                  \ c_t's sign, extended
  LDA c_t+1
  BPL p
  DEX
.p
  TXA
  ADC r7_m2
  STA r7_m2
  TXA
  ADC r7_m3
  STA r7_m3
  JMP r7_div32
}
\ r7_lstart: A = steps: l_n = A, l_e = (A DIV 2) - l_b, l_x = x0, the buffer's
\ dirty rows += y0..y1 (both inside the window)
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
  CMP R_PRDYT,X           \ A = top, Y = bottom
  BCS t2
  STA R_PRDYT,X
.t2
  TYA
  CMP R_PRDYB,X
  BCC t4
  STA R_PRDYB,X
.t4
  RTS
}
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
.r7_lm                    \ pixels x..3 of a byte (x = 0..3)
FOR x, 0, 3
  EQUB ((&F0 >> x) AND &F0) OR (&0F >> x)
NEXT
.r7_rm                    \ pixels 0..x of a byte (x = 0..3)
FOR x, 0, 3
  EQUB ((&F0 << (3 - x)) AND &F0) OR ((&0F << (3 - x)) AND &0F)
NEXT

\ ============================================================================
\ R_LINE (the frame layer's T_LINE pages bank 7 and calls it)
\ ============================================================================
.R_LINE
{
  LDA R_X0+1              \ both ends in the window: the line loops
  ORA R_X1+1
  ORA R_Y0+1
  ORA R_Y1+1
  BNE gen
  LDA R_X0
  CMP R_CL
  BCC gen
  CMP R_CR
  BEQ f1
  BCS gen
.f1
  LDA R_X1
  CMP R_CL
  BCC gen
  CMP R_CR
  BEQ f2
  BCS gen
.f2
  LDA R_Y0
  CMP R_CT
  BCC gen
  CMP R_CB
  BEQ f3
  BCS gen
.f3
  LDA R_Y1
  CMP R_CT
  BCC gen
  CMP R_CB
  BEQ f4
  BCS gen
.f4
  JMP r7_line
.gen
}
\ ----------------------------------------------------------------------------
\ rl_gen: R_LINE clipped: the rows min(y0, y1)..max(y0, y1) inside the
\ window join the buffer's row range; then the first pixel inside the window
\ (i = c_i) and the last (c_j) are found exactly, and the pixels between them
\ drawn.  From the left / top end (major m0, minor n0, s the minor's sign):
\   c_i = max(0, lo - m0, ceil((k * d - h) / a)) with k = nl - n0 (s > 0) or
\         n0 - nh (s < 0), the last term only if k > 0 (none inside if k > a)
\   c_j = min(d, hi - m0, ((K + 1) * d - h - 1) DIV a) with K = nh - n0 (s >
\         0) or n0 - nl (s < 0), the last term only if K < a (none if K < 0)
\ ----------------------------------------------------------------------------
.rl_gen
{
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
  LDX R_PRBUF             \ the DIRTY operands for this buffer
  CPX r7_lbuf
  BEQ pd
  JSR r7_lpat
.pd
  LDX #2                  \ d = P1 - P0 -> c_dx (x), c_dy (y); |d| -> c_ax, c_ay
.dl
  SEC
  LDA R_X1,X
  SBC R_X0,X
  STA c_dx,X
  STA c_ax,X
  LDA R_X1+1,X
  SBC R_X0+1,X
  STA c_dx+1,X
  STA c_ax+1,X
  BPL dp
  SEC
  LDA #0
  SBC c_dx,X
  STA c_ax,X
  LDA #0
  SBC c_dx+1,X
  STA c_ax+1,X
.dp
  DEX
  DEX
  BPL dl
  LDX #0                  \ X = major axis offset (0 = x, 2 = y), Y = minor
  LDY #2
  LDA c_ax
  CMP c_ay
  LDA c_ax+1
  SBC c_ay+1
  BCS mx
  LDX #2
  LDY #0
.mx
  STX c_mo
  LDA c_dx+1,Y            \ minor sign: d minor's, negated when the ends swap
  EOR c_dx+1,X
  STA c_s
  LDA c_ax,X
  STA c_d
  LDA c_ax+1,X
  STA c_d+1
  LSR A
  STA c_h+1
  LDA c_d
  ROR A
  STA c_h
  LDA c_ax,Y
  STA c_a
  LDA c_ax+1,Y
  STA c_a+1
  LDA R_CL,X
  STA c_lo
  LDA R_CR,X
  STA c_hi
  LDA R_CL,Y
  STA c_nl
  LDA R_CR,Y
  STA c_nh
  LDA #0                  \ from P1 when d major < 0
  BIT c_dx+1,X
  BPL p0
  LDA #4
.p0
  ORA c_mo
  TAX
  LDA R_X0,X
  STA c_m0
  LDA R_X0+1,X
  STA c_m0+1
  TXA
  EOR #2
  TAX
  LDA R_X0,X
  STA c_n0
  LDA R_X0+1,X
  STA c_n0+1
  LDA c_mo                \ kind: 2 + (y increases) for x major, 0 + (x
  EOR #2                  \ increases) for y major
  BIT c_s
  BMI kd
  ORA #1
.kd
  STA l_k
  SEC                     \ c_i = max(0, lo - m0)
  LDA c_lo
  SBC c_m0
  STA c_i
  LDA #0
  SBC c_m0+1
  STA c_i+1
  BPL i1
  STZ c_i
  STZ c_i+1
.i1
  BIT c_s                 \ k -> r7_ma
  BMI ed
  SEC
  LDA c_nl
  SBC c_n0
  STA r7_ma
  LDA #0
  SBC c_n0+1
  BRA ek
.ed
  SEC
  LDA c_n0
  SBC c_nh
  STA r7_ma
  LDA c_n0+1
  SBC #0
.ek
  STA r7_ma+1
  BMI e0                  \ k <= 0: inside from the start on the minor axis
  ORA r7_ma
  BEQ e0
  LDA c_a                 \ k > a: never inside
  CMP r7_ma
  LDA c_a+1
  SBC r7_ma+1
  BCS P%+5
.none1
  JMP none
  CLC                     \ c_t = a - h - 1 = a + NOT h
  LDA c_h
  EOR #&FF
  ADC c_a
  STA c_t
  LDA c_h+1
  EOR #&FF
  ADC c_a+1
  STA c_t+1
  JSR rl_mdqa             \ (k * d + a - h - 1) DIV a
  LDA r7_m0               \ c_i = max(c_i, that)
  CMP c_i
  LDA r7_m1
  SBC c_i+1
  BCC e0
  LDA r7_m0
  STA c_i
  LDA r7_m1
  STA c_i+1
.e0
  SEC                     \ c_j = hi - m0 (none if < 0) ...
  LDA c_hi
  SBC c_m0
  STA c_j
  LDA #0
  SBC c_m0+1
  STA c_j+1
  BMI none1
  LDA c_d                 \ ... at most d
  CMP c_j
  LDA c_d+1
  SBC c_j+1
  BCS j1
  LDA c_d
  STA c_j
  LDA c_d+1
  STA c_j+1
.j1
  BIT c_s                 \ K -> r7_ma
  BMI xd
  SEC
  LDA c_nh
  SBC c_n0
  STA r7_ma
  LDA #0
  SBC c_n0+1
  BRA xk
.xd
  SEC
  LDA c_n0
  SBC c_nl
  STA r7_ma
  LDA c_n0+1
  SBC #0
.xk
  STA r7_ma+1
  BPL P%+5                \ K < 0: never inside
  JMP none
  LDA r7_ma               \ K >= a: inside to the end on the minor axis
  CMP c_a
  LDA r7_ma+1
  SBC c_a+1
  BCS x0
  INC r7_ma               \ K + 1
  BNE P%+5
  INC r7_ma+1
  LDA c_h                 \ c_t = -h - 1 = NOT h
  EOR #&FF
  STA c_t
  LDA c_h+1
  EOR #&FF
  STA c_t+1
  JSR rl_mdqa             \ ((K + 1) * d - h - 1) DIV a
  LDA r7_m0               \ c_j = min(c_j, that)
  CMP c_j
  LDA r7_m1
  SBC c_j+1
  BCS x0
  LDA r7_m0
  STA c_j
  LDA r7_m1
  STA c_j+1
.x0
  LDA c_j                 \ c_i > c_j: none inside
  CMP c_i
  LDA c_j+1
  SBC c_i+1
  BCC none
  LDA c_i                 \ q, r = (c_i * a + h) DIV / MOD d
  ORA c_i+1
  BNE fq
  STZ r7_m0
  STZ r7_m1
  LDA c_h
  STA r7_m2
  LDA c_h+1
  STA r7_m3
  BRA qd
.none
  RTS
.fq
  LDA c_i
  STA r7_ma
  LDA c_i+1
  STA r7_ma+1
  LDA c_a
  STA r7_mb
  LDA c_a+1
  STA r7_mb+1
  LDA c_h
  STA c_t
  LDA c_h+1
  STA c_t+1
  LDA c_d
  STA r7_v0
  LDA c_d+1
  STA r7_v1
  JSR rl_mdq
.qd
  SEC                     \ pixels: c_j - c_i + 1
  LDA c_j
  SBC c_i
  INC A
  STA l_n
  CLC                     \ the first pixel: major m0 + c_i ...
  LDA c_m0
  ADC c_i
  TAY
  BIT c_s                 \ ... minor n0 +- q
  BMI qn
  CLC
  LDA c_n0
  ADC r7_m0
  BRA qs
.qn
  SEC
  LDA c_n0
  SBC r7_m0
.qs
  LDX c_mo                \ A = minor, Y = major -> l_x0, l_y0
  BEQ qx
  STA l_x0
  STY l_y0
  BRA qe
.qx
  STA l_y0
  STY l_x0
.qe
  SEC                     \ e = r - d
  LDA r7_m2
  SBC c_d
  STA l_e
  LDA r7_m3
  SBC c_d+1
  LDX c_d+1
  BNE long
  LDA l_x0                \ d <= 255: the line loops from there
  STA l_x
  LDA c_a
  STA l_a
  LDA c_d
  STA l_b
  JMP r7_lgo
.long                     \ d > 255: pixel by pixel, e 16-bit
  STA c_t+1               \ (c_t: e)
  LDA l_e
  STA c_t
  LDA c_mo                \ X = the major axis (0 = x, 1 = y: l_x0,X)
  LSR A
  TAX
.lp
  PHX
  LDX l_x0
  LDY l_y0
  JSR r7_pset
  PLX
  DEC l_n
  BEQ done
  INC l_x0,X              \ major step
  CLC                     \ e += a
  LDA c_t
  ADC c_a
  STA c_t
  LDA c_t+1
  ADC c_a+1
  STA c_t+1
  BMI lp
  SEC                     \ e >= 0: e -= d, minor step
  LDA c_t
  SBC c_d
  STA c_t
  LDA c_t+1
  SBC c_d+1
  STA c_t+1
  TXA
  EOR #1
  TAX
  BIT c_s
  BMI md
  INC l_x0,X
  BRA mn
.md
  DEC l_x0,X
.mn
  TXA
  EOR #1
  TAX
  BRA lp
.done
  RTS
}
\ rl_mdqa: rl_mdq with r7_mb = d and r7_v = a (rl_gen's c_i and c_j bounds)
.rl_mdqa
  LDA c_d
  STA r7_mb
  LDA c_d+1
  STA r7_mb+1
  LDA c_a
  STA r7_v0
  LDA c_a+1
  STA r7_v1
  JMP rl_mdq

\ ============================================================================
\ The line loops: Bresenham along the major axis from the left / top end, a
\ pixel per step.  Pointer RZ_PP (+ Y = row AND 7), pixel mask l_m, colour
\ by row AND 7 (r7_lct); X = row; DIRTY[b][row] extended per pixel (the
\ buffer's row range is the caller's).  l_n pixels (0: 256), all inside the
\ window.
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
  STA r7_ps2+2
  STA r7_ps3+2
  RTS

\ r7_line: R_LINE with both ends inside the window (8-bit); r7_lgo: a line
\ prepared by rl_gen (l_x0 = l_x, l_y0, l_e, l_a, l_b, l_n, l_k; the DIRTY
\ operands patched)
.r7_line
{
  LDX R_PRBUF
  CPX r7_lbuf
  BEQ pd
  JSR r7_lpat
.pd
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
}
.r7_lgo
{
  LDY #6
.ct
  LDA R_COLE
  STA r7_lct,Y
  LDA R_COLO
  STA r7_lct+1,Y
  DEY
  DEY
  BPL ct
  LDX l_y0                \ X = row, l_x = x
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
  EQUW lyl, lyr, lxu, lxd
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
}

.r7_end
PRINT "raster7.asm: ", r7_end - r7_start, " bytes"
