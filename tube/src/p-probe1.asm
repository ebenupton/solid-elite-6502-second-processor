\ ******************************************************************************
\
\ p-probe1.asm - the lens flare's probes (p-probe.asm): fl_arm's helpers, in
\ the resident code's tail (p-layout.asm)
\
\ ******************************************************************************

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
