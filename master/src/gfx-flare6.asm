\ ******************************************************************************
\
\ gfx-flare6.asm - the lens flare's part in bank 6 (see gfx-flare.asm): its
\ step in F_FRAME and the writing of a span
\
\ ******************************************************************************

\ Zero page: the rasteriser's scratch &10-&27, which F_FRAME saves and
\ restores, and R_COLE, R_COLO and R_DCE (&06, &07, &0E: saved too, and set
\ again before any use after the flare)

fl_lq   = &06           \ a span's first byte's mask (before the row's)
fl_rq   = &07           \ its last byte's
fl_t    = &0E
fl_dx   = &10           \ the sun's x - 128 (signed)
fl_dy   = &11           \ the sun's y - 96 (signed; fl_dx + 1)
fl_u    = &12           \ the ghost's ink
fl_i    = &13           \ the next ghost's number
fl_ymin = &14           \ the rows written
fl_ymax = &15
fl_gx   = &16           \ the ghost's centre (on the screen when the sun's
fl_gy   = &17           \ centre is, as |k| <= 8: all 8-bit)
fl_r    = &18           \ a disc's radius (a ring: the step, 2 or 4)
fl_hw   = &19           \ a disc's half-width table (a ring: dx, dy)
fl_pat  = &1B           \ the ghost's ink masks for rows y AND 3 = 0..3
fl_d    = &1F           \ a disc's row offset d (a ring: the point's offset)
fl_m    = &20           \ the row's mask (fl_or: the middle bytes')
fl_sp   = &21           \ screen pointer (fl_or)
fl_n    = &23           \ 8 * (bytes - 1) (fl_or)
fl_ch   = &24           \ &40 + (a span's first byte's column >= 32)
fl_cl   = &27           \ 8 x a span's first byte's column, low byte

FLNG = 8                \ ghosts
FLHMAX = 26             \ the ring round the sun only for a sun this small

\ f_flt: F_FRAME's text step, after the flare (in place of JSR f_text2).
\ Without the sun (GSUNON = 0) it costs a test; with it FL_MAIN, in shadow
\ RAM, runs with ACCCON X = 1, and X goes back to this buffer's after.

.f_flt
 LDA GSUNON
 BEQ flt9
 LDA F_BACK             \ fl_xb: 4 when the back buffer is main RAM (0)
 EOR #1
 ASL A
 ASL A
 STA fl_xb
 LDA #4
 TSB &FE34
 JSR FL_MAIN            \ (in shadow RAM: ACCCON X is set; bankcheck: ok)
 LDA fl_xb
 TRB &FE34
.flt9
 JMP f_text2

\ fl_or: OR the span at fl_sp into the back buffer: its last byte (offset
\ fl_n) with fl_rq AND fl_m, then if fl_n > 0 the bytes between with fl_m and
\ its first with fl_lq AND fl_m (fl_n = 0: the one byte, with fl_lq AND
\ fl_m), with ACCCON X cleared around it for buffer 0 (fl_xb = 4; buffer 1
\ enters at fl_or1). Called from shadow RAM, so X is set again before
\ returning. Clobbers A, Y.

.fl_or
 LDA fl_xb
 TRB &FE34
.fl_or1                 \ (buffer 1: X already set)
 LDY fl_n
 BEQ flo9
 LDA fl_rq
 AND fl_m
 ORA (fl_sp),Y
 STA (fl_sp),Y
 SEC
 BRA flo3
.flo2
 LDA (fl_sp),Y
 ORA fl_m
 STA (fl_sp),Y
.flo3
 TYA
 SBC #8
 TAY
 BNE flo2
.flo9
 LDA fl_lq
 AND fl_m
 ORA (fl_sp)
 STA (fl_sp)
 LDA #4
 TSB &FE34
 RTS
ASSERT HI(fl_or) = HI(fl_or1)

\ The flare's tables, read by its code in shadow RAM (bank 6 is paged
\ while it runs)

.fl_dk  EQUB 0, 3, 2, 4, 2, 1, 2, 2 \ the k steps 8 -> 5 -> 3 -> -1 -> -3 ->
                                    \ -4 -> -6 -> -8, by ghost
.fl_lmt EQUB &FF, &77, &33, &11     \ pixels x AND 3..3 of a byte
.fl_rmt EQUB &88, &CC, &EE, &FF     \ pixels 0..x AND 3
.fl_pxm EQUB &88, &44, &22, &11     \ pixel x AND 3
.fl_ring                \ (dx, dy) of 9 points of a quarter circle of radius 15
 EQUB 15, 0, 15, 3, 14, 6, 12, 8, 11, 11, 8, 12, 6, 14, 3, 15, 0, 15
