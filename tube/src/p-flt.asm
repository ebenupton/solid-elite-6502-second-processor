\ p-flt.asm - the lens flare's tables and variables on the parasite (the Master
\ port's are in gfx-raster.asm's run pages' tails): fl_htab in one page

 ALIGN &100
.fl_htab                \ the lens flare's half-widths (gfx-flare.asm): the
MACRO FLHW r            \ widest x with x^2 + d^2 <= r^2 + r, d = 0..r
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
.fl_ml  SKIP 2          \ 32 D (x, y), low and high bytes
.fl_mh  SKIP 2
.fl_sl  SKIP 2          \ the centres' sums S (x, y)
.fl_sh  SKIP 2
.fl_lev SKIP 1          \ the level, 1..3
