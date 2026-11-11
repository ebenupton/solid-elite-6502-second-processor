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
\     workspace only what the host's code names (below), f_enter's buffers;
\     then from KCODE, above the loader's part that loads it, the game's
\     host blocks (the sound, the IRQ, CHPR, UP), the renderer's glue, the
\     command loop (h-main.asm), the recursive tokens, which the IRQ reads,
\     and the span kernel: the code that enters the STA runs, and their
\     tables. Only the kernel pages a line's bank, and it pages bank 7 back;
\   * bank 7 (GFXBANK, the resting bank, paged whenever the host runs
\     outside the STA runs): all of the host's other code, one run from
\     &9400: the lines, the dots, the stars and phase B's set-up, the frame
\     layer's host part, the panel's drawing, the commands' handlers and
\     the rarely run code;
\   * the STA runs (h-sta.asm) in banks 4, 5 and 6, in line order;
\   * the overlays' storage (build/hstore.asm): main RAM &3000-&3DFF and
\     &7000-&7FFF, ANDY, bank 7 below its code, HAZEL from &CA00, then the
\     STA runs' pages' tails in bank 4; the planet is wholly the parasite's;
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
GFXBANK = 7             \ the host's code (the frame layer's host part, the
                        \ rasteriser's, the commands'): the resting bank

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
.F_HW   SKIP 256        \ (f_enter's buffers)
.F_HW2  SKIP 256
.F_DSX  SKIP NDSTAR     \ (f_unstar's: C_EORDOT's star)
.F_DSY  SKIP NDSTAR
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
 INCLUDE "tsrc/h-sta.asm"
 INCLUDE "build/elite-source-host.asm"
 INCLUDE "src/gfx-gvars.asm"
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


 CLEAR &8000, &C000      \ bank 7: the host's code, one run from &9400
 GUARD &C000
 ORG &9400
.B7_START
 INCLUDE "src/gfx-raster_line.asm"        \ (first: the log tables after it start
 INCLUDE "build/elite-source-hostb.asm"   \ a page with no padding before them)
 CPU 1
 ASSERT log = dsg9 + 1
 INCLUDE "src/gfx-frame.asm"
 INCLUDE "src/gfx-frame_cold.asm"
 INCLUDE "tsrc/h-cold.asm"
 INCLUDE "tsrc/h-panel.asm"
 INCLUDE "tsrc/h-prim.asm"
 INCLUDE "build/gfx-raster-frame.asm"         \ (streams.py's passes: the blocks
 INCLUDE "build/gfx-raster_lcold-frame.asm"   \ tagged "Area: kernel" are in the kernel)
 INCLUDE "src/gfx-raster_poly.asm"
.B7_END
 PRINT "Host: bank 7 &", ~B7_START, "-&", ~B7_END-1, ", free to &C000: ", &C000-B7_END
 SAVE "build/HBANK7.bin", B7_START, B7_END, B7_START
