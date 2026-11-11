\ ******************************************************************************
\
\ h-layout.asm - the host's memory (docs/TUBE-MAP.md): phase 1, a BBC Master
\ host, laid out as the Master port's display side
\
\   * zero page, K% and WP: the game's definitions (build/elite-source-ws.asm),
\     so that the host's copies of the game's drawing code see their
\     variables where the parasite has them (the commands carry the values);
\   * CHPR's font at &0400-&06FF, the pages of the MOS's Tube code, which
\     runs the boot and then is never called again (hstart clears &027A,
\     and the disc commands are the host's own I/O, h_disc): the loader
\     brings it after the kernel's code, and hstart moves it there;
\   * the kernel, main RAM below &3000, which every bank and either setting
\     of ACCCON X sees: from &0E00 its workspace, ylookup (the page of each
\     pixel row's character row, which hstart makes: one copy for the game's
\     drawing and the rasteriser, as r_ypg) and of the renderer's shared
\     workspace only what the host's code names (below); then from KCODE,
\     above the loader's part that loads it, the game's host blocks (the
\     sound, the IRQ, CHPR, UP), the renderer's glue, the command loop
\     (h-main.asm), the recursive tokens, which the IRQ reads, and the
\     span kernel: the code that enters the STA runs, and their tables;
\   * the rasteriser in bank 5 and ANDY, the frame layer's host part (the text
\     map, the text overlay, the sights) in bank 6, as the Master port's;
\   * the STA runs (h-sta.asm) in banks 4, 5, 6 and 7, their pages' tails
\     holding pages of the overlays' storage (bank 7: build/hstore.asm;
\     bank 4's are free); the planet is wholly the parasite's;
\   * the screen: buffer 0 in main RAM, buffer 1 and the dashboard in shadow
\     RAM, as the Master port's.
\
\ ******************************************************************************

_TPART = 2
_HOSTB = FALSE          \ (not the Model B host: hb-*.asm)
_RBANK = 0

 INCLUDE "tsrc/cmds.asm"
 INCLUDE "build/povl.asm"
OVLBANK = 4             \ the parasite's overlays' images (storage only: h_ovlget):
OVLSBANK = 7            \ D in bank 4, S and its state in bank 7
 INCLUDE "build/elite-source-ws.asm"

\ The kernel's workspace: of the renderer's shared workspace (elite-gfx.asm),
\ only what the host's code names, at the host's own addresses (tube/build.sh
\ writes build/h-ws.asm from these lines, the declarations in the source's
\ order; a name the host's code uses that is not listed fails the assembly):
\ the lines' end points, phase B's colours and rows, the stars, the directly
\ drawn stars' sizes and DFS's lasting bytes
\ HWS R_X0 R_Y0 R_X1 R_Y1 R_COL2 R_COL3 R_PYS R_PYE
\ HWS R_SS R_SX R_SY R_SN R_SCOL F_DSS DFSST
HFONT = &0400           \ (CHPR's font: FONT%, elite-source.asm)
KCODE = &1240           \ (the kernel's code: tube/src/loader.asm asserts that
                        \ its part that runs after loading this is below)
 ORG &0E00
.ylookup SKIP 256       \ (hstart makes it: h-cold.asm)
r_ypg = ylookup         \ (rows 0..191: gfx-raster.asm's)
 INCLUDE "build/h-ws.asm"
 ASSERT P% <= KCODE
 PRINT "Host: the kernel's workspace &0E00-&", ~P%-1, ", free to the code at &", ~KCODE, ": ", KCODE-P%



 ORG KCODE
 GUARD &3000
.H_START
 CPU 1
\ The span kernel: the code that enters the STA runs (the blocks of the
\ rasteriser's files tagged "Area: kernel", streams.py's passes: r_rowset,
\ r_spc, the per-x tables, R_SPAN, r_dspin, phase B), the runs' tables and
\ generator (h-sta.asm)
 INCLUDE "build/gfx-raster-kernel.asm"
 INCLUDE "build/gfx-raster_lcold-kernel.asm"
 INCLUDE "build/gfx-raster_polyb-kernel.asm"
IF _HSTA
 INCLUDE "tsrc/h-sta.asm"
ELSE
 INCLUDE "tsrc/h-rows.asm"   \ (FILL=rows: the row runs, bank 5's)
ENDIF
 INCLUDE "build/elite-source-host.asm"
 INCLUDE "src/gfx-gvars.asm"
 INCLUDE "src/gfx-tramp.asm"
 INCLUDE "src/gfx-gluehooks.asm"
 INCLUDE "tsrc/h-main.asm"
\ The recursive tokens (QQ18, as stored: build/HQQ18.bin) and where each
\ starts (build/htokix.asm): data that h4body's C_TOKEN sends to the
\ parasite (elite-source.asm's ex) from the IRQ, wherever the host is, as
\ the overlays' images are kept
.HQQ18
 INCBIN "build/HQQ18.bin"
 INCLUDE "build/htokix.asm"
.H_END
\ CHPR's font, after the code in the loaded image (HMAIN): hstart moves it
\ to HFONT, and this room is the kernel's free room
.HFONTST
 INCBIN "src/fonts/P.FONT.bin"
 PRINT "Host: the kernel's code &", ~H_START, "-&", ~H_END-1, ", the font after it to &", ~P%-1, ", free to &3000: ", &3000-P%
 SAVE "build/HMAIN.bin", H_START, P%, hwrch


 CLEAR &8000, &C000      \ bank 5: the rasteriser's shared region and disc window
 GUARD &C000
 ORG &9000
 INCLUDE "build/gfx-raster-frame.asm"         \ (streams.py's passes: the blocks
 INCLUDE "build/gfx-raster_lcold-frame.asm"   \ tagged "Area: kernel" are in the kernel)
.B5_END
 PRINT "Host: bank 5 &8000-&", ~B5_END-1
 SAVE "build/HBANK5.bin", &8000, B5_END, &8000

 CLEAR &8000, &9000      \ ANDY: the polygon window
 ORG &8000
 INCLUDE "src/gfx-raster_poly.asm"
 INCLUDE "src/gfx-raster_line.asm"
.RA_END
 ASSERT RA_END <= &9000
 SAVE "build/HRASTA.bin", &8000, RA_END, &8000

 CLEAR &8000, &C000      \ bank 6: the frame layer's host part
 ORG &8000
 INCLUDE "src/gfx-frame.asm"
 INCLUDE "src/gfx-frame_cold.asm"
 INCLUDE "tsrc/h-cold.asm"
 INCLUDE "tsrc/h-panel.asm"
 INCLUDE "tsrc/h-prim.asm"
 ALIGN &100              \ (the log tables: page aligned)
 INCLUDE "build/elite-source-hostb.asm"   \ the dashboard's drawing (p-dash.asm)
 CPU 1
.B6_CODE_END
.F_HW   SKIP 256        \ (f_enter's buffer)
.F_HW2  SKIP 256
.F_DSX  SKIP NDSTAR     \ (f_unstar's: C_EORDOT's star)
.F_DSY  SKIP NDSTAR
.B6_END
 PRINT "Host: bank 6 &8000-&", ~B6_END-1, " (code to &", ~B6_CODE_END-1, "), its STA runs from &", ~RUN6
 ASSERT B6_END <= RUN6
 SAVE "build/HBANK6.bin", &8000, B6_END, &8000

