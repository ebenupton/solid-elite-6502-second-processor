\ ******************************************************************************
\
\ hb-res.asm - the Model B host's main-RAM code (docs/TUBE-MAP.md), NMOS.
\ hb-main.asm assembles each part in its region (hb-ws.asm):
\
\   hb_fixed  at RUNP: the entry points banks D and P call (runp, p_rowrepr)
\   hb_tramp  the trampolines from bank F (the resting bank, where the command
\             loop and its handlers are) into banks D and P
\   hb_pers   at MR_E (&7E00-&7FFF, beyond the panel, which no disc command
\             touches): WRCHV's hwrch, the IRQ's entry and the exchange of the
\             MOS's main RAM with ours (hbswap)
\
\ ******************************************************************************

MACRO TRAMPOLINE bank, target
 STA tA
 PAGE bank
 LDA tA
 JSR target
 JMP tback
ENDMACRO
MACRO PAGE b            \ page bank b (keeping the MOS's copy in &F4)
 LDA #b
 STA &F4
 STA &FE30
ENDMACRO


\ the parts, which hb-main.asm assembles each in its region:
\   hb-res1.asm (hb_fixed), hb-res2.asm (hb_tramp), hb-res3.asm (hb_pers)
