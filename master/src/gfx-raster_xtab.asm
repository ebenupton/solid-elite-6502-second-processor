\ ============================================================================
\ raster_xtab.asm -- the per-x tables that gfx-raster.asm's span core, R_LINE,
\ r_pset and the stars read (each 256 bytes, page aligned by the includer),
\ as macros, so that a host whose readers of them are in two banks emits
\ the same tables in both (the Tube's Model B host: tube/src/hb-line.asm)
\ ============================================================================

MACRO R_XOTAB             \ (8 * (x DIV 4)) AND &FF : edge byte offset
FOR x, 0, 255
  EQUB (x * 2) AND &F8
NEXT
ENDMACRO

MACRO R_LMTAB             \ pixels (x AND 3)..3 of a byte
FOR x, 0, 255
  EQUB ((&F0 >> (x AND 3)) AND &F0) OR (&0F >> (x AND 3))
NEXT
ENDMACRO

MACRO R_RMTAB             \ pixels 0..(x AND 3) of a byte
FOR x, 0, 255
  EQUB ((&F0 << (3 - (x AND 3))) AND &F0) OR ((&0F << (3 - (x AND 3))) AND &0F)
NEXT
ENDMACRO
