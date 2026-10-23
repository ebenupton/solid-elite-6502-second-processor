\ p-dash2.asm - p-dash.asm's second part, in the parasite's high area
\ (p-layout.asm's PHIGH): never used during a disc command

\ MSBAR: missile indicator X (1-4) in colour Y (C_PMSBAR); returns as the
\ Master port's: X kept, Y = 0, T = X * 16, A = %00001001, C clear

.MSBAR
 LDA #C_PMSBAR
 JSR ptx
 TXA
 JSR ptx
 ASL A
 ASL A
 ASL A
 ASL A
 STA T
 TYA
 JSR ptx
 LDY #0
 LDA #%00001001
 CLC
 RTS

\ ECBLB2: the E.C.M. on (ECMA = 32) and its bulb; ECBLB, SPBLB: EOR the E.C.M.
\ or space station bulb (C_PBULB 0 or 1); they return as the Master port's: A
\ = %00001001, X kept, Y = &FF, C kept

.ECBLB2
 LDA #32
 STA ECMA

.ECBLB
 LDA #0
 BEQ pbl1

.SPBLB
 LDA #1
.pbl1
 PHA
 LDA #C_PBULB
 JSR ptx
 PLA
 JSR ptx
 LDY #&FF
 LDA #%00001001
 RTS
