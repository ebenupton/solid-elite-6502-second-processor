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
 INCLUDE "src/gfx-hooks.asm"            \ the hooks in Elite's drawing code
 INCLUDE "build/p-io-frame.asm"         \ the Tube (streams.py's pass)
 INCLUDE "tsrc/p-ovl.asm"               \ the overlay region's stubs' helpers
 INCLUDE "tsrc/p-dash.asm"              \ the dashboard's parasite halves
