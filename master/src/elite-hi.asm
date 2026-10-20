\ ******************************************************************************
\
\ elite-hi.asm - the high code, main RAM &7200-&7FFF (docs/MASTER-MAP.md)
\
\ Main RAM &7000-&7DFF would be the dashboard's, but the dashboard is in
\ shadow RAM (the IRQ shows shadow RAM from the dashboard's first line on):
\ only its first character row (&7000-&71FF) is kept, as a copy of the static
\ image, so that a split that lands a few lines late shows the dashboard
\ rather than code. Code here must never run with ACCCON X set (which hides
\ main RAM at &3000-&7FFF): the quarter-square tables, the renderer's
\ game-context stubs and hooks, and the ship lighting's game-context half,
\ followed by the stubs into the cold area (build/elite-stubs7.asm).
\
\ ******************************************************************************

\ ******************************************************************************
\
\       Name: QSL, QSH
\       Type: Variable
\   Category: Maths (Arithmetic)
\    Summary: Port: quarter squares for MULTS, MU11 and MULT1
\
\ ------------------------------------------------------------------------------
\
\ QSL and QSH are the low and high bytes of n^2 / 4 (rounded down) for n =
\ 0..511, so a * b = QS(a + b) - QS(|a - b|) for 8-bit a and b. The
\ multiplications that use them run in game context only (never with ACCCON
\ X set, which would hide these tables).
\
\ ******************************************************************************

 ASSERT LO(P%) = 0       \ (page-aligned: no page-crossing cycles on the
                        \ indexed look-ups)

.QSL

FOR n, 0, 511
 EQUB LO(n * n DIV 4)
NEXT

.QSH

FOR n, 0, 511
 EQUB HI(n * n DIV 4)
NEXT

 INCLUDE "src/gfx-gstubs.asm"       \ stubs that page the frame layer in
 INCLUDE "src/gfx-hooks.asm"        \ the hooks in Elite's drawing code

 INCLUDE "src/gfx-light.asm"        \ the ship lighting's game-context half
