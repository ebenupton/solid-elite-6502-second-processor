\ ******************************************************************************
\
\ h-sta.asm - the Master host's STA runs (h-layout.asm, in HAZEL): one run per
\ screen line of the 3D view (192), an STA abs per byte of the line (the
\ line's byte for column c is &4000 + &200 * (L DIV 8) + (L AND 7) + 8c, the
\ same address in both buffers, main and shadow RAM, ACCCON X choosing) then
\ an RTS.
\ They are made at the host's start (s_gen, from hstart), not carried on the
\ disc. The code that enters them (r_spc, phase B; r_rowset sets RZ_PP and
\ s_rbk from the tables here) is in HAZEL with them, so a run's bank can be
\ paged in unconditionally for each span (LDA s_rbk : STA &FE30), with no
\ copy in &F4
\
\ ******************************************************************************

s_opSTA = &8D           \ STA abs (the runs' stores; r_opRTS planted over one)
RUN6 = &9F00            \ (bank 6's runs, after its code: h-layout.asm asserts)

\ Each line's run is at the start of a page of its own: STA abs for columns
\ 1-63 (column 0 is never inside a span: r_spc enters at xl DIV 4 + 1), then
\ an RTS, 190 bytes, so r_j's offsets are the entry and the plant in the page
\ with no sums. Lines 0-63 are in bank 4 and 64-127 in bank 7 (&8000 on),
\ 128-143 in bank 5's &8000-&8FFF, 144-167 in bank 5's 24 pages that held the
\ row runs (r_run0 on: their tails stay after offset 190) and 168-191 in bank
\ 6 from RUN6. Pages' bytes 192-255 in banks 4 and 7 hold overlay S's state
\ (h-main.asm's h_ovlget)

.s_pg                   \ per line: its run's page, and its bank
FOR L, 0, 191
 IF L < 64
  EQUB &80 + L
 ELIF L < 128
  EQUB &80 + L - 64
 ELIF L < 144
  EQUB &80 + L - 128
 ELIF L < 168
  EQUB HI(r_run0) + L - 144
 ELSE
  EQUB HI(RUN6) + L - 168
 ENDIF
NEXT
.s_bk
FOR L, 0, 191
 IF L < 64
  EQUB 4
 ELIF L < 128
  EQUB 7
 ELIF L < 168
  EQUB RASTBANK
 ELSE
  EQUB GFXBANK
 ENDIF
NEXT
ASSERT HI(RUN6) + 24 <= &C0

.s_rbk EQUB 0           \ the row's run's bank (r_rowset)

\ The row's bank in, from HAZEL (the callers in the rasteriser's windows
\ would page themselves out): phase B's first row, and the line code's long
\ spans, which have that window back after

.s_pbxe
 LDA s_rbk
 STA &FE30
 JMP r_pbx_e
.s_pbxo
 LDA s_rbk
 STA &FE30
 JMP r_pbx_o
.s_lspan
 LDA s_rbk
 STA &FE30
 JSR r_spc
 LDA #RASTPOLY
 STA &FE30
 RTS

\ s_gen: make the runs (hstart, once). Returns with bank 6 (GFXBANK) paged

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
 CPX #192
 BNE sg1
 LDA #GFXBANK
 STA &FE30
 RTS
.sga EQUW 0

\ s_clr: lines 0-191 black (the whole of &4000-&6FFF in the buffer ACCCON X
\ chooses): column 0, then the line's run (f_b0new, C_CLS). Returns with
\ bank 6 (GFXBANK) paged

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
 CPX #192
 BNE scl1
 LDA #GFXBANK
 STA &FE30
 RTS
