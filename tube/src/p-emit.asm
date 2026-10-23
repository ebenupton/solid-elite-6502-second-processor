\ ******************************************************************************
\
\ p-emit.asm - the polygons' spans to the host as they are made (the dumb
\ host, docs/TUBE-MAP.md)
\
\ R_POLY's rows reach the host one at a time, so that the host fills each
\ row while the parasite works out the next: the two-phase path's tables
\ (p_spans, p-rast.asm; the one-pass generator, gfx-raster_onepass.asm, when
\ OPTUBE is set) hand each row with pixels to p_emit, which sends it in a
\ C_SPANS stream: the opcode, the four colours and the first row with the
\ first span, then each next row's left and right (exclusive), rows with no
\ pixels as (1, 1), and &FF at the end (p_spend), but for a polygon down to
\ row 191, where the host stops. p_emit also extends this buffer's dirty
\ extent by the row's span (and p_spend the dirty rows by the stream's rows),
\ as phase B did. In K mode each row goes through the kept rows' pass first
\ (pem_k, p-kept.asm).
\
\ ******************************************************************************

\ p_emit: Y = row, X = left (the first pixel), A = right + 1 (exclusive, > X).
\ Rows come in increasing order. Keeps Y

.p_emit
 BIT op_st              \ bit 6: the stream has begun; bit 7: K mode
 BVC pem_first
 BMI pem_kj
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
 INY
 STY op_ny
 DEY
.pem_dirty              \ the row's dirty extent: X .. A - 1
 DEC A
 CMP (pr_dr),Y
 BCC pem1
 STA (pr_dr),Y
.pem1
 TXA
 CMP (pr_dl),Y
 BCS pem2
 STA (pr_dl),Y
.pem2
 RTS
.pem_gap
 JSR pem_gaps
 BRA pem_send
.pem_first              \ the polygon's first row: the stream's head
 JSR pem_head
 BIT op_st
 BPL pem_send
.pem_kj
 JMP pem_k              \ (p-kept.asm)

\ pem_raw: as p_emit, but the dirty extent is left alone (the kept rows' pass
\ sets it)

.pem_raw
 BIT op_st
 BVS pemr1
 JSR pem_head
.pemr1
 CPY op_ny
 BEQ pemr2
 JSR pem_gaps
.pemr2
 BIT PR1S
 BVC pemr2
 STX PR1D
.pemr3
 BIT PR1S
 BVC pemr3
 STA PR1D
 INY
 STY op_ny
 DEY
 RTS

\ pem_gaps: rows op_ny .. Y - 1 had no pixels: (1, 1) each (keeps A, X, Y)

.pem_gaps
 PHA
 LDA #1
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
 RTS

\ pem_head: the stream's head at row Y: C_SPANS, the four colours, the row
\ (keeps A, X, Y)

.pem_head
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
 STY op_yl
 LDA #&40
 BIT KMODE              \ (K mode: the kept rows' pass for each row, with the
 BPL pemh1              \ colours by row)
 LDA R_COLE
 STA pk_col
 LDA R_COLO
 STA pk_col+1
 LDA R_COL2
 STA pk_col+2
 LDA R_COL3
 STA pk_col+3
 LDA #&C0
.pemh1
 STA op_st
 PLA
 RTS

\ p_spend: the polygon is done: the stream's end, if it has begun, and this
\ buffer's dirty rows; then the kept rows' deferred black pieces, if any

.p_spend
 BIT op_st
 BVC psd9
 LDA op_ny              \ the end mark (but after row 191: the host stops there)
 CMP #192
 BEQ psd0
 LDA #&FF
 JSR ptx
.psd0
 STZ op_st
 LDX r_buf
 LDA op_y0
 CMP r_dyt,X
 BCS psd1
 STA r_dyt,X
.psd1
 LDA op_ny              \ (the last row sent, or in K mode the last row seen if
 CMP op_y0              \ later, or if nothing was sent: a kept row may be sent
 BEQ psd2               \ nothing, but its dirty extent stays)
 DEC A
 CMP op_yl
 BCS psd3
.psd2
 LDA op_yl
.psd3
 CMP r_dyb,X
 BCC psd9
 STA r_dyb,X
.psd9
 JMP pk_zsend           \ (p-kept.asm)

.op_st EQUB 0           \ bit 6: a stream has begun; bit 7: K mode in it
.op_ny EQUB 0           \ the next row the host's stream expects
.op_y0 EQUB 0           \ the stream's first row
.op_yl EQUB 0           \ (K mode) the last row seen (pem_k)
