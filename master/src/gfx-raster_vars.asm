\ ============================================================================
\ raster_vars.asm -- the variables and arrays of raster.asm that its caller
\ reads or writes.  Assemble it (before INCLUDEing raster.asm) anywhere in
\ memory both the caller and the rasteriser can see (e.g. HAZEL, &C000-&DFFF).
\ No ORG and no alignment: it is placed at P%.  5921 bytes.
\ See raster.asm for what each one means.
\ ============================================================================

.R_NDT      SKIP 1          \ new disc rows NDT..NDB (NDT > NDB: none)
.R_NDB      SKIP 1
.R_NDISCR   SKIP 192
.R_DIRTYL0  SKIP 192        \ buffer 0: dirty extents (empty: L=255, R=0)
.R_DIRTYR0  SKIP 192
.R_DISCR0   SKIP 192        \ buffer 0: disc spans (empty: L=255, R=0); R before
.R_DISCL0   SKIP 192        \ L so that L (read more often) is at LO &35: no page crossing
.R_DIRTYL1  SKIP 192        \ buffer 1: the same, &300 on
.R_DIRTYR1  SKIP 192
.R_DISCR1   SKIP 192
.R_DISCL1   SKIP 192
\ two-colour discs (R_DISCROWS): rows NDT..NDB, used when R_NDF <> 0
.R_NDF      SKIP 1          \ 0: no boundaries this frame (disc all colour A)
.R_DBE      SKIP 1          \ colour B pair (even, odd rows)
.R_DBO      SKIP 1
.R_NDP      SKIP 192        \ bit 0: colour (0 = A, 1 = B) at the span's left end
.R_NDX0     SKIP 192        \ boundary x, ascending: pixels >= x take the other
.R_NDX1     SKIP 192        \ colour; values <= NDISCL or > NDISCR are allowed
.R_NDX2     SKIP 192
.R_NDX3     SKIP 192
\ private to raster.asm: each buffer's last boundaries (raw), &500 apart
.R_BDN0     SKIP 192
.R_BDP0     SKIP 192
.R_BDX00    SKIP 192
.R_BDX10    SKIP 192
.R_BDX20    SKIP 192
.R_BDX30    SKIP 192
\ (in the gap between the two buffers' boundary arrays: Master port, for room
\ in HAZEL below &DC00)
.R_GAP0
.PM_OK   SKIP 1         \ bit 7: PM_BLK1/2 hold this frame's meridian constants
.PM_R    SKIP 1         \ the planet's radius (F_PLANET)
.PM_BLK1 SKIP MCB       \ roofv's circle (planet4.asm -> f_merid)
.PM_BLK2 SKIP MCB       \ sidev's
.PM_CX   SKIP 2         \ the planet's centre (f_merid -> PM_MERID)
.PM_CY   SKIP 2
\ private to raster.asm / raster7.asm: shared state
.R_PRBUF    SKIP 1
.R_PRDYT    SKIP 2
.R_PRDYB    SKIP 2
.R_PRDST    SKIP 2
.R_PRDSB    SKIP 2
.R_PRSCNT   SKIP 2
.R_PRECNT   SKIP 2
.R_PRWT     SKIP 1
.R_PRWB     SKIP 1
.R_PRBMODE  SKIP 2
.R_PRNT     SKIP 1          \ R_DISCROWS' scalars (here so bank 7 can see them)
.R_PRNB     SKIP 1
.R_PRLO     SKIP 1
.R_PRHI     SKIP 1
.R_PRDYA    SKIP 1
.R_PRDYZ    SKIP 1
.R_PRCWB    SKIP 1
.r7_lpx     SKIP 1          \ r_lc16 -> r7_lines: start pixel, error, a, b, count, kind
.r7_lpy     SKIP 1
.r7_lpe     SKIP 1
.r7_lpa     SKIP 1
.r7_lpb     SKIP 1
.r7_lpn     SKIP 1
.r7_lpk     SKIP 1          \ last row whose R_WL/R_WR the repair wrote (0: none)
            SKIP &500 - 6 * 192 - (P% - R_GAP0)
.R_BDN1     SKIP 192
.R_BDP1     SKIP 192
.R_BDX01    SKIP 192
.R_BDX11    SKIP 192
.R_BDX21    SKIP 192
.R_BDX31    SKIP 192


ASSERT R_DIRTYL1 = R_DIRTYL0 + &300
ASSERT R_BDN1 = R_BDN0 + &500
