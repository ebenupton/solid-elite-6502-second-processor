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
 INCLUDE "src/gfx-planetv.asm"          \ (the moon's and the ring's variables:
.HZ_END                                 \ f_reset writes them out of space mode)

PRINT "Parasite: data end at &", ~P%
PFRAME% = P%
 INCLUDE "tsrc/p-ws.asm"                \ (ORG &0E00: the frame layer's inputs)
 ORG PFRAME%

.PF_START
 INCLUDE "build/gfx-frame-frame.asm"   \ (streams.py's frame pass)
 INCLUDE "src/gfx-faces.asm"
 INCLUDE "src/gfx-light6.asm"
 INCLUDE "src/gfx-light.asm"
 INCLUDE "build/gfx-frame_cold-frame.asm"  \ (its "Area: ovl S" block, f_slot,
                                        \ in overlay S)
 INCLUDE "src/gfx-hangar.asm"
 INCLUDE "build/gfx-ssun-frame.asm"     \ (S_SUN's and MN_TURN's resident part:
 CPU 1                                  \ G_FRAME, G_PFHOOK, MOONHIT)
 INCLUDE "src/elite-moon.asm"           \ (MOONHIT: the moon is solid)
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
.F_TM   SKIP 768        \ the text map (gfx-frame.asm)
.F_SLV  SKIP 52         \ the docking slot's vertices (f_poly2, f_slot,
                        \ gfx-frame_cold.asm; F_SLV+16 &80: none)
.PRES_END                \ (the end of what is always resident)


\ The overlay region (p-ovl.asm): from OVL_START, page aligned, to RING. The
\ parasite's image holds overlay D there (the cold area: the direct-mode
\ blocks tagged "Tube: ovl D", then the extended tokens); the host keeps its
\ image (HOVD), whole pages
 ORG (P% + 255) AND &FF00
.OVL_START
.COLD_START%
 INCLUDE "build/elite-source-cold.asm"
 INCLUDE "build/elite-data-cold.asm"
 INCLUDE "build/p-io-ovld.asm"          \ (the "ovl D" blocks of the Tube's files:
 INCLUDE "build/p-glue-ovld.asm"        \ streams.py's ovld passes)
.COLD_END%
.OVL_D_END

.PCODE_END

 PRINT "Parasite: code &", ~CODE%, "-&", ~PRES_END-1, ", frame layer &", ~PF_START, "-&", ~PRES_END-1, " (", PRES_END-PF_START, " bytes)"
 PRINT "Parasite: overlay region &", ~OVL_START, "-&", ~RING-1, " (", RING-OVL_START, " bytes), overlay D to &", ~OVL_D_END-1, " (", OVL_D_END-OVL_START, " bytes), free to the ring: ", RING-OVL_D_END
 ASSERT PCODE_END <= RING
 ASSERT ZPSAVE + &90 >= (OVL_D_END + 255) AND &FF00 AND ZPSAVE + &100 <= RING   \ (getzp's buffer: above
                        \ overlay D's pages, which a load of D rewrites; elite-source.asm)
 SAVE "build/PCODE.bin", CODE%, PCODE_END, S%
 SAVE "build/HOVD.bin", OVL_START, (OVL_D_END + 255) AND &FF00

\ Overlay S, the space-mode overlay: the rasteriser (p-rast.asm: its state
\ first, then its code), the lens flare and the planet's surface (the circle
\ engine, gfx-merid.asm, and its styles, moon and ring, gfx-planet7.asm),
\ from OVL_START (p-ovl.asm). The host keeps its image (HOVS)
 IF MEASURE             \ (tube/build.sh MEASURE=1: sizes only, no usable image)
  CLEAR OVL_START, &FFFF
 ELSE
  CLEAR OVL_START, &F800
 ENDIF
 ORG OVL_START
.OVL_S_START
 INCLUDE "tsrc/p-rast.asm"
 INCLUDE "tsrc/p-moon.asm"              \ (the moon, drawn incrementally)
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
 INCLUDE "src/gfx-planet7.asm"
 CPU 1
 INCLUDE "build/gfx-frame_cold-ovls.asm"  \ (f_slot: the stars round a docking slot)
 INCLUDE "build/gfx-ssun-ovls.asm"      \ (S_SUN's ss_seed and ss_draw)
.OVL_S_END
 PRINT "Parasite: overlay S &", ~OVL_START, "-&", ~OVL_S_END-1, " (", OVL_S_END-OVL_START, " bytes, its state ", S_STATE_END-OVL_START, "), free to the ring: ", RING-OVL_S_END
 ASSERT OVL_S_END <= RING OR MEASURE    \ (the ring above: p-io.asm)
 SAVE "build/HOVS.bin", OVL_START, (OVL_S_END + 255) AND &FF00

\ The high code (PHIGH): &F800-&FEEF, where the client OS is until the boot
\ (p_boot) copies it in from the staging area; then the page at &FF00 with
\ the vectors (&FFFA-&FFFF): NMI an RTI (the host never writes register 3
\ again), RESET p_start, IRQ and BRK pirq (the ring's doorbell, p-io.asm; a
\ BRK goes on to p_crash)
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
.pcrsh
 JMP pcrsh
.p_nmi
 RTI
.pcra EQUB 0
.pcrx EQUB 0
.pcry EQUB 0
.pcrs EQUB 0
 INCLUDE "src/gfx-flare6.asm"           \ (resident code and tables, out of the
 CPU 1                                  \ run: OVL_START is lower for them)
 INCLUDE "tsrc/p-flt.asm"               \ (the lens flare's tables)
.F_DSX  SKIP NDSTAR     \ the stars drawn directly (gfx-frame_cold.asm)
.F_DSY  SKIP NDSTAR
.PFF_END
 PRINT "Parasite: the page at &FF00 to &", ~PFF_END-1, ", free to &FFFA: ", &FFFA-PFF_END

\ QSL, the quarter squares' low bytes (elite-qs.asm: QSH is in the run), in
\ the client OS's pages 2 and 3 (its vectors and error buffer)
 CLEAR &0200, &0400
 ORG &0200
.QSL
FOR n, 0, 511
 EQUB LO(n * n DIV 4)
NEXT
 ASSERT PFF_END <= &FFFA
 ORG &FFFA
 EQUW p_nmi, p_start, pirq

 CLEAR OVL_D_END, &F800
 ORG OVL_D_END

\ The boot's staging area, above overlay D (S and the next C_OVLGET of D
\ overwrite it; tube/build.sh appends it to PCODE): p_boot (p_start's first
\ call), the high area's image, the page at &FF00 and pages 2 and 3. p_boot drains a stray byte from
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
 LDA PSTG_LO,X
 STA &0200,X
 LDA PSTG_LO + 256,X
 STA &0300,X
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
 EQUB HI(pirq)          \ (&FFFF: COPYBLOCK's end is 16-bit)
.PSTG_LO
 COPYBLOCK &0200, &0400, P%
 ORG PSTG_LO + &200
.PSTG_END
 PRINT "Parasite: the boot's staging &", ~OVL_D_END, "-&", ~PSTG_END-1, ", free to the ring: ", RING-PSTG_END
 ASSERT PSTG_END <= RING OR MEASURE
 SAVE "build/PSTAGE.bin", OVL_D_END, PSTG_END
