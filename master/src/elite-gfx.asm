\ ******************************************************************************
\
\ elite-gfx.asm - the filled renderer's memory: its shared workspace in main
\ RAM, its glue in HAZEL, banks 5 and 6 and ANDY, and the meridian window in
\ bank 7
\ (docs/MASTER-MAP.md)
\
\ INCLUDEd at the end of elite-source.asm (after the game's code, so that the
\ layer can use Elite's symbols). From the Demonstration Disc port (tag
\ demo-final, src/gfx-build.asm), with the memory laid out for the full
\ game. The state that more than one bank, the IRQ handler or code running
\ with ACCCON X set reads is in main RAM below &3000 (the shared workspace,
\ below the main code), which every bank sees whatever ACCCON X is; so is
\ the glue (the cross-bank trampolines and hooks, the shared variables with
\ initial values), in the main code's low area (elite-low.asm), as the IRQ
\ and text hooks run during disc commands too. HAZEL holds the game data
\ (the ship blueprints, elite-data.asm: elite-layout.asm). Produces:
\
\   build/BANK5.bin  sideways RAM bank 5: the rasteriser's shared region and
\                    disc window (gfx-raster.asm, gfx-flare.asm,
\                    gfx-raster_lcold.asm; gfx-raster_disc.asm)
\   build/RASTA.bin  ANDY: the rasteriser's polygon window (gfx-raster_poly.asm,
\                    gfx-raster_line.asm)
\   build/BANK6.bin  sideways RAM bank 6: the frame layer (gfx-frame.asm),
\                    the ship faces and colours (gfx-faces.asm) and its state
\   build/MERID.bin  sideways RAM bank 7 after the cold area: the meridian
\                    window, the beach ball planet's boundaries (gfx-merid.asm)
\
\ ******************************************************************************

INCLUDE "src/gfx-ws.asm"      \ the constants and the shared workspace


CLEAR &8000, &C000      \ bank 5: the shared region from &9000 (the per-x tables,
ORG &9000               \ the row runs, the boundary arrays, the stars, the lens
INCLUDE "src/gfx-raster.asm"   \ flare ...), then the disc window at &8000
INCLUDE "src/gfx-flare.asm"    \ the lens flare (its step in bank 6: gfx-flare6.asm)
INCLUDE "src/gfx-raster_lcold.asm"   \ R_LINE's cold part
.B5_END
ASSERT B5_END <= &C000
ORG &8000
INCLUDE "src/gfx-raster_disc.asm"
INCLUDE "src/gfx-raster_kept.asm"   \ kept solid rows: bank 5's part

.B5LO_END
ASSERT B5LO_END <= &9000
PRINT "Bank 5: rasteriser: disc window &8000-", ~B5LO_END-1, " (free ", &9000-B5LO_END, "), shared &9000-", ~B5_END-1, " free ", &C000-B5_END, " (+ ", r_tables-r_tfree, " at ", ~r_tfree, ")"
SAVE "build/BANK5.bin", &8000, B5_END, &8000

CLEAR COLD_END%, &C000  \ bank 7 after the cold area (ROMSEL MERIDBANK): the
ORG COLD_END%           \ meridian window, the beach ball planet's boundaries
.MERID_START
INCLUDE "src/gfx-merid.asm"
INCLUDE "src/gfx-kept7.asm"    \ kept solid rows: the polygons' part (SOLIDSPAN-REPORT.md)
.MERID_END
ASSERT MERID_END <= &C000
PRINT "Bank 7: meridian window ", ~MERID_START, "-", ~MERID_END-1, ", bank 7 free ", &C000-MERID_END
SAVE "build/MERID.bin", MERID_START, MERID_END, MERID_START

CLEAR &8000, &9000      \ ANDY (ROMSEL &85): the rasteriser's polygon window
ORG &8000
INCLUDE "src/gfx-raster_poly.asm"
INCLUDE "src/gfx-raster_line.asm"   \ R_LINE
.RA_END
ASSERT RA_END <= &9000
PRINT "ANDY: rasteriser polygon window &8000-", ~RA_END-1, " free ", &9000-RA_END
SAVE "build/RASTA.bin", &8000, RA_END, &8000

CLEAR &8000, &C000
ORG &8000
INCLUDE "src/gfx-frame.asm"
INCLUDE "src/gfx-faces.asm"
INCLUDE "src/gfx-light6.asm"   \ the lighting tables (and the first ramps)
INCLUDE "src/gfx-light.asm"    \ the lighting's L_SUN and L_REC
INCLUDE "src/gfx-frame_cold.asm"
INCLUDE "src/gfx-flare6.asm"   \ the lens flare's step (the flare: gfx-flare.asm, bank 5)
INCLUDE "src/gfx-hangar.asm"   \ the hangar's frame (HALL; its tables are in HAZEL)
.B6_CODE_END
.F_HW   SKIP 256        \ planet half-widths
.F_HW2  SKIP 256        \ sun half-widths
.F_DL                   \ ship records: XX2 then XX3 copies (1536 bytes)
 SKIP &22
 INCLUDE "src/gfx-finit.asm"   \ F_INIT, run once before the first frame
 SKIP F_DL + 1536 - P%
.F_DLEND
.F_TM   SKIP 768        \ text map: desired characters, 24 rows of 32
.F_ST   SKIP 768        \ what each buffer shows in each cell (gfx-frame.asm)
ASSERT F_ST = F_TM + &300
.F_TMR  SKIP 24         \ non-empty cells per row
.F_SHR0 SKIP 24
.F_SHR1 SKIP 24
.F_DSX  SKIP NDSTAR     \ the stars drawn directly (gfx-frame_cold.asm's F_DSTAR,
.F_DSY  SKIP NDSTAR     \ f_unstar): x and y (their sizes, F_DSS, in the shared
                        \ workspace)
 INCLUDE "src/gfx-hangar6.asm"   \ the hangar's tables (f_hback; data
                        \ before them stays at its place)
.B6_END
PRINT "Bank 6: frame layer &8000-", ~B6_CODE_END-1, ", data ", ~F_HW, "-", ~B6_END-1, " free ", &C000-B6_END
ASSERT B6_END <= &C000
SAVE "build/BANK6.bin", &8000, B6_END, &8000
