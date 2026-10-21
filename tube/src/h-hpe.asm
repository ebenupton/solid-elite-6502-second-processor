\ h-hpe.asm - the host's pre-erase (h-main.asm's; the Model B host places it in
\ main RAM itself, hb-main.asm)

\ The pre-erase (phase 5): while the parasite runs an iteration's game, the
\ host blacks the next back buffer's old dirty rows outside its old disc rows
\ (what R_DISCROWS' r7_crep would do at the frame's start: these rows are
\ black whatever the new disc), a few rows at a time between commands, once
\ the flip has hidden the buffer; it starts the frame's R_WL/R_WR as
\ R_DISCROWS would (which then leaves them: hpe_w), and leaves the buffer's
\ dirty row range to the old disc rows. Commands that may draw (any not in
\ hsafe) finish it first, as does C_FB.

.hpe_start
 LDA F_BACK             \ (bank 6's)
 EOR #1
 STA hpe_b
 LDA #RASTBANK
 STA &F4
 STA &FE30
IF _HOSTB
 JSR D_WCLEAR           \ (Model B: bank D's, through its jump table)
ELSE
 JSR r_wclear           \ the frame's R_WL/R_WR (text2 has read the last's)
ENDIF
 LDA #&FF
 STA R_PRWT
 STZ R_PRWB
 LDA #1
 STA hpe_w
IF _HOSTB                 \ (Model B: both banks' operands for the buffer now; the
 LDA hpe_b              \ next frame draws it)
 JSR D_SETBUF
 LDA #RASTPOLY
 STA &F4
 STA &FE30
 LDA hpe_b
 JSR P_SETBUF
 LDA #RASTBANK
 STA &F4
 STA &FE30
ENDIF
 LDX hpe_b
 LDA R_PRDYT,X          \ the dirty rows dyt..dyb, less the old disc rows
 STA hpe_y              \ dst..dsb: dyt..min(dyb, dst-1), max(dyt, dsb+1)..dyb
 LDA R_PRDYB,X
 STA hpe_e2
 CMP hpe_y
 BCS P%+5
 JMP hpa9               \ (no dirty rows)
 LDA R_PRDSB,X
 CMP R_PRDST,X
 BCS hpa2
 LDA hpe_e2             \ no disc rows: one part, and no dirty rows left
 STA hpe_e
 LDA #&FF
 STA hpe_y2
 STA R_PRDYT,X
 STZ R_PRDYB,X
 BRA hpa8
.hpa2
 LDA R_PRDST,X          \ first part: dyt .. min(dyb, dst - 1)
 DEC A
 CMP hpe_e2
 BCC P%+5
 LDA hpe_e2
 STA hpe_e              \ (empty if dst = 0 or dyt >= dst: hpe_e < hpe_y)
 LDA R_PRDST,X
 BEQ hpa3
 CMP hpe_y
 BCS hpa4
.hpa3
 LDA #&FF               \ (empty)
 STA hpe_e
.hpa4
 LDA R_PRDSB,X          \ second part: max(dyt, dsb + 1) .. dyb
 INC A
 BEQ hpa5
 CMP hpe_y
 BCS P%+5
 LDA hpe_y
 CMP hpe_e2
 BEQ hpa6
 BCC hpa6
.hpa5
 LDA #&FF
.hpa6
 STA hpe_y2
 LDA R_PRDST,X          \ the dirty rows left: max(dyt, dst) .. min(dyb, dsb)
 CMP hpe_y
 BCS P%+5
 LDA hpe_y
 STA hpe_t
 LDA R_PRDSB,X
 CMP hpe_e2
 BCC P%+5
 LDA hpe_e2
 CMP hpe_t
 BCS hpa7
 LDA #&FF
 STA R_PRDYT,X
 STZ R_PRDYB,X
 BRA hpa7b
.hpa7
 STA R_PRDYB,X
 LDA hpe_t
 STA R_PRDYT,X
.hpa7b
 LDA hpe_e              \ an empty first part: straight to the second
 CMP #&FF
 BNE hpa8
 JSR hpe_next
 BRA hpa9
.hpa8
 LDA #1
 STA hpe_on
.hpa9
 LDA #GFXBANK
 STA &F4
 STA &FE30
 RTS

.hpe_next               \ on to the second part (hpe_y2 = &FF: none): done?
 LDA hpe_y2
 CMP #&FF
 BEQ hnx9
 STA hpe_y
 LDA hpe_e2
 STA hpe_e
 LDA #&FF
 STA hpe_y2
 LDA #1
 STA hpe_on
 RTS
.hnx9
 STZ hpe_on
 RTS

.hpe_fin                \ finish it (waiting for the flip). Keeps X
 PHX
.hfi1
 JSR hpe_step
 LDA hpe_on
 BNE hfi1
 PLX
 RTS

.hpe_step               \ up to 4 rows (none until the flip)
 LDA GFLIP
 BNE hps9
IF _HOSTB
 LDA #RASTPOLY          \ (Model B: r7_rowrep is bank P's)
ELSE
 LDA #RASTBANK
ENDIF
 STA &F4
 STA &FE30
 LDA R_PRBUF
 PHA
 LDX hpe_b
 STX R_PRBUF
IF _HOSTB = 0
 BEQ hps1
 LDA #4                 \ (buffer 1: shadow RAM)
 TSB &FE34
ENDIF
.hps1
 LDY hpe_y
 CPY R_PRWT             \ (the frame's written rows)
 BCS P%+5
 STY R_PRWT
 TYA                    \ rows Y .. min(Y + 3, e)
 CLC
 ADC #3
 CMP hpe_e
 BCC P%+5
 LDA hpe_e
 CMP R_PRWB
 BCC P%+5
 STA R_PRWB
 INC A
 STA zc_YE
 STA hpe_y
IF _HOSTB
 JSR P_ROWREP
ELSE
 JSR r7_rowrep
ENDIF
 LDA hpe_e
 CMP hpe_y
 BCS hps8
 JSR hpe_next
.hps8
IF _HOSTB = 0
 LDA #4
 TRB &FE34
ENDIF
 PLA
 STA R_PRBUF
 LDA #GFXBANK
 STA &F4
 STA &FE30
.hps9
 RTS

.hpe_on  EQUB 0         \ rows to black
.hpe_arm EQUB 0         \ after the next C_SYNC
IF _HOSTB = 0             \ (Model B: at a fixed address, hb-ws.asm)
.hpe_w   EQUB 0         \ R_DISCROWS: the frame's R_WL/R_WR are started
ENDIF
.hpe_b   EQUB 0         \ the buffer
.hpe_y   EQUB 0         \ the part: next row, last row
.hpe_e   EQUB 0
.hpe_y2  EQUB 0         \ the second part (&FF: none)
.hpe_e2  EQUB 0
.hpe_t   EQUB 0
