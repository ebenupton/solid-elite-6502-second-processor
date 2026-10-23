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
_HOSTB = FALSE          \ (not the Model B host: hb-*.asm)
_RBANK = 0

 INCLUDE "tsrc/cmds.asm"

 INCLUDE "build/elite-source-run.asm"

 INCLUDE "build/elite-source-bank4.asm"

PRINT "Parasite: run and Master's drawing end at &", ~P%
.HZ_START
 INCLUDE "build/elite-data-hot.asm"
.HZDATA_END%
 INCLUDE "src/gfx-hangar6.asm"
.HZ_END

PRINT "Parasite: data end at &", ~P%
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
 INCLUDE "tsrc/p-polya.asm"    \ (phase 3: R_POLY's phase A, its first part)
 CPU 1
.PF_CODE_END
PRINT "Parasite: frame code end at &", ~P%
.F_HW   SKIP 256        \ planet half-widths
.F_HW2  SKIP 256        \ sun half-widths
.F_DL                   \ ship records: XX2 then XX3 copies (1536 bytes)
 SKIP &22
 INCLUDE "src/gfx-finit.asm"
 SKIP F_DL + 1536 - P%
.F_DLEND
.F_TM   SKIP 768        \ the text map (gfx-frame.asm), and what each buffer shows
.F_ST   SKIP 768
ASSERT F_ST = F_TM + &300
.F_DSX  SKIP NDSTAR     \ the stars drawn directly (gfx-frame_cold.asm)
.F_DSY  SKIP NDSTAR
.PRES_END                \ (the end of what is always resident)

\ The overlay region (p-ovl.asm): from OVL_START, page aligned, to &F800. The
\ parasite's image holds overlay D there (the cold area: the direct-mode
\ blocks of tube/src/ovl-d.txt, then the extended tokens); the host keeps its
\ image (HOVD), whole pages
 ORG (P% + 255) AND &FF00
.OVL_START
.COLD_START%
 INCLUDE "build/elite-source-cold.asm"
 INCLUDE "build/elite-data-cold.asm"
.COLD_END%
.OVL_D_END
.PCODE_END

 PRINT "Parasite: code &", ~CODE%, "-&", ~PRES_END-1, ", frame layer &", ~PF_START, "-&", ~PRES_END-1, " (", PRES_END-PF_START, " bytes)"
 PRINT "Parasite: overlay region &", ~OVL_START, "-&F7FF (", &F800-OVL_START, " bytes), overlay D to &", ~OVL_D_END-1, " (", OVL_D_END-OVL_START, " bytes), free to &F800: ", &F800-OVL_D_END
 ASSERT PCODE_END <= &F800
 SAVE "build/PCODE.bin", CODE%, PCODE_END, S%
 SAVE "build/HOVD.bin", OVL_START, (OVL_D_END + 255) AND &FF00

\ Overlay S, the space-mode overlay: the rasteriser (p-rast.asm: its state
\ first, then its code), the lens flare and the meridian window (the beach
\ ball), from OVL_START (p-ovl.asm). The host keeps its image (HOVS)
 CLEAR OVL_START, &F800
 ORG OVL_START
.OVL_S_START
 INCLUDE "tsrc/p-rast.asm"
 INCLUDE "src/gfx-ftext.asm"
 CPU 1
 INCLUDE "tsrc/p-flt.asm"
 INCLUDE "src/gfx-flare.asm"
 CPU 1
 INCLUDE "src/gfx-merid.asm"
 CPU 1
.OVL_S_END
 PRINT "Parasite: overlay S &", ~OVL_START, "-&", ~OVL_S_END-1, " (", OVL_S_END-OVL_START, " bytes, its state ", S_STATE_END-OVL_START, "), free to &F800: ", &F800-OVL_S_END
 ASSERT OVL_S_END <= &F800
 SAVE "build/HOVS.bin", OVL_START, (OVL_S_END + 255) AND &FF00

\ The high code (PHIGH): &F800-&FEEF, where the client OS's copy is but for
\ the client's only use (the boot and disc commands, through the MOS's Tube
\ code): the host keeps whichever of the two is not in the parasite, and
\ p_swap exchanges them (at the start, and either side of a disc command)
 ORG &F800
.PHIGH_START
 INCLUDE "tsrc/p-polyb.asm"    \ (phase 3: R_POLY's phase A, its second part)
 CPU 1
 INCLUDE "tsrc/p-dash2.asm"    \ (the dashboard's parasite halves, their second part)
.PHIGH_END
 PRINT "Parasite: high code &F800-&", ~PHIGH_END-1, ", free to &FEF0: ", &FEF0-PHIGH_END
 ASSERT PHIGH_END <= &FEF0
 SAVE "build/PHIGH.bin", PHIGH_START, PHIGH_END
