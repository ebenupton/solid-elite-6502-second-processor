\ ============================================================================
\ raster_hz.asm -- the rasteriser's cross-bank call stubs.  Code: assemble it
\ in HAZEL (&C000-&DFFF) inside the region the loader copies (it must be
\ visible whichever sideways bank is paged).  ~60 bytes.
\
\ The rasteriser lives in two sideways RAM banks: R_BANK_MAIN (5: everything
\ the caller calls) and R_BANK_AUX (7: R_MESH and cold code).  r_call7 is
\ JSRed from bank-5 code with r_hzt7 = a bank-7 address; r_call5 from bank-7
\ code with r_hzt5 = a bank-5 address.  A, X, Y pass through both ways;
\ flags do not.
\ ============================================================================

R_BANK_MAIN = 5
R_BANK_AUX = 7

.r_hzt7 EQUW 0
.r_hzt5 EQUW 0
.r_hza EQUB 0

.r_call7
  STA r_hza
  LDA #R_BANK_AUX
  STA &F4
  STA &FE30
  LDA r_hza
  JSR r_hzj7
  STA r_hza
  LDA #R_BANK_MAIN
  STA &F4
  STA &FE30
  LDA r_hza
  RTS
.r_hzj7
  JMP (r_hzt7)

.r_call5
  STA r_hza
  LDA #R_BANK_MAIN
  STA &F4
  STA &FE30
  LDA r_hza
  JSR r_hzj5
  STA r_hza
  LDA #R_BANK_AUX
  STA &F4
  STA &FE30
  LDA r_hza
  RTS
.r_hzj5
  JMP (r_hzt5)
