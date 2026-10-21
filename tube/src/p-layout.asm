\ ******************************************************************************
\
\ p-layout.asm - the parasite's memory (docs/TUBE-MAP.md): the game and the
\ frame layer in one flat 64K
\
\ The game's source is the Master port's (master/src/elite-source.asm, in the
\ copies tools/streams.py writes with TUBE=1), assembled with _TUBE and
\ _TPART = 1; the far-call stubs between its hot and cold areas are plain
\ jumps. In order from CODE%: the run (its head with the low area, p-low.asm,
\ then the quarter squares, page aligned, and the rest of the run), Master's
\ drawing (the blocks tagged bank 4, whose screen writes go to the host),
\ the game data (elite-data.asm's hot blocks), the cold area (the cold blocks
\ and the cold data), then the frame layer (the renderer's files with
\ _TPART = 1: the part that records and turns the display list into the
\ rasteriser's inputs) and its state. Below CODE%, the renderer's shared
\ workspace at the Master port's addresses (gfx-ws.asm), where the frame
\ layer leaves the rasteriser's inputs for the commands to send. Saved as
\ PCODE from CODE%.
\
\ ******************************************************************************

_TPART = 1

 INCLUDE "tsrc/cmds.asm"

 INCLUDE "build/elite-source-run.asm"

 INCLUDE "build/elite-source-bank4.asm"

PRINT "Parasite: run and Master's drawing end at &", ~P%
.HZ_START
 INCLUDE "build/elite-data-hot.asm"
.HZDATA_END%
 INCLUDE "src/gfx-hangar-hz.asm"
.HZ_END

PRINT "Parasite: data end at &", ~P%
.COLD_START%
 INCLUDE "build/elite-source-cold.asm"
 INCLUDE "build/elite-data-cold.asm"
.COLD_END%

PRINT "Parasite: cold end at &", ~P%
PFRAME% = P%
 INCLUDE "tsrc/p-ws.asm"                \ (ORG &0E00: the frame layer's inputs)
 ORG PFRAME%

.PF_START
 INCLUDE "src/gfx-frame.asm"
 INCLUDE "src/gfx-faces.asm"
 INCLUDE "src/gfx-light6.asm"
 INCLUDE "src/gfx-light.asm"
 INCLUDE "src/gfx-frame_cold.asm"
 INCLUDE "src/gfx-flare6.asm"
 INCLUDE "src/gfx-hangar.asm"
.PF_CODE_END
PRINT "Parasite: frame code end at &", ~P%
.F_HW   SKIP 256        \ planet half-widths
.F_HW2  SKIP 256        \ sun half-widths
.F_DL                   \ ship records: XX2 then XX3 copies (1536 bytes)
 SKIP &22
 INCLUDE "src/gfx-finit.asm"
 SKIP F_DL + 1536 - P%
.F_DLEND
.PCODE_END

 PRINT "Parasite: code &", ~CODE%, "-&", ~PCODE_END-1, ", frame layer &", ~PF_START, "-&", ~PCODE_END-1, " (", PCODE_END-PF_START, " bytes), free to &F800: ", &F800-PCODE_END
 ASSERT PCODE_END <= &F800
 SAVE "build/PCODE.bin", CODE%, PCODE_END, S%
