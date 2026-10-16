\ QMUL src, dst, mul: A = src * mul (8-bit by 8-bit, by quarter squares),
\ the low byte in dst; X, Y clobbered
MACRO QMUL src, dst, mul
 LDA src                \ Y = |src - mul|
 SEC
 SBC mul
 BCS d
 EOR #&FF
 ADC #1
.d
 TAY
 LDA src                \ X = src + mul, C = bit 8
 CLC
 ADC mul
 TAX
 BCS h
 LDA QSL,X
 SEC
 SBC QSL,Y
 STA dst
 LDA QSH,X
 SBC QSH,Y
 BRA e
.h
 LDA QSL+256,X
 SEC
 SBC QSL,Y
 STA dst
 LDA QSH+256,X
 SBC QSH,Y
.e
ENDMACRO

.MU5
 STA K
 STA K+1
 STA K+2
 STA K+3
 CLC
 RTS

.MULT3
 STA R
 AND #%01111111
 STA K+2
 LDA Q
 AND #%01111111
 BEQ MU5
 STA T                  \ (T = |Q| for now)
 PHY
 QMUL K+2, K+2, T         \ (K+3 K+2) = |A| * |Q|
 STA K+3
 QMUL P+1, K+1, T         \ (A K+1) = P+1 * |Q|, added in at K+2
 CLC
 ADC K+2
 STA K+2
 BCC m1
 INC K+3
.m1
 QMUL P, K, T             \ (A K) = P * |Q|, added in at K+1
 CLC
 ADC K+1
 STA K+1
 LDA K+2
 ADC #0
 STA K+2
 LDA K+3
 ADC #0
 STA T                  \ T = the result's high byte, as the original
 LDX #0
 PLY
 CLC
 LDA R
 EOR Q
 AND #%10000000
 ORA T
 STA K+3
 RTS

 STX Q
.MLTU2
 PHY
 STA P+1                \ (A P+1 P) = Q * (A ~P)
 LDA P
 EOR #&FF
 STA P
 QMUL P, P, Q             \ (A P) = ~P * Q
 PHA
 QMUL P+1, P+1, Q         \ (A P+1) = A * Q
 TAX
 PLA
 CLC
 ADC P+1
 STA P+1
 TXA
 ADC #0
 LDX #0
 PLY
 CLC
 RTS
