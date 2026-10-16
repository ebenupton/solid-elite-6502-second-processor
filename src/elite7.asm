\ ******************************************************************************
\
\ elite7.asm - cold Elite code moved to sideways RAM bank 7 (after the
\ rasteriser's second bank) to make room in main RAM. Each routine here is
\ reached through a main-RAM stub in elite-source.asm that pages bank 7 in and
\ Elite's bank (ELITEBANK) back out afterwards, so it may only call main-RAM
\ code and read main-RAM, zero page or its own data.
\
\ ******************************************************************************

\ ******************************************************************************
\
\       Name: ARCTAN
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Calculate A = arctan(P / Q)
\  Deep dive: The sine, cosine and arctan tables
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following:
\
\   A = arctan(P / Q)
\
\ In other words, this finds the angle in the right-angled triangle where the
\ opposite side to angle A is length P and the adjacent side to angle A has
\ length Q, so:
\
\   tan(A) = P / Q
\
\ The result in A is an integer representing the angle in radians. The routine
\ returns values in the range 0 to 128, which covers 0 to 180 degrees (or 0 to
\ PI radians).
\
\ ******************************************************************************

.ARCTAN7

 LDA P                  \ Set T1 = P EOR Q, which will have the sign of P * Q
 EOR Q                  \
\AND #%10000000         \ The AND is commented out in the original source
 STA T1

 LDA Q                  \ If Q = 0, jump to AR2 to return a right angle
 BEQ AR2

 ASL A                  \ Set Q = |Q| * 2 (this is a quick way of clearing the
 STA Q                  \ sign bit, and we don't need to shift right again as we
                        \ only ever use this value in the division with |P| * 2,
                        \ which we set next)

 LDA P                  \ Set A = |P| * 2
 ASL A

 CMP Q                  \ If A >= Q, i.e. |P| > |Q|, jump to AR1 to swap P
 BCS AR1                \ and Q around, so we can still use the lookup table

 JSR ARS1               \ Call ARS1 to set the following from the lookup table:
                        \
                        \   A = arctan(A / Q)
                        \     = arctan(|P / Q|)

 SEC                    \ Set the C flag so the SBC instruction in AR3 will be
                        \ correct, should we jump there

.AR4

 LDX T1                 \ If T1 is negative, i.e. P and Q have different signs,
 BMI AR3                \ jump down to AR3 to return arctan(-|P / Q|)

 RTS                    \ Otherwise P and Q have the same sign, so our result is
                        \ correct and we can return from the subroutine

.AR1

                        \ We want to calculate arctan(t) where |t| > 1, so we
                        \ can use the calculation described in the documentation
                        \ for the ACT table, i.e. 64 - arctan(1 / t)

 LDX Q                  \ Swap the values in Q and P, using the fact that we
 STA Q                  \ called AR1 with A = P
 STX P                  \
 TXA                    \ This also sets A = P (which now contains the original
                        \ argument |Q|)

 JSR ARS1               \ Call ARS1 to set the following from the lookup table:
                        \
                        \   A = arctan(A / Q)
                        \     = arctan(|Q / P|)
                        \     = arctan(1 / |P / Q|)

 STA T                  \ Set T = 64 - T
 LDA #64
 SBC T

 BCS AR4                \ Jump to AR4 to continue the calculation (this BCS is
                        \ effectively a JMP as the subtraction will never
                        \ underflow, as ARS1 returns values in the range 0-31)

.AR2

                        \ If we get here then Q = 0, so tan(A) = infinity and
                        \ A is a right angle, or 0.25 of a circle. We allocate
                        \ 255 to a full circle, so we should return 63 for a
                        \ right angle

 LDA #63                \ Set A to 63, to represent a right angle

 RTS                    \ Return from the subroutine

.AR3

                        \ A contains arctan(|P / Q|) but P and Q have different
                        \ signs, so we need to return arctan(-|P / Q|), using
                        \ the calculation described in the documentation for the
                        \ ACT table, i.e. 128 - A

 STA T                  \ Set A = 128 - A
 LDA #128               \
\SEC                    \ The SEC instruction is commented out in the original
 SBC T                  \ source, and isn't required as we did a SEC before
                        \ calling AR3

 RTS                    \ Return from the subroutine

.ARS1

                        \ This routine fetches arctan(A / Q) from the ACT table,
                        \ so A will be set to an integer in the range 0 to 31
                        \ that represents an angle from 0 to 45 degrees (or 0 to
                        \ PI / 4 radians)

 JSR LL28               \ Call LL28 to calculate:
                        \
                        \   R = 256 * A / Q

 LDA R                  \ Set X = R / 8
 LSR A                  \       = 32 * A / Q
 LSR A                  \
 LSR A                  \ so X has the value t * 32 where t = A / Q, which is
 TAX                    \ what we need to look up values in the ACT table

 LDA ACT,X              \ Fetch ACT+X from the ACT table into A, so now:
                        \
                        \   A = value in ACT + X
                        \     = value in ACT + (32 * A / Q)
                        \     = arctan(A / Q)

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: ACT
\       Type: Variable
\   Category: Maths (Geometry)
\    Summary: Arctan table
\  Deep dive: The sine, cosine and arctan tables
\
\ ------------------------------------------------------------------------------
\
\ This table contains lookup values for arctangent calculations involving angles
\ in the range 0 to 45 degrees (or 0 to PI / 4 radians).
\
\ To calculate the value of theta in the following:
\
\   theta = arctan(t)
\
\ where 0 <= t < 1, we look up the value in:
\
\   ACT + (t * 32)
\
\ The result will be an integer representing the angle in radians, where 256
\ represents a full circle of 360 degrees (2 * PI radians). The result of the
\ lookup will therefore be an integer in the range 0 to 31, as this represents
\ 0 to 45 degrees (0 to PI / 4 radians).
\
\ The table does not support values of t >= 1 or t < 0 directly, so if we need
\ to calculate the arctangent for an angle greater than 45 degrees, we can apply
\ the following calculation to the result from the table:
\
\   * For t > 1, arctan(t) = 64 - arctan(1 / t)
\
\ For negative values of t where -1 < t < 0, we can apply the following
\ calculation to the result from the table:
\
\   * For t < 0, arctan(-t) = 128 - arctan(t)
\
\ Finally, if t < -1, we can do the first calculation to get arctan(|t|), and
\ the second to get arctan(-|t|).
\
\ ******************************************************************************

.ACT

 FOR I%, 0, 31

  EQUB INT((128 / PI) * ATN(I% / 32) + 0.5)

 NEXT

\ ******************************************************************************
\
\       Name: TRTBL
\       Type: Variable
\   Category: Keyboard
\    Summary: Translation table from internal key number to ASCII (copied from
\             BBC Master Elite)
\
\ ------------------------------------------------------------------------------
\
\ BBC Master port: the cassette loader sets TRTB%(1 0) to point to the MOS 1.20
\ keyboard translation table (via OSBYTE 172). The Master's MOS 3.20 doesn't
\ have this table at the same place, so this is a copy of the MOS 3.20 table
\ (and the MOS code that is interleaved with it), as included in BBC Master
\ Elite. Moved here from main RAM: the demo never reads it (TRTB% no longer
\ points at it).
\
\ ******************************************************************************
.TRTBL7


 EQUB &00, &40, &FE     \ MOS code
 EQUB &A0, &5F, &8C
 EQUB &43, &FE, &8E
 EQUB &4F, &FE, &EA
 EQUB &AE, &4F, &FE
 EQUB &60

                        \ Internal key numbers &10 to &19:
                        \
 EQUB &51, &33          \ Q             3
 EQUB &34, &35          \ 4             5
 EQUB &84, &38          \ f4            8
 EQUB &87, &2D          \ f7            -
 EQUB &5E, &8C          \ ^             Left arrow

 EQUB &36, &37, &BC     \ MOS code
 EQUB &00, &FC, &60

                        \ Internal key numbers &20 to &29:
                        \
 EQUB &80, &57          \ f0            W
 EQUB &45, &54          \ E             T
 EQUB &37, &49          \ 7             I
 EQUB &39, &30          \ 9             0
 EQUB &5F, &8E          \ _             Down arrow

 EQUB &38, &39, &BC     \ MOS code
 EQUB &00, &FD, &60

                        \ Internal key numbers &30 to &39:
                        \
 EQUB &31, &32          \ 1             2
 EQUB &44, &52          \ D             R
 EQUB &36, &55          \ 6             U
 EQUB &4F, &50          \ O             P
 EQUB &5B, &8F          \ [             Up arrow

 EQUB &81, &82, &0D     \ MOS code
 EQUB &4C, &20, &02

                        \ Internal key numbers &40 to &49:
                        \
 EQUB &01, &41          \ CAPS LOCK     A
 EQUB &58, &46          \ X             F
 EQUB &59, &4A          \ Y             J
 EQUB &4B, &40          \ K             @
 EQUB &3A, &0D          \ :             RETURN

 EQUB &83, &7F, &AE     \ MOS code
 EQUB &4C, &FE, &FD

                        \ Internal key numbers &50 to &59:
                        \
 EQUB &02, &53          \ SHIFT LOCK    S
 EQUB &43, &47          \ C             G
 EQUB &48, &4E          \ H             N
 EQUB &4C, &3B          \ L             ;
 EQUB &5D, &7F          \ ]             DELETE

 EQUB &85, &84, &86     \ MOS code
 EQUB &4C, &FA, &00

                        \ Internal key numbers &60 to &69:
                        \
 EQUB &00, &5A          \ TAB           Z
 EQUB &20, &56          \ Space         V
 EQUB &42, &4D          \ B             M
 EQUB &2C, &2E          \ ,             .
 EQUB &2F, &8B          \ /             COPY

 EQUB &30, &31, &33     \ MOS code
 EQUB &00, &00, &00

                        \ Internal key numbers &70 to &79:
                        \
 EQUB &1B, &81          \ ESCAPE        f1
 EQUB &82, &83          \ f2            f3
 EQUB &85, &86          \ f5            f6
 EQUB &88, &89          \ f8            f9
 EQUB &5C, &8D          \ \             Right arrow

 EQUB &34, &35, &32     \ MOS code
 EQUB &2C, &4E, &E3
