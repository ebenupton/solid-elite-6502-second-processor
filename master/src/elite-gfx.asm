\ ******************************************************************************
\
\ elite-gfx.asm - the filled renderer's memory: its shared workspace in main
\ RAM, its glue in HAZEL, banks 5 and 6, bank 7 below the cold area
\ (docs/MASTER-MAP.md)
\
\ INCLUDEd at the end of elite-source.asm (after the game's code, so that the
\ layer can use Elite's symbols). From the Demonstration Disc port (tag
\ demo-final, src/gfx-build.asm), with the memory laid out for the full
\ game. The state that more than one bank, the IRQ handler or code running
\ with ACCCON X set reads is in main RAM below &3000 (the shared workspace,
\ below the main code), which every bank sees whatever ACCCON X is. HAZEL
\ holds the game data (the ship blueprints, elite-data.asm) and the glue
\ (the cross-bank stubs and hooks, the shared variables with initial
\ values), at &C300 on, which disc commands leave alone: the IRQ and text
\ hooks run during them (DOSCLI stashes the rest of HAZEL in screen buffer
\ 0 for the command, docs/MASTER-MEMORY.md). Produces:
\
\   build/HAZEL.bin  HAZEL &C000-&DFFF: the game data and the glue, which the
\                    loader copies into place after its last disc access
\   build/BANK5.bin  sideways RAM bank 5: the rasteriser (gfx-raster.asm)
\   build/BANK6.bin  sideways RAM bank 6: the frame layer (gfx-frame.asm),
\                    the ship faces and colours (gfx-faces.asm) and its state
\   build/RAST7.bin  sideways RAM bank 7 from &8000: the rasteriser's cold
\                    code (gfx-raster7.asm), below the cold area at COLD7LO
\
\ ******************************************************************************

ACCY = 8                \ ACCCON bit Y: HAZEL at &C000-&DFFF
MAXSH = 13              \ ships per frame
MAXLN = 48              \ lines per frame
MAXDT = 64              \ dots per frame
RASTBANK = 5
GFXBANK = 6
ELITEBANK = HOMEBANK

\ HAZEL: the Cougar's and the Dodo's blueprints, SNE and ACT (elite-data.asm),
\ the glue at &C300 (the shared variables with initial values, the T_
\ trampolines, the text and IRQ hooks), then XX21 and the other blueprints to
\ the end of HAZEL (elite-data.asm, "Blueprints in HAZEL" in
\ docs/MASTER-PLAN.md). The rasteriser's bank 5 <-> 7 stubs (gfx-raster_hz.asm)
\ are in the main code below &3000, for want of room here

CLEAR &C000, &E000
ORG &C000
.HZ_START
INCBIN "build/HZDATA1.bin"
ORG &C300
.HZ_GLUE
INCLUDE "src/gfx-gvars.asm"
INCLUDE "src/gfx-tramp.asm"
INCLUDE "src/gfx-hzhooks.asm"   \ (the other hooks are in main RAM, elite-hi.asm)
.GWARP   EQUB 0         \ bit 7: TT66 is an in-system jump's (WARP sets it,
                        \ F_DIRECT clears it)
.HZ_GLUE_END
PRINT "HAZEL: game data &C000-", ~HZDATA1END%-1, ", glue &C300-", ~HZ_GLUE_END-1, " (", XX21-HZ_GLUE_END, " free), game data ", ~XX21, "-&DFFF"
ASSERT HZ_GLUE_END <= XX21
ASSERT HZDATA1END% <= &C300
ORG XX21
INCBIN "build/HZDATA2.bin"
.HZ_END
ASSERT HZ_END = &E000
SAVE "build/HAZEL.bin", HZ_START, HZ_END, HZ_START

NDSTAR = NOST+1         \ stars 1..NOSTM (Master port: NOSTM <= NOST = 20)

\ The shared workspace: the state that the rasteriser's two banks, the frame
\ layer, the game's hooks, the IRQ handler and the lens flare (which runs
\ with ACCCON X set) share, in main RAM below the main code (CODE%) and below
\ &3000, where all of them see it. Variables only (the renderer initialises
\ them: R_INIT, F_INIT), except DFSST, which the loader fills. The arrays
\ keep their low bytes from HAZEL, where their page crossings were measured:
\ raster_vars at a fixed place (the rows of the laser sights' scan in
\ R_DIRTYR0/1 must not cross a page, gfx-frame.asm's f_sight2), R_NDISCL page
\ aligned (gfx-raster_scr.asm)

ORG &1300               \ (from here to WS_END: test_raster.py assembles it too)
.WS_START
.R_SS       SKIP 24         \ star size 1..3 (raster_vars.asm: the stars)
.F_DSS      SKIP NDSTAR     \ the directly drawn stars' sizes (0 = none; see
                            \ F_DSX): cleared with R_SS (F_INIT, f_direct0)
ASSERT F_DSS = R_SS + 24
RVOFF = &182            \ R_DIRTYR0's offset in raster_vars (asserted below)
RVBASE = &14B5 - RVOFF
ASSERT P% <= RVBASE
SKIP RVBASE - P%
INCLUDE "src/gfx-raster_vars.asm"
ASSERT R_DIRTYR0 = RVBASE + RVOFF
.R_SX       SKIP 24         \ (raster_vars.asm: the stars)
.R_SY       SKIP 24
.R_WR       SKIP 192        \ (raster_vars.asm)
.R_SN       SKIP 1          \ star count 0..24
.R_SCOL     SKIP 1          \ star colour byte (R_INIT: &FF)
.fl_ml  SKIP 2          \ the lens flare (gfx-flare.asm): 32 D (x, y), low
.fl_mh  SKIP 2          \ and high bytes
.fl_sl  SKIP 2          \ the centres' sums S (x, y)
.fl_sh  SKIP 2
.fl_lev SKIP 1          \ the level, 1..3
.fl_xb  SKIP 1          \ ACCCON X while writing: 4 = clear it (buffer 0)
.WS_HI_END
ASSERT P% <= &1F00
ORG &0840               \ (the MOS's sound, printer, RS423, cassette and speech
                        \ buffers, and &0B00-&0CFF, which the Master does not use,
                        \ docs/MASTER-MEMORY.md)
.WS_LO
.R_NDN      SKIP 192        \ (raster_vars.asm: boundaries per disc row, 0..4)
INCLUDE "src/gfx-raster_scr.asm"
ASSERT R_NDISCL = &0900
.DFSST  SKIP 128        \ DFS's and the MOS's lasting bytes in HAZEL, &C2C0-&C2FF
                        \ and &DFC0-&DFFF (the MOS's FSCV copy at &DFDA-&DFDB, the
                        \ ACCCON its error path puts back at &DFDC-&DFDD), while
                        \ the game uses those places: put back for each disc
                        \ command (DOSCLI; the loader takes them first)
.DFSIN  SKIP 1          \ bit 7: a disc command is under way (DOSCLI, DOSNMI)
ASSERT DFSIN = DFSST + 128      \ (the loader clears it)
ASSERT P% <= &0C40
ORG &0C40
.R_WL       SKIP 192        \ this frame's written extents (empty: R=0)
ASSERT P% <= &0D00      \ (page &0D is off limits, docs/MASTER-MEMORY.md)
.WS_END
PRINT "Shared workspace: &0840-", ~WS_END-1, " (free ", &0C40-DFSIN-1, "), &1300-", ~WS_HI_END-1, " (free to the main code ", CODE%-WS_HI_END, ")"
ASSERT WS_HI_END <= CODE%

CLEAR &8000, &C000
ORG &8000
INCLUDE "src/gfx-raster.asm"
.B5_END
PRINT "Bank 5: rasteriser &8000-", ~B5_END-1, " free ", &C000-B5_END
ASSERT B5_END <= &C000
SAVE "build/BANK5.bin", &8000, B5_END, &8000

CLEAR &8000, &C000
ORG &8000
INCLUDE "src/gfx-frame.asm"
INCLUDE "src/gfx-faces.asm"
INCLUDE "src/gfx-light6.asm"   \ the lighting tables (and the first ramps)
INCLUDE "src/gfx-frame_cold.asm"
INCLUDE "src/gfx-flare6.asm"   \ the lens flare's step and span writer
.B6_CODE_END
.F_HW   SKIP 256        \ planet half-widths
.F_HW2  SKIP 256        \ sun half-widths
.F_DL   SKIP 1536       \ ship records: XX2 then XX3 copies
.F_DLEND
.F_TM   SKIP 768        \ text map: desired characters, 24 rows of 32
.F_SH0  SKIP 768        \ what buffer 0 shows
.F_SH1  SKIP 768        \ what buffer 1 shows
.F_TMR  SKIP 24         \ non-empty cells per row
.F_SHR0 SKIP 24
.F_SHR1 SKIP 24
.F_DSX  SKIP NDSTAR     \ the stars drawn directly (gfx-frame_cold.asm's F_DSTAR,
.F_DSY  SKIP NDSTAR     \ f_unstar): x and y (F_DSS, their sizes, in the
                        \ shared workspace after R_SS, cleared with it)
.B6_END
PRINT "Bank 6: frame layer &8000-", ~B6_CODE_END-1, ", data ", ~F_HW, "-", ~B6_END-1, " free ", &C000-B6_END
ASSERT B6_END <= &C000
SAVE "build/BANK6.bin", &8000, B6_END, &8000

CLEAR &8000, &C000
ORG &8000
INCLUDE "src/gfx-raster7.asm"   \ the rasteriser's second bank (cold code)
.R7_END
PRINT "Bank 7: rasteriser (cold) &8000-", ~R7_END-1, " free to the cold area ", COLD7LO-R7_END
ASSERT R7_END <= COLD7LO
SAVE "build/RAST7.bin", &8000, R7_END, &8000

\ Shadow RAM (ACCCON X = 1): the lens flare (gfx-flare.asm), at &7E00-&7FFF
\ after the dashboard (the screen ends at &7DFF), &3F00-&3FFF after the
\ extended tokens (elite-data.asm, &3100-&3EFF) and &3000-&308F before
\ setzp's zero page save. Main RAM at these addresses holds BCODE and the
\ stubs, saved above, so these blocks come last.
CLEAR &7E00, &8000
CLEAR &3F00, &4000
CLEAR &3000, &3090
INCLUDE "src/gfx-flare.asm"
PRINT "Shadow: lens flare &7E00-", ~SH7_END-1, " free ", &8000-SH7_END, ", &3F00-", ~SH3_END-1, " free ", &4000-SH3_END, ", &3000-", ~SH0_END-1, " free ", &3090-SH0_END
SAVE "build/FLARE7.bin", &7E00, SH7_END, &7E00
SAVE "build/FLARE3.bin", &3F00, SH3_END, &3F00
SAVE "build/FLARE0.bin", &3000, SH0_END, &3000
