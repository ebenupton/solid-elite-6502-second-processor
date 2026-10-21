\ p-polyb.asm - phase 3: the second part of R_POLY's phase A (from r_e8:
\ gfx-raster_polyb.asm), in the parasite's high area (p-layout.asm's PHIGH)

 INCLUDE "src/gfx-raster_polyb.asm"

\ p_spans: phase A's result to the host: C_POLY, the four colours, the
\ horizontal clip flag, the first and last rows, then each row's two table
\ entries (r_ta's, r_tb's)

.p_spans
 LDA #C_POLY
 PSEND
 LDA R_COLE
 PSEND
 LDA R_COLO
 PSEND
 LDA R_COL2
 PSEND
 LDA R_COL3
 PSEND
 LDA r_xclip
 PSEND
 LDA r_ystart
 PSEND
 LDA r_ylast
 PSEND
 LDY r_ystart
.psp1
 LDA r_ta,Y
 PSEND
 LDA r_tb,Y
 PSEND
 CPY r_ylast
 INY
 BCC psp1
 RTS
