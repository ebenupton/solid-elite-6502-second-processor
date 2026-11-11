\ ******************************************************************************
\
\ h-layout.asm - the host's memory (docs/TUBE-MAP.md): phase 1, a BBC Master
\ host, laid out as the Master port's display side
\
\   * zero page: the game's definitions (build/elite-source-ws.asm), so that
\     the host's copies of the game's drawing code see their variables where
\     the parasite has them (the commands carry the values). K% and WP have
\     names here only as the game's definitions: the host keeps nothing in
\     &0700-&0CFF (tube/build.sh checks its listing), and the panel's few
\     variables of WP are in the kernel's workspace (HWP);
\   * CHPR's font at &0400-&06FF, the pages of the MOS's Tube code, which
\     runs the boot and then is never called again (hstart clears &027A,
\     and the disc commands are the host's own I/O, h_disc): the loader
\     puts it in buffer 0 (HFONTST), and hstart moves it there;
\   * the kernel, main RAM below &3000, which every bank and either setting
\     of ACCCON X sees: from &0E00 its code, the command loop (h-main.asm),
\     the span kernel (the code that enters the STA runs, and their
\     tables), the game's host blocks (the sound, the IRQ, CHPR, UP), the
\     renderer's glue and the recursive tokens, which the IRQ reads; then
\     the room it leaves (where the loader runs at the boot); then its
\     workspace, one run up to the disc commands' buffers (h-cold.asm,
\     cmds.asm's HDBUF): f_enter's buffers, of the renderer's shared
\     workspace only what the host's code names (below), the panel's
\     variables of WP (HWP) and ylookup (the page of each pixel row's
\     character row, which hstart makes: one copy for the game's drawing
\     and the rasteriser, as r_ypg). Only the kernel pages a line's bank,
\     and it pages bank 7 back;
\   * bank 7 (GFXBANK, the resting bank, paged whenever the host runs
\     outside the STA runs): all of the host's other code, one run from
\     &9400: the lines, the dots, the stars and phase B's set-up, the frame
\     layer's host part, the panel's drawing, the commands' handlers and
\     the rarely run code;
\   * the STA runs (h-sta.asm) in banks 4, 5 and 6, in line order: line L's
\     run starts page &80 + L MOD 64 of bank 4 + L DIV 64;
\   * the overlays' storage (h-main.asm's h_ovlget): D in the STA runs'
\     pages' tails, bytes 192-255, its page p in the tails of lines 4p to
\     4p+3; S in three extents in address order: main RAM from HSTS0 to
\     &3FFF and &7000-&7FFF (ACCCON X clear), then bank 7 below its code.
\     ANDY and HAZEL are not the host's; the planet is wholly the
\     parasite's;
\   * the screen: buffer 0 in main RAM, buffer 1 and the dashboard in shadow
\     RAM, as the Master port's.
\
\ ******************************************************************************

_TPART = 2
_HOSTB = FALSE          \ (not the Model B host: hb-*.asm)
_RBANK = 0

 INCLUDE "tsrc/cmds.asm"
 INCLUDE "build/povl.asm"
HYL = HDBUF - &200      \ ylookup: the workspace's top page, below the disc
                        \ commands' buffers (h-cold.asm, cmds.asm's HDBUF)
HWP = HYL - 47          \ the panel's variables of WP, below it: the game's
                        \ workspace puts SWAP, JOPOS, DASHV ... dstab and
                        \ dQQ14 ... dCOMY here (elite-source.asm; asserted)
 INCLUDE "build/elite-source-ws.asm"
 INCLUDE "build/h-wsc.asm"
GFXBANK = 7             \ the host's code (the frame layer's host part, the
                        \ rasteriser's, the commands'): the resting bank

\ The kernel's workspace: of the renderer's shared workspace (elite-gfx.asm),
\ only what the host's code names, at the host's own addresses (tube/build.sh
\ writes build/h-ws.asm from these lines, the declarations in the source's
\ order; a name the host's code uses that is not listed fails the assembly):
\ the lines' end points, phase B's colours and rows, the stars and the
\ directly drawn stars' sizes
\ HWS R_X0 R_Y0 R_X1 R_Y1 R_COL2 R_COL3 R_PYS R_PYE
\ HWS R_SS R_SX R_SY R_SN R_SCOL F_DSS
HFONT = &0400           \ (CHPR's font: FONT%, elite-source.asm)
HFONTST = &4000         \ (where the loader puts it, buffer 0, for hstart)
HSTS0 = &2D00           \ overlay S's first stored page (h_ovlget): the
                        \ kernel's room's last three pages, after the disc
                        \ commands' buffers
 ORG HWP - HWS_LEN - 2 * &100 - 2 * NDSTAR
.H_WS                   \ (one run, ending where the disc buffers start)
.F_HW   SKIP 256        \ (f_enter's buffers)
.F_HW2  SKIP 256
.F_DSX  SKIP NDSTAR     \ (f_unstar's: C_EORDOT's star)
.F_DSY  SKIP NDSTAR
 INCLUDE "build/h-ws.asm"
 ASSERT P% = HWP AND SWAP = HWP AND dCOMY + 1 = HYL
 ORG HYL
.ylookup SKIP 256       \ (hstart makes it: h-cold.asm)
r_ypg = ylookup         \ (rows 0..191: gfx-raster.asm's)
 ASSERT P% = HDBUF - &100
 PRINT "Host: the kernel's workspace &", ~H_WS, "-&", ~P%-1


 ORG &0E00
 GUARD H_WS
.H_START
 CPU 1
\ The renderer's shared variables and the command loop, then the span
\ kernel: the code that enters the STA runs (the blocks of the rasteriser's
\ files tagged "Area: kernel", streams.py's passes: r_rowset, r_spc, the
\ per-x tables, page aligned, R_SPAN, r_dspin, phase B), the runs' tables
\ and generator (h-sta.asm)
 INCLUDE "src/gfx-gvars.asm"
 INCLUDE "tsrc/h-main.asm"
 INCLUDE "build/gfx-raster-kernel.asm"
 INCLUDE "build/gfx-raster_lcold-kernel.asm"
 INCLUDE "build/gfx-raster_polyb-kernel.asm"
 INCLUDE "tsrc/h-sta.asm"
 INCLUDE "build/elite-source-host.asm"
 INCLUDE "src/gfx-gluehooks.asm"
\ The recursive tokens (QQ18, as stored: build/HQQ18.bin) and where each
\ starts (build/htokix.asm): data that h4body's C_TOKEN sends to the
\ parasite (elite-source.asm's ex) from the IRQ, wherever the host is, as
\ the overlays' images are kept
.HQQ18
 INCBIN "build/HQQ18.bin"
 INCLUDE "build/htokix.asm"
.H_END
 PRINT "Host: the kernel's code &", ~H_START, "-&", ~H_END-1, ", free to the workspace at &", ~H_WS, ": ", H_WS-H_END
 SAVE "build/HKERN.bin", H_START, H_END, hwrch
 ASSERT HDBUF + &100 = HSTS0

\ CHPR's font, which the loader puts in buffer 0 with the kernel's code
\ after it (HMAIN: tube/build.sh) for hstart to move to HFONT
 CLEAR HFONTST, HFONTST + &300
 ORG HFONTST
 INCBIN "src/fonts/P.FONT.bin"
 SAVE "build/HFONT.bin", HFONTST, P%


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
 ASSERT (&40 - HI(HSTS0)) + &10 + (HI(B7_START) - &80) = OVLS_PAGES - OVLS0_PAGES
 ASSERT 4 * OVLD_PAGES <= R_ROWS     \ (D's quarters, in the lines' runs' tails)
 SAVE "build/HCODE.bin", B7_START, B7_END, B7_START
