\ ******************************************************************************
\
\ p-disc0.asm - p-disc.asm's resident part, in the resident code's tail
\ (p-layout.asm): the disc heap's drop, and the cold ends of the surface's
\ rows (ps_nd0, ps_whole)
\
\ ******************************************************************************

\ ------------------------------------------------------------------------------
\ hp_drop: both bodies' states dropped (hp_drops): the surface's rows of
\ both buffers unknown (each repaints them whole once: no capacity, so the
\ next fit starts them unknown), and the second disc's old pixels in each
\ buffer repaired as dirty (its box), its rows none and its colour none;
\ kept rows forgotten (their rows then repaired as dirty too)
\ ------------------------------------------------------------------------------

.hp_drop
 INC hp_drops
 BNE P%+5
 INC hp_drops+1
 STZ hb_cap+HB_S
 STZ hb_cap+HB_D
 DEC hp_dfl
 JSR k_clear
 LDX r_buf              \ this buffer's second disc: as dirty, before the
 LDA hq_k               \ disc layer's repair (the surface is being fitted,
 CMP #HB_D              \ R_DISCROWS), or black now (the second disc itself:
 BEQ hpd1               \ R_DISCROWS has run)
 JSR hd_box
 BRA hpd2
.hpd1
 JSR pd_black
.hpd2
 LDA r_buf              \ the other buffer's: as dirty
 EOR #1
 TAX
 JMP hd_box

\ ps_nd0: (ps_rows) a one-colour frame's new rows: no boundaries, colour A

.ps_nd0
 LDA R_NDF
 BNE pnd9
 LDX r_nt
.pnd1
 CPX r_nb
 BEQ P%+4
 BCS pnd9
 STZ R_NDN,X
 INX
 BNE pnd1
.pnd9
 RTS

\ ps_whole: (ps_rows, Y = r_bt) no room for the surface: every row of the
\ band repainted whole (ps_gen), nothing kept

.ps_whole
 CPY r_nt
 BCC pwh1
 CPY r_nb
 BEQ P%+4
 BCS pwh1
 JSR ps_spin
 BRA pwh2
.pwh1
 JSR ps_spo
.pwh2
 JSR ps_gen
 JSR ps_fin0
 CPY r_bb
 INY
 BCC ps_whole
 RTS
