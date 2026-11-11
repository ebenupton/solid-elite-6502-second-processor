\ ******************************************************************************
\
\ p-layout.asm - the parasite's memory (docs/TUBE-MAP.md): the game and the
\ frame layer in one flat 64K
\
\ Every place is a pass. A source file is one file wherever its blocks go:
\ the game's source (master/src/elite-source.asm) by its headers' "Tube:"
\ fields, the renderer's files and the Tube's own by "Area:" tag lines;
\ tools/streams.py writes a copy of each file for each place, the other
\ lines blanked (build/<file>-<pass>.asm: frame, the file's own place,
\ which is the resident code; ovld, overlay D; ovls, overlay S; high, low,
\ top and boot), and this file includes each copy at its place, as the
\ Master port's layout includes its low, hot and cold passes.
\
\ The game's copies (tools/streams.py with TUBE=1) are assembled with _TUBE
\ and _TPART = 1; the far-call stubs between its hot and cold areas are plain
\ jumps. In order from CODE%: the run (its head with the low area, p-low.asm,
\ then the quarter squares, page aligned, and the rest of the run), Master's
\ drawing (the blocks tagged bank 4, whose screen writes go to the host),
\ the game data (elite-data.asm's hot blocks), the cold area (the cold blocks
\ and the cold data), then the frame layer (the renderer's files with
\ _TPART = 1: the part that records and turns the display list into the
\ rasteriser's inputs) and its state. Below CODE%, the renderer's shared
\ workspace at the Master port's addresses (elite-gfx.asm), where the frame
\ layer leaves the rasteriser's inputs for the commands to send. Saved as
\ PCODE from CODE%.
\
\ ******************************************************************************

_TPART = 1
_HOSTB = FALSE          \ (not the Model B host: hb-*.asm)
_RBANK = 0

 INCLUDE "tsrc/cmds.asm"

 INCLUDE "build/elite-source-config.asm"   \ (the configuration and the workspaces)

 ORG CODE%
.PCODE_START
 INCLUDE "tsrc/p-low.asm"               \ the parasite's glue (p-low.asm)
.GLUE_END%

 INCLUDE "build/elite-source-run.asm"   \ the game, resident, in the source's order

PRINT "Parasite: glue &", ~CODE%, "-&", ~GLUE_END%-1, ", the game's run to &", ~P%-1
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
 INCLUDE "build/gfx-light-6.asm"         \ (L_REC)
 INCLUDE "build/gfx-light-4.asm"         \ (L_SUN, from G_FRAME and G_HANGAR)
 INCLUDE "build/gfx-frame_cold-frame.asm"  \ (its "Area: ovl S" block, f_slot,
                                        \ in overlay S)
 INCLUDE "build/gfx-hangar-frame.asm"  \ (streams.py's pass: F_HANG0 is overlay D's)
 INCLUDE "build/gfx-ssun-frame.asm"     \ (S_SUN's and MN_TURN's resident part:
 CPU 1                                  \ G_FRAME, G_PFHOOK, MOONHIT)
 INCLUDE "src/elite-moon.asm"           \ (MOONHIT: the moon is solid)
.PF_CODE_END
PRINT "Parasite: frame code end at &", ~P%
.F_HW   SKIP 256        \ planet half-widths
.F_HW2  SKIP 256        \ sun half-widths
F_SRN = MAXSH * 15      \ (the most faces is 15)
.F_SR                   \ the ships' faces' levels (F_SHIP), with F_INIT, run
 SKIP &22               \ once before the first frame, in its room
 INCLUDE "src/gfx-finit.asm"
 SKIP F_SR + F_SRN - P%
.F_RP   SKIP 29 * MAXSH \ the ship records (F_SHIP): INWK 0-8, XX16, XX0
F_SZL = F_RP + 6 * MAXSH  \ (the ship's z, INWK 6-7: the sort's, T_KFRAME's)
F_SZH = F_RP + 7 * MAXSH
.F_DLEND                \ (the rest of the frame layer's small state is p-low.asm's)
.F_TM   SKIP 768        \ the text map (gfx-frame.asm)
.PRES_END                \ (the end of what is always resident)

\ The low code (PLOW, the "Area: low" passes): resident too, in the
\ workspace's tail below CODE% (p-ws.asm), which p_boot copies it into from
\ the staging area
PRES_ORG = P%
 ORG PWS_END
.PLOW
 INCLUDE "build/p-disc-low.asm"     \ (the disc heap's drop)
 INCLUDE "build/p-ovl-low.asm"      \ (savc0, savosc's first byte)
.PLOW_END
 PRINT "Parasite: low code &", ~PLOW, "-&", ~PLOW_END-1, ", free to CODE%: ", CODE%-PLOW_END
 ASSERT PLOW_END <= CODE%
 ORG PRES_ORG


\ The overlay region (p-ovl.asm): from OVL_START, page aligned, to RING. The
\ parasite's image holds overlay D there (the cold area: the direct-mode
\ blocks tagged "Tube: ovl D", then the extended tokens); the host keeps its
\ image (HOVD), whole pages
 ORG (P% + 255) AND &FF00
.OVL_START
.COLD_START%
 INCLUDE "build/elite-stubs-x4.asm"    \ (overlay D's names for resident routines)
 INCLUDE "build/elite-source-cold.asm"
 INCLUDE "build/elite-data-cold.asm"
 INCLUDE "build/p-io-ovld.asm"          \ (the "ovl D" blocks of the Tube's files
 INCLUDE "build/p-glue-ovld.asm"        \ and the renderer's: streams.py's ovld
 INCLUDE "build/gfx-hooks-ovld.asm"     \ passes)
 INCLUDE "build/gfx-frame_cold-ovld.asm"
 INCLUDE "build/gfx-hangar-ovld.asm"
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

\ Overlay S, the space-mode overlay (the "Area: ovl S" passes): the
\ rasteriser (p-rast.asm: its state first, then its code), the lens flare
\ and the planet's surface (the circle engine, gfx-merid.asm, and its
\ styles, moon and ring, gfx-planet7.asm), from OVL_START (p-ovl.asm). The
\ host keeps its image (HOVS)
 IF MEASURE             \ (tube/build.sh MEASURE=1: sizes only, no usable image)
  CLEAR OVL_START, &FFFF
 ELSE
  CLEAR OVL_START, &F800
 ENDIF
 ORG OVL_START
.OVL_S_START
 INCLUDE "build/p-rast-ovls.asm"
 INCLUDE "build/p-disc-ovls.asm"        \ (the disc heap, the surface and the second disc
                                        \ drawn as changes)
IF _PLANET_MOON
 ERROR "MOON=on: the Tube's parasite has no room for the moon"
ENDIF
IF _PLANET_RINGS
.RG_Y   SKIP 64         \ the ring's dots' y and flags (gfx-planetv.asm's in the
.RG_F   SKIP 64         \ Master port): only used with S in (pf_ring, f_ring)
ENDIF
 INCLUDE "build/p-emit-ovls.asm"        \ (the polygons' rows to the host as they are made)
 INCLUDE "build/p-kept-ovls.asm"        \ (kept solid rows)
 INCLUDE "build/p-poly-ovls.asm"        \ (R_POLY's set-up and arithmetic, C_DSPANS's
 CPU 1                                  \ encoder: only ever run with S in)
 INCLUDE "build/p-onepass-ovls.asm"     \ (R_POLY in one pass)
 INCLUDE "build/gfx-frame-ovls.asm"    \ (the text overlay and the sights)
 CPU 1
 INCLUDE "build/gfx-flare-ovls.asm"
 CPU 1
 INCLUDE "build/p-probe-ovls.asm"       \ (the lens flare's probes)
 INCLUDE "build/gfx-merid-ovls.asm"
 CPU 1
 INCLUDE "build/gfx-planet7-ovls.asm"
 CPU 1
 INCLUDE "build/gfx-frame_cold-ovls.asm"  \ (f_slot: the stars round a docking slot)
 INCLUDE "build/gfx-hangar-ovls.asm"     \ (fh_rect: the hangar's rectangles, f_hback's, in F_FRAME)
 INCLUDE "build/gfx-ssun-ovls.asm"      \ (S_SUN's ss_seed and ss_draw)
 INCLUDE "build/p-lost-ovls.asm"        \ (S's state rebuilt: r_lost)
.OVL_S_END
 PRINT "Parasite: overlay S &", ~OVL_START, "-&", ~OVL_S_END-1, " (", OVL_S_END-OVL_START, " bytes, its state ", S_STATE_END-OVL_START, "), free to the ring: ", RING-OVL_S_END
 ASSERT OVL_S_END <= RING OR MEASURE    \ (the ring above: p-io.asm)
 SAVE "build/HOVS.bin", OVL_START, (OVL_S_END + 255) AND &FF00

\ The high code (PHIGH, the "Area: high" passes): &F800-&FEEF, where the
\ client OS is until the boot (p_boot) copies it in from the staging area;
\ then the page at &FF00 (the "Area: top" passes) with the vectors
\ (&FFFA-&FFFF): NMI an RTI (the host never writes register 3 again), RESET
\ p_start, IRQ and BRK pirq (the ring's doorbell, p-io.asm; a BRK goes on to
\ p_crash)
 ORG &F800
.PHIGH_START
 INCLUDE "build/p-poly-high.asm"    \ (R_POLY's phase A from r_e8)
 CPU 1
 INCLUDE "build/p-dash-high.asm"    \ (the dashboard's parasite halves: MSBAR, the bulbs)
 INCLUDE "build/p-kept-high.asm"    \ (kept solid rows: pk_line, T_KFRAME)
 INCLUDE "build/p-onepass-high.asm" \ (R_POLY in one pass: oo_scan, the 16-bit edges)
.PHIGH_END
 PRINT "Parasite: high code &F800-&", ~PHIGH_END-1, ", free to &FEF0: ", &FEF0-PHIGH_END
 ASSERT PHIGH_END <= &FEF0 OR MEASURE
 SAVE "build/PHIGH.bin", PHIGH_START, PHIGH_END
 CLEAR &FF00, &10000       \ (and its guard, elite-source-run.asm's &FEF0)
 ORG &FF00
.PFF_START
 INCLUDE "build/p-io-top.asm"           \ (p_crash, p_nmi)
 INCLUDE "build/gfx-flare-top.asm"      \ (the flare's step in F_FRAME, f_flt: out
 CPU 1                                  \ of the run, OVL_START is lower for it)
 INCLUDE "build/p-probe-top.asm"        \ (the lens flare's probes' resident part)
.F_DSX  SKIP NDSTAR     \ the stars drawn directly (gfx-frame_cold.asm)
.F_DSY  SKIP NDSTAR
.PFF_END
 PRINT "Parasite: the page at &FF00 to &", ~PFF_END-1, ", free to &FFFA: ", &FFFA-PFF_END

 ASSERT PFF_END <= &FFFA
 ORG &FFFA
 EQUW p_nmi, p_start, pirq

 CLEAR OVL_D_END, &F800
 ORG OVL_D_END

\ The boot's staging area, above overlay D (S and the next C_OVLGET of D
\ overwrite it; tube/build.sh appends it to PCODE): p_start and p_boot (the
\ "Area: boot" pass, p-io.asm), then the images p_boot copies in over the
\ client OS: the high area, the page at &FF00 and the low code

 INCLUDE "build/p-io-boot.asm"          \ (p_start, p_boot)
.PSTG_HI
 COPYBLOCK &F800, &FEF0, P%
 ORG PSTG_HI + &6F0
.PSTG_FF
 COPYBLOCK &FF00, &FFFF, P%
 ORG PSTG_FF + &FF
 EQUB HI(pirq)          \ (&FFFF: COPYBLOCK's end is 16-bit)
.PSTG_PL
 COPYBLOCK PLOW, PLOW_END, P%
 ORG PSTG_PL + PLOW_END - PLOW
.PSTG_END
 PRINT "Parasite: the boot's staging &", ~OVL_D_END, "-&", ~PSTG_END-1, ", free to the ring: ", RING-PSTG_END
 ASSERT PSTG_END <= RING OR MEASURE
 SAVE "build/PSTAGE.bin", OVL_D_END, PSTG_END
