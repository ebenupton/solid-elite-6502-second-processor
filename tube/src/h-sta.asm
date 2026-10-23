\ ******************************************************************************
\
\ h-sta.asm - the Master host's STA runs (h-layout.asm, in HAZEL): one run per
\ screen line of the 3D view (192), 64 STA abs (one per byte of the line: the
\ line's byte for column c is &4000 + &200 * (L DIV 8) + (L AND 7) + 8c, the
\ same address in both buffers, main and shadow RAM, ACCCON X choosing) then
\ an RTS, 193 bytes. A run never straddles a bank: lines 0-83 are in bank 4,
\ 84-167 in bank 7 (&8000 on, 84 a bank) and 168-191 in bank 6 from RUN6.
\ They are made at the host's start (s_gen, from hstart), not carried on the
\ disc. The code that enters them (r_spc, phase B; r_rowset sets RZ_PP and
\ s_rbk from the tables here) is in HAZEL with them, so a run's bank can be
\ paged in unconditionally for each span (LDA s_rbk : STA &FE30), with no
\ copy in &F4
\
\ ******************************************************************************

s_opSTA = &8D           \ STA abs (the runs' stores; r_opRTS planted over one)
RUN6 = &9F00            \ (bank 6's runs, after its code: h-layout.asm asserts)

.s_lo                   \ per line: its run's column 1 (r_j's offsets are from
FOR L, 0, 191           \ there), and its bank
 IF L < 84
  EQUB LO(&8000 + 193 * L + 3)
 ELIF L < 168
  EQUB LO(&8000 + 193 * (L - 84) + 3)
 ELSE
  EQUB LO(RUN6 + 193 * (L - 168) + 3)
 ENDIF
NEXT
.s_hi
FOR L, 0, 191
 IF L < 84
  EQUB HI(&8000 + 193 * L + 3)
 ELIF L < 168
  EQUB HI(&8000 + 193 * (L - 84) + 3)
 ELSE
  EQUB HI(RUN6 + 193 * (L - 168) + 3)
 ENDIF
NEXT
.s_bk
FOR L, 0, 191
 IF L < 84
  EQUB 4
 ELIF L < 168
  EQUB 7
 ELSE
  EQUB GFXBANK
 ENDIF
NEXT
ASSERT &8000 + 193 * 84 <= &C000 AND RUN6 + 193 * 24 <= &C000

.s_rbk EQUB 0           \ the row's run's bank (r_rowset)

\ s_gen: make the runs (hstart, once). Returns with bank 6 (GFXBANK) paged

.s_gen
 LDX #0                 \ X = the line
.sg1
 LDA s_bk,X
 STA &FE30
 SEC
 LDA s_lo,X
 SBC #3
 STA RZ_PP
 LDA s_hi,X
 SBC #0
 STA RZ_PP+1
 TXA                    \ the line's byte in column 0
 AND #7
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
 CPY #192
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
\ chooses), each by its run from column 0 (f_b0new, C_CLS). Returns with
\ bank 6 (GFXBANK) paged

.s_clr
 LDX #0
.scl1
 LDA s_bk,X
 STA &FE30
 SEC
 LDA s_lo,X
 SBC #3
 STA scl2+1
 LDA s_hi,X
 SBC #0
 STA scl2+2
 LDA #0
.scl2
 JSR &FFFF              \ (patched: the line's run)
 INX
 CPX #192
 BNE scl1
 LDA #GFXBANK
 STA &FE30
 RTS
