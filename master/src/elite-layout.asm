\ ******************************************************************************
\
\ elite-layout.asm - the port's memory layout (docs/MASTER-MAP.md)
\
\ Port: the file that build.sh assembles. elite-source.asm is the original's
\ main source in the original's order, and the header of each routine or
\ table names the area it lives in (no Area field: the main code's run;
\ "Area: bank 4"; "Area: cold"). Banks 4 and 7 share the addresses
\ &8000-&BFFF and BeebAsm assembles a file with one location counter, so
\ tools/streams.py writes a copy of elite-source.asm for each area, with the
\ other areas' lines blanked (build/elite-source-run.asm, -bank4.asm,
\ -cold.asm; the line numbers are the source's), and this file assembles
\ them one after the other, each at its own address. Every label is defined
\ once, in its own area's copy, and every block is assembled once:
\
\   * the run: the configuration and the workspaces, then the main code from
\     CODE% in main RAM (saved as BCODE), continuing in bank 4 at &8000 where
\     main RAM ends;
\
\   * bank 4: the blocks that must be in bank 4, after the run;
\
\   * the cold area: sideways RAM bank 7;
\
\ then the high code (main RAM &7200-&7FFF) and the renderer (elite-gfx.asm).
\
\ ******************************************************************************

 INCLUDE "build/elite-source-run.asm"

\ ******************************************************************************
\
\ Port: the main code's part in bank 4 ends here; the rest of bank 4 is the
\ game code that elite-bank4.asm holds (docs/MASTER-MAP.md), then the blocks
\ of elite-source.asm in bank 4
\
\ ******************************************************************************

 INCLUDE "src/elite-bank4.asm"

 INCLUDE "build/elite-source-bank4.asm"

.BANK4_END%

 PRINT "Bank 4: &8000-", ~BANK4_END%-1, " free ", HANGHEAP-BANK4_END%
 ASSERT BANK4_END% <= HANGHEAP
 SAVE "build/BANK4.bin", &8000, &C000, &8000

\ ******************************************************************************
\
\ Port: the high code, main RAM &7200-&7FFF (docs/MASTER-MAP.md): the
\ quarter-square tables, the renderer's game-context side (elite-hi.asm) and
\ the stubs into the cold area (elite-stubs7.asm). Code here runs only in game
\ context, never while ACCCON X is set (which hides main RAM at &3000-&7FFF).
\ Saved as HICODE, which the loader copies there.
\
\ ******************************************************************************

 ORG &7200

 INCLUDE "src/elite-hi.asm"         \ quarter squares, renderer stubs and hooks

 INCLUDE "src/elite-stubs7.asm"     \ stubs into the cold area (far7, far7j)

.HI_END%

 PRINT "Hi code: &7200-", ~HI_END%-1, " free ", &8000-HI_END%
 ASSERT HI_END% <= &8000
 SAVE "build/HICODE.bin", &7200, HI_END%, &7200

\ ******************************************************************************
\
\ Port: the cold area (docs/MASTER-MAP.md), paged in as ROMSEL = COLDBANK
\ (7): sideways RAM bank 7 at &8000-&8FFF (elite-andy.asm, which was ANDY's
\ and keeps the name) and from COLD7LO (QQ18 from elite-data.asm, the stubs
\ that lead out of the cold area, then elite-cold7.asm and the blocks of
\ elite-source.asm in the cold area). Between them bank 7 holds the extended
\ tokens (elite-gfx.asm, from &9000), then free space.
\
\ ******************************************************************************

 CLEAR &8000, &C000
 ORG &8000

 INCLUDE "src/elite-andy.asm"

.ANDY_END%

 PRINT "Bank 7 cold (elite-andy.asm): &8000-", ~ANDY_END%-1, " free ", &9000-ANDY_END%
 ASSERT ANDY_END% <= &9000
 SAVE "build/ANDY.bin", &8000, &9000, &8000

 CLEAR &8000, &C000
 ORG COLD7LO

.COLD7_START%

 INCBIN "build/QQ18D.bin"           \ QQ18, the recursive token table

 INCLUDE "src/elite-coldstubs.asm"  \ stubs out of the cold area (far4, far4j)

 INCLUDE "src/elite-cold7.asm"

 INCLUDE "build/elite-source-cold.asm"

.COLD7_END%

 PRINT "Bank 7 cold: ", ~COLD7LO, "-", ~COLD7_END%-1, " free ", &C000-COLD7_END%
 SAVE "build/COLD7.bin", COLD7LO, &C000, COLD7LO

 PRINT "Addresses for the scramble routines in elite-checksum.py"
 PRINT "F% = ", ~F%
 PRINT "G% = ", ~G%
 PRINT "NA2% = ", ~NA2%

 INCLUDE "src/elite-gfx.asm"      \ Port: the filled renderer (HAZEL, banks 5 and 6, bank 7 below COLD7LO)
