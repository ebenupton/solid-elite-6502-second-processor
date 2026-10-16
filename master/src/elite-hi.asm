\ ******************************************************************************
\
\ elite-hi.asm - code in main RAM &7200-&7DFF (docs/MASTER-MAP.md)
\
\ Main RAM &7000-&7DFF would be the dashboard's, but the dashboard is in
\ shadow RAM (the IRQ shows shadow RAM from the dashboard's first line on):
\ only its first character row (&7000-&71FF) is kept, as a copy of the static
\ image, so that a split that lands a few lines late shows the dashboard
\ rather than code. Code here must never run with ACCCON X set (which hides
\ main RAM at &3000-&7FFF): the renderer's game-context stubs and hooks.
\
\ ******************************************************************************

 INCLUDE "src/gfx-gstubs.asm"       \ stubs that page the frame layer in
 INCLUDE "src/gfx-hooks.asm"        \ the hooks in Elite's drawing code
