\ ******************************************************************************
\
\ p-low.asm - the parasite's low area (elite-low.asm in the Master port), at
\ the end of the main code's head. The parasite has no banks and no ACCCON,
\ so nothing here needs to be low; it keeps the place the Master port's low
\ area has in the run (docs/TUBE-MAP.md):
\
\   * the stubs into overlay D (build/elite-stubs.asm, streams.py);
\
\   * the renderer's glue: the variables the game and the renderer share
\     (gfx-gvars.asm), the G_ stubs and the text hooks (p-glue.asm), the
\     hooks in Elite's drawing code (gfx-hooks.asm);
\
\   * the Tube: the commands to the host (p-io.asm).
\
\ ******************************************************************************

 INCLUDE "build/elite-stubs.asm"        \ the stubs into overlay D (streams.py)
 INCLUDE "src/gfx-gvars.asm"            \ the renderer's shared variables
 INCLUDE "build/p-glue-frame.asm"       \ the G_ stubs, the text hooks (streams.py's pass)
 INCLUDE "build/gfx-hooks-frame.asm"    \ the hooks in Elite's drawing code (streams.py's pass)
 INCLUDE "build/p-io-frame.asm"         \ the Tube (streams.py's pass)
 INCLUDE "tsrc/p-ovl.asm"               \ the overlay region's stubs' helpers
 INCLUDE "tsrc/p-dash.asm"              \ the dashboard's parasite halves

\ The frame layer's small state (p-layout.asm keeps the rest), here before
\ the game's run: the run's first ALIGN (elite-source.asm's, before log)
\ takes it into its padding, where it costs the resident code nothing

.F_BX   SKIP 10         \ the energy bomb's bolt (f_bomb), BOMBTBX and BOMBTBY
.F_BY   SKIP 10         \ as F_BOMB found them
.F_DCOL SKIP 2          \ disc colour index in each buffer's disc layer
.f_tcol SKIP 1          \ (f_char1's column)
.f_zsv  SKIP &22 + 16   \ F_FRAME's keep of &06-&27 and FZ's &D2-&E1
.F_SLV  SKIP 52         \ the docking slot's vertices (f_poly2, f_slot,
                        \ gfx-frame_cold.asm; F_SLV+16 &80: none)
