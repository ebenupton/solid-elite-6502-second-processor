\ ******************************************************************************
\
\ p-disc0.asm - p-disc.asm's resident part, in the resident code's tail
\ (p-layout.asm): the disc heap's drop, and ps_getn
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

\ ps_getn: ps_on = row Y's old nibble for this buffer, in bits 0-3. Keeps X, Y

.ps_getn
 LDA (hp_n),Y
 BIT ps_msk
 BPL P%+6
 LSR A
 LSR A
 LSR A
 LSR A
 AND #15
 STA ps_on
 RTS
