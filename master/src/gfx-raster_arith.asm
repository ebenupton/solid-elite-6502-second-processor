\ (gfx-raster.asm's polygon arithmetic, its own file so that the Tube's
\ parasite can assemble it for its phase A: tube/src/p-poly.asm)
\ ----------------------------------------------------------------------------
\ The polygon window's arithmetic (R_POLY's phase A, gfx-raster_poly.asm),
\ here for room: r_div8, r_pdiv and the 32-bit multiply and divide with their
\ variables (only r_pdiv uses anything of the polygon window's: it goes back
\ to r_prnz or r_prz)
\ ----------------------------------------------------------------------------
IF _TPART <> 2             \ (the Tube's hosts: the lines' multiply and divide
                          \ only; phase A is the parasite's)
\ r_div8: A / r_v0 -> r_m0 (and X) quotient, A remainder; r_div8b with the
\ dividend in RZ_T6 already.
.r_div8
{
  STA RZ_T6               \ dividend, becoming the quotient
.^r_div8b
  LDA r_v0
  STA RZ_T7
  LDA #0
  LDX #8
.lp
  ASL RZ_T6
  ROL A
  BCS sb
  CMP RZ_T7
  BCC ns
.sb
  SBC RZ_T7
  INC RZ_T6
.ns
  DEX
  BNE lp
  LDX RZ_T6
  STX r_m0
  RTS
}

\ r_pdiv: R_POLY's edges' division (gfx-raster_poly.asm's r_e8, here for
\ ANDY's room): reached by a JMP, it goes back to r_prnz or r_prz.
\ |dx| / dy (|dx| >= dy >= 1) -> X quotient, A remainder (Z set if it is 0).
\ Repeated subtraction when the quotient is small (divisor >= 16).
.r_pdiv
{
  LDX RZ_T1
  CPX #16
  BCC small
  LDX #&FF                \ divisor >= 16: quotient < 16
  SEC
.dl
  INX
  SBC RZ_T1
  BCS dl
  ADC RZ_T1
  BNE drnz
.drz
  JMP r_prz
.long
  LDX RZ_T1
  STX r_v0
  JSR r_div8b             \ (RZ_T6 holds the dividend: past r_div8's STA RZ_T6)
  CMP #0
  BEQ drz
.drnz
  JMP r_prnz
.small
  STA RZ_T6               \ divisor < 16: quotient < 16 unless A >= 16 * d
  TXA
  ASL A
  ASL A
  STA RZ_T7               \ 4d
  ASL A
  ASL A                   \ 16d (< 256)
  CMP RZ_T6
  BEQ long
  BCC long
  LDA RZ_T6
  LDX #&FC
  SEC
.l4
  INX
  INX
  INX
  INX
  SBC RZ_T7
  BCS l4
  ADC RZ_T7
  DEX
.l1
  INX
  SBC RZ_T1
  BCS l1
  ADC RZ_T1
  BEQ drz
  BNE drnz                \ (always)
}
ENDIF
\ the 32-bit multiply and divide
.rp_m0 EQUB 0           \ 32-bit dividend / product; quotient m0,m1
.rp_m1 EQUB 0
.rp_m2 EQUB 0           \ remainder m2,m3
.rp_m3 EQUB 0
.rp_v0 EQUB 0           \ divisor
.rp_v1 EQUB 0
.rp_ma EQUW 0           \ multiplicand
.rp_mb EQUW 0           \ multiplier
.rp_mul16
{
  LDA #0
  STA rp_m2
  STA rp_m3
  LDX #16
.lp
  LSR rp_mb+1
  ROR rp_mb
  BCC ns
  CLC
  LDA rp_m2
  ADC rp_ma
  STA rp_m2
  LDA rp_m3
  ADC rp_ma+1
  STA rp_m3
.ns
  ROR rp_m3
  ROR rp_m2
  ROR rp_m1
  ROR rp_m0
  DEX
  BNE lp
  RTS
}
.rp_div32
{
  LDX #16
.lp
  ASL rp_m0
  ROL rp_m1
  ROL rp_m2
  ROL rp_m3
  BCS sb
  LDA rp_m2
  CMP rp_v0
  LDA rp_m3
  SBC rp_v1
  BCC ns
.sb
  LDA rp_m2
  SBC rp_v0
  STA rp_m2
  LDA rp_m3
  SBC rp_v1
  STA rp_m3
  INC rp_m0
.ns
  DEX
  BNE lp
  RTS
}

