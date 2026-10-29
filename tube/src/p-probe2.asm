\ ******************************************************************************
\
\ p-probe2.asm - the lens flare's probes' resident part (p-probe.asm), in the
\ parasite's page at &FF00: what p_emit and R_DOT reach while the probes are
\ armed, and their disarming
\
\ ******************************************************************************

\ fp_off: not armed (R_FLARE, fl_arm); p_emit's first instruction back

.fp_off
 STZ fp_on
 LDA #&2C               \ (BIT op_st)
 STA p_emit
 LDA #LO(op_st)
 STA p_emit+1
 LDA #HI(op_st)
 STA p_emit+2
 RTS

\ fp_emit: (p_emit's first instruction while armed) polygon row Y, pixels X
\ .. A - 1: each probe on it takes the row's colour; then p_emit's own BIT
\ op_st, whose flags it returns with (keeps A, X, Y)

.fp_emit
 STA fp_r
 STX fp_l
 PHX
 TYA
 AND #3
 TAX
 LDA R_COLE,X           \ (R_COLE, R_COLO: zero page &06, &07)
 CPX #2
 BCC fpe1
 LDA R_COL2-2,X
.fpe1
 STA fp_c
 LDX #8
.fpe2
 TYA
 CMP fp_y,X
 BNE fpe3
 LDA fp_x,X
 CMP fp_l
 BCC fpe3
 CMP fp_r
 BCS fpe3
 LDA fp_c
 STA fp_b,X
.fpe3
 DEX
 BPL fpe2
 PLX
 LDA fp_r
 BIT op_st
 RTS

\ fp_pix: (R_DOT's pdclip while armed) pixel X, Y in R_COLE/R_COLO by the
\ row's parity (keeps X, Y)

.fp_pix
 STX fp_l
 TYA
 LSR A
 LDA R_COLE
 BCC P%+4
 LDA R_COLO
 STA fp_c
 PHX
 LDX #8
.fpp1
 TYA
 CMP fp_y,X
 BNE fpp2
 LDA fp_x,X
 CMP fp_l
 BNE fpp2
 LDA fp_c
 STA fp_b,X
.fpp2
 DEX
 BPL fpp1
 PLX
 RTS

