\ ******************************************************************************
\
\ p-emit.asm - the polygons' spans to the host as they are made (the dumb
\ host, docs/TUBE-MAP.md)
\
\ R_POLY's rows reach the host one at a time, so that the host fills each
\ row while the parasite works out the next: the one-pass generator
\ (gfx-raster_onepass.asm, R_POLY's 8-bit polygons) and the two-phase path's
\ tables (p_spans, p-rast.asm: 16-bit polygons) both hand each row with
\ pixels to p_emit, which sends it in a C_SPANS stream: the opcode, the four
\ colours and the first row with the first span, then each next row's left
\ and right (exclusive), rows with no pixels as (1, 1), and &FF at the end
\ (p_spend), but for a polygon down to row 191, where the host stops. p_emit also extends this buffer's dirty extent by the row's
\ span (and p_spend the dirty rows by the stream's rows), as phase B did.
\
\ ******************************************************************************

\ p_emit: Y = row, X = left (the first pixel), A = right + 1 (exclusive, > X).
\ Rows come in increasing order. Keeps Y

.p_emit
.pem_b
 BRA pem_first          \ (patched: 0, straight on, once the stream has begun)
.pem_go
 CPY op_ny              \ rows the host has not had (no pixels): empty
 BNE pem_gap
.pem_send
 BIT PR1S               \ left, right (exclusive)
 BVC pem_send
 STX PR1D
.pem_s2
 BIT PR1S
 BVC pem_s2
 STA PR1D
 DEC A                  \ the row's dirty extent: X .. A - 1
 CMP (pr_dr),Y
 BCC pem1
 STA (pr_dr),Y
.pem1
 TXA
 CMP (pr_dl),Y
 BCS pem2
 STA (pr_dl),Y
.pem2
 INY
 STY op_ny
 DEY
 RTS
.pem_gap
 PHA
 LDA #1                 \ (left 1, right 1: no pixels)
.pemg1
 BIT PR1S
 BVC pemg1
 STA PR1D
.pemg2
 BIT PR1S
 BVC pemg2
 STA PR1D
 INC op_ny
 CPY op_ny
 BNE pemg1
 PLA
 BRA pem_send
.pem_first              \ the polygon's first row: the stream's head
 PHA
 LDA #C_SPANS
 JSR ptx
 LDA R_COLE
 JSR ptx
 LDA R_COLO
 JSR ptx
 LDA R_COL2
 JSR ptx
 LDA R_COL3
 JSR ptx
 TYA
 JSR ptx
 STY op_y0
 STY op_ny
 STZ pem_b+1            \ (straight on from now)
 PLA
 BRA pem_send

\ p_spend: the polygon is done: the stream's end, if it has begun, and this
\ buffer's dirty rows

.p_spend
 LDA pem_b+1
 BNE psd9               \ (no rows with pixels: nothing was sent)
 LDA op_ny              \ the end mark (but after row 191: the host stops there)
 CMP #192
 BEQ psd0
 LDA #&FF
 JSR ptx
.psd0
 LDA #pem_first - pem_b - 2
 STA pem_b+1
 LDX r_buf
 LDA op_y0
 CMP r_dyt,X
 BCS psd1
 STA r_dyt,X
.psd1
 LDA op_ny
 DEC A
 CMP r_dyb,X
 BCC psd9
 STA r_dyb,X
.psd9
 RTS

.op_ny EQUB 0           \ the next row the host's stream expects
.op_y0 EQUB 0           \ the stream's first row
