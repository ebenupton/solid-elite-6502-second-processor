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
\ between them: hb-irq.asm), and while the game runs the host takes what the
\ MOS does not need then: &0236-&0CFF, &0E00-&0FFF and &7E00-&7FFF, swapped
\ with the MOS's contents (and &1000-&10FF, DFS's workspace over buffer 0)
\ through the stash bank S for each disc command. Page &0D stays the MOS's.
\
\   * zero page: the game's definitions (build/elite-source-ws.asm), as the
\     Master host's;
\   * CHPR's font at &0400-&06FF (HFONT), the pages of the MOS's Tube code,
\     which runs the boot and then is never called again (hstart clears
\     &027A): hstart moves it there from bank F (HFONTST);
\   * main RAM from &0236: the trampolines into bank P (hb-res2.asm), then
\     of the renderer's shared workspace only what the host's code names
\     (below), at HWSAT; ylookup at &0E00, the storage reader after it
\     (hb-ovl.asm); at &7E00, beyond the panel and never swapped, WRCHV's
\     hwrch, the IRQ's entry and point 2 of the rupture, hbswap and hrw
\     (hb-res3.asm);
\   * bank P (RASTPOLY): the row runs, a page per character row of each
\     buffer in order from &8000 (row r of buffer b at page &80 + 24b + r),
\     so that no run is patched for a buffer; then the span kernel, the
\     code that enters them: the rasteriser's blocks tagged "Area: kernel"
\     (streams.py's passes: r_rowset, r_spc, the per-x tables, R_SPAN,
\     r_dspin, phase B) and phase B's set-up (gfx-raster_poly.asm), in a
\     scope of its own, as the per-x tables are in bank F too;
\   * bank F (GFXBANK, the resting bank, paged whenever the host runs outside
\     bank P): all of the host's other code, one run from &8000 in the
\     Master host's order: what the Master host keeps in its kernel (the
\     renderer's shared variables, the command loop, the interrupts, the
\     game's host blocks), then what it keeps in bank 7 (the panel's
\     drawing, its log tables last, the second copy of the per-x tables
\     after them, page aligned, the lines that read them, the frame
\     layer's host part, the rarely run code, the handlers, the rasteriser's
\     own place: R_SETBUF, the dots, the stars, r_pset); then f_enter's
\     buffers, the recursive tokens and the font's first place; the panel's
\     variables of WP at its top (HWP);
\   * the stash bank S (STASHBANK): the MOS's main RAM while the game runs,
\     ours while a disc command does (hbswap), then overlay D's image from
\     OVLD_AT; bank D (RASTBANK): overlay S's image (hb-ovl.asm).
\
\ The bank numbers here are the defaults; the loader patches the code for
\ the banks it finds (tube/build.sh lists the operands to patch).
\
\ ******************************************************************************

_TPART = 2
_HOSTB = TRUE

 INCLUDE "tsrc/cmds.asm"
 INCLUDE "build/povl.asm"
HWP = &C000 - 47        \ the panel's variables of WP, at bank F's top: the game's
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
STASHBANK = HBB + 3     \ S: the MOS's main RAM while the game runs, ours while
                        \ a disc command does (HBB: beebasm -D, 4; the build
                        \ assembles again with 8 to find the operands to patch)
ELITEBANK = HOMEBANK
ONEPASS = FALSE         \ (the parasite's: p-ws.asm)
OPTUBE = FALSE
NDSTAR = NOST+1
R_ROWS = 192            \ the lines of the 3D view (phase B's end row, r_pcbs)
BUF0 = &1000            \ buffer 0's screen (buffer 1's is the Master port's &4000)
PANEL = &7000
HFONT = &0400           \ (CHPR's font: FONT%, elite-source.asm)
OVLBANK = STASHBANK     \ the parasite's overlays' images (storage only: hb_ovlget),
OVLD_AT = &8E00         \ overlay D's after the stash
HBS_IMG = &8000         \ the stash bank: main RAM's &0236-&0CFF, &0E00-&10FF
HBS_LEN = &0DCA         \ (hb-res.asm's hbswap)

 INCLUDE "tsrc/hb-res.asm"
 INCLUDE "tsrc/h-zp.asm"
 INCLUDE "build/hb-rzp.asm"
 CPU 0

\ Main RAM (reclaimed from the MOS while the game runs)

MR_A = &0236            \ the trampolines into bank P: to page &04
MR_AEND = &0400
HWSAT = &0700           \ the renderer's shared workspace, as the host's code
                        \ names it (tube/build.sh writes build/hb-wsn.asm from
                        \ these lines, the declarations in the source's order;
                        \ a name the host's code uses that is not listed fails
                        \ the assembly): the lines' end points, phase B's
                        \ colours and rows, the stars and the directly drawn
                        \ stars' sizes
\ HWS R_X0 R_Y0 R_X1 R_Y1 R_COL2 R_COL3 R_PYS R_PYE
\ HWS R_SS R_SX R_SY R_SN R_SCOL F_DSS
ylookup = &0E00         \ the page of each pixel row's character row (hstart
r_ypg = ylookup         \ makes it: h-cold.asm): one copy for the game's
                        \ drawing and the rasteriser (r_ypg, rows 0..191)
MR_D = ylookup + &100   \ the storage reader
MR_DEND = &1000
MR_E = &7E00            \ the persistent block
MR_EEND = &8000

 CLEAR &0200, &1100     \ (the game's workspaces' names stay; the host's own
 CLEAR &7E00, &8000     \ use of these places follows)
 ORG HWSAT
 INCLUDE "build/hb-wsn.asm"
 ASSERT P% <= &0D00

 ORG MR_D
 GUARD MR_DEND
 INCLUDE "tsrc/hb-ovl.asm"
 CPU 0
.MR_D_END
 PRINT "Model B &0E00 part: ylookup &", ~ylookup, "-&", ~ylookup+&FF, ", then &", ~MR_D, "-&", ~MR_D_END-1, " (free ", MR_DEND-MR_D_END, ")"

 ORG MR_E
 GUARD MR_EEND
 INCLUDE "tsrc/hb-res3.asm"
.MR_E_END
 PRINT "Model B &7E00 part: &", ~MR_E, "-&", ~MR_E_END-1, " (free ", MR_EEND-MR_E_END, ")"


\ Bank P: the row runs, then the span kernel. Each run: 63 STA abs,Y (Y the
\ pixel row), one per byte column of the character row, an RTS, and the
\ 'nothing planted' target (offset 190); bytes 191-255 free
 CLEAR &8000, &C000
 GUARD &C000
FOR b, 0, 1
 FOR r, 0, 23
  ORG &8000 + (24 * b + r) * &100
  FOR c, 1, 63
   STA BUF0 + b * (&4000 - BUF0) + r * &200 + c * 8 - r * 8, Y
  NEXT
  RTS
  EQUB 0
 NEXT
NEXT
 ORG &B000
 INCLUDE "build/nmos/hb-kernel.asm"   \ (tsrc/hb-kernel.asm in a scope of its own)
 SAVE "build/HBP.bin", &8000, &C000, &8000


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
.F_HW   SKIP 256        \ (f_enter's buffers)
.F_HW2  SKIP 256
.F_DSX  SKIP NDSTAR     \ (f_unstar's: C_EORDOT's star)
.F_DSY  SKIP NDSTAR
\ The recursive tokens (QQ18, as stored: build/HQQ18.bin) and where each
\ starts (build/htokix.asm): data that h4body's C_TOKEN sends to the
\ parasite from the IRQ, which pages bank F
.HQQ18
 INCBIN "build/HQQ18.bin"
 INCLUDE "build/htokix.asm"
.HFONTST                \ CHPR's font, which hstart moves to HFONT
 INCBIN "src/fonts/P.FONT.bin"
.F_END
 ASSERT F_END <= HWP AND SWAP = HWP AND dCOMY + 1 = &C000
 ASSERT HI(r_xo) = HI(alogh) + 1
 PRINT "Model B bank F: code &8000-&", ~F_CODE_END-1, ", the tokens &", ~HQQ18, ", the font &", ~HFONTST, "-&", ~F_END-1, ", free to the panel's variables: ", HWP-F_END
 SAVE "build/HBF.bin", &8000, F_END, &8000
 SAVE "build/HBRES1.bin", &0236, &0D00
 SAVE "build/HBRES2.bin", &0E00, &1100
 SAVE "build/HBE.bin", MR_E, &8000
