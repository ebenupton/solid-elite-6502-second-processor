\ ******************************************************************************
\
\ p-polya.asm - phase 3 (docs/TUBE-PLAN.md): R_POLY's phase A on the parasite.
\ The Master port's own phase A (gfx-raster_poly.asm, assembled with
\ _TPART = 1: the clipping and the edge walking, 8-bit and 16-bit paths, into
\ the per-row tables) runs here, in the high area (p-layout.asm's PHIGH);
\ p_spans sends the host the rows' tables and the colours (C_POLY), and the
\ host goes on from r_pcbd (the orientation, the horizontal clip, the
\ trimming, the dirty rows, then phase B) as before.
\
\ ******************************************************************************

RZ_PA   = &10           \ (gfx-raster.asm's zero page: F_FRAME has saved &06-&27)
RZ_PB   = &12
RZ_PP   = &14
RZ_COL  = &16
RZ_Y    = &17
RZ_SA   = &18
RZ_TA   = &1A
RZ_SB   = &1C
RZ_TB   = &1E
RZ_T0   = &20
RZ_T1   = &21
RZ_T2   = &22
RZ_T3   = &23
RZ_T4   = &24
RZ_T5   = &25
RZ_T6   = &26
RZ_T7   = &27

r_ta = R_NDX2           \ the edge tables (R_NDX2/3: free once the disc layer's
r_tb = R_NDX3           \ boundaries have gone to the host, as the ships come after)
.r_ystart EQUB 0
.r_ylast EQUB 0
.r_yend  EQUB 0
.r_xclip EQUB 0
.r_cr1   EQUB 0
.r_n     EQUB 0
.r_i0    EQUB 0
.r_i1    EQUB 0
.r_yminL EQUB 0
.r_yminH EQUB 0
.r_ymaxL EQUB 0
.r_ymaxH EQUB 0
.r_top   EQUB 0
.r_cc    EQUB 0
.r_m0    EQUB 0
.r_v0    EQUB 0

 INCLUDE "src/gfx-raster_arith.asm"
 INCLUDE "src/gfx-raster_poly.asm"      \ (R_POLY, r_pf8; the rest: p-polyb.asm)

