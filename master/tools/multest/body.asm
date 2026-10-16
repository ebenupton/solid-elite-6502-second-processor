\ MULTS: (A P) = |A| * (P AND 31), sign of A; X = T1 = |A| - 1, T = sign, C = 0
.MULTS
 TAX
 AND #%10000000
 STA T
 TXA
 AND #%01111111
 BEQ MU6
 TAX
 DEX
 STX T1
 PHY
 LDA P                  \ b = P AND 31 (the bits the shift-and-add used)
 AND #31
 STA P
 SEC                    \ X = b + |A| (< 256)
 ADC T1
 TAX
 LDA P                  \ Y = |b - |A||
 CLC
 SBC T1
 BCS ms1
 EOR #&FF
 ADC #1
.ms1
 TAY
 LDA QSL,X              \ (A P) = (b + a)^2 / 4 - (b - a)^2 / 4
 SEC
 SBC QSL,Y
 STA P
 LDA QSH,X
 SBC QSH,Y
 LDX T1
 PLY
 CLC
 ORA T
 RTS
.MU6
 STA P+1
 STA P
 RTS

\ MU11: (A P) = P * X (X = 0: P * 256); T = X - 1, X = 0, C = 0
.MU11
 DEX
 STX T
 INX
 BEQ mu0
 PHY
 LDA P                  \ Y = |P - X|
 CLC
 SBC T
 BCS mu1
 EOR #&FF
 ADC #1
.mu1
 TAY
 LDA P                  \ X = P + X (9 bits: C)
 SEC
 ADC T
 TAX
 BCS mu2
 LDA QSL,X
 SEC
 SBC QSL,Y
 STA P
 LDA QSH,X
 SBC QSH,Y
 PLY
 LDX #0
 CLC
 RTS
.mu2
 LDA QSL+256,X
 SEC
 SBC QSL,Y
 STA P
 LDA QSH+256,X
 SBC QSH,Y
 PLY
 LDX #0
 CLC
 RTS
.mu0
 LDA P
 STZ P
 CLC
 RTS

\ MULT1: (A P) = |A| * |Q| (7 bits each), sign of A EOR Q; T = sign; |Q| = 0:
\ A = P = 0, X = A; else X = 0, T1 = |Q| - 1; C = 0
.MULT1
 TAX
 EOR Q
 AND #%10000000
 STA T
 LDA Q
 AND #%01111111
 BEQ mt0
 PHY
 STX P                  \ (the argument A, for now)
 TAX                    \ T1 = |Q| - 1
 DEX
 STX T1
 LDA P                  \ P = |A|
 AND #%01111111
 STA P
 SEC                    \ X = |A| + |Q| (< 256)
 ADC T1
 TAX
 LDA P                  \ Y = ||A| - |Q||
 CLC
 SBC T1
 BCS mt1
 EOR #&FF
 ADC #1
.mt1
 TAY
 LDA QSL,X
 SEC
 SBC QSL,Y
 STA P
 LDA QSH,X
 SBC QSH,Y
 PLY
 LDX #0
 CLC
 ORA T
 RTS
.mt0
 TXA                    \ as the original: C = bit 0 of A, A = P = 0, Z set
 LSR A
 LDA #0
 STA P
 RTS
