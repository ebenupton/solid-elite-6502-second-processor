\ ******************************************************************************
\
\ gfx-flare6.asm - the lens flare's part in bank 6 (see gfx-flare.asm): its
\ step in F_FRAME and the writing of a span
\
\ ******************************************************************************

\ Zero page: the rasteriser's scratch &10-&27, which F_FRAME saves and
\ restores

fl_dx   = &10           \ the sun's x - 128 (signed)
fl_dy   = &11           \ the sun's y - 96 (signed)
fl_lev  = &12           \ level 1..3
fl_i    = &13           \ the next ghost's number (AND 3: a disc's phase)
fl_ymin = &14           \ the rows written
fl_ymax = &15
fl_gx   = &16           \ the ghost's centre (on the screen when the sun's
fl_gy   = &17           \ centre is, as |k| <= 8: all 8-bit)
fl_r    = &18           \ a disc's radius (a ring: the step, 2 or 4)
fl_hw   = &19           \ a disc's half-width table (a ring: dx, dy)
fl_pat  = &1B           \ a disc's ink masks for rows y AND 3 = 0..3 (a
                        \ ring: -, its scale, the point's offset)
fl_y    = &1F           \ row (fl_kd: |k|)
fl_yb   = &20           \ last row (fl_kd: +-D; fl_main: the phase)
fl_m    = &21           \ this span's ink mask (a ghost's density index)
fl_sp   = &22           \ screen pointer (fl_or)
fl_n    = &24           \ 8 * (bytes - 1) (fl_or)
fl_xb   = &25           \ ACCCON X while writing: 4 = clear it (buffer 0)
fl_t    = &26
fl_u    = &27

FLNG = 8                \ ghosts
FLHMAX = 26             \ the ring round the sun only for a sun this small

\ f_flt: F_FRAME's text step, after the flare (in place of JSR f_text2).
\ Without the sun (GSUNON = 0) it costs a test; with it FL_MAIN, in shadow
\ RAM, runs with ACCCON X = 1, and X goes back to this buffer's after.

.f_flt
 LDA GSUNON
 BEQ flt9
 LDA #4
 TSB &FE34
 JSR FL_MAIN
 LDA fl_xb
 TRB &FE34
.flt9
 JMP f_text2

\ fl_or: OR the span at fl_sp into the back buffer: its last byte (offset
\ fl_n) with flo_l's mask, then if fl_n > 0 its first with flo_f's and the
\ bytes between with flo_m's (the masks patched by fl_span), with ACCCON X
\ cleared around it for buffer 0 (fl_xb = 4). Called from shadow RAM, so X
\ is set again before returning. Clobbers A, Y.

.fl_or
 LDA fl_xb
 TRB &FE34
 LDY fl_n
 LDA (fl_sp),Y
.flo_l
 ORA #0                 \ patched
 STA (fl_sp),Y
 TYA
 BEQ flo9
 LDA (fl_sp)
.flo_f
 ORA #0                 \ patched
 STA (fl_sp)
 SEC
 BRA flo3
.flo2
 LDA (fl_sp),Y
.flo_m
 ORA #0                 \ patched
 STA (fl_sp),Y
.flo3
 TYA
 SBC #8
 TAY
 BNE flo2
.flo9
 LDA #4
 TSB &FE34
 RTS
