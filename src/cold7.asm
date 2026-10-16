\ ******************************************************************************
\
\ cold7.asm - Elite's cold code, in sideways RAM bank 7
\
\ INCLUDEd by gfx-build.asm in bank 7 after the rasteriser's cold code
\ (raster7.asm). These routines were moved out of the main code and bank 4 to
\ free space there: they are never run in the flight loop's hot paths (docked
\ screens, charts, the market and equipment screens, hyperspace and launch
\ set-up, the title screen, ...).
\
\ Every label here is the original label with the suffix _7. Code outside bank 7
\ calls these routines through stubs with the original names (JSR far7 : EQUW
\ name_7, see far7.asm), and code here reaches anything outside bank 7 through
\ the x4_ (call) and j4_ (jump, never returns) stubs at the end of this file.
\ Nothing here may read data in bank 4 (it is not paged in while this code runs).
\
\ ******************************************************************************

\ ---- moved from elite-source.asm lines 7267-7547 (main RAM) ----
\ ******************************************************************************
\
\       Name: NA%
\       Type: Variable
\   Category: Save and load
\    Summary: The data block for the last saved commander
\  Deep dive: Commander save files
\             The competition code
\
\ ------------------------------------------------------------------------------
\
\ Contains the last saved commander data, with the name at NA% and the data at
\ NA%+8 onwards. The size of the data block is given in NT% (which also includes
\ the two checksum bytes that follow this block). This block is initially set up
\ with the default commander, which can be maxed out for testing purposes by
\ setting Q% to TRUE.
\
\ The commander's name is stored at NA%, and can be up to 7 characters long
\ (the DFS filename limit). It is terminated with a carriage return character,
\ ASCII 13.
\
\ The offset of each byte within a saved commander file is also shown as #0, #1
\ and so on, so the kill tally, for example, is in bytes #71 and #72 of the
\ saved file. The related variable name from the current commander block is
\ also shown.
\
\ ******************************************************************************

.NA_7%

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\EQUS "JAMESON"         \ The current commander name, which defaults to JAMESON
\EQUB 13                \
\                       \ The commander name can be up to seven characters (the
\                       \ DFS limit for filenames), and is terminated by a
\                       \ carriage return

                        \ --- And replaced by: -------------------------------->

 EQUS "DISPLAY"         \ The current commander name, which defaults to DISPLAY
 EQUB 13                \
                        \ The commander name can be up to seven characters (the
                        \ DFS limit for filenames), and is terminated by a
                        \ carriage return

                        \ --- End of replacement ------------------------------>

                        \ NA%+8 is the start of the commander data block
                        \
                        \ This block contains the last saved commander data
                        \ block. As the game is played it uses an identical
                        \ block at location TP to store the current commander
                        \ state, and that block is copied here when the game is
                        \ saved. Conversely, when the game starts up, the block
                        \ here is copied to TP, which restores the last saved
                        \ commander when we die
                        \
                        \ The initial state of this block defines the default
                        \ commander. Q% can be set to TRUE to give the default
                        \ commander lots of credits and equipment

 EQUB 0                 \ TP = Mission status, #0

 EQUB 20                \ QQ0 = Current system X-coordinate (Lave), #1
 EQUB 173               \ QQ1 = Current system Y-coordinate (Lave), #2

 EQUW &5A4A             \ QQ21 = Seed s0 for system 0, galaxy 0 (Tibedied), #3-4
 EQUW &0248             \ QQ21 = Seed s1 for system 0, galaxy 0 (Tibedied), #5-6
 EQUW &B753             \ QQ21 = Seed s2 for system 0, galaxy 0 (Tibedied), #7-8

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\IF Q%
\EQUD &00CA9A3B         \ CASH = Amount of cash (100,000,000 Cr), #9-12
\ELSE
\EQUD &E8030000         \ CASH = Amount of cash (100 Cr), #9-12
\ENDIF
\
\EQUB 70                \ QQ14 = Fuel level, #13

                        \ --- And replaced by: -------------------------------->

 EQUD &88130000         \ CASH = Amount of cash (500 Cr), #9-12

 EQUB 20                \ QQ14 = Fuel level, #13

                        \ --- End of replacement ------------------------------>

 EQUB 0                 \ COK = Competition flags, #14

 EQUB 0                 \ GCNT = Galaxy number, 0-7, #15

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\EQUB POW+(128 AND Q%)  \ LASER = Front laser, #16
\
\IF _STH_CASSETTE OR _TEXT_SOURCES
\
\EQUB (POW+128) AND Q%  \ LASER+1 = Rear laser, #17
\
\ELIF _SOURCE_DISC
\
\EQUB POW               \ LASER+1 = Rear laser, #17
\
\ENDIF

                        \ --- And replaced by: -------------------------------->

 EQUB POW               \ LASER = Front laser, #16

 EQUB POW               \ LASER+1 = Rear laser, #17

                        \ --- End of replacement ------------------------------>

 EQUB 0                 \ LASER+2 = Left laser, #18

 EQUB 0                 \ LASER+3 = Right laser, #19

 EQUW 0                 \ These bytes appear to be unused (they were originally
                        \ used for up/down lasers, but they were dropped),
                        \ #20-21

 EQUB 22 + (15 AND Q%)  \ CRGO = Cargo capacity, #22

 EQUB 0                 \ QQ20+0  = Amount of food in cargo hold, #23
 EQUB 0                 \ QQ20+1  = Amount of textiles in cargo hold, #24
 EQUB 0                 \ QQ20+2  = Amount of radioactives in cargo hold, #25
 EQUB 0                 \ QQ20+3  = Amount of slaves in cargo hold, #26
 EQUB 0                 \ QQ20+4  = Amount of liquor/Wines in cargo hold, #27
 EQUB 0                 \ QQ20+5  = Amount of luxuries in cargo hold, #28
 EQUB 0                 \ QQ20+6  = Amount of narcotics in cargo hold, #29
 EQUB 0                 \ QQ20+7  = Amount of computers in cargo hold, #30
 EQUB 0                 \ QQ20+8  = Amount of machinery in cargo hold, #31
 EQUB 0                 \ QQ20+9  = Amount of alloys in cargo hold, #32
 EQUB 0                 \ QQ20+10 = Amount of firearms in cargo hold, #33
 EQUB 0                 \ QQ20+11 = Amount of furs in cargo hold, #34
 EQUB 0                 \ QQ20+12 = Amount of minerals in cargo hold, #35
 EQUB 0                 \ QQ20+13 = Amount of gold in cargo hold, #36
 EQUB 0                 \ QQ20+14 = Amount of platinum in cargo hold, #37
 EQUB 0                 \ QQ20+15 = Amount of gem-stones in cargo hold, #38
 EQUB 0                 \ QQ20+16 = Amount of alien items in cargo hold, #39

 EQUB Q%                \ ECM = E.C.M. system, #40

 EQUB Q%                \ BST = Fuel scoops ("barrel status"), #41

 EQUB Q% AND 127        \ BOMB = Energy bomb, #42

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\EQUB Q% AND 1          \ ENGY = Energy/shield level, #43

                        \ --- And replaced by: -------------------------------->

 EQUB 1                 \ ENGY = Energy/shield level, #43

                        \ --- End of replacement ------------------------------>

 EQUB Q%                \ DKCMP = Docking computer, #44

 EQUB Q%                \ GHYP = Galactic hyperdrive, #45

 EQUB Q%                \ ESCP = Escape pod, #46

 EQUD 0                 \ These four bytes appear to be unused, #47-50

 EQUB 3 + (Q% AND 1)    \ NOMSL = Number of missiles, #51

 EQUB 0                 \ FIST = Legal status ("fugitive/innocent status"), #52

 EQUB 16                \ AVL+0  = Market availability of food, #53
 EQUB 15                \ AVL+1  = Market availability of textiles, #54
 EQUB 17                \ AVL+2  = Market availability of radioactives, #55
 EQUB 0                 \ AVL+3  = Market availability of slaves, #56
 EQUB 3                 \ AVL+4  = Market availability of liquor/Wines, #57
 EQUB 28                \ AVL+5  = Market availability of luxuries, #58
 EQUB 14                \ AVL+6  = Market availability of narcotics, #59
 EQUB 0                 \ AVL+7  = Market availability of computers, #60
 EQUB 0                 \ AVL+8  = Market availability of machinery, #61
 EQUB 10                \ AVL+9  = Market availability of alloys, #62
 EQUB 0                 \ AVL+10 = Market availability of firearms, #63
 EQUB 17                \ AVL+11 = Market availability of furs, #64
 EQUB 58                \ AVL+12 = Market availability of minerals, #65
 EQUB 7                 \ AVL+13 = Market availability of gold, #66
 EQUB 9                 \ AVL+14 = Market availability of platinum, #67
 EQUB 8                 \ AVL+15 = Market availability of gem-stones, #68
 EQUB 0                 \ AVL+16 = Market availability of alien items, #69

 EQUB 0                 \ QQ26 = Random byte that changes for each visit to a
                        \ system, for randomising market prices, #70

 EQUW 0                 \ TALLY = Number of kills, #71-72

 EQUB 128               \ SVC = Save count, #73

\ ******************************************************************************
\
\       Name: CHK2
\       Type: Variable
\   Category: Save and load
\    Summary: Second checksum byte for the saved commander data file
\  Deep dive: Commander save files
\             The competition code
\
\ ------------------------------------------------------------------------------
\
\ Second commander checksum byte. If the default commander is changed, a new
\ checksum will be calculated and inserted by the elite-checksum.py script.
\
\ The offset of this byte within a saved commander file is also shown (it's at
\ byte #74).
\
\ ******************************************************************************

.CHK2_7

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\IF _STH_CASSETTE OR _TEXT_SOURCES
\
\EQUB &03 EOR &A9       \ The checksum value for the default commander, EOR'd
\                       \ with &A9 to make it harder to tamper with the checksum
\                       \ byte, #74
\
\ELIF _SOURCE_DISC
\
\EQUB &92 EOR &A9       \ The checksum value for the default commander from the
\                       \ source disc, EOR'd with &A9 to make it harder to
\                       \ tamper with the checksum byte, #74
\
\ENDIF

                        \ --- And replaced by: -------------------------------->

 EQUB &2D EOR &A9       \ The checksum value for the default commander, EOR'd
                        \ with &A9 to make it harder to tamper with the checksum
                        \ byte, #74

                        \ --- End of replacement ------------------------------>

\ ******************************************************************************
\
\       Name: CHK
\       Type: Variable
\   Category: Save and load
\    Summary: First checksum byte for the saved commander data file
\  Deep dive: Commander save files
\             The competition code
\
\ ------------------------------------------------------------------------------
\
\ Commander checksum byte. If the default commander is changed, a new checksum
\ will be calculated and inserted by the elite-checksum.py script.
\
\ The offset of this byte within a saved commander file is also shown (it's at
\ byte #75).
\
\ ******************************************************************************

.CHK_7

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\IF _STH_CASSETTE OR _TEXT_SOURCES
\
\EQUB &03               \ The checksum value for the default commander, #75
\
\ELIF _SOURCE_DISC
\
\EQUB &92               \ The checksum value for the default commander from the
\                       \ source disc, #75
\
\ENDIF

                        \ --- And replaced by: -------------------------------->

 EQUB &2D               \ The checksum value for the default commander, #75

                        \ --- End of replacement ------------------------------>

\ ---- moved from elite-source.asm lines 8626-8980 (main RAM) ----
\ ******************************************************************************
\
\       Name: PRXS
\       Type: Variable
\   Category: Equipment
\    Summary: Equipment prices
\
\ ------------------------------------------------------------------------------
\
\ Equipment prices are stored as 10 * the actual value, so we can support prices
\ with fractions of credits (0.1 Cr). This is used for the price of fuel only.
\
\ ******************************************************************************

.PRXS_7

 EQUW 1                 \ 0  Fuel, calculated in EQSHP  140.0 Cr (full tank)
 EQUW 300               \ 1  Missile                     30.0 Cr
 EQUW 4000              \ 2  Large Cargo Bay            400.0 Cr
 EQUW 6000              \ 3  E.C.M. System              600.0 Cr
 EQUW 4000              \ 4  Extra Pulse Lasers         400.0 Cr
 EQUW 10000             \ 5  Extra Beam Lasers         1000.0 Cr
 EQUW 5250              \ 6  Fuel Scoops                525.0 Cr
 EQUW 10000             \ 7  Escape Pod                1000.0 Cr
 EQUW 9000              \ 8  Energy Bomb                900.0 Cr
 EQUW 15000             \ 9  Energy Unit               1500.0 Cr
 EQUW 10000             \ 10 Docking Computer          1000.0 Cr
 EQUW 50000             \ 11 Galactic Hyperspace       5000.0 Cr

\ ******************************************************************************
\
\       Name: STATUS
\       Type: Subroutine
\   Category: Status
\    Summary: Show the Status Mode screen (red key f8)
\  Deep dive: Combat rank
\
\ ******************************************************************************

.st4_7

                        \ We call this from st5 below with the high byte of the
                        \ kill tally in A, which is non-zero, and want to return
                        \ with the following in X, depending on our rating:
                        \
                        \   Competent = 6
                        \   Dangerous = 7
                        \   Deadly    = 8
                        \   Elite     = 9
                        \
                        \ The high bytes of the top tier ratings are as follows,
                        \ so this a relatively simple calculation:
                        \
                        \   Competent = 1
                        \   Dangerous = 2 to 9
                        \   Deadly    = 10 to 24
                        \   Elite     = 25 and up

 LDX #9                 \ Set X to 9 for an Elite rating

 CMP #25                \ If A >= 25, jump to st3 to print out our rating, as we
 BCS st3_7              \ are Elite

 DEX                    \ Decrement X to 8 for a Deadly rating

 CMP #10                \ If A >= 10, jump to st3 to print out our rating, as we
 BCS st3_7              \ are Deadly

 DEX                    \ Decrement X to 7 for a Dangerous rating

 CMP #2                 \ If A >= 2, jump to st3 to print out our rating, as we
 BCS st3_7              \ are Dangerous

 DEX                    \ Decrement X to 6 for a Competent rating

 BNE st3_7              \ Jump to st3 to print out our rating, as we are
                        \ Competent (this BNE is effectively a JMP as A will
                        \ never be zero)

.STATUS_7

 LDA #8                 \ Clear the top part of the screen, draw a border box,
 JSR x4_TT66            \ and set the current view type in QQ11 to 8 (Status
                        \ Mode screen)

 JSR x4_TT111           \ Select the system closest to galactic coordinates
                        \ (QQ9, QQ10)

 LDA #7                 \ Move the text cursor to column 7
 STA XC

 LDA #126               \ Print recursive token 126, which prints the top
 JSR x4_NLIN3           \ four lines of the Status Mode screen:
                        \
                        \         COMMANDER {commander name}
                        \
                        \   Present System      : {current system name}
                        \   Hyperspace System   : {selected system name}
                        \   Condition           :
                        \
                        \ and draw a horizontal line at pixel row 19 to box
                        \ in the title

 LDA #15                \ Set A to token 129 ("{sentence case}DOCKED")

 LDY QQ12               \ Fetch the docked status from QQ12, and if we are
 BNE st6_7              \ docked, jump to st6 to print "Docked" for our
                        \ ship's condition

 LDA #230               \ Otherwise we are in space, so start off by setting A
                        \ to token 70 ("GREEN")

 LDY MANY+AST           \ Set Y to the number of asteroids in our local bubble
                        \ of universe

 LDX FRIN+2,Y           \ The ship slots at FRIN are ordered with the first two
                        \ slots reserved for the planet and sun/space station,
                        \ and then any ships, so if the slot at FRIN+2+Y is not
                        \ empty (i.e. is non-zero), then that means the number
                        \ of non-asteroids in the vicinity is at least 1

 BEQ st6_7              \ So if X = 0, there are no ships in the vicinity, so
                        \ jump to st6 to print "Green" for our ship's condition

 LDY ENERGY             \ Otherwise we have ships in the vicinity, so we load
                        \ our energy levels into Y

 CPY #128               \ Set the C flag if Y >= 128, so C is set if we have
                        \ more than half of our energy banks charged

 ADC #1                 \ Add 1 + C to A, so if C is not set (i.e. we have low
                        \ energy levels) then A is set to token 231 ("RED"),
                        \ and if C is set (i.e. we have healthy energy levels)
                        \ then A is set to token 232 ("YELLOW")

.st6_7

 JSR x4_plf             \ Print the text token in A (which contains our ship's
                        \ condition) followed by a newline

 LDA #125               \ Print recursive token 125, which prints the next
 JSR spc_7              \ three lines of the Status Mode screen:
                        \
                        \   Fuel: {fuel level} Light Years
                        \   Cash: {cash} Cr
                        \   Legal Status:
                        \
                        \ followed by a space

 LDA #19                \ Set A to token 133 ("CLEAN")

 LDY FIST               \ Fetch our legal status, and if it is 0, we are clean,
 BEQ st5_7              \ so jump to st5 to print "Clean"

 CPY #50                \ Set the C flag if Y >= 50, so C is set if we have
                        \ a legal status of 50+ (i.e. we are a fugitive)

 ADC #1                 \ Add 1 + C to A, so if C is not set (i.e. we have a
                        \ legal status between 1 and 49) then A is set to token
                        \ 134 ("OFFENDER"), and if C is set (i.e. we have a
                        \ legal status of 50+) then A is set to token 135
                        \ ("FUGITIVE")

.st5_7

 JSR x4_plf             \ Print the text token in A (which contains our legal
                        \ status) followed by a newline

 LDA #16                \ Print recursive token 130 ("RATING:") followed by a
 JSR spc_7              \ space

 LDA TALLY+1            \ Fetch the high byte of the kill tally, and if it is
 BNE st4_7              \ not zero, then we have more than 256 kill points, so
                        \ jump to st4 to work out whether we are Competent,
                        \ Dangerous, Deadly or Elite

                        \ Otherwise we have fewer than 256 kill pointss, so we
                        \ are one of Harmless, Mostly Harmless, Poor, Average,
                        \ Above Average or Competent

 TAX                    \ Set X to 0 (as A is 0)

 LDA TALLY              \ Set A to the lower byte of tally, with bits 0 and 1
 LSR A                  \ shifted off to the right, so we can now analyse bits
 LSR A                  \ 2 to 7 by shifting A to the right one bit at a time

.st5L_7

                        \ We now loop through bits 2 to 7, shifting each of them
                        \ off the end of A until there are no set bits left, and
                        \ incrementing X before each shift, so at the end of the
                        \ process, X contains the position of the leftmost 1 in
                        \ A. Looking at the rank values in TALLY:
                        \
                        \   Harmless        = %00000000 to %00000111
                        \   Mostly Harmless = %00001000 to %00001111
                        \   Poor            = %00010000 to %00011111
                        \   Average         = %00100000 to %00111111
                        \   Above Average   = %01000000 to %01111111
                        \   Competent       = %10000000 to %11111111
                        \
                        \ we can see that the values returned by this process
                        \ are:
                        \
                        \   Harmless        = 1
                        \   Mostly Harmless = 2
                        \   Poor            = 3
                        \   Average         = 4
                        \   Above Average   = 5
                        \   Competent       = 6

 INX                    \ Increment X to count the number of shifts

 LSR A                  \ Shift A to the right

 BNE st5L_7             \ Keep looping around until A = 0, which means there are
                        \ no set bits left in A

.st3_7

 TXA                    \ A now contains our rating as a value of 1 to 9, so
                        \ transfer X to A, so we can print it out

 CLC                    \ Print recursive token 135 + A, which will be in the
 ADC #21                \ range 136 ("HARMLESS") to 144 ("---- E L I T E ----")
 JSR x4_plf             \ followed by a newline

 LDA #18                \ Print recursive token 132, which prints the next bit
 JSR plf2_7             \ of the Status Mode screen:
                        \
                        \   EQUIPMENT:
                        \
                        \ followed by a newline and an indent of 6 characters

 LDA CRGO               \ If our ship's cargo capacity is < 26 (i.e. we do not
 CMP #26                \ have a cargo bay extension), skip the following two
 BCC P%+7               \ instructions

 LDA #107               \ We do have a cargo bay extension, so print recursive
 JSR plf2_7             \ token 107 ("LARGE CARGO{sentence case} BAY"), followed
                        \ by a newline and an indent of 6 characters

 LDA BST                \ If we don't have fuel scoops fitted, skip the
 BEQ P%+7               \ following two instructions

 LDA #111               \ We do have fuel scoops fitted, so print recursive
 JSR plf2_7             \ token 111 ("FUEL SCOOPS"), followed by a newline and
                        \ an indent of 6 characters

 LDA ECM                \ If we don't have an E.C.M. fitted, skip the following
 BEQ P%+7               \ two instructions

 LDA #108               \ We do have an E.C.M. fitted, so print recursive token
 JSR plf2_7             \ 108 ("E.C.M.SYSTEM"), followed by a newline and an
                        \ indent of 6 characters

 LDA #113               \ We now cover the four pieces of equipment whose flags
 STA XX4                \ are stored in BOMB through BOMB+3, and whose names
                        \ correspond with text tokens 113 through 116:
                        \
                        \   BOMB+0 = BOMB  = token 113 = Energy bomb
                        \   BOMB+1 = ENGY  = token 114 = Energy unit
                        \   BOMB+2 = DKCMP = token 115 = Docking computer
                        \   BOMB+3 = GHYP  = token 116 = Galactic hyperdrive
                        \
                        \ We can print these out using a loop, so we set XX4 to
                        \ 113 as a counter (and we also set A as well, to pass
                        \ through to plf2)

.stqv_7

 TAY                    \ Fetch byte BOMB+0 through BOMB+4 for values of XX4
 LDX BOMB-113,Y         \ from 113 through 117

 BEQ P%+5               \ If it is zero then we do not own that piece of
                        \ equipment, so skip the next instruction

 JSR plf2_7             \ Print the recursive token in A from 113 ("ENERGY
                        \ BOMB") through 116 ("GALACTIC HYPERSPACE "), followed
                        \ by a newline and an indent of 6 characters

 INC XX4                \ Increment the counter (and A as well)
 LDA XX4

 CMP #117               \ If A < 117, loop back up to stqv to print the next
 BCC stqv_7             \ piece of equipment

 LDX #0                 \ Now to print our ship's lasers, so set a counter in X
                        \ to count through the four views (0 = front, 1 = rear,
                        \ 2 = left, 3 = right)

.st_7

 STX CNT                \ Store the view number in CNT

 LDY LASER,X            \ Fetch the laser power for view X, and if we do not
 BEQ st1_7              \ have a laser fitted to that view, jump to st1 to move
                        \ on to the next one

 TXA                    \ Print recursive token 96 + X, which will print from 96
 CLC                    \ ("FRONT") through to 99 ("RIGHT"), followed by a space
 ADC #96
 JSR spc_7

 LDA #103               \ Set A to token 103 ("PULSE LASER")

 LDX CNT                \ If the laser power for view X has bit 7 clear, then it
 LDY LASER,X            \ is a pulse laser, so skip the following instruction
 BPL P%+4

 LDA #104               \ Set A to token 104 ("BEAM LASER")

 JSR plf2_7             \ Print the text token in A (which contains the laser
                        \ type) followed by a newline and an indent of 6
                        \ characters

.st1_7

 LDX CNT                \ Increment the counter in X and CNT to point to the
 INX                    \ next view

 CPX #4                 \ If this isn't the last of the four views, jump back up
 BCC st_7               \ to st to print out the next one

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: plf2
\       Type: Subroutine
\   Category: Text
\    Summary: Print text followed by a newline and indent of 6 characters
\
\ ------------------------------------------------------------------------------
\
\ Print a text token followed by a newline, and indent the next line to text
\ column 6.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The text token to be printed
\
\ ******************************************************************************

.plf2_7

 JSR x4_plf             \ Print the text token in A followed by a newline

 LDX #6                 \ Move the text cursor to column 6
 STX XC

 RTS                    \ Return from the subroutine

\ ---- moved from elite-source.asm lines 15062-15155 (main RAM) ----
\ ******************************************************************************
\
\       Name: RESET
\       Type: Subroutine
\   Category: Start and end
\    Summary: Reset most variables
\
\ ------------------------------------------------------------------------------
\
\ Reset our ship and various controls, recharge shields and energy, and then
\ fall through into RES2 to reset the stardust and the ship workspace at INWK.
\
\ In this subroutine, this means zero-filling the following locations:
\
\   * Pages &9, &A, &B, &C and &D
\
\   * BETA to BETA+6, which covers the following:
\
\     * BETA, BET1 - Set pitch to 0
\
\     * XC, YC - Set text cursor to (0, 0)
\
\     * QQ22 - Set hyperspace counters to 0
\
\     * ECMA - Turn E.C.M. off
\
\ It also sets QQ12 to &FF, to indicate we are docked, recharges the shields and
\ energy banks, and then falls through into RES2.
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   RES4                Reset the shields and energy banks, then fall through
\                       into RES2 to reset the stardust and the ship workspace
\                       at INWK
\
\ ******************************************************************************

.RESET_7

 JSR x4_ZERO            \ Zero-fill pages &9, &A, &B, &C and &D, which clears
                        \ the ship data blocks, the ship line heap, the ship
                        \ slots for the local bubble of universe, and various
                        \ flight and ship status variables

                        \ --- Mod: Code added for Demonstration Disc: --------->

 STA hyperspaceDone     \ Zero hyperspaceDone to indicate that we haven't yet
                        \ done the hyperspace jump to Riedquat and are therefore
                        \ still in Lave

                        \ --- End of added code ------------------------------->

 LDX #6                 \ Set up a counter for zeroing BETA through BETA+6

.SAL3_7

 STA BETA,X             \ Zero the X-th byte after BETA

 DEX                    \ Decrement the loop counter

 BPL SAL3_7             \ Loop back for the next byte to zero

 STX QQ12               \ X is now negative - i.e. &FF - so this sets QQ12 to
                        \ &FF to indicate we are docked

                        \ We now fall through into RES4 to restore shields and
                        \ energy, and reset the stardust and ship workspace at
                        \ INWK

.RES4_7

 LDA #&FF               \ Set A to &FF so we can fill up the shields and energy
                        \ bars with a full charge

 LDX #2                 \ We're now going to recharge both shields and the
                        \ energy bank, which live in the three bytes at FSH,
                        \ ASH (FSH+1) and ENERGY (FSH+2), so set a loop counter
                        \ in X for 3 bytes

.REL5_7

 STA FSH,X              \ Set the X-th byte of FSH to &FF to charge up that
                        \ shield/bank

 DEX                    \ Decrement the loop counter

 BPL REL5_7             \ Loop back to REL5 until we have recharged both shields
                        \ and the energy bank

                        \ Fall through into RES2 to reset the stardust and ship
                        \ workspace at INWK

 JMP x4_RES2              \ (RES2 stays in main RAM: it was the fall-through)

\ ---- moved from elite-source.asm lines 16250-16277 (main RAM) ----

.T95_7

                        \ If we get here, "D" was pressed, so we need to show
                        \ the distance to the selected system (if we are in a
                        \ chart view)

 LDA QQ11               \ If the current view is a chart (QQ11 = 64 or 128),
 AND #%11000000         \ keep going, otherwise return from the subroutine (as
 BEQ b3_t95             \ t95 contains an RTS)

 JSR x4_hm              \ Call hm to move the crosshairs to the target system
                        \ in (QQ9, QQ10), returning with A = 0

 STA QQ17               \ Set QQ17 = 0 to switch to ALL CAPS

 JSR x4_cpl             \ Print control code 3 (the selected system name)

 LDA #%10000000         \ Set bit 7 of QQ17 to switch to Sentence Case, with the
 STA QQ17               \ next letter in capitals

 LDA #1                 \ Move the text cursor to column 1 and down one line
 STA XC                 \ (in other words, to the start of the next line)
 INC YC

 JMP TT146_7            \ Print the distance to the selected system and return
                        \ from the subroutine using a tail call


\ (branches out of the code above)
.b3_t95 JSR far4 : EQUW t95

\ ---- moved from elite-source.asm lines 16439-16552 (main RAM) ----
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

.DEATH_7

 JSR x4_EXNO3           \ Make the sound of us dying

 JSR x4_RES2            \ Reset a number of flight variables and workspaces

 ASL DELTA              \ Divide our speed in DELTA by 4
 ASL DELTA

 LDX #24                \ Set the screen to only show 24 text rows, which hides
 JSR x4_DET1            \ the dashboard, setting A to 6 in the process

 JSR x4_TT66            \ Clear the top part of the screen, draw a border box,
                        \ and set the current view type in QQ11 to 6 (death
                        \ screen)

 JSR x4_BOX             \ Call BOX to redraw the same border box (BOX is part
                        \ of TT66), which removes the border as it is drawn
                        \ using EOR logic

 JSR x4_nWq             \ Create a cloud of stardust containing the correct
                        \ number of dust particles (i.e. NOSTM of them)

 LDA #12                \ Move the text cursor to column 12 on row 12
 STA YC
 STA XC

 LDA #146               \ Print recursive token 146 ("{all caps}GAME OVER")
 JSR x4_ex

.D1_7

 JSR x4_Ze              \ Call Ze to initialise INWK to a fairly aggressive
                        \ ship, and set A and X to random values

 LSR A                  \ Set A = A / 4, so A is now between 0 and 63, and
 LSR A                  \ store in byte #0 (x_lo)
 STA INWK

 LDY #0                 \ Set the following to 0: the current view in QQ11
 STY QQ11               \ (space view), x_hi, y_hi, z_hi and the AI flag (no AI
 STY INWK+1             \ or E.C.M. and zero aggression)
 STY INWK+4
 STY INWK+7
 STY INWK+32

 DEY                    \ Set Y = 255

 STY MCNT               \ Reset the main loop counter to 255, so all timer-based
                        \ calls will be stopped

 STY LASCT              \ Set the laser count to 255 to act as a counter in the
                        \ D2 loop below, so this setting determines how long the
                        \ death animation lasts (it's 5.1 seconds, as LASCT is
                        \ decremented every vertical sync, or 50 times a second,
                        \ and 255 / 50 = 5.1)

 EOR #%00101010         \ Flip bits 1, 3 and 5 in A (x_lo) to get another number
 STA INWK+3             \ between 48 and 63, and store in byte #3 (y_lo)

 ORA #%01010000         \ Set bits 4 and 6 of A to bump it up to between 112 and
 STA INWK+6             \ 127, and store in byte #6 (z_lo)

 TXA                    \ Set A to the random number in X and keep bits 0-3 and
 AND #%10001111         \ the sign in bit 7 to get a number between -15 and +15,
 STA INWK+29            \ and store in byte #29 (roll counter) to give our ship
                        \ a gentle roll with damping

 ROR A                  \ The C flag is randomly set from the above call to Ze,
 AND #%10000111         \ so this sets A to a number between -7 and +7, which
 STA INWK+30            \ we store in byte #30 (the pitch counter) to give our
                        \ ship a very gentle pitch with damping

 PHP                    \ Store the processor flags

 LDX #OIL               \ Call fq1 with X set to #OIL, which adds a new cargo
 JSR x4_fq1             \ canister to our local bubble of universe and points it
                        \ away from us with double DELTA speed (i.e. 6, as DELTA
                        \ was set to 3 by the call to RES2 above). INF is set to
                        \ point to the canister's ship data block in K%

 PLP                    \ Restore the processor flags, including our random C
                        \ flag from before

 LDA #0                 \ Set bit 7 of A to our random C flag and store in byte
 ROR A                  \ #31 of the ship's data block, so this has a 50% chance
 LDY #31                \ of marking our new canister as being killed (so it
 STA (INF),Y            \ will explode)

 LDA FRIN+3             \ The call we made to RES2 before we entered the loop at
 BEQ D1_7               \ D1 will have reset all the ship slots at FRIN, so this
                        \ checks to see if the fourth slot is empty, and if it
                        \ is we loop back to D1 to add another canister, until
                        \ we have added four of them

 JSR x4_Upc             \ Clear the key logger, which also sets A = 0

 STA DELTA              \ Set our speed in DELTA to 0, as we aren't going
                        \ anywhere any more

 JMP j4_D2                \ (D2 stays in main RAM: compare.mjs hooks its LDA LASCT)

\ ---- moved from elite-source.asm lines 16613-17303 (main RAM) ----
\ ******************************************************************************
\
\       Name: BR1 (Part 1 of 2)
\       Type: Subroutine
\   Category: Start and end
\    Summary: Show the "Load New Commander (Y/N)?" screen and start the game
\
\ ------------------------------------------------------------------------------
\
\ BRKV is set to point to BR1 by the loading process.
\
\ ******************************************************************************

.BR1_7

 LDX #3                 \ Set XC = 3 (set text cursor to column 3)
 STX XC

 JSR FX200_7            \ Disable the ESCAPE key and clear memory if the BREAK
                        \ key is pressed (*FX 200,3)

 LDX #CYL               \ Call TITLE to show a rotating Cobra Mk III (#CYL) and
 LDA #128               \ token 128 ("  LOAD NEW COMMANDER (Y/N)?{crlf}{crlf}"),
 JSR TITLE_7            \ returning with the internal number of the key pressed
                        \ in A

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\CMP #&44               \ Did we press "Y"? If not, jump to QU5, otherwise
\BNE QU5                \ continue on to load a new commander

                        \ --- End of removed code ----------------------------->

\.BR1                   \ These instructions are commented out in the original
\
\LDX #3                 \ source. This block starts with the same *FX call as
\STX XC                 \ above, then clears the screen, calls a routine to
\                       \ flush the keyboard buffer (FLKB) that isn't present
\JSR FX200              \ in the cassette version but is in other versions,
\                       \ and then it displays "LOAD NEW COMMANDER (Y/N)?" and
\LDA #1                 \ lists the current cargo, before falling straight into
\JSR TT66               \ the load routine below, whether or not we have
\                       \ pressed "Y". This may be a bit of testing code, as the
\JSR FLKB               \ first line is a commented label, BR1, which is where
\                       \ BRKV points, so when this is uncommented, any BRK
\LDA #14                \ instructions will jump straight to the load screen
\JSR TT214
\
\BCC QU5

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\JSR GTNME              \ We want to load a new commander, so we need to get
\                       \ the commander name to load
\
\JSR LOD                \ We then call the LOD subroutine to load the commander
\                       \ file to address NA%+8, which is where we store the
\                       \ commander save file
\
\JSR TRNME              \ Once loaded, we copy the commander name to NA%
\
\JSR TTX66              \ And we clear the top part of the screen and draw a
\                       \ border box

                        \ --- End of removed code ----------------------------->

\ ******************************************************************************
\
\       Name: QU5
\       Type: Subroutine
\   Category: Start and end
\    Summary: Reset the current commander data block to the last saved commander
\
\ ******************************************************************************

.QU5_7

                        \ By the time we get here, the correct commander name
                        \ is at NA% and the correct commander data is at NA%+8.
                        \ Specifically:
                        \
                        \   * If we loaded a commander file, then the name and
                        \     data from that file will be at NA% and NA%+8
                        \
                        \   * If this is a brand new game, then NA% will contain
                        \     the default starting commander name ("JAMESON")
                        \     and NA%+8 will contain the default commander data
                        \
                        \   * If this is not a new game (because they died or
                        \     quit) and we didn't want to load a commander file,
                        \     then NA% will contain the last saved commander
                        \     name, and NA%+8 the last saved commander data. If
                        \     the game has never been saved, this will still be
                        \     the default commander

\JSR TTX66              \ This instruction is commented out in the original
                        \ source; it clears the screen and draws a border

 LDX #NT%               \ The size of the commander data block is NT% bytes,
                        \ and it starts at NA%+8, so we need to copy the data
                        \ from the "last saved" buffer at NA%+8 to the current
                        \ commander workspace at TP. So we set up a counter in X
                        \ for the NT% bytes that we want to copy

.QUL1_7

 LDA NA_7%+7,X          \ Copy the X-th byte of NA%+7 to the X-th byte of TP-1,
 STA TP-1,X             \ (the -1 is because X is counting down from NT% to 1)

 DEX                    \ Decrement the loop counter

 BNE QUL1_7             \ Loop back for the next byte of the commander data
                        \ block

 STX QQ11               \ X is 0 by the end of the above loop, so this sets QQ11
                        \ to 0, which means we will be showing a view without a
                        \ boxed title at the top (i.e. we're going to use the
                        \ screen layout of a space view in the following)

                        \ If the commander check below fails, we keep jumping
                        \ back to here to crash the game with an infinite loop

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\JSR CHECK              \ Call the CHECK subroutine to calculate the checksum
\                       \ for the current commander block at NA%+8 and put it
\                       \ in A
\
\CMP CHK                \ Test the calculated checksum against CHK
\
\IF _REMOVE_CHECKSUMS
\
\NOP                    \ If we have disabled checksums, then ignore the result
\NOP                    \ of the comparison and fall through into the next part
\
\ELSE
\
\BNE P%-6               \ If the calculated checksum does not match CHK, then
\                       \ loop back to repeat the check - in other words, we
\                       \ enter an infinite loop here, as the checksum routine
\                       \ will keep returning the same incorrect value
\
\ENDIF
\
\                       \ The checksum CHK is correct, so now we check whether
\                       \ CHK2 = CHK EOR A9, and if this check fails, bit 7 of
\                       \ the competition flags at COK gets set, to indicate
\                       \ to Acornsoft via the competition code that there has
\                       \ been some hacking going on with this competition entry
\
\EOR #&A9               \ X = checksum EOR &A9
\TAX
\
\LDA COK                \ Set A to the competition flags in COK
\
\CPX CHK2               \ If X = CHK2, then skip the next instruction
\BEQ tZ
\
\ORA #%10000000         \ Set bit 7 of A to indicate this commander file has
\                       \ been tampered with
\
\.tZ
\
\ORA #%00000010         \ Set bit 1 of A to denote that this is the cassette
\                       \ version
\
\STA COK                \ Store the updated competition flags in COK

                        \ --- End of removed code ----------------------------->

\ ******************************************************************************
\
\       Name: BR1 (Part 2 of 2)
\       Type: Subroutine
\   Category: Start and end
\    Summary: Show the second title screen and start the game
\
\ ------------------------------------------------------------------------------
\
\ BRKV is set to point to BR1 by the loading process.
\
\ ******************************************************************************

 JSR x4_msblob          \ Reset the dashboard's missile indicators so none of
                        \ them are targeted

 LDA #147               \ Call TITLE to show a rotating Mamba (#3) and token
 LDX #3                 \ 147 ("{all caps}BBC{sentence case} TAPE VERSION
 JSR TITLE_7            \ DEMONSTRATION")

 JSR x4_ping            \ Set the target system coordinates (QQ9, QQ10) to the
                        \ current system coordinates (QQ0, QQ1) we just loaded

 JSR x4_hyp1            \ Arrive in the system closest to (QQ9, QQ10)

                        \ Fall through into the docking bay routine below

\ ******************************************************************************
\
\       Name: BAY
\       Type: Subroutine
\   Category: Status
\    Summary: Go to the docking bay (i.e. show the Status Mode screen)
\  Deep dive: The Elite Demonstration Disc
\
\ ------------------------------------------------------------------------------
\
\ We end up here after the start-up process (load commander etc.), as well as
\ after a successful save, an escape pod launch, a successful docking, the end
\ of a cargo sell, and various errors (such as not having enough cash, entering
\ too many items when buying, trying to fit an item to your ship when you
\ already have it, running out of cargo space, and so on).
\
\ ******************************************************************************

.BAY_7

 LDA #&FF               \ Set QQ12 = &FF (the docked flag) to indicate that we
 STA QQ12               \ are docked

                        \ --- Mod: Code added for Demonstration Disc: --------->

                        \ We now show a sequence of docked screens by "pressing"
                        \ the relevant keys and showing various screens for five
                        \ seconds each

 LDA #f8                \ Call TT102 to "press" the f8 key (Status Mode) and
 JSR x4_TT102           \ wait for five seconds (the delay has been added to
                        \ TT102)

 LDA #f7                \ Call TT102 to "press" the f7 key (Market Price) and
 JSR x4_TT102           \ wait for five seconds (the delay has been added to
                        \ TT167)

 LDA #f6                \ Call TT102 to "press" the f6 key (Data on System) and
 JSR x4_TT102           \ wait for five seconds (the delay has been added to
                        \ TT25, which falls through into DelayFiveSeconds)

 LDA #f3                \ Call TT102 to "press" the f3 key (Equip Ship) to start
 JSR x4_TT102           \ the following sequence
                        \
                        \ EQSHP does the following:
                        \
                        \   * Display the Equip Ship screen, buy fuel and a
                        \     missile and wait for five seconds (see EQSHP)
                        \
                        \ And then TT219 does the following:
                        \
                        \   * Show the Buy Cargo screen and buy some random
                        \     cargo
                        \
                        \   * Show the Inventory screen and wait for five
                        \     seconds (see TT213 and TT210)
                        \
                        \   * Show the Long-range Chart screen, choose a random
                        \     system and show the Data on System screen for five
                        \     seconds, repeating this process for a random
                        \     number of systems
                        \
						\   * Show the Status Mode screen for five seconds
                        \
						\   * Launch from the station
                        \
						\   * Show the Short-range Chart screen, move the
                        \     crosshairs to Riedquat and start a hyperspace
                        \     (see TT110)

 LDA #f0                \ Jump into the main game loop at FRCE, setting the key
 JMP j4_FRCE            \ "pressed" to red key f0 (so we switch to the front
                        \ space view to wait for the hyperspace countdown)

                        \ The following code is never run, and is presumably
                        \ just the remains of the old BAY routine, with the new
                        \ code being inserted above

 LDA #&FF               \ Set QQ12 = &FF (the docked flag) to indicate that we
 STA QQ12               \ are docked

                        \ --- End of added code ------------------------------->

 LDA #f8                \ Jump into the main loop at FRCE, setting the key
 JMP j4_FRCE            \ that's "pressed" to red key f8 (so we show the Status
                        \ Mode screen)

\ ******************************************************************************
\
\       Name: TITLE
\       Type: Subroutine
\   Category: Start and end
\    Summary: Display a title screen with a rotating ship and prompt
\
\ ------------------------------------------------------------------------------
\
\ Display the title screen, with a rotating ship and a text token at the bottom
\ of the screen.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The number of the recursive token to show below the
\                       rotating ship (see variable QQ18 for details of
\                       recursive tokens)
\
\   X                   The type of the ship to show (see variable XX21 for a
\                       list of ship types)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   X                   If a key is being pressed, X contains the internal key
\                       number, otherwise it contains 0
\
\ ******************************************************************************

.TITLE_7

 PHA                    \ Store the token number on the stack for later

 STX TYPE               \ Store the ship type in location TYPE

 JSR RESET_7            \ Reset our ship so we can use it for the rotating
                        \ title ship

 LDA #1                 \ Clear the top part of the screen, draw a border box,
 JSR x4_TT66            \ and set the current view type in QQ11 to 1

 DEC QQ11               \ Decrement QQ11 to 0, so from here on we are using a
                        \ space view

 LDA #96                \ Set nosev_z hi = 96 (96 is the value of unity in the
 STA INWK+14            \ rotation vector)

\LSR A                  \ This instruction is commented out in the original
                        \ source. It would halve the value of z_hi to 48, so the
                        \ ship would start off closer to the viewer

 STA INWK+7             \ Set z_hi, the high byte of the ship's z-coordinate,
                        \ to 96, which is the distance at which the rotating
                        \ ship starts out before coming towards us

 LDX #127               \ Set roll counter = 127, so don't dampen the roll and
 STX INWK+29            \ make the roll direction clockwise

 STX INWK+30            \ Set pitch counter = 127, so don't dampen the pitch and
                        \ set the pitch direction to dive

 INX                    \ Set QQ17 to 128 (so bit 7 is set) to switch to
 STX QQ17               \ Sentence Case, with the next letter printing in upper
                        \ case

 LDA TYPE               \ Set up a new ship, using the ship type in TYPE
 JSR x4_NWSHP

 LDY #6                 \ Move the text cursor to column 6
 STY XC

 JSR x4_DELAY           \ Wait for 6/50 of a second (0.12 seconds)

 LDA #30                \ Print recursive token 144 ("---- E L I T E ----")
 JSR x4_plf             \ followed by a newline

 LDY #6                 \ Move the text cursor to column 6 again
 STY XC

 INC YC                 \ Move the text cursor down a row

 LDA PATG               \ If PATG = 0, skip the following two lines, which
 BEQ awe_7              \ print the author credits (PATG can be toggled by
                        \ pausing the game and pressing "X")

 LDA #254               \ Print recursive token 94 ("BY D.BRABEN & I.BELL")
 JSR x4_TT27

.awe_7

 JSR x4_CLYNS           \ Clear the bottom three text rows of the upper screen,
                        \ and move the text cursor to the first cleared row.
                        \ It also returns with Y = 0

 STY DELTA              \ Set DELTA = 0 (i.e. ship speed = 0)

 STY JSTK               \ Set JSTK = 0 (i.e. keyboard, not joystick)

 PLA                    \ Restore the recursive token number we stored on the
 JSR x4_ex              \ stack at the start of this subroutine, and print that
                        \ token

 LDA #148               \ Set A to recursive token 148

 LDX #7                 \ Move the text cursor to column 7
 STX XC

 JSR x4_ex              \ Print recursive token 148 ("(C) ACORNSOFT 1984")

.TLL2_7

                        \ --- Mod: Code added for Demonstration Disc: --------->

 LDA #255               \ Set the main loop counter in MCNT to 255, so we show
 STA MCNT               \ the title screen for 255 iterations of the loop at
                        \ titl1

.titl1_7

                        \ --- End of added code ------------------------------->

 LDA INWK+7             \ If z_hi (the ship's distance) is 1, jump to TL1 to
 CMP #1                 \ skip the following decrement
 BEQ TL1_7

 DEC INWK+7             \ Decrement the ship's distance, to bring the ship
                        \ a bit closer to us

.TL1_7

 JSR x4_MVEIT           \ Move the ship in space according to the orientation
                        \ vectors and the new value in z_hi

 LDA #128               \ Set z_lo = 128, so the closest the ship gets to us is
 STA INWK+6             \ z_hi = 1, z_lo = 128, or 256 + 128 = 384

 ASL A                  \ Set A = 0

 STA INWK               \ Set x_lo = 0, so the ship remains in the screen centre

 STA INWK+3             \ Set y_lo = 0, so the ship remains in the screen centre

 JSR x4_H_LL9F          \ Call LL9 to display the ship (then the frame)

 DEC MCNT               \ Decrement the main loop counter

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\LDA VIA+&40            \ Read 6522 System VIA input register IRB (SHEILA &40)
\
\AND #%00010000         \ Bit 4 of IRB (PB4) is clear if joystick 1's fire
\                       \ button is pressed, otherwise it is set, so AND'ing
\                       \ the value of IRB with %10000 extracts this bit
\
\\TAX                   \ This instruction is commented out in the original
\                       \ source; it would have no effect, as the comparison
\                       \ flags are already set by the AND, and the value of X
\                       \ is not used anywhere
\
\BEQ TL2                \ If the joystick fire button is pressed, jump to TL2
\
\JSR RDKEY              \ Scan the keyboard for a key press and return the
\                       \ internal key number in A and X (or 0 for no key press)
\
\BEQ TLL2               \ If no key was pressed, loop back up to move/rotate
\                       \ the ship and check again for a key press
\
\RTS                    \ Return from the subroutine
\
\.TL2
\
\DEC JSTK               \ Joystick fire button was pressed, so set JSTK to &FF
\                       \ (it was set to 0 above), to disable keyboard and
\                       \ enable joysticks

                        \ --- And replaced by: -------------------------------->

 BNE titl1_7            \ Loop back to titl1 to keep showing the title screen
                        \ until the loop counter in MCNT has reached zero

                        \ --- End of replacement ------------------------------>

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: CHECK, Removed
\       Type: Subroutine
\   Category: Save and load
\    Summary: Calculate the checksum for the last saved commander data block
\  Deep dive: Commander save files
\
\ ------------------------------------------------------------------------------
\
\ The checksum for the last saved commander data block is saved as part of the
\ commander file, in two places (CHK AND CHK2), to protect against file
\ tampering. This routine calculates the checksum and returns it in A.
\
\ This algorithm is also implemented in elite-checksum.py.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   The checksum for the last saved commander data block
\
\ ******************************************************************************

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\.CHECK
\
\LDX #NT%-2             \ Set X to the size of the commander data block, less
\                       \ 2 (to omit the checksum bytes and the save count)
\
\CLC                    \ Clear the C flag so we can do addition without the
\                       \ C flag affecting the result
\
\TXA                    \ Seed the checksum calculation by setting A to the
\                       \ size of the commander data block, less 2
\
\                       \ We now loop through the commander data block,
\                       \ starting at the end and looping down to the start
\                       \ (so at the start of this loop, the X-th byte is the
\                       \ last byte of the commander data block, i.e. the save
\                       \ count)
\
\.QUL2
\
\ADC NA%+7,X            \ Add the X-1-th byte of the data block to A, plus the
\                       \ C flag
\
\EOR NA%+8,X            \ EOR A with the X-th byte of the data block
\
\DEX                    \ Decrement the loop counter
\
\BNE QUL2               \ Loop back for the next byte in the calculation, until
\                       \ we have added byte #0 and EOR'd with byte #1 of the
\                       \ data block
\
\RTS                    \ Return from the subroutine

                        \ --- End of removed code ----------------------------->

\ ******************************************************************************
\
\       Name: TRNME, Removed
\       Type: Subroutine
\   Category: Save and load
\    Summary: Copy the last saved commander's name from INWK to NA%
\
\ ******************************************************************************

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\.TRNME
\
\LDX #7                 \ The commander's name can contain a maximum of 7
\                       \ characters, and is terminated by a carriage return,
\                       \ so set up a counter in X to copy 8 characters
\
\.GTL1
\
\LDA INWK,X             \ Copy the X-th byte of INWK to the X-th byte of NA%
\STA NA%,X
\
\DEX                    \ Decrement the loop counter
\
\BPL GTL1               \ Loop back until we have copied all 8 bytes
\
\                       \ Fall through into TR1 to copy the name back from NA%
\                       \ to INWK. This isn't necessary as the name is already
\                       \ there, but it does save one byte, as we don't need an
\                       \ RTS here

                        \ --- End of removed code ----------------------------->

\ ******************************************************************************
\
\       Name: TR1, Removed
\       Type: Subroutine
\   Category: Save and load
\    Summary: Copy the last saved commander's name from NA% to INWK
\
\ ******************************************************************************

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\.TR1
\
\LDX #7                 \ The commander's name can contain a maximum of 7
\                       \ characters, and is terminated by a carriage return,
\                       \ so set up a counter in X to copy 8 characters
\
\.GTL2
\
\LDA NA%,X              \ Copy the X-th byte of NA% to the X-th byte of INWK
\STA INWK,X
\
\DEX                    \ Decrement the loop counter
\
\BPL GTL2               \ Loop back until we have copied all 8 bytes
\
\RTS                    \ Return from the subroutine

                        \ --- End of removed code ----------------------------->

\ ******************************************************************************
\
\       Name: GTNME, Removed
\       Type: Subroutine
\   Category: Save and load
\    Summary: Fetch the name of a commander file to save or load
\
\ ------------------------------------------------------------------------------
\
\ Get the commander's name for loading or saving a commander file. The name is
\ stored in the INWK workspace and is terminated by a return character (13).
\
\ If ESCAPE is pressed or a blank name is entered, then the name stored is set
\ to the name from the last saved commander block.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   INWK                The commander name entered, terminated by a return
\                       character (13)
\
\ ******************************************************************************

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\.GTNME
\
\LDA #1                 \ Clear the top part of the screen, draw a border box,
\JSR TT66               \ and set the current view type in QQ11 to 1
\
\LDA #123               \ Print recursive token 123 ("{crlf}COMMANDER'S NAME? ")
\JSR TT27
\
\JSR DEL8               \ Wait for 8/50 of a second (0.16 seconds)
\
\LDA #%10000001         \ Clear 6522 System VIA interrupt enable register IER
\STA VIA+&4E            \ (SHEILA &4E) bit 1 (i.e. enable the CA2 interrupt,
\                       \ which comes from the keyboard)
\
\LDA #15                \ Call OSBYTE with A = 15 (flush all buffers)
\TAX
\JSR OSBYTE
\
\LDX #LO(RLINE)         \ Set (Y X) to point to the RLINE parameter block
\LDY #HI(RLINE)         \ configuration block below
\
\LDA #0                 \ Call OSWORD with A = 0 to read a line from the current
\JSR OSWORD             \ input stream (i.e. the keyboard)
\
\\LDA #%00000001        \ These instructions are commented out in the original
\\STA VIA+&4E           \ source, but they would set 6522 System VIA interrupt
\                       \ enable register IER (SHEILA &4E) bit 1 (i.e. disable
\                       \ the CA2 interrupt, which comes from the keyboard)
\
\BCS TR1                \ The C flag will be set if we pressed ESCAPE when
\                       \ entering the name, in which case jump to TR1 to copy
\                       \ the last saved commander's name from NA% to INWK
\                       \ and return from the subroutine there
\
\TYA                    \ The OSWORD call returns the length of the commander's
\                       \ name in Y, so transfer this to A
\
\BEQ TR1                \ If A = 0, no name was entered, so jump to TR1 to copy
\                       \ the last saved commander's name from NA% to INWK
\                       \ and return from the subroutine there
\
\JMP TT67               \ We have a name, so jump to TT67 to print a newline
\                       \ and return from the subroutine using a tail call

                        \ --- End of removed code ----------------------------->

\ ******************************************************************************
\
\       Name: RLINE, Removed
\       Type: Variable
\   Category: Text
\    Summary: The OSWORD configuration block used to fetch a line of text from
\             the keyboard
\
\ ******************************************************************************

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\.RLINE
\
\EQUW INWK              \ The address to store the input, so the commander's
\                       \ name will be stored in INWK as it is typed
\
\EQUB 7                 \ Maximum line length = 7, as that's the maximum size
\                       \ for a commander's name
\
\EQUB '!'               \ Allow ASCII characters from "!" through to "z" in
\EQUB 'z'               \ the name

                        \ --- End of removed code ----------------------------->

\ ---- moved from elite-source.asm lines 17415-17730 (main RAM) ----
\ ******************************************************************************
\
\       Name: SVE, Removed
\       Type: Subroutine
\   Category: Save and load
\    Summary: Save the commander file
\  Deep dive: Commander save files
\             The competition code
\
\ ******************************************************************************

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\.SVE
\
\JSR GTNME              \ Clear the screen and ask for the commander filename
\                       \ to save, storing the name at INWK
\
\JSR TRNME              \ Transfer the commander filename from INWK to NA%
\
\JSR ZERO               \ Zero-fill pages &9, &A, &B, &C and &D, which clears
\                       \ the ship data blocks, the ship line heap, the ship
\                       \ slots for the local bubble of universe, and various
\                       \ flight and ship status variables
\
\LSR SVC                \ Halve the save count value in SVC
\
\LDX #NT%               \ We now want to copy the current commander data block
\                       \ from location TP to the last saved commander block at
\                       \ NA%+8, so set a counter in X to copy the NT% bytes in
\                       \ the commander data block
\                       \
\                       \ We also want to copy the data block to another
\                       \ location &0B00, which is normally used for the ship
\                       \ lines heap
\
\.SVL1
\
\LDA TP,X               \ Copy the X-th byte of TP to the X-th byte of &0B00
\STA &0B00,X            \ and NA%+8
\STA NA%+8,X
\
\DEX                    \ Decrement the loop counter
\
\BPL SVL1               \ Loop back until we have copied all the bytes in the
\                       \ commander data block
\
\JSR CHECK              \ Call CHECK to calculate the checksum for the last
\                       \ saved commander and return it in A
\
\STA CHK                \ Store the checksum in CHK, which is at the end of the
\                       \ last saved commander block
\
\PHA                    \ Store the checksum on the stack
\
\ORA #%10000000         \ Set K = checksum with bit 7 set
\STA K
\
\EOR COK                \ Set K+2 = K EOR COK (the competition flags)
\STA K+2
\
\EOR CASH+2             \ Set K+1 = K+2 EOR CASH+2 (the third cash byte)
\STA K+1
\
\EOR #&5A               \ Set K+3 = K+1 EOR &5A EOR TALLY+1 (the high byte of
\EOR TALLY+1            \ the kill tally)
\STA K+3
\
\JSR BPRNT              \ Print the competition number stored in K to K+3. The
\                       \ value of U might affect how this is printed, and as
\                       \ it's a temporary variable in zero page that isn't
\                       \ reset by ZERO, it might have any value, but as the
\                       \ competition code is a 10-digit number, this just means
\                       \ it may or may not have an extra space of padding
\
\JSR TT67               \ Call TT67 twice to print two newlines
\JSR TT67
\
\PLA                    \ Restore the checksum from the stack
\
\STA &0B00+NT%          \ Store the checksum in the last byte of the save file
\                       \ at &0B00 (the equivalent of CHK in the last saved
\                       \ block)
\
\EOR #&A9               \ Store the checksum EOR &A9 in CHK2, the penultimate
\STA CHK2               \ byte of the last saved commander block
\
\STA &0AFF+NT%          \ Store the checksum EOR &A9 in the penultimate byte of
\                       \ the save file at &0B00 (the equivalent of CHK2 in the
\                       \ last saved block)
\
\LDY #&B                \ Set up an OSFILE block at &0C00, containing:
\STY &0C0B              \
\INY                    \ Start address for save = &00000B00 in &0C0A to &0C0D
\STY &0C0F              \
\                       \ End address for save = &00000C00 in &0C0E to &0C11
\                       \
\                       \ Y is left containing &C which we use below
\
\LDA #%10000001         \ Clear 6522 System VIA interrupt enable register IER
\STA VIA+&4E            \ (SHEILA &4E) bit 1 (i.e. enable the CA2 interrupt,
\                       \ which comes from the keyboard)
\
\INC SVN                \ Increment SVN to indicate we are about to start saving
\
\LDA #0                 \ Call QUS1 with A = 0, Y = &C to save the commander
\JSR QUS1               \ file with the filename we copied to INWK at the start
\                       \ of this routine
\
\LDX #0                 \ Set X = 0 for storing in SVN below
\
\\STX VIA+&4E           \ This instruction is commented out in the original
\                       \ source. It would affect the 6522 System VIA interrupt
\                       \ enable register IER (SHEILA &4E) if any of bits 0-6
\                       \ of X were set, but they aren't, so this instruction
\                       \ would have no effect anyway
\
\\DEX                   \ This instruction is commented out in the original
\                       \ source. It would end up setting SVN to &FF, which
\                       \ affects the logic in the IRQ1 handler
\
\STX SVN                \ Set SVN to 0 to indicate we are done saving
\
\JMP BAY                \ Go to the docking bay (i.e. show Status Mode)

                        \ --- End of removed code ----------------------------->

\ ******************************************************************************
\
\       Name: SVE
\       Type: Subroutine
\   Category: Save and load
\    Summary: Remnants of the save routine
\
\ ******************************************************************************

                        \ --- Mod: Code added for Demonstration Disc: --------->

.SVE_7

                        \ The following remnants are all that remain of the SVE
                        \ routine, and they are not used by the demo, so
                        \ presumably removing the SVE routine from the demo was
                        \ only partially done

 STA CHK2_7             \ Store the checksum EOR &A9 in CHK2, the penultimate
                        \ byte of the last saved commander block

 STA &0AFF+NT%          \ Store the checksum EOR &A9 in the penultimate byte of
                        \ the save file at &0B00 (the equivalent of CHK2 in the
                        \ last saved block)

 LDY #&B                \ Set up an OSFILE block at &0C00, containing:
 STY &0C0B              \
 INY                    \ Start address for save = &00000B00 in &0C0A to &0C0D
 STY &0C0F              \
                        \ End address for save = &00000C00 in &0C0E to &0C11
                        \
                        \ Y is left containing &C which we use below

                        \ --- End of added code ------------------------------->

\ ******************************************************************************
\
\       Name: QUS1, Removed
\       Type: Subroutine
\   Category: Save and load
\    Summary: Save or load the commander file
\  Deep dive: Commander save files
\
\ ------------------------------------------------------------------------------
\
\ The filename should be stored at INWK, terminated with a carriage return (13).
\ The routine should be called with Y set to &C.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   File operation to be performed. Can be one of the
\                       following:
\
\                         * 0 (save file)
\
\                         * &FF (load file)
\
\   Y                   Points to the page number containing the OSFILE block,
\                       which must be &C because that's where the pointer to the
\                       filename in INWK is stored below (by the STX &0C00
\                       instruction)
\
\ ******************************************************************************

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\.QUS1
\
\LDX #INWK              \ Store a pointer to INWK at the start of the block at
\STX &0C00              \ &0C00, storing #INWK in the low byte because INWK is
\                       \ in zero page
\
\LDX #0                 \ Set X to 0 so (Y X) = &0C00
\
\JMP OSFILE             \ Jump to OSFILE to do the file operation specified in
\                       \ &0C00 (i.e. save or load a file depending on the value
\                       \ of A), returning from the subroutine using a tail call

                        \ --- End of removed code ----------------------------->

\ ******************************************************************************
\
\       Name: LOD, Removed
\       Type: Subroutine
\   Category: Save and load
\    Summary: Load a commander file
\
\ ------------------------------------------------------------------------------
\
\ The filename should be stored at INWK, terminated with a carriage return (13).
\
\ ******************************************************************************

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\.LOD
\
\LDX #2                 \ Enable the ESCAPE key and clear memory if the BREAK
\JSR FX200              \ key is pressed (*FX 200,2)
\
\JSR ZERO               \ Zero-fill pages &9, &A, &B, &C and &D, which clears
\                       \ the ship data blocks, the ship line heap, the ship
\                       \ slots for the local bubble of universe, and various
\                       \ flight and ship status variables
\
\LDY #&B                \ Set up an OSFILE block at &0C00, containing:
\STY &0C03              \
\INC &0C0B              \ Load address = &00000B00 in &0C02 to &0C05
\                       \
\                       \ Length of file = &00000100 in &0C0A to &0C0D
\
\INY                    \ Increment Y to &C, which we use next
\
\LDA #&FF               \ Call QUS1 with A = &FF, Y = &C to load the commander
\JSR QUS1               \ file to address &0B00
\
\LDA &0B00              \ If the first byte of the loaded file has bit 7 set,
\BMI SPS1+1             \ jump to SPS+1, which is the second byte of an LDA #0
\                       \ instruction, i.e. a BRK instruction, which will force
\                       \ an interrupt to call the address in BRKV, which is set
\                       \ to BR1... so this instruction restarts the game from
\                       \ the title screen. Valid commander files for the
\                       \ cassette version of Elite only have 0 for the first
\                       \ byte, as there are no missions in this version, so
\                       \ having bit 7 set is invalid anyway
\
\LDX #NT%               \ We have successfully loaded the commander file at
\                       \ &0B00, so now we want to copy it to the last saved
\                       \ commander data block at NA%+8, so we set up a counter
\                       \ in X to copy NT% bytes
\
\.LOL1
\
\LDA &0B00,X            \ Copy the X-th byte of &0B00 to the X-th byte of NA%+8
\STA NA%+8,X
\
\DEX                    \ Decrement the loop counter
\
\BPL LOL1               \ Loop back until we have copied all NT% bytes
\
\LDX #3                 \ Fall through into FX200 to disable the ESCAPE key and
\                       \ clear memory if the BREAK key is pressed (*FX 200,3)
\                       \ and return from the subroutine there

                        \ --- End of removed code ----------------------------->

\ ******************************************************************************
\
\       Name: FX200
\       Type: Subroutine
\   Category: Utility routines
\    Summary: Set the behaviour of the ESCAPE and BREAK keys
\
\ ------------------------------------------------------------------------------
\
\ This is the equivalent of a *FX 200 command, which controls the behaviour of
\ the ESCAPE and BREAK keys.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   Controls the behaviour as follows:
\
\                         * 0 = Enable ESCAPE key
\                               Normal BREAK key action
\
\                         * 1 = Disable ESCAPE key
\                               Normal BREAK key action
\
\                         * 2 = Enable ESCAPE key
\                               Clear memory if the BREAK key is pressed
\
\                         * 3 = Disable ESCAPE key
\                               Clear memory if the BREAK key is pressed
\
\ ******************************************************************************

.FX200_7

 LDY #0                 \ Call OSBYTE 200 with Y = 0, so the new value is set to
 LDA #200               \ X, and return from the subroutine using a tail call
 JMP OSBYTE

 RTS                    \ This instruction has no effect, as we already returned
                        \ from the subroutine

\ ---- moved from elite-source.asm lines 24114-24845 (main RAM) ----
\ ******************************************************************************
\
\       Name: EQSHP
\       Type: Subroutine
\   Category: Equipment
\    Summary: Show the Equip Ship screen (red key f3)
\  Deep dive: The Elite Demonstration Disc
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   err                 Beep, pause and go to the docking bay (i.e. show the
\                       Status Mode screen)
\
\   pres                Given an item number A with the item name in recursive
\                       token Y, show an error to say that the item is already
\                       present, refund the cost of the item, and then beep and
\                       exit to the docking bay (i.e. show the Status Mode
\                       screen)
\
\ ******************************************************************************

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\.bay
\
\JMP BAY                \ Go to the docking bay (i.e. show the Status Mode
\                       \ screen)

                        \ --- End of removed code ----------------------------->

.EQSHP_7

 JSR x4_DIALS           \ Call DIALS to update the dashboard

 LDA #32                \ Clear the top part of the screen, draw a border box,
 JSR x4_TT66            \ and set the current view type in QQ11 to 32 (Equip
                        \ Ship screen)

 LDA #12                \ Move the text cursor to column 12
 STA XC

 LDA #207               \ Print recursive token 47 ("EQUIP") followed by a space
 JSR spc_7

 LDA #185               \ Print recursive token 25 ("SHIP") and draw a
 JSR x4_NLIN3           \ horizontal line at pixel row 19 to box in the title

 LDA #%10000000         \ Set bit 7 of QQ17 to switch to Sentence Case, with the
 STA QQ17               \ next letter in capitals

 INC YC                 \ Move the text cursor down one line

 LDA tek                \ Fetch the tech level of the current system from tek
 CLC                    \ and add 3 (the tech level is stored as 0-14, so A is
 ADC #3                 \ now set to between 3 and 17)

 CMP #12                \ If A >= 12 then set A = 12, so A is now set to between
 BCC P%+4               \ 3 and 12
 LDA #12

 STA Q                  \ Set QQ25 = A (so QQ25 is in the range 3-12 and
 STA QQ25               \ represents the number of the most advanced item
 INC Q                  \ available in this system, which we can pass to gnum
                        \ below when asking which item we want to buy)
                        \
                        \ Set Q = A + 1 (so Q is in the range 4-13 and contains
                        \ QQ25 + 1, i.e. the highest item number on sale + 1)

 LDA #70                \ Set A = 70 - QQ14, where QQ14 contains the current
 SEC                    \ fuel in light years * 10, so this leaves the amount
 SBC QQ14               \ of fuel we need to fill 'er up (in light years * 10)

 ASL A                  \ The price of fuel is always 2 Cr per light year, so we
 STA PRXS_7             \ double A and store it in PRXS, as the first price in
                        \ the price list (which is reserved for fuel), and
                        \ because the table contains prices as price * 10, it's
                        \ in the right format (so tank containing 7.0 light
                        \ years of fuel would be 14.0 Cr, or a PRXS value of
                        \ 140)

                        \ --- Mod: Code added for Demonstration Disc: --------->

 LDA #3                 \ Set QQ25 to 3 so we show the smallest range of
 STA QQ25               \ equipment in the Equip Ship menu, overriding the
                        \ value that we calculated above

                        \ --- End of added code ------------------------------->

 LDX #1                 \ We are now going to work our way through the equipment
                        \ price list at PRXS, printing out the equipment that is
                        \ available at this station, so set a counter in X,
                        \ starting at 1, to hold the number of the current item
                        \ plus 1 (so the item number in X loops through 1-13)

.EQL1_7

 STX XX13               \ Store the current item number + 1 in XX13

 JSR x4_TT67            \ Print a newline

 LDX XX13               \ Print the current item number + 1 to 3 digits, left-
 CLC                    \ padding with spaces, and with no decimal point, so the
 JSR x4_pr2             \ items are numbered from 1

 JSR x4_TT162           \ Print a space

 LDA XX13               \ Print recursive token 104 + XX13, which will be in the
 CLC                    \ range 105 ("FUEL") to 116 ("GALACTIC HYPERSPACE ")
 ADC #104               \ so this prints the current item's name
 JSR x4_TT27

 LDA XX13               \ Call prx-3 to set (Y X) to the price of the item with
 JSR prx_7-3            \ number XX13 - 1 (as XX13 contains the item number + 1)

 SEC                    \ Set the C flag so we will print a decimal point when
                        \ we print the price

 LDA #25                \ Move the text cursor to column 25
 STA XC

 LDA #6                 \ Print the number in (Y X) to 6 digits, left-padding
 JSR x4_TT11            \ with spaces and including a decimal point, which will
                        \ be the correct price for this item as (Y X) contains
                        \ the price * 10, so the trailing zero will go after the
                        \ decimal point (i.e. 5250 will be printed as 525.0)

 LDX XX13               \ Increment the current item number in XX13
 INX

 CPX Q                  \ If X < Q, loop back up to print the next item on the
 BCC EQL1_7             \ list of equipment available at this station

 JSR x4_CLYNS           \ Clear the bottom three text rows of the upper screen,
                        \ and move the text cursor to the first cleared row

 LDA #127               \ Print recursive token 127 ("ITEM") followed by a
 JSR x4_prq             \ question mark

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\JSR gnum               \ Call gnum to get a number from the keyboard, which
\                       \ will be the number of the item we want to purchase,
\                       \ returning the number entered in A and R, and setting
\                       \ the C flag if the number is bigger than the highest
\                       \ item number in QQ25
\
\BEQ bay                \ If no number was entered, jump up to bay to go to the
\                       \ docking bay (i.e. show the Status Mode screen)
\
\BCS bay                \ If the number entered was too big, jump up to bay to
\                       \ go to the docking bay (i.e. show the Status Mode
\                       \ screen)

                        \ --- And replaced by: -------------------------------->

 LDA NOMSL              \ Set A to the number of missiles

 CMP #4                 \ Set the flags depending on whether we already have
                        \ four missiles

 LDA #2                 \ If we have fewer than four missiles, then set A = 2 to
 BCC equi1_7            \ use as the menu item for buying a missile, and jump
                        \ to equi1 to buy a missile by "choosing" this item

                        \ If we get here then we already have four missiles, so
                        \ now we check our fuel level

 LDA QQ14               \ Fetch our current fuel level from Q114 into A

 CMP #70                \ Set the flags depending on whether we already have a
                        \ full tank of fuel (7.0 light years)

 LDA #1                 \ If we have less than 7.0 light years of fuel, then set
 BCC equi1_7            \ A = 1 to use as the menu item for buying more fuel,
                        \ and jump to equi1 to buy a tank of fuel by "choosing"
                        \ this item

 JSR gnum_7             \ If we get here then we already have four missiles and
                        \ a full tank of fuel, so call gnum to choose a random
                        \ item from the menu, in the range 0 to QQ25 (where 0
                        \ denotes that we are choosing not to buy anything)
                        \
                        \ If this returns the C flag set, then the chosen item
                        \ is greater than or equal to QQ25, which we set to 3
                        \ above, so the following will only let us choose to
                        \ buy item 1 (fuel) or item 2 (missiles), as item 3
                        \ (large cargo bay) equals QQ25 and that will be deemed
                        \ too big and will set the C flag

.equi1_7

 STA R                  \ Store the chosen menu item in R, so we can try to buy
                        \ it

 BEQ equi2_7            \ If the menu item is zero then we are choosing not to
                        \ buy anything, so jump to equi2 to move on to the Buy
                        \ Cargo screen

 BCC equi3_7            \ If the number chosen was not too big, jump to equi3 to
                        \ buy the chosen item

.equi2_7

 JSR DelayFiveSeconds_7 \ Wait for five seconds (so when we show the Equip Ship
                        \ screen, we wait for five seconds when we have finished
                        \ with it)

 LDA #f1                \ Call TT102 to "press" the f1 key (Buy Cargo) and
 JMP x4_TT102           \ return from the subroutine using a tail call

.equi3_7

                        \ --- End of replacement ------------------------------>

 SBC #0                 \ Set A to the number entered - 1 (because the C flag is
                        \ clear), which will be the actual item number we want
                        \ to buy

 LDX #2                 \ Move the text cursor to column 2
 STX XC

 INC YC                 \ Move the text cursor down one line

 PHA                    \ While preserving the value in A, call eq to subtract
 JSR eq_7               \ the price of the item we want to buy (which is in A)
 PLA                    \ from our cash pot, but only if we have enough cash in
                        \ the pot. If we don't have enough cash, exit to the
                        \ docking bay (i.e. show the Status Mode screen)

 BNE et0_7              \ If A is not 0 (i.e. the item we've just bought is not
                        \ fuel), skip to et0

 STA MCNT               \ We just bought fuel, so we zero the main loop counter

 LDX #70                \ Set the current fuel level * 10 in QQ14 to 70, or 7.0
 STX QQ14               \ light years (a full tank)

.et0_7

 CMP #1                 \ If A is not 1 (i.e. the item we've just bought is not
 BNE et1_7              \ a missile), skip to et1

 LDX NOMSL              \ Fetch the current number of missiles from NOMSL into X

 INX                    \ Increment X to the new number of missiles

 LDY #117               \ Set Y to recursive token 117 ("ALL")

 CPX #5                 \ If buying this missile would give us 5 missiles, this
 BCS pres_7             \ is more than the maximum of 4 missiles that we can
                        \ fit, so jump to pres to show the error "All Present",
                        \ beep and exit to the docking bay (i.e. show the Status
                        \ Mode screen)

 STX NOMSL              \ Otherwise update the number of missiles in NOMSL

 JSR x4_msblob          \ Reset the dashboard's missile indicators so none of
                        \ them are targeted

.et1_7

 LDY #107               \ Set Y to recursive token 107 ("LARGE CARGO{sentence
                        \ case} BAY")

 CMP #2                 \ If A is not 2 (i.e. the item we've just bought is not
 BNE et2_7              \ a large cargo bay), skip to et2

 LDX #37                \ If our current cargo capacity in CRGO is 37, then we
 CPX CRGO               \ already have a large cargo bay fitted, so jump to pres
 BEQ pres_7             \ to show the error "Large Cargo Bay Present", beep and
                        \ exit to the docking bay (i.e. show the Status Mode
                        \ screen)

 STX CRGO               \ Otherwise we just scored ourselves a large cargo bay,
                        \ so update our current cargo capacity in CRGO to 37

.et2_7

 CMP #3                 \ If A is not 3 (i.e. the item we've just bought is not
 BNE et3_7              \ an E.C.M. system), skip to et3

 INY                    \ Increment Y to recursive token 108 ("E.C.M.SYSTEM")

 LDX ECM                \ If we already have an E.C.M. fitted (i.e. ECM is
 BNE pres_7             \ non-zero), jump to pres to show the error "E.C.M.
                        \ System Present", beep and exit to the docking bay
                        \ (i.e. show the Status Mode screen)

 DEC ECM                \ Otherwise we just took delivery of a brand new E.C.M.
                        \ system, so set ECM to &FF (as ECM was 0 before the DEC
                        \ instruction)

.et3_7

 CMP #4                 \ If A is not 4 (i.e. the item we've just bought is not
 BNE et4_7              \ an extra pulse laser), skip to et4

 JSR qv_7               \ Print a menu listing the four views, with a "View ?"
                        \ prompt, and ask for a view number, which is returned
                        \ in X (which now contains 0-3)

 LDA #4                 \ This instruction doesn't appear to do anything, as we
                        \ either don't need it (if we already have this laser)
                        \ or we set A to 4 below (if we buy it)

 LDY LASER,X            \ If there is no laser mounted in the chosen view (i.e.
 BEQ ed4_7              \ LASER+X, which contains the laser power for view X, is
                        \ zero), jump to ed4 to buy a pulse laser

.ed7_7

 LDY #187               \ Otherwise we already have a laser mounted in this
 BNE pres_7             \ view, so jump to pres with Y set to token 27
                        \ (" LASER") to show the error "Laser Present", beep
                        \ and exit to the docking bay (i.e. show the Status
                        \ Mode screen)

.ed4_7

 LDA #POW               \ We just bought a pulse laser for view X, so we need
 STA LASER,X            \ to fit it by storing the laser power for a pulse laser
                        \ (given in POW) in LASER+X

 LDA #4                 \ Set A to 4 as we just overwrote the original value,
                        \ and we still need it set correctly so we can continue
                        \ through the conditional statements for all the other
                        \ equipment

.et4_7

 CMP #5                 \ If A is not 5 (i.e. the item we've just bought is not
 BNE et5_7              \ an extra beam laser), skip to et5

 JSR qv_7               \ Print a menu listing the four views, with a "View ?"
                        \ prompt, and ask for a view number, which is returned
                        \ in X (which now contains 0-3)

 STX T1                 \ Store the view in T1 so we can retrieve it below

 LDA #5                 \ Set A to 5 as the call to qv will have overwritten
                        \ the original value, and we still need it set
                        \ correctly so we can continue through the conditional
                        \ statements for all the other equipment

 LDY LASER,X            \ If there is no laser mounted in the chosen view (i.e.
 BEQ ed5_7              \ LASER+X, which contains the laser power for view X,
                        \ is zero), jump to ed5 to buy a beam laser

\BPL P%+4               \ This instruction is commented out in the original
                        \ source, though it would have no effect (it would
                        \ simply skip the BMI if A is positive, which is what
                        \ BMI does anyway)

 BMI ed7_7              \ If there is a beam laser already mounted in the chosen
                        \ view (i.e. LASER+X has bit 7 set, which indicates a
                        \ beam laser rather than a pulse laser), skip back to
                        \ ed7 to print a "Laser Present" error, beep and exit
                        \ to the docking bay (i.e. show the Status Mode screen)

 LDA #4                 \ If we get here then we already have a pulse laser in
 JSR prx_7              \ the selected view, so we call prx to set (Y X) to the
                        \ price of equipment item number 4 (extra pulse laser)
                        \ so we can give a refund of the pulse laser

 JSR x4_MCASH           \ Add (Y X) cash to the cash pot in CASH, so we refund
                        \ the price of the pulse laser we are exchanging for a
                        \ new beam laser

.ed5_7

 LDA #POW+128           \ We just bought a beam laser for view X, so we need
 LDX T1                 \ to fit it by storing the laser power for a beam laser
 STA LASER,X            \ (given in POW+128) in LASER+X, using the view number
                        \ we stored in T1 earlier, as the call to prx will have
                        \ overwritten the original value in X

.et5_7

 LDY #111               \ Set Y to recursive token 111 ("FUEL SCOOPS")

 CMP #6                 \ If A is not 6 (i.e. the item we've just bought is not
 BNE et6_7              \ a fuel scoop), skip to et6

 LDX BST                \ If we already have fuel scoops fitted (i.e. BST is
 BEQ ed9_7              \ zero), jump to ed9, otherwise fall through into pres
                        \ to show the error "Fuel Scoops Present", beep and
                        \ exit to the docking bay (i.e. show the Status Mode
                        \ screen)

.pres_7

                        \ If we get here we need to show an error to say that
                        \ the item whose name is in recursive token Y is already
                        \ present, and then process a refund for the cost of
                        \ item number A

 STY K                  \ Store the item's name in K

 JSR prx_7              \ Call prx to set (Y X) to the price of equipment item
                        \ number A

 JSR x4_MCASH           \ Add (Y X) cash to the cash pot in CASH, as the station
                        \ already took the money for this item in the JSR eq
                        \ instruction above, but we can't fit the item, so need
                        \ our money back

 LDA K                  \ Print the recursive token in K (the item's name)
 JSR spc_7              \ followed by a space

 LDA #31                \ Print recursive token 145 ("PRESENT")
 JSR x4_TT27

.err_7

 JSR dn2_7              \ Call dn2 to make a short, high beep and delay for 1
                        \ second

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\JMP BAY                \ Jump to BAY to go to the docking bay (i.e. show the
\                       \ Status Mode screen)

                        \ --- And replaced by: -------------------------------->

 JMP equi2_7            \ Jump to equi2 to wait for five seconds and move on to
                        \ the Buy Cargo screen

                        \ --- End of replacement ------------------------------>

.ed9_7

 DEC BST                \ We just bought a shiny new fuel scoop, so set BST to
                        \ &FF (as BST was 0 before the jump to ed9 above)

.et6_7

 INY                    \ Increment Y to recursive token 112 ("E.C.M.SYSTEM")

 CMP #7                 \ If A is not 7 (i.e. the item we've just bought is not
 BNE et7_7              \ an escape pod), skip to et7

 LDX ESCP               \ If we already have an escape pod fitted (i.e. ESCP is
 BNE pres_7             \ non-zero), jump to pres to show the error "Escape Pod
                        \ Present", beep and exit to the docking bay (i.e. show
                        \ the Status Mode screen)

 DEC ESCP               \ Otherwise we just bought an escape pod, so set ESCP
                        \ to &FF (as ESCP was 0 before the DEC instruction)

.et7_7

 INY                    \ Increment Y to recursive token 113 ("ENERGY BOMB")

 CMP #8                 \ If A is not 8 (i.e. the item we've just bought is not
 BNE et8_7              \ an energy bomb), skip to et8

 LDX BOMB               \ If we already have an energy bomb fitted (i.e. BOMB
 BNE pres_7             \ is non-zero), jump to pres to show the error "Energy
                        \ Bomb Present", beep and exit to the docking bay (i.e.
                        \ show the Status Mode screen)

 LDX #&7F               \ Otherwise we just bought an energy bomb, so set BOMB
 STX BOMB               \ to &7F

.et8_7

 INY                    \ Increment Y to recursive token 114 ("ENERGY UNIT")

 CMP #9                 \ If A is not 9 (i.e. the item we've just bought is not
 BNE etA_7              \ an energy unit), skip to etA

 LDX ENGY               \ If we already have an energy unit fitted (i.e. ENGY is
 BNE pres_7             \ non-zero), jump to pres to show the error "Energy Unit
                        \ Present", beep and exit to the docking bay (i.e. show
                        \ the Status Mode screen)

 INC ENGY               \ Otherwise we just picked up an energy unit, so set
                        \ ENGY to 1 (as ENGY was 0 before the INC instruction)

.etA_7

 INY                    \ Increment Y to recursive token 115 ("DOCKING
                        \ COMPUTERS")

 CMP #10                \ If A is not 10 (i.e. the item we've just bought is not
 BNE etB_7              \ a docking computer), skip to etB

 LDX DKCMP              \ If we already have a docking computer fitted (i.e.
 BNE pres_7             \ DKCMP is non-zero), jump to pres to show the error
                        \ "Docking Computer Present", beep and exit to the
                        \ docking bay (i.e. show the Status Mode screen)

 DEC DKCMP              \ Otherwise we just got hold of a docking computer, so
                        \ set DKCMP to &FF (as DKCMP was 0 before the DEC
                        \ instruction)

.etB_7

 INY                    \ Increment Y to recursive token 116 ("GALACTIC
                        \ HYPERSPACE ")

 CMP #11                \ If A is not 11 (i.e. the item we've just bought is not
 BNE et9_7              \ a galactic hyperdrive), skip to et9

 LDX GHYP               \ If we already have a galactic hyperdrive fitted (i.e.
 BNE pres_7             \ GHYP is non-zero), jump to pres to show the error
                        \ "Galactic Hyperspace Present", beep and exit to the
                        \ docking bay (i.e. show the Status Mode screen)

 DEC GHYP               \ Otherwise we just splashed out on a galactic
                        \ hyperdrive, so set GHYP to &FF (as GHYP was 0 before
                        \ the DEC instruction)

.et9_7

 JSR dn_7               \ We are done buying equipment, so print the amount of
                        \ cash left in the cash pot, then make a short, high
                        \ beep to confirm the purchase, and delay for 1 second

 JMP EQSHP_7            \ Jump back up to EQSHP to show the Equip Ship screen
                        \ again and see if we can't track down another bargain

\ ******************************************************************************
\
\       Name: dn
\       Type: Subroutine
\   Category: Market
\    Summary: Print the amount of money we have left in the cash pot, then make
\             a short, high beep and delay for 1 second
\
\ ******************************************************************************

.dn_7

 JSR x4_TT162           \ Print a space

 LDA #119               \ Print recursive token 119 ("CASH:{cash} CR{crlf}")
 JSR spc_7              \ followed by a space

                        \ Fall through into dn2 to make a beep and delay for
                        \ 1 second before returning from the subroutine

\ ******************************************************************************
\
\       Name: dn2
\       Type: Subroutine
\   Category: Text
\    Summary: Make a short, high beep and delay for 1 second
\
\ ******************************************************************************

.dn2_7

 JSR x4_BEEP            \ Call the BEEP subroutine to make a short, high beep

 LDY #50                \ Wait for 50/50 of a second (1 second) and return
 JMP x4_DELAY           \ from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: eq
\       Type: Subroutine
\   Category: Equipment
\    Summary: Subtract the price of equipment from the cash pot
\
\ ------------------------------------------------------------------------------
\
\ If we have enough cash, subtract the price of a specified piece of equipment
\ from our cash pot and return from the subroutine. If we don't have enough
\ cash, exit to the docking bay (i.e. show the Status Mode screen).
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The item number of the piece of equipment (0-11) as
\                       shown in the table at PRXS
\
\ ******************************************************************************

.eq_7

 JSR prx_7              \ Call prx to set (Y X) to the price of equipment item
                        \ number A

 JSR LCASH_7            \ Subtract (Y X) cash from the cash pot, but only if
                        \ we have enough cash

 BCS c_7                \ If the C flag is set then we did have enough cash for
                        \ the transaction, so jump to c to return from the
                        \ subroutine (as c contains an RTS)

 LDA #197               \ Otherwise we don't have enough cash to buy this piece
 JSR x4_prq             \ of equipment, so print recursive token 37 ("CASH")
                        \ followed by a question mark

 JMP err_7              \ Jump to err to beep, pause and go to the docking bay
                        \ (i.e. show the Status Mode screen)

\ ******************************************************************************
\
\       Name: prx
\       Type: Subroutine
\   Category: Equipment
\    Summary: Return the price of a piece of equipment
\
\ ------------------------------------------------------------------------------
\
\ This routine returns the price of equipment as listed in the table at PRXS.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The item number of the piece of equipment (0-11) as
\                       shown in the table at PRXS
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   (Y X)               The item price in Cr * 10 (Y = high byte, X = low byte)
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   prx-3               Return the price of the item with number A - 1
\
\   c                   Contains an RTS
\
\ ******************************************************************************

 SEC                    \ Decrement A (for when this routine is called via
 SBC #1                 \ prx-3)

.prx_7

 ASL A                  \ Set Y = A * 2, so it can act as an index into the
 TAY                    \ PRXS table, which has two bytes per entry

 LDX PRXS_7,Y           \ Fetch the low byte of the price into X

 LDA PRXS_7+1,Y         \ Fetch the high byte of the price into A and transfer
 TAY                    \ it to X, so the price is now in (Y X)

.c_7

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: qv
\       Type: Subroutine
\   Category: Equipment
\    Summary: Print a menu of the four space views, for buying lasers
\
\ ------------------------------------------------------------------------------
\
\ Print a menu in the bottom-middle of the screen, at row 16, column 12, that
\ lists the four available space views, like this:
\
\                 0 Front
\                 1 Rear
\                 2 Left
\                 3 Right
\
\ Also print a "View ?" prompt and ask for a view number. The menu is shown
\ when we choose to buy a new laser in the Equip Ship screen.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   X                   The chosen view number (0-3)
\
\ ******************************************************************************

.qv_7

 LDY #16                \ Move the text cursor to row 16, and at the same time
 STY YC                 \ set Y to a counter going from 16 to 19 in the loop
                        \ below

.qv1_7

 LDX #12                \ Move the text cursor to column 12
 STX XC

 TYA                    \ Transfer the counter value from Y to A

 CLC                    \ Print ASCII character "0" - 16 + A, so as A goes from
 ADC #'0'-16            \ 16 to 19, this prints "0" through "3" followed by a
 JSR spc_7              \ space

 LDA YC                 \ Print recursive text token 80 + YC, so as YC goes from
 CLC                    \ 16 to 19, this prints "FRONT", "REAR", "LEFT" and
 ADC #80                \ "RIGHT"
 JSR x4_TT27

 INC YC                 \ Move the text cursor down a row, and increment the
                        \ counter in YC at the same time

 LDY YC                 \ Update Y with the incremented counter in YC

 CPY #20                \ If Y < 20 then loop back up to qv1 to print the next
 BCC qv1_7              \ view in the menu

.qv3_7

 JSR x4_CLYNS           \ Clear the bottom three text rows of the upper screen,
                        \ and move the text cursor to the first cleared row

.qv2_7

 LDA #175               \ Print recursive text token 15 ("VIEW ") followed by
 JSR x4_prq             \ a question mark

 JSR x4_TT217           \ Scan the keyboard until a key is pressed, and return
                        \ the key's ASCII code in A (and X)

 SEC                    \ Subtract ASCII "0" from the key pressed, to leave the
 SBC #'0'               \ numeric value of the key in A (if it was a number key)

 CMP #4                 \ If the number entered in A >= 4, then it is not a
 BCS qv3_7              \ valid view number, so jump back to qv3 to try again

 TAX                    \ We have a valid view number, so transfer it to X

 RTS                    \ Return from the subroutine
\ ---- moved from elite-source.asm lines 26014-26130 (bank 4) ----
\ ******************************************************************************
\
\       Name: tnpr
\       Type: Subroutine
\   Category: Market
\    Summary: Work out if we have space for a specific amount of cargo
\
\ ------------------------------------------------------------------------------
\
\ Given a market item and an amount, work out whether there is room in the
\ cargo hold for this item.
\
\ For standard tonne canisters, the limit is given by the type of cargo hold we
\ have, with a standard cargo hold having a capacity of 20t and an extended
\ cargo bay being 35t.
\
\ For items measured in kg (gold, platinum), g (gem-stones) and alien items,
\ the individual limit on each of these is 200 units.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The number of units of this market item
\
\   QQ29                The type of market item (see QQ23 for a list of market
\                       item numbers)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   A is preserved
\
\   C flag              Returns the result:
\
\                         * Set if there is no room for this item
\
\                         * Clear if there is room for this item
\
\ ******************************************************************************

.tnpr_7

 PHA                    \ Store A on the stack

 LDX #12                \ If QQ29 > 12 then jump to kg below, as this cargo
 CPX QQ29               \ type is gold, platinum, gem-stones or alien items,
 BCC kg_7               \ and they have different cargo limits to the standard
                        \ tonne canisters

.Tml_7

                        \ Here we count the tonne canisters we have in the hold
                        \ and add to A to see if we have enough room for A more
                        \ tonnes of cargo, using X as the loop counter, starting
                        \ with X = 12

 ADC QQ20,X             \ Set A = A + the number of tonnes we have in the hold
                        \ of market item number X. Note that the first time we
                        \ go round this loop, the C flag is set (as we didn't
                        \ branch with the BCC above, so the effect of this loop
                        \ is to count the number of tonne canisters in the hold,
                        \ and add 1

 DEX                    \ Decrement the loop counter

 BPL Tml_7              \ Loop back to add in the next market item in the hold,
                        \ until we have added up all market items from 12
                        \ (minerals) down to 0 (food)

 CMP CRGO               \ If A < CRGO then the C flag will be clear (we have
                        \ room in the hold)
                        \
                        \ If A >= CRGO then the C flag will be set (we do not
                        \ have room in the hold)
                        \
                        \ This works because A contains the number of canisters
                        \ plus 1, while CRGO contains our cargo capacity plus 2,
                        \ so if we actually have "a" canisters and a capacity
                        \ of "c", then:
                        \
                        \ A < CRGO means: a+1 <  c+2
                        \                 a   <  c+1
                        \                 a   <= c
                        \
                        \ So this is why the value in CRGO is 2 higher than the
                        \ actual cargo bay size, i.e. it's 22 for the standard
                        \ 20-tonne bay, and 37 for the large 35-tonne bay

 PLA                    \ Restore A from the stack

 RTS                    \ Return from the subroutine

.kg_7

                        \ Here we count the number of items of this type that
                        \ we already have in the hold, and add to A to see if
                        \ we have enough room for A more units

 LDY QQ29               \ Set Y to the item number we want to add

 ADC QQ20,Y             \ Set A = A + the number of units of this item that we
                        \ already have in the hold

 CMP #200               \ Is the result greater than 200 (the limit on
                        \ individual stocks of gold, platinum, gem-stones and
                        \ alien items)?
                        \
                        \ If so, this sets the C flag (no room)
                        \
                        \ Otherwise it is clear (we have room)

 PLA                    \ Restore A from the stack

 RTS                    \ Return from the subroutine

\ ---- moved from elite-source.asm lines 26228-26336 (bank 4) ----
\ ******************************************************************************
\
\       Name: TT146
\       Type: Subroutine
\   Category: Universe
\    Summary: Print the distance to the selected system in light years
\
\ ------------------------------------------------------------------------------
\
\ If it is non-zero, print the distance to the selected system in light years.
\ If it is zero, just move the text cursor down a line.
\
\ Specifically, if the distance in QQ8 is non-zero, print token 31 ("DISTANCE"),
\ then a colon, then the distance to one decimal place, then token 35 ("LIGHT
\ YEARS"). If the distance is zero, move the cursor down one line.
\
\ ******************************************************************************

.TT146_7

 LDA QQ8                \ Take the two bytes of the 16-bit value in QQ8 and
 ORA QQ8+1              \ OR them together to check whether there are any
 BNE TT63_7             \ non-zero bits, and if so, jump to TT63 to print the
                        \ distance

 INC YC                 \ The distance is zero, so we just move the text cursor
 RTS                    \ in YC down by one line and return from the subroutine

.TT63_7

 LDA #191               \ Print recursive token 31 ("DISTANCE") followed by
 JSR x4_TT68            \ a colon

 LDX QQ8                \ Load (Y X) from QQ8, which contains the 16-bit
 LDY QQ8+1              \ distance we want to show

 SEC                    \ Set the C flag so that the call to pr5 will include a
                        \ decimal point, and display the value as (Y X) / 10

 JSR x4_pr5             \ Print (Y X) to 5 digits, including a decimal point

 LDA #195               \ Set A to the recursive token 35 (" LIGHT YEARS") and
                        \ fall through into TT60 to print the token followed
                        \ by a paragraph break

\ ******************************************************************************
\
\       Name: TT60
\       Type: Subroutine
\   Category: Text
\    Summary: Print a text token and a paragraph break
\
\ ------------------------------------------------------------------------------
\
\ Print a text token (i.e. a character, control code, two-letter token or
\ recursive token). Then print a paragraph break (a blank line between
\ paragraphs) by moving the cursor down a line, setting Sentence Case, and then
\ printing a newline.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The text token to be printed
\
\ ******************************************************************************

.TT60_7

 JSR x4_TT27            \ Print the text token in A and fall through into TTX69
                        \ to print the paragraph break

\ ******************************************************************************
\
\       Name: TTX69
\       Type: Subroutine
\   Category: Text
\    Summary: Print a paragraph break
\
\ ------------------------------------------------------------------------------
\
\ Print a paragraph break (a blank line between paragraphs) by moving the cursor
\ down a line, setting Sentence Case, and then printing a newline.
\
\ ******************************************************************************

.TTX69_7

 INC YC                 \ Move the text cursor down a line

                        \ Fall through into TT69 to set Sentence Case and print
                        \ a newline

\ ******************************************************************************
\
\       Name: TT69
\       Type: Subroutine
\   Category: Text
\    Summary: Set Sentence Case and print a newline
\
\ ******************************************************************************

.TT69_7

 LDA #%10000000         \ Set bit 7 of QQ17 to switch to Sentence Case
 STA QQ17

                        \ Fall through into TT67 to print a newline

 JMP x4_TT67              \ (TT67 stays in bank 4: it was the fall-through)

\ ---- moved from elite-source.asm lines 26353-26732 (bank 4) ----
\ ******************************************************************************
\
\       Name: TT70
\       Type: Subroutine
\   Category: Universe
\    Summary: Display "MAINLY " and jump to TT72
\
\ ------------------------------------------------------------------------------
\
\ This subroutine is called by TT25 when displaying a system's economy.
\
\ ******************************************************************************

.TT70_7

 LDA #173               \ Print recursive token 13 ("MAINLY ")
 JSR x4_TT27

 JMP TT72_7             \ Jump to TT72 to continue printing system data as part
                        \ of routine TT25

\ ******************************************************************************
\
\       Name: spc
\       Type: Subroutine
\   Category: Text
\    Summary: Print a text token followed by a space
\
\ ------------------------------------------------------------------------------
\
\ Print a text token (i.e. a character, control code, two-letter token or
\ recursive token) followed by a space.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The text token to be printed
\
\ ******************************************************************************

.spc_7

 JSR x4_TT27            \ Print the text token in A

 JMP x4_TT162           \ Print a space and return from the subroutine using a
                        \ tail call

\ ******************************************************************************
\
\       Name: TT25
\       Type: Subroutine
\   Category: Universe
\    Summary: Show the Data on System screen (red key f6)
\  Deep dive: Generating system data
\             Galaxy and system seeds
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   TT72                Used by TT70 to re-enter the routine after displaying
\                       "MAINLY" for the economy type
\
\ ******************************************************************************

.TT25_7

 JSR x4_TT66m2          \ Clear the top part of the screen, draw a border box,
                        \ and set the current view type in QQ11 to 1

 LDA #9                 \ Move the text cursor to column 9
 STA XC

 LDA #163               \ Print recursive token 3 as a title in capitals at
 JSR x4_TT27            \ the top ("DATA ON {selected system name}")

 JSR x4_NLIN            \ Draw a horizontal line underneath the title

 JSR TTX69_7            \ Print a paragraph break and set Sentence Case

 INC YC                 \ Move the text cursor down one more line

 JSR TT146_7            \ If the distance to this system is non-zero, print
                        \ "DISTANCE", then the distance, "LIGHT YEARS" and a
                        \ paragraph break, otherwise just move the cursor down
                        \ a line

 LDA #194               \ Print recursive token 34 ("ECONOMY") followed by
 JSR x4_TT68            \ a colon

 LDA QQ3                \ The system economy is determined by the value in QQ3,
                        \ so fetch it into A. First we work out the system's
                        \ prosperity as follows:
                        \
                        \   QQ3 = 0 or 5 = %000 or %101 = Rich
                        \   QQ3 = 1 or 6 = %001 or %110 = Average
                        \   QQ3 = 2 or 7 = %010 or %111 = Poor
                        \   QQ3 = 3 or 4 = %011 or %100 = Mainly

 CLC                    \ If (QQ3 + 1) >> 1 = %10, i.e. if QQ3 = %011 or %100
 ADC #1                 \ (3 or 4), then call TT70, which prints "MAINLY " and
 LSR A                  \ jumps down to TT72 to print the type of economy
 CMP #%00000010
 BEQ TT70_7

 LDA QQ3                \ If (QQ3 + 1) >> 1 < %10, i.e. if QQ3 = %000, %001 or
 BCC TT71_7             \ %010 (0, 1 or 2), then jump to TT71 with A set to the
                        \ original value of QQ3

 SBC #5                 \ Here QQ3 = %101, %110 or %111 (5, 6 or 7), so subtract
 CLC                    \ 5 to bring it down to 0, 1 or 2 (the C flag is already
                        \ set so the SBC will be correct)

.TT71_7

 ADC #170               \ A is now 0, 1 or 2, so print recursive token 10 + A.
 JSR x4_TT27            \ This means that:
                        \
                        \   QQ3 = 0 or 5 prints token 10 ("RICH ")
                        \   QQ3 = 1 or 6 prints token 11 ("AVERAGE ")
                        \   QQ3 = 2 or 7 prints token 12 ("POOR ")

.TT72_7

 LDA QQ3                \ Now to work out the type of economy, which is
 LSR A                  \ determined by bit 2 of QQ3, as follows:
 LSR A                  \
                        \   QQ3 bit 2 = 0 = Industrial
                        \   QQ3 bit 2 = 1 = Agricultural
                        \
                        \ So we fetch QQ3 into A and set A = bit 2 of QQ3 using
                        \ two right shifts (which will work as QQ3 is only a
                        \ 3-bit number)

 CLC                    \ Print recursive token 8 + A, followed by a paragraph
 ADC #168               \ break and Sentence Case, so:
 JSR TT60_7             \
                        \   QQ3 bit 2 = 0 prints token 8 ("INDUSTRIAL")
                        \   QQ3 bit 2 = 1 prints token 9 ("AGRICULTURAL")

 LDA #162               \ Print recursive token 2 ("GOVERNMENT") followed by
 JSR x4_TT68            \ a colon

 LDA QQ4                \ The system's government is determined by the value in
                        \ QQ4, so fetch it into A

 CLC                    \ Print recursive token 17 + A, followed by a paragraph
 ADC #177               \ break and Sentence Case, so:
 JSR TT60_7             \
                        \   QQ4 = 0 prints token 17 ("ANARCHY")
                        \   QQ4 = 1 prints token 18 ("FEUDAL")
                        \   QQ4 = 2 prints token 19 ("MULTI-GOVERNMENT")
                        \   QQ4 = 3 prints token 20 ("DICTATORSHIP")
                        \   QQ4 = 4 prints token 21 ("COMMUNIST")
                        \   QQ4 = 5 prints token 22 ("CONFEDERACY")
                        \   QQ4 = 6 prints token 23 ("DEMOCRACY")
                        \   QQ4 = 7 prints token 24 ("CORPORATE STATE")

 LDA #196               \ Print recursive token 36 ("TECH.LEVEL") followed by a
 JSR x4_TT68            \ colon

 LDX QQ5                \ Fetch the tech level from QQ5 and increment it, as it
 INX                    \ is stored in the range 0-14 but the displayed range
                        \ should be 1-15

 CLC                    \ Call pr2 to print the technology level as a
 JSR x4_pr2             \ three-digit number without a decimal point (by
                        \ clearing the C flag)

 JSR TTX69_7            \ Print a paragraph break and set Sentence Case

 LDA #192               \ Print recursive token 32 ("POPULATION") followed by a
 JSR x4_TT68            \ colon

 SEC                    \ Call pr2 to print the population as a three-digit
 LDX QQ6                \ number with a decimal point (by setting the C flag),
 JSR x4_pr2             \ so the number printed will be population / 10

 LDA #198               \ Print recursive token 38 (" BILLION"), followed by a
 JSR TT60_7             \ paragraph break and Sentence Case

 LDA #'('               \ Print an opening bracket
 JSR x4_TT27

 LDA QQ15+4             \ Now to calculate the species, so first check bit 7 of
 BMI TT75_7             \ s2_lo, and if it is set, jump to TT75 as this is an
                        \ alien species

 LDA #188               \ Bit 7 of s2_lo is clear, so print recursive token 28
 JSR x4_TT27            \ ("HUMAN COLONIAL")

 JMP TT76_7             \ Jump to TT76 to print "S)" and a paragraph break, so
                        \ the whole species string is "(HUMAN COLONIALS)"

.TT75_7

 LDA QQ15+5             \ This is an alien species, and we start with the first
 LSR A                  \ adjective, so fetch bits 2-7 of s2_hi into A and push
 LSR A                  \ onto the stack so we can use this later
 PHA

 AND #%00000111         \ Set A = bits 0-2 of A (so that's bits 2-4 of s2_hi)

 CMP #3                 \ If A >= 3, jump to TT205 to skip the first adjective,
 BCS TT205_7

 ADC #227               \ Otherwise A = 0, 1 or 2, so print recursive token
 JSR spc_7              \ 67 + A, followed by a space, so:
                        \
                        \   A = 0 prints token 67 ("LARGE") and a space
                        \   A = 1 prints token 68 ("FIERCE") and a space
                        \   A = 2 prints token 69 ("SMALL") and a space

.TT205_7

 PLA                    \ Now for the second adjective, so restore A to bits
 LSR A                  \ 2-7 of s2_hi, and throw away bits 2-4 to leave
 LSR A                  \ A = bits 5-7 of s2_hi
 LSR A

 CMP #6                 \ If A >= 6, jump to TT206 to skip the second adjective
 BCS TT206_7

 ADC #230               \ Otherwise A = 0 to 5, so print recursive token
 JSR spc_7              \ 70 + A, followed by a space, so:
                        \
                        \   A = 0 prints token 70 ("GREEN") and a space
                        \   A = 1 prints token 71 ("RED") and a space
                        \   A = 2 prints token 72 ("YELLOW") and a space
                        \   A = 3 prints token 73 ("BLUE") and a space
                        \   A = 4 prints token 74 ("BLACK") and a space
                        \   A = 5 prints token 75 ("HARMLESS") and a space

.TT206_7

 LDA QQ15+3             \ Now for the third adjective, so EOR the high bytes of
 EOR QQ15+1             \ s0 and s1 and extract bits 0-2 of the result:
 AND #%00000111         \
 STA QQ19               \   A = (s0_hi EOR s1_hi) AND %111
                        \
                        \ storing the result in QQ19 so we can use it later

 CMP #6                 \ If A >= 6, jump to TT207 to skip the third adjective
 BCS TT207_7

 ADC #236               \ Otherwise A = 0 to 5, so print recursive token
 JSR spc_7              \ 76 + A, followed by a space, so:
                        \
                        \   A = 0 prints token 76 ("SLIMY") and a space
                        \   A = 1 prints token 77 ("BUG-EYED") and a space
                        \   A = 2 prints token 78 ("HORNED") and a space
                        \   A = 3 prints token 79 ("BONY") and a space
                        \   A = 4 prints token 80 ("FAT") and a space
                        \   A = 5 prints token 81 ("FURRY") and a space

.TT207_7

 LDA QQ15+5             \ Now for the actual species, so take bits 0-1 of
 AND #%00000011         \ s2_hi, add this to the value of A that we used for
 CLC                    \ the third adjective, and take bits 0-2 of the result
 ADC QQ19
 AND #%00000111

 ADC #242               \ A = 0 to 7, so print recursive token 82 + A, so:
 JSR x4_TT27            \
                        \   A = 0 prints token 82 ("RODENT")
                        \   A = 1 prints token 83 ("FROG")
                        \   A = 2 prints token 84 ("LIZARD")
                        \   A = 3 prints token 85 ("LOBSTER")
                        \   A = 4 prints token 86 ("BIRD")
                        \   A = 5 prints token 87 ("HUMANOID")
                        \   A = 6 prints token 88 ("FELINE")
                        \   A = 7 prints token 89 ("INSECT")

.TT76_7

 LDA #'S'               \ Print an "S" to pluralise the species
 JSR x4_TT27

 LDA #')'               \ And finally, print a closing bracket, followed by a
 JSR TT60_7             \ paragraph break and Sentence Case, to end the species
                        \ section

 LDA #193               \ Print recursive token 33 ("GROSS PRODUCTIVITY"),
 JSR x4_TT68            \ followed by a colon

 LDX QQ7                \ Fetch the 16-bit productivity value from QQ7 into
 LDY QQ7+1              \ (Y X)

 JSR x4_pr6             \ Print (Y X) to 5 digits with no decimal point

 JSR x4_TT162           \ Print a space

 LDA #0                 \ Set QQ17 = 0 to switch to ALL CAPS
 STA QQ17

 LDA #'M'               \ Print "M"
 JSR x4_TT27

 LDA #226               \ Print recursive token 66 (" CR"), followed by a
 JSR TT60_7             \ paragraph break and Sentence Case

 LDA #250               \ Print recursive token 90 ("AVERAGE RADIUS"), followed
 JSR x4_TT68            \ by a colon

                        \ The average radius is calculated like this:
                        \
                        \   ((s2_hi AND %1111) + 11) * 256 + s1_hi
                        \
                        \ or, in terms of memory locations:
                        \
                        \   ((QQ15+5 AND %1111) + 11) * 256 + QQ15+3
                        \
                        \ Because the multiplication is by 256, this is the
                        \ same as saying a 16-bit number, with high byte:
                        \
                        \   (QQ15+5 AND %1111) + 11
                        \
                        \ and low byte:
                        \
                        \   QQ15+3
                        \
                        \ so we can set this up in (Y X) and call the pr5
                        \ routine to print it out

 LDA QQ15+5             \ Set A = QQ15+5
 LDX QQ15+3             \ Set X = QQ15+3

 AND #%00001111         \ Set Y = (A AND %1111) + 11
 CLC
 ADC #11
 TAY

 JSR x4_pr5             \ Print (Y X) to 5 digits, not including a decimal
                        \ point, as the C flag will be clear (as the maximum
                        \ radius will always fit into 16 bits)

 JSR x4_TT162           \ Print a space

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\LDA #'k'               \ Print "km", returning from the subroutine using a
\JSR TT26               \ tail call
\LDA #'m'
\JMP TT26

                        \ --- And replaced by: -------------------------------->

 LDA #'k'               \ Print "km"
 JSR x4_TT26
 LDA #'m'
 JSR x4_TT26

                        \ Fall through into DelayFiveSeconds to delay for five
                        \ seconds before returning from the subroutine (so when
                        \ we show the Data on System screen, we show it for five
                        \ seconds)

                        \ --- End of replacement ------------------------------>

\ ******************************************************************************
\
\       Name: DelayFiveSeconds
\       Type: Subroutine
\   Category: Utility routines
\    Summary: Wait for 5.1 seconds
\  Deep dive: The Elite Demonstration Disc
\
\ ******************************************************************************

                        \ --- Mod: Code added for Demonstration Disc: --------->

.DelayFiveSeconds_7

 LDY #255               \ Wait for 255/50 of a second (5.1 seconds) and return
 JMP x4_DELAY           \ from the subroutine using a tail call

                        \ --- End of added code ------------------------------->

\ ---- moved from elite-source.asm lines 26851-26946 (bank 4) ----
\ ******************************************************************************
\
\       Name: TT22
\       Type: Subroutine
\   Category: Charts
\    Summary: Show the Long-range Chart (red key f4)
\  Deep dive: A sense of scale
\
\ ******************************************************************************

.TT22_7

 LDA #64                \ Clear the top part of the screen, draw a border box,
 JSR x4_TT66            \ and set the current view type in QQ11 to 32 (Long-
                        \ range Chart)

 LDA #7                 \ Move the text cursor to column 7
 STA XC

 JSR x4_TT81            \ Set the seeds in QQ15 to those of system 0 in the
                        \ current galaxy (i.e. copy the seeds from QQ21 to QQ15)

 LDA #199               \ Print recursive token 39 ("GALACTIC CHART{galaxy
 JSR x4_TT27            \ number right-aligned to width 3}")

 JSR x4_NLIN            \ Draw a horizontal line at pixel row 23 to box in the
                        \ title and act as the top frame of the chart, and move
                        \ the text cursor down one line

 LDA #152               \ Draw a screen-wide horizontal line at pixel row 152
 JSR x4_NLIN2           \ for the bottom edge of the chart, so the chart itself
                        \ is 128 pixels high, starting on row 24 and ending on
                        \ row 151

 JSR TT14_7             \ Call TT14 to draw a circle with crosshairs at the
                        \ current system's galactic coordinates

 LDX #0                 \ We're now going to plot each of the galaxy's systems,
                        \ so set up a counter in X for each system, starting at
                        \ 0 and looping through to 255

.TT83_7

 STX XSAV               \ Store the counter in XSAV

 LDX QQ15+3             \ Fetch the s1_hi seed into X, which gives us the
                        \ galactic x-coordinate of this system

 LDY QQ15+4             \ Fetch the s2_lo seed and set bits 4 and 6, storing the
 TYA                    \ result in ZZ to give a random number between 80 and
 ORA #%01010000         \ (but which will always be the same for this system).
 STA ZZ                 \ We use this value to determine the size of the point
                        \ for this system on the chart by passing it as the
                        \ distance argument to the PIXEL routine below

 LDA QQ15+1             \ Fetch the s0_hi seed into A, which gives us the
                        \ galactic y-coordinate of this system

 LSR A                  \ We halve the y-coordinate because the galaxy in
                        \ in Elite is rectangular rather than square, and is
                        \ twice as wide (x-axis) as it is high (y-axis), so the
                        \ chart is 256 pixels wide and 128 high

 CLC                    \ Add 24 to the halved y-coordinate and store in XX15+1
 ADC #24                \ (as the top of the chart is on pixel row 24, just
 STA XX15+1             \ below the line we drew on row 23 above)

 JSR x4_PIXEL           \ Call PIXEL to draw a point at (X, A), with the size of
                        \ the point dependent on the distance specified in ZZ
                        \ (so a high value of ZZ will produce a one-pixel point,
                        \ a medium value will produce a two-pixel dash, and a
                        \ small value will produce a four-pixel square)

 JSR x4_TT20            \ We want to move on to the next system, so call TT20
                        \ to twist the three 16-bit seeds in QQ15

 LDX XSAV               \ Restore the loop counter from XSAV

 INX                    \ Increment the counter

 BNE TT83_7             \ If X > 0 then we haven't done all 256 systems yet, so
                        \ loop back up to TT83

 LDA QQ9                \ Set QQ19 to the selected system's x-coordinate
 STA QQ19

 LDA QQ10               \ Set QQ19+1 to the selected system's y-coordinate,
 LSR A                  \ halved to fit it into the chart
 STA QQ19+1

 LDA #4                 \ Set QQ19+2 to size 4 for the crosshairs size
 STA QQ19+2

                        \ Fall through into TT15 to draw crosshairs of size 4 at
                        \ the selected system's coordinates

 JMP x4_TT15              \ (TT15 stays in bank 4: it was the fall-through)

\ ---- moved from elite-source.asm lines 27090-27903 (bank 4) ----
\ ******************************************************************************
\
\       Name: TT14
\       Type: Subroutine
\   Category: Drawing circles
\    Summary: Draw a circle with crosshairs on a chart
\
\ ------------------------------------------------------------------------------
\
\ Draw a circle with crosshairs at the current system's galactic coordinates.
\
\ ******************************************************************************

.TT126_7

 LDA #104               \ Set QQ19 = 104, for the x-coordinate of the centre of
 STA QQ19               \ the fixed circle on the Short-range Chart

 LDA #90                \ Set QQ19+1 = 90, for the y-coordinate of the centre of
 STA QQ19+1             \ the fixed circle on the Short-range Chart

 LDA #16                \ Set QQ19+2 = 16, the size of the crosshairs on the
 STA QQ19+2             \ Short-range Chart

 JSR x4_TT15            \ Draw the set of crosshairs defined in QQ19, at the
                        \ exact coordinates as this is the Short-range Chart

 LDA QQ14               \ Set K to the fuel level from QQ14, so this can act as
 STA K                  \ the circle's radius (70 being a full tank)

 JMP TT128_7            \ Jump to TT128 to draw a circle with the centre at the
                        \ same coordinates as the crosshairs, (QQ19, QQ19+1),
                        \ and radius K that reflects the current fuel levels,
                        \ returning from the subroutine using a tail call

.TT14_7

 LDA QQ11               \ If the current view is the Short-range Chart, which
 BMI TT126_7            \ is the only view with bit 7 set, then jump up to TT126
                        \ to draw the crosshairs and circle for that view

                        \ Otherwise this is the Long-range Chart, so we draw the
                        \ crosshairs and circle for that view instead

 LDA QQ14               \ Set K to the fuel level from QQ14 divided by 4, so
 LSR A                  \ this can act as the circle's radius (70 being a full
 LSR A                  \ tank, which divides down to a radius of 17)
 STA K

 LDA QQ0                \ Set QQ19 to the x-coordinate of the current system,
 STA QQ19               \ which will be the centre of the circle and crosshairs
                        \ we draw

 LDA QQ1                \ Set QQ19+1 to the y-coordinate of the current system,
 LSR A                  \ halved because the galactic chart is half as high as
 STA QQ19+1             \ it is wide, which will again be the centre of the
                        \ circle and crosshairs we draw

 LDA #7                 \ Set QQ19+2 = 7, the size of the crosshairs on the
 STA QQ19+2             \ Long-range Chart

 JSR x4_TT15            \ Draw the set of crosshairs defined in QQ19, which will
                        \ be drawn 24 pixels to the right of QQ19+1

 LDA QQ19+1             \ Add 24 to the y-coordinate of the crosshairs in QQ19+1
 CLC                    \ so that the centre of the circle matches the centre
 ADC #24                \ of the crosshairs
 STA QQ19+1

                        \ Fall through into TT128 to draw a circle with the
                        \ centre at the same coordinates as the crosshairs,
                        \ (QQ19, QQ19+1), and radius K that reflects the
                        \ current fuel levels

\ ******************************************************************************
\
\       Name: TT128
\       Type: Subroutine
\   Category: Drawing circles
\    Summary: Draw a circle on a chart
\  Deep dive: Drawing circles
\
\ ------------------------------------------------------------------------------
\
\ Draw a circle with the centre at (QQ19, QQ19+1) and radius K.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   QQ19                The x-coordinate of the centre of the circle
\
\   QQ19+1              The y-coordinate of the centre of the circle
\
\   K                   The radius of the circle
\
\ ******************************************************************************

.TT128_7

 LDA QQ19               \ Set K3 = the x-coordinate of the centre
 STA K3

 LDA QQ19+1             \ Set K4 = the y-coordinate of the centre
 STA K4

 LDX #0                 \ Set the high bytes of K3(1 0) and K4(1 0) to 0
 STX K4+1
 STX K3+1

\STX LSX                \ This instruction is commented out in the original
                        \ source

 INX                    \ Set LSP = 1 to reset the ball line heap
 STX LSP

 LDX #2                 \ Set STP = 2, the step size for the circle
 STX STP

 JSR x4_CIRCLE2         \ Call CIRCLE2 to draw a circle with the centre at
                        \ (K3(1 0), K4(1 0)) and radius K

\LDA #&FF               \ These instructions are commented out in the original
\STA LSX                \ source

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TT219
\       Type: Subroutine
\   Category: Market
\    Summary: Show the Buy Cargo screen (red key f1)
\  Deep dive: The Elite Demonstration Disc
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   BAY2                Jump into the main loop at FRCE, setting the key
\                       "pressed" to red key f9 (so we show the Inventory
\                       screen)
\
\ ******************************************************************************

.TT219_7

\LDA #2                 \ This instruction is commented out in the original
                        \ source. Perhaps this view originally had a QQ11 value
                        \ of 2, but it turned out not to need its own unique ID,
                        \ so the authors found they could just use a view value
                        \ of 1 and save an instruction at the same time?

 JSR x4_TT66m2          \ Clear the top part of the screen, draw a border box,
                        \ and set the current view type in QQ11 to 1

 JSR TT163_7            \ Print the column headers for the prices table

 LDA #%10000000         \ Set bit 7 of QQ17 to switch to Sentence Case, with the
 STA QQ17               \ next letter in capitals

\JSR FLKB               \ This instruction is commented out in the original
                        \ source. It calls a routine to flush the keyboard
                        \ buffer (FLKB) that isn't present in the cassette
                        \ version but is in other versions

 LDA #0                 \ We're going to loop through all the available market
 STA QQ29               \ items, so we set up a counter in QQ29 to denote the
                        \ current item and start it at 0

.TT220_7

 JSR TT151_7            \ Call TT151 to print the item name, market price and
                        \ availability of the current item, and set QQ24 to the
                        \ item's price / 4, QQ25 to the quantity available and
                        \ QQ19+1 to byte #1 from the market prices table for
                        \ this item

 LDA QQ25               \ If there are some of the current item available, jump
 BNE TT224_7            \ to TT224 below to see if we want to buy any

 JMP TT222_7            \ Otherwise there are none available, so jump down to
                        \ TT222 to skip this item

.TQ4_7

 LDY #176               \ Set Y to the recursive token 16 ("QUANTITY")

.Tc_7

 JSR x4_TT162           \ Print a space

 TYA                    \ Print the recursive token in Y followed by a question
 JSR x4_prq             \ mark

.TTX224_7

 JSR dn2_7              \ Call dn2 to make a short, high beep and delay for 1
                        \ second

.TT224_7

 JSR x4_CLYNS           \ Clear the bottom three text rows of the upper screen,
                        \ and move the text cursor to the first cleared row

 LDA #204               \ Print recursive token 44 ("QUANTITY OF ")
 JSR x4_TT27

 LDA QQ29               \ Print recursive token 48 + QQ29, which will be in the
 CLC                    \ range 48 ("FOOD") to 64 ("ALIEN ITEMS"), so this
 ADC #208               \ prints the current item's name
 JSR x4_TT27

 LDA #'/'               \ Print "/"
 JSR x4_TT27

 JSR TT152_7            \ Print the unit ("t", "kg" or "g") for the current item
                        \ (as the call to TT151 above set QQ19+1 with the
                        \ appropriate value)

 LDA #'?'               \ Print "?"
 JSR x4_TT27

 JSR x4_TT67            \ Print a newline

 LDX #0                 \ These instructions have no effect, as they are
 STX R                  \ repeated at the start of gnum, which we call next.
 LDX #12                \ Perhaps they were left behind when code was moved from
 STX T1                 \ here into gnum, and weren't deleted?

\.TT223                 \ This label is commented out in the original source,
                        \ and is a duplicate of a label in gnum, so this could
                        \ also be a remnant if the code in gnum was originally
                        \ here, but got moved into the gnum subroutine

 JSR gnum_7             \ Call gnum to get a number from the keyboard, which
                        \ will be the quantity of this item we want to purchase,
                        \ returning the number entered in A and R

 BCS TQ4_7              \ If gnum set the C flag, the number entered is greater
                        \ than the quantity available, so jump up to TQ4 to
                        \ display a "Quantity?" error, beep, clear the number
                        \ and try again

 STA P                  \ Otherwise we have a valid purchase quantity entered,
                        \ so store the amount we want to purchase in P

 JSR tnpr_7             \ Call tnpr to work out whether there is room in the
                        \ cargo hold for this item

 LDY #206               \ Set Y to recursive token 46 (" CARGO{sentence case}")
                        \ to pass to the Tc routine if we call it

 BCS Tc_7               \ If the C flag is set, then there is no room in the
                        \ cargo hold, jump up to Tc to print a "Cargo?" error,
                        \ beep, clear the number and try again

 LDA QQ24               \ There is room in the cargo hold, so now to check
 STA Q                  \ whether we have enough cash, so fetch the item's
                        \ price / 4, which was returned in QQ24 by the call
                        \ to TT151 above and store it in Q

 JSR GCASH_7            \ Call GCASH to calculate:
                        \
                        \   (Y X) = P * Q * 4
                        \
                        \ which will be the total price of this transaction
                        \ (as P contains the purchase quantity and Q contains
                        \ the item's price / 4)

 JSR LCASH_7            \ Subtract (Y X) cash from the cash pot in CASH

 LDY #197               \ If the C flag is clear, we didn't have enough cash,
 BCC Tc_7               \ so set Y to the recursive token 37 ("CASH") and jump
                        \ up to Tc to print a "Cash?" error, beep, clear the
                        \ number and try again

 LDY QQ29               \ Fetch the current market item number from QQ29 into Y

 LDA R                  \ Set A to the number of items we just purchased (this
                        \ was set by gnum above)

 PHA                    \ Store the quantity just purchased on the stack

 CLC                    \ Add the number purchased to the Y-th byte of QQ20,
 ADC QQ20,Y             \ which contains the number of items of this type in
 STA QQ20,Y             \ our hold (so this transfers the bought items into our
                        \ cargo hold)

 LDA AVL,Y              \ Subtract the number of items from the Y-th byte of
 SEC                    \ AVL, which contains the number of items of this type
 SBC R                  \ that are available on the market
 STA AVL,Y

 PLA                    \ Restore the quantity just purchased

 BEQ TT222_7            \ If we didn't buy anything, jump to TT222 to skip the
                        \ following instruction

 JSR dn_7               \ Call dn to print the amount of cash left in the cash
                        \ pot, then make a short, high beep to confirm the
                        \ purchase, and delay for 1 second

.TT222_7

 LDA QQ29               \ Move the text cursor to row QQ29 + 5 (where QQ29 is
 CLC                    \ the item number, starting from 0)
 ADC #5
 STA YC

 LDA #0                 \ Move the text cursor to column 0
 STA XC

 INC QQ29               \ Increment QQ29 to point to the next item

 LDA QQ29               \ If QQ29 >= 17 then jump to BAY2 as we have done the
 CMP #17                \ last item
 BCS BAY2_7

 JMP TT220_7            \ Otherwise loop back to TT220 to print the next market
                        \ item

.BAY2_7

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\LDA #f9                \ Jump into the main loop at FRCE, setting the key
\JMP FRCE               \ "pressed" to red key f9 (so we show the Inventory
\                       \ screen)

                        \ --- And replaced by: -------------------------------->

 LDA #f9                \ Call TT102 to "press" the f9 key (Inventory) and
 JSR x4_TT102           \ wait for five seconds (the delay has been added to
                        \ TT210)

.buyc1_7

 JSR TT22_7             \ Jump to TT22 to show the Long-range Chart

 JSR x4_TT103           \ Draw small crosshairs at coordinates (QQ9, QQ10),
                        \ which will erase the crosshairs currently there

 JSR x4_DORND           \ Set (QQ9, QQ10) to a random galactic coordinate so
 STA QQ9                \ we select and show the distance to a randomly selected
 JSR x4_DORND           \ system when we "press" the "D" key below
 STA QQ10

 JSR x4_TT103           \ Draw small crosshairs at coordinates (QQ9, QQ10),
                        \ which will draw the crosshairs at the newly chosen
                        \ random coordinates

 LDA #&32               \ Call TT102 to "press" the "D" key to move the
 JSR x4_TT102           \ crosshairs to the nearest system to the random
                        \ coordinates that we just set, and then print the
                        \ distance to that system

 LDY #99                \ Wait for 99/50 of a second (1.98 seconds)
 JSR x4_DELAY

 JSR TT25_7             \ Jump to TT25 to show the Data on System screen and
                        \ wait for five seconds (the delay has been added to
                        \ TT25, which falls through into DelayFiveSeconds)

 JSR x4_DORND           \ Set A and X to random numbers

 CMP #180               \ If A < 180 (70% chance), loop back to buyc1 to show
 BCC buyc1_7            \ data for another randomly picked system

 LDA #f8                \ Call TT102 to "press" the f8 key (Status Mode) and
 JSR x4_TT102           \ wait for five seconds (the delay has been added to
                        \ TT102)

 JSR x4_ping            \ Set the target system coordinates (QQ9, QQ10) to the
                        \ current system coordinates (QQ0, QQ1) we just loaded

 LDA #f0                \ Jump into the main game loop at FRCE, setting the key
 JMP j4_FRCE            \ "pressed" to red key f0 (so we launch from the
                        \ station)

                        \ --- End of replacement ------------------------------>

\ ******************************************************************************
\
\       Name: gnum
\       Type: Subroutine
\   Category: Market
\    Summary: Get a number from the keyboard
\
\ ------------------------------------------------------------------------------
\
\ Get a number from the keyboard, up to the maximum number in QQ25, for the
\ buying and selling of cargo and equipment.
\
\ Pressing a key with an ASCII code less than ASCII "0" will return a 0 in A (so
\ that includes pressing Space or Return), while pressing a key with an ASCII
\ code greater than ASCII "9" will jump to the Inventory screen (so that
\ includes all letters and most punctuation).
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   QQ25                The maximum number allowed
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   The number entered
\
\   R                   Also contains the number entered
\
\   C flag              Set if the number is too large (> QQ25), clear otherwise
\
\ ******************************************************************************

.gnum_7

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\LDX #0                 \ We will build the number entered in R, so initialise
\STX R                  \ it with 0
\
\LDX #12                \ We will check for up to 12 key presses, so set a
\STX T1                 \ counter in T1
\
\.TT223
\
\JSR TT217              \ Scan the keyboard until a key is pressed, and return
\                       \ the key's ASCII code in A (and X)
\
\STA Q                  \ Store the key pressed in Q
\
\SEC                    \ Subtract ASCII "0" from the key pressed, to leave the
\SBC #'0'               \ numeric value of the key in A (if it was a number key)
\
\BCC OUT                \ If A < 0, jump to OUT to load the current number and
\                       \ return from the subroutine, as the key pressed was
\                       \ RETURN (or some other character with a value less than
\                       \ ASCII "0")
\
\CMP #10                \ If A >= 10, jump to BAY2 to display the Inventory
\BCS BAY2               \ screen, as the key pressed was a letter or other
\                       \ non-digit and is greater than ASCII "9"
\
\STA S                  \ Store the numeric value of the key pressed in S
\
\LDA R                  \ Fetch the result so far into A
\
\CMP #26                \ If A >= 26, where A is the number entered so far, then
\BCS OUT                \ adding a further digit will make it bigger than 256,
\                       \ so jump to OUT to return from the subroutine with the
\                       \ result in R (i.e. ignore the last key press)
\
\ASL A                  \ Set A = (A * 2) + (A * 8) = A * 10
\STA T
\ASL A
\ASL A
\ADC T
\
\ADC S                  \ Add the pressed digit to A and store in R, so R now
\STA R                  \ contains its previous value with the new key press
\                       \ tacked onto the end
\
\CMP QQ25               \ If the result in R = the maximum allowed in QQ25, jump
\BEQ TT226              \ to TT226 to print the key press and keep looping (the
\                       \ BEQ is needed because the BCS below would jump to OUT
\                       \ if R >= QQ25, which we don't want)
\
\BCS OUT                \ If the result in R > QQ25, jump to OUT to return from
\                       \ the subroutine with the result in R
\
\.TT226
\
\LDA Q                  \ Print the character in Q (i.e. the key that was
\JSR TT26               \ pressed, as we stored the ASCII value in Q earlier)
\
\DEC T1                 \ Decrement the loop counter
\
\BNE TT223              \ Loop back to TT223 until we have checked for 12 digits

                        \ --- And replaced by: -------------------------------->

                        \ Instead of waiting for the player to choose a menu
                        \ item, we now choose a random menu item instead,
                        \ returning a value in R in the range 0 to QQ25, with 0
                        \ denoting that we are not choosing to buy anything

 JSR x4_DORND           \ Set A and X to random numbers

 CPX #160               \ Clear the C flag if X < 160

 AND #7                 \ Reduce A to a random number in the range 0 to 7

 BCC gnum1_7            \ If X < 160 (62.5% chance), skip the following
                        \ instruction

 LDA #0                 \ Set A = 0, so A is a random number in the range 0 to 7
                        \ with a reasonably large chance of it being zero

.gnum1_7

 AND QQ25               \ Reduce the random number in A into the range 0 to QQ25

 STA R                  \ Store the reduced result in R

 BEQ gnum2_7            \ If the result is zero then the choice is not to buy
                        \ anything, so skip printing the number

 CLC                    \ The item number is in A, so add ASCII "0" to get the
 ADC #'0'               \ ASCII character number to print

 JSR x4_TT26            \ Call TT26 to print the character in A so it looks like
                        \ we have typed it in

.gnum2_7

 LDY #50                \ Wait for 50/50 of a second (1 second)
 JSR x4_DELAY

 LDA R                  \ Set R to the chosen menu item to return to the

 CMP QQ25               \ Set the C flag if the chosen menu item is too large
                        \ (i.e. it is greater than or equal to QQ25), so we can
                        \ check this on returning

                        \ --- End of replacement ------------------------------>

.OUT_7

 LDA R                  \ Set A to the result we have been building in R

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TT208
\       Type: Subroutine
\   Category: Market
\    Summary: Show the Sell Cargo screen (red key f2)
\
\ ******************************************************************************

.TT208_7

 LDA #4                 \ Clear the top part of the screen, draw a border box,
 JSR x4_TT66            \ and set the current view type in QQ11 to 4 (Sell
                        \ Cargo screen)

 LDA #4                 \ Move the text cursor to row 4, column 4
 STA YC
 STA XC

\JSR FLKB               \ This instruction is commented out in the original
                        \ source. It calls a routine to flush the keyboard
                        \ buffer (FLKB) that isn't present in the cassette
                        \ version but is in other versions

 LDA #205               \ Print recursive token 45 ("SELL")
 JSR x4_TT27

 LDA #206               \ Print recursive token 46 (" CARGO{sentence case}")
 JSR x4_TT68            \ followed by a colon

                        \ Fall through into TT210 to show the Inventory screen
                        \ with the option to sell

\ ******************************************************************************
\
\       Name: TT210
\       Type: Subroutine
\   Category: Market
\    Summary: Show a list of current cargo in our hold, optionally to sell
\
\ ------------------------------------------------------------------------------
\
\ Show a list of current cargo in our hold, either with the ability to sell (the
\ Sell Cargo screen) or without (the Inventory screen), depending on the current
\ view.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   QQ11                The current view:
\
\                           * 4 = Sell Cargo
\
\                           * 8 = Inventory
\
\ ******************************************************************************

.TT210_7

 LDY #0                 \ We're going to loop through all the available market
                        \ items and check whether we have any in the hold (and,
                        \ if we are in the Sell Cargo screen, whether we want
                        \ to sell any items), so we set up a counter in Y to
                        \ denote the current item and start it at 0

.TT211_7

 STY QQ29               \ Store the current item number in QQ29

 LDX QQ20,Y             \ Fetch into X the amount of the current item that we
 BEQ TT212_7            \ have in our cargo hold, which is stored in QQ20+Y,
                        \ and if there are no items of this type in the hold,
                        \ jump down to TT212 to skip to the next item

 TYA                    \ Set Y = Y * 4, so this will act as an index into the
 ASL A                  \ market prices table at QQ23 for this item (as there
 ASL A                  \ are four bytes per item in the table)
 TAY

 LDA QQ23+1,Y           \ Fetch byte #1 from the market prices table for the
 STA QQ19+1             \ current item and store it in QQ19+1, for use by the
                        \ call to TT152 below

 TXA                    \ Store the amount of item in the hold (in X) on the
 PHA                    \ stack

 JSR TT69_7             \ Call TT69 to set Sentence Case and print a newline

 CLC                    \ Print recursive token 48 + QQ29, which will be in the
 LDA QQ29               \ range 48 ("FOOD") to 64 ("ALIEN ITEMS"), so this
 ADC #208               \ prints the current item's name
 JSR x4_TT27

 LDA #14                \ Move the text cursor to column 14, for the item's
 STA XC                 \ quantity

 PLA                    \ Restore the amount of item in the hold into X
 TAX

 CLC                    \ Print the 8-bit number in X to 3 digits, without a
 JSR x4_pr2             \ decimal point

 JSR TT152_7            \ Print the unit ("t", "kg" or "g") for the market item
                        \ whose byte #1 from the market prices table is in
                        \ QQ19+1 (which we set up above)

 LDA QQ11               \ If the current view type in QQ11 is not 4 (Sell Cargo
 CMP #4                 \ screen), jump to TT212 to skip the option to sell
 BNE TT212_7            \ items

 LDA #205               \ Set A to recursive token 45 ("SELL")

 JSR TT214_7            \ Call TT214 to print "Sell(Y/N)?" and return the
                        \ response in the C flag

 BCC TT212_7            \ If the response was "no", jump to TT212 to move on to
                        \ the next item

 LDA QQ29               \ We are selling this item, so fetch the item number
                        \ from QQ29

 LDX #255               \ Set QQ17 = 255 to disable printing
 STX QQ17

 JSR TT151_7            \ Call TT151 to set QQ24 to the item's price / 4 (the
                        \ routine doesn't print the item details, as we just
                        \ disabled printing)

 LDY QQ29               \ Set P to the amount of this item we have in our cargo
 LDA QQ20,Y             \ hold (which is the amount to sell)
 STA P

 LDA QQ24               \ Set Q to the item's price / 4
 STA Q

 JSR GCASH_7            \ Call GCASH to calculate
                        \
                        \   (Y X) = P * Q * 4
                        \
                        \ which will be the total price we make from this sale
                        \ (as P contains the quantity we're selling and Q
                        \ contains the item's price / 4)

 JSR x4_MCASH           \ Add (Y X) cash to the cash pot in CASH

 LDA #0                 \ We've made the sale, so set the amount
 LDY QQ29
 STA QQ20,Y

 STA QQ17               \ Set QQ17 = 0, which enables printing again

.TT212_7

 LDY QQ29               \ Fetch the item number from QQ29 into Y, and increment
 INY                    \ Y to point to the next item

 CPY #17                \ If Y >= 17 then skip the next instruction as we have
 BCS P%+5               \ done the last item

 JMP TT211_7            \ Otherwise loop back to TT211 to print the next item
                        \ in the hold

 LDA QQ11               \ If the current view type in QQ11 is not 4 (Sell Cargo
 CMP #4                 \ screen), skip the next two instructions and just
 BNE P%+8               \ return from the subroutine

 JSR dn2_7              \ This is the Sell Cargo screen, so call dn2 to make a
                        \ short, high beep and delay for 1 second

 JMP BAY2_7             \ And then jump to BAY2 to display the Inventory
                        \ screen, as we have finished selling cargo

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\RTS                    \ Return from the subroutine

                        \ --- And replaced by: -------------------------------->

 JMP DelayFiveSeconds_7 \ Wait for five seconds before returning from the
                        \ subroutine using a tail call (so when we show the
                        \ Inventory screen, we show it for five seconds)

                        \ --- End of replacement ------------------------------>

\ ******************************************************************************
\
\       Name: TT213
\       Type: Subroutine
\   Category: Market
\    Summary: Show the Inventory screen (red key f9)
\
\ ******************************************************************************

.TT213_7

 LDA #8                 \ Clear the top part of the screen, draw a border box,
 JSR x4_TT66            \ and set the current view type in QQ11 to 8 (Inventory
                        \ screen)

 LDA #11                \ Move the text cursor to column 11 to print the screen
 STA XC                 \ title

 LDA #164               \ Print recursive token 4 ("INVENTORY{crlf}") followed
 JSR TT60_7             \ by a paragraph break and Sentence Case

 JSR x4_NLIN4           \ Draw a horizontal line at pixel row 19 to box in the
                        \ title. The authors could have used a call to NLIN3
                        \ instead and saved the above call to TT60, but you
                        \ just can't optimise everything

 JSR fwl_7              \ Call fwl to print the fuel and cash levels on two
                        \ separate lines

 LDA CRGO               \ If our ship's cargo capacity is < 26 (i.e. we do not
 CMP #26                \ have a cargo bay extension), skip the following two
 BCC P%+7               \ instructions

 LDA #107               \ We do have a cargo bay extension, so print recursive
 JSR x4_TT27            \ token 107 ("LARGE CARGO{sentence case} BAY")

 JMP TT210_7            \ Jump to TT210 to print the contents of our cargo bay
                        \ and return from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: TT214
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Ask a question with a "Y/N?" prompt and return the response
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The text token to print before the "Y/N?" prompt
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              Set if the response was "yes", clear otherwise
\
\ ******************************************************************************

.TT214_7

 PHA                    \ Print a space, using the stack to preserve the value
 JSR x4_TT162           \ of A
 PLA

.TT221_7

 JSR x4_TT27            \ Print the text token in A

 LDA #225               \ Print recursive token 65 ("(Y/N)?")
 JSR x4_TT27

 JSR x4_TT217           \ Scan the keyboard until a key is pressed, and return
                        \ the key's ASCII code in A and X

 ORA #%00100000         \ Set bit 5 in the value of the key pressed, which
                        \ converts it to lower case

 CMP #'y'               \ If "y" was pressed, jump to TT218
 BEQ TT218_7

 LDA #'n'               \ Otherwise jump to TT26 to print "n" and return from
 JMP x4_TT26            \ the subroutine using a tail call (so all other
                        \ responses apart from "y" indicate a no)

.TT218_7

 JSR x4_TT26            \ Print the character in A, i.e. print "y"

 SEC                    \ Set the C flag to indicate a "yes" response

 RTS                    \ Return from the subroutine

\ ---- moved from elite-source.asm lines 28147-28391 (bank 4) ----
\ ******************************************************************************
\
\       Name: TT23
\       Type: Subroutine
\   Category: Charts
\    Summary: Show the Short-range Chart (red key f5)
\
\ ******************************************************************************

.TT23_7

 LDA #128               \ Clear the top part of the screen, draw a border box,
 JSR x4_TT66            \ and set the current view type in QQ11 to 128 (Short-
                        \ range Chart)

 LDA #7                 \ Move the text cursor to column 7
 STA XC

 LDA #190               \ Print recursive token 30 ("SHORT RANGE CHART") and
 JSR x4_NLIN3           \ draw a horizontal line at pixel row 19 to box in the
                        \ title

 JSR TT14_7             \ Call TT14 to draw a circle with crosshairs at the
                        \ current system's galactic coordinates

 JSR x4_TT103           \ Draw small crosshairs at coordinates (QQ9, QQ10),
                        \ i.e. at the selected system

 JSR x4_TT81            \ Set the seeds in QQ15 to those of system 0 in the
                        \ current galaxy (i.e. copy the seeds from QQ21 to QQ15)

 LDA #0                 \ Set A = 0, which we'll use below to zero out the INWK
                        \ workspace

 STA XX20               \ We're about to start working our way through each of
                        \ the galaxy's systems, so set up a counter in XX20 for
                        \ each system, starting at 0 and looping through to 255

 LDX #24                \ First, though, we need to zero out the 25 bytes at
                        \ INWK so we can use them to work out which systems have
                        \ room for a label, so set a counter in X for 25 bytes

.EE3_7

 STA INWK,X             \ Set the X-th byte of INWK to zero

 DEX                    \ Decrement the counter

 BPL EE3_7              \ Loop back to EE3 for the next byte until we've zeroed
                        \ all 25 bytes

                        \ We now loop through every single system in the galaxy
                        \ and check the distance from the current system whose
                        \ coordinates are in (QQ0, QQ1). We get the galactic
                        \ coordinates of each system from the system's seeds,
                        \ like this:
                        \
                        \   x = s1_hi (which is stored in QQ15+3)
                        \   y = s0_hi (which is stored in QQ15+1)
                        \
                        \ so the following loops through each system in the
                        \ galaxy in turn and calculates the distance between
                        \ (QQ0, QQ1) and (s1_hi, s0_hi) to find the closest one

.TT182_7

 LDA QQ15+3             \ Set A = s1_hi - QQ0, the horizontal distance between
 SEC                    \ (s1_hi, s0_hi) and (QQ0, QQ1)
 SBC QQ0

 BCS TT184_7            \ If a borrow didn't occur, i.e. s1_hi >= QQ0, then the
                        \ result is positive, so jump to TT184 and skip the
                        \ following two instructions

 EOR #&FF               \ Otherwise negate the result in A, so A is always
 ADC #1                 \ positive (i.e. A = |s1_hi - QQ0|)

.TT184_7

 CMP #20                \ If the horizontal distance in A is >= 20, then this
 BCS TT187_7            \ system is too far away from the current system to
                        \ appear in the Short-range Chart, so jump to TT187 to
                        \ move on to the next system

 LDA QQ15+1             \ Set A = s0_hi - QQ1, the vertical distance between
 SEC                    \ (s1_hi, s0_hi) and (QQ0, QQ1)
 SBC QQ1

 BCS TT186_7            \ If a borrow didn't occur, i.e. s0_hi >= QQ1, then the
                        \ result is positive, so jump to TT186 and skip the
                        \ following two instructions

 EOR #&FF               \ Otherwise negate the result in A, so A is always
 ADC #1                 \ positive (i.e. A = |s0_hi - QQ1|)

.TT186_7

 CMP #38                \ If the vertical distance in A is >= 38, then this
 BCS TT187_7            \ system is too far away from the current system to
                        \ appear in the Short-range Chart, so jump to TT187 to
                        \ move on to the next system

                        \ This system should be shown on the Short-range Chart,
                        \ so now we need to work out where the label should go,
                        \ and set up the various variables we need to draw the
                        \ system's filled circle on the chart

 LDA QQ15+3             \ Set A = s1_hi - QQ0, the horizontal distance between
 SEC                    \ this system and the current system, where |A| < 20.
 SBC QQ0                \ Let's call this the x-delta, as it's the horizontal
                        \ difference between the current system at the centre of
                        \ the chart, and this system (and this time we keep the
                        \ sign of A, so it can be negative if it's to the left
                        \ of the chart's centre, or positive if it's to the
                        \ right)

 ASL A                  \ Set XX12 = 104 + x-delta * 4
 ASL A                  \
 ADC #104               \ 104 is the x-coordinate of the centre of the chart,
 STA XX12               \ so this sets XX12 to the centre 104 +/- 76, the pixel
                        \ x-coordinate of this system

 LSR A                  \ Move the text cursor to column x-delta / 2 + 1
 LSR A                  \ which will be in the range 1-10
 LSR A
 STA XC
 INC XC

 LDA QQ15+1             \ Set A = s0_hi - QQ1, the vertical distance between
 SEC                    \ this system and the current system, where |A| < 38.
 SBC QQ1                \ Let's call this the y-delta, as it's the vertical
                        \ difference between the current system at the centre of
                        \ the chart, and this system (and this time we keep the
                        \ sign of A, so it can be negative if it's above the
                        \ chart's centre, or positive if it's below)

 ASL A                  \ Set K4 = 90 + y-delta * 2
 ADC #90                \
 STA K4                 \ 90 is the y-coordinate of the centre of the chart,
                        \ so this sets K4 to the centre 90 +/- 74, the pixel
                        \ y-coordinate of this system

 LSR A                  \ Set Y = A >> 3
 LSR A                  \       = K4 div 8
 LSR A                  \
 TAY                    \ So Y now contains the number of the character row
                        \ that contains this system

                        \ Now to see if there is room for this system's label.
                        \ Ideally we would print the system name on the same
                        \ text row as the system, but we only want to print one
                        \ label per row, to prevent overlap, so now we check
                        \ this system's row, and if that's already occupied,
                        \ the row above, and if that's already occupied, the
                        \ row below... and if that's already occupied, we give
                        \ up and don't print a label for this system

 LDX INWK,Y             \ If the value in INWK+Y is 0 (i.e. the text row
 BEQ EE4_7              \ containing this system does not already have another
                        \ system's label on it), jump to EE4 to store this
                        \ system's label on this row

 INY                    \ If the value in INWK+Y+1 is 0 (i.e. the text row below
 LDX INWK,Y             \ the one containing this system does not already have
 BEQ EE4_7              \ another system's label on it), jump to EE4 to store
                        \ this system's label on this row

 DEY                    \ If the value in INWK+Y-1 is 0 (i.e. the text row above
 DEY                    \ the one containing this system does not already have
 LDX INWK,Y             \ another system's label on it), fall through into to
 BNE ee1_7              \ EE4 to store this system's label on this row,
                        \ otherwise jump to ee1 to skip printing a label for
                        \ this system (as there simply isn't room)

.EE4_7

 STY YC                 \ Now to print the label, so move the text cursor to row
                        \ Y (which contains the row where we can print this
                        \ system's label)

 CPY #3                 \ If Y < 3, then the system would clash with the chart
 BCC TT187_7            \ title, so jump to TT187 to skip showing the system

 DEX                    \ We entered the EE4 routine with X = 0, so this stores
 STX INWK,Y             \ &FF in INWK+Y, to denote that this row is now occupied
                        \ so we don't try to print another system's label on
                        \ this row

 LDA #%10000000         \ Set bit 7 of QQ17 to switch to Sentence Case
 STA QQ17

 JSR x4_cpl             \ Call cpl to print out the system name for the seeds
                        \ in QQ15 (which now contains the seeds for the current
                        \ system)

.ee1_7

 LDA #0                 \ Now to plot the star, so set the high bytes of K, K3
 STA K3+1               \ and K4 to 0
 STA K4+1
 STA K+1

 LDA XX12               \ Set the low byte of K3 to XX12, the pixel x-coordinate
 STA K3                 \ of this system

 LDA QQ15+5             \ Fetch s2_hi for this system from QQ15+5, extract bit 0
 AND #1                 \ and add 2 to get the size of the star, which we store
 ADC #2                 \ in K. This will be either 2, 3 or 4, depending on the
 STA K                  \ value of bit 0, and whether the C flag is set (which
                        \ will vary depending on what happens in the above call
                        \ to cpl). Incidentally, the planet's average radius
                        \ also uses s2_hi, bits 0-3 to be precise, but that
                        \ doesn't mean the two sizes affect each other

                        \ We now have the following:
                        \
                        \   K(1 0)  = radius of star (2, 3 or 4)
                        \
                        \   K3(1 0) = pixel x-coordinate of system
                        \
                        \   K4(1 0) = pixel y-coordinate of system
                        \
                        \ which we can now pass to the SUN routine to draw a
                        \ small "sun" on the Short-range Chart for this system

 JSR x4_FLFLLS          \ Call FLFLLS to reset the LSO block

 JSR x4_SUN             \ Call SUN to plot a sun with radius K at pixel
                        \ coordinate (K3, K4)

 JSR x4_FLFLLS          \ Call FLFLLS to reset the LSO block

.TT187_7

 JSR x4_TT20            \ We want to move on to the next system, so call TT20
                        \ to twist the three 16-bit seeds in QQ15

 INC XX20               \ Increment the counter

 BEQ b13_TT111m1        \ If X = 0 then we have done all 256 systems, so return
                        \ from the subroutine (as TT111-1 contains an RTS)

 JMP TT182_7            \ Otherwise jump back up to TT182 to process the next
                        \ system


\ (branches out of the code above)
.b13_TT111m1 JSR far4 : EQUW TT111-1

\ ---- moved from elite-source.asm lines 29188-29362 (bank 4) ----
\ ******************************************************************************
\
\       Name: TT151
\       Type: Subroutine
\   Category: Market
\    Summary: Print the name, price and availability of a market item
\  Deep dive: Market item prices and availability
\             Galaxy and system seeds
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The number of the market item to print, 0-16 (see QQ23
\                       for details of item numbers)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   QQ19+1              Byte #1 from the market prices table for this item
\
\   QQ24                The item's price / 4
\
\   QQ25                The item's availability
\
\ ******************************************************************************

.TT151_7

 PHA                    \ Store the item number on the stack and in QQ19+4
 STA QQ19+4

 ASL A                  \ Store the item number * 4 in QQ19, so this will act as
 ASL A                  \ an index into the market prices table at QQ23 for this
 STA QQ19               \ item (as there are four bytes per item in the table)

 LDA #1                 \ Move the text cursor to column 1, for the item's name
 STA XC

 PLA                    \ Restore the item number

 ADC #208               \ Print recursive token 48 + A, which will be in the
 JSR x4_TT27            \ range 48 ("FOOD") to 64 ("ALIEN ITEMS"), so this
                        \ prints the item's name

 LDA #14                \ Move the text cursor to column 14, for the price
 STA XC

 LDX QQ19               \ Fetch byte #1 from the market prices table (units and
 LDA QQ23+1,X           \ economic_factor) for this item and store in QQ19+1
 STA QQ19+1

 LDA QQ26               \ Fetch the random number for this system visit and
 AND QQ23+3,X           \ AND with byte #3 from the market prices table (mask)
                        \ to give:
                        \
                        \   A = random AND mask

 CLC                    \ Add byte #0 from the market prices table (base_price),
 ADC QQ23,X             \ so we now have:
 STA QQ24               \
                        \   A = base_price + (random AND mask)

 JSR TT152_7            \ Call TT152 to print the item's unit ("t", "kg" or
                        \ "g"), padded to a width of two characters

 JSR x4_var             \ Call var to set QQ19+3 = economy * |economic_factor|
                        \ (and set the availability of alien items to 0)

 LDA QQ19+1             \ Fetch the byte #1 that we stored above and jump to
 BMI TT155_7            \ TT155 if it is negative (i.e. if the economic_factor
                        \ is negative)

 LDA QQ24               \ Set A = QQ24 + QQ19+3
 ADC QQ19+3             \
                        \       = base_price + (random AND mask)
                        \         + (economy * |economic_factor|)
                        \
                        \ which is the result we want, as the economic_factor
                        \ is positive

 JMP TT156_7            \ Jump to TT156 to multiply the result by 4

.TT155_7

 LDA QQ24               \ Set A = QQ24 - QQ19+3
 SEC                    \
 SBC QQ19+3             \       = base_price + (random AND mask)
                        \         - (economy * |economic_factor|)
                        \
                        \ which is the result we want, as economic_factor
                        \ is negative

.TT156_7

 STA QQ24               \ Store the result in QQ24 and P
 STA P

 LDA #0                 \ Set A = 0 and call GC2 to calculate (Y X) = (A P) * 4,
 JSR GC2_7              \ which is the same as (Y X) = P * 4 because A = 0

 SEC                    \ We now have our final price, * 10, so we can call pr5
 JSR x4_pr5             \ to print (Y X) to 5 digits, including a decimal
                        \ point, as the C flag is set

 LDY QQ19+4             \ We now move on to availability, so fetch the market
                        \ item number that we stored in QQ19+4 at the start

 LDA #5                 \ Set A to 5 so we can print the availability to 5
                        \ digits (right-padded with spaces)

 LDX AVL,Y              \ Set X to the item's availability, which is given in
                        \ the AVL table

 STX QQ25               \ Store the availability in QQ25

 CLC                    \ Clear the C flag

 BEQ TT172_7            \ If none are available, jump to TT172 to print a tab
                        \ and a "-"

 JSR x4_pr2p2           \ Otherwise print the 8-bit number in X to 5 digits,
                        \ right-aligned with spaces. This works because we set
                        \ A to 5 above, and we jump into the pr2 routine just
                        \ after the first instruction, which would normally
                        \ set the number of digits to 3

 JMP TT152_7            \ Print the unit ("t", "kg" or "g") for the market item,
                        \ with a following space if required to make it two
                        \ characters long, and return from the subroutine using
                        \ a tail call

.TT172_7

 LDA XC                 \ Move the text cursor in XC to the right by 4 columns,
 ADC #4                 \ so the cursor is where the last digit would be if we
 STA XC                 \ were printing a five-digit availability number

 LDA #'-'               \ Print a "-" character by jumping to TT162+2, which
 BNE b14_TT162p2        \ contains JMP TT27 (this BNE is effectively a JMP as A
                        \ will never be zero), and return from the subroutine
                        \ using a tail call

\ ******************************************************************************
\
\       Name: TT152
\       Type: Subroutine
\   Category: Market
\    Summary: Print the unit ("t", "kg" or "g") for a market item
\
\ ------------------------------------------------------------------------------
\
\ Print the unit ("t", "kg" or "g") for the market item whose byte #1 from the
\ market prices table is in QQ19+1, right-padded with spaces to a width of two
\ characters (so that's "t ", "kg" or "g ").
\
\ ******************************************************************************

.TT152_7

 LDA QQ19+1             \ Fetch the economic_factor from QQ19+1

 AND #96                \ If bits 5 and 6 are both clear, jump to TT160 to
 BEQ TT160_7            \ print "t" for tonne, followed by a space, and return
                        \ from the subroutine using a tail call

 CMP #32                \ If bit 5 is set, jump to TT161 to print "kg" for
 BEQ TT161_7            \ kilograms, and return from the subroutine using a tail
                        \ call

 JSR TT16a_7            \ Otherwise call TT16a to print "g" for grams, and fall
                        \ through into TT162 to print a space and return from
                        \ the subroutine

 JMP x4_TT162             \ (TT162 stays in bank 4: it was the fall-through)


\ (branches out of the code above)
.b14_TT162p2 JSR far4 : EQUW TT162+2

\ ---- moved from elite-source.asm lines 29385-29525 (bank 4) ----
\ ******************************************************************************
\
\       Name: TT160
\       Type: Subroutine
\   Category: Market
\    Summary: Print "t" (for tonne) and a space
\
\ ******************************************************************************

.TT160_7

 LDA #'t'               \ Load a "t" character into A

 JSR x4_TT26            \ Print the character, using TT216 so that it doesn't
                        \ change the character case

 BCC b15_TT162          \ Jump to TT162 to print a space and return from the
                        \ subroutine using a tail call (this BCC is effectively
                        \ a JMP as the C flag is cleared by TT26)

\ ******************************************************************************
\
\       Name: TT161
\       Type: Subroutine
\   Category: Market
\    Summary: Print "kg" (for kilograms)
\
\ ******************************************************************************

.TT161_7

 LDA #'k'               \ Load a "k" character into A

 JSR x4_TT26            \ Print the character, using TT216 so that it doesn't
                        \ change the character case, and fall through into
                        \ TT16a to print a "g" character

\ ******************************************************************************
\
\       Name: TT16a
\       Type: Subroutine
\   Category: Market
\    Summary: Print "g" (for grams)
\
\ ******************************************************************************

.TT16a_7

 LDA #'g'               \ Load a "g" character into A

 JMP x4_TT26            \ Print the character, using TT216 so that it doesn't
                        \ change the character case, and return from the
                        \ subroutine using a tail call

\ ******************************************************************************
\
\       Name: TT163
\       Type: Subroutine
\   Category: Market
\    Summary: Print the headers for the table of market prices
\
\ ------------------------------------------------------------------------------
\
\ Print the column headers for the prices table in the Buy Cargo and Market
\ Price screens.
\
\ ******************************************************************************

.TT163_7

 LDA #17                \ Move the text cursor in XC to column 17
 STA XC

 LDA #255               \ Print recursive token 95 token ("UNIT  QUANTITY
 BNE b15_TT162p2        \ {crlf} PRODUCT   UNIT PRICE FOR SALE{crlf}{lf}") by
                        \ jumping to TT162+2, which contains JMP TT27 (this BNE
                        \ is effectively a JMP as A will never be zero), and
                        \ return from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: TT167
\       Type: Subroutine
\   Category: Market
\    Summary: Show the Market Price screen (red key f7)
\
\ ******************************************************************************

.TT167_7

 LDA #16                \ Clear the top part of the screen, draw a border box,
 JSR x4_TT66            \ and set the current view type in QQ11 to 16 (Market
                        \ Price screen)

 LDA #5                 \ Move the text cursor to column 5
 STA XC

 LDA #167               \ Print recursive token 7 ("{current system name} MARKET
 JSR x4_NLIN3           \ PRICES") and draw a horizontal line at pixel row 19
                        \ to box in the title

 LDA #3                 \ Move the text cursor to row 3
 STA YC

 JSR TT163_7            \ Print the column headers for the prices table

 LDA #0                 \ We're going to loop through all the available market
 STA QQ29               \ items, so we set up a counter in QQ29 to denote the
                        \ current item and start it at 0

.TT168_7

 LDX #%10000000         \ Set bit 7 of QQ17 to switch to Sentence Case, with the
 STX QQ17               \ next letter in capitals

 JSR TT151_7            \ Call TT151 to print the item name, market price and
                        \ availability of the current item, and set QQ24 to the
                        \ item's price / 4, QQ25 to the quantity available and
                        \ QQ19+1 to byte #1 from the market prices table for
                        \ this item

 INC YC                 \ Move the text cursor down one row

 INC QQ29               \ Increment QQ29 to point to the next item

 LDA QQ29               \ If QQ29 >= 17 then jump to TT168 as we have done the
 CMP #17                \ last item
 BCC TT168_7

                        \ --- Mod: Code removed for Demonstration Disc: ------->

\RTS                    \ Return from the subroutine

                        \ --- And replaced by: -------------------------------->

 JMP DelayFiveSeconds_7 \ Wait for five seconds before returning from the
                        \ subroutine using a tail call (so when we show the
                        \ Market Price screen, we show it for five seconds)

                        \ --- End of replacement ------------------------------>


\ (branches out of the code above)
.b15_TT162 JSR far4 : EQUW TT162
.b15_TT162p2 JSR far4 : EQUW TT162+2

\ ---- moved from elite-source.asm lines 30108-30164 (bank 4) ----
\ ******************************************************************************
\
\       Name: LCASH
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Subtract an amount of cash from the cash pot
\
\ ------------------------------------------------------------------------------
\
\ Subtract (Y X) cash from the cash pot in CASH, but only if there is enough
\ cash in the pot. As CASH is a four-byte number, this calculates:
\
\   CASH(0 1 2 3) = CASH(0 1 2 3) - (0 0 Y X)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              If set, there was enough cash to do the subtraction
\
\                       If clear, there was not enough cash to do the
\                       subtraction
\
\ ******************************************************************************

.LCASH_7

 STX T1                 \ Subtract the least significant bytes:
 LDA CASH+3             \
 SEC                    \   CASH+3 = CASH+3 - X
 SBC T1
 STA CASH+3

 STY T1                 \ Then the second most significant bytes:
 LDA CASH+2             \
 SBC T1                 \   CASH+2 = CASH+2 - Y
 STA CASH+2

 LDA CASH+1             \ Then the third most significant bytes (which are 0):
 SBC #0                 \
 STA CASH+1             \   CASH+1 = CASH+1 - 0

 LDA CASH               \ And finally the most significant bytes (which are 0):
 SBC #0                 \
 STA CASH               \   CASH = CASH - 0

 BCS b16_TT113          \ If the C flag is set then the subtraction didn't
                        \ underflow, so the value in CASH is correct and we can
                        \ jump to TT113 to return from the subroutine with the
                        \ C flag set to indicate success (as TT113 contains an
                        \ RTS)

                        \ Otherwise we didn't have enough cash in CASH to
                        \ subtract (Y X) from it, so fall through into
                        \ MCASH to reverse the sum and restore the original
                        \ value in CASH, and returning with the C flag clear

 JMP x4_MCASH             \ (MCASH stays in bank 4: it was the fall-through)


\ (branches out of the code above)
.b16_TT113 JSR far4 : EQUW TT113

\ ---- moved from elite-source.asm lines 30214-30303 (bank 4) ----
\ ******************************************************************************
\
\       Name: GCASH
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (Y X) = P * Q * 4
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following multiplication of unsigned 8-bit numbers:
\
\   (Y X) = P * Q * 4
\
\ ******************************************************************************

.GCASH_7

 JSR x4_MULTU           \ Call MULTU to calculate (A P) = P * Q

\ ******************************************************************************
\
\       Name: GC2
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (Y X) = (A P) * 4
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following multiplication of unsigned 16-bit numbers:
\
\   (Y X) = (A P) * 4
\
\ ******************************************************************************

.GC2_7

 ASL P                  \ Set (A P) = (A P) * 4
 ROL A
 ASL P
 ROL A

 TAY                    \ Set (Y X) = (A P)
 LDX P

 RTS                    \ Return from the subroutine



\ --- Original ELITE E file --------------------------------------------------


\ ******************************************************************************
\
\       Name: Authors' names
\       Type: Variable
\   Category: Copy protection
\    Summary: The authors' names and a copyright notice, buried in the code
\
\ ------------------------------------------------------------------------------
\
\ This copyright notice is not used anywhere and it is obfuscated by EOR'ing
\ each character with 164, but presumably the authors wanted their names buried
\ in the code somewhere. Though they do also have recursive token 94, which
\ reads "BY D.BRABEN & I.BELL" and can be displayed on the title screen using
\ the "X" configuration option, so this isn't the only author name easter egg
\ in the game. It contains the following text:
\
\   (C)Bell/Braben1984
\
\ ******************************************************************************

 EQUB '(' EOR 164
 EQUB 'C' EOR 164
 EQUB ')' EOR 164
 EQUB 'B' EOR 164
 EQUB 'e' EOR 164
 EQUB 'l' EOR 164
 EQUB 'l' EOR 164
 EQUB '/' EOR 164
 EQUB 'B' EOR 164
 EQUB 'r' EOR 164
 EQUB 'a' EOR 164
 EQUB 'b' EOR 164
 EQUB 'e' EOR 164
 EQUB 'n' EOR 164
 EQUB '1' EOR 164
 EQUB '9' EOR 164
 EQUB '8' EOR 164
 EQUB '4' EOR 164

\ ---- moved from elite-source.asm lines 30387-30549 (bank 4) ----
\ ******************************************************************************
\
\       Name: cmn
\       Type: Subroutine
\   Category: Status
\    Summary: Print the commander's name
\
\ ------------------------------------------------------------------------------
\
\ Print control code 4 (the commander's name).
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   cmn-1               Contains an RTS
\
\ ******************************************************************************

.cmn_7

 LDY #0                 \ Set up a counter in Y, starting from 0

.QUL4_7

 LDA NA_7%,Y            \ The commander's name is stored at NA%, so load the
                        \ Y-th character from NA%

 CMP #13                \ If we have reached the end of the name, return from
 BEQ ypl_7-1            \ the subroutine (ypl-1 points to the RTS below)

 JSR x4_TT26            \ Print the character we just loaded

 INY                    \ Increment the loop counter

 BNE QUL4_7             \ Loop back for the next character

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: ypl
\       Type: Subroutine
\   Category: Universe
\    Summary: Print the current system name
\
\ ------------------------------------------------------------------------------
\
\ Print control code 2 (the current system name).
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   ypl-1               Contains an RTS
\
\ ******************************************************************************

.ypl_7

 LDA MJ                 \ Check the mis-jump flag at MJ, and if it is non-zero
 BNE yplR_7             \ then we are in witchspace, and witchspace doesn't have
                        \ a system name, so return from the subroutine (cmn-1
                        \ contains an RTS)

 JSR TT62_7             \ Call TT62 below to swap the three 16-bit seeds in
                        \ QQ2 and QQ15 (before the swap, QQ2 contains the seeds
                        \ for the current system, while QQ15 contains the seeds
                        \ for the selected system)

 JSR x4_cpl             \ Call cpl to print out the system name for the seeds
                        \ in QQ15 (which now contains the seeds for the current
                        \ system)

                        \ Now we fall through into the TT62 subroutine, which
                        \ will swap QQ2 and QQ15 once again, so everything goes
                        \ back into the right place, and the RTS at the end of
                        \ TT62 will return from the subroutine

.TT62_7

 LDX #5                 \ Set up a counter in X for the three 16-bit seeds we
                        \ want to swap (i.e. 6 bytes)

.TT78_7

 LDA QQ15,X             \ Swap byte X between QQ2 and QQ15
 LDY QQ2,X
 STA QQ2,X
 STY QQ15,X

 DEX                    \ Decrement the loop counter

 BPL TT78_7             \ Loop back for the next byte to swap

.yplR_7 RTS             \ Once all bytes are swapped, return from the
                        \ subroutine

\ ******************************************************************************
\
\       Name: tal
\       Type: Subroutine
\   Category: Universe
\    Summary: Print the current galaxy number
\
\ ------------------------------------------------------------------------------
\
\ Print control code 1 (the current galaxy number, right-aligned to width 3).
\
\ ******************************************************************************

.tal_7

 CLC                    \ We don't want to print the galaxy number with a
                        \ decimal point, so clear the C flag for pr2 to take as
                        \ an argument

 LDX GCNT               \ Load the current galaxy number from GCNT into X

 INX                    \ Add 1 to the galaxy number, as the galaxy numbers
                        \ are 0-7 internally, but we want to display them as
                        \ galaxy 1 through 8

 JMP x4_pr2             \ Jump to pr2, which prints the number in X to a width
                        \ of 3 figures, left-padding with spaces to a width of
                        \ 3, and return from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: fwl
\       Type: Subroutine
\   Category: Status
\    Summary: Print fuel and cash levels
\
\ ------------------------------------------------------------------------------
\
\ Print control code 5 ("FUEL: ", fuel level, " LIGHT YEARS", newline, "CASH:",
\ control code 0).
\
\ ******************************************************************************

.fwl_7

 LDA #105               \ Print recursive token 105 ("FUEL") followed by a
 JSR x4_TT68            \ colon

 LDX QQ14               \ Load the current fuel level from QQ14

 SEC                    \ We want to print the fuel level with a decimal point,
                        \ so set the C flag for pr2 to take as an argument

 JSR x4_pr2             \ Call pr2, which prints the number in X to a width of
                        \ 3 figures (i.e. in the format x.x, which will always
                        \ be exactly 3 characters as the maximum fuel is 7.0)

 LDA #195               \ Print recursive token 35 ("LIGHT YEARS") followed by
 JSR x4_plf             \ a newline

.PCASH_7

 LDA #119               \ Print recursive token 119 ("CASH:" then control code
 BNE b18_TT27           \ 0, which prints cash levels, then " CR" and newline)


\ (branches out of the code above)
.b18_TT27 JSR far4 : EQUW TT27


\ ---- calls out of bank 7 (page bank 4 in around the call) ----

.j4_FRCE JSR far4j : EQUW FRCE
.x4_BEEP JSR far4 : EQUW BEEP
.x4_BOX JSR far4 : EQUW BOX
.x4_CIRCLE2 JSR far4 : EQUW CIRCLE2
.x4_CLYNS JSR far4 : EQUW CLYNS
.x4_DELAY JSR far4 : EQUW DELAY
.x4_DET1 JSR far4 : EQUW DET1
.x4_DIALS JSR far4 : EQUW DIALS
.x4_DORND JSR far4 : EQUW DORND
.x4_EXNO3 JSR far4 : EQUW EXNO3
.x4_FLFLLS JSR far4 : EQUW FLFLLS
.x4_H_LL9F JSR far4 : EQUW H_LL9F
.x4_MCASH JSR far4 : EQUW MCASH
.x4_MULTU JSR far4 : EQUW MULTU
.x4_MVEIT JSR far4 : EQUW MVEIT
.x4_NLIN JSR far4 : EQUW NLIN
.x4_NLIN2 JSR far4 : EQUW NLIN2
.x4_NLIN3 JSR far4 : EQUW NLIN3
.x4_NLIN4 JSR far4 : EQUW NLIN4
.x4_NWSHP JSR far4 : EQUW NWSHP
.x4_PIXEL JSR far4 : EQUW PIXEL
.x4_RES2 JSR far4 : EQUW RES2
.x4_SUN JSR far4 : EQUW SUN
.x4_TT102 JSR far4 : EQUW TT102
.x4_TT103 JSR far4 : EQUW TT103
.x4_TT11 JSR far4 : EQUW TT11
.x4_TT111 JSR far4 : EQUW TT111
.x4_TT15 JSR far4 : EQUW TT15
.x4_TT162 JSR far4 : EQUW TT162
.x4_TT20 JSR far4 : EQUW TT20
.x4_TT217 JSR far4 : EQUW TT217
.x4_TT26 JSR far4 : EQUW TT26
.x4_TT27 JSR far4 : EQUW TT27
.x4_TT66 JSR far4 : EQUW TT66
.x4_TT66m2 JSR far4 : EQUW TT66-2
.x4_TT67 JSR far4 : EQUW TT67
.x4_TT68 JSR far4 : EQUW TT68
.x4_TT81 JSR far4 : EQUW TT81
.x4_Upc JSR far4 : EQUW U%
.x4_ZERO JSR far4 : EQUW ZERO
.x4_Ze JSR far4 : EQUW Ze
.x4_cpl JSR far4 : EQUW cpl
.x4_ex JSR far4 : EQUW ex
.x4_fq1 JSR far4 : EQUW fq1
.x4_hm JSR far4 : EQUW hm
.x4_hyp1 JSR far4 : EQUW hyp1
.x4_msblob JSR far4 : EQUW msblob
.x4_nWq JSR far4 : EQUW nWq
.x4_ping JSR far4 : EQUW ping
.x4_plf JSR far4 : EQUW plf
.x4_pr2 JSR far4 : EQUW pr2
.x4_pr2p2 JSR far4 : EQUW pr2+2
.x4_pr5 JSR far4 : EQUW pr5
.x4_pr6 JSR far4 : EQUW pr6
.x4_prq JSR far4 : EQUW prq
.x4_var JSR far4 : EQUW var
.j4_D2 JSR far4j : EQUW D2
