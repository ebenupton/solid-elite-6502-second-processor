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

\ G_DIRECT's end (gfx-gstubs.asm), here so that no stub or hook moves: if
\ F_DIRECT kept space mode (an in-system jump), return to TTX66's caller
\ instead, with TTX66's results but no screen clear and border (F_DIRECT set
\ XC = YC = 1 and X = Y = 0; COL is as it was): A = %00001001, C = 0 and
\ V = 0 (from the BIT: GMODE = &80), as TTX66 returns

.gdir2
 BIT GMODE
 BPL gdir9
 PLA
 PLA
 JSR gback
 LDA #%00001001
 CLC
 RTS
.gdir9
 JMP gback

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

 ALIGN &100

.QSL

FOR n, 0, 511
 EQUB LO(n * n DIV 4)
NEXT

.QSH

FOR n, 0, 511
 EQUB HI(n * n DIV 4)
NEXT

 INCLUDE "src/gfx-light.asm"        \ the ship lighting's game-context half
