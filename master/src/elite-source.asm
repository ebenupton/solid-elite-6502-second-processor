\ ******************************************************************************
\
\ BBC MASTER ELITE MAIN GAME SOURCE
\
\ BBC Master Elite was written by Ian Bell and David Braben and is copyright
\ Acornsoft 1986
\
\ The code in this file has been reconstructed from a disassembly of the version
\ released on Ian Bell's personal website at http://www.elitehomepage.org/
\
\ The commentary is copyright Mark Moxon, and any misunderstandings or mistakes
\ in the documentation are entirely my fault
\
\ The terminology and notations used in this commentary are explained at
\ https://elite.bbcelite.com/terminology
\
\ The deep dive articles referred to in this commentary can be found at
\ https://elite.bbcelite.com/deep_dives
\
\ ------------------------------------------------------------------------------
\
\ This source file contains the main game code for BBC Master Elite.
\
\ ------------------------------------------------------------------------------
\
\ This source file produces the following binary file:
\
\   * BCODE.bin
\
\ ******************************************************************************

 INCLUDE "build/elite-build-options.asm"

 CPU 1                  \ Switch to 65SC12 assembly, as this code runs on a
                        \ BBC Master

 _SNG47                 = (_VARIANT = 1)
 _COMPACT               = (_VARIANT = 2)

 GUARD &C000            \ Guard against assembling over MOS memory

\ ******************************************************************************
\
\ Configuration variables
\
\ ******************************************************************************

 CODE% = &1300          \ The address where the code will be run

 LOAD% = &1300          \ The address where the code will be loaded

 Q% = _MAX_COMMANDER    \ Set Q% to TRUE to max out the default commander, FALSE
                        \ for the standard default commander

 NOST = 20              \ The number of stardust particles in normal space (this
                        \ goes down to 3 in witchspace)

 NOSH = 12              \ The maximum number of ships in our local bubble of
                        \ universe

 NTY = 33               \ The number of different ship types

 MSL = 1                \ Ship type for a missile

 SST = 2                \ Ship type for a Coriolis space station

 ESC = 3                \ Ship type for an escape pod

 PLT = 4                \ Ship type for an alloy plate

 OIL = 5                \ Ship type for a cargo canister

 AST = 7                \ Ship type for an asteroid

 SPL = 8                \ Ship type for a splinter

 SHU = 9                \ Ship type for a Shuttle

 CYL = 11               \ Ship type for a Cobra Mk III

 ANA = 14               \ Ship type for an Anaconda

 HER = 15               \ Ship type for a rock hermit (asteroid)

 COPS = 16              \ Ship type for a Viper

 SH3 = 17               \ Ship type for a Sidewinder

 KRA = 19               \ Ship type for a Krait

 ADA = 20               \ Ship type for an Adder

 WRM = 23               \ Ship type for a Worm

 CYL2 = 24              \ Ship type for a Cobra Mk III (pirate)

 ASP = 25               \ Ship type for an Asp Mk II

 THG = 29               \ Ship type for a Thargoid

 TGL = 30               \ Ship type for a Thargon

 CON = 31               \ Ship type for a Constrictor

 COU = 32               \ Ship type for a Cougar

 DOD = 33               \ Ship type for a Dodecahedron ("Dodo") space station

 JL = ESC               \ Junk is defined as starting from the escape pod

 JH = SHU+2             \ Junk is defined as ending before the Cobra Mk III
                        \
                        \ So junk is defined as the following: escape pod,
                        \ alloy plate, cargo canister, asteroid, splinter,
                        \ Shuttle or Transporter

 PACK = SH3             \ The first of the eight pack-hunter ships, which tend
                        \ to spawn in groups. With the default value of PACK the
                        \ pack-hunters are the Sidewinder, Mamba, Krait, Adder,
                        \ Gecko, Cobra Mk I, Worm and Cobra Mk III (pirate)

 POW = 15               \ Pulse laser power

 Mlas = 50              \ Mining laser power

 Armlas = INT(128.5 + 1.5*POW)  \ Military laser power

 NI% = 37               \ The number of bytes in each ship's data block (as
                        \ stored in INWK and K%)

 X = 128                \ The centre x-coordinate of the 256 x 192 space view

 Y = 96                 \ The centre y-coordinate of the 256 x 192 space view

 GCYT = 24              \ The y-coordinate of the top of the Long-range Chart

 GCYB = GCYT + 128      \ The y-coordinate of the bottom of the Long-range chart

 f0 = &80               \ Internal key number for red key f0 (Launch, Front)

 f1 = &81               \ Internal key number for red key f1 (Buy Cargo, Rear)

 f2 = &82               \ Internal key number for red key f2 (Sell Cargo, Left)

 f3 = &83               \ Internal key number for red key f3 (Equip Ship, Right)

 f4 = &84               \ Internal key number for red key f4 (Long-range Chart)

 f5 = &85               \ Internal key number for red key f5 (Short-range Chart)

 f6 = &86               \ Internal key number for red key f6 (Data on System)

 f7 = &87               \ Internal key number for red key f7 (Market Price)

 f8 = &88               \ Internal key number for red key f8 (Status Mode)

 f9 = &89               \ Internal key number for red key f9 (Inventory)

 YELLOW  = %00001111    \ Four mode 1 pixels of colour 1 (yellow)

 RED     = %11110000    \ Four mode 1 pixels of colour 2 (red, magenta or white)

 CYAN    = %11111111    \ Four mode 1 pixels of colour 3 (cyan or white)

 GREEN   = %10101111    \ Four mode 1 pixels of colour 3, 1, 3, 1 (cyan/yellow)

 WHITE   = %11111010    \ Four mode 1 pixels of colour 3, 2, 3, 2 (cyan/red)

 MAGENTA = RED          \ Four mode 1 pixels of colour 2 (red, magenta or white)

 DUST    = WHITE        \ Four mode 1 pixels of colour 3, 2, 3, 2 (cyan/red)

 RED2    = %00000011    \ Two mode 2 pixels of colour 1    (red)

 GREEN2  = %00001100    \ Two mode 2 pixels of colour 2    (green)

 YELLOW2 = %00001111    \ Two mode 2 pixels of colour 3    (yellow)

 BLUE2   = %00110000    \ Two mode 2 pixels of colour 4    (blue)

 MAG2    = %00110011    \ Two mode 2 pixels of colour 5    (magenta)

 CYAN2   = %00111100    \ Two mode 2 pixels of colour 6    (cyan)

 WHITE2  = %00111111    \ Two mode 2 pixels of colour 7    (white)

 STRIPE  = %00100011    \ Two mode 2 pixels of colour 5, 1 (magenta/red)

 soboop  = 0            \ Sound 0  = Long, low beep

 sobeep  = 1            \ Sound 1  = Short, high beep

 soclick = 2            \ Sound 2  = This sound is not used

 solaser = 3            \ Sound 3  = Lasers fired by us 1

 soexpl  = 4            \ Sound 4  = We died / Collision / Being hit by lasers 2

 solas2  = 5            \ Sound 5  = Lasers fired by us 2

 sohit   = 6            \ Sound 6  = We made a hit/kill / Other ship exploding

 sobomb  = 6            \ Sound 6  = Energy bomb

 soecm   = 7            \ Sound 7  = E.C.M. on

 solaun  = 8            \ Sound 8  = Missile launched / Ship launch

                        \ Sound 9  = Being hit by lasers 1 (no variable defined
                        \            in original source code)

 sohyp   = 10           \ Sound 10 = Hyperspace drive engaged 1

 sohyp2  = 11           \ Sound 11 = Hyperspace drive engaged 2

 NRU% = 0               \ The number of planetary systems with extended system
                        \ description overrides in the RUTOK table
                        \
                        \ NRU% is set to 0 in the original source, but this is a
                        \ bug, as it should match the number of entries in the
                        \ RUGAL table
                        \
                        \ This bug causes the Data on System screen to crash the
                        \ game for a small number of systems - for example, the
                        \ game will freeze if you bring up the Data on System
                        \ screen after docking at Biarge in the first galaxy
                        \ during the Constrictor mission

 RE = &23               \ The obfuscation byte used to hide the recursive tokens
                        \ table from crackers viewing the binary code

 VE = &57               \ The obfuscation byte used to hide the extended tokens
                        \ table from crackers viewing the binary code

 KEY1 = &19             \ The seed for encrypting the game code from DOENTRY to
                        \ F%

 KEY2 = &62             \ The seed for encrypting the game data from XX21 to
                        \ &BBFF

 LL = 30                \ The length of lines (in characters) of justified text
                        \ in the extended tokens system

 BRKV = &0202           \ The break vector that we intercept to enable us to
                        \ handle and display system errors

 IRQ1V = &0204          \ The IRQ1V vector that we intercept to implement the
                        \ split-screen mode

 WRCHV = &020E          \ The WRCHV vector that we intercept with our custom
                        \ text printing routine

 LS% = &0800            \ The start of the descending ship line heap

 TAP% = LS% - 111       \ The staging area where we copy files after loading and
                        \ before saving (though this isn't actually used in this
                        \ version, and is left-over Commodore 64 code)

 commbuf = &0E7E        \ The file buffer where we load and save commander files
                        \ (this shares a location with LSX2 and is the address
                        \ used in the *SAVE and *LOAD OS commands)

 INCLUDE "build/data-addresses.asm"

                        \ Port: the addresses of the game data (XX21, E%, KWL%,
                        \ KWH%, QQ18, SNE, ACT, TKN1, RUPLA, RUGAL, RUTOK), as
                        \ set in elite-data.asm, which build.sh assembles first
                        \ and takes these from (they were constants here)

 HOMEBANK = 4           \ Port: Elite's home bank, the sideways RAM bank that is
                        \ paged in while the game runs (bank 6 in the original)

 VIA = &FE00            \ Memory-mapped space for accessing internal hardware,
                        \ such as the video ULA, 6845 CRTC and 6522 VIAs (also
                        \ known as SHEILA)

 OSBYTE = &FFF4         \ The address for the OSBYTE routine

 OSCLI = &FFF7          \ The address for the OSCLI routine

\ ******************************************************************************
\
\       Name: ZP
\       Type: Workspace
\    Address: &0000 to &00E3
\   Category: Workspaces
\    Summary: Lots of important variables are stored in the zero page workspace
\             as it is quicker and more space-efficient to access memory here
\
\ ******************************************************************************

 ORG &0000              \ Set the assembly address to &0000

.ZP

 SKIP 2                 \ These bytes appear to be unused

IF _COMPACT

.MOS

 SKIP 1                 \ Determines whether we are running on a Master Compact
                        \
                        \   * 0 = This is a Master Compact
                        \
                        \   * &FF = This is not a Master Compact

ENDIF

.RAND

 SKIP 4                 \ Four 8-bit seeds for the random number generation
                        \ system implemented in the DORND routine

.T1

 SKIP 1                 \ Temporary storage, used in a number of places

.T2

 SKIP 1                 \ This byte appears to be unused

.T3

 SKIP 1                 \ This byte appears to be unused

.T4

 SKIP 1                 \ This byte appears to be unused

.SC

 SKIP 1                 \ Screen address (low byte)
                        \
                        \ Elite draws on-screen by poking bytes directly into
                        \ screen memory, and SC(1 0) is typically set to the
                        \ address of the character block containing the pixel
                        \ we want to draw

.SCH

 SKIP 1                 \ Screen address (high byte)

.P

 SKIP 4                 \ Temporary storage, used in a number of places

.XC

 SKIP 1                 \ The x-coordinate of the text cursor (i.e. the text
                        \ column), which can be from 0 to 32
                        \
                        \ A value of 0 denotes the leftmost column and 32 the
                        \ rightmost column, but because the top part of the
                        \ screen (the space view) has a border box that
                        \ clashes with columns 0 and 32, text is only shown
                        \ in columns 1-31

.COL

 SKIP 1                 \ Temporary storage, used to store colour information
                        \ when drawing pixels in the dashboard

.YC

 SKIP 1                 \ The y-coordinate of the text cursor (i.e. the text
                        \ row), which can be from 0 to 23
                        \
                        \ The screen actually has 31 character rows if you
                        \ include the dashboard, but the text printing routines
                        \ only work on the top part (the space view), so the
                        \ text cursor only goes up to a maximum of 23, the row
                        \ just before the screen splits
                        \
                        \ A value of 0 denotes the top row, but because the
                        \ top part of the screen has a border box that clashes
                        \ with row 0, text is always shown at row 1 or greater

.QQ17

 SKIP 1                 \ Contains a number of flags that affect how text tokens
                        \ are printed, particularly capitalisation
                        \
                        \   * If all bits are set (255) then text printing is
                        \     disabled
                        \
                        \   * Bit 7: 0 = ALL CAPS
                        \            1 = Sentence Case, bit 6 determines the
                        \                case of the next letter to print
                        \
                        \   * Bit 6: 0 = print the next letter in upper case
                        \            1 = print the next letter in lower case
                        \
                        \   * Bits 0-5: If any of bits 0-5 are set, print in
                        \               lower case
                        \
                        \ So:
                        \
                        \   * QQ17 = 0 means case is set to ALL CAPS
                        \
                        \   * QQ17 = %10000000 means Sentence Case, currently
                        \            printing upper case
                        \
                        \   * QQ17 = %11000000 means Sentence Case, currently
                        \            printing lower case
                        \
                        \   * QQ17 = %11111111 means printing is disabled

.K3

 SKIP 0                 \ Temporary storage, used in a number of places

.XX2

 SKIP 14                \ Temporary storage, used to store the visibility of the
                        \ ship's faces during the ship-drawing routine at LL9

.K4

 SKIP 2                 \ Temporary storage, used in a number of places

.XX16

 SKIP 18                \ Temporary storage for a block of values, used in a
                        \ number of places

.XX0

 SKIP 2                 \ Temporary storage, used to store the address of a ship
                        \ blueprint. For example, it is used when we add a new
                        \ ship to the local bubble in routine NWSHP, and it
                        \ contains the address of the current ship's blueprint
                        \ as we loop through all the nearby ships in the main
                        \ flight loop

.INF

 SKIP 2                 \ Temporary storage, typically used for storing the
                        \ address of a ship's data block, so it can be copied
                        \ to and from the internal workspace at INWK

.V

 SKIP 2                 \ Temporary storage, typically used for storing an
                        \ address pointer

.XX

 SKIP 2                 \ Temporary storage, typically used for storing a 16-bit
                        \ x-coordinate

.YY

 SKIP 2                 \ Temporary storage, typically used for storing a 16-bit
                        \ y-coordinate

.SUNX

 SKIP 2                 \ The 16-bit x-coordinate of the vertical centre axis
                        \ of the sun (which might be off-screen)

.BETA

 SKIP 1                 \ The current pitch angle beta, which is reduced from
                        \ JSTY to a sign-magnitude value between -8 and +8
                        \
                        \ This describes how fast we are pitching our ship, and
                        \ determines how fast the universe pitches around us
                        \
                        \ The sign bit is also stored in BET2, while the
                        \ opposite sign is stored in BET2+1

.BET1

 SKIP 1                 \ The magnitude of the pitch angle beta, i.e. |beta|,
                        \ which is a positive value between 0 and 8

.QQ22

 SKIP 2                 \ The two hyperspace countdown counters
                        \
                        \ Before a hyperspace jump, both QQ22 and QQ22+1 are
                        \ set to 15
                        \
                        \ QQ22 is an internal counter that counts down by 1
                        \ each time TT102 is called, which happens every
                        \ iteration of the main game loop. When it reaches
                        \ zero, the on-screen counter in QQ22+1 gets
                        \ decremented, and QQ22 gets set to 5 and the countdown
                        \ continues (so the first tick of the hyperspace counter
                        \ takes 15 iterations to happen, but subsequent ticks
                        \ take 5 iterations each)
                        \
                        \ QQ22+1 contains the number that's shown on-screen
                        \ during the countdown. It counts down from 15 to 1, and
                        \ when it hits 0, the hyperspace engines kick in

.ECMA

 SKIP 1                 \ The E.C.M. countdown timer, which determines whether
                        \ an E.C.M. system is currently operating
                        \
                        \   * 0 = E.C.M. is off
                        \
                        \   * Non-zero = E.C.M. is on and is counting down
                        \
                        \ The counter starts at 32 when an E.C.M. is activated,
                        \ either by us or by an opponent, and it decreases by 1
                        \ in each iteration of the main flight loop until it
                        \ reaches zero, at which point the E.C.M. switches off.
                        \ Only one E.C.M. can be active at any one time, so
                        \ there is only one counter

.ALP1

 SKIP 1                 \ Magnitude of the roll angle alpha, i.e. |alpha|,
                        \ which is a positive value between 0 and 31

.ALP2

 SKIP 2                 \ Bit 7 of ALP2 = sign of the roll angle in ALPHA
                        \
                        \ Bit 7 of ALP2+1 = opposite sign to ALP2 and ALPHA

.XX15

 SKIP 0                 \ Temporary storage, typically used for storing screen
                        \ coordinates in line-drawing routines
                        \
                        \ There are six bytes of storage, from XX15 TO XX15+5.
                        \ The first four bytes have the following aliases:
                        \
                        \   X1 = XX15
                        \   Y1 = XX15+1
                        \   X2 = XX15+2
                        \   Y2 = XX15+3
                        \
                        \ These are typically used for describing lines in terms
                        \ of screen coordinates, i.e. (X1, Y1) to (X2, Y2)
                        \
                        \ The last two bytes of XX15 do not have aliases

.X1

 SKIP 1                 \ Temporary storage, typically used for x-coordinates in
                        \ the line-drawing routines

.Y1

 SKIP 1                 \ Temporary storage, typically used for y-coordinates in
                        \ line-drawing routines

.X2

 SKIP 1                 \ Temporary storage, typically used for x-coordinates in
                        \ the line-drawing routines

.Y2

 SKIP 1                 \ Temporary storage, typically used for y-coordinates in
                        \ line-drawing routines

 SKIP 2                 \ The last two bytes of the XX15 block

.XX12

 SKIP 6                 \ Temporary storage for a block of values, used in a
                        \ number of places

.K

 SKIP 4                 \ Temporary storage, used in a number of places

.LAS

 SKIP 1                 \ Contains the laser power of the laser fitted to the
                        \ current space view (or 0 if there is no laser fitted
                        \ to the current view)
                        \
                        \ This gets set to bits 0-6 of the laser power byte from
                        \ the commander data block, which contains the laser's
                        \ power (bit 7 doesn't denote laser power, just whether
                        \ or not the laser pulses, so that is not stored here)

.MSTG

 SKIP 1                 \ The current missile lock target
                        \
                        \   * &FF = no target
                        \
                        \   * 1-12 = the slot number of the ship that our
                        \            missile is locked onto

.DL

 SKIP 1                 \ Vertical sync flag
                        \
                        \ DL gets set to 30 every time we reach vertical sync on
                        \ the video system, which happens 50 times a second
                        \ (50Hz). The WSCAN routine uses this to pause until the
                        \ vertical sync, by setting DL to 0 and then monitoring
                        \ its value until it changes to 30

.LSP

 SKIP 1                 \ The ball line heap pointer, which contains the number
                        \ of the first free byte after the end of the LSX2 and
                        \ LSY2 heaps

.QQ15

 SKIP 6                 \ The three 16-bit seeds for the selected system, i.e.
                        \ the one in the crosshairs in the Short-range Chart

.K5

 SKIP 0                 \ Temporary storage used to store segment coordinates
                        \ across successive calls to BLINE, the ball line
                        \ routine

.XX18

 SKIP 4                 \ Temporary storage used to store coordinates in the
                        \ LL9 ship-drawing routine

.K6

 SKIP 5                 \ Temporary storage, typically used for storing
                        \ coordinates during vector calculations

.QQ19

 SKIP 6                 \ Temporary storage, used in a number of places

.BET2

 SKIP 2                 \ Bit 7 of BET2 = sign of the pitch angle in BETA
                        \
                        \ Bit 7 of BET2+1 = opposite sign to BET2 and BETA

.DELTA

 SKIP 1                 \ Our current speed, in the range 1-40

.DELT4

 SKIP 2                 \ Our current speed * 64 as a 16-bit value
                        \
                        \ This is stored as DELT4(1 0), so the high byte in
                        \ DELT4+1 therefore contains our current speed / 4

.U

 SKIP 1                 \ Temporary storage, used in a number of places

.Q

 SKIP 1                 \ Temporary storage, used in a number of places

.R

 SKIP 1                 \ Temporary storage, used in a number of places

.S

 SKIP 1                 \ Temporary storage, used in a number of places

.T

 SKIP 1                 \ Temporary storage, used in a number of places

.XSAV

 SKIP 1                 \ Temporary storage for saving the value of the X
                        \ register, used in a number of places

.YSAV

 SKIP 1                 \ Temporary storage for saving the value of the Y
                        \ register, used in a number of places

.XX17

 SKIP 1                 \ Temporary storage, used in BPRNT to store the number
                        \ of characters to print, and as the edge counter in the
                        \ main ship-drawing routine

.W

 SKIP 1                 \ Temporary storage, used in a number of places

.QQ11

 SKIP 1                 \ The type of the current view:
                        \
                        \   0   = Space view
                        \         Death screen
                        \   1   = Data on System screen (red key f6)
                        \         Get commander name ("@", save/load commander)
                        \         In-system jump just arrived ("J")
                        \   2   = Buy Cargo screen (red key f1)
                        \   3   = Mis-jump just arrived (witchspace)
                        \   4   = Sell Cargo screen (red key f2)
                        \   8   = Status Mode screen (red key f8)
                        \         Inventory screen (red key f9)
                        \   13  = Rotating ship view (title or mission screen)
                        \   16  = Market Price screen (red key f7)
                        \   32  = Equip Ship screen (red key f3)
                        \   64  = Long-range Chart (red key f4)
                        \   128 = Short-range Chart (red key f5)
                        \   255 = Launch view
                        \
                        \ This value is typically set by calling routine TT66

.ZZ

 SKIP 1                 \ Temporary storage, typically used for distance values

.XX13

 SKIP 1                 \ Temporary storage, typically used in the line-drawing
                        \ routines

.MCNT

 SKIP 1                 \ The main loop counter
                        \
                        \ This counter determines how often certain actions are
                        \ performed within the main loop

.TYPE

 SKIP 1                 \ The current ship type
                        \
                        \ This is where we store the current ship type for when
                        \ we are iterating through the ships in the local bubble
                        \ as part of the main flight loop. See the table at XX21
                        \ for information about ship types

.ALPHA

 SKIP 1                 \ The current roll angle alpha, which is reduced from
                        \ JSTX to a sign-magnitude value between -31 and +31
                        \
                        \ This describes how fast we are rolling our ship, and
                        \ determines how fast the universe rolls around us
                        \
                        \ The sign bit is also stored in ALP2, while the
                        \ opposite sign is stored in ALP2+1

.QQ12

 SKIP 1                 \ Our "docked" status
                        \
                        \   * 0 = we are not docked
                        \
                        \   * &FF = we are docked

.TGT

 SKIP 1                 \ Temporary storage, typically used as a target value
                        \ for counters when drawing explosion clouds and partial
                        \ circles

.FLAG

 SKIP 1                 \ A flag that's used to define whether this is the first
                        \ call to the ball line routine in BLINE, so it knows
                        \ whether to wait for the second call before storing
                        \ segment data in the ball line heap

.CNT

 SKIP 1                 \ Temporary storage, typically used for storing the
                        \ number of iterations required when looping

.CNT2

 SKIP 1                 \ Temporary storage, used in the planet-drawing routine
                        \ to store the segment number where the arc of a partial
                        \ circle should start

.STP

 SKIP 1                 \ The step size for drawing circles
                        \
                        \ Circles in Elite are split up into 64 points, and the
                        \ step size determines how many points to skip with each
                        \ straight-line segment, so the smaller the step size,
                        \ the smoother the circle. The values used are:
                        \
                        \   * 2 for big planets and the circles on the charts
                        \
                        \   * 4 for medium planets and the launch tunnel
                        \
                        \   * 8 for small planets and the hyperspace tunnel
                        \
                        \ As the step size increases we move from smoother
                        \ circles at the top to more polygonal at the bottom.
                        \ See the CIRCLE2 routine for more details

.XX4

 SKIP 1                 \ Temporary storage, used in a number of places

.XX20

 SKIP 1                 \ Temporary storage, used in a number of places

.LSNUM

 SKIP 1                 \ The pointer to the current position in the ship line
                        \ heap as we work our way through the new ship's edges
                        \ (and the corresponding old ship's edges) when drawing
                        \ the ship in the main ship-drawing routine at LL9

.LSNUM2

 SKIP 1                 \ The size of the existing ship line heap for the ship
                        \ we are drawing in LL9, i.e. the number of lines in the
                        \ old ship that is currently shown on-screen and which
                        \ we need to erase

.RAT

 SKIP 1                 \ Used to store different signs depending on the current
                        \ space view, for use in calculating stardust movement

.RAT2

 SKIP 1                 \ Temporary storage, used to store the pitch and roll
                        \ signs when moving objects and stardust

.K2

 SKIP 4                 \ Temporary storage, used in a number of places

.widget

 SKIP 1                 \ Temporary storage, used to store the original argument
                        \ in A in the logarithmic FMLTU and LL28 routines

.dontclip

 SKIP 1                 \ This is set to 0 in the RES2 routine, but the value is
                        \ never actually read (this is left over from the
                        \ Commodore 64 version of Elite)

.Yx2M1

 SKIP 1                 \ This is used to store the number of pixel rows in the
                        \ space view minus 1, which is also the y-coordinate of
                        \ the bottom pixel row of the space view (it is set to
                        \ 191 in the RES2 routine)

.messXC

 SKIP 1                 \ Temporary storage, used to store the text column
                        \ of the in-flight message in MESS, so it can be erased
                        \ from the screen at the correct time

.newzp

 SKIP 1                 \ This is used by the STARS2 routine for storing the
                        \ stardust particle's delta_x value

.XX1

 SKIP 0                 \ This is an alias for INWK that is used in the main
                        \ ship-drawing routine at LL9

.INWK

 SKIP 33                \ The zero-page internal workspace for the current ship
                        \ data block
                        \
                        \ As operations on zero page locations are faster and
                        \ have smaller opcodes than operations on the rest of
                        \ the addressable memory, Elite tends to store oft-used
                        \ data here. A lot of the routines in Elite need to
                        \ access and manipulate ship data, so to make this an
                        \ efficient exercise, the ship data is first copied from
                        \ the ship data blocks at K% into INWK (or, when new
                        \ ships are spawned, from the blueprints at XX21)

.XX19

 SKIP NI% - 34          \ XX19(1 0) shares its location with INWK(34 33), which
                        \ contains the address of the ship line heap

.NEWB

 SKIP 1                 \ The ship's "new byte flags" (or NEWB flags)
                        \
                        \ Contains details about the ship's type and associated
                        \ behaviour, such as whether they are a trader, a bounty
                        \ hunter, a pirate, currently hostile, in the process of
                        \ docking, inside the hold having been scooped, and so
                        \ on. The default values for each ship type are taken
                        \ from the table at E%

.JSTX

 SKIP 1                 \ Our current roll rate
                        \
                        \ This value is shown in the dashboard's RL indicator,
                        \ and determines the rate at which we are rolling
                        \
                        \ The value ranges from 1 to 255 with 128 as the centre
                        \ point, so 1 means roll is decreasing at the maximum
                        \ rate, 128 means roll is not changing, and 255 means
                        \ roll is increasing at the maximum rate
                        \
                        \ This value is updated by "<" and ">" key presses, or
                        \ if joysticks are enabled, from the joystick. If
                        \ keyboard damping is enabled (which it is by default),
                        \ the value is slowly moved towards the centre value of
                        \ 128 (no roll) if there are no key presses or joystick
                        \ movement

.JSTY

 SKIP 1                 \ Our current pitch rate
                        \
                        \ This value is shown in the dashboard's DC indicator,
                        \ and determines the rate at which we are pitching
                        \
                        \ The value ranges from 1 to 255 with 128 as the centre
                        \ point, so 1 means pitch is decreasing at the maximum
                        \ rate, 128 means pitch is not changing, and 255 means
                        \ pitch is increasing at the maximum rate
                        \
                        \ This value is updated by "S" and "X" key presses, or
                        \ if joysticks are enabled, from the joystick. If
                        \ keyboard damping is enabled (which it is by default),
                        \ the value is slowly moved towards the centre value of
                        \ 128 (no pitch) if there are no key presses or joystick
                        \ movement

.KL

 SKIP 1                 \ The following bytes implement a key logger that
                        \ enables Elite to scan for concurrent key presses of
                        \ the primary flight keys, plus a secondary flight key
                        \
                        \ If a key is being pressed that is not in the keyboard
                        \ table at KYTB, it can be stored here (as seen in
                        \ routine DK4, for example)

.KY17

 SKIP 1                 \ "E" is being pressed (activate E.C.M.)
                        \
                        \   * 0 = no
                        \
                        \   * Non-zero = yes

.KY14

 SKIP 1                 \ "T" is being pressed (target missile)
                        \
                        \   * 0 = no
                        \
                        \   * Non-zero = yes

.KY15

 SKIP 1                 \ "U" is being pressed (unarm missile)
                        \
                        \   * 0 = no
                        \
                        \   * Non-zero = yes

.KY20

 SKIP 1                 \ "P" is being pressed (deactivate docking computer)
                        \
                        \   * 0 = no
                        \
                        \   * Non-zero = yes

.KY7

 SKIP 1                 \ "A" is being pressed (fire lasers)
                        \
                        \   * 0 = no
                        \
                        \   * Non-zero = yes
                        \
                        \ This is also set when the joystick fire button has
                        \ been pressed

.KY5

 SKIP 1                 \ "X" is being pressed (pull up)
                        \
                        \   * 0 = no
                        \
                        \   * Non-zero = yes

.KY18

 SKIP 1                 \ "J" is being pressed (in-system jump)
                        \
                        \   * 0 = no
                        \
                        \   * Non-zero = yes

.KY6

 SKIP 1                 \ "S" is being pressed (pitch down)
                        \
                        \   * 0 = no
                        \
                        \   * Non-zero = yes

.KY19

 SKIP 1                 \ "C" is being pressed (activate docking computer)
                        \
                        \   * 0 = no
                        \
                        \   * Non-zero = yes

.KY12

 SKIP 1                 \ TAB is being pressed (energy bomb)
                        \
                        \   * 0 = no
                        \
                        \   * Non-zero = yes

.KY2

 SKIP 1                 \ Space is being pressed (speed up)
                        \
                        \   * 0 = no
                        \
                        \   * Non-zero = yes

.KY16

 SKIP 1                 \ "M" is being pressed (fire missile)
                        \
                        \   * 0 = no
                        \
                        \   * Non-zero = yes

.KY3

 SKIP 1                 \ "<" is being pressed (roll left)
                        \
                        \   * 0 = no
                        \
                        \   * Non-zero = yes

.KY4

 SKIP 1                 \ ">" is being pressed (roll right)
                        \
                        \   * 0 = no
                        \
                        \   * Non-zero = yes

.KY1

 SKIP 1                 \ "?" is being pressed (slow down)
                        \
                        \   * 0 = no
                        \
                        \   * Non-zero = yes

.KY13

 SKIP 1                 \ ESCAPE is being pressed (launch escape pod)
                        \
                        \   * 0 = no
                        \
                        \   * Non-zero = yes

.LSX

 SKIP 1                 \ LSX contains the status of the sun line heap at LSO
                        \
                        \   * &FF indicates the sun line heap is empty
                        \
                        \   * Otherwise the LSO heap contains the line data for
                        \     the sun

.FSH

 SKIP 1                 \ Forward shield status
                        \
                        \   * 0 = empty
                        \
                        \   * &FF = full

.ASH

 SKIP 1                 \ Aft shield status
                        \
                        \   * 0 = empty
                        \
                        \   * &FF = full

.ENERGY

 SKIP 1                 \ Energy bank status
                        \
                        \   * 0 = empty
                        \
                        \   * &FF = full

.QQ3

 SKIP 1                 \ The selected system's economy (0-7)
                        \
                        \   * 0 = Rich Industrial
                        \   * 1 = Average Industrial
                        \   * 2 = Poor Industrial
                        \   * 3 = Mainly Industrial
                        \   * 4 = Mainly Agricultural
                        \   * 5 = Rich Agricultural
                        \   * 6 = Average Agricultural
                        \   * 7 = Poor Agricultural

.QQ4

 SKIP 1                 \ The selected system's government (0-7)

.QQ5

 SKIP 1                 \ The selected system's tech level (0-14)

.QQ6

 SKIP 2                 \ The selected system's population in billions * 10
                        \ (1-71), so the maximum population is 7.1 billion

.QQ7

 SKIP 2                 \ The selected system's productivity in M CR (96-62480)

.QQ8

 SKIP 2                 \ The distance from the current system to the selected
                        \ system in light years * 10, stored as a 16-bit number
                        \
                        \ The distance will be 0 if the selected system is the
                        \ current system
                        \
                        \ The galaxy chart is 102.4 light years wide and 51.2
                        \ light years tall (see the intra-system distance
                        \ calculations in routine TT111 for details), which
                        \ equates to 1024 x 512 in terms of QQ8

.QQ9

 SKIP 1                 \ The galactic x-coordinate of the crosshairs in the
                        \ galaxy chart (and, most of the time, the selected
                        \ system's galactic x-coordinate)

.QQ10

 SKIP 1                 \ The galactic y-coordinate of the crosshairs in the
                        \ galaxy chart (and, most of the time, the selected
                        \ system's galactic y-coordinate)

.NOSTM

 SKIP 1                 \ The number of stardust particles shown on screen,
                        \ which is 20 (#NOST) for normal space, and 3 for
                        \ witchspace

 PRINT "ZP workspace from ", ~ZP, "to ", ~P%-1, "inclusive"

\ ******************************************************************************
\
\       Name: XX3
\       Type: Workspace
\    Address: &0100 to the top of the descending stack
\   Category: Workspaces
\    Summary: Temporary storage space for complex calculations
\
\ ------------------------------------------------------------------------------
\
\ Used as heap space for storing temporary data during calculations. Shared with
\ the descending 6502 stack, which works down from &01FF.
\
\ ******************************************************************************

 ORG &0100              \ Set the assembly address to &0100

.XX3

 SKIP 256               \ Temporary storage, typically used for storing tables
                        \ of values such as screen coordinates or ship data

\ ******************************************************************************
\
\       Name: K%
\       Type: Workspace
\    Address: &0400 to &05BB
\   Category: Workspaces
\    Summary: Ship data blocks and ship line heaps
\  Deep dive: Ship data blocks
\             The local bubble of universe
\
\ ------------------------------------------------------------------------------
\
\ Contains ship data for all the ships, planets, suns and space stations in our
\ local bubble of universe.
\
\ The blocks are pointed to by the lookup table at location UNIV. The first 444
\ bytes of the K% workspace hold ship data on up to 12 ships, with 37 (NI%)
\ bytes per ship.
\
\ ******************************************************************************

 ORG &0400              \ Set the assembly address to &0400

.K%

 SKIP NOSH * NI%        \ Ship data blocks and ship line heap

 PRINT "K% workspace from ", ~K%, "to ", ~P%-1, "inclusive"

 ASSERT P% <= &0D00     \ Port: nothing may be assembled into page &0D, which
                        \ holds the DFS's NMI routine, the extended vectors and
                        \ the ROM workspace table on a Master (see "Page &0D is
                        \ off limits" in docs/MASTER-MEMORY.md)

\ ******************************************************************************
\
\       Name: WP
\       Type: Workspace
\    Address: &0E41 to &12A9
\   Category: Workspaces
\    Summary: Ship slots, variables
\
\ ******************************************************************************

 ASSERT &0E41 >= &0E00  \ Port: WP starts above page &0D (see K%)

 ORG &0E41              \ Set the assembly address to &0E41

.WP

 SKIP 0                 \ The start of the WP workspace

.FRIN

 SKIP NOSH + 1          \ Slots for the ships in the local bubble of universe
                        \
                        \ There are #NOSH + 1 slots, but the ship-spawning
                        \ routine at NWSHP only populates #NOSH of them, so
                        \ there are 13 slots but only 12 are used for ships
                        \ (the last slot is effectively used as a null
                        \ terminator when shuffling the slots down in the
                        \ KILLSHP routine)

.MANY

 SKIP SST               \ The number of ships of each type in the local bubble
                        \ of universe
                        \
                        \ The number of ships of type X in the local bubble is
                        \ stored at MANY+X

.SSPR

 SKIP NTY + 1 - SST     \ "Space station present" flag
                        \
                        \   * Non-zero if we are inside the space station's safe
                        \     zone
                        \
                        \   * 0 if we aren't (in which case we can show the sun)
                        \
                        \ This flag is at MANY+SST, which is no coincidence, as
                        \ MANY+SST is a count of how many space stations there
                        \ are in our local bubble, which is the same as saying
                        \ "space station present"

.JUNK

 SKIP 1                 \ The amount of junk in the local bubble
                        \
                        \ "Junk" is defined as being one of these:
                        \
                        \   * Escape pod
                        \   * Alloy plate
                        \   * Cargo canister
                        \   * Asteroid
                        \   * Splinter
                        \   * Shuttle
                        \   * Transporter

.auto

 SKIP 1                 \ Docking computer activation status
                        \
                        \   * 0 = Docking computer is off
                        \
                        \   * Non-zero = Docking computer is running

.ECMP

 SKIP 1                 \ Our E.C.M. status
                        \
                        \   * 0 = E.C.M. is off
                        \
                        \   * Non-zero = E.C.M. is on

.MJ

 SKIP 1                 \ Are we in witchspace (i.e. have we mis-jumped)?
                        \
                        \   * 0 = no, we are in normal space
                        \
                        \   * &FF = yes, we are in witchspace

.CABTMP

 SKIP 1                 \ Cabin temperature
                        \
                        \ The ambient cabin temperature in deep space is 30,
                        \ which is displayed as one notch on the dashboard bar
                        \
                        \ We get higher temperatures closer to the sun
                        \
                        \ CABTMP shares a location with MANY, but that's OK as
                        \ MANY+0 would contain the number of ships of type 0,
                        \ and as there is no ship type 0 (they start at 1), the
                        \ byte at MANY+0 is not used for storing a ship type
                        \ and can be used for the cabin temperature instead

.LAS2

 SKIP 1                 \ Laser power for the current laser
                        \
                        \   * Bits 0-6 contain the laser power of the current
                        \     space view
                        \
                        \   * Bit 7 denotes whether or not the laser pulses:
                        \
                        \     * 0 = pulsing laser
                        \
                        \     * 1 = beam laser (i.e. always on)

.MSAR

 SKIP 1                 \ The targeting state of our leftmost missile
                        \
                        \   * 0 = missile is not looking for a target, or it
                        \     already has a target lock (indicator is not
                        \     yellow/white)
                        \
                        \   * Non-zero = missile is currently looking for a
                        \     target (indicator is yellow/white)

.VIEW

 SKIP 1                 \ The number of the current space view
                        \
                        \   * 0 = front
                        \   * 1 = rear
                        \   * 2 = left
                        \   * 3 = right

.LASCT

 SKIP 1                 \ The laser pulse count for the current laser
                        \
                        \ This is a counter that defines the gap between the
                        \ pulses of a pulse laser. It is set as follows:
                        \
                        \   * 0 for a beam laser
                        \
                        \   * 10 for a pulse laser
                        \
                        \ It gets decremented by 2 on each iteration around the
                        \ main game loop and is set to a non-zero value for
                        \ pulse lasers only
                        \
                        \ The laser only fires when the value of LASCT hits
                        \ zero, so for pulse lasers with a value of 10, that
                        \ means the laser fires once every five iterations
                        \ around the main game loop (LASCT = 10, 8, 6, 4, 2, 0)
                        \
                        \ In comparison, beam lasers fire continuously as the
                        \ value of LASCT is always 0

.GNTMP

 SKIP 1                 \ Laser temperature (or "gun temperature")
                        \
                        \ If the laser temperature exceeds 242 then the laser
                        \ overheats and cannot be fired again until it has
                        \ cooled down

.HFX

 SKIP 1                 \ A flag that toggles the hyperspace colour effect
                        \
                        \   * 0 = no colour effect
                        \
                        \   * Non-zero = hyperspace colour effect enabled
                        \
                        \ When HFX is set to 1, the mode 1 screen that makes
                        \ up the top part of the display is temporarily switched
                        \ to mode 2 (the same screen mode as the dashboard),
                        \ which has the effect of blurring and colouring the
                        \ hyperspace rings in the top part of the screen. The
                        \ code to do this is in the LINSCN routine, which is
                        \ called as part of the screen mode routine at IRQ1.
                        \ It's in LINSCN that HFX is checked, and if it is
                        \ non-zero, the top part of the screen is not switched
                        \ to mode 1, thus leaving the top part of the screen in
                        \ the more colourful mode 2

.EV

 SKIP 1                 \ The "extra vessels" spawning counter
                        \
                        \ This counter is set to 0 on arrival in a system and
                        \ following an in-system jump, and is bumped up when we
                        \ spawn bounty hunters or pirates (i.e. "extra vessels")
                        \
                        \ It decreases by 1 each time we consider spawning more
                        \ "extra vessels" in part 4 of the main game loop, so
                        \ increasing the value of EV has the effect of delaying
                        \ the spawning of more vessels
                        \
                        \ In other words, this counter stops bounty hunters and
                        \ pirates from continually appearing, and ensures that
                        \ there's a delay between spawnings

.DLY

 SKIP 1                 \ In-flight message delay
                        \
                        \ This counter is used to keep an in-flight message up
                        \ for a specified time before it gets removed. The value
                        \ in DLY is decremented each time we start another
                        \ iteration of the main game loop at TT100

.de

 SKIP 1                 \ Equipment destruction flag
                        \
                        \   * Bit 1 denotes whether or not the in-flight message
                        \     about to be shown by the MESS routine is about
                        \     destroyed equipment:
                        \
                        \     * 0 = the message is shown normally
                        \
                        \     * 1 = the string " DESTROYED" gets added to the
                        \       end of the message

.LSX2

 SKIP 256               \ The ball line heap for storing x-coordinates

.LSY2

 SKIP 256               \ The ball line heap for storing y-coordinates

.LSO

 SKIP 200               \ The ship line heap for the space station (see NWSPS)
                        \ and the sun line heap (see SUN)
                        \
                        \ The spaces can be shared as our local bubble of
                        \ universe can support either the sun or a space
                        \ station, but not both

.BUF

 SKIP 90                \ The line buffer used by DASC to print justified text

.SX

 SKIP NOST + 1          \ This is where we store the x_hi coordinates for all
                        \ the stardust particles

.SXL

 SKIP NOST + 1          \ This is where we store the x_lo coordinates for all
                        \ the stardust particles

.SY

 SKIP NOST + 1          \ This is where we store the y_hi coordinates for all
                        \ the stardust particles

.SYL

 SKIP NOST + 1          \ This is where we store the y_lo coordinates for all
                        \ the stardust particles

.SZ

 SKIP NOST + 1          \ This is where we store the z_hi coordinates for all
                        \ the stardust particles

.SZL

 SKIP NOST + 1          \ This is where we store the z_lo coordinates for all
                        \ the stardust particles

.LASX

 SKIP 1                 \ The x-coordinate of the tip of the laser line

.LASY

 SKIP 1                 \ The y-coordinate of the tip of the laser line

.XX24

 SKIP 1                 \ This byte appears to be unused

.ALTIT

 SKIP 1                 \ Our altitude above the surface of the planet or sun
                        \
                        \   * 255 = we are a long way above the surface
                        \
                        \   * 1-254 = our altitude as the square root of:
                        \
                        \       x_hi^2 + y_hi^2 + z_hi^2 - 6^2
                        \
                        \     where our ship is at the origin, the centre of the
                        \     planet/sun is at (x_hi, y_hi, z_hi), and the
                        \     radius of the planet/sun is 6
                        \
                        \   * 0 = we have crashed into the surface

.SWAP

 SKIP 1                 \ Temporary storage, used to store a flag that records
                        \ whether or not we had to swap a line's start and end
                        \ coordinates around when clipping the line in routine
                        \ LL145 (the flag is used in places like BLINE to swap
                        \ them back)

.XP

 SKIP 1                 \ This byte appears to be unused

.YP

 SKIP 1                 \ This byte appears to be unused

.YS

 SKIP 1                 \ This byte appears to be unused

.BALI

 SKIP 1                 \ This byte appears to be unused

.UPO

 SKIP 1                 \ This byte appears to be unused

.boxsize

 SKIP 1                 \ This byte appears to be unused

.distaway

 SKIP 1                 \ Used to store the nearest distance of the rotating
                        \ ship on the title screen

.XSAV2

 SKIP 1                 \ This byte appears to be unused

.YSAV2

 SKIP 1                 \ This byte appears to be unused

IF _COMPACT

.NMI

 SKIP 1                 \ Used to store the ID of the current owner of the NMI
                        \ workspace in the NMICLAIM routine, so we can hand it
                        \ back to them in the NMIRELEASE routine once we are
                        \ done using it

ENDIF

.NAME

 SKIP 8                 \ The current commander name
                        \
                        \ The commander name can be up to 7 characters (the DFS
                        \ limit for filenames), and is terminated by a carriage
                        \ return

.TP

 SKIP 1                 \ The current mission status
                        \
                        \   * Bits 0-1 = Mission 1 status
                        \
                        \     * %00 = Mission not started
                        \     * %01 = Mission in progress, hunting for ship
                        \     * %11 = Constrictor killed, not debriefed yet
                        \     * %10 = Mission and debrief complete
                        \
                        \   * Bits 2-3 = Mission 2 status
                        \
                        \     * %00 = Mission not started
                        \     * %01 = Mission in progress, plans not picked up
                        \     * %10 = Mission in progress, plans picked up
                        \     * %11 = Mission complete

.QQ0

 SKIP 1                 \ The current system's galactic x-coordinate (0-256)

.QQ1

 SKIP 1                 \ The current system's galactic y-coordinate (0-256)

.QQ21

 SKIP 6                 \ The three 16-bit seeds for the current galaxy
                        \
                        \ These seeds define system 0 in the current galaxy, so
                        \ they can be used as a starting point to generate all
                        \ 256 systems in the galaxy
                        \
                        \ Using a galactic hyperdrive rotates each byte to the
                        \ left (rolling each byte within itself) to get the
                        \ seeds for the next galaxy, so after eight galactic
                        \ jumps, the seeds roll around to the first galaxy again

.CASH

 SKIP 4                 \ Our current cash pot
                        \
                        \ The cash stash is stored as a 32-bit unsigned integer,
                        \ with the most significant byte in CASH and the least
                        \ significant in CASH+3. This is big-endian, which is
                        \ the opposite way round to most of the numbers used in
                        \ Elite - to use our notation for multi-byte numbers,
                        \ the amount of cash is CASH(0 1 2 3)

.QQ14

 SKIP 1                 \ Our current fuel level (0-70)
                        \
                        \ The fuel level is stored as the number of light years
                        \ multiplied by 10, so QQ14 = 1 represents 0.1 light
                        \ years, and the maximum possible value is 70, for 7.0
                        \ light years

.COK

 SKIP 1                 \ Flags used to generate the competition code

.GCNT

 SKIP 1                 \ The number of the current galaxy (0-7)
                        \
                        \ When this is displayed in-game, 1 is added to the
                        \ number, so we start in galaxy 1 in-game, but it's
                        \ stored as galaxy 0 internally
                        \
                        \ The galaxy number increases by one every time a
                        \ galactic hyperdrive is used, and wraps back around to
                        \ the start after eight galaxies

.LASER

 SKIP 4                 \ The specifications of the lasers fitted to each of the
                        \ four space views
                        \
                        \   * Byte #0 = front view
                        \
                        \   * Byte #1 = rear view
                        \
                        \   * Byte #2 = left view
                        \
                        \   * Byte #3 = right view
                        \
                        \ The value for each view is as follows:
                        \
                        \   * 0 = no laser is fitted to this view
                        \
                        \   * Non-zero = a laser is fitted to this view, with
                        \     the following specification:
                        \
                        \     * Bits 0-6 contain the laser's power
                        \
                        \     * Bit 7 determines whether or not the laser pulses
                        \       (0 = pulse or mining laser) or is always on
                        \       (1 = beam or military laser)

 SKIP 2                 \ These bytes appear to be unused (they were originally
                        \ used for up/down lasers, but they were dropped)

.CRGO

 SKIP 1                 \ Our ship's cargo capacity
                        \
                        \   * 22 = standard cargo bay of 20 tonnes
                        \
                        \   * 37 = large cargo bay of 35 tonnes
                        \
                        \ The value is two greater than the actual capacity to
                        \ make the maths in tnpr slightly more efficient

.QQ20

 SKIP 17                \ The contents of our cargo hold
                        \
                        \ The amount of market item X that we have in our hold
                        \ can be found in the X-th byte of QQ20. For example:
                        \
                        \   * QQ20 contains the amount of food (item 0)
                        \
                        \   * QQ20+7 contains the amount of computers (item 7)
                        \
                        \ See QQ23 for a list of market item numbers and their
                        \ storage units

.ECM

 SKIP 1                 \ E.C.M. system
                        \
                        \   * 0 = not fitted
                        \
                        \   * &FF = fitted

.BST

 SKIP 1                 \ Fuel scoops (BST stands for "barrel status")
                        \
                        \   * 0 = not fitted
                        \
                        \   * &FF = fitted

.BOMB

 SKIP 1                 \ Energy bomb
                        \
                        \   * 0 = not fitted
                        \
                        \   * &7F = fitted

.ENGY

 SKIP 1                 \ Energy unit
                        \
                        \   * 0 = not fitted
                        \
                        \   * Non-zero = fitted
                        \
                        \ The actual value determines the refresh rate of our
                        \ energy banks, as they refresh by ENGY+1 each time (so
                        \ our ship's energy level goes up by 2 each time if we
                        \ have an energy unit fitted, otherwise it goes up by 1)
                        \
                        \ The enhanced versions of Elite set ENGY to 2 as the
                        \ reward for completing mission 2, where we receive a
                        \ special naval energy unit that recharges at a fast
                        \ rate than a standard energy unit, i.e. by 3 each time

.DKCMP

 SKIP 1                 \ Docking computer
                        \
                        \   * 0 = not fitted
                        \
                        \   * &FF = fitted

.GHYP

 SKIP 1                 \ Galactic hyperdrive
                        \
                        \   * 0 = not fitted
                        \
                        \   * &FF = fitted

.ESCP

 SKIP 1                 \ Escape pod
                        \
                        \   * 0 = not fitted
                        \
                        \   * &FF = fitted

 SKIP 1                 \ This byte appears to be unused

.TRIBBLE

 SKIP 2                 \ The number of Trumbles in the cargo hold
                        \
                        \ The Master version doesn't actually have Trumbles, but
                        \ the Trumble code from the other versions was kept when
                        \ the Master version was put together

.TALLYL

 SKIP 1                 \ Combat rank fraction
                        \
                        \ Contains the fraction part of the kill count, which
                        \ together with the integer in TALLY(1 0) determines our
                        \ combat rank. The fraction is stored as the numerator
                        \ of a fraction with a denominator of 256, so a TALLYL
                        \ of 128 would represent 0.5 (i.e. 128 / 256)

.NOMSL

 SKIP 1                 \ The number of missiles we have fitted (0-4)

.FIST

 SKIP 1                 \ Our legal status (FIST stands for "fugitive/innocent
                        \ status")
                        \
                        \   * 0 = Clean
                        \
                        \   * 1-49 = Offender
                        \
                        \   * 50+ = Fugitive
                        \
                        \ You get 64 points if you kill a cop, so that's a fast
                        \ ticket to fugitive status

.AVL

 SKIP 17                \ Market availability in the current system
                        \
                        \ The available amount of market item X is stored in
                        \ the X-th byte of AVL, so for example:
                        \
                        \   * AVL contains the amount of food (item 0)
                        \
                        \   * AVL+7 contains the amount of computers (item 7)
                        \
                        \ See QQ23 for a list of market item numbers and their
                        \ storage units

.QQ26

 SKIP 1                 \ A random value used to randomise market data
                        \
                        \ This value is set to a new random number for each
                        \ change of system, so we can add a random factor into
                        \ the calculations for market prices

.TALLY

 SKIP 2                 \ Our combat rank
                        \
                        \ The combat rank is stored as the number of kills, in a
                        \ 16-bit number TALLY(1 0) - so the high byte is in
                        \ TALLY+1 and the low byte in TALLY
                        \
                        \ There is also a fractional part of the kill count,
                        \ which is stored in TALLYL
                        \
                        \ If the high byte in TALLY+1 is 0 then we have between
                        \ 0 and 255 kills, so our rank is Harmless, Mostly
                        \ Harmless, Poor, Average Above Average or Competent,
                        \ according to the value of the low byte in TALLY:
                        \
                        \   Harmless         %00000000 to %00000111 = 0 to 7
                        \   Mostly Harmless  %00001000 to %00001111 = 8 to 15
                        \   Poor             %00010000 to %00011111 = 16 to 31
                        \   Average          %00100000 to %00111111 = 32 to 63
                        \   Above Average    %01000000 to %01111111 = 64 to 127
                        \   Competent        %10000000 to %11111111 = 128 to 255
                        \
                        \ Note that the Competent range also covers kill counts
                        \ from 256 to 511, as follows
                        \
                        \ If the high byte in TALLY+1 is non-zero then we are
                        \ Competent, Dangerous, Deadly or Elite, according to
                        \ the value of TALLY(1 0):
                        \
                        \   Competent   (1 0) to (1 255)   = 256 to 511 kills
                        \   Dangerous   (2 0) to (9 255)   = 512 to 2559 kills
                        \   Deadly      (10 0) to (24 255) = 2560 to 6399 kills
                        \   Elite       (25 0) and up      = 6400 kills and up
                        \
                        \ You can see the rating calculation in the STATUS
                        \ subroutine

.SVC

 SKIP 1                 \ The save count
                        \
                        \ When a new commander is created, the save count gets
                        \ set to 128. This value gets halved each time the
                        \ commander file is saved, but it is otherwise unused.
                        \ It is presumably part of the security system for the
                        \ competition, possibly another flag to catch out
                        \ entries with manually altered commander files

 SKIP 2                 \ The commander file checksum
                        \
                        \ These two bytes are reserved for the commander file
                        \ checksum, so when the current commander block is
                        \ copied from here to the last saved commander block at
                        \ NA%, CHK and CHK2 get overwritten

 NT% = SVC + 3 - TP     \ This sets the variable NT% to the size of the current
                        \ commander data block, which starts at TP and ends at
                        \ SVC+3 (inclusive), i.e. with the last checksum byte

 SKIP 1                 \ This byte appears to be unused

.MCH

 SKIP 1                 \ The text token number of the in-flight message that is
                        \ currently being shown, and which will be removed by
                        \ the me2 routine when the counter in DLY reaches zero

.COMX

 SKIP 1                 \ The x-coordinate of the compass dot

.COMY

 SKIP 1                 \ The y-coordinate of the compass dot

.dialc

 SKIP 14                \ These bytes are unused in this version of Elite
                        \
                        \ They are left over from the Apple II version, where
                        \ they are used to store the current colour of the
                        \ dashboard indicators

.QQ24

 SKIP 1                 \ Temporary storage, used to store the current market
                        \ item's price in routine TT151

.QQ25

 SKIP 1                 \ Temporary storage, used to store the current market
                        \ item's availability in routine TT151

.QQ28

 SKIP 1                 \ The current system's economy (0-7)
                        \
                        \   * 0 = Rich Industrial
                        \   * 1 = Average Industrial
                        \   * 2 = Poor Industrial
                        \   * 3 = Mainly Industrial
                        \   * 4 = Mainly Agricultural
                        \   * 5 = Rich Agricultural
                        \   * 6 = Average Agricultural
                        \   * 7 = Poor Agricultural

.QQ29

 SKIP 1                 \ Temporary storage, used in a number of places

.gov

 SKIP 1                 \ The current system's government type (0-7)

.tek

 SKIP 1                 \ The current system's tech level (0-14)

.SLSP

 SKIP 2                 \ The address of the bottom of the ship line heap
                        \
                        \ The ship line heap is a descending block of memory
                        \ extended downwards by the NWSHP routine when adding
                        \ new ships (and their associated ship line heaps), in
                        \ which case SLSP is lowered to provide more heap space,
                        \ assuming there is enough free memory to do so

.QQ2

 SKIP 6                 \ The three 16-bit seeds for the current system, i.e.
                        \ the one we are currently in

.safehouse

 SKIP 6                 \ Backup storage for the seeds for the selected system
                        \
                        \ The seeds for the current system get stored here as
                        \ soon as a hyperspace is initiated, so we can fetch
                        \ them in the hyp1 routine. This fixes a bug in an
                        \ earlier version where you could hyperspace while
                        \ docking and magically appear in your destination
                        \ station

.frump

 SKIP 1                 \ Used to store the number of particles in the explosion
                        \ cloud, though the number is never actually used

.JOPOS

 SKIP 1                 \ Contains the high byte of the latest value from ADC
                        \ channel 1 (the joystick X value), which gets updated
                        \ regularly by the IRQ1 interrupt handler

 SKIP 1                 \ Contains the high byte of the latest value from ADC
                        \ channel 2 (the joystick Y value), which gets updated
                        \ regularly by the IRQ1 interrupt handler

 SKIP 1                 \ Contains the high byte of the latest value from ADC
                        \ channel 3 (the Bitstik rotation value), which gets
                        \ updated regularly by the IRQ1 interrupt handler

 PRINT "WP workspace from ", ~WP, "to ", ~P%-1, "inclusive"

\ ******************************************************************************
\
\ ELITE A FILE
\
\ ******************************************************************************

 ORG CODE%              \ Set the assembly address to CODE%

 LOAD_A% = LOAD%

\ ******************************************************************************
\
\       Name: VEC
\       Type: Variable
\   Category: Drawing the screen
\    Summary: The original value of the IRQ1 vector
\
\ ******************************************************************************

.VEC

 EQUW &8888             \ This gets set to the value of the original IRQ1 vector
                        \ by the STARTUP routine

\ ******************************************************************************
\
\       Name: WSCAN
\       Type: Subroutine
\   Category: Drawing the screen
\    Summary: Implement the #wscn command (wait for the vertical sync)
\
\ ------------------------------------------------------------------------------
\
\ Wait for vertical sync to occur on the video system - in other words, wait
\ for the screen to start its refresh cycle, which it does 50 times a second
\ (50Hz).
\
\ ******************************************************************************

.WSCAN

 STZ DL                 \ Set DL to 0

.DELL1K                 \ This label is a duplicate of a label in the DELT
                        \ routine
                        \
                        \ In the original source this label is DELL1, but
                        \ because BeebAsm doesn't allow us to redefine labels,
                        \ I have renamed it to DELL1K

 LDA DL                 \ Loop round these two instructions until DL is no
 BEQ DELL1K             \ longer 0 (DL gets set to 30 in the LINSCN routine,
                        \ which is run when vertical sync has occurred on the
                        \ video system, so DL will change to a non-zero value
                        \ at the start of each screen refresh)

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: DELAY
\       Type: Subroutine
\   Category: Utility routines
\    Summary: Wait for a specified time, in 1/50s of a second
\
\ ------------------------------------------------------------------------------
\
\ Wait for the number of vertical syncs given in Y, so this effectively waits
\ for Y/50 of a second (as the vertical sync occurs 50 times a second).
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   Y                   The number of vertical sync events to wait for
\
\ ******************************************************************************

.DELAY

 JSR WSCAN              \ Call WSCAN to wait for the vertical sync, so the whole
                        \ screen gets drawn

 DEY                    \ Decrement the counter in Y

 BNE DELAY              \ If Y isn't yet at zero, jump back to DELAY to wait
                        \ for another vertical sync

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: BOOP
\       Type: Subroutine
\   Category: Sound
\    Summary: Make a long, low beep
\
\ ******************************************************************************

.BOOP

 LDY #soboop            \ Call the NOISE routine with Y = 0 to make a long, low
 BRA NOISE              \ beep, returning from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: BEEP
\       Type: Subroutine
\   Category: Sound
\    Summary: Make a short, high beep
\
\ ******************************************************************************

.BEEP

 LDY #sobeep            \ Call the NOISE routine with Y = 1 to make a short,
 BRA NOISE              \ high beep, returning from the subroutine using a tail
                        \ call

\ ******************************************************************************
\
\       Name: SOFH
\       Type: Variable
\   Category: Sound
\    Summary: Sound chip data mask for choosing a tone channel in the range 0-2
\
\ ******************************************************************************

.SOFH

 EQUB %11000000         \ Mask for a latch byte for channel 2
 EQUB %10100000         \ Mask for a latch byte for channel 1
 EQUB %10000000         \ Mask for a latch byte for channel 0

\ ******************************************************************************
\
\       Name: SOOFF
\       Type: Variable
\   Category: Sound
\    Summary: Sound chip data to turn the volume down on all channels and to act
\             as a mask for choosing a tone channel in the range 0-2
\
\ ******************************************************************************

.SOOFF

 EQUB %11111111         \            %1         %11               %1     %1111
                        \ Latch byte (1), channel 3, volume latch (1), data 15

 EQUB %10111111         \            %1         %01               %1     %1111
                        \ Latch byte (1), channel 1, volume latch (1), data 15

 EQUB %10011111         \            %1         %00               %1     %1111
                        \ Latch byte (1), channel 0, volume latch (1), data 15

 EQUB %11011111         \            %1         %10               %1     %1111
                        \ Latch byte (1), channel 2, volume latch (1), data 15

 EQUB %11101111         \            %1         %11             %0       %1111
                        \ Latch byte (1), channel 3,   tone latch (0), data 15

\ ******************************************************************************
\
\       Name: SOUS1
\       Type: Subroutine
\   Category: Sound
\    Summary: Write sound data directly to the 76489 sound chip
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The sound byte to send to the 76489 sound chip
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   SOUR1               Contains an RTS
\
\ ******************************************************************************

.SOUS1

 LDX #%11111111         \ Set 6522 System VIA data direction register DDRA
 STX VIA+&43            \ (SHEILA &43) to %11111111. This sets the ORA register
                        \ so that bits 0-7 of ORA will be sent to the 76489
                        \ sound chip

 STA VIA+&4F            \ Set 6522 System VIA output register ORA (SHEILA &4F)
                        \ to A, the sound data we want to send

 LDA #%00000000         \ Activate the sound chip by clearing bit 3 of the
 STA VIA+&40            \ 6522 System VIA output register ORB (SHEILA &40)

 PHA                    \ These instructions don't do anything apart from
 PLA                    \ keeping the sound chip activated for at least 8us,
 PHA                    \ which we need to do in order for the data to make
 PLA                    \ it to the chip

 LDA #%00001000         \ Deactivate the sound chip by setting bit 3 of the
 STA VIA+&40            \ 6522 System VIA output register ORB (SHEILA &40)

.SOUR1

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: SOFLUSH
\       Type: Subroutine
\   Category: Sound
\    Summary: Reset the sound buffers and turn off all sound channels
\
\ ******************************************************************************

.SOFLUSH

 LDY #3                 \ We need to zero the first 3 bytes of the sound buffer
                        \ at SOFLG, so set a counter in Y

 LDA #0                 \ Set A to 0 so we can zero the sound buffer

.SOUL2

 STA SOFLG-1,Y          \ Zero the Y-1th byte of SOFLG

 DEY                    \ Decrement the loop counter

 BNE SOUL2              \ Loop back to zero the next byte until we have done all
                        \ three from SOFLG+2 down to SOFLG

 SEI                    \ Disable interrupts while we update the sound chip

                        \ At this point Y = 0, which we can now use as a loop
                        \ counter to loop through the 5 bytes in SOOFF and send
                        \ them directly to the 76489 sound chip to set the
                        \ volume levels on all 4 sound channels to 15 (silent)
                        \ and the noise register on channel 3 to %111

.SOUL1

 LDA SOOFF,Y            \ Fetch the Y-th byte of SOOFF

 JSR SOUS1              \ Write the value in A directly to the 76489 sound chip

 INY                    \ Increment the loop counter

 CPY #5                 \ Loop back until we have sent all 5 bytes to the sound
 BNE SOUL1              \ chip

 CLI                    \ Enable interrupts again

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: ELASNO
\       Type: Subroutine
\   Category: Sound
\    Summary: Make the sound of us being hit
\
\ ******************************************************************************

.ELASNO

 LDY #9                 \ Call the NOISE routine with Y = 9 to make the first
 JSR NOISE              \ sound of us being hit

 LDY #5                 \ Call the NOISE routine with Y = 5 to make the second
 BRA NOISE              \ sound of us being hit, returning from the subroutine
                        \ using a tail call

\ ******************************************************************************
\
\       Name: LASNO
\       Type: Subroutine
\   Category: Sound
\    Summary: Make the sound of our laser firing
\
\ ******************************************************************************

.LASNO

 LDY #3                 \ Call the NOISE routine with Y = 3 to make the first
 JSR NOISE              \ sound of us firing our lasers

 LDY #5                 \ Set Y = 5 and fall through into the NOISE routine to
                        \ make the second sound of us firing our lasers

\ ******************************************************************************
\
\       Name: NOISE
\       Type: Subroutine
\   Category: Sound
\    Summary: Make the sound whose number is in Y by populating the sound buffer
\
\ ------------------------------------------------------------------------------
\
\ The following sounds can be made by this routine. Two-part noises are made by
\ consecutive calls to this routine with different values of Y. The routine
\ doesn't make any sounds itself; instead, it populates the sound buffer at
\ SOFLG with the relevant sound data, and the interrupt handler at IRQ1 calls
\ the SOINT routine to process the data in the sound buffer and send it to the
\ 76489 sound chip.
\
\ This routine can make the following sounds depending on the value of Y:
\
\   0       Long, low beep
\   1       Short, high beep
\   3, 5    Lasers fired by us
\   4       We died / Collision / Our depleted shields being hit by lasers
\   6       We made a hit or kill / Energy bomb / Other ship exploding
\   7       E.C.M. on
\   8       Missile launched / Ship launched from station
\   9, 5    We're being hit by lasers
\   10, 11  Hyperspace drive engaged
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   Y                   The number of the sound to be made from the above table
\
\ ******************************************************************************

.NOISE

                        \ This routine appears to set up the contents of the
                        \ SOFLG sound buffer, so the SOINT routine can then send
                        \ the results to the 76489 sound chip. How this all
                        \ works is a bit of a mystery, so this part needs more
                        \ investigation

 LDA DNOIZ              \ If DNOIZ is non-zero, then sound is disabled, so
 BNE SOUR1              \ return from the subroutine (as SOUR1 contains an RTS)

 LDA SFXBT,Y            \ Fetch SFXBT+Y and shift bit 0 into the C flag
 LSR A

 CLV                    \ Clear the V flag

 LDX #0                 \ If bit 0 of SFXBT+Y is set, set X = 0 and jump to
 BCS SOUS4              \ SOUS4

 INX                    \ Increment X to 1

 LDA SOPR+1             \ If SOPR+1 < SOPR+2, set X = 1 and jump to SOUS4
 CMP SOPR+2
 BCC SOUS4

 INX                    \ SOPR+1 >= SOPR+2, so increment X to 2

\JSR SOUS4              \ These instructions are commented out in the original
\                       \ source
\BCC SOUR1
\
\DEX
\
\BIT SOUR1
\
\LDA SFXPR,Y
\AND #&10
\BEQ SOUS9
\
\RTS
\
\fall into SOUS4 since
\this facility not
\needed

.SOUS4

                        \ By the time we get here, X is set as follows:
                        \
                        \   * X = 0 if bit 0 of SFXBT+Y is set
                        \   * X = 1 if SOPR+1 < SOPR+2
                        \   * X = 2 if SOPR+1 >= SOPR+2

 LDA SFXPR,Y            \ Set A = SFXPR+Y

.SOUS9

 CMP SOPR,X             \ If SFXPR+Y < SOPR+X, return from the subroutine
 BCC SOUR1              \ (as SOUR1 contains an RTS)

 SEI                    \ Disable interrupts while we update the sound buffer

                        \ If we get here then SFXPR+Y >= SOPR+X

 STA SOPR,X             \ SOPR+X = A = SFXPR+Y

 LSR A                  \ Store bits 1-3 of SFXPR+Y in bits 0-2 of SOVOL+X
 AND #%00000111
 STA SOVOL,X

 LDA SFXVC,Y            \ Store SFXVC+Y in SOVCH+X
 STA SOVCH,X

 LDA SFXBT,Y            \ Store SFXBT+Y in SOCNT+X
 STA SOCNT,X

 AND #%00001111         \ Store bits 1-3 of SFXBT+Y in bits 0-2 of SOFRCH+X
 LSR A
 STA SOFRCH,X

 LDA SFXFQ,Y            \ Set A = SFXFQ+Y

 BVC P%+3               \ If the V flag is set, double the value in A
 ASL A

 STA SOFRQ,X            \ Store A in SOFRQ+X

 LDA #%10000000         \ Set bit 7 of SOFLG+X
 STA SOFLG,X

 CLI                    \ Enable interrupts again

 SEC                    \ Set the C flag

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: SOINT
\       Type: Subroutine
\   Category: Sound
\    Summary: Process the contents of the sound buffer and send it to the sound
\             chip
\
\ ******************************************************************************

.SOINT

                        \ This routine is called from the IRQ1 interrupt handler
                        \ and appears to process the contents of the SOFLG sound
                        \ buffer, sending the results to the 76489 sound chip.
                        \ What it's actually doing, though, is a bit of a
                        \ mystery, so this part needs more investigation

 LDY #2                 \ We want to loop through the three tone channels, so
                        \ set a counter in Y to iterate through the channels

.SOUL8

 LDA SOFLG,Y            \ If the Y-th byte of SOFLG is zero, there is no data
 BEQ SOUL3              \ buffered for this channel, so jump to SOUL3 to move
                        \ onto the next one

 BMI SOUL4              \ If bit 7 of the Y-th byte of SOFLG is set, jump to
                        \ SOUL4

 LDA SOFRCH,Y           \ If SOFRCH+Y = 0, jump to SOUL5
 BEQ SOUL5

 EQUB &2C               \ Skip the next instruction by turning it into
                        \ &2C &A9 &00, or BIT &00A9, which does nothing apart
                        \ from affect the flags

.SOUL4

 LDA #0                 \ Set A = 0

 CLC                    \ Clear the C flag for the additions below

 CLD                    \ Clear the D flag to ensure we are in binary mode

 ADC SOFRQ,Y            \ Set SOFRQ+Y = SOFRQ+Y + A
 STA SOFRQ,Y

 PHA                    \ Store A on the stack

 ASL A                  \ Set A = (A * 4) mod 16
 ASL A
 AND #%00001111

 ORA SOFH,Y             \ Set the channel to 0, 1, 2 for Y = 2, 1, 0

 JSR SOUS1              \ Write the value in A directly to the 76489 sound chip

 PLA                    \ Retrieve A from the stack

 LSR A                  \ Set A = A / 4
 LSR A

 JSR SOUS1              \ Write the value in A directly to the 76489 sound chip

.SOUL5

 TYA                    \ Copy Y into X
 TAX

 LDA SOFLG,Y            \ If bit 7 of the Y-th byte of SOFLG is set, jump to
 BMI SOUL6              \ SOUL6

 DEC SOCNT,X            \ Decrement SOCNT+X

 BEQ SOKILL             \ If the value is zero, skip to SOKILL

 LDA SOCNT,X            \ If SOCNT+X AND SOVCH+X is non-zero, skip to SOUL3
 AND SOVCH,X
 BNE SOUL3

 DEC SOVOL,X            \ Decrement SOVOL+X

 BNE SOU1               \ If the value is non-zero, skip to SOU1

.SOKILL

 LDA #0                 \ Set SOFLG+Y = 0
 STA SOFLG,Y

 STA SOPR,Y             \ Set SOPR+Y = 0

 BEQ SOU3               \ Jump to SOU3 (this BEQ is effectively a JMP as A is
                        \ always zero)

.SOUL6

 LSR SOFLG,X            \ Halve the value in SOFLG+X

.SOU1

 LDA SOVOL,Y            \ Set A = SOVOL+Y + VOL
 CLC                    \
 ADC VOL                \ where VOL is the current volume setting (0-7)

.SOU3

 EOR SOOFF,Y            \ EOR A with the Y-th byte of SOOFF

 JSR SOUS1              \ Write the value in A directly to the 76489 sound chip

.SOUL3

 DEY                    \ Decrement the loop counter

 BPL SOUL8              \ Loop back to SOUL8 until we have done all three
                        \ channels

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: Sound variables
\       Type: Workspace
\    Address: &144D to &1491
\   Category: Sound
\    Summary: The sound buffer where the data to be sent to the sound chip is
\             processed
\
\ ******************************************************************************

.SOFLG

 EQUB 0                 \ Sound buffer for sound effect flags
 EQUB 0                 \
 EQUB 0                 \ SOFLG,Y contains the following:
                        \
                        \   * Bits 0-5: sound effect number + 1 of the sound
                        \               currently being made on voice Y
                        \
                        \   * Bit 7 is set if this is a new sound being made,
                        \     rather than one that is in progress

.SOCNT

 EQUB 0                 \ Sound buffer for sound effect counters
 EQUB 0                 \
 EQUB 0                 \ SOCNT,Y contains the counter of the sound currently
                        \ being made on voice Y
                        \
                        \ The counter decrements each frame, and when it reaches
                        \ zero, the sound effect has finished
                        \
                        \ These values come from the SFXCNT table

.SOVOL

 EQUB 0                 \ Sound buffer for volume levels
 EQUB 0                 \
 EQUB 0                 \ SOVOL,Y contains the volume of the sound currently
                        \ being made on voice Y
                        \
                        \ These values come from bits 1-3 of the SFXPR table

.SOVCH

 EQUB 0                 \ Sound buffer for the volume change rate
 EQUB 0                 \
 EQUB 0                 \ SOVCH,Y contains the volume change rate of the sound
                        \ currently being made on voice Y
                        \
                        \ The sound's volume gets reduced by one every SOVCH,Y
                        \ frames
                        \
                        \ These values come from the SFXVCH table

.SOPR

 EQUB 0                 \ Sound buffer for sound effect priorities
 EQUB 0                 \
 EQUB 0                 \ SOPR,Y contains the priority of the sound currently
                        \ being made on voice Y
                        \
                        \ These values come from the SFXPR table

.SOFRCH

 EQUB 0                 \ Sound buffer for frequency change values
 EQUB 0                 \
 EQUB 0                 \ SOFRCH,Y contains the frequency change to be applied
                        \ to the sound currently being made on voice Y in each
                        \ frame
                        \
                        \ These values come from the SFXFRCH table

.SOFRQ

 EQUB 0                 \ Sound buffer for sound effect frequencies
 EQUB 0                 \
 EQUB 0                 \ SOFRQ,Y contains the frequency of the sound currently
                        \ being made on voice Y
                        \
                        \ These values come from the SFXFQ table, and have the
                        \ frequency change from the SFXFRCH table applied in
                        \ each frame

\ ******************************************************************************
\
\       Name: SFXPR
\       Type: Variable
\   Category: Sound
\    Summary: Sound data block 1
\
\ ******************************************************************************

.SFXPR

 EQUB &4B, &5B, &3F
 EQUB &EB, &FF, &09
 EQUB &FF, &8B, &CF
 EQUB &E7, &FF, &EF

\ ******************************************************************************
\
\       Name: SFXBT
\       Type: Variable
\   Category: Sound
\    Summary: Sound data block 2
\
\ ******************************************************************************

.SFXBT

 EQUB &40, &10, &01
 EQUB &FC, &F3, &19
 EQUB &F9, &7C, &F1
 EQUB &FA, &FE, &FE

\ ******************************************************************************
\
\       Name: SFXFQ
\       Type: Variable
\   Category: Sound
\    Summary: Sound data block 3
\
\ ******************************************************************************

.SFXFQ

 EQUB &F0, &20, &10
 EQUB &30, &03, &01
 EQUB &08, &80, &16
 EQUB &38, &00, &80

\ ******************************************************************************
\
\       Name: SFXVC
\       Type: Variable
\   Category: Sound
\    Summary: Sound data block 4
\
\ ******************************************************************************

.SFXVC

 EQUB &FF, &FF, &00
 EQUB &03, &1F, &01
 EQUB &07, &07, &0F
 EQUB &03, &0F, &0F

\ ******************************************************************************
\
\       Name: IRQ1
\       Type: Subroutine
\   Category: Drawing the screen
\    Summary: The main screen-mode interrupt handler (IRQ1V points here)
\  Deep dive: The split-screen mode in BBC Micro Elite
\
\ ------------------------------------------------------------------------------
\
\ The main interrupt handler, which implements Elite's split-screen mode.
\
\ IRQ1V is set to point to IRQ1 by the loading process.
\
\ ******************************************************************************

.IRQ1

 PHY                    \ Store Y on the stack

 LDA #%00000010         \ Read the 6522 System VIA status byte bit 1 (SHEILA
 BIT VIA+&4D            \ &4D), which is set if vertical sync has occurred on
                        \ the video system

 BNE LINSCN             \ If we are on the vertical sync pulse, jump to LINSCN

                        \ Port: this is timer 1 (the space view / dashboard
                        \ boundary). The whole screen is now one MODE 1 screen
                        \ in one CMYK palette, set once by the loader, so there
                        \ is no switch to mode 2 and no dashboard palette (nor
                        \ the escape pod's tint of it) here any more. The space
                        \ view is double buffered (main or shadow RAM, shown at
                        \ vsync by H_VSYNC), and the dashboard is in shadow RAM:
                        \ show shadow RAM from here to the end of the frame
                        \ (ACCCON D = 1, X as it is)

 LDA #1
 TSB VIA+&34

IF _COMPACT

 LDA MOS                \ If MOS = 0 then this is a Master Compact, so jump to
 BEQ jvec               \ jvec to skip reading the ADC channels (as the Compact
                        \ doesn't have them)

ENDIF

 LDA VIA+&18            \ Fetch the ADC channel number into Y from bits 0-1 of
\BMI JONO               \ the ADC status byte at SHEILA &18
 AND #%00000011         \
 TAY                    \ The BMI is commented out in the original source

 LDA VIA+&19            \ Fetch the high byte of the value on this ADC channel
                        \ (bits 8-15 of the 12-bit value)

 STA JOPOS,Y            \ Store this value in the appropriate JOPOS byte

 INY                    \ Increment the channel number

 TYA                    \ If the new channel number in A < 3, skip the next two
 CMP #3                 \ instructions
 BCC P%+4

 LDA #0                 \ Set the ADC status byte at SHEILA &18 to 0 to reset
 STA VIA+&18            \ the data latch, ready for the next channel

.jvec

 PLY                    \ Restore Y from the stack

 LDA VIA+&44            \ Read 6522 System VIA T1C-L timer 1 low-order counter
                        \ (SHEILA &44), which clears the timer 1 interrupt flag

 LDA &FC                \ Restore the value of A from before the call to the
                        \ interrupt handler (as the MOS stores it in &FC)

 RTI                    \ Return from interrupts, so this interrupt is not
                        \ passed on to the next interrupt handler

.LINSCN

 LDA VIA+&41            \ Read 6522 System VIA input register IRA (SHEILA &41),
                        \ which clears the vertical sync interrupt

 LDA &FC                \ Fetch the value of A from before the call to the
                        \ interrupt handler (as the MOS stores it in &FC)

 PHA                    \ Store the original value of A on the stack

 LDA VSCAN+1            \ Set the line scan counter to the value of VSCAN+1
 STA DL                 \ (which contains 30 by default and doesn't change), so
                        \ routines like WSCAN can set DL to 0 and then wait for
                        \ it to change to non-zero to catch the vertical sync

 STA VIA+&44            \ Set 6522 System VIA T1C-L timer 1 low-order counter
                        \ (SHEILA &44) to 30

 LDA VSCAN              \ Set 6522 System VIA T1C-L timer 1 high-order counter
 STA VIA+&45            \ (SHEILA &45) to the contents of VSCAN (57) to start
                        \ the T1 counter counting down from 14622 at a rate of
                        \ 1 MHz (as before; Port: no mode or palette change
                        \ follows, so HFX, the hyperspace effect's mode 2
                        \ colours, no longer has any effect here)

 JSR H_VSYNC            \ Port: the renderer's flip: show the front buffer
                        \ (ACCCON D; gfx-hooks.asm)

 PHX                    \ Call SOINT to send the current sound data to the
 JSR SOINT              \ 76489 sound chip, stashing X on the stack so it gets
 PLX                    \ preserved across the call

 PLA                    \ Restore A from the stack

 PLY                    \ Restore Y from the stack

 RTI                    \ Return from interrupts, so this interrupt is not
                        \ passed on to the next interrupt handler

\ ******************************************************************************
\
\       Name: VSCAN
\       Type: Variable
\   Category: Drawing the screen
\    Summary: Defines the split position in the split-screen mode
\
\ ******************************************************************************

.VSCAN

 EQUB 57                \ Defines the split position in the split-screen mode

 EQUB 30                \ The line scan counter in DL gets reset to this value
                        \ at each vertical sync, before decrementing with each
                        \ line scan
\ ******************************************************************************
\
\       Name: DOVDU19
\       Type: Subroutine
\   Category: Drawing the screen
\    Summary: Change the mode 1 palette
\
\ ------------------------------------------------------------------------------
\
\ This routine updates the VNT3+1 location in the IRQ1 handler to change the
\ palette that's applied to the top part of the screen (the four-colour mode 1
\ part). The parameter is the offset within the TVT3 palette block of the
\ desired palette.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The offset within the TVT3 table of palettes:
\
\                         * 0 = Yellow, red, cyan palette (space view)
\
\                         * 16 = Yellow, red, white palette (charts)
\
\                         * 32 = Yellow, white, cyan palette (title screen)
\
\                         * 48 = Yellow, magenta, white palette (trading)
\
\ ******************************************************************************

.VNT3

 EQUB 0, 0              \ Port: the palette offset DOVDU19 stores (VNT3+1),
                        \ which nothing reads any more

.DOVDU19

 STA VNT3+1             \ Store the new colour in VNT3+1 (Port: the palette is
                        \ fixed now, so this is kept only as a variable),
                        \ which modifies which TVT3 palette block gets applied
                        \ to the mode 1 part of the screen

 RTS                    \ Return from the subroutine

 INCLUDE "src/elite-far.asm"   \ Port: far calls to and from the cold area

\ ******************************************************************************
\
\       Name: SHIFT
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Scan the keyboard to see if SHIFT is currently pressed
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   X                   X = %10000000 if SHIFT is being pressed
\
\                       X = 0 if SHIFT is not being pressed
\
\   A                   Contains the same as X
\
\ ******************************************************************************

IF _COMPACT

.SHIFT

 LDA #0                 \ Set A to the internal key number for SHIFT and fall
                        \ through to DKS4mc to scan the keyboard

 EQUB &2C               \ Skip the next instruction by turning it into
                        \ &2C &A9 &49, or BIT &49A9, which does nothing apart
                        \ from affect the flags

ENDIF

\ ******************************************************************************
\
\       Name: RETURN
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Scan the keyboard to see if RETURN is currently pressed
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   X                   X = %11001001 if RETURN is being pressed
\
\                       X = %01001001 if RETURN is not being pressed
\
\   A                   Contains the same as X
\
\ ******************************************************************************

IF _COMPACT

.RETURN

 LDA #&49               \ Set A to the internal key number for RETURN and fall
                        \ through to DKS4mc to scan the keyboard

 EQUB &2C               \ Skip the next instruction by turning it into
                        \ &2C &A9 &01, or BIT &01A9, which does nothing apart
                        \ from affect the flags

ENDIF

\ ******************************************************************************
\
\       Name: CTRLmc
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Scan the Master Compact keyboard to see if CTRL is currently
\             pressed
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   X                   X = %10000001 (i.e. 129 or -127) if CTRL is being
\                       pressed
\
\                       X = 1 if CTRL is not being pressed
\
\   A                   Contains the same as X
\
\ ******************************************************************************

IF _COMPACT

.CTRLmc

 LDA #1                 \ Set A to the internal key number for CTRL and fall
                        \ through to DKS4mc to scan the keyboard

ENDIF

\ ******************************************************************************
\
\       Name: DKS4mc
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Scan the Master Compact keyboard to see if a specific key is being
\             pressed
\  Deep dive: The key logger
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The internal number of the key to check (see page 142 of
\                       the "Advanced User Guide for the BBC Micro" by Bray,
\                       Dickens and Holmes for a list of internal key numbers)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   If the key in A is being pressed, A contains the
\                       original argument A, but with bit 7 set (i.e. A + 128).
\                       If the key in A is not being pressed, the value in A is
\                       unchanged
\
\   X                   Contains the same as A
\
\ ******************************************************************************

IF _COMPACT

.DKS4mc

 LDX #3                 \ Set X to 3, so it's ready to send to SHEILA once
                        \ interrupts have been disabled

 SEI                    \ Disable interrupts so we can scan the keyboard
                        \ without being hijacked

 STX VIA+&40            \ Set 6522 System VIA output register ORB (SHEILA &40)
                        \ to %00000011 to stop auto scan of keyboard

 LDX #%01111111         \ Set 6522 System VIA data direction register DDRA
 STX VIA+&43            \ (SHEILA &43) to %01111111. This sets the A registers
                        \ (IRA and ORA) so that:
                        \
                        \   * Bits 0-6 of ORA will be sent to the keyboard
                        \
                        \   * Bit 7 of IRA will be read from the keyboard

 STA VIA+&4F            \ Set 6522 System VIA output register ORA (SHEILA &4F)
                        \ to A, the key we want to scan for; bits 0-6 will be
                        \ sent to the keyboard, of which bits 0-3 determine the
                        \ keyboard column, and bits 4-6 the keyboard row

 LDX VIA+&4F            \ Read 6522 System VIA output register IRA (SHEILA &4F)
                        \ into X; bit 7 is the only bit that will have changed.
                        \ If the key is pressed, then bit 7 will be set,
                        \ otherwise it will be clear

 LDA #%00001011         \ Set 6522 System VIA output register ORB (SHEILA &40)
 STA VIA+&40            \ to %00001011 to restart auto scan of keyboard

 CLI                    \ Allow interrupts again

 TXA                    \ Transfer X into A

ENDIF

\ ******************************************************************************
\
\       Name: cls
\       Type: Subroutine
\   Category: Drawing the screen
\    Summary: Clear the top part of the screen and draw a border box
\
\ ******************************************************************************

.cls

 JSR TTX66M             \ Call TTX66 to clear the top part of the screen and
                        \ draw a border box

 JMP RR4                \ Jump to RR4 to restore X and Y from the stack and A
                        \ from K3, and return from the subroutine using a tail
                        \ call

\ ******************************************************************************
\
\       Name: TT67K
\       Type: Subroutine
\   Category: Text
\    Summary: Print a newline
\
\ ******************************************************************************

.TT67K

                        \ This does the same as the existing TT67 routine, which
                        \ is also present in this source, so it isn't clear why
                        \ this duplicate exists
                        \
                        \ In the original source this label is TT67, but
                        \ because BeebAsm doesn't allow us to redefine labels,
                        \ I have renamed it to TT67K

 LDA #12                \ Set A to a carriage return character

                        \ Fall through into TT26 to print the newline

\ ******************************************************************************
\
\       Name: CHPR
\       Type: Subroutine
\   Category: Text
\    Summary: Print a character at the text cursor by poking into screen memory
\  Deep dive: Drawing text
\
\ ------------------------------------------------------------------------------
\
\ Print a character at the text cursor (XC, YC), do a beep, print a newline,
\ or delete left (backspace).
\
\ Calls to OSWRCH will end up here when A is not in the range 128-147, as those
\ are reserved for the special jump table OSWRCH commands.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The character to be printed. Can be one of the
\                       following:
\
\                         * 7 (beep)
\
\                         * 10 (line feed)
\
\                         * 11 (clear the top part of the screen and draw a
\                           border)
\
\                         * 12-13 (carriage return)
\
\                         * 32-95 (ASCII capital letters, numbers and
\                           punctuation)
\
\                         * 127 (delete the character to the left of the text
\                           cursor and move the cursor to the left)
\
\   XC                  Contains the text column to print at (the x-coordinate)
\
\   YC                  Contains the line number to print on (the y-coordinate)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   A is preserved
\
\   X                   X is preserved
\
\   Y                   Y is preserved
\
\   C flag              The C flag is cleared
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   RR4                 Restore the registers and return from the subroutine
\
\ ******************************************************************************

.CHPR

 STA K3                 \ Store the A, X and Y registers, so we can restore
 PHY                    \ them at the end (so they don't get changed by this
 PHX                    \ routine)

 LDY QQ17               \ Load the QQ17 flag, which contains the text printing
                        \ flags

 CPY #255               \ If QQ17 = 255 then printing is disabled, so jump to
 BEQ RR4S               \ RR4 (via the JMP in RR4S) to restore the registers
                        \ and return from the subroutine using a tail call

IF _COMPACT

 TAY                    \ Copy the character to be printed from A into Y

 BEQ RR4S               \ If the character to be printed is 0 or >= 128, jump to
 BMI RR4S               \ RR4S (via the JMP in RR4S) to restore the registers
                        \ and return from the subroutine using a tail call

.RRNEW

ENDIF

 TAY                    \ Set Y = the character to be printed

 LDA #4                 \ Set bit 2 (X) of the Access Control Register at
 TSB VIA+&34            \ SHEILA &34 to switch screen memory into &3000-&7FFF
                        \ (Port: keeping D, which buffer the IRQ shows)

 TYA                    \ (A and the flags from the character, as the TAY left
                        \ them)

IF _SNG47

 BEQ RR4S               \ If the character is zero, which is typically a string
                        \ terminator character, jump down to RR4 (via the JMP in
                        \ RR4S) to restore the registers and return from the
                        \ subroutine using a tail call

 BMI RR4S               \ If A > 127 then there is nothing to print, so jump to
                        \ RR4 (via the JMP in RR4S) to restore the registers and
                        \ return from the subroutine

ELIF _COMPACT

 LDX CATF               \ If CATF <> 0, skip the following two instructions, as
 BNE P%+6               \ we are printing a disc catalogue and we don't want any
                        \ control characters lurking in the catalogue to trigger
                        \ the screen clearing routine

ENDIF

 CMP #11                \ If this is control code 11 (clear screen), jump to cls
 BEQ cls                \ to clear the top part of the screen, draw a white
                        \ border and return from the subroutine via RR4

 CMP #7                 \ If this is not control code 7 (beep), skip the next
 BNE P%+5               \ instruction

 JMP R5                 \ This is control code 7 (beep), so jump to R5 to make
                        \ a beep and return from the subroutine via RR4

 CMP #32                \ If this is an ASCII character (A >= 32), jump to RR1
 BCS RR1                \ below, which will print the character, restore the
                        \ registers and return from the subroutine

 CMP #10                \ If this is control code 10 (line feed) then jump to
 BEQ RRX1               \ RRX1, which will move down a line, restore the
                        \ registers and return from the subroutine

 LDX #1                 \ If we get here, then this is control code 12 or 13,
 STX XC                 \ both of which are used. This code prints a newline,
                        \ which we can achieve by moving the text cursor
                        \ to the start of the line (carriage return) and down
                        \ one line (line feed). These two lines do the first
                        \ bit by setting XC = 1, and we then fall through into
                        \ the line feed routine that's used by control code 10

.RRX1

 CMP #13                \ If this is control code 13 (carriage return) then jump
 BEQ RR4S               \ to RR4 (via the JMP in RR4S) to restore the registers
                        \ and return from the subroutine using a tail call

 INC YC                 \ Increment the text cursor y-coordinate to move it
                        \ down one row

.RR4S

 JMP RR4                \ Jump to RR4 to restore the registers and return from
                        \ the subroutine using a tail call

.RR1

                        \ If we get here, then the character to print is an
                        \ ASCII character in the range 32-95. The quickest way
                        \ to display text on-screen is to poke the character
                        \ pixel by pixel, directly into screen memory, so
                        \ that's what the rest of this routine does
                        \
                        \ The first step, then, is to get hold of the bitmap
                        \ definition for the character we want to draw on the
                        \ screen (i.e. we need the pixel shape of this
                        \ character). The MOS ROM contains bitmap definitions
                        \ of the system's ASCII characters, starting from &C000
                        \ for space (ASCII 32) and ending with the £ symbol
                        \ (ASCII 126)
                        \
                        \ There are definitions for 32 characters in each of the
                        \ three pages of MOS memory, as each definition takes up
                        \ 8 bytes (8 rows of 8 pixels) and 32 * 8 = 256 bytes =
                        \ 1 page. So:
                        \
                        \   ASCII 32-63  are defined in &C000-&C0FF (page 0)
                        \   ASCII 64-95  are defined in &C100-&C1FF (page 1)
                        \   ASCII 96-126 are defined in &C200-&C2F0 (page 2)
                        \
                        \ The following code reads the relevant character
                        \ those values into the correct position in screen
                        \ memory, thus printing the character on-screen
                        \
                        \ It's a long way from 10 PRINT "Hello world!":GOTO 10

                        \ Now we want to set X to point to the relevant page

                        \ The following logic is easier to follow if we look
                        \ at the three character number ranges in binary:
                        \
                        \   Bit #  76543210
                        \
                        \   32  = %00100000     Page 0 of bitmap definitions
                        \   63  = %00111111
                        \
                        \   64  = %01000000     Page 1 of bitmap definitions
                        \   95  = %01011111
                        \
                        \   96  = %01100000     Page 2 of bitmap definitions
                        \   125 = %01111101
                        \
                        \ We'll refer to this below

 LDX #(FONT%-1)         \ Set X to point to the page before the first font page,
                        \ which is FONT% - 1

 ASL A                  \ If bit 6 of the character is clear (A is 32-63)
 ASL A                  \ then skip the following instruction
 BCC P%+4

 LDX #(FONT%+1)         \ A is 64-126, so set X to point to page FONT% + 1

 ASL A                  \ If bit 5 of the character is clear (A is 64-95)
 BCC P%+3               \ then skip the following instruction

 INX                    \ Increment X
                        \
                        \ In other words, X points to the relevant page. But
                        \ what about the value of A? That gets shifted to the
                        \ left three times during the above code, which
                        \ multiplies the number by 8 but also drops bits 7, 6
                        \ and 5 in the process. Look at the above binary
                        \ figures and you can see that if we cleared bits 5-7,
                        \ then that would change 32-53 to 0-31... but it would
                        \ do exactly the same to 64-95 and 96-125. And because
                        \ we also multiply this figure by 8, A now points to
                        \ the start of the character's definition within its
                        \ page (because there are 8 bytes per character
                        \ definition)
                        \
                        \ Or, to put it another way, X contains the high byte
                        \ (the page) of the address of the definition that we
                        \ want, while A contains the low byte (the offset into
                        \ the page) of the address

 STA P                  \ Store the address of this character's definition in
 STX P+1                \ P(1 0)

 LDA XC                 \ Fetch XC, the x-coordinate (column) of the text cursor
                        \ into A

 LDX CATF               \ If CATF = 0, jump to RR5, otherwise we are printing a
 BEQ RR5                \ disc catalogue

IF _SNG47

 CPY #' '               \ If the character we want to print in Y is not a space,
 BNE RR5                \ jump to RR5

                        \ If we get here, then CATF is non-zero, so we are
                        \ printing a disc catalogue and we are not printing a
                        \ space, so we drop column 17 from the output so the
                        \ catalogue will fit on-screen (column 17 is a blank
                        \ column in the middle of the catalogue, between the
                        \ two lists of filenames, so it can be dropped without
                        \ affecting the layout). Without this, the catalogue
                        \ would be one character too wide for the square screen
                        \ mode (it's 34 characters wide, while the screen mode
                        \ is only 33 characters across)

 CMP #17                \ If A = 17, i.e. the text cursor is in column 17, jump
 BEQ RR4                \ to RR4 to restore the registers and return from the
                        \ subroutine, thus omitting this column

ELIF _COMPACT

 CMP #21                \ If A < 21, i.e. the text cursor is in column 0-20,
 BCC RR5                \ jump to RR5 to skip the following

                        \ If we get here, then CATF is non-zero, so we are
                        \ printing a disc catalogue and we have reached column
                        \ 21, so we move to the start of the next line so the
                        \ catalogue line-wraps to fit within the bounds of the
                        \ screen

 INC YC                 \ More the text cursor down a line

 LDA #1                 \ Move the text cursor to column 1
 STA XC

ENDIF

.RR5

 ASL A                  \ Multiply A by 8, and store in SC, so we now have:
 ASL A                  \
 ASL A                  \   SC = XC * 8
 STA SC

 LDA YC                 \ Fetch YC, the y-coordinate (row) of the text cursor

 CPY #127               \ If the character number (which is in Y) <> 127, then
 BNE RR2                \ skip to RR2 to print that character, otherwise this is
                        \ the delete character, so continue on

 DEC XC                 \ We want to delete the character to the left of the
                        \ text cursor and move the cursor back one, so let's
                        \ do that by decrementing YC. Note that this doesn't
                        \ have anything to do with the actual deletion below,
                        \ we're just updating the cursor so it's in the right
                        \ position following the deletion

 JSR H_DEL              \ Port: keep the renderer's text map, and in record mode
                        \ return through RR4 instead of blanking (gfx-hooks.asm)

 ASL A                  \ A contains YC (from above), so this sets A = YC * 2

 ASL SC                 \ Double the low byte of SC(1 0), catching bit 7 in the
                        \ C flag. As each character is 8 pixels wide, and the
                        \ special screen mode Elite uses for the top part of the
                        \ screen is 256 pixels across with two bits per pixel,
                        \ this value is not only double the screen address
                        \ offset of the text cursor from the left side of the
                        \ screen, it's also the least significant byte of the
                        \ screen address where we want to print this character,
                        \ as each row of on-screen pixels corresponds to two
                        \ pages. To put this more explicitly, the screen starts
                        \ at &4000, so the text rows are stored in screen
                        \ memory like this:
                        \
                        \   Row 1: &4000 - &41FF    YC = 1, XC = 0 to 31
                        \   Row 2: &4200 - &43FF    YC = 2, XC = 0 to 31
                        \   Row 3: &4400 - &45FF    YC = 3, XC = 0 to 31
                        \
                        \ and so on

 ADC #&3F               \ Set X = A
 TAX                    \       = A + &3F + C
                        \       = YC * 2 + &3F + C

                        \ Because YC starts at 0 for the first text row, this
                        \ means that X will be &3F for row 0, &41 for row 1 and
                        \ so on. In other words, X is now set to the page number
                        \ for the row before the one containing the text cursor,
                        \ and given that we set SC above to point to the offset
                        \ in memory of the text cursor within the row's page,
                        \ this means that (X SC) now points to the character
                        \ above the text cursor

 LDY #&F0               \ Set Y = &F0, so the following call to ZES2 will count
                        \ Y upwards from &F0 to &FF

 JSR ZES2               \ Call ZES2, which zero-fills from address (X SC) + Y to
                        \ (X SC) + &FF. (X SC) points to the character above the
                        \ text cursor, and adding &FF to this would point to the
                        \ cursor, so adding &F0 points to the character before
                        \ the cursor, which is the one we want to delete. So
                        \ this call zero-fills the character to the left of the
                        \ cursor, which erases it from the screen

 BEQ RR4                \ We are done deleting, so restore the registers and
                        \ return from the subroutine (this BNE is effectively
                        \ a JMP as ZES2 always returns with the Z flag set)

.RR2

                        \ Now to actually print the character

 INC XC                 \ Once we print the character, we want to move the text
                        \ cursor to the right, so we do this by incrementing
                        \ XC. Note that this doesn't have anything to do
                        \ with the actual printing below, we're just updating
                        \ the cursor so it's in the right position following
                        \ the print

 CMP #24                \ If the text cursor is on the screen (i.e. YC < 24, so
 BCC RR3                \ we are on rows 0-23), then jump to RR3 to print the
                        \ character

IF _SNG47

 JSR TTX66M             \ Otherwise we are off the bottom of the screen, so
                        \ clear the screen and draw a border box

 LDA #4                 \ Set bit 2 (X) of the Access Control Register at
 TSB VIA+&34            \ SHEILA &34 to switch screen memory into &3000-&7FFF
                        \ (Port: keeping D)

ELIF _COMPACT

 LDA CATF               \ If CATF = 0, skip the next two instructions, as we are
 BEQ P%+7               \ not printing a disc catalogue

 JSR RETURN             \ We have just printed the disc catalogue, so wait until
 BPL P%-3               \ RETURN is pressed, looping indefinitely until it gets
                        \ tapped

 JSR TTX66M             \ Call TTX66 to clear the screen

ENDIF

 LDA #1                 \ Move the text cursor to column 1, row 1
 STA XC
 STA YC

 LDA K3                 \ Set A to the character to be printed, though again
                        \ this has no effect, as the following call to RR4 does
                        \ the exact same thing

IF _SNG47

 JMP RR4                \ And restore the registers and return from the
                        \ subroutine

ELIF _COMPACT

 JMP RRNEW              \ Jump back to RRNEW to print the character

ENDIF

.RR3

 JSR H_CHAR             \ Port: keep the renderer's text map, and in record mode
                        \ return through RR4 instead of drawing (gfx-hooks.asm)

                        \ A contains the value of YC - the screen row where we
                        \ want to print this character - so now we need to
                        \ convert this into a screen address, so we can poke
                        \ the character data to the right place in screen
                        \ memory

 ASL A                  \ Set A = 2 * A
                        \       = 2 * YC

 ASL SC                 \ Back in RR5 we set SC = XC * 8, so this does the
                        \ following:
                        \
                        \   SC = SC * 2
                        \      = XC * 16
                        \
                        \ so SC contains the low byte of the screen address we
                        \ want to poke the character into, as each text
                        \ character is 8 pixels wide, and there are four pixels
                        \ per byte, so the offset within the row's 512 bytes
                        \ is XC * 8 pixels * 2 bytes for each 8 pixels = XC * 16

 ADC #&40               \ Set A = &40 + A
                        \       = &40 + (2 * YC)
                        \
                        \ so A contains the high byte of the screen address we
                        \ want to poke the character into, as screen memory
                        \ starts at &4000 (page &40) and each screen row takes
                        \ up 2 pages (512 bytes)

.RREN

 STA SC+1               \ Store the page number of the destination screen
                        \ location in SC+1, so SC now points to the full screen
                        \ location where this character should go

 LDA SC                 \ Set P(3 2) = SC(1 0) + 8
 CLC                    \
 ADC #8                 \ starting with the low bytes
 STA P+2

 LDA SC+1               \ And then adding the high bytes, so P(3 2) points to
 STA P+3                \ the character block after the one pointed to by
                        \ SC(1 0)

 LDY #7                 \ We want to print the 8 bytes of character data to the
                        \ screen (one byte per row), so set up a counter in Y
                        \ to count these bytes

.RRL1

                        \ We print the character's eight-pixel row in two parts,
                        \ starting with the first four pixels (one byte of
                        \ screen memory), and then the second four (a second
                        \ byte of screen memory)

 LDA (P),Y              \ The character definition is at P(1 0) - we set this up
                        \ above - so load the Y-th byte from P(1 0), which will
                        \ contain the bitmap for the Y-th row of the character

 AND #%11110000         \ Extract the high nibble of the character definition
                        \ byte, so the first four pixels on this row of the
                        \ character are in the first nibble, i.e. xxxx 0000
                        \ where xxxx is the pattern of those four pixels in the
                        \ character

 STA W                  \ Set A = (A >> 4) OR A
 LSR A                  \
 LSR A                  \ which duplicates the high nibble into the low nibble
 LSR A                  \ to give xxxx xxxx
 LSR A
 ORA W

 AND COL                \ AND with the colour byte so that the pixels take on
                        \ the colour we want to draw (i.e. A is acting as a mask
                        \ on the colour byte)

 EOR (SC),Y             \ If we EOR this value with the existing screen
                        \ contents, then it's reversible (so reprinting the
                        \ same character in the same place will revert the
                        \ screen to what it looked like before we printed
                        \ anything); this means that printing a white pixel
                        \ onto a white background results in a black pixel, but
                        \ that's a small price to pay for easily erasable text

 STA (SC),Y             \ Store the Y-th byte at the screen address for this
                        \ character location

                        \ We now repeat the process for the second batch of four
                        \ pixels in this character row

 LDA (P),Y              \ Fetch the bitmap for the Y-th row of the character
                        \ again

 AND #%00001111         \ This time we extract the low nibble of the character
                        \ definition, to get 0000 xxxx

 STA W                  \ Set A = (A << 4) OR A
 ASL A                  \
 ASL A                  \ which duplicates the low nibble into the high nibble
 ASL A                  \ to give xxxx xxxx
 ASL A
 ORA W

 AND COL                \ AND with the colour byte so that the pixels take on
                        \ the colour we want to draw (i.e. A is acting as a mask
                        \ on the colour byte)

 EOR (P+2),Y            \ EOR this value with the existing screen contents of
                        \ P(3 2), which is equal to SC(1 0) + 8, the next four
                        \ pixels along from the first four pixels we just
                        \ plotted in SC(1 0)

 STA (P+2),Y            \ Store the Y-th byte at the screen address for this
                        \ character location

 DEY                    \ Decrement the loop counter

 BPL RRL1               \ Loop back for the next byte to print to the screen

.RR4

 LDA #4                 \ Clear bit 2 (X) of the Access Control Register at
 TRB VIA+&34            \ SHEILA &34 to switch main memory back into &3000-&7FFF
                        \ (Port: keeping D)

 PLX                    \ We're done printing, so restore the values of the
 PLY                    \ A, X and Y registers that we saved above and clear the
 LDA K3                 \ C flag, so everything is back to how it was
 CLC

 RTS                    \ Return from the subroutine

.R5

 JSR BEEP               \ Call the BEEP subroutine to make a short, high beep

 JMP RR4                \ Jump to RR4 to restore the registers and return from
                        \ the subroutine using a tail call

\ ******************************************************************************
\
\       Name: ZES1
\       Type: Subroutine
\   Category: Utility routines
\    Summary: Zero-fill the page whose number is in X
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The page we want to zero-fill
\
\ ******************************************************************************

.ZES1

 LDY #0                 \ If we set Y = SC = 0 and fall through into ZES2
 STY SC                 \ below, then we will zero-fill 255 bytes starting from
                        \ SC - in other words, we will zero-fill the whole of
                        \ page X

\ ******************************************************************************
\
\       Name: ZES2
\       Type: Subroutine
\   Category: Utility routines
\    Summary: Zero-fill a specific page
\
\ ------------------------------------------------------------------------------
\
\ Zero-fill from address (X SC) + Y to (X SC) + &FF.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The high byte (i.e. the page) of the starting point of
\                       the zero-fill
\
\   Y                   The offset from (X SC) where we start zeroing, counting
\                       up to &FF
\
\   SC                  The low byte (i.e. the offset into the page) of the
\                       starting point of the zero-fill
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   Z flag              Z flag is set
\
\ ******************************************************************************

.ZES2

 LDA #0                 \ Load A with the byte we want to fill the memory block
                        \ with - i.e. zero

 STX SC+1               \ We want to zero-fill page X, so store this in the
                        \ high byte of SC, so the 16-bit address in SC and
                        \ SC+1 is now pointing to the SC-th byte of page X

.ZEL1

 STA (SC),Y             \ Zero the Y-th byte of the block pointed to by SC,
                        \ so that's effectively the Y-th byte before SC

 INY                    \ Increment the loop counter

 BNE ZEL1               \ Loop back to zero the next byte

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: FONT%
\       Type: Variable
\   Category: Text
\    Summary: A copy of the character definition bitmap table from the MOS ROM
\
\ ------------------------------------------------------------------------------
\
\ This is used by the TT26 routine to save time looking up the character bitmaps
\ from the ROM. Note that FONT% contains just the high byte (i.e. the page
\ number) of the address of this table, rather than the full address.
\
\ The contents of the P.FONT.bin file included here are taken straight from the
\ following three pages in the BBC Micro OS 1.20 ROM:
\
\   ASCII 32-63  are defined in &C000-&C0FF (page 0)
\   ASCII 64-95  are defined in &C100-&C1FF (page 1)
\   ASCII 96-126 are defined in &C200-&C2F0 (page 2)
\
\ The code could look these values up each time (as the cassette version does),
\ but it's quicker to use a lookup table, at the expense of three pages of
\ memory.
\
\ ******************************************************************************

 ALIGN &100             \ Port: the font must start on a page boundary, as only
                        \ its page number is used (code moves in front of it)

 FONT% = HI(P%)         \ Set FONT% to the high byte of the font file address

 INCBIN "src/fonts/P.FONT.bin"

\ ******************************************************************************
\
\       Name: log
\       Type: Variable
\   Category: Maths (Arithmetic)
\    Summary: Binary logarithm table (high byte)
\
\ ------------------------------------------------------------------------------
\
\ At byte n, the table contains the high byte of:
\
\   &2000 * log10(n) / log10(2) = 32 * 256 * log10(n) / log10(2)
\
\ where log10 is the logarithm to base 10. The change-of-base formula says that:
\
\   log2(n) = log10(n) / log10(2)
\
\ so byte n contains the high byte of:
\
\   32 * log2(n) * 256
\
\ ******************************************************************************

.log

IF _MATCH_ORIGINAL_BINARIES

 EQUB &00               \ This byte appears to be unused and just contains
                        \ random workspace noise left over from the BBC Micro
                        \ assembly process

 EQUB &00, &20, &32, &40, &4A, &52, &59
 EQUB &60, &65, &6A, &6E, &72, &76, &79, &7D
 EQUB &80, &82, &85, &87, &8A, &8C, &8E, &90
 EQUB &92, &94, &96, &98, &99, &9B, &9D, &9E
 EQUB &A0, &A1, &A2, &A4, &A5, &A6, &A7, &A9
 EQUB &AA, &AB, &AC, &AD, &AE, &AF, &B0, &B1
 EQUB &B2, &B3, &B4, &B5, &B6, &B7, &B8, &B9
 EQUB &B9, &BA, &BB, &BC, &BD, &BD, &BE, &BF
 EQUB &C0, &C0, &C1, &C2, &C2, &C3, &C4, &C4
 EQUB &C5, &C6, &C6, &C7, &C7, &C8, &C9, &C9
 EQUB &CA, &CA, &CB, &CC, &CC, &CD, &CD, &CE
 EQUB &CE, &CF, &CF, &D0, &D0, &D1, &D1, &D2
 EQUB &D2, &D3, &D3, &D4, &D4, &D5, &D5, &D5
 EQUB &D6, &D6, &D7, &D7, &D8, &D8, &D9, &D9
 EQUB &D9, &DA, &DA, &DB, &DB, &DB, &DC, &DC
 EQUB &DD, &DD, &DD, &DE, &DE, &DE, &DF, &DF
 EQUB &E0, &E0, &E0, &E1, &E1, &E1, &E2, &E2
 EQUB &E2, &E3, &E3, &E3, &E4, &E4, &E4, &E5
 EQUB &E5, &E5, &E6, &E6, &E6, &E7, &E7, &E7
 EQUB &E7, &E8, &E8, &E8, &E9, &E9, &E9, &EA
 EQUB &EA, &EA, &EA, &EB, &EB, &EB, &EC, &EC
 EQUB &EC, &EC, &ED, &ED, &ED, &ED, &EE, &EE
 EQUB &EE, &EE, &EF, &EF, &EF, &EF, &F0, &F0
 EQUB &F0, &F1, &F1, &F1, &F1, &F1, &F2, &F2
 EQUB &F2, &F2, &F3, &F3, &F3, &F3, &F4, &F4
 EQUB &F4, &F4, &F5, &F5, &F5, &F5, &F5, &F6
 EQUB &F6, &F6, &F6, &F7, &F7, &F7, &F7, &F7
 EQUB &F8, &F8, &F8, &F8, &F9, &F9, &F9, &F9
 EQUB &F9, &FA, &FA, &FA, &FA, &FA, &FB, &FB
 EQUB &FB, &FB, &FB, &FC, &FC, &FC, &FC, &FC
 EQUB &FD, &FD, &FD, &FD, &FD, &FD, &FE, &FE
 EQUB &FE, &FE, &FE, &FF, &FF, &FF, &FF, &FF

ELSE

 SKIP 1

 FOR I%, 1, 255

  EQUB HI(INT(&2000 * LOG(I%) / LOG(2) + 0.5))

 NEXT

ENDIF

\ ******************************************************************************
\
\       Name: logL
\       Type: Variable
\   Category: Maths (Arithmetic)
\    Summary: Binary logarithm table (low byte)
\
\ ------------------------------------------------------------------------------
\
\ Byte n contains the low byte of:
\
\   32 * log2(n) * 256
\
\ ******************************************************************************

.logL

IF _MATCH_ORIGINAL_BINARIES

 IF _SNG47

  EQUB &60              \ This byte appears to be unused and just contains
                        \ random workspace noise left over from the BBC Micro
                        \ assembly process

 ELIF _COMPACT

  EQUB &A9              \ This byte appears to be unused and just contains
                        \ random workspace noise left over from the BBC Micro
                        \ assembly process

 ENDIF

 EQUB &00, &00, &B8, &00, &4D, &B8, &D6
 EQUB &00, &70, &4D, &B4, &B8, &6A, &D6, &05
 EQUB &00, &CC, &70, &EF, &4D, &8E, &B4, &C1
 EQUB &B8, &9A, &6A, &28, &D6, &75, &05, &89
 EQUB &00, &6C, &CC, &23, &70, &B4, &EF, &22
 EQUB &4D, &71, &8E, &A4, &B4, &BD, &C1, &BF
 EQUB &B8, &AC, &9A, &85, &6A, &4B, &28, &01
 EQUB &D6, &A7, &75, &3F, &05, &C9, &89, &46
 EQUB &00, &B7, &6C, &1D, &CC, &79, &23, &CB
 EQUB &70, &13, &B4, &52, &EF, &8A, &22, &B9
 EQUB &4D, &E0, &71, &00, &8E, &1A, &A4, &2D
 EQUB &B4, &39, &BD, &40, &C1, &41, &BF, &3C
 EQUB &B8, &32, &AC, &24, &9A, &10, &85, &F8
 EQUB &6A, &DB, &4B, &BA, &28, &95, &01, &6C
 EQUB &D6, &3F, &A7, &0E, &75, &DA, &3F, &A2
 EQUB &05, &67, &C9, &29, &89, &E8, &46, &A3
 EQUB &00, &5C, &B7, &12, &6C, &C5, &1D, &75
 EQUB &CC, &23, &79, &CE, &23, &77, &CB, &1E
 EQUB &70, &C2, &13, &64, &B4, &03, &52, &A1
 EQUB &EF, &3D, &8A, &D6, &22, &6E, &B9, &03
 EQUB &4D, &97, &E0, &29, &71, &B9, &00, &47
 EQUB &8E, &D4, &1A, &5F, &A4, &E8, &2D, &70
 EQUB &B4, &F7, &39, &7B, &BD, &FF, &40, &81
 EQUB &C1, &01, &41, &80, &BF, &FE, &3C, &7A
 EQUB &B8, &F5, &32, &6F, &AC, &E8, &24, &5F
 EQUB &9A, &D5, &10, &4A, &85, &BE, &F8, &31
 EQUB &6A, &A3, &DB, &13, &4B, &83, &BA, &F1
 EQUB &28, &5F, &95, &CB, &01, &36, &6C, &A1
 EQUB &D6, &0A, &3F, &73, &A7, &DB, &0E, &42
 EQUB &75, &A7, &DA, &0C, &3F, &71, &A2, &D4
 EQUB &05, &36, &67, &98, &C9, &F9, &29, &59
 EQUB &89, &B8, &E8, &17, &46, &75, &A3, &D2

ELSE

 SKIP 1

 FOR I%, 1, 255

  EQUB LO(INT(&2000 * LOG(I%) / LOG(2) + 0.5))

 NEXT

ENDIF

\ ******************************************************************************
\
\       Name: alogh
\       Type: Variable
\   Category: Maths (Arithmetic)
\    Summary: Binary antilogarithm table
\
\ ------------------------------------------------------------------------------
\
\ At byte n, the table contains:
\
\   2^((n / 2 + 128) / 16) / 256
\
\ which equals:
\
\   2^(n / 32 + 8) / 256
\
\ ******************************************************************************

.alogh

 FOR I%, 0, 255

  EQUB HI(INT(2^((I% / 2 + 128) / 16) + 0.5))

 NEXT

\ ******************************************************************************
\
\       Name: UP
\       Type: Workspace
\    Address: &2C40 to &2C61
\   Category: Workspaces
\    Summary: Configuration variables
\
\ ******************************************************************************

.UP

 SKIP 0                 \ The start of the UP workspace

.COMC

 SKIP 1                 \ The colour of the dot on the compass
                        \
                        \   * #WHITE2 = the object in the compass is in front of
                        \     us, so the dot is white
                        \
                        \   * #GREEN2 = the object in the compass is behind us,
                        \     so the dot is green

.dials

 SKIP 14                \ These bytes appear to be unused

.mscol

 SKIP 4                 \ This byte appears to be unused

.CATF

 SKIP 1                 \ The disc catalogue flag
                        \
                        \ Determines whether a disc catalogue is currently in
                        \ progress, so the TT26 print routine can format the
                        \ output correctly:
                        \
                        \   * 0 = disc is not currently being catalogued
                        \
                        \   * 1 = disc is currently being catalogued
                        \
                        \ Specifically, when CATF is non-zero, TT26 will omit
                        \ column 17 from the catalogue so that it will fit
                        \ on-screen (column 17 is blank column in the middle
                        \ of the catalogue, between the two lists of filenames,
                        \ so it can be dropped without affecting the layout)

.DFLAG

 SKIP 1                 \ This byte appears to be unused

.DNOIZ

 SKIP 1                 \ Sound on/off configuration setting
                        \
                        \   * 0 = sound is on (default)
                        \
                        \   * Non-zero = sound is off
                        \
                        \ Toggled by pressing "S" when paused, see the DK4
                        \ routine for details

.DAMP

 SKIP 1                 \ Keyboard damping configuration setting
                        \
                        \   * 0 = damping is enabled (default)
                        \
                        \   * &FF = damping is disabled
                        \
                        \ Toggled by pressing CAPS LOCK when paused, see the
                        \ DKS3 routine for details

.DJD

 SKIP 1                 \ Keyboard auto-recentre configuration setting
                        \
                        \   * 0 = auto-recentre is enabled (default)
                        \
                        \   * &FF = auto-recentre is disabled
                        \
                        \ Toggled by pressing "A" when paused, see the DKS3
                        \ routine for details

.PATG

 SKIP 1                 \ Configuration setting to show the author names on the
                        \ start-up screen and enable manual hyperspace mis-jumps
                        \
                        \   * 0 = no author names or manual mis-jumps (default)
                        \
                        \   * &FF = show author names and allow manual mis-jumps
                        \
                        \ Toggled by pressing "X" when paused, see the DKS3
                        \ routine for details
                        \
                        \ This needs to be turned on for manual mis-jumps to be
                        \ possible. To do a manual mis-jump, first toggle the
                        \ author display by pausing the game and pressing "X",
                        \ and during the next hyperspace, hold down CTRL to
                        \ force a mis-jump. See routine ee5 for the "AND PATG"
                        \ instruction that implements this logic

.FLH

 SKIP 1                 \ Flashing console bars configuration setting
                        \
                        \   * 0 = static bars (default)
                        \
                        \   * &FF = flashing bars
                        \
                        \ Toggled by pressing "F" when paused, see the DKS3
                        \ routine for details

.JSTGY

 SKIP 1                 \ Reverse joystick Y-channel configuration setting
                        \
                        \   * 0 = reversed Y-channel
                        \
                        \   * &FF = standard Y-channel (default)
                        \
                        \ Toggled by pressing "Y" when paused, see the DKS3
                        \ routine for details

.JSTE

 SKIP 1                 \ Reverse both joystick channels configuration setting
                        \
                        \   * 0 = standard channels (default)
                        \
                        \   * &FF = reversed channels
                        \
                        \ Toggled by pressing "J" when paused, see the DKS3
                        \ routine for details

.JSTK

 SKIP 1                 \ Keyboard or joystick configuration setting
                        \
                        \   * 0 = keyboard (default)
                        \
                        \   * &FF = joystick
                        \
                        \ Toggled by pressing "K" when paused, see the DKS3
                        \ routine for details

.UPTOG

 SKIP 1                 \ The configuration setting for toggle key "U", which
                        \ isn't actually used but is still updated by pressing
                        \ "U" while the game is paused. This is a configuration
                        \ option from the Apple II version of Elite that lets
                        \ you switch between lower-case and upper-case text

.DISK

 SKIP 1                 \ The configuration setting for toggle key "T", which
                        \ isn't actually used but is still updated by pressing
                        \ "T" while the game is paused. This is a configuration
                        \ option from the Commodore 64 version of Elite that
                        \ lets you switch between tape and disc

.BSTK

 SKIP 1                 \ Bitstik configuration setting
                        \
                        \   * 0 = keyboard or joystick (default)
                        \
                        \   * &FF = Bitstik
                        \
                        \ Toggled by pressing "B" when paused, see the DKS3
                        \ routine for details

 SKIP 1                 \ This byte appears to be unused

.VOL

 EQUB 7                 \ The volume level for the game's sound effects (0-7)
                        \
                        \ This is controlled by the "<" and ">" keys while the
                        \ game is paused, and the default level is 7

 PRINT "UP workspace from ", ~UP, "to ", ~P%-1, "inclusive"

 ASSERT P% <= &3000     \ Port: everything up to here must be below &3000, as it
                        \ is used while ACCCON X = 1 (shadow RAM at &3000-&7FFF):
                        \ the IRQ and sound code, CHPR and its font, the far
                        \ calls, the log tables (LOINQ) and UP (CATF, FLH, COMC)

\ ******************************************************************************
\
\       Name: G%
\       Type: Variable
\   Category: Utility routines
\    Summary: Denotes the start of the main game code, from ELITE A to ELITE H
\
\ ******************************************************************************

.G%

 SKIP 0                 \ The game code is scrambled from here to F% (or, as the
                        \ original source code puts it, "mutilated")

\ ******************************************************************************
\
\       Name: TRIBDIR
\       Type: Variable
\   Category: Missions
\    Summary: The low byte of the four 16-bit directions in which Trumble
\             sprites can move
\
\ ******************************************************************************

\.TRIBDIR               \ These instructions are commented out in the original
\                       \ source
\EQUB 0
\EQUB 1
\EQUB &FF
\EQUB 0

\ ******************************************************************************
\
\       Name: TRIBDIRH
\       Type: Variable
\   Category: Missions
\    Summary: The high byte of the four 16-bit directions in which Trumble
\             sprites can move
\
\ ******************************************************************************

\.TRIBDIRH              \ These instructions are commented out in the original
\                       \ source
\EQUB 0
\EQUB 0
\EQUB &FF
\EQUB 0

\ ******************************************************************************
\
\       Name: SPMASK
\       Type: Variable
\   Category: Missions
\    Summary: Masks for updating sprite bits in VIC+&10 for the top bit of the
\             9-bit x-coordinates of the Trumble sprites
\
\ ******************************************************************************

.SPMASK

 EQUW &04FB             \ These bytes are unused and are left over from the
 EQUW &08F7             \ Commodore 64 version
 EQUW &10EF
 EQUW &20DF
 EQUW &40BF
 EQUW &807F

\ ******************************************************************************
\
\       Name: Main flight loop (Part 1 of 16)
\       Type: Subroutine
\   Category: Main loop
\    Summary: Seed the random number generator
\  Deep dive: Program flow of the main game loop
\             Generating random numbers
\
\ ------------------------------------------------------------------------------
\
\ The main flight loop covers most of the flight-specific aspects of Elite. This
\ section covers the following:
\
\   * Seed the random number generator
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   M%                  The entry point for the main flight loop
\
\ ******************************************************************************

.M%

 LDA K%                 \ We want to seed the random number generator with a
                        \ pretty random number, so fetch the contents of K%,
                        \ which is the x_lo coordinate of the planet. This value
                        \ will be fairly unpredictable, so it's a pretty good
                        \ candidate

 STA RAND               \ Store the seed in the first byte of the four-byte
                        \ random number seed that's stored in RAND

\LDA TRIBCT             \ These instructions are commented out in the original
\BEQ NOMVETR            \ source
\JMP MVTRIBS
\
\.NOMVETR

\ ******************************************************************************
\
\       Name: Main flight loop (Part 2 of 16)
\       Type: Subroutine
\   Category: Main loop
\    Summary: Calculate the alpha and beta angles from the current pitch and
\             roll of our ship
\  Deep dive: Program flow of the main game loop
\             Pitching and rolling
\
\ ------------------------------------------------------------------------------
\
\ The main flight loop covers most of the flight-specific aspects of Elite. This
\ section covers the following:
\
\   * Calculate the alpha and beta angles from the current pitch and roll
\
\ Here we take the current rate of pitch and roll, as set by the joystick or
\ keyboard, and convert them into alpha and beta angles that we can use in the
\ matrix functions to rotate space around our ship. The alpha angle covers
\ roll, while the beta angle covers pitch (there is no yaw in this version of
\ Elite). The angles are in radians, which allows us to use the small angle
\ approximation when moving objects in the sky (see the MVEIT routine for more
\ on this). Also, the signs of the two angles are stored separately, in both
\ the sign and the flipped sign, as this makes calculations easier.
\
\ ******************************************************************************

 LDX JSTX               \ Set X to the current rate of roll in JSTX

 JSR cntr               \ Apply keyboard damping twice (if enabled) so the roll
 JSR cntr               \ rate in X creeps towards the centre by 2

                        \ The roll rate in JSTX increases if we press ">" (and
                        \ the RL indicator on the dashboard goes to the right)
                        \
                        \ This rolls our ship to the right (clockwise), but we
                        \ actually implement this by rolling everything else
                        \ to the left (anti-clockwise), so a positive roll rate
                        \ in JSTX translates to a negative roll angle alpha

 TXA                    \ Set A and Y to the roll rate but with the sign bit
 EOR #%10000000         \ flipped (i.e. set them to the sign we want for alpha)
 TAY

 AND #%10000000         \ Extract the flipped sign of the roll rate and store
 STA ALP2               \ in ALP2 (so ALP2 contains the sign of the roll angle
                        \ alpha)

 STX JSTX               \ Update JSTX with the damped value that's still in X

 EOR #%10000000         \ Extract the correct sign of the roll rate and store
 STA ALP2+1             \ in ALP2+1 (so ALP2+1 contains the flipped sign of the
                        \ roll angle alpha)

 TYA                    \ Set A to the roll rate but with the sign bit flipped

 BPL P%+7               \ If the value of A is positive, skip the following
                        \ three instructions

 EOR #%11111111         \ A is negative, so change the sign of A using two's
 CLC                    \ complement so that A is now positive and contains
 ADC #1                 \ the absolute value of the roll rate, i.e. |JSTX|

 LSR A                  \ Divide the (positive) roll rate in A by 4
 LSR A

 CMP #8                 \ If A >= 8, skip the following instruction
 BCS P%+3

 LSR A                  \ A < 8, so halve A again

 STA ALP1               \ Store A in ALP1, so we now have:
                        \
                        \   ALP1 = |JSTX| / 8    if |JSTX| < 32
                        \
                        \   ALP1 = |JSTX| / 4    if |JSTX| >= 32
                        \
                        \ This means that at lower roll rates, the roll angle is
                        \ reduced closer to zero than at higher roll rates,
                        \ which gives us finer control over the ship's roll at
                        \ lower roll rates
                        \
                        \ Because JSTX is in the range -127 to +127, ALP1 is
                        \ in the range 0 to 31

 ORA ALP2               \ Store A in ALPHA, but with the sign set to ALP2 (so
 STA ALPHA              \ ALPHA has a different sign to the actual roll rate)

 LDX JSTY               \ Set X to the current rate of pitch in JSTY

 JSR cntr               \ Apply keyboard damping so the pitch rate in X creeps
                        \ towards the centre by 1

 TXA                    \ Set A and Y to the pitch rate but with the sign bit
 EOR #%10000000         \ flipped
 TAY

 AND #%10000000         \ Extract the flipped sign of the pitch rate into A

 STX JSTY               \ Update JSTY with the damped value that's still in X

 STA BET2+1             \ Store the flipped sign of the pitch rate in BET2+1

 EOR #%10000000         \ Extract the correct sign of the pitch rate and store
 STA BET2               \ it in BET2

 TYA                    \ Set A to the pitch rate but with the sign bit flipped

 BPL P%+4               \ If the value of A is positive, skip the following
                        \ instruction

 EOR #%11111111         \ A is negative, so flip the bits

 ADC #4                 \ Add 4 to the (positive) pitch rate, so the maximum
                        \ value is now up to 131 (rather than 127)

 LSR A                  \ Divide the (positive) pitch rate in A by 16
 LSR A
 LSR A
 LSR A

 CMP #3                 \ If A >= 3, skip the following instruction
 BCS P%+3

 LSR A                  \ A < 3, so halve A again

 STA BET1               \ Store A in BET1, so we now have:
                        \
                        \   BET1 = |JSTY| / 32    if |JSTY| < 48
                        \
                        \   BET1 = |JSTY| / 16    if |JSTY| >= 48
                        \
                        \ This means that at lower pitch rates, the pitch angle
                        \ is reduced closer to zero than at higher pitch rates,
                        \ which gives us finer control over the ship's pitch at
                        \ lower pitch rates
                        \
                        \ Because JSTY is in the range -131 to +131, BET1 is in
                        \ the range 0 to 8

 ORA BET2               \ Store A in BETA, but with the sign set to BET2 (so
 STA BETA               \ BETA has the same sign as the actual pitch rate)

 LDA BSTK               \ If BSTK = 0 then the Bitstik is not configured, so
 BEQ BS2                \ jump to BS2 to skip the following

 LDA JOPOS+2            \ Fetch the Bitstik rotation value (high byte) from
                        \ JOPOS+2, which is constantly updated with the high
                        \ byte of ADC channel 3 by the interrupt handler IRQ1

 LSR A                  \ Divide A by 4
 LSR A

 CMP #40                \ If A < 40, skip the following instruction
 BCC P%+4

 LDA #40                \ Set A = 40, which ensures a maximum speed of 40

 STA DELTA              \ Update our speed in DELTA

 BNE MA4                \ If the speed we just set is non-zero, then jump to MA4
                        \ to skip the following, as we don't need to check the
                        \ keyboard for speed keys, otherwise do check the
                        \ keyboard (so Bitstik users can still use the keyboard
                        \ for speed adjustments if they twist the stick to zero)

\ ******************************************************************************
\
\       Name: Main flight loop (Part 3 of 16)
\       Type: Subroutine
\   Category: Main loop
\    Summary: Scan for flight keys and process the results
\  Deep dive: Program flow of the main game loop
\             The key logger
\
\ ------------------------------------------------------------------------------
\
\ The main flight loop covers most of the flight-specific aspects of Elite. This
\ section covers the following:
\
\   * Scan for flight keys and process the results
\
\ Flight keys are logged in the key logger at location KY1 onwards, with a
\ non-zero value in the relevant location indicating a key press.
\
\ The key presses that are processed are as follows:
\
\   * Space and "?" to speed up and slow down
\   * "U", "T" and "M" to unarm, target and fire missiles
\   * TAB to fire an energy bomb
\   * ESCAPE to launch an escape pod
\   * "J" to initiate an in-system jump
\   * "E" to deploy E.C.M. anti-missile countermeasures
\   * "C" to use the docking computer
\   * "A" to fire lasers
\
\ ******************************************************************************

.BS2

 LDA KY2                \ If Space is being pressed, keep going, otherwise jump
 BEQ MA17               \ down to MA17 to skip the following

 LDA DELTA              \ The "go faster" key is being pressed, so first we
 CMP #40                \ fetch the current speed from DELTA into A, and if
 BCS MA17               \ A >= 40, we are already going at full pelt, so jump
                        \ down to MA17 to skip the following

 INC DELTA              \ We can go a bit faster, so increment the speed in
                        \ location DELTA

.MA17

 LDA KY1                \ If "?" is being pressed, keep going, otherwise jump
 BEQ MA4                \ down to MA4 to skip the following

 DEC DELTA              \ The "slow down" key is being pressed, so we decrement
                        \ the current ship speed in DELTA

 BNE MA4                \ If the speed is still greater than zero, jump to MA4

 INC DELTA              \ Otherwise we just braked a little too hard, so bump
                        \ the speed back up to the minimum value of 1

.MA4

 LDA KY15               \ If "U" is being pressed and the number of missiles
 AND NOMSL              \ in NOMSL is non-zero, keep going, otherwise jump down
 BEQ MA20               \ to MA20 to skip the following

 LDY #GREEN2            \ The "unarm missiles" key is being pressed, so call
 JSR ABORT              \ ABORT to unarm the missile and update the missile
                        \ indicators on the dashboard to green (Y = &EE)

 JSR BOOP               \ Call the BOOP routine to make a low, long beep to
                        \ indicate the missile is now unarmed

 LDA #0                 \ Set MSAR to 0 to indicate that no missiles are
 STA MSAR               \ currently armed

.MA20

 LDA MSTG               \ If MSTG is positive (i.e. it does not have bit 7 set),
 BPL MA25               \ then it indicates we already have a missile locked on
                        \ a target (in which case MSTG contains the ship number
                        \ of the target), so jump to MA25 to skip targeting. Or
                        \ to put it another way, if MSTG = &FF, which means
                        \ there is no current target lock, keep going

 LDA KY14               \ If "T" is being pressed, keep going, otherwise jump
 BEQ MA25               \ down to MA25 to skip the following

 LDX NOMSL              \ If the number of missiles in NOMSL is zero, jump down
 BEQ MA25               \ to MA25 to skip the following

 STA MSAR               \ The "target missile" key is being pressed and we have
                        \ at least one missile, so set MSAR = &FF to denote that
                        \ our missile is currently armed (we know A has the
                        \ value &FF, as we just loaded it from MSTG and checked
                        \ that it was negative)

 LDY #YELLOW2           \ Change the leftmost missile indicator to yellow
 JSR MSBAR              \ on the missile bar (this call changes the leftmost
                        \ indicator because we set X to the number of missiles
                        \ in NOMSL above, and the indicators are numbered from
                        \ right to left, so X is the number of the leftmost
                        \ indicator)

.MA25

 LDA KY16               \ If "M" is being pressed, keep going, otherwise jump
 BEQ MA24               \ down to MA24 to skip the following

 LDA MSTG               \ If MSTG = &FF then there is no target lock, so jump to
 BMI MA64               \ MA64 to skip the following (also skipping the checks
                        \ for TAB, ESCAPE, "J" and "E")

 JSR FRMIS              \ The "fire missile" key is being pressed and we have
                        \ a missile lock, so call the FRMIS routine to fire
                        \ the missile

.MA24

 LDA KY12               \ If TAB is being pressed, keep going, otherwise jump
 BEQ MA76               \ down to MA76 to skip the following

 LDA BOMB               \ If we already set off our energy bomb, then BOMB is
 BMI MA76               \ negative, so this skips to MA76 if our energy bomb is
                        \ already going off

 ASL BOMB               \ The "energy bomb" key is being pressed, so double
                        \ the value in BOMB. If we have an energy bomb fitted,
                        \ BOMB will contain &7F (%01111111) before this shift
                        \ and will contain &FE (%11111110) after the shift; if
                        \ we don't have an energy bomb fitted, BOMB will still
                        \ contain 0. The bomb explosion is dealt with in the
                        \ MAL1 routine below - this just registers the fact that
                        \ we've set the bomb ticking

 BEQ MA76               \ If BOMB now contains 0, then the bomb is not going off
                        \ any more (or it never was), so skip the following
                        \ instruction

 JSR BOMBON             \ Call BOMBON to set up and display a new energy bomb
                        \ zig-zag lightning bolt

.MA76

 LDA KY20               \ If "P" is being pressed, keep going, otherwise skip
 BEQ MA78               \ the next two instructions

 LDA #0                 \ The "cancel docking computer" key is bring pressed,
 STA auto               \ so turn it off by setting auto to 0

\JSR stopbd             \ This instruction is commented out in the original
                        \ source

.MA78

 LDA KY13               \ If ESCAPE is being pressed and we have an escape pod
 AND ESCP               \ fitted, keep going, otherwise jump to noescp to skip
 BEQ noescp             \ the following instructions

 LDA MJ                 \ If we are in witchspace, we can't launch our escape
 BNE noescp             \ pod, so jump down to noescp

 JMP ESCAPE             \ The button is being pressed to launch an escape pod
                        \ and we have an escape pod fitted, so jump to ESCAPE to
                        \ launch it, and exit the main flight loop using a tail
                        \ call

.noescp

 LDA KY18               \ If "J" is being pressed, keep going, otherwise skip
 BEQ P%+5               \ the next instruction

 JSR WARP               \ Call the WARP routine to do an in-system jump

 LDA KY17               \ If "E" is being pressed and we have an E.C.M. fitted,
 AND ECM                \ keep going, otherwise jump down to MA64 to skip the
 BEQ MA64               \ following

 LDA ECMA               \ If ECMA is non-zero, that means an E.C.M. is already
 BNE MA64               \ operating and is counting down (this can be either
                        \ our E.C.M. or an opponent's), so jump down to MA64 to
                        \ skip the following (as we can't have two E.C.M.
                        \ systems operating at the same time)

 DEC ECMP               \ The E.C.M. button is being pressed and nobody else
                        \ is operating their E.C.M., so decrease the value of
                        \ ECMP to make it non-zero, to denote that our E.C.M.
                        \ is now on

 JSR ECBLB2             \ Call ECBLB2 to light up the E.C.M. indicator bulb on
                        \ the dashboard, set the E.C.M. countdown timer to 32,
                        \ and start making the E.C.M. sound

.MA64

 LDA KY19               \ If "C" is being pressed, and we have a docking
 AND DKCMP              \ computer fitted, keep going, otherwise jump down to
 BEQ MA68               \ MA68 to skip the following

 STA auto               \ Set auto to the non-zero value of A, so the docking
                        \ computer is activated

\EOR KLO+&29            \ These instructions are commented out in the original
\BEQ MA68               \ source
\
\STA auto
\
\JSR startbd
\
\kill phantom Cs

.MA68

 LDA #0                 \ Set LAS = 0, to switch the laser off while we do the
 STA LAS                \ following logic

 STA DELT4              \ Take the 16-bit value (DELTA 0) - i.e. a two-byte
 LDA DELTA              \ number with DELTA as the high byte and 0 as the low
 LSR A                  \ byte - and divide it by 4, storing the 16-bit result
 ROR DELT4              \ in DELT4(1 0). This has the effect of storing the
 LSR A                  \ current speed * 64 in the 16-bit location DELT4(1 0)
 ROR DELT4
 STA DELT4+1

 LDA LASCT              \ If LASCT is zero, keep going, otherwise the laser is
 BNE MA3                \ a pulse laser that is between pulses, so jump down to
                        \ MA3 to skip the following

 LDA KY7                \ If "A" is being pressed, keep going, otherwise jump
 BEQ MA3                \ down to MA3 to skip the following

 LDA GNTMP              \ If the laser temperature >= 242 then the laser has
 CMP #242               \ overheated, so jump down to MA3 to skip the following
 BCS MA3

 LDX VIEW               \ If the current space view has a laser fitted (i.e. the
 LDA LASER,X            \ laser power for this view is greater than zero), then
 BEQ MA3                \ keep going, otherwise jump down to MA3 to skip the
                        \ following

                        \ If we get here, then the "fire" button is being
                        \ pressed, our laser hasn't overheated and isn't already
                        \ being fired, and we actually have a laser fitted to
                        \ the current space view, so it's time to hit me with
                        \ those laser beams

 PHA                    \ Store the current view's laser power on the stack

 AND #%01111111         \ Set LAS and LAS2 to bits 0-6 of the laser power
 STA LAS
 STA LAS2

 JSR LASNO              \ Call the LASNO routine to make the sound of our laser
                        \ firing

 JSR LASLI              \ Call LASLI to draw the laser lines

 PLA                    \ Restore the current view's laser power into A

 BPL ma1                \ If the laser power has bit 7 set, then it's an "always
                        \ on" laser rather than a pulsing laser, so keep going,
                        \ otherwise jump down to ma1 to skip the following
                        \ instruction

 LDA #0                 \ This is an "always on" laser (i.e. a beam laser or a
                        \ military laser), so set A = 0, which will be stored in
                        \ LASCT to denote that this is not a pulsing laser

.ma1

 AND #%11111010         \ LASCT will be set to 0 for beam lasers, and to the
 STA LASCT              \ laser power AND %11111010 for pulse lasers, which
                        \ comes to 10 for pulse lasers (as pulse lasers have a
                        \ power of 15) or 50 for mining lasers (as mining
                        \ lasers hava a power of 50). See MA23 in part 16 for
                        \ more on laser pulsing and LASCT

\ ******************************************************************************
\
\       Name: Main flight loop (Part 4 of 16)
\       Type: Subroutine
\   Category: Main loop
\    Summary: For each nearby ship: Copy the ship's data block from K% to the
\             zero-page workspace at INWK
\  Deep dive: Program flow of the main game loop
\             Ship data blocks
\
\ ------------------------------------------------------------------------------
\
\ The main flight loop covers most of the flight-specific aspects of Elite. This
\ section covers the following:
\
\   * Start looping through all the ships in the local bubble, and for each
\     one:
\
\     * Copy the ship's data block from K% to INWK
\
\     * Set XX0 to point to the ship's blueprint (if this is a ship)
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   MAL1                Marks the beginning of the ship analysis loop, so we
\                       can jump back here from part 12 of the main flight loop
\                       to work our way through each ship in the local bubble.
\                       We also jump back here when a ship is removed from the
\                       bubble, so we can continue processing from the next ship
\
\ ******************************************************************************

.MA3

 LDX #0                 \ We're about to work our way through all the ships in
                        \ our local bubble of universe, so set a counter in X,
                        \ starting from 0, to refer to each ship slot in turn

.MAL1

 STX XSAV               \ Store the current slot number in XSAV

 LDA FRIN,X             \ Fetch the contents of this slot into A. If it is 0
 BNE P%+5               \ then this slot is empty and we have no more ships to
 JMP MA18               \ process, so jump to MA18 below, otherwise A contains
                        \ the type of ship that's in this slot, so skip over the
                        \ JMP MA18 instruction and keep going

 STA TYPE               \ Store the ship type in TYPE

 JSR GINF               \ Call GINF to fetch the address of the ship data block
                        \ for the ship in slot X and store it in INF. The data
                        \ block is in the K% workspace, which is where all the
                        \ ship data blocks are stored

                        \ Next we want to copy the ship data block from INF to
                        \ the zero-page workspace at INWK, so we can process it
                        \ more efficiently

 LDY #NI%-1             \ There are NI% bytes in each ship data block (and in
                        \ the INWK workspace, so we set a counter in Y so we can
                        \ loop through them

 LDA (INF),Y            \ Copy the last byte (NI%-1) on its own, using a
 STA INWK+NI%-1         \ zero-page store, so the remaining NI%-1 = 36 bytes
 DEY                    \ can be copied four per loop pass

 ASSERT (NI%-1) MOD 4 = 0 \ The loop below copies four bytes per pass

.MAL2

 LDA (INF),Y            \ Load the Y-th byte of INF and store it in the Y-th
 STA INWK,Y             \ byte of INWK

 DEY                    \ Decrement the loop counter

 LDA (INF),Y            \ Second byte of this pass (loop unrolled four times)
 STA INWK,Y

 DEY                    \ Decrement the loop counter

 LDA (INF),Y            \ Third byte of this pass
 STA INWK,Y

 DEY                    \ Decrement the loop counter

 LDA (INF),Y            \ Fourth byte of this pass
 STA INWK,Y

 DEY                    \ Decrement the loop counter

 BPL MAL2               \ Loop back for the next byte until we have copied the
                        \ last byte from INF to INWK

 LDA TYPE               \ If the ship type is negative then this indicates a
 BMI MA21               \ planet or sun, so jump down to MA21, as the next bit
                        \ sets up a pointer to the ship blueprint, and then
                        \ checks for energy bomb damage, and neither of these
                        \ apply to planets and suns

 ASL A                  \ Set Y = ship type * 2
 TAY

 LDA XX21-2,Y           \ The ship blueprints at XX21 start with a lookup
 STA XX0                \ table that points to the individual ship blueprints,
                        \ so this fetches the low byte of this particular ship
                        \ type's blueprint and stores it in XX0

 LDA XX21-1,Y           \ Fetch the high byte of this particular ship type's
 STA XX0+1              \ blueprint and store it in XX0+1

\ ******************************************************************************
\
\       Name: Main flight loop (Part 5 of 16)
\       Type: Subroutine
\   Category: Main loop
\    Summary: For each nearby ship: If an energy bomb has been set off,
\             potentially kill this ship
\  Deep dive: Program flow of the main game loop
\
\ ------------------------------------------------------------------------------
\
\ The main flight loop covers most of the flight-specific aspects of Elite. This
\ section covers the following:
\
\   * Continue looping through all the ships in the local bubble, and for each
\     one:
\
\     * If an energy bomb has been set off and this ship can be killed, kill it
\       and increase the kill tally
\
\ ******************************************************************************

 LDA BOMB               \ If we set off our energy bomb (see MA24 above), then
 BPL MA21               \ BOMB is now negative, so this skips to MA21 if our
                        \ energy bomb is not going off

 CPY #2*SST             \ If the ship in Y is the space station, jump to BA21
 BEQ MA21               \ as energy bombs are useless against space stations

 CPY #2*THG             \ If the ship in Y is a Thargoid, jump to BA21 as energy
 BEQ MA21               \ bombs have no effect against Thargoids

 CPY #2*CON             \ If the ship in Y is the Constrictor, jump to BA21
 BCS MA21               \ as energy bombs are useless against the Constrictor
                        \ (the Constrictor is the target of mission 1, and it
                        \ would be too easy if it could just be blown out of
                        \ the sky with a single key press)

 LDA INWK+31            \ If the ship we are checking has bit 5 set in its ship
 AND #%00100000         \ byte #31, then it is already exploding, so jump to
 BNE MA21               \ BA21 as ships can't explode more than once

 ASL INWK+31            \ The energy bomb is killing this ship, so set bit 7 of
 SEC                    \ the ship byte #31 to indicate that it has now been
 ROR INWK+31            \ killed

 LDX TYPE               \ Set X to the type of the ship that was killed so the
                        \ following call to EXNO2 can award us the correct
                        \ number of fractional kill points

 JSR EXNO2              \ Call EXNO2 to process the fact that we have killed a
                        \ ship (so increase the kill tally, make an explosion
                        \ sound and possibly display "RIGHT ON COMMANDER!")

\ ******************************************************************************
\
\       Name: Main flight loop (Part 6 of 16)
\       Type: Subroutine
\   Category: Main loop
\    Summary: For each nearby ship: Move the ship in space and copy the updated
\             INWK data block back to K%
\  Deep dive: Program flow of the main game loop
\             Program flow of the ship-moving routine
\             Ship data blocks
\
\ ------------------------------------------------------------------------------
\
\ The main flight loop covers most of the flight-specific aspects of Elite. This
\ section covers the following:
\
\   * Continue looping through all the ships in the local bubble, and for each
\     one:
\
\     * Move the ship in space
\
\     * Copy the updated ship's data block from INWK back to K%
\
\ ******************************************************************************

.MA21

 JSR MVEIT              \ Call MVEIT to move the ship we are processing in space

                        \ Now that we are done processing this ship, we need to
                        \ copy the ship data back from INWK to the correct place
                        \ in the K% workspace. We already set INF in part 4 to
                        \ point to the ship's data block in K%, so we can simply
                        \ do the reverse of the copy we did before, this time
                        \ copying from INWK to INF

 LDY #NI%-1             \ Set a counter in Y so we can loop through the NI%
                        \ bytes in the ship data block

 BRA MAL3b              \ Port: the loop is unrolled twice; NI% = 37 is odd, so
                        \ enter at the second copy (Y = 36, 34, ... 0 there)

 ASSERT NI% MOD 2 = 1

.MAL3

 LDA INWK,Y             \ Load the Y-th byte of INWK and store it in the Y-th
 STA (INF),Y            \ byte of INF

 DEY                    \ Decrement the loop counter

.MAL3b

 LDA INWK,Y             \ Load the Y-th byte of INWK and store it in the Y-th
 STA (INF),Y            \ byte of INF

 DEY                    \ Decrement the loop counter

 BPL MAL3               \ Loop back for the next byte, until we have copied the
                        \ last byte from INWK back to INF

\ ******************************************************************************
\
\       Name: Main flight loop (Part 7 of 16)
\       Type: Subroutine
\   Category: Main loop
\    Summary: For each nearby ship: Check whether we are docking, scooping or
\             colliding with it
\  Deep dive: Program flow of the main game loop
\
\ ------------------------------------------------------------------------------
\
\ The main flight loop covers most of the flight-specific aspects of Elite. This
\ section covers the following:
\
\   * Continue looping through all the ships in the local bubble, and for each
\     one:
\
\     * Check how close we are to this ship and work out if we are docking,
\       scooping or colliding with it
\
\ ******************************************************************************

 LDA INWK+31            \ Fetch the status of this ship from bits 5 (is ship
 AND #%10100000         \ exploding?) and bit 7 (has ship been killed?) from
                        \ ship byte #31 into A

 JSR MAS4               \ Or this value with x_hi, y_hi and z_hi

 BNE MA65               \ If this value is non-zero, then either the ship is
                        \ far away (i.e. has a non-zero high byte in at least
                        \ one of the three axes), or it is already exploding,
                        \ or has been flagged as being killed - in which case
                        \ jump to MA65 to skip the following, as we can't dock
                        \ scoop or collide with it

 LDA INWK               \ Set A = (x_lo OR y_lo OR z_lo), and if bit 7 of the
 ORA INWK+3             \ result is set, the ship is still a fair distance
 ORA INWK+6             \ away (further than 127 in at least one axis), so jump
 BMI MA65               \ to MA65 to skip the following, as it's too far away to
                        \ dock, scoop or collide with

 LDX TYPE               \ If the current ship type is negative then it's either
 BMI MA65               \ a planet or a sun, so jump down to MA65 to skip the
                        \ following, as we can't dock with it or scoop it

 CPX #SST               \ If this ship is the space station, jump to ISDK to
 BEQ ISDK               \ check whether we are docking with it

 AND #%11000000         \ If bit 6 of (x_lo OR y_lo OR z_lo) is set, then the
 BNE MA65               \ ship is still a reasonable distance away (further than
                        \ 63 in at least one axis), so jump to MA65 to skip the
                        \ following, as it's too far away to dock, scoop or
                        \ collide with

 CPX #MSL               \ If this ship is a missile, jump down to MA65 to skip
 BEQ MA65               \ the following, as we can't scoop or dock with a
                        \ missile, and it has its own dedicated collision
                        \ checks in the TACTICS routine

 LDA BST                \ If we have fuel scoops fitted then BST will be &FF,
                        \ otherwise it will be 0

 AND INWK+5             \ Ship byte #5 contains the y_sign of this ship, so a
                        \ negative value here means the canister is below us,
                        \ which means the result of the AND will be negative if
                        \ the canister is below us and we have a fuel scoop
                        \ fitted

 BPL MA58               \ If the result is positive, then we either have no
                        \ scoop or the canister is above us, and in both cases
                        \ this means we can't scoop the item, so jump to MA58
                        \ to process a collision

\ ******************************************************************************
\
\       Name: Main flight loop (Part 8 of 16)
\       Type: Subroutine
\   Category: Main loop
\    Summary: For each nearby ship: Process us potentially scooping this item
\  Deep dive: Program flow of the main game loop
\
\ ------------------------------------------------------------------------------
\
\ The main flight loop covers most of the flight-specific aspects of Elite. This
\ section covers the following:
\
\   * Continue looping through all the ships in the local bubble, and for each
\     one:
\
\     * Process us potentially scooping this item
\
\ ******************************************************************************

 CPX #OIL               \ If this is a cargo canister, jump to oily to randomly
 BEQ oily               \ decide the canister's contents

 LDY #0                 \ Fetch byte #0 of the ship's blueprint
 LDA (XX0),Y

 LSR A                  \ Shift it right four times, so A now contains the high
 LSR A                  \ nibble (i.e. bits 4-7)
 LSR A
 LSR A

 BEQ MA58               \ If A = 0, jump to MA58 to skip all the docking and
                        \ scooping checks

                        \ Only the Thargon, alloy plate, splinter and escape pod
                        \ have non-zero high nibbles in their blueprint byte #0
                        \ so if we get here, our ship is one of those, and the
                        \ high nibble gives the market item number of the item
                        \ when scooped, less 1

 ADC #1                 \ Add 1 to the high nibble to get the market item
                        \ number

 BNE slvy2              \ Skip to slvy2 so we scoop the ship as a market item

.oily

 JSR DORND              \ Set A and X to random numbers and reduce A to a
 AND #7                 \ random number in the range 0-7

.slvy2

                        \ By the time we get here, we are scooping, and A
                        \ contains the type of item we are scooping (a random
                        \ number 0-7 if we are scooping a cargo canister, 3 if
                        \ we are scooping an escape pod, or 16 if we are
                        \ scooping a Thargon). These numbers correspond to the
                        \ relevant market items (see QQ23 for a list), so a
                        \ cargo canister can contain anything from food to
                        \ computers, while escape pods contain slaves, and
                        \ Thargons become alien items when scooped

 JSR tnpr1              \ Call tnpr1 with the scooped cargo type stored in A
                        \ to work out whether we have room in the hold for one
                        \ tonne of this cargo (A is set to 1 by this call, and
                        \ the C flag contains the result)

 LDY #78                \ This instruction has no effect, so presumably it used
                        \ to do something, but didn't get removed

 BCS MA59               \ If the C flag is set then we have no room in the hold
                        \ for the scooped item, so jump down to MA59 make a
                        \ sound to indicate failure, before destroying the
                        \ canister

 LDY QQ29               \ Scooping was successful, so set Y to the type of
                        \ item we just scooped, which we stored in QQ29 above

 ADC QQ20,Y             \ Add A (which we set to 1 above) to the number of items
 STA QQ20,Y             \ of type Y in the cargo hold, as we just successfully
                        \ scooped one canister of type Y

 TYA                    \ Print recursive token 48 + Y as an in-flight token,
 ADC #208               \ which will be in the range 48 ("FOOD") to 64 ("ALIEN
 JSR MESS               \ ITEMS"), so this prints the scooped item's name

 ASL NEWB               \ The item has now been scooped, so set bit 7 of its
 SEC                    \ NEWB flags to indicate this
 ROR NEWB

.MA65

 JMP MA26               \ If we get here, then the ship we are processing was
                        \ too far away to be scooped, docked or collided with,
                        \ so jump to MA26 to skip over the collision routines
                        \ and move on to missile targeting

\ ******************************************************************************
\
\       Name: Main flight loop (Part 9 of 16)
\       Type: Subroutine
\   Category: Main loop
\    Summary: For each nearby ship: If it is a space station, check whether we
\             are successfully docking with it
\  Deep dive: Program flow of the main game loop
\             Docking checks
\
\ ------------------------------------------------------------------------------
\
\ The main flight loop covers most of the flight-specific aspects of Elite. This
\ section covers the following:
\
\   * Process docking with a space station
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   GOIN                We jump here from part 3 of the main flight loop if the
\                       docking computer is activated by pressing "C"
\
\ ******************************************************************************

.ISDK

 LDA K%+NI%+36          \ 1. Fetch the NEWB flags (byte #36) of the second ship
 AND #%00000100         \ in the ship data workspace at K%, which is reserved
 BNE MA62               \ for the sun or the space station (in this case it's
                        \ the latter), and if bit 2 is set, meaning the station
                        \ is hostile, jump down to MA62 to fail docking (so
                        \ trying to dock at a station that we have annoyed does
                        \ not end well)

 LDA INWK+14            \ 2. If nosev_z_hi < 214, jump down to MA62 to fail
 CMP #214               \ docking, as the angle of approach is greater than 26
 BCC MA62               \ degrees

 JSR SPS1               \ Call SPS1 to calculate the vector to the planet and
                        \ store it in XX15

 LDA XX15+2             \ Set A to the z-axis of the vector

                        \ This version of Elite omits check 3 (which would check
                        \ the sign of the z-axis)

 CMP #89                \ 4. If z-axis < 89, jump to MA62 to fail docking, as
 BCC MA62               \ we are not in the 22.0 degree safe cone of approach

 LDA INWK+16            \ 5. If |roofv_x_hi| < 80, jump to MA62 to fail docking,
 AND #%01111111         \ as the slot is more than 36.6 degrees from horizontal
 CMP #80
 BCC MA62

.GOIN

                        \ If we arrive here, we just docked successfully

\JSR stopbd             \ This instruction is commented out in the original
                        \ source

 JMP DOENTRY            \ Go to the docking bay (i.e. show the ship hangar)

.MA62

                        \ If we arrive here, docking has just failed

 LDA DELTA              \ If the ship's speed is < 5, jump to MA67 to register
 CMP #5                 \ some damage, but not a huge amount
 BCC MA67

 JMP DEATH              \ Otherwise we have just crashed into the station, so
                        \ process our death

\ ******************************************************************************
\
\       Name: Main flight loop (Part 10 of 16)
\       Type: Subroutine
\   Category: Main loop
\    Summary: For each nearby ship: Remove if scooped, or process collisions
\  Deep dive: Program flow of the main game loop
\
\ ------------------------------------------------------------------------------
\
\ The main flight loop covers most of the flight-specific aspects of Elite. This
\ section covers the following:
\
\   * Continue looping through all the ships in the local bubble, and for each
\     one:
\
\     * Remove scooped item after both successful and failed scooping attempts
\
\     * Process collisions
\
\ ******************************************************************************

.MA59

                        \ If we get here then scooping failed

 JSR EXNO3              \ Make the sound of the cargo canister being destroyed
                        \ and fall through into MA60 to remove the canister
                        \ from our local bubble

.MA60

                        \ If we get here then scooping was successful

 ASL INWK+31            \ Set bit 7 of the scooped or destroyed item, to denote
 SEC                    \ that it has been killed and should be removed from
 ROR INWK+31            \ the local bubble

.MA61

 BNE MA26               \ Jump to MA26 to skip over the collision routines and
                        \ to move on to missile targeting (this BNE is
                        \ effectively a JMP as A will never be zero)

.MA67

                        \ If we get here then we have collided with something,
                        \ but not fatally

 LDA #1                 \ Set the speed in DELTA to 1 (i.e. a sudden stop)
 STA DELTA

 LDA #5                 \ Set the amount of damage in A to 5 (a small dent) and
 BNE MA63               \ jump down to MA63 to process the damage (this BNE is
                        \ effectively a JMP as A will never be zero)

.MA58

                        \ If we get here, we have collided with something in a
                        \ potentially fatal way

 ASL INWK+31            \ Set bit 7 of the ship we just collided with, to
 SEC                    \ denote that it has been killed and should be removed
 ROR INWK+31            \ from the local bubble

 LDA INWK+35            \ Load A with the energy level of the ship we just hit

 SEC                    \ Set the amount of damage in A to 128 + A / 2, so
 ROR A                  \ this is quite a big dent, and colliding with higher
                        \ energy ships will cause more damage

.MA63

 JSR OOPS               \ The amount of damage is in A, so call OOPS to reduce
                        \ our shields, and if the shields are gone, there's a
                        \ chance of cargo loss or even death

 JSR EXNO3              \ Make the sound of colliding with the other ship and
                        \ fall through into MA26 to try targeting a missile

\ ******************************************************************************
\
\       Name: Main flight loop (Part 11 of 16)
\       Type: Subroutine
\   Category: Main loop
\    Summary: For each nearby ship: Process missile lock and firing our laser
\  Deep dive: Program flow of the main game loop
\             Flipping axes between space views
\
\ ------------------------------------------------------------------------------
\
\ The main flight loop covers most of the flight-specific aspects of Elite. This
\ section covers the following:
\
\   * Continue looping through all the ships in the local bubble, and for each
\     one:
\
\     * If this is not the front space view, flip the axes of the ship's
\        coordinates in INWK
\
\     * Process missile lock
\
\     * Process our laser firing
\
\ ******************************************************************************

.MA26

 LDA NEWB               \ If bit 7 of the ship's NEWB flags is clear, skip the
 BPL P%+5               \ following instruction

 JSR SCAN               \ Bit 7 of the ship's NEWB flags is set, which means the
                        \ ship has docked or been scooped, so we draw the ship
                        \ on the scanner, which has the effect of removing it

 LDA QQ11               \ If this is not a space view, jump to MA15 to skip
 BNE MA15               \ missile and laser locking

 JSR PLUT               \ Call PLUT to update the geometric axes in INWK to
                        \ match the view (front, rear, left, right)

 JSR HITCH              \ Call HITCH to see if this ship is in the crosshairs,
 BCC MA8                \ in which case the C flag will be set (so if there is
                        \ no missile or laser lock, we jump to MA8 to skip the
                        \ following)

 LDA MSAR               \ We have missile lock, so check whether the leftmost
 BEQ MA47               \ missile is currently armed, and if not, jump to MA47
                        \ to process laser fire, as we can't lock an unarmed
                        \ missile

 JSR BEEP               \ We have missile lock and an armed missile, so call
                        \ the BEEP subroutine to make a short, high beep

 LDX XSAV               \ Call ABORT2 to store the details of this missile
 LDY #RED2              \ lock, with the targeted ship's slot number in X
 JSR ABORT2             \ (which we stored in XSAV at the start of this ship's
                        \ loop at MAL1), and set the colour of the missile
                        \ indicator to the colour in Y (red = &0E)

.MA47

                        \ If we get here then the ship is in our sights, but
                        \ we didn't lock a missile, so let's see if we're
                        \ firing the laser

 LDA LAS                \ If we are firing the laser then LAS will contain the
 BEQ MA8                \ laser power (which we set in MA68 above), so if this
                        \ is zero, jump down to MA8 to skip the following

 LDX #15                \ We are firing our laser and the ship in INWK is in
 JSR EXNO               \ the crosshairs, so call EXNO to make the sound of
                        \ us making a laser strike on another ship

 LDA TYPE               \ Did we just hit the space station? If so, jump to
 CMP #SST               \ MA14+2 to make the station hostile, skipping the
 BEQ MA14+2             \ following as we can't destroy a space station

 CMP #CON               \ If the ship we hit is less than #CON - i.e. it's not
 BCC BURN               \ a Constrictor, Cougar, Dodo station or the Elite logo,
                        \ jump to BURN to skip the following

 LDA LAS                \ Set A to the power of the laser we just used to hit
                        \ the ship (i.e. the laser in the current view)

 CMP #(Armlas AND 127)  \ If the laser is not a military laser, jump to MA14+2
 BNE MA14+2             \ to skip the following, as only military lasers have
                        \ any effect on the Constrictor or Cougar

 LSR LAS                \ Divide the laser power of the current view by 4, so
 LSR LAS                \ the damage inflicted on the super-ship is a quarter of
                        \ the damage our military lasers would inflict on a
                        \ normal ship

.BURN

 LDA INWK+35            \ Fetch the hit ship's energy from byte #35 and subtract
 SEC                    \ our current laser power, and if the result is greater
 SBC LAS                \ than zero, the other ship has survived the hit, so
 BCS MA14               \ jump down to MA14 to make it angry

 ASL INWK+31            \ Set bit 7 of the ship byte #31 to indicate that it has
 SEC                    \ now been killed
 ROR INWK+31

 LDA TYPE               \ Did we just kill an asteroid? If not, jump to nosp,
 CMP #AST               \ otherwise keep going
 BNE nosp

 LDA LAS                \ Did we kill the asteroid using mining lasers? If not,
 CMP #Mlas              \ jump to nosp, otherwise keep going
 BNE nosp

 JSR DORND              \ Set A and X to random numbers

 LDX #SPL               \ Set X to the ship type for a splinter

 AND #3                 \ Reduce the random number in A to the range 0-3

 JSR SPIN2              \ Call SPIN2 to spawn A items of type X (i.e. spawn
                        \ 0-3 splinters)

.nosp

 LDY #PLT               \ Randomly spawn some alloy plates
 JSR SPIN

 LDY #OIL               \ Randomly spawn some cargo canisters
 JSR SPIN

 LDX TYPE               \ Set X to the type of the ship that was killed so the
                        \ following call to EXNO2 can award us the correct
                        \ number of fractional kill points

 JSR EXNO2              \ Call EXNO2 to process the fact that we have killed a
                        \ ship (so increase the kill tally, make an explosion
                        \ sound and so on)

.MA14

 STA INWK+35            \ Store the hit ship's updated energy in ship byte #35

 LDA TYPE               \ Call ANGRY to make the target ship or station hostile,
 JSR ANGRY              \ and if this is a ship, wake up its AI and give it a
                        \ kick of speed

\ ******************************************************************************
\
\       Name: Main flight loop (Part 12 of 16)
\       Type: Subroutine
\   Category: Main loop
\    Summary: For each nearby ship: Draw the ship, remove if killed, loop back
\  Deep dive: Program flow of the main game loop
\             Drawing ships
\
\ ------------------------------------------------------------------------------
\
\ The main flight loop covers most of the flight-specific aspects of Elite. This
\ section covers the following:
\
\   * Continue looping through all the ships in the local bubble, and for each
\     one:
\
\     * Draw the ship
\
\     * Process removal of killed ships
\
\   * Loop back up to MAL1 to move onto the next ship in the local bubble
\
\ ******************************************************************************

.MA8

 JSR LL9                \ Call LL9 to draw the ship we're processing on-screen

.MA15

 LDY #35                \ Fetch the ship's energy from byte #35 and copy it to
 LDA INWK+35            \ byte #35 in INF (so the ship's data in K% gets
 STA (INF),Y            \ updated)

 LDA NEWB               \ If bit 7 of the ship's NEWB flags is set, which means
 BMI KS1S               \ the ship has docked or been scooped, jump to KS1S to
                        \ skip the following, as we can't get a bounty for a
                        \ ship that's no longer around

 LDA INWK+31            \ If bit 7 of the ship's byte #31 is clear, then the
 BPL MAC1               \ ship hasn't been killed by energy bomb, collision or
                        \ laser fire, so jump to MAC1 to skip the following

 AND #%00100000         \ If bit 5 of the ship's byte #31 is clear then the
 BEQ MAC1               \ ship is no longer exploding, so jump to MAC1 to skip
                        \ the following

 LDA NEWB               \ Extract bit 6 of the ship's NEWB flags, so A = 64 if
 AND #%01000000         \ bit 6 is set, or 0 if it is clear. Bit 6 is set if
                        \ this ship is a cop, so A = 64 if we just killed a
                        \ policeman, otherwise it is 0

 ORA FIST               \ Update our FIST flag ("fugitive/innocent status") to
 STA FIST               \ at least the value in A, which will instantly make us
                        \ a fugitive if we just shot the sheriff, but won't
                        \ affect our status if the enemy wasn't a copper

 LDA DLY                \ If we already have an in-flight message on-screen (in
 ORA MJ                 \ which case DLY > 0), or we are in witchspace (in
 BNE KS1S               \ which case MJ > 0), jump to KS1S to skip showing an
                        \ on-screen bounty for this kill

 LDY #10                \ Fetch byte #10 of the ship's blueprint, which is the
 LDA (XX0),Y            \ low byte of the bounty awarded when this ship is
 BEQ KS1S               \ killed (in Cr * 10), and if it's zero jump to KS1S as
                        \ there is no on-screen bounty to display

 TAX                    \ Put the low byte of the bounty into X

 INY                    \ Fetch byte #11 of the ship's blueprint, which is the
 LDA (XX0),Y            \ high byte of the bounty awarded (in Cr * 10), and put
 TAY                    \ it into Y

 JSR MCASH              \ Call MCASH to add (Y X) to the cash pot

 LDA #0                 \ Print control code 0 (current cash, right-aligned to
 JSR MESS               \ width 9, then " CR", newline) as an in-flight message

.KS1S

 JMP KS1                \ Process the killing of this ship (which removes this
                        \ ship from its slot and shuffles all the other ships
                        \ down to close up the gap)

.MAC1

 LDA TYPE               \ If the ship we are processing is a planet or sun,
 BMI MA27               \ jump to MA27 to skip the following two instructions

 JSR FAROF              \ If the ship we are processing is a long way away (its
 BCC KS1S               \ distance in any one direction is > 224, jump to KS1S
                        \ to remove the ship from our local bubble, as it's just
                        \ left the building

.MA27

 LDY #31                \ Fetch the ship's explosion/killed state from byte #31
 LDA INWK+31            \ and copy it to byte #31 in INF (so the ship's data in
 STA (INF),Y            \ K% gets updated)

 LDX XSAV               \ We're done processing this ship, so fetch the ship's
                        \ slot number, which we saved in XSAV back at the start
                        \ of the loop

 INX                    \ Increment the slot number to move on to the next slot

 JMP MAL1               \ And jump back up to the beginning of the loop to get
                        \ the next ship in the local bubble for processing

\ ******************************************************************************
\
\       Name: Main flight loop (Part 13 of 16)
\       Type: Subroutine
\   Category: Main loop
\    Summary: Show energy bomb effect, charge shields and energy banks
\  Deep dive: Program flow of the main game loop
\             Scheduling tasks with the main loop counter
\
\ ------------------------------------------------------------------------------
\
\ The main flight loop covers most of the flight-specific aspects of Elite. This
\ section covers the following:
\
\   * Show energy bomb effect (if applicable)
\
\   * Charge shields and energy banks (every 7 iterations of the main loop)
\
\ ******************************************************************************

.MA18

 LDA BOMB               \ If we set off our energy bomb (see MA24 above), then
 BPL MA77               \ BOMB is now negative, so this skips to MA21 if our
                        \ energy bomb is not going off

 JSR BOMBEFF2           \ Call BOMBEFF2 to erase the energy bomb zig-zag
                        \ lightning bolt that we drew in part 3, make the sound
                        \ of the energy bomb going off, draw a new lightning
                        \ bolt, and repeat the process four times so the bolt
                        \ flashes

 ASL BOMB               \ We set off our energy bomb, so rotate BOMB to the
                        \ left by one place. BOMB was rotated left once already
                        \ during this iteration of the main loop, back at MA24,
                        \ so if this is the first pass it will already be
                        \ %11111110, and this will shift it to %11111100 - so
                        \ if we set off an energy bomb, it stays activated
                        \ (BOMB > 0) for four iterations of the main loop

 BMI MA77               \ If the result has bit 7 set, skip the following
                        \ instruction as the bomb is still going off

 JSR BOMBOFF            \ Our energy bomb has finished going off, so call
                        \ BOMBOFF to draw the zig-zag lightning bolt, which
                        \ erases it from the screen

.MA77

 LDA MCNT               \ Fetch the main loop counter and calculate MCNT mod 8,
 AND #7                 \ jumping to MA22 if it is non-zero (so the following
 BNE MA22               \ code only runs every 8 iterations of the main loop)

 LDX ENERGY             \ Fetch our ship's energy levels and skip to b if bit 7
 BPL b                  \ is not set, i.e. only charge the shields from the
                        \ energy banks if they are at more than 50% charge

 LDX ASH                \ Call SHD to recharge our aft shield and update the
 JSR SHD                \ shield status in ASH
 STX ASH

 LDX FSH                \ Call SHD to recharge our forward shield and update
 JSR SHD                \ the shield status in FSH
 STX FSH

.b

 SEC                    \ Set A = ENERGY + ENGY + 1, so our ship's energy
 LDA ENGY               \ level goes up by 2 if we have an energy unit fitted,
 ADC ENERGY             \ otherwise it goes up by 1

 BCS paen1              \ If the value of A did not overflow (the maximum
 STA ENERGY             \ energy level is &FF), then store A in ENERGY

.paen1

\ ******************************************************************************
\
\       Name: Main flight loop (Part 14 of 16)
\       Type: Subroutine
\   Category: Main loop
\    Summary: Spawn a space station if we are close enough to the planet
\  Deep dive: Program flow of the main game loop
\             Scheduling tasks with the main loop counter
\             Ship data blocks
\             The space station safe zone
\
\ ------------------------------------------------------------------------------
\
\ The main flight loop covers most of the flight-specific aspects of Elite. This
\ section covers the following:
\
\   * Spawn a space station if we are close enough to the planet (every 32
\     iterations of the main loop)
\
\ ******************************************************************************

 LDA MJ                 \ If we are in witchspace, jump down to MA23S to skip
 BNE MA23S              \ the following, as there are no space stations in
                        \ witchspace

 LDA MCNT               \ Fetch the main loop counter and calculate MCNT mod 32,
 AND #31                \ jumping to MA93 if it is on-zero (so the following
 BNE MA93               \ code only runs every 32 iterations of the main loop)

 LDA SSPR               \ If we are inside the space station safe zone, jump to
 BNE MA23S              \ MA23S to skip the following, as we already have a
                        \ space station and don't need another

 TAY                    \ Set Y = A = 0 (A is 0 as we didn't branch with the
                        \ previous BNE instruction)

 JSR MAS2               \ Call MAS2 to calculate the largest distance to the
 BNE MA23S              \ planet in any of the three axes, and if it's
                        \ non-zero, jump to MA23S to skip the following, as we
                        \ are too far from the planet to bump into a space
                        \ station

                        \ We now want to spawn a space station, so first we
                        \ need to set up a ship data block for the station in
                        \ INWK that we can then pass to NWSPS to add a new
                        \ station to our bubble of universe. We do this by
                        \ copying the planet data block from K% to INWK so we
                        \ can work on it, but we only need the first 29 bytes,
                        \ as we don't need to worry about bytes #29 to #35
                        \ for planets (as they don't have rotation counters,
                        \ AI, explosions, missiles, a ship line heap or energy
                        \ levels)

 LDX #28                \ So we set a counter in X to copy 29 bytes from K%+0
                        \ to K%+28

.MAL4

 LDA K%,X               \ Load the X-th byte of K% and store in the X-th byte
 STA INWK,X             \ of the INWK workspace

 DEX                    \ Decrement the loop counter

 BPL MAL4               \ Loop back for the next byte until we have copied the
                        \ first 28 bytes of K% to INWK

                        \ We now check the distance from our ship (at the
                        \ origin) towards the point where we will spawn the
                        \ space station if we are close enough
                        \
                        \ This point is calculated by starting at the planet's
                        \ centre and adding 2 * nosev, which takes us to a point
                        \ above the planet's surface, at an altitude that
                        \ matches the planet's radius
                        \
                        \ This point pitches and rolls around the planet as the
                        \ nosev vector rotates with the planet, and if our ship
                        \ is within a distance of (192 0) from this point in all
                        \ three axes, then we spawn the space station at this
                        \ point, with the station's slot facing towards the
                        \ planet, along the nosev vector
                        \
                        \ This works because in the following, we calculate the
                        \ station's coordinates one axis at a time, and store
                        \ the results in the INWK block, so by the time we have
                        \ calculated and checked all three, the ship data block
                        \ is set up with the correct spawning coordinates

 INX                    \ Set X = 0 (as we ended the above loop with X as &FF)

 LDY #9                 \ Call MAS1 with X = 0, Y = 9 to do the following:
 JSR MAS1               \
                        \   (x_sign x_hi x_lo) += (nosev_x_hi nosev_x_lo) * 2
                        \
                        \   A = |x_sign|

 BNE MA23S              \ If A > 0, jump to MA23S to skip the following, as we
                        \ are too far from the planet in the x-direction to
                        \ bump into a space station

 LDX #3                 \ Call MAS1 with X = 3, Y = 11 to do the following:
 LDY #11                \
 JSR MAS1               \   (y_sign y_hi y_lo) += (nosev_y_hi nosev_y_lo) * 2
                        \
                        \   A = |y_sign|

 BNE MA23S              \ If A > 0, jump to MA23S to skip the following, as we
                        \ are too far from the planet in the y-direction to
                        \ bump into a space station

 LDX #6                 \ Call MAS1 with X = 6, Y = 13 to do the following:
 LDY #13                \
 JSR MAS1               \   (z_sign z_hi z_lo) += (nosev_z_hi nosev_z_lo) * 2
                        \
                        \   A = |z_sign|

 BNE MA23S              \ If A > 0, jump to MA23S to skip the following, as we
                        \ are too far from the planet in the z-direction to
                        \ bump into a space station

 LDA #192               \ Call FAROF2 to compare x_hi, y_hi and z_hi with 192,
 JSR FAROF2             \ which will set the C flag if all three are < 192, or
                        \ clear the C flag if any of them are >= 192

 BCC MA23S              \ Jump to MA23S if any one of x_hi, y_hi or z_hi are
                        \ >= 192 (i.e. they must all be < 192 for us to be near
                        \ enough to the planet to bump into a space station)

 JSR WPLS               \ Call WPLS to remove the sun from the screen, as we
                        \ can't have both the sun and the space station at the
                        \ same time

 JSR NWSPS              \ Add a new space station to our local bubble of
                        \ universe

.MA23S

 JMP MA23               \ Jump to MA23 to skip the following planet and sun
                        \ altitude checks

\ ******************************************************************************
\
\       Name: Main flight loop (Part 15 of 16)
\       Type: Subroutine
\   Category: Main loop
\    Summary: Perform altitude checks with the planet and sun and process fuel
\             scooping if appropriate
\  Deep dive: Program flow of the main game loop
\             Scheduling tasks with the main loop counter
\
\ ------------------------------------------------------------------------------
\
\ The main flight loop covers most of the flight-specific aspects of Elite. This
\ section covers the following:
\
\   * Perform an altitude check with the planet (every 32 iterations of the main
\     loop, on iteration 10 of each 32)
\
\   * Perform an altitude check with the sun and process fuel scooping (every
\     32 iterations of the main loop, on iteration 20 of each 32)
\
\ ******************************************************************************

.MA22

 LDA MJ                 \ If we are in witchspace, jump down to MA23S to skip
 BNE MA23S              \ the following, as there are no planets or suns to
                        \ bump into in witchspace

 LDA MCNT               \ Fetch the main loop counter and calculate MCNT mod 32,
 AND #31                \ which tells us the position of this loop in each block
                        \ of 32 iterations

.MA93

 CMP #10                \ If this is the tenth iteration in this block of 32,
 BNE MA29               \ do the following, otherwise jump to MA29 to skip the
                        \ planet altitude check and move on to the sun distance
                        \ check

 LDA #50                \ If our energy bank status in ENERGY is >= 50, skip
 CMP ENERGY             \ printing the following message (so the message is
 BCC P%+6               \ only shown if our energy is low)

 ASL A                  \ Print recursive token 100 ("ENERGY LOW{beep}") as an
 JSR MESS               \ in-flight message

 LDY #&FF               \ Set our altitude in ALTIT to &FF, the maximum
 STY ALTIT

 INY                    \ Set Y = 0

 JSR m                  \ Call m to calculate the maximum distance to the
                        \ planet in any of the three axes, returned in A

 BNE MA23               \ If A > 0 then we are a fair distance away from the
                        \ planet in at least one axis, so jump to MA23 to skip
                        \ the rest of the altitude check

 JSR MAS3               \ Set A = x_hi^2 + y_hi^2 + z_hi^2, so using Pythagoras
                        \ we now know that A now contains the square of the
                        \ distance between our ship (at the origin) and the
                        \ centre of the planet at (x_hi, y_hi, z_hi)

 BCS MA23               \ If the C flag was set by MAS3, then the result
                        \ overflowed (was greater than &FF) and we are still a
                        \ fair distance from the planet, so jump to MA23 as we
                        \ haven't crashed into the planet

 SBC #36                \ Subtract 37 from x_hi^2 + y_hi^2 + z_hi^2
                        \
                        \ The SBC subtracts 37 as we just passed through a BCS
                        \ so we know the C flag is clear
                        \
                        \ When we do the 3D Pythagoras calculation, we only use
                        \ the high bytes of the coordinates, so that's x_hi,
                        \ y_hi and z_hi and
                        \
                        \ The planet radius is (0 96 0), as defined in the
                        \ PLANET routine, so the high byte is 96
                        \
                        \ When we square the coordinates above and add them,
                        \ the result gets divided by 256 (otherwise the result
                        \ wouldn't fit into one byte), so if we do the same for
                        \ the planet's radius, we get:
                        \
                        \   96 * 96 / 256 = 36
                        \
                        \ So for the planet, the equivalent figure to test the
                        \ sum of the _hi bytes against is 36, so A now contains
                        \ the high byte of our altitude above the planet
                        \ surface, squared, with an extra 1 subtracted so the
                        \ test in the next instruction will ensure we crash
                        \ even if we are exactly one planet radius away

 BCC MA28               \ If A < 0 then jump to MA28 as we have crashed into
                        \ the planet

 STA R                  \ We are getting close to the planet, so we need to
 JSR LL5                \ work out how close. We know from the above that A
                        \ contains our altitude squared, so we store A in R
                        \ and call LL5 to calculate:
                        \
                        \   Q = SQRT(R Q) = SQRT(A Q)
                        \
                        \ Interestingly, Q doesn't appear to be set to 0 for
                        \ this calculation, so presumably this doesn't make a
                        \ difference

 LDA Q                  \ Store the result in ALTIT, our altitude
 STA ALTIT

 BNE MA23               \ If our altitude is non-zero then we haven't crashed,
                        \ so jump to MA23 to skip to the next section

.MA28

 JMP DEATH              \ If we get here then we just crashed into the planet
                        \ or got too close to the sun, so jump to DEATH to start
                        \ the funeral preparations and return from the main
                        \ flight loop using a tail call

.MA29

 CMP #15                \ If this is the 15th iteration in this block of 32,
 BNE MA33               \ do the following, otherwise jump to MA33 to skip the
                        \ docking computer manoeuvring

 LDA auto               \ If auto is zero, then the docking computer is not
 BEQ MA23               \ activated, so jump to MA23 to skip to the next
                        \ section

 LDA #123               \ Set A = 123 and jump down to MA34 to print token 123
 BNE MA34               \ ("DOCKING COMPUTERS ON") as an in-flight message

.MA33

 CMP #20                \ If this is the 20th iteration in this block of 32,
 BNE MA23               \ do the following, otherwise jump to MA23 to skip the
                        \ sun altitude check

 LDA #30                \ Set CABTMP to 30, the cabin temperature in deep space
 STA CABTMP             \ (i.e. one notch on the dashboard bar)

 LDA SSPR               \ If we are inside the space station safe zone, jump to
 BNE MA23               \ MA23 to skip the following, as we can't have both the
                        \ sun and space station at the same time, so we clearly
                        \ can't be flying near the sun

 LDY #NI%               \ Set Y to NI%, which is the offset in K% for the sun's
                        \ data block, as the second block at K% is reserved for
                        \ the sun (or space station)

 JSR MAS2               \ Call MAS2 to calculate the largest distance to the
 BNE MA23               \ sun in any of the three axes, and if it's non-zero,
                        \ jump to MA23 to skip the following, as we are too far
                        \ from the sun for scooping or temperature changes

 JSR MAS3               \ Set (A ?) = x_hi^2 + y_hi^2 + z_hi^2, so using
                        \ Pythagoras we now know that A now contains the high
                        \ byte of the square of the distance between our ship
                        \ (at the origin) and the heart of the sun at coordinate
                        \ (x_hi, y_hi, z_hi)
                        \
                        \ If the calculation overflows so it doesn't fit into
                        \ one byte, then A is set to &FF and the C flag is set

 EOR #%11111111         \ Invert A, so A is now small if we are far from the
                        \ sun and large if we are close to the sun, in the
                        \ range 0 = far away to &FF = extremely close, ouch,
                        \ hot, hot, hot!

 ADC #30                \ Add the minimum cabin temperature of 30, plus the C
                        \ flag, so we get one of the following:
                        \
                        \   * If the MAS3 calculation overflowed then we are a
                        \     long way from the sun, A will be zero and the C
                        \     flag will be set, so this addition sets A = 31
                        \     and clears the C flag
                        \
                        \   * If the result of the MAS3 calculation fitted into
                        \     one byte, then A will be in the range 0 to 255 and
                        \     the C flag will be clear, so this addition has a
                        \     result in the range 0 to 285, with the higher
                        \     values overflowing the addition and setting the
                        \     C flag
                        \
                        \ So the C flag is set if the cabin temperature is too
                        \ hot to handle, and if it's clear then A contains the
                        \ cabin temperature

 STA CABTMP             \ Store the updated cabin temperature

 BCS MA28               \ If the C flag is set then jump to MA28 to die, as
                        \ our temperature is off the scale

 CMP #224               \ If the cabin temperature < 224 then jump to MA23 to
 BCC MA23               \ skip fuel scooping, as we aren't close enough

\CMP #&F0               \ These instructions are commented out in the original
\BCC nokilltr           \ source
\
\LDA #5
\JSR SETL1
\
\LDA VIC+&15
\AND #&3
\STA VIC+&15
\
\LDA #4
\JSR SETL1
\
\LSR TRIBBLE+1
\ROR TRIBBLE
\
\.nokilltr

 LDA BST                \ If we don't have fuel scoops fitted, jump to BA23 to
 BEQ MA23               \ skip fuel scooping, as we can't scoop without fuel
                        \ scoops

 LDA DELT4+1            \ We are now successfully fuel scooping, so it's time
 LSR A                  \ to work out how much fuel we're scooping. Fetch the
                        \ high byte of DELT4, which contains our current speed
                        \ divided by 4, and halve it to get our current speed
                        \ divided by 8 (so it's now a value between 1 and 5, as
                        \ our speed is normally between 1 and 40). This gives
                        \ us the amount of fuel that's being scooped in A, so
                        \ the faster we go, the more fuel we scoop, and because
                        \ the fuel levels are stored as 10 * the fuel in light
                        \ years, that means we just scooped between 0.1 and 0.5
                        \ light years of free fuel

 ADC QQ14               \ Set A = A + the current fuel level * 10 (from QQ14)

 CMP #70                \ If A > 70 then set A = 70 (as 70 is the maximum fuel
 BCC P%+4               \ level, or 7.0 light years)
 LDA #70

 STA QQ14               \ Store the updated fuel level in QQ14

 LDA #160               \ Set A to token 160 ("FUEL SCOOPS ON")

.MA34

 JSR MESS               \ Print the token in A as an in-flight message

\ ******************************************************************************
\
\       Name: Main flight loop (Part 16 of 16)
\       Type: Subroutine
\   Category: Main loop
\    Summary: Process laser pulsing, E.C.M. energy drain, call stardust routine
\  Deep dive: Program flow of the main game loop
\
\ ------------------------------------------------------------------------------
\
\ The main flight loop covers most of the flight-specific aspects of Elite. This
\ section covers the following:
\
\   * Process laser pulsing
\
\   * Process E.C.M. energy drain
\
\   * Jump to the stardust routine if we are in a space view
\
\   * Return from the main flight loop
\
\ ******************************************************************************

.MA23

 LDA LAS2               \ If the current view has no laser, jump to MA16 to skip
 BEQ MA16               \ the following

 LDA LASCT              \ If LASCT >= 8, jump to MA16 to skip the following, so
 CMP #8                 \ for a pulse laser with a LASCT between 8 and 10, the
 BCS MA16               \ laser stays on, but for a LASCT of 7 or less it gets
                        \ turned off and stays off until LASCT reaches zero and
                        \ the next pulse can start (if the fire button is still
                        \ being pressed)
                        \
                        \ For pulse lasers, LASCT gets set to 10 in ma1 above,
                        \ and it decrements every vertical sync (50 times a
                        \ second), so this means it pulses five times a second,
                        \ with the laser being on for the first 3/10 of each
                        \ pulse and off for the rest of the pulse
                        \
                        \ If this is a beam laser, LASCT is 0 so we always keep
                        \ going here. This means the laser doesn't pulse, but it
                        \ does get drawn and removed every cycle, in a slightly
                        \ different place each time, so the beams still flicker
                        \ around the screen

 JSR LASLI2             \ Redraw the existing laser lines, which has the effect
                        \ of removing them from the screen

 LDA #0                 \ Set LAS2 to 0 so if this is a pulse laser, it will
 STA LAS2               \ skip over the above until the next pulse (this has no
                        \ effect if this is a beam laser)

.MA16

 LDA ECMP               \ If our E.C.M is not on, skip to MA69, otherwise keep
 BEQ MA69               \ going to drain some energy

 JSR DENGY              \ Call DENGY to deplete our energy banks by 1

 BEQ MA70               \ If we have no energy left, jump to MA70 to turn our
                        \ E.C.M. off

.MA69

 LDA ECMA               \ If an E.C.M is going off (ours or an opponent's) then
 BEQ MA66               \ keep going, otherwise skip to MA66

 LDY #soecm             \ Call the NOISE routine with Y = 7 to make the sound of
 JSR NOISE              \ the E.C.M.

 DEC ECMA               \ Decrement the E.C.M. countdown timer, and if it has
 BNE MA66               \ reached zero, keep going, otherwise skip to MA66

.MA70

 JSR ECMOF              \ If we get here then either we have either run out of
                        \ energy, or the E.C.M. timer has run down, so switch
                        \ off the E.C.M.

.MA66

 LDA QQ11               \ If this is not a space view (i.e. QQ11 is non-zero)
 BNE oh                 \ then jump to oh to return from the main flight loop
                        \ (as oh is an RTS)

 JMP STARS              \ This is a space view, so jump to the STARS routine to
                        \ process the stardust, and return from the main flight
                        \ loop using a tail call

\JMP PBFL               \ This instruction is commented out in the original
                        \ source

\ ******************************************************************************
\
\       Name: SPIN
\       Type: Subroutine
\   Category: Universe
\    Summary: Randomly spawn cargo from a destroyed ship
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   Y                   The type of cargo to consider spawning (typically #PLT
\                       or #OIL)
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   oh                  Contains an RTS
\
\   SPIN2               Remove any randomness: spawn cargo of a specific type
\                       (given in X), and always spawn the number given in A
\
\ ******************************************************************************

.SPIN

 JSR DORND              \ Fetch a random number, and jump to oh if it is
 BPL oh                 \ positive (50% chance)

 TYA                    \ Copy the cargo type from Y into A and X
 TAX

 LDY #0                 \ Fetch the first byte of the hit ship's blueprint,
 AND (XX0),Y            \ which determines the maximum number of bits of
                        \ debris shown when the ship is destroyed, and AND
                        \ with the random number we just fetched

 AND #15                \ Reduce the random number in A to the range 0-15

.SPIN2

 STA CNT                \ Store the result in CNT, so CNT contains a random
                        \ number between 0 and the maximum number of bits of
                        \ debris that this ship will release when destroyed
                        \ (to a maximum of 15 bits of debris)

.spl

 BEQ oh                 \ We're going to go round a loop using CNT as a counter
                        \ so this checks whether the counter is zero and jumps
                        \ to oh when it gets there (which might be straight
                        \ away)

 LDA #0                 \ Call SFS1 to spawn the specified cargo from the now
 JSR SFS1               \ deceased parent ship, giving the spawned canister an
                        \ AI flag of 0 (no AI, zero aggression, no E.C.M.)

 DEC CNT                \ Decrease the loop counter

 BNE spl+2              \ Jump back up to the LDA &0 instruction above (this BPL
                        \ is effectively a JMP as CNT will never be negative)

.oh

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: BOMBOFF
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw the zig-zag lightning bolt for the energy bomb
\
\ ******************************************************************************

.BOMBOFF

 LDA #CYAN              \ Change the current colour to cyan
 STA COL

 LDA QQ11               \ If the current view is non-zero (i.e. not a space
 BNE BOMBR1             \ view), return from the subroutine (as BOMBR1 contains
                        \ an RTS)

 JSR H_BOMB             \ Port: a new bolt for the renderer (gfx-hooks.asm)

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

 JSR H_LLINE            \ Draw a line from (X1, Y1) to (X2, Y2) (Port: recorded
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

.BOMBEFF2

 JSR P%+3               \ This pair of JSRs runs the following code four times
 JSR BOMBEFF

.BOMBEFF

 LDY #sobomb            \ Call the NOISE routine with Y = 6 to make the sound of
 JSR NOISE              \ an energy bomb going off

 JSR BOMBOFF            \ Our energy bomb is going off, so call BOMBOFF to draw
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

.BOMBON

 LDY #0                 \ We first need to generate 10 random coordinates for a
                        \ zig-zag lightning bolt, with the x-coordinates in the
                        \ table at BOMBTBX and the y-coordinates in the table at
                        \ BOMBTBY, so set a counter in Y as an index to point at
                        \ each coordinate as we create them
                        \
                        \ Note that we generate the points from right to left,
                        \ so that's high x-coordinate to low x-coordinate

.BOMBL2

 JSR DORND              \ Set A and X to random numbers and reduce A to a
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

 BCS BOMBOFF            \ Call BOMBOFF to draw the newly generated zig-zag
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

\ ******************************************************************************
\
\       Name: BOMBTBX
\       Type: Variable
\   Category: Drawing lines
\    Summary: This is where we store the x-coordinates for the energy bomb's
\             zig-zag lightning bolt
\
\ ******************************************************************************

.BOMBTBX

 SKIP 10

\ ******************************************************************************
\
\       Name: BOMBTBY
\       Type: Variable
\   Category: Drawing lines
\    Summary: This is where we store the y-coordinates for the energy bomb's
\             zig-zag lightning bolt
\
\ ******************************************************************************

.BOMBTBY

 SKIP 10

\ ******************************************************************************
\
\       Name: NA%
\       Type: Variable
\   Category: Save and load
\    Summary: The data block for the last saved commander
\
\ ******************************************************************************

 EQUS ":0.E."           \ The drive part of this string (the "0") is updated
                        \ with the chosen drive in the GTNMEW routine, but the
                        \ directory part (the "E") is fixed. The variable is
                        \ followed directly by the commander file at NA%, which
                        \ starts with the commander name, so the full string at
                        \ NA%-5 is in the format ":0.E.jameson", which gives the
                        \ full filename of the commander file

.NA%

 EQUS "jameson"         \ The current commander name
 EQUB 13

 SKIP 53                \ Placeholders for bytes #0 to #52

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

 SKIP 3                 \ Placeholders for bytes #70 to #72

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

.CHK2

 EQUB 0                 \ Placeholder for the checksum in byte #74

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

.CHK

 EQUB 0                 \ Placeholder for the checksum in byte #75

\.CHK3                  \ These instructions are commented out in the original
\                       \ source
\EQUB 0

 SKIP 12                \ These bytes appear to be unused, though the first byte
                        \ in this block is included in the commander file (it
                        \ has no effect, as it's the third checksum byte from
                        \ the Commodore 64 version, which isn't used in the
                        \ Master version)

\ ******************************************************************************
\
\       Name: S1%
\       Type: Variable
\   Category: Save and load
\    Summary: The drive and directory number used when saving or loading a
\             commander file
\  Deep dive: Commander save files
\
\ ******************************************************************************

.S1%

 EQUS ":0.E."

\ ******************************************************************************
\
\       Name: NA2%
\       Type: Variable
\   Category: Save and load
\    Summary: The data block for the default commander
\  Deep dive: Commander save files
\             The competition code
\
\ ------------------------------------------------------------------------------
\
\ Contains the default commander data, with the name at NA% and the data at
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

.NA2%

 EQUS "JAMESON"         \ The current commander name, which defaults to JAMESON
 EQUB 13                \
                        \ The commander name can be up to seven characters (the
                        \ DFS limit for filenames), and is terminated by a
                        \ carriage return

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

IF Q%
 EQUD &00CA9A3B         \ CASH = Amount of cash (100,000,000 Cr), #9-12
ELSE
 EQUD &E8030000         \ CASH = Amount of cash (100 Cr), #9-12
ENDIF

 EQUB 70                \ QQ14 = Fuel level, #13

 EQUB %10000000 AND Q%  \ COK = Competition flags, #14

 EQUB 0                 \ GCNT = Galaxy number, 0-7, #15

IF Q%
 EQUB Armlas            \ LASER = Front laser, #16
ELSE
 EQUB POW               \ LASER = Front laser, #16
ENDIF

 EQUB POW AND Q%        \ LASER = Rear laser, #16

 EQUB (POW+128) AND Q%  \ LASER+2 = Left laser, #18

 EQUB Mlas AND Q%       \ LASER+3 = Right laser, #19

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

 EQUB Q% AND 1          \ ENGY = Energy/shield level, #43

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

 EQUW 20000 AND Q%      \ TALLY = Number of kills, #71-72

 EQUB 128               \ SVC = Save count, #73

\.CHK2                  \ This label is commented out in the original source

 EQUB &AA               \ The CHK2 checksum value for the default commander

\.CHK3                  \ These instructions are commented out in the original
\                       \ source
\EQUB CH3X%

\.CHK                   \ This label is commented out in the original source

 EQUB &03               \ The CHK checksum value for the default commander

 SKIP 12                \ These bytes appear to be unused, though the first byte
                        \ in this block is included in the commander file (it
                        \ has no effect, as it's the third checksum byte from
                        \ the Commodore 64 version, which isn't used in the
                        \ Master version)

.NAEND%

 SKIP 4                 \ These bytes appear to be unused

\ ******************************************************************************

 PRINT "ELITE A"
 PRINT "Assembled at ", ~(NA%-5)
 PRINT "Ends at ", ~P%
 PRINT "Code size is ", ~(P% - (NA%-5))
 PRINT "Execute at ", ~LOAD%
 PRINT "Reload at ", ~LOAD_A%

 PRINT "S.ELTA ", ~(NA%-5), " ", ~P%, " ", ~LOAD%, " ", ~LOAD_A%
\SAVE "build/ELTA.bin", (NA%-5), P%, LOAD%

\ ******************************************************************************
\
\ ELITE B FILE
\
\ ******************************************************************************

 CODE_B% = P%

 LOAD_B% = LOAD% + P% - CODE%

\ ******************************************************************************
\
\       Name: UNIV
\       Type: Variable
\   Category: Universe
\    Summary: Table of pointers to the local universe's ship data blocks
\  Deep dive: The local bubble of universe
\             Ship data blocks
\
\ ******************************************************************************

.UNIV

 FOR I%, 0, NOSH

  EQUW K% + I% * NI%    \ Address of block no. I%, of size NI%, in workspace K%

 NEXT

\ ******************************************************************************
\
\       Name: BLINE
\       Type: Subroutine
\   Category: Drawing circles
\    Summary: Draw a circle segment and add it to the ball line heap
\  Deep dive: The ball line heap
\             Drawing circles
\
\ ------------------------------------------------------------------------------
\
\ Draw a single segment of a circle, adding the point to the ball line heap.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   CNT                 The number of this segment
\
\   STP                 The step size for the circle
\
\   K6(1 0)             The x-coordinate of the new point on the circle, as
\                       a screen coordinate
\
\   (T X)               The y-coordinate of the new point on the circle, as
\                       an offset from the centre of the circle
\
\   FLAG                Set to &FF for the first call, so it sets up the first
\                       point in the heap but waits until the second call before
\                       drawing anything (as we need two points, i.e. two calls,
\                       before we can draw a line)
\
\   K4(1 0)             Pixel y-coordinate of the centre of the circle
\
\   K5(1 0)             Screen x-coordinate of the previous point added to the
\                       ball line heap (if this is not the first point)
\
\   K5(3 2)             Screen y-coordinate of the previous point added to the
\                       ball line heap (if this is not the first point)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   CNT                 CNT is updated to CNT + STP
\
\   A                   The new value of CNT
\
\   K5(1 0)             Screen x-coordinate of the point that we just added to
\                       the ball line heap
\
\   K5(3 2)             Screen y-coordinate of the point that we just added to
\                       the ball line heap
\
\   FLAG                Set to 0
\
\ ******************************************************************************

.BLINE

 TXA                    \ Set K6(3 2) = (T X) + K4(1 0)
 ADC K4                 \             = y-coord of centre + y-coord of new point
 STA K6+2               \
 STA XX12               \ Port: also set XX12 = y_lo of new point for LL145
 LDA K4+1               \ so K6(3 2) now contains the y-coordinate of the new
 ADC T                  \ point on the circle but as a screen coordinate, to go
 STA K6+3               \ along with the screen x-coordinate in K6(1 0)
 STA XX12+1             \ Port: also set XX12+1 = y_hi (H_BPT keeps XX12)

 JSR H_BPT              \ Port: in record mode, record the point K6 for the
                        \ renderer (gfx-hooks.asm; X, Y and C preserved)

 LDA FLAG               \ If FLAG = 0, jump down to BL1
 BEQ BL1

 INC FLAG               \ Flag is &FF so this is the first call to BLINE, so
                        \ increment FLAG to set it to 0, as then the next time
                        \ we call BLINE it can draw the first line, from this
                        \ point to the next

.BL5

                        \ The following inserts a &FF marker into the LSY2 line
                        \ heap to indicate that the next call to BLINE should
                        \ store both the (X1, Y1) and (X2, Y2) points. We do
                        \ this on the very first call to BLINE (when FLAG is
                        \ &FF), and on subsequent calls if the segment does not
                        \ fit on-screen, in which case we don't draw or store
                        \ that segment, and we start a new segment with the next
                        \ call to BLINE that does fit on-screen

 LDY LSP                \ If byte LSP-1 of LSY2 = &FF, jump to BL7 to tidy up
 LDA #&FF               \ and return from the subroutine, as the point that has
 CMP LSY2-1,Y           \ been passed to BLINE is the start of a segment, so all
 BEQ BL7                \ we need to do is save the coordinate in K5, without
                        \ moving the pointer in LSP

 STA LSY2,Y             \ Otherwise we just tried to plot a segment but it
                        \ didn't fit on-screen, so put the &FF marker into the
                        \ heap for this point, so the next call to BLINE starts
                        \ a new segment

 INC LSP                \ Increment LSP to point to the next point in the heap

 BNE BL7                \ Jump to BL7 to tidy up and return from the subroutine
                        \ (this BNE is effectively a JMP, as LSP will never be
                        \ zero)

.BL1

 LDA K5                 \ Set XX15 = K5 = x_lo of previous point
 STA XX15

 LDA K5+1               \ Set XX15+1 = K5+1 = x_hi of previous point
 STA XX15+1

 LDA K5+2               \ Set XX15+2 = K5+2 = y_lo of previous point
 STA XX15+2

 LDA K5+3               \ Set XX15+3 = K5+3 = y_hi of previous point
 STA XX15+3

 LDA K6                 \ Set XX15+4 = x_lo of new point
 STA XX15+4

 LDA K6+1               \ Set XX15+5 = x_hi of new point
 STA XX15+5

                        \ XX12(1 0) = K6(3 2) = y of new point was set above

 JSR LL145              \ Call LL145 to see if the new line segment needs to be
                        \ clipped to fit on-screen, returning the clipped line's
                        \ end-points in (X1, Y1) and (X2, Y2)

 BCS BL5                \ If the C flag is set then the line is not visible on
                        \ screen anyway, so jump to BL5, to avoid drawing and
                        \ storing this line

 LDA SWAP               \ If SWAP = 0, then we didn't have to swap the line
 BEQ BL9                \ coordinates around during the clipping process, so
                        \ jump to BL9 to skip the following swap

 LDA X1                 \ Otherwise the coordinates were swapped by the call to
 LDY X2                 \ LL145 above, so we swap (X1, Y1) and (X2, Y2) back
 STA X2                 \ again
 STY X1
 LDA Y1
 LDY Y2
 STA Y2
 STY Y1

.BL9

 LDY LSP                \ Set Y = LSP

 LDA LSY2-1,Y           \ If byte LSP-1 of LSY2 is not &FF, jump down to BL8
 CMP #&FF               \ to skip the following (X1, Y1) code
 BNE BL8

                        \ Byte LSP-1 of LSY2 is &FF, which indicates that we
                        \ need to store (X1, Y1) in the heap

 LDA X1                 \ Store X1 in the LSP-th byte of LSX2
 STA LSX2,Y

 LDA Y1                 \ Store Y1 in the LSP-th byte of LSY2
 STA LSY2,Y

 INY                    \ Increment Y to point to the next byte in LSX2/LSY2

.BL8

 LDA X2                 \ Store X2 in the LSP-th byte of LSX2
 STA LSX2,Y

 LDA Y2                 \ Store Y2 in the LSP-th byte of LSX2
 STA LSY2,Y

 INY                    \ Increment Y to point to the next byte in LSX2/LSY2

 STY LSP                \ Update LSP to point to the same as Y

 LDA QQ11               \ Draw a line from (X1, Y1) to (X2, Y2), but only when
 ORA GFORCE             \ not in record mode (Port: H_BLOIN inlined, with the
 BNE BL10               \ LOIN call out of line below)

.BL11

 LDA XX13               \ If XX13 is non-zero, jump up to BL5 to add a &FF
 BNE BL5                \ marker to the end of the line heap. XX13 is non-zero
                        \ after the call to the clipping routine LL145 above if
                        \ the end of the line was clipped, meaning the next line
                        \ sent to BLINE can't join onto the end but has to start
                        \ a new segment, and that's what inserting the &FF
                        \ marker does

.BL7

 LDA K6                 \ Copy the data for this step point from K6(3 2 1 0)
 STA K5                 \ into K5(3 2 1 0), for use in the next call to BLINE:
 LDA K6+1               \
 STA K5+1               \   * K5(1 0) = screen x-coordinate of this point
 LDA K6+2               \
 STA K5+2               \   * K5(3 2) = screen y-coordinate of this point
 LDA K6+3               \
 STA K5+3               \ They now become the "previous point" in the next call

 LDA CNT                \ Set CNT = CNT + STP
 CLC
 ADC STP
 STA CNT

 RTS                    \ Return from the subroutine

.BL10

 JSR LOIN               \ Not in record mode: draw the line, then rejoin above
 BRA BL11

\ ******************************************************************************
\
\       Name: FLIP
\       Type: Subroutine
\   Category: Stardust
\    Summary: Reflect the stardust particles in the screen diagonal and redraw
\             the stardust field
\
\ ------------------------------------------------------------------------------
\
\ Swap the x- and y-coordinates of all the stardust particles and draw the new
\ set of particles. Called by LOOK1 when we switch views.
\
\ This is a quick way of making the stardust field in the new view feel
\ different without having to generate a whole new field. If you look carefully
\ at the stardust field when you switch views, you can just about see that the
\ new field is a reflection of the previous field in the screen diagonal, i.e.
\ in the line from bottom left to top right. This is the line where x = y when
\ the origin is in the middle of the screen, and positive x and y are right and
\ up, which is the coordinate system we use for stardust).
\
\ ******************************************************************************

.FLIP

 LDA #DUST              \ Switch to stripe 3-2-3-2, which is cyan/red in the
 STA COL                \ space view

 LDY NOSTM              \ Set Y to the current number of stardust particles, so
                        \ we can use it as a counter through all the stardust

.FLL1

 LDX SY,Y               \ Copy the Y-th particle's y-coordinate from SY+Y into X

 LDA SX,Y               \ Copy the Y-th particle's x-coordinate from SX+Y into
 STA Y1                 \ both Y1 and the particle's y-coordinate
 STA SY,Y

 TXA                    \ Copy the Y-th particle's original y-coordinate into
 STA X1                 \ both X1 and the particle's x-coordinate, so the x- and
 STA SX,Y               \ y-coordinates are now swapped and (X1, Y1) contains
                        \ the particle's new coordinates

 LDA SZ,Y               \ Fetch the Y-th particle's distance from SZ+Y into ZZ
 STA ZZ

 JSR PIXEL2             \ Draw a stardust particle at (X1,Y1) with distance ZZ

 DEY                    \ Decrement the counter to point to the next particle of
                        \ stardust

 BNE FLL1               \ Loop back to FLL1 until we have moved all the stardust
                        \ particles

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: STARS
\       Type: Subroutine
\   Category: Stardust
\    Summary: The main routine for processing the stardust
\
\ ------------------------------------------------------------------------------
\
\ Called at the very end of the main flight loop.
\
\ ******************************************************************************

.STARS

 LDA #DUST              \ Switch to stripe 3-2-3-2, which is cyan/red in the
 STA COL                \ space view

 LDX VIEW               \ Load the current view into X:
                        \
                        \   0 = front
                        \   1 = rear
                        \   2 = left
                        \   3 = right

 BEQ STARS1             \ If this is view 0, jump to STARS1 to process the
                        \ stardust for the front view

 DEX                    \ If this is view 2 or 3, jump to STARS2 (via ST11) to
 BNE ST11               \ process the stardust for the left or right views

 JMP STARS6             \ Otherwise this is the rear view, so jump to STARS6 to
                        \ process the stardust for the rear view

.ST11

 JMP STARS2             \ Jump to STARS2 for the left or right views, as it's
                        \ too far for the branch instruction above

\ ******************************************************************************
\
\       Name: STARS1
\       Type: Subroutine
\   Category: Stardust
\    Summary: Process the stardust for the front view
\  Deep dive: Stardust in the front view
\
\ ------------------------------------------------------------------------------
\
\ This moves the stardust towards us according to our speed (so the dust rushes
\ past us), and applies our current pitch and roll to each particle of dust, so
\ the stardust moves correctly when we steer our ship.
\
\ When a stardust particle rushes past us and falls off the side of the screen,
\ its memory is recycled as a new particle that's positioned randomly on-screen.
\
\ These are the calculations referred to in the commentary:
\
\   1. q = 64 * speed / z_hi
\   2. z = z - speed * 64
\   3. y = y + |y_hi| * q
\   4. x = x + |x_hi| * q
\
\   5. y = y + alpha * x / 256
\   6. x = x - alpha * y / 256
\
\   7. x = x + 2 * (beta * y / 256) ^ 2
\   8. y = y - beta * 256
\
\ For more information see the associated deep dive.
\
\ ******************************************************************************

.STARS1

 LDY NOSTM              \ Set Y to the current number of stardust particles, so
                        \ we can use it as a counter through all the stardust

                        \ In the following, we're going to refer to the 16-bit
                        \ space coordinates of the current particle of stardust
                        \ (i.e. the Y-th particle) like this:
                        \
                        \   x = (x_hi x_lo)
                        \   y = (y_hi y_lo)
                        \   z = (z_hi z_lo)
                        \
                        \ These values are stored in (SX+Y SXL+Y), (SY+Y SYL+Y)
                        \ and (SZ+Y SZL+Y) respectively

.STL1

 JSR DV42               \ Call DV42 to set the following:
                        \
                        \   (P R) = 256 * DELTA / z_hi
                        \         = 256 * speed / z_hi
                        \
                        \ The maximum value returned is P = 2 and R = 128 (see
                        \ DV42 for an explanation)

                        \ DV42 returns with A = R (both exits of its inlined
                        \ LL28+4 tail do STA R just before RTS), so now:
                        \
                        \   (P A) = 256 * speed / z_hi

 LSR P                  \ Rotate (P A) right by 2 places, which sets P = 0 (as P
 ROR A                  \ has a maximum value of 2) and leaves:
 LSR P                  \
 ROR A                  \   A = 64 * speed / z_hi

 ORA #1                 \ Make sure A is at least 1, and store it in Q, so we
 STA Q                  \ now have result 1 above:
                        \
                        \   Q = 64 * speed / z_hi

 LDA SZL,Y              \ We now calculate the following:
 SBC DELT4              \
 STA SZL,Y              \  (z_hi z_lo) = (z_hi z_lo) - DELT4(1 0)
                        \
                        \ starting with the low bytes

 LDA SZ,Y               \ And then we do the high bytes
 STA ZZ                 \
 SBC DELT4+1            \ We also set ZZ to the original value of z_hi, which we
 STA SZ,Y               \ use below to remove the existing particle
                        \
                        \ So now we have result 2 above:
                        \
                        \   z = z - DELT4(1 0)
                        \     = z - speed * 64

 JSR MLU1               \ Call MLU1 to set:
                        \
                        \   Y1 = y_hi
                        \
                        \   (A P) = |y_hi| * Q
                        \
                        \ So Y1 contains the original value of y_hi, which we
                        \ use below to remove the existing particle

                        \ We now calculate:
                        \
                        \   (S R) = YY(1 0) = (A P) + y

 TAX                    \ First we do the low bytes with:
 LDA P                  \
 ADC SYL,Y              \   X = A (temporarily; MLU2 below resets X)
 STA R                  \   R = P + y_lo
                        \
                        \ so we get this:
                        \
                        \   (? R) = (A P) + y_lo
                        \
                        \ (YY(1 0) is not written here, as it is overwritten
                        \ by STA YY+1 / STX YY after the ADD below before it
                        \ is ever read)

 TXA                    \ And then we do the high bytes with:
 ADC Y1                 \
 STA S                  \   S = y_hi + X
                        \ so we get our result:
                        \
                        \   (S R) = YY(1 0) = (A P) + (y_hi y_lo)
                        \                   = |y_hi| * Q + y
                        \
                        \ which is result 3 above, and (S R) is set to the new
                        \ value of y

 LDA SX,Y               \ Set X1 = A = x_hi
 STA X1                 \
                        \ So X1 contains the original value of x_hi, which we
                        \ use below to remove the existing particle

 JSR MLU2               \ Set (A P) = |x_hi| * Q

                        \ We now calculate:
                        \
                        \   XX(1 0) = (A P) + x

 STA XX+1               \ First we do the low bytes:
 LDA P                  \
 ADC SXL,Y              \   XX(1 0) = (A P) + x_lo
 STA XX

 LDA X1                 \ And then we do the high bytes:
 ADC XX+1               \
 STA XX+1               \   XX(1 0) = XX(1 0) + (x_hi 0)
                        \
                        \ so we get our result:
                        \
                        \   XX(1 0) = (A P) + x
                        \           = |x_hi| * Q + x
                        \
                        \ which is result 4 above, and we also have:
                        \
                        \   A = XX+1 = (|x_hi| * Q + x) / 256
                        \
                        \ i.e. A is the new value of x, divided by 256

 EOR ALP2+1             \ EOR with the flipped sign of the roll angle alpha, so
                        \ A has the opposite sign to the flipped roll angle
                        \ alpha, i.e. it gets the same sign as alpha

 JSR MLS1               \ Call MLS1 to calculate:
                        \
                        \   (A P) = A * ALP1
                        \         = (x / 256) * alpha

 JSR ADD                \ Call ADD to calculate:
                        \
                        \   (A X) = (A P) + (S R)
                        \         = (x / 256) * alpha + y
                        \         = y + alpha * x / 256

 STA YY+1               \ Set YY(1 0) = (A X) to give:
 STX YY                 \
                        \   YY(1 0) = y + alpha * x / 256
                        \
                        \ which is result 5 above, and we also have:
                        \
                        \   A = YY+1 = y + alpha * x / 256
                        \
                        \ i.e. A is the new value of y, divided by 256

 EOR ALP2               \ EOR A with the correct sign of the roll angle alpha,
                        \ so A has the opposite sign to the roll angle alpha

 JSR MLS2               \ Call MLS2 to calculate:
                        \
                        \   (S R) = XX(1 0)
                        \         = x
                        \
                        \   (A P) = A * ALP1
                        \         = -y / 256 * alpha

 JSR ADD                \ Call ADD to calculate:
                        \
                        \   (A X) = (A P) + (S R)
                        \         = -y / 256 * alpha + x

 STA S                  \ Set XX(1 0) = (A X), which gives us result 6 above:
 STX XX                 \
 STX R                  \   x = x - alpha * y / 256
                        \
                        \ (XX+1 is not written here, as it is overwritten by
                        \ STA XX+1 after the ADD below before it is ever read)
                        \
                        \ Port: and (S R) = XX(1 0) now, as MUT2 did (MULTS-2
                        \ below leaves S and R alone)

 LDX BET1               \ Fetch the pitch magnitude into X

 LDA YY+1               \ Set A to y_hi and set it to the flipped sign of beta
 EOR BET2+1

 JSR MULTS-2            \ Call MULTS-2 to calculate:
                        \
                        \   (A P) = X * A
                        \         = -beta * y_hi

 STA Q                  \ Store the high byte of the result in Q, so:
                        \
                        \   Q = -beta * y_hi / 256

                        \ Port: (A P) = 2 * Q * Q straight from the quarter
                        \ squares, as MULT1 with A = Q gives sign 0 and |Q| <=
                        \ 15, so Q^2 = QS(2 * |Q|) < 256 and the high byte is 0
                        \ (MULT1's T, T1 and X are all rewritten by ADD below)

 ASL A                  \ Set X = 2 * |Q| (the sign bit goes into C)
 TAX

 LDA QSL,X              \ Set (A P) = 2 * Q^2, so (A P) = 2 * (beta * y / 256) ^ 2
 ASL A                  \
 STA P                  \   (S R) is still XX(1 0) = x
 LDA #0
 ROL A                  \
                        \ Port: the high byte of Q^2 is always 0 here (the
                        \ sign is Q EOR Q = 0, and |Q| <= 15 as MULTS uses
                        \ P AND 31, so Q^2 < 256), so the original's
                        \ sign-preserving STA T : LDA #0 : ROR A : ORA T is a
                        \ no-op (C = 0 and A, N, Z are the same; ADD rewrites T)

 JSR ADD                \ Call ADD to calculate:
                        \
                        \   (A X) = (A P) + (S R)
                        \         = 2 * (beta * y / 256) ^ 2 + x

 STA XX+1               \ Store the high byte A in XX+1

 TXA                    \ Store the low byte X in x_lo
 STA SXL,Y

                        \ So (XX+1 x_lo) now contains:
                        \
                        \   x = x + 2 * (beta * y / 256) ^ 2
                        \
                        \ which is result 7 above

 LDA YY                 \ Set (S R) = YY(1 0) = y
 STA R                  \
 LDA YY+1               \ The call to MAD and the two store instructions are
\JSR MAD                \ commented out in the original source
\STA S
\STX R
 STA S

 STZ P                  \ Set P = 0

 LDA BETA               \ Set A = -beta, so:
 EOR #%10000000         \
                        \   (A P) = (-beta 0)
                        \         = -beta * 256

 JSR PIX1               \ Call PIX1 to calculate the following:
                        \
                        \   (YY+1 y_lo) = (A P) + (S R)
                        \               = -beta * 256 + y
                        \
                        \ i.e. y = y - beta * 256, which is result 8 above
                        \
                        \ PIX1 also draws a particle at (X1, Y1) with distance
                        \ ZZ, which will remove the old stardust particle, as we
                        \ set X1, Y1 and ZZ to the original values for this
                        \ particle during the calculations above

                        \ We now have our newly moved stardust particle at
                        \ x-coordinate (XX+1 x_lo) and y-coordinate (YY+1 y_lo)
                        \ and distance z_hi, so we draw it if it's still on
                        \ screen, otherwise we recycle it as a new bit of
                        \ stardust and draw that

 LDA XX+1               \ Set X1 and x_hi to the high byte of XX in XX+1, so
 STA X1                 \ the new x-coordinate is in (x_hi x_lo) and the high
 STA SX,Y               \ byte is in X1

 AND #%01111111         \ If |x_hi| >= 120 then jump to KILL1 to recycle this
 CMP #120               \ particle, as it's gone off the side of the screen,
 BCS KILL1              \ and rejoin at STC1 with the new particle

 LDA YY+1               \ Set Y1 and y_hi to the high byte of YY in YY+1, so
 STA SY,Y               \ the new x-coordinate is in (y_hi y_lo) and the high
 STA Y1                 \ byte is in Y1

 AND #%01111111         \ If |y_hi| >= 120 then jump to KILL1 to recycle this
 CMP #120               \ particle, as it's gone off the top or bottom of the
 BCS KILL1              \ screen, and rejoin at STC1 with the new particle

 LDA SZ,Y               \ If z_hi < 16 then jump to KILL1 to recycle this
 CMP #16                \ particle, as it's so close that it's effectively gone
 BCC KILL1              \ past us, and rejoin at STC1 with the new particle

 STA ZZ                 \ Set ZZ to the z-coordinate in z_hi

.STC1

 JSR PIXEL2             \ Draw a stardust particle at (X1,Y1) with distance ZZ,
                        \ i.e. draw the newly moved particle at (x_hi, y_hi)
                        \ with distance z_hi

 DEY                    \ Decrement the loop counter to point to the next
                        \ stardust particle

 BEQ P%+5               \ If we have just done the last particle, skip the next
                        \ instruction to return from the subroutine

 JMP STL1               \ We have more stardust to process, so jump back up to
                        \ STL1 for the next particle

 RTS                    \ Return from the subroutine

.KILL1

                        \ Our particle of stardust just flew past us, so let's
                        \ recycle that particle, starting it at a random
                        \ position that isn't too close to the centre point

 JSR DORND              \ Set A and X to random numbers

 ORA #4                 \ Make sure A is at least 4 and store it in Y1 and y_hi,
 STA Y1                 \ so the new particle starts at least 4 pixels above or
 STA SY,Y               \ below the centre of the screen

 JSR DORND              \ Set A and X to random numbers

 ORA #8                 \ Make sure A is at least 8 and store it in X1 and x_hi,
 STA X1                 \ so the new particle starts at least 8 pixels either
 STA SX,Y               \ side of the centre of the screen

 JSR DORND              \ Set A and X to random numbers

 ORA #144               \ Make sure A is at least 144 and store it in ZZ and
 STA SZ,Y               \ z_hi so the new particle starts in the far distance
 STA ZZ

 LDA Y1                 \ Set A to the new value of y_hi. This has no effect as
                        \ STC1 starts with a jump to PIXEL2, which starts with a
                        \ LDA instruction

 JMP STC1               \ Jump up to STC1 to draw this new particle

\ ******************************************************************************
\
\       Name: STARS6
\       Type: Subroutine
\   Category: Stardust
\    Summary: Process the stardust for the rear view
\  Deep dive: Stardust in the front view
\
\ ------------------------------------------------------------------------------
\
\ This routine is very similar to STARS1, which processes stardust for the front
\ view. The main difference is that the direction of travel is reversed, so the
\ signs in the calculations are different, as well as the order of the first
\ batch of calculations.
\
\ When a stardust particle falls away into the far distance, it is removed from
\ the screen and its memory is recycled as a new particle, positioned randomly
\ along one of the four edges of the screen.
\
\ These are the calculations referred to in the commentary:
\
\   1. q = 64 * speed / z_hi
\   2. z = z - speed * 64
\   3. y = y + |y_hi| * q
\   4. x = x + |x_hi| * q
\
\   5. y = y + alpha * x / 256
\   6. x = x - alpha * y / 256
\
\   7. x = x + 2 * (beta * y / 256) ^ 2
\   8. y = y - beta * 256
\
\ For more information see the associated deep dive.
\
\ ******************************************************************************

.STARS6

 LDY NOSTM              \ Set Y to the current number of stardust particles, so
                        \ we can use it as a counter through all the stardust

.STL6

 JSR DV42               \ Call DV42 to set the following:
                        \
                        \   (P R) = 256 * DELTA / z_hi
                        \         = 256 * speed / z_hi
                        \
                        \ The maximum value returned is P = 2 and R = 128 (see
                        \ DV42 for an explanation)

 LDA R                  \ Set A = R, so now:
                        \
                        \   (P A) = 256 * speed / z_hi

 LSR P                  \ Rotate (P A) right by 2 places, which sets P = 0 (as P
 ROR A                  \ has a maximum value of 2) and leaves:
 LSR P                  \
 ROR A                  \   A = 64 * speed / z_hi

 ORA #1                 \ Make sure A is at least 1, and store it in Q, so we
 STA Q                  \ now have result 1 above:
                        \
                        \   Q = 64 * speed / z_hi

 LDA SX,Y               \ Set X1 = A = x_hi
 STA X1                 \
                        \ So X1 contains the original value of x_hi, which we
                        \ use below to remove the existing particle

 JSR MLU2               \ Set (A P) = |x_hi| * Q

                        \ We now calculate:
                        \
                        \   XX(1 0) = x - (A P)

 STA XX+1               \ First we do the low bytes:
 LDA SXL,Y              \
 SBC P                  \   XX(1 0) = x_lo - (A P)
 STA XX

 LDA X1                 \ And then we do the high bytes:
 SBC XX+1               \
 STA XX+1               \   XX(1 0) = (x_hi 0) - XX(1 0)
                        \
                        \ so we get our result:
                        \
                        \   XX(1 0) = x - (A P)
                        \           = x - |x_hi| * Q
                        \
                        \ which is result 2 above, and we also have:

 JSR MLU1               \ Call MLU1 to set:
                        \
                        \   Y1 = y_hi
                        \
                        \   (A P) = |y_hi| * Q
                        \
                        \ So Y1 contains the original value of y_hi, which we
                        \ use below to remove the existing particle

                        \ We now calculate:
                        \
                        \   (S R) = YY(1 0) = y - (A P)

 STA YY+1               \ First we do the low bytes with:
 LDA SYL,Y              \
 SBC P                  \   YY+1 = A
 STA YY                 \   R = YY = y_lo - P
 STA R                  \
                        \ so we get this:
                        \
                        \   (? R) = YY(1 0) = y_lo - (A P)

 LDA Y1                 \ And then we do the high bytes with:
 SBC YY+1               \
 STA YY+1               \   S = YY+1 = y_hi - YY+1
 STA S                  \
                        \ so we get our result:
                        \
                        \   (S R) = YY(1 0) = (y_hi y_lo) - (A P)
                        \                   = y - |y_hi| * Q
                        \
                        \ which is result 3 above, and (S R) is set to the new
                        \ value of y

 LDA SZL,Y              \ We now calculate the following:
 ADC DELT4              \
 STA SZL,Y              \  (z_hi z_lo) = (z_hi z_lo) + DELT4(1 0)
                        \
                        \ starting with the low bytes

 LDA SZ,Y               \ And then we do the high bytes
 STA ZZ                 \
 ADC DELT4+1            \ We also set ZZ to the original value of z_hi, which we
 STA SZ,Y               \ use below to remove the existing particle
                        \
                        \ So now we have result 4 above:
                        \
                        \   z = z + DELT4(1 0)
                        \     = z + speed * 64

 LDA XX+1               \ EOR x with the correct sign of the roll angle alpha,
 EOR ALP2               \ so A has the opposite sign to the roll angle alpha

 JSR MLS1               \ Call MLS1 to calculate:
                        \
                        \   (A P) = A * ALP1
                        \         = (-x / 256) * alpha

 JSR ADD                \ Call ADD to calculate:
                        \
                        \   (A X) = (A P) + (S R)
                        \         = (-x / 256) * alpha + y
                        \         = y - alpha * x / 256

 STA YY+1               \ Set YY(1 0) = (A X) to give:
 STX YY                 \
                        \   YY(1 0) = y - alpha * x / 256
                        \
                        \ which is result 5 above, and we also have:
                        \
                        \   A = YY+1 = y - alpha * x / 256
                        \
                        \ i.e. A is the new value of y, divided by 256

 EOR ALP2+1             \ EOR with the flipped sign of the roll angle alpha, so
                        \ A has the opposite sign to the flipped roll angle
                        \ alpha, i.e. it gets the same sign as alpha

 JSR MLS2               \ Call MLS2 to calculate:
                        \
                        \   (S R) = XX(1 0)
                        \         = x
                        \
                        \   (A P) = A * ALP1
                        \         = y / 256 * alpha

 JSR ADD                \ Call ADD to calculate:
                        \
                        \   (A X) = (A P) + (S R)
                        \         = y / 256 * alpha + x

 STA XX+1               \ Set XX(1 0) = (A X), which gives us result 6 above:
 STX XX                 \
                        \   x = x + alpha * y / 256

 LDA YY+1               \ Set A to y_hi and set it to the flipped sign of beta
 EOR BET2+1

 LDX BET1               \ Fetch the pitch magnitude into X

 JSR MULTS-2            \ Call MULTS-2 to calculate:
                        \
                        \   (A P) = X * A
                        \         = beta * y_hi

 STA Q                  \ Store the high byte of the result in Q, so:
                        \
                        \   Q = beta * y_hi / 256

 LDA XX+1               \ Set S = x_hi
 STA S

 EOR #%10000000         \ Flip the sign of A, so A now contains -x

 JSR MUT1               \ Call MUT1 to calculate:
                        \
                        \   R = XX = x_lo
                        \
                        \   (A P) = Q * A
                        \         = (beta * y_hi / 256) * (-beta * y_hi / 256)
                        \         = (-beta * y / 256) ^ 2

 ASL P                  \ Double (A P), store the top byte in A and set the C
 ROL A                  \ flag to bit 7 of the original A, so this does:
 STA T                  \
                        \   (T P) = (A P) << 1
                        \         = 2 * (-beta * y / 256) ^ 2

 LDA #0                 \ Set bit 7 in A to the sign bit from the A in the
 ROR A                  \ calculation above and apply it to T, so we now have:
 ORA T                  \
                        \   (A P) = -2 * (beta * y / 256) ^ 2
                        \
                        \ with the doubling retaining the sign of (A P)

 JSR ADD                \ Call ADD to calculate:
                        \
                        \   (A X) = (A P) + (S R)
                        \         = -2 * (beta * y / 256) ^ 2 + x

 STA XX+1               \ Store the high byte A in XX+1

 TXA                    \ Store the low byte X in x_lo
 STA SXL,Y

                        \ So (XX+1 x_lo) now contains:
                        \
                        \   x = x - 2 * (beta * y / 256) ^ 2
                        \
                        \ which is result 7 above

 LDA YY                 \ Set (S R) = YY(1 0) = y
 STA R
 LDA YY+1
 STA S

\EOR #128               \ These instructions are commented out in the original
\JSR MAD                \ source
\STA S
\STX R

 LDA #0                 \ Set P = 0
 STA P

 LDA BETA               \ Set A = beta, so (A P) = (beta 0) = beta * 256

 JSR PIX1               \ Call PIX1 to calculate the following:
                        \
                        \   (YY+1 y_lo) = (A P) + (S R)
                        \               = beta * 256 + y
                        \
                        \ i.e. y = y + beta * 256, which is result 8 above
                        \
                        \ PIX1 also draws a particle at (X1, Y1) with distance
                        \ ZZ, which will remove the old stardust particle, as we
                        \ set X1, Y1 and ZZ to the original values for this
                        \ particle during the calculations above

                        \ We now have our newly moved stardust particle at
                        \ x-coordinate (XX+1 x_lo) and y-coordinate (YY+1 y_lo)
                        \ and distance z_hi, so we draw it if it's still on
                        \ screen, otherwise we recycle it as a new bit of
                        \ stardust and draw that

 LDA XX+1               \ Set X1 and x_hi to the high byte of XX in XX+1, so
 STA X1                 \ the new x-coordinate is in (x_hi x_lo) and the high
 STA SX,Y               \ byte is in X1

 LDA YY+1               \ Set Y1 and y_hi to the high byte of YY in YY+1, so
 STA SY,Y               \ the new x-coordinate is in (y_hi y_lo) and the high
 STA Y1                 \ byte is in Y1

 AND #%01111111         \ If |y_hi| >= 110 then jump to KILL6 to recycle this
 CMP #110               \ particle, as it's gone off the top or bottom of the
 BCS KILL6              \ screen, and rejoin at STC6 with the new particle

 LDA SZ,Y               \ If z_hi >= 160 then jump to KILL6 to recycle this
 CMP #160               \ particle, as it's so far away that it's too far to
 BCS KILL6              \ see, and rejoin at STC1 with the new particle

 STA ZZ                 \ Set ZZ to the z-coordinate in z_hi

.STC6

 JSR PIXEL2             \ Draw a stardust particle at (X1,Y1) with distance ZZ,
                        \ i.e. draw the newly moved particle at (x_hi, y_hi)
                        \ with distance z_hi

 DEY                    \ Decrement the loop counter to point to the next
                        \ stardust particle

 BEQ ST3                \ If we have just done the last particle, skip the next
                        \ instruction to return from the subroutine

 JMP STL6               \ We have more stardust to process, so jump back up to
                        \ STL6 for the next particle

.ST3

 RTS                    \ Return from the subroutine

.KILL6

 JSR DORND              \ Set A and X to random numbers

 AND #%01111111         \ Clear the sign bit of A to get |A|

 ADC #10                \ Make sure A is at least 10 and store it in z_hi and
 STA SZ,Y               \ ZZ, so the new particle starts close to us
 STA ZZ

 LSR A                  \ Divide A by 2 and randomly set the C flag

 BCS ST4                \ Jump to ST4 half the time

 LSR A                  \ Randomly set the C flag again

 LDA #252               \ Set A to either +126 or -126 (252 >> 1) depending on
 ROR A                  \ the C flag, as this is a sign-magnitude number with
                        \ the C flag rotated into its sign bit

 STA X1                 \ Set x_hi and X1 to A, so this particle starts on
 STA SX,Y               \ either the left or right edge of the screen

 JSR DORND              \ Set A and X to random numbers

 STA Y1                 \ Set y_hi and Y1 to random numbers, so the particle
 STA SY,Y               \ starts anywhere along either the left or right edge

 JMP STC6               \ Jump up to STC6 to draw this new particle

.ST4

 JSR DORND              \ Set A and X to random numbers

 STA X1                 \ Set x_hi and X1 to random numbers, so the particle
 STA SX,Y               \ starts anywhere along the x-axis

 LSR A                  \ Randomly set the C flag

 LDA #230               \ Set A to either +115 or -115 (230 >> 1) depending on
 ROR A                  \ the C flag, as this is a sign-magnitude number with
                        \ the C flag rotated into its sign bit

 STA Y1                 \ Set y_hi and Y1 to A, so the particle starts anywhere
 STA SY,Y               \ along either the top or bottom edge of the screen

 BNE STC6               \ Jump up to STC6 to draw this new particle (this BNE is
                        \ effectively a JMP as A will never be zero)

\ ******************************************************************************
\
\       Name: MAS1
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Add an orientation vector coordinate to an INWK coordinate
\  Deep dive: The space station safe zone
\
\ ------------------------------------------------------------------------------
\
\ Add a doubled nosev vector coordinate, e.g. (nosev_y_hi nosev_y_lo) * 2, to
\ an INWK coordinate, e.g. (x_sign x_hi x_lo), storing the result in the INWK
\ coordinate. The axes used in each side of the addition are specified by the
\ arguments X and Y.
\
\ In the comments below, we document the routine as if we are doing the
\ following, i.e. if X = 0 and Y = 11:
\
\   (x_sign x_hi x_lo) = (x_sign x_hi x_lo) + (nosev_y_hi nosev_y_lo) * 2
\
\ as that way the variable names in the comments contain "x" and "y" to match
\ the registers that specify the vector axis to use.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The coordinate to add, as follows:
\
\                         * If X = 0, add (x_sign x_hi x_lo)
\                         * If X = 3, add (y_sign y_hi y_lo)
\                         * If X = 6, add (z_sign z_hi z_lo)
\
\   Y                   The vector to add, as follows:
\
\                         * If Y = 9,  add (nosev_x_hi nosev_x_lo)
\                         * If Y = 11, add (nosev_y_hi nosev_y_lo)
\                         * If Y = 13, add (nosev_z_hi nosev_z_lo)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   The highest byte of the result with the sign cleared
\                       (e.g. |x_sign| when X = 0, etc.)
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   MA9                 Contains an RTS
\
\ ******************************************************************************

.MAS1

 LDA INWK,Y             \ Set K(2 1) = (nosev_y_hi nosev_y_lo) * 2
 ASL A
 STA K+1
 LDA INWK+1,Y
 ROL A
 STA K+2

 LDA #0                 \ Set K+3 bit 7 to the C flag, so the sign bit of the
 ROR A                  \ above result goes into K+3
 STA K+3

 JSR MVT3               \ Add (x_sign x_hi x_lo) to K(3 2 1)

 STA INWK+2,X           \ Store the sign of the result in x_sign

 LDY K+1                \ Store K(2 1) in (x_hi x_lo)
 STY INWK,X
 LDY K+2
 STY INWK+1,X

 AND #%01111111         \ Set A to the sign byte with the sign cleared,
                        \ i.e. |x_sign| when X = 0

.MA9

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: MAS2
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Calculate a cap on the maximum distance to the planet or sun
\
\ ------------------------------------------------------------------------------
\
\ Given a value in Y that points to the start of a ship data block as an offset
\ from K%, calculate the following:
\
\   A = A OR x_sign OR y_sign OR z_sign
\
\ and clear the sign bit of the result. The K% workspace contains the ship data
\ blocks, so the offset in Y must be 0 or a multiple of NI% (as each block in
\ K% contains NI% bytes).
\
\ The result effectively contains a maximum cap of the three values (though it
\ might not be one of the three input values - it's just guaranteed to be
\ larger than all of them).
\
\ If Y = 0 and A = 0, then this calculates the maximum cap of the highest byte
\ containing the distance to the planet, as K%+2 = x_sign, K%+5 = y_sign and
\ K%+8 = z_sign (the first slot in the K% workspace represents the planet).
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   Y                   The offset from K% for the start of the ship data block
\                       to use
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   A OR K%+2+Y OR K%+5+Y OR K%+8+Y, with bit 7 cleared
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   m                   Do not include A in the calculation
\
\ ******************************************************************************

.m

 LDA #0                 \ Set A = 0 and fall through into MAS2 to calculate the
                        \ OR of the three bytes at K%+2+Y, K%+5+Y and K%+8+Y

.MAS2

 ORA K%+2,Y             \ Set A = A OR x_sign OR y_sign OR z_sign
 ORA K%+5,Y
 ORA K%+8,Y

 AND #%01111111         \ Clear bit 7 in A

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: MAS3
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate A = x_hi^2 + y_hi^2 + z_hi^2 in the K% block
\
\ ------------------------------------------------------------------------------
\
\ Given a value in Y that points to the start of a ship data block as an offset
\ from K%, calculate the following:
\
\   (A ?) = x_hi^2 + y_hi^2 + z_hi^2
\
\ returning A = &FF if the calculation overflows a one-byte result. The K%
\ workspace contains the ship data blocks, so the offset in Y must be 0 or a
\ multiple of NI% (as each block in K% contains NI% bytes).
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   Y                   The offset from K% for the start of the ship data block
\                       to use
\
\ Returns
\
\   A                   The high byte of x_hi^2 + y_hi^2 + z_hi^2
\
\   C flag              The overflow status (i.e. did the result fit into one
\                       byte):
\
\                         * Clear if the calculation didn't overflow
\
\                         * Set if the calculation overflowed (in which case A
\                           is set to &FF)
\
\ ******************************************************************************

.MAS3

 LDA K%+1,Y             \ Set (A P) = x_hi * x_hi
 JSR SQUA2

 STA R                  \ Store A (high byte of result) in R

 LDA K%+4,Y             \ Set (A P) = y_hi * y_hi
 JSR SQUA2

 ADC R                  \ Add A (high byte of second result) to R

 BCS MA30               \ If the addition of the two high bytes caused a carry
                        \ (i.e. they overflowed), jump to MA30 to return A = &FF

 STA R                  \ Store A (sum of the two high bytes) in R

 LDA K%+7,Y             \ Set (A P) = z_hi * z_hi
 JSR SQUA2

 ADC R                  \ Add A (high byte of third result) to R, so R now
                        \ contains the high byte of the entire sum, i.e. of
                        \ x_hi^2 + y_hi^2 + z_hi^2

 BCC P%+4               \ If there is no carry, skip the following instruction
                        \ to return straight from the subroutine

.MA30

 LDA #&FF               \ The calculation has overflowed, so set A = &FF

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: MVT3
\       Type: Subroutine
\   Category: Moving
\    Summary: Calculate K(3 2 1) = (x_sign x_hi x_lo) + K(3 2 1)
\
\ ------------------------------------------------------------------------------
\
\ Add an INWK position coordinate - i.e. x, y or z - to K(3 2 1), like this:
\
\   K(3 2 1) = (x_sign x_hi x_lo) + K(3 2 1)
\
\ The INWK coordinate to add to K(3 2 1) is specified by X.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The coordinate to add to K(3 2 1), as follows:
\
\                         * If X = 0, add (x_sign x_hi x_lo)
\
\                         * If X = 3, add (y_sign y_hi y_lo)
\
\                         * If X = 6, add (z_sign z_hi z_lo)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   Contains a copy of the high byte of the result, K+3
\
\   X                   X is preserved
\
\ ******************************************************************************

.MVT3

 LDA K+3                \ Set S = K+3
 STA S

 AND #%10000000         \ Set T = sign bit of K(3 2 1)
 STA T

 EOR INWK+2,X           \ If x_sign has a different sign to K(3 2 1), jump to
 BMI MV13               \ MV13 to process the addition as a subtraction

 LDA K+1                \ Set K(3 2 1) = K(3 2 1) + (x_sign x_hi x_lo)
 CLC                    \ starting with the low bytes
 ADC INWK,X
 STA K+1

 LDA K+2                \ Then the middle bytes
 ADC INWK+1,X
 STA K+2

 LDA K+3                \ And finally the high bytes
 ADC INWK+2,X

 AND #%01111111         \ Setting the sign bit of K+3 to T, the original sign
 ORA T                  \ of K(3 2 1)
 STA K+3

 RTS                    \ Return from the subroutine

.MV13

 LDA S                  \ Set S = |K+3| (i.e. K+3 with the sign bit cleared)
 AND #%01111111
 STA S

 LDA INWK,X             \ Set K(3 2 1) = (x_sign x_hi x_lo) - K(3 2 1)
 SEC                    \ starting with the low bytes
 SBC K+1
 STA K+1

 LDA INWK+1,X           \ Then the middle bytes
 SBC K+2
 STA K+2

 LDA INWK+2,X           \ And finally the high bytes, doing A = |x_sign| - |K+3|
 AND #%01111111         \ and setting the C flag for testing below
 SBC S

 ORA #%10000000         \ Set the sign bit of K+3 to the opposite sign of T,
 EOR T                  \ i.e. the opposite sign to the original K(3 2 1)
 STA K+3

 BCS MV14               \ If the C flag is set, i.e. |x_sign| >= |K+3|, then
                        \ the sign of K(3 2 1). In this case, we want the
                        \ result to have the same sign as the largest argument,
                        \ which is (x_sign x_hi x_lo), which we know has the
                        \ opposite sign to K(3 2 1), and that's what we just set
                        \ the sign of K(3 2 1) to... so we can jump to MV14 to
                        \ return from the subroutine

 LDA #1                 \ We need to swap the sign of the result in K(3 2 1),
 SBC K+1                \ which we do by calculating 0 - K(3 2 1), which we can
 STA K+1                \ do with 1 - C - K(3 2 1), as we know the C flag is
                        \ clear. We start with the low bytes

 LDA #0                 \ Then the middle bytes
 SBC K+2
 STA K+2

 LDA #0                 \ And finally the high bytes
 SBC K+3

 AND #%01111111         \ Set the sign bit of K+3 to the same sign as T,
 ORA T                  \ i.e. the same sign as the original K(3 2 1), as
 STA K+3                \ that's the largest argument

.MV14

 RTS                    \ Return from the subroutine

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

.MVS5

 LDA INWK+1,X           \ Fetch roofv_x_hi, clear the sign bit, divide by 2 and
 AND #%01111111         \ store in T, so:
 LSR A                  \
 STA T                  \ T = |roofv_x_hi| / 2
                        \   = |roofv_x| / 512
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

 LDA INWK,X             \ Now we do the following subtraction:
 SEC                    \
 SBC T                  \ (S R) = (roofv_x_hi roofv_x_lo) - |roofv_x| / 512
 STA R                  \       = (1 - 1/512) * roofv_x
                        \
                        \ by doing the low bytes first

 LDA INWK+1,X           \ And then the high bytes (the high byte of the right
 SBC #0                 \ side of the subtraction being 0)
 STA S

 LDA INWK,Y             \ Set P = nosev_x_lo
 STA P

 LDA INWK+1,Y           \ Fetch nosev_x_hi (sign bit included)

 LSR A                  \ Set (A P) = (A P) / 16, so P is as for
 ROR P                  \ |nosev_x| / 16 and A = %0000smmm, where s is the
 LSR A                  \ sign of nosev_x and mmm = |nosev_x_hi| / 16
 ROR P
 LSR A
 ROR P
 LSR A
 ROR P

 CLC                    \ Port: move the sign from bit 3 to bit 7:
 ADC #&78               \ s=0: &78+mmm, AND &87 = mmm
 AND #%10000111         \ s=1: &80+mmm, AND &87 = &80+mmm
                        \ so now (A P) = nosev_x / 16

 EOR RAT2               \ Give it the sign as if we multiplied by the direction
                        \ by the pitch or roll direction

 STX Q                  \ Store the value of X so it can be restored after the
                        \ call to ADD

 JSR ADD                \ (A X) = (A P) + (S R)
                        \       = +/-nosev_x / 16 + (1 - 1/512) * roofv_x

 STA K+1                \ Set K(1 0) = (1 - 1/512) * roofv_x +/- nosev_x / 16
 STX K

 LDX Q                  \ Restore the value of X from before the call to ADD

 LDA INWK+1,Y           \ Fetch nosev_x_hi, clear the sign bit, divide by 2 and
 AND #%01111111         \ store in T, so:
 LSR A                  \
 STA T                  \ T = |nosev_x_hi| / 2
                        \   = |nosev_x| / 512

 LDA INWK,Y             \ Now we do the following subtraction:
 SEC                    \
 SBC T                  \ (S R) = (nosev_x_hi nosev_x_lo) - |nosev_x| / 512
 STA R                  \       = (1 - 1/512) * nosev_x
                        \
                        \ by doing the low bytes first

 LDA INWK+1,Y           \ And then the high bytes (the high byte of the right
 SBC #0                 \ side of the subtraction being 0)
 STA S

 LDA INWK,X             \ Set P = roofv_x_lo
 STA P

 LDA INWK+1,X           \ Fetch roofv_x_hi (sign bit included)

 LSR A                  \ Set (A P) = (A P) / 16, so P is as for
 ROR P                  \ |roofv_x| / 16 and A = %0000smmm, where s is the
 LSR A                  \ sign of roofv_x and mmm = |roofv_x_hi| / 16
 ROR P
 LSR A
 ROR P
 LSR A
 ROR P

 CLC                    \ Port: move the sign from bit 3 to bit 7 and flip it:
 ADC #&F8               \ s=0: &F8+mmm, AND &87 = &80+mmm
 AND #%10000111         \ s=1: &100+mmm wraps to mmm, AND &87 = mmm
                        \ so now (A P) = -roofv_x / 16

 EOR RAT2               \ Give it the sign as if we multiplied by the direction
                        \ by the pitch or roll direction

 STX Q                  \ Store the value of X so it can be restored after the
                        \ call to ADD

 JSR ADD                \ (A X) = (A P) + (S R)
                        \       = -/+roofv_x / 16 + (1 - 1/512) * nosev_x

 STA INWK+1,Y           \ Set nosev_x = (1-1/512) * nosev_x -/+ roofv_x / 16
 STX INWK,Y

 LDX Q                  \ Restore the value of X from before the call to ADD

 LDA K                  \ Set roofv_x = K(1 0)
 STA INWK,X             \             = (1-1/512) * roofv_x +/- nosev_x / 16
 LDA K+1
 STA INWK+1,X

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: DTW1
\       Type: Variable
\   Category: Text
\    Summary: A mask for applying the lower case part of Sentence Case to
\             extended text tokens
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ This variable is used to change characters to lower case as part of applying
\ Sentence Case to extended text tokens. It has two values:
\
\   * %00100000 = apply lower case to the second letter of a word onwards
\
\   * %00000000 = do not change case to lower case
\
\ The default value is %00100000 (apply lower case).
\
\ The flag is set to %00100000 (apply lower case) by jump token 2, {sentence
\ case}, which calls routine MT2 to change the value of DTW1.
\
\ The flag is set to %00000000 (do not change case to lower case) by jump token
\ 1, {all caps}, which calls routine MT1 to change the value of DTW1.
\
\ The letter to print is OR'd with DTW1 in DETOK2, which lower-cases the letter
\ by setting bit 5 (if DTW1 is %00100000). However, this OR is only done if bit
\ 7 of DTW2 is clear, i.e. we are printing a word, so this doesn't affect the
\ first letter of the word, which remains capitalised.
\
\ ******************************************************************************

.DTW1

 EQUB %00100000

\ ******************************************************************************
\
\       Name: DTW2
\       Type: Variable
\   Category: Text
\    Summary: A flag that indicates whether we are currently printing a word
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ This variable is used to indicate whether we are currently printing a word. It
\ has two values:
\
\   * 0 = we are currently printing a word
\
\   * Non-zero = we are not currently printing a word
\
\ The default value is %11111111 (we are not currently printing a word).
\
\ The flag is set to %00000000 (we are currently printing a word) whenever a
\ non-terminator character is passed to DASC for printing.
\
\ The flag is set to %11111111 (we are not currently printing a word) whenever a
\ terminator character (full stop, colon, carriage return, line feed, space) is
\ passed to DASC for printing. It is also set to %11111111 by jump token 8,
\ {tab 6}, which calls routine MT8 to change the value of DTW2, and to %10000000
\ by TTX66 when we clear the screen.
\
\ ******************************************************************************

.DTW2

 EQUB %11111111

\ ******************************************************************************
\
\       Name: DTW3
\       Type: Variable
\   Category: Text
\    Summary: A flag for switching between standard and extended text tokens
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ This variable is used to indicate whether standard or extended text tokens
\ should be printed by calls to DETOK. It allows us to mix standard tokens in
\ with extended tokens. It has two values:
\
\   * %00000000 = print extended tokens (i.e. those in TKN1 and RUTOK)
\
\   * %11111111 = print standard tokens (i.e. those in QQ18)
\
\ The default value is %00000000 (extended tokens).
\
\ Standard tokens are set by jump token {6}, which calls routine MT6 to change
\ the value of DTW3 to %11111111.
\
\ Extended tokens are set by jump token {5}, which calls routine MT5 to change
\ the value of DTW3 to %00000000.
\
\ ******************************************************************************

.DTW3

 EQUB %00000000

\ ******************************************************************************
\
\       Name: DTW4
\       Type: Variable
\   Category: Text
\    Summary: Flags that govern how justified extended text tokens are printed
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ This variable is used to control how justified text tokens are printed as part
\ of the extended text token system. There are two bits that affect justified
\ text:
\
\   * Bit 7: 1 = justify text
\            0 = do not justify text
\
\   * Bit 6: 1 = buffer the entire token before printing, including carriage
\                returns (used for in-flight messages only)
\            0 = print the contents of the buffer whenever a carriage return
\                appears in the token
\
\ The default value is %00000000 (do not justify text, print buffer on carriage
\ return).
\
\ The flag is set to %10000000 (justify text, print buffer on carriage return)
\ by jump token 14, {justify}, which calls routine MT14 to change the value of
\ DTW4.
\
\ The flag is set to %11000000 (justify text, buffer entire token) by routine
\ MESS, which prints in-flight messages.
\
\ The flag is set to %00000000 (do not justify text, print buffer on carriage
\ return) by jump token 15, {left align}, which calls routine MT1 to change the
\ value of DTW4.
\
\ ******************************************************************************

.DTW4

 EQUB 0

\ ******************************************************************************
\
\       Name: DTW5
\       Type: Variable
\   Category: Text
\    Summary: The size of the justified text buffer at BUF
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ When justified text is enabled by jump token 14, {justify}, during printing of
\ extended text tokens, text is fed into a buffer at BUF instead of being
\ printed straight away, so it can be padded out with spaces to justify the
\ text. DTW5 contains the size of the buffer, so BUF + DTW5 points to the first
\ free byte after the end of the buffer.
\
\ ******************************************************************************

.DTW5

 EQUB 0

\ ******************************************************************************
\
\       Name: DTW6
\       Type: Variable
\   Category: Text
\    Summary: A flag to denote whether printing in lower case is enabled for
\             extended text tokens
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ This variable is used to indicate whether lower case is currently enabled. It
\ has two values:
\
\   * %10000000 = lower case is enabled
\
\   * %00000000 = lower case is not enabled
\
\ The default value is %00000000 (lower case is not enabled).
\
\ The flag is set to %10000000 (lower case is enabled) by jump token 13 {lower
\ case}, which calls routine MT10 to change the value of DTW6.
\
\ The flag is set to %00000000 (lower case is not enabled) by jump token 1, {all
\ caps}, and jump token 2, {sentence case}, which call routines MT1 and MT2 to
\ change the value of DTW6.
\
\ ******************************************************************************

.DTW6

 EQUB %00000000

\ ******************************************************************************
\
\       Name: DTW8
\       Type: Variable
\   Category: Text
\    Summary: A mask for capitalising the next letter in an extended text token
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ This variable is only used by one specific extended token, the {single cap}
\ jump token, which capitalises the next letter only. It has two values:
\
\   * %11011111 = capitalise the next letter
\
\   * %11111111 = do not change case
\
\ The default value is %11111111 (do not change case).
\
\ The flag is set to %11011111 (capitalise the next letter) by jump token 19,
\ {single cap}, which calls routine MT19 to change the value of DTW.
\
\ The flag is set to %11111111 (do not change case) at the start of DASC, after
\ the letter has been capitalised in DETOK2, so the effect is to capitalise one
\ letter only.
\
\ The letter to print is AND'd with DTW8 in DETOK2, which capitalises the letter
\ by clearing bit 5 (if DTW8 is %11011111). However, this AND is only done if at
\ least one of the following is true:
\
\   * Bit 7 of DTW2 is set (we are not currently printing a word)
\
\   * Bit 7 of DTW6 is set (lower case has been enabled by jump token 13, {lower
\     case}
\
\ In other words, we only capitalise the next letter if it's the first letter in
\ a word, or we are printing in lower case.
\
\ ******************************************************************************

.DTW8

 EQUB %11111111

\ ******************************************************************************
\
\       Name: FEED
\       Type: Subroutine
\   Category: Text
\    Summary: Print a newline
\
\ ******************************************************************************

.FEED

 LDA #12                \ Set A = 12, so when we skip MT16 and fall through into
                        \ TT26, we print character 12, which is a newline

 EQUB &2C               \ Skip the next instruction by turning it into
                        \ &2C &A9 &41, or BIT &41A9, which does nothing apart
                        \ from affect the flags

                        \ Fall through into TT26 (skipping MT16) to print the
                        \ newline character

\ ******************************************************************************
\
\       Name: MT16
\       Type: Subroutine
\   Category: Text
\    Summary: Print the character in variable DTW7
\  Deep dive: Extended text tokens
\
\ ******************************************************************************

.MT16

 LDA #'A'               \ Set A to the contents of DTW7, as DTW7 points to the
                        \ second byte of this instruction, so updating DTW7 will
                        \ modify this instruction (the default value of DTW7 is
                        \ an "A")

 DTW7 = MT16 + 1        \ Point DTW7 to the second byte of the instruction above
                        \ so that modifying DTW7 changes the value loaded into A

                        \ Fall through into TT26 to print the character in A

\ ******************************************************************************
\
\       Name: TT26
\       Type: Subroutine
\   Category: Text
\    Summary: Print a character at the text cursor, with support for verified
\             text in extended tokens
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The character to print
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   X                   X is preserved
\
\   C flag              The C flag is cleared
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   DASC                DASC does exactly the same as TT26 and prints a
\                       character at the text cursor, with support for verified
\                       text in extended tokens
\
\ ******************************************************************************

.DASC

.TT26

 STX SC                 \ Store X in SC, so we can retrieve it below

 LDX #%11111111         \ Set DTW8 = %11111111, to disable the effect of {19} if
 STX DTW8               \ it was set (as {19} capitalises one character only)

 CMP #'.'               \ If the character in A is a word terminator:
 BEQ DA8                \
 CMP #':'               \   * Full stop
 BEQ DA8                \   * Colon
 CMP #10                \   * Line feed
 BEQ DA8                \   * Carriage return
 CMP #12                \   * Space
 BEQ DA8                \
 CMP #' '               \ then skip the following instruction
 BEQ DA8

 INX                    \ Increment X to 0, so DTW2 gets set to %00000000 below

.DA8

 STX DTW2               \ Store X in DTW2, so DTW2 is now:
                        \
                        \   * %00000000 if this character is a word terminator
                        \
                        \   * %11111111 if it isn't
                        \
                        \ so DTW2 indicates whether or not we are currently
                        \ printing a word

 LDX SC                 \ Retrieve the original value of X from SC

 BIT DTW4               \ If bit 7 of DTW4 is set then we are currently printing
 BMI P%+5               \ justified text, so skip the next instruction

 JMP CHPR               \ Bit 7 of DTW4 is clear, so jump down to CHPR to print
                        \ this character, as we are not printing justified text

                        \ If we get here then we are printing justified text, so
                        \ we need to buffer the text until we reach the end of
                        \ the paragraph, so we can then pad it out with spaces

 BIT DTW4               \ If bit 6 of DTW4 is set, then this is an in-flight
 BVS P%+6               \ message and we should buffer the carriage return
                        \ character {12}, so skip the following two instructions

 CMP #12                \ If the character in A is a carriage return, then we
 BEQ DA1                \ have reached the end of the paragraph, so jump down to
                        \ DA1 to print out the contents of the buffer,
                        \ justifying it as we go

                        \ If we get here then we need to buffer this character
                        \ in the line buffer at BUF

 LDX DTW5               \ DTW5 contains the current size of the buffer, so this
 STA BUF,X              \ stores the character in A at BUF + DTW5, the next free
                        \ space in the buffer

 LDX SC                 \ Retrieve the original value of X from SC so we can
                        \ preserve it through this subroutine call

 INC DTW5               \ Increment the size of the BUF buffer that is stored in
                        \ DTW5

 CLC                    \ Clear the C flag

 RTS                    \ Return from the subroutine

.DA1

                        \ If we get here then we are justifying text and we have
                        \ reached the end of the paragraph, so we need to print
                        \ out the contents of the buffer, justifying it as we go

 TXA                    \ Store X and Y on the stack
 PHA
 TYA
 PHA

.DA5

 LDX DTW5               \ Set X = DTW5, which contains the size of the buffer

 BEQ DA6+3              \ If X = 0 then the buffer is empty, so jump down to
                        \ DA6+3 to print a newline

 CPX #(LL+1)            \ If X < LL+1, i.e. X <= LL, then the buffer contains
 BCC DA6                \ fewer than LL characters, which is less than a line
                        \ length, so jump down to DA6 to print the contents of
                        \ BUF followed by a newline, as we don't justify the
                        \ last line of the paragraph

                        \ Otherwise X > LL, so the buffer does not fit into one
                        \ line, and we therefore need to justify the text, which
                        \ we do one line at a time

 LSR SC+1               \ Shift SC+1 to the right, which clears bit 7 of SC+1,
                        \ so we pass through the following comparison on the
                        \ first iteration of the loop and set SC+1 to %01000000

.DA11

 LDA SC+1               \ If bit 7 of SC+1 is set, skip the following two
 BMI P%+6               \ instructions

 LDA #%01000000         \ Set SC+1 = %01000000
 STA SC+1

 LDY #(LL-1)            \ Set Y = line length, so we can loop backwards from the
                        \ end of the first line in the buffer using Y as the
                        \ loop counter

.DAL1

 LDA BUF+LL             \ If the LL-th byte in BUF is a space, jump down to DA2
 CMP #' '               \ to print out the first line from the buffer, as it
 BEQ DA2                \ fits the line width exactly (i.e. it's justified)

                        \ We now want to find the last space character in the
                        \ first line in the buffer, so we loop through the line
                        \ using Y as a counter

.DAL2

 DEY                    \ Decrement the loop counter in Y

 BMI DA11               \ If Y <= 0, loop back to DA11, as we have now looped
 BEQ DA11               \ through the whole line

 LDA BUF,Y              \ If the Y-th byte in BUF is not a space, loop back up
 CMP #' '               \ to DAL2 to check the next character
 BNE DAL2

                        \ Y now points to a space character in the line buffer

 ASL SC+1               \ Shift SC+1 to the left

 BMI DAL2               \ If bit 7 of SC+1 is set, jump to DAL2 to find the next
                        \ space character

                        \ We now want to insert a space into the line buffer at
                        \ position Y, which we do by shifting every character
                        \ after position Y along by 1, and then inserting the
                        \ space

 STY SC                 \ Store Y in SC, so we want to insert the space at
                        \ position SC

 LDY DTW5               \ Fetch the buffer size from DTW5 into Y, to act as a
                        \ loop counter for moving the line buffer along by 1

.DAL6

 LDA BUF,Y              \ Copy the Y-th character from BUF into the Y+1-th
 STA BUF+1,Y            \ position

 DEY                    \ Decrement the loop counter in Y

 CPY SC                 \ Loop back to shift the next character along, until we
 BCS DAL6               \ have moved the SC-th character (i.e. Y < SC)

 INC DTW5               \ Increment the buffer size in DTW5

\LDA #' '               \ This instruction is commented out in the original
                        \ source, as it has no effect because A already contains
                        \ ASCII " ". This is because the last character that is
                        \ tested in the above loop is at position SC, which we
                        \ know contains a space, so we know A contains a space
                        \ character when the loop finishes

                        \ We've now shifted the line to the right by 1 from
                        \ position SC onwards, so SC and SC+1 both contain
                        \ spaces, and Y is now SC-1 as we did a DEY just before
                        \ the end of the loop - in other words, we have inserted
                        \ a space at position SC, and Y points to the character
                        \ before the newly inserted space

                        \ We now want to move the pointer Y left to find the
                        \ next space in the line buffer, before looping back to
                        \ check whether we are done, and if not, insert another
                        \ space

.DAL3

 CMP BUF,Y              \ If the character at position Y is not a space, jump to
 BNE DAL1               \ DAL1 to see whether we have now justified the line

 DEY                    \ Decrement the loop counter in Y

 BPL DAL3               \ Loop back to check the next character to the left,
                        \ until we have found a space

 BMI DA11               \ Jump back to DA11 (this BMI is effectively a JMP as
                        \ we already passed through a BPL to get here)

.DA2

                        \ This subroutine prints out a full line of characters
                        \ from the start of the line buffer in BUF, followed by
                        \ a newline. It then removes that line from the buffer,
                        \ shuffling the rest of the buffer contents down

 LDX #LL                \ Call DAS1 to print out the first LL characters from
 JSR DAS1               \ the line buffer in BUF

 LDA #12                \ Print a newline
 JSR CHPR

 LDA DTW5               \ Subtract #LL from the end-of-buffer pointer in DTW5
\CLC                    \
 SBC #LL                \ The CLC instruction is commented out in the original
 STA DTW5               \ source. It isn't needed as CHPR clears the C flag

 TAX                    \ Copy the new value of DTW5 into X

 BEQ DA6+3              \ If DTW5 = 0 then jump down to DA6+3 to print a newline
                        \ as the buffer is now empty

                        \ If we get here then we have printed our line but there
                        \ is more in the buffer, so we now want to remove the
                        \ line we just printed from the start of BUF

 LDY #0                 \ Set Y = 0 to count through the characters in BUF

 INX                    \ Increment X, so it now contains the number of
                        \ characters in the buffer (as DTW5 is a zero-based
                        \ pointer and is therefore equal to the number of
                        \ characters minus 1)

.DAL4

 LDA BUF+LL+1,Y         \ Copy the Y-th character from BUF+LL to BUF
 STA BUF,Y

 INY                    \ Increment the character pointer

 DEX                    \ Decrement the character count

 BNE DAL4               \ Loop back to copy the next character until we have
                        \ shuffled down the whole buffer

 BEQ DA5                \ Jump back to DA5 (this BEQ is effectively a JMP as we
                        \ have already passed through the BNE above)

.DAS1

                        \ This subroutine prints out X characters from BUF,
                        \ returning with X = 0

 LDY #0                 \ Set Y = 0 to point to the first character in BUF

.DAL5

 LDA BUF,Y              \ Print the Y-th character in BUF using CHPR, which also
 JSR CHPR               \ clears the C flag for when we return from the
                        \ subroutine below

 INY                    \ Increment Y to point to the next character

 DEX                    \ Decrement the loop counter

 BNE DAL5               \ Loop back for the next character until we have printed
                        \ X characters from BUF

.dec27

 RTS                    \ Return from the subroutine

.DA6

 JSR DAS1               \ Call DAS1 to print X characters from BUF, returning
                        \ with X = 0

 STX DTW5               \ Set the buffer size in DTW5 to 0, as the buffer is now
                        \ empty

 PLA                    \ Restore Y and X from the stack
 TAY
 PLA
 TAX

 LDA #12                \ Set A = 12, so when we skip BELL and fall through into
                        \ CHPR, we print character 12, which is a newline

.DA7

 EQUB &2C               \ Skip the next instruction by turning it into
                        \ &2C &A9 &07, or BIT &07A9, which does nothing apart
                        \ from affect the flags

                        \ Fall through into CHPR (skipping BELL) to print the
                        \ character and return with the C flag cleared

\ ******************************************************************************
\
\       Name: BELL
\       Type: Subroutine
\   Category: Sound
\    Summary: Make a standard system beep
\
\ ------------------------------------------------------------------------------
\
\ This is the standard system beep, as made by the ASCII 7 "BELL" control code.
\
\ ******************************************************************************

.BELL

 LDA #7                 \ Control code 7 makes a beep, so load this into A

 JMP CHPR               \ Call the CHPR print routine to actually make the sound

\ ******************************************************************************

 PRINT "ELITE B"
 PRINT "Assembled at ", ~CODE_B%
 PRINT "Ends at ", ~P%
 PRINT "Code size is ", ~(P% - CODE_B%)
 PRINT "Execute at ", ~LOAD%
 PRINT "Reload at ", ~LOAD_B%

 PRINT "S.ELTB ", ~CODE_B%, " ", ~P%, " ", ~LOAD%, " ", ~LOAD_B%
\SAVE "build/ELTB.bin", CODE_B%, P%, LOAD%

\ ******************************************************************************
\
\ ELITE C FILE
\
\ ******************************************************************************

 CODE_C% = P%

 LOAD_C% = LOAD% +P% - CODE%

\ ******************************************************************************
\
\       Name: HATB
\       Type: Variable
\   Category: Ship hangar
\    Summary: Ship hangar group table
\
\ ------------------------------------------------------------------------------
\
\ This table contains groups of ships to show in the ship hangar. A group of
\ ships is shown half the time (the other half shows a solo ship), and each of
\ the four groups is equally likely.
\
\ The bytes for each ship in the group contain the following information:
\
\   Byte #0             Non-zero = Ship type to draw
\                       0        = don't draw anything
\
\   Byte #1             Bits 0-7 = Ship's x_hi
\                       Bit 0    = Ship's z_hi (1 if clear, or 2 if set)
\
\   Byte #2             Bits 0-7 = Ship's z_lo
\                       Bit 0    = Ship's x_sign
\
\ The ship's y-coordinate is calculated in the has1 routine from the size of
\ its targetable area. Ships of type 0 are not shown.
\
\ ******************************************************************************

.HATB

                        \ Hangar group for X = 0
                        \
                        \ Cobra Mk III (left)

 EQUB 11                \ Ship type = 11 = Cobra Mk III
 EQUB %01000100         \ x_hi = %01000100 = 68, z_hi   = 1     -> x = -68
 EQUB %00111011         \ z_lo = %00111011 = 59, x_sign = 1        z = +315

 EQUB 0                 \ No second ship
 EQUB %10000010         \ x_hi = %10000010 = 130, z_hi   = 1    -> x = +130
 EQUB %10110000         \ z_lo = %10110000 = 176, x_sign = 0       z = +432

 EQUB 0                 \ No third ship
 EQUB 0
 EQUB 0

                        \ Hangar group for X = 9
                        \
                        \ Three cargo canisters (left, far right and forward,
                        \ right)

 EQUB OIL               \ Ship type = OIL = Cargo canister
 EQUB %01010000         \ x_hi = %01010000 = 80, z_hi   = 1     -> x = -80
 EQUB %00010001         \ z_lo = %00010001 = 17, x_sign = 1        z = +273

 EQUB OIL               \ Ship type = OIL = Cargo canister
 EQUB %11010001         \ x_hi = %11010001 = 209, z_hi = 2      -> x = +209
 EQUB %00101000         \ z_lo = %00101000 =  40, x_sign = 0       z = +552

 EQUB OIL               \ Ship type = OIL = Cargo canister
 EQUB %01000000         \ x_hi = %01000000 = 64, z_hi   = 1     -> x = +64
 EQUB %00000110         \ z_lo = %00000110 = 6,  x_sign = 0        z = +262

                        \ Hangar group for X = 18
                        \
                        \ Viper (right) and Krait (left)

 EQUB COPS              \ Ship type = COPS = Viper
 EQUB %01100000         \ x_hi = %01100000 =  96, z_hi   = 1    -> x = +96
 EQUB %10010000         \ z_lo = %10010000 = 144, x_sign = 0       z = +400

 EQUB KRA               \ Ship type = KRA = Krait
 EQUB %00010000         \ x_hi = %00010000 =  16, z_hi   = 1    -> x = -16
 EQUB %11010001         \ z_lo = %11010001 = 209, x_sign = 1       z = +465

 EQUB 0                 \ No third ship
 EQUB 0
 EQUB 0

                        \ Hangar group for X = 27
                        \
                        \ Adder (right and forward) and Viper (left)

 EQUB 20                \ Ship type = 20 = Adder
 EQUB %01010001         \ x_hi = %01010001 =  81, z_hi  = 2     -> x = +81
 EQUB %11111000         \ z_lo = %11111000 = 248, x_sign = 0       z = +760

 EQUB 16                \ Ship type = 16 = Viper
 EQUB %01100000         \ x_hi = %01100000 = 96,  z_hi   = 1    -> x = -96
 EQUB %01110101         \ z_lo = %01110101 = 117, x_sign = 1       z = +373

 EQUB 0                 \ No third ship
 EQUB 0
 EQUB 0

\ ******************************************************************************
\
\       Name: HALL
\       Type: Subroutine
\   Category: Ship hangar
\    Summary: Draw the ships in the ship hangar, then draw the hangar
\
\ ------------------------------------------------------------------------------
\
\ Half the time this will draw one of the four pre-defined ship hangar groups in
\ HATB, and half the time this will draw a solitary Sidewinder, Mamba, Krait or
\ Adder on a random position. In all cases, the ships will be randomly spun
\ around on the ground so they can face in any direction, and larger ships are
\ drawn higher up off the ground than smaller ships.
\
\ ******************************************************************************

.HALL

 LDA #0                 \ Switch to the mode 1 palette for the space view,
 JSR DOVDU19            \ which is yellow (colour 1), red (colour 2) and cyan
                        \ (colour 3)

 LDA #0                 \ Clear the top part of the screen, draw a border box,
 JSR TT66               \ and set the current view type in QQ11 to 0 (space
                        \ view)

 LDA #&FF               \ Port: the hangar's ships are drawn directly, not
 STA GFORCE             \ recorded for the renderer (GFORCE, gfx-gstubs.asm)

 JSR DORND              \ Set A and X to random numbers

 BPL HA7                \ Jump to HA7 if A is positive (50% chance)

 AND #3                 \ Reduce A to a random number in the range 0-3

 STA T                  \ Set X = A * 8 + A
 ASL A                  \       = 9 * A
 ASL A                  \
 ASL A                  \ so X is a random number, either 0, 9, 18 or 27
 ADC T
 TAX

                        \ The following double loop calls the HAS1 routine three
                        \ times to display three ships on screen. For each call,
                        \ the values passed to HAS1 in XX15+2 to XX15 are taken
                        \ from the HATB table, depending on the value in X, as
                        \ follows:
                        \
                        \   * If X = 0,  pass bytes #0 to #2 of HATB to HAS1
                        \                then bytes #3 to #5
                        \                then bytes #6 to #8
                        \
                        \   * If X = 9,  pass bytes  #9 to #11 of HATB to HAS1
                        \                then bytes #12 to #14
                        \                then bytes #15 to #17
                        \
                        \   * If X = 18, pass bytes #18 to #20 of HATB to HAS1
                        \                then bytes #21 to #23
                        \                then bytes #24 to #26
                        \
                        \   * If X = 27, pass bytes #27 to #29 of HATB to HAS1
                        \                then bytes #30 to #32
                        \                then bytes #33 to #35
                        \
                        \ Note that the values are passed in reverse, so for the
                        \ first call, for example, where we pass bytes #0 to #2
                        \ of HATB to HAS1, we call HAS1 with:
                        \
                        \   XX15   = HATB+2
                        \   XX15+1 = HATB+1
                        \   XX15+2 = HATB

 LDY #3                 \ Set CNT2 = 3 to act as an outer loop counter going
 STY CNT2               \ from 3 to 1, so the HAL8 loop is run 3 times

.HAL8

 LDY #2                 \ Set Y = 2 to act as an inner loop counter going from
                        \ 2 to 0

.HAL9

 LDA HATB,X             \ Copy the X-th byte of HATB to the Y-th byte of XX15,
 STA XX15,Y             \ as described above

 INX                    \ Increment X to point to the next byte in HATB

 DEY                    \ Decrement Y to point to the previous byte in XX15

 BPL HAL9               \ Loop back to copy the next byte until we have copied
                        \ three of them (i.e. Y was 3 before the DEY)

 TXA                    \ Store X on the stack so we can retrieve it after the
 PHA                    \ call to HAS1 (as it contains the index of the next
                        \ byte in HATB

 JSR HAS1               \ Call HAS1 to draw this ship in the hangar

 PLA                    \ Restore the value of X, so X points to the next byte
 TAX                    \ in HATB after the three bytes we copied into XX15

 DEC CNT2               \ Decrement the outer loop counter in CNT2

 BNE HAL8               \ Loop back to HAL8 to do it 3 times, once for each ship
                        \ in the HATB table

 LDY #128               \ Set Y = 128 to send as byte #2 of the parameter block
                        \ to the OSWORD 248 command below, to tell the I/O
                        \ processor that there are multiple ships in the hangar

 BNE HA9                \ Jump to HA9 to display the ship hangar (this BNE is
                        \ effectively a JMP as Y is never zero)

.HA7

                        \ If we get here, A is a positive random number in the
                        \ range 0-127

 LSR A                  \ Set XX15+1 = A / 2 (random number 0-63)
 STA XX15+1

 JSR DORND              \ Set XX15 = random number 0-255
 STA XX15

 JSR DORND              \ Set XX15+2 = #SH3 + random number 0-3
 AND #3                 \
 ADC #SH3               \ which is the ship type of a Sidewinder, Mamba, Krait
 STA XX15+2             \ or Adder

 JSR HAS1               \ Call HAS1 to draw this ship in the hangar, with the
                        \ following properties:
                        \
                        \   * Random x-coordinate from -63 to +63
                        \
                        \   * Randomly chosen Sidewinder, Mamba, Krait or Adder
                        \
                        \   * Random z-coordinate from +256 to +639

 LDY #0                 \ Set Y = 0 to use in the following instruction, to tell
                        \ the hangar-drawing routine that there is just one ship
                        \ in the hangar, so it knows not to draw between the
                        \ ships

.HA9

 STY HANGFLAG           \ Store Y in HANGFLAG to specify whether there are
                        \ multiple ships in the hangar

 STZ GFORCE             \ Port: back to recording (the ships are drawn)

 JMP HANGER             \ Call HANGER to draw the hangar background and return
                        \ from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: HAS1
\       Type: Subroutine
\   Category: Ship hangar
\    Summary: Draw a ship in the ship hangar
\
\ ------------------------------------------------------------------------------
\
\ The ship's position within the hangar is determined by the arguments and the
\ size of the ship's targetable area, as follows:
\
\   * The x-coordinate is (x_sign x_hi 0) from the arguments, so the ship can be
\     left of centre or right of centre
\
\   * The y-coordinate is negative and is lower down the screen for smaller
\     ships, so smaller ships are drawn closer to the ground (because they are)
\
\   * The z-coordinate is positive, with both z_hi (which is 1 or 2) and z_lo
\     coming from the arguments
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   XX15                Bits 0-7 = Ship's z_lo
\                       Bit 0    = Ship's x_sign
\
\   XX15+1              Bits 0-7 = Ship's x_hi
\                       Bit 0    = Ship's z_hi (1 if clear, or 2 if set)
\
\   XX15+2              Non-zero = Ship type to draw
\                       0        = Don't draw anything
\
\ ******************************************************************************

.HAS1

 JSR ZINF               \ Call ZINF to reset the INWK ship workspace and reset
                        \ the orientation vectors, with nosev pointing out of
                        \ the screen, so this puts the ship flat on the
                        \ horizontal deck (the y = 0 plane) with its nose
                        \ pointing towards us

 LDA XX15               \ Set z_lo = XX15
 STA INWK+6

 LSR A                  \ Set the sign bit of x_sign to bit 0 of A
 ROR INWK+2

 LDA XX15+1             \ Set x_hi = XX15+1
 STA INWK

 LSR A                  \ Set z_hi = 1 + bit 0 of XX15+1
 LDA #1
 ADC #0
 STA INWK+7

 LDA #%10000000         \ Set bit 7 of y_sign, so y is negative
 STA INWK+5

 STA RAT2               \ Set RAT2 = %10000000, so the yaw calls in HAL5 below
                        \ are negative

 LDA #&0B               \ Set the ship line heap pointer in INWK(34 33) to point
 STA INWK+34            \ to &0B00 (Port: HANGHEAP during LL9, below)

 JSR DORND              \ We now perform a random number of small angle (3.6
 STA XSAV               \ degree) rotations to spin the ship on the deck while
                        \ keeping it flat on the deck (a bit like spinning a
                        \ bottle), so we set XSAV to a random number between 0
                        \ and 255 for the number of small yaw rotations to
                        \ perform, so the ship could be pointing in any
                        \ direction by the time we're done

.HAL5

 LDX #21                \ Rotate (sidev_x, nosev_x) by a small angle (yaw)
 LDY #9
 JSR MVS5

 LDX #23                \ Rotate (sidev_y, nosev_y) by a small angle (yaw)
 LDY #11
 JSR MVS5

 LDX #25                \ Rotate (sidev_z, nosev_z) by a small angle (yaw)
 LDY #13
 JSR MVS5

 DEC XSAV               \ Decrement the yaw counter in XSAV

 BNE HAL5               \ Loop back to yaw a little more until we have yawed
                        \ by the number of times in XSAV

 LDY XX15+2             \ Set Y = XX15+2, the ship type of the ship we need to
                        \ draw

 BEQ HA1                \ If Y = 0, return from the subroutine (as HA1 contains
                        \ an RTS)

 TYA                    \ Set X = 2 * Y
 ASL A
 TAX

 LDA XX21-2,X           \ Set XX0(1 0) to the X-th address in the ship blueprint
 STA XX0                \ address lookup table at XX21, so XX0(1 0) now points
 LDA XX21-1,X           \ to the blueprint for the ship we need to draw
 STA XX0+1

 BEQ HA1                \ If the high byte of the blueprint address is 0, then
                        \ this is not a valid blueprint address, so return from
                        \ the subroutine (as HA1 contains an RTS)

 LDY #1                 \ Set Q = ship byte #1
 LDA (XX0),Y
 STA Q

 INY                    \ Set R = ship byte #2
 LDA (XX0),Y            \
 STA R                  \ so (R Q) contains the ship's targetable area, which is
                        \ a square number

 JSR LL5                \ Set Q = SQRT(R Q)

 LDA #100               \ Set y_lo = (100 - Q) / 2
 SBC Q                  \
 LSR A                  \ so the bigger the ship's targetable area, the smaller
 STA INWK+3             \ the magnitude of the y-coordinate, so because we set
                        \ y_sign to be negative above, this means smaller ships
                        \ are drawn lower down, i.e. closer to the ground, while
                        \ larger ships are drawn higher up, as you would expect

 JSR TIDY               \ Call TIDY to tidy up the orientation vectors, to
                        \ prevent the ship from getting elongated and out of
                        \ shape due to the imprecise nature of trigonometry
                        \ in assembly language

 LDA #HI(HANGHEAP)      \ Port: the line heap at HANGHEAP while LL9 draws
 STA INWK+34

 JSR LL9                \ Display the ship (Port: JSR, not a tail call, so that
                        \ the heap pointer can be put back below)

 LDA #&0B               \ Port: leave INWK(34 33) = &0B00, as the original does
 STA INWK+34

 RTS                    \ Return from the subroutine

                        \ Port: the hangar's ships are drawn directly (GFORCE,
                        \ HALL), so LL9 writes their line heaps. The original's
                        \ &0B00 holds the port's low code (DOCKIT and the
                        \ tactics helpers, elite-low.asm), which those writes
                        \ wrecked, so the heap goes in the rasteriser's HAZEL
                        \ scratch instead, unused while docked (and not DFS's
                        \ lasting state, docs/MASTER-MEMORY.md)

HANGHEAP = &C000

.HA1

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: STARS2
\       Type: Subroutine
\   Category: Stardust
\    Summary: Process the stardust for the left or right view
\  Deep dive: Stardust in the side views
\
\ ------------------------------------------------------------------------------
\
\ This moves the stardust sideways according to our speed and which side we are
\ looking out of, and applies our current pitch and roll to each particle of
\ dust, so the stardust moves correctly when we steer our ship.
\
\ These are the calculations referred to in the commentary:
\
\   1. delta_x = 8 * 256 * speed / z_hi
\   2. x = x + delta_x
\
\   3. x = x + beta * y
\   4. y = y - beta * x
\
\   5. x = x - alpha * x * y
\   6. y = y + alpha * y * y + alpha
\
\ For more information see the associated deep dive.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The view to process:
\
\                         * X = 1 for left view
\
\                         * X = 2 for right view
\
\ ******************************************************************************

.STARS2

 LDA #0                 \ Set A to 0 so we can use it to capture a sign bit

 CPX #2                 \ If X >= 2 then the C flag is set

 ROR A                  \ Roll the C flag into the sign bit of A and store in
 STA RAT                \ RAT, so:
                        \
                        \   * Left view, C is clear so RAT = 0 (positive)
                        \
                        \   * Right view, C is set so RAT = 128 (negative)
                        \
                        \ RAT represents the end of the x-axis where we want new
                        \ stardust particles to come from: positive for the left
                        \ view where new particles come in from the right,
                        \ negative for the right view where new particles come
                        \ in from the left

 EOR #%10000000         \ Set RAT2 to the opposite sign, so:
 STA RAT2               \
                        \   * Left view, RAT2 = 128 (negative)
                        \
                        \   * Right view, RAT2 = 0 (positive)
                        \
                        \ RAT2 represents the direction in which stardust
                        \ particles should move along the x-axis: negative for
                        \ the left view where particles go from right to left,
                        \ positive for the right view where particles go from
                        \ left to right

 JSR ST2                \ Call ST2 to flip the signs of the following if this is
                        \ the right view: ALPHA, ALP2, ALP2+1, BET2 and BET2+1

 LDY NOSTM              \ Set Y to the current number of stardust particles, so
                        \ we can use it as a counter through all the stardust

.STL2

 LDA SZ,Y               \ Set A = ZZ = z_hi

 STA ZZ                 \ We also set ZZ to the original value of z_hi, which we
                        \ use below to remove the existing particle

 LSR A                  \ Set A = z_hi / 8
 LSR A
 LSR A

 JSR DV41               \ Call DV41 to set the following:
                        \
                        \   (P R) = 256 * DELTA / A
                        \         = 256 * speed / (z_hi / 8)
                        \         = 8 * 256 * speed / z_hi
                        \
                        \ This represents the distance we should move this
                        \ particle along the x-axis, let's call it delta_x

 LDA P                  \ Store the high byte of delta_x in newzp
 STA newzp

 EOR RAT2               \ Set S = P but with the sign from RAT2, so we now have
 STA S                  \ the distance delta_x with the correct sign in (S R):
                        \
                        \   (S R) = delta_x
                        \         = 8 * 256 * speed / z_hi
                        \
                        \ So (S R) is the delta, signed to match the direction
                        \ the stardust should move in, which is result 1 above

 LDA SXL,Y              \ Set (A P) = (x_hi x_lo)
 STA P                  \           = x
 LDA SX,Y

 STA X1                 \ Set X1 = A, so X1 contains the original value of x_hi,
                        \ which we use below to remove the existing particle

 JSR ADD                \ Call ADD to calculate:
                        \
                        \   (A X) = (A P) + (S R)
                        \         = x + delta_x

 STA S                  \ Set (S R) = (A X)
 STX R                  \           = x + delta_x

 LDA SY,Y               \ Set A = y_hi

 STA Y1                 \ Set Y1 = A, so Y1 contains the original value of y_hi,
                        \ which we use below to remove the existing particle

 EOR BET2               \ Give A the correct sign of A * beta, i.e. y_hi * beta

 LDX BET1               \ Fetch |beta| from BET1, the pitch angle

 JSR MULTS-2            \ Call MULTS-2 to calculate:
                        \
                        \   (A P) = X * A
                        \         = beta * y_hi

 JSR ADD                \ Call ADD to calculate:
                        \
                        \   (A X) = (A P) + (S R)
                        \         = beta * y + x + delta_x

 STX XX                 \ Set XX(1 0) = (A X), which gives us results 2 and 3
 STA XX+1               \ above, done at the same time:
                        \
                        \   x = x + delta_x + beta * y

 LDX SYL,Y              \ Set (S R) = (y_hi y_lo)
 STX R                  \           = y
 LDX Y1
 STX S

 LDX BET1               \ Fetch |beta| from BET1, the pitch angle

 EOR BET2+1             \ Give A the opposite sign to x * beta

 JSR MULTS-2            \ Call MULTS-2 to calculate:
                        \
                        \   (A P) = X * A
                        \         = -beta * x

 JSR ADD                \ Call ADD to calculate:
                        \
                        \   (A X) = (A P) + (S R)
                        \         = -beta * x + y

 STX YY                 \ Set YY(1 0) = (A X), which gives us result 4 above:
 STA YY+1               \
                        \   y = y - beta * x

 LDX ALP1               \ Set X = |alpha| from ALP2, the roll angle

 EOR ALP2               \ Give A the correct sign of A * alpha, i.e. y_hi *
                        \ alpha

 JSR MULTS-2            \ Call MULTS-2 to calculate:
                        \
                        \   (A P) = X * A
                        \         = alpha * y

 STA Q                  \ Set Q = high byte of alpha * y

 LDA XX                 \ Set (S R) = XX(1 0)
 STA R                  \           = x
 LDA XX+1               \
 STA S                  \ and set A = y_hi at the same time

 EOR #%10000000         \ Flip the sign of A = -x_hi

 JSR MAD                \ Call MAD to calculate:
                        \
                        \   (A X) = Q * A + (S R)
                        \         = alpha * y * -x + x

 STA XX+1               \ Store the high byte A in XX+1

 TXA                    \ Store the low byte X in x_lo
 STA SXL,Y

                        \ So (XX+1 x_lo) now contains result 5 above:
                        \
                        \   x = x - alpha * x * y

 LDA YY                 \ Set (S R) = YY(1 0)
 STA R                  \           = y
 LDA YY+1               \
 STA S                  \ and set A = y_hi at the same time

 JSR MAD                \ Call MAD to calculate:
                        \
                        \   (A X) = Q * A + (S R)
                        \         = alpha * y * y_hi + y

 STA S                  \ Set (S R) = (A X)
 STX R                  \           = y + alpha * y * y

 LDA #0                 \ Set P = 0
 STA P

 LDA ALPHA              \ Set A = alpha, so:
                        \
                        \   (A P) = (alpha 0)
                        \         = alpha / 256

 JSR PIX1               \ Call PIX1 to calculate the following:
                        \
                        \   (YY+1 y_lo) = (A P) + (S R)
                        \               = alpha * 256 + y + alpha * y * y
                        \
                        \ i.e. y = y + alpha / 256 + alpha * y^2, which is
                        \ result 6 above
                        \
                        \ PIX1 also draws a particle at (X1, Y1) with distance
                        \ ZZ, which will remove the old stardust particle, as we
                        \ set X1, Y1 and ZZ to the original values for this
                        \ particle during the calculations above

                        \ We now have our newly moved stardust particle at
                        \ x-coordinate (XX+1 x_lo) and y-coordinate (YY+1 y_lo)
                        \ and distance z_hi, so we draw it if it's still on
                        \ screen, otherwise we recycle it as a new bit of
                        \ stardust and draw that

 LDA XX+1               \ Set X1 and x_hi to the high byte of XX in XX+1, so
 STA SX,Y               \ the new x-coordinate is in (x_hi x_lo) and the high
 STA X1                 \ byte is in X1

 AND #%01111111         \ Set A = ~|x_hi|, which is the same as -(x_hi + 1)
 EOR #%01111111         \ using two's complement

 CMP newzp              \ If newzp <= -(x_hi + 1), then the particle has been
 BCC KILL2              \ moved off the side of the screen and has wrapped
 BEQ KILL2              \ round to the other side, jump to KILL2 to recycle this
                        \ particle and rejoin at STC2 with the new particle
                        \
                        \ In the original BBC Micro versions, this test simply
                        \ checks whether |x_hi| >= 116, but this version using
                        \ newzp doesn't hard-code the screen width, so this is
                        \ presumably a change that was introduced to support
                        \ the different screen sizes of the other platforms

 LDA YY+1               \ Set Y1 and y_hi to the high byte of YY in YY+1, so
 STA SY,Y               \ the new x-coordinate is in (y_hi y_lo) and the high
 STA Y1                 \ byte is in Y1

 AND #%01111111         \ If |y_hi| >= 116 then jump to ST5 to recycle this
 CMP #116               \ particle, as it's gone off the top or bottom of the
 BCS ST5                \ screen, and rejoin at STC2 with the new particle

.STC2

 JSR PIXEL2             \ Draw a stardust particle at (X1,Y1) with distance ZZ,
                        \ i.e. draw the newly moved particle at (x_hi, y_hi)
                        \ with distance z_hi

 DEY                    \ Decrement the loop counter to point to the next
                        \ stardust particle

 BEQ ST2                \ If we have just done the last particle, skip the next
                        \ instruction to return from the subroutine

 JMP STL2               \ We have more stardust to process, so jump back up to
                        \ STL2 for the next particle

                        \ Fall through into ST2 to restore the signs of the
                        \ following if this is the right view: ALPHA, ALP2,
                        \ ALP2+1, BET2 and BET2+1

.ST2

 LDA ALPHA              \ If this is the right view, flip the sign of ALPHA
 EOR RAT
 STA ALPHA

 LDA ALP2               \ If this is the right view, flip the sign of ALP2
 EOR RAT
 STA ALP2

 EOR #%10000000         \ If this is the right view, flip the sign of ALP2+1
 STA ALP2+1

 LDA BET2               \ If this is the right view, flip the sign of BET2
 EOR RAT
 STA BET2

 EOR #%10000000         \ If this is the right view, flip the sign of BET2+1
 STA BET2+1

 RTS                    \ Return from the subroutine

.KILL2

 JSR DORND              \ Set A and X to random numbers

 STA Y1                 \ Set y_hi and Y1 to random numbers, so the particle
 STA SY,Y               \ starts anywhere along the y-axis

 LDA #115               \ Make sure A is at least 115 and has the sign in RAT
 ORA RAT

 STA X1                 \ Set x_hi and X1 to A, so this particle starts on the
 STA SX,Y               \ correct edge of the screen for new particles

 BNE STF1               \ Jump down to STF1 to set the z-coordinate (this BNE is
                        \ effectively a JMP as A will never be zero)

.ST5

 JSR DORND              \ Set A and X to random numbers

 STA X1                 \ Set x_hi and X1 to random numbers, so the particle
 STA SX,Y               \ starts anywhere along the x-axis

 LDA #110               \ Make sure A is at least 110 and has the sign in AL2+1,
 ORA ALP2+1             \ the flipped sign of the roll angle alpha

 STA Y1                 \ Set y_hi and Y1 to A, so the particle starts at the
 STA SY,Y               \ top or bottom edge, depending on the current roll
                        \ angle alpha

.STF1

 JSR DORND              \ Set A and X to random numbers

 ORA #8                 \ Make sure A is at least 8 and store it in z_hi and
 STA ZZ                 \ ZZ, so the new particle starts at any distance from
 STA SZ,Y               \ us, but not too close

 BNE STC2               \ Jump up to STC2 to draw this new particle (this BNE is
                        \ effectively a JMP as A will never be zero)

\ ******************************************************************************
\
\       Name: MU5
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Set K(3 2 1 0) = (A A A A) and clear the C flag
\
\ ------------------------------------------------------------------------------
\
\ In practice this is only called via a BEQ following an AND instruction, in
\ which case A = 0, so this routine effectively does this:
\
\   K(3 2 1 0) = 0
\
\ ******************************************************************************

.MU5

 STA K                  \ Set K(3 2 1 0) to (A A A A)
 STA K+1
 STA K+2
 STA K+3

 CLC                    \ Clear the C flag

 RTS                    \ Return from the subroutine

\ Port: QMUL src, dst, mul (MULT3 and MLTU2): A = src * mul, 8-bit by 8-bit
\ by quarter squares (QSL and QSH, elite-hi.asm), the low byte in dst; X and Y
\ are clobbered

MACRO QMUL src, dst, mul
 LDA src                \ Y = |src - mul|
 SEC
 SBC mul
 BCS d
 EOR #&FF
 ADC #1
.d
 TAY
 LDA src                \ X = src + mul, C = bit 8
 CLC
 ADC mul
 TAX
 BCS h
 LDA QSL,X
 SEC
 SBC QSL,Y
 STA dst
 LDA QSH,X
 SBC QSH,Y
 BRA e
.h
 LDA QSL+256,X
 SEC
 SBC QSL,Y
 STA dst
 LDA QSH+256,X
 SBC QSH,Y
.e
ENDMACRO

\ ******************************************************************************
\
\       Name: MULT3
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate K(3 2 1 0) = (A P+1 P) * Q
\  Deep dive: Shift-and-add multiplication
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following multiplication between a signed 24-bit number and a
\ signed 8-bit number, returning the result as a signed 32-bit number:
\
\   K(3 2 1 0) = (A P+1 P) * Q
\
\ The algorithm is the same shift-and-add algorithm as in routine MULT1, but
\ extended to cope with more bits.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              The C flag is cleared
\
\ ******************************************************************************

.MULT3

                        \ Port: by quarter squares (QSL and QSH, elite-hi.asm):
                        \ the three bytes' products by |Q|, added. Exactly the
                        \ original's results: K(3 2 1 0) with the sign of A
                        \ EOR Q, A = K+3, T = K+3 without the sign, R = the
                        \ argument A, X = 0, Y kept, C clear, N and Z from A

 STA R                  \ Store the high byte of (A P+1 P) in R

 AND #%01111111         \ Set K+2 to |A|, the high byte of K(2 1 0)
 STA K+2

 LDA Q                  \ Set A to bits 0-6 of Q, so A = |Q|
 AND #%01111111

 BEQ MU5                \ If |Q| = 0, jump to MU5 to set K(3 2 1 0) to 0,
                        \ returning from the subroutine using a tail call

 STA T                  \ Set T = |Q| for the products

 PHY                    \ Keep Y

 QMUL K+2, K+2, T       \ Set (K+3 K+2) = |A| * |Q|
 STA K+3

 QMUL P+1, K+1, T       \ Set (A K+1) = P+1 * |Q| and add A to (K+3 K+2)
 CLC
 ADC K+2
 STA K+2
 BCC mlt3
 INC K+3

.mlt3

 QMUL P, K, T           \ Set (A K) = P * |Q| and add A to (K+3 K+2 K+1)
 CLC
 ADC K+1
 STA K+1
 LDA K+2
 ADC #0
 STA K+2
 LDA K+3
 ADC #0

 STA T                  \ Save the high byte of the result into T

 LDX #0                 \ X = 0 and C clear, as the original leaves them
 PLY                    \ (and restore Y)
 CLC

 LDA R                  \ Fetch the sign byte from the original (A P+1 P)
                        \ argument that we stored in R

 EOR Q                  \ EOR with Q so the sign bit is the same as that of
                        \ (A P+1 P) * Q

 AND #%10000000         \ Extract the sign bit

 ORA T                  \ Apply this to the high byte of the result in T

 STA K+3                \ Store A in K+3, so K(3 2 1 0) now contains the result

 RTS                    \ Return from the subroutine


\ ******************************************************************************
\
\       Name: MLS2
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (S R) = XX(1 0) and (A P) = A * ALP1
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following:
\
\   (S R) = XX(1 0)
\
\   (A P) = A * ALP1
\
\ where ALP1 is the magnitude of the current roll angle alpha, in the range
\ 0-31.
\
\ ******************************************************************************

.MLS2

 LDX XX                 \ Set (S R) = XX(1 0), starting with the low bytes
 STX R

 LDX XX+1               \ And then doing the high bytes
 STX S

                        \ Fall through into MLS1 to calculate (A P) = A * ALP1

\ ******************************************************************************
\
\       Name: MLS1
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (A P) = ALP1 * A
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following:
\
\   (A P) = ALP1 * A
\
\ where ALP1 is the magnitude of the current roll angle alpha, in the range
\ 0-31.
\
\ This routine uses an unrolled version of MU11. MU11 calculates P * X, so we
\ use the same algorithm but with P set to ALP1 and X set to A. The unrolled
\ version here can skip the bit tests for bits 5-7 of P as we know P < 32, so
\ only 5 shifts with bit tests are needed (for bits 0-4), while the other 3
\ shifts can be done without a test (for bits 5-7).
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   MULTS-2             Calculate (A P) = X * A
\
\ ******************************************************************************

.MLS1

 LDX ALP1               \ Set P to the roll angle alpha magnitude in ALP1
 STX P                  \ (0-31), so now we calculate P * A

.MULTS

                        \ Port: the product by quarter squares (the tables QSL
                        \ and QSH, elite-hi.asm), with exactly the original's
                        \ results: (A P) = |A| * (P AND 31) with A's sign (the
                        \ shift-and-add only used bits 0-4 of P), T1 =
                        \ |A| - 1, T = the sign, Y kept, N and Z from A (X and
                        \ C are left differently, but no caller reads them)

 STA T                  \ Set T = A for now

 AND #%01111111         \ Set A = |A|

 BEQ MU6                \ If A = 0, jump to MU6 to set P(1 0) = 0 and return
                        \ (T = A = its sign bit already)

 TRB T                  \ Clear |A|'s bits in T, leaving T = the sign bit

 PHY                    \ Keep Y

 DEC A                  \ Set T1 = |A| - 1
 STA T1

 TXA                    \ Set Y = b = P AND 31 (X = P on entry: MULTS is only
                        \ reached by falling through from MLS1's or MULTS-2's
                        \ STX P)
 AND #31
 TAY

 CLC                    \ Set X = b + |A| - 1 (< 256, so C stays clear), so
 ADC T1                 \ QSL+1,X is QS(b + |A|)
 TAX

 TYA                    \ Set A = b - |A| (C clear: b - T1 - 1 = b - |A|)
 SBC T1
 BCS mlt4               \ If b >= |A| (rare), jump to mlt4
 EOR #&FF               \ Set A = |A| - b - 1, so QSL+1,Y is QS(|A| - b)

.mlt1

 TAY

 LDA QSL+1,X            \ Set (A P) = (b + |A|)^2 / 4 - (b - |A|)^2 / 4
 SEC                    \           = b * |A|
 SBC QSL+1,Y
 STA P
 LDA QSH+1,X
 SBC QSH+1,Y

.mlt5

 PLY                    \ Restore Y

 ORA T                  \ Give A the sign bit of the original argument A that
                        \ we stored in T

 RTS                    \ Return from the subroutine

.mlt4

 DEC A                  \ Set A = b - |A| - 1 (-1..30) and if b > |A|, use it
 BPL mlt1               \ as the QSL+1,Y index of QS(b - |A|)

 LDA QSL+1,X            \ b = |A|, so (A P) = QS(2|A|) - QS(0) = QS(2|A|)
 STA P
 LDA QSH+1,X
 BRA mlt5

.MU6

 STA P+1                \ Set P(1 0) = (A A)
 STA P

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: SQUA
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Clear bit 7 of A and calculate (A P) = A * A
\
\ ------------------------------------------------------------------------------
\
\ Do the following multiplication of unsigned 8-bit numbers, after first
\ clearing bit 7 of A:
\
\   (A P) = A * A
\
\ ******************************************************************************

.SQUA

 AND #%01111111         \ Clear bit 7 of A and fall through into SQUA2 to set
                        \ (A P) = A * A

\ ******************************************************************************
\
\       Name: SQUA2
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (A P) = A * A
\
\ ------------------------------------------------------------------------------
\
\ Do the following multiplication of unsigned 8-bit numbers:
\
\   (A P) = A * A
\
\ ******************************************************************************

.SQUA2

 STA P                  \ Copy A into P and X
 TAX

 BEQ MU1                \ If X = 0 jump to MU1 to return a 0

                        \ Port: P * P by quarter squares directly, with MU11's
                        \ exact results: |P - P| = 0 and QS(0) = 0, so
                        \ (A P) = QS(2P); T = P - 1, X = 0, Y kept, C and V
                        \ clear, Z set, N clear (as MU11's SBC QSH / LDX #0)

 DEX                    \ Set T = X - 1
 STX T

 ASL A                  \ X = 2P mod 256, C = bit 8 of 2P
 TAX

 BCS sq5

 LDA QSL,X              \ (A P) = QS(2P) = P * P
 STA P
 LDA QSH,X

.sq6

 LDX #0                 \ X = 0, V and C clear, as MU11 leaves them
 CLV
 CLC

 RTS                    \ Return from the subroutine

.sq5

 LDA QSL+256,X          \ As above, with 2P - 256 in X
 STA P
 LDA QSH+256,X
 BRA sq6

\ ******************************************************************************
\
\       Name: MU1
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Copy X into P and A, and clear the C flag
\
\ ------------------------------------------------------------------------------
\
\ Used to return a 0 result quickly from MULTU below.
\
\ ******************************************************************************

.MU1

 CLC                    \ Clear the C flag

 STX P                  \ Copy X into P and A
 TXA

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: MLU1
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate Y1 = y_hi and (A P) = |y_hi| * Q for Y-th stardust
\
\ ------------------------------------------------------------------------------
\
\ Do the following assignment, and multiply the Y-th stardust particle's
\ y-coordinate with an unsigned number Q:
\
\   Y1 = y_hi
\
\   (A P) = |y_hi| * Q
\
\ ******************************************************************************

.MLU1

 LDA SY,Y               \ Set Y1 the Y-th byte of SY
 STA Y1

                        \ Fall through into MLU2 to calculate:
                        \
                        \   (A P) = |A| * Q

\ ******************************************************************************
\
\       Name: MLU2
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (A P) = |A| * Q
\
\ ------------------------------------------------------------------------------
\
\ Do the following multiplication of a sign-magnitude 8-bit number P with an
\ unsigned number Q:
\
\   (A P) = |A| * Q
\
\ ******************************************************************************

.MLU2

 AND #%01111111         \ Clear the sign bit in P, so P = |A|
 STA P

                        \ Fall through into MULTU to calculate:
                        \
                        \   (A P) = P * Q
                        \         = |A| * Q

\ ******************************************************************************
\
\       Name: MULTU
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (A P) = P * Q
\
\ ------------------------------------------------------------------------------
\
\ Do the following multiplication of unsigned 8-bit numbers:
\
\   (A P) = P * Q
\
\ ******************************************************************************

.MULTU

 LDX Q                  \ Set X = Q

 BEQ MU1                \ If X = Q = 0, jump to MU1 to copy X into P and A,
                        \ clear the C flag and return from the subroutine using
                        \ a tail call

                        \ Otherwise fall through into MU11 to set (A P) = P * X

\ ******************************************************************************
\
\       Name: MU11
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (A P) = P * X
\  Deep dive: Shift-and-add multiplication
\
\ ------------------------------------------------------------------------------
\
\ Do the following multiplication of two unsigned 8-bit numbers:
\
\   (A P) = P * X
\
\ This uses the same shift-and-add approach as MULT1, but it's simpler as we
\ are dealing with unsigned numbers in P and X.
\
\ ******************************************************************************

.MU11

                        \ Port: the product by quarter squares (the tables QSL
                        \ and QSH, elite-hi.asm), with exactly the original's
                        \ results: (A P) = P * X (X = 1..255), T = X - 1,
                        \ X = 0, Y kept, C clear (callers use it)

 DEX                    \ Set T = X - 1 (X is never 0 here: MULTU's
 STX T                  \ fall-through after BEQ MU1 guarantees X <> 0)

 PHY                    \ Keep Y

 LDA P                  \ Set X = P + X, with C set if it is 256 or more
 SEC
 ADC T
 TAX

 BCS mu5                \ If P + X >= 256, jump to mu5 for the tables' upper
                        \ halves

 LDA P                  \ Set Y = |P - X| (C is clear here as BCS mu5 was
 SBC T                  \ not taken, so this is P - T - 1 = P - X)
 BCS mu4
 EOR #&FF
 ADC #1

.mu4

 TAY

 LDA QSL,X              \ Set (A P) = (P + X)^2 / 4 - (P - X)^2 / 4
 SEC                    \           = P * X
 SBC QSL,Y
 STA P
 LDA QSH,X
 SBC QSH,Y

.mu7

 PLY                    \ Restore Y

 LDX #0                 \ X = 0 and C clear, as the original leaves them
 CLC

 RTS                    \ Return from the subroutine

.mu5

 LDA P                  \ Set Y = |P - X|
 CLC
 SBC T
 BCS mu6
 EOR #&FF
 ADC #1

.mu6

 TAY

 LDA QSL+256,X          \ As above, with P + X - 256 in X
 SEC
 SBC QSL,Y
 STA P
 LDA QSH+256,X
 SBC QSH,Y

 BRA mu7                \ Restore Y, set X = 0 and C clear, and return


\ ******************************************************************************
\
\       Name: FMLTU2
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate A = K * sin(A)
\  Deep dive: The sine, cosine and arctan tables
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following:
\
\   A = K * sin(A)
\
\ Because this routine uses the sine lookup table SNE, we can also call this
\ routine to calculate cosine multiplication. To calculate the following:
\
\   A = K * cos(B)
\
\ call this routine with B + 16 in the accumulator, as sin(B + 16) = cos(B).
\
\ ******************************************************************************

.FMLTU2

 AND #%00011111         \ Restrict A to bits 0-5 (so it's in the range 0-31)

 TAX                    \ Set Q = sin(A) * 256
 LDA SNE,X
 STA Q

 LDA K                  \ Set A to the radius in K

                        \ Fall through into FMLTU to do the following:
                        \
                        \   (A ?) = A * Q
                        \         = K * sin(A) * 256
                        \
                        \ which is equivalent to:
                        \
                        \   A = K * sin(A)

\ ******************************************************************************
\
\       Name: FMLTU
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate A = A * Q / 256
\  Deep dive: Multiplication and division using logarithms
\
\ ------------------------------------------------------------------------------
\
\ Do the following multiplication of two unsigned 8-bit numbers, returning only
\ the high byte of the result:
\
\   (A ?) = A * Q
\
\ or, to put it another way:
\
\   A = A * Q / 256
\
\ The advanced versions of Elite use logarithms to speed up the multiplication
\ process.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              The C flag is clear if A = 0, or set if we return a
\                       result from one of the log tables
\
\ ******************************************************************************

.FMLTU

 STX P                  \ Store X in P so we can preserve it through the call to
                        \ FMLTU

 STA FMLA+1             \ Port: store A in the low byte of the operand of the
                        \ ADC at FMLA (log is page-aligned), so that ADC reads
                        \ log + A = high byte of La without reloading A into X

 TAX                    \ Transfer A into X, so now X = argument A

 BEQ MU3                \ If A = 0, jump to MU3 to return a result of 0, as
                        \ 0 * Q / 256 is always 0

                        \ We now want to calculate La + Lq, first adding the low
                        \ bytes (from the logL table), and then the high bytes
                        \ (from the log table)

 LDA logL,X             \ Set A = low byte of La
                        \       = low byte of La (as we set X to A above)

 LDX Q                  \ Set X = Q

 BEQ MU3again           \ If X = 0, jump to MU3again to return a result of 0, as
                        \ A * 0 / 256 is always 0

 CLC                    \ Set A = A + low byte of Lq
 ADC logL,X             \       = low byte of La + low byte of Lq

 LDA log,X              \ Set A = high byte of Lq

 ASSERT LO(log) = 0     \ (the operand's low byte is the argument A)

.FMLA

 ADC log                \ Set A = A + C + high byte of La
                        \       = high byte of Lq + high byte of La + C
                        \
                        \ (self-modified: the operand is log + argument A)
                        \
                        \ so we now have:
                        \
                        \   A = high byte of (La + Lq)

 BCC MU3again           \ If the addition fitted into one byte and didn't carry,
                        \ then La + Lq < 256, so we jump to MU3again to return a
                        \ result of 0 and the C flag clear

                        \ If we get here then the C flag is set, ready for when
                        \ we return from the subroutine below

 TAX                    \ Otherwise La + Lq >= 256, so we return the A-th entry
 LDA alogh,X            \ from the antilog table

 LDX P                  \ Restore X from P so it is preserved

 RTS                    \ Return from the subroutine

.MU3again

 LDA #0                 \ Set A = 0

.MU3

                        \ If we get here then A (our result) is already 0

 LDX P                  \ Restore X from P so it is preserved

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: MLTU2
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (A P+1 P) = (A ~P) * Q
\  Deep dive: Shift-and-add multiplication
\
\ ------------------------------------------------------------------------------
\
\ Do the following multiplication of an unsigned 16-bit number and an unsigned
\ 8-bit number:
\
\   (A P+1 P) = (A ~P) * Q
\
\ where ~P means P EOR %11111111 (i.e. P with all its bits flipped). In other
\ words, if you wanted to calculate &1234 * &56, you would:
\
\   * Set A to &12
\   * Set P to &34 EOR %11111111 = &CB
\   * Set Q to &56
\
\ before calling MLTU2.
\
\ This routine is like a mash-up of MU11 and FMLTU. It uses part of FMLTU's
\ inverted argument trick to work out whether or not to do an addition, and like
\ MU11 it sets up a counter in X to extract bits from (P+1 P). But this time we
\ extract 16 bits from (P+1 P), so the result is a 24-bit number. The core of
\ the algorithm is still the shift-and-add approach explained in MULT1, just
\ with more bits.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   Q                   Q is preserved
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   MLTU2-2             Set Q to X, so this calculates (A P+1 P) = (A ~P) * X
\
\ ******************************************************************************

 STX Q                  \ Store X in Q

.MLTU2

                        \ Port: by quarter squares (QSL and QSH, elite-hi.asm):
                        \ (A P+1 P) = Q * (A ~P) as the two bytes' products,
                        \ added. Exactly the original's results: X = 0, Q and Y
                        \ kept, C clear (N and Z differ: no caller reads them)

 PHY                    \ Keep Y

 STA P+1                \ Set P+1 = A and P = ~P, the two bytes
 LDA P
 EOR #&FF
 STA P

 QMUL P, P, Q           \ Set (A P) = ~P * Q

 PHA                    \ Keep the high byte

 QMUL P+1, P+1, Q       \ Set (A P+1) = A * Q

 TAX                    \ Add the first product's high byte to (A P+1)
 PLA
 CLC
 ADC P+1
 STA P+1
 TXA
 ADC #0

 LDX #0                 \ X = 0 and C clear, as the original leaves them
 PLY                    \ (and restore Y)
 CLC

 RTS                    \ Return from the subroutine


\ ******************************************************************************
\
\       Name: MUT3
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: An unused routine that does the same as MUT2
\
\ ------------------------------------------------------------------------------
\
\ This routine is never actually called, but it is identical to MUT2, as the
\ extra instructions have no effect.
\
\ ******************************************************************************

.MUT3

 LDX ALP1               \ Set P = ALP1, though this gets overwritten by the
 STX P                  \ following, so this has no effect

                        \ Fall through into MUT2 to do the following:
                        \
                        \   (S R) = XX(1 0)
                        \   (A P) = Q * A

\ ******************************************************************************
\
\       Name: MUT2
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (S R) = XX(1 0) and (A P) = Q * A
\
\ ------------------------------------------------------------------------------
\
\ Do the following assignment, and multiplication of two signed 8-bit numbers:
\
\   (S R) = XX(1 0)
\   (A P) = Q * A
\
\ ******************************************************************************

.MUT2

 LDX XX+1               \ Set S = XX+1
 STX S

                        \ Fall through into MUT1 to do the following:
                        \
                        \   R = XX
                        \   (A P) = Q * A

\ ******************************************************************************
\
\       Name: MUT1
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate R = XX and (A P) = Q * A
\
\ ------------------------------------------------------------------------------
\
\ Do the following assignment, and multiplication of two signed 8-bit numbers:
\
\   R = XX
\   (A P) = Q * A
\
\ ******************************************************************************

.MUT1

 LDX XX                 \ Set R = XX
 STX R

                        \ Fall through into MULT1 to do the following:
                        \
                        \   (A P) = Q * A

\ ******************************************************************************
\
\       Name: MULT1
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (A P) = Q * A
\  Deep dive: Shift-and-add multiplication
\
\ ------------------------------------------------------------------------------
\
\ Do the following multiplication of two 8-bit sign-magnitude numbers:
\
\   (A P) = Q * A
\
\ ******************************************************************************

.MULT1

                        \ Port: the product by quarter squares (the tables QSL
                        \ and QSH, elite-hi.asm), with exactly the original's
                        \ results: (A P) = |A| * |Q| with the sign of A EOR Q,
                        \ T = the sign, Y kept; |Q| = 0: A = P = 0, X = the
                        \ argument A, C = its bit 0, Z set; else X = 0, T1 =
                        \ |Q| - 1, C clear, N and Z from A

 TAX                    \ Store A in X

 EOR Q                  \ Set T to the sign bit of Q * A
 AND #%10000000
 STA T

 LDA Q                  \ Set A = |Q|
 AND #%01111111

 BEQ mu10               \ If |Q| = 0 jump to mu10

 PHY                    \ Keep Y

 DEC A                  \ Set T1 = |Q| - 1
 STA T1

 TXA                    \ Set Y = |A| (Y is free, as it is saved on the stack)
 AND #%01111111
 TAY

 SEC                    \ Set X = |A| + |Q| (< 256)
 ADC T1
 TAX

 TYA                    \ Set Y = ||A| - |Q|| (C is already clear, as
 SBC T1                 \ |A| + |Q| <= 254 in the ADC above)
 BCS mlt2               \ C set on both paths into mlt2 for the SBC below
 EOR #&FF
 INC A
 SEC

.mlt2

 TAY

 LDA QSL,X              \ Set (A P) = (|A| + |Q|)^2 / 4 - (|A| - |Q|)^2 / 4
 SBC QSL,Y              \           = |A| * |Q|
 STA P
 LDA QSH,X
 SBC QSH,Y

 PLY                    \ Restore Y

 LDX #0                 \ X = 0 and C clear, as the original leaves them
 CLC

 ORA T                  \ Set the sign bit of the result that we stored in T

 RTS                    \ Return from the subroutine

.mu10

 TXA                    \ The result is 0: as the original, C = bit 0 of the
 LSR A                  \ argument A (still in X), A = P = 0 and Z set
 LDA #0
 STA P

 RTS                    \ Return from the subroutine


\ ******************************************************************************
\
\       Name: MULT12
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (S R) = Q * A
\
\ ------------------------------------------------------------------------------
\
\ Calculate:
\
\   (S R) = Q * A
\
\ ******************************************************************************

.MULT12

 JSR MULT1              \ Set (A P) = Q * A

 STA S                  \ Set (S R) = (A P)
 LDA P                  \           = Q * A
 STA R

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TAS3
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Calculate the dot product of XX15 and an orientation vector
\
\ ------------------------------------------------------------------------------
\
\ Calculate the dot product of the vector in XX15 and one of the orientation
\ vectors, as determined by the value of Y. If vect is the orientation vector,
\ we calculate this:
\
\   (A X) = vect . XX15
\         = vect_x * XX15 + vect_y * XX15+1 + vect_z * XX15+2
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   Y                   The orientation vector:
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

.TAS3

 LDX INWK,Y             \ Set Q = the Y-th byte of INWK, i.e. vect_x
 STX Q

 LDA XX15               \ Set A = XX15

 JSR MULT12             \ Set (S R) = Q * A
                        \           = vect_x * XX15

 LDX INWK+2,Y           \ Set Q = the Y+2-th byte of INWK, i.e. vect_y
 STX Q

 LDA XX15+1             \ Set A = XX15+1

 JSR MAD                \ Set (A X) = Q * A + (S R)
                        \           = vect_y * XX15+1 + vect_x * XX15

 STA S                  \ Set (S R) = (A X)
 STX R

 LDX INWK+4,Y           \ Set Q = the Y+2-th byte of INWK, i.e. vect_z
 STX Q

 LDA XX15+2             \ Set A = XX15+2

                        \ Fall through into MAD to set:
                        \
                        \   (A X) = Q * A + (S R)
                        \           = vect_z * XX15+2 + vect_y * XX15+1 +
                        \             vect_x * XX15

\ ******************************************************************************
\
\       Name: MAD
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (A X) = Q * A + (S R)
\
\ ------------------------------------------------------------------------------
\
\ Calculate
\
\   (A X) = Q * A + (S R)
\
\ ******************************************************************************

.MAD

 LDX Q                  \ If |Q| = 0, i.e. Q = 0 or &80, then Q * A = 0, so
 BEQ mad2               \ skip MULT1 (whose other effects, X, T and the flags,
 CPX #%10000000         \ ADD overwrites) and do ADD's work with (A P) = 0,
 BNE mad1               \ otherwise jump to mad1 to call MULT1

.mad2

 STZ P                  \ Set (A P) = 0, and do ADD's work directly: with
 STZ T1                 \ A = 0, ADD sets T1 = T = 0 and, if S is positive,
 STZ T                  \ returns (A X) = (S R) with C = V = 0 and N/Z from S;
 LDX R                  \ if S is negative it goes to MU8 with P = T1 = T = 0
 LDA S
 BMI MU8
 CLC
 CLV
 RTS

\ ******************************************************************************
\
\       Name: ADD
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (A X) = (A P) + (S R)
\  Deep dive: Adding sign-magnitude numbers
\
\ ------------------------------------------------------------------------------
\
\ Add two 16-bit sign-magnitude numbers together, calculating:
\
\   (A X) = (A P) + (S R)
\
\ ******************************************************************************

.ADD

 STA T1                 \ Store argument A in T1

 AND #%10000000         \ Extract the sign (bit 7) of A and store it in T
 STA T

 EOR S                  \ EOR bit 7 of A with S. If they have different bit 7s
 BMI MU8                \ (i.e. they have different signs) then bit 7 in the
                        \ EOR result will be 1, which means the EOR result is
                        \ negative. So the AND, EOR and BMI together mean "jump
                        \ to MU8 if A and S have different signs"

                        \ If we reach here, then A and S have the same sign, so
                        \ we can add them and set the sign to get the result

.add1

 LDA R                  \ Add the least significant bytes together into X:
 CLC                    \
 ADC P                  \   X = P + R
 TAX

 LDA S                  \ Add the most significant bytes together into A. We
 ADC T1                 \ stored the original argument A in T1 earlier, so we
                        \ can do this with:
                        \
                        \   A = A  + S + C
                        \     = T1 + S + C

 ORA T                  \ If argument A was negative (and therefore S was also
                        \ negative) then make sure result A is negative by
                        \ OR'ing the result with the sign bit from argument A
                        \ (which we stored in T)

 RTS                    \ Return from the subroutine

.mad1

 JSR MULT1              \ |Q| <> 0: set (A P) = Q * A (MULT1 has already set
                        \ T to the sign of the result, and |A| < &80, so this
                        \ is the head of ADD without the AND and STA T)

 STA T1                 \ Store A in T1, as ADD does

 EOR S                  \ If A and S have the same sign jump to add1 in ADD,
 BPL add1               \ otherwise fall through into MU8

.MU8

                        \ If we reach here, then A and S have different signs,
                        \ so we can subtract their absolute values and set the
                        \ sign to get the result

 LDA P                  \ Subtract the least significant bytes into X:
 SEC                    \
 SBC R                  \   X = P - R
 TAX

 LDA T1                 \ Port: A and S have opposite signs, so flipping the
 EOR #%10000000         \ sign of T1 gives A the same bit 7 as S, and then
                        \ (T1 EOR &80) - S - borrow = |A| - |S| - borrow
 SBC S                  \ exactly, with the same C and V (V = 0) as before,
                        \ without having to build |S| in U

                        \ At this point we have |A P| - |S R| in (A X), so we
                        \ need to check whether the subtraction above was the
                        \ right way round (i.e. that we subtracted the smaller
                        \ absolute value from the larger absolute value)

 BCS MU9                \ If |A| >= |S|, our subtraction was the right way
                        \ round, so jump to MU9 to set the sign

                        \ If we get here, then |A| < |S|, so our subtraction
                        \ above was the wrong way round (we actually subtracted
                        \ the larger absolute value from the smaller absolute
                        \ value). So let's subtract the result we have in (A X)
                        \ from zero, so that the subtraction is the right way
                        \ round

 STA U                  \ Store A in U

 TXA                    \ Set X = 0 - X using two's complement (to negate a
 EOR #&FF               \ number in two's complement, you can invert the bits
 ADC #1                 \ and add one - and we know the C flag is clear as we
 TAX                    \ didn't take the BCS branch above, so the ADC will do
                        \ the correct addition)

 LDA #0                 \ Set A = 0 - A, which we can do this time using a
 SBC U                  \ subtraction with the C flag clear

 ORA #%10000000         \ We now set the sign bit of A, so that the EOR on the
                        \ next line will give the result the opposite sign to
                        \ argument A (as T contains the sign bit of argument
                        \ A). This is the same as giving the result the same
                        \ sign as argument S (as A and S have different signs),
                        \ which is what we want, as S has the larger absolute
                        \ value

.MU9

 EOR T                  \ If we get here from the BCS above, then |A| >= |S|,
                        \ so we want to give the result the same sign as
                        \ argument A, so if argument A was negative, we flip
                        \ the sign of the result with an EOR (to make it
                        \ negative)

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TIS1
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (A ?) = (-X * A + (S R)) / 96
\  Deep dive: Shift-and-subtract division
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following expression between sign-magnitude numbers, ignoring
\ the low byte of the result:
\
\   (A ?) = (-X * A + (S R)) / 96
\
\ This uses the same shift-and-subtract algorithm as TIS2, just with the
\ quotient A hard-coded to 96.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   Q                   Gets set to the value of argument X
\
\ ******************************************************************************

.TIS1

 STX Q                  \ Set Q = X

 EOR #%10000000         \ Flip the sign bit in A

 JSR MAD                \ Set (A X) = Q * A + (S R)
                        \           = X * -A + (S R)

.DVID96

 TAX                    \ Set T to the sign bit of the result
 AND #%10000000
 STA T

 TXA                    \ Set A to the high byte of the result with the sign bit
 AND #%01111111         \ cleared, so (A ?) = |X * A + (S R)|

                        \ The following is identical to TIS2, except Q is
                        \ hard-coded to 96, so this does A = A / 96

 LDX #254               \ Set T1 to have bits 1-7 set, so we can rotate through
 STX T1                 \ 7 loop iterations, getting a 1 each time, and then
                        \ getting a 0 on the 8th iteration... and we can also
                        \ use T1 to catch our result bits into bit 0 each time

.DVL3

 ASL A                  \ Shift A to the left

 CMP #96                \ If A < 96 skip the following subtraction
 BCC DV4

 SBC #96                \ Set A = A - 96
                        \
                        \ Going into this subtraction we know the C flag is
                        \ set as we passed through the BCC above, and we also
                        \ know that A >= 96, so the C flag will still be set
                        \ once we are done

.DV4

 ROL T1                 \ Rotate the counter in T1 to the left, and catch the
                        \ result bit into bit 0 (which will be a 0 if we didn't
                        \ do the subtraction, or 1 if we did)

 BCS DVL3               \ If we still have set bits in T1, loop back to DVL3 to
                        \ do the next iteration of 7

 LDA T1                 \ Fetch the result from T1 into A

 ORA T                  \ Give A the sign of the result that we stored above

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: DV42
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (P R) = 256 * DELTA / z_hi
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following division and remainder:
\
\   P = DELTA / (the Y-th stardust particle's z_hi coordinate)
\
\   R = remainder as a fraction of A, where 1.0 = 255
\
\ Another way of saying the above is this:
\
\   (P R) = 256 * DELTA / z_hi
\
\ DELTA is a value between 1 and 40, and the minimum z_hi is 16 (dust particles
\ are removed at lower values than this), so this means P is between 0 and 2
\ (as 40 / 16 = 2.5, so the maximum result is P = 2 and R = 128.
\
\ This uses the same shift-and-subtract algorithm as TIS2, but this time we
\ keep the remainder.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   Y                   The number of the stardust particle to process
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              The C flag is cleared
\
\ ******************************************************************************

.DV42

 LDA SZ,Y               \ Fetch the Y-th dust particle's z_hi coordinate into A

                        \ Fall through into DV41 to do:
                        \
                        \   (P R) = 256 * DELTA / A
                        \         = 256 * DELTA / Y-th stardust particle's z_hi

\ ******************************************************************************
\
\       Name: DV41
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (P R) = 256 * DELTA / A
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following division and remainder:
\
\   P = DELTA / A
\
\   R = remainder as a fraction of A, where 1.0 = 255
\
\ Another way of saying the above is this:
\
\   (P R) = 256 * DELTA / A
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

.DV41

 STA Q                  \ Store A in Q

 LDA DELTA              \ Fetch the speed from DELTA into A

                        \ Fall through into DVID4 to do:
                        \
                        \   (P R) = 256 * A / Q
                        \         = 256 * DELTA / A

\ ******************************************************************************
\
\       Name: DVID4
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
\ keep the remainder and the loop is unrolled.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              The C flag is cleared
\
\ ******************************************************************************

.DVID4

 STZ P                  \ Port: if A < Q then the quotient is 0 and the
 CMP Q                  \ remainder is A (no subtraction can happen and the
 BCC DVID4z             \ remainder never overflows), so set P = 0 and jump
                        \ straight to the remainder conversion with A
                        \ unchanged and C clear, exactly as the unrolled
                        \ division below would leave them

\LDX #8                 \ This instruction is commented out in the original
                        \ source

 ASL A                  \ Shift A left and store in P (we will build the result
 STA P                  \ in P)

 LDA #0                 \ Set A = 0 for us to build a remainder

\.DVL4                  \ This label is commented out in the original source

                        \ We now repeat the following five instruction block
                        \ eight times, one for each bit in P. In the BBC Micro
                        \ cassette and disc versions of Elite the following is
                        \ done with a loop, but it is marginally faster to
                        \ unroll the loop and have eight copies of the code,
                        \ though it does take up a bit more memory (though that
                        \ isn't a big concern when you have a 6502 Second
                        \ Processor)

 ROL A                  \ Shift A to the left

 CMP Q                  \ If A < Q skip the following subtraction
 BCC P%+4

 SBC Q                  \ A >= Q, so set A = A - Q

 ROL P                  \ Shift P to the left, pulling the C flag into bit 0

 ROL A                  \ Repeat for the second time
 CMP Q
 BCC P%+4
 SBC Q
 ROL P

 ROL A                  \ Repeat for the third time
 CMP Q
 BCC P%+4
 SBC Q
 ROL P

 ROL A                  \ Repeat for the fourth time
 CMP Q
 BCC P%+4
 SBC Q
 ROL P

 ROL A                  \ Repeat for the fifth time (grind: the subtraction is
 CMP Q                  \ rare here, so it is done out of line in DV4s5, which
 BCS DV4s5              \ makes the common no-subtract path one cycle faster)
.DV4r5
 ROL P

 ROL A                  \ Repeat for the sixth time
 CMP Q
 BCS DV4s6
.DV4r6
 ROL P

 ROL A                  \ Repeat for the seventh time
 CMP Q
 BCS DV4s7
.DV4r7
 ROL P

 ROL A                  \ Repeat for the eighth time
 CMP Q
 BCS DV4s8
.DV4r8
 ROL P

.DVID4z

 TAX                    \ This contains the code from the LL28+4 routine, so
 BEQ LLfix22            \ this section is exactly equivalent to a JMP LL28+4
 LDA log,X              \ call, but is slightly faster as it's been inlined
 STA widget             \ (so it converts the remainder in A into an integer
 LDA logL,X             \ representation of the fractional value A / Q, in R,
 LDX Q                  \ where 1.0 = 255, and it also clears the C flag)
 CMP logL,X             \ C = borrow from low bytes of log(A) - log(Q)
 LDA widget
 SBC log,X
 BCS LL222
 TAX
 LDA alogh,X

.LLfix22

 STA R                  \ This is also part of the inline LL28+4 routine
 RTS

.LL222

 LDA #255               \ This is also part of the inline LL28+4 routine
 STA R
 RTS

.DV4s5                  \ grind: out-of-line subtractions for DVID4's fifth to
 SBC Q                  \ eighth steps (C = 1 on entry and exit, as in-line)
 BRA DV4r5

.DV4s6
 SBC Q
 BRA DV4r6

.DV4s7
 SBC Q
 BRA DV4r7

.DV4s8
 SBC Q
 BRA DV4r8

.DVL9a

                        \ Here A = 0 and Y = 0. If P+1 < 128, the DVL9 loop
                        \ would shift exactly eight times (A stays below 64
                        \ until the eighth shift), so do it as a byte move,
                        \ (A P+1 P) = (P+1 P 0) with Y = 8, and carry on

 LDA P+1                \ If bit 7 of P+1 is set, jump to DVL9b to run the
 BMI DVL9b              \ bitwise loop from A = 0

 LDY P                  \ Set (A P+1 P) = (P+1 P 0)
 STY P+1
 STZ P

 LDY #8                 \ Count the eight shifts in Y

 BRA DVL9               \ Carry on shifting bit by bit

.DVL9b

 TYA                    \ Set A = Y = 0 and run the bitwise loop (A < 64, so
 BRA DVL9l              \ skip the test at DVL9)

.DV14z

                        \ Port: if we get here then |S| = 0 and R >= 128, so the
                        \ loop below would shift (A R Q) left exactly 8 times,
                        \ leaving A = R (which it already is), so we just need
                        \ to decrement the scale factor in Y by 8

 DEY
 DEY
 DEY
 DEY
 DEY
 DEY
 DEY
 DEY

 BRA DV9

\ ******************************************************************************
\
\       Name: DVID3B2
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate K(3 2 1 0) = (A P+1 P) / (z_sign z_hi z_lo)
\  Deep dive: Shift-and-subtract division
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following:
\
\   K(3 2 1 0) = (A P+1 P) / (z_sign z_hi z_lo)
\
\ The actual division here is done as an 8-bit calculation using LL31, but this
\ routine shifts both the numerator (the top part of the division) and the
\ denominator (the bottom part of the division) around to get the multi-byte
\ result we want.
\
\ Specifically, it shifts both of them to the left as far as possible, keeping a
\ tally of how many shifts get done in each one - and specifically, the
\ difference in the number of shifts between the top and bottom (as shifting
\ both of them once in the same direction won't change the result). It then
\ divides the two highest bytes with the simple 8-bit routine in LL31, and
\ shifts the result by the difference in the number of shifts, which acts as a
\ scale factor to get the correct result.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   K(3 2 1 0)          The result of the division
\
\   X                   X is preserved
\
\ ******************************************************************************

.DVID3B2

 TAY                    \ Set Y = A, the sign and top byte of the numerator
                        \ (Y is reset to 0 below)

 EOR INWK+8             \ Set T to the sign of A * z_sign (i.e. the sign of the
 AND #%10000000         \ result) and store it in T
 STA T

 LDA INWK+6             \ Set Q = z_lo, making sure Q is at least 1
 ORA #1
 STA Q

 LDA INWK+7             \ Set R = z_hi
 STA R

 LDA INWK+8             \ Set S = z_sign
 STA S

.DVID3B

                        \ Given the above assignments, we now want to calculate
                        \ the following to get the result we want:
                        \
                        \   K(3 2 1 0) = (Y P+1 P) / (S R Q)

 LDA #1                 \ Make sure P is at least 1
 TSB P

 TYA                    \ Set A = |Y|, clearing the sign bit so the division
 LDY #0                 \ can be done with positive numbers, and set Y = 0 to
 AND #%01111111         \ store the scale factor

 BEQ DVL9a              \ If A = 0, jump to DVL9a to try a whole-byte shift

.DVL9

                        \ We now shift (A P+1 P) left until A >= 64, counting
                        \ the number of shifts in Y. This makes the top part of
                        \ the division as large as possible, thus retaining as
                        \ much accuracy as we can.  When we come to return the
                        \ final result, we shift the result by the number of
                        \ places in Y, and in the correct direction

 CMP #64                \ If A >= 64, jump down to DV14
 BCS DV14

.DVL9l

 ASL P                  \ Shift (A P+1 P) to the left
 ROL P+1
 ROL A

 INY                    \ Increment the scale factor in Y

 CMP #64                \ Loop back to DVL9l until A >= 64, then fall through
 BCC DVL9l              \ into DV14 with the C flag set

.DV14

                        \ If we get here, A >= 64 and contains the highest byte
                        \ of the numerator, scaled up by the number of left
                        \ shifts in Y

 STA P+2                \ Store A in P+2, so we now have the scaled value of
                        \ the numerator in P(2 1 0)

 LDA S                  \ Set A = |S|
 AND #%01111111

 BNE DVL6a              \ Port: if |S| <> 0 then at most 7 shifts are needed,
                        \ and in that many shifts no bit of Q can reach A (and
                        \ R and Q are overwritten at DV9), so jump to DVL6a to
                        \ shift just (A R)

 ORA R                  \ |S| = 0, so set A = R, and if R >= 128 jump to DV14z
 BMI DV14z              \ to do the 8 shifts in one go

 LDA #0                 \ Otherwise restore A = |S| = 0 for the full shift

.DVL6

                        \ We now shift (S R Q) left until bit 7 of S is set,
                        \ reducing Y by the number of shifts. This makes the
                        \ bottom part of the division as large as possible, thus
                        \ retaining as much accuracy as we can. When we come to
                        \ return the final result, we shift the result by the
                        \ total number of places in Y, and in the correct
                        \ direction, to give us the correct result
                        \
                        \ We set A to |S| above, so the following actually
                        \ shifts (A R Q)

 DEY                    \ Decrement the scale factor in Y

 ASL Q                  \ Shift (A R Q) to the left
 ROL R
 ROL A

 BEQ DVL6               \ Port: loop while A is still zero

 BMI DV9                \ If bit 7 of A is set we are done

                        \ Otherwise A is now 1-127, so at most 7 more shifts are
                        \ needed and the bits of R already hold everything that
                        \ can reach A, so fall into DVL6a to shift just (A R)

.DVL6a

 DEY                    \ Decrement the scale factor in Y

 ASL R                  \ Shift (A R) to the left
 ROL A

 BPL DVL6a              \ Loop up to DVL6a to do another shift, until bit 7 of A
                        \ is set and we can't shift left any further

.DV9

                        \ We have now shifted both the numerator and denominator
                        \ left as far as they will go, keeping a tally of the
                        \ overall scale factor of the various shifts in Y. We
                        \ can now divide just the two highest bytes to get our
                        \ result

 STA Q                  \ Set Q = A, the highest byte of the denominator

 LDA #254               \ Set R to have bits 1-7 set, so we can pass this to
 STA R                  \ LL31 to act as the bit counter in the division

 LDA P+2                \ Set A to the highest byte of the numerator

.LL31new

 ASL A                  \ This contains the code from the LL31 routine, so
 BCS LL29new            \ this section is exactly equivalent to a JSR LL31
 CMP Q                  \ call, but is slightly faster as it's been inlined,
 BCC P%+4               \ so it calculates:
 SBC Q                  \
 ROL R                  \   R = 256 * A / Q
 BCS LL31new            \     = 256 * numerator / denominator
 BCC LL312new           \ Port: C is clear here, so this is a JMP

.LL29new

 SBC Q                  \ This is also part of the inline LL31 routine
 SEC
 ROL R
 BCS LL31new

.LL312new

                        \ The result of our division is now in R, so we just
                        \ need to shift it back by the scale factor in Y

 STZ K+1                \ Set K(2 1) = 0 to hold the result (we populate K
 STZ K+2                \ next; K+3 is set by every path below)

 TYA                    \ If Y is positive, jump to DV12
 BPL DV12

                        \ If we get here then Y is negative, so we need to shift
                        \ the result R to the left by Y places, and then set the
                        \ correct sign for the result

 STZ K+3                \ Set K+3 = 0 for the shift below

 LDA R                  \ Set A = R

.DVL8

 ASL A                  \ Shift (K+3 K+2 K+1 A) left
 ROL K+1
 ROL K+2
 ROL K+3

 INY                    \ Increment the scale factor in Y

 BNE DVL8               \ Loop back to DVL8 until we have shifted left by Y
                        \ places

 STA K                  \ Store A in K so the result is now in K(3 2 1 0)

 LDA K+3                \ Set K+3 to the sign in T, which we set above to the
 ORA T                  \ correct sign for the result
 STA K+3

 RTS                    \ Return from the subroutine

.DV13

                        \ If we get here then Y is zero, so we don't need to
                        \ shift the result R, we just need to set the correct
                        \ sign for the result

 LDA R                  \ Store R in K so the result is now in K(3 2 1 0)
 STA K

 LDA T                  \ Set K+3 to the sign in T, which we set above to the
 STA K+3                \ correct sign for the result

 RTS                    \ Return from the subroutine

.DV12

 BEQ DV13               \ We jumped here having set A to the scale factor in Y,
                        \ so this jumps up to DV13 if Y = 0

                        \ If we get here then Y is positive and non-zero, so we
                        \ need to shift the result R to the right by Y places
                        \ and then set the correct sign for the result. We also
                        \ know that K(3 2 1) will stay 0, as we are shifting the
                        \ lowest byte to the right, so no set bits will make
                        \ their way into the top three bytes

 LDA R                  \ Set A = R

.DVL10

 LSR A                  \ Shift A right

 DEY                    \ Decrement the scale factor in Y

 BNE DVL10              \ Loop back to DVL10 until we have shifted right by Y
                        \ places

 STA K                  \ Store the shifted A in K so the result is now in
                        \ K(3 2 1 0)

 LDA T                  \ Set K+3 to the sign in T, which we set above to the
 STA K+3                \ correct sign for the result

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: cntr
\       Type: Subroutine
\   Category: Dashboard
\    Summary: Apply damping to the pitch or roll dashboard indicator
\
\ ------------------------------------------------------------------------------
\
\ Apply damping to the value in X, where X ranges from 1 to 255 with 128 as the
\ centre point (so X represents a position on a centre-based dashboard slider,
\ such as pitch or roll). If the value is in the left-hand side of the slider
\ (1-127) then it bumps the value up by 1 so it moves towards the centre, and
\ if it's in the right-hand side, it reduces it by 1, also moving it towards the
\ centre.
\
\ ******************************************************************************

.cntr

 LDA auto               \ If the docking computer is currently activated, jump
 BNE cnt2               \ to cnt2 to skip the following as we always want to
                        \ enable damping for the docking computer

 LDA DAMP               \ If DAMP is non-zero, then keyboard damping is not
 BNE RE1                \ enabled, so jump to RE1 to return from the subroutine

.cnt2

 TXA                    \ If X < 128, then it's in the left-hand side of the
 BPL BUMP               \ dashboard slider, so jump to BUMP to bump it up by 1,
                        \ to move it closer to the centre

 DEX                    \ Otherwise X >= 128, so it's in the right-hand side
 BMI ARSR1              \ of the dashboard slider, so decrement X by 1, and if
                        \ it's still >= 128, jump to ARSR1 to return from the
                        \ subroutine, otherwise fall through to BUMP to undo
                        \ the bump and then return

.BUMP

 INX                    \ Bump X up by 1, and if it hasn't overshot the end of
 BNE RE1                \ the dashboard slider, jump to RE1 to return from the
                        \ subroutine, otherwise fall through to REDU to drop
                        \ it down by 1 again

.REDU

 DEX                    \ Reduce X by 1, and if we have reached 0 jump up to
 BEQ BUMP               \ BUMP to add 1, because we need the value to be in the
                        \ range 1 to 255

.RE1

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: BUMP2
\       Type: Subroutine
\   Category: Dashboard
\    Summary: Bump up the value of the pitch or roll dashboard indicator
\
\ ------------------------------------------------------------------------------
\
\ Increase ("bump up") X by A, where X is either the current rate of pitch or
\ the current rate of roll.
\
\ The rate of pitch or roll ranges from 1 to 255 with 128 as the centre point.
\ This is the amount by which the pitch or roll is currently changing, so 1
\ means it is decreasing at the maximum rate, 128 means it is not changing,
\ and 255 means it is increasing at the maximum rate. These values correspond
\ to the line on the DC or RL indicators on the dashboard, with 1 meaning full
\ left, 128 meaning the middle, and 255 meaning full right.
\
\ If bumping up X would push it past 255, then X is set to 255.
\
\ If keyboard auto-recentre is configured and the result is less than 128, we
\ bump X up to the mid-point, 128. This is the equivalent of having a roll or
\ pitch in the left half of the indicator, when increasing the roll or pitch
\ should jump us straight to the mid-point.
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   RE2+2               Restore A from T and return from the subroutine
\
\ ******************************************************************************

.BUMP2

 STA T                  \ Store argument A in T so we can restore it later

 TXA                    \ Copy argument X into A

 CLC                    \ Clear the C flag so we can do addition without the
                        \ C flag affecting the result

 ADC T                  \ Set X = A = argument X + argument A
 TAX

 BCC RE2                \ If the C flag is clear, then we didn't overflow, so
                        \ jump to RE2 to auto-recentre and return the result

 LDX #255               \ We have an overflow, so set X to the maximum possible
                        \ value of 255

.RE2

 BPL djd1               \ If X has bit 7 clear (i.e. the result < 128), then
                        \ jump to djd1 in routine REDU2 to do an auto-recentre,
                        \ if configured, because the result is on the left side
                        \ of the centre point of 128

                        \ Jumps to RE2+2 end up here

 LDA T                  \ Restore the original argument A from T into A

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: REDU2
\       Type: Subroutine
\   Category: Dashboard
\    Summary: Reduce the value of the pitch or roll dashboard indicator
\
\ ------------------------------------------------------------------------------
\
\ Reduce X by A, where X is either the current rate of pitch or the current
\ rate of roll.
\
\ The rate of pitch or roll ranges from 1 to 255 with 128 as the centre point.
\ This is the amount by which the pitch or roll is currently changing, so 1
\ means it is decreasing at the maximum rate, 128 means it is not changing,
\ and 255 means it is increasing at the maximum rate. These values correspond
\ to the line on the DC or RL indicators on the dashboard, with 1 meaning full
\ left, 128 meaning the middle, and 255 meaning full right.
\
\ If reducing X would bring it below 1, then X is set to 1.
\
\ If keyboard auto-recentre is configured and the result is greater than 128, we
\ reduce X down to the mid-point, 128. This is the equivalent of having a roll
\ or pitch in the right half of the indicator, when decreasing the roll or pitch
\ should jump us straight to the mid-point.
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   djd1                Auto-recentre the value in X, if keyboard auto-recentre
\                       is configured
\
\ ******************************************************************************

.REDU2

 STA T                  \ Store argument A in T so we can restore it later

 TXA                    \ Copy argument X into A

 SEC                    \ Set the C flag so we can do subtraction without the
                        \ C flag affecting the result

 SBC T                  \ Set X = A = argument X - argument A
 TAX

 BCS RE3                \ If the C flag is set, then we didn't underflow, so
                        \ jump to RE3 to auto-recentre and return the result

 LDX #1                 \ We have an underflow, so set X to the minimum possible
                        \ value, 1

.RE3

 BPL RE2+2              \ If X has bit 7 clear (i.e. the result < 128), then
                        \ jump to RE2+2 above to return the result as is,
                        \ because the result is on the left side of the centre
                        \ point of 128, so we don't need to auto-centre

.djd1

                        \ If we get here, then we need to apply auto-recentre,
                        \ if it is configured

 LDA DJD                \ If keyboard auto-recentre is disabled, then jump to
 BNE RE2+2              \ RE2+2 to restore A and return

 LDX #128               \ If we get here then keyboard auto-recentre is enabled,
 BMI RE2+2              \ so set X to 128 (the middle of our range) and jump to
                        \ RE2+2 to restore A and return from the subroutine
                        \ (this BMI is effectively a JMP as bit 7 of X is always
                        \ set)

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
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   ARSR1               Contains an RTS
\
\ ******************************************************************************

.ARCTAN

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

.ARSR1

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: LASLI
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw the laser lines for when we fire our lasers
\
\ ------------------------------------------------------------------------------
\
\ Draw the laser lines, aiming them to slightly different place each time so
\ they appear to flicker and dance. Also heat up the laser temperature and drain
\ some energy.
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   LASLI2              Just draw the current laser lines without moving the
\                       centre point, draining energy or heating up. This has
\                       the effect of removing the lines from the screen
\
\   LASLI-1             Contains an RTS
\
\ ******************************************************************************

.LASLI

 JSR DORND              \ Set A and X to random numbers

 AND #7                 \ Restrict A to a random value in the range 0 to 7

 ADC #Y-4               \ Set LASY to four pixels above the centre of the
 STA LASY               \ screen (#Y), plus our random number, so the laser
                        \ dances above and below the centre point

 JSR DORND              \ Set A and X to random numbers

 AND #7                 \ Restrict A to a random value in the range 0 to 7

 ADC #X-4               \ Set LASX to four pixels left of the centre of the
 STA LASX               \ screen (#X), plus our random number, so the laser
                        \ dances to the left and right of the centre point

 LDA GNTMP              \ Add 8 to the laser temperature in GNTMP
 ADC #8
 STA GNTMP

 JSR DENGY              \ Call DENGY to deplete our energy banks by 1

 JSR H_LAS1             \ Port: in record mode, show the beams in the frame
                        \ and return from LASLI (gfx-hooks.asm)

.LASLI2

 JSR H_LAS2             \ Port: in record mode there are no beams to draw or
                        \ remove here (gfx-hooks.asm)

 LDA QQ11               \ If this is not a space view (i.e. QQ11 is non-zero)
 BNE ARSR1              \ then jump to MA9 to return from the main flight loop
                        \ (as ARSR1 is an RTS)

 LDA #RED               \ Switch to colour 2, which is red in the space view
 STA COL

 LDA #32                \ Set A = 32 and Y = 224 for the first set of laser
 LDY #224               \ lines (the wider pair of lines)

 DEC LASY               \ Decrement the y-coordinate of the centre point to move
 DEC LASY               \ it up the screen by two pixels for the top set of
                        \ lines, so the wider set of lines aim slightly higher
                        \ than the narrower set

 JSR las                \ Call las below to draw the first set of laser lines

 INC LASY               \ Increment the y-coordinate of the centre point to put
 INC LASY               \ it back to the original position

 LDA #48                \ Fall through into las with A = 48 and Y = 208 to draw
 LDY #208               \ a second set of lines (the narrower pair)

                        \ The following routine draws two laser lines, one from
                        \ the centre point down to point A on the bottom row,
                        \ and the other from the centre point down to point Y
                        \ on the bottom row. We therefore get lines from the
                        \ centre point to points 32, 48, 208 and 224 along the
                        \ bottom row, giving us the triangular laser effect
                        \ we're after

.las

 STA X2                 \ Set X2 = A

 LDA LASX               \ Set (X1, Y1) to the random centre point we set above
 STA X1
 LDA LASY
 STA Y1

 LDA #2*Y-1             \ Set Y2 = 2 * #Y - 1. The constant #Y is 96, the
 STA Y2                 \ y-coordinate of the mid-point of the space view, so
                        \ this sets Y2 to 191, the y-coordinate of the bottom
                        \ pixel row of the space view

 JSR LOIN               \ Draw a line from (X1, Y1) to (X2, Y2), so that's from
                        \ the centre point to (A, 191)

 LDA LASX               \ Set (X1, Y1) to the random centre point we set above
 STA X1
 LDA LASY
 STA Y1

 STY X2                 \ Set X2 = Y

 LDA #2*Y-1             \ Set Y2 = 2 * #Y - 1, the y-coordinate of the bottom
 STA Y2                 \ pixel row of the space view (as before)

 JMP LOIN               \ Draw a line from (X1, Y1) to (X2, Y2), so that's from
                        \ the centre point to (Y, 191), and return from
                        \ the subroutine using a tail call

\ ******************************************************************************
\
\       Name: GINF
\       Type: Subroutine
\   Category: Universe
\    Summary: Fetch the address of a ship's data block into INF
\
\ ------------------------------------------------------------------------------
\
\ Get the address of the data block for ship slot X and store it in INF. This
\ address is fetched from the UNIV table, which stores the addresses of the 13
\ ship data blocks in workspace K%.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The ship slot number for which we want the data block
\                       address
\
\ ******************************************************************************

.GINF

 TXA                    \ Set Y = X * 2
 ASL A
 TAY

 LDA UNIV,Y             \ Get the high byte of the address of the X-th ship
 STA INF                \ from UNIV and store it in INF

 LDA UNIV+1,Y           \ Get the low byte of the address of the X-th ship
 STA INF+1              \ from UNIV and store it in INF

 RTS                    \ Return from the subroutine

\ ******************************************************************************

 PRINT "ELITE C"
 PRINT "Assembled at ", ~CODE_C%
 PRINT "Ends at ", ~P%
 PRINT "Code size is ", ~(P% - CODE_C%)
 PRINT "Execute at ", ~LOAD%
 PRINT "Reload at ", ~LOAD_C%

 PRINT "S.ELTC ", ~CODE_C%, " ", ~P%, " ", ~LOAD%, " ", ~LOAD_C%
\SAVE "build/ELTC.bin", CODE_C%, P%, LOAD%

\ ******************************************************************************
\
\ ELITE D FILE
\
\ ******************************************************************************

 CODE_D% = P%

 LOAD_D% = LOAD% + P% - CODE%

\ ******************************************************************************

 PRINT "ELITE D"
 PRINT "Assembled at ", ~CODE_D%
 PRINT "Ends at ", ~P%
 PRINT "Code size is ", ~(P% - CODE_D%)
 PRINT "Execute at ", ~LOAD%
 PRINT "Reload at ", ~LOAD_D%

 PRINT "S.ELTD ", ~CODE_D%, " ", ~P%, " ", ~LOAD%, " ", ~LOAD_D%
\SAVE "build/ELTD.bin", CODE_D%, P%, LOAD%

\ ******************************************************************************
\
\ ELITE E FILE
\
\ ******************************************************************************

 CODE_E% = P%

 LOAD_E% = LOAD% + P% - CODE%

\ ******************************************************************************
\
\       Name: DOEXP
\       Type: Subroutine
\   Category: Drawing ships
\    Summary: Draw an exploding ship
\  Deep dive: Drawing explosion clouds
\             Generating random numbers
\
\ ******************************************************************************

.EX2

 LDA INWK+31            \ Set bits 5 and 7 of the ship's byte #31 to denote that
 ORA #%10100000         \ the ship is exploding and has been killed
 STA INWK+31

 RTS                    \ Return from the subroutine

.DOEXP

 LDA INWK+31            \ If bit 6 of the ship's byte #31 is clear, then the
 AND #%01000000         \ ship is not already exploding so there is no existing
 BEQ P%+5               \ explosion cloud to remove, so skip the following
                        \ instruction

 JSR H_PTCLSE           \ Call PTCLS to remove the existing cloud by drawing it
                        \ (Port: with the renderer's recording off,
                        \ gfx-hooks.asm)
                        \ again

 LDA INWK+6             \ Set T = z_lo
 STA T

 LDA INWK+7             \ Set A = z_hi, so (A T) = z

 CMP #32                \ If z_hi < 32, skip the next two instructions
 BCC P%+6

 LDA #&FE               \ Set A = 254 and jump to yy (this BNE is effectively a
 BNE yy                 \ JMP, as A is never zero)

 ASL T                  \ Shift (A T) left twice
 ROL A
 ASL T
 ROL A

 SEC                    \ And then shift A left once more, inserting a 1 into
 ROL A                  \ bit 0

                        \ Overall, the above multiplies A by 8 and makes sure it
                        \ is at least 1, to leave a one-byte distance in A. We
                        \ can use this as the distance for our cloud, to ensure
                        \ that the explosion cloud is visible even for ships
                        \ that blow up a long way away

.yy

 STA Q                  \ Store the distance to the explosion in Q

 LDY #1                 \ Fetch byte #1 of the ship line heap, which contains
 LDA (XX19),Y           \ the cloud counter

 STA frump              \ Store the cloud counter in frump (though this value is
                        \ never read, so this has no effect)

 ADC #4                 \ Add 4 to the cloud counter, so it ticks onwards every
                        \ we redraw it

 BCS EX2                \ If the addition overflowed, jump up to EX2 to update
                        \ the explosion flags and return from the subroutine

 STA (XX19),Y           \ Store the updated cloud counter in byte #1 of the ship
                        \ line heap

 JSR DVID4              \ Calculate the following:
                        \
                        \   (P R) = 256 * A / Q
                        \         = 256 * cloud counter / distance
                        \
                        \ We are going to use this as our cloud size, so the
                        \ further away the cloud, the smaller it is, and as the
                        \ cloud counter ticks onward, the cloud expands

 LDA P                  \ Set A = P, so we now have:
                        \
                        \   (A R) = 256 * cloud counter / distance

 CMP #&1C               \ If A < 28, skip the next two instructions
 BCC P%+6

 LDA #&FE               \ Set A = 254 and skip the following (this BNE is
 BNE LABEL_1            \ effectively a JMP as A is never zero)

 ASL R                  \ Shift (A R) left three times to multiply by 8
 ROL A
 ASL R
 ROL A
 ASL R
 ROL A

                        \ Overall, the above multiplies (A R) by 8 to leave a
                        \ one-byte cloud size in A, given by the following:
                        \
                        \   A = 8 * cloud counter / distance

.LABEL_1

 DEY                    \ Decrement Y to 0

 STA (XX19),Y           \ Store the cloud size in byte #0 of the ship line heap

 LDA INWK+31            \ Clear bit 6 of the ship's byte #31 to denote that the
 AND #%10111111         \ explosion has not yet been drawn
 STA INWK+31

 AND #%00001000         \ If bit 3 of the ship's byte #31 is clear, then nothing
 BNE P%+3               \ is being drawn on-screen for this ship anyway, so
 RTS                    \ return from the subroutine (Port: the original
                        \ branched to the RTS at TT48, which is now in the
                        \ cold area)

 LDY #2                 \ Otherwise it's time to draw an explosion cloud, so
 LDA (XX19),Y           \ fetch byte #2 of the ship line heap into Y, which we
 TAY                    \ set to the explosion count for this ship (i.e. the
                        \ number of vertices used as origins for explosion
                        \ clouds)
                        \
                        \ The explosion count is stored as 4 * n + 6, where n is
                        \ the number of vertices, so the following loop copies
                        \ the coordinates of the first n vertices from the heap
                        \ at XX3, which is where we stored all the visible
                        \ vertex coordinates in part 8 of the LL9 routine, and
                        \ sticks them in the ship line heap pointed to by XX19,
                        \ starting at byte #7 (so it leaves the first 6 bytes of
                        \ the ship line heap alone)

.EXL1

 LDA XX3-7,Y            \ Copy byte Y-7 from the XX3 heap, into the Y-th byte of
 STA (XX19),Y           \ the ship line heap

 DEY                    \ Decrement the loop counter

 CPY #6                 \ Keep copying vertex coordinates into the ship line
 BNE EXL1               \ heap until Y = 6 (which will copy n vertices, where n
                        \ is the number of vertices we should be exploding)

 LDA INWK+31            \ Set bit 6 of the ship's byte #31 to denote that the
 ORA #%01000000         \ explosion has been drawn (as it's about to be)
 STA INWK+31

.PTCLS

                        \ This part of the routine actually draws the explosion
                        \ cloud

 LDY #0                 \ Fetch byte #0 of the ship line heap, which contains
 LDA (XX19),Y           \ the cloud size we stored above, and store it in Q
 STA Q

 INY                    \ Increment the index in Y to point to byte #1

 LDA (XX19),Y           \ Fetch byte #1 of the ship line heap, which contains
                        \ the cloud counter. We are now going to process this
                        \ into the number of particles in each vertex's cloud

 BPL P%+4               \ If the cloud counter < 128, then we are in the first
                        \ half of the cloud's existence, so skip the next
                        \ instruction

 EOR #&FF               \ Flip the value of A so that in the second half of the
                        \ cloud's existence, A counts down instead of up

 LSR A                  \ Divide A by 16 so that is has a maximum value of 7
 LSR A
 LSR A
 LSR A

 ORA #1                 \ Make sure A is at least 1 and store it in U, to
 STA U                  \ give us the number of particles in the explosion for
                        \ each vertex

 INY                    \ Increment the index in Y to point to byte #2

 LDA (XX19),Y           \ Fetch byte #2 of the ship line heap, which contains
 STA TGT                \ the explosion count for this ship (i.e. the number of
                        \ vertices used as origins for explosion clouds) and
                        \ store it in TGT

 LDA RAND+1             \ Fetch the current random number seed in RAND+1 and
 PHA                    \ store it on the stack, so we can re-randomise the
                        \ seeds when we are done

 LDY #6                 \ Set Y = 6 to point to the byte before the first vertex
                        \ coordinate we stored on the ship line heap above (we
                        \ increment it below so it points to the first vertex)

.EXL5

 LDX #3                 \ We are about to fetch a pair of coordinates from the
                        \ ship line heap, so set a counter in X for 4 bytes

.EXL3

 INY                    \ Increment the index in Y so it points to the next byte
                        \ from the coordinate we are copying

 LDA (XX19),Y           \ Copy the Y-th byte from the ship line heap to the X-th
 STA K3,X               \ byte of K3

 DEX                    \ Decrement the X index

 BPL EXL3               \ Loop back to EXL3 until we have copied all four bytes

                        \ The above loop copies the vertex coordinates from the
                        \ ship line heap to K3, reversing them as we go, so it
                        \ sets the following:
                        \
                        \   K3+3 = x_lo
                        \   K3+2 = x_hi
                        \   K3+1 = y_lo
                        \   K3+0 = y_hi

 STY CNT                \ Set CNT to the index that points to the next vertex on
                        \ the ship line heap

 LDY #2                 \ Set Y = 2, which we will use to point to bytes #3 to
                        \ #6, after incrementing it

                        \ This next loop copies bytes #3 to #6 from the ship
                        \ line heap into the four random number seeds in RAND to
                        \ RAND+3, EOR'ing them with the vertex index so they are
                        \ different for every vertex. This enables us to
                        \ generate random numbers for drawing each vertex that
                        \ are random but repeatable, which we need when we
                        \ redraw the cloud to remove it
                        \
                        \ Note that we haven't actually set the values of bytes
                        \ #3 to #6 in the ship line heap, so we have no idea
                        \ what they are, we just use what's already there. But
                        \ the fact that those bytes are stored for this ship
                        \ means we can repeat the random generation of the
                        \ cloud, which is the important bit

.EXL2

 INY                    \ Increment the index in Y so it points to the next
                        \ random number seed to copy

 LDA (XX19),Y           \ Fetch the Y-th byte from the ship line heap

 EOR CNT                \ EOR with the vertex index, so the seeds are different
                        \ for each vertex

IF _SNG47

 STA &FFFF,Y            \ Y is going from 3 to 6, so this stores the four bytes
                        \ in memory locations &02, &03, &04 and &05, which are
                        \ the memory locations of RAND through RAND+3

ELIF _COMPACT

 STA &0000,Y            \ Y is going from 3 to 6, so this stores the four bytes
                        \ in memory locations &03, &04, &05 and &06, which are
                        \ the memory locations of RAND through RAND+3

ENDIF

 CPY #6                 \ Loop back to EXL2 until Y = 6, which means we have
 BNE EXL2               \ copied four bytes

 LDY U                  \ Set Y to the number of particles in the explosion for
                        \ each vertex, which we stored in U above. We will now
                        \ use this as a loop counter to iterate through all the
                        \ particles in the explosion

 STY CNT2               \ Store the number of explosion particles in CNT2, to
                        \ use this as a loop counter to iterate through all the
                        \ particles in the explosion

.EXL4

 CLC                    \ This contains the code from the DORND2 routine, so
 LDA RAND               \ this section is exactly equivalent to a JSR DORND2
 ROL A                  \ call, but is slightly faster as it's been inlined
 TAX                    \ (so it sets A and X to random values, making sure
 ADC RAND+2             \ the C flag doesn't affect the outcome)
 STA RAND
 STX RAND+2
 LDA RAND+1
 TAX
 ADC RAND+3
 STA RAND+1
 STX RAND+3

 STA ZZ                 \ Set ZZ to a random number

 AND #3                 \ Set X to this random number, reduced to be in the
 TAX                    \ range 0-3

 LDA coltabl,X          \ Set the colour randomly to one of the four colours
 STA COL                \ in the coltabl table, so explosions are made up of
                        \ yellow, red and cyan particles

 LDA K3+1               \ Set (A R) = (y_hi y_lo)
 STA R                  \           = y
 LDA K3

 JSR EXS1               \ Set (A X) = (A R) +/- random * cloud size
                        \           = y +/- random * cloud size

 BNE EX11               \ If A is non-zero, the particle is off-screen as the
                        \ coordinate is either negative or bigger than 255, so
                        \ jump to EX11 to do the next particle

 CPX #2*Y-1             \ If X > the y-coordinate of the bottom of the screen,
 BCS EX11               \ the particle is off the bottom of the screen, so jump
                        \ to EX11 to do the next particle

                        \ Otherwise X contains a random y-coordinate within the
                        \ cloud

 STX Y1                 \ Set Y1 = our random y-coordinate within the cloud

 LDA K3+3               \ Set (A R) = (x_hi x_lo)
 STA R
 LDA K3+2

 JSR EXS1               \ Set (A X) = (A R) +/- random * cloud size
                        \           = x +/- random * cloud size

 BNE EX4                \ If A is non-zero, the particle is off-screen as the
                        \ coordinate is bigger than 255), so jump to EX4 to do
                        \ the next particle

                        \ Otherwise X contains a random x-coordinate within the
                        \ cloud

 LDA Y1                 \ Set A = our random y-coordinate within the cloud

 JSR PIXEL              \ Draw a point at screen coordinate (X, A) with the
                        \ point size determined by the distance in ZZ

.EX4

 DEC CNT2               \ Decrement the loop counter in CNT2 for the next
                        \ particle

 BPL EXL4               \ Loop back to EXL4 until we have done all the particles
                        \ in the cloud

 LDY CNT                \ Set Y to the index that points to the next vertex on
                        \ the ship line heap

 CPY TGT                \ If Y < TGT, which we set to the explosion count for
 BCC EXL5               \ this ship (i.e. the number of vertices used as origins
                        \ for explosion clouds), loop back to EXL5 to do a cloud
                        \ for the next vertex

 PLA                    \ Restore the current random number seed to RAND+1 that
 STA RAND+1             \ we stored at the start of the routine

 LDA K%+6               \ Store the z_lo coordinate for the planet (which will
 STA RAND+3             \ be pretty random) in the RAND+3 seed

 RTS                    \ Return from the subroutine

.EX11

 CLC                    \ This contains the code from the DORND2 routine, so
 LDA RAND               \ this section is exactly equivalent to a JSR DORND2
 ROL A                  \ call, but is slightly faster as it's been inlined
 TAX                    \ (so it sets A and X to random values, making sure
 ADC RAND+2             \ the C flag doesn't affect the outcome)
 STA RAND
 STX RAND+2
 LDA RAND+1
 TAX
 ADC RAND+3
 STA RAND+1
 STX RAND+3

 JMP EX4                \ We just skipped a particle, so jump up to EX4 to do
                        \ the next one

.EXS1

                        \ This routine calculates the following:
                        \
                        \   (A X) = (A R) +/- random * cloud size
                        \
                        \ returning with the flags set for the high byte in A

 STA S                  \ Store A in S so we can use it later

 CLC                    \ This contains the code from the DORND2 routine, so
 LDA RAND               \ this section is exactly equivalent to a JSR DORND2
 ROL A                  \ call, but is slightly faster as it's been inlined
 TAX                    \ (so it sets A and X to random values, making sure
 ADC RAND+2             \ the C flag doesn't affect the outcome)
 STA RAND
 STX RAND+2
 LDA RAND+1
 TAX
 ADC RAND+3
 STA RAND+1
 STX RAND+3

 ROL A                  \ Set A = A * 2

 BCS EX5                \ If bit 7 of A was set (50% chance), jump to EX5

 JSR FMLTU              \ Set A = A * Q / 256
                        \       = random << 1 * projected cloud size / 256

 ADC R                  \ Set (A X) = (S R) + A
 TAX                    \           = (S R) + random * projected cloud size
                        \
                        \ where S contains the argument A, starting with the low
                        \ bytes

 LDA S                  \ And then the high bytes
 ADC #0

 RTS                    \ Return from the subroutine

.EX5

 JSR FMLTU              \ Set T = A * Q / 256
 STA T                  \       = random << 1 * projected cloud size / 256

 LDA R                  \ Set (A X) = (S R) - T
 SBC T                  \
 TAX                    \ where S contains the argument A, starting with the low
                        \ bytes

 LDA S                  \ And then the high bytes
 SBC #0

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: exlook
\       Type: Variable
\   Category: Drawing ships
\    Summary: A table to shift X left by one place when X is 0 or 1
\
\ ******************************************************************************

.exlook

 EQUB %00               \ Looking up exlook,X will return X shifted left by one
 EQUB %10               \ place, where X is 0 or 1
                        \
                        \ This is not used in this version of Elite; it is left
                        \ over from the Commodore 64 version of Elite

\ ******************************************************************************
\
\       Name: coltabl
\       Type: Variable
\   Category: Drawing ships
\    Summary: Colours for ship explosions
\
\ ******************************************************************************

.coltabl

 EQUB YELLOW
 EQUB RED
 EQUB YELLOW
 EQUB CYAN

\ ******************************************************************************
\
\       Name: NWSTARS
\       Type: Subroutine
\   Category: Stardust
\    Summary: Initialise the stardust field
\
\ ------------------------------------------------------------------------------
\
\ This routine is called when the space view is initialised in routine LOOK1.
\
\ ******************************************************************************

.NWSTARS

 LDA QQ11               \ If this is not a space view, jump to WPSHPS to skip
\ORA MJ                 \ the initialisation of the SX, SY and SZ tables. The OR
 BNE WPSHPS             \ instruction is commented out in the original source,
                        \ but it would have the effect of also skipping the
                        \ initialisation if we had mis-jumped into witchspace

\ ******************************************************************************
\
\       Name: nWq
\       Type: Subroutine
\   Category: Stardust
\    Summary: Create a random cloud of stardust
\
\ ------------------------------------------------------------------------------
\
\ Create a random cloud of stardust containing the correct number of dust
\ particles, i.e. NOSTM of them, which is 3 in witchspace and 18 (#NOST) in
\ normal space. Also clears the scanner and initialises the LSO block.
\
\ This is called by the DEATH routine when it displays our untimely demise.
\
\ ******************************************************************************

.nWq

 LDA #DUST              \ Switch to stripe 3-2-3-2, which is cyan/red in the
 STA COL                \ space view

 LDY NOSTM              \ Set Y to the current number of stardust particles, so
                        \ we can use it as a counter through all the stardust

.SAL4

 JSR DORND              \ Set A and X to random numbers

 ORA #8                 \ Set A so that it's at least 8

 STA SZ,Y               \ Store A in the Y-th particle's z_hi coordinate at
                        \ SZ+Y, so the particle appears in front of us

 STA ZZ                 \ Set ZZ to the particle's z_hi coordinate

 JSR DORND              \ Set A and X to random numbers

 STA SX,Y               \ Store A in the Y-th particle's x_hi coordinate at
                        \ SX+Y, so the particle appears in front of us

 STA X1                 \ Set X1 to the particle's x_hi coordinate

 JSR DORND              \ Set A and X to random numbers

 STA SY,Y               \ Store A in the Y-th particle's y_hi coordinate at
                        \ SY+Y, so the particle appears in front of us

 STA Y1                 \ Set Y1 to the particle's y_hi coordinate

 JSR PIXEL2             \ Draw a stardust particle at (X1,Y1) with distance ZZ

 DEY                    \ Decrement the counter to point to the next particle of
                        \ stardust

 BNE SAL4               \ Loop back to SAL4 until we have randomised all the
                        \ stardust particles

\JSR PBFL               \ This instruction is commented out in the original
                        \ source

                        \ Fall through into WPSHPS to clear the scanner and
                        \ reset the LSO block

\ ******************************************************************************
\
\       Name: WPSHPS
\       Type: Subroutine
\   Category: Dashboard
\    Summary: Clear the scanner, reset the ball line and sun line heaps
\
\ ------------------------------------------------------------------------------
\
\ Remove all ships from the scanner, reset the sun line heap at LSO, and reset
\ the ball line heap at LSX2 and LSY2.
\
\ ******************************************************************************

.WPSHPS

 LDX #0                 \ Set up a counter in X to work our way through all the
                        \ ship slots in FRIN

.WSL1

 LDA FRIN,X             \ Fetch the ship type in slot X

 BEQ WS2                \ If the slot contains 0 then it is empty and we have
                        \ checked all the slots (as they are always shuffled
                        \ down in the main loop to close up any gaps), so jump
                        \ to WS2 as we are done

 BMI WS1                \ If the slot contains a ship type with bit 7 set, then
                        \ it contains the planet or the sun, so jump down to WS1
                        \ to skip this slot, as the planet and sun don't appear
                        \ on the scanner

 STA TYPE               \ Store the ship type in TYPE

 JSR GINF               \ Call GINF to get the address of the data block for
                        \ ship slot X and store it in INF

 LDY #31                \ We now want to copy the first 32 bytes from the ship's
                        \ data block into INWK, so set a counter in Y

.WSL2

 LDA (INF),Y            \ Copy the Y-th byte from the data block pointed to by
 STA INWK,Y             \ INF into the Y-th byte of INWK workspace

 DEY                    \ Decrement the counter to point at the next byte

 BPL WSL2               \ Loop back to WSL2 until we have copied all 32 bytes

 STX XSAV               \ Store the ship slot number in XSAV while we call SCAN

 JSR SCAN               \ Call SCAN to plot this ship on the scanner, which will
                        \ remove it as it's plotted with EOR logic

 LDX XSAV               \ Restore the ship slot number from XSAV into X

 LDY #31                \ Clear bits 3, 4 and 6 in the ship's byte #31, which
 LDA (INF),Y            \ stops drawing the ship on-screen (bit 3), hides it
 AND #%10100111         \ from the scanner (bit 4) and stops any lasers firing
 STA (INF),Y            \ (bit 6)

.WS1

 INX                    \ Increment X to point to the next ship slot

 BNE WSL1               \ Loop back up to process the next slot (this BNE is
                        \ effectively a JMP as X will never be zero)

.WS2

 LDX #0                 \ Reset the ball line heap by setting the ball line heap
 STX LSP                \ pointer to 0

 DEX                    \ Set X = &FF

 STX LSX2               \ Set LSX2 = LSY2 = &FF to clear the ball line heap
 STX LSY2

                        \ Fall through into FLFLLS to reset the LSO block

\ ******************************************************************************
\
\       Name: FLFLLS
\       Type: Subroutine
\   Category: Drawing suns
\    Summary: Reset the sun line heap
\
\ ------------------------------------------------------------------------------
\
\ Reset the sun line heap at LSO by zero-filling it and setting the first byte
\ to &FF.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   A is set to 0
\
\ ******************************************************************************

.FLFLLS

 LDY #2*Y-1+8           \ #Y is the y-coordinate of the centre of the space
                        \ view, so this sets Y as a counter for the number of
                        \ lines in the space view (i.e. 191) - which is also the
                        \ number of lines in the LSO block - plus an extra 8
                        \ bytes

 LDA #0                 \ Set A to 0 so we can zero-fill the LSO block

.SAL6

 STA LSO,Y              \ Set the Y-th byte of the LSO block to 0

 DEY                    \ Decrement the counter

 BNE SAL6               \ Loop back until we have filled all the way to LSO+1

 DEY                    \ Decrement Y to value of &FF (as we exit the above loop
                        \ with Y = 0)

 STY LSX                \ Set the first byte of the LSO block, which has its own
                        \ label LSX, to &FF, to indicate that the sun line heap
                        \ is empty

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: DET1
\       Type: Subroutine
\   Category: Drawing the screen
\    Summary: Show or hide the dashboard (for when we die)
\
\ ------------------------------------------------------------------------------
\
\ This routine sets the screen to show the number of text rows given in X.
\
\ It is used when we are killed, as reducing the number of rows from the usual
\ 31 to 24 has the effect of hiding the dashboard, leaving a monochrome image
\ of ship debris and explosion clouds. Increasing the rows back up to 31 makes
\ the dashboard reappear, as the dashboard's screen memory doesn't get touched
\ by this process.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The number of text rows to display on the screen (24
\                       will hide the dashboard, 31 will make it reappear)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   A is set to 6
\
\ ******************************************************************************

.DET1

 LDA #6                 \ Set A to 6 so we can update 6845 register R6 below

 SEI                    \ Disable interrupts so we can update the 6845

 STA VIA+&00            \ Set 6845 register R6 to the value in X. Register R6
 STX VIA+&01            \ is the "vertical displayed" register, which sets the
                        \ number of rows shown on the screen

 CLI                    \ Re-enable interrupts

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: SHD
\       Type: Subroutine
\   Category: Flight
\    Summary: Charge a shield and drain some energy from the energy banks
\
\ ------------------------------------------------------------------------------
\
\ Charge up a shield, and if it needs charging, drain some energy from the
\ energy banks.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The value of the shield to recharge
\
\ ******************************************************************************

 DEX                    \ If we get here then we just incremented the shield
                        \ value back around to zero, so decrement it back down
                        \ to 255 so it stays at the maximum value of 255

 RTS                    \ Return from the subroutine

.SHD

 INX                    \ Increment the shield value

 BEQ SHD-2              \ If the shield value is 0 then this means it was 255
                        \ before, which is the maximum value, so jump to SHD-2
                        \ to bring it back down to 255 and return without
                        \ draining our energy banks

                        \ Otherwise fall through into DENGY to drain our energy
                        \ to pay for all this shield charging

\ ******************************************************************************
\
\       Name: DENGY
\       Type: Subroutine
\   Category: Flight
\    Summary: Drain some energy from the energy banks
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   Z flag              Set if we have no energy left, clear otherwise
\
\ ******************************************************************************

.DENGY

 DEC ENERGY             \ Decrement the energy banks in ENERGY

 PHP                    \ Save the flags on the stack

 BNE paen2              \ If the energy levels are not yet zero, skip the
                        \ following instruction

 INC ENERGY             \ The minimum allowed energy level is 1, and we just
                        \ reached 0, so increment ENERGY back to 1

.paen2

 PLP                    \ Restore the flags from the stack, so we return with
                        \ the Z flag from the DEC instruction above

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: COMPAS
\       Type: Subroutine
\   Category: Dashboard
\    Summary: Update the compass
\
\ ******************************************************************************

.COMPAS

 JSR DOT                \ Call DOT to redraw (i.e. remove) the current compass
                        \ dot

 LDA SSPR               \ If we are inside the space station safe zone, jump to
 BNE SP1                \ SP1 to draw the space station on the compass

 JSR SPS1               \ Otherwise we need to draw the planet on the compass,
                        \ so first call SPS1 to calculate the vector to the
                        \ planet and store it in XX15

 JMP SP2                \ Jump to SP2 to draw XX15 on the compass, returning
                        \ from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: SPS2
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Calculate (Y X) = A / 10
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following, where A is a sign-magnitude 8-bit integer and the
\ result is a signed 16-bit integer:
\
\   (Y X) = A / 10
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              The C flag is cleared
\
\ ******************************************************************************

.SPS2

 ASL A                  \ Set X = |A| * 2, and set the C flag to the sign bit of
 TAX                    \ A

 LDA #0                 \ Set Y to have the sign bit from A in bit 7, with the
 ROR A                  \ rest of its bits zeroed, so Y now contains the sign of
 TAY                    \ the original argument

 LDA #20                \ Set Q = 20
 STA Q

 TXA                    \ Copy X into A, so A now contains the argument A * 2

 JSR DVID4              \ Calculate the following:
                        \
                        \   P = A / Q
                        \     = |argument A| * 2 / 20
                        \     = |argument A| / 10

 LDX P                  \ Set X to the result

 TYA                    \ If the sign of the original argument A is negative,
 BMI LL163              \ jump to LL163 to flip the sign of the result

 LDY #0                 \ Set the high byte of the result to 0, as the result is
                        \ positive

 RTS                    \ Return from the subroutine

.LL163

 LDY #&FF               \ The result is negative, so set the high byte to &FF

 TXA                    \ Flip the low byte and add 1 to get the negated low
 EOR #&FF               \ byte, using two's complement
 TAX
 INX

.COR1

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: SPS4
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Calculate the vector to the space station
\
\ ------------------------------------------------------------------------------
\
\ Calculate the vector between our ship and the space station and store it in
\ XX15.
\
\ ******************************************************************************

.SPS4

 LDX #8                 \ First we need to copy the space station's coordinates
                        \ into K3, so set a counter to copy the first 9 bytes
                        \ (the three-byte x, y and z coordinates) from the
                        \ station's data block at K% + NI% into K3

.SPL1

 LDA K%+NI%,X           \ Copy the X-th byte from the station's data block at
 STA K3,X               \ K% + NI% to the X-th byte of K3

 DEX                    \ Decrement the loop counter

 BPL SPL1               \ Loop back to SPL1 until we have copied all 9 bytes

 JMP TAS2               \ Call TAS2 to build XX15 from K3, returning from the
                        \ subroutine using a tail call

\ ******************************************************************************
\
\       Name: SP1
\       Type: Subroutine
\   Category: Dashboard
\    Summary: Draw the space station on the compass
\
\ ******************************************************************************

.SP1

 JSR SPS4               \ Call SPS4 to calculate the vector to the space station
                        \ and store it in XX15

                        \ Fall through into SP2 to draw XX15 on the compass

\ ******************************************************************************
\
\       Name: SP2
\       Type: Subroutine
\   Category: Dashboard
\    Summary: Draw a dot on the compass, given the planet/station vector
\
\ ------------------------------------------------------------------------------
\
\ Draw a dot on the compass to represent the planet or station, whose normalised
\ vector is in XX15.
\
\   XX15 to XX15+2      The normalised vector to the planet or space station,
\                       stored as x in XX15, y in XX15+1 and z in XX15+2
\
\ ******************************************************************************

.SP2

 LDA XX15               \ Set A to the x-coordinate of the planet or station to
                        \ show on the compass, which will be in the range -96 to
                        \ +96 as the vector has been normalised

 JSR SPS2               \ Set (Y X) = A / 10, so X will be from -9 to +9, which
                        \ is the x-offset from the centre of the compass of the
                        \ dot we want to draw. Returns with the C flag clear

 TXA                    \ Set COMX = 195 + X, as 186 is the pixel x-coordinate
 ADC #195               \ of the leftmost dot possible on the compass, and X can
 STA COMX               \ be -9, which would be 195 - 9 = 186. This also means
                        \ that the highest value for COMX is 195 + 9 = 204,
                        \ which is the pixel x-coordinate of the rightmost dot
                        \ in the compass... but the compass dot is actually two
                        \ pixels wide, so the compass dot can overlap the right
                        \ edge of the compass, but not the left edge

 LDA XX15+1             \ Set A to the y-coordinate of the planet or station to
                        \ show on the compass, which will be in the range -96 to
                        \ +96 as the vector has been normalised

 JSR SPS2               \ Set (Y X) = A / 10, so X will be from -9 to +9, which
                        \ is the x-offset from the centre of the compass of the
                        \ dot we want to draw. Returns with the C flag clear

 STX T                  \ Set COMY = 204 - X, as 203 is the pixel y-coordinate
 LDA #204               \ of the centre of the compass, the C flag is clear,
 SBC T                  \ and the y-axis needs to be flipped around (because
 STA COMY               \ when the planet or station is above us, and the
                        \ vector is therefore positive, we want to show the dot
                        \ higher up on the compass, which has a smaller pixel
                        \ y-coordinate). So this calculation does this:
                        \
                        \   COMY = 204 - X - (1 - 0) = 203 - X

 LDA #YELLOW2           \ Set A to yellow, the colour for when the planet or
                        \ station in the compass is in front of us

 LDX XX15+2             \ If the z-coordinate of the XX15 vector is positive,
 BPL P%+4               \ skip the following instruction

 LDA #GREEN2            \ The z-coordinate of XX15 is negative, so the planet or
                        \ station is behind us and the compass dot should be in
                        \ green, so set A accordingly

 STA COMC               \ Store the compass colour in COMC

 JMP DOT                \ Jump to DOT to draw the dot on the compass and return
                        \ from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: OOPS
\       Type: Subroutine
\   Category: Flight
\    Summary: Take some damage
\
\ ------------------------------------------------------------------------------
\
\ We just took some damage, so reduce the shields if we have any, or reduce the
\ energy levels and potentially take some damage to the cargo if we don't.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The amount of damage to take
\
\   INF                 The address of the ship block for the ship that attacked
\                       us, or the ship that we just ran into
\
\ ******************************************************************************

.OOPS

 STA T                  \ Store the amount of damage in T

 LDX #0                 \ Fetch byte #8 (z_sign) for the ship attacking us, and
 LDY #8                 \ set X = 0
 LDA (INF),Y

 BMI OO1                \ If A is negative, then we got hit in the rear, so jump
                        \ to OO1 to process damage to the aft shield

 LDA FSH                \ Otherwise the forward shield was damaged, so fetch the
 SBC T                  \ shield strength from FSH and subtract the damage in T

 BCC OO2                \ If the C flag is clear then this amount of damage was
                        \ too much for the shields, so jump to OO2 to set the
                        \ shield level to 0 and start taking damage directly
                        \ from the energy banks

 STA FSH                \ Store the new value of the forward shield in FSH

 RTS                    \ Return from the subroutine

.OO2

 LDX #0                 \ Set the forward shield to 0
 STX FSH

 BCC OO3                \ Jump to OO3 to start taking damage directly from the
                        \ energy banks (this BCC is effectively a JMP as the C
                        \ flag is clear, as we jumped to OO2 with a BCC)

.OO1

 LDA ASH                \ The aft shield was damaged, so fetch the shield
 SBC T                  \ strength from ASH and subtract the damage in T

 BCC OO5                \ If the C flag is clear then this amount of damage was
                        \ too much for the shields, so jump to OO5 to set the
                        \ shield level to 0 and start taking damage directly
                        \ from the energy banks

 STA ASH                \ Store the new value of the aft shield in ASH

 RTS                    \ Return from the subroutine

.OO5

 LDX #0                 \ Set the forward shield to 0
 STX ASH

.OO3

 ADC ENERGY             \ A is negative and contains the amount by which the
 STA ENERGY             \ damage overwhelmed the shields, so this drains the
                        \ energy banks by that amount (and because the energy
                        \ banks are shown over four indicators rather than one,
                        \ but with the same value range of 0-255, energy will
                        \ appear to drain away four times faster than the
                        \ shields did)

 BEQ P%+4               \ If we have just run out of energy, skip the next
                        \ instruction to jump straight to our death

 BCS P%+5               \ If the C flag is set, then subtracting the damage from
                        \ the energy banks didn't underflow, so we had enough
                        \ energy to survive, and we can skip the next
                        \ instruction to make a sound and take some damage

 JMP DEATH              \ Otherwise our energy levels are either 0 or negative,
                        \ and in either case that means we jump to our DEATH,
                        \ returning from the subroutine using a tail call

 JSR EXNO3              \ We didn't die, so call EXNO3 to make the sound of a
                        \ collision

 JMP OUCH               \ And jump to OUCH to take damage and return from the
                        \ subroutine using a tail call

\ ******************************************************************************
\
\       Name: SPS3
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Copy a space coordinate from the K% block into K3
\
\ ------------------------------------------------------------------------------
\
\ Copy one of the planet's coordinates into the corresponding location in the
\ temporary variable K3. The high byte and absolute value of the sign byte are
\ copied into the first two K3 bytes, and the sign of the sign byte is copied
\ into the highest K3 byte.
\
\ The comments below are written for copying the planet's x-coordinate into
\ K3(2 1 0).
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   Determines which coordinate to copy, and to where:
\
\                         * X = 0 copies (x_sign, x_hi) into K3(2 1 0)
\
\                         * X = 3 copies (y_sign, y_hi) into K3(5 4 3)
\
\                         * X = 6 copies (z_sign, z_hi) into K3(8 7 6)
\
\ ******************************************************************************

.SPS3

 LDA K%+1,X             \ Copy x_hi into K3+X
 STA K3,X

 LDA K%+2,X             \ Set A = Y = x_sign
 TAY

 AND #%01111111         \ Set K3+1 = |x_sign|
 STA K3+1,X

 TYA                    \ Set K3+2 = the sign of x_sign
 AND #%10000000
 STA K3+2,X

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: NWSPS
\       Type: Subroutine
\   Category: Universe
\    Summary: Add a new space station to our local bubble of universe
\
\ ******************************************************************************

.NWSPS

 JSR SPBLB              \ Light up the space station bulb on the dashboard

 LDX #%10000001         \ Set the AI flag in byte #32 to %10000001 (AI enabled,
 STX INWK+32            \ has an E.C.M.)

 LDX #0                 \ Set pitch counter to 0 (no pitch, roll only)
 STX INWK+30

 STX NEWB               \ Set NEWB to %00000000, though this gets overridden by
                        \ the default flags from E% in NWSHP below

\STX INWK+31            \ This instruction is commented out in the original
                        \ source. It would set the exploding state and missile
                        \ count to 0

 STX FRIN+1             \ Set the second slot in the FRIN table to 0, so when we
                        \ fall through into NWSHP below, the new station that
                        \ gets created will go into slot FRIN+1, as this will be
                        \ the first empty slot that the routine finds

 DEX                    \ Set the roll counter to 255 (maximum anti-clockwise
 STX INWK+29            \ roll with no damping)

 LDX #10                \ Call NwS1 to flip the sign of nosev_x_hi (byte #10)
 JSR NwS1

 JSR NwS1               \ And again to flip the sign of nosev_y_hi (byte #12)

 JSR NwS1               \ And again to flip the sign of nosev_z_hi (byte #14)

 LDA spasto             \ Copy the address of the Coriolis space station's ship
 STA XX21+2*SST-2       \ blueprint from spasto to the #SST entry in the
 LDA spasto+1           \ blueprint lookup table at XX21, so when we spawn a
 STA XX21+2*SST-1       \ ship of type #SST, it will be a Coriolis station

 LDA tek                \ If the system's tech level in tek is less than 10,
 CMP #10                \ jump to notadodo, so tech levels 0 to 9 have Coriolis
 BCC notadodo           \ stations, while 10 and above will have Dodo stations

 LDA XX21+2*DOD-2       \ Copy the address of the Dodo space station's ship
 STA XX21+2*SST-2       \ blueprint from spasto to the #SST entry in the
 LDA XX21+2*DOD-1       \ blueprint lookup table at XX21, so when we spawn a
 STA XX21+2*SST-1       \ ship of type #SST, it will be a Dodo station

.notadodo

 LDA #LO(LSO)           \ Set bytes #33 and #34 to point to LSO for the ship
 STA INWK+33            \ line heap for the space station
 LDA #HI(LSO)
 STA INWK+34

 LDA #SST               \ Set A to the space station type, and fall through
                        \ into NWSHP to finish adding the space station to the
                        \ universe

\ ******************************************************************************
\
\       Name: NWSHP
\       Type: Subroutine
\   Category: Universe
\    Summary: Add a new ship to our local bubble of universe
\
\ ------------------------------------------------------------------------------
\
\ This creates a new block of ship data in the K% workspace, allocates a new
\ block in the ship line heap at WP, adds the new ship's type into the first
\ empty slot in FRIN, and adds a pointer to the ship data into UNIV. If there
\ isn't enough free memory for the new ship, it isn't added.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The type of the ship to add (see variable XX21 for a
\                       list of ship types)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              Set if the ship was successfully added, clear if it
\                       wasn't (as there wasn't enough free memory)
\
\   INF                 Points to the new ship's data block in K%
\
\ ******************************************************************************

.NWSHP

 STA T                  \ Store the ship type in location T

 LDX #0                 \ Before we can add a new ship, we need to check
                        \ whether we have an empty slot we can put it in. To do
                        \ this, we need to loop through all the slots to look
                        \ for an empty one, so set a counter in X that starts
                        \ from the first slot at 0. When ships are killed, then
                        \ the slots are shuffled down by the KILLSHP routine, so
                        \ the first empty slot will always come after the last
                        \ filled slot. This allows us to tack the new ship's
                        \ data block and ship line heap onto the end of the
                        \ existing ship data and heap, as shown in the memory
                        \ map below

.NWL1

 LDA FRIN,X             \ Load the ship type for the X-th slot

 BEQ NW1                \ If it is zero, then this slot is empty and we can use
                        \ it for our new ship, so jump down to NW1

 INX                    \ Otherwise increment X to point to the next slot

 CPX #NOSH              \ If we haven't reached the last slot yet, loop back up
 BCC NWL1               \ to NWL1 to check the next slot (note that this means
                        \ only slots from 0 to #NOSH - 1 are populated by this
                        \ routine, but there is one more slot reserved in FRIN,
                        \ which is used to identify the end of the slot list
                        \ when shuffling the slots down in the KILLSHP routine)

.NW3

 CLC                    \ Otherwise we don't have an empty slot, so we can't
 RTS                    \ add a new ship, so clear the C flag to indicate that
                        \ we have not managed to create the new ship, and return
                        \ from the subroutine

.NW1

                        \ If we get here, then we have found an empty slot at
                        \ index X, so we can go ahead and create our new ship.
                        \ We do that by creating a ship data block at INWK and,
                        \ when we are done, copying the block from INWK into
                        \ the K% workspace (specifically, to INF)

 JSR GINF               \ Get the address of the data block for ship slot X
                        \ (which is in workspace K%) and store it in INF

 LDA T                  \ If the type of ship that we want to create is
 BMI NW2                \ negative, then this indicates a planet or sun, so
                        \ jump down to NW2, as the next section sets up a ship
                        \ data block, which doesn't apply to planets and suns,
                        \ as they don't have things like shields, missiles,
                        \ vertices and edges

                        \ This is a ship, so first we need to set up various
                        \ pointers to the ship blueprint we will need. The
                        \ blueprints for each ship type in Elite are stored
                        \ in a table at location XX21, so refer to the comments
                        \ on that variable for more details on the data we're
                        \ about to access

 ASL A                  \ Set Y = ship type * 2
 TAY

 LDA XX21-1,Y           \ The ship blueprints at XX21 start with a lookup
                        \ table that points to the individual ship blueprints,
                        \ so this fetches the high byte of this particular ship
                        \ type's blueprint

 BEQ NW3                \ If the high byte is 0 then this is not a valid ship
                        \ type, so jump to NW3 to clear the C flag and return
                        \ from the subroutine

 STA XX0+1              \ This is a valid ship type, so store the high byte in
                        \ XX0+1

 LDA XX21-2,Y           \ Fetch the low byte of this particular ship type's
 STA XX0                \ blueprint and store it in XX0, so XX0(1 0) now
                        \ contains the address of this ship's blueprint

 CPY #2*SST             \ If the ship type is a space station (SST), then jump
 BEQ NW6                \ to NW6, skipping the heap space steps below, as the
                        \ space station has its own line heap at LSO (which it
                        \ shares with the sun)

                        \ We now want to allocate space for a heap that we can
                        \ use to store the lines we draw for our new ship (so it
                        \ can easily be erased from the screen again). SLSP
                        \ points to the start of the current heap space, and we
                        \ can extend it downwards with the heap for our new ship
                        \ (as the heap space always ends just before the WP
                        \ workspace)

 LDY #5                 \ Fetch ship blueprint byte #5, which contains the
 LDA (XX0),Y            \ maximum heap size required for plotting the new ship,
 STA T1                 \ and store it in T1

 LDA SLSP               \ Take the 16-bit address in SLSP and subtract T1,
 SEC                    \ storing the 16-bit result in INWK(34 33), so this now
 SBC T1                 \ points to the start of the line heap for our new ship
 STA INWK+33
 LDA SLSP+1
 SBC #0
 STA INWK+34

                        \ We now need to check that there is enough free space
                        \ for both this new line heap and the new data block
                        \ for our ship. In memory, this is the layout of the
                        \ ship data blocks and ship line heaps:
                        \
                        \   +-----------------------------------+   &1034
                        \   |                                   |
                        \   | WP workspace                      |
                        \   |                                   |
                        \   +-----------------------------------+   &0800 = WP
                        \   |                                   |
                        \   | Current ship line heap            |
                        \   |                                   |
                        \   +-----------------------------------+   SLSP
                        \   |                                   |
                        \   | Proposed heap for new ship        |
                        \   |                                   |
                        \   +-----------------------------------+   INWK(34 33)
                        \   |                                   |
                        \   .                                   .
                        \   .                                   .
                        \   .                                   .
                        \   .                                   .
                        \   .                                   .
                        \   |                                   |
                        \   +-----------------------------------+   INF + NI%
                        \   |                                   |
                        \   | Proposed data block for new ship  |
                        \   |                                   |
                        \   +-----------------------------------+   INF
                        \   |                                   |
                        \   | Existing ship data blocks         |
                        \   |                                   |
                        \   +-----------------------------------+   &0400 = K%
                        \
                        \ So, to work out if we have enough space, we have to
                        \ make sure there is room between the end of our new
                        \ ship data block at INF + NI%, and the start of the
                        \ proposed heap for our new ship at the address we
                        \ stored in INWK(34 33). Or, to put it another way, we
                        \ and to make sure that:
                        \
                        \   INWK(34 33) > INF + NI%
                        \
                        \ which is the same as saying:
                        \
                        \   INWK+33 - INF > NI%
                        \
                        \ because INWK is in zero page, so INWK+34 = 0

 LDA INWK+33            \ Calculate INWK+33 - INF, again using 16-bit
\SEC                    \ arithmetic, and put the result in (A Y), so the high
 SBC INF                \ byte is in A and the low byte in Y. The SEC
 TAY                    \ instruction is commented out in the original source;
 LDA INWK+34            \ as the previous subtraction will never underflow, it
 SBC INF+1              \ is superfluous

 BCC NW3+1              \ If we have an underflow from the subtraction, then
                        \ INF > INWK+33 and we definitely don't have enough
                        \ room for this ship, so jump to NW3+1, which returns
                        \ from the subroutine (with the C flag already cleared)

 BNE NW4                \ If the subtraction of the high bytes in A is not
                        \ zero, and we don't have underflow, then we definitely
                        \ have enough space, so jump to NW4 to continue setting
                        \ up the new ship

 CPY #NI%               \ Otherwise the high bytes are the same in our
 BCC NW3+1              \ subtraction, so now we compare the low byte of the
                        \ result (which is in Y) with NI%. This is the same as
                        \ doing INWK+33 - INF > NI% (see above). If this isn't
                        \ true, the C flag will be clear and we don't have
                        \ enough space, so we jump to NW3+1, which returns
                        \ from the subroutine (with the C flag already cleared)

.NW4

 LDA INWK+33            \ If we get here then we do have enough space for our
 STA SLSP               \ new ship, so store the new bottom of the ship line
 LDA INWK+34            \ heap (i.e. INWK+33) in SLSP, doing both the high and
 STA SLSP+1             \ low bytes

.NW6

 LDY #14                \ Fetch ship blueprint byte #14, which contains the
 LDA (XX0),Y            \ ship's energy, and store it in byte #35
 STA INWK+35

 LDY #19                \ Fetch ship blueprint byte #19, which contains the
 LDA (XX0),Y            \ number of missiles and laser power, and AND with %111
 AND #%00000111         \ to extract the number of missiles before storing in
 STA INWK+31            \ byte #31

 LDA T                  \ Restore the ship type we stored above

.NW2

 STA FRIN,X             \ Store the ship type in the X-th byte of FRIN, so the
                        \ slot is now shown as occupied in the index table

 TAX                    \ Copy the ship type into X

 BMI NW8                \ If the ship type is negative (planet or sun), then
                        \ jump to NW8 to skip the following instructions

 CPX #HER               \ If the ship type is a rock hermit, jump to gangbang
 BEQ gangbang           \ to increase the junk count

 CPX #JL                \ If JL <= X < JH, i.e. the type of ship we added in X
 BCC NW7                \ is junk (escape pod, alloy plate, cargo canister,
 CPX #JH                \ asteroid, splinter, Shuttle or Transporter), then keep
 BCS NW7                \ going, otherwise jump to NW7

.gangbang

 INC JUNK               \ We're adding junk, so increase the junk counter

.NW7

 INC MANY,X             \ Increment the total number of ships of type X

.NW8

 LDY T                  \ Restore the ship type we stored above

 LDA E%-1,Y             \ Fetch the E% byte for this ship to get the default
                        \ settings for the ship's NEWB flags

 AND #%01101111         \ Zero bits 4 and 7 (so the new ship is not docking, has
                        \ not been scooped, and has not just docked)

 ORA NEWB               \ Apply the result to the ship's NEWB flags, which sets
 STA NEWB               \ bits 0-3 and 5-6 in NEWB if they are set in the E%
                        \ byte

 LDY #NI%-1             \ The final step is to copy the new ship's data block
                        \ from INWK to INF, so set up a counter for NI% bytes
                        \ in Y

.NWL3

 LDA INWK,Y             \ Load the Y-th byte of INWK and store in the Y-th byte
 STA (INF),Y            \ of the workspace pointed to by INF

 DEY                    \ Decrement the loop counter

 BPL NWL3               \ Loop back for the next byte until we have copied them
                        \ all over

 SEC                    \ We have successfully created our new ship, so set the
                        \ C flag to indicate success

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: NwS1
\       Type: Subroutine
\   Category: Universe
\    Summary: Flip the sign and double an INWK byte
\
\ ------------------------------------------------------------------------------
\
\ Flip the sign of the INWK byte at offset X, and increment X by 2. This is
\ used by the space station creation routine at NWSPS.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The offset of the INWK byte to be flipped
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   X                   X is incremented by 2
\
\ ******************************************************************************

.NwS1

 LDA INWK,X             \ Load the X-th byte of INWK into A and flip bit 7,
 EOR #%10000000         \ storing the result back in the X-th byte of INWK
 STA INWK,X

 INX                    \ Add 2 to X
 INX

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: ABORT
\       Type: Subroutine
\   Category: Dashboard
\    Summary: Unarm missiles and update the dashboard indicators
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   Y                   The new colour of the missile indicator:
\
\                         * &00 = black (no missile)
\
\                         * #RED2 = red (armed and locked)
\
\                         * #YELLOW2 = yellow/white (armed)
\
\                         * #GREEN2 = green (unarmed)
\
\ ******************************************************************************

.ABORT

 LDX #&FF               \ Set X to &FF, which is the value of MSTG when we have
                        \ no target lock for our missile

                        \ Fall through into ABORT2 to set the missile lock to
                        \ the value in X, which effectively unarms the missile

\ ******************************************************************************
\
\       Name: ABORT2
\       Type: Subroutine
\   Category: Dashboard
\    Summary: Set/unset the lock target for a missile and update the dashboard
\
\ ------------------------------------------------------------------------------
\
\ Set the lock target for the leftmost missile and update the dashboard.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The slot number of the ship to lock our missile onto, or
\                       &FF to remove missile lock
\
\   Y                   The new colour of the missile indicator:
\
\                         * &00 = black (no missile)
\
\                         * #RED2 = red (armed and locked)
\
\                         * #YELLOW2 = yellow/white (armed)
\
\                         * #GREEN2 = green (unarmed)
\
\ ******************************************************************************

.ABORT2

 STX MSTG               \ Store the target of our missile lock in MSTG

 LDX NOMSL              \ Call MSBAR to update the leftmost indicator in the
 JSR MSBAR              \ dashboard's missile bar, which returns with Y = 0

 STY MSAR               \ Set MSAR = 0 to indicate that the leftmost missile
                        \ is no longer seeking a target lock

 RTS                    \ Return from the subroutine

.msbpars

 EQUB 4, 0, 0, 0, 0     \ These bytes appear to be unused (they are left over
                        \ from the 6502 Second Processor version of Elite)

\ ******************************************************************************
\
\       Name: PROJ
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Project the current ship or planet onto the screen
\  Deep dive: Extended screen coordinates
\
\ ------------------------------------------------------------------------------
\
\ Project the current ship's location or the planet onto the screen, either
\ returning the screen coordinates of the projection (if it's on-screen), or
\ returning an error via the C flag.
\
\ In this context, "on-screen" means that the point is projected into the
\ following range:
\
\   centre of screen - 1024 < x < centre of screen + 1024
\   centre of screen - 1024 < y < centre of screen + 1024
\
\ This is to cater for ships (and, more likely, planets and suns) whose centres
\ are off-screen but whose edges may still be visible.
\
\ The projection calculation is:
\
\   K3(1 0) = #X + x / z
\   K4(1 0) = #Y + y / z
\
\ where #X and #Y are the pixel x-coordinate and y-coordinate of the centre of
\ the screen.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   INWK                The ship data block for the ship to project on-screen
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   K3(1 0)             The x-coordinate of the ship's projection on-screen
\
\   K4(1 0)             The y-coordinate of the ship's projection on-screen
\
\   C flag              Set if the ship's projection doesn't fit on the screen,
\                       clear if it does project onto the screen
\
\   A                   Contains K4+1, the high byte of the y-coordinate
\
\ ******************************************************************************

.PROJ

 LDA INWK               \ Set P(1 0) = (x_hi x_lo)
 STA P                  \            = x
 LDA INWK+1
 STA P+1

 LDA INWK+2             \ Set A = x_sign

 JSR PLS6               \ Call PLS6 to calculate:
                        \
                        \   (X K) = (A P+1 P) / (z_sign z_hi z_lo)
                        \         = (x_sign x_hi x_lo) / (z_sign z_hi z_lo)
                        \         = x / z

 BCS PL2-1              \ If the C flag is set then the result overflowed and
                        \ the coordinate doesn't fit on the screen, so return
                        \ from the subroutine with the C flag set (as PL2-1
                        \ contains an RTS)

 LDA K                  \ Set K3(1 0) = (X K) + #X
 ADC #X                 \             = #X + x / z
 STA K3                 \
                        \ first doing the low bytes

 TXA                    \ And then the high bytes. #X is the x-coordinate of
 ADC #0                 \ the centre of the space view, so this converts the
 STA K3+1               \ space x-coordinate into a screen x-coordinate

 LDA INWK+3             \ Set P(1 0) = (y_hi y_lo)
 STA P
 LDA INWK+4
 STA P+1

 LDA INWK+5             \ Set A = -y_sign
 EOR #%10000000

 JSR PLS6               \ Call PLS6 to calculate:
                        \
                        \   (X K) = (A P+1 P) / (z_sign z_hi z_lo)
                        \         = -(y_sign y_hi y_lo) / (z_sign z_hi z_lo)
                        \         = -y / z

 BCS PL2-1              \ If the C flag is set then the result overflowed and
                        \ the coordinate doesn't fit on the screen, so return
                        \ from the subroutine with the C flag set (as PL2-1
                        \ contains an RTS)

 LDA K                  \ Set K4(1 0) = (X K) + #Y
 ADC #Y                 \             = #Y - y / z
 STA K4                 \
                        \ first doing the low bytes

 TXA                    \ And then the high bytes. #Y is the y-coordinate of
 ADC #0                 \ the centre of the space view, so this converts the
 STA K4+1               \ space y-coordinate into a screen y-coordinate

 CLC                    \ Clear the C flag to indicate success

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: PL2
\       Type: Subroutine
\   Category: Drawing planets
\    Summary: Remove the planet or sun from the screen
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   PL2-1               Contains an RTS
\
\ ******************************************************************************

.PL2

 LDA TYPE               \ Shift bit 0 of the planet/sun's type into the C flag
 LSR A

 BCS P%+5               \ If the planet/sun's type has bit 0 clear, then it's
                        \ either 128 or 130, which is a planet; meanwhile, the
                        \ sun has type 129, which has bit 0 set. So if this is
                        \ the sun, skip the following instruction

 JMP WPLS2              \ This is the planet, so jump to WPLS2 to remove it from
                        \ screen, returning from the subroutine using a tail
                        \ call

 JMP WPLS               \ This is the sun, so jump to WPLS to remove it from
                        \ screen, returning from the subroutine using a tail
                        \ call

\ ******************************************************************************
\
\       Name: PLANET
\       Type: Subroutine
\   Category: Drawing planets
\    Summary: Draw the planet or sun
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   INWK                The planet or sun's ship data block
\
\ ******************************************************************************

.PLANET

 LDA #GREEN             \ Switch to stripe 3-1-3-1, which is cyan/yellow in the
 STA COL                \ space view

 LDA INWK+8             \ Set A = z_sign (the highest byte in the planet/sun's
                        \ coordinates)

\BMI PL2                \ This instruction is commented out in the original
                        \ source. It would remove the planet from the screen
                        \ when it's behind us

 CMP #48                \ If A >= 48 then the planet/sun is too far away to be
 BCS PL2                \ seen, so jump to PL2 to remove it from the screen,
                        \ returning from the subroutine using a tail call

 ORA INWK+7             \ Set A to 0 if both z_sign and z_hi are 0

 BEQ PL2                \ If both z_sign and z_hi are 0, then the planet/sun is
                        \ too close to be shown, so jump to PL2 to remove it
                        \ from the screen, returning from the subroutine using a
                        \ tail call

 JSR PROJ               \ Project the planet/sun onto the screen, returning the
                        \ centre's coordinates in K3(1 0) and K4(1 0)

 BCS PL2                \ If the C flag is set by PROJ then the planet/sun is
                        \ not visible on-screen, so jump to PL2 to remove it
                        \ from the screen, returning from the subroutine using
                        \ a tail call

 LDA #96                \ Set (A P+1 P) = (0 96 0) = 24576
 STA P+1                \
 LDA #0                 \ This represents the planet/sun's radius at a distance
 STA P                  \ of z = 1

 JSR DVID3B2            \ Call DVID3B2 to calculate:
                        \
                        \   K(3 2 1 0) = (A P+1 P) / (z_sign z_hi z_lo)
                        \              = (0 96 0) / z
                        \              = 24576 / z
                        \
                        \ so K now contains the planet/sun's radius, reduced by
                        \ the actual distance to the planet/sun. We know that
                        \ K+3 and K+2 will be 0, as the number we are dividing,
                        \ (0 96 0), fits into the two bottom bytes, so the
                        \ result is actually in K(1 0)

 LDA K+1                \ If the high byte of the reduced radius is zero, jump
 BEQ PL82               \ to PL82, as K contains the radius on its own

 LDA #248               \ Otherwise set K = 248, to round up the radius in
 STA K                  \ K(1 0) to the nearest integer (if we consider the low
                        \ byte to be the fractional part)

.PL82

 LDA TYPE               \ If the planet/sun's type has bit 0 clear, then it's
 LSR A                  \ either 128 or 130, which is a planet (the sun has type
 BCC PL9                \ 129, which has bit 0 set). So jump to PL9 to draw the
                        \ planet with radius K, returning from the subroutine
                        \ using a tail call

 JMP SUN                \ Otherwise jump to SUN to draw the sun with radius K,
                        \ returning from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: PL9 (Part 1 of 3)
\       Type: Subroutine
\   Category: Drawing planets
\    Summary: Draw the planet, with either an equator and meridian, or a crater
\
\ ------------------------------------------------------------------------------
\
\ Draw the planet with radius K at pixel coordinate (K3, K4), and with either an
\ equator and meridian, or a crater.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   K(1 0)              The planet's radius
\
\   K3(1 0)             Pixel x-coordinate of the centre of the planet
\
\   K4(1 0)             Pixel y-coordinate of the centre of the planet
\
\   INWK                The planet's ship data block
\
\ ******************************************************************************

.PL9

 JSR WPLS2              \ Call WPLS2 to remove the planet from the screen

 JSR CIRCLE             \ Call CIRCLE to draw the planet's new circle

 BCS PL20               \ If the call to CIRCLE returned with the C flag set,
                        \ then the circle does not fit on-screen, so jump to
                        \ PL20 to return from the subroutine

 LDA K+1                \ If K+1 is zero, jump to PL25 as K(1 0) < 256, so the
 BEQ PL25               \ planet fits on the screen and we can draw meridians or
                        \ craters

.PL20

 RTS                    \ The planet doesn't fit on-screen, so return from the
                        \ subroutine

.PL25

 LDA TYPE               \ If the planet type is 128 then it has an equator and
 CMP #128               \ a meridian, so this jumps to PL26 if this is not a
 BNE PL26               \ planet with an equator - in other words, if it is a
                        \ planet with a crater

                        \ Otherwise this is a planet with an equator and
                        \ meridian, so fall through into the following to draw
                        \ them

\ ******************************************************************************
\
\       Name: PL9 (Part 2 of 3)
\       Type: Subroutine
\   Category: Drawing planets
\    Summary: Draw the planet's equator and meridian
\  Deep dive: Drawing meridians and equators
\
\ ------------------------------------------------------------------------------
\
\ Draw the planet's equator and meridian.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   K(1 0)              The planet's radius
\
\   K3(1 0)             Pixel x-coordinate of the centre of the planet
\
\   K4(1 0)             Pixel y-coordinate of the centre of the planet
\
\   INWK                The planet's ship data block
\
\ ******************************************************************************

 LDA K                  \ If the planet's radius is less than 6, the planet is
 CMP #6                 \ too small to show a meridian, so jump to PL20 to
 BCC PL20               \ return from the subroutine

 LDA INWK+14            \ Set P = -nosev_z_hi
 EOR #%10000000
 STA P

 LDA INWK+20            \ Set A = roofv_z_hi

 JSR PLS4               \ Call PLS4 to calculate the following:
                        \
                        \   CNT2 = arctan(P / A) / 4
                        \        = arctan(-nosev_z_hi / roofv_z_hi) / 4
                        \
                        \ and do the following if nosev_z_hi >= 0:
                        \
                        \   CNT2 = CNT2 + PI

 LDX #9                 \ Set X to 9 so the call to PLS1 divides nosev_x

 JSR PLS1               \ Call PLS1 to calculate the following:
 STA K2                 \
 STY XX16               \   (XX16 K2) = nosev_x / z
                        \
                        \ and increment X to point to nosev_y for the next call

 JSR PLS1               \ Call PLS1 to calculate the following:
 STA K2+1               \
 STY XX16+1             \   (XX16+1 K2+1) = nosev_y / z

 LDX #15                \ Set X to 15 so the call to PLS5 divides roofv_x

 JSR PLS5               \ Call PLS5 to calculate the following:
                        \
                        \   (XX16+2 K2+2) = roofv_x / z
                        \
                        \   (XX16+3 K2+3) = roofv_y / z

 JSR PLS2               \ Call PLS2 to draw the first meridian

 LDA INWK+14            \ Set P = -nosev_z_hi
 EOR #%10000000
 STA P

 LDA INWK+26            \ Set A = sidev_z_hi, so the second meridian will be at
                        \ 90 degrees to the first

 JSR PLS4               \ Call PLS4 to calculate the following:
                        \
                        \   CNT2 = arctan(P / A) / 4
                        \        = arctan(-nosev_z_hi / sidev_z_hi) / 4
                        \
                        \ and do the following if nosev_z_hi >= 0:
                        \
                        \   CNT2 = CNT2 + PI

 LDX #21                \ Set X to 21 so the call to PLS5 divides sidev_x

 JSR PLS5               \ Call PLS5 to calculate the following:
                        \
                        \   (XX16+2 K2+2) = sidev_x / z
                        \
                        \   (XX16+3 K2+3) = sidev_y / z

 JMP PLS2               \ Jump to PLS2 to draw the second meridian, returning
                        \ from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: PL9 (Part 3 of 3)
\       Type: Subroutine
\   Category: Drawing planets
\    Summary: Draw the planet's crater
\  Deep dive: Drawing craters
\
\ ------------------------------------------------------------------------------
\
\ Draw the planet's crater.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   K(1 0)              The planet's radius
\
\   K3(1 0)             Pixel x-coordinate of the centre of the planet
\
\   K4(1 0)             Pixel y-coordinate of the centre of the planet
\
\   INWK                The planet's ship data block
\
\ ******************************************************************************

.PL26

 LDA INWK+20            \ Set A = roofv_z_hi

 BMI PL20               \ If A is negative, the crater is on the far side of the
                        \ planet, so return from the subroutine (as PL2
                        \ contains an RTS)

 LDX #15                \ Set X = 15, so the following call to PLS3 operates on
                        \ roofv

 JSR PLS3               \ Call PLS3 to calculate:
                        \
                        \   (Y A P) = 222 * roofv_x / z
                        \
                        \ to give the x-coordinate of the crater offset and
                        \ increment X to point to roofv_y for the next call

 CLC                    \ Calculate:
 ADC K3                 \
 STA K3                 \   K3(1 0) = (Y A) + K3(1 0)
                        \           = 222 * roofv_x / z + x-coordinate of planet
                        \             centre
                        \
                        \ starting with the high bytes

 TYA                    \ And then doing the low bytes, so now K3(1 0) contains
 ADC K3+1               \ the x-coordinate of the crater offset plus the planet
 STA K3+1               \ centre to give the x-coordinate of the crater's centre

 JSR PLS3               \ Call PLS3 to calculate:
                        \
                        \   (Y A P) = 222 * roofv_y / z
                        \
                        \ to give the y-coordinate of the crater offset

 STA P                  \ Calculate:
 LDA K4                 \
 SEC                    \   K4(1 0) = K4(1 0) - (Y A)
 SBC P                  \           = 222 * roofv_y / z - y-coordinate of planet
 STA K4                 \             centre
                        \
                        \ starting with the low bytes

 STY P                  \ And then doing the low bytes, so now K4(1 0) contains
 LDA K4+1               \ the y-coordinate of the crater offset plus the planet
 SBC P                  \ centre to give the y-coordinate of the crater's centre
 STA K4+1

 LDX #9                 \ Set X = 9, so the following call to PLS1 operates on
                        \ nosev

 JSR PLS1               \ Call PLS1 to calculate the following:
                        \
                        \   (Y A) = nosev_x / z
                        \
                        \ and increment X to point to nosev_y for the next call

 LSR A                  \ Set (XX16 K2) = (Y A) / 2
 STA K2
 STY XX16

 JSR PLS1               \ Call PLS1 to calculate the following:
                        \
                        \   (Y A) = nosev_y / z
                        \
                        \ and increment X to point to nosev_z for the next call

 LSR A                  \ Set (XX16+1 K2+1) = (Y A) / 2
 STA K2+1
 STY XX16+1

 LDX #21                \ Set X = 21, so the following call to PLS1 operates on
                        \ sidev

 JSR PLS1               \ Call PLS1 to calculate the following:
                        \
                        \   (Y A) = sidev_x / z
                        \
                        \ and increment X to point to sidev_y for the next call

 LSR A                  \ Set (XX16+2 K2+2) = (Y A) / 2
 STA K2+2
 STY XX16+2

 JSR PLS1               \ Call PLS1 to calculate the following:
                        \
                        \   (Y A) = sidev_y / z
                        \
                        \ and increment X to point to sidev_z for the next call

 LSR A                  \ Set (XX16+3 K2+3) = (Y A) / 2
 STA K2+3
 STY XX16+3

 LDA #64                \ Set TGT = 64, so we draw a full ellipse in the call to
 STA TGT                \ PLS22 below

 LDA #0                 \ Set CNT2 = 0 as we are drawing a full ellipse, so we
 STA CNT2               \ don't need to apply an offset

 JMP PLS22              \ Jump to PLS22 to draw the crater, returning from the
                        \ subroutine using a tail call

\ ******************************************************************************
\
\       Name: PLS1
\       Type: Subroutine
\   Category: Drawing planets
\    Summary: Calculate (Y A) = nosev_x / z
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following division of a specified value from one of the
\ orientation vectors (in this example, nosev_x):
\
\   (Y A) = nosev_x / z
\
\ where z is the z-coordinate of the planet from INWK. The result is an 8-bit
\ magnitude in A, with maximum value 254, and just a sign bit (bit 7) in Y.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   Determines which of the INWK orientation vectors to
\                       divide:
\
\                         * X = 9, 11, 13: divides nosev_x, nosev_y, nosev_z
\
\                         * X = 15, 17, 19: divides roofv_x, roofv_y, roofv_z
\
\                         * X = 21, 23, 25: divides sidev_x, sidev_y, sidev_z
\
\   INWK                The planet's ship data block
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   The result as an 8-bit magnitude with maximum value 254
\
\   Y                   The sign of the result in bit 7
\
\   K+3                 Also the sign of the result in bit 7
\
\   X                   X gets incremented by 2 so it points to the next
\                       coordinate in this orientation vector (so consecutive
\                       calls to the routine will start with x, then move onto y
\                       and then z)
\
\ ******************************************************************************

.PLS1

 LDA INWK,X             \ Set P = nosev_x_lo
 STA P

 LDA INWK+1,X           \ Set P+1 = |nosev_x_hi|
 AND #%01111111
 STA P+1

 LDA INWK+1,X           \ Set A = sign bit of nosev_x_lo
 AND #%10000000

 JSR DVID3B2            \ Call DVID3B2 to calculate:
                        \
                        \   K(3 2 1 0) = (A P+1 P) / (z_sign z_hi z_lo)

 LDA K                  \ Fetch the lowest byte of the result into A

 LDY K+1                \ Fetch the second byte of the result into Y

 BEQ P%+4               \ If the second byte is 0, skip the next instruction

 LDA #254               \ The second byte is non-zero, so the result won't fit
                        \ into one byte, so set A = 254 as our maximum one-byte
                        \ value to return

 LDY K+3                \ Fetch the sign of the result from K+3 into Y

 INX                    \ Add 2 to X so the index points to the next coordinate
 INX                    \ in this orientation vector (so consecutive calls to
                        \ the routine will start with x, then move onto y and z)

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: PLS2
\       Type: Subroutine
\   Category: Drawing planets
\    Summary: Draw a half-ellipse
\  Deep dive: Drawing ellipses
\             Drawing meridians and equators
\
\ ------------------------------------------------------------------------------
\
\ Draw a half-ellipse, used for the planet's equator and meridian.
\
\ ******************************************************************************

.PLS2

 LDA #31                \ Set TGT = 31, so we only draw half an ellipse
 STA TGT

                        \ Fall through into PLS22 to draw the half-ellipse

\ ******************************************************************************
\
\       Name: PLS22
\       Type: Subroutine
\   Category: Drawing planets
\    Summary: Draw an ellipse or half-ellipse
\  Deep dive: Drawing ellipses
\             Drawing meridians and equators
\             Drawing craters
\
\ ------------------------------------------------------------------------------
\
\ Draw an ellipse or half-ellipse, to be used for the planet's equator and
\ meridian (in which case we draw half an ellipse), or crater (in which case we
\ draw a full ellipse).
\
\ The ellipse is defined by a centre point, plus two conjugate radius vectors,
\ u and v, where:
\
\   u = [ u_x ]       v = [ v_x ]
\       [ u_y ]           [ v_y ]
\
\ The individual components of these 2D vectors (i.e. u_x, u_y etc.) are 16-bit
\ sign-magnitude numbers, where the high bytes contain only the sign bit (in
\ bit 7), with bits 0 to 6 being clear. This means that as we store u_x as
\ (XX16 K2), for example, we know that |u_x| = K2.
\
\ This routine calls BLINE to draw each line segment in the ellipse, passing the
\ coordinates as follows:
\
\   K6(1 0) = K3(1 0) + u_x * cos(CNT2) + v_x * sin(CNT2)
\
\   K6(3 2) = K4(1 0) - u_y * cos(CNT2) - v_y * sin(CNT2)
\
\ The y-coordinates are negated because BLINE expects pixel coordinates but the
\ u and v vectors are extracted from the orientation vector. The y-axis runs
\ in the opposite direction in 3D space to that on the screen, so we need to
\ negate the 3D space coordinates before we can combine them with the ellipse's
\ centre coordinates.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   K(1 0)              The planet's radius
\
\   K3(1 0)             The pixel x-coordinate of the centre of the ellipse
\
\   K4(1 0)             The pixel y-coordinate of the centre of the ellipse
\
\   (XX16 K2)           The x-component of u (i.e. u_x), where XX16 contains
\                       just the sign of the sign-magnitude number
\
\   (XX16+1 K2+1)       The y-component of u (i.e. u_y), where XX16+1 contains
\                       just the sign of the sign-magnitude number
\
\   (XX16+2 K2+2)       The x-component of v (i.e. v_x), where XX16+2 contains
\                       just the sign of the sign-magnitude number
\
\   (XX16+3 K2+3)       The y-component of v (i.e. v_y), where XX16+3 contains
\                       just the sign of the sign-magnitude number
\
\   TGT                 The number of segments to draw:
\
\                         * 32 for a half ellipse (a meridian)
\
\                         * 64 for a full ellipse (a crater)
\
\   CNT2                The starting segment for drawing the half-ellipse
\
\ ******************************************************************************

.PLS22

 JSR H_PCURVE           \ Port: a new curve of the planet's detail, for the
                        \ renderer (gfx-hooks.asm)

 LDX #0                 \ Set CNT = 0
 STX CNT

 DEX                    \ Set FLAG = &FF to start a new line in the ball line
 STX FLAG               \ heap when calling BLIN below, so the crater or
                        \ meridian is separate from any previous ellipses

.PLL4

 LDA CNT2               \ Set the C flag if CNT2 >= 33, i.e. C = the sign of
 CMP #33                \ sin(CNT2) (set for 180 to 360 degrees)
 AND #31                \
 TAX                    \ Set X = CNT2 mod 32, so sin(X) = |sin(CNT2)|

 LDA #0                 \ Shift the C flag into the sign bit of XX16+5, so
 ROR A                  \ XX16+5 has the correct sign for sin(CNT2)
 STA XX16+5             \ (this also clears the C flag)

 LDA SNE,X              \ Set Q = sin(X)
 STA Q                  \       = |sin(CNT2)|

 LDA K2+2               \ Set R = K2+2 * Q / 256
 JSR FMLTU              \       = |v_x| * |sin(CNT2)|
 STA R                  \ so (XX16+5 R) = |v_x| * sin(CNT2)

 LDA K2+3               \ Set K = K2+3 * Q / 256
 JSR FMLTU+2            \       = |v_y| * |sin(CNT2)|
                        \ (skip FMLTU's STX P: the previous FMLTU call already
                        \ left P = X, and X is unchanged since)
 STA K                  \ so (XX16+5 K) = |v_y| * sin(CNT2)

 TXA                    \ FMLTU preserves X = CNT2 mod 32, so set
 EOR #16                \ X = (CNT2 + 16) mod 32, so sin(X) = |cos(CNT2)|
 TAX

 CLC                    \ Clear the C flag, as the original ADC #16 did, as it
                        \ can pass through FMLTU into the ADC #15 below

 LDA SNE,X              \ Set Q = sin(X)
 STA Q                  \       = |cos(CNT2)|

 LDA K2+1               \ Set K+2 = K2+1 * Q / 256
 JSR FMLTU              \         = |u_y| * |cos(CNT2)|
 STA K+2

 LDA K2                 \ Set P = K2 * Q / 256
 JSR FMLTU              \       = |u_x| * |cos(CNT2)|
 STA P

 LDA XX16+5             \ Set S = the sign of XX16+2 * XX16+5
 EOR XX16+2             \       = the sign of v_x * XX16+5
 STA S                  \
                        \ So because we set this above:
                        \
                        \   (XX16+5 R) = |v_x| * sin(CNT2)
                        \
                        \ we now have this:
                        \
                        \   (S R) = v_x * sin(CNT2)
                        \
                        \ (LDA/EOR/STA leave C alone, so the C flag from
                        \ FMLTU still reaches the ADC #15 below)
                        \
                        \ The call to FMLTU also sets the C flag, so in the
                        \ following, ADC #15 adds 16 rather than 15

 LDA CNT2               \ If (CNT2 + 16) mod 64 >= 33 then this sets the C flag,
 ADC #15                \ otherwise it's clear, so this means that:
 AND #63                \
 CMP #33                \   * C is clear if the segment starts in the first or
                        \     last quarter of the circle, 0 to 90 degrees or 270
                        \     to 360 degrees
                        \
                        \   * C is set if the segment starts in the second or
                        \     third quarter of the circle, 90 to 270 degrees
                        \
                        \ In other words, the C flag contains the sign bit for
                        \ cos(CNT2), which is positive for 0 to 90 degrees or
                        \ 270 to 360 degrees, and negative for 90 to 270 degrees

 LDA #0                 \ Shift the C flag into the sign bit of XX16+4, so:
 ROR A                  \ XX16+4 has the correct sign for cos(CNT2)
 STA XX16+4             \
                        \ Because we set the following above:
                        \
                        \   K+2 = |u_y| * |cos(CNT2)|
                        \   P   = |u_x| * |cos(CNT2)|
                        \
                        \ we can add XX16+4 as the high byte to give us the
                        \ following:
                        \
                        \   (XX16+4 K+2) = |u_y| * cos(CNT2)
                        \   (XX16+4 P)   = |u_x| * cos(CNT2)

 EOR XX16               \ A still holds XX16+4, so set A = the sign of
                        \ XX16 * XX16+4 = the sign of u_x * XX16+4
                        \
                        \ So because we set this above:
                        \
                        \   (XX16+4 P)   = |u_x| * cos(CNT2)
                        \
                        \ we now have this:
                        \
                        \   (A P) = u_x * cos(CNT2)

 JSR ADD                \ Set (A X) = (A P) + (S R)
                        \           = u_x * cos(CNT2) + v_x * sin(CNT2)

 STA T                  \ Store the high byte in T, so the result is now:
                        \
                        \   (T X) = u_x * cos(CNT2) + v_x * sin(CNT2)

 BPL PL42               \ If the result is positive, jump down to PL42

 TXA                    \ The result is negative, so we need to negate the
 EOR #%11111111         \ magnitude using two's complement, first doing the low
 CLC                    \ byte in X
 ADC #1
 TAX

 LDA T                  \ And then the high byte in T, making sure to leave the
 EOR #%01111111         \ sign bit alone
 ADC #0
 STA T

.PL42

 TXA                    \ Set K6(1 0) = K3(1 0) + (T X)
 ADC K3                 \
 STA K6                 \ starting with the low bytes

 LDA T                  \ And then doing the high bytes, so we now get:
 ADC K3+1               \
 STA K6+1               \   K6(1 0) = K3(1 0) + (T X)
                        \           = K3(1 0) + u_x * cos(CNT2)
                        \                     + v_x * sin(CNT2)
                        \
                        \ K3(1 0) is the x-coordinate of the centre of the
                        \ ellipse, so we now have the correct x-coordinate for
                        \ our ellipse segment that we can pass to BLINE below

 LDA K                  \ Set R = K = |v_y| * sin(CNT2)
 STA R

 LDA XX16+5             \ Set S = the sign of XX16+3 * XX16+5
 EOR XX16+3             \       = the sign of v_y * XX16+5
 STA S                  \
                        \ So because we set this above:
                        \
                        \   (XX16+5 K) = |v_y| * sin(CNT2)
                        \
                        \ and we just set R = K, we now have this:
                        \
                        \   (S R) = v_y * sin(CNT2)

 LDA K+2                \ Set P = K+2 = |u_y| * cos(CNT2)
 STA P

 LDA XX16+4             \ Set A = the sign of XX16+1 * XX16+4
 EOR XX16+1             \       = the sign of u_y * XX16+4
                        \
                        \ So because we set this above:
                        \
                        \   (XX16+4 K+2) = |u_y| * cos(CNT2)
                        \
                        \ and we just set P = K+2, we now have this:
                        \
                        \   (A P) = u_y * cos(CNT2)

 JSR ADD                \ Set (A X) = (A P) + (S R)
                        \           =  u_y * cos(CNT2) + v_y * sin(CNT2)

 EOR #%10000000         \ Store the negated high byte in T, so the result is
 STA T                  \ now:
                        \
                        \   (T X) = - u_y * cos(CNT2) - v_y * sin(CNT2)
                        \
                        \ This negation is necessary because BLINE expects us
                        \ to pass pixel coordinates, where y-coordinates get
                        \ larger as we go down the screen; u_y and v_y, on the
                        \ other hand, are extracted from the orientation
                        \ vectors, where y-coordinates get larger as we go up
                        \ in space, so to rectify this we need to negate the
                        \ result in (T X) before we can add it to the
                        \ y-coordinate of the ellipse's centre in BLINE

 BPL PL43               \ If the result is positive, jump down to PL43

 TXA                    \ The result is negative, so we need to negate the
 EOR #%11111111         \ magnitude using two's complement, first doing the low
 CLC                    \ byte in X
 ADC #1
 TAX

 LDA T                  \ And then the high byte in T, making sure to leave the
 EOR #%01111111         \ sign bit alone
 ADC #0
 STA T

.PL43

                        \ We now call BLINE to draw the ellipse line segment
                        \
                        \ The first few instructions of BLINE do the following:
                        \
                        \   K6(3 2) = K4(1 0) + (T X)
                        \
                        \ which gives:
                        \
                        \   K6(3 2) = K4(1 0) - u_y * cos(CNT2)
                        \                     - v_y * sin(CNT2)
                        \
                        \ K4(1 0) is the pixel y-coordinate of the centre of the
                        \ ellipse, so this gives us the correct y-coordinate for
                        \ our ellipse segment (we already calculated the
                        \ x-coordinate in K3(1 0) above)

 JSR BLINE              \ Call BLINE to draw this segment, which also returns
                        \ the updated value of CNT in A

 CMP TGT                \ If CNT > TGT then jump to PL40 to stop drawing the
 BEQ P%+4               \ ellipse (which is how we draw half-ellipses)
 BCS PL40

 LDA CNT2               \ Set CNT2 = (CNT2 + STP) mod 64
 CLC
 ADC STP
 AND #63
 STA CNT2

 JMP PLL4               \ Jump back to PLL4 to draw the next segment

.PL40

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: SUN (Part 1 of 4)
\       Type: Subroutine
\   Category: Drawing suns
\    Summary: Draw the sun: Set up all the variables needed to draw the sun
\  Deep dive: Drawing the sun
\
\ ------------------------------------------------------------------------------
\
\ Draw a new sun with radius K at pixel coordinate (K3, K4), removing the old
\ sun if there is one. This routine is used to draw the sun, as well as the
\ star systems on the Short-range Chart.
\
\ The first part sets up all the variables needed to draw the new sun.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   K                   The new sun's radius
\
\   K3(1 0)             Pixel x-coordinate of the centre of the new sun
\
\   K4(1 0)             Pixel y-coordinate of the centre of the new sun
\
\   SUNX(1 0)           The x-coordinate of the vertical centre axis of the old
\                       sun (the one currently on-screen)
\
\ ******************************************************************************

.PLF3M3

 JMP WPLS               \ Jump to WPLS to remove the old sun from the screen. We
                        \ only get here via the BCS just after the SUN entry
                        \ point below, when there is no new sun to draw

.PLF3

                        \ This is called from below to negate X and set A to
                        \ &FF, for when the new sun's centre is off the bottom
                        \ of the screen (so we don't need to draw its bottom
                        \ half)
                        \
                        \ This happens when the y-coordinate of the centre of
                        \ the sun is bigger than the y-coordinate of the bottom
                        \ of the space view

 TXA                    \ Negate X using two's complement, so X = ~X + 1
 EOR #%11111111
 CLC
 ADC #1
 TAX

.PLF17

                        \ This is called from below to set A to &FF, for when
                        \ the new sun's centre is right on the bottom of the
                        \ screen (so we don't need to draw its bottom half)

 LDA #&FF               \ Set A = &FF

 BNE PLF5               \ Jump to PLF5 (this BNE is effectively a JMP as A is
                        \ never zero)

.SUN

 LDA #RED               \ Switch to colour 2, which is red in the space view
 STA COL

 LDA #1                 \ Set LSX = 1 to indicate the sun line heap is about to
 STA LSX                \ be filled up

 JSR CHKON              \ Call CHKON to check whether any part of the new sun's
                        \ circle appears on-screen, and if it does, set P(2 1)
                        \ to the maximum y-coordinate of the new sun on-screen

 BCS PLF3M3             \ If CHKON set the C flag then the new sun's circle does
 JSR H_SUN              \ Port: in record mode, record the sun for the renderer
                        \ (gfx-hooks.asm)
                        \ not appear on-screen, so jump to WPLS (via the JMP at
                        \ the top of this routine) to remove the sun from the
                        \ screen, returning from the subroutine using a tail
                        \ call

 LDA #0                 \ Set A = 0

 LDX K                  \ Set X = K = radius of the new sun

 CPX #96                \ If X >= 96, set the C flag and rotate it into bit 0
 ROL A                  \ of A, otherwise rotate a 0 into bit 0

 CPX #40                \ If X >= 40, set the C flag and rotate it into bit 0
 ROL A                  \ of A, otherwise rotate a 0 into bit 0

 CPX #16                \ If X >= 16, set the C flag and rotate it into bit 0
 ROL A                  \ of A, otherwise rotate a 0 into bit 0

                        \ By now, A contains the following:
                        \
                        \   * If radius is 96-255 then A = %111 = 7
                        \
                        \   * If radius is 40-95  then A = %11  = 3
                        \
                        \   * If radius is 16-39  then A = %1   = 1
                        \
                        \   * If radius is 0-15   then A = %0   = 0
                        \
                        \ The value of A determines the size of the new sun's
                        \ ragged fringes - the bigger the sun, the bigger the
                        \ fringes

.PLF18

 STA CNT                \ Store the fringe size in CNT

                        \ We now calculate the highest pixel y-coordinate of the
                        \ new sun, given that P(2 1) contains the 16-bit maximum
                        \ y-coordinate of the new sun on-screen

 LDA Yx2M1              \ Set Y to the y-coordinate of the bottom of the space
                        \ view

 LDX P+2                \ If P+2 is non-zero, the maximum y-coordinate is off
 BNE PLF2               \ the bottom of the screen, so skip to PLF2 with A set
                        \ to the y-coordinate of the bottom of the space view

 CMP P+1                \ If A < P+1, the maximum y-coordinate is underneath the
 BCC PLF2               \ dashboard, so skip to PLF2 with A set to the
                        \ y-coordinate of the bottom of the space view

 LDA P+1                \ Set A = P+1, the low byte of the maximum y-coordinate
                        \ of the sun on-screen

 BNE PLF2               \ If A is non-zero, skip to PLF2 as it contains the
                        \ value we are after

 LDA #1                 \ Otherwise set A = 1, the top line of the screen

.PLF2

 STA TGT                \ Set TGT to A, the maximum y-coordinate of the sun on
                        \ screen

                        \ We now calculate the number of lines we need to draw
                        \ and the direction in which we need to draw them, both
                        \ from the centre of the new sun

 LDA Yx2M1              \ Set (A X) = y-coordinate of bottom of screen - K4(1 0)
 SEC                    \
 SBC K4                 \ Starting with the low bytes
 TAX

 LDA #0                 \ And then doing the high bytes, so (A X) now contains
 SBC K4+1               \ the number of lines between the centre of the sun and
                        \ the bottom of the screen. If it is positive then the
                        \ centre of the sun is above the bottom of the screen,
                        \ if it is negative then the centre of the sun is below
                        \ the bottom of the screen

 BMI PLF3               \ If A < 0, then this means the new sun's centre is off
                        \ the bottom of the screen, so jump up to PLF3 to negate
                        \ the height in X (so it becomes positive), set A to &FF
                        \ and jump down to PLF5

 BNE PLF4               \ If A > 0, then the new sun's centre is at least a full
                        \ screen above the bottom of the space view, so jump
                        \ down to PLF4 to set X = radius and A = 0

 INX                    \ Set the flags depending on the value of X
 DEX

 BEQ PLF17              \ If X = 0 (we already know A = 0 by this point) then
                        \ jump up to PLF17 to set A to &FF before jumping down
                        \ to PLF5

 CPX K                  \ If X < the radius in K, jump down to PLF5, so if
 BCC PLF5               \ X >= the radius in K, we set X = radius and A = 0

.PLF4

 LDX K                  \ Set X to the radius

 LDA #0                 \ Set A = 0

.PLF5

 STX V                  \ Store the height in V

 STA V+1                \ Store the direction in V+1

 LDA K                  \ Set (A P) = K * K
 JSR SQUA2

 STA K2+1               \ Set K2(1 0) = (A P) = K * K
 LDA P
 STA K2

                        \ By the time we get here, the variables should be set
                        \ up as shown in the header for part 3 below

\ ******************************************************************************
\
\       Name: SUN (Part 2 of 4)
\       Type: Subroutine
\   Category: Drawing suns
\    Summary: Draw the sun: Start from the bottom of the screen and erase the
\             old sun line by line
\  Deep dive: Drawing the sun
\
\ ------------------------------------------------------------------------------
\
\ This part erases the old sun, starting at the bottom of the screen and working
\ upwards until we reach the bottom of the new sun.
\
\ ******************************************************************************

 LDY Yx2M1              \ Set Y = y-coordinate of the bottom of the screen,
                        \ which we use as a counter in the following routine to
                        \ redraw the old sun

 LDA SUNX               \ Set YY(1 0) = SUNX(1 0), the x-coordinate of the
 STA YY                 \ vertical centre axis of the old sun that's currently
 LDA SUNX+1             \ on-screen
 STA YY+1

.PLFL2

 CPY TGT                \ If Y = TGT, we have reached the line where we will
 BEQ PLFL               \ start drawing the new sun, so there is no need to
                        \ keep erasing the old one, so jump down to PLFL

 LDA LSO,Y              \ Fetch the Y-th point from the sun line heap, which
                        \ gives us the half-width of the old sun's line on this
                        \ line of the screen

 BEQ PLF13              \ If A = 0, skip the following call to HLOIN2 as there
                        \ is no sun line on this line of the screen

 JSR HLOIN2             \ Call HLOIN2 to draw a horizontal line on pixel line Y,
                        \ with centre point YY(1 0) and half-width A, and remove
                        \ the line from the sun line heap once done

.PLF13

 DEY                    \ Decrement the loop counter

 BNE PLFL2              \ Loop back for the next line in the line heap until
                        \ we have either gone through the entire heap, or
                        \ reached the bottom row of the new sun

\ ******************************************************************************
\
\       Name: SUN (Part 3 of 4)
\       Type: Subroutine
\   Category: Drawing suns
\    Summary: Draw the sun: Continue to move up the screen, drawing the new sun
\             line by line
\  Deep dive: Drawing the sun
\
\ ------------------------------------------------------------------------------
\
\ This part draws the new sun. By the time we get to this point, the following
\ variables should have been set up by parts 1 and 2:
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   V                   As we draw lines for the new sun, V contains the
\                       vertical distance between the line we're drawing and the
\                       centre of the new sun. As we draw lines and move up the
\                       screen, we either decrement (bottom half) or increment
\                       (top half) this value
\
\   V+1                 This determines which half of the new sun we are drawing
\                       as we work our way up the screen, line by line:
\
\                         * 0 means we are drawing the bottom half, so the lines
\                           get wider as we work our way up towards the centre,
\                           at which point we will move into the top half, and
\                           V+1 will switch to &FF
\
\                         * &FF means we are drawing the top half, so the lines
\                           get smaller as we work our way up, away from the
\                           centre
\
\   TGT                 The maximum y-coordinate of the new sun on-screen (i.e.
\                       the screen y-coordinate of the bottom row of the new
\                       sun)
\
\   CNT                 The fringe size of the new sun
\
\   K2(1 0)             The new sun's radius squared, i.e. K^2
\
\   Y                   The y-coordinate of the bottom row of the new sun
\
\ ******************************************************************************

.PLFL

 LDA V                  \ Set (T P) = V * V
 JSR SQUA2              \           = V^2
 STA T

 LDA K2                 \ Set (R Q) = K^2 - V^2
 SEC                    \
 SBC P                  \ First calculating the low bytes
 STA Q

 LDA K2+1               \ And then doing the high bytes
 SBC T
 STA R

 STY Y1                 \ Store Y in Y1, so we can restore it after the call to
                        \ LL5

 JSR LL5                \ Set Q = SQRT(R Q)
                        \       = SQRT(K^2 - V^2)
                        \
                        \ So Q contains the half-width of the new sun's line at
                        \ height V from the sun's centre - in other words, it
                        \ contains the half-width of the sun's line on the
                        \ current pixel row Y

 LDY Y1                 \ Restore Y from Y1

 JSR DORND              \ Set A and X to random numbers

 AND CNT                \ Reduce A to a random number in the range 0 to CNT,
                        \ where CNT is the fringe size of the new sun

 CLC                    \ Set A = A + Q
 ADC Q                  \
                        \ So A now contains the half-width of the sun on row
                        \ V, plus a random variation based on the fringe size

 BCC PLF44              \ If the above addition did not overflow, skip the
                        \ following instruction

 LDA #255               \ The above overflowed, so set the value of A to 255

                        \ So A contains the half-width of the new sun on pixel
                        \ line Y, changed by a random amount within the size of
                        \ the sun's fringe

.PLF44

 LDX LSO,Y              \ Set X to the line heap value for the old sun's line
                        \ at row Y

 STA LSO,Y              \ Store the half-width of the new row Y line in the line
                        \ heap

 BEQ PLF11              \ If X = 0 then there was no sun line on pixel row Y, so
                        \ jump to PLF11

 LDA SUNX               \ Set YY(1 0) = SUNX(1 0), the x-coordinate of the
 STA YY                 \ vertical centre axis of the old sun that's currently
 LDA SUNX+1             \ on-screen
 STA YY+1

 TXA                    \ Transfer the line heap value for the old sun's line
                        \ from X into A

 JSR EDGES              \ Call EDGES to calculate X1 and X2 for the horizontal
                        \ line centred on YY(1 0) and with half-width A, i.e.
                        \ the line for the old sun

 LDA X1                 \ Store X1 and X2, the ends of the line for the old sun,
 STA XX                 \ in XX and XX+1
 LDA X2
 STA XX+1

 LDA K3                 \ Set YY(1 0) = K3(1 0), the x-coordinate of the centre
 STA YY                 \ of the new sun
 LDA K3+1
 STA YY+1

 LDA LSO,Y              \ Fetch the half-width of the new row Y line from the
                        \ line heap (which we stored above)

 JSR EDGES              \ Call EDGES to calculate X1 and X2 for the horizontal
                        \ line centred on YY(1 0) and with half-width A, i.e.
                        \ the line for the new sun

 BCS PLF23              \ If the C flag is set, the new line doesn't fit on the
                        \ screen, so jump to PLF23 to just draw the old line
                        \ without drawing the new one

                        \ At this point the old line is from XX to XX+1 and the
                        \ new line is from X1 to X2, and both fit on-screen. We
                        \ now want to remove the old line and draw the new one.
                        \ We could do this by simply drawing the old one then
                        \ drawing the new one, but instead Elite does this by
                        \ drawing first from X1 to XX and then from X2 to XX+1,
                        \ which you can see in action by looking at all the
                        \ permutations below of the four points on the line and
                        \ imagining what happens if you draw from X1 to XX and
                        \ X2 to XX+1 using EOR logic. The six possible
                        \ permutations are as follows, along with the result of
                        \ drawing X1 to XX and then X2 to XX+1:
                        \
                        \   X1    X2    XX____XX+1      ->      +__+  +  +
                        \
                        \   X1    XX____X2____XX+1      ->      +__+__+  +
                        \
                        \   X1    XX____XX+1  X2        ->      +__+__+__+
                        \
                        \   XX____X1____XX+1  X2        ->      +  +__+__+
                        \
                        \   XX____XX+1  X1    X2        ->      +  +  +__+
                        \
                        \   XX____X1____X2____XX+1      ->      +  +__+  +
                        \
                        \ They all end up with a line between X1 and X2, which
                        \ is what we want. There's probably a mathematical proof
                        \ of why this works somewhere, but the above is probably
                        \ easier to follow.
                        \
                        \ We can draw from X1 to XX and X2 to XX+1 by swapping
                        \ XX and X2 and drawing from X1 to X2, and then drawing
                        \ from XX to XX+1, so let's do this now

 LDA X2                 \ Swap XX and X2
 LDX XX
 STX X2
 STA XX

 JSR HLOIN              \ Draw a horizontal line from (X1, Y1) to (X2, Y1)

.PLF23

                        \ If we jump here from the BCS above when there is no
                        \ new line this will just draw the old line

 LDA XX                 \ Set X1 = XX
 STA X1

 LDA XX+1               \ Set X2 = XX+1
 STA X2

.PLF16

 JSR HLOIN              \ Draw a horizontal line from (X1, Y1) to (X2, Y1)

.PLF6

 DEY                    \ Decrement the line number in Y to move to the line
                        \ above

 BEQ PLF8               \ If we have reached the top of the screen, jump to PLF8
                        \ as we are done drawing (the top line of the screen is
                        \ the border, so we don't draw there)

 LDA V+1                \ If V+1 is non-zero then we are doing the top half of
 BNE PLF10              \ the new sun, so jump down to PLF10 to increment V and
                        \ decrease the width of the line we draw

 DEC V                  \ Decrement V, the height of the sun that we use to work
                        \ out the width, so this makes the line get wider, as we
                        \ move up towards the sun's centre

 BNE PLFL               \ If V is non-zero, jump back up to PLFL to do the next
                        \ screen line up

 DEC V+1                \ Otherwise V is 0 and we have reached the centre of the
                        \ sun, so decrement V+1 to -1 so we start incrementing V
                        \ each time, thus doing the top half of the new sun

.PLFLS

 JMP PLFL               \ Jump back up to PLFL to do the next screen line up

.PLF11

                        \ If we get here then there is no old sun line on this
                        \ line, so we can just draw the new sun's line

 LDX K3                 \ Set YY(1 0) = K3(1 0), the x-coordinate of the centre
 STX YY                 \ of the new sun's line
 LDX K3+1
 STX YY+1

 JSR EDGES              \ Call EDGES to calculate X1 and X2 for the horizontal
                        \ line centred on YY(1 0) and with half-width A, i.e.
                        \ the line for the new sun

 BCC PLF16              \ If the line is on-screen, jump up to PLF16 to draw the
                        \ line and loop round for the next line up

 LDA #0                 \ The line is not on-screen, so set the line heap for
 STA LSO,Y              \ line Y to 0, which means there is no sun line here

 BEQ PLF6               \ Jump up to PLF6 to loop round for the next line up
                        \ (this BEQ is effectively a JMP as A is always zero)

.PLF10

 LDX V                  \ Increment V, the height of the sun that we use to work
 INX                    \ out the width, so this makes the line get narrower, as
 STX V                  \ we move up and away from the sun's centre

 CPX K                  \ If V <= the radius of the sun, we still have lines to
 BCC PLFLS              \ draw, so jump up to PLFL (via PLFLS) to do the next
 BEQ PLFLS              \ screen line up

\ ******************************************************************************
\
\       Name: SUN (Part 4 of 4)
\       Type: Subroutine
\   Category: Drawing suns
\    Summary: Draw the sun: Continue to the top of the screen, erasing the old
\             sun line by line
\  Deep dive: Drawing the sun
\
\ ------------------------------------------------------------------------------
\
\ This part erases any remaining traces of the old sun, now that we have drawn
\ all the way to the top of the new sun.
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   RTS2                Contains an RTS
\
\ ******************************************************************************

 LDA SUNX               \ Set YY(1 0) = SUNX(1 0), the x-coordinate of the
 STA YY                 \ vertical centre axis of the old sun that's currently
 LDA SUNX+1             \ on-screen
 STA YY+1

.PLFL3

 LDA LSO,Y              \ Fetch the Y-th point from the sun line heap, which
                        \ gives us the half-width of the old sun's line on this
                        \ line of the screen

 BEQ PLF9               \ If A = 0, skip the following call to HLOIN2 as there
                        \ is no sun line on this line of the screen

 JSR HLOIN2             \ Call HLOIN2 to draw a horizontal line on pixel line Y,
                        \ with centre point YY(1 0) and half-width A, and remove
                        \ the line from the sun line heap once done

.PLF9

 DEY                    \ Decrement the line number in Y to move to the line
                        \ above

 BNE PLFL3              \ Jump up to PLFL3 to redraw the next line up, until we
                        \ have reached the top of the screen

.PLF8

                        \ If we get here, we have successfully made it from the
                        \ bottom line of the screen to the top, and the old sun
                        \ has been replaced by the new one

 CLC                    \ Clear the C flag to indicate success in drawing the
                        \ sun

 LDA K3                 \ Set SUNX(1 0) = K3(1 0)
 STA SUNX
 LDA K3+1
 STA SUNX+1

.RTS2

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: CIRCLE
\       Type: Subroutine
\   Category: Drawing circles
\    Summary: Draw a circle for the planet
\  Deep dive: Drawing circles
\
\ ------------------------------------------------------------------------------
\
\ Draw a circle with the centre at (K3, K4) and radius K. Used to draw the
\ planet's main outline.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   K                   The planet's radius
\
\   K3(1 0)             Pixel x-coordinate of the centre of the planet
\
\   K4(1 0)             Pixel y-coordinate of the centre of the planet
\
\ ******************************************************************************

.CIRCLE

 JSR H_CIRC             \ Port: in record mode, record the planet's disc for the
                        \ renderer and return (gfx-hooks.asm)

 JSR CHKON              \ Call CHKON to check whether the circle fits on-screen

 BCS RTS2               \ If CHKON set the C flag then the circle does not fit
                        \ on-screen, so return from the subroutine (as RTS2
                        \ contains an RTS)

 LDA #0                 \ Set LSX2 = 0 to indicate that the ball line heap is
 STA LSX2               \ not empty, as we are about to fill it

 LDX K                  \ Set X = K = radius

 LDA #8                 \ Set A = 8

 CPX #8                 \ If the radius < 8, skip to PL89
 BCC PL89

 LSR A                  \ Halve A so A = 4

 CPX #60                \ If the radius < 60, skip to PL89
 BCC PL89

 LSR A                  \ Halve A so A = 2

.PL89

 STA STP                \ Set STP = A. STP is the step size for the circle, so
                        \ the above sets a smaller step size for bigger circles

                        \ Fall through into CIRCLE2 to draw the circle with the
                        \ correct step size

\ ******************************************************************************
\
\       Name: CIRCLE2
\       Type: Subroutine
\   Category: Drawing circles
\    Summary: Draw a circle (for the planet or chart)
\  Deep dive: Drawing circles
\
\ ------------------------------------------------------------------------------
\
\ Draw a circle with the centre at (K3, K4) and radius K. Used to draw the
\ planet and the chart circles.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   STP                 The step size for the circle
\
\   K                   The circle's radius
\
\   K3(1 0)             Pixel x-coordinate of the centre of the circle
\
\   K4(1 0)             Pixel y-coordinate of the centre of the circle
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              The C flag is cleared
\
\ ******************************************************************************

.CIRCLE2

 LDX #&FF               \ Set FLAG = &FF to reset the ball line heap in the call
 STX FLAG               \ to the BLINE routine below

 INX                    \ Set CNT = 0, our counter that goes up to 64, counting
 STX CNT                \ segments in our circle

.PLL3

 LDA CNT                \ Set A = CNT

 JSR FMLTU2             \ Call FMLTU2 to calculate:
                        \
                        \   A = K * sin(A)
                        \     = K * sin(CNT)

 LDX #0                 \ Set T = 0, so we have the following:
 STX T                  \
                        \   (T A) = K * sin(CNT)
                        \
                        \ which is the x-coordinate of the circle for this count

 LDX CNT                \ If CNT < 33 then jump to PL37, as this is the right
 CPX #33                \ half of the circle and the sign of the x-coordinate is
 BCC PL37               \ correct

 EOR #%11111111         \ This is the left half of the circle, so we want to
 ADC #0                 \ flip the sign of the x-coordinate in (T A) using two's
 TAX                    \ complement, so we start with the low byte and store it
                        \ in X (the ADC adds 1 as we know the C flag is set)

 LDA #&FF               \ And then we flip the high byte in T
 ADC #0
 STA T

 TXA                    \ Finally, we restore the low byte from X, so we have
                        \ now negated the x-coordinate in (T A)

 CLC                    \ Clear the C flag so we can do some more addition below

.PL37

 ADC K3                 \ We now calculate the following:
 STA K6                 \
                        \   K6(1 0) = (T A) + K3(1 0)
                        \
                        \ to add the coordinates of the centre to our circle
                        \ point, starting with the low bytes

 LDA K3+1               \ And then doing the high bytes, so we now have:
 ADC T                  \
 STA K6+1               \   K6(1 0) = K * sin(CNT) + K3(1 0)
                        \
                        \ which is the result we want for the x-coordinate

 LDA CNT                \ Set A = CNT + 16
 CLC
 ADC #16

 JSR FMLTU2             \ Call FMLTU2 to calculate:
                        \
                        \   A = K * sin(A)
                        \     = K * sin(CNT + 16)
                        \     = K * cos(CNT)

 TAX                    \ Set X = A
                        \       = K * cos(CNT)

 LDA #0                 \ Set T = 0, so we have the following:
 STA T                  \
                        \   (T X) = K * cos(CNT)
                        \
                        \ which is the y-coordinate of the circle for this count

 LDA CNT                \ Set A = (CNT + 15) mod 64
 ADC #15
 AND #63

 CMP #33                \ If A < 33 (i.e. CNT is 0-16 or 48-64) then jump to
 BCC PL38               \ PL38, as this is the bottom half of the circle and the
                        \ sign of the y-coordinate is correct

 TXA                    \ This is the top half of the circle, so we want to
 EOR #%11111111         \ flip the sign of the y-coordinate in (T X) using two's
 ADC #0                 \ complement, so we start with the low byte in X (the
 TAX                    \ ADC adds 1 as we know the C flag is set)

 LDA #&FF               \ And then we flip the high byte in T, so we have
 ADC #0                 \ now negated the y-coordinate in (T X)
 STA T

 CLC                    \ Clear the C flag so the addition at the start of BLINE
                        \ will work

.PL38

 JSR BLINE              \ Call BLINE to draw this segment, which also increases
                        \ CNT by STP, the step size

 CMP #65                \ If CNT >= 65 then skip the next instruction
 BCS P%+5

 JMP PLL3               \ Jump back for the next segment

 CLC                    \ Clear the C flag to indicate success

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: WPLS2
\       Type: Subroutine
\   Category: Drawing planets
\    Summary: Remove the planet from the screen
\  Deep dive: The ball line heap
\
\ ------------------------------------------------------------------------------
\
\ We do this by redrawing it using the lines stored in the ball line heap when
\ the planet was originally drawn by the BLINE routine.
\
\ ******************************************************************************

.WPLS2

 JSR H_WPLS2            \ Port: in record mode there are no lines to erase
                        \ (gfx-hooks.asm)

 LDY LSX2               \ If LSX2 is non-zero (which indicates the ball line
 BNE WP1                \ heap is empty), jump to WP1 to reset the line heap
                        \ without redrawing the planet

                        \ Otherwise Y is now 0, so we can use it as a counter to
                        \ loop through the lines in the line heap, redrawing
                        \ each one to remove the planet from the screen, before
                        \ resetting the line heap once we are done

.WPL1

 CPY LSP                \ If Y >= LSP then we have reached the end of the line
 BCS WP1                \ heap and have finished redrawing the planet (as LSP
                        \ points to the end of the heap), so jump to WP1 to
                        \ reset the line heap, returning from the subroutine
                        \ using a tail call

 LDA LSY2,Y             \ Set A to the y-coordinate of the current heap entry

 CMP #&FF               \ If the y-coordinate is &FF, this indicates that the
 BEQ WP2                \ next point in the heap denotes the start of a line
                        \ segment, so jump to WP2 to put it into (X1, Y1)

 STA Y2                 \ Set (X2, Y2) to the x- and y-coordinates from the
 LDA LSX2,Y             \ heap
 STA X2

 JSR LOIN               \ Draw a line from (X1, Y1) to (X2, Y2)

 INY                    \ Increment the loop counter to point to the next point

 LDA SWAP               \ If SWAP is non-zero then we swapped the coordinates
 BNE WPL1               \ when filling the heap in BLINE, so loop back WPL1
                        \ for the next point in the heap

 LDA X2                 \ Swap (X1, Y1) and (X2, Y2), so the next segment will
 STA X1                 \ be drawn from the current (X2, Y2) to the next point
 LDA Y2                 \ in the heap
 STA Y1

 JMP WPL1               \ Loop back to WPL1 for the next point in the heap

.WP2

 INY                    \ Increment the loop counter to point to the next point

 LDA LSX2,Y             \ Set (X1, Y1) to the x- and y-coordinates from the
 STA X1                 \ heap
 LDA LSY2,Y
 STA Y1

 INY                    \ Increment the loop counter to point to the next point

 JMP WPL1               \ Loop back to WPL1 for the next point in the heap

\ ******************************************************************************
\
\       Name: WP1
\       Type: Subroutine
\   Category: Drawing planets
\    Summary: Reset the ball line heap
\
\ ******************************************************************************

.WP1

 LDA #1                 \ Set LSP = 1 to reset the ball line heap pointer
 STA LSP

 LDA #&FF               \ Set LSX2 = &FF to indicate the ball line heap is empty
 STA LSX2

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: WPLS
\       Type: Subroutine
\   Category: Drawing suns
\    Summary: Remove the sun from the screen
\  Deep dive: Drawing the sun
\
\ ------------------------------------------------------------------------------
\
\ We do this by redrawing it using the lines stored in the sun line heap when
\ the sun was originally drawn by the SUN routine.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   SUNX(1 0)           The x-coordinate of the vertical centre axis of the sun
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   WPLS-1              Contains an RTS
\
\ ******************************************************************************

.WPLS

 LDA LSX                \ If LSX < 0, the sun line heap is empty, so return from
 BMI WPLS-1             \ the subroutine (as WPLS-1 contains an RTS)

 LDA SUNX               \ Set YY(1 0) = SUNX(1 0), the x-coordinate of the
 STA YY                 \ vertical centre axis of the sun that's currently on
 LDA SUNX+1             \ screen
 STA YY+1

 LDY #2*Y-1             \ #Y is the y-coordinate of the centre of the space
                        \ view, so this sets Y as a counter for the number of
                        \ lines in the space view (i.e. 191), which is also the
                        \ number of lines in the LSO block

.WPL2

 LDA LSO,Y              \ Fetch the Y-th point from the sun line heap, which
                        \ gives us the half-width of the sun's line on this line
                        \ of the screen

 BEQ P%+5               \ If A = 0, skip the following call to HLOIN2 as there
                        \ is no sun line on this line of the screen

 JSR HLOIN2             \ Call HLOIN2 to draw a horizontal line on pixel line Y,
                        \ with centre point YY(1 0) and half-width A, and remove
                        \ the line from the sun line heap once done

 DEY                    \ Decrement the loop counter

 BNE WPL2               \ Loop back for the next line in the line heap until
                        \ we have gone through the entire heap

 DEY                    \ This sets Y to &FF, as we end the loop with Y = 0

 STY LSX                \ Set LSX to &FF to indicate the sun line heap is empty

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: EDGES
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw a horizontal line given a centre and a half-width
\
\ ------------------------------------------------------------------------------
\
\ Set X1 and X2 to the x-coordinates of the ends of the horizontal line with
\ centre x-coordinate YY(1 0), and length A in either direction from the centre
\ (so a total line length of 2 * A). In other words, this line:
\
\   X1             YY(1 0)             X2
\   +-----------------+-----------------+
\         <- A ->           <- A ->
\
\ The resulting line gets clipped to the edges of the screen, if needed. If the
\ calculation doesn't overflow, we return with the C flag clear, otherwise the C
\ flag gets set to indicate failure and the Y-th LSO entry gets set to 0.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The half-length of the line
\
\   YY(1 0)             The centre x-coordinate
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              Clear if the line fits on-screen, set if it doesn't
\
\   X1, X2              The x-coordinates of the clipped line
\
\   LSO+Y               If the line doesn't fit, LSO+Y is set to 0
\
\   Y                   Y is preserved
\
\ ******************************************************************************

.EDGES

 STA T                  \ Set T to the line's half-length in argument A

 CLC                    \ We now calculate:
 ADC YY                 \
 STA X2                 \  (A X2) = YY(1 0) + A
                        \
                        \ to set X2 to the x-coordinate of the right end of the
                        \ line, starting with the low bytes

 LDA YY+1               \ And then adding the high bytes
 ADC #0

 BMI ED1                \ If the addition is negative then the calculation has
                        \ overflowed, so jump to ED1 to return a failure

 BEQ P%+6               \ If the high byte A from the result is 0, skip the
                        \ next two instructions, as the result already fits on
                        \ the screen

 LDA #255               \ The high byte is positive and non-zero, so we went
 STA X2                 \ past the right edge of the screen, so clip X2 to the
                        \ x-coordinate of the right edge of the screen

 LDA YY                 \ We now calculate:
 SEC                    \
 SBC T                  \   (A X1) = YY(1 0) - argument A
 STA X1                 \
                        \ to set X1 to the x-coordinate of the left end of the
                        \ line, starting with the low bytes

 LDA YY+1               \ And then subtracting the high bytes
 SBC #0

 BNE ED3                \ If the high byte subtraction is non-zero, then skip
                        \ to ED3

 CLC                    \ Otherwise the high byte of the subtraction was zero,
                        \ so the line fits on-screen and we clear the C flag to
                        \ indicate success

 RTS                    \ Return from the subroutine

.ED3

 BPL ED1                \ If the addition is positive then the calculation has
                        \ underflowed, so jump to ED1 to return a failure

 LDA #0                 \ The high byte is negative and non-zero, so we went
 STA X1                 \ past the left edge of the screen, so clip X1 to the
                        \ x-coordinate of the left edge of the screen

 CLC                    \ The line does fit on-screen, so clear the C flag to
                        \ indicate success

 RTS                    \ Return from the subroutine

.ED1

 LDA #0                 \ Set the Y-th byte of the LSO block to 0
 STA LSO,Y

 SEC                    \ The line does not fit on the screen, so set the C flag
                        \ to indicate this result

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: CHKON
\       Type: Subroutine
\   Category: Drawing circles
\    Summary: Check whether any part of a circle appears on the extended screen
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   K                   The circle's radius
\
\   K3(1 0)             Pixel x-coordinate of the centre of the circle
\
\   K4(1 0)             Pixel y-coordinate of the centre of the circle
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              Clear if any part of the circle appears on-screen, set
\                       if none of the circle appears on-screen
\
\   (A X)               Minimum y-coordinate of the circle on-screen (i.e. the
\                       y-coordinate of the top edge of the circle)
\
\   P(2 1)              Maximum y-coordinate of the circle on-screen (i.e. the
\                       y-coordinate of the bottom edge of the circle)
\
\ ******************************************************************************

.CHKON

 LDA K3                 \ Set A = K3 + K
 CLC
 ADC K

 LDA K3+1               \ Set A = K3+1 + 0 + any carry from above, so this
 ADC #0                 \ effectively sets A to the high byte of K3(1 0) + K:
                        \
                        \   (A ?) = K3(1 0) + K
                        \
                        \ so A is the high byte of the x-coordinate of the right
                        \ edge of the circle

 BMI PL21               \ If A is negative then the right edge of the circle is
                        \ to the left of the screen, so jump to PL21 to set the
                        \ C flag and return from the subroutine, as the whole
                        \ circle is off-screen to the left

 LDA K3                 \ Set A = K3 - K
 SEC
 SBC K

 LDA K3+1               \ Set A = K3+1 - 0 - any carry from above, so this
 SBC #0                 \ effectively sets A to the high byte of K3(1 0) - K:
                        \
                        \   (A ?) = K3(1 0) - K
                        \
                        \ so A is the high byte of the x-coordinate of the left
                        \ edge of the circle

 BMI PL31               \ If A is negative then the left edge of the circle is
                        \ to the left of the screen, and we already know the
                        \ right edge is either on-screen or off-screen to the
                        \ right, so skip to PL31 to move on to the y-coordinate
                        \ checks, as at least part of the circle is on-screen in
                        \ terms of the x-axis

 BNE PL21               \ If A is non-zero, then the left edge of the circle is
                        \ to the right of the screen, so jump to PL21 to set the
                        \ C flag and return from the subroutine, as the whole
                        \ circle is off-screen to the right

.PL31

 LDA K4                 \ Set P+1 = K4 + K
 CLC
 ADC K
 STA P+1

 LDA K4+1               \ Set A = K4+1 + 0 + any carry from above, so this
 ADC #0                 \ does the following:
                        \
                        \   (A P+1) = K4(1 0) + K
                        \
                        \ so A is the high byte of the y-coordinate of the
                        \ bottom edge of the circle

 BMI PL21               \ If A is negative then the bottom edge of the circle is
                        \ above the top of the screen, so jump to PL21 to set
                        \ the C flag and return from the subroutine, as the
                        \ whole circle is off-screen to the top

 STA P+2                \ Store the high byte in P+2, so now we have:
                        \
                        \   P(2 1) = K4(1 0) + K
                        \
                        \ i.e. the maximum y-coordinate of the circle on-screen
                        \ (which we return)

 LDA K4                 \ Set X = K4 - K
 SEC
 SBC K
 TAX

 LDA K4+1               \ Set A = K4+1 - 0 - any carry from above, so this
 SBC #0                 \ does the following:
                        \
                        \   (A X) = K4(1 0) - K
                        \
                        \ so A is the high byte of the y-coordinate of the top
                        \ edge of the circle

 BMI PL44               \ If A is negative then the top edge of the circle is
                        \ above the top of the screen, and we already know the
                        \ bottom edge is either on-screen or below the bottom
                        \ of the screen, so skip to PL44 to clear the C flag and
                        \ return from the subroutine using a tail call, as part
                        \ of the circle definitely appears on-screen

 BNE PL21               \ If A is non-zero, then the top edge of the circle is
                        \ below the bottom of the screen, so jump to PL21 to set
                        \ the C flag and return from the subroutine, as the
                        \ whole circle is off-screen to the bottom

 CPX Yx2M1              \ If we get here then A is zero, which means the top
                        \ edge of the circle is within the screen boundary, so
                        \ now we need to check whether it is in the space view
                        \ (in which case it is on-screen) or the dashboard (in
                        \ which case the top of the circle is hidden by the
                        \ dashboard, so the circle isn't on-screen). We do this
                        \ by checking the low byte of the result in X against
                        \ Yx2M1, and returning the C flag from this comparison.
                        \ The value in Yx2M1 is the y-coordinate of the bottom
                        \ pixel row of the space view, so this does the
                        \ following:
                        \
                        \   * The C flag is set if coordinate (A X) is below the
                        \     bottom row of the space view, i.e. the top edge of
                        \     the circle is hidden by the dashboard
                        \
                        \   * The C flag is clear if coordinate (A X) is above
                        \     the bottom row of the space view, i.e. the top
                        \     edge of the circle is on-screen

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: PL21
\       Type: Subroutine
\   Category: Drawing planets
\    Summary: Return from a planet/sun-drawing routine with a failure flag
\
\ ------------------------------------------------------------------------------
\
\ Set the C flag and return from the subroutine. This is used to return from a
\ planet- or sun-drawing routine with the C flag indicating an overflow in the
\ calculation.
\
\ ******************************************************************************

.PL21

 SEC                    \ Set the C flag to indicate an overflow

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: PLS3
\       Type: Subroutine
\   Category: Drawing planets
\    Summary: Calculate (Y A P) = 222 * roofv_x / z
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following, with X determining the vector to use:
\
\   (Y A P) = 222 * roofv_x / z
\
\ though in reality only (Y A) is used.
\
\ Although the code below supports a range of values of X, in practice the
\ routine is only called with X = 15, and then again after X has been
\ incremented to 17. So the values calculated by PLS1 use roofv_x first, then
\ roofv_y. The comments below refer to roofv_x, for the first call.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   Determines which of the INWK orientation vectors to
\                       divide:
\
\                         * X = 15: divides roofv_x
\
\                         * X = 17: divides roofv_y
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   X                   X gets incremented by 2 so it points to the next
\                       coordinate in this orientation vector (so consecutive
\                       calls to the routine will start with x, then move onto y
\                       and then z)
\
\ ******************************************************************************

.PLS3

 JSR PLS1               \ Call PLS1 to calculate the following:
 STA P                  \
                        \   P = |roofv_x / z|
                        \   K+3 = sign of roofv_x / z
                        \
                        \ and increment X to point to roofv_y for the next call

 LDA #222               \ Set Q = 222, the offset to the crater
 STA Q

 STX U                  \ Store the vector index X in U for retrieval after the
                        \ call to MULTU

 JSR MULTU              \ Call MULTU to calculate
                        \
                        \   (A P) = P * Q
                        \         = 222 * |roofv_x / z|

 LDX U                  \ Restore the vector index from U into X

 LDY K+3                \ If the sign of the result in K+3 is positive, skip to
 BPL PL12               \ PL12 to return with Y = 0

 EOR #&FF               \ Otherwise the result should be negative, so negate the
 CLC                    \ high byte of the result using two's complement with
 ADC #1                 \ A = ~A + 1

 BEQ PL12               \ If A = 0, jump to PL12 to return with (Y A) = 0

 LDY #&FF               \ Set Y = &FF to be a negative high byte

 RTS                    \ Return from the subroutine

.PL12

 LDY #0                 \ Set Y = 0 to be a positive high byte

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: PLS4
\       Type: Subroutine
\   Category: Drawing planets
\    Summary: Calculate CNT2 = arctan(P / A) / 4
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following:
\
\   CNT2 = arctan(P / A) / 4
\
\ and do the following if nosev_z_hi >= 0:
\
\   CNT2 = CNT2 + 32
\
\ which is the equivalent of adding 180 degrees to the result (or PI radians),
\ as there are 64 segments in a full circle.
\
\ This routine is called with the following arguments when calculating the
\ equator and meridian for planets:
\
\   * A = roofv_z_hi, P = -nosev_z_hi
\
\   * A = sidev_z_hi, P = -nosev_z_hi
\
\ So it calculates the angle between the planet's orientation vectors, in the
\ z-axis.
\
\ ******************************************************************************

.PLS4

 STA Q                  \ Set Q = A

 JSR ARCTAN             \ Call ARCTAN to calculate:
                        \
                        \   A = arctan(P / Q)
                        \       arctan(P / A)
                        \
                        \ The result in A will be in the range 0 to 128, which
                        \ represents an angle of 0 to 180 degrees (or 0 to PI
                        \ radians)

 LDX INWK+14            \ If nosev_z_hi is negative, skip the following
 BMI P%+4               \ instruction to leave the angle in A as a positive
                        \ integer in the range 0 to 128 (so when we calculate
                        \ CNT2 below, it will be in the right half of the
                        \ anti-clockwise arc that we describe when drawing
                        \ circles, i.e. from 6 o'clock, through 3 o'clock and
                        \ on to 12 o'clock)

 EOR #%10000000         \ If we get here then nosev_z_hi is positive, so flip
                        \ bit 7 of the angle in A, which is the same as adding
                        \ 128 to give a result in the range 129 to 256 (i.e. 129
                        \ to 0), or 180 to 360 degrees (so when we calculate
                        \ CNT2 below, it will be in the left half of the
                        \ anti-clockwise arc that we describe when drawing
                        \ circles, i.e. from 12 o'clock, through 9 o'clock and
                        \ on to 6 o'clock)

 LSR A                  \ Set CNT2 = A / 4
 LSR A
 STA CNT2

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: PLS5
\       Type: Subroutine
\   Category: Drawing planets
\    Summary: Calculate roofv_x / z and roofv_y / z
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following divisions of a specified value from one of the
\ orientation vectors (in this example, roofv):
\
\   (XX16+2 K2+2) = roofv_x / z
\
\   (XX16+3 K2+3) = roofv_y / z
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   Determines which of the INWK orientation vectors to
\                       divide:
\
\                         * X = 15: divides roofv_x and roofv_y
\
\                         * X = 21: divides sidev_x and sidev_y
\
\   INWK                The planet's ship data block
\
\ ******************************************************************************

.PLS5

 JSR PLS1               \ Call PLS1 to calculate the following:
 STA K2+2               \
 STY XX16+2             \   K+2    = |roofv_x / z|
                        \   XX16+2 = sign of roofv_x / z
                        \
                        \ i.e. (XX16+2 K2+2) = roofv_x / z
                        \
                        \ and increment X to point to roofv_y for the next call

 JSR PLS1               \ Call PLS1 to calculate the following:
 STA K2+3               \
 STY XX16+3             \   K+3    = |roofv_y / z|
                        \   XX16+3 = sign of roofv_y / z
                        \
                        \ i.e. (XX16+3 K2+3) = roofv_y / z
                        \
                        \ and increment X to point to roofv_z for the next call

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: PLS6
\       Type: Subroutine
\   Category: Drawing planets
\    Summary: Calculate (X K) = (A P+1 P) / (z_sign z_hi z_lo)
\
\ ------------------------------------------------------------------------------
\
\ Calculate the following:
\
\   (X K) = (A P+1 P) / (z_sign z_hi z_lo)
\
\ returning an overflow in the C flag if the result is >= 1024.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   INWK                The planet or sun's ship data block
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              Set if the result >= 1024, clear otherwise
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   PL44                Clear the C flag and return from the subroutine
\
\   PL6                 Contains an RTS
\
\ ******************************************************************************

.PLS6

 JSR DVID3B2            \ Call DVID3B2 to calculate:
                        \
                        \   K(3 2 1 0) = (A P+1 P) / (z_sign z_hi z_lo)

 LDA K+3                \ Set A = |K+3| OR K+2
 AND #%01111111
 ORA K+2

 BNE PL21               \ If A is non-zero then the two high bytes of K(3 2 1 0)
                        \ are non-zero, so jump to PL21 to set the C flag and
                        \ return from the subroutine

                        \ We can now just consider K(1 0), as we know the top
                        \ two bytes of K(3 2 1 0) are both 0

 LDX K+1                \ Set X = K+1, so now (X K) contains the result in
                        \ K(1 0), which is the format we want to return the
                        \ result in

 CPX #4                 \ If the high byte of K(1 0) >= 4 then the result is
 BCS PL6                \ >= 1024, so return from the subroutine with the C flag
                        \ set to indicate an overflow (as PL6 contains an RTS)

 LDA K+3                \ Fetch the sign of the result from K+3 (which we know
                        \ has zeroes in bits 0-6, so this just fetches the sign)

\CLC                    \ This instruction is commented out in the original
                        \ source. It would have no effect as we know the C flag
                        \ is already clear, as we skipped past the BCS above

 BPL PL6                \ If the sign bit is clear and the result is positive,
                        \ then the result is already correct, so return from
                        \ the subroutine with the C flag clear to indicate
                        \ success (as PL6 contains an RTS)

 LDA K                  \ Otherwise we need to negate the result, which we do
 EOR #%11111111         \ using two's complement, starting with the low byte:
 ADC #1                 \
 STA K                  \   K = ~K + 1

 TXA                    \ And then the high byte:
 EOR #%11111111         \
 ADC #0                 \   X = ~X
 TAX

.PL44

 CLC                    \ Clear the C flag to indicate success

.PL6

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TT17
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Scan the keyboard for cursor key or joystick movement
\
\ ------------------------------------------------------------------------------
\
\ Scan the keyboard and joystick for cursor key or stick movement, and return
\ the result as deltas (changes) in x- and y-coordinates as follows:
\
\   * For joystick, X and Y are integers between -2 and +2 depending on how far
\     the stick has moved
\
\   * For keyboard, X and Y are integers between -1 and +1 depending on which
\     keys are pressed
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   The key pressed, if the arrow keys were used
\
\   X                   Change in the x-coordinate according to the cursor keys
\                       being pressed or joystick movement, as an integer (see
\                       above)
\
\   Y                   Change in the y-coordinate according to the cursor keys
\                       being pressed or joystick movement, as an integer (see
\                       above)
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   TJ1                 Check for cursor key presses and return the combined
\                       deltas for the digital joystick and cursor keys (Master
\                       Compact only)
\
\ ******************************************************************************

.TT17

 LDA QQ11               \ If this not the space view, skip the following three
 BNE TT17afterall       \ instructions to move onto the cursor key logic

 JSR DOKEY              \ This is the space view, so scan the keyboard for
                        \ flight controls and pause keys, (or the equivalent on
                        \ joystick) and update the key logger, setting KL to the
                        \ key pressed

 TXA                    \ Transfer the value of the key pressed from X to A

 RTS                    \ Return from the subroutine

.TT17afterall

 JSR DOKEY              \ Scan the keyboard for flight controls and pause keys,
                        \ (or the equivalent on joystick) and update the key
                        \ logger, setting KL to the key pressed

IF _COMPACT

 LDX #0                 \ Set the initial values for the results, X = Y = 0,
 LDY #0                 \ which we now increase or decrease appropriately

ENDIF

 LDA JSTK               \ If the joystick is not configured, jump down to TJ1,
 BEQ TJ1                \ otherwise we move the cursor with the joystick

IF _COMPACT

 LDA MOS                \ If MOS = 0 then this is a Master Compact, so jump to
 BEQ DJOY               \ DJOY to read the digital joystick before rejoining the
                        \ routine below at TJ1

ENDIF

 LDA JSTY               \ Fetch the joystick pitch, ranging from 1 to 255 with
                        \ 128 as the centre point

 JSR TJS1               \ Call TJS1 just below to set A to a value between -4
                        \ and +4 depending on the joystick pitch value (moving
                        \ the stick up and down)

 TAY                    \ Copy the result into Y

 LDA JSTX               \ Fetch the joystick roll, ranging from 1 to 255 with
                        \ 128 as the centre point

 EOR #&FF               \ Flip the sign so A = -JSTX, because the joystick roll
                        \ works in the opposite way to moving a cursor on-screen
                        \ in terms of left and right

 JSR TJS1               \ Call TJS1 just below to set A to a value between -4
                        \ and +4 depending on the joystick roll value (moving
                        \ the stick sideways)

 TAX                    \ Copy the value of A into X

IF _SNG47

 LDA KL                 \ Set A to the value of KL (the key pressed)

 RTS                    \ Return from the subroutine

ENDIF

.TJ1

 LDA KL                 \ Set A to the value of KL (the key pressed)

IF _SNG47

 LDX #0                 \ Set the results, X = Y = 0
 LDY #0

ENDIF

 CMP #&8C               \ If left arrow was pressed, set X = X - 1
 BNE P%+3
 DEX

 CMP #&8D               \ If right arrow was pressed, set X = X + 1
 BNE P%+3
 INX

 CMP #&8E               \ If down arrow was pressed, set Y = Y - 1
 BNE P%+3
 DEY

 CMP #&8F               \ If up arrow was pressed, set Y = Y + 1
 BNE P%+3
 INY

 PHX                    \ Store X (which contains the change in the
                        \ x-coordinate) on the stack so we can retrieve it later

IF _SNG47

 LDA #0                 \ Call DKS5 to check whether the SHIFT key is being
 JSR DKS5               \ pressed

ELIF _COMPACT

 LDA #0                 \ Call DKS4mc to check whether the SHIFT key is being
 JSR DKS4mc             \ pressed

ENDIF

 BMI speedup            \ If SHIFT is being pressed, skip the next three
                        \ instructions

 PLX                    \ SHIFT is not being pressed, so retrieve the value of X
                        \ we stored above so we can return it

 LDA KL                 \ Set A to the value of KL (the key pressed)

 RTS                    \ Return from the subroutine

.speedup

 PLA                    \ Pull the value of X from the stack into A, so A now
                        \ contains the change in the x-coordinate

 ASL A                  \ SHIFT is being held down, so quadruple the value of A
 ASL A                  \ (i.e. SHIFT moves the cursor at four times the speed
                        \ when using the joystick)

 TAX                    \ Put the amended value of A back into X

 TYA                    \ Now to do the same with the change in y-coordinate, so
                        \ fetch the value of Y into A

 ASL A                  \ SHIFT is being held down, so quadruple the value of A
 ASL A                  \ (i.e. SHIFT moves the cursor at four times the speed
                        \ when using the joystick)

 TAY                    \ Put the amended value of A back into Y

IF _COMPACT

 STZ KY7                \ Clear the key logger at KY7 to reset the "A" (fire)
                        \ button to "not pressed"

ENDIF

 LDA KL                 \ Set A to the value of KL (the key pressed)

 RTS                    \ Return from the subroutine

.TJS1

                        \ This routine calculates the following:
                        \
                        \   A = round(A / 16) - 4
                        \
                        \ This sets A to a value between -4 and +4, given an
                        \ initial value ranging from 1 to 255 with 128 as
                        \ the centre point

 LSR A                  \ Set A = A / 16
 LSR A                  \
 LSR A                  \ and C contains the last bit to be shifted out
 LSR A
 LSR A

 ADC #0                 \ If that last bit was a 1, this increments A, so
                        \ this effectively implements a rounding function,
                        \ where 0.5 and above get rounded up

 SBC #3                 \ The addition will not overflow, so the C flag is
                        \ clear at this point, so this performs:
                        \
                        \   A = A - 3 - (1 - C)
                        \     = A - 3 - (1 - 0)
                        \     = A - 3 - 1
                        \     = A - 4

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\ Save ELTE.bin
\
\ ******************************************************************************

 PRINT "ELITE E"
 PRINT "Assembled at ", ~CODE_E%
 PRINT "Ends at ", ~P%
 PRINT "Code size is ", ~(P% - CODE_E%)
 PRINT "Execute at ", ~LOAD%
 PRINT "Reload at ", ~LOAD_E%

 PRINT "S.ELTE ", ~CODE_E%, " ", ~P%, " ", ~LOAD%, " ", ~LOAD_E%
\SAVE "build/ELTE.bin", CODE_E%, P%, LOAD%

\ ******************************************************************************
\
\ ELITE F FILE
\
\ ******************************************************************************

 CODE_F% = P%

 LOAD_F% = LOAD% + P% - CODE%

\ ******************************************************************************
\
\       Name: DJOY
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Scan the keyboard for cursor key or digital joystick movement
\
\ ******************************************************************************

IF _COMPACT

.DJOY

 JSR TT17X              \ Call TT17X to read the digital joystick and return
                        \ deltas as appropriate

 JMP TJ1                \ Jump to TJ1 in the TT17 routine to check for cursor
                        \ key presses and return the combined deltas for the
                        \ digital joystick and cursor keys, returning from the
                        \ subroutine using a tail call

ENDIF

\ ******************************************************************************
\
\       Name: KS3
\       Type: Subroutine
\   Category: Universe
\    Summary: Set the SLSP ship line heap pointer after shuffling ship slots
\
\ ------------------------------------------------------------------------------
\
\ The final part of the KILLSHP routine, called after we have shuffled the ship
\ slots and sorted out our missiles. This simply sets SLSP to the new bottom of
\ the ship line heap.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   P(1 0)              Points to the ship line heap of the ship in the last
\                       occupied slot (i.e. it points to the bottom of the
\                       descending heap)
\
\ ******************************************************************************

.KS3

 LDA P                  \ After shuffling the ship slots, P(1 0) will point to
 STA SLSP               \ the new bottom of the ship line heap, so store this in
 LDA P+1                \ SLSP(1 0), which stores the bottom of the heap
 STA SLSP+1

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: KS1
\       Type: Subroutine
\   Category: Universe
\    Summary: Remove the current ship from our local bubble of universe
\
\ ------------------------------------------------------------------------------
\
\ Part 12 of the main flight loop calls this routine to remove the ship that is
\ currently being analysed by the flight loop. Once the ship is removed, it
\ jumps back to MAL1 to rejoin the main flight loop, with X pointing to the
\ same slot that we just cleared (and which now contains the next ship in the
\ local bubble of universe).
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   XX0                 The address of the blueprint for this ship
\
\   INF                 The address of the data block for this ship
\
\ ******************************************************************************

.KS1

 LDX XSAV               \ Fetch the current ship's slot number from XSAV

 JSR KILLSHP            \ Call KILLSHP to remove the ship in slot X from our
                        \ local bubble of universe

 LDX XSAV               \ Restore the current ship's slot number from XSAV,
                        \ which now points to the next ship in the bubble

 JMP MAL1               \ Jump to MAL1 to rejoin the main flight loop at the
                        \ start of the ship analysis loop

\ ******************************************************************************
\
\       Name: KS4
\       Type: Subroutine
\   Category: Universe
\    Summary: Remove the space station and replace it with the sun
\
\ ******************************************************************************

.KS4

 JSR ZINF               \ Call ZINF to reset the INWK ship workspace

 JSR FLFLLS             \ Reset the LSO block, returns with A = 0

 STA FRIN+1             \ Set the second slot in the FRIN table to 0, which
                        \ sets this slot to empty, so when we call NWSHP below
                        \ the new sun that gets created will go into FRIN+1

 STA SSPR               \ Set the "space station present" flag to 0, as we are
                        \ no longer in the space station's safe zone

 JSR SPBLB              \ Call SPBLB to redraw the space station bulb, which
                        \ will erase it from the dashboard

 LDA #6                 \ Set the sun's y_sign to 6
 STA INWK+5

 LDA #129               \ Set A = 129, the ship type for the sun

 JMP NWSHP              \ Call NWSHP to set up the sun's data block and add it
                        \ to FRIN, where it will get put in the second slot as
                        \ we just cleared out the second slot, and the first
                        \ slot is already taken by the planet

\ ******************************************************************************
\
\       Name: KS2
\       Type: Subroutine
\   Category: Universe
\    Summary: Check the local bubble for missiles with target lock
\
\ ------------------------------------------------------------------------------
\
\ Check the local bubble of universe to see if there are any missiles with
\ target lock in the vicinity. If there are, then check their targets; if we
\ just removed their target in the KILLSHP routine, then switch off their AI so
\ they just drift in space, otherwise update their targets to reflect the newly
\ shuffled slot numbers.
\
\ This is called from KILLSHP once the slots have been shuffled down, following
\ the removal of a ship.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   XX4                 The slot number of the ship we removed just before
\                       calling this routine
\
\ ******************************************************************************

.KS2

 LDX #&FF               \ We want to go through the ships in our local bubble
                        \ and pick out all the missiles, so set X to &FF to
                        \ use as a counter

.KSL4

 INX                    \ Increment the counter (so it starts at 0 on the first
                        \ iteration)

 LDA FRIN,X             \ If slot X is empty then we have worked our way through
 BEQ KS3                \ all the slots, so jump to KS3 to stop looking

 CMP #MSL               \ If the slot does not contain a missile, loop back to
 BNE KSL4               \ KSL4 to check the next slot

                        \ We have found a slot containing a missile, so now we
                        \ want to check whether it has target lock

 TXA                    \ Set Y = X * 2 and fetch the Y-th address from UNIV
 ASL A                  \ and store it in SC and SC+1 - in other words, set
 TAY                    \ SC(1 0) to point to the missile's ship data block
 LDA UNIV,Y
 STA SC
 LDA UNIV+1,Y
 STA SC+1

 LDY #32                \ Fetch byte #32 from the missile's ship data (AI)
 LDA (SC),Y

 BPL KSL4               \ If bit 7 of byte #32 is clear, then the missile is
                        \ dumb and has no AI, so loop back to KSL4 to move on
                        \ to the next slot

 AND #%01111111         \ Otherwise this missile has AI, so clear bit 7 and
 LSR A                  \ shift right to set the C flag to the missile's "is
                        \ locked" flag, and A to the target's slot number

 CMP XX4                \ If this missile's target is less than XX4, then the
 BCC KSL4               \ target's slot isn't being shuffled down, so jump to
                        \ KSL4 to move on to the next slot

 BEQ KS6                \ If this missile was locked onto the ship that we just
                        \ removed in KILLSHP, jump to KS6 to stop the missile
                        \ from continuing to hunt it down

 SBC #1                 \ Otherwise this missile is locked and has AI enabled,
                        \ and its target will have moved down a slot, so
                        \ subtract 1 from the target number (we know C is set
                        \ from the BCC above)

 ASL A                  \ Shift the target number left by 1, so it's in bits
                        \ 1-6 once again, and also set bit 0 to 1, as the C
                        \ flag is still set, so this makes sure the missile is
                        \ still set to being locked

 ORA #%10000000         \ Set bit 7, so the missile's AI is enabled

 STA (SC),Y             \ Update the missile's AI flag to the value in A

 BNE KSL4               \ Loop back to KSL4 to move on to the next slot (this
                        \ BNE is effectively a JMP as A will never be zero)

.KS6

 LDA #0                 \ The missile's target lock just got removed, so set the
 STA (SC),Y             \ AI flag to 0 to make it dumb and not locked

 BEQ KSL4               \ Loop back to KSL4 to move on to the next slot (this
                        \ BEQ is effectively a JMP as A is always zero)

\ ******************************************************************************
\
\       Name: KILLSHP
\       Type: Subroutine
\   Category: Universe
\    Summary: Remove a ship from our local bubble of universe
\
\ ------------------------------------------------------------------------------
\
\ Remove the ship in slot X from our local bubble of universe. This happens
\ when we kill a ship, collide with a ship and destroy it, or when a ship moves
\ outside our local bubble.
\
\ We also use this routine when we move out of range of the space station, in
\ which case we replace it with the sun.
\
\ When removing a ship, this creates a gap in the ship slots at FRIN, so we
\ shuffle all the later slots down to close the gap. We also shuffle the ship
\ data blocks at K% and ship line heap at WP, to reclaim all the memory that
\ the removed ship used to occupy.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The slot number of the ship to remove
\
\   XX0                 The address of the blueprint for the ship to remove
\
\   INF                 The address of the data block for the ship to remove
\
\ ******************************************************************************

.KILLSHP

 STX XX4                \ Store the slot number of the ship to remove in XX4

 LDA MSTG               \ Check whether this slot matches the slot number in
 CMP XX4                \ MSTG, which is the target of our missile lock

 BNE KS5                \ If our missile is not locked on this ship, jump to KS5

 LDY #GREEN2            \ Otherwise we need to remove our missile lock, so call
 JSR ABORT              \ ABORT to unarm the missile and update the missile
                        \ indicators on the dashboard to green (Y = #GREEN2)

 LDA #200               \ Print recursive token 40 ("TARGET LOST") as an
 JSR MESS               \ in-flight message

.KS5

 LDY XX4                \ Restore the slot number of the ship to remove into Y

 LDX FRIN,Y             \ Fetch the contents of the slot, which contains the
                        \ ship type

 CPX #SST               \ If this is the space station, then jump to KS4 to
 BEQ KS4                \ replace the space station with the sun

 CPX #CON               \ Did we just kill the Constrictor from mission 1? If
 BNE lll                \ not, jump to lll

 LDA TP                 \ We just killed the Constrictor from mission 1, so set
 ORA #%00000010         \ bit 1 of TP to indicate that we have successfully
 STA TP                 \ completed mission 1

 INC TALLY+1            \ Award 256 kill points for killing the Constrictor

.lll

 CPX #HER               \ Did we just kill a rock hermit? If we did, jump to
 BEQ blacksuspenders    \ blacksuspenders to decrease the junk count

 CPX #JL                \ If JL <= X < JH, i.e. the type of ship we killed in X
 BCC KS7                \ is junk (escape pod, alloy plate, cargo canister,
 CPX #JH                \ asteroid, splinter, Shuttle or Transporter), then keep
 BCS KS7                \ going, otherwise jump to KS7

.blacksuspenders

 DEC JUNK               \ We just killed junk, so decrease the junk counter

.KS7

 DEC MANY,X             \ Decrease the number of this type of ship in our little
                        \ bubble, which is stored in MANY+X (where X is the ship
                        \ type)

 LDX XX4                \ Restore the slot number of the ship to remove into X

                        \ We now want to remove this ship and reclaim all the
                        \ memory that it uses. Removing the ship will leave a
                        \ gap in three places, which we need to close up:
                        \
                        \   * The ship slots in FRIN
                        \
                        \   * The ship data blocks in K%
                        \
                        \   * The descending ship line heap at WP down
                        \
                        \ The rest of this routine closes up these gaps by
                        \ looping through all the occupied ship slots after the
                        \ slot we are removing, one by one, and shuffling each
                        \ ship's slot, data block and line heap down to close
                        \ up the gaps left by the removed ship. As part of this,
                        \ we have to make sure we update any address pointers
                        \ so they point to the newly shuffled data blocks and
                        \ line heaps
                        \
                        \ In the following, when shuffling a ship's data down
                        \ into the preceding empty slot, we call the ship that
                        \ we are shuffling down the "source", and we call the
                        \ empty slot we are shuffling it into the "destination"
                        \
                        \ Before we start looping through the ships we need to
                        \ shuffle down, we need to set up some variables to
                        \ point to the source and destination line heaps

 LDY #5                 \ Fetch byte #5 of the removed ship's blueprint into A,
 LDA (XX0),Y            \ which gives the ship's maximum heap size for the ship
                        \ we are removing (i.e. the size of the gap in the heap
                        \ created by the ship removal)

                        \ INF currently contains the ship data for the ship we
                        \ are removing, and INF(34 33) contains the address of
                        \ the bottom of the ship's heap, so we can calculate
                        \ the address of the top of the heap by adding the heap
                        \ size to this address

 LDY #33                \ First we add A and the address in INF+33, to get the
 CLC                    \ low byte of the top of the heap, which we store in P
 ADC (INF),Y
 STA P

 INY                    \ And next we add A and the address in INF+34, with any
 LDA (INF),Y            \ carry from the previous addition, to get the high byte
 ADC #0                 \ of the top of the heap, which we store in P+1, so
 STA P+1                \ P(1 0) points to the top of this ship's heap

                        \ Now, we're ready to start looping through the ships
                        \ we want to move, moving the slots, data blocks and
                        \ line heap from the source to the destination. In the
                        \ following, we set up SC to point to the source data,
                        \ and INF (which currently points to the removed ship's
                        \ data that we can now overwrite) points to the
                        \ destination
                        \
                        \ So P(1 0) now points to the top of the line heap for
                        \ the destination

.KSL1

 INX                    \ On entry, X points to the empty slot we want to
                        \ shuffle the next ship into (the destination), so
                        \ this increment points X to the next slot - i.e. the
                        \ source slot we want to shuffle down

 LDA FRIN,X             \ Copy the contents of the source slot into the
 STA FRIN-1,X           \ destination slot

 BNE P%+5               \ If the slot we just shuffled down is not empty, then
                        \ skip the following instruction

 JMP KS2                \ The source slot is empty and we are done shuffling,
                        \ so jump to KS2 to move on to processing missiles

 ASL A                  \ Otherwise we have a source ship to shuffle down into
 TAY                    \ the destination, so set Y = A * 2 so it can act as an
                        \ index into the two-byte ship blueprint lookup table
                        \ at XX21 for the source ship

 LDA XX21-2,Y           \ Set SC(0 1) to point to the blueprint data for the
 STA SC                 \ source ship
 LDA XX21-1,Y
 STA SC+1

 LDY #5                 \ Fetch blueprint byte #5 for the source ship, which
 LDA (SC),Y             \ gives us its maximum heap size, and store it in T
 STA T

                        \ We now subtract T from P(1 0), so P(1 0) will point to
                        \ the bottom of the line heap for the destination
                        \ (which we will use later when closing up the gap in
                        \ the heap space)

 LDA P                  \ First, we subtract the low bytes
 SEC
 SBC T
 STA P

 LDA P+1                \ And then we do the high bytes, for which we subtract
 SBC #0                 \ 0 to include any carry, so this is effectively doing
 STA P+1                \ P(1 0) = P(1 0) - (0 T)

                        \ Next, we want to set SC(1 0) to point to the source
                        \ ship's data block

 TXA                    \ Set Y = X * 2 so it can act as an index into the
 ASL A                  \ two-byte lookup table at UNIV, which contains the
 TAY                    \ addresses of the ship data blocks. In this case we are
                        \ multiplying X by 2, and X contains the source ship's
                        \ slot number so Y is now an index for the source ship's
                        \ entry in UNIV

 LDA UNIV,Y             \ Set SC(1 0) to the address of the data block for the
 STA SC                 \ source ship
 LDA UNIV+1,Y
 STA SC+1

                        \ We have now set up our variables as follows:
                        \
                        \   SC(1 0) points to the source's ship data block
                        \
                        \   INF(1 0) points to the destination's ship data block
                        \
                        \   P(1 0) points to the destination's line heap
                        \
                        \ so let's start copying data from the source to the
                        \ destination

 LDY #36                \ We are going to be using Y as a counter for the 37
                        \ bytes of ship data we want to copy from the source
                        \ to the destination, so we set it to 36 to start things
                        \ off, and will decrement Y for each byte we copy

 LDA (SC),Y             \ Fetch byte #36 of the source's ship data block at SC,
 STA (INF),Y            \ and store it in byte #36 of the destination's block
 DEY                    \ at INF, so that's the ship's NEWB flags copied from
                        \ the source to the destination. One down, quite a few
                        \ to go...

 LDA (SC),Y             \ Fetch byte #35 of the source's ship data block at SC,
 STA (INF),Y            \ and store it in byte #35 of the destination's block
                        \ at INF, so that's the ship's energy copied from the
                        \ source to the destination

 DEY                    \ Fetch byte #34 of the source ship, which is the
 LDA (SC),Y             \ high byte of the source ship's line heap, and store
 STA K+1                \ in K+1

 LDA P+1                \ Set the low byte of the destination's heap pointer
 STA (INF),Y            \ to P+1

 DEY                    \ Fetch byte #33 of the source ship, which is the
 LDA (SC),Y             \ low byte of the source ship's heap, and store in K
 STA K                  \ so now we have the following:
                        \
                        \   K(1 0) points to the source's line heap

 LDA P                  \ Set the low byte of the destination's heap pointer
 STA (INF),Y            \ to P, so now the destination's heap pointer is to
                        \ P(1 0), so that's the heap pointer in bytes #33 and
                        \ #34 done

 DEY                    \ Luckily, we can just copy the rest of the source's
                        \ ship data block into the destination, as there are no
                        \ more address pointers, so first we decrement our
                        \ counter in Y to point to the next byte (the AI flag)
                        \ in byte #32) and then start looping

.KSL2

 LDA (SC),Y             \ Copy the Y-th byte of the source to the Y-th byte of
 STA (INF),Y            \ the destination

 DEY                    \ Decrement the counter

 BPL KSL2               \ Loop back to KSL2 to copy the next byte until we have
                        \ copied the whole block

                        \ We have now shuffled the ship's slot and the ship's
                        \ data block, so we only have the heap data itself to do

 LDA SC                 \ First, we copy SC into INF, so when we loop round
 STA INF                \ again, INF will correctly point to the destination for
 LDA SC+1               \ the next iteration
 STA INF+1

 LDY T                  \ Now we want to move the contents of the heap, as all
                        \ we did above was to update the pointers, so first
                        \ we set a counter in Y that is initially set to T
                        \ (which we set above to the maximum heap size for the
                        \ source ship)
                        \
                        \ As a reminder, we have already set the following:
                        \
                        \   K(1 0) points to the source's line heap
                        \
                        \   P(1 0) points to the destination's line heap
                        \
                        \ so we can move the heap data by simply copying the
                        \ correct number of bytes from K(1 0) to P(1 0)
.KSL3

 DEY                    \ Decrement the counter

 LDA (K),Y              \ Copy the Y-th byte of the source heap at K(1 0) to
 STA (P),Y              \ the destination heap at P(1 0)

 TYA                    \ Loop back to KSL3 to copy the next byte, until we
 BNE KSL3               \ have done them all

 BEQ KSL1               \ We have now shuffled everything down one slot, so
                        \ jump back up to KSL1 to see if there is another slot
                        \ that needs shuffling down (this BEQ is effectively a
                        \ JMP as A will always be zero)

\ ******************************************************************************
\
\       Name: THERE
\       Type: Subroutine
\   Category: Missions
\    Summary: Check whether we are in the Constrictor's system in mission 1
\
\ ------------------------------------------------------------------------------
\
\ The stolen Constrictor is the target of mission 1. We finally track it down to
\ the Orarra system in the second galaxy, which is at galactic coordinates
\ (144, 33). This routine checks whether we are in this system and sets the C
\ flag accordingly.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              Set if we are in the Constrictor system, otherwise clear
\
\ ******************************************************************************

.THERE

 LDX GCNT               \ Set X = GCNT - 1
 DEX

 BNE THEX               \ If X is non-zero (i.e. GCNT is not 1, so we are not in
                        \ the second galaxy), then jump to THEX

 LDA QQ0                \ Set A = the current system's galactic x-coordinate

 CMP #144               \ If A <> 144 then jump to THEX
 BNE THEX

 LDA QQ1                \ Set A = the current system's galactic y-coordinate

 CMP #33                \ If A = 33 then set the C flag

 BEQ THEX+1             \ If A = 33 then jump to THEX+1, so we return from the
                        \ subroutine with the C flag set (otherwise we clear the
                        \ C flag with the next instruction)

.THEX

 CLC                    \ Clear the C flag

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: NUMBOR
\       Type: Subroutine
\   Category: Text
\    Summary: An unused routine that prints a number in hexadecimal
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The number to print
\
\ ******************************************************************************

.NUMBOR

 PHA                    \ Store A on the stack so we can grab the low nibble
                        \ from it later

 LSR A                  \ Shift A right so that it contains the high nibble
 LSR A                  \ of the original argument
 LSR A
 LSR A

 JSR DIDGIT             \ Call DIDGIT below to print 0-F for the high nibble

 PLA                    \ Restore A from the stack

 AND #%00001111         \ Extract the low nibble and fall through into DIDGIT
                        \ to print 0-F for the low nibble

.DIDGIT

 CMP #10                \ If A >= 10, skip the next three instructions
 BCS P%+7

 ADC #'0'               \ A < 10, so print the number in A as a digit 0-9 and
 JMP CHPR               \ return from the subroutine using a tail call

.DIDGIT2

 ADC #'6'               \ A >= 10, so print the number in A as a digit A-F and
 JMP CHPR               \ return from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: ZINF
\       Type: Subroutine
\   Category: Universe
\    Summary: Reset the INWK workspace and orientation vectors
\  Deep dive: Orientation vectors
\
\ ------------------------------------------------------------------------------
\
\ Zero-fill the INWK ship workspace and reset the orientation vectors, with
\ nosev pointing out of the screen, towards us.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   Y                   Y is set to &FF
\
\ ******************************************************************************

.ZINF

 LDY #NI%-1             \ There are NI% bytes in the INWK workspace, so set a
                        \ counter in Y so we can loop through them

 LDA #0                 \ Set A to 0 so we can zero-fill the workspace

.ZI1

 STA INWK,Y             \ Zero the Y-th byte of the INWK workspace

 DEY                    \ Decrement the loop counter

 BPL ZI1                \ Loop back for the next byte, ending when we have
                        \ zero-filled the last byte at INWK, which leaves Y
                        \ with a value of &FF

                        \ Finally, we reset the orientation vectors as follows:
                        \
                        \   sidev = (1,  0,  0)
                        \   roofv = (0,  1,  0)
                        \   nosev = (0,  0, -1)
                        \
                        \ 96 * 256 (&6000) represents 1 in the orientation
                        \ vectors, while -96 * 256 (&E000) represents -1. We
                        \ already set the vectors to zero above, so we just
                        \ need to set up the high bytes of the diagonal values
                        \ and we're done. The negative nosev makes the ship
                        \ point towards us, as the z-axis points into the screen

 LDA #96                \ Set A to represent a 1 (in vector terms)

 STA INWK+18            \ Set byte #18 = roofv_y_hi = 96 = 1

 STA INWK+22            \ Set byte #22 = sidev_x_hi = 96 = 1

 ORA #%10000000         \ Flip the sign of A to represent a -1

 STA INWK+14            \ Set byte #14 = nosev_z_hi = -96 = -1

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: msblob
\       Type: Subroutine
\   Category: Dashboard
\    Summary: Display the dashboard's missile indicators in green
\
\ ------------------------------------------------------------------------------
\
\ Display the dashboard's missile indicators, with all the missiles reset to
\ green (i.e. not armed or locked).
\
\ ******************************************************************************

.msblob

 LDX #4                 \ Set up a loop counter in X to count through all four
                        \ missile indicators

.ss

 CPX NOMSL              \ If the counter is equal to the number of missiles,
 BEQ SAL8               \ jump down to SAL8 to draw the remaining missiles, as
                        \ the rest of them are present and should be drawn in
                        \ green

 LDY #0                 \ Draw the missile indicator at position X in black
 JSR MSBAR

 DEX                    \ Decrement the counter to point to the next missile

 BNE ss                 \ Loop back to ss if we still have missiles to draw

 RTS                    \ Return from the subroutine

.SAL8

 LDY #GREEN2            \ Draw the missile indicator at position X in green
 JSR MSBAR

 DEX                    \ Decrement the counter to point to the next missile

 BNE SAL8               \ Loop back to SAL8 if we still have missiles to draw

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: me2
\       Type: Subroutine
\   Category: Flight
\    Summary: Remove an in-flight message from the space view
\
\ ******************************************************************************

.me2

 LDA QQ11               \ If this is not the space view, jump down to clynsneed
 BNE clynsneed          \ to skip displaying the in-flight message

 LDA MCH                \ Fetch the token number of the current message into A

 JSR MESS               \ Call MESS to print the token, which will remove it
                        \ from the screen as printing uses EOR logic

 LDA #0                 \ Set the delay in DLY to 0, so any new in-flight
 STA DLY                \ messages will be shown instantly

 JMP me3                \ Jump back into the main spawning loop at me3

.clynsneed

 JSR CLYNS              \ Clear the bottom three text rows of the upper screen,
                        \ and move the text cursor to the first cleared row

 JMP me3                \ Jump back into the main spawning loop at me3

\ ******************************************************************************
\
\       Name: Ze
\       Type: Subroutine
\   Category: Universe
\    Summary: Initialise the INWK workspace to a fairly aggressive ship
\  Deep dive: Fixing ship positions
\             Aggression and hostility in ship tactics
\
\ ------------------------------------------------------------------------------
\
\ Specifically, this routine does the following:
\
\   * Reset the INWK ship workspace
\
\   * Set the ship to a fair distance away in all axes, in front of us but
\     randomly up or down, left or right
\
\   * Give the ship a 4% chance of having E.C.M.
\
\   * Set the ship's aggression level to at least 32 out of 63, with AI enabled
\
\ This routine also sets A, X, T1 and the C flag to random values.
\
\ Note that because this routine uses the value of X returned by DORND, and X
\ contains the value of A returned by the previous call to DORND, this routine
\ does not necessarily set the new ship to a totally random location.
\
\ ******************************************************************************

.Ze

 JSR ZINF               \ Call ZINF to reset the INWK ship workspace

 JSR DORND              \ Set A and X to random numbers

 STA T1                 \ Store A in T1

 AND #%10000000         \ Extract the sign of A and store in x_sign
 STA INWK+2

 TXA                    \ Extract the sign of X and store in y_sign
 AND #%10000000
 STA INWK+5

 LDA #25                \ Set x_hi = y_hi = z_hi = 25, a fair distance away
 STA INWK+1
 STA INWK+4
 STA INWK+7

 TXA                    \ Set the C flag if X >= 245 (4% chance)
 CMP #245

 ROL A                  \ Set bit 0 of A to the C flag (i.e. there's a 4%
                        \ chance of this ship having E.C.M.)

 ORA #%11000000         \ Set bits 6 and 7 of A, so the ship has AI (bit 7) and
                        \ an aggression level of at least 32 out of 63

 STA INWK+32            \ Store A in the AI flag of this ship

                        \ Fall through into DORND2 to set A, X and the C flag
                        \ randomly

\ ******************************************************************************
\
\       Name: DORND
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Generate random numbers
\  Deep dive: Generating random numbers
\             Fixing ship positions
\
\ ------------------------------------------------------------------------------
\
\ Set A and X to random numbers (though note that X is set to the random number
\ that was returned in A the last time DORND was called).
\
\ The C and V flags are also set randomly.
\
\ If we want to generate a repeatable sequence of random numbers, when
\ generating explosion clouds, for example, then we call DORND2 to ensure that
\ the value of the C flag on entry doesn't affect the outcome, as otherwise we
\ might not get the same sequence of numbers if the C flag changes.
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   DORND2              Make sure the C flag doesn't affect the outcome
\
\ ******************************************************************************

.DORND2

 CLC                    \ Clear the C flag so the value of the C flag on entry
                        \ doesn't affect the outcome

.DORND

 LDA RAND               \ Calculate the next two values f2 and f3 in the feeder
 ROL A                  \ sequence:
 TAX                    \
 ADC RAND+2             \   * f2 = (f1 << 1) mod 256 + C flag on entry
 STA RAND               \   * f3 = f0 + f2 + (1 if bit 7 of f1 is set)
 STX RAND+2             \   * C flag is set according to the f3 calculation

 LDA RAND+1             \ Calculate the next value m2 in the main sequence:
 TAX                    \
 ADC RAND+3             \   * A = m2 = m0 + m1 + C flag from feeder calculation
 STA RAND+1             \   * X = m1
 STX RAND+3             \   * C and V flags set according to the m2 calculation

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: Main game loop (Part 1 of 6)
\       Type: Subroutine
\   Category: Main loop
\    Summary: Spawn a trader (a Cobra Mk III, Python, Boa or Anaconda)
\  Deep dive: Program flow of the main game loop
\             Ship data blocks
\             Aggression and hostility in ship tactics
\
\ ------------------------------------------------------------------------------
\
\ This is part of the main game loop. This is where the core loop of the game
\ lives, and it's in two parts. The shorter loop (just parts 5 and 6) is
\ iterated when we are docked, while the entire loop from part 1 to 6 iterates
\ if we are in space.
\
\ This section covers the following:
\
\   * Spawn a trader, i.e. a Cobra Mk III, Python, Boa or Anaconda, with a 50%
\     chance of it having an E.C.M., a 50% chance of it docking, a random
\     aggression level, a speed between 16 and 31, and a gentle clockwise roll
\
\ We call this from within the main loop.
\
\ ******************************************************************************

.MTT4

 JSR DORND              \ Set A and X to random numbers

 LSR A                  \ Clear bit 7 of our random number in A and set the C
                        \ flag to bit 0 of A, which is random

 STA INWK+32            \ Store this in the ship's AI flag, so this ship does
                        \ not have AI

 STA INWK+29            \ Store A in the ship's roll counter, giving it a
                        \ clockwise roll (as bit 7 is clear), and a 1 in 127
                        \ chance of it having no damping

 ROL INWK+31            \ This instruction would appear to set bit 0 of the
                        \ ship's missile count randomly (as the C flag was set),
                        \ giving the ship either no missiles or one missile
                        \
                        \ However, INWK+31 is overwritten in the call to the
                        \ NWSHP routine below, where it is set to the number of
                        \ missiles from the ship blueprint, and the value of the
                        \ C flag is not used, so this instruction actually has
                        \ no effect
                        \
                        \ Interestingly, the original source code for the NWSPS
                        \ routine also has an instruction that sets INWK+31 and
                        \ which gets overwritten when it falls through into
                        \ NWSHP, but in this case the instruction is commented
                        \ out in the source. Perhaps the original version of
                        \ NWSHP didn't set the missile count and instead relied
                        \ on the calling code to set it, and when the authors
                        \ changed it, they commented out the INWK+31 instruction
                        \ in NWSPS and forgot about this one. Who knows?

 AND #31                \ Set the ship speed to our random number, set to a
 ORA #16                \ minimum of 16 and a maximum of 31
 STA INWK+27

 JSR DORND              \ Set A and X to random numbers, plus the C flag

 BMI nodo               \ If A is negative (50% chance), jump to nodo to skip
                        \ the following

                        \ If we get here then we are going to spawn a ship that
                        \ is minding its own business and trying to dock

 LDA INWK+32            \ Set bits 6 and 7 of A, so the ship has AI (bit 7) and
 ORA #%11000000         \ an aggression level of at least 32 out of 63 (this
 STA INWK+32            \ makes the ship more likely to turn towards its target,
                        \ which in this case is the space station, as we are
                        \ about to set the ship flags so it is docking)

 LDX #%00010000         \ Set bit 4 of the ship's NEWB flags, to indicate that
 STX NEWB               \ this ship is docking

.nodo

 AND #2                 \ This reduces A to a random value of either 0 or 2

 ADC #CYL               \ Set A = A + C + #CYL
                        \
                        \ where A is 0 or 2 and C is 0 or 1, so this gives us a
                        \ ship type from the following: Cobra Mk III, Python,
                        \ Boa or Anaconda

 CMP #HER               \ If A is now the ship type of a rock hermit, jump to
 BEQ TT100              \ TT100 to skip the following instruction

 JSR NWSHP              \ Add a new ship of type A to the local bubble and fall
                        \ through into the main game loop again

\ ******************************************************************************
\
\       Name: Main game loop (Part 2 of 6)
\       Type: Subroutine
\   Category: Main loop
\    Summary: Call the main flight loop, and potentially spawn a trader, an
\             asteroid, or a cargo canister
\  Deep dive: Program flow of the main game loop
\             Ship data blocks
\             Fixing ship positions
\
\ ------------------------------------------------------------------------------
\
\ This section covers the following:
\
\   * Call M% to do the main flight loop
\
\   * Potentially spawn a trader, asteroid or cargo canister
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   TT100               The entry point for the start of the main game loop,
\                       which calls the main flight loop and the moves into the
\                       spawning routine
\
\   me3                 Used by me2 to jump back into the main game loop after
\                       printing an in-flight message
\
\ ******************************************************************************

.TT100

 JSR H_MFRAME           \ Call M% to iterate through the main flight loop,
                        \ then render the frame (Port: the renderer,
                        \ gfx-hooks.asm)

 DEC DLY                \ Decrement the delay counter in DLY, so any in-flight
                        \ messages get removed once the counter reaches zero

 BEQ me2                \ If DLY is now 0, jump to me2 to remove any in-flight
                        \ message from the space view, and once done, return to
                        \ me3 below, skipping the following two instructions

 BPL me3                \ If DLY is positive, jump to me3 to skip the next
                        \ instruction

 INC DLY                \ If we get here, DLY is negative, so we have gone too
                        \ and need to increment DLY back to 0

.me3

 DEC MCNT               \ Decrement the main loop counter in MCNT

 BEQ P%+5               \ If the counter has reached zero, which it will do
                        \ every 256 main loops, skip the next JMP instruction
                        \ (or to put it another way, if the counter hasn't
                        \ reached zero, jump down to MLOOP, skipping all the
                        \ following checks)

.ytq

 JMP MLOOP              \ Jump down to MLOOP to do some end-of-loop tidying and
                        \ restart the main loop

                        \ We only get here once every 256 iterations of the
                        \ main loop. If we aren't in witchspace and don't
                        \ already have 3 or more asteroids in our local bubble,
                        \ then this section has a 13% chance of spawning
                        \ something benign (the other 87% of the time we jump
                        \ down to consider spawning cops, pirates and bounty
                        \ hunters)
                        \
                        \ If we are in that 13%, then 50% of the time this will
                        \ be a trader, and the other 50% of the time it will
                        \ either be an asteroid (98.5% chance) or, very rarely,
                        \ a cargo canister (1.5% chance)

 LDA MJ                 \ If we are in witchspace following a mis-jump, skip the
 BNE ytq                \ following by jumping down to MLOOP (via ytq above)

 JSR DORND              \ Set A and X to random numbers

 CMP #35                \ If A >= 35 (87% chance), jump down to MTT1 to skip
 BCS MTT1               \ the spawning of an asteroid or cargo canister and
                        \ potentially spawn something else

 LDA JUNK               \ If we already have 3 or more bits of junk in the local
 CMP #3                 \ bubble, jump down to MTT1 to skip the following and
 BCS MTT1               \ potentially spawn something else

 JSR ZINF               \ Call ZINF to reset the INWK ship workspace

 LDA #38                \ Set z_hi = 38 (far away)
 STA INWK+7

 JSR DORND              \ Set A, X and C flag to random numbers

 STA INWK               \ Set x_lo = random

 STX INWK+3             \ Set y_lo = random
                        \
                        \ Note that because we use the value of X returned by
                        \ DORND, and X contains the value of A returned by the
                        \ previous call to DORND, this does not set the new ship
                        \ to a totally random location

 AND #%10000000         \ Set x_sign = bit 7 of x_lo
 STA INWK+2

 TXA                    \ Set y_sign = bit 7 of y_lo
 AND #%10000000
 STA INWK+5

 ROL INWK+1             \ Set bit 1 of x_hi to the C flag, which is random, so
 ROL INWK+1             \ this randomly moves us off-centre by 512 (as if x_hi
                        \ is %00000010, then (x_hi x_lo) is 512 + x_lo)

 JSR DORND              \ Set A, X and V flag to random numbers

 BVS MTT4               \ If V flag is set (50% chance), jump up to MTT4 to
                        \ spawn a trader

 ORA #%01101111         \ Take the random number in A and set bits 0-3 and 5-6,
 STA INWK+29            \ so the result has a 50% chance of being positive or
                        \ negative, and a 50% chance of bits 0-6 being 127.
                        \ Storing this number in the roll counter therefore
                        \ gives our new ship a fast roll speed with a 50%
                        \ chance of having no damping, plus a 50% chance of
                        \ rolling clockwise or anti-clockwise

 LDA SSPR               \ If we are inside the space station safe zone, jump
 BNE MTT1               \ down to MTT1 to skip the following and potentially
                        \ spawn something else

 TXA                    \ Set A to the random X we set above, which we haven't
 BCS MTT2               \ used yet, and if the C flag is set (50% chance) jump
                        \ down to MTT2 to skip the following

 AND #31                \ Set the ship speed to our random number, set to a
 ORA #16                \ minimum of 16 and a maximum of 31
 STA INWK+27

 BCC MTT3               \ Jump down to MTT3, skipping the following (this BCC
                        \ is effectively a JMP as we know the C flag is clear,
                        \ having passed through the BCS above)

.MTT2

 ORA #%01111111         \ Set bits 0-6 of A to 127, leaving bit 7 as random, so
 STA INWK+30            \ storing this number in the pitch counter means we have
                        \ full pitch with no damping, with a 50% chance of
                        \ pitching up or down

.MTT3

 JSR DORND              \ Set A and X to random numbers

 CMP #252               \ If random A < 252 (98.8% of the time), jump to thongs
 BCC thongs             \ to skip the following

 LDA #HER               \ Set A to #HER so we spawn a rock hermit 1.2% of the
                        \ time

 STA INWK+32            \ Set byte #32 to %00001111 to give the rock hermit an
                        \ E.C.M.

 BNE whips              \ Jump to whips (this BNE is effectively a JMP as A will
                        \ never be zero)

.thongs

 CMP #10                \ If random A >= 10 (96% of the time), set the C flag

 AND #1                 \ Reduce A to a random number that's 0 or 1

 ADC #OIL               \ Set A = #OIL + A + C, so there's a 2% chance of us
                        \ spawning a cargo canister (#OIL), a 50% chance of
                        \ us spawning a boulder (#OIL + 1), and a 48% chance of
                        \ us spawning an asteroid (#OIL + 2)

.whips

 JSR NWSHP              \ Add our new asteroid or canister to the universe

\ ******************************************************************************
\
\       Name: Main game loop (Part 3 of 6)
\       Type: Subroutine
\   Category: Main loop
\    Summary: Potentially spawn a cop, particularly if we've been bad
\  Deep dive: Program flow of the main game loop
\             Ship data blocks
\             Fixing ship positions
\
\ ------------------------------------------------------------------------------
\
\ This section covers the following:
\
\   * Potentially spawn a cop (in a Viper), very rarely if we have been good,
\     more often if have been naughty, and very often if we have been properly
\     bad
\
\   * Very rarely, consider spawning a Thargoid, or vanishingly rarely, a Cougar
\
\ ******************************************************************************

.MTT1

 LDA SSPR               \ If we are outside the space station's safe zone, skip
 BEQ P%+5               \ the following instruction

.MLOOPS

 JMP MLOOP              \ Jump to MLOOP to skip the following

 JSR BAD                \ Call BAD to work out how much illegal contraband we
                        \ are carrying in our hold (A is up to 40 for a
                        \ standard hold crammed with contraband, up to 70 for
                        \ an extended cargo hold full of narcotics and slaves)

 ASL A                  \ Double A to a maximum of 80 or 140

 LDX MANY+COPS          \ If there are no cops in the local bubble, skip the
 BEQ P%+5               \ next instruction

 ORA FIST               \ There are cops in the vicinity and we've got a hold
                        \ full of jail time, so OR the value in A with FIST to
                        \ get a new value that is at least as high as both
                        \ values, to reflect the fact that they have almost
                        \ certainly scanned our ship

 STA T                  \ Store our badness level in T

 JSR Ze                 \ Call Ze to initialise INWK to a fairly aggressive
                        \ ship, and set A and X to random values
                        \
                        \ Note that because Ze uses the value of X returned by
                        \ DORND, and X contains the value of A returned by the
                        \ previous call to DORND, this does not set the new ship
                        \ to a totally random location

 CMP #136               \ If the random number in A = 136 (0.4% chance), jump
 BEQ fothg              \ to fothg in part 4 to spawn either a Thargoid or, very
                        \ rarely, a Cougar

 CMP T                  \ If the random value in A >= our badness level, which
 BCS P%+7               \ will be the case unless we have been really, really
                        \ bad, then skip the following two instructions (so
                        \ if we are really bad, there's a higher chance of
                        \ spawning a cop, otherwise we got away with it, for
                        \ now)

 LDA #COPS              \ Add a new police ship to the local bubble
 JSR NWSHP

 LDA MANY+COPS          \ If we now have at least one cop in the local bubble,
 BNE MLOOPS             \ jump down to MLOOPS to stop spawning, otherwise fall
                        \ through into the next part to look at spawning
                        \ something else

\ ******************************************************************************
\
\       Name: Main game loop (Part 4 of 6)
\       Type: Subroutine
\   Category: Main loop
\    Summary: Potentially spawn a lone bounty hunter, a Thargoid, or up to four
\             pirates
\  Deep dive: Program flow of the main game loop
\             Ship data blocks
\             Fixing ship positions
\             The elusive Cougar
\             Aggression and hostility in ship tactics
\
\ ------------------------------------------------------------------------------
\
\ This section covers the following:
\
\   * Potentially spawn (35% chance) either a lone bounty hunter (a Cobra Mk
\     III, Asp Mk II, Python or Fer-de-lance), a Thargoid, or a group of up to 4
\     pirates (a mix of Sidewinders, Mambas, Kraits, Adders, Geckos, Cobras Mk I
\     and III, and Worms)
\
\   * Also potentially spawn a Constrictor if this is the mission 1 endgame, or
\     Thargoids if mission 2 is in progress
\
\ ******************************************************************************

 DEC EV                 \ Decrement EV, the extra vessels spawning delay, and if
 BPL MLOOPS             \ it is still positive, jump to MLOOPS to stop spawning,
                        \ so we only do the following when the EV counter runs
                        \ down

 INC EV                 \ EV is negative, so bump it up again, setting it back
                        \ to 0

 LDA TP                 \ Fetch bits 2 and 3 of TP, which contain the status of
 AND #%00001100         \ mission 2

 CMP #%00001000         \ If bit 3 is set and bit 2 is clear, keep going to
 BNE nopl               \ spawn a Thargoid as we are transporting the plans in
                        \ mission 2 and the Thargoids are trying to stop us,
                        \ otherwise jump to nopl to skip spawning a Thargoid

 JSR DORND              \ Set A and X to random numbers

 CMP #220               \ If the random number in A < 220 (86% chance), jump to
 BCC nopl               \ nopl to skip spawning a Thargoid

.fothg2

 JSR GTHG               \ Call GTHG to spawn a Thargoid ship and a Thargon
                        \ companion

.nopl

 JSR DORND              \ Set A and X to random numbers

 LDY gov                \ If the government of this system is 0 (anarchy), jump
 BEQ LABEL_2            \ straight to LABEL_2 to start spawning pirates or a
                        \ lone bounty hunter

 CMP #90                \ If the random number in A >= 90 (65% chance), jump to
 BCS MLOOPS             \ MLOOPS to stop spawning (so there's a 35% chance of
                        \ spawning pirates or a lone bounty hunter)

 AND #7                 \ Reduce the random number in A to the range 0-7, and
 CMP gov                \ if A is less than government of this system, jump
 BCC MLOOPS             \ to MLOOPS to stop spawning (so safer governments with
                        \ larger gov numbers have a greater chance of jumping
                        \ out, which is another way of saying that more
                        \ dangerous systems spawn pirates and bounty hunters
                        \ more often)

.LABEL_2

                        \ Now to spawn a lone bounty hunter, a Thargoid or a
                        \ group of pirates

 JSR Ze                 \ Call Ze to initialise INWK to a fairly aggressive
                        \ ship, and set A and X to random values
                        \
                        \ Note that because Ze uses the value of X returned by
                        \ DORND, and X contains the value of A returned by the
                        \ previous call to DORND, this does not set the new ship
                        \ to a totally random location

 CMP #100               \ If the random number in A >= 100 (61% chance), jump
 BCS mt1                \ to mt1 to spawn pirates, otherwise keep going to
                        \ spawn a lone bounty hunter or a Thargoid

 INC EV                 \ Increase the extra vessels spawning counter, to
                        \ prevent the next attempt to spawn extra vessels

 AND #3                 \ Set A = random number in the range 0-3, which we
                        \ will now use to determine the type of ship

 ADC #CYL2              \ Add A to #CYL2 (we know the C flag is clear as we
                        \ passed through the BCS above), so A is now one of the
                        \ lone bounty hunter ships, i.e. Cobra Mk III (pirate),
                        \ Asp Mk II, Python (pirate) or Fer-de-lance
                        \
                        \ Interestingly, this logic means that the Moray, which
                        \ is the ship after the Fer-de-lance in the XX21 table,
                        \ never spawns, as the above logic chooses a blueprint
                        \ number in the range CYL2 to CYL2+3 (i.e. 24 to 27),
                        \ and the Moray is blueprint 28
                        \
                        \ No other code spawns the ship with blueprint 28, so
                        \ this means the Moray is never seen in Elite
                        \
                        \ This is presumably a bug, which could be very easily
                        \ fixed by inserting one of the following instructions
                        \ before the AND #3 instruction above:
                        \
                        \   * SEC would change the range to 25 to 28, which
                        \     would cover the Asp Mk II, Python (pirate),
                        \     Fer-de-lance and Moray
                        \
                        \   * LSR A would set the C flag to a random number to
                        \     give a range of 24 to 28, which would cover the
                        \     Cobra Mk III (pirate), Asp Mk II, Python (pirate),
                        \     Fer-de-lance and Moray
                        \
                        \ It's hard to know what the authors' original intent
                        \ was, but the second approach makes the Moray and Cobra
                        \ Mk III the rarest choices, with the Asp Mk II, Python
                        \ and Fer-de-Lance being more likely, and as the Moray
                        \ is described in the literature as a rare ship, and the
                        \ Cobra can already be spawned as part of a group of
                        \ pirates (see mt1 below), I tend to favour the LSR A
                        \ solution over the SEC approach

 TAY                    \ Copy the new ship type to Y

 JSR THERE              \ Call THERE to see if we are in the Constrictor's
                        \ system in mission 1

 BCC NOCON              \ If the C flag is clear then we are not in the
                        \ Constrictor's system, so skip to NOCON

 LDA #%11111001         \ Set the AI flag of this ship so that it has E.C.M.,
 STA INWK+32            \ has a very high aggression level of 60 out of 63, is
                        \ hostile, and has AI enabled - nasty stuff!

 LDA TP                 \ Fetch bits 0 and 1 of TP, which contain the status of
 AND #%00000011         \ mission 1

 LSR A                  \ Shift bit 0 into the C flag

 BCC NOCON              \ If bit 0 is clear, skip to NOCON as mission 1 is not
                        \ in progress

 ORA MANY+CON           \ Bit 0 of A now contains bit 1 of TP, so this will be
                        \ set if we have already completed mission 1, so this OR
                        \ will be non-zero if we have either completed mission
                        \ 1, or there is already a Constrictor in our local
                        \ bubble of universe (in which case MANY+CON will be
                        \ non-zero)

 BEQ YESCON             \ If A = 0 then mission 1 is in progress, we haven't
                        \ completed it yet, and there is no Constrictor in the
                        \ vicinity, so jump to YESCON to spawn the Constrictor

.NOCON

 LDA #%00000100         \ Set bit 2 of the NEWB flags and clear all other bits,
 STA NEWB               \ so the ship we are about to spawn is hostile

                        \ We now build the AI flag for this ship in A

 JSR DORND              \ Set A and X to random numbers

 CMP #200               \ First, set the C flag if X >= 200 (22% chance)

 ROL A                  \ Set bit 0 of A to the C flag (i.e. there's a 22%
                        \ chance of this ship having E.C.M.)

 ORA #%11000000         \ Set bits 6 and 7 of A, so the ship has AI (bit 7) and
                        \ an aggression level of at least 32 out of 63

 STA INWK+32            \ Store A in the AI flag of this ship

 TYA                    \ Set A to the new ship type in Y

 EQUB &2C               \ Skip the next instruction by turning it into
                        \ &2C &A9 &1F, or BIT &1FA9, which does nothing apart
                        \ from affect the flags

.YESCON

 LDA #CON               \ If we jump straight here, we are in the mission 1
                        \ endgame and it's time to spawn the Constrictor, so
                        \ set A to the Constrictor's type

.focoug

 JSR NWSHP              \ Spawn the new ship, whether it's a pirate, Thargoid,
                        \ Cougar or Constrictor

.mj1

 JMP MLOOP              \ Jump down to MLOOP, as we are done spawning ships

.fothg

 LDA K%+6               \ Fetch the z_lo coordinate of the first ship in the K%
 AND #%00111110         \ block (i.e. the planet) and extract bits 1-5

 BNE fothg2             \ If any of bits 1-5 are set (96.8% chance), jump up to
                        \ fothg2 to spawn a Thargoid

                        \ If we get here then we're going to spawn a Cougar, a
                        \ very rare event indeed. How rare? Well, all the
                        \ following have to happen in sequence:
                        \
                        \  * Main loop iteration = 0 (1 in 256 iterations)
                        \  * Skip asteroid spawning (87% chance)
                        \  * Skip cop spawning (0.4% chance)
                        \  * Skip Thargoid spawning (3.2% chance)
                        \
                        \ so the chances of spawning a Cougar on any single main
                        \ loop iteration are slim, to say the least

 LDA #18                \ Give the ship we're about to spawn a speed of 27
 STA INWK+27

 LDA #%01111001         \ Give it an E.C.M. and an aggression level of 60 out of
 STA INWK+32            \ 63, but don't enable its AI, so the ship will sit
                        \ still in space unless it is hit, at which point it
                        \ will defend itself vigorously
                        \
                        \ This ensures the Cougar behaves like a ship with a
                        \ cloaking device that hides it from the scanner, so it
                        \ minds its own business until it's discovered

 LDA #COU               \ Set the ship type to a Cougar and jump up to focoug
 BNE focoug             \ to spawn it

.mt1

 AND #3                 \ It's time to spawn a group of pirates, so set A to a
                        \ random number in the range 0-3, which will be the
                        \ loop counter for spawning pirates below (so we will
                        \ spawn 1-4 pirates)

 STA EV                 \ Delay further spawnings by this number

 STA XX13               \ Store the number in XX13, the pirate counter

.mt3

 JSR DORND              \ Set A and X to random numbers

 STA T                  \ Set T to a random number

 JSR DORND              \ Set A and X to random numbers

 AND T                  \ Set A to the AND of two random numbers, so each bit
                        \ has 25% chance of being set which makes the chances
                        \ of a smaller number higher

 AND #7                 \ Reduce A to a random number in the range 0-7, though
                        \ with a bigger chance of a smaller number in this range

 ADC #PACK              \ #PACK is set to #SH3, the ship type for a Sidewinder,
                        \ so this sets our new ship type to one of the pack
                        \ hunters, namely a Sidewinder, Mamba, Krait, Adder,
                        \ Gecko, Cobra Mk I, Worm or Cobra Mk III (pirate)

 JSR NWSHP              \ Try adding a new ship of type A to the local bubble

 DEC XX13               \ Decrement the pirate counter

 BPL mt3                \ If we need more pirates, loop back up to mt3,
                        \ otherwise we are done spawning, so fall through into
                        \ the end of the main loop at MLOOP

\ ******************************************************************************
\
\       Name: Main game loop (Part 5 of 6)
\       Type: Subroutine
\   Category: Main loop
\    Summary: Cool down lasers, make calls to update the dashboard
\  Deep dive: Program flow of the main game loop
\             The dashboard indicators
\
\ ------------------------------------------------------------------------------
\
\ This is the first half of the minimal game loop, which we iterate when we are
\ docked. This section covers the following:
\
\   * Cool down lasers
\
\   * Make calls to update the dashboard
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   MLOOP               The entry point for the main game loop. This entry point
\                       comes after the call to the main flight loop and
\                       spawning routines, so it marks the start of the main
\                       game loop for when we are docked (as we don't need to
\                       call the main flight loop or spawning routines if we
\                       aren't in space)
\
\ ******************************************************************************

.MLOOP

 LDX #&FF               \ Set the stack pointer to &01FF, which is the standard
 TXS                    \ location for the 6502 stack, so this instruction
                        \ effectively resets the stack

 LDX GNTMP              \ If the laser temperature in GNTMP is non-zero,
 BEQ EE20               \ decrement it (i.e. cool it down a bit)
 DEC GNTMP

.EE20

 LDX LASCT              \ Set X to the value of LASCT, the laser pulse count

 BEQ NOLASCT            \ If X = 0 then jump to NOLASCT to skip reducing LASCT,
                        \ as it can't be reduced any further

 DEX                    \ Decrement the value of LASCT in X

 BEQ P%+3               \ If X = 0, skip the next instruction

 DEX                    \ Decrement the value of LASCT in X again

 STX LASCT              \ Store the decremented value of X in LASCT, so LASCT
                        \ gets reduced by 2, but not into negative territory

.NOLASCT

\LDA QQ11               \ These instructions are commented out in the original
\BNE P%+5               \ source

 JSR DIALS              \ Call DIALS to update the dashboard

 LDA QQ11               \ If this is a space view, jump to plus13 to skip the
 BEQ plus13             \ following five instructions

 AND PATG               \ If PATG = &FF (author names are shown on start-up)
 LSR A                  \ and bit 0 of QQ11 is 1 (the current view is type 1),
 BCS plus13             \ then skip the following two instructions

 LDY #2                 \ Wait for 2/50 of a second (0.04 seconds), to slow the
 JSR DELAY              \ main loop down a bit

.plus13

 JSR TT17               \ Scan the keyboard for the cursor keys or joystick,
                        \ returning the cursor's delta values in X and Y and
                        \ the key pressed in A

\ ******************************************************************************
\
\       Name: Main game loop (Part 6 of 6)
\       Type: Subroutine
\   Category: Main loop
\    Summary: Process non-flight key presses (red function keys, docked keys)
\  Deep dive: Program flow of the main game loop
\
\ ------------------------------------------------------------------------------
\
\ This is the second half of the minimal game loop, which we iterate when we are
\ docked. This section covers the following:
\
\   * Process more key presses (red function keys, docked keys etc.)
\
\ It also supports joining the main loop with a key already "pressed", so we can
\ jump into the main game loop to perform a specific action. In practice, this
\ is used when we enter the docking bay in BAY to display Status Mode (red key
\ f8), and when we finish buying or selling cargo in BAY2 to jump to the
\ Inventory (red key f9).
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   FRCE                The entry point for the main game loop if we want to
\                       jump straight to a specific screen, by pretending to
\                       "press" a key, in which case A contains the internal key
\                       number of the key we want to "press"
\
\ ******************************************************************************

.FRCE

 JSR TT102              \ Call TT102 to process the key pressed in A

 LDA QQ12               \ Fetch the docked flag from QQ12 into A

 BEQ P%+5               \ If we are docked, loop back up to MLOOP just above
 JMP MLOOP              \ to restart the main loop, but skipping all the flight
                        \ and spawning code in the top part of the main loop

 JMP TT100              \ Otherwise jump to TT100 to restart the main loop from
                        \ the start

\ ******************************************************************************
\
\       Name: TT102
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Process function key, save key, hyperspace and chart key presses
\             and update the hyperspace counter
\
\ ------------------------------------------------------------------------------
\
\ Process function key presses, plus "@" (save commander), "H" (hyperspace),
\ "D" (show distance to system) and "O" (move chart cursor back to current
\ system). We can also pass cursor position deltas in X and Y to indicate that
\ the cursor keys or joystick have been used (i.e. the values that are returned
\ by routine TT17).
\
\ This routine also checks for the "F" key press (search for a system), which
\ applies to enhanced versions only.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The internal key number of the key pressed (see page 142
\                       of the "Advanced User Guide for the BBC Micro" by Bray,
\                       Dickens and Holmes for a list of internal key numbers)
\
\   X                   The amount to move the crosshairs in the x-axis
\
\   Y                   The amount to move the crosshairs in the y-axis
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   T95                 Print the distance to the selected system
\
\ ******************************************************************************

.TT102

 CMP #f8                \ If red key f8 was pressed, jump to STATUS to show the
 BNE P%+5               \ Status Mode screen, returning from the subroutine
 JMP STATUS             \ using a tail call

 CMP #f4                \ If red key f4 was pressed, jump to TT22 to show the
 BNE P%+5               \ Long-range Chart, returning from the subroutine using
 JMP TT22               \ a tail call

 CMP #f5                \ If red key f5 was pressed, jump to TT23 to show the
 BNE P%+5               \ Short-range Chart, returning from the subroutine using
 JMP TT23               \ a tail call

 CMP #f6                \ If red key f6 was pressed, call TT111 to select the
 BNE TT92               \ system nearest to galactic coordinates (QQ9, QQ10)
 JSR TT111              \ (the location of the chart crosshairs) and set ZZ to
 JMP TT25               \ the system number, and then jump to TT25 to show the
                        \ Data on System screen (along with an extended system
                        \ description for the system in ZZ if we're docked),
                        \ returning from the subroutine using a tail call

.TT92

 CMP #f9                \ If red key f9 was pressed, jump to TT213 to show the
 BNE P%+5               \ Inventory screen, returning from the subroutine
 JMP TT213              \ using a tail call

 CMP #f7                \ If red key f7 was pressed, jump to TT167 to show the
 BNE P%+5               \ Market Price screen, returning from the subroutine
 JMP TT167              \ using a tail call

 CMP #f0                \ If red key f0 was pressed, jump to TT110 to launch our
 BNE fvw                \ ship (if docked), returning from the subroutine using
\JSR CTRL               \ a tail call
\BPL P%+5               \
\JMP HALL               \ Three instructions are commented out in the original
 JMP TT110              \ source, which would show the ship hangar instead of
                        \ launching if CTRL is held down, so presumably they
                        \ were put in for testing

.fvw

 BIT QQ12               \ If bit 7 of QQ12 is clear (i.e. we are not docked, but
 BPL INSP               \ in space), jump to INSP to skip the following checks
                        \ for f1-f3 and "@" (save commander file) key presses

 CMP #f3                \ If red key f3 was pressed, jump to EQSHP to show the
 BNE P%+5               \ Equip Ship screen, returning from the subroutine using
 JMP EQSHP              \ a tail call

 CMP #f1                \ If red key f1 was pressed, jump to TT219 to show the
 BNE P%+5               \ Buy Cargo screen, returning from the subroutine using
 JMP TT219              \ a tail call

 CMP #'@'               \ If "@" was not pressed, skip to nosave
 BNE nosave

 JSR SVE                \ "@" was pressed, so call SVE to show the disc access
                        \ menu

 BCC P%+5               \ If the C flag was set by SVE, then we loaded a new
 JMP QU5                \ commander file, so jump to QU5 to restart the game
                        \ with the newly loaded commander

 JMP BAY                \ Otherwise the C flag was clear, so jump to BAY to go
                        \ to the docking bay (i.e. show the Status Mode screen)

.nosave

 CMP #f2                \ If red key f2 was pressed, jump to TT208 to show the
 BNE LABEL_3            \ Sell Cargo screen, returning from the subroutine using
 JMP TT208              \ a tail call

.INSP

 CMP #f1                \ If red key f1 was pressed, jump to chview1
 BEQ chview1

 CMP #f2                \ If red key f2 was pressed, jump to chview2
 BEQ chview2

 CMP #f3                \ If red key f3 was not pressed, jump to LABEL_3 to keep
 BNE LABEL_3            \ checking for which key was pressed

 LDX #3                 \ Red key f3 was pressed, so set the view number in X to
                        \ 3 for the right view

 EQUB &2C               \ Skip the next instruction by turning it into
                        \ &2C &A2 &02, or BIT &02A2, which does nothing apart
                        \ from affect the flags

.chview2

 LDX #2                 \ If we jump to here, red key f2 was pressed, so set the
                        \ view number in X to 2 for the left view

 EQUB &2C               \ Skip the next instruction by turning it into
                        \ &2C &A2 &01, or BIT &02A2, which does nothing apart
                        \ from affect the flags

.chview1

 LDX #1                 \ If we jump to here, red key f1 was pressed, so set the
                        \ view number in X to 1 for the rear view

 JMP LOOK1              \ Jump to LOOK1 to switch to view X (rear, left or
                        \ right), returning from the subroutine using a tail
                        \ call

.LABEL_3

 LDA KL                 \ If "H" was not pressed, jump to NWDAV5 to skip the
 CMP #'H'               \ following
 BNE NWDAV5

 JMP hyp                \ Jump to hyp to do a hyperspace jump (if we are in
                        \ space), returning from the subroutine using a tail
                        \ call

.NWDAV5

 CMP #'D'               \ If "D" was pressed, jump to T95 to print the distance
 BEQ T95                \ to a system (if we are in one of the chart screens)

 CMP #'F'               \ If "F" was not pressed, jump down to HME1, otherwise
 BNE HME1               \ keep going to process searching for systems

 LDA QQ12               \ If QQ12 = 0 (we are not docked), we can't search for
 BEQ t95                \ systems, so return from the subroutine (as t95
                        \ contains an RTS)

 LDA QQ11               \ If the current view is a chart (QQ11 = 64 or 128),
 AND #%11000000         \ keep going, otherwise return from the subroutine (as
 BEQ t95                \ t95 contains an RTS)

 JMP HME2               \ Jump to HME2 to let us search for a system, returning
                        \ from the subroutine using a tail call

.HME1

 STA T1                 \ Store A (the key that's been pressed) in T1

 LDA QQ11               \ If the current view is a chart (QQ11 = 64 or 128),
 AND #%11000000         \ keep going, otherwise jump down to TT107 to skip the
 BEQ TT107              \ following

 LDA QQ22+1             \ If the on-screen hyperspace counter is non-zero,
 BNE TT107              \ then we are already counting down, so jump to TT107
                        \ to skip the following

 LDA T1                 \ Restore the original value of A (the key that's been
                        \ pressed) from T1

 CMP #'O'               \ If "O" was pressed, do the following three jumps,
 BNE ee2                \ otherwise skip to ee2 to continue

 JSR TT103              \ Draw small crosshairs at coordinates (QQ9, QQ10),
                        \ which will erase the crosshairs currently there

 JSR ping               \ Set the target system to the current system (which
                        \ will move the location in (QQ9, QQ10) to the current
                        \ home system

 JMP TT103              \ Draw small crosshairs at coordinates (QQ9, QQ10),
                        \ which will draw the crosshairs at our current home
                        \ system, and return from the subroutine using a tail
                        \ call

.ee2

 JSR TT16               \ Call TT16 to move the crosshairs by the amount in X
                        \ and Y, which were passed to this subroutine as
                        \ arguments

.TT107

 LDA QQ22+1             \ If the on-screen hyperspace counter is zero, return
 BEQ t95                \ from the subroutine (as t95 contains an RTS), as we
                        \ are not currently counting down to a hyperspace jump

 DEC QQ22               \ Decrement the internal hyperspace counter

 BNE t95                \ If the internal hyperspace counter is still non-zero,
                        \ then we are still counting down, so return from the
                        \ subroutine (as t95 contains an RTS)

                        \ If we get here then the internal hyperspace counter
                        \ has just reached zero and it wasn't zero before, so
                        \ we need to reduce the on-screen counter and update
                        \ the screen. We do this by first printing the next
                        \ number in the countdown sequence, and then printing
                        \ the old number, which will erase the old number
                        \ and display the new one because printing uses EOR
                        \ logic

 LDX QQ22+1             \ Set X = the on-screen hyperspace counter - 1
 DEX                    \ (i.e. the next number in the sequence)

 JSR ee3                \ Print the 8-bit number in X at text location (0, 1)

 LDA #5                 \ Reset the internal hyperspace counter to 5
 STA QQ22

 LDX QQ22+1             \ Set X = the on-screen hyperspace counter (i.e. the
                        \ current number in the sequence, which is already
                        \ shown on-screen)

 JSR ee3                \ Print the 8-bit number in X at text location (0, 1),
                        \ i.e. print the hyperspace countdown in the top-left
                        \ corner

 DEC QQ22+1             \ Decrement the on-screen hyperspace countdown

 BNE t95                \ If the countdown is not yet at zero, return from the
                        \ subroutine (as t95 contains an RTS)

 JMP TT18               \ Otherwise the countdown has finished, so jump to TT18
                        \ to do a hyperspace jump, returning from the subroutine
                        \ using a tail call

.t95

 RTS                    \ Return from the subroutine

.T95

                        \ If we get here, "D" was pressed, so we need to show
                        \ the distance to the selected system (if we are in a
                        \ chart view)

 LDA QQ11               \ If the current view is a chart (QQ11 = 64 or 128),
 AND #%11000000         \ keep going, otherwise return from the subroutine (as
 BEQ t95                \ t95 contains an RTS)

 JSR hm                 \ Call hm to move the crosshairs to the target system
                        \ in (QQ9, QQ10), returning with A = 0

\STA QQ17               \ This instruction is commented out in the original
                        \ source

 JSR cpl                \ Print control code 3 (the selected system name)

 LDA #%10000000         \ Set bit 7 of QQ17 to switch to Sentence Case, with the
 STA QQ17               \ next letter in capitals

 LDA #12                \ Print a line feed to move the text cursor down a line
 JSR TT26

 JMP TT146              \ Print the distance to the selected system and return
                        \ from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: FAROF
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Compare x_hi, y_hi and z_hi with 224
\  Deep dive: A sense of scale
\
\ ------------------------------------------------------------------------------
\
\ Compare x_hi, y_hi and z_hi with 224, and set the C flag if all three <= 224,
\ otherwise clear the C flag.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              Set if x_hi <= 224 and y_hi <= 224 and z_hi <= 224
\
\                       Clear otherwise (i.e. if any one of them are bigger than
\                       224)
\
\ ******************************************************************************

.FAROF

 LDA #224               \ Set A = 224 and fall through into FAROF2 to do the
                        \ comparison

\ ******************************************************************************
\
\       Name: FAROF2
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Compare x_hi, y_hi and z_hi with A
\
\ ------------------------------------------------------------------------------
\
\ Compare x_hi, y_hi and z_hi with A, and set the C flag if all three <= A,
\ otherwise clear the C flag.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              Set if x_hi <= A and y_hi <= A and z_hi <= A
\
\                       Clear otherwise (i.e. if any one of them are bigger than
\                       A)
\
\ ******************************************************************************

.FAROF2

 CMP INWK+1             \ If A < x_hi, C will be clear so jump to FA1 to
 BCC FA1                \ return from the subroutine with C clear, otherwise
                        \ C will be set so move on to the next one

 CMP INWK+4             \ If A < y_hi, C will be clear so jump to FA1 to
 BCC FA1                \ return from the subroutine with C clear, otherwise
                        \ C will be set so move on to the next one

 CMP INWK+7             \ If A < z_hi, C will be clear, otherwise C will be set

.FA1

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: MAS4
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Calculate a cap on the maximum distance to a ship
\
\ ------------------------------------------------------------------------------
\
\ Logical OR the value in A with the high bytes of the ship's position (x_hi,
\ y_hi and z_hi).
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   A OR x_hi OR y_hi OR z_hi
\
\ ******************************************************************************

.MAS4

 ORA INWK+1             \ OR A with x_hi, y_hi and z_hi
 ORA INWK+4
 ORA INWK+7

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: stackpt
\       Type: Variable
\   Category: Save and load
\    Summary: Temporary storage for the stack pointer when jumping to the break
\             handler at NEWBRK
\
\ ******************************************************************************

.stackpt

 EQUB &FF

\ ******************************************************************************
\
\       Name: NEWBRK
\       Type: Subroutine
\   Category: Utility routines
\    Summary: The standard BRKV handler for the game
\
\ ------------------------------------------------------------------------------
\
\ This routine is used to display error messages, before restarting the game.
\ When called, it makes a beep and prints the system error message in the block
\ pointed to by (&FD &FE), which is where the MOS will put any system errors. It
\ then waits for a key press and restarts the game.
\
\ ******************************************************************************

.NEWBRK

 LDX stackpt            \ Set the stack pointer to the value that we stored in
 TXS                    \ location stack, so that's back to the value it had

 LDA #HOMEBANK          \ Port: page Elite's home bank in, as the MOS enters
 STA &F4                \ BRKV with the ROM that raised the error paged in (the
 STA VIA+&30            \ original's getzp did this, setting ROMSEL to bank 6)
                        \ before we change it in the SVE routine

 JSR getzp              \ Call getzp to restore the top part of zero page from
                        \ the buffer at &3000, as this will have been stored in
                        \ the buffer before performing the disc access that gave
                        \ the error we're processsing

 JSR DOSNMI             \ Port: the minimal NMI handler back (DFS installed its
                        \ own for the command that failed; elite-cold7.asm)

 STZ CATF               \ Set the CATF flag to 0, so the TT26 routine reverts to
                        \ standard formatting

 LDY #0                 \ Set Y to 0, which we use as a loop counter below

 LDA #7                 \ Set A = 7 to generate a beep before we print the error
                        \ message

.BRBRLOOP

 JSR CHPR               \ Print the character in A, which contains a line feed
                        \ on the first loop iteration, and then any non-zero
                        \ characters we fetch from the error message

 INY                    \ Increment the loop counter

 LDA (&FD),Y            \ Fetch the Y-th byte of the block pointed to by
                        \ (&FD &FE), so that's the Y-th character of the message
                        \ pointed to by the error message pointer

 BNE BRBRLOOP           \ If the fetched character is non-zero, loop back to the
                        \ JSR OSWRCH above to print the it, and keep looping
                        \ until we fetch a zero (which marks the end of the
                        \ message)

 JSR t                  \ Scan the keyboard until a key is pressed, returning
                        \ the ASCII code in A and X

 JMP SVE                \ Jump to SVE to display the disc access menu and return
                        \ from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: spasto
\       Type: Variable
\   Category: Universe
\    Summary: Contains the address of the Coriolis space station's ship
\             blueprint
\
\ ******************************************************************************

.spasto

 EQUW &8888             \ This variable is set by routine BEGIN to the address
                        \ of the Coriolis space station's ship blueprint

\ ******************************************************************************
\
\       Name: BEGIN
\       Type: Subroutine
\   Category: Loader
\    Summary: Initialise the configuration variables and start the game
\
\ ******************************************************************************

.BEGIN

 LDX #(DISK-COMC)       \ We start by zeroing all the configuration variables
                        \ between COMC and DISK, to set them to their default
                        \ values, so set a counter in X for DISK - COMC bytes

 LDA #0                 \ Set A = 0 so we can zero the variables

.BEL1

 STA COMC,X             \ Zero the X-th configuration variable

 DEX                    \ Decrement the loop counter

 BPL BEL1               \ Loop back to BEL1 to zero the next byte, until we have
                        \ zeroed them all

 LDA XX21+SST*2-2       \ Set spasto(1 0) to the Coriolis space station entry
 STA spasto             \ from the ship blueprint lookup table at XX21 (so
 LDA XX21+SST*2-1       \ spasto(1 0) points to the Coriolis blueprint)
 STA spasto+1

 JSR JAMESON            \ Call JAMESON to set the last saved commander to the
                        \ default "JAMESON" commander

 JMP TT170              \ Port: jump to TT170 to start the game (the original
                        \ fell through into it; it is now in the cold area)

\ ******************************************************************************
\
\       Name: RLINE
\       Type: Variable
\   Category: Text
\    Summary: The OSWORD configuration block used to fetch a line of text from
\             the keyboard
\
\ ******************************************************************************

.RLINE

 EQUW INWK+5            \ The address to store the input, so the text entered
                        \ will be stored in INWK+5 as it is typed

 EQUB 9                 \ Maximum line length = 9, as that's the maximum size
                        \ for a commander's name including a directory name

 EQUB '!'               \ Allow ASCII characters from "!" through to "{" in
 EQUB '{'               \ the input

\ ******************************************************************************
\
\       Name: thislong
\       Type: Variable
\   Category: Save and load
\    Summary: Contains the length of the most recently entered commander name
\
\ ******************************************************************************

.thislong

 EQUB 7

\ ******************************************************************************
\
\       Name: oldlong
\       Type: Variable
\   Category: Save and load
\    Summary: Contains the length of the last saved commander name
\
\ ******************************************************************************

.oldlong

 EQUB 7

\ ******************************************************************************
\
\       Name: CTLI
\       Type: Variable
\   Category: Save and load
\    Summary: The OS command string for cataloguing a disc
\
\ ******************************************************************************

.CTLI

IF _SNG47

 EQUS "CAT 1"           \ The "1" part of the string is overwritten with the
 EQUB 13                \ actual drive number by the CATS routine

ELIF _COMPACT

 EQUS "CAT"             \ The Master Compact only has one drive, so the CAT
 EQUB 13                \ command always catalogues that drive

ENDIF

\ ******************************************************************************
\
\       Name: DELI
\       Type: Variable
\   Category: Save and load
\    Summary: The OS command string for deleting a file
\
\ ******************************************************************************

.DELI

IF _SNG47

 EQUS "DELETE :1.1234567"
 EQUB 13

ELIF _COMPACT

 EQUS "DELETE 1234567890"
 EQUB 13

ENDIF

\ ******************************************************************************
\
\       Name: DIRI
\       Type: Variable
\   Category: Save and load
\    Summary: The OS command string for changing directory on the Master Compact
\
\ ******************************************************************************

IF _COMPACT

.DIRI

 EQUS "DIR 12345678901234567890"
 EQUB 13

ENDIF

\ ******************************************************************************
\
\       Name: savosc
\       Type: Variable
\   Category: Save and load
\    Summary: The OS command string for saving a commander file
\
\ ******************************************************************************

.savosc

IF _SNG47

 EQUS "SAVE :1.E.JAMESON  E7E +100 0 0"
 EQUB 13

ELIF _COMPACT

 EQUS "SAVE JAMESON  E7E +100 0 0"
 EQUB 13

ENDIF

\ ******************************************************************************
\
\       Name: lodosc
\       Type: Variable
\   Category: Save and load
\    Summary: The OS command string for loading a commander file
\
\ ******************************************************************************

.lodosc

IF _SNG47

 EQUS "LOAD :1.E.JAMESON  E7E"
 EQUB 13

ELIF _COMPACT

 EQUS "LOAD JAMESON  E7E"
 EQUB 13

ENDIF

\ ******************************************************************************
\
\       Name: SPS1
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Calculate the vector to the planet and store it in XX15
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   SPS1+1              A BRK instruction
\
\ ******************************************************************************

.SPS1

 LDX #0                 \ Copy the two high bytes of the planet's x-coordinate
 JSR SPS3               \ into K3(2 1 0), separating out the sign bit into K3+2

 LDX #3                 \ Copy the two high bytes of the planet's y-coordinate
 JSR SPS3               \ into K3(5 4 3), separating out the sign bit into K3+5

 LDX #6                 \ Copy the two high bytes of the planet's z-coordinate
 JSR SPS3               \ into K3(8 7 6), separating out the sign bit into K3+8

                        \ Fall through into TAS2 to build XX15 from K3

\ ******************************************************************************
\
\       Name: TAS2
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Normalise the three-coordinate vector in K3
\
\ ------------------------------------------------------------------------------
\
\ Normalise the vector in K3, which has 16-bit values and separate sign bits,
\ and store the normalised version in XX15 as a signed 8-bit vector.
\
\ A normalised vector (also known as a unit vector) has length 1, so this
\ routine takes an existing vector in K3 and scales it so the length of the
\ new vector is 1. This is used in a number of places: when drawing the compass,
\ when applying AI tactics to ships (so traders fly towards planets and missiles
\ fly towards their targets, for example), and when implementing the docking
\ computer in the enhanced versions of Elite.
\
\ We do this in two stages. This stage shifts the 16-bit vector coordinates in
\ K3 to the left as far as they will go without losing any bits off the end, so
\ we can then take the high bytes and use them as the most accurate 8-bit vector
\ to normalise. Then the next stage (in routine NORM) does the normalisation.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   K3(2 1 0)           The 16-bit x-coordinate as (x_sign x_hi x_lo), where
\                       x_sign is just bit 7
\
\   K3(5 4 3)           The 16-bit y-coordinate as (y_sign y_hi y_lo), where
\                       y_sign is just bit 7
\
\   K3(8 7 6)           The 16-bit z-coordinate as (z_sign z_hi z_lo), where
\                       z_sign is just bit 7
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   XX15                The normalised vector, with:
\
\                         * The x-coordinate in XX15
\
\                         * The y-coordinate in XX15+1
\
\                         * The z-coordinate in XX15+2
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   TA2                 Calculate the length of the vector in XX15 (ignoring the
\                       low coordinates), returning it in Q
\
\ ******************************************************************************

.TAS2

 LDA K3                 \ OR the three low bytes and 1 to get a byte that has
 ORA K3+3               \ a 1 wherever any of the three low bytes has a 1
 ORA K3+6               \ (as well as always having bit 0 set), and store in
 ORA #1                 \ K3+9
 STA K3+9

 LDA K3+1               \ OR the three high bytes to get a byte in A that has a
 ORA K3+4               \ 1 wherever any of the three high bytes has a 1
 ORA K3+7

                        \ (A K3+9) now has a 1 wherever any of the 16-bit
                        \ values in K3 has a 1
.TAL2

 ASL K3+9               \ Shift (A K3+9) to the left, so bit 7 of the high byte
 ROL A                  \ goes into the C flag

 BCS TA2                \ If the left shift pushed a 1 out of the end, then we
                        \ know that at least one of the coordinates has a 1 in
                        \ this position, so jump to TA2 as we can't shift the
                        \ values in K3 any further to the left

 ASL K3                 \ Shift K3(1 0), the x-coordinate, to the left
 ROL K3+1

 ASL K3+3               \ Shift K3(4 3), the y-coordinate, to the left
 ROL K3+4

 ASL K3+6               \ Shift K3(6 7), the z-coordinate, to the left
 ROL K3+7

 BCC TAL2               \ Jump back to TAL2 to do another shift left (this BCC
                        \ is effectively a JMP as we know bit 7 of K3+7 is not a
                        \ 1, as otherwise bit 7 of A would have been a 1 and we
                        \ would have taken the BCS above)

.TA2

 LDA K3+1               \ Fetch the high byte of the x-coordinate from our left-
 LSR A                  \ shifted K3, shift it right to clear bit 7, stick the
 ORA K3+2               \ sign bit in there from the x_sign part of K3, and
 STA XX15               \ store the resulting signed 8-bit x-coordinate in XX15

 LDA K3+4               \ Fetch the high byte of the y-coordinate from our left-
 LSR A                  \ shifted K3, shift it right to clear bit 7, stick the
 ORA K3+5               \ sign bit in there from the y_sign part of K3, and
 STA XX15+1             \ store the resulting signed 8-bit y-coordinate in
                        \ XX15+1

 LDA K3+7               \ Fetch the high byte of the z-coordinate from our left-
 LSR A                  \ shifted K3, shift it right to clear bit 7, stick the
 ORA K3+8               \ sign bit in there from the z_sign part of K3, and
 STA XX15+2             \ store the resulting signed 8-bit  z-coordinate in
                        \ XX15+2

                        \ Now we have a signed 8-bit version of the vector K3 in
                        \ XX15, so fall through into NORM to normalise it

\ ******************************************************************************
\
\       Name: NORM
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Normalise the three-coordinate vector in XX15
\  Deep dive: Tidying orthonormal vectors
\             Orientation vectors
\
\ ------------------------------------------------------------------------------
\
\ We do this by dividing each of the three coordinates by the length of the
\ vector, which we can calculate using Pythagoras. Once normalised, 96 (&60) is
\ used to represent a value of 1, and 96 with bit 7 set (&E0) is used to
\ represent -1. This enables us to represent fractional values of less than 1
\ using integers.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   XX15                The vector to normalise, with:
\
\                         * The x-coordinate in XX15
\
\                         * The y-coordinate in XX15+1
\
\                         * The z-coordinate in XX15+2
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   XX15                The normalised vector
\
\   Q                   The length of the original XX15 vector
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   NO1                 Contains an RTS
\
\ ******************************************************************************

.NORM

 LDA XX15               \ Fetch the x-coordinate into A

 JSR SQUA               \ Set (A P) = A * A = x^2

 STA R                  \ Set (R Q) = (A P) = x^2
 LDA P
 STA Q

 LDA XX15+1             \ Fetch the y-coordinate into A

 JSR SQUA               \ Set (A P) = A * A = y^2

 STA T                  \ Set (T P) = (A P) = y^2

 LDA P                  \ Set (R Q) = (R Q) + (T P) = x^2 + y^2
 ADC Q                  \
 STA Q                  \ First, doing the low bytes, Q = Q + P

 LDA T                  \ And then the high bytes, R = R + T
 ADC R
 STA R

 LDA XX15+2             \ Fetch the z-coordinate into A

 JSR SQUA               \ Set (A P) = A * A = z^2

 STA T                  \ Set (T P) = (A P) = z^2

 LDA P                  \ Set (R Q) = (R Q) + (T P) = x^2 + y^2 + z^2
 ADC Q                  \
 STA Q                  \ First, doing the low bytes, Q = Q + P

 LDA T                  \ And then the high bytes, R = R + T
 ADC R
 STA R

 JSR LL5                \ We now have the following:
                        \
                        \ (R Q) = x^2 + y^2 + z^2
                        \
                        \ so we can call LL5 to use Pythagoras to get:
                        \
                        \ Q = SQRT(R Q)
                        \   = SQRT(x^2 + y^2 + z^2)
                        \
                        \ So Q now contains the length of the vector (x, y, z),
                        \ and we can normalise the vector by dividing each of
                        \ the coordinates by this value, which we do by calling
                        \ routine TIS2. TIS2 returns the divided figure, using
                        \ 96 to represent 1 and 96 with bit 7 set for -1

 LDA XX15               \ Call TIS2 to divide the x-coordinate in XX15 by Q,
 JSR TIS2               \ with 1 being represented by 96
 STA XX15

 LDA XX15+1             \ Call TIS2 to divide the y-coordinate in XX15+1 by Q,
 JSR TIS2               \ with 1 being represented by 96
 STA XX15+1

 LDA XX15+2             \ Call TIS2 to divide the z-coordinate in XX15+2 by Q,
 JSR TIS2               \ with 1 being represented by 96
 STA XX15+2

.NO1

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: ITEM
\       Type: Macro
\   Category: Market
\    Summary: Macro definition for the market prices table
\  Deep dive: Market item prices and availability
\
\ ------------------------------------------------------------------------------
\
\ The following macro is used to build the market prices table:
\
\   ITEM price, factor, units, quantity, mask
\
\ It inserts an item into the market prices table at QQ23.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   price               Base price
\
\   factor              Economic factor
\
\   units               Units: "t", "g" or "k"
\
\   quantity            Base quantity
\
\   mask                Fluctuations mask
\
\ ******************************************************************************

MACRO ITEM price, factor, units, quantity, mask

 IF factor < 0
  s = 1 << 7
 ELSE
  s = 0
 ENDIF

 IF units = 't'
  u = 0
 ELIF units = 'k'
  u = 1 << 5
 ELSE
  u = 1 << 6
 ENDIF

 e = ABS(factor)

 EQUB price
 EQUB s + u + e
 EQUB quantity
 EQUB mask

ENDMACRO

\ ******************************************************************************
\
\       Name: QQ23
\       Type: Variable
\   Category: Market
\    Summary: Market prices table
\  Deep dive: Market item prices and availability
\
\ ------------------------------------------------------------------------------
\
\ Each item has four bytes of data, like this:
\
\   Byte #0 = Base price
\   Byte #1 = Economic factor in bits 0-4, with the sign in bit 7
\             Unit in bits 5-6
\   Byte #2 = Base quantity
\   Byte #3 = Mask to control price fluctuations
\
\ To make it easier for humans to follow, I've defined a macro called ITEM
\ that takes the following arguments and builds the four bytes for us:
\
\   ITEM base price, economic factor, units, base quantity, mask
\
\ So for food, we have the following, for example:
\
\   * Base price = 19
\   * Economic factor = -2
\   * Unit = tonnes
\   * Base quantity = 6
\   * Mask = %00000001
\
\ ******************************************************************************

.QQ23

 ITEM 19,  -2, 't',   6, %00000001  \  0 = Food
 ITEM 20,  -1, 't',  10, %00000011  \  1 = Textiles
 ITEM 65,  -3, 't',   2, %00000111  \  2 = Radioactives
 ITEM 40,  -5, 't', 226, %00011111  \  3 = Slaves
 ITEM 83,  -5, 't', 251, %00001111  \  4 = Liquor/Wines
 ITEM 196,  8, 't',  54, %00000011  \  5 = Luxuries
 ITEM 235, 29, 't',   8, %01111000  \  6 = Narcotics
 ITEM 154, 14, 't',  56, %00000011  \  7 = Computers
 ITEM 117,  6, 't',  40, %00000111  \  8 = Machinery
 ITEM 78,   1, 't',  17, %00011111  \  9 = Alloys
 ITEM 124, 13, 't',  29, %00000111  \ 10 = Firearms
 ITEM 176, -9, 't', 220, %00111111  \ 11 = Furs
 ITEM 32,  -1, 't',  53, %00000011  \ 12 = Minerals
 ITEM 97,  -1, 'k',  66, %00000111  \ 13 = Gold

\EQUD &360A118          \ This data is commented out in the original source
                        \
                        \ It would have inserted an item as follows:
                        \
                        \   ITEM 24, -1, 'k',  96, %00000011
                        \
                        \ So that's an item with a base price of 24 credits that
                        \ is slightly cheaper than average in agricultural
                        \ economies but closer to average in rich industrial
                        \ ones, with a base quantity of 96kg and a reasonably
                        \ stable price
                        \
                        \ I wonder what this mysterious item was going to be?

 ITEM 171, -2, 'k',  55, %00011111  \ 14 = Platinum
 ITEM 45,  -1, 'g', 250, %00001111  \ 15 = Gem-Stones
 ITEM 53,  15, 't', 192, %00000111  \ 16 = Alien items

\ ******************************************************************************
\
\       Name: KTRAN
\       Type: Variable
\   Category: Keyboard
\    Summary: An unused key logger buffer that's left over from the 6502 Second
\             Processor version of Elite
\
\ ******************************************************************************

.buf

 EQUB 2                 \ Transmit 2 bytes as part of this command

 EQUB 15                \ Receive 15 bytes as part of this command

.KTRAN

 EQUS "1234567890"      \ A 17-byte buffer to hold the key logger data from the
 EQUS "1234567"         \ KEYBOARD routine in the I/O processor (note that only
                        \ 12 of these bytes are actually updated by the KEYBOARD
                        \ routine)

\ ******************************************************************************
\
\ Save ELTF.bin
\
\ ******************************************************************************

 PRINT "ELITE F"
 PRINT "Assembled at ", ~CODE_F%
 PRINT "Ends at ", ~P%
 PRINT "Code size is ", ~(P% - CODE_F%)
 PRINT "Execute at ", ~LOAD%
 PRINT "Reload at ", ~LOAD_F%

 PRINT "S.ELTF ", ~CODE_F%, " ", ~P%, " ", ~LOAD%, " ", ~LOAD_F%
\SAVE "build/ELTF.bin", CODE_F%, P%, LOAD%

\ ******************************************************************************
\
\ ELITE G FILE
\
\ ******************************************************************************

 CODE_G% = P%

 LOAD_G% = LOAD% + P% - CODE%

\ ******************************************************************************

 PRINT "ELITE G"
 PRINT "Assembled at ", ~CODE_G%
 PRINT "Ends at ", ~P%
 PRINT "Code size is ", ~(P% - CODE_G%)
 PRINT "Execute at ", ~LOAD%
 PRINT "Reload at ", ~LOAD_G%

 PRINT "S.ELTG ", ~CODE_G%, " ", ~P%, " ", ~LOAD%, " ", ~LOAD_G%
\SAVE "build/ELTG.bin", CODE_G%, P%, LOAD%

\ ******************************************************************************
\
\ ELITE H FILE
\
\ ******************************************************************************

 CODE_H% = P%

 LOAD_H% = LOAD% + P% - CODE%

\ ******************************************************************************
\
\       Name: TRIBTA
\       Type: Variable
\   Category: Missions
\    Summary: A table for converting the number of Trumbles in the hold into a
\             number of sprites in the range 0 to 6
\
\ ******************************************************************************

\.TRIBTA                \ These instructions are commented out in the original
\                       \ source
\EQUB 0
\EQUB 1
\EQUB 2
\EQUB 3
\EQUB 4
\EQUB 5
\EQUB 6
\EQUB 6

\ ******************************************************************************
\
\       Name: TRIBMA
\       Type: Variable
\   Category: Missions
\    Summary: A table for converting the number of Trumbles in the hold into a
\             sprite-enable flag to use with VIC register &15
\
\ ******************************************************************************

\.TRIBMA                \ These instructions are commented out in the original
\                       \ source
\EQUB 0
\EQUB 4
\EQUB &C
\EQUB &1C
\EQUB &3C
\EQUB &7C
\EQUB &FC
\EQUB &FC

\ ******************************************************************************
\
\       Name: TRTB%
\       Type: Variable
\   Category: Keyboard
\    Summary: Translation table from internal key number to ASCII
\
\ ------------------------------------------------------------------------------
\
\ This is a copy of the keyboard translation table from the BBC Master's MOS
\ 3.20 ROM. The value at offset n is the upper-case ASCII value of the key with
\ internal key number n, so for example the value at offset &10 is &51, which is
\ 81, or ASCII "Q", so internal key number &10 is the key number of the "Q"
\ key.
\
\ Valid internal key numbers are Binary Coded Decimal (BCD) numbers in the range
\ &10 top &79, so they're in the ranges &10 to &19, then &20 to &29, then &30 to
\ &39, and so on. This means that the other locations - i.e. &1A to &1F, &2A to
\ &2F and so on - aren't used by the lookup table, but the MOS doesn't let this
\ space go to waste; instead, those gaps contain MOS code, which is replicated
\ below as the table contains a copy of this entire block of the MOS, not just
\ the table entries.
\
\ This table allows code running on the parasite to convert internal key numbers
\ into ASCII codes in an efficient way. Without this table we would have to do a
\ lookup from the table in the I/O processor's MOS ROM, which we would have to
\ access from across the Tube, and this would be a lot slower than doing a
\ simple table lookup in the parasite's user RAM.
\
\ ******************************************************************************

.TRTB%

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

\ ******************************************************************************
\
\       Name: IKNS
\       Type: Variable
\   Category: Keyboard
\    Summary: Lookup table for in-flight keyboard controls
\  Deep dive: The key logger
\
\ ------------------------------------------------------------------------------
\
\ Keyboard table for in-flight controls. This table contains the internal key
\ codes for the flight keys, EOR'd with &FF to invert each bit.
\
\ ******************************************************************************

.IKNS

 EQUB &DD EOR &FF       \ E         IKNS+0    KY13     E.C.M.
 EQUB &DC EOR &FF       \ T         IKNS+1    KY10     Target missile
 EQUB &CA EOR &FF       \ U         IKNS+2    KY11     Unarm missile
 EQUB &C8 EOR &FF       \ P         IKNS+3    KY16     Cancel docking computer
 EQUB &BE EOR &FF       \ A         IKNS+4    KY7      Fire lasers
 EQUB &BD EOR &FF       \ X         IKNS+5    KY5      Pull up
 EQUB &BA EOR &FF       \ J         IKNS+6    KY14     In-system jump
 EQUB &AE EOR &FF       \ S         IKNS+7    KY6      Pitch down
 EQUB &AD EOR &FF       \ C         IKNS+8    KY15     Docking computer
 EQUB &9F EOR &FF       \ TAB       IKNS+9    KY8      Energy bomb
 EQUB &9D EOR &FF       \ Space     IKNS+10   KY2      Speed up
 EQUB &9A EOR &FF       \ M         IKNS+11   KY12     Fire missile
 EQUB &99 EOR &FF       \ <         IKNS+12   KY3      Roll left
 EQUB &98 EOR &FF       \ >         IKNS+13   KY4      Roll right
 EQUB &97 EOR &FF       \ ?         IKNS+14   KY1      Slow down
 EQUB &8F EOR &FF       \ ESCAPE    IKNS+15   KY9      Launch escape pod

 EQUB &F0               \ This value just has to be higher than &80 to act as a
                        \ terminator for the IKNS matching process in FILLKL

\ ******************************************************************************
\
\       Name: FILLKL
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Scan the keyboard for a flight key and update the key logger
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   X                   If a key is being pressed, X contains the internal key
\                       number, otherwise it contains 0
\
\ ******************************************************************************

.FILLKL

 JSR ZEKTRAN            \ Call ZEKTRAN to clear the key logger, which also sets
                        \ X to 0 (so we can use X as an index for working our
                        \ way through the flight keys in Rd2 below)

 LDA #16                \ Start the scan with internal key number 16 ("Q")

 CLC                    \ Clear the C flag so we can do the additions below

.Rd1

 LDY #%00000011         \ Set Y to %00000011, so it's ready to send to SHEILA
                        \ once interrupts have been disabled

 SEI                    \ Disable interrupts so we can scan the keyboard
                        \ without being hijacked

 STY VIA+&40            \ Set 6522 System VIA output register ORB (SHEILA &40)
                        \ to %00000011 to stop auto scan of keyboard

 LDY #%01111111         \ Set 6522 System VIA data direction register DDRA
 STY VIA+&43            \ (SHEILA &43) to %01111111. This sets the A registers
                        \ (IRA and ORA) so that:
                        \
                        \   * Bits 0-6 of ORA will be sent to the keyboard
                        \
                        \   * Bit 7 of IRA will be read from the keyboard

 LDY #%00001011         \ Set Y ready to restart the keyboard auto scan below

 STA VIA+&4F            \ Set 6522 System VIA output register ORA (SHEILA &4F)
                        \ to A, the key we want to scan for; bits 0-6 will be
                        \ sent to the keyboard, of which bits 0-3 determine the
                        \ keyboard column, and bits 4-6 the keyboard row

 BIT VIA+&4F            \ Read 6522 System VIA input register IRA (SHEILA &4F)
                        \ so N is bit 7, which is set if the key is pressed;
                        \ A still holds the key number with bit 7 clear

 STY VIA+&40            \ Set 6522 System VIA output register ORB (SHEILA &40)
                        \ to %00001011 to restart auto scan of keyboard (this
                        \ doesn't affect the N flag)

 CLI                    \ Allow interrupts again

 BMI Rd2                \ If the key was pressed then N is set, so jump to Rd2

.Rd3

 ADC #1                 \ Increment A to point to the next key to scan for

 BPL Rd1                \ If A is positive, we still have keys to check, so loop
                        \ back to scan for the next one

                        \ If we get here then no keys are being pressed

 CLD                    \ Clear the D flag to return to binary mode (for cases
                        \ where this routine is called in BCD mode)

 LDA KY6                \ If KY6 ("S") is being pressed, then KY6 is &FF, and
 EOR #&FF               \ KY6 EOR &FF AND KY19 will be zero, so this stops "C"
 AND KY19               \ from being registered as being pressed if "S" is being
 STA KY19               \ pressed. This code isn't necessary on a BBC Master, as
                        \ it's from other versions of Elite where there were
                        \ issues with "ghost keys", which the Master didn't have

 LDA KL                 \ Fetch the last key pressed from KL

 TAX                    \ Copy the key value into X

 RTS                    \ Return from the subroutine

.Rd2

                        \ If we get here then the key in A is being pressed. We
                        \ now work our way through the IKNS table, looking for
                        \ a match against the flight keys, using X as an index
                        \ into the table (X was initialised to 0 by the call to
                        \ ZEKTRAN above, and it keeps track of our progress
                        \ through the table between calls to Rd2)
                        \
                        \ A already holds the key number with bit 7 clear

 STA KL                 \ Store the number of the key pressed in KL

                        \ Now to scan the IKNS table for a possible match for
                        \ the pressed key (if we get a match we update the key
                        \ logger, as IKNS contains the flight keys that have
                        \ key logger entries. Because we are scanning the
                        \ keyboard by incrementing the key to check in A, and
                        \ the IKNS table is sorted in increasing order, we don't
                        \ need to scan the whole IKNS table each time for a
                        \ match, we can just check against the next key in the
                        \ table, as pointed to by X

.Rd5

 CMP IKNS,X             \ If A is less than the X-th byte in IKNS, jump back to
 BCC Rd3                \ Rd3 to continue scanning for more keys, as this key
                        \ isn't in the IKNS table and doesn't have an entry in
                        \ the key logger

 BEQ Rd4                \ If A is equal to the X-th byte in IKNS, we have a
                        \ match, so skip the next two instructions to go to the
                        \ part where we update the key logger

 INX                    \ The pressed key is higher than the IKNS entry at X, so
                        \ increment X to point to the next key in the table

 BNE Rd5                \ And loop back to Rd5 to test against this next flight
                        \ key in IKNS (this BNE is effectively a JMP as X won't
                        \ get high enough to wrap around to zero)

                        \ If we get here, the pressed key has an entry in the
                        \ key logger, so now to update the logger

.Rd4

 DEC KY17,X             \ We got a match in the IKNS table for our key at
                        \ position X, so we decrement the corresponding key
                        \ logger byte for this key at KY17+X (KY17 is the first
                        \ key in the key logger)

 INX                    \ Increment X so next time we check IKNS from the next
                        \ key in the table

 CLC                    \ Clear the C flag so we can do more additions

 BCC Rd3                \ Jump back to Rd3 to continue scanning for more keys
                        \ (this BCC is effectively a JMP as we just cleared the
                        \ C flag)

\ ******************************************************************************
\
\       Name: CTRL
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Scan the keyboard to see if CTRL is currently pressed
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   X                   X = %10000001 (i.e. 129 or -127) if CTRL is being
\                       pressed
\
\                       X = 1 if CTRL is not being pressed
\
\   A                   Contains the same as X
\
\ ******************************************************************************

IF _SNG47

.CTRL

 LDA #1                 \ Set A to the internal key number for CTRL and fall
                        \ through into DKS5 to scan the keyboard

ENDIF

\ ******************************************************************************
\
\       Name: DKS5
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Scan the keyboard to see if a specific key is being pressed
\  Deep dive: The key logger
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The internal number of the key to check (see page 142 of
\                       the "Advanced User Guide for the BBC Micro" by Bray,
\                       Dickens and Holmes for a list of internal key numbers)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   If the key in A is being pressed, A contains the
\                       original argument A, but with bit 7 set (i.e. A + 128).
\                       If the key in A is not being pressed, the value in A is
\                       unchanged
\
\   X                   Contains the same as A
\
\ ******************************************************************************

IF _SNG47

.DKS5

 LDX #3                 \ Set X to 3, so it's ready to send to SHEILA once
                        \ interrupts have been disabled

 SEI                    \ Disable interrupts so we can scan the keyboard
                        \ without being hijacked

 STX VIA+&40            \ Set 6522 System VIA output register ORB (SHEILA &40)
                        \ to %00000011 to stop auto scan of keyboard

 LDX #%01111111         \ Set 6522 System VIA data direction register DDRA
 STX VIA+&43            \ (SHEILA &43) to %01111111. This sets the A registers
                        \ (IRA and ORA) so that:
                        \
                        \   * Bits 0-6 of ORA will be sent to the keyboard
                        \
                        \   * Bit 7 of IRA will be read from the keyboard

 STA VIA+&4F            \ Set 6522 System VIA output register ORA (SHEILA &4F)
                        \ to A, the key we want to scan for; bits 0-6 will be
                        \ sent to the keyboard, of which bits 0-3 determine the
                        \ keyboard column, and bits 4-6 the keyboard row

 LDX VIA+&4F            \ Read 6522 System VIA output register IRA (SHEILA &4F)
                        \ into X; bit 7 is the only bit that will have changed.
                        \ If the key is pressed, then bit 7 will be set,
                        \ otherwise it will be clear

 LDA #%00001011         \ Set 6522 System VIA output register ORB (SHEILA &40)
 STA VIA+&40            \ to %00001011 to restart auto scan of keyboard

 CLI                    \ Allow interrupts again

 TXA                    \ Transfer X into A

 RTS                    \ Return from the subroutine

ENDIF

\ ******************************************************************************
\
\       Name: RDKEY
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Scan the keyboard for key presses and update the key logger
\
\ ------------------------------------------------------------------------------
\
\ Scan the keyboard, starting with internal key number 16 ("Q") and working
\ through the set of internal key numbers, returning the resulting key press in
\ ASCII. The key logger is also updated.
\
\ This routine is effectively the same as OSBYTE 122, though the OSBYTE call
\ preserves A, unlike this routine.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   X                   If a key is being pressed, X contains the ASCII code
\                       of the key pressed, otherwise it contains 0
\
\   A                   Contains the same as X
\
\   Y                   Y is preserved
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   RDKEY-1             Only scan the keyboard for valid BCD key numbers
\
\ ******************************************************************************

 SED                    \ Set the D flag to enter decimal mode. Because
                        \ internal key numbers are all valid BCD (Binary Coded
                        \ Decimal) numbers, setting this flag ensures we only
                        \ loop through valid key numbers

.RDKEY

 TYA                    \ Store Y on the stack so we can retrieve it later
 PHA

 JSR FILLKL             \ Call FILLKL to scan the keyboard, update the key
                        \ logger and return any non-logger key presses in X

 PLA                    \ Retrieve the value of Y we stored above
 TAY

 LDA TRTB%,X            \ Fetch the internal key number for the key pressed

 STA KL                 \ Store the key pressed in KL

 TAX                    \ Copy the key value into X

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: RDFIRE
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Read the fire button on either the analogue or digital joystick
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              Set if the joystick fire button is being pressed, clear
\                       if it isn't
\
\ ******************************************************************************

IF _COMPACT

.RDFIRE

 LDA MOS                \ If MOS = 0 then this is a Master Compact, so jump to
 BEQ DFIRE              \ DFIRE to read the digital joystick rather than the
                        \ analogue joystick, as the Compact doesn't have the
                        \ latter

 CLC                    \ Clear the C flag

 LDA VIA+&40            \ Read 6522 System VIA input register IRB (SHEILA &40)

 AND #%00010000         \ Bit 4 of IRB (PB4) is clear if joystick 1's fire
                        \ button is pressed, otherwise it is set, so AND'ing
                        \ the value of IRB with %10000 extracts this bit

 BNE P%+3               \ If the joystick fire button is not being pressed,
                        \ jump skip the following to leave the C flag clear

 SEC                    \ Set the C flag to indicate the joystick fire button
                        \ is being pressed

 RTS                    \ Return from the subroutine

.DFIRE

 LDA VIA+&60            \ Read the 6522 User VIA, which is where the Master
                        \ Compact's digital joystick is mapped to. The pins go
                        \ low when the joystick connection is made, and PB0 is
                        \ connected to the joystick fire button, so when PB0
                        \ is low, fire is being pressed

 EOR #%00000001         \ Flip PB0 so that it's 1 if fire is being pressed and
                        \ 0 if it isn't

 LSR A                  \ Shift PB0 into the C flag, so it's set if the fire
                        \ button is being pressed

 RTS                    \ Return from the subroutine

ENDIF

\ ******************************************************************************
\
\       Name: RDJOY
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Read from either the analogue or digital joystick
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              Clear if we just read from the analogue joystick, set if
\                       we just read from the digital joystick
\
\ ******************************************************************************

IF _COMPACT

.RDJOY

 LDA MOS                \ If MOS = 0 then this is a Master Compact, so jump to
 BEQ DIGITAL            \ DIGITAL to read the digital joystick rather than the
                        \ analogue joystick, as the Compact doesn't have the
                        \ latter

 CLC                    \ Clear the C flag to indicate that we are reading from
                        \ the analogue joystick

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

 BNE P%+6               \ If the joystick fire button is not being pressed, skip
                        \ the following to return from the subroutine

 LDA #&FF               \ Update the key logger at KY7 to "press" the "A" (fire)
 STA KY7                \ button

 RTS                    \ Return from the subroutine

.DIGITAL

 LDX #&FF               \ Set X = &FF so we can use it to "press" keys in the
                        \ key logger

 LDA VIA+&60            \ Read the 6522 User VIA, which is where the Master
                        \ Compact's digital joystick is mapped to. The pins go
                        \ low when the joystick connection is made, so we need
                        \ to check whether any of the following are zero:
                        \
                        \   PB0 = fire
                        \   PB1 = left
                        \   PB2 = down
                        \   PB3 = up
                        \   PB4 = right

 LSR A                  \ If PB0 from the User VIA is set (fire button), skip
 BCS P%+4               \ the following

 STX KY7                \ Update the key logger at KY7 to "press" the "A" (fire)
                        \ button

 LSR A                  \ If PB1 from the User VIA is set (left), skip the
 BCS P%+4               \ following

 STX KY3                \ Update the key logger at KY3 to "press" the "<" (roll
                        \ left) button

 LSR A                  \ If PB2 from the User VIA is set (down), skip the
 BCS P%+4               \ following

 STX KY6                \ Update the key logger at KY6 to "press" the "S" (pitch
                        \ down) button
                        \
                        \ Note that this is the opposite key press to the stick
                        \ direction, as in the default configuration, we want to
                        \ pull up when we pull the joystick back (i.e. when the
                        \ stick is down). To fix this, we flip this result below

 LSR A                  \ If PB3 from the User VIA is set (up), skip the
 BCS P%+4               \ following

 STX KY5                \ Update the key logger at KY5 to "press" the "X" (pull
                        \ up) button
                        \
                        \ Note that this is the opposite key press to the stick
                        \ direction, as in the default configuration, we want to
                        \ pitch down when we push the joystick forward (i.e.
                        \ when the stick is up). To fix this, we flip this
                        \ result below

 LSR A                  \ If PB4 from the User VIA is set (right), skip the
 BCS P%+4               \ following

 STX KY4                \ Update the key logger at KY4 to "press" the ">" (roll
                        \ right) button

 LDA JSTE               \ JSTE contains &FF if both joystick channels are
 BEQ DIG1               \ reversed and 0 otherwise, so skip to DIG1 if the
                        \ joystick channels are not reversed

 LDA KY3                \ Both the joystick channels are reversed, so swap the
 LDX KY4                \ values of KY3 and KY4 (to swap the roll)
 STX KY3
 STA KY4

.DIG1

 LDA JSTE               \ Set A to &FF if both joystick channels are reversed
                        \ and 0 otherwise

 EOR JSTGY              \ JSTGY will be 0 if the game is configured to reverse
                        \ the joystick Y channel, &FF otherwise, so A will be
                        \ 0 if one of these is true:
                        \
                        \  * Both channels are normal and Y is reversed
                        \  * Both channels are reversed and Y is not
                        \
                        \ i.e. it will be 0 if the Y channel is configured to be
                        \ reversed

 BEQ DIG2               \ If the result in A is 0, skip the following to leave
                        \ the Y channel alone, as we already set the pitch keys
                        \ above to the opposite direction to the stick

                        \ If we get here, then the configuration settings are
                        \ not set to reverse the Y channel, so we now swap KY5
                        \ and KY6 around, as we set the pitch keys above to the
                        \ opposite direction to the stick

 LDA KY5                \ The Y channel should be reversed, so swap the values
 LDX KY6                \ of KY5 and KY6 (to swap the pitch)
 STX KY5
 STA KY6

.DIG2

 SEC                    \ Set the C flag to indicate that we just read the
                        \ digital joystick

 RTS                    \ Return from the subroutine

ENDIF

\ ******************************************************************************
\
\       Name: TT17X
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Scan the digital joystick for movement
\
\ ------------------------------------------------------------------------------
\
\ Scan the digital joystick for stick movement, and return the result as deltas
\ (changes) in x- and y-coordinates as follows:
\
\   * For joystick, X and Y are integers between -2 and +2 depending on how far
\     the stick has moved
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   X                   Change in the x-coordinate according to the joystick
\                       movement, as an integer (see above)
\
\   Y                   Change in the y-coordinate according to the joystick
\                       movement, as an integer (see above)
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   TT17X-1             Contains an RTS
\
\ ******************************************************************************

IF _COMPACT

.TT17X

 LDA VIA+&60            \ Read the 6522 User VIA, which is where the Master
                        \ Compact's digital joystick is mapped to. The pins go
                        \ low when the joystick connection is made, so we need
                        \ to check whether any of the following are zero:
                        \
                        \   PB0 = fire
                        \   PB1 = left
                        \   PB2 = down
                        \   PB3 = up
                        \   PB4 = right

 LSR A                  \ Shift the PB0 bit out, as we aren't interested in the
                        \ fire button in this routine

 LDX #0                 \ Set the initial values for the results, X = Y = 0,
 LDY #0                 \ which we now increase or decrease appropriately

 LSR A                  \ If PB1 from the User VIA is set (left), skip the
 BCS P%+3               \ following

 DEX                    \ Set X = X - 1

 LSR A                  \ If PB2 from the User VIA is set (down), skip the
 BCS P%+3               \ following

 INY                    \ Set Y = Y + 1
                        \
                        \ Note that this is the opposite direction to the stick
                        \ direction, as moving the stick down should decrease Y.
                        \ To fix this, we flip this result below

 LSR A                  \ If PB3 from the User VIA is set (up), skip the
 BCS P%+3               \ following

 DEY                    \ Set Y = Y - 1
                        \
                        \ Note that this is the opposite direction to the stick
                        \ direction, as moving the stick up should increase Y.
                        \ To fix this, we flip this result below

 LSR A                  \ If PB4 from the User VIA is set (right), skip the
 BCS P%+3               \ following

 INX                    \ Set X = X + 1

 LDA JSTE               \ JSTE contains &FF if both joystick channels are
 BEQ TT171              \ reversed and 0 otherwise, so skip to TT171 if the
                        \ joystick channels are not reversed

 TXA                    \ The X channel needs to be reversed, so negate the
 EOR #&FF               \ value in X, using two's complement
 CLC
 ADC #1
 TAX

.TT171

 LDA JSTE               \ Set A to &FF if both joystick channels are reversed
                        \ and 0 otherwise

 EOR JSTGY              \ JSTGY will be 0 if the game is configured to reverse
                        \ the joystick Y channel, &FF otherwise, so A will be
                        \ 0 if one of these is true:
                        \
                        \  * Both channels are normal and Y is reversed
                        \  * Both channels are reversed and Y is not
                        \
                        \ i.e. it will be 0 if the Y channel is configured to be
                        \ reversed

 BEQ TT17X-1            \ If the result in A is 0, return from the subroutine
                        \ (as TT17X-1 contain an RTS), as we already set the Y
                        \ value above to the opposite direction to the stick

                        \ If we get here, then the configuration settings are
                        \ not set to reverse the Y channel, so we now negate the
                        \ Y value, as we set Y above to the opposite direction
                        \ to the stick

 TYA                    \ The Y channel should be reversed, so negate the value
 EOR #&FF               \ in Y, using two's complement
 CLC
 ADC #1
 TAY

                        \ Fall through into yetanotherrts to return from the
                        \ subroutine

ENDIF

\ ******************************************************************************
\
\       Name: yetanotherrts
\       Type: Subroutine
\   Category: Tactics
\    Summary: Contains an RTS
\
\ ------------------------------------------------------------------------------
\
\ This routine contains an RTS so we can return from the SFRMIS subroutine with
\ a branch instruction.
\
\ It also contains the DEMON label, which is left over from the 6502 Second
\ Processor version, where it implements the demo (there is no demo in this
\ version of Elite).
\
\ ******************************************************************************

.yetanotherrts

.DEMON

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: ECMOF
\       Type: Subroutine
\   Category: Dashboard
\    Summary: Switch off the E.C.M. and turn off the dashboard bulb
\
\ ******************************************************************************

.ECMOF

IF _SNG47

 LDA #0                 \ Set ECMA and ECMP to 0 to indicate that no E.C.M. is
 STA ECMA               \ currently running
 STA ECMP

ELIF _COMPACT

 STZ ECMA               \ Set ECMA and ECMP to 0 to indicate that no E.C.M. is
 STZ ECMP               \ currently running

ENDIF

 JMP ECBLB              \ Update the E.C.M. indicator bulb on the dashboard and
                        \ return from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: SFRMIS
\       Type: Subroutine
\   Category: Tactics
\    Summary: Add an enemy missile to our local bubble of universe
\
\ ------------------------------------------------------------------------------
\
\ An enemy has fired a missile, so add the missile to our universe if there is
\ room, and if there is, make the appropriate warnings and noises.
\
\ ******************************************************************************

.SFRMIS

 LDX #MSL               \ Set X to the ship type of a missile, and call SFS1-2
 JSR SFS1-2             \ to add a missile to our universe that has AI (bit 7
                        \ set), is hostile (bit 6 set) and has been launched
                        \ (bit 0 clear); the target slot number is set to 31,
                        \ but this is ignored as the hostile flags means we
                        \ are the target

IF _SNG47

 BCC yetanotherrts      \ The C flag will be set if the call to SFS1-2 was a
                        \ success, so if it's clear, jump to yetanotherrts to
                        \ return from the subroutine (as yetanotherrts contains
                        \ an RTS)

ELIF _COMPACT

 BCC TT17X-1            \ The C flag will be set if the call to SFS1-2 was a
                        \ success, so if it's clear, jump to TT17X-1 to return
                        \ from the subroutine (as TT17X-1 contains an RTS)

ENDIF

 LDA #120               \ Print recursive token 120 ("INCOMING MISSILE") as an
 JSR MESS               \ in-flight message

 LDY #solaun            \ Call the NOISE routine with Y = 8 to make the sound
 JMP NOISE              \ of the missile being launched and return from the
                        \ subroutine using a tail call

\ ******************************************************************************
\
\       Name: EXNO2
\       Type: Subroutine
\   Category: Status
\    Summary: Process us making a kill
\  Deep dive: Combat rank
\
\ ------------------------------------------------------------------------------
\
\ We have killed a ship, so increase the kill tally, displaying an iconic
\ message of encouragement if the kill total is a multiple of 256, and then
\ make a nearby explosion sound.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The type of the ship that was killed
\
\ ******************************************************************************

.EXNO2

 LDA TALLYL             \ We now add the fractional kill count to our tally,
 CLC                    \ starting with the fractional bytes:
 ADC KWL%-1,X           \
 STA TALLYL             \   TALLYL = TALLYL + fractional kill count
                        \
                        \ where the fractional kill count is taken from the
                        \ KWL% table, according to the ship's type (we look up
                        \ the X-1-th value from KWL% because ship types start
                        \ at 1 rather than 0)

 LDA TALLY              \ And then we add the low byte of TALLY(1 0):
 ADC KWH%-1,X           \
 STA TALLY              \   TALLY = TALLY + carry + integer kill count
                        \
                        \ where the integer kill count is taken from the KWH%
                        \ table in the same way

 BCC davidscockup       \ If there is no carry, jump to davidscockup to skip the
                        \ following three instructions, as we have not earned
                        \ a "RIGHT ON COMMANDER!" message

 INC TALLY+1            \ Increment the high byte of the kill count in TALLY

 LDA #101               \ The kill total is a multiple of 256, so it's time
 JSR MESS               \ for a pat on the back, so print recursive token 101
                        \ ("RIGHT ON COMMANDER!") as an in-flight message

.davidscockup

                        \ Fall through into EXNO3 to make the sound of a
                        \ ship exploding

\ ******************************************************************************
\
\       Name: EXNO3
\       Type: Subroutine
\   Category: Sound
\    Summary: Make an explosion sound
\
\ ------------------------------------------------------------------------------
\
\ Make the sound of death in the cold, hard vacuum of space. Apparently, in
\ Elite space, everyone can hear you scream.
\
\ This routine also makes the sound of a destroyed cargo canister if we don't
\ get scooping right, the sound of us colliding with another ship, and the sound
\ of us being hit with depleted shields. It is not a good sound to hear.
\
\ ******************************************************************************

.EXNO3

 LDY #soexpl            \ Call the NOISE routine with Y = 4 to make the sound of
 JMP NOISE              \ an explosion and return from the subroutine using a
                        \ tail call

\ ******************************************************************************
\
\       Name: EXNO
\       Type: Subroutine
\   Category: Sound
\    Summary: Make the sound of a laser strike on another ship or a ship
\             explosion
\
\ ------------------------------------------------------------------------------
\
\ Make the two-part explosion sound of us making a laser strike, or of another
\ ship exploding.
\
\ ******************************************************************************

.EXNO

 LDY #sohit             \ Call the NOISE routine with Y = 6 to make the sound of
 JMP NOISE              \ us making a hit or kill and return from the subroutine
                        \ using a tail call

\ ******************************************************************************
\
\       Name: NMIpissoff
\       Type: Subroutine
\   Category: Loader
\    Summary: Acknowledge NMI interrupts and ignore them
\
\ ******************************************************************************

                        \ Port: removed (it was never reached and nothing
                        \ refers to it), to make room in the main code

\ ******************************************************************************
\
\       Name: F%
\       Type: Variable
\   Category: Utility routines
\    Summary: Denotes the end of the main game code, from ELITE A to ELITE H
\
\ ******************************************************************************

 INCLUDE "src/elite-flight.asm" \ Port: flight code moved back from bank 4

.F%

 SKIP 0

IF _COMPACT

 EQUB &F8, &F8          \ These bytes appear to be unused
 EQUB &F8, &F8
 EQUB &F8, &F8
 EQUB &F8, &F8
 EQUB &F8, &F8
 EQUB &F8, &F8
 EQUB &F8, &F8
 EQUB &F8, &F8
 EQUB &F8, &F8
 EQUB &F8

ENDIF

\ ******************************************************************************
\
\ Save ELTH.bin
\
\ ******************************************************************************

 PRINT "ELITE H"
 PRINT "Assembled at ", ~CODE_H%
 PRINT "Ends at ", ~P%
 PRINT "Code size is ", ~(P% - CODE_H%)
 PRINT "Execute at ", ~LOAD%
 PRINT "Reload at ", ~LOAD_H%

 PRINT "S.ELTH ", ~CODE_H%, " ", ~P%, " ", ~LOAD%, " ", ~LOAD_H%
\SAVE "build/ELTH.bin", CODE_G%, P%, LOAD%

 ASSERT P% <= &4000     \ Port: the main code ends below &4000. Main RAM &4000-&6FFF
                        \ is screen buffer A in the final map and &7000-&7DFF the
                        \ dashboard (docs/MASTER-MAP.md), so nothing of the game
                        \ may live there

\ ******************************************************************************
\
\ Save BCODE.unprot.bin
\
\ ******************************************************************************

 PRINT "S.BCODE ", ~CODE%, " ", ~P%, " ", ~LOAD%, " ", ~LOAD%
 SAVE "build/BCODE.unprot.bin", CODE%, P%, LOAD%

\ ******************************************************************************
\
\ Port: the stubs into the cold area, in main RAM at &7E00-&7FFF (above the
\ dashboard, docs/MASTER-MAP.md). They are called only by game code, never
\ while ACCCON X is set (which hides main RAM there). Saved as STUBS, which
\ the loader copies there.
\
\ ******************************************************************************

 ORG &0840

 INCLUDE "src/elite-low.asm"        \ game code at &0840-&0CFF

.LOW_END%

 PRINT "Low code: &0840-", ~LOW_END%-1, " free ", &0D00-LOW_END%
 ASSERT LOW_END% <= &0D00           \ page &0D is off limits (docs/MASTER-MEMORY.md)
 SAVE "build/LOWCODE.bin", &0840, LOW_END%, &0840

 ORG &7200

 INCLUDE "src/elite-hi.asm"         \ renderer stubs and hooks, &7200-&7DFF

.HI_END%

 PRINT "Hi code: &7200-", ~HI_END%-1, " free ", &7E00-HI_END%
 ASSERT HI_END% <= &7E00
 SAVE "build/HICODE.bin", &7200, HI_END%, &7200

 ORG &7E00

 INCLUDE "src/elite-stubs7.asm"     \ stubs into the cold area (far7, far7j)

.STUBS_END%

 PRINT "Stubs: &7E00-", ~STUBS_END%-1, " free ", &8000-STUBS_END%
 ASSERT STUBS_END% <= &8000
 SAVE "build/STUBS.bin", &7E00, &8000, &7E00

\ ******************************************************************************
\
\ Port: sideways RAM bank 4, Elite's home bank (docs/MASTER-MAP.md)
\
\ The game data that elite-data.asm assembles for bank 4 (build/BANK4D.bin:
\ blueprints and their tables, the tokens, SNE, ACT), then the game code
\ that lives in bank 4 (elite-bank4.asm). Saved as the whole bank, which the
\ loader copies to sideways RAM bank HOMEBANK.
\
\ ******************************************************************************

 CLEAR &8000, &C000
 ORG &8000

 INCBIN "build/BANK4D.bin"

 INCLUDE "src/elite-bank4.asm"

.BANK4_END%

 PRINT "Bank 4: &8000-", ~BANK4_END%-1, " free ", &C000-BANK4_END%
 SAVE "build/BANK4.bin", &8000, &C000, &8000

\ ******************************************************************************
\
\ Port: the cold area (docs/MASTER-MAP.md), paged in as ROMSEL = COLDBANK
\ (&87): ANDY at &8000-&8FFF (elite-andy.asm) and sideways RAM bank 7 from
\ &AC40 (QQ18 from elite-data.asm, the stubs that lead out of the cold area,
\ then elite-cold7.asm).
\ Bank 7 below &AC40 is kept for the renderer's cold code.
\
\ ******************************************************************************

 CLEAR &8000, &C000
 ORG &8000

 INCLUDE "src/elite-andy.asm"

.ANDY_END%

 PRINT "ANDY: &8000-", ~ANDY_END%-1, " free ", &9000-ANDY_END%
 ASSERT ANDY_END% <= &9000
 SAVE "build/ANDY.bin", &8000, &9000, &8000

 CLEAR &8000, &C000
 ORG &AC40

 INCBIN "build/QQ18D.bin"           \ QQ18, the recursive token table

 INCLUDE "src/elite-coldstubs.asm"  \ stubs out of the cold area (far4, far4j)

 INCLUDE "src/elite-cold7.asm"

.COLD7_END%

 PRINT "Bank 7 cold: &AC40-", ~COLD7_END%-1, " free ", &C000-COLD7_END%
 SAVE "build/COLD7.bin", &AC40, &C000, &AC40

 PRINT "Addresses for the scramble routines in elite-checksum.py"
 PRINT "F% = ", ~F%
 PRINT "G% = ", ~G%
 PRINT "NA2% = ", ~NA2%

 INCLUDE "src/elite-gfx.asm"      \ Port: the filled renderer (HAZEL, banks 5 and 6, bank 7 below &AC40)
