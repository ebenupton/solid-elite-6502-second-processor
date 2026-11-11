\ ******************************************************************************
\
\ hb-res.asm - the Model B host's main-RAM code (docs/TUBE-MAP.md), NMOS,
\ in two parts (hb-layout.asm):
\
\   hb_tramp  hb-res2.asm, after the storage reader at &0F00, in the span
\             kernel's scope (hb-kernel.asm): the trampolines from bank F (the
\             resting bank, where the command loop and its handlers are) into
\             bank P
\   hb_pers   hb-res3.asm, at &7E00 (beyond the panel, which no disc command
\             touches): WRCHV's hwrch, the IRQ's entry and hrw
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
\   hb-res2.asm (hb_tramp), hb-res3.asm (hb_pers)
