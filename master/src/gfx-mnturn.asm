\ ******************************************************************************
\
\ gfx-mnturn.asm - the moon's place kept fixed in space (MN_TURN) and the
\ turn of a vector by our roll and pitch that it uses (ss_turnx: MV40
\ itself), as the Master port's gfx-ssun.asm (where S_SUN, the sun near the
\ planet, shares them; S_SUN is not in this tree). In the Master port's bank
\ 4 (elite-layout.asm), in the Tube's resident image (p-layout.asm): G_FRAME,
\ G_PFHOOK and MOONHIT call MN_TURN, once an iteration
\
\ ******************************************************************************

\ ss_tc: (A ss_w+1 ss_w) sign-magnitude -> ss_w(2 1 0) two's complement (X kept)

.ss_tc
 STA ss_w+2
 ASL A
 BCC sst9
 LSR A
 STA ss_w+2
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

\ ss_turn: D turned by our roll (ALPHA) and pitch (BETA) by MV40 itself, as
\ it turns the planet and the sun (ss_turnx: the vector at ss_d + X, X = 0
\ D, 9 the moon's MN_E):
\   1. K2 = y - alpha * x / 256    2. z = z + beta * K2 / 256
\   3. y = K2 - beta * z / 256     4. x = x + alpha * y / 256
\ The vector goes into INWK's coordinates, sign-magnitude, and MV40 runs
\ with TYPE the sun's (129) and DELTA 0, so that MV45, which it jumps to,
\ moves z by nothing and returns; K2's low byte, which MV40 reads without
\ setting (step 3's carry), is 0. The zero page it uses (ss_zpa: INWK's
\ coordinates, P, Q, R, S, T, K, K2, TYPE and DELTA) is kept and put back,
\ so the game sees none of it.

.ss_turn
 LDX #0
.ss_turnx
 LDA ALPHA
 ORA BETA
 AND #%01111111
 BNE sst0
 RTS                    \ neither: nothing turns
.sst0
 STX ss_o
 LDY #SS_NZP-1          \ keep the zero page MV40 uses
.sst1
 LDX ss_zpa,Y
 LDA 0,X
 STA ss_zs,Y
 DEY
 BPL sst1
 LDX ss_o               \ INWK's coordinates = the vector, sign-magnitude
 LDY #0
.sst2
 LDA ss_d,X
 STA ss_w
 LDA ss_d+1,X
 STA ss_w+1
 LDA ss_d+2,X
 STA ss_w+2
 BPL sst3
 JSR ss_neg
 LDA ss_w+2
 ORA #%10000000
 STA ss_w+2
.sst3
 LDA ss_w
 STA INWK,Y
 LDA ss_w+1
 STA INWK+1,Y
 LDA ss_w+2
 STA INWK+2,Y
 INX
 INX
 INX
 INY
 INY
 INY
 CPY #9
 BNE sst2
 LDA #129               \ the sun (MV45 returns), not moved (DELTA 0)
 STA TYPE
 STZ DELTA
 STZ K2
 JSR MV40
 LDX ss_o               \ the vector = INWK's coordinates, two's complement
 LDY #0
.sst4
 LDA INWK,Y
 STA ss_w
 LDA INWK+1,Y
 STA ss_w+1
 LDA INWK+2,Y
 JSR ss_tc               \ (X and Y kept)
 LDA ss_w
 STA ss_d,X
 LDA ss_w+1
 STA ss_d+1,X
 LDA ss_w+2
 STA ss_d+2,X
 INX
 INX
 INX
 INY
 INY
 INY
 CPY #9
 BNE sst4
 LDY #SS_NZP-1          \ the zero page back
.sst5
 LDX ss_zpa,Y
 LDA ss_zs,Y
 STA 0,X
 DEY
 BPL sst5
 RTS

.ss_zpa                 \ the zero page MV40 (with MULT3, MVT3, MV45 and MVT1)
 EQUB INWK, INWK+1, INWK+2, INWK+3, INWK+4, INWK+5, INWK+6, INWK+7, INWK+8
 EQUB P, P+1, P+2, Q, R, S, T, K, K+1, K+2, K+3, K2, K2+1, K2+2, K2+3
 EQUB TYPE, DELTA
SS_NZP = P% - ss_zpa

\ ******************************************************************************
\
\ MN_TURN: the moon's place, E = moon - planet (MN_E), kept as the Master
\ port's S_SUN keeps D: a vector fixed in space, so turned by our roll and
\ pitch as MV40 turns the planet's position (our own movement moves the
\ planet and the moon alike), once an iteration (the first call with this
\ MCNT: from G_PFHOOK before the planet's detail, from MOONHIT, or from
\ G_FRAME after the iteration). The planet's own orientation is not followed: Elite's TIDY
\ renormalises it with one-byte precision every 16 iterations, which turns
\ its spin axis (nosev - sidev) by up to 3 degrees at a time, so a moon 3
\ to 5.25 radii out on that axis would jump with it.
\
\ In a system with a moon (h = s0_hi EOR s1_hi EOR s2_hi, bits 0-1 = 1), E
\ is made in the first iteration after we arrive (SOLAR) or launch (SOS1),
\ which make the planet with ZINF's orientation: on its spin axis then, w =
\ (nosev - sidev) / sqrt(2) = (-1, 0, -1) / sqrt(2), on the side h bit 4
\ gives (set: -w), D = 3, 3.75, 4.5 or 5.25 radii out (h bits 2-3): E =
\ +/- (c, 0, c), c = D 24576 / sqrt(2) (the planet's radius is 24576 in the
\ coordinates, which E is in, as D); then turned by that iteration's roll
\ and pitch, as the planet's position was. It is forgotten (MN_OK clear) in
\ witchspace, with no planet, while we are docked (also F_DIRECT) and when
\ the system changes (QQ2). Only E, MN_OK and its own variables are
\ written (A, X, Y and the flags are not kept).
\
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
.ss_w   SKIP 3
.ss_zs  SKIP SS_NZP     \ the zero page kept round MV40
ENDIF
