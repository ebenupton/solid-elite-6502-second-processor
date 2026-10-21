\ h-zp.asm - h-main.asm's zero page names (its own file: the Model B host's
\ hb-main.asm needs them before its main RAM code)

\ the rasteriser's zero page (gfx-raster.asm, gfx-flare.asm, which are
\ assembled after this file)
zR_COLE = &06
zR_COLO = &07
zR_XL = &08
zR_XR = &09
zR_CL = &0A
zR_CR = &0B
zR_CT = &0C
zR_CB = &0D
zR_DCE = &0E
zR_DCO = &0F
zfl_dx = &10
zfl_dy = &11
zc_YE = &1E              \ (r7_rowrep's c_YE, for the pre-erase)

hsp = &E4                \ (a pointer: zero page the game leaves free)

