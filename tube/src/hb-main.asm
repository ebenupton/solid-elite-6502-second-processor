\ ******************************************************************************
\
\ hb-main.asm - the Model B host's main RAM part, bank F and the stash bank S
\ (docs/TUBE-MAP.md); banks D and P are hb-d.asm, hb-p.asm. NMOS code
\ (build/nmos/: the Master port's sources through tube/tools/nmos.py).
\
\   * main RAM, reclaimed from the MOS while the game runs (hb-ws.asm): the
\     entry points banks D and P call, the trampolines into them, the
\     pre-erase, the renderer's globals, and the per-buffer arrays; saved as
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
 INCLUDE "build/elite-source-ws.asm"
 INCLUDE "tsrc/hb-ws.asm"
 INCLUDE "tsrc/hb-res.asm"
 INCLUDE "tsrc/h-zp.asm"
 INCLUDE "build/hb-rzp.asm"
 CPU 0

 CLEAR &0200, &1100     \ (the game's workspaces' names stay; the host's own
 CLEAR &7E00, &8000     \ use of these places follows)

 ORG RUNP
 GUARD MR_AEND
 INCLUDE "tsrc/hb-res1.asm"
 ASSERT runpj = RUNPJ AND p_rowrepr = P_ROWREPT
 ORG MR_A
 INCLUDE "tsrc/hb-res2.asm"
.MR_A_END
 PRINT "Model B main RAM: &", ~RUNP, "-&", ~MR_A_END-1, " (free ", MR_AEND-MR_A_END, ")"

 ORG GVARS
 GUARD MR_CEND
 INCLUDE "build/nmos/gfx-gvars.asm"
 CPU 0
 ASSERT P% = MR_C
.MR_C_END

 ORG MR_D
 GUARD MR_DEND
 INCLUDE "build/nmos/h-hpe.asm"
 CPU 0
.MR_D_END
 PRINT "Model B &0E00 part: &", ~MR_D, "-&", ~MR_D_END-1, " (free ", MR_DEND-MR_D_END, ")"

 ORG MR_E
 GUARD MR_EEND
 INCLUDE "tsrc/hb-res3.asm"
.MR_E_END
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
 INCLUDE "build/nmos/gfx-lowhooks.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-frame.asm"
 CPU 0
 INCLUDE "build/nmos/gfx-frame_cold.asm"
 CPU 0
.F_CODE_END
.F_HW   SKIP 256        \ (f_enter's buffer)
.F_HW2  SKIP 256
.F_TM   SKIP 768
.F_ST   SKIP 768
ASSERT F_ST = F_TM + &300
.F_TMR  SKIP 24
.F_SHR0 SKIP 24
.F_SHR1 SKIP 24
.F_DSX  SKIP NDSTAR
.F_DSY  SKIP NDSTAR
.f_hwr  EQUB 0
.f_hw2r EQUB 0
ALIGN &100
.HSW                    \ the parasite's &F800-&FEEF that is not in it (h_swap)
 INCBIN "build/PHIGH.bin"
 SKIP HSW + &6F0 - P%
.F_END
 PRINT "Model B bank F: &8000-&", ~F_END-1, " (code to &", ~F_CODE_END-1, ")"
 SAVE "build/HBF.bin", &8000, F_END, &8000
