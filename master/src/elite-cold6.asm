\ ******************************************************************************
\
\ elite-cold6.asm - cold game code in bank 6
\
\ Port: flight-rare game code in sideways RAM bank 6, in the frame layer's
\ spare space (gfx-frame.asm, after f_zsave), to make room in main RAM. As
\ for the cold area (elite-far.asm), code outside calls it through 5-byte
\ stubs that keep the routine's name (JSR far6 : EQUW name_C, in the stubs
\ area at &7E00), and it calls code outside through stubs of its own, here:
\
\   .y4_NOISE JSR far4 : EQUW NOISE     call, then page bank 6 back in
\
\ It reads and writes main RAM directly, never bank 4 (bankcheck.py's area
\ "cold6").
\
\ ******************************************************************************

.y4_H_BOMB
 JSR far4
 EQUW H_BOMB

.y4_H_LLINE
 JSR far4
 EQUW H_LLINE

.y4_NOISE
 JSR far4
 EQUW NOISE

.y4_DORND
 JSR far4
 EQUW DORND

\ ******************************************************************************
\
\       Name: BOMBOFF
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw the zig-zag lightning bolt for the energy bomb
\
\ ******************************************************************************

.BOMBOFF_C

 LDA #CYAN              \ Change the current colour to cyan
 STA COL

 LDA QQ11               \ If the current view is non-zero (i.e. not a space
 BNE BOMBR1             \ view), return from the subroutine (as BOMBR1 contains
                        \ an RTS)

 JSR y4_H_BOMB             \ Port: a new bolt for the renderer (gfx-hooks.asm)

 LDY #1                 \ We now want to loop through the 10 (BOMBTBX, BOMBTBY)
                        \ coordinates, drawing a total of 9 lines between them
                        \ to make the lightning effect, so set an index in Y
                        \ to point to the end-point for each line, starting with
                        \ the second coordinate pair

 LDA BOMBTBX            \ Store the first coordinate pair from (BOMBTBX,
 STA XX12               \ BOMBTBY) in (XX12, XX12+1)
 LDA BOMBTBY
 STA XX12+1

.BOMBL1

\JSR CLICK              \ This instruction is commented out in the original
                        \ source

 LDA XX12               \ Set (X1, Y1) = (XX12, XX12+1)
 STA X1                 \
 LDA XX12+1             \ so the start point for this line
 STA Y1

 LDA BOMBTBX,Y          \ Set X2 = Y-th x-coordinate from BOMBTBX
 STA X2

 STA XX12               \ Set XX12 = X2

 LDA BOMBTBY,Y          \ Set Y2 = Y-th y-coordinate from BOMBTBY, so we now
 STA Y2                 \ have:
                        \
                        \   (X2, Y2) = Y-th coordinate from (BOMBTBX, BOMBTBY)

 STA XX12+1             \ Set XX12+1 = Y2, so we now have
                        \
                        \   (XX12, XX12+1) = (X2, Y2)
                        \
                        \ so in the next loop iteration, the start point of the
                        \ line will be the end point of this line, making the
                        \ zig-zag lines all join up like a lightning bolt

 JSR y4_H_LLINE            \ Draw a line from (X1, Y1) to (X2, Y2) (Port: recorded
                        \ for the renderer in record mode, gfx-hooks.asm)

 INY                    \ Increment the loop counter

 CPY #10                \ If Y < 10, loop back until we have drawn all the lines
 BCC BOMBL1

.BOMBR1

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: BOMBEFF2
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Erase the energy bomb zig-zag lightning bolt, make the sound of
\             the energy bomb going off, draw a new bolt and repeat four times
\
\ ******************************************************************************

.BOMBEFF2_C

 JSR P%+3               \ This pair of JSRs runs the following code four times
 JSR BOMBEFF

.BOMBEFF

 LDY #sobomb            \ Call the NOISE routine with Y = 6 to make the sound of
 JSR y4_NOISE              \ an energy bomb going off

 JSR BOMBOFF_C            \ Our energy bomb is going off, so call BOMBOFF to draw
                        \ the current zig-zag lightning bolt, which will erase
                        \ it from the screen

                        \ Fall through into BOMBON to set up and display a new
                        \ zig-zag lightning bolt

\ ******************************************************************************
\
\       Name: BOMBON
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Randomise and draw the energy bomb's zig-zag lightning bolt lines
\
\ ******************************************************************************

.BOMBON_C

 LDY #0                 \ We first need to generate 10 random coordinates for a
                        \ zig-zag lightning bolt, with the x-coordinates in the
                        \ table at BOMBTBX and the y-coordinates in the table at
                        \ BOMBTBY, so set a counter in Y as an index to point at
                        \ each coordinate as we create them
                        \
                        \ Note that we generate the points from right to left,
                        \ so that's high x-coordinate to low x-coordinate

.BOMBL2

 JSR y4_DORND              \ Set A and X to random numbers and reduce A to a
 AND #127               \ random number in the range 0-127

 ADC #3                 \ Add 3 so A is now in the range 3-130, so the smallest
                        \ possible value gives a y-coordinate just below the top
                        \ border, and the highest possible value gives a
                        \ y-coordinate that's around two-thirds of the way down
                        \ the space view

 STA BOMBTBY,Y          \ Store A in the Y-th byte of BOMBTBY, as the
                        \ y-coordinate of the Y-th point in our lightning bolt

 TXA                    \ Fetch the random number from X into A and reduce it to
 AND #31                \ the range 0-31

 CLC                    \ Add the Y-th value from BOMBPOS table, which contains
 ADC BOMBPOS,Y          \ the smallest possible x-coordinate for the Y-th point
                        \ (so the coordinates in the bolt will step along the
                        \ screen from right to left, but with varying step
                        \ sizes)

 STA BOMBTBX,Y          \ Store A in the Y-th byte of BOMBTBX, as the
                        \ x-coordinate of the Y-th point in our lightning bolt

 INY                    \ Increment the loop index

 CPY #10                \ Loop back to generate the next coordinate until we
 BCC BOMBL2             \ have generated all ten

 LDX #0                 \ Set BOMBTBX+9 = 0, so the lightning bolt starts at the
 STX BOMBTBX+9          \ left edge of the screen

 DEX                    \ Set BOMBTBX = 255, so the lightning bolt ends at the
 STX BOMBTBX            \ right edge of the screen

 BCS BOMBOFF_C           \ Call BOMBOFF to draw the newly generated zig-zag
                        \ lightning bolt and return from the subroutine using a
                        \ tail call (this BCS is effectively a JMP as we passed
                        \ through the BCC above)

\ ******************************************************************************
\
\       Name: BOMBPOS
\       Type: Variable
\   Category: Drawing lines
\    Summary: A set of x-coordinates that are used as the basis for the energy
\             bomb's zig-zag lightning bolt
\
\ ******************************************************************************

.BOMBPOS

 EQUB 224
 EQUB 224
 EQUB 192
 EQUB 160
 EQUB 128
 EQUB 96
 EQUB 64
 EQUB 32
 EQUB 0
 EQUB 0
