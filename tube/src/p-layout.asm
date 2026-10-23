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
 INCLUDE "tsrc/p-flt.asm"               \ (the lens flare's tables: resident, for S's room)
 CPU 1
.PF_CODE_END
PRINT "Parasite: frame code end at &", ~P%
IF OPTEST                \ (a test build for test_onepass.py --tube only: the
.F_HW                   \ one-pass generator over the frame layer's buffers)
 INCLUDE "tsrc/p-onepass.asm"
 SKIP F_HW + 2048 - P%
F_HW2 = F_HW + 256
F_DL = F_HW + 512
F_INIT = F_HW
ELSE
.F_HW   SKIP 256        \ planet half-widths
.F_HW2  SKIP 256        \ sun half-widths
.F_DL                   \ ship records: XX2 then XX3 copies (1536 bytes)
 SKIP &22
 INCLUDE "src/gfx-finit.asm"
 SKIP F_DL + 1536 - P%
ENDIF
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
 IF MEASURE             \ (tube/build.sh MEASURE=1: sizes only, no usable image)
  CLEAR OVL_START, &FFFF
 ELSE
  CLEAR OVL_START, &F800
 ENDIF
 ORG OVL_START
.OVL_S_START
 INCLUDE "tsrc/p-rast.asm"
 INCLUDE "tsrc/p-emit.asm"              \ (the polygons' rows to the host as they are made)
 INCLUDE "tsrc/p-kept.asm"              \ (kept solid rows)
 INCLUDE "tsrc/p-polya.asm"             \ (R_POLY's set-up and arithmetic, C_DSPANS's
 CPU 1                                  \ encoder: only ever run with S in)
IF OPTEST = 0
 INCLUDE "tsrc/p-onepass.asm"           \ (R_POLY in one pass)
ENDIF
 INCLUDE "src/gfx-ftext.asm"
 CPU 1
 INCLUDE "src/gfx-flare.asm"
 CPU 1
 INCLUDE "src/gfx-merid.asm"
 CPU 1
.OVL_S_END
 PRINT "Parasite: overlay S &", ~OVL_START, "-&", ~OVL_S_END-1, " (", OVL_S_END-OVL_START, " bytes, its state ", S_STATE_END-OVL_START, "), free to &F800: ", &F800-OVL_S_END
 ASSERT OVL_S_END <= &F800 OR MEASURE
 SAVE "build/HOVS.bin", OVL_START, (OVL_S_END + 255) AND &FF00

\ The high code (PHIGH): &F800-&FEEF, where the client OS is until the boot
\ (p_boot) copies it in from the staging area; then the page at &FF00 with
\ the vectors (&FFFA-&FFFF): NMI an RTI (the host never writes register 3
\ again), RESET p_start, IRQ and BRK p_crash (interrupts stay off, so only a
\ BRK can come here: a crash)
 ORG &F800
.PHIGH_START
 INCLUDE "tsrc/p-polyb.asm"    \ (phase 3: R_POLY's phase A, its second part)
 CPU 1
 INCLUDE "tsrc/p-dash2.asm"    \ (the dashboard's parasite halves, their second part)
 INCLUDE "tsrc/p-kept2.asm"    \ (kept solid rows: T_KFRAME)
 INCLUDE "tsrc/p-onepass2.asm" \ (R_POLY in one pass: its second part)
.PHIGH_END
 PRINT "Parasite: high code &F800-&", ~PHIGH_END-1, ", free to &FEF0: ", &FEF0-PHIGH_END
 ASSERT PHIGH_END <= &FEF0 OR MEASURE
 SAVE "build/PHIGH.bin", PHIGH_START, PHIGH_END
 CLEAR &FF00, &10000       \ (and its guard, elite-source-run.asm's &FEF0)
 ORG &FF00
.PFF_START
.p_crash                \ a BRK (a crash): A, X, Y and S kept here (the stack's
 STA pcra               \ top at &0101+S: the flags, then the BRK's address+2)
 STX pcrx
 STY pcry
 TSX
 STX pcrs
.pcr1
 JMP pcr1
.p_nmi
 RTI
.pcra EQUB 0
.pcrx EQUB 0
.pcry EQUB 0
.pcrs EQUB 0
.PFF_END
 ASSERT PFF_END <= &FFFA
 ORG &FFFA
 EQUW p_nmi, p_start, p_crash

 CLEAR OVL_D_END, &F800
 ORG OVL_D_END

\ The boot's staging area, above overlay D (S and the next C_OVLGET of D
\ overwrite it; tube/build.sh appends it to PCODE): p_boot (p_start's first
\ call), the high area's image and the page at &FF00. p_boot drains a stray byte from
\ the host in register 1, then copies them in over the client OS, which the
\ game never uses again

.p_boot
 LDA &FEF8
 BPL pbt0
 LDA &FEF9
.pbt0
 LDX #0
.pbt1
 LDA PSTG_FF,X
 STA &FF00,X
FOR i, 0, 5
 LDA PSTG_HI + i * 256,X
 STA &F800 + i * 256,X
NEXT
 CPX #&F0
 BCS pbt2
 LDA PSTG_HI + &600,X
 STA &FE00,X
.pbt2
 INX
 BNE pbt1
 RTS
.PSTG_HI
 COPYBLOCK &F800, &FEF0, P%
 ORG PSTG_HI + &6F0
.PSTG_FF
 COPYBLOCK &FF00, &FFFF, P%
 ORG PSTG_FF + &FF
 EQUB HI(p_crash)       \ (&FFFF: COPYBLOCK's end is 16-bit)
.PSTG_END
 PRINT "Parasite: the boot's staging &", ~OVL_D_END, "-&", ~PSTG_END-1, ", free to &F800: ", &F800-PSTG_END
 ASSERT PSTG_END <= &F800 OR MEASURE
 SAVE "build/PSTAGE.bin", OVL_D_END, PSTG_END
