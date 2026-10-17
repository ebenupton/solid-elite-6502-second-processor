\ ******************************************************************************
\
\ elite-bank4.asm - Elite's game code in its home bank (sideways RAM bank 4)
\
\ Port (docs/MASTER-MAP.md): INCLUDEd by elite-source.asm after the game data
\ that elite-data.asm puts at the start of bank 4. Bank 4 is paged in whenever
\ the game's code runs, so code here and in main RAM call each other and read
\ each other's data directly. Nothing here may be reached by an interrupt or
\ from a MOS vector (the IRQ, WRCHV and BRKV handlers are in main RAM), or
\ called directly from the cold area (it uses far4 stubs).
\
\ ******************************************************************************

\ ******************************************************************************
\
\       Name: ylookup
\       Type: Variable
\   Category: Drawing pixels
\    Summary: Lookup table for converting pixel y-coordinate to page number of
\             screen address
\
\ ------------------------------------------------------------------------------
\
\ Elite's screen mode is based on mode 1, so it allocates two pages of screen
\ memory to each character row (where a character row is 8 pixels high). This
\ table enables us to convert a pixel y-coordinate in the range 0-247 into the
\ page number for the start of the character row containing that coordinate.
\
\ Screen memory is from &4000 to &7DFF, so the lookup works like this:
\
\   Y =   0 to  7,  lookup value = &40 (so row 1 is from &4000 to &41FF)
\   Y =   8 to 15,  lookup value = &42 (so row 2 is from &4200 to &43FF)
\   Y =  16 to 23,  lookup value = &44 (so row 3 is from &4400 to &45FF)
\   Y =  24 to 31,  lookup value = &46 (so row 4 is from &4600 to &47FF)
\
\   ...
\
\   Y = 232 to 239, lookup value = &7A (so row 31 is from &7A00 to &7BFF)
\   Y = 240 to 247, lookup value = &7C (so row 32 is from &7C00 to &7DFF)
\
\ There is also a lookup value for y-coordinates from 248 to 255, but that's off
\ the end of the screen, as the special Elite screen mode only has 31 character
\ rows.
\
\ ******************************************************************************

.ylookup

 FOR I%, 0, 255

  EQUB &40 + ((I% DIV 8) * 2)

 NEXT

\ ******************************************************************************
\
\       Name: LOIN
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw a one-segment line
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X1                  The screen x-coordinate of the start of the line
\
\   Y1                  The screen y-coordinate of the start of the line
\
\   X2                  The screen x-coordinate of the end of the line
\
\   Y2                  The screen y-coordinate of the end of the line
\
\ ******************************************************************************

.LOIN

 STY YSAV               \ Store Y in YSAV so we can retrieve it below

 LDA #%00001111         \ Set bits 1 and 2 of the Access Control Register at
 STA VIA+&34            \ SHEILA &34 to switch screen memory into &3000-&7FFF

 JSR LOINQ              \ Draw a line from (X1, Y1) to (X2, Y2)

 LDA #%00001001         \ Clear bits 1 and 2 of the Access Control Register at
 STA VIA+&34            \ SHEILA &34 to switch main memory back into &3000-&7FFF

 LDY YSAV               \ Retrieve the value of Y we stored above

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TWOS
\       Type: Variable
\   Category: Drawing pixels
\    Summary: Ready-made single-pixel character row bytes for mode 1
\
\ ------------------------------------------------------------------------------
\
\ Ready-made bytes for plotting one-pixel points in mode 1 (the top part of the
\ split screen).
\
\ ******************************************************************************

.TWOS

 EQUB %10001000
 EQUB %01000100
 EQUB %00100010
 EQUB %00010001

\ ******************************************************************************
\
\       Name: TWOS2
\       Type: Variable
\   Category: Drawing pixels
\    Summary: Ready-made double-pixel character row bytes for mode 1
\
\ ------------------------------------------------------------------------------
\
\ Ready-made bytes for plotting two-pixel dashes in mode 1 (the top part of the
\ split screen).
\
\ ******************************************************************************

.TWOS2

 EQUB %11001100
 EQUB %01100110
 EQUB %00110011
 EQUB %00110011

\ ******************************************************************************
\
\       Name: LOINQ (Part 1 of 7)
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw a line: Calculate the line gradient in the form of deltas
\  Deep dive: Elite's line-drawing algorithm
\
\ ------------------------------------------------------------------------------
\
\ This routine draws a line from (X1, Y1) to (X2, Y2). It has multiple stages.
\ This stage calculates the line deltas.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X1                  The screen x-coordinate of the start of the line
\
\   Y1                  The screen y-coordinate of the start of the line
\
\   X2                  The screen x-coordinate of the end of the line
\
\   Y2                  The screen y-coordinate of the end of the line
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   LOINQ               Draw a one-segment line from (X1, Y1) to (X2, Y2)
\
\ ******************************************************************************

.HLOIN22

 JMP HLOIN3             \ This instruction doesn't appear to be used anywhere

                        \ In the BBC Micro cassette and disc versions of Elite,
                        \ LL30 and LOIN are synonyms for the same routine,
                        \ presumably because the two developers each had their
                        \ own line routines to start with, and then chose one of
                        \ them for the final game
                        \
                        \ In the BBC Master version, there are two different
                        \ routines: LOINQ draws a one-segment line, while LOIN
                        \ draws individual segments of multi-segment lines (the
                        \ distinction being that we switch to screen memory at
                        \ the start of LOINQ and back out again after drawing
                        \ the line, while LOIN just draws the line)

.LOINQ

 LDA #128               \ Set S = 128, which is the starting point for the
 STA S                  \ slope error (representing half a pixel)

 ASL A                  \ Set SWAP = 0, as %10000000 << 1 = 0
 STA SWAP

 LDA X2                 \ Set A = X2 - X1
 SBC X1                 \       = delta_x
                        \
                        \ This subtraction works as the ASL A above sets the C
                        \ flag

 BCS LI1                \ If X2 > X1 then A is already positive and we can skip
                        \ the next three instructions

 EOR #%11111111         \ Negate the result in A by flipping all the bits and
 ADC #1                 \ adding 1, i.e. using two's complement to make it
                        \ positive

 SEC                    \ Set the C flag, ready for the subtraction below

.LI1

 STA P                  \ Store A in P, so P = |X2 - X1|, or |delta_x|

 LDA Y2                 \ Set A = Y2 - Y1
 SBC Y1                 \       = delta_y
                        \
                        \ This subtraction works as we either set the C flag
                        \ above, or we skipped that SEC instruction with a BCS

\BEQ HLOIN22            \ This instruction is commented out in the original
                        \ source

 BCS LI2                \ If Y2 > Y1 then A is already positive and we can skip
                        \ the next two instructions

 EOR #%11111111         \ Negate the result in A by flipping all the bits and
 ADC #1                 \ adding 1, i.e. using two's complement to make it
                        \ positive

.LI2

 STA Q                  \ Store A in Q, so Q = |Y2 - Y1|, or |delta_y|

 CMP P                  \ If Q < P, jump to STPX to step along the x-axis, as
 BCC STPX               \ the line is closer to being horizontal than vertical

 JMP STPY               \ Otherwise Q >= P so jump to STPY to step along the
                        \ y-axis, as the line is closer to being vertical than
                        \ horizontal

\ ******************************************************************************
\
\       Name: LOINQ (Part 2 of 7)
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw a line: Line has a shallow gradient, step right along x-axis
\  Deep dive: Elite's line-drawing algorithm
\
\ ------------------------------------------------------------------------------
\
\ This routine draws a line from (X1, Y1) to (X2, Y2). It has multiple stages.
\ If we get here, then:
\
\   * |delta_y| < |delta_x|
\
\   * The line is closer to being horizontal than vertical
\
\   * We are going to step right along the x-axis
\
\   * We potentially swap coordinates to make sure X1 < X2
\
\ ******************************************************************************

.STPX

 LDX X1                 \ Set X = X1

 CPX X2                 \ If X1 < X2, jump down to LI3, as the coordinates are
 BCC LI3                \ already in the order that we want

 DEC SWAP               \ Otherwise decrement SWAP from 0 to &FF, to denote that
                        \ we are swapping the coordinates around

 LDA X2                 \ Swap the values of X1 and X2
 STA X1
 STX X2

 TAX                    \ Set X = X1

 LDA Y2                 \ Swap the values of Y1 and Y2
 LDY Y1
 STA Y1
 STY Y2

.LI3

                        \ By this point we know the line is horizontal-ish and
                        \ X1 < X2, so we're going from left to right as we go
                        \ from X1 to X2

 LDY Y1                 \ Look up the page number of the character row that
 LDA ylookup,Y          \ contains the pixel with the y-coordinate in Y1, and
 STA SC+1               \ store it in SC+1, so the high byte of SC is set
                        \ correctly for drawing our line

 LDA Y1                 \ Set Y = Y1 mod 8, which is the pixel row within the
 AND #7                 \ character block at which we want to draw the start of
 TAY                    \ our line (as each character block has 8 rows)

 TXA                    \ Set A = 2 * bits 2-6 of X1
 AND #%11111100         \
 ASL A                  \ and shift bit 7 of X1 into the C flag

 STA SC                 \ Store this value in SC, so SC(1 0) now contains the
                        \ screen address of the far left end (x-coordinate = 0)
                        \ of the horizontal pixel row that we want to draw the
                        \ start of our line on

 BCC P%+4               \ If bit 7 of X1 was set, so X1 > 127, increment the
 INC SC+1               \ high byte of SC(1 0) to point to the second page on
                        \ this screen row, as this page contains the right half
                        \ of the row

 TXA                    \ Set R = X1 mod 4, which is the horizontal pixel number
 AND #3                 \ within the character block where the line starts (as
 STA R                  \ each pixel line in the character block is 4 pixels
                        \ wide)

                        \ The following section calculates:
                        \
                        \   Q = Q / P
                        \     = |delta_y| / |delta_x|
                        \
                        \ using the log tables at logL and log to calculate:
                        \
                        \   A = log(Q) - log(P)
                        \     = log(|delta_y|) - log(|delta_x|)
                        \
                        \ by first subtracting the low bytes of the logarithms
                        \ from the table at LogL, and then subtracting the high
                        \ bytes from the table at log, before applying the
                        \ antilog to get the result of the division and putting
                        \ it in Q

 LDX Q                  \ Set X = |delta_y|

 BEQ LIlog7             \ If |delta_y| = 0, jump to LIlog7 to return 0 as the
                        \ result of the division

 LDA logL,X             \ Set A = log(Q) - log(P)
 LDX P                  \       = log(|delta_y|) - log(|delta_x|)
 SEC                    \
 SBC logL,X             \ by first subtracting the low bytes of log(Q) - log(P)

 LDX Q                  \ And then subtracting the high bytes of log(Q) - log(P)
 LDA log,X              \ so now A contains the high byte of log(Q) - log(P)
 LDX P
 SBC log,X

 BCS LIlog5             \ If the subtraction fitted into one byte and didn't
                        \ underflow, then log(Q) - log(P) < 256, so we jump to
                        \ LIlog5 to return a result of 255

 TAX                    \ Otherwise we set A to the A-th entry from the antilog
 LDA alogh,X            \ table so the result of the division is now in A

 JMP LIlog6             \ Jump to LIlog6 to return the result

.LIlog5

 LDA #255               \ The division is very close to 1, so set A to the
 BNE LIlog6             \ closest possible answer to 256, i.e. 255, and jump to
                        \ LIlog6 to return the result (this BNE is effectively a
                        \ JMP as A is never zero)

.LIlog7

 LDA #0                 \ The numerator in the division is 0, so set A to 0

.LIlog6

 STA Q                  \ Store the result of the division in Q, so we have:
                        \
                        \   Q = |delta_y| / |delta_x|

 LDX P                  \ Set X = P
                        \       = |delta_x|

 BEQ LIEXS              \ If |delta_x| = 0, return from the subroutine, as LIEXS
                        \ contains a BEQ LIEX instruction, and LIEX contains an
                        \ RTS

 INX                    \ Set X = P + 1
                        \       = |delta_x| + 1
                        \
                        \ We add 1 so we can skip the first pixel plot if the
                        \ line is being drawn with swapped coordinates

 LDA Y2                 \ If Y2 < Y1 then skip the following instruction
 CMP Y1
 BCC P%+5

 JMP DOWN               \ Y2 >= Y1, so jump to DOWN, as we need to draw the line
                        \ to the right and down

\ ******************************************************************************
\
\       Name: LOINQ (Part 3 of 7)
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw a shallow line going right and up or left and down
\  Deep dive: Elite's line-drawing algorithm
\
\ ------------------------------------------------------------------------------
\
\ This routine draws a line from (X1, Y1) to (X2, Y2). It has multiple stages.
\ If we get here, then:
\
\   * The line is going right and up (no swap) or left and down (swap)
\
\   * X1 < X2 and Y1 > Y2
\
\   * Draw from (X1, Y1) at bottom left to (X2, Y2) at top right, omitting the
\     first pixel
\
\ This routine looks complex, but that's because the loop that's used in the
\ BBC Micro cassette and disc versions has been unrolled to speed it up. The
\ algorithm is unchanged, it's just a lot longer.
\
\ ******************************************************************************

 LDA #%10001000         \ Modify the value in the LDA instruction at LI100 below
 AND COL                \ to contain a pixel mask for the first pixel in the
 STA LI100+1            \ four-pixel byte, in the colour COL, so that it draws
                        \ in the correct colour

 LDA #%01000100         \ Modify the value in the LDA instruction at LI110 below
 AND COL                \ to contain a pixel mask for the second pixel in the
 STA LI110+1            \ four-pixel byte, in the colour COL, so that it draws
                        \ in the correct colour

 LDA #%00100010         \ Modify the value in the LDA instruction at LI120 below
 AND COL                \ to contain a pixel mask for the third pixel in the
 STA LI120+1            \ four-pixel byte, in the colour COL, so that it draws
                        \ in the correct colour

 LDA #%00010001         \ Modify the value in the LDA instruction at LI130 below
 AND COL                \ to contain a pixel mask for the fourth pixel in the
 STA LI130+1            \ four-pixel byte, in the colour COL, so that it draws
                        \ in the correct colour

                        \ We now work our way along the line from left to right,
                        \ using X as a decreasing counter, and at each count we
                        \ plot a single pixel using the pixel mask in R

 LDA SWAP               \ If SWAP = 0 then we didn't swap the coordinates above,
 BEQ LI190              \ so jump down to LI190 to plot the first pixel

                        \ If we get here then we want to omit the first pixel

 LDA R                  \ Fetch the pixel byte from R, which we set in part 2 to
                        \ the horizontal pixel number within the character block
                        \ where the line starts (so it's 0, 1, 2 or 3)

 BEQ LI100+6            \ If R = 0, jump to LI100+6 to start plotting from the
                        \ second pixel in this byte (LI100+6 points to the DEX
                        \ instruction after the EOR/STA instructions, so the
                        \ pixel doesn't get plotted but we join at the right
                        \ point to decrement X correctly to plot the next three)

 CMP #2                 \ If R < 2 (i.e. R = 1), jump to LI110+6 to skip the
 BCC LI110+6            \ first two pixels but plot the next two

 CLC                    \ Clear the C flag so it doesn't affect the additions
                        \ below

 BEQ LI120+6            \ If R = 2, jump to LI120+6 to skip the first three
                        \ pixels but plot the last one

 BNE LI130+6            \ If we get here then R must be 3, so jump to LI130+6 to
                        \ skip plotting any of the pixels, but making sure we
                        \ join the routine just after the plotting instructions
                        \ (this BNE is effectively a JMP as we just passed
                        \ through a BEQ)

.LI190

 DEX                    \ Decrement the counter in X because we're about to plot
                        \ the first pixel

 LDA R                  \ Fetch the pixel byte from R, which we set in part 2 to
                        \ the horizontal pixel number within the character block
                        \ where the line starts (so it's 0, 1, 2 or 3)

 BEQ LI100              \ If R = 0, jump to LI100 to start plotting from the
                        \ first pixel in this byte

 CMP #2                 \ If R < 2 (i.e. R = 1), jump to LI110 to start plotting
 BCC LI110              \ from the second pixel in this byte

 CLC                    \ Clear the C flag so it doesn't affect the additions
                        \ below

 BEQ LI120              \ If R = 2, jump to LI120 to start plotting from the
                        \ third pixel in this byte

 JMP LI130              \ If we get here then R must be 3, so jump to LI130 to
                        \ start plotting from the fourth pixel in this byte

.LI100

 LDA #%10001000         \ Set a mask in A to the first pixel in the four-pixel
                        \ byte (note that this value is modified by the code at
                        \ the start of this section to be a bit mask for the
                        \ colour in COL)

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

.LIEXS

 BEQ LIEX               \ If we have just reached the right end of the line,
                        \ jump to LIEX to return from the subroutine

 LDA S                  \ Set S = S + Q to update the slope error
 ADC Q
 STA S

 BCC LI110              \ If the addition didn't overflow, jump to LI110

 CLC                    \ Otherwise we just overflowed, so clear the C flag and
 DEY                    \ decrement Y to move to the pixel line above

 BMI LI101              \ If Y is negative we need to move up into the character
                        \ block above, so jump to LI101 to decrement the screen
                        \ address accordingly (jumping back to LI110 afterwards)

.LI110

 LDA #%01000100         \ Set a mask in A to the second pixel in the four-pixel
                        \ byte (note that this value is modified by the code at
                        \ the start of this section to be a bit mask for the
                        \ colour in COL)

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX               \ If we have just reached the right end of the line,
                        \ jump to LIEX to return from the subroutine

 LDA S                  \ Set S = S + Q to update the slope error
 ADC Q
 STA S

 BCC LI120              \ If the addition didn't overflow, jump to LI120

 CLC                    \ Otherwise we just overflowed, so clear the C flag and
 DEY                    \ decrement Y to move to the pixel line above

 BMI LI111              \ If Y is negative we need to move up into the character
                        \ block above, so jump to LI111 to decrement the screen
                        \ address accordingly (jumping back to LI120 afterwards)

.LI120

 LDA #%00100010         \ Set a mask in A to the third pixel in the four-pixel
                        \ byte (note that this value is modified by the code at
                        \ the start of this section to be a bit mask for the
                        \ colour in COL)

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX               \ If we have just reached the right end of the line,
                        \ jump to LIEX to return from the subroutine

 LDA S                  \ Set S = S + Q to update the slope error
 ADC Q
 STA S

 BCC LI130              \ If the addition didn't overflow, jump to LI130

 CLC                    \ Otherwise we just overflowed, so clear the C flag and
 DEY                    \ decrement Y to move to the pixel line above

 BMI LI121              \ If Y is negative we need to move up into the character
                        \ block above, so jump to LI121 to decrement the screen
                        \ address accordingly (jumping back to LI130 afterwards)

.LI130

 LDA #%00010001         \ Set a mask in A to the fourth pixel in the four-pixel
                        \ byte (note that this value is modified by the code at
                        \ the start of this section to be a bit mask for the
                        \ colour in COL)

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 LDA S                  \ Set S = S + Q to update the slope error
 ADC Q
 STA S

 BCC LI140              \ If the addition didn't overflow, jump to LI140

 CLC                    \ Otherwise we just overflowed, so clear the C flag and
 DEY                    \ decrement Y to move to the pixel line above

 BMI LI131              \ If Y is negative we need to move up into the character
                        \ block above, so jump to LI131 to decrement the screen
                        \ address accordingly (jumping back to LI140 afterwards)

.LI140

 DEX                    \ Decrement the counter in X

 BEQ LIEX               \ If we have just reached the right end of the line,
                        \ jump to LIEX to return from the subroutine

 LDA SC                 \ Add 8 to SC, so SC(1 0) now points to the next
 ADC #8                 \ character along to the right
 STA SC

 BCC LI100              \ If the addition didn't overflow, jump back to LI100
                        \ to plot the next pixel

 INC SC+1               \ Otherwise the low byte of SC(1 0) just overflowed, so
                        \ increment the high byte SC+1 as we just crossed over
                        \ into the right half of the screen

 CLC                    \ Clear the C flag to avoid breaking any arithmetic

 BCC LI100              \ Jump back to LI100 to plot the next pixel

.LI101

 DEC SC+1               \ If we get here then we need to move up into the
 DEC SC+1               \ character block above, so we decrement the high byte
 LDY #7                 \ of the screen twice (as there are two pages per screen
                        \ row) and set the pixel line to the last line in
                        \ that character block

 BPL LI110              \ Jump back to the instruction after the BMI that called
                        \ this routine

.LI111

 DEC SC+1               \ If we get here then we need to move up into the
 DEC SC+1               \ character block above, so we decrement the high byte
 LDY #7                 \ of the screen twice (as there are two pages per screen
                        \ row) and set the pixel line to the last line in
                        \ that character block

 BPL LI120              \ Jump back to the instruction after the BMI that called
                        \ this routine

.LI121

 DEC SC+1               \ If we get here then we need to move up into the
 DEC SC+1               \ character block above, so we decrement the high byte
 LDY #7                 \ of the screen twice (as there are two pages per screen
                        \ row) and set the pixel line to the last line in
                        \ that character block

 BPL LI130              \ Jump back to the instruction after the BMI that called
                        \ this routine

.LI131

 DEC SC+1               \ If we get here then we need to move up into the
 DEC SC+1               \ character block above, so we decrement the high byte
 LDY #7                 \ of the screen twice (as there are two pages per screen
                        \ row) and set the pixel line to the last line in
                        \ that character block

 BPL LI140              \ Jump back to the instruction after the BMI that called
                        \ this routine

.LIEX

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: LOINQ (Part 4 of 7)
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw a shallow line going right and down or left and up
\  Deep dive: Elite's line-drawing algorithm
\
\ ------------------------------------------------------------------------------
\
\ This routine draws a line from (X1, Y1) to (X2, Y2). It has multiple stages.
\ If we get here, then:
\
\   * The line is going right and down (no swap) or left and up (swap)
\
\   * X1 < X2 and Y1 <= Y2
\
\   * Draw from (X1, Y1) at top left to (X2, Y2) at bottom right, omitting the
\     first pixel
\
\ This routine looks complex, but that's because the loop that's used in the
\ BBC Micro cassette and disc versions has been unrolled to speed it up. The
\ algorithm is unchanged, it's just a lot longer.
\
\ ******************************************************************************

.DOWN

 LDA #%10001000         \ Modify the value in the LDA instruction at LI200 below
 AND COL                \ to contain a pixel mask for the first pixel in the
 STA LI200+1            \ four-pixel byte, in the colour COL, so that it draws
                        \ in the correct colour

 LDA #%01000100         \ Modify the value in the LDA instruction at LI210 below
 AND COL                \ to contain a pixel mask for the second pixel in the
 STA LI210+1            \ four-pixel byte, in the colour COL, so that it draws
                        \ in the correct colour

 LDA #%00100010         \ Modify the value in the LDA instruction at LI220 below
 AND COL                \ to contain a pixel mask for the third pixel in the
 STA LI220+1            \ four-pixel byte, in the colour COL, so that it draws
                        \ in the correct colour

 LDA #%00010001         \ Modify the value in the LDA instruction at LI230 below
 AND COL                \ to contain a pixel mask for the fourth pixel in the
 STA LI230+1            \ four-pixel byte, in the colour COL, so that it draws
                        \ in the correct colour

 LDA SC                 \ Set SC(1 0) = SC(1 0) - 248
 SBC #248
 STA SC
 LDA SC+1
 SBC #0
 STA SC+1

 TYA                    \ Set bits 3-7 of Y, which contains the pixel row within
 EOR #%11111000         \ the character, and is therefore in the range 0-7, so
 TAY                    \ this does Y = 248 + Y
                        \
                        \ We therefore have the following:
                        \
                        \   SC(1 0) + Y = SC(1 0) - 248 + 248 + Y
                        \               = SC(1 0) + Y
                        \
                        \ so the screen location we poke hasn't changed, but Y
                        \ is now a larger number and SC is smaller. This means
                        \ we can increment Y to move down a line, as per usual,
                        \ but we can test for when it reaches the bottom of the
                        \ character block with a simple BEQ rather than checking
                        \ whether it's reached 8, so this appears to be a code
                        \ optimisation
                        \
                        \ If it helps, you can think of Y as being a negative
                        \ number that we are incrementing towards zero as we
                        \ move along the line - we just need to alter the value
                        \ of SC so that SC(1 0) + Y points to the right address

                        \ We now work our way along the line from left to right,
                        \ using X as a decreasing counter, and at each count we
                        \ plot a single pixel using the pixel mask in R

 LDA SWAP               \ If SWAP = 0 then we didn't swap the coordinates above,
 BEQ LI191              \ so jump down to LI191 to plot the first pixel

                        \ If we get here then we want to omit the first pixel

 LDA R                  \ Fetch the pixel byte from R, which we set in part 2 to
                        \ the horizontal pixel number within the character block
                        \ where the line starts (so it's 0, 1, 2 or 3)

 BEQ LI200+6            \ If R = 0, jump to LI200+6 to start plotting from the
                        \ second pixel in this byte (LI200+6 points to the DEX
                        \ instruction after the EOR/STA instructions, so the
                        \ pixel doesn't get plotted but we join at the right
                        \ point to decrement X correctly to plot the next three)

 CMP #2                 \ If R < 2 (i.e. R = 1), jump to LI210+6 to skip the
 BCC LI210+6            \ first two pixels but plot the next two

 CLC                    \ Clear the C flag so it doesn't affect the additions
                        \ below

 BEQ LI220+6            \ If R = 2, jump to LI220+6 to skip the first three
                        \ pixels but plot the last one

 BNE LI230+6            \ If we get here then R must be 3, so jump to LI230+6 to
                        \ skip plotting any of the pixels, but making sure we
                        \ join the routine just after the plotting instructions
                        \ (this BNE is effectively a JMP as we just passed
                        \ through a BEQ)

.LI191

 DEX                    \ Decrement the counter in X because we're about to plot
                        \ the first pixel

 LDA R                  \ Fetch the pixel byte from R, which we set in part 2 to
                        \ the horizontal pixel number within the character block
                        \ where the line starts (so it's 0, 1, 2 or 3)

 BEQ LI200              \ If R = 0, jump to LI200 to start plotting from the
                        \ first pixel in this byte

 CMP #2                 \ If R < 2 (i.e. R = 1), jump to LI210 to start plotting
 BCC LI210              \ from the second pixel in this byte

 CLC                    \ Clear the C flag so it doesn't affect the additions
                        \ below

 BEQ LI220              \ If R = 2, jump to LI220 to start plotting from the
                        \ third pixel in this byte

 BNE LI230              \ If we get here then R must be 3, so jump to LI130 to
                        \ start plotting from the fourth pixel in this byte
                        \ (this BNE is effectively a JMP as we just passed
                        \ through a BEQ)

.LI200

 LDA #%10001000         \ Set a mask in A to the first pixel in the four-pixel
                        \ byte (note that this value is modified by the code at
                        \ the start of this section to be a bit mask for the
                        \ colour in COL)

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX               \ If we have just reached the right end of the line,
                        \ jump to LIEX to return from the subroutine

 LDA S                  \ Set S = S + Q to update the slope error
 ADC Q
 STA S

 BCC LI210              \ If the addition didn't overflow, jump to LI210

 CLC                    \ Otherwise we just overflowed, so clear the C flag and
 INY                    \ increment Y to move to the pixel line below

 BEQ LI201              \ If Y is zero we need to move down into the character
                        \ block below, so jump to LI201 to increment the screen
                        \ address accordingly (jumping back to LI210 afterwards)

.LI210

 LDA #%01000100         \ Set a mask in A to the second pixel in the four-pixel
                        \ byte (note that this value is modified by the code at
                        \ the start of this section to be a bit mask for the
                        \ colour in COL)

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX               \ If we have just reached the right end of the line,
                        \ jump to LIEX to return from the subroutine

 LDA S                  \ Set S = S + Q to update the slope error
 ADC Q
 STA S

 BCC LI220              \ If the addition didn't overflow, jump to LI220

 CLC                    \ Otherwise we just overflowed, so clear the C flag and
 INY                    \ increment Y to move to the pixel line below

 BEQ LI211              \ If Y is zero we need to move down into the character
                        \ block below, so jump to LI211 to increment the screen
                        \ address accordingly (jumping back to LI220 afterwards)

.LI220

 LDA #%00100010         \ Set a mask in A to the third pixel in the four-pixel
                        \ byte (note that this value is modified by the code at
                        \ the start of this section to be a bit mask for the
                        \ colour in COL)

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX2              \ If we have just reached the right end of the line,
                        \ jump to LIEX2 to return from the subroutine

 LDA S                  \ Set S = S + Q to update the slope error
 ADC Q
 STA S

 BCC LI230              \ If the addition didn't overflow, jump to LI230

 CLC                    \ Otherwise we just overflowed, so clear the C flag and
 INY                    \ increment Y to move to the pixel line below

 BEQ LI221              \ If Y is zero we need to move down into the character
                        \ block below, so jump to LI221 to increment the screen
                        \ address accordingly (jumping back to LI230 afterwards)

.LI230

 LDA #%00010001         \ Set a mask in A to the fourth pixel in the four-pixel
                        \ byte (note that this value is modified by the code at
                        \ the start of this section to be a bit mask for the
                        \ colour in COL)

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 LDA S                  \ Set S = S + Q to update the slope error
 ADC Q
 STA S

 BCC LI240              \ If the addition didn't overflow, jump to LI240

 CLC                    \ Otherwise we just overflowed, so clear the C flag and
 INY                    \ increment Y to move to the pixel line below

 BEQ LI231              \ If Y is zero we need to move down into the character
                        \ block below, so jump to LI231 to increment the screen
                        \ address accordingly (jumping back to LI240 afterwards)

.LI240

 DEX                    \ Decrement the counter in X

 BEQ LIEX2              \ If we have just reached the right end of the line,
                        \ jump to LIEX2 to return from the subroutine

 LDA SC                 \ Add 8 to SC, so SC(1 0) now points to the next
 ADC #8                 \ character along to the right
 STA SC

 BCC LI200              \ If the addition didn't overflow, jump back to LI200
                        \ to plot the next pixel

 INC SC+1               \ Otherwise the low byte of SC(1 0) just overflowed, so
                        \ increment the high byte SC+1 as we just crossed over
                        \ into the right half of the screen

 CLC                    \ Clear the C flag to avoid breaking any arithmetic

 BCC LI200              \ Jump back to LI200 to plot the next pixel

.LI201

 INC SC+1               \ If we get here then we need to move down into the
 INC SC+1               \ character block below, so we increment the high byte
 LDY #248               \ of the screen twice (as there are two pages per screen
                        \ row) and set the pixel line to the first line in that
                        \ character block (as we subtracted 248 from SC above)

 BNE LI210              \ Jump back to the instruction after the BMI that called
                        \ this routine

.LI211

 INC SC+1               \ If we get here then we need to move down into the
 INC SC+1               \ character block below, so we increment the high byte
 LDY #248               \ of the screen twice (as there are two pages per screen
                        \ row) and set the pixel line to the first line in that
                        \ character block (as we subtracted 248 from SC above)

 BNE LI220              \ Jump back to the instruction after the BMI that called
                        \ this routine

.LI221

 INC SC+1               \ If we get here then we need to move down into the
 INC SC+1               \ character block below, so we increment the high byte
 LDY #248               \ of the screen twice (as there are two pages per screen
                        \ row) and set the pixel line to the first line in that
                        \ character block (as we subtracted 248 from SC above)

 BNE LI230              \ Jump back to the instruction after the BMI that called
                        \ this routine

.LI231

 INC SC+1               \ If we get here then we need to move down into the
 INC SC+1               \ character block below, so we increment the high byte
 LDY #248               \ of the screen twice (as there are two pages per screen
                        \ row) and set the pixel line to the first line in that
                        \ character block (as we subtracted 248 from SC above)

 BNE LI240              \ Jump back to the instruction after the BMI that called
                        \ this routine

.LIEX2

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: LOINQ (Part 5 of 7)
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw a line: Line has a steep gradient, step up along y-axis
\  Deep dive: Elite's line-drawing algorithm
\
\ ------------------------------------------------------------------------------
\
\ This routine draws a line from (X1, Y1) to (X2, Y2). It has multiple stages.
\ If we get here, then:
\
\   * |delta_y| >= |delta_x|
\
\   * The line is closer to being vertical than horizontal
\
\   * We are going to step up along the y-axis
\
\   * We potentially swap coordinates to make sure Y1 >= Y2
\
\ ******************************************************************************

.STPY

 LDY Y1                 \ Set A = Y = Y1
 TYA

 LDX X1                 \ Set X = X1

 CPY Y2                 \ If Y1 >= Y2, jump down to LI15, as the coordinates are
 BCS LI15               \ already in the order that we want

 DEC SWAP               \ Otherwise decrement SWAP from 0 to &FF, to denote that
                        \ we are swapping the coordinates around

 LDA X2                 \ Swap the values of X1 and X2
 STA X1
 STX X2

 TAX                    \ Set X = X1

 LDA Y2                 \ Swap the values of Y1 and Y2
 STA Y1
 STY Y2

 TAY                    \ Set Y = A = Y1

.LI15

                        \ By this point we know the line is vertical-ish and
                        \ Y1 >= Y2, so we're going from top to bottom as we go
                        \ from Y1 to Y2

 LDA ylookup,Y          \ Look up the page number of the character row that
 STA SC+1               \ contains the pixel with the y-coordinate in Y1, and
                        \ store it in the high byte of SC(1 0) at SC+1, so the
                        \ high byte of SC is set correctly for drawing our line

 TXA                    \ Set A = 2 * bits 2-6 of X1
 AND #%11111100         \
 ASL A                  \ and shift bit 7 of X1 into the C flag

 STA SC                 \ Store this value in SC, so SC(1 0) now contains the
                        \ screen address of the far left end (x-coordinate = 0)
                        \ of the horizontal pixel row that we want to draw the
                        \ start of our line on

 BCC P%+4               \ If bit 7 of X1 was set, so X1 > 127, increment the
 INC SC+1               \ high byte of SC(1 0) to point to the second page on
                        \ this screen row, as this page contains the right half
                        \ of the row

 TXA                    \ Set X = X1 mod 4, which is the horizontal pixel number
 AND #3                 \ within the character block where the line starts (as
 TAX                    \ each pixel line in the character block is 4 pixels
                        \ wide)

 LDA TWOS,X             \ Fetch a one-pixel byte from TWOS where pixel X is set,
 STA R                  \ and store it in R

                        \ The following section calculates:
                        \
                        \   P = P / Q
                        \     = |delta_x| / |delta_y|
                        \
                        \ using the log tables at logL and log to calculate:
                        \
                        \   A = log(P) - log(Q)
                        \     = log(|delta_x|) - log(|delta_y|)
                        \
                        \ by first subtracting the low bytes of the logarithms
                        \ from the table at LogL, and then subtracting the high
                        \ bytes from the table at log, before applying the
                        \ antilog to get the result of the division and putting
                        \ it in P

 LDX P                  \ Set X = |delta_x|

 BEQ LIfudge            \ If |delta_x| = 0, jump to LIfudge to return 0 as the
                        \ result of the division

 LDA logL,X             \ Set A = log(P) - log(Q)
 LDX Q                  \       = log(|delta_x|) - log(|delta_y|)
 SEC                    \
 SBC logL,X             \ by first subtracting the low bytes of log(P) - log(Q)

 LDX P                  \ And then subtracting the high bytes of log(P) - log(Q)
 LDA log,X              \ so now A contains the high byte of log(P) - log(Q)
 LDX Q
 SBC log,X

 BCS LIlog3             \ If the subtraction fitted into one byte and didn't
                        \ underflow, then log(P) - log(Q) < 256, so we jump to
                        \ LIlog3 to return a result of 255

 TAX                    \ Otherwise we set A to the A-th entry from the antilog
 LDA alogh,X            \ table so the result of the division is now in A

 JMP LIlog2             \ Jump to LIlog2 to return the result

.LIlog3

 LDA #255               \ The division is very close to 1, so set A to the
                        \ closest possible answer to 256, i.e. 255

.LIlog2

 STA P                  \ Store the result of the division in P, so we have:
                        \
                        \   P = |delta_x| / |delta_y|

.LIfudge

 LDX Q                  \ Set X = Q
                        \       = |delta_y|

 BEQ LIEX7              \ If |delta_y| = 0, jump down to LIEX7 to return from
                        \ the subroutine

 INX                    \ Set X = Q + 1
                        \       = |delta_y| + 1
                        \
                        \ We add 1 so we can skip the first pixel plot if the
                        \ line is being drawn with swapped coordinates

 LDA X2                 \ Set A = X2 - X1
 SEC
 SBC X1

 BCS P%+6               \ If X2 >= X1 then skip the following two instructions

 JMP LFT                \ If X2 < X1 then jump to LFT, as we need to draw the
                        \ line to the left and down

.LIEX7

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: LOINQ (Part 6 of 7)
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw a steep line going up and left or down and right
\  Deep dive: Elite's line-drawing algorithm
\
\ ------------------------------------------------------------------------------
\
\ This routine draws a line from (X1, Y1) to (X2, Y2). It has multiple stages.
\ If we get here, then:
\
\   * The line is going up and left (no swap) or down and right (swap)
\
\   * X1 < X2 and Y1 >= Y2
\
\   * Draw from (X1, Y1) at top left to (X2, Y2) at bottom right, omitting the
\     first pixel
\
\ This routine looks complex, but that's because the loop that's used in the
\ BBC Micro cassette and disc versions has been unrolled to speed it up. The
\ algorithm is unchanged, it's just a lot longer.
\
\ ******************************************************************************

 LDA SWAP               \ If SWAP = 0 then we didn't swap the coordinates above,
 BEQ LI290              \ so jump down to LI290 to plot the first pixel

 TYA                    \ Fetch bits 0-2 of the y-coordinate, so Y contains the
 AND #7                 \ y-coordinate mod 8
 TAY

 BNE P%+5               \ If Y = 0, jump to LI307+8 to start plotting from the
 JMP LI307+8            \ pixel above the top row of this character block
                        \ (LI307+8 points to the DEX instruction after the
                        \ EOR/STA instructions, so the pixel at row 0 doesn't
                        \ get plotted but we join at the right point to
                        \ decrement X and Y correctly to continue plotting from
                        \ the character row above)

 CPY #2                 \ If Y < 2 (i.e. Y = 1), jump to LI306+8 to start
 BCS P%+5               \ plotting from row 0 of this character block, missing
 JMP LI306+8            \ out row 1

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 BNE P%+5               \ If Y = 2, jump to LI305+8 to start plotting from row
 JMP LI305+8            \ 1 of this character block, missing out row 2

 CPY #4                 \ If Y < 4 (i.e. Y = 3), jump to LI304+8 to start
 BCS P%+5               \ plotting from row 2 of this character block, missing
 JMP LI304+8            \ out row 3

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 BNE P%+5               \ If Y = 4, jump to LI303+8 to start plotting from row
 JMP LI303+8            \ 3 of this character block, missing out row 4

 CPY #6                 \ If Y < 6 (i.e. Y = 5), jump to LI302+8 to start
 BCS P%+5               \ plotting from row 4 of this character block, missing
 JMP LI302+8            \ out row 5

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 BEQ P%+5               \ If Y <> 6 (i.e. Y = 7), jump to LI300+8 to start
 JMP LI300+8            \ plotting from row 6 of this character block, missing
                        \ out row 7

 JMP LI301+8            \ Otherwise Y = 6, so jump to LI301+8 to start plotting
                        \ from row 5 of this character block, missing out row 6

.LI290

 DEX                    \ Decrement the counter in X because we're about to plot
                        \ the first pixel

 TYA                    \ Fetch bits 0-2 of the y-coordinate, so Y contains the
 AND #7                 \ y-coordinate mod 8
 TAY

 BNE P%+5               \ If Y = 0, jump to LI307 to start plotting from row 0
 JMP LI307              \ of this character block

 CPY #2                 \ If Y < 2 (i.e. Y = 1), jump to LI306 to start plotting
 BCS P%+5               \ from row 1 of this character block
 JMP LI306

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 BNE P%+5               \ If Y = 2, jump to LI305 to start plotting from row 2
 JMP LI305              \ of this character block

 CPY #4                 \ If Y < 4 (i.e. Y = 3), jump to LI304 (via LI304S) to
 BCC LI304S             \ start plotting from row 3 of this character block

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 BEQ LI303S             \ If Y = 4, jump to LI303 (via LI303S) to start plotting
                        \ from row 4 of this character block

 CPY #6                 \ If Y < 6 (i.e. Y = 5), jump to LI302 (via LI302S) to
 BCC LI302S             \ start plotting from row 5 of this character block

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 BEQ LI301S             \ If Y = 6, jump to LI301 (via LI301S) to start plotting
                        \ from row 6 of this character block

 JMP LI300              \ Otherwise Y = 7, so jump to LI300 to start plotting
                        \ from row 7 of this character block

.LI310

 LSR R                  \ If we get here then the slope error just overflowed
                        \ after plotting the pixel in LI300, so shift the single
                        \ pixel in R to the right, so the next pixel we plot
                        \ will be at the next x-coordinate along

 BCC LI301              \ If the pixel didn't fall out of the right end of R
                        \ into the C flag, then jump to LI301 to plot the pixel
                        \ on the next character row up

 LDA #%10001000         \ Set a mask in R to the first pixel in the four-pixel
 STA R                  \ byte

 LDA SC                 \ Add 8 to SC, so SC(1 0) now points to the next
 ADC #7                 \ character along to the right (the C flag is set as we
 STA SC                 \ didn't take the above BCC, so the ADC adds 8)

 BCC LI301              \ If the addition didn't overflow, jump to LI301 to plot
                        \ the pixel on the next character row up

 INC SC+1               \ The addition overflowed, so increment the high byte in
                        \ SC(1 0) to move to the next page in screen memory

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

.LI301S

 BCC LI301              \ Jump to LI301 to rejoin the pixel plotting routine
                        \ (this BCC is effectively a JMP as the C flag is clear)

.LI311

 LSR R                  \ If we get here then the slope error just overflowed
                        \ after plotting the pixel in LI301, so shift the single
                        \ pixel in R to the right, so the next pixel we plot
                        \ will be at the next x-coordinate along

 BCC LI302              \ If the pixel didn't fall out of the right end of R
                        \ into the C flag, then jump to LI302 to plot the pixel
                        \ on the next character row up

 LDA #%10001000         \ Set a mask in R to the first pixel in the four-pixel
 STA R                  \ byte

 LDA SC                 \ Add 8 to SC, so SC(1 0) now points to the next
 ADC #7                 \ character along to the right (the C flag is set as we
 STA SC                 \ didn't take the above BCC, so the ADC adds 8)

 BCC LI302              \ If the addition didn't overflow, jump to LI302 to plot
                        \ the pixel on the next character row up

 INC SC+1               \ The addition overflowed, so increment the high byte in
                        \ SC(1 0) to move to the next page in screen memory

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

.LI302S

 BCC LI302              \ Jump to LI302 to rejoin the pixel plotting routine
                        \ (this BCC is effectively a JMP as the C flag is clear)

.LI312

 LSR R                  \ If we get here then the slope error just overflowed
                        \ after plotting the pixel in LI302, so shift the single
                        \ pixel in R to the right, so the next pixel we plot
                        \ will be at the next x-coordinate along

 BCC LI303              \ If the pixel didn't fall out of the right end of R
                        \ into the C flag, then jump to LI303 to plot the pixel
                        \ on the next character row up

 LDA #%10001000         \ Set a mask in R to the first pixel in the four-pixel
 STA R                  \ byte

 LDA SC                 \ Add 8 to SC, so SC(1 0) now points to the next
 ADC #7                 \ character along to the right (the C flag is set as we
 STA SC                 \ didn't take the above BCC, so the ADC adds 8)

 BCC LI303              \ If the addition didn't overflow, jump to LI303 to plot
                        \ the pixel on the next character row up

 INC SC+1               \ The addition overflowed, so increment the high byte in
                        \ SC(1 0) to move to the next page in screen memory

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

.LI303S

 BCC LI303              \ Jump to LI303 to rejoin the pixel plotting routine
                        \ (this BCC is effectively a JMP as the C flag is clear)

.LI313

 LSR R                  \ If we get here then the slope error just overflowed
                        \ after plotting the pixel in LI303, so shift the single
                        \ pixel in R to the right, so the next pixel we plot
                        \ will be at the next x-coordinate along

 BCC LI304              \ If the pixel didn't fall out of the right end of R
                        \ into the C flag, then jump to LI304 to plot the pixel
                        \ on the next character row up

 LDA #%10001000         \ Set a mask in R to the first pixel in the four-pixel
 STA R                  \ byte

 LDA SC                 \ Add 8 to SC, so SC(1 0) now points to the next
 ADC #7                 \ character along to the right (the C flag is set as we
 STA SC                 \ didn't take the above BCC, so the ADC adds 8)

 BCC LI304              \ If the addition didn't overflow, jump to LI304 to plot
                        \ the pixel on the next character row up

 INC SC+1               \ The addition overflowed, so increment the high byte in
                        \ SC(1 0) to move to the next page in screen memory

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

.LI304S

 BCC LI304              \ Jump to LI304 to rejoin the pixel plotting routine
                        \ (this BCC is effectively a JMP as the C flag is clear)

.LIEX3

 RTS                    \ Return from the subroutine

.LI300

                        \ Plot a pixel on row 7 of this character block

 LDA R                  \ Fetch the pixel byte from R and apply the colour in
 AND COL                \ COL to it

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX3              \ If we have just reached the right end of the line,
                        \ jump to LIEX3 to return from the subroutine

 DEY                    \ Decrement Y to step up along the y-axis

 LDA S                  \ Set S = S + P to update the slope error
 ADC P
 STA S

 BCS LI310              \ If the addition overflowed, jump to LI310 to move to
                        \ the pixel in the next character block along, which
                        \ returns us to LI301 below

.LI301

                        \ Plot a pixel on row 6 of this character block

 LDA R                  \ Fetch the pixel byte from R and apply the colour in
 AND COL                \ COL to it

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX3              \ If we have just reached the right end of the line,
                        \ jump to LIEX3 to return from the subroutine

 DEY                    \ Decrement Y to step up along the y-axis

 LDA S                  \ Set S = S + P to update the slope error
 ADC P
 STA S

 BCS LI311              \ If the addition overflowed, jump to LI311 to move to
                        \ the pixel in the next character block along, which
                        \ returns us to LI302 below

.LI302

                        \ Plot a pixel on row 5 of this character block

 LDA R                  \ Fetch the pixel byte from R and apply the colour in
 AND COL                \ COL to it

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX3              \ If we have just reached the right end of the line,
                        \ jump to LIEX3 to return from the subroutine

 DEY                    \ Decrement Y to step up along the y-axis

 LDA S                  \ Set S = S + P to update the slope error
 ADC P
 STA S

 BCS LI312              \ If the addition overflowed, jump to LI312 to move to
                        \ the pixel in the next character block along, which
                        \ returns us to LI303 below

.LI303

                        \ Plot a pixel on row 4 of this character block

 LDA R                  \ Fetch the pixel byte from R and apply the colour in
 AND COL                \ COL to it

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX3              \ If we have just reached the right end of the line,
                        \ jump to LIEX3 to return from the subroutine

 DEY                    \ Decrement Y to step up along the y-axis

 LDA S                  \ Set S = S + P to update the slope error
 ADC P
 STA S

 BCS LI313              \ If the addition overflowed, jump to LI313 to move to
                        \ the pixel in the next character block along, which
                        \ returns us to LI304 below

.LI304

                        \ Plot a pixel on row 3 of this character block

 LDA R                  \ Fetch the pixel byte from R and apply the colour in
 AND COL                \ COL to it

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX4              \ If we have just reached the right end of the line,
                        \ jump to LIEX4 to return from the subroutine

 DEY                    \ Decrement Y to step up along the y-axis

 LDA S                  \ Set S = S + P to update the slope error
 ADC P
 STA S

 BCS LI314              \ If the addition overflowed, jump to LI314 to move to
                        \ the pixel in the next character block along, which
                        \ returns us to LI305 below

.LI305

                        \ Plot a pixel on row 2 of this character block

 LDA R                  \ Fetch the pixel byte from R and apply the colour in
 AND COL                \ COL to it

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX4              \ If we have just reached the right end of the line,
                        \ jump to LIEX4 to return from the subroutine

 DEY                    \ Decrement Y to step up along the y-axis

 LDA S                  \ Set S = S + P to update the slope error
 ADC P
 STA S

 BCS LI315              \ If the addition overflowed, jump to LI315 to move to
                        \ the pixel in the next character block along, which
                        \ returns us to LI306 below

.LI306

                        \ Plot a pixel on row 1 of this character block

 LDA R                  \ Fetch the pixel byte from R and apply the colour in
 AND COL                \ COL to it

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX4              \ If we have just reached the right end of the line,
                        \ jump to LIEX4 to return from the subroutine

 DEY                    \ Decrement Y to step up along the y-axis

 LDA S                  \ Set S = S + P to update the slope error
 ADC P
 STA S

 BCS LI316              \ If the addition overflowed, jump to LI316 to move to
                        \ the pixel in the next character block along, which
                        \ returns us to LI307 below

.LI307

                        \ Plot a pixel on row 0 of this character block

 LDA R                  \ Fetch the pixel byte from R and apply the colour in
 AND COL                \ COL to it

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX4              \ If we have just reached the right end of the line,
                        \ jump to LIEX4 to return from the subroutine

 DEC SC+1               \ We just reached the top of the character block, so
 DEC SC+1               \ decrement the high byte in SC(1 0) twice to point to
 LDY #7                 \ the screen row above (as there are two pages per
                        \ screen row) and set Y to point to the last row in the
                        \ new character block

 LDA S                  \ Set S = S + P to update the slope error
 ADC P
 STA S

 BCS P%+5               \ If the addition didn't overflow, jump to LI300 to
 JMP LI300              \ continue plotting in the next character block along

 LSR R                  \ If we get here then the slope error just overflowed
                        \ after plotting the pixel in LI307 above, so shift the
                        \ single pixel in R to the right, so the next pixel we
                        \ plot will be at the next x-coordinate

 BCS P%+5               \ If the pixel didn't fall out of the right end of R
 JMP LI300              \ into the C flag, then jump to LI400 to continue
                        \ plotting in the next character block along

 LDA #%10001000         \ Otherwise we need to move over to the next character
 STA R                  \ along, so set a mask in R to the first pixel in the
                        \ four-pixel byte

 LDA SC                 \ Add 8 to SC, so SC(1 0) now points to the next
 ADC #7                 \ character along to the right (the C flag is set as we
 STA SC                 \ took the above BCS, so the ADC adds 8)

 BCS P%+5               \ If the addition didn't overflow, ump to LI300 to
 JMP LI300              \ continue plotting in the next character block along

 INC SC+1               \ The addition overflowed, so increment the high byte in
                        \ SC(1 0) to move to the next page in screen memory

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 JMP LI300              \ Jump to LI300 to continue plotting in the next
                        \ character block along

.LIEX4

 RTS                    \ Return from the subroutine

.LI314

 LSR R                  \ If we get here then the slope error just overflowed
                        \ after plotting the pixel in LI304, so shift the single
                        \ pixel in R to the right, so the next pixel we plot
                        \ will be at the next x-coordinate along

 BCC LI305              \ If the pixel didn't fall out of the right end of R
                        \ into the C flag, then jump to LI305 to plot the pixel
                        \ on the next character row up

 LDA #%10001000         \ Set a mask in R to the first pixel in the four-pixel
 STA R                  \ byte

 LDA SC                 \ Add 8 to SC, so SC(1 0) now points to the next
 ADC #7                 \ character along to the right (the C flag is set as we
 STA SC                 \ didn't take the above BCC, so the ADC adds 8)

 BCC LI305              \ If the addition didn't overflow, jump to LI305 to plot
                        \ the pixel on the next character row up

 INC SC+1               \ The addition overflowed, so increment the high byte in
                        \ SC(1 0) to move to the next page in screen memory

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 BCC LI305              \ Jump to LI305 to rejoin the pixel plotting routine
                        \ (this BCC is effectively a JMP as the C flag is clear)

.LI315

 LSR R                  \ If we get here then the slope error just overflowed
                        \ after plotting the pixel in LI305, so shift the single
                        \ pixel in R to the right, so the next pixel we plot
                        \ will be at the next x-coordinate along

 BCC LI306              \ If the pixel didn't fall out of the right end of R
                        \ into the C flag, then jump to LI306 to plot the pixel
                        \ on the next character row up

 LDA #%10001000         \ Set a mask in R to the first pixel in the four-pixel
 STA R                  \ byte

 LDA SC                 \ Add 8 to SC, so SC(1 0) now points to the next
 ADC #7                 \ character along to the right (the C flag is set as we
 STA SC                 \ didn't take the above BCC, so the ADC adds 8)

 BCC LI306              \ If the addition didn't overflow, jump to LI306 to plot
                        \ the pixel on the next character row up

 INC SC+1               \ The addition overflowed, so increment the high byte in
                        \ SC(1 0) to move to the next page in screen memory

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 BCC LI306              \ Jump to LI306 to rejoin the pixel plotting routine
                        \ (this BCC is effectively a JMP as the C flag is clear)

.LI316

 LSR R                  \ If we get here then the slope error just overflowed
                        \ after plotting the pixel in LI306, so shift the single
                        \ pixel in R to the right, so the next pixel we plot
                        \ will be at the next x-coordinate along

 BCC LI307              \ If the pixel didn't fall out of the right end of R
                        \ into the C flag, then jump to LI307 to plot the pixel
                        \ on the next character row up

 LDA #%10001000         \ Set a mask in R to the first pixel in the four-pixel
 STA R                  \ byte

 LDA SC                 \ Add 8 to SC, so SC(1 0) now points to the next
 ADC #7                 \ character along to the right (the C flag is set as we
 STA SC                 \ didn't take the above BCC, so the ADC adds 8)

 BCC LI307              \ If the addition didn't overflow, jump to LI307 to plot
                        \ the pixel on the next character row up

 INC SC+1               \ The addition overflowed, so increment the high byte in
                        \ SC(1 0) to move to the next page in screen memory

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 BCC LI307              \ Jump to LI307 to rejoin the pixel plotting routine
                        \ (this BCC is effectively a JMP as the C flag is clear)

\ ******************************************************************************
\
\       Name: LOINQ (Part 7 of 7)
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw a steep line going up and right or down and left
\  Deep dive: Elite's line-drawing algorithm
\
\ ------------------------------------------------------------------------------
\
\ This routine draws a line from (X1, Y1) to (X2, Y2). It has multiple stages.
\ If we get here, then:
\
\   * The line is going up and right (no swap) or down and left (swap)
\
\   * X1 >= X2 and Y1 >= Y2
\
\   * Draw from (X1, Y1) at bottom left to (X2, Y2) at top right, omitting the
\     first pixel
\
\ This routine looks complex, but that's because the loop that's used in the
\ BBC Micro cassette and disc versions has been unrolled to speed it up. The
\ algorithm is unchanged, it's just a lot longer.
\
\ ******************************************************************************

.LFT

 LDA SWAP               \ If SWAP = 0 then we didn't swap the coordinates above,
 BEQ LI291              \ so jump down to LI291 to plot the first pixel

 TYA                    \ Fetch bits 0-2 of the y-coordinate, so Y contains the
 AND #7                 \ y-coordinate mod 8
 TAY                    \
                        \ So Y is the pixel row within the character block where
                        \ we want to start drawing

 BNE P%+5               \ If Y = 0, jump to LI407+8 to start plotting from the
 JMP LI407+8            \ pixel above the top row of this character block
                        \ (LI407+8 points to the DEX instruction after the
                        \ EOR/STA instructions, so the pixel at row 0 doesn't
                        \ get plotted but we join at the right point to
                        \ decrement X and Y correctly to continue plotting from
                        \ the character row above)

 CPY #2                 \ If Y < 2 (i.e. Y = 1), jump to LI406+8 to start
 BCS P%+5               \ plotting from row 0 of this character block, missing
 JMP LI406+8            \ out row 1

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 BNE P%+5               \ If Y = 2, jump to LI405+8 to start plotting from row
 JMP LI405+8            \ 1 of this character block, missing out row 2

 CPY #4                 \ If Y < 4 (i.e. Y = 3), jump to LI404+8 to start
 BCS P%+5               \ plotting from row 2 of this character block, missing
 JMP LI404+8            \ out row 3

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 BNE P%+5               \ If Y = 4, jump to LI403+8 to start plotting from row
 JMP LI403+8            \ 3 of this character block, missing out row 4

 CPY #6                 \ If Y < 6 (i.e. Y = 5), jump to LI402+8 to start
 BCS P%+5               \ plotting from row 4 of this character block, missing
 JMP LI402+8            \ out row 5

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 BEQ P%+5               \ If Y <> 6 (i.e. Y = 7), jump to LI400+8 to start
 JMP LI400+8            \ plotting from row 6 of this character block, missing
                        \ out row 7

 JMP LI401+8            \ Otherwise Y = 6, so jump to LI401+8 to start plotting
                        \ from row 5 of this character block, missing out row 6

.LI291

 DEX                    \ Decrement the counter in X because we're about to plot
                        \ the first pixel

 TYA                    \ Fetch bits 0-2 of the y-coordinate, so Y contains the
 AND #7                 \ y-coordinate mod 8
 TAY                    \
                        \ So Y is the pixel row within the character block where
                        \ we want to start drawing

 BNE P%+5               \ If Y = 0, jump to LI407 to start plotting from row 0
 JMP LI407              \ of this character block

 CPY #2                 \ If Y < 2 (i.e. Y = 1), jump to LI406 to start plotting
 BCS P%+5               \ from row 1 of this character block
 JMP LI406

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 BNE P%+5               \ If Y = 2, jump to LI405 to start plotting from row 2
 JMP LI405              \ of this character block

 CPY #4                 \ If Y < 4 (i.e. Y = 3), jump to LI404 (via LI404S) to
 BCC LI404S             \ start plotting from row 3 of this character block

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 BEQ LI403S             \ If Y = 4, jump to LI403 (via LI403S) to start plotting
                        \ from row 4 of this character block

 CPY #6                 \ If Y < 6 (i.e. Y = 5), jump to LI402 (via LI402S) to
 BCC LI402S             \ start plotting from row 5 of this character block

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 BEQ LI401S             \ If Y = 6, jump to LI401 (via LI401S) to start plotting
                        \ from row 6 of this character block

 JMP LI400              \ Otherwise Y = 7, so jump to LI400 to start plotting
                        \ from row 7 of this character block

.LI410

 ASL R                  \ If we get here then the slope error just overflowed
                        \ after plotting the pixel in LI400, so shift the single
                        \ pixel in R to the left, so the next pixel we plot will
                        \ be at the previous x-coordinate

 BCC LI401              \ If the pixel didn't fall out of the left end of R
                        \ into the C flag, then jump to LI401 to plot the pixel
                        \ on the next character row up

 LDA #%00010001         \ Otherwise we need to move over to the next character
 STA R                  \ block to the left, so set a mask in R to the fourth
                        \ pixel in the four-pixel byte

 LDA SC                 \ Subtract 8 from SC, so SC(1 0) now points to the
 SBC #8                 \ previous character along to the left
 STA SC

 BCS P%+4               \ If the subtraction underflowed, decrement the high
 DEC SC+1               \ byte in SC(1 0) to move to the previous page in
                        \ screen memory

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

.LI401S

 BCC LI401              \ Jump to LI401 to rejoin the pixel plotting routine
                        \ (this BCC is effectively a JMP as the C flag is clear)

.LI411

 ASL R                  \ If we get here then the slope error just overflowed
                        \ after plotting the pixel in LI410, so shift the single
                        \ pixel in R to the left, so the next pixel we plot will
                        \ be at the previous x-coordinate

 BCC LI402              \ If the pixel didn't fall out of the left end of R
                        \ into the C flag, then jump to LI402 to plot the pixel
                        \ on the next character row up

 LDA #%00010001         \ Otherwise we need to move over to the next character
 STA R                  \ block to the left, so set a mask in R to the fourth
                        \ pixel in the four-pixel byte

 LDA SC                 \ Subtract 8 from SC, so SC(1 0) now points to the
 SBC #8                 \ previous character along to the left
 STA SC

 BCS P%+4               \ If the subtraction underflowed, decrement the high
 DEC SC+1               \ byte in SC(1 0) to move to the previous page in
                        \ screen memory

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

.LI402S

 BCC LI402              \ Jump to LI402 to rejoin the pixel plotting routine
                        \ (this BCC is effectively a JMP as the C flag is clear)

.LI412

 ASL R                  \ If we get here then the slope error just overflowed
                        \ after plotting the pixel in LI420, so shift the single
                        \ pixel in R to the left, so the next pixel we plot will
                        \ be at the previous x-coordinate

 BCC LI403              \ If the pixel didn't fall out of the left end of R
                        \ into the C flag, then jump to LI403 to plot the pixel
                        \ on the next character row up

 LDA #%00010001         \ Otherwise we need to move over to the next character
 STA R                  \ block to the left, so set a mask in R to the fourth
                        \ pixel in the four-pixel byte

 LDA SC                 \ Subtract 8 from SC, so SC(1 0) now points to the
 SBC #8                 \ previous character along to the left
 STA SC

 BCS P%+4               \ If the subtraction underflowed, decrement the high
 DEC SC+1               \ byte in SC(1 0) to move to the previous page in
                        \ screen memory

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

.LI403S

 BCC LI403              \ Jump to LI403 to rejoin the pixel plotting routine
                        \ (this BCC is effectively a JMP as the C flag is clear)

.LI413

 ASL R                  \ If we get here then the slope error just overflowed
                        \ after plotting the pixel in LI430, so shift the single
                        \ pixel in R to the left, so the next pixel we plot will
                        \ be at the previous x-coordinate

 BCC LI404              \ If the pixel didn't fall out of the left end of R
                        \ into the C flag, then jump to LI404 to plot the pixel
                        \ on the next character row up

 LDA #%00010001         \ Otherwise we need to move over to the next character
 STA R                  \ block to the left, so set a mask in R to the fourth
                        \ pixel in the four-pixel byte

 LDA SC                 \ Subtract 8 from SC, so SC(1 0) now points to the
 SBC #8                 \ previous character along to the left
 STA SC

 BCS P%+4               \ If the subtraction underflowed, decrement the high
 DEC SC+1               \ byte in SC(1 0) to move to the previous page in
                        \ screen memory

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

.LI404S

 BCC LI404              \ Jump to LI404 to rejoin the pixel plotting routine
                        \ (this BCC is effectively a JMP as the C flag is clear)

.LIEX5

 RTS                    \ Return from the subroutine

.LI400

                        \ Plot a pixel on row 7 of this character block

 LDA R                  \ Fetch the pixel byte from R and apply the colour in
 AND COL                \ COL to it

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX5              \ If we have just reached the right end of the line,
                        \ jump to LIEX5 to return from the subroutine

 DEY                    \ Decrement Y to step up along the y-axis

 LDA S                  \ Set S = S + P to update the slope error
 ADC P
 STA S

 BCS LI410              \ If the addition overflowed, jump to LI410 to move to
                        \ the pixel in the row above, which returns us to LI401
                        \ below

.LI401

                        \ Plot a pixel on row 6 of this character block

 LDA R                  \ Fetch the pixel byte from R and apply the colour in
 AND COL                \ COL to it

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX5              \ If we have just reached the right end of the line,
                        \ jump to LIEX5 to return from the subroutine

 DEY                    \ Decrement Y to step up along the y-axis

 LDA S                  \ Set S = S + P to update the slope error
 ADC P
 STA S

 BCS LI411              \ If the addition overflowed, jump to LI411 to move to
                        \ the pixel in the row above, which returns us to LI402
                        \ below

.LI402

                        \ Plot a pixel on row 5 of this character block

 LDA R                  \ Fetch the pixel byte from R and apply the colour in
 AND COL                \ COL to it

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX5              \ If we have just reached the right end of the line,
                        \ jump to LIEX5 to return from the subroutine

 DEY                    \ Decrement Y to step up along the y-axis

 LDA S                  \ Set S = S + P to update the slope error
 ADC P
 STA S

 BCS LI412              \ If the addition overflowed, jump to LI412 to move to
                        \ the pixel in the row above, which returns us to LI403
                        \ below

.LI403

                        \ Plot a pixel on row 4 of this character block

 LDA R                  \ Fetch the pixel byte from R and apply the colour in
 AND COL                \ COL to it

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX5              \ If we have just reached the right end of the line,
                        \ jump to LIEX5 to return from the subroutine

 DEY                    \ Decrement Y to step up along the y-axis

 LDA S                  \ Set S = S + P to update the slope error
 ADC P
 STA S

 BCS LI413              \ If the addition overflowed, jump to LI413 to move to
                        \ the pixel in the row above, which returns us to LI404
                        \ below

.LI404

                        \ Plot a pixel on row 3 of this character block

 LDA R                  \ Fetch the pixel byte from R and apply the colour in
 AND COL                \ COL to it

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX6              \ If we have just reached the right end of the line,
                        \ jump to LIEX6 to return from the subroutine

 DEY                    \ Decrement Y to step up along the y-axis

 LDA S                  \ Set S = S + P to update the slope error
 ADC P
 STA S

 BCS LI414              \ If the addition overflowed, jump to LI414 to move to
                        \ the pixel in the row above, which returns us to LI405
                        \ below

.LI405

                        \ Plot a pixel on row 2 of this character block

 LDA R                  \ Fetch the pixel byte from R and apply the colour in
 AND COL                \ COL to it

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX6              \ If we have just reached the right end of the line,
                        \ jump to LIEX6 to return from the subroutine

 DEY                    \ Decrement Y to step up along the y-axis

 LDA S                  \ Set S = S + P to update the slope error
 ADC P
 STA S

 BCS LI415              \ If the addition overflowed, jump to LI415 to move to
                        \ the pixel in the row above, which returns us to LI406
                        \ below

.LI406

                        \ Plot a pixel on row 1 of this character block

 LDA R                  \ Fetch the pixel byte from R and apply the colour in
 AND COL                \ COL to it

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX6              \ If we have just reached the right end of the line,
                        \ jump to LIEX6 to return from the subroutine

 DEY                    \ Decrement Y to step up along the y-axis

 LDA S                  \ Set S = S + P to update the slope error
 ADC P
 STA S

 BCS LI416              \ If the addition overflowed, jump to LI416 to move to
                        \ the pixel in the row above, which returns us to LI407
                        \ below

.LI407

                        \ Plot a pixel on row 0 of this character block

 LDA R                  \ Fetch the pixel byte from R and apply the colour in
 AND COL                \ COL to it

 EOR (SC),Y             \ Store A into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen

 DEX                    \ Decrement the counter in X

 BEQ LIEX6              \ If we have just reached the right end of the line,
                        \ jump to LIEX6 to return from the subroutine

 DEC SC+1               \ We just reached the top of the character block, so
 DEC SC+1               \ decrement the high byte in SC(1 0) twice to point to
 LDY #7                 \ the screen row above (as there are two pages per
                        \ screen row) and set Y to point to the last row in the
                        \ new character block

 LDA S                  \ Set S = S + P to update the slope error
 ADC P
 STA S

 BCS P%+5               \ If the addition didn't overflow, jump to LI400 to
 JMP LI400              \ continue plotting from row 7 of the new character
                        \ block

 ASL R                  \ If we get here then the slope error just overflowed
                        \ after plotting the pixel in LI407 above, so shift the
                        \ single pixel in R to the left, so the next pixel we
                        \ plot will be at the previous x-coordinate

 BCS P%+5               \ If the pixel didn't fall out of the left end of R
 JMP LI400              \ into the C flag, then jump to LI400 to continue
                        \ plotting from row 7 of the new character block

 LDA #%00010001         \ Otherwise we need to move over to the next character
 STA R                  \ block to the left, so set a mask in R to the fourth
                        \ pixel in the four-pixel byte

 LDA SC                 \ Subtract 8 from SC, so SC(1 0) now points to the
 SBC #8                 \ previous character along to the left
 STA SC

 BCS P%+4               \ If the subtraction underflowed, decrement the high
 DEC SC+1               \ byte in SC(1 0) to move to the previous page in
                        \ screen memory

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 JMP LI400              \ Jump to LI400 to continue plotting from row 7 of the
                        \ new character block

.LIEX6

 RTS                    \ Return from the subroutine

.LI414

 ASL R                  \ If we get here then the slope error just overflowed
                        \ after plotting the pixel in LI440, so shift the single
                        \ pixel in R to the left, so the next pixel we plot will
                        \ be at the previous x-coordinate

 BCC LI405              \ If the pixel didn't fall out of the left end of R
                        \ into the C flag, then jump to LI405 to plot the pixel
                        \ on the next character row up

 LDA #%00010001         \ Otherwise we need to move over to the next character
 STA R                  \ block to the left, so set a mask in R to the fourth
                        \ pixel in the four-pixel byte

 LDA SC                 \ Subtract 8 from SC, so SC(1 0) now points to the
 SBC #8                 \ previous character along to the left
 STA SC

 BCS P%+4               \ If the subtraction underflowed, decrement the high
 DEC SC+1               \ byte in SC(1 0) to move to the previous page in
                        \ screen memory

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 BCC LI405              \ Jump to LI405 to rejoin the pixel plotting routine
                        \ (this BCC is effectively a JMP as the C flag is clear)

.LI415

 ASL R                  \ If we get here then the slope error just overflowed
                        \ after plotting the pixel in LI450, so shift the single
                        \ pixel in R to the left, so the next pixel we plot will
                        \ be at the previous x-coordinate

 BCC LI406              \ If the pixel didn't fall out of the left end of R
                        \ into the C flag, then jump to LI406 to plot the pixel
                        \ on the next character row up

 LDA #%00010001         \ Otherwise we need to move over to the next character
 STA R                  \ block to the left, so set a mask in R to the fourth
                        \ pixel in the four-pixel byte

 LDA SC                 \ Subtract 8 from SC, so SC(1 0) now points to the
 SBC #8                 \ previous character along to the left
 STA SC

 BCS P%+4               \ If the subtraction underflowed, decrement the high
 DEC SC+1               \ byte in SC(1 0) to move to the previous page in
                        \ screen memory

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 BCC LI406              \ Jump to LI406 to rejoin the pixel plotting routine
                        \ (this BCC is effectively a JMP as the C flag is clear)

.LI416

 ASL R                  \ If we get here then the slope error just overflowed
                        \ after plotting the pixel in LI460, so shift the single
                        \ pixel in R to the left, so the next pixel we plot will
                        \ be at the previous x-coordinate

 BCC LI407              \ If the pixel didn't fall out of the left end of R
                        \ into the C flag, then jump to LI407 to plot the pixel
                        \ on the next character row up

 LDA #%00010001         \ Otherwise we need to move over to the next character
 STA R                  \ block to the left, so set a mask in R to the fourth
                        \ pixel in the four-pixel byte

 LDA SC                 \ Subtract 8 from SC, so SC(1 0) now points to the
 SBC #8                 \ previous character along to the left
 STA SC

 BCS P%+4               \ If the subtraction underflowed, decrement the high
 DEC SC+1               \ byte in SC(1 0) to move to the previous page in
                        \ screen memory

 CLC                    \ Clear the C flag so it doesn't affect the arithmetic
                        \ below

 JMP LI407              \ Jump to LI407 to rejoin the pixel plotting routine

\ ******************************************************************************
\
\       Name: HLOIN
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw a horizontal line from (X1, Y1) to (X2, Y1)
\  Deep dive: Drawing colour pixels on the BBC Micro
\
\ ------------------------------------------------------------------------------
\
\ This routine draws a horizontal orange line in the space view.
\
\ We do not draw a pixel at the right end of the line.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   Y                   Y is preserved
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   HLOIN3              Draw a line from (X, Y1) to (X2, Y1) in the colour given
\                       in A
\
\ ******************************************************************************

.HLOIN

 JSR H_HLOIN            \ Port: in record mode the renderer fills the sun, so
                        \ return at once (gfx-hooks.asm)

 LDA Y1                 \ Set A = Y1, the pixel y-coordinate of the line

 AND #3                 \ Set A to the correct order of red/yellow pixels to
 TAX                    \ make this line an orange colour (by using bits 0-1 of
 LDA orange,X           \ the pixel y-coordinate as the index into the orange
                        \ lookup table)

 STA COL                \ Store the correct orange colour in COL

.HLOIN3

 STY YSAV               \ Store Y into YSAV, so we can preserve it across the
                        \ call to this subroutine

 LDY #%00001111         \ Set bits 1 and 2 of the Access Control Register at
 STY VIA+&34            \ SHEILA &34 to switch screen memory into &3000-&7FFF

 LDX X1                 \ Set X = X1

 CPX X2                 \ If X1 = X2 then the start and end points are the same,
 BEQ HL6                \ so return from the subroutine (as HL6 contains an RTS)

 BCC HL5                \ If X1 < X2, jump to HL5 to skip the following code, as
                        \ (X1, Y1) is already the left point

 LDA X2                 \ Swap the values of X1 and X2, so we know that (X1, Y1)
 STA X1                 \ is on the left and (X2, Y1) is on the right
 STX X2

 TAX                    \ Set X = X1

.HL5

 DEC X2                 \ Decrement X2 so we do not draw a pixel at the end
                        \ point

 LDY Y1                 \ Look up the page number of the character row that
 LDA ylookup,Y          \ contains the pixel with the y-coordinate in Y1, and
 STA SC+1               \ store it in SC+1, so the high byte of SC is set
                        \ correctly for drawing our line

 TYA                    \ Set A = Y1 mod 8, which is the pixel row within the
 AND #7                 \ character block at which we want to draw our line (as
                        \ each character block has 8 rows)

 STA SC                 \ Store this value in SC, so SC(1 0) now contains the
                        \ screen address of the far left end (x-coordinate = 0)
                        \ of the horizontal pixel row that we want to draw our
                        \ horizontal line on

 TXA                    \ Set Y = 2 * bits 2-6 of X1
 AND #%11111100         \
 ASL A                  \ and shift bit 7 of X1 into the C flag
 TAY

 BCC P%+4               \ If bit 7 of X1 was set, so X1 > 127, increment the
 INC SC+1               \ high byte of SC(1 0) to point to the second page on
                        \ this screen row, as this page contains the right half
                        \ of the row

.HL1

 TXA                    \ Set T = bits 2-7 of X1, which will contain the
 AND #%11111100         \ character number of the start of the line * 4
 STA T

 LDA X2                 \ Set A = bits 2-7 of X2, which will contain the
 AND #%11111100         \ character number of the end of the line * 4

 SEC                    \ Set A = A - T, which will contain the number of
 SBC T                  \ character blocks we need to fill - 1 * 4

 BEQ HL2                \ If A = 0 then the start and end character blocks are
                        \ the same, so the whole line fits within one block, so
                        \ jump down to HL2 to draw the line

                        \ Otherwise the line spans multiple characters, so we
                        \ start with the left character, then do any characters
                        \ in the middle, and finish with the right character

 LSR A                  \ Set R = A / 4, so R now contains the number of
 LSR A                  \ character blocks we need to fill - 1
 STA R

 LDA X1                 \ Set X = X1 mod 4, which is the horizontal pixel number
 AND #3                 \ within the character block where the line starts (as
 TAX                    \ each pixel line in the character block is 4 pixels
                        \ wide)

 LDA TWFR,X             \ Fetch a ready-made byte with X pixels filled in at the
                        \ right end of the byte (so the filled pixels start at
                        \ point X and go all the way to the end of the byte),
                        \ which is the shape we want for the left end of the
                        \ line

 AND COL                \ Apply the pixel mask in A to the four-pixel block of
                        \ coloured pixels in COL, so we now know which bits to
                        \ set in screen memory to paint the relevant pixels in
                        \ the required colour

 EOR (SC),Y             \ Store this into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen,
                        \ so we have now drawn the line's left cap

 TYA                    \ Set Y = Y + 8 so (SC),Y points to the next character
 ADC #8                 \ block along, on the same pixel row as before
 TAY

 BCS HL7                \ If the above addition overflowed, then we have just
                        \ crossed over from the left half of the screen into the
                        \ right half, so call HL7 to increment the high byte in
                        \ SC+1 so that SC(1 0) points to the page in screen
                        \ memory for the right half of the screen row. HL7 also
                        \ clears the C flag and jumps back to HL8, so this acts
                        \ like a conditional JSR instruction

.HL8

 LDX R                  \ Fetch the number of character blocks we need to fill
                        \ from R

 DEX                    \ Decrement the number of character blocks in X

 BEQ HL3                \ If X = 0 then we only have the last block to do (i.e.
                        \ the right cap), so jump down to HL3 to draw it

 CLC                    \ Otherwise clear the C flag so we can do some additions
                        \ while we draw the character blocks with full-width
                        \ lines in them

.HLL1

 LDA COL                \ Store a full-width four-pixel horizontal line of
 EOR (SC),Y             \ colour COL in SC(1 0) so that it draws the line
 STA (SC),Y             \ on-screen, using EOR logic so it merges with whatever
                        \ is already on-screen

 TYA                    \ Set Y = Y + 8 so (SC),Y points to the next character
 ADC #8                 \ block along, on the same pixel row as before
 TAY

 BCS HL9                \ If the above addition overflowed, then we have just
                        \ crossed over from the left half of the screen into the
                        \ right half, so call HL9 to increment the high byte in
                        \ SC+1 so that SC(1 0) points to the page in screen
                        \ memory for the right half of the screen row. HL9 also
                        \ clears the C flag and jumps back to HL10, so this acts
                        \ like a conditional JSR instruction

.HL10

 DEX                    \ Decrement the number of character blocks in X

 BNE HLL1               \ Loop back to draw more full-width lines, if we have
                        \ any more to draw

.HL3

 LDA X2                 \ Now to draw the last character block at the right end
 AND #3                 \ of the line, so set X = X2 mod 3, which is the
 TAX                    \ horizontal pixel number where the line ends

 LDA TWFL,X             \ Fetch a ready-made byte with X pixels filled in at the
                        \ left end of the byte (so the filled pixels start at
                        \ the left edge and go up to point X), which is the
                        \ shape we want for the right end of the line

 AND COL                \ Apply the pixel mask in A to the four-pixel block of
                        \ coloured pixels in COL, so we now know which bits to
                        \ set in screen memory to paint the relevant pixels in
                        \ the required colour

 EOR (SC),Y             \ Store this into screen memory at SC(1 0), using EOR
 STA (SC),Y             \ logic so it merges with whatever is already on-screen,
                        \ so we have now drawn the line's right cap

.HL6

 LDY #%00001001         \ Clear bits 1 and 2 of the Access Control Register at
 STY VIA+&34            \ SHEILA &34 to switch main memory back into &3000-&7FFF

 LDY YSAV               \ Restore Y from YSAV, so that it's preserved

 RTS                    \ Return from the subroutine

.HL2

                        \ If we get here then the entire horizontal line fits
                        \ into one character block

 LDA X1                 \ Set X = X1 mod 4, which is the horizontal pixel number
 AND #3                 \ within the character block where the line starts (as
 TAX                    \ each pixel line in the character block is 4 pixels
                        \ wide)

 LDA TWFR,X             \ Fetch a ready-made byte with X pixels filled in at the
 STA T                  \ right end of the byte (so the filled pixels start at
                        \ point X and go all the way to the end of the byte)

 LDA X2                 \ Set X = X2 mod 4, which is the horizontal pixel number
 AND #3                 \ where the line ends
 TAX

 LDA TWFL,X             \ Fetch a ready-made byte with X pixels filled in at the
                        \ left end of the byte (so the filled pixels start at
                        \ the left edge and go up to point X)

 AND T                  \ We now have two bytes, one (T) containing pixels from
                        \ the starting point X1 onwards, and the other (A)
                        \ containing pixels up to the end point at X2, so we can
                        \ get the actual line we want to draw by AND'ing them
                        \ together. For example, if we want to draw a line from
                        \
                        \   T       = %00111111
                        \   A       = %11111100
                        \   T AND A = %00111100
                        \
                        \ So we can stick T AND A in screen memory to get the
                        \ line we want, which is what we do here by setting
                        \ A = A AND T

 AND COL                \ Apply the pixel mask in A to the four-pixel block of
                        \ coloured pixels in COL, so we now know which bits to
                        \ set in screen memory to paint the relevant pixels in
                        \ the required colour

 EOR (SC),Y             \ Store our horizontal line byte into screen memory at
 STA (SC),Y             \ SC(1 0), using EOR logic so it merges with whatever is
                        \ already on-screen

 LDY #%00001001         \ Clear bits 1 and 2 of the Access Control Register at
 STY VIA+&34            \ SHEILA &34 to switch main memory back into &3000-&7FFF

 LDY YSAV               \ Restore Y from YSAV, so that it's preserved

 RTS                    \ Return from the subroutine

.HL7

 INC SC+1               \ We have just crossed over from the left half of the
                        \ screen into the right half, so increment the high byte
                        \ in SC+1 so that SC(1 0) points to the page in screen
                        \ memory for the right half of the screen row

 CLC                    \ Clear the C flag (as HL7 is called with the C flag
                        \ set, which this instruction reverts)

 JMP HL8                \ Jump back to HL8, just after the instruction that
                        \ called HL7

.HL9

 INC SC+1               \ We have just crossed over from the left half of the
                        \ screen into the right half, so increment the high byte
                        \ in SC+1 so that SC(1 0) points to the page in screen
                        \ memory for the right half of the screen row

 CLC                    \ Clear the C flag (as HL9 is called with the C flag
                        \ set, which this instruction reverts)

 JMP HL10               \ Jump back to HL10, just after the instruction that
                        \ called HL9

\ ******************************************************************************
\
\       Name: TWFL
\       Type: Variable
\   Category: Drawing pixels
\    Summary: Ready-made character rows for the left end of a horizontal line
\
\ ------------------------------------------------------------------------------
\
\ Ready-made bytes for plotting horizontal line end caps in mode 1 (the top part
\ of the split screen). This table provides a byte with pixels at the left end,
\ which is used for the right end of the line.
\
\ See the HLOIN routine for details.
\
\ ******************************************************************************

.TWFL

 EQUB %10001000
 EQUB %11001100
 EQUB %11101110
 EQUB %11111111

\ ******************************************************************************
\
\       Name: TWFR
\       Type: Variable
\   Category: Drawing pixels
\    Summary: Ready-made character rows for the right end of a horizontal line
\
\ ------------------------------------------------------------------------------
\
\ Ready-made bytes for plotting horizontal line end caps in mode 1 (the top part
\ of the split screen). This table provides a byte with pixels at the left end,
\ which is used for the right end of the line.
\
\ See the HLOIN routine for details.
\
\ ******************************************************************************

.TWFR

 EQUB %11111111
 EQUB %01110111
 EQUB %00110011
 EQUB %00010001

\ ******************************************************************************
\
\       Name: orange
\       Type: Variable
\   Category: Drawing pixels
\    Summary: Lookup table for two-pixel mode 1 orange pixels for the sun
\
\ ------------------------------------------------------------------------------
\
\ Blocks of orange (as used when drawing the sun) have alternate red and yellow
\ pixels in a cross-hatch pattern. The cross-hatch pattern is made up of offset
\ rows that are 2 pixels high, and it is made up of red and yellow rectangles,
\ each of which is 2 pixels high and 1 pixel wide. The result looks like this:
\
\   ...ryryryryryryryry...
\   ...ryryryryryryryry...
\   ...yryryryryryryryr...
\   ...yryryryryryryryr...
\   ...ryryryryryryryry...
\   ...ryryryryryryryry...
\
\ and so on, repeating every four pixel rows.
\
\ This is implemented with the following lookup table, where bits 0-1 of the
\ pixel y-coordinate are used as the index, to fetch the correct pattern to use.
\
\ Rows with y-coordinates ending in %00 or %01 fetch the red/yellow pattern from
\ the table, while rows with y-coordinates ending in %10 or %11 fetch the
\ yellow/red pattern, so the pattern repeats every four pixel rows.
\
\ ******************************************************************************

.orange

 EQUB %10100101         \ Four mode 1 pixels of colour 2, 1, 2, 1 (red/yellow)
 EQUB %10100101
 EQUB %01011010         \ Four mode 1 pixels of colour 1, 2, 1, 2 (yellow/red)
 EQUB %01011010

\ ******************************************************************************
\
\       Name: PIX1
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (YY+1 SYL+Y) = (A P) + (S R) and draw stardust particle
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following:
\
\   (YY+1 SYL+Y) = (A P) + (S R)
\
\ and draw a stardust particle at (X1,Y1) with distance ZZ.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   (A P)               A is the angle ALPHA or BETA, P is always 0
\
\   (S R)               YY(1 0) or YY(1 0) + Q * A
\
\   Y                   Stardust particle number
\
\   X1                  The x-coordinate offset
\
\   Y1                  The y-coordinate offset
\
\   ZZ                  The distance of the point, with bigger distances drawing
\                       smaller points:
\
\                         * ZZ < 80           Double-height four-pixel square
\
\                         * 80 <= ZZ <= 143   Single-height two-pixel dash
\
\                         * ZZ > 143          Single-height one-pixel dot
\
\ ******************************************************************************

.PIX1

 JSR ADD                \ Set (A X) = (A P) + (S R) (Port: ADD, ADDK's twin, which
                        \ is below &3000)

 STA YY+1               \ Set YY+1 to A, the high byte of the result

 TXA                    \ Set SYL+Y to X, the low byte of the result
 STA SYL,Y

 LDA QQ11               \ Port: in record mode PIX1's drawing only erases the
 ORA GFORCE             \ particle's old position, which the renderer has no
 BNE PIXEL2             \ need of (the particle's new position is recorded by
 RTS                    \ the PIXEL2 call that follows for it), so return

                        \ Fall through into PIXEL2 to draw the stardust particle
                        \ at (X1,Y1)

\ ******************************************************************************
\
\       Name: PIXEL2
\       Type: Subroutine
\   Category: Drawing pixels
\    Summary: Draw a stardust particle relative to the screen centre
\
\ ------------------------------------------------------------------------------
\
\ Draw a point (X1, Y1) from the middle of the screen with a size determined by
\ a distance value. Used to draw stardust particles.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X1                  The x-coordinate offset
\
\   Y1                  The y-coordinate offset (positive means up the screen
\                       from the centre, negative means down the screen)
\
\   ZZ                  The distance of the point, with bigger distances drawing
\                       smaller points:
\
\                         * ZZ < 80           Double-height four-pixel square
\
\                         * 80 <= ZZ <= 143   Single-height two-pixel dash
\
\                         * ZZ > 143          Single-height one-pixel dot
\
\ ******************************************************************************

.PIXEL2

 LDA X1                 \ Fetch the x-coordinate offset into A

 BPL PX21               \ If the x-coordinate offset is positive, jump to PX21
                        \ to skip the following negation

 EOR #%01111111         \ The x-coordinate offset is negative, so flip all the
 CLC                    \ bits apart from the sign bit and add 1, to convert it
 ADC #1                 \ from a sign-magnitude number to a signed number

.PX21

 EOR #%10000000         \ Set X = X1 + 128
 TAX                    \
                        \ So X is now the offset converted to an x-coordinate,
                        \ centred on x-coordinate 128

 LDA Y1                 \ Fetch the y-coordinate offset into A

 BPL PX23               \ If it is positive, A = |Y1| already, so jump to PX23
                        \ to do the on-screen check

 AND #%01111111         \ Clear the sign bit, so A = |Y1|

 CMP #Y                 \ If |Y1| >= #Y then it's off the screen (as #Y is half
 BCS PXOFF              \ the screen height), so return from the subroutine (Port:
                        \ via H_STAROFF, gfx-hooks.asm, as the renderer records
                        \ that it is off screen)

 EOR #%11111111         \ The y-coordinate offset is negative, so negate |Y1|
 ADC #1                 \ (C is clear) to convert A from a sign-magnitude number
                        \ into a traditional signed number (the same ADC
                        \ operand, $FF - |Y1|, as Y1 EOR %01111111 gives, so
                        \ the result and flags are as before)

 BRA PX22               \ Jump to PX22 to convert it to a screen y-coordinate

.PX23

 CMP #Y                 \ If Y1 >= #Y then it's off the screen, so return from
 BCS PXOFF              \ the subroutine via H_STAROFF with A = |Y1|

.PX22

 STA T                  \ Set A = #Y + 1 - Y1 (Port: as ~T + #Y + 1 + C, which
 EOR #%11111111         \ is exactly what SBC T computes, with the same C, N,
 ADC #Y+1               \ Z and V; T is still stored)
                        \
                        \ So if Y1 is positive we display the point up from the
                        \ centre at y-coordinate 97, while a negative Y1 means
                        \ down from the centre

                        \ Fall through into PIXEL to draw the stardust at the
                        \ screen coordinates in (X, A)

 JMP H_STAR             \ Port: in record mode, record star Y's position for the
                        \ renderer and return from PIXEL2 (gfx-hooks.asm),
                        \ otherwise jump back to PIXEL to draw it

\ ******************************************************************************
\
\       Name: PIXEL
\       Type: Subroutine
\   Category: Drawing pixels
\    Summary: Draw a one-pixel dot, two-pixel dash or four-pixel square
\  Deep dive: Drawing colour pixels on the BBC Micro
\
\ ------------------------------------------------------------------------------
\
\ Draw a point at screen coordinate (X, A) with the point size determined by the
\ distance in ZZ. This applies to the top part of the screen (the four-colour
\ mode 5 portion).
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The screen x-coordinate of the point to draw
\
\   A                   The screen y-coordinate of the point to draw
\
\   ZZ                  The distance of the point, with bigger distances drawing
\                       smaller points:
\
\                         * ZZ < 80           Double-height four-pixel square
\
\                         * 80 <= ZZ <= 143   Single-height two-pixel dash
\
\                         * ZZ > 143          Single-height one-pixel dot
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   Y                   Y is preserved
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   PXR1                Contains an RTS
\
\ ******************************************************************************

.PIXEL

 JSR H_DOT              \ Port: in record mode, record the dot (an explosion
                        \ particle) for the renderer and return (gfx-hooks.asm)

 STY T1                 \ Store Y in T1 so we can restore it at the end of the
                        \ subroutine

 LDY #%00001111         \ Set bits 1 and 2 of the Access Control Register at
 STY VIA+&34            \ SHEILA &34 to switch screen memory into &3000-&7FFF

 TAY                    \ Copy the screen y-coordinate from A into Y

 LDA ylookup,Y          \ Look up the page number of the character row that
 STA SC+1               \ contains the pixel with the y-coordinate in Y, and
                        \ store it in the high byte of SC(1 0) at SC+1

 TXA                    \ Each character block contains 8 pixel rows, so to get
 AND #%11111100         \ the address of the first byte in the character block
 ASL A                  \ that we need to draw into, as an offset from the start
                        \ of the row, we clear bits 0-1 and shift left to double
                        \ it (as each character row contains two pages of bytes,
                        \ or 512 bytes, which cover 256 pixels). This also
                        \ shifts bit 7 of the x-coordinate into the C flag

 STA SC                 \ Store the address of the character block in the low
                        \ byte of SC(1 0), so now SC(1 0) points to the
                        \ character block we need to draw into

 BCC P%+4               \ If the C flag is clear then skip the next instruction

 INC SC+1               \ The C flag is set, which means bit 7 of X1 was set
                        \ before the ASL above, so the x-coordinate is in the
                        \ right half of the screen (i.e. in the range 128-255).
                        \ Each row takes up two pages in memory, so the right
                        \ half is in the second page but SC+1 contains the value
                        \ we looked up from ylookup, which is the page number of
                        \ the first memory page for the row... so we need to
                        \ increment SC+1 to point to the correct page

 TYA                    \ Set Y = Y mod 8, which is the pixel row within the
 AND #7                 \ character block at which we want to draw the pixel
 TAY                    \ (as each character block has 8 rows)

 TXA                    \ Copy bits 0-1 of the x-coordinate to bits 0-1 of X,
 AND #%00000011         \ which will now be in the range 0-3, and will contain
 TAX                    \ the two pixels to show in the character row

 LDA ZZ                 \ Set A to the pixel's distance in ZZ

 CMP #80                \ If the pixel's ZZ distance is < 80, then the dot is
 BCC PX2                \ pretty close, so jump to PX2 to draw a four-pixel
                        \ square

 LDA TWOS2,X            \ Fetch a mode 1 two-pixel byte with the pixels set as
 AND COL                \ in X, and AND with the colour byte we fetched into COL
                        \ so that pixel takes on the colour we want to draw
                        \ (i.e. A is acting as a mask on the colour byte)

 EOR (SC),Y             \ Draw the pixel on-screen using EOR logic, so we can
 STA (SC),Y             \ remove it later without ruining the background that's
                        \ already on-screen

 LDY #%00001001         \ Clear bits 1 and 2 of the Access Control Register at
 STY VIA+&34            \ SHEILA &34 to switch main memory back into &3000-&7FFF

 LDY T1                 \ Restore Y from T1, so Y is preserved by the routine

.PXR1

 RTS                    \ Return from the subroutine

.PX2

                        \ If we get here, we need to plot a four-pixel square in
                        \ in the correct colour for this pixel's distance

 LDA TWOS2,X            \ Fetch a mode 1 two-pixel byte with the pixels set as
 AND COL                \ in X, and AND with the colour byte we fetched into COL
                        \ so that pixel takes on the colour we want to draw
                        \ (i.e. A is acting as a mask on the colour byte)

 EOR (SC),Y             \ Draw the pixel on-screen using EOR logic, so we can
 STA (SC),Y             \ remove it later without ruining the background that's
                        \ already on-screen

 DEY                    \ Reduce Y by 1 to point to the pixel row above the one
 BPL P%+4               \ we just plotted, and if it is still positive, skip the
                        \ next instruction

 LDY #1                 \ Reducing Y by 1 made it negative, which means Y was
                        \ 0 before we did the DEY above, so set Y to 1 to point
                        \ to the pixel row after the one we just plotted

                        \ We now draw our second dash

 LDA TWOS2,X            \ Fetch a mode 1 two-pixel byte with the pixels set as
 AND COL                \ in X, and AND with the colour byte we fetched into COL
                        \ so that pixel takes on the colour we want to draw
                        \ (i.e. A is acting as a mask on the colour byte)

 EOR (SC),Y             \ Draw the pixel on-screen using EOR logic, so we can
 STA (SC),Y             \ remove it later without ruining the background that's
                        \ already on-screen

 LDY #%00001001         \ Clear bits 1 and 2 of the Access Control Register at
 STY VIA+&34            \ SHEILA &34 to switch main memory back into &3000-&7FFF

 LDY T1                 \ Restore Y from T1, so Y is preserved by the routine

 RTS                    \ Return from the subroutine

.PXOFF

 JMP H_STAROFF          \ Port: PIXEL2's star Y is off screen (gfx-hooks.asm)

\ ******************************************************************************
\
\       Name: PXCL
\       Type: Variable
\   Category: Drawing pixels
\    Summary: A four-colour mode 1 pixel byte that represents a dot's distance
\
\ ------------------------------------------------------------------------------
\
\ The following table contains colour bytes for two-pixel mode 1 pixels, with
\ the index into the table representing distance. Closer pixels are at the top,
\ so the closest pixels are cyan/red, then yellow, then red, then red/yellow,
\ then yellow.
\
\ That said, this table is only used with odd distance values, as set in the
\ parasite's PIXEL3 routine, so in practice the four distances are yellow, red,
\ red/yellow, yellow.
\
\ ******************************************************************************

.PXCL

 EQUB WHITE             \ Four mode 1 pixels of colour 3, 2, 3, 2 (cyan/red)
 EQUB %00001111         \ Four mode 1 pixels of colour 1 (yellow)
 EQUB %00001111         \ Four mode 1 pixels of colour 1 (yellow)
 EQUB %11110000         \ Four mode 1 pixels of colour 2 (red)
 EQUB %11110000         \ Four mode 1 pixels of colour 2 (red)
 EQUB %10100101         \ Four mode 1 pixels of colour 2, 1, 2, 1 (red/yellow)
 EQUB %10100101         \ Four mode 1 pixels of colour 2, 1, 2, 1 (red/yellow)
 EQUB %00001111         \ Four mode 1 pixels of colour 1, 1, 1, 1 (yellow)

\ ******************************************************************************
\
\       Name: HANGFLAG
\       Type: Variable
\   Category: Ship hangar
\    Summary: The number of ships being displayed in the ship hangar
\
\ ******************************************************************************

.HANGFLAG

 EQUB 0

\ ******************************************************************************
\
\       Name: HANGER
\       Type: Subroutine
\   Category: Ship hangar
\    Summary: Display the ship hangar
\
\ ------------------------------------------------------------------------------
\
\ This routine is called after the ships in the hangar have been drawn, so all
\ it has to do is draw the hangar's background.
\
\ The hangar background is made up of two parts:
\
\   * The hangar floor consists of 11 screen-wide horizontal lines, which start
\     out quite spaced out near the bottom of the screen, and bunch ever closer
\     together as the eye moves up towards the horizon, where they merge to give
\     a sense of perspective
\
\   * The back wall of the hangar consists of 15 equally spaced vertical lines
\     that join the horizon to the top of the screen
\
\ The ships in the hangar have already been drawn by this point, so the lines
\ are drawn so they don't overlap anything that's already there, which makes
\ them look like they are behind and below the ships. This is achieved by
\ drawing the lines in from the screen edges until they bump into something
\ already on-screen. For the horizontal lines, when there are multiple ships in
\ the hangar, this also means drawing lines between the ships, as well as in
\ from each side.
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   HA3                 Contains an RTS
\
\ ******************************************************************************

.HANGER

                        \ We start by drawing the floor

 LDX #2                 \ We start with a loop using a counter in T that goes
                        \ from 2 to 12, one for each of the 11 horizontal lines
                        \ in the floor, so set the initial value in X

 LDA #%00001111         \ Set bits 1 and 2 of the Access Control Register at
 STA VIA+&34            \ SHEILA &34 to switch screen memory into &3000-&7FFF

.HAL1

 STX T                  \ Store the loop counter in T

 LDA #130               \ Set A = 130

 STX Q                  \ Set Q to the value of the loop counter

 JSR DVID4K             \ Calculate the following:
                        \
                        \   (P R) = 256 * A / Q
                        \         = 256 * 130 / Q
                        \
                        \ so P = 130 / Q, and as the counter Q goes from 2 to
                        \ 12, P goes 65, 43, 32 ... 13, 11, 10, with the
                        \ difference between two consecutive numbers getting
                        \ smaller as P gets smaller
                        \
                        \ We can use this value as a y-coordinate to draw a set
                        \ of horizontal lines, spaced out near the bottom of the
                        \ screen (high value of P, high y-coordinate, lower down
                        \ the screen) and bunching up towards the horizon (low
                        \ value of P, low y-coordinate, higher up the screen)

 LDA P                  \ Set Y = #Y + P
 CLC                    \
 ADC #Y                 \ where #Y is the y-coordinate of the centre of the
 TAY                    \ screen, so Y is now the horizontal pixel row of the
                        \ line we want to draw to display the hangar floor

 LDA ylookup,Y          \ Look up the page number of the character row that
 STA SC+1               \ contains the pixel with the y-coordinate in Y, and
                        \ store it in the high byte of SC(1 0) at SC+1

 STA R                  \ Also store the page number in R

 LDA P                  \ Set the low byte of SC(1 0) to the y-coordinate mod 8,
 AND #7                 \ which determines the pixel row in the character block
 STA SC                 \ we need to draw in (as each character row is 8 pixels
                        \ high), so SC(1 0) now points to the address of the
                        \ start of the horizontal line we want to draw

 LDY #0                 \ Set Y = 0 so the call to HAS2 starts drawing the line
                        \ in the first byte of the screen row, at the left edge
                        \ of the screen

 JSR HAS2               \ Draw a horizontal line from the left edge of the
                        \ screen, going right until we bump into something
                        \ already on-screen, at which point stop drawing

 LDY R                  \ Fetch the page number of the line from R, increment it
 INY                    \ so it points to the right half of the character row
 STY SC+1               \ (as each row takes up 2 pages), and store it in the
                        \ high byte of SC(1 0) at SC+1

 LDA #%01000000         \ Now to draw the same line but from the right edge of
                        \ the screen, so set a pixel mask in A to check the
                        \ second pixel of the last byte, so we skip the
                        \ two-pixel screen border at the right edge of the
                        \ screen

 LDY #248               \ Set Y = 248 so the call to HAS3 starts drawing the
                        \ line in the last byte of the screen row, at the right
                        \ edge of the screen

 JSR HAS3               \ Draw a horizontal line from the right edge of the
                        \ screen, going left until we bump into something
                        \ already on-screen, at which point stop drawing

 LDY HANGFLAG           \ Fetch the value of HANGFLAG, which gets set to 0 in
                        \ the HALL routine above if there is only one ship

 BEQ HA2                \ If HANGFLAG is zero, jump to HA2 to skip the following
                        \ as there is only one ship in the hangar

                        \ If we get here then there are multiple ships in the
                        \ hangar, so we also need to draw the horizontal line in
                        \ the gap between the ships

 LDY #0                 \ First we draw the line from the centre of the screen
                        \ to the right. SC(1 0) points to the start address of
                        \ the second half of the screen row, so we set Y to 0 so
                        \ the call to HAL3 starts drawing from the first
                        \ character in that second half

 LDA #%10001000         \ We want to start drawing from the first pixel, so we
                        \ set a mask in A to the first pixel in the four-pixel
                        \ byte

 JSR HAL3               \ Call HAL3, which draws a line from the halfway point
                        \ across the right half of the screen, going right until
                        \ we bump into something already on-screen, at which
                        \ point it stops drawing

 DEC SC+1               \ Decrement the high byte of SC(1 0) in SC+1 to point to
                        \ the previous page (i.e. the left half of this screen
                        \ row)

 LDY #248               \ We now draw the line from the centre of the screen
                        \ to the left. SC(1 0) points to the start address of
                        \ the first half of the screen row, so we set Y to 248
                        \ so the call to HAS3 starts drawing from the last
                        \ character in that first half

 LDA #%00010000         \ We want to start drawing from the last pixel, so we
                        \ set a mask in A to the last pixel in the four-pixel
                        \ byte

 JSR HAS3               \ Call HAS3, which draws a line from the halfway point
                        \ across the left half of the screen, going left until
                        \ we bump into something already on-screen, at which
                        \ point it stops drawing

.HA2

                        \ We have finished threading our horizontal line behind
                        \ the ships already on-screen, so now for the next line

 LDX T                  \ Fetch the loop counter from T and increment it
 INX

 CPX #13                \ If the loop counter is less than 13 (i.e. 2 to 12)
 BCC HAL1               \ then loop back to HAL1 to draw the next line

                        \ The floor is done, so now we move on to the back wall

 LDA #60                \ Set S = 60, so we run the following 60 times (though I
 STA S                  \ have no idea why it's 60 times, when it should be 15,
                        \ as this has the effect of drawing each vertical line
                        \ four times, each time starting one character row lower
                        \ on-screen)

 LDA #16                \ We want to draw 15 vertical lines, one every 16 pixels
                        \ across the screen, with the first at x-coordinate 16,
                        \ so set this in A to act as the x-coordinate of each
                        \ line as we work our way through them from left to
                        \ right, incrementing by 16 for each new line

 LDX #&40               \ Set X = &40, the high byte of the start of screen
 STX R                  \ memory (the screen starts at location &4000) and the
                        \ page number of the first screen row

.HAL6

 LDX R                  \ Set the high byte of SC(1 0) to R
 STX SC+1

 STA T                  \ Store A in T so we can retrieve it later

 AND #%11111100         \ A contains the x-coordinate of the line to draw, and
 STA SC                 \ each character block is 4 pixels wide, so setting the
                        \ low byte of SC(1 0) to A mod 4 points SC(1 0) to the
                        \ correct character block on the top screen row for this
                        \ x-coordinate

 LDX #%10001000         \ Set a mask in X to the first pixel in the four-pixel
                        \ byte

 LDY #1                 \ We are going to start drawing the line from the second
                        \ pixel from the top (to avoid drawing on the one-pixel
                        \ border), so set Y to 1 to point to the second row in
                        \ the first character block

.HAL7

 TXA                    \ Copy the pixel mask to A

 AND (SC),Y             \ If the pixel we want to draw is non-zero (using A as a
 BNE HA6                \ mask), then this means it already contains something,
                        \ so jump to HA6 to stop drawing this line

 TXA                    \ Copy the pixel mask to A again

 AND #RED               \ Apply the pixel mask in A to a four-pixel block of
                        \ red pixels, so we now know which bits to set in screen
                        \ memory

 ORA (SC),Y             \ OR the byte with the current contents of screen
                        \ memory, so the pixel we want is set to red (because
                        \ we know the bits are already 0 from the above test)

 STA (SC),Y             \ Store the updated pixel in screen memory

 INY                    \ Increment Y to point to the next row in the character
                        \ block, i.e. the next pixel down

 CPY #8                 \ Loop back to HAL7 to draw this next pixel until we
 BNE HAL7               \ have drawn all 8 in the character block

 INC SC+1               \ There are two pages of memory for each character row,
 INC SC+1               \ so we increment the high byte of SC(1 0) twice to
                        \ point to the same character but in the next row down

 LDY #0                 \ Set Y = 0 to point to the first row in this character
                        \ block

 BEQ HAL7               \ Loop back up to HAL7 to keep drawing the line (this
                        \ BEQ is effectively a JMP as Y is always zero)

.HA6

 LDA T                  \ Fetch the x-coordinate of the line we just drew from T
 CLC                    \ into A, and add 16 so that A contains the x-coordinate
 ADC #16                \ of the next line to draw

 BCC P%+4               \ If the addition overflowed, increment the page number
 INC R                  \ in R to point to the second half of the screen row

 DEC S                  \ Decrement the loop counter in S

 BNE HAL6               \ Loop back to HAL6 until we have run through the loop
                        \ 60 times, by which point we are most definitely done

IF _SNG47

 LDA #%00001001         \ Clear bits 1 and 2 of the Access Control Register at
 STA VIA+&34            \ SHEILA &34 to switch main memory back into &3000-&7FFF

 RTS                    \ Return from the subroutine (this instruction is not
                        \ needed as we could just fall through into the RTS at
                        \ HA3 below)

ELIF _COMPACT

 JMP away               \ Jump to away to switch main memory back into
                        \ &3000-&7FFF and return from the subroutine

ENDIF

.HA3

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: HAS2
\       Type: Subroutine
\   Category: Ship hangar
\    Summary: Draw a hangar background line from left to right
\
\ ------------------------------------------------------------------------------
\
\ This routine draws a line to the right, starting with the third pixel of the
\ pixel row at screen address SC(1 0), and aborting if we bump into something
\ that's already on-screen.
\
\ HAL2 draws from the left edge of the screen to the halfway point, and then
\ HAL3 takes over to draw from the halfway point across the right half of the
\ screen.
\
\ ******************************************************************************

.HAS2

 LDA #%00100010         \ Set A to the pixel pattern for a mode 1 character row
                        \ byte with the third pixel set, so we start drawing the
                        \ horizontal line just to the right of the two-pixel
                        \ border along the edge of the screen

.HAL2

 TAX                    \ Store A in X so we can retrieve it after the following
                        \ check and again after updating screen memory

 AND (SC),Y             \ If the pixel we want to draw is non-zero (using A as a
 BNE HA3                \ mask), then this means it already contains something,
                        \ so we stop drawing because we have run into something
                        \ that's already on-screen, and return from the
                        \ subroutine (as HA3 contains an RTS)

 TXA                    \ Retrieve the value of A we stored above, so A now
                        \ contains the pixel mask again

 AND #RED               \ Apply the pixel mask in A to a four-pixel block of
                        \ red pixels, so we now know which bits to set in screen
                        \ memory

 ORA (SC),Y             \ OR the byte with the current contents of screen
                        \ memory, so the pixel we want is set to red (because
                        \ we know the bits are already 0 from the above test)

 STA (SC),Y             \ Store the updated pixel in screen memory

 TXA                    \ Retrieve the value of A we stored above, so A now
                        \ contains the pixel mask again

 LSR A                  \ Shift A to the right to move on to the next pixel

 BCC HAL2               \ If bit 0 before the shift was clear (i.e. we didn't
                        \ just do the fourth pixel in this block), loop back to
                        \ HAL2 to check and draw the next pixel

 TYA                    \ Set Y = Y + 8 (as we know the C flag is set) to point
 ADC #7                 \ to the next character block along
 TAY

 LDA #%10001000         \ Reset the pixel mask in A to the first pixel in the
                        \ new four-pixel character block

 BCC HAL2               \ If the above addition didn't overflow, jump back to
                        \ HAL2 to keep drawing the line in the next character
                        \ block

 INC SC+1               \ The addition overflowed, so we have reached the last
                        \ character block in this page of memory, so increment
                        \ the high byte of SC(1 0) in SC+1 to point to the next
                        \ page (i.e. the right half of this screen row) and fall
                        \ into HAL3 to repeat the performance

\ ******************************************************************************
\
\       Name: HAL3
\       Type: Subroutine
\   Category: Ship hangar
\    Summary: Draw a hangar background line from left to right, stopping when it
\             bumps into existing on-screen content
\
\ ******************************************************************************

.HAL3

 TAX                    \ Store A in X so we can retrieve it after the following
                        \ check and again after updating screen memory

 AND (SC),Y             \ If the pixel we want to draw is non-zero (using A as a
 BNE HA3                \ mask), then this means it already contains something,
                        \ so we stop drawing because we have run into something
                        \ that's already on-screen, and return from the
                        \ subroutine (as HA3 contains an RTS)

 TXA                    \ Retrieve the value of A we stored above, so A now
                        \ contains the pixel mask again

 AND #RED               \ Apply the pixel mask in A to a four-pixel block of
                        \ red pixels, so we now know which bits to set in screen
                        \ memory

 ORA (SC),Y             \ OR the byte with the current contents of screen
                        \ memory, so the pixel we want is set to red (because
                        \ we know the bits are already 0 from the above test)

 STA (SC),Y             \ Store the updated pixel in screen memory

 TXA                    \ Retrieve the value of A we stored above, so A now
                        \ contains the pixel mask again

 LSR A                  \ Shift A to the right to move on to the next pixel

 BCC HAL3               \ If bit 0 before the shift was clear (i.e. we didn't
                        \ just do the fourth pixel in this block), loop back to
                        \ HAL3 to check and draw the next pixel

 TYA                    \ Set Y = Y + 8 (as we know the C flag is set) to point
 ADC #7                 \ to the next character block along
 TAY

 LDA #%10001000         \ Reset the pixel mask in A to the first pixel in the
                        \ new four-pixel character block

 BCC HAL3               \ If the above addition didn't overflow, jump back to
                        \ HAL3 to keep drawing the line in the next character
                        \ block

 RTS                    \ The addition overflowed, so we have reached the last
                        \ character block in this page of memory, which is the
                        \ end of the line, so we return from the subroutine

\ ******************************************************************************
\
\       Name: HAS3
\       Type: Subroutine
\   Category: Ship hangar
\    Summary: Draw a hangar background line from right to left
\
\ ------------------------------------------------------------------------------
\
\ This routine draws a line to the left, starting with the pixel mask in A at
\ screen address SC(1 0) and character block offset Y, and aborting if we bump
\ into something that's already on-screen.
\
\ ******************************************************************************

.HAS3

 TAX                    \ Store A in X so we can retrieve it after the following
                        \ check and again after updating screen memory

 AND (SC),Y             \ If the pixel we want to draw is non-zero (using A as a
 BNE HA3                \ mask), then this means it already contains something,
                        \ so we stop drawing because we have run into something
                        \ that's already on-screen, and return from the
                        \ subroutine (as HA3 contains an RTS)

 TXA                    \ Retrieve the value of A we stored above, so A now
                        \ contains the pixel mask again

 ORA (SC),Y             \ OR the byte with the current contents of screen
                        \ memory, so the pixel we want is set to red (because
                        \ we know the bits are already 0 from the above test)

 STA (SC),Y             \ Store the updated pixel in screen memory

 TXA                    \ Retrieve the value of A we stored above, so A now
                        \ contains the pixel mask again

 ASL A                  \ Shift A to the left to move to the next pixel to the
                        \ left

 BCC HAS3               \ If bit 7 before the shift was clear (i.e. we didn't
                        \ just do the first pixel in this block), loop back to
                        \ HAS3 to check and draw the next pixel to the left

 TYA                    \ Set Y = Y - 8 (as we know the C flag is set) to point
 SBC #8                 \ to the next character block to the left
 TAY

 LDA #%00010000         \ Set a mask in A to the last pixel in the four-pixel
                        \ byte

 BCS HAS3               \ If the above subtraction didn't underflow, jump back
                        \ to HAS3 to keep drawing the line in the next character
                        \ block to the left

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: DVID4K
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (P R) = 256 * A / Q
\  Deep dive: Shift-and-subtract division
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following division and remainder:
\
\   P = A / Q
\
\   R = remainder as a fraction of Q, where 1.0 = 255
\
\ Another way of saying the above is this:
\
\   (P R) = 256 * A / Q
\
\ This uses the same shift-and-subtract algorithm as TIS2, but this time we
\ keep the remainder.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              The C flag is cleared
\
\ ******************************************************************************

.DVID4K

                        \ This is an exact duplicate of the DVID4 routine, which
                        \ is also present in this source, so it isn't clear why
                        \ this duplicate exists (especially as the other version
                        \ is slightly faster, as it unrolls the loop)

 LDX #8                 \ Set a counter in X to count the 8 bits in A

 ASL A                  \ Shift A left and store in P (we will build the result
 STA P                  \ in P)

 LDA #0                 \ Set A = 0 for us to build a remainder

.DVL4K

 ROL A                  \ Shift A to the left

 BCS DV8K               \ If the C flag is set (i.e. bit 7 of A was set) then
                        \ skip straight to the subtraction

 CMP Q                  \ If A < Q skip the following subtraction
 BCC DV5K

.DV8K

 SBC Q                  \ A >= Q, so set A = A - Q

.DV5K

 ROL P                  \ Shift P to the left, pulling the C flag into bit 0

 DEX                    \ Decrement the loop counter

 BNE DVL4K              \ Loop back for the next bit until we have done all 8
                        \ bits of P

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TTX66
\       Type: Subroutine
\   Category: Drawing the screen
\    Summary: Clear the top part of the screen and draw a border box
\
\ ------------------------------------------------------------------------------
\
\ Clear the top part of the screen (the space view) and draw a border box
\ along the top and sides.
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   BOX                 Just draw the border box along the top and sides
\
\ ******************************************************************************

.TTX66

 JSR G_DIRECT           \ Port: the renderer stops recording until the first
                        \ frame after the screen is cleared (gfx-frame.asm)

 LDX #%00001111         \ Set bits 1 and 2 of the Access Control Register at
 STX VIA+&34            \ SHEILA &34 to switch screen memory into &3000-&7FFF

 LDX #&40               \ Set X to point to page &40, which is the start of the
                        \ screen memory at &4000

.BOL1

 JSR ZES1               \ Call ZES1 to zero-fill the page in X, which will clear
                        \ half a character row

 INX                    \ Increment X to point to the next page in screen
                        \ memory

 CPX #&70               \ Loop back to keep clearing character rows until we
 BNE BOL1               \ have cleared up to &7000, which is where the dashboard
                        \ starts

.BOX

 LDX #%00001111         \ Set bits 1 and 2 of the Access Control Register at
 STX VIA+&34            \ SHEILA &34 to switch screen memory into &3000-&7FFF

 LDA COL                \ Store the current colour on the stack, so we can
 PHA                    \ restore it once we have drawn the border

 LDA #%00001111         \ Set COL = %00001111 to act as a four-pixel yellow
 STA COL                \ character byte (i.e. set the line colour to yellow)

 LDY #1                 \ Move the text cursor to row 1
 STY YC

 STY XC                 \ Move the text cursor to column 1

IF _SNG47

 LDX #0                 \ Set X1 = Y1 = Y2 = 0
 STX Y1
 STX Y2
 STX X1

 DEX                    \ Set X2 = 255
 STX X2

ELIF _COMPACT

 STZ Y1                 \ Set X1 = Y1 = Y2 = 0
 STZ Y2
 STZ X1

 LDX #255               \ Set X2 = 255
 STX X2

ENDIF

 JSR LOINQ              \ Draw a line from (X1, Y1) to (X2, Y2), so that's from
                        \ (0, 0) to (255, 0), along the very top of the screen

 LDA #2                 \ Set X1 = X2 = 2
 STA X1
 STA X2

 JSR BOS2               \ Call BOS2 below, which will call BOS1 twice, and then
 JSR BOS2               \ call BOS2 again, so we effectively do BOS1 four times,
                        \ decrementing X1 and X2 each time before calling LOIN,
                        \ so this whole loop-within-a-loop mind-bender ends up
                        \ drawing these four lines:
                        \
                        \   (1, 0)   to (1, 191)
                        \   (0, 0)   to (0, 191)
                        \   (255, 0) to (255, 191)
                        \   (254, 0) to (254, 191)
                        \
                        \ So that's a two-pixel wide vertical border along the
                        \ left edge of the upper part of the screen, and a
                        \ two-pixel wide vertical border along the right edge

 LDA COL                \ Set locations &4000 and &41F8 to the correct colour,
 STA &4000              \ as otherwise the top-left and top-right corners will
 STA &41F8              \ be black (as the lines overlap at the corners, and
                        \ the EOR logic used by LOINQ will otherwise make them
                        \ black)

 PLA                    \ Restore the original colour that we stored above
 STA COL

 LDA #%00001001         \ Clear bits 1 and 2 of the Access Control Register at
 STA VIA+&34            \ SHEILA &34 to switch main memory back into &3000-&7FFF

 RTS                    \ Return from the subroutine

.BOS2

 JSR BOS1               \ Call BOS1 below and then fall through into it, which
                        \ ends up running BOS1 twice. This is all part of the
                        \ loop-the-loop border-drawing mind-bender explained
                        \ above

.BOS1

 STZ Y1                 \ Set Y1 = 0

 LDA #2*Y-1             \ Set Y2 = 2 * #Y - 1. The constant #Y is 96, the
 STA Y2                 \ y-coordinate of the mid-point of the space view, so
                        \ this sets Y2 to 191, the y-coordinate of the bottom
                        \ pixel row of the space view

 DEC X1                 \ Decrement X1 and X2
 DEC X2

 JMP LOINQ              \ Draw a line from (X1, Y1) to (X2, Y2) and return from
                        \ the subroutine using a tail call

\ ******************************************************************************
\
\       Name: CLYNS
\       Type: Subroutine
\   Category: Drawing the screen
\    Summary: Clear the bottom three text rows of the space view
\
\ ******************************************************************************

.CLYNS

 STZ DLY                \ Set the delay in DLY to 0, to indicate that we are
                        \ no longer showing an in-flight message, so any new
                        \ in-flight messages will be shown instantly

 STZ de                 \ Clear de, the flag that appends " DESTROYED" to the
                        \ end of the next text token, so that it doesn't

 LDA #%11111111         \ Set DTW2 = %11111111 to denote that we are not
 STA DTW2               \ currently printing a word

 LDA #%10000000         \ Set bit 7 of QQ17 to switch standard tokens to
 STA QQ17               \ Sentence Case

 LDA #20                \ Move the text cursor to row 20, near the bottom of
 STA YC                 \ the screen

 JSR TT67K              \ Print a newline

 JSR H_CLYNS            \ Port: clear the renderer's text map rows 21-23, and in
                        \ record mode return instead of clearing the screen
                        \ (gfx-hooks.asm)

 LDA #%00001111         \ Set bits 1 and 2 of the Access Control Register at
 STA VIA+&34            \ SHEILA &34 to switch screen memory into &3000-&7FFF

 LDA #&6A               \ Set SC+1 = &6A, for the high byte of SC(1 0)
 STA SC+1

 LDA #0                 \ Set SC = 0, so now SC(1 0) = &6A00
 STA SC

 LDX #3                 \ We want to clear three text rows, so set a counter in
                        \ X for 3 rows

.CLYL

 LDY #8                 \ We want to clear each text row, starting from the
                        \ left, but we don't want to overwrite the border, so we
                        \ start from the second character block, which is byte
                        \ #8 from the edge, so set Y to 8 to act as the byte
                        \ counter within the row

.EE2

 STA (SC),Y             \ Zero the Y-th byte from SC(1 0), which clears it by
                        \ setting it to colour 0, black

 INY                    \ Increment the byte counter in Y

 BNE EE2                \ Loop back to EE2 to blank the next byte along, until
                        \ we have done one page's worth (from byte #8 to #255)

 INC SC+1               \ We have just finished the first page - which covers
                        \ the left half of the text row - so we increment SC+1
                        \ so SC(1 0) points to the start of the next page, or
                        \ the start of the right half of the row

 STA (SC),Y             \ Clear the byte at SC(1 0), as that won't be caught by
                        \ the next loop

 LDY #247               \ The second page covers the right half of the text row,
                        \ and as before we don't want to overwrite the border,
                        \ which we can do by starting from the last-but-one
                        \ character block and working our way left towards the
                        \ centre of the row. The last-but-one character block
                        \ ends at byte 247 (that's 255 - 8, as each character
                        \ is 8 bytes), so we put this in Y to act as a byte
                        \ counter, as before

.EE3K                   \ This label is a duplicate of a label in the TT23
                        \ routine
                        \
                        \ In the original source this label is EE3, but
                        \ because BeebAsm doesn't allow us to redefine labels,
                        \ I have renamed it to EE3K

 STA (SC),Y             \ Zero the Y-th byte from SC(1 0), which clears it by
                        \ setting it to colour 0, black

 DEY                    \ Decrement the byte counter in Y

 BNE EE3K               \ Loop back to EE3K to blank the next byte to the left,
                        \ until we have done one page's worth (from byte #247 to
                        \ #1)

 INC SC+1               \ We have now blanked a whole text row, so increment
                        \ SC+1 so that SC(1 0) points to the next row

 DEX                    \ Decrement the row counter in X

 BNE CLYL               \ Loop back to blank another row, until we have done the
                        \ number of rows in X

 LDA #%00001001         \ Clear bits 1 and 2 of the Access Control Register at
 STA VIA+&34            \ SHEILA &34 to switch main memory back into &3000-&7FFF

 LDA #0                 \ Set A = 0 as this is a return value for this routine

 RTS                    \ Return from the subroutine

INCLUDE "src/elite-dash.asm"    \ Port: the MODE 1 CMYK dashboard

\ ******************************************************************************
\
\       Name: shpcol
\       Type: Variable
\   Category: Drawing ships
\    Summary: Ship colours
\
\ ******************************************************************************

.shpcol

 EQUB 0

 EQUB YELLOW            \ Missile
 EQUB CYAN              \ Coriolis space station
 EQUB CYAN              \ Escape pod
 EQUB CYAN              \ Alloy plate
 EQUB CYAN              \ Cargo canister
 EQUB RED               \ Boulder
 EQUB RED               \ Asteroid
 EQUB RED               \ Splinter
 EQUB CYAN              \ Shuttle
 EQUB CYAN              \ Transporter
 EQUB CYAN              \ Cobra Mk III
 EQUB CYAN              \ Python
 EQUB CYAN              \ Boa
 EQUB CYAN              \ Anaconda
 EQUB RED               \ Rock hermit (asteroid)
 EQUB CYAN              \ Viper
 EQUB CYAN              \ Sidewinder
 EQUB CYAN              \ Mamba
 EQUB CYAN              \ Krait
 EQUB CYAN              \ Adder
 EQUB CYAN              \ Gecko
 EQUB CYAN              \ Cobra Mk I
 EQUB CYAN              \ Worm
 EQUB CYAN              \ Cobra Mk III (pirate)
 EQUB CYAN              \ Asp Mk II
 EQUB CYAN              \ Python (pirate)
 EQUB CYAN              \ Fer-de-lance
 EQUB %11001001         \ Moray (colour 3, 2, 0, 1 = cyan/red/black/yellow)
 EQUB WHITE             \ Thargoid
 EQUB WHITE             \ Thargon
 EQUB CYAN              \ Constrictor
 EQUB CYAN              \ Cougar

 EQUB CYAN              \ This byte appears to be unused

\ ******************************************************************************
\
\       Name: scacol
\       Type: Variable
\   Category: Drawing ships
\    Summary: Ship colours on the scanner
\  Deep dive: The elusive Cougar
\
\ ******************************************************************************

.scacol

 EQUB 0                 \ This byte appears to be unused

 EQUB YELLOW2           \ Missile
 EQUB GREEN2            \ Coriolis space station
 EQUB BLUE2             \ Escape pod
 EQUB BLUE2             \ Alloy plate
 EQUB BLUE2             \ Cargo canister
 EQUB RED2              \ Boulder
 EQUB RED2              \ Asteroid
 EQUB RED2              \ Splinter
 EQUB CYAN2             \ Shuttle
 EQUB CYAN2             \ Transporter
 EQUB CYAN2             \ Cobra Mk III
 EQUB MAG2              \ Python
 EQUB MAG2              \ Boa
 EQUB MAG2              \ Anaconda
 EQUB RED2              \ Rock hermit (asteroid)
 EQUB CYAN2             \ Viper
 EQUB CYAN2             \ Sidewinder
 EQUB CYAN2             \ Mamba
 EQUB CYAN2             \ Krait
 EQUB CYAN2             \ Adder
 EQUB CYAN2             \ Gecko
 EQUB CYAN2             \ Cobra Mk I
 EQUB BLUE2             \ Worm
 EQUB CYAN2             \ Cobra Mk III (pirate)
 EQUB CYAN2             \ Asp Mk II
 EQUB MAG2              \ Python (pirate)
 EQUB CYAN2             \ Fer-de-lance
 EQUB CYAN2             \ Moray
 EQUB WHITE2            \ Thargoid
 EQUB CYAN2             \ Thargon
 EQUB CYAN2             \ Constrictor
 EQUB 0                 \ Cougar

 EQUB CYAN2             \ These bytes appear to be unused
 EQUD 0

\ ******************************************************************************
\
\ Save ELTA.bin
\

\ ******************************************************************************
\
\       Name: TACTICS (Part 1 of 7)
\       Type: Subroutine
\   Category: Tactics
\    Summary: Apply tactics: Process missiles, both enemy missiles and our own
\  Deep dive: Program flow of the tactics routine
\
\ ------------------------------------------------------------------------------
\
\ This section implements missile tactics and is entered at TA18 from the main
\ entry point below, if the current ship is a missile. Specifically:
\
\   * If E.C.M. is active, destroy the missile
\
\   * If the missile is hostile towards us, then check how close it is. If it
\     hasn't reached us, jump to part 3 so it can streak towards us, otherwise
\     we've been hit, so process a large amount of damage to our ship
\
\   * Otherwise see how close the missile is to its target. If it has not yet
\     reached its target, give the target a chance to activate its E.C.M. if it
\     has one, otherwise jump to TA19 with K3 set to the vector from the target
\     to the missile
\
\   * If it has reached its target and the target is the space station, destroy
\     the missile, potentially damaging us if we are nearby
\
\   * If it has reached its target and the target is a ship, destroy the missile
\     and the ship, potentially damaging us if we are nearby
\
\ ******************************************************************************

.TA352

                        \ If we get here, the missile has been destroyed by
                        \ E.C.M. or by the space station

 LDA INWK               \ Set A = x_lo OR y_lo OR z_lo of the missile
 ORA INWK+3
 ORA INWK+6

 BNE TA872              \ If A is non-zero then the missile is not near our
                        \ ship, so skip the next two instructions to avoid
                        \ damaging our ship

 LDA #80                \ Otherwise the missile just got destroyed near us, so
 JSR OOPS               \ call OOPS to damage the ship by 80, which is nowhere
                        \ near as bad as the 250 damage from a missile slamming
                        \ straight into us, but it's still pretty nasty

.TA872

 LDX #PLT               \ Set X to the ship type for plate alloys, so we get
                        \ awarded the kill points for the missile scraps in TA87

 BNE TA353              \ Jump to TA353 to process the missile kill tally and
                        \ make an explosion sound

.TA34

                        \ If we get here, the missile is hostile

 LDA #0                 \ Set A to x_hi OR y_hi OR z_hi
 JSR MAS4

 BEQ P%+5               \ If A = 0 then the missile is very close to our ship,
                        \ so skip the following instruction

 JMP TN4                \ Jump down to part 3 to set up the vectors and skip
                        \ straight to aggressive manoeuvring

 JSR TA873              \ The missile has hit our ship, so call TA873 to set
                        \ bit 7 of the missile's byte #31, which marks the
                        \ missile as being killed

 JSR EXNO3              \ Make the sound of the missile exploding

 LDA #250               \ Call OOPS to damage the ship by 250, which is a pretty
 JMP OOPS               \ big hit, and return from the subroutine using a tail
                        \ call

.TA18

                        \ This is the entry point for missile tactics and is
                        \ called from the main TACTICS routine below

 LDA ECMA               \ If an E.C.M. is currently active (either ours or an
 BNE TA352              \ opponent's), jump to TA352 to destroy this missile

 LDA INWK+32            \ Fetch the AI flag from byte #32 and if bit 6 is set
 ASL A                  \ (i.e. missile is hostile), jump up to TA34 to check
 BMI TA34               \ whether the missile has hit us

 LSR A                  \ Otherwise shift A right again. We know bits 6 and 7
                        \ are now clear, so this leaves bits 0-5. Bits 1-5
                        \ contain the target's slot number, and bit 0 is cleared
                        \ in FRMIS when a missile is launched, so A contains
                        \ the slot number shifted left by 1 (i.e. doubled) so we
                        \ can use it as an index for the two-byte address table
                        \ at UNIV

 TAX                    \ Copy the address of the target ship's data block from
 LDA UNIV,X             \ UNIV(X+1 X) to (A V)
 STA V
 LDA UNIV+1,X

 JSR VCSUB              \ Calculate vector K3 as follows:
                        \
                        \ K3(2 1 0) = (x_sign x_hi x_lo) - x-coordinate of
                        \ target ship
                        \
                        \ K3(5 4 3) = (y_sign y_hi z_lo) - y-coordinate of
                        \ target ship
                        \
                        \ K3(8 7 6) = (z_sign z_hi z_lo) - z-coordinate of
                        \ target ship

                        \ So K3 now contains the vector from the target ship to
                        \ the missile

 LDA K3+2               \ Set A = OR of all the sign and high bytes of the
 ORA K3+5               \ above, clearing bit 7 (i.e. ignore the signs)
 ORA K3+8
 AND #%01111111
 ORA K3+1
 ORA K3+4
 ORA K3+7

 BNE TA64               \ If the result is non-zero, then the missile is some
                        \ distance from the target, so jump down to TA64 see if
                        \ the target activates its E.C.M.

 LDA INWK+32            \ Fetch the AI flag from byte #32 and if only bits 7 and
 CMP #%10000010         \ 1 are set (AI is enabled and the target is slot 1, the
 BEQ TA352              \ space station), jump to TA352 to destroy this missile,
                        \ as the space station ain't kidding around

 LDY #31                \ Fetch byte #31 (the exploding flag) of the target ship
 LDA (V),Y              \ into A

 BIT M32+1              \ M32 contains an LDY #32 instruction, so M32+1 contains
                        \ 32, so this instruction tests A with %00100000, which
                        \ checks bit 5 of A (the "already exploding?" bit)

 BNE TA35               \ If the target ship is already exploding, jump to TA35
                        \ to destroy this missile

 ORA #%10000000         \ Otherwise set bit 7 of the target's byte #31 to mark
 STA (V),Y              \ the ship as having been killed, so it explodes

.TA35

 LDA INWK               \ Set A = x_lo OR y_lo OR z_lo of the missile
 ORA INWK+3
 ORA INWK+6

 BNE P%+7               \ If A is non-zero then the missile is not near our
                        \ ship, so skip the next two instructions to avoid
                        \ damaging our ship

 LDA #80                \ Otherwise the missile just got destroyed near us, so
 JSR OOPS               \ call OOPS to damage the ship by 80, which is nowhere
                        \ near as bad as the 250 damage from a missile slamming
                        \ straight into us, but it's still pretty nasty

.TA87

 LDA INWK+32            \ Set X to bits 1-6 of the missile's AI flag in ship
 AND #%01111111         \ byte #32, so that bits 0-4 of X are the target's slot
 LSR A                  \ number, and bit 5 is clear (as the missile is ours)
 TAX                    \
                        \ So X contains the slot number of the target ship
                        \
                        \ We should now fetch the ship type from slot X, so we
                        \ can pass the ship type to EXNO2 to add the correct
                        \ number of kill points to award for this type of ship,
                        \ but instead we're passing the slot number to EXNO2
                        \
                        \ This is a bug that means we will be allocated a fairly
                        \ random number of kill points when destroying a ship
                        \ with a missile; this bug was fixed in the NES version,
                        \ but it affects the Commodore 64, Apple II and BBC
                        \ Master versions of Elite

.TA353

 JSR EXNO2              \ Call EXNO2 to process the fact that we have killed a
                        \ missile (so increase the kill tally, make an explosion
                        \ sound and so on)

.TA873

 ASL INWK+31            \ Set bit 7 of the missile's byte #31 flag to mark it as
 SEC                    \ having been killed, so it explodes
 ROR INWK+31

.TA1

 RTS                    \ Return from the subroutine

.TA64

                        \ If we get here then the missile has not reached the
                        \ target

 JSR DORND              \ Set A and X to random numbers

 CMP #16                \ If A >= 16 (94% chance), jump down to TA19S with the
 BCS TA19S              \ vector from the target to the missile in K3

.M32

 LDY #32                \ Fetch byte #32 for the target and shift bit 0 (E.C.M.)
 LDA (V),Y              \ into the C flag
 LSR A

 BCS P%+5               \ If the C flag is set then the target has E.C.M.
                        \ fitted, so skip the next instruction

.TA19S

 JMP TA19               \ The target does not have E.C.M. fitted, so jump down
                        \ to TA19 with the vector from the target to the missile
                        \ in K3

 JMP ECBLB2             \ The target has E.C.M., so jump to ECBLB2 to set it
                        \ off, returning from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: TACTICS (Part 2 of 7)
\       Type: Subroutine
\   Category: Tactics
\    Summary: Apply tactics: Escape pod, station, lone Thargon, safe-zone pirate
\  Deep dive: Program flow of the tactics routine
\             Aggression and hostility in ship tactics
\
\ ------------------------------------------------------------------------------
\
\ This section contains the main entry point at TACTICS, which is called from
\ part 2 of MVEIT for ships that have the AI flag set (i.e. bit 7 of byte #32).
\ This part does the following:
\
\   * If this is a missile, jump up to the missile code in part 1
\
\   * If this is the space station and it is hostile, consider spawning a cop
\     (6.2% chance, up to a maximum of seven) and we're done
\
\   * If this is the space station and it is not hostile, consider spawning
\     (0.8% chance if there are no Transporters around) a Transporter or Shuttle
\     (equal odds of each type) and we're done
\
\   * If this is a rock hermit, consider spawning (22% chance) a highly
\     aggressive and hostile Sidewinder, Mamba, Krait, Adder or Gecko (equal
\     odds of each type) and we're done
\
\   * Recharge the ship's energy banks by 1
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The ship type
\
\ ******************************************************************************

.TACTICS

 LDA #3                 \ Set RAT = 3, which is the magnitude we set the pitch
 STA RAT                \ or roll counter to in part 7 when turning a ship
                        \ towards a vector (a higher value giving a longer
                        \ turn). This value is not changed in the TACTICS
                        \ routine, but it is set to different values by the
                        \ DOCKIT routine

 LDA #4                 \ Set RAT2 = 4, which is the threshold below which we
 STA RAT2               \ don't apply pitch and roll to the ship (so a lower
                        \ value means we apply pitch and roll more often, and a
                        \ value of 0 means we always apply them). The value is
                        \ compared with double the high byte of sidev . XX15,
                        \ where XX15 is the vector from the ship to the enemy
                        \ or planet. This value is set to different values by
                        \ both the TACTICS and DOCKIT routines

 LDA #22                \ Set CNT2 = 22, which is the maximum angle beyond which
 STA CNT2               \ a ship will slow down to start turning towards its
                        \ prey (a lower value means a ship will start to slow
                        \ down even if its angle with the enemy ship is large,
                        \ which gives a tighter turn). This value is not changed
                        \ in the TACTICS routine, but it is set to different
                        \ values by the DOCKIT routine

 CPX #MSL               \ If this is a missile, jump up to TA18 to implement
 BEQ TA18               \ missile tactics

 CPX #SST               \ If this is not the space station, jump down to TA13
 BNE TA13

 LDA NEWB               \ This is the space station, so check whether bit 2 of
 AND #%00000100         \ the ship's NEWB flags is set, and if it is (i.e. the
 BNE TN5                \ station is hostile), jump to TN5 to spawn some cops

 LDA MANY+SHU+1         \ The station is not hostile, so check how many
 BNE TA1                \ Transporters there are in the vicinity, and if we
                        \ already have one, return from the subroutine (as TA1
                        \ contains an RTS)

                        \ If we get here then the station is not hostile, so we
                        \ can consider spawning a Transporter or Shuttle

 JSR DORND              \ Set A and X to random numbers

 CMP #253               \ If A < 253 (99.2% chance), return from the subroutine
 BCC TA1                \ (as TA1 contains an RTS)

 AND #1                 \ Set A = a random number that's either 0 or 1

 ADC #SHU-1             \ The C flag is set (as we didn't take the BCC above),
 TAX                    \ so this sets X to a value of either #SHU or #SHU + 1,
                        \ which is the ship type for a Shuttle or a Transporter

 BNE TN6                \ Jump to TN6 to spawn this ship type and return from
                        \ the subroutine using a tail call (this BNE is
                        \ effectively a JMP as A is never zero)

.TN5

                        \ If we get here then this is the space station and it
                        \ is hostile, so we need to spawn some cops

 JSR DORND              \ Set A and X to random numbers

 CMP #240               \ If A < 240 (93.8% chance), return from the subroutine
 BCC TA1                \ (as TA1 contains an RTS)

 LDA MANY+COPS          \ Check how many cops there are in the vicinity already,
 CMP #6                 \ and if there are 6 or more, return from the subroutine
 BCS TA22               \ (as TA22 contains an RTS)

 LDX #COPS              \ Set X to the ship type for a cop

.TN6

 LDA #%11110001         \ Set the AI flag to give the ship E.C.M., enable AI and
                        \ make it very aggressive (56 out of 63)

 JMP SFS1               \ Jump to SFS1 to spawn the ship, returning from the
                        \ subroutine using a tail call

.TA13

 CPX #HER               \ If this is not a rock hermit, jump down to TA17
 BNE TA17

 JSR DORND              \ Set A and X to random numbers

 CMP #200               \ If A < 200 (78% chance), return from the subroutine
 BCC TA22               \ (as TA22 contains an RTS)

 LDX #0                 \ Set byte #32 to %00000000 to disable AI, zero the
 STX INWK+32            \ aggression level and remove E.C.M.

 LDX #%00100100         \ Set the ship's NEWB flags to %00100100 so the ship we
 STX NEWB               \ spawn below will inherit the default values from E% as
                        \ well as having bit 2 (hostile) and bit 5 (innocent
                        \ bystander) set

 AND #3                 \ Set A = a random number that's in the range 0-3

 ADC #SH3               \ The C flag is set (as we didn't take the BCC above),
 TAX                    \ so this sets X to a random value between #SH3 + 1 and
                        \ #SH3 + 4, so that's a Sidewinder, Mamba, Krait, Adder
                        \ or Gecko

 JSR TN6                \ Call TN6 to spawn this ship with E.C.M., AI and a high
                        \ aggression (56 out of 63), though we override this in
                        \ the next instructions

 LDA #0                 \ Set byte #32 to %00000000 to disable AI, zero the
 STA INWK+32            \ aggression level and remove E.C.M. (for the rock
                        \ hermit)

 RTS                    \ Return from the subroutine

.TA17

 LDY #14                \ If the ship's energy is greater or equal to the
 LDA INWK+35            \ maximum value from the ship's blueprint pointed to by
 CMP (XX0),Y            \ XX0, then skip the next instruction
 BCS TA21

 INC INWK+35            \ The ship's energy is not at maximum, so recharge the
                        \ energy banks by 1

\ ******************************************************************************
\
\       Name: TACTICS (Part 3 of 7)
\       Type: Subroutine
\   Category: Tactics
\    Summary: Apply tactics: Calculate dot product to determine ship's aim
\  Deep dive: Program flow of the tactics routine
\             Aggression and hostility in ship tactics
\
\ ------------------------------------------------------------------------------
\
\ This section sets up some vectors and calculates dot products. Specifically:
\
\   * If this is a lone Thargon without a mothership, set it adrift aimlessly
\     and we're done
\
\   * If this is a trader, 80% of the time we're done, 20% of the time the
\     trader performs the same checks as the bounty hunter
\
\   * If this is a bounty hunter (or one of the 20% of traders) and we have been
\     really bad (i.e. a fugitive or serious offender), the ship becomes hostile
\     (if it isn't already)
\
\   * If the ship is not hostile, then either perform docking manoeuvres (if
\     it's docking) or fly towards the planet (if it isn't docking) and we're
\     done
\
\   * If the ship is hostile, and a pirate, and we are within the space station
\     safe zone, stop the pirate from attacking by removing all its aggression
\
\   * Calculate the dot product of the ship's nose vector (i.e. the direction it
\     is pointing) with the vector between us and the ship. This value will help
\     us work out later on whether the enemy ship is pointing towards us, and
\     therefore whether it can hit us with its lasers.
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   GOPL                Make the ship head towards the planet
\
\ ******************************************************************************

.TA21

 CPX #TGL               \ If this is not a Thargon, jump down to TA14
 BNE TA14

 LDA MANY+THG           \ If there is at least one Thargoid in the vicinity,
 BNE TA14               \ jump down to TA14

 LSR INWK+32            \ This is a Thargon but there is no Thargoid mothership,
 ASL INWK+32            \ so clear bit 0 of the AI flag to disable its E.C.M.

 LSR INWK+27            \ And halve the Thargon's speed

.TA22

 RTS                    \ Return from the subroutine

.TA14

 JSR DORND              \ Set A and X to random numbers

 LDA NEWB               \ Extract bit 0 of the ship's NEWB flags into the C flag
 LSR A                  \ and jump to TN1 if it is clear (i.e. if this is not a
 BCC TN1                \ trader)

 CPX #50                \ This is a trader, so if X >= 50 (80% chance), return
 BCS TA22               \ from the subroutine (as TA22 contains an RTS)

.TN1

 LSR A                  \ Extract bit 1 of the ship's NEWB flags into the C flag
 BCC TN2                \ and jump to TN2 if it is clear (i.e. if this is not a
                        \ bounty hunter)

 LDX FIST               \ This is a bounty hunter, so check whether our FIST
 CPX #40                \ rating is < 40 (where 50 is a fugitive), and jump to
 BCC TN2                \ TN2 if we are not 100% evil

 LDA NEWB               \ We are a fugitive or a bad offender, and this ship is
 ORA #%00000100         \ a bounty hunter, so set bit 2 of the ship's NEWB flags
 STA NEWB               \ to make it hostile

 LSR A                  \ Shift A right twice so the next test in TN2 will check
 LSR A                  \ bit 2

.TN2

 LSR A                  \ Extract bit 2 of the ship's NEWB flags into the C flag
 BCS TN3                \ and jump to TN3 if it is set (i.e. if this ship is
                        \ hostile)

 LSR A                  \ The ship is not hostile, so extract bit 4 of the
 LSR A                  \ ship's NEWB flags into the C flag, and jump to GOPL if
 BCC GOPL               \ it is clear (i.e. if this ship is not docking)

 JMP DOCKIT             \ The ship is not hostile and is docking, so jump to
                        \ DOCKIT to apply the docking algorithm to this ship

.GOPL

 JSR SPS1               \ The ship is not hostile and it is not docking, so call
                        \ SPS1 to calculate the vector to the planet and store
                        \ it in XX15

 JMP TA151              \ Jump to TA151 to make the ship head towards the planet

.TN3

 LSR A                  \ Extract bit 3 of the ship's NEWB flags into the C flag
 BCC TN4                \ and jump to TN4 if it is clear (i.e. if this ship is
                        \ not a pirate)

 LDA SSPR               \ If we are not inside the space station safe zone, jump
 BEQ TN4                \ to TN4

                        \ If we get here then this is a pirate and we are inside
                        \ the space station safe zone

 LDA INWK+32            \ Clear bits 1 to 6 of the AI flag in byte #32 (to set
 AND #%10000001         \ the aggression level to zero)
 STA INWK+32

.TN4

 LDX #8                 \ We now want to copy the ship's x, y and z coordinates
                        \ from INWK to K3, so set up a counter for 9 bytes

.TAL1

 LDA INWK,X             \ Copy the X-th byte from INWK to the X-th byte of K3
 STA K3,X

 DEX                    \ Decrement the counter

 BPL TAL1               \ Loop back until we have copied all 9 bytes

.TA19

                        \ If this is a missile that's heading for its target
                        \ (not us, one of the other ships), then the missile
                        \ routine at TA18 above jumps here after setting K3 to
                        \ the vector from the target to the missile

 JSR TAS2               \ Normalise the vector in K3 and store the normalised
                        \ version in XX15, so XX15 contains the normalised
                        \ vector from our ship to the ship we are applying AI
                        \ tactics to (or the normalised vector from the target
                        \ to the missile - in both cases it's the vector from
                        \ the potential victim to the attacker)

 LDY #10                \ Set (A X) = nosev . XX15
 JSR TAS3

 STA CNT                \ Store the high byte of the dot product in CNT. The
                        \ bigger the value, the more aligned the two ships are,
                        \ with a maximum magnitude of 36 (96 * 96 >> 8). If CNT
                        \ is positive, the ships are facing in a similar
                        \ direction, if it's negative they are facing in
                        \ opposite directions

\ ******************************************************************************
\
\       Name: TACTICS (Part 4 of 7)
\       Type: Subroutine
\   Category: Tactics
\    Summary: Apply tactics: Check energy levels, maybe launch escape pod if low
\  Deep dive: Program flow of the tactics routine
\
\ ------------------------------------------------------------------------------
\
\ This section works out what kind of condition the ship is in. Specifically:
\
\   * If this is an Anaconda, consider spawning (22% chance) a Worm (61% of the
\     time) or a Sidewinder (39% of the time)
\
\   * Rarely (2.5% chance) roll the ship by a noticeable amount
\
\   * If the ship has at least half its energy banks full, jump to part 6 to
\     consider firing the lasers
\
\   * If the ship is not into the last 1/8th of its energy, jump to part 5 to
\     consider firing a missile
\
\   * If the ship is into the last 1/8th of its energy, and this ship type has
\     an escape pod fitted, then rarely (10% chance) the ship launches an escape
\     pod and is left drifting in space
\
\ ******************************************************************************

 LDA TYPE               \ If this is not a missile, skip the following
 CMP #MSL               \ instruction
 BNE P%+5

 JMP TA20               \ This is a missile, so jump down to TA20 to get
                        \ straight into some aggressive manoeuvring

 CMP #ANA               \ If this is not an Anaconda, jump down to TN7 to skip
 BNE TN7                \ the following

 JSR DORND              \ Set A and X to random numbers

 CMP #200               \ If A < 200 (78% chance), jump down to TN7 to skip the
 BCC TN7                \ following

 JSR DORND              \ Set A and X to random numbers

 LDX #WRM               \ Set X to the ship type for a Worm

 CMP #100               \ If A >= 100 (61% chance), skip the following
 BCS P%+4               \ instruction

 LDX #SH3               \ Set X to the ship type for a Sidewinder

 JMP TN6                \ Jump to TN6 to spawn the Worm or Sidewinder and return
                        \ from the subroutine using a tail call

.TN7

 JSR DORND              \ Set A and X to random numbers

 CMP #250               \ If A < 250 (97.5% chance), jump down to TA7 to skip
 BCC TA7                \ the following

 JSR DORND              \ Set A and X to random numbers

 ORA #104               \ Bump A up to at least 104 and store in the roll
 STA INWK+29            \ counter, to gives the ship a noticeable roll

.TA7

 LDY #14                \ Set A = the ship's maximum energy / 2
 LDA (XX0),Y
 LSR A

 CMP INWK+35            \ If the ship's current energy in byte #35 > A, i.e. the
 BCC TA3                \ ship has at least half of its energy banks charged,
                        \ jump down to TA3

 LSR A                  \ If the ship's current energy in byte #35 > A / 4, i.e.
 LSR A                  \ the ship is not into the last 1/8th of its energy,
 CMP INWK+35            \ jump down to ta3 to consider firing a missile
 BCC ta3

 JSR DORND              \ Set A and X to random numbers

 CMP #230               \ If A < 230 (90% chance), jump down to ta3 to consider
 BCC ta3                \ firing a missile

 LDX TYPE               \ Fetch the ship blueprint's default NEWB flags from the
 LDA E%-1,X             \ table at E%, and if bit 7 is clear (i.e. this ship
 BPL ta3                \ does not have an escape pod), jump to ta3 to skip the
                        \ spawning of an escape pod

                        \ By this point, the ship has run out of both energy and
                        \ luck, so it's time to bail

 LDA NEWB               \ Clear bits 0-3 of the NEWB flags, so the ship is no
 AND #%11110000         \ longer a trader, a bounty hunter, hostile or a pirate
 STA NEWB               \ and the escape pod we are about to spawn won't inherit
                        \ any of these traits

 LDY #36                \ Update the NEWB flags in the ship's data block
 STA (INF),Y

 LDA #%00000000         \ Set the AI flag to 0 to disable AI, set aggression to
 STA INWK+32            \ zero and disable any E.C.M., so the ship's a sitting
                        \ duck

 JMP SESCP              \ Jump to SESCP to spawn an escape pod from the ship,
                        \ returning from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: TACTICS (Part 5 of 7)
\       Type: Subroutine
\   Category: Tactics
\    Summary: Apply tactics: Consider whether to launch a missile at us
\  Deep dive: Program flow of the tactics routine
\
\ ------------------------------------------------------------------------------
\
\ This section considers whether to launch a missile. Specifically:
\
\   * If the ship doesn't have any missiles, skip to the next part
\
\   * If an E.C.M. is firing, skip to the next part
\
\   * Randomly decide whether to fire a missile (or, in the case of Thargoids,
\     release a Thargon), and if we do, we're done
\
\ ******************************************************************************

.ta3

                        \ If we get here then the ship has less than half energy
                        \ so there may not be enough juice for lasers, but let's
                        \ see if we can fire a missile

 LDA INWK+31            \ Set A = bits 0-2 of byte #31, the number of missiles
 AND #%00000111         \ the ship has left

 BEQ TA3                \ If it doesn't have any missiles, jump to TA3

 STA T                  \ Store the number of missiles in T

 JSR DORND              \ Set A and X to random numbers

 AND #31                \ Restrict A to a random number in the range 0-31

 CMP T                  \ If A >= T, which is quite likely, though less likely
 BCS TA3                \ with higher numbers of missiles, jump to TA3 to skip
                        \ firing a missile

 LDA ECMA               \ If an E.C.M. is currently active (either ours or an
 BNE TA3                \ opponent's), jump to TA3 to skip firing a missile

 DEC INWK+31            \ We're done with the checks, so it's time to fire off a
                        \ missile, so reduce the missile count in byte #31 by 1

 LDA TYPE               \ Fetch the ship type into A

 CMP #THG               \ If this is not a Thargoid, jump down to TA16 to launch
 BNE TA16               \ a missile

 LDX #TGL               \ This is a Thargoid, so instead of launching a missile,
 LDA INWK+32            \ the mothership launches a Thargon, so call SFS1 to
 JMP SFS1               \ spawn a Thargon from the parent ship, and return from
                        \ the subroutine using a tail call

.TA16

 JMP SFRMIS             \ Jump to SFRMIS to spawn a missile as a child of the
                        \ current ship, make a noise and print a message warning
                        \ of incoming missiles, and return from the subroutine
                        \ using a tail call

\ ******************************************************************************
\
\       Name: TACTICS (Part 6 of 7)
\       Type: Subroutine
\   Category: Tactics
\    Summary: Apply tactics: Consider firing a laser at us, if aim is true
\  Deep dive: Program flow of the tactics routine
\
\ ------------------------------------------------------------------------------
\
\ This section looks at potentially firing the ship's laser at us. Specifically:
\
\   * If the ship is not pointing at us, skip to the next part
\
\   * If the ship is pointing at us but not accurately, fire its laser at us and
\     skip to the next part
\
\   * If we are in the ship's crosshairs, register some damage to our ship, slow
\     down the attacking ship, make the noise of us being hit by laser fire, and
\     move on to the next part to manoeuvre the attacking ship
\
\ ******************************************************************************

.TA3

                        \ If we get here then the ship either has plenty of
                        \ energy, or levels are low but it couldn't manage to
                        \ launch a missile, so maybe we can fire the laser?

 LDA #0                 \ Set A to x_hi OR y_hi OR z_hi
 JSR MAS4

 AND #%11100000         \ If any of the hi bytes have any of bits 5-7 set, then
 BNE TA4                \ jump to TA4 to skip the laser checks, as the ship is
                        \ too far away from us to hit us with a laser

 LDX CNT                \ Set X = the dot product set above in CNT. If this is
                        \ positive, this ship and our ship are facing in similar
                        \ directions, but if it's negative then we are facing
                        \ each other, so for us to be in the enemy ship's line
                        \ of fire, X needs to be negative. The value in X can
                        \ have a maximum magnitude of 36, which would mean we
                        \ were facing each other square on, so in the following
                        \ code we check X like this:
                        \
                        \   X = 0 to -31, we are not in the enemy ship's line
                        \       of fire, so they can't shoot at us
                        \
                        \   X = -32 to -34, we are in the enemy ship's line
                        \       of fire, so they can shoot at us, but they can't
                        \       hit us as we're not dead in their crosshairs
                        \
                        \   X = -35 to -36, we are bang in the middle of the
                        \       enemy ship's crosshairs, so they can not only
                        \       shoot at us, they can hit us

\BPL TA4                \ This instruction is commented out in the original
                        \ source

 CPX #160               \ If X < 160, i.e. X > -32, then we are not in the enemy
 BCC TA4                \ ship's line of fire, so jump to TA4 to skip the laser
                        \ checks

 LDY #19                \ Fetch the enemy ship's byte #19 from their ship's
 LDA (XX0),Y            \ blueprint into A

 AND #%11111000         \ Extract bits 3-7, which contain the enemy's laser
                        \ power

 BEQ TA4                \ If the enemy has no laser power, jump to TA4 to skip
                        \ the laser checks

 LDA INWK+31            \ Set bit 6 in byte #31 to denote that the ship is
 ORA #%01000000         \ firing its laser at us
 STA INWK+31

 CPX #163               \ If X < 163, i.e. X > -35, then we are not in the enemy
 BCC TA4                \ ship's crosshairs, so jump to TA4 to skip the laser
                        \ checks

\LDY #19                \ This instruction is commented out in the original
                        \ source

 LDA (XX0),Y            \ Fetch the enemy ship's byte #19 from their ship's
                        \ blueprint into A

 LSR A                  \ Halve the enemy ship's byte #19 (which contains both
                        \ the laser power and number of missiles) to get the
                        \ amount of damage we should take

 JSR OOPS               \ Call OOPS to take some damage, which could do anything
                        \ from reducing the shields and energy, all the way to
                        \ losing cargo or dying (if the latter, we don't come
                        \ back from this subroutine)

 DEC INWK+28            \ Halve the attacking ship's acceleration in byte #28

 LDA ECMA               \ If an E.C.M. is currently active (either ours or an
 BNE TA9-1              \ opponent's), return from the subroutine without making
                        \ the laser-strike sound (as TA9-1 contains an RTS)

 JSR ELASNO             \ Call the ELASNO routine to make the sound of us
                        \ being hit by lasers

\ ******************************************************************************
\
\       Name: TACTICS (Part 7 of 7)
\       Type: Subroutine
\   Category: Tactics
\    Summary: Apply tactics: Set pitch, roll, and acceleration
\  Deep dive: Program flow of the tactics routine
\             Aggression and hostility in ship tactics
\
\ ------------------------------------------------------------------------------
\
\ This section looks at manoeuvring the ship. Specifically:
\
\   * Work out which direction the ship should be moving, depending on the type
\     of ship, where it is, which direction it is pointing, and how aggressive
\     it is
\
\   * Set the pitch and roll counters to head in that direction
\
\   * Speed up or slow down, depending on where the ship is in relation to us
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   TA151               Make the ship head towards the planet
\
\   TA9-1               Contains an RTS
\
\ ******************************************************************************

.TA4

 LDA INWK+7             \ If z_hi >= 3 then the ship is quite far away, so jump
 CMP #3                 \ down to TA5
 BCS TA5

 LDA INWK+1             \ Otherwise set A = x_hi OR y_hi and extract bits 1-7
 ORA INWK+4
 AND #%11111110

 BEQ TA15               \ If A = 0 then the ship is pretty close to us, so jump
                        \ to TA15 so it heads away from us

.TA5

                        \ If we get here then the ship is quite far away

 JSR DORND              \ Set A and X to random numbers

 ORA #%10000000         \ Set bit 7 of A, so the following comparison ignores
                        \ the AI flag in bit 7 (as we already know bit 7 is set
                        \ in byte #32)

 CMP INWK+32            \ If A >= byte #32 (the ship's AI flag) then jump down
 BCS TA15               \ to TA15 so it heads away from us

                        \ We get here if byte #32 > A, where byte #32 is
                        \ composed of the following:
                        \
                        \   * Bit 7 set = AI is enabled
                        \
                        \   * Bits 1-6 = aggression level (0 to 63)
                        \
                        \   * Bit 0 set = ship has E.C.M.
                        \
                        \ We set bit 7 of A above, so if we get here we know the
                        \ ship has AI enabled, and the comparison then boils
                        \ down to the following:
                        \
                        \   Aggression level * 2 + E.C.M. > random number 0-127
                        \
                        \ In other words, higher aggression levels increase the
                        \ chances of a ship changing direction to head towards
                        \ us - or, to put it another way, ships with higher
                        \ aggression levels are spoiling for a fight, with
                        \ E.C.M. making them even more aggressive
                        \
                        \ Thargoids and missiles both have an aggression level
                        \ of 63 out of 63, which explains an awful lot
                        \
                        \ Interestingly, escape pods also have a maximum
                        \ agression level, but in this case it makes them fly
                        \ towards the planet rather than towards us

.TA20

                        \ If this is a missile we will have jumped straight
                        \ here, but we also get here if the ship is either far
                        \ away and aggressive, or not too close

 JSR TAS6               \ Call TAS6 to negate the vector in XX15 so it points in
                        \ the opposite direction

 LDA CNT                \ Change the sign of the dot product in CNT, so now it's
 EOR #%10000000         \ positive if the ships are facing each other, and
                        \ negative if they are facing the same way

.TA152

 STA CNT                \ Update CNT with the new value in A

.TA15

                        \ If we get here, then one of the following is true:
                        \
                        \   * This is a trader and XX15 is pointing towards the
                        \     planet
                        \
                        \   * The ship is pretty close to us, or it's just not
                        \     very aggressive (though there is a random factor
                        \     at play here too). XX15 is still pointing from our
                        \     ship towards the enemy ship
                        \
                        \   * The ship is aggressive (though again, there's an
                        \     element of randomness here). XX15 is pointing from
                        \     the enemy ship towards our ship
                        \
                        \   * This is a missile heading for a target. XX15 is
                        \     pointing from the missile towards the target
                        \
                        \ We now want to move the ship in the direction of XX15,
                        \ which will make aggressive ships head towards us, and
                        \ ships that are too close turn away. Peaceful traders,
                        \ meanwhile, head off towards the planet in search of a
                        \ space station, and missiles home in on their targets

 LDY #16                \ Set (A X) = roofv . XX15
 JSR TAS3               \
                        \ This will be positive if XX15 is pointing in the same
                        \ direction as an arrow out of the top of the ship, in
                        \ other words if the ship should pull up to head in the
                        \ direction of XX15

 TAX                    \ Copy A into X so we can retrieve it below

 EOR #%10000000         \ Give the ship's pitch counter the opposite sign to the
 AND #%10000000         \ dot product result, with a value of 0
 STA INWK+30

 TXA                    \ Retrieve the original value of A from X

 ASL A                  \ Shift A left to double it and drop the sign bit

 CMP RAT2               \ If A < RAT2, skip to TA11 (so if RAT2 = 0, we always
 BCC TA11               \ set the pitch counter to RAT)

 LDA RAT                \ Set the magnitude of the ship's pitch counter to RAT
 ORA INWK+30            \ (we already set the sign above)
 STA INWK+30

.TA11

 LDA INWK+29            \ Fetch the roll counter from byte #29 into A

 ASL A                  \ Shift A left to double it and drop the sign bit

 CMP #32                \ If A >= 32 then jump to TA6, as the ship is already
 BCS TA6                \ in the process of rolling

 LDY #22                \ Set (A X) = sidev . XX15
 JSR TAS3               \
                        \ This will be positive if XX15 is pointing in the same
                        \ direction as an arrow out of the right side of the
                        \ ship, in other words if the ship should roll right to
                        \ head in the direction of XX15

 TAX                    \ Copy A into X so we can retrieve it below

 EOR INWK+30            \ Give the ship's roll counter a positive sign
 AND #%10000000         \ (clockwise roll) if the pitch counter and dot product
 EOR #%10000000         \ have different signs, negative (anti-clockwise roll)
 STA INWK+29            \ if they have the same sign, with a value of 0

 TXA                    \ Retrieve the original value of A from X

 ASL A                  \ Shift A left to double it and drop the sign bit

 CMP RAT2               \ If A < RAT2, skip to TA12 (so if RAT2 = 0, we always
 BCC TA12               \ set the roll counter to RAT)

 LDA RAT                \ Set the magnitude of the ship's roll counter to RAT
 ORA INWK+29            \ (we already set the sign above)
 STA INWK+29

.TA12

.TA6

 LDA CNT                \ Fetch the dot product, and if it's negative jump to
 BMI TA9                \ TA9, as the ships are facing away from each other and
                        \ the ship might want to slow down to take another shot

 CMP CNT2               \ The dot product is positive, so the ships are facing
 BCC TA9                \ each other. If A < CNT2 then the ships are not heading
                        \ directly towards each other, so jump to TA9 to slow
                        \ down

.PH10E

 LDA #3                 \ Otherwise set the acceleration in byte #28 to 3
 STA INWK+28

 RTS                    \ Return from the subroutine

.TA9

 AND #%01111111         \ Clear the sign bit of the dot product in A

 CMP #18                \ If A < 18 then the ship is way off the XX15 vector, so
 BCC TA10               \ return from the subroutine (TA10 contains an RTS)
                        \ without slowing down, as it still has quite a bit of
                        \ turning to do to get on course

 LDA #&FF               \ Otherwise set A = -1

 LDX TYPE               \ If this is not a missile then skip the ASL instruction
 CPX #MSL
 BNE P%+3

 ASL A                  \ This is a missile, so set A = -2, as missiles are more
                        \ nimble and can brake more quickly

 STA INWK+28            \ Set the ship's acceleration to A

.TA10

 RTS                    \ Return from the subroutine

.TA151

                        \ This is called from part 3 with the vector to the
                        \ planet in XX15, when we want the ship to turn towards
                        \ the planet. It does the same dot product calculation
                        \ as part 3, but it can also change the value of RAT2
                        \ so that roll and pitch is always applied

 LDY #10                \ Set (A X) = nosev . XX15
 JSR TAS3               \
                        \ The bigger the value of the dot product, the more
                        \ aligned the two vectors are, with a maximum magnitude
                        \ in A of 36 (96 * 96 >> 8). If A is positive, the
                        \ vectors are facing in a similar direction, if it's
                        \ negative they are facing in opposite directions

 CMP #&98               \ If A is positive or A <= -24, jump to ttt
 BCC ttt

 LDX #0                 \ A > -24, which means the vectors are facing in
 STX RAT2               \ opposite directions but are quite aligned, so set
                        \ RAT2 = 0 instead of the default value of 4, so we
                        \ always apply roll and pitch when we turn the ship
                        \ all the way around towards the planet

.ttt

 JMP TA152              \ Jump to TA152 to store A in CNT and move the ship in
                        \ the direction of XX15

\ ******************************************************************************
\
\       Name: SESCP
\       Type: Subroutine
\   Category: Flight
\    Summary: Spawn an escape pod from the current (parent) ship
\  Deep dive: Aggression and hostility in ship tactics
\
\ ------------------------------------------------------------------------------
\
\ This is called when an enemy ship has run out of both energy and luck, so it's
\ time to bail.
\
\ ******************************************************************************

.SESCP

 LDX #ESC               \ Set X to the ship type for an escape pod

 LDA #%11111110         \ Set A to use as an AI flag that has AI enabled, an
                        \ aggression level of 63 out of 63, and no E.C.M.
                        \
                        \ When spawning an escape pod, this high agression level
                        \ makes the pod turn towards the planet rather than
                        \ towards us
                        \
                        \ This instruction is also used as an entry point to
                        \ spawn missile (when calling via the SFS1-2 entry
                        \ point), in which case the missile has AI (bit 7 set),
                        \ is hostile (bit 6 set) and has been launched (bit 0
                        \ clear); the target slot number is set to 31, but this
                        \ is ignored as the hostile flag means we are the target

                        \ Fall through into SFS1 to spawn the escape pod or
                        \ missile

\ ******************************************************************************
\
\       Name: SFS1
\       Type: Subroutine
\   Category: Universe
\    Summary: Spawn a child ship from the current (parent) ship
\
\ ------------------------------------------------------------------------------
\
\ If the parent is a space station then the child ship is spawned coming out of
\ the slot, and if the child is a cargo canister, it is sent tumbling through
\ space. Otherwise the child ship is spawned with the same ship data as the
\ parent, just with damping disabled and the ship type and AI flag that are
\ passed in A and X.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   AI flag for the new ship (see the documentation on ship
\                       data byte #32 for details)
\
\   X                   The ship type of the child to spawn
\
\   INF                 Address of the parent's ship data block
\
\   TYPE                The type of the parent ship
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              Set if ship successfully added, clear if it failed
\
\   INF                 INF is preserved
\
\   XX0                 XX0 is preserved
\
\   INWK                The whole INWK workspace is preserved
\
\   X                   X is preserved
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   SFS1-2              Used to add a missile to the local bubble that that has
\                       AI (bit 7 set), is hostile (bit 6 set) and has been
\                       launched (bit 0 clear); the target slot number is set to
\                       31, but this is ignored as the hostile flags means we
\                       are the target
\
\ ******************************************************************************

.SFS1

 STA T1                 \ Store the child ship's AI flag in T1

                        \ Before spawning our child ship, we need to save the
                        \ INF and XX00 variables and the whole INWK workspace,
                        \ so we can restore them later when returning from the
                        \ subroutine

 TXA                    \ Store X, the ship type to spawn, on the stack so we
 PHA                    \ can preserve it through the routine

 LDA XX0                \ Store XX0(1 0) on the stack, so we can restore it
 PHA                    \ later when returning from the subroutine
 LDA XX0+1
 PHA

 LDA INF                \ Store INF(1 0) on the stack, so we can restore it
 PHA                    \ later when returning from the subroutine
 LDA INF+1
 PHA

 LDY #NI%-1             \ Now we want to store the current INWK data block in
                        \ temporary memory so we can restore it when we are
                        \ done, and we also want to copy the parent's ship data
                        \ into INWK, which we can do at the same time, so set up
                        \ a counter in Y for NI% bytes

.FRL2

 LDA INWK,Y             \ Copy the Y-th byte of INWK to the Y-th byte of
 STA XX3,Y              \ temporary memory in XX3, so we can restore it later
                        \ when returning from the subroutine

 LDA (INF),Y            \ Copy the Y-th byte of the parent ship's data block to
 STA INWK,Y             \ the Y-th byte of INWK

 DEY                    \ Decrement the loop counter

 BPL FRL2               \ Loop back to copy the next byte until we have done
                        \ them all

                        \ INWK now contains the ship data for the parent ship,
                        \ so now we need to tweak the data before creating the
                        \ new child ship (in this way, the child inherits things
                        \ like location from the parent)

 LDA TYPE               \ Fetch the ship type of the parent into A

 CMP #SST               \ If the parent is not a space station, jump to rx to
 BNE rx                 \ skip the following

                        \ The parent is a space station, so the child needs to
                        \ launch out of the space station's slot. The space
                        \ station's nosev vector points out of the station's
                        \ slot, so we want to move the ship along this vector.
                        \ We do this by taking the unit vector in nosev and
                        \ doubling it, so we spawn our ship 2 units along the
                        \ vector from the space station's centre

 TXA                    \ Store the child's ship type in X on the stack
 PHA

 LDA #32                \ Set the child's byte #27 (speed) to 32
 STA INWK+27

 LDX #0                 \ Add 2 * nosev_x_hi to (x_lo, x_hi, x_sign) to get the
 LDA INWK+10            \ child's x-coordinate
 JSR SFS2

 LDX #3                 \ Add 2 * nosev_y_hi to (y_lo, y_hi, y_sign) to get the
 LDA INWK+12            \ child's y-coordinate
 JSR SFS2

 LDX #6                 \ Add 2 * nosev_z_hi to (z_lo, z_hi, z_sign) to get the
 LDA INWK+14            \ child's z-coordinate
 JSR SFS2

 PLA                    \ Restore the child's ship type from the stack into X
 TAX

.rx

 LDA T1                 \ Restore the child ship's AI flag from T1 and store it
 STA INWK+32            \ in the child's byte #32 (AI)

 LSR INWK+29            \ Clear bit 0 of the child's byte #29 (roll counter) so
 ASL INWK+29            \ that its roll dampens (so if we are spawning from a
                        \ space station, for example, the spawned ship won't
                        \ keep rolling forever)

 TXA                    \ Copy the child's ship type from X into A

 CMP #SPL+1             \ If the type of the child we are spawning is less than
 BCS NOIL               \ #PLT or greater than #SPL - i.e. not an alloy plate,
 CMP #PLT               \ cargo canister, boulder, asteroid or splinter - then
 BCC NOIL               \ jump to NOIL to skip us setting up some pitch and roll
                        \ for it

 PHA                    \ Store the child's ship type on the stack so we can
                        \ retrieve it below

 JSR DORND              \ Set A and X to random numbers

 ASL A                  \ Set the child's byte #30 (pitch counter) to a random
 STA INWK+30            \ value, and at the same time set the C flag randomly

 TXA                    \ Set the child's byte #27 (speed) to a random value
 AND #%00001111         \ between 0 and 15
 STA INWK+27

 LDA #&FF               \ Set the child's byte #29 (roll counter) to a full
 ROR A                  \ roll with no damping (as bits 0 to 6 are set), so the
 STA INWK+29            \ canister tumbles through space, with the direction in
                        \ bit 7 set randomly, depending on the C flag from above

 PLA                    \ Retrieve the child's ship type from the stack

.NOIL

 JSR NWSHP              \ Add a new ship of type A to the local bubble

                        \ We have now created our child ship, so we need to
                        \ restore all the variables we saved at the start of
                        \ the routine, so they are preserved when we return
                        \ from the subroutine

 PLA                    \ Restore INF(1 0) from the stack
 STA INF+1
 PLA
 STA INF

 LDX #NI%-1             \ Now to restore the INWK workspace that we saved into
                        \ XX3 above, so set a counter in X for NI% bytes

.FRL3

 LDA XX3,X              \ Copy the Y-th byte of XX3 to the Y-th byte of INWK
 STA INWK,X

 DEX                    \ Decrement the loop counter

 BPL FRL3               \ Loop back to copy the next byte until we have done
                        \ them all

 PLA                    \ Restore XX0(1 0) from the stack
 STA XX0+1
 PLA
 STA XX0

 PLA                    \ Retrieve the ship type to spawn from the stack into X
 TAX                    \ so it is preserved through calls to this routine

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: SFS2
\       Type: Subroutine
\   Category: Moving
\    Summary: Move a ship in space along one of the coordinate axes
\
\ ------------------------------------------------------------------------------
\
\ Move a ship's coordinates by a certain amount in the direction of one of the
\ axes, where X determines the axis. Mathematically speaking, this routine
\ translates the ship along a single axis by a signed delta.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The amount of movement, i.e. the signed delta
\
\   X                   Determines which coordinate axis of INWK to move:
\
\                         * X = 0 moves the ship along the x-axis
\
\                         * X = 3 moves the ship along the y-axis
\
\                         * X = 6 moves the ship along the z-axis
\
\ ******************************************************************************

.SFS2

 ASL A                  \ Set R = |A * 2|, with the C flag set to bit 7 of A
 STA R

 LDA #0                 \ Set bit 7 of A to the C flag, i.e. the sign bit from
 ROR A                  \ the original argument in A

 JMP MVT1               \ Add the delta R with sign A to (x_lo, x_hi, x_sign)
                        \ (or y or z, depending on the value in X) and return
                        \ from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: SHPPT
\       Type: Subroutine
\   Category: Drawing ships
\    Summary: Draw a distant ship as a point rather than a full wireframe
\
\ ******************************************************************************

.SHPPT

 JSR PROJ               \ Project the ship onto the screen, returning:
                        \
                        \   * K3(1 0) = the screen x-coordinate
                        \   * K4(1 0) = the screen y-coordinate
                        \   * A = K4+1

 ORA K3+1               \ If either of the high bytes of the screen coordinates
 BNE nono               \ are non-zero, jump to nono as the ship is off-screen

 LDA K4                 \ Set A = the y-coordinate of the dot

 CMP #Y*2-2             \ If the y-coordinate is bigger than the y-coordinate of
 BCS nono               \ the bottom of the screen, jump to nono as the ship's
                        \ dot is off the bottom of the space view

 JSR H_SHPPT            \ Port: in record mode, record the dot for the renderer
                        \ and continue at SHPPT2 (gfx-hooks.asm)

 JSR Shpt               \ Call Shpt to draw a horizontal four-pixel dash for the
                        \ first row of the dot (i.e. a four-pixel dash)

 LDA K4                 \ Set A = y-coordinate of dot + 1 (so this is the second
 CLC                    \ row of the two-pixel high dot)
 ADC #1

 JSR Shpt               \ Call Shpt to draw a horizontal four-pixel dash for the
                        \ second row of the dot (i.e. a four-pixel dash)

.SHPPT2

 LDA #%00001000         \ Set bit 3 of the ship's byte #31 to record that we
 ORA XX1+31             \ have now drawn something on-screen for this ship
 STA XX1+31

 JMP LSCLR              \ Jump to LSCLR to draw any remaining lines that are
                        \ still in the ship line heap and return from the
                        \ subroutine using a tail call

.nono

 LDA #%11110111         \ Clear bit 3 of the ship's byte #31 to record that
 AND XX1+31             \ nothing is being drawn on-screen for this ship
 STA XX1+31

 JMP LSCLR              \ Jump to LSCLR to draw any remaining lines that are
                        \ still in the ship line heap and return from the
                        \ subroutine using a tail call

.Shpt

                        \ This routine draws a horizontal four-pixel dash, for
                        \ either the top or the bottom of the ship's dot

 STA Y1                 \ Store A in both y-coordinates, as this is a horizontal
 STA Y2                 \ dash at y-coordinate A

 LDA K3                 \ Set A = screen x-coordinate of the ship dot

 STA X1                 \ Store the x-coordinate of the ship dot in X1, as this
                        \ is where the dash starts

 CLC                    \ Set A = screen x-coordinate of the ship dot + 3
 ADC #3

 BCC P%+4               \ If the addition overflowed, set A = 255, the
 LDA #255               \ x-coordinate of the right edge of the screen

 STA X2                 \ Store the x-coordinate of the ship dot in X1, as this
                        \ is where the dash starts

 JMP LSPUT              \ Draw this edge using flicker-free animation, by first
                        \ drawing the ship's new line and then erasing the
                        \ corresponding old line from the screen, and return
                        \ from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: LL5
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate Q = SQRT(R Q)
\  Deep dive: Calculating square roots
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following square root:
\
\   Q = SQRT(R Q)
\
\ ******************************************************************************

.LL5

                        \ Port: the dividend high byte lives in T and the
                        \ remainder in A during the loop, so both can be
                        \ shifted in place, and Y is the loop counter

 LDA R                  \ Set T = R, the dividend high byte
 STA T
 LDA Q                  \ Push Q, the dividend low byte, which is fed into T
 PHA                    \ after the first four loops (when the original's
                        \ 8 shifts of (T S) would have moved S into T)

                        \ So now to calculate Q = SQRT(T S)

 STZ Q                  \ Set Q = 0, to hold the result

 STZ S                  \ Leave S = 0 on exit, as the original's 16 shifts do

 LDA #0                 \ Set A = 0, to hold the remainder

 JSR LL5h               \ Do the first four loops, shifting zeroes into T

 PLX                    \ T is now 0, so set T to the dividend low byte, as
 STX T                  \ the original has it at this point, and fall through
                        \ to do the last four loops

.LL5h

 LDY #4                 \ Set Y = 4, to use as a loop counter

.LL6

 CMP Q                  \ If A < Q, jump to LL7
 BCC LL7

 BNE P%+8               \ If A > Q, skip the next three instructions

 LDX T                  \ If T < 64, jump to LL7 with the C flag clear,
 CPX #64                \ otherwise fall through with the C flag set
 BCC LL7

 TAX                    \ Set (A T) = (A T) - (Q 64), with C set on entry
 LDA T                  \ (same subtractions, in the same order, as the
 SBC #64                \ original, so C and V end up the same)
 STA T
 TXA
 SBC Q

.LL7

 ROL Q                  \ Shift the result in Q to the left, shifting the C flag
                        \ into bit 0 and bit 7 into the C flag

 ASL T                  \ Shift (A T) to the left
 ROL A

 ASL T                  \ Shift (A T) to the left
 ROL A

 DEY                    \ Decrement the loop counter

 BNE LL6                \ Loop back to LL6 until we have done 4 loops

 TAX                    \ Return with X = A = remainder; the 16 shifts leave
 LDY #0                 \ T = 0, and Y = 0 with Z set and N clear, exactly as
                        \ the original (C and V unchanged)

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: LL28
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate R = 256 * A / Q
\  Deep dive: Multiplication and division using logarithms
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following, where A < Q:
\
\   R = 256 * A / Q
\
\ This is a sister routine to LL61, which does the division when A >= Q.
\
\ If A >= Q then 255 is returned and the C flag is set to indicate an overflow
\ (the C flag is clear if the division was a success).
\
\ The result is returned in one byte as the result of the division multiplied
\ by 256, so we can return fractional results using integers.
\
\ This routine uses the same logarithm algorithm that's documented in FMLTU,
\ except it subtracts the logarithm values, to do a division instead of a
\ multiplication.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              Set if the answer is too big for one byte, clear if the
\                       division was a success
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   LL28+4              Skips the A >= Q check and always returns with C flag
\                       cleared, so this can be called if we know the division
\                       will work
\
\   LL31                Skips the A >= Q check and does not set the R counter,
\                       so this can be used for jumping straight into the
\                       division loop if R is already set to 254 and we know the
\                       division will work
\
\ ******************************************************************************

.LL28

 CMP Q                  \ If A >= Q, then the answer will not fit in one byte,
 BCS LL2                \ so jump to LL2 to return 255

 STA widget             \ Store A in widget, so now widget = argument A

 TAX                    \ Transfer A into X, so now X = argument A

 BEQ LLfix              \ If A = 0, jump to LLfix to return a result of 0, as
                        \ 0 * Q / 256 is always 0

                        \ We now want to calculate log(A) - log(Q), first adding
                        \ the low bytes (from the logL table), and then the high
                        \ bytes (from the log table)

 LDA logL,X             \ Set A = low byte of log(X)
                        \       = low byte of log(A) (as we set X to A above)

 LDX Q                  \ Set X = Q

 SEC                    \ Set A = A - low byte of log(Q)
 SBC logL,X             \       = low byte of log(A) - low byte of log(Q)

 LDX widget             \ Set A = high byte of log(A) - high byte of log(Q)
 LDA log,X
 LDX Q
 SBC log,X

 BCS LL2                \ If the subtraction fitted into one byte and didn't
                        \ underflow, then log(A) - log(Q) < 256, so we jump to
                        \ LL2 return a result of 255

 TAX                    \ Otherwise we return the A-th entry from the antilog
 LDA alogh,X            \ table

.LLfix

 STA R                  \ Set the result in R to the value of A

 RTS                    \ Return from the subroutine

\.LL28                  \ These instructions are commented out in the original
\CMP Q                  \ source

 BCS LL2                \ If the subtraction fitted into one byte and didn't
                        \ underflow, then log(A) - log(Q) < 256, so we jump to
                        \ LL2 to return a result of 255

 LDX #254               \ Otherwise set the result in R to 254
 STX R

.LL31

 ASL A                  \ Shift A to the left

 BCS LL29               \ If bit 7 of A was set, then jump straight to the
                        \ subtraction

 CMP Q                  \ If A < Q, skip the following subtraction
 BCC P%+4

 SBC Q                  \ A >= Q, so set A = A - Q

 ROL R                  \ Rotate the counter in R to the left, and catch the
                        \ result bit into bit 0 (which will be a 0 if we didn't
                        \ do the subtraction, or 1 if we did)

 BCS LL31               \ If we still have set bits in R, loop back to LL31 to
                        \ do the next iteration of 7

 RTS                    \ R left with remainder of division

.LL29

 SBC Q                  \ A >= Q, so set A = A - Q

 SEC                    \ Set the C flag to rotate into the result in R

 ROL R                  \ Rotate the counter in R to the left, and catch the
                        \ result bit into bit 0 (which will be a 0 if we didn't
                        \ do the subtraction, or 1 if we did)

 BCS LL31               \ If we still have set bits in R, loop back to LL31 to
                        \ do the next iteration of 7

 LDA R                  \ Set A to the remainder in R

 RTS                    \ Return from the subroutine with R containing the
                        \ remainder of the division

.LL2

 LDA #255               \ The division is very close to 1, so return the closest
 STA R                  \ possible answer to 256, i.e. R = 255

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: LL38
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (S A) = (S R) + (A Q)
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following between sign-magnitude numbers:
\
\   (S A) = (S R) + (A Q)
\
\ where the sign bytes only contain the sign bits, not magnitudes.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              Set if the addition overflowed, clear otherwise
\
\ ******************************************************************************

.LL38

 EOR S                  \ If the sign of A * S is negative, skip to LL35, as
 BMI LL39               \ A and S have different signs so we need to subtract

 LDA Q                  \ Otherwise set A = R + Q, which is the result we need,
 CLC                    \ as S already contains the correct sign
 ADC R

 RTS                    \ Return from the subroutine

.LL39

 LDA R                  \ Set A = R - Q
 SEC
 SBC Q

 BCC P%+4               \ If the subtraction underflowed, skip the next two
                        \ instructions so we can negate the result

 CLC                    \ Otherwise the result is correct, and S contains the
                        \ correct sign of the result as R is the dominant side
                        \ of the subtraction, so clear the C flag

 RTS                    \ And return from the subroutine

                        \ If we get here we need to negate both the result and
                        \ the sign in S, as both are the wrong sign

.LL40

 LDA S                  \ Flip the sign of S (C is still clear from the
 EOR #%10000000         \ underflowed subtraction)
 STA S

 LDA Q                  \ Port: C = 0, so this sets A = Q - R - 1, which is
 SBC R                  \ >= 0 as Q > R, so C is now set

 ADC #0                 \ A = Q - R = -(R - Q), and C ends up clear as the
                        \ result is in 1..255

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: LL51
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Calculate the dot product of XX15 and XX16
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following dot products:
\
\   XX12(1 0) = XX15(5 0) . XX16(5 0)
\   XX12(3 2) = XX15(5 0) . XX16(11 6)
\   XX12(5 4) = XX15(5 0) . XX16(12 17)
\
\ storing the results as sign-magnitude numbers in XX12 through XX12+5.
\
\ When called from part 5 of LL9, XX12 contains the vector [x y z] to the ship
\ we're drawing, and XX16 contains the orientation vectors, so it returns:
\
\   [ x ]   [ sidev_x ]         [ x ]   [ roofv_x ]         [ x ]   [ nosev_x ]
\   [ y ] . [ sidev_y ]         [ y ] . [ roofv_y ]         [ y ] . [ nosev_y ]
\   [ z ]   [ sidev_z ]         [ z ]   [ roofv_z ]         [ z ]   [ nosev_z ]
\
\ When called from part 6 of LL9, XX12 contains the vector [x y z] of the vertex
\ we're analysing, and XX16 contains the transposed orientation vectors with
\ each of them containing the x, y and z elements of the original vectors, so it
\ returns:
\
\   [ x ]   [ sidev_x ]         [ x ]   [ sidev_y ]         [ x ]   [ sidev_z ]
\   [ y ] . [ roofv_x ]         [ y ] . [ roofv_y ]         [ y ] . [ roofv_z ]
\   [ z ]   [ nosev_x ]         [ z ]   [ nosev_y ]         [ z ]   [ nosev_z ]
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   XX15(1 0)           The ship (or vertex)'s x-coordinate as (x_sign x_lo)
\
\   XX15(3 2)           The ship (or vertex)'s y-coordinate as (y_sign y_lo)
\
\   XX15(5 4)           The ship (or vertex)'s z-coordinate as (z_sign z_lo)
\
\   XX16 to XX16+5      The scaled sidev (or _x) vector, with:
\
\                         * x, y, z magnitudes in XX16, XX16+2, XX16+4
\
\                         * x, y, z signs in XX16+1, XX16+3, XX16+5
\
\   XX16+6 to XX16+11   The scaled roofv (or _y) vector, with:
\
\                         * x, y, z magnitudes in XX16+6, XX16+8, XX16+10
\
\                         * x, y, z signs in XX16+7, XX16+9, XX16+11
\
\   XX16+12 to XX16+17  The scaled nosev (or _z) vector, with:
\
\                         * x, y, z magnitudes in XX16+12, XX16+14, XX16+16
\
\                         * x, y, z signs in XX16+13, XX16+15, XX16+17
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   XX12(1 0)           The dot product of [x y z] vector with the sidev (or _x)
\                       vector, with the sign in XX12+1 and magnitude in XX12
\
\   XX12(3 2)           The dot product of [x y z] vector with the roofv (or _y)
\                       vector, with the sign in XX12+3 and magnitude in XX12+2
\
\   XX12(5 4)           The dot product of [x y z] vector with the nosev (or _z)
\                       vector, with the sign in XX12+5 and magnitude in XX12+4
\
\ ******************************************************************************

.LL51

 LDX #256-6             \ Set X = -6, which will contain the offset of the
                        \ result bytes in XX12 (relative to XX12+6, wrapping
                        \ within zero page), increasing by 2 for each new
                        \ result until it wraps to 0

 LDY #0                 \ Set Y = 0, which will contain the offset of the
                        \ vector to use in the calculation (relative to XX16),
                        \ increasing by 6 for each new vector

.ll51

 LDA XX15               \ Set Q = x_lo
 STA Q

 LDA XX16,Y             \ Set A = |sidev_x|

 JSR FMLTU              \ Set R = A * Q / 256
 STA R                  \       = |sidev_x| * x_lo / 256

 LDA XX15+1             \ Set S to the sign of x_sign * sidev_x
 EOR XX16+1,Y
 STA S

 LDA XX15+3             \ Set A to the sign of y_sign * sidev_y EOR S, so
 EOR XX16+3,Y           \ N tells us which case of the inlined LL38 we need
 EOR S                  \ before we multiply (the sign does not depend on the
 BMI ll51n1             \ product), jumping to ll51n1 if the signs differ

 LDA XX15+2             \ Set Q = y_lo
 STA Q

 LDA XX16+2,Y           \ Set A = |sidev_y|

 JSR FMLTU+2            \ Set A = A * Q / 256 = |sidev_y| * y_lo / 256
                        \ (skip FMLTU's STX P: the first FMLTU call this
                        \ pass already set P = X)

 CLC                    \ Set (S R) = (S R) + (A Q), same-sign case: R + A
 ADC R                  \ (LL38 inlined; the different-sign case is ll51n1)

.ll51r1

 STA R

 LDA XX15+5             \ Set A to the sign of z_sign * sidev_z EOR S (S is
 EOR XX16+5,Y           \ final here, ll51n1 having run LL39), jumping to
 EOR S                  \ ll51n2 if the signs differ
 BMI ll51n2

 LDA XX15+4             \ Set Q = z_lo
 STA Q

 LDA XX16+4,Y           \ Set A = |sidev_z|

 JSR FMLTU+2            \ Set A = A * Q / 256 = |sidev_z| * z_lo / 256
                        \ (skip FMLTU's STX P: P = X still holds from the
                        \ first FMLTU call this pass)

 CLC                    \ Set (S A) = (S R) + (A Q), same-sign case: R + A
 ADC R                  \ (LL38 inlined, as above)

.ll51r2

 STA XX12+6,X           \ Store the result in XX12+X+6(1 0)
 LDA S
 STA XX12+7,X

 LDY ll51yt-&FA,X       \ Set Y = Y + 6 by lookup on X (X = -6 -> Y = 6,
                        \ X = -4 -> Y = 12; on the last pass, X = -2, Y is
                        \ loaded from the byte after the table but is unused)

 INX                    \ Set X = X + 2
 INX

 BNE ll51               \ Loop back to ll51 until X wraps from -2 to 0

 RTS                    \ Return from the subroutine

.ll51yt

 EQUB 6, 0, 12          \ Next Y for X = -6 (+0) and X = -4 (+2)

.ll51n1

 LDA XX15+2             \ The different-sign case of the second term: set
 STA Q                  \ Q = |sidev_y| * y_lo / 256 as above, then call LL39
 LDA XX16+2,Y           \ for (S A) = (S R) + (A Q)
 JSR FMLTU+2
 STA Q
 LDA R                  \ (LL39 inlined: A = R - Q, and if that underflows,
 SEC                    \ LL40 negates A and flips the sign in S; C is clear
 SBC Q                  \ on entry to LL40 as it requires)
 BCS ll51r1
 JSR LL40
 BRA ll51r1

.ll51n2

 LDA XX15+4             \ The different-sign case of the third term, likewise
 STA Q
 LDA XX16+4,Y
 JSR FMLTU+2
 STA Q
 LDA R                  \ (LL39 inlined, as for ll51n1: A = R - Q, and if
 SEC                    \ that underflows, LL40 negates A and flips S, C
 SBC Q                  \ being clear as it requires)
 BCS ll51r2
 JSR LL40
 BRA ll51r2

\ ******************************************************************************
\
\       Name: LL9 (Part 1 of 12)
\       Type: Subroutine
\   Category: Drawing ships
\    Summary: Draw ship: Check if ship is exploding, check if ship is in front
\  Deep dive: Drawing ships
\
\ ------------------------------------------------------------------------------
\
\ This routine draws the current ship on the screen. This part checks to see if
\ the ship is exploding, or if it should start exploding, and if it does it sets
\ things up accordingly.
\
\ In this code, XX1 is used to point to the current ship's data block at INWK
\ (the two labels are interchangeable).
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   XX1                 XX1 shares its location with INWK, which contains the
\                       zero-page copy of the data block for this ship from the
\                       K% workspace
\
\   INF                 The address of the data block for this ship in workspace
\                       K%
\
\   XX19(1 0)           XX19(1 0) shares its location with INWK(34 33), which
\                       contains the ship line heap address pointer
\
\   XX0                 The address of the blueprint for this ship
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   EE51                Remove the current ship from the screen, called from
\                       SHPPT before drawing the ship as a point
\
\ ******************************************************************************

.LL25

 JMP PLANET             \ Jump to the PLANET routine, returning from the
                        \ subroutine using a tail call

.LL9

 LDX TYPE               \ If the ship type is negative then this indicates a
 BMI LL25               \ planet or sun, so jump to PLANET via LL25 above

 LDA shpcol,X           \ Set A to the ship colour for this type, from the X-th
                        \ entry in the shpcol table

 STA COL                \ Switch to this colour

 LDA #31                \ Set XX4 = 31 to store the ship's distance for later
 STA XX4                \ comparison with the visibility distance. We will
                        \ update this value below with the actual ship's
                        \ distance if it turns out to be visible on-screen

                        \ We now set things up for flicker-free ship plotting,
                        \ by setting the following:
                        \
                        \   LSNUM = offset to the first coordinate in the ship's
                        \           line heap
                        \
                        \   LSNUM2 = the number of bytes in the heap for the
                        \            ship that's currently on-screen (or 0 if
                        \            there is no ship currently on-screen)

 LDY #1                 \ Set LSNUM = 1, the offset of the first set of line
 STY LSNUM              \ coordinates in the ship line heap

 DEY                    \ Decrement Y to 0

 LDA #%00001000         \ If bit 3 of the ship's byte #31 is set, then the ship
 BIT INWK+31            \ is currently being drawn on-screen, so skip the
 BNE P%+5               \ following two instructions

 LDA #0                 \ The ship is not being drawn on screen, so set A = 0
                        \ so that LSNUM2 gets set to 0 below (as there are no
                        \ existing coordinates on the ship line heap for this
                        \ ship)

 EQUB &2C               \ Skip the next instruction by turning it into
                        \ &2C &B1 &BD, or BIT &BDB1 which does nothing apart
                        \ from affect the flags

 LDA (XX19),Y           \ Set LSNUM2 to the first byte of the ship's line heap,
 STA LSNUM2             \ which contains the number of bytes in the heap

 LDA NEWB               \ If bit 7 of the ship's NEWB flags is set, then the
 BMI EE51               \ ship has been scooped or has docked, so jump down to
                        \ EE51 to redraw its wireframe, to remove it from the
                        \ screen

 LDA #%00100000         \ If bit 5 of the ship's byte #31 is set, then the ship
 BIT XX1+31             \ is currently exploding, so jump down to EE28
 BNE EE28

 BPL EE28               \ If bit 7 of the ship's byte #31 is clear then the ship
                        \ has not just been killed, so jump down to EE28

                        \ Otherwise bit 5 is clear and bit 7 is set, so the ship
                        \ is not yet exploding but it has been killed, so we
                        \ need to start an explosion

 ORA XX1+31             \ Clear bits 6 and 7 of the ship's byte #31, to stop the
 AND #%00111111         \ ship from firing its laser and to mark it as no longer
 STA XX1+31             \ having just been killed

 LDA #0                 \ Set the ship's acceleration in byte #31 to 0, updating
 LDY #28                \ the byte in the workspace K% data block so we don't
 STA (INF),Y            \ have to copy it back from INWK later

 LDY #30                \ Set the ship's pitch counter in byte #30 to 0, to stop
 STA (INF),Y            \ the ship from pitching

 JSR EE51               \ Call EE51 to remove the ship from the screen

                        \ We now need to set up a new explosion cloud. We
                        \ initialise it with a size of 18 (which gets increased
                        \ by 4 every time the cloud gets redrawn), and the
                        \ explosion count (i.e. the number of particles in the
                        \ explosion), which go into bytes 1 and 2 of the ship
                        \ line heap. See DOEXP for more details of explosion
                        \ clouds

 LDY #1                 \ Set byte #1 of the ship line heap to 18, the initial
 LDA #18                \ size of the explosion cloud
 STA (XX19),Y

 LDY #7                 \ Fetch byte #7 from the ship's blueprint, which
 LDA (XX0),Y            \ determines the explosion count (i.e. the number of
 LDY #2                 \ vertices used as origins for explosion clouds), and
 STA (XX19),Y           \ store it in byte #2 of the ship line heap

                        \ The following loop sets bytes 3-6 of the of the ship
                        \ line heap to random numbers

.EE55

 INY                    \ Increment Y (so the loop starts at 3)

 JSR DORND              \ Set A and X to random numbers

 STA (XX19),Y           \ Store A in the Y-th byte of the ship line heap

 CPY #6                 \ Loop back until we have randomised the 6th byte
 BNE EE55

.EE28

 LDA XX1+8              \ Set A = z_sign

.EE49

 BPL LL10               \ If A is positive, i.e. the ship is in front of us,
                        \ jump down to LL10

.LL14

                        \ The following removes the ship from the screen by
                        \ redrawing it (or, if it is exploding, by redrawing the
                        \ explosion cloud). We call it when the ship is no
                        \ longer on-screen, is too far away to be fully drawn,
                        \ and so on

 LDA XX1+31             \ If bit 5 of the ship's byte #31 is clear, then the
 AND #%00100000         \ ship is not currently exploding, so jump down to EE51
 BEQ EE51               \ to redraw its wireframe

 LDA XX1+31             \ The ship is exploding, so clear bit 3 of the ship's
 AND #%11110111         \ byte #31 to denote that the ship is no longer being
 STA XX1+31             \ drawn on-screen

 JMP DOEXP              \ Jump to DOEXP to display the explosion cloud, which
                        \ will remove it from the screen, returning from the
                        \ subroutine using a tail call

.EE51

 LDA #%00001000         \ If bit 3 of the ship's byte #31 is clear, then there
 BIT XX1+31             \ is already nothing being shown for this ship, so
 BEQ LL10-1             \ return from the subroutine (as LL10-1 contains an RTS)

 EOR XX1+31             \ Otherwise flip bit 3 of byte #31 and store it (which
 STA XX1+31             \ clears bit 3 as we know it was set before the EOR), so
                        \ this sets this ship as no longer being drawn on-screen

 JMP LSCLR              \ Jump to LSCLR to draw the ship, which removes it from
                        \ the screen, returning from the subroutine using a
                        \ tail call

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: LL9 (Part 2 of 12)
\       Type: Subroutine
\   Category: Drawing ships
\    Summary: Draw ship: Check if ship is in field of view, close enough to draw
\  Deep dive: Drawing ships
\
\ ------------------------------------------------------------------------------
\
\ This part checks whether the ship is in our field of view, and whether it is
\ close enough to be fully drawn (if not, we jump to SHPPT to draw it as a dot).
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   LL10-1              Contains an RTS
\
\ ******************************************************************************

.LL10

 LDA XX1+7              \ Set A = z_hi

 CMP #192               \ If A >= 192 then the ship is a long way away, so jump
 BCS LL14               \ to LL14 to remove the ship from the screen

 LDA XX1                \ If x_lo >= z_lo, set the C flag, otherwise clear it
 CMP XX1+6

 LDA XX1+1              \ Set A = x_hi - z_hi using the carry from the low
 SBC XX1+7              \ bytes, which sets the C flag as if we had done a full
                        \ two-byte subtraction (x_hi x_lo) - (z_hi z_lo)

 BCS LL14               \ If the C flag is set then x >= z, so the ship is
                        \ further to the side than it is in front of us, so it's
                        \ outside our viewing angle of 45 degrees, and we jump
                        \ to LL14 to remove it from the screen

 LDA XX1+3              \ If y_lo >= z_lo, set the C flag, otherwise clear it
 CMP XX1+6

 LDA XX1+4              \ Set A = y_hi - z_hi using the carry from the low
 SBC XX1+7              \ bytes, which sets the C flag as if we had done a full
                        \ two-byte subtraction (y_hi y_lo) - (z_hi z_lo)

 BCS LL14               \ If the C flag is set then y >= z, so the ship is
                        \ further above us than it is in front of us, so it's
                        \ outside our viewing angle of 45 degrees, and we jump
                        \ to LL14 to remove it from the screen

 LDY #6                 \ Fetch byte #6 from the ship's blueprint into X, which
 LDA (XX0),Y            \ is the number * 4 of the vertex used for the ship's
 TAX                    \ laser

 LDA #255               \ Set bytes X and X+1 of the XX3 heap to 255. We're
 STA XX3,X              \ going to use XX3 to store the screen coordinates of
 STA XX3+1,X            \ all the visible vertices of this ship, so setting the
                        \ laser vertex to 255 means that if we don't update this
                        \ vertex with its screen coordinates in parts 6 and 7,
                        \ this vertex's entry in the XX3 heap will still be 255,
                        \ which we can check in part 9 to see if the laser
                        \ vertex is visible (and therefore whether we should
                        \ draw laser lines if the ship is firing at us)

 LDA XX1+6              \ Set (A T) = (z_hi z_lo)
 STA T
 LDA XX1+7

 LSR A                  \ Set (A T) = (A T) / 8
 ROR T
 LSR A
 ROR T
 LSR A
 ROR T

 LSR A                  \ If A >> 4 is non-zero, i.e. z_hi >= 16, jump to LL13
 BNE LL13               \ as the ship is possibly far away enough to be shown as
                        \ a dot

 LDA T                  \ Otherwise the C flag contains the previous bit 0 of A,
 ROR A                  \ which could have been set, so rotate A right four
 LSR A                  \ times so it's in the form %000xxxxx, i.e. z_hi reduced
 LSR A                  \ to a maximum value of 31
 LSR A

 STA XX4                \ Store A in XX4, which is now the distance of the ship
                        \ we can use for visibility testing

 BPL LL17               \ Jump down to LL17 (this BPL is effectively a JMP as we
                        \ know bit 7 of A is definitely clear)

.LL13

                        \ If we get here then the ship is possibly far enough
                        \ away to be shown as a dot

 LDY #13                \ Fetch byte #13 from the ship's blueprint, which gives
 LDA (XX0),Y            \ the ship's visibility distance, beyond which we show
                        \ the ship as a dot

 CMP XX1+7              \ If z_hi <= the visibility distance, skip to LL17 to
 BCS LL17               \ draw the ship fully, rather than as a dot, as it is
                        \ closer than the visibility distance

 LDA #%00100000         \ If bit 5 of the ship's byte #31 is set, then the
 AND XX1+31             \ ship is currently exploding, so skip to LL17 to draw
 BNE LL17               \ the ship's explosion cloud

 JMP SHPPT              \ Otherwise jump to SHPPT to draw the ship as a dot,
                        \ returning from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: LL9 (Part 3 of 12)
\       Type: Subroutine
\   Category: Drawing ships
\    Summary: Draw ship: Set up orientation vector, ship coordinate variables
\  Deep dive: Drawing ships
\
\ ------------------------------------------------------------------------------
\
\ This part sets up the following variable blocks:
\
\   * XX16 contains the orientation vectors, divided to normalise them
\
\   * XX18 contains the ship's x, y and z coordinates in space
\
\ ******************************************************************************

.LL17

 LDX #5                 \ First we copy the three orientation vectors into XX16,
                        \ so set up a counter in X for the 6 bytes in each
                        \ vector

.LL15

 LDA XX1+21,X           \ Copy the X-th byte of sidev to the X-th byte of XX16
 STA XX16,X

 LDA XX1+15,X           \ Copy the X-th byte of roofv to XX16+6 to the X-th byte
 STA XX16+6,X           \ of XX16+6

 LDA XX1+9,X            \ Copy the X-th byte of nosev to XX16+12 to the X-th
 STA XX16+12,X          \ byte of XX16+12

 DEX                    \ Decrement the counter

 BPL LL15               \ Loop back to copy the next byte of each vector, until
                        \ we have the following:
                        \
                        \   * XX16(1 0) = sidev_x
                        \   * XX16(3 2) = sidev_y
                        \   * XX16(5 4) = sidev_z
                        \
                        \   * XX16(7 6) = roofv_x
                        \   * XX16(9 8) = roofv_y
                        \   * XX16(11 10) = roofv_z
                        \
                        \   * XX16(13 12) = nosev_x
                        \   * XX16(15 14) = nosev_y
                        \   * XX16(17 16) = nosev_z

 LDA #197               \ Set Q = 197
 STA Q

 LDY #16                \ Set Y to be a counter that counts down by 2 each time,
                        \ starting with 16, then 14, 12 and so on. We use this
                        \ to work through each of the coordinates in each of the
                        \ orientation vectors

.LL21

 LDA XX16,Y             \ Set A = the low byte of the vector coordinate, e.g.
                        \ nosev_z_lo when Y = 16

 ASL A                  \ Shift bit 7 into the C flag

 LDA XX16+1,Y           \ Set A = the high byte of the vector coordinate, e.g.
                        \ nosev_z_hi when Y = 16

 ROL A                  \ Rotate A left, incorporating the C flag, so A now
                        \ contains the original high byte, doubled, and without
                        \ a sign bit, e.g. A = |nosev_z_hi| * 2

 JSR LL28               \ Call LL28 to calculate:
                        \
                        \   R = 256 * A / Q
                        \
                        \ so, for nosev, this would be:
                        \
                        \   R = 256 * |nosev_z_hi| * 2 / 197
                        \     = 2.6 * |nosev_z_hi|

 LDX R                  \ Store R in the low byte's location, so we can keep the
 STX XX16,Y             \ old, unscaled high byte intact for the sign

 DEY                    \ Decrement the loop counter twice
 DEY

 BPL LL21               \ Loop back for the next vector coordinate until we have
                        \ divided them all

                        \ By this point, the vectors have been turned into
                        \ scaled magnitudes, so we have the following:
                        \
                        \   * XX16   = scaled |sidev_x|
                        \   * XX16+2 = scaled |sidev_y|
                        \   * XX16+4 = scaled |sidev_z|
                        \
                        \   * XX16+6  = scaled |roofv_x|
                        \   * XX16+8  = scaled |roofv_y|
                        \   * XX16+10 = scaled |roofv_z|
                        \
                        \   * XX16+12 = scaled |nosev_x|
                        \   * XX16+14 = scaled |nosev_y|
                        \   * XX16+16 = scaled |nosev_z|

 LDX #8                 \ Next we copy the ship's coordinates into XX18, so set
                        \ up a counter in X for 9 bytes

.ll91

 LDA XX1,X              \ Copy the X-th byte from XX1 to XX18
 STA XX18,X

 DEX                    \ Decrement the loop counter

 BPL ll91               \ Loop back for the next byte until we have copied all
                        \ three coordinates

                        \ So we now have the following:
                        \
                        \   * XX18(2 1 0) = (x_sign x_hi x_lo)
                        \
                        \   * XX18(5 4 3) = (y_sign y_hi y_lo)
                        \
                        \   * XX18(8 7 6) = (z_sign z_hi z_lo)

 LDA #255               \ Set the 15th byte of XX2 to 255, so that face 15 is
 STA XX2+15             \ always visible. No ship definitions actually have this
                        \ number of faces, but this allows us to force a vertex
                        \ to always be visible by associating it with face 15
                        \ (see the ship blueprints for the Cobra Mk III at
                        \ SHIP_COBRA_MK_3 and the asteroid at SHIP_ASTEROID for
                        \ examples of vertices that are associated with face 15)

 LDY #12                \ Set Y = 12 to point to the ship blueprint byte #12,

 LDA XX1+31             \ If bit 5 of the ship's byte #31 is clear, then the
 AND #%00100000         \ ship is not currently exploding, so jump down to EE29
 BEQ EE29               \ to skip the following

                        \ Otherwise we fall through to set up the visibility
                        \ block for an exploding ship

\ ******************************************************************************
\
\       Name: LL9 (Part 4 of 12)
\       Type: Subroutine
\   Category: Drawing ships
\    Summary: Draw ship: Set visibility for exploding ship (all faces visible)
\  Deep dive: Drawing ships
\
\ ------------------------------------------------------------------------------
\
\ This part sets up the visibility block in XX2 for a ship that is exploding.
\
\ The XX2 block consists of one byte for each face in the ship's blueprint,
\ which holds the visibility of that face. Because the ship is exploding, we
\ want to set all the faces to be visible. A value of 255 in the visibility
\ table means the face is visible, so the following code sets each face to 255
\ and then skips over the face visibility calculations that we would apply to a
\ non-exploding ship.
\
\ ******************************************************************************

 LDA (XX0),Y            \ Fetch byte #12 of the ship's blueprint, which contains
                        \ the number of faces * 4

 LSR A                  \ Set X = A / 4
 LSR A                  \       = the number of faces
 TAX

 LDA #255               \ Set A = 255

.EE30

 STA XX2,X              \ Set the X-th byte of XX2 to 255

 DEX                    \ Decrement the loop counter

 BPL EE30               \ Loop back for the next byte until there is one byte
                        \ set to 255 for each face

 INX                    \ Set XX4 = 0 for the distance value we use to test
 STX XX4                \ for visibility, so we always shows everything

.LL41

 JMP LL42               \ Jump to LL42 to skip the face visibility calculations
                        \ as we don't need to do them now we've set up the XX2
                        \ block for the explosion

\ ******************************************************************************
\
\       Name: LL9 (Part 5 of 12)
\       Type: Subroutine
\   Category: Drawing ships
\    Summary: Draw ship: Calculate the visibility of each of the ship's faces
\  Deep dive: Drawing ships
\             Back-face culling
\
\ ******************************************************************************

.EE29

 LDA (XX0),Y            \ We set Y to 12 above before jumping down to EE29, so
                        \ this fetches byte #12 of the ship's blueprint, which
                        \ contains the number of faces * 4

 BEQ LL41               \ If there are no faces in this ship, jump to LL42 (via
                        \ LL41) to skip the face visibility calculations

 STA XX20               \ Set A = the number of faces * 4

 LDY #18                \ Fetch byte #18 of the ship's blueprint, which contains
 LDA (XX0),Y            \ the factor by which we scale the face normals, into X
 TAX

 LDA XX18+7             \ Set A = z_hi

.LL90

 TAY                    \ Set Y = z_hi

 BEQ LL91               \ If z_hi = 0 then jump to LL91

                        \ The following is a loop that jumps back to LL90+3,
                        \ i.e. here. LL90 is only used for this loop, so it's a
                        \ bit of a strange use of the label here

 INX                    \ Increment the scale factor in X

 LSR XX18+4             \ Divide (y_hi y_lo) by 2
 ROR XX18+3

 LSR XX18+1             \ Divide (x_hi x_lo) by 2
 ROR XX18

 LSR A                  \ Divide (z_hi z_lo) by 2 (as A contains z_hi)
 ROR XX18+6

 TAY                    \ Set Y = z_hi

 BNE LL90+3             \ If Y is non-zero, loop back to LL90+3 to divide the
                        \ three coordinates until z_hi is 0

.LL91

                        \ By this point z_hi is 0 and X contains the number of
                        \ right shifts we had to do, plus the scale factor from
                        \ the blueprint

 STX XX17               \ Store the updated scale factor in XX17

 LDA XX18+8             \ Set XX15+5 = z_sign
 STA XX15+5

 LDA XX18               \ Set XX15(1 0) = (x_sign x_lo)
 STA XX15
 LDA XX18+2
 STA XX15+1

 LDA XX18+3             \ Set XX15(3 2) = (y_sign y_lo)
 STA XX15+2
 LDA XX18+5
 STA XX15+3

 LDA XX18+6             \ Set XX15+4 = z_lo, so now XX15(5 4) = (z_sign z_lo)
 STA XX15+4

 JSR LL51               \ Call LL51 to set XX12 to the dot products of XX15 and
                        \ XX16, which we'll call dot_sidev, dot_roofv and
                        \ dot_nosev:
                        \
                        \   XX12(1 0) = [x y z] . sidev
                        \             = (dot_sidev_sign dot_sidev_lo)
                        \             = dot_sidev
                        \
                        \   XX12(3 2) = [x y z] . roofv
                        \             = (dot_roofv_sign dot_roofv_lo)
                        \             = dot_roofv
                        \
                        \   XX12(5 4) = [x y z] . nosev
                        \             = (dot_nosev_sign dot_nosev_lo)
                        \             = dot_nosev

 LDA XX12               \ Set XX18(2 0) = dot_sidev
 STA XX18
 LDA XX12+1
 STA XX18+2

 LDA XX12+2             \ Set XX18(5 3) = dot_roofv
 STA XX18+3
 LDA XX12+3
 STA XX18+5

 LDA XX12+4             \ Set XX18(8 6) = dot_nosev
 STA XX18+6
 LDA XX12+5
 STA XX18+8

 LDY #4                 \ Fetch byte #4 of the ship's blueprint, which contains
 LDA (XX0),Y            \ the low byte of the offset to the faces data

 CLC                    \ Set V = low byte faces offset + XX0
 ADC XX0
 STA V

 LDY #17                \ Fetch byte #17 of the ship's blueprint, which contains
 LDA (XX0),Y            \ the high byte of the offset to the faces data

 ADC XX0+1              \ Set V+1 = high byte faces offset + XX0+1
 STA V+1                \
                        \ So V(1 0) now points to the start of the faces data
                        \ for this ship

 LDY #0                 \ We're now going to loop through all the faces for this
                        \ ship, so set a counter in Y, starting from 0, which we
                        \ will increment by 4 each loop to step through the
                        \ four bytes of data for each face

.LL86

 LDA (V),Y              \ Fetch byte #0 for this face into A, so:
                        \
                        \   A = %xyz vvvvv, where:
                        \
                        \     * Bits 0-4 = visibility distance, beyond which the
                        \       face is always shown
                        \
                        \     * Bits 7-5 = the sign bits of normal_x, normal_y
                        \       and normal_z

 STA XX12+1             \ Store byte #0 in XX12+1, so XX12+1 now has the sign of
                        \ normal_x

 AND #%00011111         \ Extract bits 0-4 to give the visibility distance

 CMP XX4                \ If XX4 <= the visibility distance, where XX4 contains
 BCS LL87               \ the ship's z-distance reduced to 0-31 (which we set in
                        \ part 2), skip to LL87 as this face is close enough
                        \ that we have to test its visibility using the face
                        \ normals

                        \ Otherwise this face is within range and is therefore
                        \ always shown

 TYA                    \ Set X = Y / 4
 LSR A                  \       = the number of this face * 4 /4
 LSR A                  \       = the number of this face
 TAX

 LDA #255               \ Set the X-th byte of XX2 to 255 to denote that this
 STA XX2,X              \ face is visible

 TYA                    \ Set Y = Y + 4 to point to the next face
 ADC #4
 TAY

 JMP LL88               \ Jump down to LL88 to skip the following, as we don't
                        \ need to test the face normals

.LL87

 LDA XX12+1             \ Fetch byte #0 for this face into A

 ASL A                  \ Shift A left and store it, so XX12+3 now has the sign
 STA XX12+3             \ of normal_y

 ASL A                  \ Shift A left and store it, so XX12+5 now has the sign
 STA XX12+5             \ of normal_z

 INY                    \ Increment Y to point to byte #1

 LDA (V),Y              \ Fetch byte #1 for this face and store in XX12, so
 STA XX12               \ XX12 = normal_x

 INY                    \ Increment Y to point to byte #2

 LDA (V),Y              \ Fetch byte #2 for this face and store in XX12+2, so
 STA XX12+2             \ XX12+2 = normal_y

 INY                    \ Increment Y to point to byte #3

 LDA (V),Y              \ Fetch byte #3 for this face and store in XX12+4, so
 STA XX12+4             \ XX12+4 = normal_z

                        \ So we now have:
                        \
                        \   XX12(1 0) = (normal_x_sign normal_x)
                        \
                        \   XX12(3 2) = (normal_y_sign normal_y)
                        \
                        \   XX12(5 4) = (normal_z_sign normal_z)

 LDX XX17               \ If XX17 < 4 then jump to LL92, otherwise we stored a
 CPX #4                 \ larger scale factor above
 BCC LL92

.LL143

 LDA XX18               \ Set XX15(1 0) = XX18(2 0)
 STA XX15               \               = dot_sidev
 LDA XX18+2
 STA XX15+1

 LDA XX18+3             \ Set XX15(3 2) = XX18(5 3)
 STA XX15+2             \               = dot_roofv
 LDA XX18+5
 STA XX15+3

 LDA XX18+6             \ Set XX15(5 4) = XX18(8 6)
 STA XX15+4             \               = dot_nosev
 LDA XX18+8
 STA XX15+5

 JMP LL89               \ Jump down to LL89

.ovflw

                        \ If we get here then the addition below overflowed, so
                        \ we halve the dot products and normal vector

 LSR XX18               \ Divide dot_sidev_lo by 2, so dot_sidev = dot_sidev / 2

 LSR XX18+6             \ Divide dot_nosev_lo by 2, so dot_nosev = dot_nosev / 2

 LSR XX18+3             \ Divide dot_roofv_lo by 2, so dot_roofv = dot_roofv / 2

 LDX #1                 \ Set X = 1 so when we fall through into LL92, we divide
                        \ the normal vector by 2 as well

.LL92

                        \ We jump here from above with the scale factor in X,
                        \ and now we apply it by scaling the normal vector down
                        \ by a factor of 2^X (i.e. divide by 2^X)

 LDA XX12               \ Set XX15 = normal_x
 STA XX15

 LDA XX12+2             \ Set XX15+2 = normal_y
 STA XX15+2

 LDA XX12+4             \ Set A = normal_z

.LL93

 DEX                    \ Decrement the scale factor in X

 BMI LL94               \ If X was 0 before the decrement, there is no scaling
                        \ to do, so jump to LL94 to exit the loop

 LSR XX15               \ Set XX15 = XX15 / 2
                        \          = normal_x / 2

 LSR XX15+2             \ Set XX15+2 = XX15+2 / 2
                        \            = normal_y / 2

 LSR A                  \ Set A = A / 2
                        \       = normal_z / 2

 DEX                    \ Decrement the scale factor in X

 BPL LL93+3             \ If we have more scaling to do, loop back up to the
                        \ first LSR above until the normal vector is scaled down

.LL94

 STA R                  \ Set R = normal_z

 LDA XX12+5             \ Set S = normal_z_sign
 STA S

 LDA XX18+6             \ Set Q = dot_nosev_lo
 STA Q

 LDA XX18+8             \ Set A = dot_nosev_sign

 JSR LL38               \ Set (S A) = (S R) + (A Q)
                        \           = normal_z + dot_nosev
                        \
                        \ setting the sign of the result in S

 BCS ovflw              \ If the addition overflowed, jump up to ovflw to divide
                        \ both the normal vector and dot products by 2 and try
                        \ again

 STA XX15+4             \ Set XX15(5 4) = (S A)
 LDA S                  \               = normal_z + dot_nosev
 STA XX15+5

 LDA XX15               \ Set R = normal_x
 STA R

 LDA XX12+1             \ Set S = normal_x_sign
 STA S

 LDA XX18               \ Set Q = dot_sidev_lo
 STA Q

 LDA XX18+2             \ Set A = dot_sidev_sign

 JSR LL38               \ Set (S A) = (S R) + (A Q)
                        \           = normal_x + dot_sidev
                        \
                        \ setting the sign of the result in S

 BCS ovflw              \ If the addition overflowed, jump up to ovflw to divide
                        \ both the normal vector and dot products by 2 and try
                        \ again

 STA XX15               \ Set XX15(1 0) = (S A)
 LDA S                  \               = normal_x + dot_sidev
 STA XX15+1

 LDA XX15+2             \ Set R = normal_y
 STA R

 LDA XX12+3             \ Set S = normal_y_sign
 STA S

 LDA XX18+3             \ Set Q = dot_roofv_lo
 STA Q

 LDA XX18+5             \ Set A = dot_roofv_sign

 JSR LL38               \ Set (S A) = (S R) + (A Q)
                        \           = normal_y + dot_roofv

 BCS ovflw              \ If the addition overflowed, jump up to ovflw to divide
                        \ both the normal vector and dot products by 2 and try
                        \ again

 STA XX15+2             \ Set XX15(3 2) = (S A)
 LDA S                  \               = normal_y + dot_roofv
 STA XX15+3

.LL89

                        \ When we get here, we have set up the following:
                        \
                        \   XX15(1 0) = normal_x + dot_sidev
                        \             = normal_x + [x y z] . sidev
                        \
                        \   XX15(3 2) = normal_y + dot_roofv
                        \             = normal_y + [x y z] . roofv
                        \
                        \   XX15(5 4) = normal_z + dot_nosev
                        \             = normal_z + [x y z] . nosev
                        \
                        \ and:
                        \
                        \   XX12(1 0) = (normal_x_sign normal_x)
                        \
                        \   XX12(3 2) = (normal_y_sign normal_y)
                        \
                        \   XX12(5 4) = (normal_z_sign normal_z)
                        \
                        \ We now calculate the dot product XX12 . XX15 to tell
                        \ us whether or not this face is visible

 LDA XX12               \ Set Q = XX12
 STA Q

 LDA XX15               \ Set A = XX15

 JSR FMLTU              \ Set T = A * Q / 256
 STA T                  \       = XX15 * XX12 / 256

 LDA XX12+1             \ Set S = sign of XX15(1 0) * XX12(1 0), so:
 EOR XX15+1             \
 STA S                  \   (S T) = XX15(1 0) * XX12(1 0) / 256

 LDA XX12+2             \ Set Q = XX12+2
 STA Q

 LDA XX15+2             \ Set A = XX15+2

 JSR FMLTU              \ Set Q = A * Q
 STA Q                  \       = XX15+2 * XX12+2 / 256

 LDA T                  \ Set T = R, so now:
 STA R                  \
                        \   (S R) = XX15(1 0) * XX12(1 0) / 256

 LDA XX12+3             \ Set A = sign of XX15+3 * XX12+3, so:
 EOR XX15+3             \
                        \   (A Q) = XX15(3 2) * XX12(3 2) / 256

 JSR LL38               \ Set (S T) = (S R) + (A Q)
 STA T                  \           =   XX15(1 0) * XX12(1 0) / 256
                        \             + XX15(3 2) * XX12(3 2) / 256

 LDA XX12+4             \ Set Q = XX12+4
 STA Q

 LDA XX15+4             \ Set A = XX15+4

 JSR FMLTU              \ Set Q = A * Q
 STA Q                  \       = XX15+4 * XX12+4 / 256

 LDA T                  \ Set T = R, so now:
 STA R                  \
                        \   (S R) =   XX15(1 0) * XX12(1 0) / 256
                        \           + XX15(3 2) * XX12(3 2) / 256

 LDA XX15+5             \ Set A = sign of XX15+5 * XX12+5, so:
 EOR XX12+5             \
                        \   (A Q) = XX15(5 4) * XX12(5 4) / 256

 JSR LL38               \ Set (S A) = (S R) + (A Q)
                        \           =   XX15(1 0) * XX12(1 0) / 256
                        \             + XX15(3 2) * XX12(3 2) / 256
                        \             + XX15(5 4) * XX12(5 4) / 256

 PHA                    \ Push the result A onto the stack, so the stack now
                        \ contains the dot product XX12 . XX15

 TYA                    \ Set X = Y / 4
 LSR A                  \       = the number of this face * 4 /4
 LSR A                  \       = the number of this face
 TAX

 PLA                    \ Pull the dot product off the stack into A

 BIT S                  \ If bit 7 of S is set, i.e. the dot product is
 BMI P%+4               \ negative, then this face is visible as its normal is
                        \ pointing towards us, so skip the following instruction

 LDA #0                 \ Otherwise the face is not visible, so set A = 0 so we
                        \ can store this to mean "not visible"

 STA XX2,X              \ Store the face's visibility in the X-th byte of XX2

 INY                    \ Above we incremented Y to point to byte #3, so this
                        \ increments Y to point to byte #4, i.e. byte #0 of the
                        \ next face

.LL88

 CPY XX20               \ If Y >= XX20, the number of faces * 4, jump down to
 BCS LL42               \ LL42 to move on to the

 JMP LL86               \ Otherwise loop back to LL86 to work out the visibility
                        \ of the next face

\ ******************************************************************************
\
\       Name: LL9 (Part 6 of 12)
\       Type: Subroutine
\   Category: Drawing ships
\    Summary: Draw ship: Calculate the visibility of each of the ship's vertices
\  Deep dive: Drawing ships
\             Calculating vertex coordinates
\
\ ------------------------------------------------------------------------------
\
\ This section calculates the visibility of each of the ship's vertices, and for
\ those that are visible, it starts the process of calculating the screen
\ coordinates of each vertex
\
\ ******************************************************************************

.LL42

                        \ The first task is to set up the inverse matrix, ready
                        \ for us to send to the dot product routine at LL51.
                        \ Back up in part 3, we set up the following variables:
                        \
                        \   * XX16(1 0) = sidev_x
                        \   * XX16(3 2) = sidev_y
                        \   * XX16(5 4) = sidev_z
                        \
                        \   * XX16(7 6) = roofv_x
                        \   * XX16(9 8) = roofv_y
                        \   * XX16(11 10) = roofv_z
                        \
                        \   * XX16(13 12) = nosev_x
                        \   * XX16(15 14) = nosev_y
                        \   * XX16(17 16) = nosev_z
                        \
                        \ and we then scaled the vectors to give the following:
                        \
                        \   * XX16   = scaled |sidev_x|
                        \   * XX16+2 = scaled |sidev_y|
                        \   * XX16+4 = scaled |sidev_z|
                        \
                        \   * XX16+6  = scaled |roofv_x|
                        \   * XX16+8  = scaled |roofv_y|
                        \   * XX16+10 = scaled |roofv_z|
                        \
                        \   * XX16+12 = scaled |nosev_x|
                        \   * XX16+14 = scaled |nosev_y|
                        \   * XX16+16 = scaled |nosev_z|
                        \
                        \ We now need to rearrange these locations so they
                        \ effectively transpose the matrix into its inverse

 LDY XX16+2             \ Set XX16+2 = XX16+6 = scaled |roofv_x|
 LDX XX16+3             \ Set XX16+3 = XX16+7 = roofv_x_hi
 LDA XX16+6             \ Set XX16+6 = XX16+2 = scaled |sidev_y|
 STA XX16+2             \ Set XX16+7 = XX16+3 = sidev_y_hi
 LDA XX16+7
 STA XX16+3
 STY XX16+6
 STX XX16+7

 LDY XX16+4             \ Set XX16+4 = XX16+12 = scaled |nosev_x|
 LDX XX16+5             \ Set XX16+5 = XX16+13 = nosev_x_hi
 LDA XX16+12            \ Set XX16+12 = XX16+4 = scaled |sidev_z|
 STA XX16+4             \ Set XX16+13 = XX16+5 = sidev_z_hi
 LDA XX16+13
 STA XX16+5
 STY XX16+12
 STX XX16+13

 LDY XX16+10            \ Set XX16+10 = XX16+14 = scaled |nosev_y|
 LDX XX16+11            \ Set XX16+11 = XX16+15 = nosev_y_hi
 LDA XX16+14            \ Set XX16+14 = XX16+10 = scaled |roofv_z|
 STA XX16+10            \ Set XX16+15 = XX16+11 = roofv_z
 LDA XX16+15
 STA XX16+11
 STY XX16+14
 STX XX16+15

                        \ So now we have the following sign-magnitude variables
                        \ containing parts of the scaled orientation vectors:
                        \
                        \   XX16(1 0)   = scaled sidev_x
                        \   XX16(3 2)   = scaled roofv_x
                        \   XX16(5 4)   = scaled nosev_x
                        \
                        \   XX16(7 6)   = scaled sidev_y
                        \   XX16(9 8)   = scaled roofv_y
                        \   XX16(11 10) = scaled nosev_y
                        \
                        \   XX16(13 12) = scaled sidev_z
                        \   XX16(15 14) = scaled roofv_z
                        \   XX16(17 16) = scaled nosev_z
                        \
                        \ which is what we want, as the various vectors are now
                        \ arranged so we can use LL51 to multiply by the
                        \ transpose (i.e. the inverse of the matrix)

 LDY #8                 \ Fetch byte #8 of the ship's blueprint, which is the
 LDA (XX0),Y            \ number of vertices * 8, and store it in XX20
 STA XX20

                        \ We now set V(1 0) = XX0(1 0) + 20, so V(1 0) points
                        \ to byte #20 of the ship's blueprint, which is always
                        \ where the vertex data starts (i.e. just after the 20
                        \ byte block that define the ship's characteristics)

 LDA XX0                \ We start with the low bytes
 CLC
 ADC #20
 STA V

 LDA XX0+1              \ And then do the high bytes
 ADC #0
 STA V+1

 LDY #0                 \ We are about to step through all the vertices, using
                        \ Y as a counter. There are six data bytes for each
                        \ vertex, so we will increment Y by 6 for each iteration
                        \ so it can act as an offset from V(1 0) to the current
                        \ vertex's data

 STY CNT                \ Set CNT = 0, which we will use as a pointer to the
                        \ heap at XX3, starting it at zero so the heap starts
                        \ out empty

.LL48

 STY XX17               \ Set XX17 = Y, so XX17 now contains the offset of the
                        \ current vertex's data

 LDA (V),Y              \ Fetch byte #0 for this vertex into XX15, so:
 STA XX15               \
                        \   XX15 = magnitude of the vertex's x-coordinate

 INY                    \ Increment Y to point to byte #1

 LDA (V),Y              \ Fetch byte #1 for this vertex into XX15+2, so:
 STA XX15+2             \
                        \   XX15+2 = magnitude of the vertex's y-coordinate

 INY                    \ Increment Y to point to byte #2

 LDA (V),Y              \ Fetch byte #2 for this vertex into XX15+4, so:
 STA XX15+4             \
                        \   XX15+4 = magnitude of the vertex's z-coordinate

 INY                    \ Increment Y to point to byte #3

 LDA (V),Y              \ Fetch byte #3 for this vertex into T, so:
 STA T                  \
                        \   T = %xyz vvvvv, where:
                        \
                        \     * Bits 0-4 = visibility distance, beyond which the
                        \                  vertex is not shown
                        \
                        \     * Bits 7-5 = the sign bits of x, y and z

 AND #%00011111         \ Extract bits 0-4 to get the visibility distance

 CMP XX4                \ If XX4 > the visibility distance, where XX4 contains
 BCC LL49-3             \ the ship's z-distance reduced to 0-31 (which we set in
                        \ part 2), then this vertex is too far away to be
                        \ visible, so jump down to LL50 (via the JMP instruction
                        \ in LL49-3) to move on to the next vertex

 INY                    \ Increment Y to point to byte #4

 LDA (V),Y              \ Fetch byte #4 for this vertex into P, so:
 STA P                  \
                        \  P = %ffff ffff, where:
                        \
                        \    * Bits 0-3 = the number of face 1
                        \
                        \    * Bits 4-7 = the number of face 2

 AND #%00001111         \ Extract the number of face 1 into X
 TAX

 LDA XX2,X              \ If XX2+X is non-zero then we decided in part 5 that
 BNE LL49               \ face 1 is visible, so jump to LL49

 LDA P                  \ Fetch byte #4 for this vertex into A

 LSR A                  \ Shift right four times to extract the number of face 2
 LSR A                  \ from bits 4-7 into X
 LSR A
 LSR A
 TAX

 LDA XX2,X              \ If XX2+X is non-zero then we decided in part 5 that
 BNE LL49               \ face 2 is visible, so jump to LL49

 INY                    \ Increment Y to point to byte #5

 LDA (V),Y              \ Fetch byte #5 for this vertex into P, so:
 STA P                  \
                        \  P = %ffff ffff, where:
                        \
                        \    * Bits 0-3 = the number of face 3
                        \
                        \    * Bits 4-7 = the number of face 4

 AND #%00001111         \ Extract the number of face 1 into X
 TAX

 LDA XX2,X              \ If XX2+X is non-zero then we decided in part 5 that
 BNE LL49               \ face 3 is visible, so jump to LL49

 LDA P                  \ Fetch byte #5 for this vertex into A

 LSR A                  \ Shift right four times to extract the number of face 4
 LSR A                  \ from bits 4-7 into X
 LSR A
 LSR A
 TAX

 LDA XX2,X              \ If XX2+X is non-zero then we decided in part 5 that
 BNE LL49               \ face 4 is visible, so jump to LL49

 JMP LL50               \ If we get here then none of the four faces associated
                        \ with this vertex are visible, so this vertex is also
                        \ not visible, so jump to LL50 to move on to the next
                        \ vertex

.LL49

 LDA T                  \ Fetch byte #5 for this vertex into A and store it, so
 STA XX15+1             \ XX15+1 now has the sign of the vertex's x-coordinate

 ASL A                  \ Shift A left and store it, so XX15+3 now has the sign
 STA XX15+3             \ of the vertex's y-coordinate

 ASL A                  \ Shift A left and store it, so XX15+5 now has the sign
 STA XX15+5             \ of the vertex's z-coordinate

                        \ By this point we have the following:
                        \
                        \   XX15(1 0) = vertex x-coordinate
                        \   XX15(3 2) = vertex y-coordinate
                        \   XX15(5 4) = vertex z-coordinate
                        \
                        \   XX16(1 0)   = scaled sidev_x
                        \   XX16(3 2)   = scaled roofv_x
                        \   XX16(5 4)   = scaled nosev_x
                        \
                        \   XX16(7 6)   = scaled sidev_y
                        \   XX16(9 8)   = scaled roofv_y
                        \   XX16(11 10) = scaled nosev_y
                        \
                        \   XX16(13 12) = scaled sidev_z
                        \   XX16(15 14) = scaled roofv_z
                        \   XX16(17 16) = scaled nosev_z

 JSR LL51               \ Call LL51 to set XX12 to the dot products of XX15 and
                        \ XX16, as follows:
                        \
                        \   XX12(1 0) = [ x y z ] . [ sidev_x roofv_x nosev_x ]
                        \
                        \   XX12(3 2) = [ x y z ] . [ sidev_y roofv_y nosev_y ]
                        \
                        \   XX12(5 4) = [ x y z ] . [ sidev_z roofv_z nosev_z ]
                        \
                        \ XX12 contains the vector from the ship's centre to
                        \ the vertex, transformed from the orientation vector
                        \ space to the universe orientated around our ship. So
                        \ we can refer to this vector below, let's call it
                        \ vertv, so:
                        \
                        \   vertv_x = [ x y z ] . [ sidev_x roofv_x nosev_x ]
                        \
                        \   vertv_y = [ x y z ] . [ sidev_y roofv_y nosev_y ]
                        \
                        \   vertv_z = [ x y z ] . [ sidev_z roofv_z nosev_z ]
                        \
                        \ To finish the calculation, we now want to calculate:
                        \
                        \   vertv + [ x y z ]
                        \
                        \ So let's start with the vertv_x + x

 LDA XX1+2              \ Set A = x_sign of the ship's location

 STA XX15+2             \ Set XX15+2 = x_sign

 EOR XX12+1             \ If the sign of x_sign * the sign of vertv_x is
 BMI LL52               \ negative (i.e. they have different signs), skip to
                        \ LL52

 CLC                    \ Set XX15(2 1 0) = XX1(2 1 0) + XX12(1 0)
 LDA XX12               \                 = (x_sign x_hi x_lo) + vertv_x
 ADC XX1                \
 STA XX15               \ Starting with the low bytes

 LDA XX1+1              \ And then doing the high bytes (we can add 0 here as
 ADC #0                 \ we know the sign byte of vertv_x is 0)
 STA XX15+1

 JMP LL53               \ We've added the x-coordinates, so jump to LL53 to do
                        \ the y-coordinates

.LL52

                        \ If we get here then x_sign and vertv_x have different
                        \ signs, so we need to subtract them to get the result

 LDA XX1                \ Set XX15(2 1 0) = XX1(2 1 0) - XX12(1 0)
 SEC                    \                 = (x_sign x_hi x_lo) - vertv_x
 SBC XX12               \
 STA XX15               \ Starting with the low bytes

 LDA XX1+1              \ And then doing the high bytes (we can subtract 0 here
 SBC #0                 \ as we know the sign byte of vertv_x is 0)
 STA XX15+1

 BCS LL53               \ If the subtraction didn't underflow, then the sign of
                        \ the result is the same sign as x_sign, and that's what
                        \ we want, so we can jump down to LL53 to do the
                        \ y-coordinates

 EOR #%11111111         \ Otherwise we need to negate the result using two's
 STA XX15+1             \ complement, so first we flip the bits of the high byte

 LDA #1                 \ And then subtract the low byte from 1
 SBC XX15
 STA XX15

 BCC P%+4               \ If the above subtraction underflowed then we need to
 INC XX15+1             \ bump the high byte of the result up by 1

 LDA XX15+2             \ And now we flip the sign of the result to get the
 EOR #%10000000         \ correct result
 STA XX15+2

.LL53

                        \ Now for the y-coordinates, vertv_y + y

 LDA XX1+5              \ Set A = y_sign of the ship's location

 STA XX15+5             \ Set XX15+5 = y_sign

 EOR XX12+3             \ If the sign of y_sign * the sign of vertv_y is
 BMI LL54               \ negative (i.e. they have different signs), skip to
                        \ LL54

 CLC                    \ Set XX15(5 4 3) = XX1(5 4 3) + XX12(3 2)
 LDA XX12+2             \                 = (y_sign y_hi y_lo) + vertv_y
 ADC XX1+3              \
 STA XX15+3             \ Starting with the low bytes

 LDA XX1+4              \ And then doing the high bytes (we can add 0 here as
 ADC #0                 \ we know the sign byte of vertv_y is 0)
 STA XX15+4

 JMP LL55               \ We've added the y-coordinates, so jump to LL55 to do
                        \ the z-coordinates

.LL54

                        \ If we get here then y_sign and vertv_y have different
                        \ signs, so we need to subtract them to get the result

 LDA XX1+3              \ Set XX15(5 4 3) = XX1(5 4 3) - XX12(3 2)
 SEC                    \                 = (y_sign y_hi y_lo) - vertv_y
 SBC XX12+2             \
 STA XX15+3             \ Starting with the low bytes

 LDA XX1+4              \ And then doing the high bytes (we can subtract 0 here
 SBC #0                 \ as we know the sign byte of vertv_z is 0)
 STA XX15+4

 BCS LL55               \ If the subtraction didn't underflow, then the sign of
                        \ the result is the same sign as y_sign, and that's what
                        \ we want, so we can jump down to LL55 to do the
                        \ z-coordinates

 EOR #%11111111         \ Otherwise we need to negate the result using two's
 STA XX15+4             \ complement, so first we flip the bits of the high byte

 LDA XX15+3             \ And then flip the bits of the low byte and add 1
 EOR #%11111111
 ADC #1
 STA XX15+3

 LDA XX15+5             \ And now we flip the sign of the result to get the
 EOR #%10000000         \ correct result
 STA XX15+5

 BCC LL55               \ If the above subtraction underflowed then we need to
 INC XX15+4             \ bump the high byte of the result up by 1

.LL55

                        \ Now for the z-coordinates, vertv_z + z

 LDA XX12+5             \ If vertv_z_hi is negative, jump down to LL56
 BMI LL56

 LDA XX12+4             \ Set (U T) = XX1(7 6) + XX12(5 4)
 CLC                    \           = (z_hi z_lo) + vertv_z
 ADC XX1+6              \
 STA T                  \ Starting with the low bytes

 LDA XX1+7              \ And then doing the high bytes (we can add 0 here as
 ADC #0                 \ we know the sign byte of vertv_y is 0)
 STA U

 JMP LL57               \ We've added the z-coordinates, so jump to LL57

                        \ The adding process is continued in part 7, after a
                        \ couple of subroutines that we don't need quite yet

\ ******************************************************************************
\
\       Name: LL61
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (U R) = 256 * A / Q
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following, where A >= Q:
\
\   (U R) = 256 * A / Q
\
\ This is a sister routine to LL28, which does the division when A < Q.
\
\ ******************************************************************************

.LL61

 LDX Q                  \ If Q = 0, jump down to LL84 to return a division
 BEQ LL84               \ error

                        \ The LL28 routine returns A / Q, but only if A < Q. In
                        \ our case A >= Q, but we still want to use the LL28
                        \ routine, so we halve A until it's less than Q, call
                        \ the division routine, and then double A by the same
                        \ number of times

 LDX #0                 \ Set X = 0 to count the number of times we halve A

.LL63

 LSR A                  \ Halve A by shifting right

 INX                    \ Increment X

 CMP Q                  \ If A >= Q, loop back to LL63 to halve it again
 BCS LL63

 STX S                  \ Otherwise store the number of times we halved A in S

 JSR LL28               \ Call LL28 to calculate:
                        \
                        \   R = 256 * A / Q
                        \
                        \ which we can do now as A < Q

 LDX S                  \ Otherwise restore the number of times we halved A
                        \ above into X

 LDA R                  \ Set A = our division result

.LL64

 ASL A                  \ Double (U A) by shifting left
 ROL U

 BMI LL84               \ If bit 7 of U is set, the doubling has overflowed, so
                        \ jump to LL84 to return a division error

 DEX                    \ Decrement X

 BNE LL64               \ If X is not yet zero then we haven't done as many
                        \ doublings as we did halvings earlier, so loop back for
                        \ another doubling

 STA R                  \ Store the low byte of the division result in R

 RTS                    \ Return from the subroutine

.LL84

 LDA #50                \ If we get here then either we tried to divide by 0, or
 STA R                  \ the result overflowed, so we set U and R to 50
 STA U

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: LL62
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate 128 - (U R)
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following for a positive sign-magnitude number (U R):
\
\   128 - (U R)
\
\ and then store the result, low byte then high byte, on the end of the heap at
\ XX3, where X points to the first free byte on the heap. Return by jumping down
\ to LL66.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   X                   X is incremented by 1
\
\ ******************************************************************************

.LL62

 LDA #128               \ Calculate 128 - (U R), starting with the low bytes
 SEC
 SBC R

 STA XX3,X              \ Store the low byte of the result in the X-th byte of
                        \ the heap at XX3

 INX                    \ Increment the heap pointer in X to point to the next
                        \ byte

 LDA #0                 \ And then subtract the high bytes
 SBC U

 STA XX3,X              \ Store the low byte of the result in the X-th byte of
                        \ the heap at XX3

 JMP LL66               \ Jump down to LL66

\ ******************************************************************************
\
\       Name: LL9 (Part 7 of 12)
\       Type: Subroutine
\   Category: Drawing ships
\    Summary: Draw ship: Calculate the visibility of each of the ship's vertices
\  Deep dive: Drawing ships
\             Calculating vertex coordinates
\
\ ------------------------------------------------------------------------------
\
\ This section continues the coordinate adding from part 6 by finishing off the
\ calculation that we started above:
\
\                      [ sidev_x roofv_x nosev_x ]   [ x ]   [ x ]
\   vector to vertex = [ sidev_y roofv_y nosev_y ] . [ y ] + [ y ]
\                      [ sidev_z roofv_z nosev_z ]   [ z ]   [ z ]
\
\ The gets stored as follows, in sign-magnitude values with the magnitudes
\ fitting into the low bytes:
\
\   XX15(2 0)           [ x y z ] . [ sidev_x roofv_x nosev_x ] + [ x y z ]
\
\   XX15(5 3)           [ x y z ] . [ sidev_y roofv_y nosev_y ] + [ x y z ]
\
\   (U T)               [ x y z ] . [ sidev_z roofv_z nosev_z ] + [ x y z ]
\
\ Finally, because this vector is from our ship to the vertex, and we are at the
\ origin, this vector is the same as the coordinates of the vertex. In other
\ words, we have just worked out:
\
\   XX15(2 0)           x-coordinate of the current vertex
\
\   XX15(5 3)           y-coordinate of the current vertex
\
\   (U T)               z-coordinate of the current vertex
\
\ ******************************************************************************

.LL56

 LDA XX1+6              \ Set (U T) = XX1(7 6) - XX12(5 4)
 SEC                    \           = (z_hi z_lo) - vertv_z
 SBC XX12+4             \
 STA T                  \ Starting with the low bytes

 LDA XX1+7              \ And then doing the high bytes (we can subtract 0 here
 SBC #0                 \ as we know the sign byte of vertv_z is 0)
 STA U

 BCC LL140              \ If the subtraction just underflowed, skip to LL140 to
                        \ set (U T) to the minimum value of 4

 BNE LL57A              \ If U is non-zero, jump down to LL57A (A = U already)

 LDA T                  \ If T >= 4, jump down to LL57
 CMP #4
 BCS LL57

.LL140

 LDA #4                 \ If we get here then either (U T) < 4 or the
 STA T                  \ subtraction underflowed, so set (U T) = 4
 STZ U                  \ and fall through into LL57

.LL57

                        \ By this point we have our results, so now to scale
                        \ the 16-bit results down into 8-bit values

 LDA U                  \ If the high bytes of the result are all zero, we are

.LL57A

 ORA XX15+1             \ done, so jump to LL60 for the next stage
 ORA XX15+4
 BEQ LL60

.LL57S

 LSR XX15+1             \ Shift XX15(1 0) to the right
 ROR XX15

 LSR XX15+4             \ Shift XX15(4 3) to the right
 ROR XX15+3

 LSR U                  \ Shift (U T) to the right
 ROR T

 LSR A                  \ Port: A = U OR XX15+1 OR XX15+4 of the shifted values
 BNE LL57S              \ (shifting each right shifts their OR right), so loop
                        \ until the high bytes are all zero, then fall through
                        \ into LL60

\ ******************************************************************************
\
\       Name: LL9 (Part 8 of 12)
\       Type: Subroutine
\   Category: Drawing ships
\    Summary: Draw ship: Calculate the screen coordinates of visible vertices
\  Deep dive: Drawing ships
\
\ ------------------------------------------------------------------------------
\
\ This section projects the coordinate of the vertex into screen coordinates and
\ stores them on the XX3 heap. By the end of this part, the XX3 heap contains
\ four bytes containing the 16-bit screen coordinates of the current vertex, in
\ the order: x_lo, x_hi, y_lo, y_hi.
\
\ When we reach here, we are looping through the vertices, and we've just worked
\ out the coordinates of the vertex in our normal coordinate system, as follows
\
\   XX15(2 0)           (x_sign x_lo) = x-coordinate of the current vertex
\
\   XX15(5 3)           (y_sign y_lo) = y-coordinate of the current vertex
\
\   (U T)               (z_sign z_lo) = z-coordinate of the current vertex
\
\ Note that U is always zero when we get to this point, as the vertex is always
\ in front of us (so it has a positive z-coordinate, into the screen).
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   LL70+1              Contains an RTS (as the first byte of an LDA
\                       instruction)
\
\   LL66                A re-entry point into the ship-drawing routine, used by
\                       the LL62 routine to store 128 - (U R) on the XX3 heap
\
\ ******************************************************************************

.LL60

 LDA T                  \ Set Q = z_lo
 STA Q

 LDA XX15               \ Set A = x_lo

 CMP Q                  \ If x_lo < z_lo jump to LL69
 BCC LL69

 JSR LL61               \ Call LL61 to calculate:
                        \
                        \   (U R) = 256 * A / Q
                        \         = 256 * x / z
                        \
                        \ which we can do as x >= z

 JMP LL69+3             \ Jump over the next instruction to skip the division
                        \ for x_lo < z_lo

.LL69

 JSR LL28               \ Call LL28 to calculate:
                        \
                        \   R = 256 * A / Q
                        \     = 256 * x / z
                        \
                        \ Because x < z, the result fits into one byte, and we
                        \ also know that U = 0, so (U R) also contains the
                        \ result

                        \ At this point we have:
                        \
                        \   (U R) = x / z
                        \
                        \ so (U R) contains the vertex's x-coordinate projected
                        \ on screen
                        \
                        \ The next task is to convert (U R) to a pixel screen
                        \ coordinate and stick it on the XX3 heap.
                        \
                        \ We start with the x-coordinate. To convert the
                        \ x-coordinate to a screen pixel we add 128, the
                        \ x-coordinate of the centre of the screen, because the
                        \ projected value is relative to an origin at the centre
                        \ of the screen, but the origin of the screen pixels is
                        \ at the top-left of the screen

 LDX CNT                \ Fetch the pointer to the end of the XX3 heap from CNT
                        \ into X

 LDA XX15+2             \ If x_sign is negative, jump up to LL62, which will
 BMI LL62               \ store 128 - (U R) on the XX3 heap and return by
                        \ jumping down to LL66 below

 LDA R                  \ Calculate 128 + (U R), starting with the low bytes
 CLC
 ADC #128

 STA XX3,X              \ Store the low byte of the result in the X-th byte of
                        \ the heap at XX3

 INX                    \ Increment the heap pointer in X to point to the next
                        \ byte

 LDA U                  \ And then add the high bytes
 ADC #0

 STA XX3,X              \ Store the high byte of the result in the X-th byte of
                        \ the heap at XX3

.LL66

                        \ We've just stored the screen x-coordinate of the
                        \ vertex on the XX3 heap, so now for the y-coordinate

 TXA                    \ Store the heap pointer in X on the stack (at this
 PHA                    \ it points to the last entry on the heap, not the first
                        \ free byte)

 LDA #0                 \ Set U = 0
 STA U

 LDA T                  \ Set Q = z_lo
 STA Q

 LDA XX15+3             \ Set A = y_lo

 CMP Q                  \ If y_lo < z_lo jump to LL67
 BCC LL67

 JSR LL61               \ Call LL61 to calculate:
                        \
                        \   (U R) = 256 * A / Q
                        \         = 256 * y / z
                        \
                        \ which we can do as y >= z

 JMP LL68               \ Jump to LL68 to skip the division for y_lo < z_lo

.LL70

                        \ This gets called from below when y_sign is negative

 LDA #Y                 \ Calculate #Y + (U R), starting with the low bytes
 CLC
 ADC R

 STA XX3,X              \ Store the low byte of the result in the X-th byte of
                        \ the heap at XX3

 INX                    \ Increment the heap pointer in X to point to the next
                        \ byte

 LDA #0                 \ And then add the high bytes
 ADC U

 STA XX3,X              \ Store the high byte of the result in the X-th byte of
                        \ the heap at XX3

 JMP LL50               \ Jump to LL50 to move on to the next vertex

.LL67

 JSR LL28               \ Call LL28 to calculate:
                        \
                        \   R = 256 * A / Q
                        \     = 256 * y / z
                        \
                        \ Because y < z, the result fits into one byte, and we
                        \ also know that U = 0, so (U R) also contains the
                        \ result

.LL68

                        \ At this point we have:
                        \
                        \   (U R) = y / z
                        \
                        \ so (U R) contains the vertex's y-coordinate projected
                        \ on screen
                        \
                        \ We now want to convert this to a screen y-coordinate
                        \ and stick it on the XX3 heap, much like we did with
                        \ the x-coordinate above. Again, we convert the
                        \ coordinate by adding or subtracting the y-coordinate
                        \ of the centre of the screen, which is in the constant
                        \ #Y, but this time we do the opposite, as a positive
                        \ projected y-coordinate, i.e. up the space y-axis and
                        \ up the screen, converts to a low y-coordinate, which
                        \ is the opposite way round to the x-coordinates

 PLA                    \ Restore the heap pointer from the stack into X
 TAX

 INX                    \ When we stored the heap pointer, it pointed to the
                        \ last entry on the heap, not the first free byte, so we
                        \ increment it so it does point to the next free byte

 LDA XX15+5             \ If y_sign is negative, jump up to LL70, which will
 BMI LL70               \ store #Y + (U R) on the XX3 heap and return by jumping
                        \ down to LL50 below

 LDA #Y                 \ Calculate #Y - (U R), starting with the low bytes
 SEC
 SBC R

 STA XX3,X              \ Store the low byte of the result in the X-th byte of
                        \ the heap at XX3

 INX                    \ Increment the heap pointer in X to point to the next
                        \ byte

 LDA #0                 \ And then subtract the high bytes
 SBC U

 STA XX3,X              \ Store the high byte of the result in the X-th byte of
                        \ the heap at XX3

.LL50

                        \ By the time we get here, the XX3 heap contains four
                        \ bytes containing the screen coordinates of the current
                        \ vertex, in the order: x_lo, x_hi, y_lo, y_hi

 CLC                    \ Set CNT = CNT + 4, so the heap pointer points to the
 LDA CNT                \ next free byte on the heap
 ADC #4
 STA CNT

 LDA XX17               \ Set A to the offset of the current vertex's data,
                        \ which we set in part 6

 ADC #6                 \ Set Y = A + 6, so Y now points to the data for the
 TAY                    \ next vertex

 BCS LL72               \ If the addition just overflowed, meaning we just tried
                        \ to access vertex #43, jump to LL72, as the maximum
                        \ number of vertices allowed is 42

 CMP XX20               \ If Y >= number of vertices * 6 (which we stored in
 BCS LL72               \ XX20 in part 6), jump to LL72, as we have processed
                        \ all the vertices for this ship

 JMP LL48               \ Loop back to LL48 in part 6 to calculate visibility
                        \ and screen coordinates for the next vertex

\ ******************************************************************************
\
\       Name: LL9 (Part 9 of 12)
\       Type: Subroutine
\   Category: Drawing ships
\    Summary: Draw ship: Draw laser beams if the ship is firing its laser at us
\  Deep dive: Drawing ships
\
\ ------------------------------------------------------------------------------
\
\ This part sets things up so we can loop through the edges in the next part. It
\ also adds a line to the ship line heap, if the ship is firing at us.
\
\ When we get here, the heap at XX3 contains all the visible vertex screen
\ coordinates.
\
\ ******************************************************************************

.LL72

 LDA XX1+31             \ If bit 5 of the ship's byte #31 is clear, then the
 AND #%00100000         \ ship is not currently exploding, so jump down to EE31
 BEQ EE31

 LDA XX1+31             \ The ship is exploding, so set bit 3 of the ship's byte
 ORA #%00001000         \ #31 to denote that we are drawing something on-screen
 STA XX1+31             \ for this ship

 JMP DOEXP              \ Jump to DOEXP to display the explosion cloud,
                        \ returning from the subroutine using a tail call

.EE31

 JSR H_EE31             \ Port: in record mode, record the ship for the renderer
                        \ and return from LL9 (gfx-hooks.asm)

 LDY #9                 \ Fetch byte #9 of the ship's blueprint, which is the
 LDA (XX0),Y            \ number of edges, and store it in XX20
 STA XX20

 LDA #%00001000         \ Set bit 3 of A so the next instruction sets bit 3 of
                        \ the ship's byte #31 to denote that we are drawing
                        \ something on-screen for this ship

 ORA XX1+31             \ Apply bit 3 of A to the ship's byte #31, so if there
 STA XX1+31             \ was no ship already on screen, the bit is clear,
                        \ otherwise it is set

 LDY #0                 \ Set XX17 = 0, which we are going to use as a counter
\STY LSNUM              \ for stepping through the ship's edges
 STY XX17               \
                        \ The STY is commented out in the original source

 BIT XX1+31             \ If bit 6 of the ship's byte #31 is clear, then the
 BVC LL170              \ ship is not firing its lasers, so jump to LL170 to
                        \ skip the drawing of laser lines

                        \ The ship is firing its laser at us, so we need to draw
                        \ the laser lines

 LDA XX1+31             \ Clear bit 6 of the ship's byte #31 so the ship doesn't
 AND #%10111111         \ keep firing endlessly
 STA XX1+31

 LDY #6                 \ Fetch byte #6 of the ship's blueprint, which is the
 LDA (XX0),Y            \ number * 4 of the vertex where the ship has its lasers

 TAY                    \ Put the vertex number into Y, where it can act as an
                        \ index into list of vertex screen coordinates we added
                        \ to the XX3 heap

 LDX XX3,Y              \ Fetch the x_lo coordinate of the laser vertex from the
 STX XX15               \ XX3 heap into XX15

 INX                    \ If X = 255 then the laser vertex is not visible, as
 BEQ LL170              \ the value we stored in part 2 wasn't overwritten by
                        \ the vertex calculation in part 6 and 7, so jump to
                        \ LL170 to skip drawing the laser lines

                        \ We now build a laser beam from the ship's laser vertex
                        \ towards our ship, as follows:
                        \
                        \   XX15(1 0) = laser vertex x-coordinate
                        \
                        \   XX15(3 2) = laser vertex y-coordinate
                        \
                        \   XX15(5 4) = x-coordinate of the end of the beam
                        \
                        \   XX12(1 0) = y-coordinate of the end of the beam
                        \
                        \ The end of the laser beam will be positioned to look
                        \ good, rather than being directly aimed at us, as
                        \ otherwise we would only see a flashing point of light
                        \ as they unleashed their attack

 LDX XX3+1,Y            \ Fetch the x_hi coordinate of the laser vertex from the
 STX XX15+1             \ XX3 heap into XX15+1

 INX                    \ If X = 255 then the laser vertex is not visible, as
 BEQ LL170              \ the value we stored in part 2 wasn't overwritten by
                        \ a vertex calculation in part 6 and 7, so jump to LL170
                        \ to skip drawing the laser beam

 LDX XX3+2,Y            \ Fetch the y_lo coordinate of the laser vertex from the
 STX XX15+2             \ XX3 heap into XX15+2

 LDX XX3+3,Y            \ Fetch the y_hi coordinate of the laser vertex from the
 STX XX15+3             \ XX3 heap into XX15+3

 LDA #0                 \ Set XX15(5 4) = 0, so their laser beam fires to the
 STA XX15+4             \ left edge of the screen
 STA XX15+5

 STA XX12+1             \ Set XX12(1 0) = the ship's z_lo coordinate, which will
 LDA XX1+6              \ effectively make the vertical position of the end of
 STA XX12               \ the laser beam move around as the ship moves in space

 LDA XX1+2              \ If the ship's x_sign is positive, skip the next
 BPL P%+4               \ instruction

 DEC XX15+4             \ The ship's x_sign is negative (i.e. it's on the left
                        \ side of the screen), so switch the laser beam so it
                        \ goes to the right edge of the screen by decrementing
                        \ XX15(5 4) to 255

 JSR CLIP               \ Call CLIP to see if the laser beam needs to be
                        \ clipped to fit on-screen, returning the clipped line's
                        \ end-points in (X1, Y1) and (X2, Y2)

 BCS LL170              \ If the C flag is set then the line is not visible on
                        \ screen, so jump to LL170 so we don't store this line
                        \ in the ship line heap

 JSR LSPUT              \ Draw the laser line using flicker-free animation, by
                        \ first drawing the new laser line and then erasing the
                        \ corresponding old line from the screen

\ ******************************************************************************
\
\       Name: LL9 (Part 10 of 12)
\       Type: Subroutine
\   Category: Drawing ships
\    Summary: Draw ship: Calculate the visibility of each of the ship's edges
\             and draw the visible ones using flicker-free animation
\  Deep dive: Drawing ships
\
\ ------------------------------------------------------------------------------
\
\ This part calculates which edges are visible - in other words, which lines we
\ should draw - and clips them to fit on the screen.
\
\ Visible edges are drawn using flicker-free animation, which erases the
\ corresponding edge from the on-screen ship at the same time.
\
\ When we get here, the heap at XX3 contains all the visible vertex screen
\ coordinates.
\
\ ******************************************************************************

.LL170

 LDY #3                 \ Fetch byte #3 of the ship's blueprint, which contains
 CLC                    \ the low byte of the offset to the edges data
 LDA (XX0),Y

 ADC XX0                \ Set V = low byte edges offset + XX0
 STA V

 LDY #16                \ Fetch byte #16 of the ship's blueprint, which contains
 LDA (XX0),Y            \ the high byte of the offset to the edges data

 ADC XX0+1              \ Set V+1 = high byte edges offset + XX0+1
 STA V+1                \
                        \ So V(1 0) now points to the start of the edges data
                        \ for this ship

 LDY #5                 \ Fetch byte #5 of the ship's blueprint, which contains
 LDA (XX0),Y            \ the maximum heap size for plotting the ship (which is
 STA CNT                \ 1 + 4 * the maximum number of visible edges) and store
                        \ it in CNT

.LL75

 LDY #0                 \ Set Y = 0 so we start with byte #0

 LDA (V),Y              \ Fetch byte #0 for this edge, which contains the
                        \ visibility distance for this edge, beyond which the
                        \ edge is not shown

 CMP XX4                \ If XX4 > the visibility distance, where XX4 contains
 BCC LL78               \ the ship's z-distance reduced to 0-31 (which we set in
                        \ part 2), then this edge is too far away to be visible,
                        \ so jump down to LL78 to move on to the next edge

 INY                    \ Increment Y to point to byte #1

 LDA (V),Y              \ Fetch byte #1 for this edge into A, so:
                        \
                        \   A = %ffff ffff, where:
                        \
                        \     * Bits 0-3 = the number of face 1
                        \
                        \     * Bits 4-7 = the number of face 2

 STA P                  \ Store byte #1 into P

 AND #%00001111         \ Extract the number of face 1 into X
 TAX

 LDA XX2,X              \ If XX2+X is non-zero then we decided in part 5 that
 BNE LL79               \ face 1 is visible, so jump to LL79

 LDA P                  \ Fetch byte #1 for this edge into A

 LSR A                  \ Shift right four times to extract the number of face 2
 LSR A                  \ from bits 4-7 into X
 LSR A
 LSR A
 TAX

 LDA XX2,X              \ If XX2+X is zero then we decided in part 5 that
 BEQ LL78               \ face 2 is hidden, so jump to LL78

.LL79

                        \ We now build the screen line for this edge, as
                        \ follows:
                        \
                        \   XX15(1 0) = start x-coordinate
                        \
                        \   XX15(3 2) = start y-coordinate
                        \
                        \   XX15(5 4) = end x-coordinate
                        \
                        \   XX12(1 0) = end y-coordinate
                        \
                        \ We can then pass this to the line clipping routine
                        \ before storing the resulting line in the ship line
                        \ heap

 INY                    \ Increment Y to point to byte #2

 LDA (V),Y              \ Fetch byte #2 for this edge into X, which contains
 TAX                    \ the number of the vertex at the start of the edge
                        \
                        \ Byte #2 contains the vertex number multiplied by 4,
                        \ so we can use it as an index into the heap at XX3 to
                        \ fetch the vertex's screen coordinates, which are
                        \ stored as four bytes containing two 16-bit numbers

 LDA XX3,X              \ Fetch the x_lo coordinate of the edge's start vertex
 STA XX15               \ from the XX3 heap into XX15

 LDA XX3+1,X            \ Fetch the x_hi coordinate of the edge's start vertex
 STA XX15+1             \ from the XX3 heap into XX15+1

 LDA XX3+2,X            \ Fetch the y_lo coordinate of the edge's start vertex
 STA XX15+2             \ from the XX3 heap into XX15+2

 LDA XX3+3,X            \ Fetch the y_hi coordinate of the edge's start vertex
 STA XX15+3             \ from the XX3 heap into XX15+3

 INY                    \ Increment Y to point to byte #3

 LDA (V),Y              \ Fetch byte #3 for this edge into X, which contains
 TAX                    \ the number of the vertex at the end of the edge

 LDA XX3,X              \ Fetch the x_lo coordinate of the edge's end vertex
 STA XX15+4             \ from the XX3 heap into XX15+4

 LDA XX3+2,X            \ Fetch the y_lo coordinate of the edge's end vertex
 STA XX12               \ from the XX3 heap into XX12

 LDA XX3+3,X            \ Fetch the y_hi coordinate of the edge's end vertex
 STA XX12+1             \ from the XX3 heap into XX12+1

 LDA XX3+1,X            \ Fetch the x_hi coordinate of the edge's end vertex
 STA XX15+5             \ from the XX3 heap into XX15+5

 JSR CLIP2              \ Call CLIP2 to see if the new line segment needs to be
                        \ clipped to fit on-screen, returning the clipped line's
                        \ end-points in (X1, Y1) and (X2, Y2)

 BCS LL78               \ If the C flag is set then the line is not visible on
                        \ screen, so jump to LL78 so we don't store this line
                        \ in the ship line heap

 JSR LSPUT              \ Draw this edge using flicker-free animation, by first
                        \ drawing the ship's new line and then erasing the
                        \ corresponding old line from the screen

\ ******************************************************************************
\
\       Name: LL9 (Part 11 of 12)
\       Type: Subroutine
\   Category: Drawing ships
\    Summary: Draw ship: Loop back for the next edge
\  Deep dive: Drawing ships
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   LL81+2              Draw the contents of the ship line heap, used to draw
\                       the ship as a dot from SHPPT
\
\ ******************************************************************************

.LL78

 LDA LSNUM              \ If LSNUM >= CNT, skip to LL81 so we don't loop back
 CMP CNT                \ for the next edge (CNT was set to the maximum heap
 BCS LL81               \ size for this ship in part 10, so this checks whether
                        \ we have just run out of space in the ship line heap,
                        \ and stops drawing edges if we have)

 LDA V                  \ Increment V by 4 so V(1 0) points to the data for the
 CLC                    \ next edge
 ADC #4
 STA V

 BCC P%+4               \ If the above addition didn't overflow, skip the
                        \ following instruction

 INC V+1                \ Otherwise increment the high byte of V(1 0), as we
                        \ just moved the V(1 0) pointer past a page boundary

 INC XX17               \ Increment the edge counter to point to the next edge

 LDY XX17               \ If Y < XX20, which contains the number of edges in
 CPY XX20               \ the blueprint, loop back to LL75 to process the next
 BCC LL75               \ edge

.LL81

 JMP LSCLR              \ Jump down to part 12 below to draw any remaining lines
                        \ from the old ship that are still in the ship line heap

\ ******************************************************************************
\
\       Name: LL118
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Move a point along a line until it is on-screen
\  Deep dive: Line-clipping
\
\ ------------------------------------------------------------------------------
\
\ Given a point (x1, y1), a gradient and a direction of slope, move the point
\ along the line until it is on-screen, so this effectively clips the (x1, y1)
\ end of a line to be on the screen.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   XX15(1 0)           x1 as a 16-bit coordinate (x1_hi x1_lo)
\
\   XX15(3 2)           y1 as a 16-bit coordinate (y1_hi y1_lo)
\
\   XX12+2              The line's gradient * 256 (so 1.0 = 256)
\
\   XX12+3              The direction of slope:
\
\                         * Positive (bit 7 clear) = top left to bottom right
\
\                         * Negative (bit 7 set) = top right to bottom left
\
\   T                   The gradient of slope:
\
\                         * 0 if it's a shallow slope
\
\                         * &FF if it's a steep slope
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   XX15                x1 as an 8-bit coordinate
\
\   XX15+2              y1 as an 8-bit coordinate
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   LL118-1             Contains an RTS
\
\ ******************************************************************************

.LL118

 LDA XX15+1             \ If x1_hi is positive, jump down to LL119 to skip the
 BPL LL119              \ following

 STA S                  \ Otherwise x1_hi is negative, i.e. off the left of the
                        \ screen, so set S = x1_hi

 JSR LL120              \ Call LL120 to calculate:
                        \
                        \   (Y X) = (S x1_lo) * XX12+2      if T = 0
                        \         = x1 * gradient
                        \
                        \   (Y X) = (S x1_lo) / XX12+2      if T <> 0
                        \         = x1 / gradient
                        \
                        \ with the sign of (Y X) set to the opposite of the
                        \ line's direction of slope

 TXA                    \ Set y1 = y1 + (Y X)
 CLC                    \
 ADC XX15+2             \ starting with the low bytes
 STA XX15+2

 TYA                    \ And then adding the high bytes
 ADC XX15+3
 STA XX15+3

 LDA #0                 \ Set x1 = 0
 STA XX15
 STA XX15+1

 TAX                    \ Set X = 0 so the next instruction becomes a JMP

.LL119

 BEQ LL134              \ If x1_hi = 0 then jump down to LL134 to skip the
                        \ following, as the x-coordinate is already on-screen
                        \ (as 0 <= (x_hi x_lo) <= 255)

 STA S                  \ Otherwise x1_hi is positive, i.e. x1 >= 256 and off
 DEC S                  \ the right side of the screen, so set S = x1_hi - 1

 JSR LL120              \ Call LL120 to calculate:
                        \
                        \   (Y X) = (S x1_lo) * XX12+2      if T = 0
                        \         = (x1 - 256) * gradient
                        \
                        \   (Y X) = (S x1_lo) / XX12+2      if T <> 0
                        \         = (x1 - 256) / gradient
                        \
                        \ with the sign of (Y X) set to the opposite of the
                        \ line's direction of slope

 TXA                    \ Set y1 = y1 + (Y X)
 CLC                    \
 ADC XX15+2             \ starting with the low bytes
 STA XX15+2

 TYA                    \ And then adding the high bytes
 ADC XX15+3
 STA XX15+3

 LDX #255               \ Set x1 = 255
 STX XX15
 INX
 STX XX15+1

.LL134

                        \ We have moved the point so the x-coordinate is on
                        \ screen (i.e. in the range 0-255), so now for the
                        \ y-coordinate

 LDA XX15+3             \ If y1_hi is positive, jump down to LL119 to skip
 BPL LL135              \ the following

 STA S                  \ Otherwise y1_hi is negative, i.e. off the top of the
                        \ screen, so set S = y1_hi

 LDA XX15+2             \ Set R = y1_lo
 STA R

 JSR LL123              \ Call LL123 to calculate:
                        \
                        \   (Y X) = (S R) / XX12+2      if T = 0
                        \         = y1 / gradient
                        \
                        \   (Y X) = (S R) * XX12+2      if T <> 0
                        \         = y1 * gradient
                        \
                        \ with the sign of (Y X) set to the opposite of the
                        \ line's direction of slope

 TXA                    \ Set x1 = x1 + (Y X)
 CLC                    \
 ADC XX15               \ starting with the low bytes
 STA XX15

 TYA                    \ And then adding the high bytes
 ADC XX15+1
 STA XX15+1

 LDA #0                 \ Set y1 = 0
 STA XX15+2
 STA XX15+3

.LL135

\BNE LL139              \ This instruction is commented out in the original
                        \ source

 LDA XX15+2             \ Set (S R) = (y1_hi y1_lo) - screen height
 SEC                    \
 SBC #Y*2               \ starting with the low bytes
 STA R

 LDA XX15+3             \ And then subtracting the high bytes
 SBC #0
 STA S

 BCC LL136              \ If the subtraction underflowed, i.e. if y1 < screen
                        \ height, then y1 is already on-screen, so jump to LL136
                        \ to return from the subroutine, as we are done

.LL139

                        \ If we get here then y1 >= screen height, i.e. off the
                        \ bottom of the screen

 JSR LL123              \ Call LL123 to calculate:
                        \
                        \   (Y X) = (S R) / XX12+2      if T = 0
                        \         = (y1 - screen height) / gradient
                        \
                        \   (Y X) = (S R) * XX12+2      if T <> 0
                        \         = (y1 - screen height) * gradient
                        \
                        \ with the sign of (Y X) set to the opposite of the
                        \ line's direction of slope

 TXA                    \ Set x1 = x1 + (Y X)
 CLC                    \
 ADC XX15               \ starting with the low bytes
 STA XX15

 TYA                    \ And then adding the high bytes
 ADC XX15+1
 STA XX15+1

 LDA #Y*2-1             \ Set y1 = 2 * #Y - 1. The constant #Y is 96, the
 STA XX15+2             \ y-coordinate of the mid-point of the space view, so
 LDA #0                 \ this sets Y2 to 191, the y-coordinate of the bottom
 STA XX15+3             \ pixel row of the space view

.LL136

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: LL120
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (Y X) = (S x1_lo) * XX12+2 or (S x1_lo) / XX12+2
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following:
\
\   * If T = 0, this is a shallow slope, so calculate (Y X) = (S x1_lo) * XX12+2
\
\   * If T <> 0, this is a steep slope, so calculate (Y X) = (S x1_lo) / XX12+2
\
\ giving (Y X) the opposite sign to the slope direction in XX12+3.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   T                   The gradient of slope:
\
\                         * 0 if it's a shallow slope
\
\                         * &FF if it's a steep slope
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   LL122               Calculate (Y X) = (S R) * Q and set the sign to the
\                       opposite of the top byte on the stack
\
\ ******************************************************************************

.LL120

 LDA XX15               \ Set R = x1_lo
 STA R

\.LL120                 \ This label is commented out in the original source

 JSR LL129              \ Call LL129 to do the following:
                        \
                        \   Q = XX12+2
                        \     = line gradient
                        \
                        \   A = S EOR XX12+3
                        \     = S EOR slope direction
                        \
                        \   (S R) = |S R|
                        \
                        \ So A contains the sign of S * slope direction

 PHA                    \ Store A on the stack so we can use it later

 LDX T                  \ If T is non-zero, then it's a steep slope, so jump
 BNE LL121              \ down to LL121 to calculate this instead:
                        \
                        \   (Y X) = (S R) / Q

.LL122

                        \ The following calculates:
                        \
                        \   (Y X) = (S R) * Q
                        \
                        \ using the same shift-and-add algorithm that's
                        \ documented in MULT1

 LDA #0                 \ Set A = 0

 TAX                    \ Set (Y X) = 0 so we can start building the answer here
 TAY

 LSR S                  \ Shift (S R) to the right, so we extract bit 0 of (S R)
 ROR R                  \ into the C flag

 ASL Q                  \ Shift Q to the left, catching bit 7 in the C flag

 BCC LL126              \ If C (i.e. the next bit from Q) is clear, do not do
                        \ the addition for this bit of Q, and instead skip to
                        \ LL126 to just do the shifts

.LL125

 TXA                    \ Set (Y X) = (Y X) + (S R)
 CLC                    \
 ADC R                  \ starting with the low bytes
 TAX

 TYA                    \ And then doing the high bytes
 ADC S
 TAY

.LL126

 LSR S                  \ Shift (S R) to the right
 ROR R

 ASL Q                  \ Shift Q to the left, catching bit 7 in the C flag

 BCS LL125              \ If C (i.e. the next bit from Q) is set, loop back to
                        \ LL125 to do the addition for this bit of Q

 BNE LL126              \ If Q has not yet run out of set bits, loop back to
                        \ LL126 to do the "shift" part of shift-and-add until
                        \ we have done additions for all the set bits in Q, to
                        \ give us our multiplication result

 PLA                    \ Restore A, which we calculated above, from the stack

 BPL LL133              \ If A is positive jump to LL133 to negate (Y X) and
                        \ return from the subroutine using a tail call

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: LL123
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (Y X) = (S R) / XX12+2 or (S R) * XX12+2
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following:
\
\   * If T = 0, this is a shallow slope, so calculate (Y X) = (S R) / XX12+2
\
\   * If T <> 0, this is a steep slope, so calculate (Y X) = (S R) * XX12+2
\
\ giving (Y X) the opposite sign to the slope direction in XX12+3.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   XX12+2              The line's gradient * 256 (so 1.0 = 256)
\
\   XX12+3              The direction of slope:
\
\                         * Bit 7 clear means top left to bottom right
\
\                         * Bit 7 set means top right to bottom left
\
\   T                   The gradient of slope:
\
\                         * 0 if it's a shallow slope
\
\                         * &FF if it's a steep slope
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   LL121               Calculate (Y X) = (S R) / Q and set the sign to the
\                       opposite of the top byte on the stack
\
\   LL133               Negate (Y X) and return from the subroutine
\
\   LL128               Contains an RTS
\
\ ******************************************************************************

.LL123

 JSR LL129              \ Call LL129 to do the following:
                        \
                        \   Q = XX12+2
                        \     = line gradient
                        \
                        \   A = S EOR XX12+3
                        \     = S EOR slope direction
                        \
                        \   (S R) = |S R|
                        \
                        \ So A contains the sign of S * slope direction

 PHA                    \ Store A on the stack so we can use it later

 LDX T                  \ If T is non-zero, then it's a steep slope, so jump up
 BNE LL122              \ to LL122 to calculate this instead:
                        \
                        \   (Y X) = (S R) * Q

.LL121

                        \ The following calculates:
                        \
                        \   (Y X) = (S R) / Q
                        \
                        \ using the same shift-and-subtract algorithm that's
                        \ documented in TIS2

 LDA #%11111111         \ Set Y = %11111111
 TAY

 ASL A                  \ Set X = %11111110
 TAX

                        \ This sets (Y X) = %1111111111111110, so we can rotate
                        \ through 15 loop iterations, getting a 1 each time, and
                        \ then getting a 0 on the 16th iteration... and we can
                        \ also use it to catch our result bits into bit 0 each
                        \ time

.LL130

 ASL R                  \ Shift (S R) to the left
 ROL S

 LDA S                  \ Set A = S

 BCS LL131              \ If bit 7 of S was set, then jump straight to the
                        \ subtraction

 CMP Q                  \ If A < Q (i.e. S < Q), skip the following subtractions
 BCC LL132

.LL131

 SBC Q                  \ A >= Q (i.e. S >= Q) so set:
 STA S                  \
                        \   S = (A R) - Q
                        \     = (S R) - Q
                        \
                        \ starting with the low bytes (we know the C flag is
                        \ set so the subtraction will be correct)

 LDA R                  \ And then doing the high bytes
 SBC #0
 STA R

 SEC                    \ Set the C flag to rotate into the result in (Y X)

.LL132

 TXA                    \ Rotate the counter in (Y X) to the left, and catch the
 ROL A                  \ result bit into bit 0 (which will be a 0 if we didn't
 TAX                    \ do the subtraction, or 1 if we did)
 TYA
 ROL A
 TAY

 BCS LL130              \ If we still have set bits in (Y X), loop back to LL130
                        \ to do the next iteration of 15, until we have done the
                        \ whole division

 PLA                    \ Restore A, which we calculated above, from the stack

 BMI LL128              \ If A is negative jump to LL128 to return from the
                        \ subroutine with (Y X) as is

.LL133

 TXA                    \ Otherwise negate (Y X) using two's complement by first
 EOR #%11111111         \ setting the low byte to ~X + 1
\CLC                    \
 ADC #1                 \ The CLC instruction is commented out in the original
 TAX                    \ source. It would have no effect as we know the C flag
                        \ is clear from when we passed through the BCS above

 TYA                    \ Then set the high byte to ~Y + C
 EOR #%11111111
 ADC #0
 TAY

.LL128

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: LL129
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate Q = XX12+2, A = S EOR XX12+3 and (S R) = |S R|
\
\ ------------------------------------------------------------------------------
\
\ Do the following, in this order:
\
\   Q = XX12+2
\
\   A = S EOR XX12+3
\
\   (S R) = |S R|
\
\ This sets up the variables required above to calculate (S R) / XX12+2 and give
\ the result the opposite sign to XX12+3.
\
\ ******************************************************************************

.LL129

 LDX XX12+2             \ Set Q = XX12+2
 STX Q

 LDA S                  \ If S is positive, jump to LL127
 BPL LL127

 LDA #0                 \ Otherwise set R = -R
 SEC
 SBC R
 STA R

 LDA S                  \ Push S onto the stack
 PHA

 EOR #%11111111         \ Set S = ~S + 1 + C
 ADC #0
 STA S

 PLA                    \ Pull the original, negative S from the stack into A

.LL127

 EOR XX12+3             \ Set A = original argument S EOR'd with XX12+3

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: LL145 (Part 1 of 4)
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Clip line: Work out which end-points are on-screen, if any
\  Deep dive: Line-clipping
\             Extended screen coordinates
\
\ ------------------------------------------------------------------------------
\
\ This routine clips the line from (x1, y1) to (x2, y2) so it fits on-screen, or
\ returns an error if it can't be clipped to fit. The arguments are 16-bit
\ coordinates, and the clipped line is returned using 8-bit screen coordinates.
\
\ This part sets XX13 to reflect which of the two points are on-screen and
\ off-screen.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   XX15(1 0)           x1 as a 16-bit coordinate (x1_hi x1_lo)
\
\   XX15(3 2)           y1 as a 16-bit coordinate (y1_hi y1_lo)
\
\   XX15(5 4)           x2 as a 16-bit coordinate (x2_hi x2_lo)
\
\   XX12(1 0)           y2 as a 16-bit coordinate (y2_hi y2_lo)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   (X1, Y1)            Screen coordinate of the start of the clipped line
\
\   (X2, Y2)            Screen coordinate of the end of the clipped line
\
\   C flag              Clear if the clipped line fits on-screen, set if it
\                       doesn't
\
\   XX13                The state of the original coordinates on-screen:
\
\                         * 0   = (x2, y2) on-screen
\
\                         * 95  = (x1, y1) on-screen,  (x2, y2) off-screen
\
\                         * 191 = (x1, y1) off-screen, (x2, y2) off-screen
\
\                       So XX13 is non-zero if the end of the line was clipped,
\                       meaning the next line sent to BLINE can't join onto the
\                       end but has to start a new segment
\
\   SWAP                The swap status of the returned coordinates:
\
\                         * &FF if we swapped the values of (x1, y1) and
\                           (x2, y2) as part of the clipping process
\
\                         * 0 if the coordinates are still in the same order
\
\   Y                   Y is preserved
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   CLIP                Another name for LL145
\
\   CLIP2               Don't initialise the values in SWAP or A
\
\ ******************************************************************************

.LL145

.CLIP

 LDA #0                 \ Set SWAP = 0
 STA SWAP

 LDA XX15+5             \ Set A = x2_hi

.CLIP2

 LDX #Y*2-1             \ Set X = #Y * 2 - 1. The constant #Y is 96, the
                        \ y-coordinate of the mid-point of the space view, so
                        \ this sets Y2 to 191, the y-coordinate of the bottom
                        \ pixel row of the space view

 ORA XX12+1             \ If one or both of x2_hi and y2_hi are non-zero, jump
 BNE LL107              \ to LL107 to skip the following, leaving X at 191

 CPX XX12               \ If y2_lo > the y-coordinate of the bottom of screen
 BCC LL107              \ then (x2, y2) is off the bottom of the screen, so skip
                        \ the following instruction, leaving X at 191

 LDX #0                 \ Set X = 0

.LL107

 STX XX13               \ Set XX13 = X, so we have:
                        \
                        \   * XX13 = 0 if x2_hi = y2_hi = 0, y2_lo is on-screen
                        \
                        \   * XX13 = 191 if x2_hi or y2_hi are non-zero or y2_lo
                        \            is off the bottom of the screen
                        \
                        \ In other words, XX13 is 191 if (x2, y2) is off-screen,
                        \ otherwise it is 0

 LDA XX15+1             \ If one or both of x1_hi and y1_hi are non-zero, jump
 ORA XX15+3             \ to LL83
 BNE LL83

 LDA #Y*2-1             \ If y1_lo > the y-coordinate of the bottom of screen
 CMP XX15+2             \ then (x1, y1) is off the bottom of the screen, so jump
 BCC LL83               \ to LL83

                        \ If we get here, (x1, y1) is on-screen

 LDA XX13               \ If XX13 is non-zero, i.e. (x2, y2) is off-screen, jump
 BNE LL108              \ to LL108 to halve it before continuing at LL83

                        \ If we get here, the high bytes are all zero, which
                        \ means the x-coordinates are < 256 and therefore fit on
                        \ screen, and neither coordinate is off the bottom of
                        \ the screen. That means both coordinates are already on
                        \ screen, so we don't need to do any clipping, all we
                        \ need to do is move the low bytes into (X1, Y1) and
                        \ X2, Y2) and return

.LL146

                        \ If we get here then we have clipped our line to the
                        \ screen edge (if we had to clip it at all), so we move
                        \ the low bytes from (x1, y1) and (x2, y2) into (X1, Y1)
                        \ and (X2, Y2), remembering that they share locations
                        \ with XX15:
                        \
                        \   X1 = XX15
                        \   Y1 = XX15+1
                        \   X2 = XX15+2
                        \   Y2 = XX15+3
                        \
                        \ X1 already contains x1_lo, so now we do the rest

 LDA XX15+2             \ Set Y1 (aka XX15+1) = y1_lo
 STA XX15+1

 LDA XX15+4             \ Set X2 (aka XX15+2) = x2_lo
 STA XX15+2

 LDA XX12               \ Set Y2 (aka XX15+3) = y2_lo
 STA XX15+3

 CLC                    \ Clear the C flag as the clipped line fits on-screen

 RTS                    \ Return from the subroutine

.LL109

 SEC                    \ Set the C flag to indicate the clipped line does not
                        \ fit on-screen

 RTS                    \ Return from the subroutine

.LL108

 LSR XX13               \ If we get here then (x2, y2) is off-screen and XX13 is
                        \ 191, so shift XX13 right to halve it to 95

\ ******************************************************************************
\
\       Name: LL145 (Part 2 of 4)
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Clip line: Work out if any part of the line is on-screen
\  Deep dive: Line-clipping
\             Extended screen coordinates
\
\ ------------------------------------------------------------------------------
\
\ This part does a number of tests to see if the line is on or off the screen.
\
\ If we get here then at least one of (x1, y1) and (x2, y2) is off-screen, with
\ XX13 set as follows:
\
\   * 0   = (x1, y1) off-screen, (x2, y2) on-screen
\
\   * 95  = (x1, y1) on-screen,  (x2, y2) off-screen
\
\   * 191 = (x1, y1) off-screen, (x2, y2) off-screen
\
\ where "off-screen" is defined as having a non-zero high byte in one of the
\ coordinates, or in the case of y-coordinates, having a low byte > 191, the
\ y-coordinate of the bottom of the space view.
\
\ ******************************************************************************

.LL83

 LDA XX13               \ If XX13 < 128 then only one of the points is on-screen
 BPL LL115              \ so jump down to LL115 to skip the checks of whether
                        \ both points are in the strips to the right or bottom
                        \ of the screen

                        \ If we get here, both points are off-screen

 LDA XX15+1             \ If both x1_hi and x2_hi have bit 7 set, jump to LL109
 AND XX15+5             \ to return from the subroutine with the C flag set, as
 BMI LL109              \ the entire line is above the top of the screen

 LDA XX15+3             \ If both y1_hi and y2_hi have bit 7 set, jump to LL109
 AND XX12+1             \ to return from the subroutine with the C flag set, as
 BMI LL109              \ the entire line is to the left of the screen

 LDX XX15+1             \ Set A = X = x1_hi - 1
 DEX
 TXA

 LDX XX15+5             \ Set XX12+2 = x2_hi - 1
 DEX
 STX XX12+2

 ORA XX12+2             \ If neither (x1_hi - 1) or (x2_hi - 1) have bit 7 set,
 BPL LL109              \ jump to LL109 to return from the subroutine with the C
                        \ flag set, as the line doesn't fit on-screen

 LDA XX15+2             \ If y1_lo < y-coordinate of screen bottom, clear the C
 CMP #Y*2               \ flag, otherwise set it

 LDA XX15+3             \ Set XX12+2 = y1_hi - (1 - C), so:
 SBC #0                 \
 STA XX12+2             \  * Set XX12+2 = y1_hi - 1 if y1_lo is on-screen
                        \  * Set XX12+2 = y1_hi     otherwise
                        \
                        \ We do this subtraction because we are only interested
                        \ in trying to move the points up by a screen if that
                        \ might move the point into the space view portion of
                        \ the screen, i.e. if y1_lo is on-screen

 LDA XX12               \ If y2_lo < y-coordinate of screen bottom, clear the C
 CMP #Y*2               \ flag, otherwise set it

 LDA XX12+1             \ Set XX12+2 = y2_hi - (1 - C), so:
 SBC #0                 \
                        \  * Set XX12+1 = y2_hi - 1 if y2_lo is on-screen
                        \  * Set XX12+1 = y2_hi     otherwise
                        \
                        \ We do this subtraction because we are only interested
                        \ in trying to move the points up by a screen if that
                        \ might move the point into the space view portion of
                        \ the screen, i.e. if y1_lo is on-screen

 ORA XX12+2             \ If neither XX12+1 or XX12+2 have bit 7 set, jump to
 BPL LL109              \ LL109 to return from the subroutine with the C flag
                        \ set, as the line doesn't fit on-screen

\ ******************************************************************************
\
\       Name: LL145 (Part 3 of 4)
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Clip line: Calculate the line's gradient
\  Deep dive: Line-clipping
\             Extended screen coordinates
\
\ ******************************************************************************

.LL115

 TYA                    \ Store Y on the stack so we can preserve it through the
 PHA                    \ call to this subroutine

 LDA XX15+4             \ Set XX12+2 = x2_lo - x1_lo
 SEC
 SBC XX15
 STA XX12+2

 LDA XX15+5             \ Set XX12+3 = x2_hi - x1_hi
 SBC XX15+1
 STA XX12+3

 LDA XX12               \ Set XX12+4 = y2_lo - y1_lo
 SEC
 SBC XX15+2
 STA XX12+4

 LDA XX12+1             \ Set XX12+5 = y2_hi - y1_hi
 SBC XX15+3
 STA XX12+5

                        \ So we now have:
                        \
                        \   delta_x in XX12(3 2)
                        \   delta_y in XX12(5 4)
                        \
                        \ where the delta is (x1, y1) - (x2, y2))

 EOR XX12+3             \ Set S = the sign of delta_x * the sign of delta_y, so
 STA S                  \ if bit 7 of S is set, the deltas have different signs

 LDA XX12+5             \ If delta_y_hi is positive, jump down to LL110 to skip
 BPL LL110              \ the following

 LDA #0                 \ Otherwise flip the sign of delta_y to make it
 SEC                    \ positive, starting with the low bytes
 SBC XX12+4
 STA XX12+4

 LDA #0                 \ And then doing the high bytes, so now:
 SBC XX12+5             \
 STA XX12+5             \   XX12(5 4) = |delta_y|

.LL110

 LDA XX12+3             \ If delta_x_hi is positive, jump down to LL111 to skip
 BPL LL111              \ the following

 SEC                    \ Otherwise flip the sign of delta_x to make it
 LDA #0                 \ positive, starting with the low bytes
 SBC XX12+2
 STA XX12+2

 LDA #0                 \ And then doing the high bytes, so now:
 SBC XX12+3             \
                        \   (A XX12+2) = |delta_x|

.LL111

                        \ We now keep halving |delta_x| and |delta_y| until
                        \ both of them have zero in their high bytes

 TAX                    \ If |delta_x_hi| is non-zero, skip the following
 BNE LL112

 LDX XX12+5             \ If |delta_y_hi| = 0, jump down to LL113 (as both
 BEQ LL113              \ |delta_x_hi| and |delta_y_hi| are 0)

.LL112

 LSR A                  \ Halve the value of delta_x in (A XX12+2)
 ROR XX12+2

 LSR XX12+5             \ Halve the value of delta_y XX12(5 4)
 ROR XX12+4

 JMP LL111              \ Loop back to LL111

.LL113

                        \ By now, the high bytes of both |delta_x| and |delta_y|
                        \ are zero

 STX T                  \ We know that X = 0 as that's what we tested with a BEQ
                        \ above, so this sets T = 0

 LDA XX12+2             \ If delta_x_lo < delta_y_lo, so our line is more
 CMP XX12+4             \ vertical than horizontal, jump to LL114
 BCC LL114

                        \ If we get here then our line is more horizontal than
                        \ vertical, so it is a shallow slope

 STA Q                  \ Set Q = delta_x_lo

 LDA XX12+4             \ Set A = delta_y_lo

 JSR LL28               \ Call LL28 to calculate:
                        \
                        \   R = 256 * A / Q
                        \     = 256 * delta_y_lo / delta_x_lo

 JMP LL116              \ Jump to LL116, as we now have the line's gradient in R

.LL114

                        \ If we get here then our line is more vertical than
                        \ horizontal, so it is a steep slope

 LDA XX12+4             \ Set Q = delta_y_lo
 STA Q
 LDA XX12+2             \ Set A = delta_x_lo

 JSR LL28               \ Call LL28 to calculate:
                        \
                        \   R = 256 * A / Q
                        \     = 256 * delta_x_lo / delta_y_lo

 DEC T                  \ T was set to 0 above, so this sets T = &FF when our
                        \ line is steep

\ ******************************************************************************
\
\       Name: LL145 (Part 4 of 4)
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Clip line: Call the routine in LL188 to do the actual clipping
\  Deep dive: Line-clipping
\             Extended screen coordinates
\
\ ------------------------------------------------------------------------------
\
\ This part sets things up to call the routine in LL188, which does the actual
\ clipping.
\
\ If we get here, then R has been set to the gradient of the line (x1, y1) to
\ (x2, y2), with T indicating the gradient of slope:
\
\   * 0   = shallow slope (more horizontal than vertical)
\
\   * &FF = steep slope (more vertical than horizontal)
\
\ and XX13 has been set as follows:
\
\   * 0   = (x1, y1) off-screen, (x2, y2) on-screen
\
\   * 95  = (x1, y1) on-screen,  (x2, y2) off-screen
\
\   * 191 = (x1, y1) off-screen, (x2, y2) off-screen
\
\ ******************************************************************************

.LL116

 LDA R                  \ Store the gradient in XX12+2
 STA XX12+2

 LDA S                  \ Store the type of slope in XX12+3, bit 7 clear means
 STA XX12+3             \ top left to bottom right, bit 7 set means top right to
                        \ bottom left

 LDA XX13               \ If XX13 = 0, skip the following instruction
 BEQ LL138

 BPL LLX117             \ If XX13 is positive, it must be 95. This means
                        \ (x1, y1) is on-screen but (x2, y2) isn't, so we jump
                        \ to LLX117 to swap the (x1, y1) and (x2, y2)
                        \ coordinates around before doing the actual clipping,
                        \ because we need to clip (x2, y2) but the clipping
                        \ routine at LL118 only clips (x1, y1)

.LL138

                        \ If we get here, XX13 = 0 or 191, so (x1, y1) is
                        \ off-screen and needs clipping

 JSR LL118              \ Call LL118 to move (x1, y1) along the line onto the
                        \ screen, i.e. clip the line at the (x1, y1) end

 LDA XX13               \ If XX13 = 0, i.e. (x2, y2) is on-screen, jump down to
 BPL LL124              \ LL124 to return with a successfully clipped line

.LL117

                        \ If we get here, XX13 = 191 (both coordinates are
                        \ off-screen)

 LDA XX15+1             \ If either of x1_hi or y1_hi are non-zero, jump to
 ORA XX15+3             \ LL137 to return from the subroutine with the C flag
 BNE LL137              \ set, as the line doesn't fit on-screen

 LDA XX15+2             \ If y1_lo > y-coordinate of the bottom of the screen
 CMP #Y*2               \ jump to LL137 to return from the subroutine with the
 BCS LL137              \ C flag set, as the line doesn't fit on-screen

.LLX117

                        \ If we get here, XX13 = 95 or 191, and in both cases
                        \ (x2, y2) is off-screen, so we now need to swap the
                        \ (x1, y1) and (x2, y2) coordinates around before doing
                        \ the actual clipping, because we need to clip (x2, y2)
                        \ but the clipping routine at LL118 only clips (x1, y1)

 LDX XX15               \ Swap x1_lo = x2_lo
 LDA XX15+4
 STA XX15
 STX XX15+4

 LDA XX15+5             \ Swap x2_lo = x1_lo
 LDX XX15+1
 STX XX15+5
 STA XX15+1

 LDX XX15+2             \ Swap y1_lo = y2_lo
 LDA XX12
 STA XX15+2
 STX XX12

 LDA XX12+1             \ Swap y2_lo = y1_lo
 LDX XX15+3
 STX XX12+1
 STA XX15+3

 JSR LL118              \ Call LL118 to move (x1, y1) along the line onto the
                        \ screen, i.e. clip the line at the (x1, y1) end

 DEC SWAP               \ Set SWAP = &FF to indicate that we just clipped the
                        \ line at the (x2, y2) end by swapping the coordinates
                        \ (the DEC does this as we set SWAP to 0 at the start of
                        \ this subroutine)

.LL124

 PLA                    \ Restore Y from the stack so it gets preserved through
 TAY                    \ the call to this subroutine

 JMP LL146              \ Jump up to LL146 to move the low bytes of (x1, y1) and
                        \ (x2, y2) into (X1, Y1) and (X2, Y2), and return from
                        \ the subroutine with a successfully clipped line

.LL137

 PLA                    \ Restore Y from the stack so it gets preserved through
 TAY                    \ the call to this subroutine

 SEC                    \ Set the C flag to indicate the clipped line does not
                        \ fit on-screen

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: LL9 (Part 12 of 12)
\       Type: Subroutine
\   Category: Drawing ships
\    Summary: Draw ship: Draw all the visible edges from the ship line heap
\  Deep dive: Drawing ships
\
\ ------------------------------------------------------------------------------
\
\ This part draws any remaining lines from the old ship that are still in the
\ ship line heap.
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   LSCLR               Draw any remaining lines from the old ship that are
\                       still in the ship line heap
\
\   LSC3                Contains an RTS
\
\ ******************************************************************************

.LSCLR

 JSR H_LSCLR            \ Port: in record mode there are no lines to erase
                        \ (gfx-hooks.asm)

 LDY LSNUM              \ Set Y to the offset in the line heap LSNUM

.LSC1

 CPY LSNUM2             \ If Y >= LSNUM2, jump to LSC2 to return from the ship
 BCS LSC2               \ drawing routine, because the index in Y is greater
                        \ than the size of the existing ship line heap, which
                        \ means we have already erased all the old ship's lines
                        \ when drawing the new ship

                        \ If we get here then Y < LSNUM2, which means Y is
                        \ pointing to an on-screen line from the old ship that
                        \ we need to erase

 LDA (XX19),Y           \ Fetch the X1 line coordinate from the heap and store
 INY                    \ it in XX15, incrementing the heap pointer
 STA XX15

 LDA (XX19),Y           \ Fetch the Y1 line coordinate from the heap and store
 INY                    \ it in XX15+1, incrementing the heap pointer
 STA XX15+1

 LDA (XX19),Y           \ Fetch the X2 line coordinate from the heap and store
 INY                    \ it in XX15+2, incrementing the heap pointer
 STA XX15+2

 LDA (XX19),Y           \ Fetch the Y2 line coordinate from the heap and store
 INY                    \ it in XX15+3, incrementing the heap pointer
 STA XX15+3

 JSR LOIN               \ Draw a line from (X1, Y1) to (X2, Y2) to erase it from
                        \ the screen

 JMP LSC1               \ Loop back to LSC1 to draw (i.e. erase) the next line
                        \ from the heap

.LSC2

 LDA LSNUM              \ Store LSNUM in the first byte of the ship line heap
 LDY #0
 STA (XX19),Y

.LSC3

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: LSPUT
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw a ship line using flicker-free animation
\
\ ------------------------------------------------------------------------------
\
\ This routine implements flicker-free ship animation by erasing and redrawing
\ each individual line in the ship, rather than the approach in the other
\ Acornsoft versions of the game, which erase the entire existing ship before
\ drawing the new one.
\
\ Here's the new approach in this routine:
\
\   * Draw the new line
\
\   * Fetch the corresponding existing line (in position LSNUM) from the heap
\
\   * Store the new line in the heap at this position, replacing the old one
\
\   * If the existing line we just took from the heap is on-screen, erase it
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   LSNUM               The offset within the line heap where we add the new
\                       line's coordinates
\
\   X1                  The screen x-coordinate of the start of the line to add
\                       to the ship line heap
\
\   Y1                  The screen y-coordinate of the start of the line to add
\                       to the ship line heap
\
\   X2                  The screen x-coordinate of the end of the line to add
\                       to the ship line heap
\
\   Y2                  The screen y-coordinate of the end of the line to add
\                       to the ship line heap
\
\   XX19(1 0)           XX19(1 0) shares its location with INWK(34 33), which
\                       contains the ship line heap address pointer
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   LSNUM               The offset of the next line in the line heap
\
\ ******************************************************************************

.LSPUT

 LDY LSNUM              \ Set Y = LSNUM, to get the offset within the ship line
                        \ heap where we want to insert our new line

 CPY LSNUM2             \ Compare LSNUM and LSNUM2 and store the flags on the
 PHP                    \ stack so we can retrieve them later

 LDX #3                 \ We now want to copy the line coordinates (X1, Y1) and
                        \ (X2, Y2) to XX12...XX12+3, so set a counter to copy
                        \ 4 bytes

.LSC4

 LDA X1,X               \ Copy the X-th byte of X1/Y1/X2/Y2 to the X-th byte of
 STA XX12,X             \ XX12

 DEX                    \ Decrement the loop counter

 BPL LSC4               \ Loop back until we have copied all four bytes

 JSR LOIN               \ Draw a line from (X1, Y1) to (X2, Y2)

 LDA (XX19),Y           \ Set X1 to the Y-th coordinate on the ship line heap,
 STA X1                 \ i.e. the one we are replacing in the heap

 LDA XX12               \ Replace it with the X1 coordinate in XX12
 STA (XX19),Y

 INY                    \ Increment the index to point to the Y1 coordinate

 LDA (XX19),Y           \ Set Y1 to the Y-th coordinate on the ship line heap,
 STA Y1                 \ i.e. the one we are replacing in the heap

 LDA XX12+1             \ Replace it with the Y1 coordinate in XX12+1
 STA (XX19),Y

 INY                    \ Increment the index to point to the X2 coordinate

 LDA (XX19),Y           \ Set X2 to the Y-th coordinate on the ship line heap,
 STA X2                 \ i.e. the one we are replacing in the heap

 LDA XX12+2             \ Replace it with the X2 coordinate in XX12+2
 STA (XX19),Y

 INY                    \ Increment the index to point to the Y2 coordinate

 LDA (XX19),Y           \ Set Y2 to the Y-th coordinate on the ship line heap,
 STA Y2                 \ i.e. the one we are replacing in the heap

 LDA XX12+3             \ Replace it with the Y2 coordinate in XX12+3
 STA (XX19),Y

 INY                    \ Increment the index to point to the next coordinate
 STY LSNUM              \ and store the updated index in LSNUM

 PLP                    \ Restore the result of the comparison above, so if the
 BCS LSC3               \ original value of LSNUM >= LSNUM2, then we have
                        \ already redrawn all the lines from the old ship's line
                        \ heap, so return from the subroutine (as LSC3 contains
                        \ an RTS)

 JMP LOIN               \ Otherwise there are still more lines to erase from the
                        \ old ship on-screen, so the coordinates in (X1, Y1) and
                        \ (X2, Y2) that we just pulled from the ship line heap
                        \ point to a line that is still on-screen, so call LOIN
                        \ to draw this line and erase it from the screen,
                        \ returning from the subroutine using a tail call

\ ******************************************************************************
\
\ Save ELTG.bin
\
\ ******************************************************************************
\
\       Name: MVEIT (Part 1 of 9)
\       Type: Subroutine
\   Category: Moving
\    Summary: Move current ship: Tidy the orientation vectors
\  Deep dive: Program flow of the ship-moving routine
\             Scheduling tasks with the main loop counter
\
\ ------------------------------------------------------------------------------
\
\ This routine has multiple stages. This stage does the following:
\
\   * Tidy the orientation vectors for one of the ship slots
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   INWK                The current ship/planet/sun's data block
\
\   XSAV                The slot number of the current ship/planet/sun
\
\   TYPE                The type of the current ship/planet/sun
\
\ ******************************************************************************

.MVEIT

 LDA INWK+31            \ If bits 5 or 7 of ship byte #31 are set, jump to MV30
 AND #%10100000         \ as the ship is either exploding or has been killed, so
 BNE MV30               \ we don't need to tidy its orientation vectors or apply
                        \ tactics

 LDA MCNT               \ Fetch the main loop counter

 EOR XSAV               \ Fetch the slot number of the ship we are moving, EOR
 AND #15                \ with the loop counter and apply mod 15 to the result.
 BNE MV3                \ The result will be zero when "counter mod 15" matches
                        \ the slot number, so this makes sure we call TIDY 12
                        \ times every 16 main loop iterations, like this:
                        \
                        \   Iteration 0, tidy the ship in slot 0
                        \   Iteration 1, tidy the ship in slot 1
                        \   Iteration 2, tidy the ship in slot 2
                        \     ...
                        \   Iteration 11, tidy the ship in slot 11
                        \   Iteration 12, do nothing
                        \   Iteration 13, do nothing
                        \   Iteration 14, do nothing
                        \   Iteration 15, do nothing
                        \   Iteration 16, tidy the ship in slot 0
                        \     ...
                        \
                        \ and so on

 JSR TIDY               \ Call TIDY to tidy up the orientation vectors, to
                        \ prevent the ship from getting elongated and out of
                        \ shape due to the imprecise nature of trigonometry
                        \ in assembly language

\ ******************************************************************************
\
\       Name: MVEIT (Part 2 of 9)
\       Type: Subroutine
\   Category: Moving
\    Summary: Move current ship: Call tactics routine, remove ship from scanner
\  Deep dive: Scheduling tasks with the main loop counter
\
\ ------------------------------------------------------------------------------
\
\ This routine has multiple stages. This stage does the following:
\
\   * Apply tactics to ships with AI enabled (by calling the TACTICS routine)
\
\   * Remove the ship from the scanner, so we can move it
\
\ ******************************************************************************

.MV3

 LDX TYPE               \ If the type of the ship we are moving is positive,
 BPL P%+5               \ i.e. it is not a planet (types 128 and 130) or sun
                        \ (type 129), then skip the following instruction

 JMP MV40               \ This item is the planet or sun, so jump to MV40 to
                        \ move it, which ends by jumping back into this routine
                        \ at MV45 (after all the rotation, tactics and scanner
                        \ code, which we don't need to apply to planets or suns)

 LDA INWK+32            \ Fetch the ship's byte #32 (AI flag) into A

 BPL MV30               \ If bit 7 of the AI flag is clear, then skip the
                        \ following as AI is disabled and the ship has no
                        \ tactics

 CPX #MSL               \ If the ship is a missile, skip straight to MV26 to
 BEQ MV26               \ call the TACTICS routine, as we do this every
                        \ iteration of the main loop for missiles only

 LDA MCNT               \ Fetch the main loop counter

 EOR XSAV               \ Fetch the slot number of the ship we are moving, EOR
 AND #7                 \ with the loop counter and apply mod 8 to the result.
 BNE MV30               \ The result will be zero when "counter mod 8" matches
                        \ the slot number mod 8, so this makes sure we call
                        \ TACTICS 12 times every 8 main loop iterations, like
                        \ this:
                        \
                        \   Iteration 0, apply tactics to slots 0 and 8
                        \   Iteration 1, apply tactics to slots 1 and 9
                        \   Iteration 2, apply tactics to slots 2 and 10
                        \   Iteration 3, apply tactics to slots 3 and 11
                        \   Iteration 4, apply tactics to slot 4
                        \   Iteration 5, apply tactics to slot 5
                        \   Iteration 6, apply tactics to slot 6
                        \   Iteration 7, apply tactics to slot 7
                        \   Iteration 8, apply tactics to slots 0 and 8
                        \     ...
                        \
                        \ and so on

.MV26

 JSR TACTICS            \ Call TACTICS to apply AI tactics to this ship

.MV30

 JSR SCAN               \ Draw the ship on the scanner, which has the effect of
                        \ removing it as it hasn't yet moved

\ ******************************************************************************
\
\       Name: MVEIT (Part 3 of 9)
\       Type: Subroutine
\   Category: Moving
\    Summary: Move current ship: Move ship forward according to its speed
\
\ ------------------------------------------------------------------------------
\
\ This routine has multiple stages. This stage does the following:
\
\   * Move the ship forward (along the vector pointing in the direction of
\     travel) according to its speed:
\
\     (x, y, z) += nosev_hi * speed / 64
\
\ ******************************************************************************

 LDA INWK+27            \ Set Q = the ship's speed byte #27 * 4
 ASL A
 ASL A
 STA Q

 LDA INWK+10            \ Set A = |nosev_x_hi|
 AND #%01111111

 JSR FMLTU              \ Set R = A * Q / 256
 STA R                  \       = |nosev_x_hi| * speed / 64

 LDA INWK+10            \ If nosev_x_hi is positive, then:
 LDX #0                 \
 JSR MVT1-2             \   (x_sign x_hi x_lo) = (x_sign x_hi x_lo) + R
                        \
                        \ If nosev_x_hi is negative, then:
                        \
                        \   (x_sign x_hi x_lo) = (x_sign x_hi x_lo) - R
                        \
                        \ So in effect, this does:
                        \
                        \   (x_sign x_hi x_lo) += nosev_x_hi * speed / 64

 LDA INWK+12            \ Set A = |nosev_y_hi|
 AND #%01111111

 JSR FMLTU              \ Set R = A * Q / 256
 STA R                  \       = |nosev_y_hi| * speed / 64

 LDA INWK+12            \ If nosev_y_hi is positive, then:
 LDX #3                 \
 JSR MVT1-2             \   (y_sign y_hi y_lo) = (y_sign y_hi y_lo) + R
                        \
                        \ If nosev_y_hi is negative, then:
                        \
                        \   (y_sign y_hi y_lo) = (y_sign y_hi y_lo) - R
                        \
                        \ So in effect, this does:
                        \
                        \   (y_sign y_hi y_lo) += nosev_y_hi * speed / 64

 LDA INWK+14            \ Set A = |nosev_z_hi|
 AND #%01111111

 JSR FMLTU              \ Set R = A * Q / 256
 STA R                  \       = |nosev_z_hi| * speed / 64

 LDA INWK+14            \ If nosev_y_hi is positive, then:
 LDX #6                 \
 JSR MVT1-2             \   (z_sign z_hi z_lo) = (z_sign z_hi z_lo) + R
                        \
                        \ If nosev_z_hi is negative, then:
                        \
                        \   (z_sign z_hi z_lo) = (z_sign z_hi z_lo) - R
                        \
                        \ So in effect, this does:
                        \
                        \   (z_sign z_hi z_lo) += nosev_z_hi * speed / 64

\ ******************************************************************************
\
\       Name: MVEIT (Part 4 of 9)
\       Type: Subroutine
\   Category: Moving
\    Summary: Move current ship: Apply acceleration to ship's speed as a one-off
\
\ ------------------------------------------------------------------------------
\
\ This routine has multiple stages. This stage does the following:
\
\   * Apply acceleration to the ship's speed (if acceleration is non-zero),
\     and then zero the acceleration as it's a one-off change
\
\ ******************************************************************************

 LDA INWK+27            \ Set A = the ship's speed in byte #24 + the ship's
 CLC                    \ acceleration in byte #28
 ADC INWK+28

 BPL P%+4               \ If the result is positive, skip the following
                        \ instruction

 LDA #0                 \ Set A to 0 to stop the speed from going negative

 LDY #15                \ We now fetch byte #15 from the ship's blueprint, which
                        \ contains the ship's maximum speed, so set Y = 15 to
                        \ use as an index

 CMP (XX0),Y            \ If A < the ship's maximum speed, skip the following
 BCC P%+4               \ instruction

 LDA (XX0),Y            \ Set A to the ship's maximum speed

 STA INWK+27            \ We have now calculated the new ship's speed after
                        \ accelerating and keeping the speed within the ship's
                        \ limits, so store the updated speed in byte #27

 LDA #0                 \ We have added the ship's acceleration, so we now set
 STA INWK+28            \ it back to 0 in byte #28, as it's a one-off change

\ ******************************************************************************
\
\       Name: MVEIT (Part 5 of 9)
\       Type: Subroutine
\   Category: Moving
\    Summary: Move current ship: Rotate ship's location by our pitch and roll
\  Deep dive: Rotating the universe
\
\ ------------------------------------------------------------------------------
\
\ This routine has multiple stages. This stage does the following:
\
\   * Rotate the ship's location in space by the amount of pitch and roll of
\     our ship
\
\ We implement this as follows:
\
\   1. K2 = y - alpha * x
\   2. z = z + beta * K2
\   3. y = K2 - beta * z
\   4. x = x + alpha * y
\
\ ******************************************************************************

 LDX ALP1               \ Fetch the magnitude of the current roll into X, so
                        \ if the roll angle is alpha, X contains |alpha|

 LDA INWK               \ Set P = ~x_lo (i.e. with all its bits flipped) so that
 EOR #%11111111         \ we can pass x_lo to MLTU2 below)
 STA P

 LDA INWK+1             \ Set A = x_hi

 JSR MLTU2-2            \ Set (A P+1 P) = (A ~P) * X
                        \               = (x_hi x_lo) * alpha

 STA P+2                \ Store the high byte of the result in P+2, so we now
                        \ have:
                        \
                        \ P(2 1 0) = (x_hi x_lo) * alpha

 LDA ALP2+1             \ Fetch the flipped sign of the current roll angle alpha
 EOR INWK+2             \ from ALP2+1 and EOR with byte #2 (x_sign), so if the
                        \ flipped roll angle and x_sign have the same sign, A
                        \ will be positive, else it will be negative. So A will
                        \ contain the sign bit of x_sign * flipped alpha sign,
                        \ which is the opposite to the sign of the above result,
                        \ so we now have:
                        \
                        \ (A P+2 P+1) = - (x_sign x_hi x_lo) * alpha / 256

 LDX #3                 \ Set (A P+2 P+1) = (y_sign y_hi y_lo) + (A P+2 P+1)
 JSR MVT6               \                 = y - x * alpha / 256

 STA K2+3               \ Set K2(3) = A = the sign of the result

 LDA P+1                \ Set K2(1) = P+1, the low byte of the result
 STA K2+1

 EOR #%11111111         \ Set P = ~K2+1 (i.e. with all its bits flipped) so
 STA P                  \ that we can pass K2+1 to MLTU2 below)

 LDA P+2                \ Set K2(2) = A = P+2
 STA K2+2

                        \ So we now have result 1 above:
                        \
                        \ K2(3 2 1) = (A P+2 P+1)
                        \           = y - x * alpha / 256

 LDX BET1               \ Fetch the magnitude of the current pitch into X, so
                        \ if the pitch angle is beta, X contains |beta|

 JSR MLTU2-2            \ Set (A P+1 P) = (A ~P) * X
                        \               = K2(2 1) * beta

 STA P+2                \ Store the high byte of the result in P+2, so we now
                        \ have:
                        \
                        \ P(2 1 0) = K2(2 1) * beta

 LDA K2+3               \ Fetch the sign of the above result in K(3 2 1) from
 EOR BET2               \ K2+3 and EOR with BET2, the sign of the current pitch
                        \ rate, so if the pitch and K(3 2 1) have the same sign,
                        \ A will be positive, else it will be negative. So A
                        \ will contain the sign bit of K(3 2 1) * beta, which is
                        \ the same as the sign of the above result, so we now
                        \ have:
                        \
                        \ (A P+2 P+1) = K2(3 2 1) * beta / 256

 LDX #6                 \ Set (A P+2 P+1) = (z_sign z_hi z_lo) + (A P+2 P+1)
 JSR MVT6               \                 = z + K2 * beta / 256

 STA INWK+8             \ Set z_sign = A = the sign of the result

 LDA P+1                \ Set z_lo = P+1, the low byte of the result
 STA INWK+6

 EOR #%11111111         \ Set P = ~z_lo (i.e. with all its bits flipped) so that
 STA P                  \ we can pass z_lo to MLTU2 below)

 LDA P+2                \ Set z_hi = P+2
 STA INWK+7

                        \ So we now have result 2 above:
                        \
                        \ (z_sign z_hi z_lo) = (A P+2 P+1)
                        \                    = z + K2 * beta / 256

 JSR MLTU2              \ MLTU2 doesn't change Q, and Q was set to beta in
                        \ the previous call to MLTU2, so this call does:
                        \
                        \ (A P+1 P) = (A ~P) * Q
                        \           = (z_hi z_lo) * beta

 STA P+2                \ Set P+2 = A = the high byte of the result, so we
                        \ now have:
                        \
                        \ P(2 1 0) = (z_hi z_lo) * beta

 LDA K2+3               \ Set y_sign = K2+3
 STA INWK+5

 EOR BET2               \ EOR y_sign with BET2, the sign of the current pitch
 EOR INWK+8             \ rate, and z_sign. If the result is positive jump to
 BPL MV43               \ MV43, otherwise this means beta * z and y have
                        \ different signs, i.e. P(2 1) and K2(3 2 1) have
                        \ different signs, so we need to add them in order to
                        \ calculate K2(2 1) - P(2 1)

 LDA P+1                \ Set (y_hi y_lo) = K2(2 1) + P(2 1)
 ADC K2+1
 STA INWK+3
 LDA P+2
 ADC K2+2
 STA INWK+4

 JMP MV44               \ Jump to MV44 to continue the calculation

.MV43

 LDA K2+1               \ Reversing the logic above, we need to subtract P(2 1)
 SBC P+1                \ and K2(3 2 1) to calculate K2(2 1) - P(2 1), so this
 STA INWK+3             \ sets (y_hi y_lo) = K2(2 1) - P(2 1)
 LDA K2+2
 SBC P+2
 STA INWK+4

 BCS MV44               \ If the above subtraction did not underflow, then
                        \ jump to MV44, otherwise we need to negate the result

 LDA #1                 \ Negate (y_sign y_hi y_lo) using two's complement,
 SBC INWK+3             \ first doing the low bytes:
 STA INWK+3             \
                        \ y_lo = 1 - y_lo

 LDA #0                 \ Then the high bytes:
 SBC INWK+4             \
 STA INWK+4             \ y_hi = 0 - y_hi

 LDA INWK+5             \ And finally flip the sign in y_sign
 EOR #%10000000
 STA INWK+5

.MV44

                        \ So we now have result 3 above:
                        \
                        \ (y_sign y_hi y_lo) = K2(2 1) - P(2 1)
                        \                    = K2 - beta * z

 LDX ALP1               \ Fetch the magnitude of the current roll into X, so
                        \ if the roll angle is alpha, X contains |alpha|

 LDA INWK+3             \ Set P = ~y_lo (i.e. with all its bits flipped) so that
 EOR #&FF               \ we can pass y_lo to MLTU2 below)
 STA P

 LDA INWK+4             \ Set A = y_hi

 JSR MLTU2-2            \ Set (A P+1 P) = (A ~P) * X
                        \               = (y_hi y_lo) * alpha

 STA P+2                \ Store the high byte of the result in P+2, so we now
                        \ have:
                        \
                        \ P(2 1 0) = (y_hi y_lo) * alpha

 LDA ALP2               \ Fetch the correct sign of the current roll angle alpha
 EOR INWK+5             \ from ALP2 and EOR with byte #5 (y_sign), so if the
                        \ correct roll angle and y_sign have the same sign, A
                        \ will be positive, else it will be negative. So A will
                        \ contain the sign bit of x_sign * correct alpha sign,
                        \ which is the same as the sign of the above result,
                        \ so we now have:
                        \
                        \ (A P+2 P+1) = (y_sign y_hi y_lo) * alpha / 256

 LDX #0                 \ Set (A P+2 P+1) = (x_sign x_hi x_lo) + (A P+2 P+1)
 JSR MVT6               \                 = x + y * alpha / 256

 STA INWK+2             \ Set x_sign = A = the sign of the result

 LDA P+2                \ Set x_hi = P+2, the high byte of the result
 STA INWK+1

 LDA P+1                \ Set x_lo = P+1, the low byte of the result
 STA INWK

                        \ So we now have result 4 above:
                        \
                        \ x = x + alpha * y
                        \
                        \ and the rotation of (x, y, z) is done

\ ******************************************************************************
\
\       Name: MVEIT (Part 6 of 9)
\       Type: Subroutine
\   Category: Moving
\    Summary: Move current ship: Move the ship in space according to our speed
\  Deep dive: A sense of scale
\
\ ------------------------------------------------------------------------------
\
\ This routine has multiple stages. This stage does the following:
\
\   * Move the ship in space according to our speed (we already moved it
\     according to its own speed in part 3).
\
\ We do this by subtracting our speed (i.e. the distance we travel in this
\ iteration of the loop) from the other ship's z-coordinate. We subtract because
\ they appear to be "moving" in the opposite direction to us, and the whole
\ MVEIT routine is about moving the other ships rather than us (even though we
\ are the one doing the moving).
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   MV45                Rejoin the MVEIT routine after the rotation, tactics and
\                       scanner code
\
\ ******************************************************************************

.MV45

 LDA DELTA              \ Set R to our speed in DELTA
 STA R

 LDA #%10000000         \ Set A to zeroes but with bit 7 set, so that (A R) is
                        \ a 16-bit number containing -R, or -speed

 LDX #6                 \ Set X to the z-axis so the call to MVT1 does this:
 JSR MVT1               \
                        \ (z_sign z_hi z_lo) = (z_sign z_hi z_lo) + (A R)
                        \                    = (z_sign z_hi z_lo) - speed

 LDA TYPE               \ If the ship type is not the sun (129) then skip the
 AND #%10000001         \ next instruction, otherwise return from the subroutine
 CMP #129               \ as we don't need to rotate the sun around its origin.
 BNE P%+3               \ Having both the AND and the CMP is a little odd, as
                        \ the sun is the only ship type with bits 0 and 7 set,
                        \ so the AND has no effect and could be removed

 RTS                    \ Return from the subroutine, as the ship we are moving
                        \ is the sun and doesn't need any of the following

\ ******************************************************************************
\
\       Name: MVEIT (Part 7 of 9)
\       Type: Subroutine
\   Category: Moving
\    Summary: Move current ship: Rotate ship's orientation vectors by pitch/roll
\  Deep dive: Orientation vectors
\             Pitching and rolling
\
\ ------------------------------------------------------------------------------
\
\ This routine has multiple stages. This stage does the following:
\
\   * Rotate the ship's orientation vectors according to our pitch and roll
\
\ As with the previous step, this is all about moving the other ships rather
\ than us (even though we are the one doing the moving). So we rotate the
\ current ship's orientation vectors (which defines its orientation in space),
\ by the angles we are "moving" the rest of the sky through (alpha and beta, our
\ roll and pitch), so the ship appears to us to be stationary while we rotate.
\
\ ******************************************************************************

 LDY #9                 \ Apply our pitch and roll rotations to the current
 JSR MVS4               \ ship's nosev vector

 LDY #15                \ Apply our pitch and roll rotations to the current
 JSR MVS4               \ ship's roofv vector

 LDY #21                \ Apply our pitch and roll rotations to the current
 JSR MVS4               \ ship's sidev vector

\ ******************************************************************************
\
\       Name: MVEIT (Part 8 of 9)
\       Type: Subroutine
\   Category: Moving
\    Summary: Move current ship: Rotate ship about itself by its own pitch/roll
\  Deep dive: Orientation vectors
\             Pitching and rolling by a fixed angle
\
\ ------------------------------------------------------------------------------
\
\ This routine has multiple stages. This stage does the following:
\
\   * If the ship we are processing is rolling or pitching itself, rotate it and
\     apply damping if required
\
\ ******************************************************************************

 LDA INWK+30            \ Fetch the ship's pitch counter and extract the sign
 AND #%10000000         \ into RAT2
 STA RAT2

 LDA INWK+30            \ Fetch the ship's pitch counter and extract the value
 AND #%01111111         \ without the sign bit into A

 BEQ MV8                \ If the pitch counter is 0, then jump to MV8 to skip
                        \ the following, as the ship is not pitching

 CMP #%01111111         \ If bits 0-6 are set in the pitch counter (i.e. the
                        \ ship's pitch is not damping down), then the C flag
                        \ will be set by this instruction

 SBC #0                 \ Set A = A - 0 - (1 - C), so if we are damping then we
                        \ reduce A by 1, otherwise it is unchanged

 ORA RAT2               \ Change bit 7 of A to the sign we saved in RAT2, so
                        \ the updated pitch counter in A retains its sign

 STA INWK+30            \ Store the updated pitch counter in byte #30

 LDX #15                \ Rotate (roofv_x, nosev_x) by a small angle (pitch)
 LDY #9
 JSR MVS5

 LDX #17                \ Rotate (roofv_y, nosev_y) by a small angle (pitch)
 LDY #11
 JSR MVS5

 LDX #19                \ Rotate (roofv_z, nosev_z) by a small angle (pitch)
 LDY #13
 JSR MVS5

.MV8

 LDA INWK+29            \ Fetch the ship's roll counter and extract the sign
 AND #%10000000         \ into RAT2
 STA RAT2

 LDA INWK+29            \ Fetch the ship's roll counter and extract the value
 AND #%01111111         \ without the sign bit into A

 BEQ MV5                \ If the roll counter is 0, then jump to MV5 to skip the
                        \ following, as the ship is not rolling

 CMP #%01111111         \ If bits 0-6 are set in the roll counter (i.e. the
                        \ ship's roll is not damping down), then the C flag
                        \ will be set by this instruction

 SBC #0                 \ Set A = A - 0 - (1 - C), so if we are damping then we
                        \ reduce A by 1, otherwise it is unchanged

 ORA RAT2               \ Change bit 7 of A to the sign we saved in RAT2, so
                        \ the updated roll counter in A retains its sign

 STA INWK+29            \ Store the updated pitch counter in byte #29

 LDX #15                \ Rotate (roofv_x, sidev_x) by a small angle (roll)
 LDY #21
 JSR MVS5

 LDX #17                \ Rotate (roofv_y, sidev_y) by a small angle (roll)
 LDY #23
 JSR MVS5

 LDX #19                \ Rotate (roofv_z, sidev_z) by a small angle (roll)
 LDY #25
 JSR MVS5

\ ******************************************************************************
\
\       Name: MVEIT (Part 9 of 9)
\       Type: Subroutine
\   Category: Moving
\    Summary: Move current ship: Redraw on scanner, if it hasn't been destroyed
\
\ ------------------------------------------------------------------------------
\
\ This routine has multiple stages. This stage does the following:
\
\   * If the ship is exploding or being removed, hide it on the scanner
\
\   * Otherwise redraw the ship on the scanner, now that it's been moved
\
\ ******************************************************************************

.MV5

 LDA INWK+31            \ Fetch the ship's exploding/killed state from byte #31

 AND #%10100000         \ If we are exploding or removing this ship then jump to
 BNE MVD1               \ MVD1 to remove it from the scanner permanently

 LDA INWK+31            \ Set bit 4 to keep the ship visible on the scanner
 ORA #%00010000
 STA INWK+31

 JMP SCAN               \ Display the ship on the scanner, returning from the
                        \ subroutine using a tail call

.MVD1

 LDA INWK+31            \ Clear bit 4 to hide the ship on the scanner
 AND #%11101111
 STA INWK+31

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: MVT1
\       Type: Subroutine
\   Category: Moving
\    Summary: Calculate (x_sign x_hi x_lo) = (x_sign x_hi x_lo) + (A R)
\
\ ------------------------------------------------------------------------------
\
\ Add the signed delta (A R) to a ship's coordinate, along the axis given in X.
\ Mathematically speaking, this routine translates the ship along a single axis
\ by a signed delta. Taking the example of X = 0, the x-axis, it does the
\ following:
\
\   (x_sign x_hi x_lo) = (x_sign x_hi x_lo) + (A R)
\
\ (In practice, MVT1 is only ever called directly with A = 0 or 128, otherwise
\ it is always called via MVT-2, which clears A apart from the sign bit. The
\ routine is written to cope with a non-zero delta_hi, so it supports a full
\ 16-bit delta, but it appears that delta_hi is only ever used to hold the
\ sign of the delta.)
\
\ The comments below assume we are adding delta to the x-axis, though the axis
\ is determined by the value of X.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   (A R)               The signed delta, so A = delta_hi and R = delta_lo
\
\   X                   Determines which coordinate axis of INWK to change:
\
\                         * X = 0 adds the delta to (x_lo, x_hi, x_sign)
\
\                         * X = 3 adds the delta to (y_lo, y_hi, y_sign)
\
\                         * X = 6 adds the delta to (z_lo, z_hi, z_sign)
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   MVT1-2              Clear bits 0-6 of A before entering MVT1
\
\ ******************************************************************************

 AND #%10000000         \ Clear bits 0-6 of A

.MVT1

 ASL A                  \ Set the C flag to the sign bit of the delta, leaving
                        \ delta_hi << 1 in A

 STA S                  \ Set S = delta_hi << 1
                        \
                        \ This also clears bit 0 of S

 LDA #0                 \ Set T = just the sign bit of delta (in bit 7)
 ROR A
 STA T

 LSR S                  \ Set S = delta_hi >> 1
                        \       = |delta_hi|
                        \
                        \ This also clear the C flag, as we know that bit 0 of
                        \ S was clear before the LSR

 EOR INWK+2,X           \ If T EOR x_sign has bit 7 set, then x_sign and delta
 BMI MV10               \ have different signs, so jump to MV10

                        \ At this point, we know x_sign and delta have the same
                        \ sign, that sign is in T, and S contains |delta_hi|,
                        \ so now we want to do:
                        \
                        \   (x_sign x_hi x_lo) = (x_sign x_hi x_lo) + (S R)
                        \
                        \ and then set the sign of the result to the same sign
                        \ as x_sign and delta

 LDA R                  \ First we add the low bytes, so:
 ADC INWK,X             \
 STA INWK,X             \   x_lo = x_lo + R

 LDA S                  \ Then we add the high bytes:
 ADC INWK+1,X           \
 STA INWK+1,X           \   x_hi = x_hi + S

 LDA INWK+2,X           \ And finally we add any carry into x_sign, and if the
 ADC #0                 \ sign of x_sign and delta in T is negative, make sure
 ORA T                  \ the result is negative (by OR'ing with T)
 STA INWK+2,X

 RTS                    \ Return from the subroutine

.MV10

                        \ If we get here, we know x_sign and delta have
                        \ different signs, with delta's sign in T, and
                        \ |delta_hi| in S, so now we want to do:
                        \
                        \   (x_sign x_hi x_lo) = (x_sign x_hi x_lo) - (S R)
                        \
                        \ and then set the sign of the result according to
                        \ the signs of x_sign and delta

 LDA INWK,X             \ First we subtract the low bytes, so:
 SEC                    \
 SBC R                  \   x_lo = x_lo - R
 STA INWK,X

 LDA INWK+1,X           \ Then we subtract the high bytes:
 SBC S                  \
 STA INWK+1,X           \   x_hi = x_hi - S

 LDA INWK+2,X           \ And finally we subtract any borrow from bits 0-6 of
 AND #%01111111         \ x_sign, and give the result the opposite sign bit to T
 SBC #0                 \ (i.e. give it the sign of the original x_sign)
 ORA #%10000000
 EOR T
 STA INWK+2,X

 BCS MV11               \ If the C flag is set by the above SBC, then our sum
                        \ above didn't underflow and is correct - to put it
                        \ another way, (x_sign x_hi x_lo) >= (S R) so the result
                        \ should indeed have the same sign as x_sign, so jump to
                        \ MV11 to return from the subroutine

                        \ Otherwise our subtraction underflowed because
                        \ (x_sign x_hi x_lo) < (S R), so we now need to flip the
                        \ subtraction around by using two's complement to this:
                        \
                        \   (S R) - (x_sign x_hi x_lo)
                        \
                        \ and then we need to give the result the same sign as
                        \ (S R), the delta, as that's the dominant figure in the
                        \ sum

 LDA #1                 \ First we subtract the low bytes, so:
 SBC INWK,X             \
 STA INWK,X             \   x_lo = 1 - x_lo

 LDA #0                 \ Then we subtract the high bytes:
 SBC INWK+1,X           \
 STA INWK+1,X           \   x_hi = 0 - x_hi

 LDA #0                 \ And then we subtract the sign bytes:
 SBC INWK+2,X           \
                        \   x_sign = 0 - x_sign

 AND #%01111111         \ Finally, we set the sign bit to the sign in T, the
 ORA T                  \ sign of the original delta, as the delta is the
 STA INWK+2,X           \ dominant figure in the sum

.MV11

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: MVS4
\       Type: Subroutine
\   Category: Moving
\    Summary: Apply pitch and roll to an orientation vector
\  Deep dive: Orientation vectors
\             Pitching and rolling
\
\ ------------------------------------------------------------------------------
\
\ Apply pitch and roll angles alpha and beta to the orientation vector in Y.
\
\ Specifically, this routine rotates a point (x, y, z) around the origin by
\ pitch alpha and roll beta, using the small angle approximation to make the
\ maths easier, and incorporating the Minsky circle algorithm to make the
\ rotation more stable (though more elliptic).
\
\ If that paragraph makes sense to you, then you should probably be writing
\ this commentary! For the rest of us, see the associated deep dives.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   Y                   Determines which of the INWK orientation vectors to
\                       transform:
\
\                         * Y = 9 rotates nosev: (nosev_x, nosev_y, nosev_z)
\
\                         * Y = 15 rotates roofv: (roofv_x, roofv_y, roofv_z)
\
\                         * Y = 21 rotates sidev: (sidev_x, sidev_y, sidev_z)
\
\ ******************************************************************************

.MVS4

 LDA ALPHA              \ Set Q = alpha (the roll angle to rotate through)
 STA Q

 ASL A                  \ Port: if |alpha| = 0 (alpha = 0 or &80) and nosev_y
 BNE mvs4a              \ is not -0 (nosev_y_hi <> &80), then the first MAD
 LDA INWK+3,Y           \ below leaves nosev_y unchanged, and everything else
 CMP #%10000000         \ it writes (A, X, flags, P, T, T1, R, S) is written
 BNE mvs4b              \ again by the second MAD (with Q = 0 it ignores A),
                        \ so skip straight to the second MAD

.mvs4a

 LDX INWK+2,Y           \ Set (S R) = nosev_y
 STX R
 LDX INWK+3,Y
 STX S

                        \ Port: the original's dead LDX INWK,Y and STX P
                        \ (MAD overwrites X and P) are dropped here

 LDA INWK+1,Y           \ Set A = -nosev_x_hi
 EOR #%10000000

 JSR MAD                \ Set (A X) = Q * A + (S R)
 STA INWK+3,Y           \           = alpha * -nosev_x_hi + nosev_y
 STX INWK+2,Y           \
                        \ and store (A X) in nosev_y, so this does:
                        \
                        \ nosev_y = nosev_y - alpha * nosev_x_hi

                        \ Port: the original's dead STX P (MAD sets P before
                        \ reading it) is dropped here

.mvs4b

 LDX INWK,Y             \ Set (S R) = nosev_x
 STX R
 LDX INWK+1,Y
 STX S

                        \ Port: A = nosev_y_hi still, from the STA above

 JSR MAD                \ Set (A X) = Q * A + (S R)
 STA INWK+1,Y           \           = alpha * nosev_y_hi + nosev_x
 STX INWK,Y             \
                        \ and store (A X) in nosev_x, so this does:
                        \
                        \ nosev_x = nosev_x + alpha * nosev_y_hi

                        \ Port: the original's dead STX P (MAD sets P before
                        \ reading it) and LDX INWK+4,Y are dropped here

 LDA BETA               \ Set Q = beta (the pitch angle to rotate through)
 STA Q

 ASL A                  \ Port: if |beta| = 0 (beta = 0 or &80) and nosev_y
 BNE mvs4c              \ is not -0 (nosev_y_hi <> &80), then the next MAD
 LDA INWK+3,Y           \ leaves nosev_y unchanged, and everything else it
 CMP #%10000000         \ writes (A, X, flags, P, T, T1, R, S) is written
 BNE mvs4d              \ again by the last MAD (with Q = 0 it ignores A),
                        \ so skip straight to the last MAD

.mvs4c

 LDX INWK+2,Y           \ Set (S R) = nosev_y
 STX R
 LDX INWK+3,Y
 STX S

 LDA INWK+5,Y           \ Set A = -nosev_z_hi
 EOR #%10000000

 JSR MAD                \ Set (A X) = Q * A + (S R)
 STA INWK+3,Y           \           = beta * -nosev_z_hi + nosev_y
 STX INWK+2,Y           \
                        \ and store (A X) in nosev_y, so this does:
                        \
                        \ nosev_y = nosev_y - beta * nosev_z_hi

.mvs4d

 LDX INWK+4,Y           \ Set (S R) = nosev_z
 STX R
 LDX INWK+5,Y
 STX S

                        \ Port: A = nosev_y_hi still, from the STA above

 JSR MAD                \ Set (A X) = Q * A + (S R)
 STA INWK+5,Y           \           = beta * nosev_y_hi + nosev_z
 STX INWK+4,Y           \
                        \ and store (A X) in nosev_z, so this does:
                        \
                        \ nosev_z = nosev_z + beta * nosev_y_hi

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: MVT6
\       Type: Subroutine
\   Category: Moving
\    Summary: Calculate (A P+2 P+1) = (x_sign x_hi x_lo) + (A P+2 P+1)
\
\ ------------------------------------------------------------------------------
\
\ Do the following calculation, for the coordinate given by X (so this is what
\ it does for the x-coordinate):
\
\   (A P+2 P+1) = (x_sign x_hi x_lo) + (A P+2 P+1)
\
\ A is a sign bit and is not included in the calculation, but bits 0-6 of A are
\ preserved. Bit 7 is set to the sign of the result.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The sign of P(2 1) in bit 7
\
\   P(2 1)              The 16-bit value we want to add the coordinate to
\
\   X                   The coordinate to add, as follows:
\
\                         * If X = 0, add to (x_sign x_hi x_lo)
\
\                         * If X = 3, add to (y_sign y_hi y_lo)
\
\                         * If X = 6, add to (z_sign z_hi z_lo)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   The sign of the result (in bit 7)
\
\ ******************************************************************************

.MVT6

 TAY                    \ Store argument A into Y, for later use

 EOR INWK+2,X           \ Set A = A EOR x_sign

 BMI MV50               \ If the sign is negative, i.e. A and x_sign have
                        \ different signs, jump to MV50

                        \ The signs are the same, so we can add the two
                        \ arguments and keep the sign to get the result

 LDA P+1                \ First we add the low bytes:
 CLC                    \
 ADC INWK,X             \   P+1 = P+1 + x_lo
 STA P+1

 LDA P+2                \ And then the high bytes:
 ADC INWK+1,X           \
 STA P+2                \   P+2 = P+2 + x_hi

 TYA                    \ Restore the original A argument that we stored earlier
                        \ so that we keep the original sign

 RTS                    \ Return from the subroutine

.MV50

 LDA INWK,X             \ First we subtract the low bytes:
 SEC                    \
 SBC P+1                \   P+1 = x_lo - P+1
 STA P+1

 LDA INWK+1,X           \ And then the high bytes:
 SBC P+2                \
 STA P+2                \   P+2 = x_hi - P+2

 BCC MV51               \ If the last subtraction underflowed, then the C flag
                        \ will be clear and x_hi < P+2, so jump to MV51 to
                        \ negate the result

 TYA                    \ Restore the original A argument that we stored earlier
 EOR #%10000000         \ but flip bit 7, which flips the sign. We do this
                        \ because x_hi >= P+2 so we want the result to have the
                        \ same sign as x_hi (as it's the dominant side in this
                        \ calculation). The sign of x_hi is x_sign, and x_sign
                        \ has the opposite sign to A, so we flip the sign in A
                        \ to return the correct result

 RTS                    \ Return from the subroutine

.MV51

 LDA #1                 \ Our subtraction underflowed, so we negate the result
 SBC P+1                \ using two's complement, first with the low byte:
 STA P+1                \
                        \   P+1 = 1 - P+1

 LDA #0                 \ And then the high byte:
 SBC P+2                \
 STA P+2                \   P+2 = 0 - P+2

 TYA                    \ Restore the original A argument that we stored earlier
                        \ as this is the correct sign for the result. This is
                        \ because x_hi < P+2, so we want to return the same sign
                        \ as P+2, the dominant side

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: PLUT
\       Type: Subroutine
\   Category: Flight
\    Summary: Flip the coordinate axes for the four different views
\  Deep dive: Flipping axes between space views
\
\ ------------------------------------------------------------------------------
\
\ This routine flips the relevant geometric axes in INWK depending on which
\ view we are looking through (front, rear, left, right).
\
\ ******************************************************************************

.PLUT

 LDX VIEW               \ Load the current view into X:
                        \
                        \   0 = front
                        \   1 = rear
                        \   2 = left
                        \   3 = right

 BEQ PU2-1              \ If the current view is the front view, return from the
                        \ subroutine (PU2-1 contains an RTS), as the geometry in
                        \ INWK is already correct

.PU1

 DEX                    \ Decrement the view, so now:
                        \
                        \   0 = rear
                        \   1 = left
                        \   2 = right

 BNE PU2                \ If the current view is left or right, jump to PU2,
                        \ otherwise this is the rear view, so continue on

 LDA INWK+2             \ Flip the sign of x_sign
 EOR #%10000000
 STA INWK+2

 LDA INWK+8             \ Flip the sign of z_sign
 EOR #%10000000
 STA INWK+8

 LDA INWK+10            \ Flip the sign of nosev_x_hi
 EOR #%10000000
 STA INWK+10

 LDA INWK+14            \ Flip the sign of nosev_z_hi
 EOR #%10000000
 STA INWK+14

 LDA INWK+16            \ Flip the sign of roofv_x_hi
 EOR #%10000000
 STA INWK+16

 LDA INWK+20            \ Flip the sign of roofv_z_hi
 EOR #%10000000
 STA INWK+20

 LDA INWK+22            \ Flip the sign of sidev_x_hi
 EOR #%10000000
 STA INWK+22

 LDA INWK+26            \ Flip the sign of roofv_z_hi
 EOR #%10000000
 STA INWK+26

 RTS                    \ Return from the subroutine

.PU2

                        \ We enter this with X set to the view, as follows:
                        \
                        \   1 = left
                        \   2 = right

 LDA #0                 \ Set RAT2 = 0 (left view) or -1 (right view)
 CPX #2
 ROR A
 STA RAT2

 EOR #%10000000         \ Set RAT = -1 (left view) or 0 (right view)
 STA RAT

 LDA INWK               \ Swap x_lo and z_lo
 LDX INWK+6
 STA INWK+6
 STX INWK

 LDA INWK+1             \ Swap x_hi and z_hi
 LDX INWK+7
 STA INWK+7
 STX INWK+1

 LDA INWK+2             \ Swap x_sign and z_sign
 EOR RAT                \ If left view, flip sign of new z_sign
 TAX                    \ If right view, flip sign of new x_sign
 LDA INWK+8
 EOR RAT2
 STA INWK+2
 STX INWK+8

 LDY #9                 \ Swap nosev_x_lo and nosev_z_lo
 JSR PUS1               \ Swap nosev_x_hi and nosev_z_hi
                        \ If left view, flip sign of new nosev_z_hi
                        \ If right view, flip sign of new nosev_x_hi

 LDY #15                \ Swap roofv_x_lo and roofv_z_lo
 JSR PUS1               \ Swap roofv_x_hi and roofv_z_hi
                        \ If left view, flip sign of new roofv_z_hi
                        \ If right view, flip sign of new roofv_x_hi

 LDY #21                \ Swap sidev_x_lo and sidev_z_lo
                        \ Swap sidev_x_hi and sidev_z_hi
                        \ If left view, flip sign of new sidev_z_hi
                        \ If right view, flip sign of new sidev_x_hi

.PUS1

 LDA INWK,Y             \ Swap the low x and z bytes for the vector in Y:
 LDX INWK+4,Y           \
 STA INWK+4,Y           \   * For Y =  9 swap nosev_x_lo and nosev_z_lo
 STX INWK,Y             \   * For Y = 15 swap roofv_x_lo and roofv_z_lo
                        \   * For Y = 21 swap sidev_x_lo and sidev_z_lo

 LDA INWK+1,Y           \ Swap the high x and z bytes for the offset in Y:
 EOR RAT                \
 TAX                    \   * If left view, flip sign of new z-coordinate
 LDA INWK+5,Y           \   * If right view, flip sign of new x-coordinate
 EOR RAT2
 STA INWK+1,Y
 STX INWK+5,Y

                        \ Fall through into LOOK1 to return from the subroutine

\ ******************************************************************************
\
\       Name: LOOK1
\       Type: Subroutine
\   Category: Flight
\    Summary: Initialise the space view
\
\ ------------------------------------------------------------------------------
\
\ Initialise the space view, with the direction of view given in X. This clears
\ the upper screen and draws the laser crosshairs, if the view in X has lasers
\ fitted. It also wipes all the ships from the scanner, so we can recalculate
\ ship positions for the new view (they get put back in the main flight loop).
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The space view to set:
\
\                         * 0 = front
\                         * 1 = rear
\                         * 2 = left
\                         * 3 = right
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   LO2                 Contains an RTS
\
\ ******************************************************************************

.LO2

 RTS                    \ Return from the subroutine

.LQ

 STX VIEW               \ Set the current space view to X

 JSR TT66               \ Clear the top part of the screen, draw a border box,
                        \ and set the current view type in QQ11 to 0 (space
                        \ view)

 JSR SIGHT              \ Draw the laser crosshairs

 LDA BOMB               \ If our energy bomb has been set off, then BOMB will be
 BPL P%+5               \ negative, so this skips the following instruction if
                        \ our energy bomb is not going off

 JSR BOMBOFF            \ Our energy bomb is going off, so call BOMBOFF to draw
                        \ the zig-zag lightning bolt

 JMP NWSTARS            \ Set up a new stardust field and return from the
                        \ subroutine using a tail call

.LOOK1

 LDA #0                 \ Set A = 0, the type number of a space view

 JSR DOVDU19            \ Switch to the mode 1 palette for the space view,
                        \ which is yellow (colour 1), red (colour 2) and cyan
                        \ (colour 3)

 LDY QQ11               \ If the current view is not a space view, jump up to LQ
 BNE LQ                 \ to set up a new space view

 CPX VIEW               \ If the current view is already of type X, jump to LO2
 BEQ LO2                \ to return from the subroutine (as LO2 contains an RTS)

 STX VIEW               \ Change the current space view to X

 JSR TT66               \ Clear the top part of the screen, draw a border box,
                        \ and set the current view type in QQ11 to 0 (space
                        \ view)

 JSR FLIP               \ Swap the x- and y-coordinates of all the stardust
                        \ particles and redraw the stardust field

 LDA BOMB               \ If our energy bomb has been set off, then BOMB will be
 BPL P%+5               \ negative, so this skips the following instruction if
                        \ our energy bomb is not going off

 JSR BOMBOFF            \ Our energy bomb is going off, so call BOMBOFF to draw
                        \ the zig-zag lightning bolt

 JSR WPSHPS             \ Wipe all the ships from the scanner and mark them all
                        \ as not being shown on-screen

                        \ And fall through into SIGHT to draw the laser
                        \ crosshairs

\ ******************************************************************************
\
\       Name: DEATH
\       Type: Subroutine
\   Category: Start and end
\    Summary: Display the death screen
\
\ ------------------------------------------------------------------------------
\
\ We have been killed, so display the chaos of our destruction above a "GAME
\ OVER" sign, and clean up the mess ready for the next attempt.
\
\ ******************************************************************************

.DEATH

 LDY #soexpl            \ Call the NOISE routine with Y = 4 to make the sound of
 JSR NOISE              \ us dying

 JSR RES2               \ Reset a number of flight variables and workspaces

 ASL DELTA              \ Divide our speed in DELTA by 4
 ASL DELTA

 LDX #24                \ Set the screen to only show 24 text rows, which hides
 JSR DET1               \ the dashboard, setting A to 6 in the process

 LDA #13                \ Clear the top part of the screen, draw a border box,
 JSR TT66               \ and set the current view type in QQ11 to 13 (which
                        \ is not a space view, though I'm not quite sure why
                        \ this value is chosen, as it gets overwritten by the
                        \ next instruction anyway)

 STZ QQ11               \ Set QQ11 to 0, so from here on we are using a space
                        \ view

 JSR BOX                \ Call BOX to redraw the same border box (BOX is part
                        \ of TT66), which removes the border as it is drawn
                        \ using EOR logic

 JSR nWq                \ Create a cloud of stardust containing the correct
                        \ number of dust particles (i.e. NOSTM of them)

 LDA #CYAN              \ Change the current colour to cyan
 STA COL

 LDA #12                \ Move the text cursor to column 12 on row 12
 STA XC
 STA YC

 LDA #146               \ Print recursive token 146 ("{all caps}GAME OVER")
 JSR ex

.D1

 JSR Ze                 \ Call Ze to initialise INWK to a fairly aggressive
                        \ ship, and set A and X to random values

 LSR A                  \ Set A = A / 4, so A is now between 0 and 63, and
 LSR A                  \ store in byte #0 (x_lo)
 STA INWK

 LDY #0                 \ Set the following to 0: x_hi, y_hi, z_hi and the AI
 STY INWK+1             \ flag (no AI or E.C.M. and zero aggression)
 STY INWK+4
 STY INWK+7
 STY INWK+32

 DEY                    \ Set Y = 255

 STY MCNT               \ Reset the main loop counter to 255, so all timer-based
                        \ calls will be stopped

 EOR #%00101010         \ Flip bits 1, 3 and 5 in A (x_lo) to get another number
 STA INWK+3             \ between 48 and 63, and store in byte #3 (y_lo)

 ORA #%01010000         \ Set bits 4 and 6 of A to bump it up to between 112 and
 STA INWK+6             \ 127, and store in byte #6 (z_lo)

 TXA                    \ Set A to the random number in X and keep bits 0-3 and
 AND #%10001111         \ the sign in bit 7 to get a number between -15 and +15,
 STA INWK+29            \ and store in byte #29 (roll counter) to give our ship
                        \ a gentle roll with damping

 LDY #64                \ Set the laser count to 64 to act as a counter in the
 STY LASCT              \ D2 loop below, so this setting determines how long the
                        \ death animation lasts (it's 64 * 2 iterations of the
                        \ main flight loop)

 SEC                    \ Set the C flag

 ROR A                  \ This sets A to a number between 0 and +7, which we
 AND #%10000111         \ store in byte #30 (the pitch counter) to give our ship
 STA INWK+30            \ a very gentle downwards pitch with damping

 LDX #OIL               \ Set X to #OIL, the ship type for a cargo canister

 LDA XX21-1+2*PLT       \ Fetch the byte from location XX21 - 1 + 2 * PLT, which
                        \ equates to XX21 + 7 (the high byte of the address of
                        \ SHIP_PLATE), which seems a bit odd. It might make more
                        \ sense to do LDA (XX21-2+2*PLT) as this would fetch the
                        \ first byte of the alloy plate's blueprint (which
                        \ determines what happens when alloys are destroyed),
                        \ but there aren't any brackets, so instead this always
                        \ returns &D0, which is never zero, so the following
                        \ BEQ is never true. (If the brackets were there, then
                        \ we could stop plates from spawning on death by setting
                        \ byte #0 of the blueprint to 0... but then scooping
                        \ plates wouldn't give us alloys, so who knows what this
                        \ is all about?)

 BEQ D3                 \ If A = 0, jump to D3 to skip the following instruction

 BCC D3                 \ If the C flag is clear, which will be random following
                        \ the above call to Ze, jump to D3 to skip the following
                        \ instruction

 DEX                    \ Decrement X, which sets it to #PLT, the ship type for
                        \ an alloy plate

.D3

 JSR fq1                \ Call fq1 with X set to #OIL or #PLT, which adds a new
                        \ cargo canister or alloy plate to our local bubble of
                        \ universe and points it away from us with double DELTA
                        \ speed (i.e. 6, as DELTA was set to 3 by the call to
                        \ RES2 above). INF is set to point to the new arrival's
                        \ ship data block in K%

 JSR DORND              \ Set A and X to random numbers and extract bit 7 from A
 AND #%10000000

 LDY #31                \ Store this in byte #31 of the ship's data block, so it
 STA (INF),Y            \ has a 50% chance of marking our new arrival as being
                        \ killed (so it will explode)

 LDA FRIN+4             \ The call we made to RES2 before we entered the loop at
 BEQ D1                 \ D1 will have reset all the ship slots at FRIN, so this
                        \ checks to see if the fifth slot is empty, and if it
                        \ is we loop back to D1 to add another canister, until
                        \ we have added five of them

\JSR U%                 \ This instruction is commented out in the original
                        \ source

 LDA #0                 \ Set our speed in DELTA to 0, as we aren't going
 STA DELTA              \ anywhere any more

 JSR H_MFRAME           \ Call the M% routine to do the main flight loop once,
                        \ then the frame (Port: the renderer, gfx-hooks.asm),
                        \ which will display our exploding canister scene and
                        \ move everything about, as well as decrementing the
                        \ value in LASCT

\JSR NOSPRITES          \ This instruction is commented out in the original
                        \ source

.D2

 JSR H_MFRAME           \ Call the M% routine to do the main flight loop once,
                        \ then the frame (Port: the renderer, gfx-hooks.asm),
                        \ which will display our exploding canister scene and
                        \ move everything about, as well as decrementing the
                        \ value in LASCT

 DEC LASCT              \ Decrement the counter in LASCT, which we set above,
                        \ so for each loop around D2, we decrement LASCT by 5
                        \ (the main loop decrements it by 4, and this one makes
                        \ it 5)

 BNE D2                 \ Loop back to call the main flight loop again, until we
                        \ have called it 127 times

 LDX #31                \ Set the screen to show all 31 text rows, which shows
 JSR DET1               \ the dashboard

 JMP DEATH2             \ Jump to DEATH2 to reset and restart the game
