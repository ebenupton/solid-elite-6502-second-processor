\ ******************************************************************************
\
\ p-ws.asm - the parasite's part of the renderer's shared workspace
\ (gfx-ws.asm in the Master port): only what the frame layer leaves for the
\ rasteriser, whose state is the host's. From &0E00 to CODE%; page &0D below
\ holds the parasite's dummy SHEILA (VIA) and getzp's buffer (elite-source.asm)
\
\ ******************************************************************************

ACCY = 8
MAXSH = 13              \ ships per frame
MAXLN = 48              \ lines per frame
MAXDT = 64              \ dots per frame
GFXBANK = 6             \ (the frame layer's bank on the Master: unused here)
ELITEBANK = HOMEBANK
ONEPASS = FALSE         \ R_POLY's 8-bit polygons by the one-pass span generator
OPTUBE = TRUE           \ the Tube's: every polygon in one pass (p-onepass.asm, each
                        \ row's span to the host as it is made, p-emit.asm), exactly
                        \ as the two-phase path; no edge tables
NDSTAR = NOST+1
MERIDHOLD = 0           \ (gfx-ws.asm's: tube/build.sh checks that they agree)

ORG &0E00
.PWS_START
.R_NDISCL   SKIP 192        \ new disc spans, left ends (page aligned)
.R_PXL      SKIP 16         \ vertex x, low bytes
.R_PXH      SKIP 16
.R_PYL      SKIP 16
.R_PYH      SKIP 16
ASSERT LO(R_NDISCL) = 0 AND HI(R_PXL) = HI(R_PYH + 15)
.R_NDN      SKIP 192        \ boundaries per disc row
.R_X0       SKIP 2          \ line end points (words)
.R_Y0       SKIP 2
.R_X1       SKIP 2
.R_Y1       SKIP 2
.R_PN       SKIP 1
.R_COL2     SKIP 1
.R_COL3     SKIP 1
.R_NDT      SKIP 1
.R_NDB      SKIP 1
.R_NDF      SKIP 1
.R_DBE      SKIP 1
.R_DBO      SKIP 1
.R_SN       SKIP 1
.R_SCOL     SKIP 1
.R_SS       SKIP 24         \ the stars' sizes, then the directly drawn stars'
.F_DSS      SKIP NDSTAR
.R_SX       SKIP 24
.R_SY       SKIP 24
.R_NDISCR   SKIP 192
.R_NDP      SKIP 192
.R_NDX0     SKIP 192
.R_NDX1     SKIP 192
.R_NDX2     SKIP 192
.R_NDX3     SKIP 192
.F_TMR      SKIP 24         \ the text map's rows' counts (gfx-frame.asm)
.F_SHR0     SKIP 24
.F_SHR1     SKIP 24
.PWS_END
ASSERT F_DSS = R_SS + 24 AND R_Y1 = R_Y0 + 4
PRINT "Parasite workspace: &", ~PWS_START, "-&", ~PWS_END-1, ", free ", CODE%-PWS_END
ASSERT PWS_END <= CODE%
