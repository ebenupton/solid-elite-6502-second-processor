\ ******************************************************************************
\
\ p-probe.asm - the lens flare's probes on the parasite (overlay S)
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
