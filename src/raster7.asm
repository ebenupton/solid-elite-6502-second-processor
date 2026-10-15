\ ============================================================================
\ raster7.asm -- the rasteriser's second sideways bank (R_BANK_AUX = 7):
\ cold code (R_INIT, R_CLEARALL, R_RESETBUF); room for more.  INCLUDE it at &8000
\ in its own bank, after raster_vars.asm, raster_hz.asm and raster.asm (it
\ uses their symbols).  The caller never calls it directly: raster.asm's
\ entry points page it in through raster_hz.asm's stubs.
\ ============================================================================

ALIGN &100
.r7_start
.r7_xo
FOR x, 0, 255
  EQUB (x * 2) AND &F8
NEXT
.r7_j
FOR x, 0, 255
  EQUB 3 * (x DIV 4)
NEXT
.r7_lm
FOR x, 0, 255
  EQUB ((&F0 >> (x AND 3)) AND &F0) OR (&0F >> (x AND 3))
NEXT
.r7_rm
FOR x, 0, 255
  EQUB ((&F0 << (3 - (x AND 3))) AND &F0) OR ((&0F << (3 - (x AND 3))) AND &0F)
NEXT


\ ============================================================================
\ R_INIT (bank 7 part)
\ ============================================================================
.r7_init
{
  LDA #1
  STA R_CL
  STA R_CT
  LDA #254
  STA R_CR
  LDA #191
  STA R_CB
  LDA #&FF
  STA R_SCOL
  STA R_NDT
  STZ R_NDB
  STZ R_NDF
  STZ R_SN
  STZ R_PN
  LDA #1                  \ R_SETBUF 0 (forcing the patch)
  STA R_PRBUF
  LDX #LO(R_SETBUF)
  STX r_hzt5
  LDX #HI(R_SETBUF)
  STX r_hzt5+1
  LDA #0
  JSR r_call5
  LDY #191
.il
  LDA #&FF
  STA R_DIRTYL0,Y
  STA R_DISCL0,Y
  STA R_DIRTYL1,Y
  STA R_DISCL1,Y
  STA R_WL,Y
  LDA #0
  STA R_DIRTYR0,Y
  STA R_DISCR0,Y
  STA R_DIRTYR1,Y
  STA R_DISCR1,Y
  STA R_WR,Y
  DEY
  CPY #&FF
  BNE il
  LDX #1
.ib
  JSR r7_reset1
  DEX
  BPL ib
  LDA #&FF
  STA R_PRWT
  STZ R_PRWB
  RTS
}

\ r7_reset1: buffer X's scalars (keeps X)
.r7_reset1
  LDA #&FF
  STA R_PRDYT,X
  STA R_PRDST,X
  STZ R_PRDYB,X
  STZ R_PRDSB,X
  STZ R_PRSCNT,X
  STZ R_PRECNT,X
  STZ R_PRBMODE,X
  RTS

\ ============================================================================
\ R_RESETBUF (bank 7 part): the current buffer's state, not the screen
\ ============================================================================
.r7_resetbuf
{
  LDY #191
  LDX R_PRBUF
  BNE b1
.c0
  LDA #&FF
  STA R_DIRTYL0,Y
  STA R_DISCL0,Y
  LDA #0
  STA R_DIRTYR0,Y
  STA R_DISCR0,Y
  DEY
  CPY #&FF
  BNE c0
  BRA done
.b1
  LDA #&FF
  STA R_DIRTYL1,Y
  STA R_DISCL1,Y
  LDA #0
  STA R_DIRTYR1,Y
  STA R_DISCR1,Y
  DEY
  CPY #&FF
  BNE b1
.done
  JMP r7_reset1
}

\ ============================================================================
\ R_CLEARALL (bank 7 part): black the clip window, reset the buffer's state
\ ============================================================================
.r7_clearall
{
  LDX #LO(r_clrrow)       \ each row by bank 5's span code
  STX r_hzt5
  LDX #HI(r_clrrow)
  STX r_hzt5+1
  LDY R_CT
.row
  STY RZ_T0
  JSR r_call5
  LDY RZ_T0
  CPY R_CB
  INY
  BCC row
  JSR r7_resetbuf
  LDY R_CT                \ WL/WR: the whole window was written
.cw
  LDA R_CL
  STA R_WL,Y
  LDA R_CR
  STA R_WR,Y
  CPY R_CB
  INY
  BCC cw
  LDA R_CT
  CMP R_PRWT
  BCS w1
  STA R_PRWT
.w1
  LDA R_CB
  CMP R_PRWB
  BCC w2
  STA R_PRWB
.w2
  RTS
}

.r7_end
PRINT "raster7.asm: ", r7_end - r7_start, " bytes"
