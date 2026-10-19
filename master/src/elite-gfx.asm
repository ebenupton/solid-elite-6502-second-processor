\ ******************************************************************************
\
\ elite-gfx.asm - the filled renderer's memory: HAZEL, banks 5 and 6, bank 7
\ below the cold area (docs/MASTER-MAP.md)
\
\ INCLUDEd at the end of elite-source.asm (after the game's code, so that the
\ layer can use Elite's symbols). From the Demonstration Disc port (tag
\ demo-final, src/gfx-build.asm), with the HAZEL layout changed for disc
\ access (docs/MASTER-MEMORY.md): DFS overwrites &C000-&C2FF, &DC00 up to
\ the end of an OSCLI command and &DF00-&DFFF, and writes its own and
\ ADFS's private pages &D900-&DAFF. So &C000-&C2FF holds only the
\ rasteriser's scratch variables (no call reads what an earlier one left
\ there; DOSCLI puts DFS's lasting bytes &C2C0-&C2FF back for each disc
\ command), the code and the lasting state are at &C300-&D8FF, and
\ &DC40-&DFFF holds only state rebuilt on re-entering flight. Produces:
\
\   build/HAZEL.bin  HAZEL &C300 to the end of the code (and the variables
\                    with initial values), which the loader copies into place
\                    after its last disc access
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

CLEAR &C000, &E000
ORG &C000

INCLUDE "src/gfx-raster_scr.asm"
.HZ_SCR_END
ASSERT HZ_SCR_END <= &C300      \ (DFS's &C2C0-&C2FF: stashed in DFSST)

ORG &C300
.HZ_START
INCLUDE "src/gfx-gvars.asm"
INCLUDE "src/gfx-tramp.asm"
INCLUDE "src/gfx-hzhooks.asm"   \ (the other hooks are in main RAM, elite-hi.asm)
INCLUDE "src/gfx-raster_hz.asm" \ the rasteriser's cross-bank stubs (bank 5 <-> 7)
INCLUDE "src/elite-hazel.asm"   \ game code in HAZEL
.GWARP   EQUB 0         \ bit 7: TT66 is an in-system jump's (WARP sets it,
                        \ F_DIRECT clears it)
.HZ_CODE_END

\ raster_vars at a fixed place, whatever the size of the code above: the
\ rows of the laser sights' scan in R_DIRTYR0/1 must not cross a page
\ (gfx-frame.asm's f_sight2 asserts it), and the code is free to grow up
\ to here
RVOFF = &182            \ R_DIRTYR0's offset in raster_vars (asserted below)
RVBASE = &C8B5 - RVOFF
ASSERT P% <= RVBASE
SKIP RVBASE - P%
INCLUDE "src/gfx-raster_vars.asm"
ASSERT R_DIRTYR0 = RVBASE + RVOFF
\ The CMYK dashboard's scalar variables (elite-dash.asm; the dashboard
\ routines run with ACCCON X set, so not main RAM above &3000)
.DASHV
.dpE    SKIP 1          \ the current colour pair (even, odd lines)
.dpO    SKIP 1
.dmk    SKIP 1          \ the current byte mask
.dlo    SKIP 1          \ DSEG: byte range [dlo, dhi) of the indicator
.dhi    SKIP 1
.dsS    SKIP 1          \ DSEG: the segment [dsS, dsE) in pixels
.dsE    SKIP 1
.dl0    SKIP 1          \ DSEG: the first line and the number of lines
.dln    SKIP 1
.dcol   SKIP 1          \ DIL: the colour number
.dtmp   SKIP 1
.ddn    SKIP 1          \ ddot: lines to go
.deq    SKIP 1          \ DSEG: the segment's end byte, pixels in it
.der    SKIP 1
.dsq    SKIP 1          \ DSEG: the segment's start byte, pixels from it on
.dsr    SKIP 1
.dme    SKIP 1          \ DSEG: the masked even-line byte, even EOR odd
.dmx    SKIP 1
.dsx    SKIP 1
.dtv    SKIP 1
.dK     SKIP 1          \ DIL: colour numbers for values >= dT and < dT
.dK1    SKIP 1
.dT     SKIP 1          \ DIL: the colour threshold (pixels)
.dbank  SKIP 4 \ the energy banks' bar lengths (32 per bank)
.dX1    SKIP 1          \ the dot's x-coordinate (SCAN, DOT)
.dlen   SKIP 1          \ SCAN: the stick's length (signed)
.dstab  SKIP 8          \ SCAN: the stick's byte for each line of a row
NDSTAR = NOST+1         \ stars 1..NOSTM (Master port: NOSTM <= NOST = 20)
.F_DSX  SKIP NDSTAR     \ the stars drawn directly (gfx-frame_cold.asm's F_DSTAR,
.F_DSY  SKIP NDSTAR     \ f_unstar): x and y (F_DSS, their sizes, after R_SS)
.fl_ml  SKIP 2          \ the lens flare (gfx-flare.asm): 32 D (x, y), low
.fl_mh  SKIP 2          \ and high bytes
.fl_sl  SKIP 2          \ the centres' sums S (x, y)
.fl_sh  SKIP 2
.fl_lev SKIP 1          \ the level, 1..3
.fl_xb  SKIP 1          \ ACCCON X while writing: 4 = clear it (buffer 0)
.DFSST  SKIP 66         \ DFS's and the MOS's lasting bytes in HAZEL, &C2C0-&C2FF
                        \ and &DFDA-&DFDB, while the game uses those places: put
                        \ back for each disc command (DOSCLI; the loader takes
                        \ them first)
.DFSIN  SKIP 1          \ bit 7: a disc command is under way (DOSCLI, DOSNMI)
ASSERT DFSIN = DFSST + 66       \ (the loader clears it)
.HZ_END
PRINT "HAZEL: scratch &C000-", ~HZ_SCR_END-1, ", code ", ~HZ_START, "-", ~HZ_CODE_END-1, " (", RVBASE-HZ_CODE_END, " free), data ", ~RVBASE, "-", ~HZ_END-1, " (", &DC00-HZ_END, " free to &DC00)"
ASSERT HZ_END <= &D900          \ (&D900-&DAFF: the ADFS and DFS private pages,
                                \ written by disc commands)


ORG &DC40                       \ (after the longest OSCLI command the game
                                \ issues, see SVE and friends)
.R_NDN    SKIP 192       \ (raster_vars.asm: boundaries per disc row, 0..4)
.R_WL    SKIP 192       \ this frame's written extents (empty: R=0)
\ (raster_vars.asm: the stars, R_SS after R_WR)
.R_SN       SKIP 1          \ star count 0..24
.R_SX       SKIP 24
.R_SY       SKIP 24
.R_SCOL     SKIP 1          \ star colour byte (R_INIT: &FF)
.R_WR    SKIP 192       \ (raster_vars.asm)
.R_SS       SKIP 24         \ star size 1..3
.F_DSS      SKIP NDSTAR     \ the directly drawn stars' sizes (0 = none; see
                            \ F_DSX): cleared with R_SS (F_INIT, f_direct0)
ASSERT F_DSS = R_SS + 24
.HZ_END2
PRINT "HAZEL: data &DC40-", ~HZ_END2-1, " free to &E000 ", &E000-HZ_END2
ASSERT HZ_END2 <= &E000         \ (&DF00-&DFFF: the MOS's filing system workspace
                                \ during disc commands; DOSCLI's stash has its
                                \ lasting bytes)
SAVE "build/HAZEL.bin", HZ_START, HZ_CODE_END, HZ_START

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
