\ ******************************************************************************
\
\ p-layout.asm - the parasite's memory (docs/TUBE-MAP.md): the game and the
\ frame layer in one flat 64K
\
\ Every place is a pass. A source file is one file wherever its blocks go:
\ the game's source (master/src/elite-source.asm) by its headers' "Tube:"
\ fields, the renderer's files and the parasite's own by "Area:" tag lines;
\ tools/streams.py writes a copy of each file for each place, the other
\ lines blanked (build/<file>-<pass>.asm: frame, the file's own place,
\ which is the resident code; ovld, overlay D; ovls, overlay S; fe and ff,
\ the top pages; boot), and this file includes each copy at its place, as
\ the Master port's layout includes its low, hot and cold passes.
\
\ The game's copies (tools/streams.py with TUBE=1) are assembled with _TUBE
\ and _TPART = 1; the far-call stubs between its hot and cold areas are plain
\ jumps. In order from CODE%: the glue area (p-low.asm), the game's run (every
\ block not tagged for overlay D, the hosts or the aligned pass, in the
\ source's order), the game data (elite-data.asm's hot blocks), the frame
\ layer (the renderer's files with _TPART = 1: the part that records and
\ turns the display list into the rasteriser's inputs), then, after the
\ resident code's one gap, the log tables and the quarter-square tables,
\ page aligned, ending where the overlay region starts. Below CODE%, the shared workspace
\ (p-ws.asm), where the frame layer leaves the rasteriser's per-call inputs
\ for the commands to send. Saved as PCODE from CODE%, without the
\ quarter-square tables (p_load in their place).
\
\ ******************************************************************************

_TPART = 1
_HOSTB = FALSE          \ (not the Model B host: hb-*.asm)
_RBANK = 0

 INCLUDE "tsrc/cmds.asm"

 INCLUDE "build/elite-source-config.asm"   \ (the configuration and the workspaces)
 INCLUDE "tsrc/p-ws.asm"                \ (the shared workspace, after WP)
 ASSERT CODE% = PWS_END                 \ (the code starts where the workspace ends)

 ORG CODE%
.PCODE_START
 INCLUDE "tsrc/p-low.asm"               \ the glue area (p-low.asm)
.GLUE_END%

 INCLUDE "build/elite-source-run.asm"   \ the game, resident, in the source's order

PRINT "Parasite: glue &", ~CODE%, "-&", ~GLUE_END%-1, ", the game's run to &", ~P%-1
.HZ_START
 INCLUDE "build/elite-data-hot.asm"
.HZDATA_END%
 INCLUDE "src/gfx-hangar6.asm"
 INCLUDE "src/gfx-planetv.asm"          \ (the ring's variables, with RINGS=on:
.HZ_END                                 \ f_reset writes them out of space mode)

PRINT "Parasite: data end at &", ~P%

.PF_START
 INCLUDE "build/gfx-frame-frame.asm"   \ (streams.py's frame pass)
 INCLUDE "src/gfx-faces.asm"
 INCLUDE "src/gfx-light6.asm"
 INCLUDE "build/gfx-light-6.asm"         \ (L_REC)
 INCLUDE "build/gfx-light-4.asm"         \ (L_SUN, from G_FRAME and G_HANGAR)
 INCLUDE "build/gfx-frame_cold-frame.asm"  \ (its "Area: ovl S" block, f_slot,
                                        \ in overlay S)
 INCLUDE "build/gfx-flare-frame.asm"    \ (the flare's step in F_FRAME, f_flt; the
 CPU 1                                  \ flare in overlay S)
 INCLUDE "build/gfx-hangar-frame.asm"  \ (streams.py's pass: F_HANG0 is overlay D's)
 INCLUDE "build/gfx-ssun-frame.asm"     \ (S_SUN's resident part, which G_FRAME
 CPU 1                                  \ calls)
\ the resident parts of overlay S's files (their "Area: frame" blocks)
 INCLUDE "build/p-probe-frame.asm"      \ (the lens flare's probes' resident part)
 INCLUDE "build/p-disc-frame.asm"       \ (the disc heap's drop, the surface's cold ends)
 INCLUDE "build/p-poly-frame.asm"       \ (R_POLY's phase A from r_e8)
 CPU 1
 INCLUDE "build/p-kept-frame.asm"       \ (kept solid rows: pk_line, T_KFRAME)
 INCLUDE "build/p-onepass-frame.asm"    \ (R_POLY in one pass: oo_scan, the 16-bit edges)
 INCLUDE "src/gfx-finit.asm"            \ (F_INIT, run once before the first frame;
                                        \ the frame layer's state is in the
                                        \ shared workspace, p-ws.asm)
.PRES_CODE_END

\ The log tables and the quarter-square tables, page aligned (the game's
\ blocks tagged "Tube: bothb, aligned": log, logL, alogh, then QSL and QSH,
\ elite-qs.asm), the last of what is always resident: they end where the
\ overlay region starts, a page, so that neither they nor the code before
\ them is padded. The room between the code and them is the resident
\ code's one gap. The quarter squares are made by the boot (p_boot), not
\ loaded: the image (PCODE) runs from CODE% to the end of p_load, the
\ image's first step, in QSL's place (the "Area: load" pass), then goes on
\ with the overlay region, which p_load moves up into place
 ORG (P% + 255) AND &FF00
.TAB_START
 INCLUDE "build/elite-source-aligned.asm"
.TAB_END
.PRES_END                \ (the end of what is always resident)
 ASSERT LO(TAB_END) = 0 AND QSH + 512 = TAB_END AND QSL + 512 = QSH
 CLEAR QSL, QSH          \ (the quarter squares are SKIPs: nothing there to keep)
 ORG QSL
.PLOAD_START
 INCLUDE "build/p-io-load.asm"          \ (p_load)
.PLOAD_END
 ASSERT PLOAD_END <= QSH  \ (and the move: up by more than a page, less than four)
 ORG TAB_END

\ The overlay region (p-ovl.asm): from OVL_START, page aligned, to RING. The
\ parasite's image holds overlay D there (the cold area: the direct-mode
\ blocks tagged "Tube: ovl D", then the extended tokens); the host keeps its
\ image (HOVD), whole pages
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

 PRINT "Parasite: code &", ~CODE%, "-&", ~PRES_CODE_END-1, ", frame layer &", ~PF_START, "-&", ~PRES_CODE_END-1, " (", PRES_CODE_END-PF_START, " bytes); the aligned tables &", ~TAB_START, "-&", ~TAB_END-1, "; free between: ", TAB_START-PRES_CODE_END
 PRINT "Parasite: overlay region &", ~OVL_START, "-&", ~RING-1, " (", RING-OVL_START, " bytes), overlay D to &", ~OVL_D_END-1, " (", OVL_D_END-OVL_START, " bytes), free to the ring: ", RING-OVL_D_END
 ASSERT PCODE_END <= RING AND RING + &400 = &FE00   \ (the ring's four pages, below the top pages)
 ASSERT ZPSAVE + &90 >= (OVL_D_END + 255) AND &FF00 AND ZPSAVE + &100 <= RING   \ (getzp's buffer: above
                        \ overlay D's pages, which a load of D rewrites; elite-source.asm)
 SAVE "build/PCODE.bin", CODE%, PCODE_END, S%   \ (tube/build.sh leaves out what
                        \ follows p_load to OVL_START and appends the boot's staging)
 SAVE "build/HOVD.bin", OVL_START, (OVL_D_END + 255) AND &FF00

\ Overlay S, the space-mode overlay (the "Area: ovl S" passes): the
\ rasteriser (p-rast.asm: its state first, then its code), the lens flare
\ and the planet's surface (the circle engine, gfx-merid.asm, and its
\ styles, gfx-planet7.asm), from OVL_START (p-ovl.asm). The
\ host keeps its image (HOVS)
 IF MEASURE             \ (tube/build.sh MEASURE=1: sizes only, no usable image)
  CLEAR OVL_START, &FFFF
 ELSE
  CLEAR OVL_START, RING
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
 ORG RING
.OVL_END                \ (the overlay region's end: the ring, for the tools)

\ The top pages, round the Tube's registers (&FEF0-&FEFF) and the vectors:
\ the client OS's until the boot (p_boot) copies them in from the staging
\ area. The page at &FE00 (the "Area: page FE" passes): pirq's unrolled
\ sends (pbl, within the page) and p_crash; the page at &FF00 ("Area: page
\ FF"): pirq, the ring's doorbell (p-io.asm), then the vectors (&FFFA-&FFFF):
\ NMI an RTI (the host never writes register 3 again), RESET p_start, IRQ
\ and BRK pirq (a BRK goes on to p_crash)
 ORG &FE00
.PFE_START
 INCLUDE "build/p-io-fe.asm"            \ (pbl, p_crash, p_nmi)
.PFE_END
 PRINT "Parasite: the page at &FE00 to &", ~PFE_END-1, ", free to &FEF0: ", &FEF0-PFE_END
 ASSERT PFE_END <= &FEF0
 CLEAR &FF00, &10000       \ (and its guard, elite-source-run.asm's &FEF0)
 ORG &FF00
.PFF_START
 INCLUDE "build/p-io-ff.asm"            \ (pirq)
.PFF_END
 PRINT "Parasite: the page at &FF00 to &", ~PFF_END-1, ", free to &FFFA: ", &FFFA-PFF_END
 ASSERT PFF_END <= &FFFA
 ORG &FFFA
 EQUW p_nmi, p_start, pirq

 CLEAR OVL_D_END, RING
 ORG OVL_D_END

\ The boot's staging area, above overlay D (S and the next C_OVLGET of D
\ overwrite it; tube/build.sh appends it to PCODE): p_start and p_boot (the
\ "Area: boot" pass, p-io.asm), then the images p_boot copies in over the
\ client OS: the two top pages

 INCLUDE "build/p-io-boot.asm"          \ (p_start, p_boot)
.PSTG_FE
 COPYBLOCK &FE00, &FEF0, P%
 ORG PSTG_FE + &F0
.PSTG_FF
 COPYBLOCK &FF00, &FFFF, P%
 ORG PSTG_FF + &FF
 EQUB HI(pirq)          \ (&FFFF: COPYBLOCK's end is 16-bit)
.PSTG_END
 PRINT "Parasite: the boot's staging &", ~OVL_D_END, "-&", ~PSTG_END-1, ", free to the ring: ", RING-PSTG_END
 ASSERT PSTG_END <= RING OR MEASURE
 SAVE "build/PSTAGE.bin", OVL_D_END, PSTG_END
