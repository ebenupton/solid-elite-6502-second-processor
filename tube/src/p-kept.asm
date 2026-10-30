\ ******************************************************************************
\
\ p-kept.asm - kept solid rows on the parasite (the Master port's
\ gfx-raster_kept.asm and gfx-kept7.asm, SOLIDSPAN-REPORT.md), for the dumb
\ host: the bookkeeping is all here, and the host only receives fewer spans
\
\ A row of a buffer is kept when the last thing drawn on it in that buffer's
\ frame was one polygon span covering the row's whole dirty extent, at least
\ KT whole bytes, not black: the row then holds that span and nothing else,
\ in one byte value v. On the buffer's next frame the repair leaves a kept
\ row as it is, pending (its old extent still in DIRTY, its R_WL/R_WR as if
\ blacked: pk_row), and the first thing to touch the row settles it: a
\ polygon span (pem_k) sends black for the old pixels outside the new span
\ (after the polygon's stream: pk_zone), and of the new span only what the
\ row does not already hold in its colour; anything else (k_kill: lines,
\ dots, spans, R_MARKDIRTY, the text) blacks the old extent first (prep);
\ what is still pending after the ships is blacked then (T_KCOMMIT). The
\ lens flare, a buffer's reset and R_INIT forget every kept row (k_clear).
\ Only in K mode (KMODE bit 7, T_KFRAME: a space station recorded close by).
\
\ The Master port keeps a byte of flags a row and reads v from the screen.
\ Here the screen is the host's, and the state lives in the buffer's disc
\ span arrays, which a kept row does not use: a row that is no disc row of
\ the buffer has R_DISCL = 255 (an empty span; a disc span starts at CL or
\ later, so never at 0) and R_DISCR = 0. So: kept, R_DISCL 255 and R_DISCR
\ v (never 0: black is never kept); pending, R_DISCL 0 and R_DISCR v. Every
\ way out of those puts back 255 and 0, and so does pk_band for the disc
\ layer's band before it reads the rows as the old disc spans (while any row
\ may be kept: KANY, with the arrays in overlay S's saved state).
\
\ ******************************************************************************

KT = 8                  \ the least interior (whole bytes) a kept row must have

\ k_clear: forget every kept row of both buffers (K mode starting or ending,
\ a buffer's reset, the lens flare, R_INIT). Keeps X

.k_clear
 BIT KANY
 BPL kcl9
 STZ KANY
 LDY #191
.kcl1
 LDA R_DISCL0,Y         \ (a disc row's span stays)
 BEQ kcl2
 CMP #255
 BNE kcl3
.kcl2
 LDA #255
 STA R_DISCL0,Y
 LDA #0
 STA R_DISCR0,Y
.kcl3
 LDA R_DISCL1,Y
 BEQ kcl4
 CMP #255
 BNE kcl5
.kcl4
 LDA #255
 STA R_DISCL1,Y
 LDA #0
 STA R_DISCR1,Y
.kcl5
 DEY
 CPY #&FF
 BNE kcl1
.kcl9
 RTS

\ pk_y: (R_SPAN, R_MARKDIRTY) in K mode, row Y: settled if pending, and not
\ kept. Keeps A, X, Y. k_kill: rows A .. X (A <= X, both in 0..191): a
\ pending row's old extent is blacked (prep, as the repair would have), then
\ the rows are not kept. Keeps nothing

.pk_y
 BIT KMODE
 BPL pky9
 PHA
 PHX
 PHY
 TYA
 TAX
 JSR k_kill
 PLY
 PLX
 PLA
.pky9
 RTS

.k_kill
 STX pk_t
 TAY
.kk1
 LDA (pr_sl),Y
 BEQ kk2                \ pending: its old extent blacked first
 CMP #255
 BNE kk3                \ (a disc row)
 LDA (pr_sr),Y
 BEQ kk3
 BNE kk4
.kk2
 JSR prep               \ (keeps Y)
 LDA #255
 STA (pr_sl),Y
.kk4
 LDA #0
 STA (pr_sr),Y
.kk3
 CPY pk_t
 INY
 BCC kk1
 RTS

\ T_KROWS: (the text, f_glyph) rows A .. X are drawn on: not kept. Keeps Y

.T_KROWS
 BIT KMODE
 BPL pky9
 PHY
 JSR k_kill
 PLY
 RTS

\ T_KCOMMIT: after the ships, in K mode: the rows still pending blacked

.T_KCOMMIT
 BIT KMODE
 BPL kc9
 LDY KPLO
 CPY KPHI
 BEQ kc1
 BCS kc8
.kc1
 LDA (pr_sl),Y
 BNE kc2
 JSR prep               \ (keeps Y)
 LDA #255
 STA (pr_sl),Y
 LDA #0
 STA (pr_sr),Y
.kc2
 CPY KPHI
 INY
 BCC kc1
.kc8
 LDA #&FF
 STA KPLO
 STZ KPHI
.kc9
 RTS

\ pk_row: (the repair, R_DISCROWS, in K mode) row Y is dirty and no disc row:
\ if it is kept, it is left as it is, pending, its R_WL/R_WR as if blacked;
\ else the repair blacks it (prep). Keeps Y

.pk_row
 LDA (pr_sr),Y          \ (R_DISCL is 255: no disc row)
 BNE pkr1
 JMP prep
.pkr1
 LDA #0                 \ pending
 STA (pr_sl),Y
 INC KREC               \ (counted for T_KFRAME)
 LDA (pr_dr),Y          \ R_WL, R_WR as prep would set them
 ORA #3
 STA R_WR,Y
 LDA (pr_dl),Y
 AND #&FC
 STA R_WL,Y
 CPY KPLO
 BCS pkr2
 STY KPLO
.pkr2
 CPY KPHI
 BCC pkr3
 STY KPHI
.pkr3
 JMP prw                \ (the frame's written rows)

\ pk_band: (R_DISCROWS, while a row may be kept: KANY) the disc layer's band,
\ rows r_bt..r_bb, holds no kept rows (the disc rows repaint them), and their
\ R_DISCR is 0 again before the disc layer reads them as the old disc spans

.pk_band
 LDY r_bt
.pkb1
 CPY r_bb
 BEQ pkb2
 BCS pkb9
.pkb2
 LDA (pr_sl),Y
 CMP #255
 BNE pkb3
 LDA #0
 STA (pr_sr),Y
.pkb3
 INY
 BNE pkb1
.pkb9
 RTS

\ pem_k: p_emit in K mode (p-emit.asm): Y = row, X = left, A = right + 1. A
\ pending row is settled; any other row is kept if the span covers its dirty
\ extent (and is wide enough, in a colour that is not black, on a row that
\ is no disc row), else not. Keeps Y

.pem_k
 STA pk_r
 STX pk_l
 STY op_yl              \ (the stream's last row seen: p_spend's dirty rows)
 TYA                    \ w: this row's colour byte
 AND #3
 TAX
 LDA pk_col,X           \ (R_COLE, R_COLO, R_COL2, R_COL3: pem_head)
 STA pk_w
 LDA (pr_sl),Y
 BEQ pks                \ pending
 LDA pk_l               \ does it cover the dirty extent?
 CMP (pr_dl),Y
 BEQ pk1
 BCS pkf                \ XL > DL
.pk1
 LDA pk_r
 DEC A
 CMP (pr_dr),Y
 BCC pkf                \ XR < DR
 SBC pk_l               \ (C = 1) wide enough?
 CMP #4 * KT + 7
 BCC pkf
 JSR pk_keep
.pkg
 LDX pk_l
 LDA pk_r
 JMP pem_go
.pkf
 LDA (pr_sl),Y          \ not kept (a disc row's span stays)
 CMP #255
 BNE pkg
 LDA #0
 STA (pr_sr),Y
 BRA pkg

\ pk_keep: row Y is kept in colour pk_w (unless black, or a disc row). Keeps
\ Y
.pk_keep
 LDA (pr_sl),Y
 CMP #255
 BNE pkk9
 LDA pk_w
 STA (pr_sr),Y          \ v (black: 0, not kept)
 BEQ pkk9
 LDA #&80
 STA KANY
.pkk9
 RTS

\ pks: settle pending row Y: it holds the old span DL..DR in v (its R_DISCR)
\ and nothing else, and is to hold the new one XL..XR (pk_l, pk_r - 1) in
\ pk_w
.pks
 LDA #255               \ (no longer pending)
 STA (pr_sl),Y
 LDA pk_r
 DEC A
 STA pk_x
 LDA (pr_dl),Y          \ the same span in the same colour (the station held
 CMP pk_l               \ still): nothing to send, and the row stays kept
 BNE pks1
 LDA (pr_dr),Y
 CMP pk_x
 BNE pks1
 LDA pk_w
 CMP (pr_sr),Y
 BNE pks1
 RTS
.pks1
 LDA (pr_dl),Y          \ black: the old span's pixels left of the new one
 CMP pk_l
 BCS pks2
 STA pk_a
 LDA pk_l
 DEC A
 CMP (pr_dr),Y
 BCC P%+4
 LDA (pr_dr),Y
 JSR pk_zone
.pks2
 LDA pk_x               \ and right of it
 CMP (pr_dr),Y
 BCS pks3
 INC A
 CMP (pr_dl),Y
 BCS P%+4
 LDA (pr_dl),Y
 STA pk_a
 LDA (pr_dr),Y
 JSR pk_zone
.pks3
 LDX pk_l               \ what to send: in the same colour, only the new
 LDA pk_r               \ span's pixels outside the old one (one side, or the
 STA pk_b               \ whole span if both)
 LDA pk_w
 CMP (pr_sr),Y
 BNE pks6
 LDA pk_l
 CMP (pr_dl),Y
 BCC pks4               \ grows left
 LDA (pr_dr),Y          \ not left: right only (DR + 1 .. XR), or nothing
 CMP pk_x
 BCS pks7
 INC A
 TAX
 BRA pks6
.pks4
 LDA (pr_dr),Y          \ left: and right too? then all of it
 CMP pk_x
 BCC pks6
 LDA (pr_dl),Y          \ left only: XL .. min(DL - 1, XR)
 CMP pk_r
 BCS pks6
 STA pk_b
.pks6
 LDA pk_b
 JSR pem_raw
.pks7
 LDA pk_l               \ the dirty extent is the new span's
 STA (pr_dl),Y
 LDA pk_x
 STA (pr_dr),Y
 LDA #0                 \ settled; kept if wide enough
 STA (pr_sr),Y
 LDA pk_x
 SEC
 SBC pk_l
 CMP #4 * KT + 7
 BCC pks9
 JMP pk_keep
.pks9
 RTS

\ pk_zone: black pk_a .. A on row Y, after the polygon's stream (the zone's
\ pixels are none of the new span's). Keeps Y
.pk_zone
 LDX pk_zn
 CPX #PKZMAX - 3
 BCC pkz1
 PHA                    \ (full: the stream so far ended, the pieces sent; the
 JSR p_spend            \ next row begins another stream)
 PLA
 LDX pk_zn
.pkz1
 STA PKZB+2,X
 LDA pk_a
 STA PKZB+1,X
 TYA
 STA PKZB,X
 INX
 INX
 INX
 STX pk_zn
 RTS

\ pk_zsend: (p_spend) the deferred black pieces, as spans. Keeps Y
.pk_zsend
 LDX pk_zn
 BEQ pkz9
 PHY
 STZ pr_ce
 STZ pr_co
 LDX #0
.pkz2
 LDA PKZB,X
 STA pr_y
 LDA PKZB+1,X
 STA pr_a
 LDA PKZB+2,X
 STA pr_b
 JSR pspan              \ (keeps X)
 INX
 INX
 INX
 CPX pk_zn
 BNE pkz2
 STZ pk_zn
 PLY
.pkz9
 RTS

PKZB = R_NDX0           \ the deferred pieces (row, left, right): R_NDX0 is free
PKZMAX = 192            \ while the ships are drawn (the disc layer is done)

.pk_zn EQUB 0           \ (the scratch, pk_t .. pk_b: p-ws.asm)
.pk_col SKIP 4          \ the stream's four colours (pem_head, in K mode)
