\ ============================================================================
\ raster_vars.asm -- the variables and arrays of raster.asm that its caller
\ reads or writes.  Assemble it (before INCLUDEing raster.asm) anywhere in
\ memory both the caller and the rasteriser can see (e.g. HAZEL, &C000-&DFFF).
\ No ORG and no alignment: it is placed at P%.  2453 bytes.
\ See raster.asm for what each one means.
\ ============================================================================

.R_PN       SKIP 1          \ polygon vertex count 1..16
.R_PXL      SKIP 16         \ vertex x, low bytes  (signed 16-bit)
.R_PXH      SKIP 16         \ vertex x, high bytes
.R_PYL      SKIP 16         \ vertex y, low bytes
.R_PYH      SKIP 16         \ vertex y, high bytes
.R_X0       SKIP 2          \ line end points: signed 16-bit words (lo, hi)
.R_Y0       SKIP 2
.R_X1       SKIP 2
.R_Y1       SKIP 2
.R_SN       SKIP 1          \ star count 0..24
.R_SX       SKIP 24
.R_SY       SKIP 24
.R_SS       SKIP 24         \ star size 1..3
.R_SCOL     SKIP 1          \ star colour byte (R_INIT: &FF)
.R_NDT      SKIP 1          \ new disc rows NDT..NDB (NDT > NDB: none)
.R_NDB      SKIP 1
.R_NDISCL   SKIP 192        \ new disc spans (rows NDT..NDB only)
.R_NDISCR   SKIP 192
.R_DIRTYL0  SKIP 192        \ buffer 0: dirty extents (empty: L=255, R=0)
.R_DIRTYR0  SKIP 192
.R_DISCL0   SKIP 192        \ buffer 0: disc spans (empty: L=255, R=0)
.R_DISCR0   SKIP 192
.R_DIRTYL1  SKIP 192        \ buffer 1: the same, &300 on
.R_DIRTYR1  SKIP 192
.R_DISCL1   SKIP 192
.R_DISCR1   SKIP 192
.R_WL       SKIP 192        \ this frame's written extents (empty: R=0)
.R_WR       SKIP 192

ASSERT R_Y1 = R_Y0 + 4
ASSERT R_DIRTYL1 = R_DIRTYL0 + &300
