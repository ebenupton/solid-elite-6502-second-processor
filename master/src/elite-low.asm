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

\ Port: TIS2 moved to the main code (elite-flight.asm), fully unrolled

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

\ ******************************************************************************
\
\       Name: DOCKIT
\       Type: Subroutine
\   Category: Flight
\    Summary: Apply docking manoeuvres to the ship in INWK
\  Deep dive: The docking computer
\
\ ******************************************************************************

.DOCKIT

 LDA #6                 \ Set RAT2 = 6, which is the threshold below which we
 STA RAT2               \ don't apply pitch and roll to the ship (so a lower
                        \ value means we apply pitch and roll more often, and a
                        \ value of 0 means we always apply them). The value is
                        \ compared with double the high byte of sidev . XX15,
                        \ where XX15 is the vector from the ship to the station

 LSR A                  \ Set RAT = 2, which is the magnitude we set the pitch
 STA RAT                \ or roll counter to in part 7 when turning a ship
                        \ towards a vector (a higher value giving a longer
                        \ turn)

 LDA #29                \ Set CNT2 = 29, which is the maximum angle beyond which
 STA CNT2               \ a ship will slow down to start turning towards its
                        \ prey (a lower value means a ship will start to slow
                        \ down even if its angle with the enemy ship is large,
                        \ which gives a tighter turn)

 LDA SSPR               \ If we are inside the space station safe zone, skip the
 BNE P%+5               \ next instruction

.GOPLS

 JMP GOPL               \ Jump to GOPL to make the ship head towards the planet

 JSR VCSU1              \ If we get here then we are in the space station safe
                        \ zone, so call VCSU1 to calculate the following, where
                        \ the station is at coordinates (station_x, station_y,
                        \ station_z):
                        \
                        \   K3(2 1 0) = (x_sign x_hi x_lo) - station_x
                        \
                        \   K3(5 4 3) = (y_sign y_hi z_lo) - station_y
                        \
                        \   K3(8 7 6) = (z_sign z_hi z_lo) - station_z
                        \
                        \ so K3 contains the vector from the station to the ship

 LDA K3+2               \ If any of the top bytes of the K3 results above are
 ORA K3+5               \ non-zero (after removing the sign bits), jump to GOPL
 ORA K3+8               \ via GOPLS to make the ship head towards the planet, as
 AND #%01111111         \ this will aim the ship in the general direction of the
 BNE GOPLS              \ station (it's too far away for anything more accurate)

 JSR TA2                \ Call TA2 to calculate the length of the vector in K3
                        \ (ignoring the low coordinates), returning it in Q

 LDA Q                  \ Store the value of Q in K, so K now contains the
 STA K                  \ distance between station and the ship

 JSR TAS2               \ Call TAS2 to normalise the vector in K3, returning the
                        \ normalised version in XX15, so XX15 contains the unit
                        \ vector pointing from the station to the ship

 LDY #10                \ Call TAS4 to calculate:
 JSR TAS4               \
                        \   (A X) = nosev . XX15
                        \
                        \ where nosev is the nose vector of the space station,
                        \ so this is the dot product of the station to ship
                        \ vector with the station's nosev (which points straight
                        \ out into space, out of the docking slot), and because
                        \ both vectors are unit vectors, the following is also
                        \ true:
                        \
                        \   (A X) = cos(t)
                        \
                        \ where t is the angle between the two vectors
                        \
                        \ If the dot product is positive, that means the vector
                        \ from the station to the ship and the nosev sticking
                        \ out of the docking slot are facing in a broadly
                        \ similar direction (so the ship is essentially heading
                        \ for the slot, which is facing towards the ship), and
                        \ if it's negative they are facing in broadly opposite
                        \ directions (so the station slot is on the opposite
                        \ side of the station as the ship approaches)

 BMI PH1                \ If the dot product is negative, i.e. the station slot
                        \ is on the opposite side, jump to PH1 to fly towards
                        \ the ideal docking position, some way in front of the
                        \ slot

 CMP #35                \ If the dot product < 35, jump to PH1 to fly towards
 BCC PH1                \ the ideal docking position, some way in front of the
                        \ slot, as there is a large angle between the vector
                        \ from the station to the ship and the station's nosev,
                        \ so the angle of approach is not very optimal
                        \
                        \ Specifically, as the unit vector length is 96 in our
                        \ vector system,
                        \
                        \   (A X) = cos(t) < 35 / 96
                        \
                        \ so:
                        \
                        \   t > arccos(35 / 96) = 68.6 degrees
                        \
                        \ so the ship is coming in from the side of the station
                        \ at an angle between 68.6 and 90 degrees off the
                        \ optimal entry angle

                        \ If we get here, the slot is on the same side as the
                        \ ship and the angle of approach is less than 68.6
                        \ degrees, so we're heading in pretty much the correct
                        \ direction for a good approach to the docking slot

 LDY #10                \ Call TAS3 to calculate:
 JSR TAS3               \
                        \   (A X) = nosev . XX15
                        \
                        \ where nosev is the nose vector of the ship, so this is
                        \ the dot product of the station to ship vector with the
                        \ ship's nosev, and is a measure of how close to the
                        \ station the ship is pointing, with negative meaning it
                        \ is pointing at the station, and positive meaning it is
                        \ pointing away from the station

 CMP #&A2               \ If the dot product is in the range 0 to -34, jump to
 BCS PH3                \ PH3 to refine our approach, as we are pointing towards
                        \ the station

                        \ If we get here, then we are not pointing straight at
                        \ the station, so check how close we are

 LDA K                  \ Fetch the distance to the station into A

\BEQ PH10               \ This instruction is commented out in the original
                        \ source

 CMP #157               \ If A < 157, jump to PH2 to turn away from the station,
 BCC PH2                \ as we are too close

 LDA TYPE               \ Fetch the ship type into A

 BMI PH3                \ If bit 7 is set, then that means the ship type was set
                        \ to -96 in the DOKEY routine when we switched on our
                        \ docking computer, so this is us auto-docking our
                        \ Cobra, so jump to PH3 to refine our approach
                        \
                        \ Otherwise this is an NPC trying to dock, so keep going
                        \ to turn away from the station

.PH2

                        \ If we get here then we turn away from the station and
                        \ slow right down, effectively aborting this approach
                        \ attempt

 JSR TAS6               \ Call TAS6 to negate the vector in XX15 so it points in
                        \ the opposite direction, away from the station and
                        \ towards the ship

 JSR TA151              \ Call TA151 to make the ship head in the direction of
                        \ XX15, which makes the ship turn away from the station

.PH22

                        \ If we get here then we slam on the brakes and slow
                        \ right down

 LDX #0                 \ Set the acceleration in byte #28 to 0
 STX INWK+28

 INX                    \ Set the speed in byte #28 to 1
 STX INWK+27

 RTS                    \ Return from the subroutine

.PH1

                        \ If we get here then the slot is on the opposite side
                        \ of the station to the ship, or it's on the same side
                        \ and the approach angle is not optimal, so we just fly
                        \ towards the station, aiming for the ideal docking
                        \ position some distance in front of the slot

 JSR VCSU1              \ Call VCSU1 to set K3 to the vector from the station to
                        \ the ship

 JSR DCS1               \ Call DCS1 twice to calculate the vector from the ideal
 JSR DCS1               \ docking position to the ship, where the ideal docking
                        \ position is straight out of the docking slot at a
                        \ distance of 8 unit vectors from the centre of the
                        \ station

 JSR TAS2               \ Call TAS2 to normalise the vector in K3, returning the
                        \ normalised version in XX15

 JSR TAS6               \ Call TAS6 to negate the vector in XX15 so it points in
                        \ the opposite direction

 JMP TA151              \ Call TA151 to make the ship head in the direction of
                        \ XX15, which makes the ship turn towards the ideal
                        \ docking position, and return from the subroutine using
                        \ a tail call

.TN11

                        \ If we get here, we accelerate and apply a full
                        \ clockwise roll (which matches the space station's
                        \ roll)

 INC INWK+28            \ Increment the acceleration in byte #28

 LDA #%01111111         \ Set the roll counter to a positive (clockwise) roll
 STA INWK+29            \ with no damping, to match the space station's roll

 BNE TN13               \ Jump down to TN13 (this BNE is effectively a JMP as
                        \ A will never be zero)

.PH3

                        \ If we get here, we refine our approach using pitch and
                        \ roll to aim for the station

 LDX #0                 \ Set RAT2 = 0 so we always apply roll and pitch when we
 STX RAT2               \ refine the ship's approach

 STX INWK+30            \ Set the pitch counter to 0 to stop any pitching

 LDA TYPE               \ If this is not our ship's docking computer, but is an
 BPL PH32               \ NPC ship trying to dock, jump to PH32

                        \ In the following, ship_x and ship_y are the x and
                        \ y-coordinates of XX15, the vector from the station to
                        \ the ship

 EOR XX15               \ A is negative, so this sets the sign of A to the same
 EOR XX15+1             \ as -XX15 * XX15+1, or -ship_x * ship_y

 ASL A                  \ Shift the sign bit into the C flag, so the C flag has
                        \ the following sign:
                        \
                        \   * Positive if ship_x and ship_y have different signs
                        \   * Negative if ship_x and ship_y have the same sign

 LDA #2                 \ Set A = +2 or -2, giving it the sign in the C flag,
 ROR A                  \ and store it in byte #29, the roll counter, so that
 STA INWK+29            \ the ship rolls towards the station

 LDA XX15               \ If |ship_x * 2| >= 12, i.e. |ship_x| >= 6, then jump
 ASL A                  \ to PH22 to slow right down and return from the
 CMP #12                \ subroutine, as the station is not in our sights
 BCS PH22

 LDA XX15+1             \ Set A = +2 or -2, giving it the same sign as ship_y,
 ASL A                  \ and store it in byte #30, the pitch counter, so that
 LDA #2                 \ the ship pitches towards the station
 ROR A
 STA INWK+30

 LDA XX15+1             \ If |ship_y * 2| >= 12, i.e. |ship_y| >= 6, then jump
 ASL A                  \ to PH22 to slow right down and return from the
 CMP #12                \ subroutine, as the station is not in our sights
 BCS PH22

.PH32

                        \ If we get here, we try to match the station roll

 STX INWK+29            \ Set the roll counter to 0 to stop any pitching

 LDA INWK+22            \ Set XX15 = sidev_x_hi
 STA XX15

 LDA INWK+24            \ Set XX15+1 = sidev_y_hi
 STA XX15+1

 LDA INWK+26            \ Set XX15+2 = sidev_z_hi
 STA XX15+2             \
                        \ so XX15 contains the sidev vector of the ship

 LDY #16                \ Call TAS4 to calculate:
 JSR TAS4               \
                        \   (A X) = roofv . XX15
                        \
                        \ where roofv is the roof vector of the space station.
                        \ To dock with the slot horizontal, we want roofv to be
                        \ pointing off to the side, i.e. parallel to the ship's
                        \ sidev vector, which means we want the dot product to
                        \ be large (it can be positive or negative, as roofv can
                        \ point left or right - it just needs to be parallel to
                        \ the ship's sidev)

 ASL A                  \ If |A * 2| >= 66, i.e. |A| >= 33, then the ship is
 CMP #66                \ lined up with the slot, so jump to TN11 to accelerate
 BCS TN11               \ and roll clockwise (a positive roll) before jumping
                        \ down to TN13 to check if we're docked yet

 JSR PH22               \ Call PH22 to slow right down, as we haven't yet
                        \ matched the station's roll

.TN13

                        \ If we get here, we check to see if we have docked

 LDA K3+10              \ If K3+10 is non-zero, skip to TNRTS, to return from
 BNE TNRTS              \ the subroutine
                        \
                        \ I have to say I have no idea what K3+10 contains, as
                        \ it isn't mentioned anywhere in the whole codebase
                        \ apart from here, but it does share a location with
                        \ XX2+10, so it will sometimes be non-zero (specifically
                        \ when face #10 in the ship we're drawing is visible,
                        \ which probably happens quite a lot). This would seem
                        \ to affect whether an NPC ship can dock, as that's the
                        \ code that gets skipped if K3+10 is non-zero, but as
                        \ to what this means... that's not yet clear

 ASL NEWB               \ Set bit 7 of the ship's NEWB flags to indicate that
 SEC                    \ the ship has now docked, which only has meaning if
 ROR NEWB               \ this is an NPC trying to dock

.TNRTS

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: VCSU1
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate vector K3(8 0) = [x y z] - coordinates of the sun or
\             space station
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following:
\
\   K3(2 1 0) = (x_sign x_hi x_lo) - x-coordinate of the sun or space station
\
\   K3(5 4 3) = (y_sign y_hi z_lo) - y-coordinate of the sun or space station
\
\   K3(8 7 6) = (z_sign z_hi z_lo) - z-coordinate of the sun or space station
\
\ where the first coordinate is from the ship data block in INWK, and the second
\ coordinate is from the sun or space station's ship data block which they
\ share.
\
\ ******************************************************************************

.VCSU1

 LDA #LO(K%+NI%)        \ Set the low byte of V(1 0) to point to the coordinates
 STA V                  \ of the sun or space station

 LDA #HI(K%+NI%)        \ Set A to the high byte of the address of the
                        \ coordinates of the sun or space station

                        \ Fall through into VCSUB to calculate:
                        \
                        \   K3(2 1 0) = (x_sign x_hi x_lo) - x-coordinate of sun
                        \               or space station
                        \
                        \   K3(2 1 0) = (x_sign x_hi x_lo) - x-coordinate of sun
                        \               or space station
                        \
                        \   K3(8 7 6) = (z_sign z_hi z_lo) - z-coordinate of sun
                        \               or space station

\ ******************************************************************************
\
\       Name: VCSUB
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate vector K3(8 0) = [x y z] - coordinates in (A V)
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following:
\
\   K3(2 1 0) = (x_sign x_hi x_lo) - x-coordinate in (A V)
\
\   K3(5 4 3) = (y_sign y_hi z_lo) - y-coordinate in (A V)
\
\   K3(8 7 6) = (z_sign z_hi z_lo) - z-coordinate in (A V)
\
\ where the first coordinate is from the ship data block in INWK, and the second
\ coordinate is from the ship data block pointed to by (A V).
\
\ ******************************************************************************

.VCSUB

 STA V+1                \ Set the low byte of V(1 0) to A, so now V(1 0) = (A V)

 LDY #2                 \ K3(2 1 0) = (x_sign x_hi x_lo) - x-coordinate in data
 JSR TAS1               \ block at V(1 0)

 LDY #5                 \ K3(5 4 3) = (y_sign y_hi z_lo) - y-coordinate of data
 JSR TAS1               \ block at V(1 0)

 LDY #8                 \ Fall through into TAS1 to calculate the final result:
                        \
                        \ K3(8 7 6) = (z_sign z_hi z_lo) - z-coordinate of data
                        \ block at V(1 0)

\ ******************************************************************************
\
\       Name: TAS1
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate K3 = (x_sign x_hi x_lo) - V(1 0)
\
\ ------------------------------------------------------------------------------
\
\ Calculate one of the following, depending on the value in Y:
\
\   K3(2 1 0) = (x_sign x_hi x_lo) - x-coordinate in V(1 0)
\
\   K3(5 4 3) = (y_sign y_hi z_lo) - y-coordinate in V(1 0)
\
\   K3(8 7 6) = (z_sign z_hi z_lo) - z-coordinate in V(1 0)
\
\ where the first coordinate is from the ship data block in INWK, and the second
\ coordinate is from the ship data block pointed to by V(1 0).
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   V(1 0)              The address of the ship data block to subtract
\
\   Y                   The coordinate in the V(1 0) block to subtract:
\
\                         * If Y = 2, subtract the x-coordinate and store the
\                           result in K3(2 1 0)
\
\                         * If Y = 5, subtract the y-coordinate and store the
\                           result in K3(5 4 3)
\
\                         * If Y = 8, subtract the z-coordinate and store the
\                           result in K3(8 7 6)
\
\ ******************************************************************************

.TAS1

 LDA (V),Y              \ Copy the sign byte of the V(1 0) coordinate into K+3,
 EOR #%10000000         \ flipping it in the process
 STA K+3

 DEY                    \ Copy the high byte of the V(1 0) coordinate into K+2
 LDA (V),Y
 STA K+2

 DEY                    \ Copy the high byte of the V(1 0) coordinate into K+1,
 LDA (V),Y              \ so now:
 STA K+1                \
                        \   K(3 2 1) = - coordinate in V(1 0)

 STY U                  \ Copy the index (now 0, 3 or 6) into U and X
 LDX U

 JSR MVT3               \ Call MVT3 to add the same coordinates, but this time
                        \ from INWK, so this would look like this for the
                        \ x-axis:
                        \
                        \   K(3 2 1) = (x_sign x_hi x_lo) + K(3 2 1)
                        \            = (x_sign x_hi x_lo) - coordinate in V(1 0)

 LDY U                  \ Restore the index into Y, though this instruction has
                        \ no effect, as Y is not used again, either here or
                        \ following calls to this routine

 STA K3+2,X             \ Store K(3 2 1) in K3+X(2 1 0), starting with the sign
                        \ byte

 LDA K+2                \ And then doing the high byte
 STA K3+1,X

 LDA K+1                \ And finally the low byte
 STA K3,X

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TAS4
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Calculate the dot product of XX15 and one of the space station's
\             orientation vectors
\
\ ------------------------------------------------------------------------------
\
\ Calculate the dot product of the vector in XX15 and one of the space station's
\ orientation vectors, as determined by the value of Y. If vect is the space
\ station orientation vector, we calculate this:
\
\   (A X) = vect . XX15
\         = vect_x * XX15 + vect_y * XX15+1 + vect_z * XX15+2
\
\ Technically speaking, this routine can also calculate the dot product between
\ XX15 and the sun's orientation vectors, as the sun and space station share the
\ same ship data slot (the second ship data block at K%). However, the sun
\ doesn't have orientation vectors, so this only gets called when that slot is
\ being used for the space station.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   Y                   The space station's orientation vector:
\
\                         * If Y = 10, calculate nosev . XX15
\
\                         * If Y = 16, calculate roofv . XX15
\
\                         * If Y = 22, calculate sidev . XX15
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   (A X)               The result of the dot product
\
\ ******************************************************************************

.TAS4

 LDX K%+NI%,Y           \ Set Q = the Y-th byte of K%+NI%, i.e. vect_x from the
 STX Q                  \ second ship data block at K%

 LDA XX15               \ Set A = XX15

 JSR MULT12             \ Set (S R) = Q * A
                        \           = vect_x * XX15

 LDX K%+NI%+2,Y         \ Set Q = the Y+2-th byte of K%+NI%, i.e. vect_y
 STX Q

 LDA XX15+1             \ Set A = XX15+1

 JSR MAD                \ Set (A X) = Q * A + (S R)
                        \           = vect_y * XX15+1 + vect_x * XX15

 STA S                  \ Set (S R) = (A X)
 STX R

 LDX K%+NI%+4,Y         \ Set Q = the Y+4-th byte of K%+NI%, i.e. vect_z
 STX Q

 LDA XX15+2             \ Set A = XX15+2

 JMP MAD                \ Set:
                        \
                        \   (A X) = Q * A + (S R)
                        \           = vect_z * XX15+2 + vect_y * XX15+1 +
                        \             vect_x * XX15
                        \
                        \ and return from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: TAS6
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Negate the vector in XX15 so it points in the opposite direction
\
\ ******************************************************************************

.TAS6

 LDA XX15               \ Reverse the sign of the x-coordinate of the vector in
 EOR #%10000000         \ XX15
 STA XX15

 LDA XX15+1             \ Then reverse the sign of the y-coordinate
 EOR #%10000000
 STA XX15+1

 LDA XX15+2             \ And then the z-coordinate, so now the XX15 vector is
 EOR #%10000000         \ pointing in the opposite direction
 STA XX15+2

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: DCS1
\       Type: Subroutine
\   Category: Flight
\    Summary: Calculate the vector from the ideal docking position to the ship
\
\ ------------------------------------------------------------------------------
\
\ This routine is called by the docking computer routine in DOCKIT. It works out
\ the vector between the ship and the ideal docking position, which is straight
\ in front of the docking slot, but some distance away.
\
\ Specifically, it calculates the following:
\
\   * K3(2 1 0) = K3(2 1 0) - nosev_x_hi * 4
\
\   * K3(5 4 3) = K3(5 4 3) - nosev_y_hi * 4
\
\   * K3(8 7 6) = K3(8 7 6) - nosev_x_hi * 4
\
\ where K3 is the vector from the station to the ship, and nosev is the nose
\ vector for the space station.
\
\ The nose vector points from the centre of the station through the slot, so
\ -nosev * 4 is the vector from a point in front of the docking slot, but some
\ way from the station, back to the centre of the station. Adding this to the
\ vector from the station to the ship gives the vector from the point in front
\ of the station to the ship.
\
\ In practice, this routine is called twice, so the ideal docking position is
\ actually at a distance of 8 unit vectors from the centre of the station.
\
\ Back in DOCKIT, we flip this vector round to get the vector from the ship to
\ the point in front of the station slot.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   K3                  The vector from the station to the ship
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   K3                  The vector from the ship to the ideal docking position
\                       (4 unit vectors from the centre of the station for each
\                       call to DCS1, so two calls will return the vector to a
\                       point that's 8 unit vectors from the centre of the
\                       station)
\
\ ******************************************************************************

.DCS1

 JSR P%+3               \ Run the following routine twice, so the subtractions
                        \ are all * 4

 LDA K%+NI%+10          \ Set A to the space station's byte #10, nosev_x_hi

 LDX #0                 \ Set K3(2 1 0) = K3(2 1 0) - A * 2
 JSR TAS7               \               = K3(2 1 0) - nosev_x_hi * 2

 LDA K%+NI%+12          \ Set A to the space station's byte #12, nosev_y_hi

 LDX #3                 \ Set K3(5 4 3) = K3(5 4 3) - A * 2
 JSR TAS7               \               = K3(5 4 3) - nosev_y_hi * 2

 LDA K%+NI%+14          \ Set A to the space station's byte #14, nosev_z_hi

 LDX #6                 \ Set K3(8 7 6) = K3(8 7 6) - A * 2
                        \               = K3(8 7 6) - nosev_x_hi * 2

.TAS7

                        \ This routine subtracts A * 2 from one of the K3
                        \ coordinates, as determined by the value of X:
                        \
                        \   * X = 0, set K3(2 1 0) = K3(2 1 0) - A * 2
                        \
                        \   * X = 3, set K3(5 4 3) = K3(5 4 3) - A * 2
                        \
                        \   * X = 6, set K3(8 7 6) = K3(8 7 6) - A * 2
                        \
                        \ Let's document it for X = 0, i.e. K3(2 1 0)

 ASL A                  \ Shift A left one place and move the sign bit into the
                        \ C flag, so A = |A * 2|

 STA R                  \ Set R = |A * 2|

 LDA #0                 \ Rotate the sign bit of A from the C flag into the sign
 ROR A                  \ bit of A, so A is now just the sign bit from the
                        \ original value of A. This also clears the C flag

 EOR #%10000000         \ Flip the sign bit of A, so it has the sign of -A

 EOR K3+2,X             \ Give A the correct sign of K3(2 1 0) * -A

 BMI TS71               \ If the sign of K3(2 1 0) * -A is negative, jump to
                        \ TS71, as K3(2 1 0) and A have the same sign

                        \ If we get here then K3(2 1 0) and A have different
                        \ signs, so we can add them to do the subtraction

 LDA R                  \ Set K3(2 1 0) = K3(2 1 0) + R
 ADC K3,X               \               = K3(2 1 0) + |A * 2|
 STA K3,X               \
                        \ starting with the low bytes

 BCC TS72               \ If the above addition didn't overflow, we have the
                        \ result we want, so jump to TS72 to return from the
                        \ subroutine

 INC K3+1,X             \ The above addition overflowed, so increment the high
                        \ byte of K3(2 1 0)

.TS72

 RTS                    \ Return from the subroutine

.TS71

                        \ If we get here, then K3(2 1 0) and A have the same
                        \ sign

 LDA K3,X               \ Set K3(2 1 0) = K3(2 1 0) - R
 SEC                    \               = K3(2 1 0) - |A * 2|
 SBC R                  \
 STA K3,X               \ starting with the low bytes

 LDA K3+1,X             \ And then the high bytes
 SBC #0
 STA K3+1,X

 BCS TS72               \ If the subtraction didn't underflow, we have the
                        \ result we want, so jump to TS72 to return from the
                        \ subroutine

 LDA K3,X               \ Negate the result in K3(2 1 0) by flipping all the
 EOR #%11111111         \ bits and adding 1, i.e. using two's complement to
 ADC #1                 \ give it the opposite sign, starting with the low
 STA K3,X               \ bytes

 LDA K3+1,X             \ Then doing the high bytes
 EOR #%11111111
 ADC #0
 STA K3+1,X

 LDA K3+2,X             \ And finally, flipping the sign bit
 EOR #%10000000
 STA K3+2,X

 JMP TS72               \ Jump to TS72 to return from the subroutine

\ ******************************************************************************
\
\       Name: HITCH
\       Type: Subroutine
\   Category: Tactics
\    Summary: Work out if the ship in INWK is in our crosshairs
\  Deep dive: In the crosshairs
\
\ ------------------------------------------------------------------------------
\
\ This is called by the main flight loop to see if we have laser or missile lock
\ on an enemy ship.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              Set if the ship is in our crosshairs, clear if it isn't
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   HI1                 Contains an RTS
\
\ ******************************************************************************

.HITCH

 CLC                    \ Clear the C flag so we can return with it cleared if
                        \ our checks fail

 LDA INWK+8             \ Set A = z_sign

 BNE HI1                \ If A is non-zero then the ship is behind us and can't
                        \ be in our crosshairs, so return from the subroutine
                        \ with the C flag clear (as HI1 contains an RTS)

 LDA TYPE               \ If the ship type has bit 7 set then it is the planet
 BMI HI1                \ or sun, which we can't target or hit with lasers, so
                        \ return from the subroutine with the C flag clear (as
                        \ HI1 contains an RTS)

 LDA INWK+31            \ Fetch bit 5 of byte #31 (the exploding flag) and OR
 AND #%00100000         \ with x_hi and y_hi
 ORA INWK+1
 ORA INWK+4

 BNE HI1                \ If this value is non-zero then either the ship is
                        \ exploding (so we can't target it), or the ship is too
                        \ far away from our line of fire to be targeted, so
                        \ return from the subroutine with the C flag clear (as
                        \ HI1 contains an RTS)

 LDA INWK               \ Set A = x_lo

 JSR SQUA2              \ Set (A P) = A * A = x_lo^2

 STA S                  \ Set (S R) = (A P) = x_lo^2
 LDA P
 STA R

 LDA INWK+3             \ Set A = y_lo

 JSR SQUA2              \ Set (A P) = A * A = y_lo^2

 TAX                    \ Store the high byte in X

 LDA P                  \ Add the two low bytes, so:
 ADC R                  \
 STA R                  \   R = P + R

 TXA                    \ Restore the high byte into A and add S to give the
 ADC S                  \ following:
                        \
                        \   (A R) = (S R) + (A P) = x_lo^2 + y_lo^2

 BCS TN10               \ If the addition just overflowed then there is no way
                        \ our crosshairs are within the ship's targetable area,
                        \ so return from the subroutine with the C flag clear
                        \ (as TN10 contains a CLC then an RTS)

 STA S                  \ Set (S R) = (A P) = x_lo^2 + y_lo^2

 LDY #2                 \ Fetch the ship's blueprint and set A to the high byte
 LDA (XX0),Y            \ of the targetable area of the ship

 CMP S                  \ We now compare the high bytes of the targetable area
                        \ and the calculation in (S R):
                        \
                        \   * If A >= S then then the C flag will be set
                        \
                        \   * If A < S then the C flag will be C clear

 BNE HI1                \ If A <> S we have just set the C flag correctly, so
                        \ return from the subroutine (as HI1 contains an RTS)

 DEY                    \ The high bytes were identical, so now we fetch the
 LDA (XX0),Y            \ low byte of the targetable area into A

 CMP R                  \ We now compare the low bytes of the targetable area
                        \ and the calculation in (S R):
                        \
                        \   * If A >= R then the C flag will be set
                        \
                        \   * If A < R then the C flag will be C clear

.HI1

 RTS                    \ Return from the subroutine

.TN10

 CLC                    \ Clear the C flag to indicate the ship is not in our
                        \ crosshairs

 RTS                    \ Return from the subroutine

\ Port: FRS1, FRMIS, ANGRY and FR1 moved to the cold area (elite-cold7.asm,
\ ANGRY in elite-andy.asm); their stubs:

.FRMIS
 JSR far7
 EQUW FRMIS_C

.ANGRY
 JSR far7
 EQUW ANGRY_C

.fq1
 JSR far7
 EQUW fq1_C

\ Port: SFRMIS moved to bank 5 (elite-cold5.asm)

\ Port: ECMOF moved to bank 5 (elite-cold5.asm)

\ Port: THERE moved to bank 5 (elite-cold5.asm)

\ ******************************************************************************
\
\       Name: MALW
\       Type: Subroutine
\   Category: Main loop
\    Summary: Copy INWK back to a ship's data block, unrolled for slots 0-5
\             (Port: the demo port's CPYOUT, 8a7e690; in the low code for room)
\
\ ******************************************************************************

.MALW

                        \ Port: MAL3's copy of INWK back to the ship's block,
                        \ unrolled for slots 0-5 as MALC (C and V, which the
                        \ main loop still needs, are left alone)

 LDX XSAV               \ Set Y = NI% * slot, the block's offset in K%, or &FF
 LDY malct,X            \ for slots 6 and up, which go back to MAL3's loop
 BPL P%+5
 JMP MAL3s

 FOR i, 0, NI% - 1
  LDA INWK+i            \ Copy byte i of INWK into the block
  STA K%+i,Y
 NEXT

 LDY #&FF               \ Y = &FF, as MAL3's loop leaves it

 JMP MAL3e              \ Rejoin the main loop
