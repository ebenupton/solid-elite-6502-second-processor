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
\   * HAZEL: elite-data.asm's hot data (build/elite-data-hot.asm);
\
\   * the cold area, sideways RAM bank 7: elite-source.asm's cold blocks,
\     then elite-data.asm's (build/elite-data-cold.asm);
\
\ then the high code (main RAM &7200-&7FFF) and the renderer (elite-gfx.asm).
\ elite-data.asm's blocks tagged BDATA, the dashboard image, are assembled on
\ their own (build/elite-data-bdata.asm, by build.sh).
\
\ ******************************************************************************

 INCLUDE "build/elite-source-run.asm"

\ ******************************************************************************
\
\ Port: the main code's part in bank 4 ends here; the rest of bank 4 is the
\ blocks of elite-source.asm tagged bank 4 (docs/MASTER-MAP.md)
\
\ ******************************************************************************

 INCLUDE "build/elite-source-bank4.asm"

.BANK4_END%

 PRINT "Bank 4: &8000-", ~BANK4_END%-1, " free ", &C000-BANK4_END%
 ASSERT BANK4_END% <= &C000
 SAVE "build/BANK4.bin", &8000, &C000, &8000

\ ******************************************************************************
\
\ Port: HAZEL (&C000-&DFFF), visible whatever bank is paged: the hot data,
\ elite-data.asm's blocks that are not tagged (build/elite-data-hot.asm,
\ which tools/streams.py writes) in the original's order from &C000: XX21,
\ E%, KWL%, KWH%, the blueprints from the missile's to the Dodo's, SNE and
\ ACT. DOSCLI stashes all of HAZEL in screen buffer 0 around each disc
\ command, so the data may sit anywhere in it; nothing the IRQ handler or
\ CHPR uses during a command is here. After the data, the page HANGHEAP: the
\ hangar's line heap (the port's: the original's, &0B00, is in WP here), which
\ LL9 writes while HAS1 draws a ship in the hangar, and nothing else uses. Saved
\ as HAZEL, which the loader copies into place after its last disc access (and
\ the data as HZDATA, for the tools).
\
\ ******************************************************************************

 CLEAR &C000, &E000
 ORG &C000

.HZ_START

 INCLUDE "build/elite-data-hot.asm"

.HZDATA_END%

 ALIGN &100             \ (a whole page: HAS1 sets only the heap pointer's high
                        \ byte, INWK+34)
.HANGHEAP

 SKIP 256

.HZ_END

 PRINT "HAZEL: game data &C000-", ~HZDATA_END%-1, ", HANGHEAP ", ~HANGHEAP, ", free ", HANGHEAP-HZDATA_END%, " + ", &E000-HZ_END
 ASSERT HZ_END <= &E000
 SAVE "build/HZDATA.bin", &C000, HZDATA_END%, &C000
 SAVE "build/HAZEL.bin", HZ_START, HZ_END, HZ_START

\ ******************************************************************************
\
\ Port: the high code, main RAM &7200-&7FFF (docs/MASTER-MAP.md): the
\ quarter-square tables, the renderer's game-context side (elite-hi.asm) and
\ the stubs into the cold area (build/elite-stubs7.asm). Code here runs only in game
\ context, never while ACCCON X is set (which hides main RAM at &3000-&7FFF).
\ Saved as HICODE, which the loader copies there.
\
\ ******************************************************************************

 ORG &7200

 INCLUDE "src/elite-hi.asm"         \ quarter squares, renderer stubs and hooks

 INCLUDE "build/elite-stubs7.asm"   \ stubs into the cold area (far7, far7j),
                                    \ which tools/streams.py writes

.HI_END%

 PRINT "Hi code: &7200-", ~HI_END%-1, " free ", &8000-HI_END%
 ASSERT HI_END% <= &8000
 SAVE "build/HICODE.bin", &7200, HI_END%, &7200

\ ******************************************************************************
\
\ Port: the cold area (docs/MASTER-MAP.md), paged in as ROMSEL = COLDBANK
\ (7): sideways RAM bank 7 from &8000, the original's cold code and data in
\ the original's order: the blocks of elite-source.asm tagged cold, then
\ those of elite-data.asm (QQ18 and the extended tokens TKN1, RUPLA, RUGAL
\ and RUTOK), then the stubs that lead out of the cold area. Saved as COLD7.
\
\ ******************************************************************************

 CLEAR &8000, &C000
 ORG &8000

.COLD_START%

 INCLUDE "build/elite-source-cold.asm"

 INCLUDE "build/elite-data-cold.asm"    \ QQ18 and the extended tokens

 INCLUDE "build/elite-stubs4.asm"   \ stubs out of the cold area (far4, far4j),
                                    \ which tools/streams.py writes

.COLD_END%

 PRINT "Bank 7 cold: &8000-", ~COLD_END%-1, " free ", &C000-COLD_END%
 ASSERT COLD_END% <= &C000
 SAVE "build/COLD7.bin", &8000, COLD_END%, &8000

 PRINT "Addresses for the scramble routines in elite-checksum.py"
 PRINT "F% = ", ~F%
 PRINT "G% = ", ~G%
 PRINT "NA2% = ", ~NA2%

 INCLUDE "src/elite-gfx.asm"      \ Port: the filled renderer (HAZEL, banks 5 and 6, ANDY)
