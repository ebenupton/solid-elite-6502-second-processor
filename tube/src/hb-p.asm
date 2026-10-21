\ ******************************************************************************
\
\ hb-p.asm - the Model B host's bank P (docs/TUBE-MAP.md): the rasteriser's
\ polygon side, as the Master port's ROMSEL RASTPOLY (ANDY over bank 5): the
\ polygon window (gfx-raster_poly.asm, gfx-raster_line.asm) at &8000, the
\ shared region (gfx-raster.asm) from &9000 with the stars, then the flare
\ and the lines' cold part; the polygon inputs at PDATA (hb-ws.asm), where
\ bank D has the boundary arrays. NMOS code (build/nmos/).
\
\ ******************************************************************************

_TPART = 2
_HOSTB = TRUE
_RBANK = 2

 INCLUDE "tsrc/cmds.asm"
 INCLUDE "build/elite-source-ws.asm"
 INCLUDE "tsrc/hb-ws.asm"
 INCLUDE "build/hb-mainsyms.asm"

 CLEAR &8000, &C000
 GUARD &C000
 ORG &9000
 INCLUDE "build/nmos/gfx-raster.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-flare.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-raster_lcold.asm"
 CPU 0
.P_HIEND
 ORG &8000
 GUARD PDATA
 INCLUDE "build/nmos/gfx-raster_poly.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-raster_line.asm"
 CPU 0
.P_LOEND
 PRINT "Model B bank P: &8000-&", ~P_LOEND-1, " (free ", PDATA-P_LOEND, "), &9000-&", ~P_HIEND-1, " (free ", &C000-P_HIEND, ")"
 SAVE "build/HBP.bin", &8000, &C000, &8000
