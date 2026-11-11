\ ******************************************************************************
\
\ p-probe.asm - the lens flare's probes on the parasite (overlay S; fl_arm's
\ helpers, and what p_emit and R_DOT reach while the probes are armed,
\ resident: the last block)
\
\ The Master port's R_FLARE (gfx-flare.asm) turns the flare down by how much
\ of the sun is in sight: nine probes of the back buffer as drawn so far,
\ each in sight if its pixel still has the sun's colour. The parasite has no
\ screen, so it works out those nine pixels itself. F_FRAME arms the probes
\ after the discs (fl_arm): R_FLARE, run in arming mode (fp_on bit 7), notes
\ each probe's place (fp_x, fp_y; 255: none, as R_FLARE takes none there)
\ and draws nothing; each pixel starts as the discs have just left it (the
\ layer's span on its row, this buffer's, in front of the second disc's, in
\ their colours; else black: whatever else the buffer held there has been
\ repaired, and a kept row is settled or blacked before the flare), or as
\ the sights left it, if they are in this buffer and nothing written this
\ frame covers the pixel (the sights stay drawn until something is: f_sight2,
\ which draws them after the flare, then leaves them as they are); then,
\ while armed (fp_on bit 6), what F_FRAME draws over a probe before the flare
\ sets its pixel: a polygon's row (p_emit, entered through fp_emit while
\ armed: the row's colour, COLE, COLO, COL2 or COL3 by the row's place in
\ four) and a dot's pixel (R_DOT's pdclip: COLE or COLO by the row's
\ parity). R_FLARE then reads fp_b for each probe where the Master port reads
\ the screen. The lines drawn before the flare (lasers, enemy beams) are not
\ followed: they cover a probe's pixel only by chance, a pixel wide
\
\ ******************************************************************************

\       Area: ovl S

\ fl_arm: (F_FRAME, after f_disc2) the probes armed if f_flt will run the
\ flare (its tests: the sun drawn, the front view, its centre on the screen)

.fl_arm
 JSR fp_off             \ (not armed)
 LDA #255
 LDX #8
.qfa1
 STA fp_y,X
 DEX
 BPL qfa1
 LDA GSUNON
 BEQ pfa0
 LDA VIEW
 ORA F_SUX+1
 ORA F_SUY+1
 BNE pfa0
 LDA F_SUX
 BEQ pfa0
 EOR #&80
 STA fl_dx
 LDA F_SUY
 CMP #192
 BCC pfa00
.pfa0
 RTS
.pfa00
 SBC #95                \ (C = 0: - 96)
 STA fl_dy
 LDA f_sec              \ (FL_BEH as f_flt sets it)
 LSR A
 ROR A
 STA FL_BEH
 LDA #&80               \ arming: R_FLARE notes the probes' places
 STA fp_on
 LDX fsw_d1+2           \ (this buffer's dirty extents' pages, as f_flt)
 LDY fsw_d2+2
 JSR R_FLARE
 LDX #8                 \ each probe's pixel as the discs left it
.fa2
 LDY fp_y,X
 CPY #255
 BEQ fa8
 STZ fp_b,X             \ (black)
 LDA f_sec              \ the second disc: f_disc2's spans (rows R_NDT ..
 BEQ fa4                \ R_NDB)
 CPY R_NDT
 BCC fa4
 CPY R_NDB
 BEQ P%+4
 BCS fa4
 LDA fp_x,X
 CMP R_NDISCL,Y
 BCC fa4
 LDA R_NDISCR,Y
 CMP fp_x,X
 BCC fa4
 LDA f_sec
 JSR fa_col
.fa4
 LDA (pr_sl),Y          \ the layer, in front: this buffer's span (0, 255:
 BEQ fa8                \ none, p-kept.asm)
 CMP #255
 BEQ fa8
 LDA fp_x,X
 CMP (pr_sl),Y
 BCC fa8
 LDA (pr_sr),Y
 CMP fp_x,X
 BCC fa8
 LDA f_lay
 JSR fa_col
.fa8
 JSR fa_sgt             \ (the sights over it, if they are there)
 DEX
 BPL fa2
 LDA #&40               \ armed: what F_FRAME draws next over them noted
 STA fp_on
 LDA #&20               \ p_emit's polygon rows through fp_emit (JSR)
 STA p_emit
 LDA #LO(fp_emit)
 STA p_emit+1
 LDA #HI(fp_emit)
 STA p_emit+2
.fa9
 RTS

\       Area: frame

\ Resident (p-layout.asm, after the frame layer): fl_arm's helpers, and what
\ p_emit and R_DOT reach while the probes are armed, with their disarming

\ fa_col: probe X's pixel (row Y) in disc A's colour (1 the sun, 2 the planet,
\ colour A), by the row's parity (keeps X, Y)

.fa_col
 CMP #1
 BNE fac1
 TYA
 LSR A
 LDA #FC_SUNE
 BCC fac2
 LDA #FC_SUNO
 BRA fac2
.fac1
 TYA
 LSR A
 LDA #FC_PLANE
 BCC fac2
 LDA #FC_PLANO
.fac2
 STA fp_b,X
 RTS

\ fa_sgt: probe X's pixel (row Y) the sights' colour if they are in this
\ buffer, the pixel is on one of their arms (x = SGX or y = SGY, SGIN to
\ SGOUT pixels from the centre: f_sight2) and nothing written this frame
\ covers it (f_wcov, as f_sight2 asks: this frame's written extent on the
\ row, R_WL .. R_WR, or this buffer's dirty extent); else as it was (keeps
\ X, Y). (A row's written extent spans what it holds, so a pixel inside it
\ that the row's writes went round counts as written)

.fa_sgt
 LDA fp_x,X
 PHX
 TAX                    \ (X: the pixel's x)
 CPY #SGY
 BNE fas1
 SBC #SGX-SGY           \ the arms' row: d = x - SGX (C set; x < 32: d one
 BRA fas2               \ less, and far off either way)
.fas1
 CMP #SGX               \ the arms' column: d = y - SGY (C set)
 BNE fas9
 TYA
.fas2
 SBC #SGY
 BPL P%+5
 EOR #&FF
 INC A
 CMP #SGIN              \ |d| in SGIN .. SGOUT: on an arm
 BCC fas9
 CMP #SGOUT+1
 BCS fas9
 TXA
 JSR f_wcov             \ (A = X = x) written over?
 BCS fas9
 LDX F_BACK             \ the sights in this buffer?
 LDA F_SGS,X
 BEQ fas9
 PLX
 LDA F_CPE+FC_SIGHT
 STA fp_b,X
 RTS
.fas9
 PLX
 RTS

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

