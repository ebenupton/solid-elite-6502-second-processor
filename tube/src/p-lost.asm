\ ******************************************************************************
\
\ p-lost.asm - overlay S's state rebuilt when it was lost in space mode
\ (p-ovl.asm's ovl_need): at the overlay's end, out of the way of its hot
\ code (p-layout.asm)
\
\ ******************************************************************************

\ r_lost: overlay S back in space mode with its state lost (p-ovl.asm: the
\ host keeps none). Nothing is known of what either buffer holds, so each
\ buffer's every row inside the border is dirty from the clip window's left
\ to its right (RL_L .. RL_R, the frames' window: F_FRAME), and it has no
\ disc rows, no second disc and no kept rows: its next frame blacks the
\ play area (prep, or the disc layer's black on the dirty extent less the
\ new span), and the text and the sights, which redraw what that frame
\ writes over, come back over it, the Master port's pixels. The disc heap
\ is empty (the next fit starts the surface's rows unknown, each buffer
\ repainting them whole once), and nothing is written yet (R_WR). The
\ clip window, the stars' relay and the counts are F_FRAME's (resident).
\ Buffer 0 is left the current one, as R_INIT leaves it

RL_L = 2
RL_R = 253

.r_lost
 LDY #191
 LDA #0
.rlo1
 STA R_WR,Y
 DEY
 CPY #&FF
 BNE rlo1
 LDA #&FF
 STA r_wt
 STZ r_wb
 STZ hb_cap+HB_S
 STZ hb_cap+HB_D
 LDA #1
 JSR rlo2
 LDA #0
.rlo2                   \ buffer A: reset (R_RESETBUF), then rows 1-191 dirty
 JSR R_SETBUF
 JSR R_RESETBUF         \ (X = r_buf)
 LDY #191
.rlo3
 LDA #RL_L
 STA (pr_dl),Y
 LDA #RL_R
 STA (pr_dr),Y
 DEY
 BNE rlo3
 LDA #1
 STA r_dyt,X
 LDA #191
 STA r_dyb,X
 RTS
