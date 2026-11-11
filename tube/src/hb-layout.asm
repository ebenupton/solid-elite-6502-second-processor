\ ******************************************************************************
\
\ hb-layout.asm - the host's memory (docs/TUBE-MAP.md): a BBC Micro Model B
\ host with 64K of sideways RAM, laid out as the Master host's (h-layout.asm)
\ where its hardware allows. One assembly; NMOS code (build/nmos/: the
\ Master port's sources through tube/tools/nmos.py)
\
\ A Model B has no shadow RAM, no ANDY and no HAZEL: the two 12K space-view
\ buffers and the 3.5K panel take main RAM from &1000 (buffer 0 &1000-&3FFF,
\ buffer 1 &4000-&6FFF, the panel &7000-&7DFF, a CRTC vertical rupture
\ between them: hb-irq.asm). Of the rest of main RAM the host has three
\ places, each for one reason, and leaves the MOS's own (&0236-&03FF,
\ &0700-&0DFF) alone: tube/build.sh fails the build if an instruction of
\ the host's addresses them, but for the MOS's variables it means to (the
\ Tube flag &027A, the text cursor &0308 and &0318):
\
\   * zero page: the game's definitions (build/elite-source-ws.asm), as the
\     Master host's;
\   * CHPR's font at &0400-&06FF (HFONT), the pages of the MOS's Tube code,
\     which runs the boot and then is never called again (hstart clears
\     &027A): hstart moves it there from its first place, HFONTST;
\   * &0E00-&0FFF, what both banks P and F must see: ylookup, the storage
\     reader (hb-ovl.asm), which pages the overlays' banks, and the
\     trampolines into bank P (hb-res2.asm). These are DFS's pages, which
\     the screen forces the host to borrow (buffer 0 starts at &1000):
\     hbswap exchanges &0E00-&10FF with bank F's HBST around each disc
\     command, so DFS has its three pages back while it runs;
\   * &7E00-&7FFF, beyond the panel, what must survive a disc command and
\     be there whatever bank the MOS has paged: WRCHV's hwrch, the IRQ's
\     entry and point 2 of the rupture, hrw (hb-res3.asm);
\   * bank P (RASTPOLY): the row runs, a page per character row of each
\     buffer in order from &8000 (row r of buffer b at page &80 + 24b + r),
\     made at the host's start (hstart's s_gen), so that no run is patched
\     for a buffer; then the span kernel, the code that enters them, and its
\     own variables (hb-kernel.asm, in a scope of its own, as the per-x
\     tables are in bank F too);
\   * bank F (GFXBANK, the resting bank, paged whenever the host runs outside
\     bank P): all of the host's other code, one run from &8000 in the
\     Master host's order: what the Master host keeps in its kernel (the
\     renderer's shared variables, the command loop, the interrupts, the
\     game's host blocks), then what it keeps in bank 7 (the panel's
\     drawing, its log tables last, the second copy of the per-x tables
\     after them, page aligned, the lines that read them, the frame
\     layer's host part, the rarely run code, the handlers, the rasteriser's
\     own place: R_SETBUF, the dots, the stars, r_pset); then the recursive
\     tokens; then the room it leaves; then its workspace, one run to the
\     bank's top: f_enter's buffers, of the renderer's shared workspace
\     only what the host's code names (below), the panel's variables of
\     WP (HWP), and DFS's three pages while the game runs (HBST, page
\     aligned: where the loader puts the host's image of &0E00-&10FF for
\     hstart's first hbswap). CHPR's font is first put across the
\     workspace and the room below it (HFONTST), and moved before the
\     workspace is used;
\   * the stash bank S (STASHBANK): overlay D's image from &8000; bank D
\     (RASTBANK): overlay S's (hb-ovl.asm).
\
\ The bank numbers here are the defaults; the loader patches the code for
\ the banks it finds (tube/build.sh lists the operands to patch).
\
\ ******************************************************************************

_TPART = 2
_HOSTB = TRUE

 INCLUDE "tsrc/cmds.asm"
 INCLUDE "build/povl.asm"
HBST = &C000 - &300     \ DFS's three pages while the game runs (hbswap)
HWP = HBST - 47         \ the panel's variables of WP, below them: the game's
                        \ workspace puts SWAP, JOPOS, DASHV ... dstab and dQQ14
                        \ ... dCOMY here (elite-source.asm; asserted)
 INCLUDE "build/elite-source-ws.asm"

ACCY = 8                \ (no ACCCON on a Model B: &FE34 is ROMSEL's)
MAXSH = 13              \ ships per frame
MAXLN = 48              \ lines per frame
MAXDT = 64              \ dots per frame
RASTBANK = HBB          \ D: the parasite's overlay S, stored (hb-ovl.asm)
RASTPOLY = HBB + 1      \ P: the row runs and the span kernel
GFXBANK = HBB + 2       \ F: the host's code: the resting bank
STASHBANK = HBB + 3     \ S: the parasite's overlay D, stored (HBB: beebasm -D,
                        \ 4; the build assembles again with 8 to find the
                        \ operands to patch)
ELITEBANK = HOMEBANK
ONEPASS = FALSE         \ (the parasite's: p-ws.asm)
OPTUBE = FALSE
NDSTAR = NOST+1
R_ROWS = 192            \ the lines of the 3D view (phase B's end row, r_pcbs)
BUF0 = &1000            \ buffer 0's screen (buffer 1's is the Master port's &4000)
PANEL = &7000
HFONT = &0400           \ (CHPR's font: FONT%, elite-source.asm)
OVLBANK = STASHBANK     \ the parasite's overlays' images (storage only: hb_ovlget),
OVLD_AT = &8000         \ overlay D's from its bank's first page

 INCLUDE "tsrc/hb-res.asm"
 INCLUDE "tsrc/h-zp.asm"
 INCLUDE "build/hb-rzp.asm"
 CPU 0

\ Main RAM: &0E00-&0FFF

 CLEAR &0E00, &1000
 ORG &0E00
.ylookup SKIP 256       \ the page of each pixel row's character row (hstart
r_ypg = ylookup         \ makes it: h-cold.asm): one copy for the game's
                        \ drawing and the rasteriser (r_ypg, rows 0..191)
 GUARD &1000
 INCLUDE "tsrc/hb-ovl.asm"
 CPU 0
.MR_D_END               \ (then the trampolines, hb-kernel.asm's)

\ Main RAM: &7E00-&7FFF

 CLEAR &7E00, &8000
 ORG &7E00
 GUARD &8000
 INCLUDE "tsrc/hb-res3.asm"
.MR_E_END
 PRINT "Model B &7E00-&", ~MR_E_END-1, ": the persistent block (free ", &8000-MR_E_END, ")"


\ Bank P: the row runs from &8000, which hstart has r_rgen make (s_gen:
\ hb-kernel.asm), then the span kernel
 CLEAR &8000, &C000
 GUARD &C000
 ORG &B000
 INCLUDE "build/nmos/hb-kernel.asm"   \ (tsrc/hb-kernel.asm in a scope of its own)
 SAVE "build/HBP.bin", &B000, P_KEND, &B000


\ Bank F: the host's code, one run from &8000
 CLEAR &8000, &C000
 GUARD &C000
 ORG &8000
.F_START
 INCLUDE "build/nmos/gfx-gvars.asm"
 CPU 0
 INCLUDE "build/nmos/h-main.asm"
 CPU 0
 INCLUDE "tsrc/hb-irq.asm"
 INCLUDE "build/nmos/elite-source-host.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-gluehooks.asm"
 CPU 0
 INCLUDE "build/nmos/elite-source-hostb.asm"   \ (the panel's drawing: its log tables
 CPU 0                                         \ last, page aligned)
.r_xo                   \ the per-x tables: bank P's (gfx-raster.asm's, the span
 R_XOTAB                \ kernel's) again, from the one source (gfx-raster_xtab.asm),
.r_lm                   \ for R_LINE (after them), r_pset and the stars
 R_LMTAB
.r_rm
 R_RMTAB
 INCLUDE "build/nmos/gfx-raster_line.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-frame.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-frame_cold.asm"
 CPU 0
 INCLUDE "build/nmos/h-cold.asm"
 CPU 0
 INCLUDE "build/nmos/h-panel.asm"
 CPU 0
 INCLUDE "build/nmos/h-prim.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-raster-frame.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-raster_lcold-frame.asm"
 CPU 0
.F_CODE_END
\ The recursive tokens (QQ18, as stored: build/HQQ18.bin) and where each
\ starts (build/htokix.asm): data that h4body's C_TOKEN sends to the
\ parasite from the IRQ, which pages bank F
.HQQ18
 INCBIN "build/HQQ18.bin"
 INCLUDE "build/htokix.asm"
.F_END
\ The workspace, one run to the bank's top, of which the renderer's shared
\ workspace is only what the host's code names (tube/build.sh writes
\ build/hb-wsn.asm from these lines, the declarations in the source's order,
\ and their length, HBWS_LEN, in build/hb-wsc.asm; a name the host's code
\ uses that is not listed fails the assembly): the lines' end points and
\ colours, the stars and the directly drawn stars' sizes. The span kernel's
\ own are its HWSP lines (hb-kernel.asm)
\ HWS R_X0 R_Y0 R_X1 R_Y1 R_COL2 R_COL3
\ HWS R_SS R_SX R_SY R_SN R_SCOL F_DSS
 INCLUDE "build/hb-wsc.asm"
 ORG HWP - HBWS_LEN - 2 * &100 - 2 * NDSTAR
.H_WS
.F_HW   SKIP 256        \ (f_enter's buffers)
.F_HW2  SKIP 256
.F_DSX  SKIP NDSTAR     \ (f_unstar's: C_EORDOT's star)
.F_DSY  SKIP NDSTAR
 INCLUDE "build/hb-wsn.asm"
 ASSERT P% = HWP AND SWAP = HWP AND dCOMY + 1 = HBST
 COPYBLOCK &0E00, &1100, HBST   \ (DFS's three pages: the host's image of them,
                                \ for hstart's first hbswap; &1000-&10FF zero)
\ CHPR's font, first across the workspace and the room below it, which
\ hstart moves to HFONT before anything uses them
HFONTST = HBST - &300
 ASSERT HFONTST >= F_END AND HFONTST <= H_WS
 CLEAR HFONTST, HBST
 ORG HFONTST
 INCBIN "src/fonts/P.FONT.bin"
 ASSERT HI(r_xo) = HI(alogh) + 1
 PRINT "Model B bank F: code &8000-&", ~F_CODE_END-1, ", the tokens &", ~HQQ18, "-&", ~F_END-1, ", free &", ~F_END, "-&", ~H_WS-1, ": ", H_WS-F_END, ", the workspace &", ~H_WS, "-&BFFF (DFS's pages from &", ~HBST, ")"
 SAVE "build/HBF.bin", &8000, &C000, &8000
 SAVE "build/HBE.bin", &7E00, &8000
