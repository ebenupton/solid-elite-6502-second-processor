\ ******************************************************************************
\
\ elite-hi.asm - the high code: the start of the run's second part, main RAM
\ from &7000 (docs/MASTER-MAP.md)
\
\ Port: none of this has a counterpart in the original. Main RAM &7000-&7DFF
\ would be the dashboard's, but the dashboard is in shadow RAM: the IRQ shows
\ shadow RAM from the dashboard's first line on (timer 1 sets ACCCON D in
\ line 191's horizontal blanking, never late), so main RAM from &7000 is never
\ on show. The main code's run continues there (elite-source.asm, at its
\ split before TACTICS), through &8000 into bank 4, after this prefix, which
\ must be visible whatever bank is paged (so neither in bank 4 nor in the
\ renderer's banks) and is too big for the low area below &3000. Like the
\ run there, it never runs with ACCCON X set (which hides main RAM at
\ &3000-&7FFF). In order:
\
\   * QSL and QSH, the quarter squares that the port's multiplications (MU11,
\     MULT1, MULTS, MLTU2, MULT3, the stardust's) and the lighting use, with
\     bank 4, 6 or 7 paged: page aligned, first, as their users patch the
\     operands' low bytes;
\
\   * the lighting's L_SUN and L_REC (gfx-light.asm), the renderer's
\     game-context maths, which the frame layer calls with bank 6 paged in.
\
\ Saved with the run's part in main RAM from &7000 as HICODE, which the
\ loader copies into place.
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

 ASSERT LO(P%) = 0       \ (page aligned: the multiplications patch their
                        \ operands' low bytes, QSL+b and QSL-b, and index them)

.QSL

FOR n, 0, 511
 EQUB LO(n * n DIV 4)
NEXT

.QSH

FOR n, 0, 511
 EQUB HI(n * n DIV 4)
NEXT


 INCLUDE "src/gfx-light.asm"        \ the ship lighting's game-context half
