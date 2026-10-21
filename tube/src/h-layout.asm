\ ******************************************************************************
\
\ h-layout.asm - the host's memory (docs/TUBE-MAP.md): phase 1, a BBC Master
\ host, laid out as the Master port's display side
\
\   * zero page, K% and WP: the game's definitions (build/elite-source-ws.asm),
\     so that the host's copies of the game's drawing code see their
\     variables where the parasite has them (the commands carry the values);
\   * the renderer's shared workspace at &0E40-&1EDB (gfx-ws.asm), then from
\     &1EDC (below &3000, as code that runs with ACCCON X set must be) the
\     game's host blocks (the sound, the IRQ, CHPR and its font, UP), the
\     renderer's glue and the command loop (h-main.asm);
\   * the rasteriser in bank 5 and ANDY, the frame layer's host part (the text
\     map, the text overlay, the sights) in bank 6, as the Master port's;
\   * the screen: buffer 0 in main RAM, buffer 1 and the dashboard in shadow
\     RAM, as the Master port's.
\
\ ******************************************************************************

_TPART = 2

 INCLUDE "tsrc/cmds.asm"
 INCLUDE "build/elite-source-ws.asm"
 INCLUDE "src/gfx-ws.asm"

 ORG CODE%
 GUARD &3000
.H_START
 INCLUDE "build/elite-source-host.asm"
 INCLUDE "src/gfx-gvars.asm"
 INCLUDE "src/gfx-tramp.asm"
 INCLUDE "src/gfx-lowhooks.asm"
 INCLUDE "tsrc/h-main.asm"
.H_END
 PRINT "Host: main code &", ~H_START, "-&", ~H_END-1, ", free to &3000: ", &3000-H_END
 SAVE "build/HMAIN.bin", H_START, H_END, hwrch


 CLEAR &8000, &C000      \ bank 5: the rasteriser's shared region and disc window
 GUARD &C000
 ORG &9000
 INCLUDE "src/gfx-raster.asm"
 INCLUDE "src/gfx-flare.asm"
 INCLUDE "src/gfx-raster_lcold.asm"
.B5_END
 ORG &8000
 INCLUDE "src/gfx-raster_disc.asm"
.B5LO_END
 ASSERT B5LO_END <= &9000
 PRINT "Host: bank 5 &8000-&", ~B5_END-1
 SAVE "build/HBANK5.bin", &8000, B5_END, &8000

 CLEAR &8000, &9000      \ ANDY: the polygon window
 ORG &8000
 INCLUDE "src/gfx-raster_poly.asm"
 INCLUDE "src/gfx-raster_line.asm"
.RA_END
 ASSERT RA_END <= &9000
 SAVE "build/HRASTA.bin", &8000, RA_END, &8000

 CLEAR &8000, &C000      \ bank 6: the frame layer's host part
 ORG &8000
 INCLUDE "src/gfx-frame.asm"
 INCLUDE "src/gfx-frame_cold.asm"
.B6_CODE_END
.F_HW   SKIP 256        \ (f_enter's buffer)
.F_HW2  SKIP 256
.F_TM   SKIP 768
.F_ST   SKIP 768
ASSERT F_ST = F_TM + &300
.F_TMR  SKIP 24
.F_SHR0 SKIP 24
.F_SHR1 SKIP 24
.F_DSX  SKIP NDSTAR
.F_DSY  SKIP NDSTAR
.f_hwr  EQUB 0          \ (the parasite's half-width cache tags, which f_enter2
.f_hw2r EQUB 0          \ clears: unused here)
ALIGN &100
.HSW                    \ the parasite's &F800-&FEEF that is not in it (h_swap):
 INCBIN "build/PHIGH.bin" \ the high code at first, the client OS's while it runs
 SKIP HSW + &6F0 - P%
.B6_END
 PRINT "Host: bank 6 &8000-&", ~B6_END-1, " (code to &", ~B6_CODE_END-1, ")"
 SAVE "build/HBANK6.bin", &8000, B6_END, &8000
