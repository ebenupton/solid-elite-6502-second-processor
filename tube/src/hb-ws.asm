\ ******************************************************************************
\
\ hb-ws.asm - the Model B host's constants and workspace (docs/TUBE-MAP.md),
\ in place of gfx-ws.asm (the Master host's), for the Model B assemblies:
\ hb-d.asm (bank D, the rasteriser's disc side), hb-p.asm (bank P, its
\ polygon side) and hb-main.asm (bank F, main RAM and the stash bank S)
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
RASTBANK = HBB          \ D: the disc window and the rasteriser's shared code
RASTPOLY = HBB + 1      \ P: the polygon window, lines, stars, flare
GFXBANK = HBB + 2       \ F: the frame layer's host part and the commands
STASHBANK = HBB + 3     \ S: the MOS's main RAM while the game runs, ours while
                        \ a disc command does (HBB: beebasm -D, 4; the build
                        \ assembles again with 8 to find the operands to patch)
ELITEBANK = HOMEBANK
ONEPASS = FALSE         \ (the parasite's: p-ws.asm)
OPTUBE = FALSE
NDSTAR = NOST+1
MERIDHOLD = 0           \ (gfx-ws.asm's, the beach ball's: tube/build.sh checks
                        \ that they agree)

BUF0 = &1000            \ buffer 0's screen (buffer 1's is the Master port's &4000)
PANEL = &7000

\ ------------------------------------------------------------------------------
\ Main RAM (reclaimed from the MOS while the game runs)
\ ------------------------------------------------------------------------------

\ the fixed entry points bank D's and bank P's code calls in main RAM (hb-main.asm
\ assembles them here, asserting it)
RUNP = &0236            \ runp: a run of bank P's for bank D's r_spc (A colour, Y row)
RUNPJ = RUNP + 21       \ (its JSR: bank D's r_jsr)
P_ROWREPT = RUNP + 40   \ bank D's way to bank P's r7_rowrep
MR_A = P_ROWREPT + 18   \ code and data: to &03F4
MR_AEND = &03F5
R_DIRTYL0 = &03F5       \ the per-buffer arrays, at the Master port's low bytes
R_DIRTYR0 = R_DIRTYL0 + 192
R_DISCR0  = R_DIRTYR0 + 192
R_DISCL0  = R_DISCR0 + 192
R_DIRTYL1 = R_DISCL0 + 192
R_DIRTYR1 = R_DIRTYL1 + 192
R_DISCR1  = R_DIRTYR1 + 192
R_DISCL1  = R_DISCR1 + 192
ASSERT LO(R_DIRTYR0) = &B5 AND LO(R_DISCL0) = &35
ASSERT HI(R_DIRTYR0) = HI(R_DIRTYL0) + 1 AND HI(R_DIRTYR1) = HI(R_DIRTYL1) + 1
R_PRBUF   = R_DISCL1 + 192  \ the rasteriser's state (raster_vars.asm)
R_PRDYT   = R_PRBUF + 1
R_PRDYB   = R_PRBUF + 3
R_PRDST   = R_PRBUF + 5
R_PRDSB   = R_PRBUF + 7
R_PRSCNT  = R_PRBUF + 9
R_PRECNT  = R_PRBUF + 11
R_PRWT    = R_PRBUF + 13
R_PRWB    = R_PRBUF + 14
R_PRBMODE = R_PRBUF + 15
R_PRNT    = R_PRBUF + 17
R_PRNB    = R_PRBUF + 18
R_PRLO    = R_PRBUF + 19
R_PRHI    = R_PRBUF + 20
R_PRDYA   = R_PRBUF + 21
R_PRDYZ   = R_PRBUF + 22
R_PRCWB   = R_PRBUF + 23
R_SN      = R_PRBUF + 24    \ star count
R_SCOL    = R_PRBUF + 25    \ star colour byte
R_WL      = R_PRBUF + 26    \ this frame's written extents
R_SS      = R_WL + 192      \ star sizes
F_DSS     = R_SS + 24       \ the directly drawn stars' sizes
ASSERT F_DSS + NDSTAR <= &0B00
R_WR      = &0B00           \ (whole in a page)
R_SX      = R_WR + 192
R_SY      = R_SX + 24
MR_B = R_SY + 24               \ code and data: to JOPOS
MR_BEND = &0CA7
ASSERT JOPOS = &0CA7
hpe_w = &0CAA           \ R_DISCROWS (bank D): the pre-erase has started R_WL/R_WR
GVARS = &0CAB           \ gfx-gvars.asm's (hb-main.asm assembles it here)
IF _RBANK
GMODE = GVARS + 0
GFRONT = GVARS + 1
GFLIP = GVARS + 2
GPEND = GVARS + 3
GDRAWON = GVARS + 4
GFORCE = GVARS + 5
GSIGHT = GVARS + 6
GLASV = GVARS + 7
GLCOL = GVARS + 8
GDCOL = GVARS + 9
GNF = GVARS + 10
GNV = GVARS + 11
GTYPE = GVARS + 12
GSUNON = GVARS + 13
GSUNR = GVARS + 14
GSTASH = GVARS + 15
PM_OK = GVARS + 16
PM_R = GVARS + 17
PS_VALID = GVARS + 18
GWARP = GVARS + 19
ENDIF
MR_C = GVARS + 20       \ code and data: to page &0D
MR_CEND = &0D00
MR_D = &0E00            \ code and data
MR_DEND = &1000
MR_E = &7E00            \ code and data
MR_EEND = &8000

\ ------------------------------------------------------------------------------
\ Bank D's data (above its code; the disc inputs that h_disc receives there)
\ ------------------------------------------------------------------------------

DDATA = &B800
R_NDISCL = DDATA        \ page aligned: R_NDISCL,X never crosses a page
R_NDISCR = DDATA + &C0
R_NDN    = DDATA + &180
R_NDP    = DDATA + &240
R_NDX0   = DDATA + &300
R_NDX1   = DDATA + &3C0
R_NDX2   = DDATA + &480
R_NDX3   = DDATA + &540
R_NDT    = DDATA + &600
R_NDB    = DDATA + &601
R_NDF    = DDATA + &602
R_DBE    = DDATA + &603
R_DBO    = DDATA + &604
DDATA_END = DDATA + &605

\ ------------------------------------------------------------------------------
\ Bank P's data (where bank D has the disc's boundary arrays)
\ ------------------------------------------------------------------------------

PDATA = &9500           \ (buffer 1's boundary arrays in bank D)
R_PXL    = PDATA        \ vertex x, y (signed 16-bit): in one page
R_PXH    = PDATA + &10
R_PYL    = PDATA + &20
R_PYH    = PDATA + &30
R_X0     = PDATA + &40  \ line end points (words)
R_Y0     = PDATA + &42
R_X1     = PDATA + &44
R_Y1     = PDATA + &46
R_PN     = PDATA + &48
R_COL2   = PDATA + &49
R_COL3   = PDATA + &4A
R_PYS    = PDATA + &4B
R_PYL1   = PDATA + &4C
R_PYE    = PDATA + &4D
R_PXC    = PDATA + &4E
R_PCR1   = PDATA + &4F
R_PTA    = PDATA + &100
R_PTB    = PDATA + &1C0
PDATA_END = PDATA + &280

\ ------------------------------------------------------------------------------
\ The banks' jump tables, at fixed addresses (so that the assemblies need no
\ symbols from each other)
\ ------------------------------------------------------------------------------

JT = &BFC0
P_PGFIX    = JT         \ bank P
P_ROWREP   = JT + 3     \ (p_rowrepr's, never called now: the repair is the parasite's)
P_DSPANSIN = JT + 3     \ C_DSPANS's rows of spans (r_dspin)
P_POLY     = JT + 6
P_LINE     = JT + 9
P_SETBUF   = JT + 12
P_SPAN     = JT + 15
P_MARKDIRTY = JT + 18
P_DOT      = JT + 21
P_STARERASE = JT + 24
P_STARPLOT = JT + 27
P_FLARE    = JT + 30
P_POLYIN   = JT + 33    \ h_poly's receiving part (hb-p.asm)
P_LINEIN   = JT + 36    \ h_line's
                        \ (JT + 39, 42: the star records' relay, retired)

OVLBANK = STASHBANK      \ the parasite's overlays' images (storage only: hb_ovlget),
OVLD_AT = &8E00          \ after the stash, from the HBS file
HBS_IMG = &8000           \ the stash bank: main RAM's &0236-&0CFF, &0E00-&10FF
HBS_LEN = &0DCA           \ (hb-res.asm's hbswap)
