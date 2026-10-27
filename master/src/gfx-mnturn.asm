\ ******************************************************************************
\
\ gfx-mnturn.asm - the moon's place kept fixed in space (MN_TURN) and the
\ turn of a vector by our roll and pitch that it uses (ss_turnx), from the
\ Master port's gfx-ssun.asm at planetsun 6957750 (where S_SUN, the sun
\ near the planet, shares them; S_SUN is not in this tree). In the Master
\ port's bank 4 (elite-layout.asm), in the Tube's resident image
\ (p-layout.asm): G_FRAME and G_PFHOOK call MN_TURN, once an iteration
\
\ ******************************************************************************

.ss_neg                 \ ss_w(2 1 0) = -ss_w(2 1 0)
 SEC
 LDA #0
 SBC ss_w
 STA ss_w
 LDA #0
 SBC ss_w+1
 STA ss_w+1
 LDA #0
 SBC ss_w+2
 STA ss_w+2
.sst9
 RTS

\ ss_turn, ss_turnx: the vector at ss_d + X (X = 0 D, 9 the moon's MN_E)
\ turned by our roll (ALPHA) and pitch (BETA) as MV40 turns the planet:
\   1. K2 = y - alpha * x / 256    2. z = z + beta * K2 / 256
\   3. y = K2 - beta * z / 256     4. x = x + alpha * y / 256

.ss_turn
 LDX #0
.ss_turnx
 STX ss_o
 LDA ALPHA
 ORA BETA
 AND #%01111111
 BEQ sst9               \ neither: nothing turns
 LDX #0
 LDY #3
 LDA ALPHA
 EOR #%10000000
 JSR ss_stpo            \ y = y - alpha * x / 256 (K2, kept in y)
 LDX #3
 LDY #6
 LDA BETA
 JSR ss_stpo            \ z = z + beta * K2 / 256
 LDX #6
 LDY #3
 LDA BETA
 EOR #%10000000
 JSR ss_stpo            \ y = K2 - beta * z / 256
 LDX #3
 LDY #0
 LDA ALPHA
                        \ x = x + alpha * y / 256: fall through
.ss_stpo                \ (X and Y offset by ss_o)
 PHA
 TXA
 CLC
 ADC ss_o
 TAX
 TYA
 CLC
 ADC ss_o
 TAY
 PLA

\ ss_step: D[Y] += D[X] * A / 256 (A sign-magnitude, D[] 24-bit two's
\ complement)

.ss_step
 STA ss_m
 LDA ss_d,X
 STA ss_w
 LDA ss_d+1,X
 STA ss_w+1
 LDA ss_d+2,X
 STA ss_w+2
 JSR ss_mul
 CLC
 LDA ss_d,Y
 ADC ss_p
 STA ss_d,Y
 LDA ss_d+1,Y
 ADC ss_p+1
 STA ss_d+1,Y
 LDA ss_d+2,Y
 ADC ss_p+2
 STA ss_d+2,Y
 RTS

\ ss_mul: ss_p(2 1 0) = ss_w(2 1 0) * ss_m / 256, ss_w two's complement and
\ ss_m sign-magnitude; the magnitude is truncated, as MULT3's (Y kept)

.ss_mul
 LDA ss_w+2
 EOR ss_m
 AND #%10000000
 STA ss_sg              \ the result's sign
 BIT ss_w+2
 BPL ssm1
 JSR ss_neg             \ |w|
.ssm1
 LDA #0
 STA ss_w+3
 STA ss_a
 STA ss_a+1
 STA ss_a+2
 STA ss_a+3
 LDA ss_m
 AND #%01111111
 STA ss_mm
.ssm2                   \ shift and add, a bit of |m| at a time
 LSR ss_mm
 BCC ssm3
 CLC
 LDA ss_a
 ADC ss_w
 STA ss_a
 LDA ss_a+1
 ADC ss_w+1
 STA ss_a+1
 LDA ss_a+2
 ADC ss_w+2
 STA ss_a+2
 LDA ss_a+3
 ADC ss_w+3
 STA ss_a+3
.ssm3
 LDA ss_mm
 BEQ ssm4
 ASL ss_w
 ROL ss_w+1
 ROL ss_w+2
 ROL ss_w+3
 BRA ssm2
.ssm4
 LDA ss_a+1             \ / 256
 STA ss_p
 LDA ss_a+2
 STA ss_p+1
 LDA ss_a+3
 STA ss_p+2
 BIT ss_sg
 BPL ssm5
 SEC
 LDA #0
 SBC ss_p
 STA ss_p
 LDA #0
 SBC ss_p+1
 STA ss_p+1
 LDA #0
 SBC ss_p+2
 STA ss_p+2
.ssm5
 RTS


\ ******************************************************************************

.mt_off
 STZ MN_OK
.mnt9
 RTS
.MN_TURN
 LDA MCNT               \ once an iteration
 CMP mt_it
 BEQ mnt9
 STA mt_it
 LDA MJ                 \ witchspace, docked, or no planet: none
 ORA QQ12
 BNE mt_off
 LDA FRIN
 BPL mt_off
 LDX #5                 \ another system: forget it
.mnt1
 LDA QQ2,X
 CMP mt_sys,X
 BEQ mnt2
 STA mt_sys,X
 STZ MN_OK
.mnt2
 DEX
 BPL mnt1
 LDA QQ2+1              \ h: a moon?
 EOR QQ2+3
 EOR QQ2+5
 TAY
 AND #3
 CMP #1
 BNE mt_off
 BIT MN_OK
 BMI mnt4
 TYA                    \ made: E = +/- (c, 0, c)
 PHA
 LSR A
 LSR A
 AND #3
 TAY
 LDA mt_cl,Y
 STA ss_w
 LDA mt_cm,Y
 STA ss_w+1
 LDA mt_ch,Y
 STA ss_w+2
 PLA
 AND #16
 BNE P%+5
 JSR ss_neg             \ (h bit 4 clear: w, whose x and z are negative)
 LDX #2
.mnt3
 LDA ss_w,X
 STA MN_E,X
 STA MN_E+6,X
 STZ MN_E+3,X
 DEX
 BPL mnt3
 DEC MN_OK              \ (&FF)
.mnt4
 LDX #9                 \ turned
 JMP ss_turnx

.mt_cl  EQUB 166, 143, 120, 98
.mt_cm  EQUB 203, 254, 49, 100
.mt_ch  EQUB 0, 0, 1, 1

\ Its variables (ss_d, MN_E and MN_OK are in the workspace: gfx-planetv.asm)

IF _TPART <> 1             \ (the Tube's parasite: after WP, p-ws.asm)
.ss_o   SKIP 1          \ ss_turnx's vector
.mt_it  SKIP 1          \ MN_TURN: the MCNT of E's last turn
.mt_sys SKIP 6          \ the system E is of (QQ2)
.ss_w   SKIP 4
.ss_a   SKIP 4
.ss_p   SKIP 3
.ss_m   SKIP 1
.ss_mm  SKIP 1
.ss_sg  SKIP 1
ENDIF
