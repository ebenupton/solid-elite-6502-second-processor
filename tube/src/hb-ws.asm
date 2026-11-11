\ ******************************************************************************
\
\ hb-ws.asm - the Model B host's constants and workspace (docs/TUBE-MAP.md),
\ in place of the Master host's (build/h-ws.asm), for the Model B assemblies:
\ hb-p.asm (bank P, the fills) and hb-main.asm (bank F, main RAM and the
\ stash bank S)
\
\ A Model B with 64K of sideways RAM has no shadow RAM, no ANDY and no HAZEL:
\ the two 12K space-view buffers and the 3.5K panel take main RAM from &1000
\ (buffer 0 &1000-&3FFF, buffer 1 &4000-&6FFF, the panel &7000-&7DFF, a CRTC
\ vertical rupture between them), and while the game runs the host takes
\ what the MOS does not need then: &0236-&0CFF (but JOPOS, the game's, at
\ &0CA7), &0E00-&0FFF and &7E00-&7FFF, swapped with the MOS's contents (and
\ &1000-&10FF, DFS's workspace over buffer 0) through the stash bank S for
\ each disc command. Page &0D stays the MOS's.
\
\ The bank numbers here are the defaults; the loader patches the code for
\ the banks it finds (tube/build.sh lists the operands to patch).
\
\ ******************************************************************************

ACCY = 8                \ (no ACCCON on a Model B: &FE34 is ROMSEL's)
MAXSH = 13              \ ships per frame
MAXLN = 48              \ lines per frame
MAXDT = 64              \ dots per frame
RASTBANK = HBB          \ D: the parasite's overlay S, stored (hb-ovl.asm)
RASTPOLY = HBB + 1      \ P: phase B, the spans and their row runs, the dots and
                        \ the stars
GFXBANK = HBB + 2       \ F: the frame layer's host part and the commands
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
HFONT = &0400           \ CHPR's font (FONT%, elite-source.asm): the pages of the
                        \ MOS's Tube code, which runs the boot and then is never
                        \ called again (hstart clears &027A); hstart moves it
                        \ there from bank F's HFONTST (hb-main.asm)

\ ------------------------------------------------------------------------------
\ Main RAM (reclaimed from the MOS while the game runs)
\ ------------------------------------------------------------------------------

MR_A = &0236            \ code and data: to page &04
MR_AEND = &0400
HWSAT = &0700           \ the renderer's shared workspace, as the host's code
                        \ names it (tube/build.sh writes build/hb-wsn.asm from
                        \ the "\ HWS" lines below: a name the host's code uses
                        \ that is not listed fails the assembly): the lines' end
                        \ points, phase B's colours and rows, the stars and the
                        \ directly drawn stars' sizes
\ HWS R_X0 R_Y0 R_X1 R_Y1 R_COL2 R_COL3 R_PYS R_PYE
\ HWS R_SS R_SX R_SY R_SN R_SCOL F_DSS
 ORG HWSAT
 INCLUDE "build/hb-wsn.asm"
.R_PRBUF  SKIP 1        \ the rasteriser's private state (gfx-raster_lcold.asm's,
.R_PRDYT  SKIP 2        \ as the host's code names it): the buffer, the rows R_LINE
.R_PRDYB  SKIP 2        \ has drawn in (which nothing on the host reads: kept, as
.R_PRSCNT SKIP 2        \ the Master host's), the star records
GVARS = &0CAB           \ gfx-gvars.asm's (hb-main.asm assembles it here)
ylookup = &0E00         \ the page of each pixel row's character row (hstart
r_ypg = ylookup         \ makes it: h-cold.asm): one copy for the game's
                        \ drawing in bank F and the rasteriser in bank P
                        \ (r_ypg, rows 0..191)
MR_D = ylookup + &100   \ code and data
MR_DEND = &1000
MR_E = &7E00            \ code and data
MR_EEND = &8000

\ ------------------------------------------------------------------------------
\ The banks' jump tables, at fixed addresses (so that the assemblies need no
\ symbols from each other)
\ ------------------------------------------------------------------------------

JT = &BFC0
P_DSPANSIN = JT         \ bank P: C_DSPANS's rows of spans (r_dspin)
P_SETBUF   = JT + 3
P_SPAN     = JT + 6
P_DOT      = JT + 9
P_STARERASE = JT + 12
P_STARPLOT = JT + 15
P_POLYIN   = JT + 18    \ h_poly's receiving part (hb-p.asm)

OVLBANK = STASHBANK      \ the parasite's overlays' images (storage only: hb_ovlget),
OVLD_AT = &8E00          \ after the stash, from the HBS file
HBS_IMG = &8000           \ the stash bank: main RAM's &0236-&0CFF, &0E00-&10FF
HBS_LEN = &0DCA           \ (hb-res.asm's hbswap)
