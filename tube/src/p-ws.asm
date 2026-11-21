\ ******************************************************************************
\
\ p-ws.asm - the shared workspace on the parasite: one run from WP's end (VEC,
\ elite-source.asm's last WP variable) to below CODE%, written, never loaded
\ (p_boot zeroes it). In order: the dummy ACCCON byte; the disc heap's flags
\ and counts, the flare's probes and R_POLY's scratch; the part of the
\ renderer's shared workspace (elite-gfx.asm in the Master port) that the
\ frame layer leaves for the rasteriser, whose state is the host's: the
\ smaller arrays, then from &0C00 the 192-byte row arrays, R_NDISCL page
\ aligned (pr_* and the disc layer index it from its page: p-rast.asm); in
\ the pages between them, the frame layer's buffers F_HW, F_HW2 and the text
\ map; then R_NDISCR's page, and the frame layer's small state, F_SR and
\ the ship records, and the directly drawn stars. No padding: the page
\ aligned arrays start where the declarations before them end
\
\ ******************************************************************************

ACCY = 8
MAXSH = NOSH            \ (elite-gfx.asm's: one record a ship slot at most)
MAXLN = MAXSH
MAXDT = MAXSH
GFXBANK = 6             \ (the frame layer's bank on the Master: unused here)
ELITEBANK = HOMEBANK
ONEPASS = FALSE         \ R_POLY's 8-bit polygons by the one-pass span generator
OPTUBE = TRUE           \ the Tube's: every polygon in one pass (p-onepass.asm, each
                        \ row's span to the host as it is made, p-emit.asm), exactly
                        \ as the two-phase path; no edge tables
NDSTAR = NOST+1

\ The incremental discs' zero page: the rasteriser's &10-&27 (the frame layer's &06-&27, which
\ F_FRAME keeps), free while the disc layer and the second disc run

hp_n  = &10             \ this buffer's surface: count and colour (p),Y
hp_0  = &12             \ its first boundary
hp_1  = &14             \ its second
hd_l  = &16             \ this buffer's second disc: left end
hd_r  = &18             \ right end
hq_s  = &1A             \ (hp_move: the source and destination, row-indexed)
hq_d  = &1C
hq_k  = &1E             \ the body
hq_lo = &1F             \ the rows the body must hold
hq_hi = &20
hq_n  = &21             \ (scratch)
hq_c  = &22             \ a new capacity
hq_w  = &23             \ a new window top
hq_i  = &24
hq_t  = &25
hq_b  = &26             \ (2) a new base
pe_or = &1A             \ (the surface's rows, after the heap's fit: ps_strips'
pe_nr = &1B             \ ends after the right ends, old and new, the new edges
pe_lo = &1C             \ after the left end and before the end after the right
pe_lc = &1D             \ end (pe_np), the left colour; ps_outs' end; the first
pe_np = &21             \ and last rows written)
ps_e  = &1E
pe_wt = &1F
pe_wb = &20

\ The shared workspace's run, from WP's end: its first bytes, then from &0B00
\ the 192-byte row arrays (R_NDISCL page aligned, so these nine bytes are all
\ that come before it), the frame layer's buffers and the text map, R_NDISCR's
\ page, then the smaller arrays and the ship records, each array inside a
\ page (as each was before: no indexed read gains a page crossing) and no
\ ship record's MAXSH bytes across one

ORG VEC + 2

.PWS_START
.PACC       SKIP 1          \ the dummy ACCCON byte: what Master's code writes to
                            \ SHEILA &34 (VIA + &34, elite-source.asm)
ASSERT PACC = VIA + &34
.hp_dfl     SKIP 1          \ non-zero: the heap's drop has run
.hp_dir     SKIP 1          \ hp_move: 1 when the arrays move up
.hp_drops   SKIP 2          \ the heap's drops, and the frames drawn whole for want
.hp_whole   SKIP 2          \ of room (resident: kept while overlay S is out)
.fp_on      SKIP 1          \ the probes: bit 7 arming, bit 6 armed (their places
                            \ and pixels are the frame's scratch, below)
.f_tcol     SKIP 1          \ (f_char1's column)
.R_NDISCL   SKIP 192        \ new disc spans, left ends (page aligned)
ASSERT LO(R_NDISCL) = 0
.R_NDX0     SKIP 192        \ this frame's boundaries
.R_NDX1     SKIP 192
.R_NDN      SKIP 192        \ per disc row: the boundaries' count (bits 0-6) and
                            \ the colour at the span's left end (bit 7)
.F_HW       SKIP 256        \ planet half-widths (page aligned: the disc rows read
.F_HW2      SKIP 256        \ sun half-widths    F_HW,X and F_HW2,X across no page)
.F_TM       SKIP 768        \ the text map (gfx-frame.asm)
ASSERT LO(F_HW) = 0 AND LO(F_TM) = 0
.R_NDISCR   SKIP 192        \ (in one page: f_discspans's symmetric loop)
ASSERT LO(R_NDISCR) = 0
.R_NDX2     SKIP 192
.R_NDX3     SKIP 192
.R_SS       SKIP 24         \ the stars' sizes, then the directly drawn stars'
.F_DSS      SKIP NDSTAR
.R_SX       SKIP 24
.R_SY       SKIP 24
.F_TMR      SKIP 24         \ the text map's rows' counts (gfx-frame.asm)
.F_SLV      SKIP 52         \ the docking slot's vertices (f_poly2, f_slot,
                            \ gfx-frame_cold.asm; F_SLV+16 &80: none)
.F_DSY      SKIP NDSTAR     \ the stars drawn directly (gfx-frame_cold.asm)
.F_SUX      SKIP 2          \ (the sun's centre this frame: F_PLANET's)
.F_SUY      SKIP 2
.F_DCOL     SKIP 2          \ disc colour index in each buffer's disc layer
.F_RP       SKIP 29 * MAXSH \ the ship records (F_SHIP): INWK 0-8, XX16, XX0
F_SZL = F_RP + 6 * MAXSH    \ (the ship's z, INWK 6-7: the sort's, T_KFRAME's)
F_SZH = F_RP + 7 * MAXSH
.F_DSX      SKIP NDSTAR
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
.PWS_END
FOR k, 0, 28                \ (no record's MAXSH bytes across a page)
 ASSERT HI(F_RP + k * MAXSH) = HI(F_RP + k * MAXSH + MAXSH - 1)
NEXT
ASSERT HI(R_SS) = HI(F_DSS + NDSTAR - 1) AND HI(R_SX) = HI(R_SX + 23)
ASSERT HI(R_SY) = HI(R_SY + 23) AND HI(F_TMR) = HI(F_TMR + 23)
ASSERT HI(F_SLV) = HI(F_SLV + 51) AND HI(F_DSX) = HI(F_DSX + NDSTAR - 1)
ASSERT HI(F_DSY) = HI(F_DSY + NDSTAR - 1) AND HI(F_DCOL) = HI(F_DCOL + 1)

\ The persistent state that needs no page of its own: in the 65 bytes
\ between the ship line heap's top (LS%, which the heap never reaches) and
\ WP, which nothing else uses (each byte of WP is in its place in its page,
\ so these were left over). p_boot zeroes them with the run above

ORG LS%
.PWS_LS
\ the ship records' handedness (S_SHIP, L_REC), the lens flare's and the
\ second disc's
.F_DROK     SKIP 1          \ bit 7: R_NDISCL/R still hold f_discspans' last rows
.FL_BEH     SKIP 1
.GFAR       SKIP 1
.GHAND      SKIP 1
.GSPLV      SKIP 4
.GSHT       SKIP 4
.R_S2T      SKIP 2          \ (the second disc's rows in each buffer, f_disc2)
.R_S2B      SKIP 2
.R_S2C      SKIP 2
.ps_ok      SKIP 1          \ non-zero: the surface's state for this buffer's rows
.ps_msk     SKIP 1          \ this buffer's nibble of the surface's (&0F, &F0)
\ the frame layer's small state
.F_BX       SKIP 10         \ the energy bomb's bolt (f_bomb), BOMBTBX and BOMBTBY
.F_BY       SKIP 10         \ as F_BOMB found them
.F_TCH      SKIP 24         \ per text row: bit b, the row changed since buffer b's
                            \ text steps last ran on it (gfx-frame.asm)
.PWS_LS_END
ASSERT PWS_LS_END <= WP AND HI(PWS_LS) = HI(PWS_LS_END - 1)

\ The frame's scratch: written and read only while overlay S is in (by
\ F_FRAME and what it runs, and the ship records that F_FRAME draws, which
\ every screen drawn directly forgets, F_DIRECT), so it shares the bytes of
\ the ball line heap (LSX2, LSY2) that only BLINE writes, in overlay D,
\ after TT66 (TT128, HFS1): never while S is in. The heaps' first bytes,
\ which the space view's WP1, RES2 and WPSHPS write, and LSX2's last
\ (BLINE's LSY2-1 with LSP = 0), are not used. Nothing here is zeroed: each
\ is written before it is read

CLEAR LSX2 + 1, LSX2 + 255  \ (the heaps' bytes are WP's SKIPs: shared here)
CLEAR LSY2 + 1, LSY2 + 256
ORG LSX2 + 2
.R_PXL      SKIP 16         \ vertex x, low bytes (one page: the polygons' code)
.R_PXH      SKIP 16
.R_PYL      SKIP 16
.R_PYH      SKIP 16
ASSERT HI(R_PXL) = HI(R_PYH + 15)
.fp_x       SKIP 9          \ the probes' places (fp_y 255: none) and pixels
.fp_y       SKIP 9
.fp_b       SKIP 9
ASSERT HI(fp_x) = HI(fp_b + 8)
.fp_l       SKIP 1
.fp_r       SKIP 1
.fp_c       SKIP 1
.r_ystart   SKIP 1          \ (R_POLY's scratch: p-poly.asm)
.r_ylast    SKIP 1
.r_yend     SKIP 1
.r_xclip    SKIP 1
.r_cr1      SKIP 1
.r_n        SKIP 1
.r_i0       SKIP 1
.r_i1       SKIP 1
.r_yminL    SKIP 1
.r_yminH    SKIP 1
.r_ymaxL    SKIP 1
.r_ymaxH    SKIP 1
.r_top      SKIP 1
.r_m0       SKIP 1
.r_v0       SKIP 1
.R_X0       SKIP 2          \ line end points (words)
.R_Y0       SKIP 2
.R_X1       SKIP 2
.R_Y1       SKIP 2
.pk_t       SKIP 1          \ (p-kept.asm's scratch)
.pk_l       SKIP 1
.pk_r       SKIP 1
.pk_x       SKIP 1
.pk_w       SKIP 1
.pk_a       SKIP 1
.pk_b       SKIP 1
.pd_ot      SKIP 1          \ the second disc: this buffer's old rows, lo .. hi,
.pd_ob      SKIP 1          \ the row's old and new spans, the new box's x, the
.pd_lo      SKIP 1          \ row settled (K mode), recoloured
.pd_hi      SKIP 1
.pd_a0      SKIP 1
.pd_b0      SKIP 1
.pd_a1      SKIP 1
.pd_b1      SKIP 1
.pd_xl      SKIP 1
.pd_xr      SKIP 1
.pd_wr      SKIP 1
.pd_fl      SKIP 1
.f_zsv      SKIP &22 + 16   \ F_FRAME's keep of &06-&27 and FZ's &D2-&E1
ASSERT P% < LSX2 + 255
ORG LSY2 + 1
F_SRN = MAXSH * 15          \ (the most faces is 15)
.F_SR       SKIP F_SRN      \ the ships' faces' levels (F_SHIP; F_INIT's keep of
                            \ &06-&27 before the first frame)
ASSERT P% <= LSY2 + 256

ORG PWS_END
ASSERT F_DSS = R_SS + 24 AND R_Y1 = R_Y0 + 4
PRINT "Parasite workspace: &", ~PWS_START, "-&", ~PWS_END-1, ", &", ~PWS_LS, "-&", ~PWS_LS_END-1, ", the frame's scratch in LSX2 and LSY2"
ASSERT PWS_END <= CODE%
