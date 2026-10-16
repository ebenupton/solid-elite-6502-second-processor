\ ******************************************************************************
\
\ elite-low.asm - game code in main RAM at &0840-&0CFF (docs/MASTER-MAP.md)
\
\ Master Elite never uses the MOS's sound, envelope, printer, RS423, cassette
\ and speech buffers there (it has its own sound code and IRQ1V handler, which
\ never passes interrupts on to the MOS), and MOS 3.20 and DFS do not use
\ &0B00-&0CFF at all (docs/MASTER-MEMORY.md). Page &0D above is off limits.
\ The loader copies this code into place after its last disc access. It is
\ below &3000, so it may run with ACCCON X set.
\
\ ******************************************************************************

\ ******************************************************************************
\
\       Name: DOKEY
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Scan for the seven primary flight controls and apply the docking
\             computer manoeuvring code
\  Deep dive: The key logger
\             The docking computer
\
\ ------------------------------------------------------------------------------
\
\ Scan for the seven primary flight controls (or the equivalent on joystick),
\ pause and configuration keys, and secondary flight controls, and update the
\ key logger accordingly. Specifically:
\
\   * If we are on keyboard configuration, clear the key logger and update it
\     for the seven primary flight controls, and update the pitch and roll
\     rates accordingly.
\
\   * If we are on joystick configuration, clear the key logger and jump to
\     DKJ1, which reads the joystick equivalents of the primary flight
\     controls.
\
\ Both options end up at DK4 to scan for other keys, beyond the seven primary
\ flight controls.
\
\ ******************************************************************************

.DOKEY

 JSR RDKEY-1            \ Scan the keyboard for a key press and return the
                        \ ASCII code of the key pressed in X (calling RDKEY-1
                        \ only scans the keyboard for valid BCD key numbers,
                        \ which speeds things up a bit)

 LDA auto               \ If auto is 0, then the docking computer is not
 BEQ DK15               \ currently activated, so jump to DK15 to skip the
                        \ docking computer manoeuvring code below

 JSR ZINF               \ Call ZINF to reset the INWK ship workspace

 LDA #96                \ Set nosev_z_hi = 96
 STA INWK+14

 ORA #%10000000         \ Set sidev_x_hi = -96
 STA INWK+22

 STA TYPE               \ Set the ship type to -96, so the negative value will
                        \ let us check in the DOCKIT routine whether this is our
                        \ ship that is activating its docking computer, rather
                        \ than an NPC ship docking

 LDA DELTA              \ Set the ship speed to DELTA (our speed)
 STA INWK+27

 JSR DOCKIT             \ Call DOCKIT to calculate the docking computer's moves
                        \ and update INWK with the results

                        \ We now "press" the relevant flight keys, depending on
                        \ the results from DOCKIT, starting with the pitch keys

 LDA INWK+27            \ Fetch the updated ship speed from byte #27 into A

 CMP #22                \ If A < 22, skip the next instruction
 BCC P%+4

 LDA #22                \ Set A = 22, so the maximum speed during docking is 22

 STA DELTA              \ Update DELTA to the new value in A

 LDA #&FF               \ Set A = &FF, which we can insert into the key logger
                        \ to "fake" the docking computer working the keyboard

 LDX #15                \ Set X = 15, so we "press" KY+15, i.e. KY1, below
                        \ ("?", slow down)

 LDY INWK+28            \ If the updated acceleration in byte #28 is zero, skip
 BEQ DK11               \ to DK11

 BMI P%+4               \ If the updated acceleration is negative, skip the
                        \ following instruction

 LDX #11                \ Set X = 11, so we "press" KY+11, i.e. KY2, with the
                        \ next instruction (Space, speed up)

 STA KL,X               \ Store &FF in either KY1 or KY2 to "press" the relevant
                        \ key, depending on whether the updated acceleration is
                        \ negative (in which case we "press" KY1, "?", to slow
                        \ down) or positive (in which case we "press" KY2,
                        \ Space, to speed up)

.DK11

                        \ We now "press" the relevant roll keys, depending on
                        \ the results from DOCKIT

 LDA #128               \ Set A = 128, which indicates no change in roll when
                        \ stored in JSTX (i.e. the centre of the roll indicator)

 LDX #13                \ Set X = 13, so we "press" KY+13, i.e. KY3, below
                        \ ("<", increase roll)

 ASL INWK+29            \ Shift ship byte #29 left, which shifts bit 7 of the
                        \ updated roll counter (i.e. the roll direction) into
                        \ the C flag

 BEQ DK12               \ If the remains of byte #29 is zero, then the updated
                        \ roll counter is zero, so jump to DK12 set JSTX to 128,
                        \ to indicate there's no change in the roll

 BCC P%+4               \ If the C flag is clear, skip the following instruction

 LDX #14                \ The C flag is set, i.e. the direction of the updated
                        \ roll counter is negative, so set X to 14 so we
                        \ "press" KY+14. i.e. KY4, below (">", decrease roll)

 BIT INWK+29            \ We shifted the updated roll counter to the left above,
 BPL DK14               \ so this tests bit 6 of the original value, and if it
                        \ is clear (i.e. the magnitude is less than 64), jump to
                        \ DK14 to "press" the key and leave JSTX unchanged

 LDA #64                \ The magnitude of the updated roll is 64 or more, so
 STA JSTX               \ set JSTX to 64 (so the roll decreases at half the
                        \ maximum rate)

 LDA #0                 \ And set A = 0 so we do not "press" any keys (so if the
                        \ docking computer needs to make a serious roll, it does
                        \ so by setting JSTX directly rather than by "pressing"
                        \ a key)

.DK14

 STA KL,X               \ Store A in either KY3 or KY4, depending on whether
                        \ the updated roll rate is increasing (KY3) or
                        \ decreasing (KY4)

 LDA JSTX               \ Fetch A from JSTX so the next instruction has no
                        \ effect

.DK12

 STA JSTX               \ Store A in JSTX to update the current roll rate

                        \ We now "press" the relevant pitch keys, depending on
                        \ the results from DOCKIT

 LDA #128               \ Set A = 128, which indicates no change in pitch when
                        \ stored in JSTX (i.e. the centre of the pitch
                        \ indicator)

 LDX #6                 \ Set X = 6, so we "press" KY+6, i.e. KY5, below
                        \ ("X", decrease pitch, pulling the nose up)

 ASL INWK+30            \ Shift ship byte #30 left, which shifts bit 7 of the
                        \ updated pitch counter (i.e. the pitch direction) into
                        \ the C flag

 BEQ DK13               \ If the remains of byte #30 is zero, then the updated
                        \ pitch counter is zero, so jump to DK13 set JSTY to
                        \ 128, to indicate there's no change in the pitch

 BCS P%+4               \ If the C flag is set, skip the following instruction

 LDX #8                 \ Set X = 8, so we "press" KY+8, i.e. KY6, with the next
                        \ instruction ("S", increase pitch, so the nose dives)

 STA KL,X               \ Store 128 in either KY5 or KY6 to "press" the relevant
                        \ key, depending on whether the pitch direction is
                        \ negative (in which case we "press" KY5, "X", to
                        \ decrease the pitch, pulling the nose up) or positive
                        \ (in which case we "press" KY6, "S", to increase the
                        \ pitch, pushing the nose down)

 LDA JSTY               \ Fetch A from JSTY so the next instruction has no
                        \ effect

.DK13

 STA JSTY               \ Store A in JSTY to update the current pitch rate

IF _COMPACT

 JMP DK152              \ Jump to DK152 to skip reading the joystick, as we just
                        \ applied the docking computer to the controls and we
                        \ don't want the joystick to interfere
                        \
                        \ Note that this instruction is missing from the Master
                        \ version, so in that version the joystick can break the
                        \ docking computer when configured; this instruction was
                        \ added to the Master Compact version to fix this bug

ENDIF

.DK15

 LDA JSTK               \ If JSTK is zero, then we are configured to use the
 BEQ DK152              \ keyboard rather than the joystick, so jump to DK152 to
                        \ skip reading the joystick

IF _SNG47

 LDA JOPOS              \ Fetch the high byte of the joystick X value

 EOR JSTE               \ The high byte A is now EOR'd with the value in
                        \ location JSTE, which contains &FF if both joystick
                        \ channels are reversed and 0 otherwise (so A now
                        \ contains the high byte but inverted, if that's what
                        \ the current settings say)

 ORA #1                 \ Ensure the value is at least 1

 STA JSTX               \ Store the resulting joystick X value in JSTX

 LDA JOPOS+1            \ Fetch the high byte of the joystick Y value

 EOR #&FF               \ This EOR is used in conjunction with the EOR JSTGY
                        \ below, as having a value of 0 in JSTGY means we have
                        \ to invert the joystick Y value, and this EOR does
                        \ that part

 EOR JSTE               \ The high byte A is now EOR'd with the value in
                        \ location JSTE, which contains &FF if both joystick
                        \ channels are reversed and 0 otherwise (so A now
                        \ contains the high byte but inverted, if that's what
                        \ the current settings say)

 EOR JSTGY              \ JSTGY will be 0 if the game is configured to reverse
                        \ the joystick Y channel, so this EOR along with the
                        \ EOR #&FF above does exactly that

 STA JSTY               \ Store the resulting joystick Y value in JSTY

 LDA VIA+&40            \ Read 6522 System VIA input register IRB (SHEILA &40)

 AND #%00010000         \ Bit 4 of IRB (PB4) is clear if joystick 1's fire
                        \ button is pressed, otherwise it is set, so AND'ing
                        \ the value of IRB with %10000 extracts this bit

 BNE DK4                \ If the joystick fire button is not being pressed,
                        \ jump to DK4 to scan for other keys

 LDA #&FF               \ Update the key logger at KY7 to "press" the "A" (fire)
 STA KY7                \ button

 BNE DK4                \ Jump to DK4 to scan for other keys (this BNE is
                        \ effectively a JMP as A is never 0)

ELIF _COMPACT

 JSR RDJOY              \ Call RDJOY to read from either the analogue or digital
                        \ joystick

 BCC DK4                \ If we just read from the analogue joystick, the C flag
                        \ will be clear, so jump to DK4 to scan for other keys

                        \ Otherwise we just read the digital joystick, so we now
                        \ update the pitch and roll

ENDIF

.DK152

 LDX JSTX               \ Set X = JSTX, the current roll rate (as shown in the
                        \ RL indicator on the dashboard)

 LDA #7                 \ Set A to 7, which is the amount we want to alter the
                        \ roll rate by if the roll keys are being pressed

 LDY KY3                \ If the "<" key is not being pressed, skip the next
 BEQ P%+5               \ instruction

 JSR BUMP2              \ The "<" key is being pressed, so call the BUMP2
                        \ routine to increase the roll rate in X by A

 LDY KY4                \ If the ">" key is not being pressed, skip the next
 BEQ P%+5               \ instruction

 JSR REDU2              \ The "<" key is being pressed, so call the REDU2
                        \ routine to decrease the roll rate in X by A, taking
                        \ the keyboard auto re-centre setting into account

 STX JSTX               \ Store the updated roll rate in JSTX

 ASL A                  \ Double the value of A, to 14

 LDX JSTY               \ Set X = JSTY, the current pitch rate (as shown in the
                        \ DC indicator on the dashboard)

 LDY KY5                \ If the "X" key is not being pressed, skip the next
 BEQ P%+5               \ instruction

 JSR REDU2              \ The "X" key is being pressed, so call the REDU2
                        \ routine to decrease the pitch rate in X by A, taking
                        \ the keyboard auto re-centre setting into account

 LDY KY6                \ If the "S" key is not being pressed, skip the next
 BEQ P%+5               \ instruction

 JSR BUMP2              \ The "S" key is being pressed, so call the BUMP2
                        \ routine to increase the pitch rate in X by A

 STX JSTY               \ Store the updated roll rate in JSTY

                        \ Fall through into DK4 to scan for other keys

\ ******************************************************************************
\
\       Name: DK4
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Scan for pause, configuration and secondary flight keys
\  Deep dive: The key logger
\
\ ------------------------------------------------------------------------------
\
\ Scan for pause and configuration keys, and if this is a space view, also scan
\ for secondary flight controls.
\
\ Specifically:
\
\   * Scan for the pause button (COPY) and if it's pressed, pause the game and
\     process any configuration key presses until the game is unpaused (DELETE)
\
\   * If this is a space view, scan for secondary flight keys and update the
\     relevant bytes in the key logger
\
\ ******************************************************************************

.DK4

 LDX KL                 \ Fetch the key pressed from byte #0 of the key logger

 CPX #&8B               \ If COPY is not being pressed, jump to DK2 below,
 BNE DK2                \ otherwise let's process the configuration keys

.FREEZE

                        \ COPY is being pressed, so we enter a loop that
                        \ listens for configuration keys, and we keep looping
                        \ until we detect a DELETE key press. This effectively
                        \ pauses the game when COPY is pressed, and unpauses
                        \ it when DELETE is pressed

 JSR WSCAN              \ Call WSCAN to wait for the vertical sync, so the whole
                        \ screen gets drawn

 JSR RDKEY              \ Scan the keyboard for a key press and return the ASCII
                        \ code of the key pressed in A and X (or 0 for no key
                        \ press)

 CPX #'Q'               \ If "Q" is not being pressed, skip to DK6
 BNE DK6

 LDX #&FF               \ "Q" is being pressed, so set DNOIZ to &FF to turn the
 STX DNOIZ              \ sound off

 LDX #'Q'               \ Set X to the ASCII for "Q" once again, so it doesn't
                        \ get changed by the above

.DK6

 LDY #0                 \ We now want to loop through the keys that toggle
                        \ various settings, so set a counter in Y to work our
                        \ way through them

.DKL4

 JSR DKS3               \ Call DKS3 to scan for the key given in Y, and toggle
                        \ the relevant setting if it is pressed

 INY                    \ Increment Y to point to the next toggle key

 CPY #9                 \ Check to see whether we have reached the last toggle
                        \ key

 BNE DKL4               \ If not, loop back to check for the next toggle key

 LDA VOL                \ Fetch the current volume setting into A

 CPX #'.'               \ If "." is being pressed (i.e. the ">" key) then jump
 BEQ DOVOL1             \ to DOVOL1 to increase the volume

 CPX #','               \ If "," is not being pressed (i.e. the "<" key) then
 BNE DOVOL4             \ jump to DOVOL4 to skip the following

 DEC A                  \ The volume down key is being pressed, so decrement the
                        \ volume level in A

 EQUB &24               \ Skip the next instruction by turning it into &24 &1A,
                        \ or BIT &001A, which does nothing apart from affect the
                        \ flags

.DOVOL1

 INC A                  \ The volume up key is being pressed, so increment the
                        \ volume level in A

 TAY                    \ Copy the new volume level to Y

 AND #%11111000         \ If any of bits 3-7 are set, skip to DOVOL3 as we have
 BNE DOVOL3             \ either increased the volume past the maximum volume of
                        \ 7, or we have decreased it below 0 to -1, and in
                        \ neither case do we want to change the volume as we are
                        \ already at the maximum or minimum level

 STY VOL                \ Store the new volume level in VOL

.DOVOL3

 PHX                    \ Store X on the stack so we can retrieve it below after
                        \ making a beep

 JSR BEEP               \ Call the BEEP subroutine to make a short, high beep at
                        \ the new volume level

 LDY #10                \ Wait for 10/50 of a second (0.2 seconds)
 JSR DELAY

 PLX                    \ Restore the value of X we stored above

.DOVOL4

 CPX #'B'               \ If "B" is not being pressed, skip to DOVOL2
 BNE DOVOL2

 LDA BSTK               \ Toggle the value of BSTK between 0 and &FF
 EOR #&FF
 STA BSTK

 STA JSTK               \ Configure JSTK to the same value, so when the Bitstik
                        \ is enabled, so is the joystick

 STA JSTE               \ Configure JSTE to the same value, so when the Bitstik
                        \ is enabled, the joystick is configured with reversed
                        \ channels

 BPL P%+5               \ If we just toggled the Bitstik off (i.e. to 0, which
                        \ is positive), then skip the first of these two
                        \ instructions, so we get two beeps for on and one beep
                        \ for off

 JSR BELL               \ We just enabled the Bitstik, so give two standard
                        \ system beeps (this being the first)

 JSR BELL               \ Make another system beep

.DOVOL2

 CPX #'S'               \ If "S" is not being pressed, jump to DK7
 BNE DK7

 LDA #0                 \ "S" is being pressed, so set DNOIZ to 0 to turn the
 STA DNOIZ              \ sound on

.DK7

 CPX #&1B               \ If ESCAPE is not being pressed, skip over the next
 BNE P%+5               \ instruction

 JMP DEATH2             \ ESCAPE is being pressed, so jump to DEATH2 to end
                        \ the game

 CPX #&7F               \ If DELETE is not being pressed, we are still paused,
 BNE FREEZE             \ so loop back up to keep listening for configuration
                        \ keys, otherwise fall through into the rest of the
                        \ key detection code, which unpauses the game

.DK2

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TIDY
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Orthonormalise the orientation vectors for a ship
\  Deep dive: Tidying orthonormal vectors
\             Orientation vectors
\
\ ------------------------------------------------------------------------------
\
\ This routine orthonormalises the orientation vectors for a ship. This means
\ making the three orientation vectors orthogonal (perpendicular to each other),
\ and normal (so each of the vectors has length 1).
\
\ We do this because we use the small angle approximation to rotate these
\ vectors in space. It is not completely accurate, so the three vectors tend
\ to get stretched over time, so periodically we tidy the vectors with this
\ routine to ensure they remain as orthonormal as possible.
\
\ ******************************************************************************

.TI2

                        \ Called from below with A = 0, X = 0, Y = 4 when
                        \ nosev_x and nosev_y are small, so we assume that
                        \ nosev_z is big

 TYA                    \ A = Y = 4
 LDY #2
 JSR TIS3               \ Call TIS3 with X = 0, Y = 2, A = 4, to set roofv_z =
 STA INWK+20            \ -(nosev_x * roofv_x + nosev_y * roofv_y) / nosev_z

 JMP TI3                \ Jump to TI3 to keep tidying

.TI1

                        \ Called from below with A = 0, Y = 4 when nosev_x is
                        \ small

 TAX                    \ Set X = A = 0

 LDA XX15+1             \ Set A = nosev_y, and if the top two magnitude bits
 AND #%01100000         \ are both clear, jump to TI2 with A = 0, X = 0, Y = 4
 BEQ TI2

 LDA #2                 \ Otherwise nosev_y is big, so set up the index values
                        \ to pass to TIS3

 JSR TIS3               \ Call TIS3 with X = 0, Y = 4, A = 2, to set roofv_y =
 STA INWK+18            \ -(nosev_x * roofv_x + nosev_z * roofv_z) / nosev_y

 JMP TI3                \ Jump to TI3 to keep tidying

.TIDY

 LDA INWK+10            \ Set (XX15, XX15+1, XX15+2) = nosev
 STA XX15
 LDA INWK+12
 STA XX15+1
 LDA INWK+14
 STA XX15+2

 JSR NORM               \ Call NORM to normalise the vector in XX15, i.e. nosev

 LDA XX15               \ Set nosev = (XX15, XX15+1, XX15+2)
 STA INWK+10
 LDA XX15+1
 STA INWK+12
 LDA XX15+2
 STA INWK+14

 LDY #4                 \ Set Y = 4

 LDA XX15               \ Set A = nosev_x, and if the top two magnitude bits
 AND #%01100000         \ are both clear, jump to TI1 with A = 0, Y = 4
 BEQ TI1

 LDX #2                 \ Otherwise nosev_x is big, so set up the index values
 LDA #0                 \ to pass to TIS3

 JSR TIS3               \ Call TIS3 with X = 2, Y = 4, A = 0, to set roofv_x =
 STA INWK+16            \ -(nosev_y * roofv_y + nosev_z * roofv_z) / nosev_x

.TI3

 LDA INWK+16            \ Set (XX15, XX15+1, XX15+2) = roofv
 STA XX15
 LDA INWK+18
 STA XX15+1
 LDA INWK+20
 STA XX15+2

 JSR NORM               \ Call NORM to normalise the vector in XX15, i.e. roofv

 LDA XX15               \ Set roofv = (XX15, XX15+1, XX15+2)
 STA INWK+16
 LDA XX15+1
 STA INWK+18
 LDA XX15+2
 STA INWK+20

 LDA INWK+12            \ Set Q = nosev_y
 STA Q

 LDA INWK+20            \ Set A = roofv_z

 JSR MULT12             \ Set (S R) = Q * A = nosev_y * roofv_z

 LDX INWK+14            \ Set X = nosev_z

 LDA INWK+18            \ Set A = roofv_y

 JSR TIS1               \ Set (A ?) = (-X * A + (S R)) / 96
                        \        = (-nosev_z * roofv_y + nosev_y * roofv_z) / 96
                        \
                        \ This also sets Q = nosev_z

 EOR #%10000000         \ Set sidev_x = -A
 STA INWK+22            \        = (nosev_z * roofv_y - nosev_y * roofv_z) / 96

 LDA INWK+16            \ Set A = roofv_x

 JSR MULT12             \ Set (S R) = Q * A = nosev_z * roofv_x

 LDX INWK+10            \ Set X = nosev_x

 LDA INWK+20            \ Set A = roofv_z

 JSR TIS1               \ Set (A ?) = (-X * A + (S R)) / 96
                        \        = (-nosev_x * roofv_z + nosev_z * roofv_x) / 96
                        \
                        \ This also sets Q = nosev_x

 EOR #%10000000         \ Set sidev_y = -A
 STA INWK+24            \        = (nosev_x * roofv_z - nosev_z * roofv_x) / 96

 LDA INWK+18            \ Set A = roofv_y

 JSR MULT12             \ Set (S R) = Q * A = nosev_x * roofv_y

 LDX INWK+12            \ Set X = nosev_y

 LDA INWK+16            \ Set A = roofv_x

 JSR TIS1               \ Set (A ?) = (-X * A + (S R)) / 96
                        \        = (-nosev_y * roofv_x + nosev_x * roofv_y) / 96

 EOR #%10000000         \ Set sidev_z = -A
 STA INWK+26            \        = (nosev_y * roofv_x - nosev_x * roofv_y) / 96

 LDA #0                 \ Set A = 0 so we can clear the low bytes of the
                        \ orientation vectors

 LDX #14                \ We want to clear the low bytes, so start from sidev_y
                        \ at byte #9+14 (we clear all except sidev_z_lo, though
                        \ I suspect this is in error and that X should be 16)

.TIL1

 STA INWK+9,X           \ Set the low byte in byte #9+X to zero

 DEX                    \ Set X = X - 2 to jump down to the next low byte
 DEX

 BPL TIL1               \ Loop back until we have zeroed all the low bytes

 RTS                    \ Return from the subroutine

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

 LDX #%11111110         \ Set T to have bits 1-7 set, so we can rotate through 7
 STX T                  \ loop iterations, getting a 1 each time, and then
                        \ getting a 0 on the 8th iteration... and we can also
                        \ use T to catch our result bits into bit 0 each time

.TIL2

 ASL A                  \ Shift A to the left

 CMP Q                  \ If A < Q skip the following subtraction
 BCC P%+4

 SBC Q                  \ A >= Q, so set A = A - Q
                        \
                        \ Going into this subtraction we know the C flag is
                        \ set as we passed through the BCC above, and we also
                        \ know that A >= Q, so the C flag will still be set once
                        \ we are done

 ROL T                  \ Rotate the counter in T to the left, and catch the
                        \ result bit into bit 0 (which will be a 0 if we didn't
                        \ do the subtraction, or 1 if we did)

 BCS TIL2               \ If we still have set bits in T, loop back to TIL2 to
                        \ do the next iteration of 7

                        \ We've done the division and now have a result in the
                        \ range 0-255 here, which we need to reduce to the range
                        \ 0-96. We can do that by multiplying the result by 3/8,
                        \ as 256 * 3/8 = 96

 LDA T                  \ Set T = T / 4
 LSR A
 LSR A
 STA T

 LSR A                  \ Set T = T / 8 + T / 4
 ADC T                  \       = 3T / 8
 STA T

 TYA                    \ Fetch the sign bit of the original argument A
 AND #%10000000

 ORA T                  \ Apply the sign bit to T

 RTS                    \ Return from the subroutine

.TI4

 TYA                    \ Fetch the sign bit of the original argument A
 AND #%10000000

 ORA #96                \ Apply the sign bit to 96 (which represents 1)

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TIS3
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate -(nosev_1 * roofv_1 + nosev_2 * roofv_2) / nosev_3
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following expression:
\
\   A = -(nosev_1 * roofv_1 + nosev_2 * roofv_2) / nosev_3
\
\ where 1, 2 and 3 are x, y, or z, depending on the values of X, Y and A. This
\ routine is called with the following values:
\
\   X = 0, Y = 2, A = 4 ->
\         A = -(nosev_x * roofv_x + nosev_y * roofv_y) / nosev_z
\
\   X = 0, Y = 4, A = 2 ->
\         A = -(nosev_x * roofv_x + nosev_z * roofv_z) / nosev_y
\
\   X = 2, Y = 4, A = 0 ->
\         A = -(nosev_y * roofv_y + nosev_z * roofv_z) / nosev_x
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   Index 1 (0 = x, 2 = y, 4 = z)
\
\   Y                   Index 2 (0 = x, 2 = y, 4 = z)
\
\   A                   Index 3 (0 = x, 2 = y, 4 = z)
\
\ ******************************************************************************

.TIS3

 STA P+2                \ Store P+2 in A for later

 LDA INWK+10,X          \ Set Q = nosev_x_hi (plus X)
 STA Q

 LDA INWK+16,X          \ Set A = roofv_x_hi (plus X)

 JSR MULT12             \ Set (S R) = Q * A
                        \           = nosev_x_hi * roofv_x_hi

 LDX INWK+10,Y          \ Set Q = nosev_x_hi (plus Y)
 STX Q

 LDA INWK+16,Y          \ Set A = roofv_x_hi (plus Y)

 JSR MAD                \ Set (A X) = Q * A + (S R)
                        \           = (nosev_x,X * roofv_x,X) +
                        \             (nosev_x,Y * roofv_x,Y)

 STX P                  \ Store low byte of result in P, so result is now in
                        \ (A P)

 LDY P+2                \ Set Q = roofv_x_hi (plus argument A)
 LDX INWK+10,Y
 STX Q

 EOR #%10000000         \ Flip the sign of A

                        \ Fall through into DIVDT to do:
                        \
                        \   (P+1 A) = (A P) / Q
                        \
                        \     = -((nosev_x,X * roofv_x,X) +
                        \         (nosev_x,Y * roofv_x,Y))
                        \       / nosev_x,A

\ ******************************************************************************
\
\       Name: DVIDT
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (P+1 A) = (A P) / Q
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following integer division between sign-magnitude numbers:
\
\   (P+1 A) = (A P) / Q
\
\ This uses the same shift-and-subtract algorithm as TIS2.
\
\ ******************************************************************************

.DVIDT

 STA P+1                \ Set P+1 = A, so P(1 0) = (A P)

 EOR Q                  \ Set T = the sign bit of A EOR Q, so it's 1 if A and Q
 AND #%10000000         \ have different signs, i.e. it's the sign of the result
 STA T                  \ of A / Q

 LDA #0                 \ Set A = 0 for us to build a result

 LDX #16                \ Set a counter in X to count the 16 bits in P(1 0)

 ASL P                  \ Shift P(1 0) left
 ROL P+1

 ASL Q                  \ Clear the sign bit of Q the C flag at the same time
 LSR Q

.DVL2

 ROL A                  \ Shift A to the left

 CMP Q                  \ If A < Q skip the following subtraction
 BCC P%+4

 SBC Q                  \ Set A = A - Q
                        \
                        \ Going into this subtraction we know the C flag is
                        \ set as we passed through the BCC above, and we also
                        \ know that A >= Q, so the C flag will still be set once
                        \ we are done

 ROL P                  \ Rotate P(1 0) to the left, and catch the result bit
 ROL P+1                \ into the C flag (which will be a 0 if we didn't
                        \ do the subtraction, or 1 if we did)

 DEX                    \ Decrement the loop counter

 BNE DVL2               \ Loop back for the next bit until we have done all 16
                        \ bits of P(1 0)

 LDA P                  \ Set A = P so the low byte is in the result in A

 ORA T                  \ Set A to the correct sign bit that we set in T above

.itsoff

 RTS                    \ Return from the subroutine
