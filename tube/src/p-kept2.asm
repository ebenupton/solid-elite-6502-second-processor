\ ******************************************************************************
\
\ p-kept2.asm - kept solid rows (p-kept.asm): pk_line and T_KFRAME, in the high
\ area
\
\ ******************************************************************************

\ pk_line: (R_LINE, in K mode) the rows of the line R_X0,R_Y0 - R_X1,R_Y1,
\ clipped to 0..191, not kept

.pk_line
 LDX #0                 \ the top end: X = 0 (R_Y0) or 4 (R_Y1)
 LDA R_Y0
 CMP R_Y1
 LDA R_Y0+1
 SBC R_Y1+1
 BVC P%+4
 EOR #&80
 BMI pkl1               \ Y0 < Y1
 LDX #4
.pkl1
 LDA R_Y0+1,X           \ top < 0: 0; top > 191: no rows
 BMI pkl2
 BNE pkl9
 LDA R_Y0,X
 CMP #192
 BCS pkl9
 BCC pkl3
.pkl2
 LDA #0
.pkl3
 STA pk_t
 TXA                    \ the other end: bottom >= 192: 191; < 0: no rows
 EOR #4
 TAX
 LDA R_Y0+1,X
 BMI pkl9
 BNE pkl4
 LDA R_Y0,X
 CMP #192
 BCC pkl5
.pkl4
 LDA #191
.pkl5
 TAX
 LDA pk_t
 JMP k_kill
.pkl9
 RTS

KZ = &200               \ K mode: a station recorded with z below KZ (its faces
KRMIN = 16              \ about to fill whole rows), and the last K mode frame
KSKIPN = 4              \ found at least KRMIN kept rows (else it sits out KSKIPN
                        \ frames)

\ T_KFRAME: (from F_FRAME, before T_SETBUF, overlay S in) K mode on if a space
\ station is recorded close by; off otherwise

.T_KFRAME
 LDA SSPR               \ (not in the station's safe zone: no station close)
 BEQ tkf3
 LDX F_NSHIP
.tkf1
 DEX
 BMI tkf3
 LDA F_STYP,X
 CMP #SST
 BEQ tkf2
 CMP #DOD
 BNE tkf1
.tkf2
 LDA F_SZL,X            \ z < KZ (16 bits)
 CMP #LO(KZ)
 LDA F_SZH,X
 SBC #HI(KZ)
 BCS tkf1
 LDA KSKIP              \ (sitting out after a frame that kept too few rows)
 BEQ tkf4
 DEC KSKIP
 BRA tkf3
.tkf4
 BIT KMODE              \ K mode the last two frames: did the last one find
 BPL tkf6               \ enough kept rows (KREC: the repair's pending rows)?
 LDA KON                \ (the third frame's repair is the first to find rows
 CMP #3                 \ the first one kept)
 BCC tkf5
 LDA KREC
 CMP #KRMIN
 BCS tkf7
 LDA #KSKIPN            \ no: off for KSKIPN frames
 STA KSKIP
 BRA tkf3
.tkf6
 STZ KON                \ (K mode starts: no kept rows from before)
 JSR k_clear
.tkf5
 INC KON
.tkf7
 STZ KREC
 LDA #&FF
 STA KPLO
 STZ KPHI
 LDA #&80
 STA KMODE
 RTS
.tkf3
 BIT KMODE              \ K mode ends: the kept rows forgotten
 BPL tkf9
 STZ KMODE
 JMP k_clear
.tkf9
 RTS
