\ gfx-raster_stio.asm - the Tube's dumb host: the star records go to the parasite,
\ which keeps them (tube/src/h-prim.asm's h_stars, h_starerase), INCLUDEd
\ with the stars' bank. A record is 4 bytes, sent last array first (r_s0b,
\ r_s0a, r_s0x, r_s0y), for this buffer (R_PRBUF: buffer 1's arrays are buffer
\ 0's + &300)

MACRO RSTX                \ (HTX: the Master host's bank 5 has no room for it)
IF _HOSTB
 HTX
ELSE
 JSR hhtx
ENDIF
ENDMACRO
MACRO RSRX
IF _HOSTB
 HRX
ELSE
 JSR hhrx
ENDIF
ENDMACRO

.r_stout                  \ buffer A's records to the parasite: the count,
  TAX                     \ then the records
  LDA R_PRSCNT,X
  RSTX
  JSR r_stn
.rso1
  CPX RZ_T0
  BCS rso9
  LDY #3
.rso2
  JSR r_stk
.rso3
  LDA &FFFF,X             \ (patched)
  RSTX
  DEY
  BPL rso2
  INX
  BNE rso1
.rso9
  RTS

.r_stin                   \ the parasite's records for this buffer, then
  HRX                     \ R_STARERASE
  LDX R_PRBUF
  STA R_PRSCNT,X
  JSR r_stn
.rsi1
  CPX RZ_T0
  BCS rsi9
  LDY #3
.rsi2
  JSR r_stk
  RSRX
.rsi3
  STA &FFFF,X             \ (patched)
  DEY
  BPL rsi2
  INX
  BNE rsi1
.rsi9
  JMP R_STARERASE

.r_stn                    \ RZ_T0 = A (the count), RZ_T1 = 3 * X (the buffer),
  STA RZ_T0               \ X = 0
  STX RZ_T1
  TXA
  ASL A
  ADC RZ_T1
  STA RZ_T1
  LDX #0
  RTS

.r_stk                    \ array Y of this buffer into both loops' operands
  LDA rst_l,Y             \ (keeps X, Y)
  STA rso3+1
  STA rsi3+1
  LDA rst_h,Y
  CLC
  ADC RZ_T1
  STA rso3+2
  STA rsi3+2
  RTS
.rst_l EQUB LO(r_s0y), LO(r_s0x), LO(r_s0a), LO(r_s0b)
.rst_h EQUB HI(r_s0y), HI(r_s0x), HI(r_s0a), HI(r_s0b)
