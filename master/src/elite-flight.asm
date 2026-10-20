\ ******************************************************************************
\
\ elite-flight.asm - flight code at the end of the main code (docs/MASTER-MAP.md):
\ the moving of ships and the planet (MV40, MV1, MV2, MVS5), TIS2, the laser
\ sights' colours, LL9F and the stardust's record-mode patching. Game logic
\ only: none of it runs with ACCCON X set.
\
\ ******************************************************************************

\ ******************************************************************************
\
\       Name: MV40
\       Type: Subroutine
\   Category: Moving
\    Summary: Rotate the planet or sun's location in space by the amount of
\             pitch and roll of our ship
\  Deep dive: Rotating the universe
\
\ ------------------------------------------------------------------------------
\
\ We implement this using the same equations as in part 5 of MVEIT, where we
\ rotated the current ship's location by our pitch and roll. Specifically, the
\ calculation is as follows:
\
\   1. K2 = y - alpha * x
\   2. z = z + beta * K2
\   3. y = K2 - beta * z
\   4. x = x + alpha * y
\
\ ******************************************************************************

.MV40

 LDA ALPHA              \ Set Q = -ALPHA, so Q contains the angle we want to
 EOR #%10000000         \ roll the planet through (i.e. in the opposite
 STA Q                  \ direction to our ship's roll angle alpha)

 LDA INWK               \ Set P(1 0) = (x_hi x_lo)
 STA P
 LDA INWK+1
 STA P+1

 LDA INWK+2             \ Set A = x_sign

 JSR MULT3              \ Set K(3 2 1 0) = (A P+1 P) * Q
                        \
                        \ which also means:
                        \
                        \   K(3 2 1) = (A P+1 P) * Q / 256
                        \            = x * -alpha / 256
                        \            = - alpha * x / 256

 LDX #3                 \ Set K(3 2 1) = (y_sign y_hi y_lo) + K(3 2 1)
 JSR MVT3               \              = y - alpha * x / 256

 LDA K+1                \ Set K2(2 1) = P(1 0) = K(2 1)
 STA K2+1
 STA P

 LDA K+2                \ Set K2+2 = K+2
 STA K2+2

 STA P+1                \ Set P+1 = K+2

 LDA BETA               \ Set Q = beta, the pitch angle of our ship
 STA Q

 LDA K+3                \ Set K+3 to K2+3, so now we have result 1 above:
 STA K2+3               \
                        \   K2(3 2 1) = K(3 2 1)
                        \             = y - alpha * x / 256

                        \ We also have:
                        \
                        \   A = K+3
                        \
                        \   P(1 0) = K(2 1)
                        \
                        \ so combined, these mean:
                        \
                        \   (A P+1 P) = K(3 2 1)
                        \             = K2(3 2 1)

 JSR MULT3              \ Set K(3 2 1 0) = (A P+1 P) * Q
                        \
                        \ which also means:
                        \
                        \   K(3 2 1) = (A P+1 P) * Q / 256
                        \            = K2(3 2 1) * beta / 256
                        \            = beta * K2 / 256

 LDX #6                 \ K(3 2 1) = (z_sign z_hi z_lo) + K(3 2 1)
 JSR MVT3               \          = z + beta * K2 / 256

 LDA K+1                \ Set P = K+1
 STA P

 STA INWK+6             \ Set z_lo = K+1

 LDA K+2                \ Set P+1 = K+2
 STA P+1

 STA INWK+7             \ Set z_hi = K+2

 LDA K+3                \ Set A = z_sign = K+3, so now we have:
 STA INWK+8             \
                        \   (z_sign z_hi z_lo) = K(3 2 1)
                        \                      = z + beta * K2 / 256

                        \ So we now have result 2 above:
                        \
                        \   z = z + beta * K2

 EOR #%10000000         \ Flip the sign bit of A to give A = -z_sign

 JSR MULT3              \ Set K(3 2 1 0) = (A P+1 P) * Q
                        \                = (-z_sign z_hi z_lo) * beta
                        \                = -z * beta

 LDA K+3                \ Set T to the sign bit of K(3 2 1 0), i.e. to the sign
 AND #%10000000         \ bit of -z * beta
 STA T

 EOR K2+3               \ If K2(3 2 1 0) has a different sign to K(3 2 1 0),
 BMI MV1                \ then EOR'ing them will produce a 1 in bit 7, so jump
                        \ to MV1 to take this into account

                        \ If we get here, K and K2 have the same sign, so we can
                        \ add them together to get the result we're after, and
                        \ then set the sign afterwards

 LDA K                  \ We now do the following sum:
 CLC                    \
 ADC K2                 \   (A y_hi y_lo -) = K(3 2 1 0) + K2(3 2 1 0)
                        \
                        \ starting with the low bytes (which we don't keep)
                        \
                        \ The CLC has no effect because MULT3 clears the C
                        \ flag, so this instruction could be removed (as it is
                        \ in the cassette version, for example)

 LDA K+1                \ We then do the middle bytes, which go into y_lo
 ADC K2+1
 STA INWK+3

 LDA K+2                \ And then the high bytes, which go into y_hi
 ADC K2+2
 STA INWK+4

 LDA K+3                \ And then the sign bytes into A, so overall we have the
 ADC K2+3               \ following, if we drop the low bytes from the result:
                        \
                        \   (A y_hi y_lo) = (K + K2) / 256

 JMP MV2                \ Jump to MV2 to skip the calculation for when K and K2
                        \ have different signs

.MV1

 LDA K                  \ If we get here then K2 and K have different signs, so
 SEC                    \ instead of adding, we need to subtract to get the
 SBC K2                 \ result we want, like this:
                        \
                        \   (A y_hi y_lo -) = K(3 2 1 0) - K2(3 2 1 0)
                        \
                        \ starting with the low bytes (which we don't keep)

 LDA K+1                \ We then do the middle bytes, which go into y_lo
 SBC K2+1
 STA INWK+3

 LDA K+2                \ And then the high bytes, which go into y_hi
 SBC K2+2
 STA INWK+4

 LDA K2+3               \ Now for the sign bytes, so first we extract the sign
 AND #%01111111         \ byte from K2 without the sign bit, so P = |K2+3|
 STA P

 LDA K+3                \ And then we extract the sign byte from K without the
 AND #%01111111         \ sign bit, so A = |K+3|

 SBC P                  \ And finally we subtract the sign bytes, so P = A - P
 STA P

                        \ By now we have the following, if we drop the low bytes
                        \ from the result:
                        \
                        \   (A y_hi y_lo) = (K - K2) / 256
                        \
                        \ so now we just need to make sure the sign of the
                        \ result is correct

 BCS MV2                \ If the C flag is set, then the last subtraction above
                        \ didn't underflow and the result is correct, so jump to
                        \ MV2 as we are done with this particular stage

 LDA #1                 \ Otherwise the subtraction above underflowed, as K2 is
 SBC INWK+3             \ the dominant part of the subtraction, so we need to
 STA INWK+3             \ negate the result using two's complement, starting
                        \ with the low bytes:
                        \
                        \   y_lo = 1 - y_lo

 LDA #0                 \ And then the high bytes:
 SBC INWK+4             \
 STA INWK+4             \   y_hi = 0 - y_hi

 LDA #0                 \ And finally the sign bytes:
 SBC P                  \
                        \   A = 0 - P

 ORA #%10000000         \ We now force the sign bit to be negative, so that the
                        \ final result below gets the opposite sign to K, which
                        \ we want as K2 is the dominant part of the sum

.MV2

 EOR T                  \ T contains the sign bit of K, so if K is negative,
                        \ this flips the sign of A

 STA INWK+5             \ Store A in y_sign

                        \ So we now have result 3 above:
                        \
                        \   y = K2 + K
                        \     = K2 - beta * z

 LDA ALPHA              \ Set A = alpha
 STA Q

 LDA INWK+3             \ Set P(1 0) = (y_hi y_lo)
 STA P
 LDA INWK+4
 STA P+1

 LDA INWK+5             \ Set A = y_sign

 JSR MULT3              \ Set K(3 2 1 0) = (A P+1 P) * Q
                        \                = (y_sign y_hi y_lo) * alpha
                        \                = y * alpha

 LDX #0                 \ Set K(3 2 1) = (x_sign x_hi x_lo) + K(3 2 1)
 JSR MVT3               \              = x + y * alpha / 256

 LDA K+1                \ Set (x_sign x_hi x_lo) = K(3 2 1)
 STA INWK               \                        = x + y * alpha / 256
 LDA K+2
 STA INWK+1
 LDA K+3
 STA INWK+2

                        \ So we now have result 4 above:
                        \
                        \   x = x + y * alpha

 JMP MV45               \ We have now finished rotating the planet or sun by
                        \ our pitch and roll, so jump back into the MVEIT
                        \ routine at MV45 to apply all the other movements

\ ******************************************************************************
\
\       Name: LL9F
\       Type: Subroutine
\   Category: Drawing ships
\    Summary: Port: draw a ship with LL9, then the frame (the title screen)
\
\ ******************************************************************************

.LL9F

 JSR LL9                \ Draw the ship (recorded for the renderer when QQ11 = 0)

 JMP hframe             \ Render the frame (gfx-hooks.asm), returning from the
                        \ subroutine using a tail call

\ ******************************************************************************
\
\       Name: TIS2
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate A = A / Q
\  Deep dive: Shift-and-subtract division
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following division, where A is a sign-magnitude number and Q is
\ a positive integer:
\
\   A = A / Q
\
\ The value of A is returned as a sign-magnitude number with 96 representing 1,
\ and the maximum value returned is 1 (i.e. 96). This routine is used when
\ normalising vectors, where we represent fractions using integers, so this
\ gives us an approximation to two decimal places.
\
\ ******************************************************************************

.TIS2

 TAY                    \ Store the argument A in Y

 AND #%01111111         \ Strip the sign bit from the argument, so A = |A|

 CMP Q                  \ If A >= Q then jump to TI4 to return a 1 with the
 BCS TI4                \ correct sign

 STZ T                  \ Port: set T = 0; the six iterations below are fully
                        \ unrolled (the demo port's e9770fa, w_0139), so T
                        \ needs no marker bits to end a loop

 ASL A                  \ Iteration 1: shift A to the left
 CMP Q                  \ If A < Q skip the following subtraction
 BCC P%+4
 SBC Q                  \ A >= Q (C set), so set A = A - Q (C stays set)
 ROL T                  \ Catch the quotient bit into bit 0 of T

 ASL A                  \ Iteration 2: shift A to the left
 CMP Q                  \ If A < Q skip the following subtraction
 BCC P%+4
 SBC Q                  \ A >= Q (C set), so set A = A - Q (C stays set)
 ROL T                  \ Catch the quotient bit into bit 0 of T

 ASL A                  \ Iteration 3: shift A to the left
 CMP Q                  \ If A < Q skip the following subtraction
 BCC P%+4
 SBC Q                  \ A >= Q (C set), so set A = A - Q (C stays set)
 ROL T                  \ Catch the quotient bit into bit 0 of T

 ASL A                  \ Iteration 4: shift A to the left
 CMP Q                  \ If A < Q skip the following subtraction
 BCC P%+4
 SBC Q                  \ A >= Q (C set), so set A = A - Q (C stays set)
 ROL T                  \ Catch the quotient bit into bit 0 of T

 ASL A                  \ Iteration 5: shift A to the left
 CMP Q                  \ If A < Q skip the following subtraction
 BCC P%+4
 SBC Q                  \ A >= Q (C set), so set A = A - Q (C stays set)
 ROL T                  \ Catch the quotient bit into bit 0 of T

 ASL A                  \ Iteration 6: shift A to the left
 CMP Q                  \ If A < Q skip the following subtraction
 BCC P%+4
 SBC Q                  \ A >= Q (C set), so set A = A - Q (C stays set)
 ROL T                  \ Catch the quotient bit into bit 0 of T

 LDA T                  \ Set A = T + T / 2 (+ the bit shifted out)
 LSR A                  \       = 3/8 of the full 8-bit quotient, as before
 ADC T                  \ (grind: T is dead after TIS2 -- every path out of
                        \ NORM writes T in MULT1 or SPS2 before reading it --
                        \ so the result is not stored back in T)

 CPY #%10000000         \ If the original argument A (in Y) was positive, we
 BCC P%+4               \ are done as A = T, otherwise set bit 7 of A to apply
 ORA #%10000000         \ the negative sign

 RTS                    \ Return from the subroutine

.TI4

 TYA                    \ Fetch the sign bit of the original argument A
 AND #%10000000

 ORA #96                \ Apply the sign bit to 96 (which represents 1)

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\ Port: MVS5 in the demo port's form (bebd95c, 8a7e690, bcde44b w_0037,
\ 73eee89 w_0040, 22be6e1 w_0040, b5ffdfd, 55e7b89 w_0039): both ADDs inline
\ with the rare paths through ADD (MVEIT and HAS1 call it)
\
\ ******************************************************************************

\ ******************************************************************************
\
\       Name: MVS5
\       Type: Subroutine
\   Category: Moving
\    Summary: Apply a 3.6 degree pitch or roll to an orientation vector
\  Deep dive: Orientation vectors
\             Pitching and rolling by a fixed angle
\
\ ------------------------------------------------------------------------------
\
\ Pitch or roll a ship by a small, fixed amount (1/16 radians, or 3.6 degrees),
\ in a specified direction, by rotating the orientation vectors. The vectors to
\ rotate are given in X and Y, and the direction of the rotation is given in
\ RAT2. The calculation is as follows:
\
\   * If the direction is positive:
\
\     X = X * (1 - 1/512) + Y / 16
\     Y = Y * (1 - 1/512) - X / 16
\
\   * If the direction is negative:
\
\     X = X * (1 - 1/512) - Y / 16
\     Y = Y * (1 - 1/512) + X / 16
\
\ So if X = 15 (roofv_x), Y = 21 (sidev_x) and RAT2 is positive, it does this:
\
\   roofv_x = roofv_x * (1 - 1/512)  + sidev_x / 16
\   sidev_x = sidev_x * (1 - 1/512)  - roofv_x / 16
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The first vector to rotate:
\
\                         * If X = 15, rotate roofv_x
\
\                         * If X = 17, rotate roofv_y
\
\                         * If X = 19, rotate roofv_z
\
\                         * If X = 21, rotate sidev_x
\
\                         * If X = 23, rotate sidev_y
\
\                         * If X = 25, rotate sidev_z
\
\   Y                   The second vector to rotate:
\
\                         * If Y = 9,  rotate nosev_x
\
\                         * If Y = 11, rotate nosev_y
\
\                         * If Y = 13, rotate nosev_z
\
\                         * If Y = 21, rotate sidev_x
\
\                         * If Y = 23, rotate sidev_y
\
\                         * If Y = 25, rotate sidev_z
\
\   RAT2                The direction of the pitch or roll to perform, positive
\                       or negative (i.e. the sign of the roll or pitch counter
\                       in bit 7)
\
\ ******************************************************************************

.mvs5x

 JMP mvs5r              \ Port: the rare first-half path, in main RAM
                        \ (where MVS5 was), as the demo's at the end of bank 4

.mvs5n

                        \ Port (the demo port's MVS5): MVS5's roofv_x_hi is negative, so
                        \ |roofv_x_hi| / 2 = 0 1 b6..b1 after the LSR, and EOR
                        \ #&BF gives ~(|roofv_x_hi| / 2) as AND #&7F, LSR, EOR
                        \ #&FF did (S is roofv_x_hi, stored by MVS5)

 LSR A                  \ A = ~(|roofv_x_hi| / 2)
 EOR #&BF
 SEC                    \ (S R) = (roofv_x_hi roofv_x_lo) - |roofv_x| / 512
 ADC INWK,X
 STA R
 BCS P%+4
 DEC S                  \ (S stays negative: no borrow when |hi| = 0)
 BIT K+1                \ S is negative, so same signs if K+1 is negative:
 BMI mvs5q              \ back to ADD's first path, else fall into mvs5a
                        \ (either way with A = R)

.mvs5a

                        \ Port (the demo port's MVS5): the out-of-line paths of the first
                        \ inlined ADD in MVS5 below (placed here so all of
                        \ MVS5's branches stay short), entered with A = R and
                        \ the argument (A P) of ADD in K(1 0)

 SEC                    \ Different signs (ADD's MU8 common path):
 SBC K                  \   K = R - P, also stored in roofv_x_lo
 STA K                  \
 STA INWK,X             \
 LDA S                  \   A = |S| - |K+1| - borrow
 EOR #%10000000
 SBC K+1
 BCC mvs5x              \ |S R| < |A P|, or high byte 0: rare, so let ADD
 BEQ mvs5x              \ redo the whole sum from scratch (exact results)
 BIT K+1                \ |S R| > |A P|: K+1 = A (0..127) with the sign of S,
 BMI mvs5w              \ i.e. the opposite of the sign of K+1, as ADD's MU8s
 ORA #%10000000         \ (C, V = 0 dead: the second half recomputes them),
 BRA mvs5w              \ stored in K+1 and roofv_x_hi by mvs5w

.MVS5

 STX Q                  \ Port: Q = X, as MVS5 used to leave it

                        \ Port (the demo port's MVS5): roofv_x is only read before it is
                        \ overwritten, so the second half's argument
                        \ (A P) = -/+ roofv_x / 16 is computed first, into
                        \ P and T1, and the first half's (A P) = +/- nosev_x
                        \ / 16 goes in K(1 0) (overwritten by its result), so
                        \ the first half can store roofv_x directly

 LDA INWK,X             \ Set P = roofv_x_lo
 STA P

 LDA INWK+1,X           \ Fetch roofv_x_hi and give it the sign of -roofv_x
 EOR RAT2               \ as if multiplied by the pitch or roll direction
 EOR #%10000000         \ (RAT2 is 0 or &80, so bits 0-6 are unchanged)

 LSR A                  \ Set (A P) = (A P) / 16, which leaves P as
 ROR P                  \ |roofv_x| / 16 low byte (the sign bit never reaches
 LSR A                  \ P) and A = %0000sxxx, where s is the sign
 ROR P
 LSR A
 ROR P
 CMP #16                \ A = %000sxxxx here: C = s, then drop s from bit 4
 AND #%00001111         \ and rotate it into bit 7 as the last shift, so
 ROR A                  \ A = %s0000xxx and C = the bit that goes into P,
 ROR P                  \ giving (A P) = -/+ roofv_x / 16

 STA T1                 \ T1 = A, as ADD's prologue in the second half

 LDA INWK,Y             \ Set K = nosev_x_lo
 STA K

 LDA INWK+1,Y           \ Fetch nosev_x_hi and give it the sign as if we
 EOR RAT2               \ multiplied by the pitch or roll direction (RAT2 is
                        \ 0 or &80, so bits 0-6 are unchanged)

 LSR A                  \ Set (A K) = (A K) / 16, as above
 ROR K
 LSR A
 ROR K
 LSR A
 ROR K
 CMP #16
 AND #%00001111
 ROR A
 ROR K                  \ giving (A K) = +/- nosev_x / 16

 STA K+1                \ ADD's prologue, K+1 = A (in place of T1; T is not
                        \ needed: both paths get the sign from K+1 or the
                        \ carry instead); the sign test against S is done
                        \ below with a branch on the sign of S and BIT K+1

 LDA INWK+1,X           \ Fetch roofv_x_hi, store it in S (the high byte of the
 STA S                  \ subtraction below, fixed up for the borrow later),
 BMI mvs5n              \ and if it is negative do the same in mvs5n
 LSR A                  \ Positive: A = |roofv_x_hi| / 2 = |roofv_x| / 512
                        \
                        \ The above is true because:
                        \
                        \ |roofv_x| = |roofv_x_hi| * 256 + roofv_x_lo
                        \
                        \ so:
                        \
                        \ |roofv_x| / 512 = |roofv_x_hi| * 256 / 512
                        \                    + roofv_x_lo / 512
                        \                  = |roofv_x_hi| / 2

 EOR #&FF               \ Now we do the following subtraction:
 SEC                    \
 ADC INWK,X             \ (S R) = (roofv_x_hi roofv_x_lo) - |roofv_x| / 512
 STA R                  \       = (1 - 1/512) * roofv_x
                        \
                        \ low byte as lo + ~A + 1 = lo - A (same result and C)

 BCS P%+4               \ And then the high byte: decrement S if the low byte
 DEC S                  \ borrowed (same as roofv_x_hi - 0 - borrow)

 BIT K+1                \ S is positive, so jump to mvs5a (with A = R) if K+1
 BMI mvs5a              \ is negative (different signs)

.mvs5q

                        \ Same signs (ADD's first path), A = R:
 CLC                    \
 ADC K                  \   K = R + P, also stored in roofv_x_lo
 STA K                  \
 STA INWK,X             \
 LDA S                  \   K+1 = (S + K+1 + C) OR sign, where the sign is
 ADC K+1                \   the carry out (both negative: S, K+1 >= &80 so
 BCC mvs5w              \   C = 1; both positive: S + K+1 + C <= &7F+7+1, so
 ORA #%10000000         \   C = 0)

.mvs5w

 STA K+1                \ Set K(1 0) = roofv_x
 STA INWK+1,X           \            = (1 - 1/512) * roofv_x +/- nosev_x / 16

.mvs5h

 LDA INWK+1,Y           \ Fetch nosev_x_hi, store it in S (the high byte of the
 STA S                  \ subtraction below, fixed up for the borrow later),
 ORA #%10000001         \ then form ~(|nosev_x_hi| / 2) with C = 1 (hi OR &81,
 LSR A                  \ LSR gives %01mmmmmm and C = 1, EOR &BF gives
 EOR #%10111111         \ %11 + ~mmmmmm), where
                        \ |nosev_x_hi| / 2 = |nosev_x| / 512

                        \ Now we do the following subtraction:
                        \
 ADC INWK,Y             \ (S R) = (nosev_x_hi nosev_x_lo) - |nosev_x| / 512
 STA R                  \       = (1 - 1/512) * nosev_x
                        \
                        \ low byte as lo + ~A + 1 = lo - A (same result and C)

 BCS P%+4               \ And then the high byte: decrement S if the low byte
 DEC S                  \ borrowed (same as nosev_x_hi - 0 - borrow)

                        \ Port (the demo port's MVS5): ADD's two common paths are inlined
                        \ here, computing (A P) + (S R) exactly as ADD does,
                        \ with (A P) = (T1 P) = -/+ roofv_x / 16 from the top
                        \ of MVS5 (same T1 and C; T is dead, as in the first
                        \ half), but storing the result straight into nosev_x

 LDA T1                 \ Jump to mvs5d if A and S have different signs (T is
 EOR S                  \ not needed: both paths get the sign from T1 or the
 BMI mvs5d              \ carry instead)

 LDA R                  \ Same signs (ADD's first path):
 CLC                    \
 ADC P                  \   nosev_x_lo = R + P
 STA INWK,Y             \
 LDA S                  \   nosev_x_hi = (S + T1 + C) OR sign, where the
 ADC T1                 \   sign is the carry out (both negative: S, T1 >= &80
 BCC P%+4               \   so C = 1; both positive: S + T1 + C <= &7F+7+1, so
 ORA #%10000000         \   C = 0)
 STA INWK+1,Y           \ Set nosev_x = (1-1/512) * nosev_x -/+ roofv_x / 16

 RTS                    \ Return from the subroutine (roofv_x and K(1 0) were
                        \ set in the first half)

.mvs5d

 LDA R                  \ Different signs (ADD's MU8 common path):
 SEC                    \
 SBC P                  \   nosev_x_lo = R - P
 STA INWK,Y             \
 LDA S                  \   A = |S| - |T1| - borrow
 EOR #%10000000
 SBC T1
 BCC mvs5s              \ |S R| < |A P|, or high byte 0: rare, so let ADD
 BEQ mvs5s              \ redo the whole sum from scratch (exact results)
 BIT T1                 \ |S R| > |A P|: nosev_x_hi = A (1..127) with the sign
 BMI P%+4               \ of S, i.e. the opposite of the sign of T1 (ADD's MU8s
 ORA #%10000000         \ also clears C, but no caller of MVS5 reads C or V)
 STA INWK+1,Y

 RTS                    \ Return from the subroutine

.mvs5s

 JMP mvs5sm             \ Port: the rare path, in main RAM (where MVS5 was)


\ ******************************************************************************
\
\       Name: pxpatd
\       Type: Subroutine
\   Category: Stardust
\    Summary: Set COL for the stardust, then pxpat
\
\ ******************************************************************************

.pxpatd

 LDA #DUST              \ Switch to stripe 3-2-3-2, as nWq and FLIP did
 STA COL

\ ******************************************************************************
\
\       Name: pxpat
\       Type: Subroutine
\   Category: Stardust
\    Summary: Patch PIX1's, H_STAR's and H_STAROFF's record-mode tests for a
\             pass over the stardust (Port: the demo port's per-frame patching
\             of the QQ11 OR GFORCE test, transfer item B12)
\
\ ------------------------------------------------------------------------------
\
\ Called at the start of each pass that draws stardust (STARS1, STARS2,
\ STARS6, nWq, FLIP), during which QQ11 and GFORCE do not change. Corrupts A
\ only.
\
\ ******************************************************************************

.pxpat

 LDA QQ11               \ Record mode if QQ11 OR GFORCE is zero
 ORA GFORCE
 BEQ pxp1

 LDA #&EA               \ Outside record mode: PIX1 falls into PIXEL2 (NOP),
 STA pxr                \ H_STAR and H_STAROFF branch (BRA)
 LDA #&80
 BNE pxp2

.pxp1

 LDA #&60               \ Record mode: PIX1 returns (RTS), H_STAR and
 STA pxr                \ H_STAROFF fall through (BIT #imm)
 LDA #&89

.pxp2

 STA hstp
 STA hsop
 RTS

