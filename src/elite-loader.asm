\ ******************************************************************************
\
\ ELITE DEMONSTRATION DISC, BBC MASTER PORT: LOADER
\
\ The Acornsoft Elite Demonstration Disc was written by Ian Bell and David
\ Braben and is copyright Acornsoft 1984. This loader replaces the cassette
\ loader (elite-loader.asm in src/orig), which contains copy protection, MOS 1.20
\ specifics and a mode 4/5 screen setup that don't apply to the BBC Master.
\
\ ------------------------------------------------------------------------------
\
\ This loader is run by !BOOT (*RUN ELITE). It does the following:
\
\   * Sets up the MOS as the cassette loader does (OSBYTE settings, sound
\     envelopes, NMI release)
\
\   * Selects a non-shadow MODE 1 and reprograms the 6845 CRTC to give the
\     BBC Master Elite screen geometry: a 256-pixel wide MODE 1 screen at
\     &4000, 31 character rows in all (R1 = 64, R2 = 90, R6 = 31, R12/R13 =
\     &0800): the space view (24 rows) and the dashboard at &7000 (7 rows),
\     both MODE 1 in one CMYK palette, which is set here once
\
\   * Clears ACCCON bits D, E and X, so main RAM is displayed and accessed at
\     &3000 to &7FFF (the screen is in main RAM in this port)
\
\   * Loads WORDS9 to &0400, the sideways RAM image to bank 4 (*SRLOAD) and
\     the MODE 1 dashboard image to &7000 (and, if DASHDUAL, copies it to
\     shadow RAM too)
\
\   * Copies the second stage to &7E00 (which isn't displayed) and runs it, as
\     the main game code loads over this first stage. The second stage loads
\     the main code to &0F40, sets up the interrupts and vectors from the S%
\     table at the start of the game code (IRQ1V, WRCHV, BRKV), points TRTB% at
\     the keyboard translation table (TRTBL) in the game code, pages in bank 4
\     permanently (ROMSEL and its RAM copy at &F4) and starts the game
\
\ ******************************************************************************

 CPU 1                  \ The BBC Master has a 65C02

 CODE% = &1100          \ The loader is loaded and run at &1100

 STAGE2% = &7E00        \ The second stage runs at &7E00, which is in main RAM
                        \ just after the dashboard and isn't displayed

 S% = &0F40             \ The address of the S% vector table at the start of the
                        \ main game code (TT170, TT26, IRQ1, BR1)

 VEC = &0F39            \ Where the game stores the original IRQ1V vector, so
                        \ IRQ1 can pass interrupts on to the MOS

 SVN = &0F3B            \ The game's "saving in progress" flag

 TRTB% = &0004          \ The game's pointer to the keyboard translation table

 \ TRTBL               The address of the keyboard translation table in the
                        \ game code is passed in by build.sh (beebasm -D)

 VSCAN = 57             \ The split position in the split-screen mode (as in the
                        \ game)

 HZIMG = &BB00          \ Where bank 6 carries the HAZEL code image (as in
                        \ gfx-build.asm)

 ROMBANK = 4            \ The sideways RAM bank that holds the rest of the game

 VIA = &FE00            \ Memory-mapped hardware (SHEILA)

 ROMSEL = &FE30         \ The paged ROM select register

 ACCCON = &FE34         \ The BBC Master access control register

 ROMSELCOPY = &F4       \ The MOS's RAM copy of ROMSEL

 BRKV = &0202           \ The BRK vector

 IRQ1V = &0204          \ The IRQ1 vector

 WRCHV = &020E          \ The OSWRCH vector

 OSWRCH = &FFEE         \ MOS entry points
 OSWORD = &FFF1
 OSBYTE = &FFF4
 OSCLI = &FFF7

 ORG &0070              \ Zero page workspace for the loader

.ZP

 SKIP 2

 ORG CODE%

 JMP ENTRY              \ The loader is run from &1100, so jump over the data

\ ******************************************************************************
\
\       Name: E%
\       Type: Variable
\   Category: Sound
\    Summary: Sound envelope definitions (from the cassette loader)
\
\ ******************************************************************************

.E%

 EQUB 1, 1, 0, 111, -8, 4, 1, 8, 8, -2, 0, -1, 112, 44
 EQUB 2, 1, 14, -18, -1, 44, 32, 50, 6, 1, 0, -2, 120, 126
 EQUB 3, 1, 1, -1, -3, 17, 32, 128, 1, 0, 0, -1, 1, 1
 EQUB 4, 1, 4, -8, 44, 4, 6, 8, 22, 0, 0, -127, 126, 0

 ASSERT HI(E%) = HI(P% - 1)

\ ******************************************************************************
\
\       Name: ENTRY
\       Type: Subroutine
\   Category: Loader
\    Summary: The first stage of the loader
\
\ ******************************************************************************

.ENTRY

 CLD                    \ Make sure we are not in decimal mode

 LDX #0                 \ Run through the OSBYTE table at OSBTAB, calling OSBYTE
                        \ with each A, X, Y triple in turn

.ENT1

 LDA OSBTAB,X           \ Fetch the next OSBYTE call from the table, stopping
 BEQ ENT2               \ when we reach the zero at the end
 PHX
 LDY OSBTAB+2,X
 PHA
 LDA OSBTAB+1,X
 TAX
 PLA
 JSR OSBYTE
 PLX
 INX
 INX
 INX
 BRA ENT1

.ENT2

 LDY #0                 \ Send the VDU sequence in B% to OSWRCH, which selects
                        \ MODE 1 and reprograms the CRTC

.ENT3

 LDA B%,Y
 JSR OSWRCH
 INY
 CPY #BLEN
 BNE ENT3

 LDA ACCCON             \ Clear bits 0 to 2 of ACCCON (D, E and X), so the main
 AND #%11111000         \ RAM screen is displayed and main RAM is accessed by
 STA ACCCON             \ the CPU at &3000 to &7FFF

 SEI                    \ Set the Video ULA for the whole screen, once: MODE 1
 LDA #%00011000         \ with no cursor, and the CMYK palette (logical colours
 STA VIA+&20            \ 0-3 = black, cyan, magenta, yellow). The game's IRQ
 LDX #15                \ handler no longer changes the mode or palette
.ENTP
 LDA PALT,X
 STA VIA+&21
 DEX
 BPL ENTP
 CLI

 LDA #LO(E%)            \ Define the four sound envelopes that the game uses
 STA ZP                 \ (the same as the cassette loader's E% table), using
                        \ ZP as a pointer to each envelope in turn

.ENT4

 LDX ZP                 \ Call OSWORD 8 with (Y X) pointing to the envelope
 LDY #HI(E%)
 LDA #8
 JSR OSWORD

 LDA ZP                 \ Move on to the next envelope
 CLC
 ADC #14
 STA ZP

 CMP #LO(E% + 4 * 14)   \ Loop back until we have done all four
 BNE ENT4

 LDX #LO(MESS1)         \ *LOAD WORDS9 (to &0400)
 LDY #HI(MESS1)
 JSR OSCLI

 LDX #LO(MESS2)         \ *SRLOAD ELTBANK 8000 4, to load the rest of the game
 LDY #HI(MESS2)         \ into sideways RAM bank 4
 JSR OSCLI

 LDX #LO(MESS5)         \ *SRLOAD BANK5 8000 5: the rasteriser
 LDY #HI(MESS5)
 JSR OSCLI

 LDX #LO(MESS6)         \ *SRLOAD BANK6 8000 6: the frame layer and HAZEL image
 LDY #HI(MESS6)
 JSR OSCLI

 LDX #LO(MESS7)         \ *SRLOAD BANK7 8000 7: the rasteriser's second bank
 LDY #HI(MESS7)
 JSR OSCLI

 LDX #LO(MESS3)         \ *LOAD DIALS 7000, to load the MODE 1 dashboard
 LDY #HI(MESS3)         \ image (tools/dashboard.py)
 JSR OSCLI

IF DASHDUAL

 LDA #&70               \ Copy the dashboard (&7000-&7DFF) to shadow RAM too,
 STA DCP1+2             \ a page at a time through a buffer at &2000 (below
 STA DCP3+2             \ &3000, so not switched by ACCCON X)

.DCP0

 LDX #0

.DCP1

 LDA &7000,X
 STA &2000,X
 INX
 BNE DCP1

 SEI
 LDA ACCCON             \ X = 1: shadow RAM at &3000-&7FFF
 ORA #%00000100
 STA ACCCON

.DCP2

 LDA &2000,X

.DCP3

 STA &7000,X
 INX
 BNE DCP2

 LDA ACCCON             \ X = 0: main RAM
 AND #%11111011
 STA ACCCON
 CLI

 INC DCP1+2
 INC DCP3+2
 LDA DCP3+2
 CMP #&7E
 BNE DCP0

ENDIF

 LDX #0                 \ Copy the second stage to STAGE2%

.ENT5

 LDA STAGE2SRC,X
 STA STAGE2%,X
 INX
 BNE ENT5

 JMP STAGE2%            \ Run the second stage

\ ******************************************************************************
\
\       Name: PALT
\       Type: Variable
\   Category: Loader
\    Summary: The MODE 1 palette (Video ULA palette register values)
\
\ ------------------------------------------------------------------------------
\
\ Each byte is (palette index * 16) + (physical colour EOR 7). In MODE 1, the
\ index of a pixel of logical colour %ab is %a?b?, so logical colour 0 = black,
\ 1 = cyan (6), 2 = magenta (5), 3 = yellow (3).
\
\ ******************************************************************************

.PALT

 EQUB &07, &17, &21, &31, &47, &57, &61, &71
 EQUB &82, &92, &A4, &B4, &C2, &D2, &E4, &F4

\ ******************************************************************************
\
\       Name: OSBTAB
\       Type: Variable
\   Category: Loader
\    Summary: OSBYTE calls to make (A, X, Y), as done by the cassette and BBC
\             Master loaders
\
\ ******************************************************************************

.OSBTAB

 EQUB 16, 0, 0          \ Disable ADC channels (as in BBC Master Elite)
 EQUB 13, 0, 0          \ Disable the "output buffer empty" event
 EQUB 13, 2, 0          \ Disable the "character entering buffer" event
 EQUB 225, 128, 0       \ Function keys return codes &80 onwards
 EQUB 4, 1, 0           \ Cursor keys return codes
 EQUB 9, 0, 0           \ Disable flashing colours
 EQUB 247, 0, 0         \ Disable the BREAK intercept
 EQUB 190, 8, 0         \ 8-bit ADC conversions
 EQUB 114, 1, 0         \ Don't use shadow RAM on the next mode change
 EQUB 144, 255, 0       \ *TV 255, 0 (as in BBC Master Elite)
 EQUB 0

\ ******************************************************************************
\
\       Name: B%
\       Type: Variable
\   Category: Loader
\    Summary: VDU commands for setting up the BBC Master Elite screen mode
\
\ ------------------------------------------------------------------------------
\
\ These are the same as in the BBC Master Elite loader, except we select MODE 1
\ rather than MODE 129, as this port keeps the screen in main RAM.
\
\ ******************************************************************************

.B%

 EQUB 22, 1             \ Switch to screen mode 1 (non-shadow)

 EQUB 28                \ Define a text window as follows:
 EQUB 2, 17, 15, 16     \
                        \   * Left = 2
                        \   * Right = 15
                        \   * Top = 16
                        \   * Bottom = 17
                        \
                        \ So any MOS text output is confined to a small area

 EQUB 23, 0, 6, 31      \ Set 6845 register R6 = 31
 EQUB 0, 0, 0           \
 EQUB 0, 0, 0           \ This is the "vertical displayed" register, which sets
                        \ the number of rows shown on screen to 31

 EQUB 23, 0, 12, &08    \ Set 6845 register R12 = &08 and R13 = &00
 EQUB 0, 0, 0           \
 EQUB 0, 0, 0           \ This sets 6845 registers (R12 R13) = &0800 to point
 EQUB 23, 0, 13, &00    \ to the start of screen memory in terms of character
 EQUB 0, 0, 0           \ rows, so the screen starts at &0800 * 8 = &4000
 EQUB 0, 0, 0

 EQUB 23, 0, 1, 64      \ Set 6845 register R1 = 64
 EQUB 0, 0, 0           \
 EQUB 0, 0, 0           \ This is the "horizontal displayed" register, which
                        \ defines the number of character blocks per horizontal
                        \ character row, so this gives 256 mode 1 pixels

 EQUB 23, 0, 2, 90      \ Set 6845 register R2 = 90
 EQUB 0, 0, 0           \
 EQUB 0, 0, 0           \ This is the "horizontal sync position" register, which
                        \ centres the narrower screen

 EQUB 23, 0, 10, 32     \ Set 6845 register R10 = %00100000 = 32
 EQUB 0, 0, 0           \
 EQUB 0, 0, 0           \ This turns the cursor off

 BLEN = P% - B%

\ ******************************************************************************
\
\       Name: MESS1, MESS2, MESS3
\       Type: Variable
\   Category: Loader
\    Summary: The commands used by the first stage to load the game
\
\ ******************************************************************************

.MESS1

 EQUS "LOAD WORDS9"
 EQUB 13

.MESS2

 EQUS "SRLOAD ELTBANK 8000 4"
 EQUB 13

.MESS5
 EQUS "SRLOAD BANK5 8000 5"
 EQUB 13

.MESS6
 EQUS "SRLOAD BANK6 8000 6"
 EQUB 13

.MESS7
 EQUS "SRLOAD BANK7 8000 7"
 EQUB 13

.MESS3

 EQUS "LOAD DIALS 7000"
 EQUB 13

\ ******************************************************************************
\
\       Name: STAGE2
\       Type: Subroutine
\   Category: Loader
\    Summary: The second stage of the loader, which runs at &7E00
\
\ ******************************************************************************

.STAGE2SRC

 ORG STAGE2%

.STAGE2

 LDX #LO(MESS4)         \ *LOAD ELTMAIN, to load the main game code to &0F40
 LDY #HI(MESS4)         \ (this overwrites the first stage of the loader)
 JSR OSCLI

 LDA #143               \ Issue paged ROM service call &C (NMI claim), so the
 LDX #&C                \ disc filing system releases the NMI workspace at &0D00
 LDY #&FF               \ (which the game uses), as the cassette loader does
 JSR OSBYTE

 LDA #200               \ Disable the ESCAPE key and clear memory if the BREAK
 LDX #3                 \ key is pressed, as the cassette loader does
 LDY #0
 JSR OSBYTE

 SEI                    \ Disable interrupts while we set up the vectors

 LDA #%01111111         \ Disable all interrupts from the System VIA and User
 STA VIA+&4E            \ VIA, as the cassette loader does
 STA VIA+&6E

 LDA #%11000010         \ Enable the System VIA's timer 1 and vertical sync
 STA VIA+&4E            \ (CA1) interrupts, which IRQ1 uses for the split
                        \ screen, as the cassette loader does

 LDA IRQ1V              \ Store the current IRQ1V vector in VEC, so the game's
 STA VEC                \ IRQ1 handler can pass interrupts on to the MOS
 LDA IRQ1V+1
 STA VEC+1

 LDA S%+4               \ Point IRQ1V to IRQ1 (the third entry in S%)
 STA IRQ1V
 LDA S%+5
 STA IRQ1V+1

 LDA S%+2               \ Point WRCHV to TT26 (the second entry in S%)
 STA WRCHV
 LDA S%+3
 STA WRCHV+1

 LDA S%+6               \ Point BRKV to BR1 (the fourth entry in S%)
 STA BRKV
 LDA S%+7
 STA BRKV+1

 LDA #VSCAN             \ Start the System VIA's timer 1 counting down, as the
 STA VIA+&45            \ cassette loader does

 LDA #0                 \ Set SVN = 0 (not saving), as the cassette loader does
 STA SVN

 LDA #LO(TRTBL)         \ Point TRTB%(1 0) at the keyboard translation table,
 STA TRTB%              \ as the cassette loader does using OSBYTE 172 (we use
 LDA #HI(TRTBL)         \ the copy of the MOS 3.20 table in the game code)
 STA TRTB%+1

 LDA #ROMBANK           \ Page in sideways RAM bank 4 permanently, setting both
 STA ROMSELCOPY         \ ROMSEL and the MOS's copy of it at &F4, so the MOS
 STA ROMSEL             \ keeps it paged in

 LDA ACCCON             \ Make sure ACCCON bits D, E and X are clear, so main
 AND #%11110000         \ RAM is displayed and accessed at &3000 to &7FFF, and
 ORA #%00001000         \ set bit Y so HAZEL (&C000-&DFFF) is RAM from now on
 STA ACCCON             \ (the MOS doesn't touch &C000-&DFFF during the game)

 LDA #6                 \ Copy the HAZEL image from bank 6 (HZIMG) to &C000
 STA ROMSEL             \ and clear the rest of HAZEL
 LDX #0
.HZC1
 FOR I%, 0, (HZLEN-1) DIV 256
  LDA HZIMG + I% * 256,X
  STA &C000 + I% * 256,X
 NEXT
 INX
 BNE HZC1

 LDA #ROMBANK           \ Back to bank 4
 STA ROMSEL

 JSR GINIT              \ Initialise the frame layer and rasteriser

 CLI                    \ Re-enable interrupts

 JMP (S%)               \ Start the game by jumping to the address in the first
                        \ entry in S% (TT170)

.MESS4

 EQUS "LOAD ELTMAIN"
 EQUB 13

.STAGE2END

 ASSERT STAGE2END - STAGE2 <= 256

 COPYBLOCK STAGE2, STAGE2END, STAGE2SRC

 ORG STAGE2SRC + (STAGE2END - STAGE2)

.LOADEREND

 SAVE "build/ELITE.bin", CODE%, LOADEREND, CODE%, CODE%
