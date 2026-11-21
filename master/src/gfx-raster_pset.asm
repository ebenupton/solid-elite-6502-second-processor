\ r_pset (gfx-raster.asm's; its own file so that the Tube's Model B host can
\ place it out of run page 15's tail, where its NMOS code does not fit)
.r_pset
  LDA r_lm,X              \ the pixel's mask
  AND r_rm,X
  STA RZ_T6
\ r_psetm: X = x, Y = y (inside the clip window): the pixels of x's byte in
\ the mask RZ_T6 in the colour pair's dither, DIRTY[y] extended by x (r_pdr
\ extends its right end by A: R_DOT's second pixel).  Clobbers A; keeps X, Y
\ and RZ_T6.
.r_psetm
{
  TYA                     \ RZ_PP = screen address of (X, Y)
  AND #7
  ORA r_xo,X
  STA RZ_PP
  TYA
  LSR A
  LSR A
  AND #&FE
IF _HOSTB
  CLC
.^r_bs2
  ADC #&40
ELSE
  ORA #&40
ENDIF
  CPX #&80
  ADC #0
  STA RZ_PP+1
  TYA
  LSR A
  LDA R_COLE
  BCC ev
  LDA R_COLO
.ev
  EOR (RZ_PP)
  AND RZ_T6
  EOR (RZ_PP)
  STA (RZ_PP)
IF _TPART <> 2             \ (the Tube's hosts keep no dirty extents)
  TXA
.^r_pt01 CMP r_dl,Y
  BCS n1
.^r_pt02 STA r_dl,Y
.n1
.^r_pdr
.^r_pt03 CMP r_dr,Y
  BCC n2
.^r_pt04 STA r_dr,Y
.n2
ENDIF
  RTS
}
