\ ******************************************************************************
\
\ elite-hi.asm - the high code: the port's game-context glue, main RAM
\ &7000-&7FFF (docs/MASTER-MAP.md)
\
\ Port: none of this has a counterpart in the original; it is the glue that
\ the port adds around the original's code, for game context only. Main RAM
\ &7000-&7DFF would be the dashboard's, but the dashboard is in shadow RAM:
\ the IRQ shows shadow RAM from the dashboard's first line on (timer 1 sets
\ ACCCON D in line 191's horizontal blanking, never late), so main RAM there
\ is never on show, and this region starts at &7000. Code here must never run
\ with ACCCON X set (which hides main RAM at &3000-&7FFF), so what the IRQ,
\ the MOS vectors or code running with X set use is in the low area instead
\ (elite-low.asm); and it is not in bank 4, whose room is the main code's
\ (the run continues there). In order:
\
\   * QSL and QSH, the quarter squares that the port's multiplications (MU11,
\     MULT1, MULTS, MLTU2, MULT3, the stardust's) and the lighting use: page
\     aligned, first, as their users patch the operands' low bytes;
\
\   * the renderer's game-context half: the G_ stubs that page the frame
\     layer (bank 6) in from game code (gfx-gstubs.asm), the hooks in Elite's
\     drawing routines (gfx-hooks.asm), and the lighting's L_SUN and L_REC
\     (gfx-light.asm), which the frame layer calls with bank 6 paged in;
\
\   * the stubs into the cold area (far7, far7j), which tools/streams.py
\     generates from elite-source.asm's tags (build/elite-stubs7.asm).
\
\ Saved as HICODE, which the loader copies into place.
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

 INCLUDE "src/gfx-gstubs.asm"       \ stubs that page the frame layer in
 INCLUDE "src/gfx-hooks.asm"        \ the hooks in Elite's drawing code

 INCLUDE "src/gfx-light.asm"        \ the ship lighting's game-context half

 INCLUDE "build/elite-stubs7.asm"   \ the stubs into the cold area (far7,
                                    \ far7j), which tools/streams.py writes
