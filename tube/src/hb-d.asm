\ ******************************************************************************
\
\ hb-d.asm - the Model B host's bank D (docs/TUBE-MAP.md): the rasteriser's
\ disc side, as the Master port's bank 5 seen with ROMSEL RASTBANK: the disc
\ window (gfx-raster_disc.asm) at &8000, the shared region (gfx-raster.asm)
\ from &9000, less the stars (bank P's), and the disc inputs from DDATA
\ (hb-ws.asm), which h_disc receives here. NMOS code (build/nmos/: the
\ Master port's sources through tube/tools/nmos.py).
\
\ ******************************************************************************

_TPART = 2
_HOSTB = TRUE
_RBANK = 1

 INCLUDE "tsrc/cmds.asm"
 INCLUDE "build/elite-source-ws.asm"
 INCLUDE "tsrc/hb-ws.asm"
 INCLUDE "build/hb-mainsyms.asm"        \ (main RAM's: hb-main.asm's first pass)

 CLEAR &8000, &C000
 GUARD DDATA
 ORG &9000
 INCLUDE "build/nmos/gfx-raster.asm"
 CPU 0
.D_HIEND
 ORG &8000
 GUARD &9000
 INCLUDE "build/nmos/gfx-raster_disc.asm"
 CPU 0
.D_LOEND
 PRINT "Model B bank D: &8000-&", ~D_LOEND-1, " (free ", &9000-D_LOEND, "), &9000-&", ~D_HIEND-1, " (free ", DDATA-D_HIEND, "), data &", ~DDATA, "-&", ~DDATA_END-1
 SAVE "build/HBD.bin", &8000, DDATA, &8000
