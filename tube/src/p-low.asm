\ ******************************************************************************
\
\ p-low.asm - the parasite's glue (elite-glue.asm and the low area in the
\ Master port), first in the resident code (p-layout.asm). The parasite has
\ no banks and no ACCCON, so nothing here needs to be low (docs/TUBE-MAP.md):
\
\   * the stubs into overlay D (build/elite-stubs.asm, streams.py);
\
\   * the renderer's glue: the variables the game and the renderer share
\     (gfx-gvars.asm), the G_ stubs and the text hooks (p-glue.asm), the
\     hooks in Elite's drawing code (gfx-hooks.asm);
\
\   * the Tube: the commands to the host (p-io.asm), the overlay manager
\     (p-ovl.asm), the dashboard's parasite halves (p-dash.asm).
\
\ ******************************************************************************

 INCLUDE "build/elite-stubs.asm"        \ the stubs into overlay D (streams.py)
 INCLUDE "src/gfx-gvars.asm"            \ the renderer's shared variables
 INCLUDE "build/p-glue-frame.asm"       \ the G_ stubs, the text hooks (streams.py's pass)
 INCLUDE "build/gfx-hooks-frame.asm"    \ the hooks in Elite's drawing code (streams.py's pass)
 INCLUDE "build/p-io-frame.asm"         \ the Tube (streams.py's pass)
 INCLUDE "build/p-ovl-frame.asm"        \ the overlay region's stubs' helpers
 INCLUDE "build/p-dash-frame.asm"       \ the dashboard's parasite halves

