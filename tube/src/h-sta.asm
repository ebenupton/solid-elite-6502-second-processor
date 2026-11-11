\ ******************************************************************************
\
\ h-sta.asm - the Master host's STA runs (h-layout.asm, the kernel): one run per
\ screen line of the 3D view (192), an STA abs per byte of the line (the
\ line's byte for column c is &4000 + &200 * (L DIV 8) + (L AND 7) + 8c, the
\ same address in both buffers, main and shadow RAM, ACCCON X choosing) then
\ an RTS.
\ They are made at the host's start (s_gen, from hstart), not carried on the
\ disc. The code that enters them (r_spc, phase B; r_rowset sets RZ_PP and
\ s_rbk from the tables here) is in the kernel with them, main RAM, so a
\ run's bank can be paged in unconditionally for each span (LDA s_rbk : STA
\ &FE30), with no copy in &F4
\
\ ******************************************************************************

s_opSTA = &8D           \ STA abs (the runs' stores; r_opRTS planted over one)
R_ROWS = 192            \ the lines of the 3D view, with a run each

\ Each line's run is at the start of a page of its own: STA abs for columns
\ 1-63 (column 0 is never inside a span: r_spc enters at xl DIV 4 + 1), then
\ an RTS, 190 bytes, so r_j's offsets are the entry and the plant in the page
\ with no sums. The runs are in line order: line L's is page &80 + L MOD 64
\ of bank 4 + L DIV 64, so banks 4, 5 and 6 hold lines 0-63, 64-127 and
\ 128-191. Pages' bytes 192-255 hold overlay pages kept as four 64-byte
\ pieces (h-main.asm's h_ovlget, tube/build.sh)

.s_pg                   \ per line: its run's page, and its bank
FOR L, 0, R_ROWS - 1
 EQUB &80 + L MOD 64
NEXT
.s_bk
FOR L, 0, R_ROWS - 1
 EQUB 4 + L DIV 64
NEXT

\ Phase B steps a row at a time and stops at r_yend, which r_pcbs sets to
\ R_ROWS (gfx-raster_poly.asm), one past the last line, before it reads a
\ row's page and bank here: line R_ROWS would be page &80 of bank 7, a
\ stored page of overlay S. (The last line's run is in bank 6.)
ASSERT 4 + (R_ROWS - 1) DIV 64 = 6

.s_rbk EQUB 0           \ the row's run's bank (r_rowset)

\ The row's bank in, from the kernel (phase B's set-up, r_pcbs, in bank 7,
\ would page itself out): phase B's first row

.s_pbxe
 LDA s_rbk
 STA &FE30
 JMP r_pbx_e
.s_pbxo
 LDA s_rbk
 STA &FE30
 JMP r_pbx_o

\ s_gen: make the runs (hstart, once). Returns with bank 7 (GFXBANK) paged

.s_gen
 LDX #0                 \ X = the line
.sg1
 LDA s_bk,X
 STA &FE30
 STZ RZ_PP
 LDA s_pg,X
 STA RZ_PP+1
 TXA                    \ the line's byte in column 1
 AND #7
 ORA #8
 STA sga
 TXA
 LSR A
 LSR A
 AND #&FE
 ORA #&40
 STA sga+1
 LDY #0
.sg2
 LDA #s_opSTA
 STA (RZ_PP),Y
 INY
 LDA sga
 STA (RZ_PP),Y
 INY
 LDA sga+1
 STA (RZ_PP),Y
 INY
 LDA sga
 CLC
 ADC #8
 STA sga
 BCC P%+5
 INC sga+1
 CPY #189
 BNE sg2
 LDA #r_opRTS
 STA (RZ_PP),Y
 INX
 CPX #R_ROWS
 BNE sg1
 LDA #GFXBANK
 STA &FE30
 RTS
.sga EQUW 0

\ s_clr: lines 0-191 black (the whole of &4000-&6FFF in the buffer ACCCON X
\ chooses): column 0, then the line's run (f_b0new, C_CLS). Returns with
\ bank 7 (GFXBANK) paged

.s_clr
 LDX #0
.scl1
 LDA s_bk,X
 STA &FE30
 LDA s_pg,X
 STA scl2+2
 TXA                    \ column 0, which the run does not store
 AND #7
 STA scl3+1
 TXA
 LSR A
 LSR A
 AND #&FE
 ORA #&40
 STA scl3+2
 LDA #0
.scl3
 STA &FFFF              \ (patched)
.scl2
 JSR &FF00              \ (patched: the line's run)
 INX
 CPX #R_ROWS
 BNE scl1
 LDA #GFXBANK
 STA &FE30
 RTS
