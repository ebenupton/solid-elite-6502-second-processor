\ ******************************************************************************
\
\ hb-line.asm - the Model B host's lines, in bank F (hb-main.asm): R_LINE
\ (gfx-raster_line.asm, gfx-raster_lineb.asm), its cold part (rl_mdq,
\ rl_long: gfx-raster_lcold.asm's), the arithmetic and r_pset they use, and
\ their tables and variables (gfx-raster.asm's, which bank P keeps for its
\ own). The lines fill no spans (pixel by pixel), so they need none of bank
\ P's row runs, and C_LINE runs here with no paging; bank P has the room for
\ both buffers' runs. f_bufpatch patches their screen base (r_bs2, r_bs8).
\ NMOS code (build/nmos/)
\
\ ******************************************************************************

 ALIGN &100
.r_xo                   \ (8 * (x DIV 4)) AND &FF : edge byte offset
FOR x, 0, 255
  EQUB (x * 2) AND &F8
NEXT
.r_lm                   \ pixels (x AND 3)..3 of a byte
FOR x, 0, 255
  EQUB ((&F0 >> (x AND 3)) AND &F0) OR (&0F >> (x AND 3))
NEXT
.r_rm                   \ pixels 0..(x AND 3) of a byte
FOR x, 0, 255
  EQUB ((&F0 << (3 - (x AND 3))) AND &F0) OR ((&0F << (3 - (x AND 3))) AND &0F)
NEXT

\ R_LINE's variables (as gfx-raster.asm's)
.rl_lct SKIP 8          \ R_LINE: colour byte by row AND 7
.rl_lbuf EQUB &FF       \ buffer R_LINE's DIRTY operands are patched for
.rl_dx SKIP 2            \ P1 - P0: x, y (rl_dx + 2)
.rl_dy SKIP 2
.rl_ax SKIP 2            \ |dx|, |dy| (rl_ax + 2)
.rl_ay SKIP 2
.rl_d  SKIP 2            \ |d major|
.rl_a  SKIP 2            \ |d minor|
.rl_h  SKIP 2            \ d DIV 2
.rl_m0 SKIP 2            \ the left / top end: major, minor
.rl_n0 SKIP 2
.rl_i  SKIP 2            \ the first pixel inside, the last (i)
.rl_j  SKIP 2
.rl_t  SKIP 2            \ rl_mdq's signed addend
.rl_mo SKIP 1            \ major axis: 0 = x, 2 = y (an offset into R_X0.., R_CL..)
.rl_s  SKIP 1            \ bit 7: the minor coordinate decreases
.rl_lo SKIP 1            \ major window lo, hi; minor window lo, hi
.rl_hi SKIP 1
.rl_nl SKIP 1
.rl_nh SKIP 1
r_dl = R_DIRTYL0         \ (r_pset's dirty extents: unused on the dumb host)
r_dr = R_DIRTYR0
.r_m0 EQUB 0            \ (r_div8, r_dvq: quotient, divisor; gfx-raster.asm's)
.r_v0 EQUB 0

 INCLUDE "build/nmos/gfx-raster_line.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-raster_lineb.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-raster_lcold-frame.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-raster_arith.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-raster_pset.asm"
 CPU 0
T_LINE = R_LINE         \ (h_line's: no paging)
