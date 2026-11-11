\ ******************************************************************************
\
\ hb-main.asm - the Model B host's main RAM part, bank F and the stash bank S
\ (docs/TUBE-MAP.md); banks D and P are hb-d.asm, hb-p.asm. NMOS code
\ (build/nmos/: the Master port's sources through tube/tools/nmos.py).
\
\   * main RAM, reclaimed from the MOS while the game runs (hb-ws.asm): the
\     trampolines into bank P, the renderer's globals and the shared
\     workspace's names the host's code uses; saved as
\     HBS (the stash bank's image: hbswap exchanges it with the MOS's main
\     RAM at the start and either side of each disc command);
\   * &7E00-&7FFF, beyond the panel: hwrch, the IRQ's entry and hbswap,
\     loaded there directly (HBE);
\   * bank F, the resting bank: the command loop and its handlers (h-main.asm,
\     h-cold.asm), the frame layer's host part (the text map and overlay, the
\     sights), the interrupts (hb-irq.asm), and the game's host blocks (CHPR
\     and its font, the sound).
\
\ ******************************************************************************

_TPART = 2
_HOSTB = TRUE
_RBANK = 0

 INCLUDE "tsrc/cmds.asm"
 INCLUDE "build/povl.asm"
 INCLUDE "build/elite-source-ws.asm"
 INCLUDE "tsrc/hb-ws.asm"
 INCLUDE "tsrc/hb-res.asm"
 INCLUDE "tsrc/h-zp.asm"
 INCLUDE "build/hb-rzp.asm"
 CPU 0

 CLEAR &0200, &1100     \ (the game's workspaces' names stay; the host's own
 CLEAR &7E00, &8000     \ use of these places follows)

 ORG MR_A
 GUARD MR_AEND
 INCLUDE "tsrc/hb-res2.asm"
.MR_A_END
 PRINT "Model B main RAM: &", ~MR_A, "-&", ~MR_A_END-1, " (free ", MR_AEND-MR_A_END, ")"

 ORG GVARS
 GUARD &0D00
 INCLUDE "build/nmos/gfx-gvars.asm"
 CPU 0

 ORG MR_D
 GUARD MR_DEND
 INCLUDE "tsrc/hb-ovl.asm"
 CPU 0
.MR_D_END
 PRINT "Model B &0E00 part: ylookup &", ~ylookup, "-&", ~ylookup+&FF, ", then &", ~MR_D, "-&", ~MR_D_END-1, " (free ", MR_DEND-MR_D_END, ")"

 ORG MR_E
 GUARD MR_EEND
 INCLUDE "tsrc/hb-res3.asm"
.MR_E_END
 ASSERT P% <= hrw
 ORG hrw                \ (cmds.asm's hrw, at its fixed place: h-main.asm's
 BIT HR1S               \ Master copy says what it does)
 BMI P%+9
 BVC hrw
 STA HR1D
 BVS hrw
 RTS
 PRINT "Model B &7E00 part: &", ~MR_E, "-&", ~MR_E_END-1, " (free ", MR_EEND-MR_E_END, ")"
 SAVE "build/HBRES1.bin", &0236, &0D00
 SAVE "build/HBRES2.bin", &0E00, &1100
 SAVE "build/HBE.bin", MR_E, &8000

 CLEAR &8000, &C000      \ bank F
 GUARD &C000
 ORG &8000
.F_START
 INCLUDE "build/nmos/h-main.asm"
 CPU 0
 INCLUDE "build/nmos/h-cold.asm"
 CPU 0
 INCLUDE "tsrc/hb-irq.asm"
 INCLUDE "build/nmos/elite-source-host.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-gluehooks.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-frame.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-frame_cold.asm"
 CPU 0
 INCLUDE "build/nmos/h-panel.asm"
 CPU 0
 INCLUDE "build/nmos/h-prim.asm"
 CPU 0
 ALIGN &100              \ (the log tables: page aligned)
 INCLUDE "build/nmos/elite-source-hostb.asm"   \ the dashboard's drawing (p-dash.asm)
 CPU 0
.F_CODE_END
.F_HW   SKIP 256        \ (f_enter's buffer)
.F_HW2  SKIP 256
.F_DSX  SKIP NDSTAR     \ (f_unstar's: C_EORDOT's star)
.F_DSY  SKIP NDSTAR
.F_END
HQQ18 = F_END           \ the recursive tokens (QQ18, as stored) and where each
 INCBIN "build/HQQ18.bin"   \ starts: data that h4body's C_TOKEN sends (in the IRQ,
 INCLUDE "build/htokix.asm" \ with bank F paged)
.F_TEXT_END
 INCLUDE "tsrc/hb-line.asm"      \ (the lines)
.F_LEND
 ASSERT F_LEND <= DASHV_B
 PRINT "Model B bank F: the lines &", ~F_TEXT_END, "-&", ~F_LEND-1, ", free to the dashboard's variables: ", DASHV_B-F_LEND
 PRINT "Model B bank F: &8000-&", ~F_TEXT_END-1, " (code to &", ~F_CODE_END-1, ", the recursive tokens from &", ~F_END, ")"
 SAVE "build/HBF.bin", &8000, F_LEND, &8000
