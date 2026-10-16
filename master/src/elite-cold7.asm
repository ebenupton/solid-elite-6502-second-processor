\ ******************************************************************************
\
\ elite-cold7.asm - cold code in bank 7 (&AC40-&BFFF)
\
\ Port (docs/MASTER-MAP.md, master/src/elite-far.asm): the second part of the
\ cold area, paged in as ROMSEL = &87, above the space kept for the
\ renderer's cold code. Labels have the suffix _C, as in elite-andy.asm.
\ ******************************************************************************

\ ******************************************************************************
\
\       Name: MT27
\       Type: Subroutine
\   Category: Text
\    Summary: Print the captain's name during mission briefings
\  Deep dive: Extended text tokens
\             The Constrictor mission
\
\ ------------------------------------------------------------------------------
\
\ This routine prints the following tokens, depending on the galaxy number:
\
\   * Token 217 ("CURRUTHERS") in galaxy 0
\
\   * Token 218 ("FOSDYKE SMYTHE") in galaxy 1
\
\   * Token 219 ("FORTESQUE") in galaxy 2
\
\ This is used when printing extended token 213 as part of the mission
\ briefings, which looks like this when printed:
\
\   Commander {commander name}, I am Captain {mission captain's name} of Her
\   Majesty's Space Navy
\
\ where {mission captain's name} is replaced by one of the names above.
\
\ ******************************************************************************

.MT27_C

 LDA #217               \ Set A = 217, so when we fall through into MT28, the
                        \ 217 gets added to the current galaxy number, so the
                        \ extended token that is printed is 217-219 (as this is
                        \ only called in galaxies 0 through 2)

 BNE P%+4               \ Skip the next instruction

\ ******************************************************************************
\
\       Name: MT28
\       Type: Subroutine
\   Category: Text
\    Summary: Print the location hint during the mission 1 briefing
\  Deep dive: Extended text tokens
\             The Constrictor mission
\
\ ------------------------------------------------------------------------------
\
\ This routine prints the following tokens, depending on the galaxy number:
\
\   * Token 220 ("WAS LAST SEEN AT {single cap}REESDICE") in galaxy 0
\
\   * Token 221 ("IS BELIEVED TO HAVE JUMPED TO THIS GALAXY") in galaxy 1
\
\ This is used when printing extended token 10 as part of the mission 1
\ briefing, which looks like this when printed:
\
\   It went missing from our ship yard on Xeer five months ago and {mission 1
\   location hint}
\
\ where {mission 1 location hint} is replaced by one of the names above.
\
\ ******************************************************************************

.MT28_C

 LDA #220               \ Set A = galaxy number in GCNT + 220, which is in the
 CLC                    \ range 220-221, as this is only called in galaxies 0
 ADC GCNT               \ and 1

 BNE DETOK_C              \ Jump to DETOK to print extended token 220-221,
                        \ returning from the subroutine using a tail call (this
                        \ BNE is effectively a JMP as A is never zero)

\ ******************************************************************************
\
\       Name: DETOK3
\       Type: Subroutine
\   Category: Text
\    Summary: Print an extended recursive token from the RUTOK token table
\  Deep dive: Extended system descriptions
\             Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The recursive token to be printed, in the range 0-255
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   A is preserved
\
\   Y                   Y is preserved
\
\   V(1 0)              V(1 0) is preserved
\
\ ******************************************************************************

.DETOK3_C

 PHA                    \ Store A on the stack, so we can retrieve it later

 TAX                    \ Copy the token number from A into X

 TYA                    \ Store Y on the stack
 PHA

 LDA V                  \ Store V(1 0) on the stack
 PHA
 LDA V+1
 PHA

 LDA #LO(RUTOK)         \ Set V to the low byte of RUTOK
 STA V

 LDA #HI(RUTOK)         \ Set A to the high byte of RUTOK

 BNE DTEN_C               \ Call DTEN to print token number X from the RUTOK
                        \ table and restore the values of A, Y and V(1 0) from
                        \ the stack, returning from the subroutine using a tail
                        \ call (this BNE is effectively a JMP as A is never
                        \ zero)

\ ******************************************************************************
\
\       Name: DETOK
\       Type: Subroutine
\   Category: Text
\    Summary: Print an extended recursive token from the TKN1 token table
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The recursive token to be printed, in the range 1-255
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   A is preserved
\
\   Y                   Y is preserved
\
\   V(1 0)              V(1 0) is preserved
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   DTEN                Print recursive token number X from the token table
\                       pointed to by (A V), used to print tokens from the RUTOK
\                       table via calls to DETOK3
\
\ ******************************************************************************

.DETOK_C

 PHA                    \ Store A on the stack, so we can retrieve it later

 TAX                    \ Copy the token number from A into X

 TYA                    \ Store Y on the stack
 PHA

 LDA V                  \ Store V(1 0) on the stack
 PHA
 LDA V+1
 PHA

 LDA #LO(TKN1)          \ Set V to the low byte of TKN1
 STA V

 LDA #HI(TKN1)          \ Set A to the high byte of TKN1, so when we fall
                        \ through into DTEN, V(1 0) gets set to the address of
                        \ the TKN1 token table

.DTEN_C

 STA V+1                \ Set the high byte of V(1 0) to A, so V(1 0) now points
                        \ to the start of the token table to use

 LDY #0                 \ First, we need to work our way through the table until
                        \ we get to the token that we want to print. Tokens are
                        \ delimited by #VE, and VE EOR VE = 0, so we work our
                        \ way through the table in, counting #VE delimiters
                        \ until we have passed X of them, at which point we jump
                        \ down to DTL2 to do the actual printing. So first, we
                        \ set a counter Y to point to the character offset as we
                        \ scan through the table

.DTL1_C

 JSR TKRD_C             \ Port: A = (V),Y read from shadow RAM, where the
                        \ extended tokens are (was LDA (V),Y): load the
                        \ character at offset Y in the token table,
                        \ which is the next character from the token table

 EOR #VE                \ Tokens are stored in memory having been EOR'd with
                        \ #VE, so we repeat the EOR to get the actual character
                        \ in this token

 BNE DT1_C                \ If the result is non-zero, then this is a character
                        \ in a token rather than the delimiter (which is #VE),
                        \ so jump to DT1

 DEX                    \ We have just scanned the end of a token, so decrement
                        \ X, which contains the token number we are looking for

 BEQ DTL2_C               \ If X has now reached zero then we have found the token
                        \ we are looking for, so jump down to DTL2 to print it

.DT1_C

 INY                    \ Otherwise this isn't the token we are looking for, so
                        \ increment the character pointer

 BNE DTL1_C               \ If Y hasn't just wrapped around to 0, loop back to
                        \ DTL1 to process the next character

 INC V+1                \ We have just crossed into a new page, so increment
                        \ V+1 so that V points to the start of the new page

 BNE DTL1_C               \ Jump back to DTL1 to process the next character (this
                        \ BNE is effectively a JMP as V+1 won't reach zero
                        \ before we reach the end of the token table)

.DTL2_C

 INY                    \ We just detected the delimiter byte before the token
                        \ that we want to print, so increment the character
                        \ pointer to point to the first character of the token,
                        \ rather than the delimiter

 BNE P%+4               \ If Y hasn't just wrapped around to 0, skip the next
                        \ instruction

 INC V+1                \ We have just crossed into a new page, so increment
                        \ V+1 so that V points to the start of the new page

 JSR TKRD_C             \ Port: A = (V),Y read from shadow RAM, where the
                        \ extended tokens are (was LDA (V),Y): load the
                        \ character at offset Y in the token table,
                        \ which is the next character from the token we want to
                        \ print

 EOR #VE                \ Tokens are stored in memory having been EOR'd with
                        \ #VE, so we repeat the EOR to get the actual character
                        \ in this token

 BEQ DTEX_C               \ If the result is zero, then this is the delimiter at
                        \ the end of the token to print (which is #VE), so jump
                        \ to DTEX to return from the subroutine, as we are done
                        \ printing

 JSR DETOK2_C             \ Otherwise call DETOK2 to print this part of the token

 JMP DTL2_C               \ Jump back to DTL2 to process the next character

.DTEX_C

 PLA                    \ Restore V(1 0) from the stack, so it is preserved
 STA V+1                \ through calls to this routine
 PLA
 STA V

 PLA                    \ Restore Y from the stack, so it is preserved through
 TAY                    \ calls to this routine

 PLA                    \ Restore A from the stack, so it is preserved through
                        \ calls to this routine

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: DETOK2
\       Type: Subroutine
\   Category: Text
\    Summary: Print an extended text token (1-255)
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The token to be printed (1-255)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   A is preserved
\
\   Y                   Y is preserved
\
\   V(1 0)              V(1 0) is preserved
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   DTS                 Print a single letter in the correct case
\
\ ******************************************************************************

.DETOK2_C

 CMP #32                \ If A < 32 then this is a jump token, so skip to DT3 to
 BCC DT3_C                \ process it

 BIT DTW3               \ If bit 7 of DTW3 is clear, then extended tokens are
 BPL DT8_C                \ enabled, so jump to DT8 to process them

                        \ If we get there then this is not a jump token and
                        \ extended tokens are not enabled, so we can call the
                        \ standard text token routine at TT27 to print the token

 TAX                    \ Copy the token number from A into X

 TYA                    \ Store Y on the stack
 PHA

 LDA V                  \ Store V(1 0) on the stack
 PHA
 LDA V+1
 PHA

 TXA                    \ Copy the token number from X back into A

 JSR TT27_C               \ Call TT27 to print the text token

 JMP DT7_C                \ Jump to DT7 to restore V(1 0) and Y from the stack and
                        \ return from the subroutine

.DT8_C

                        \ If we get here then this is not a jump token and
                        \ extended tokens are enabled

 CMP #'['               \ If A < ASCII "[" (i.e. A <= ASCII "Z", or 90) then
 BCC DTS_C                \ this is a printable ASCII character, so jump down to
                        \ DTS to print it

 CMP #129               \ If A < 129, so A is in the range 91-128, jump down to
 BCC DT6_C                \ DT6 to print a randomised token from the MTIN table

 CMP #215               \ If A < 215, so A is in the range 129-214, jump to
 BCC DETOK_C              \ DETOK as this is a recursive token, returning from the
                        \ subroutine using a tail call

                        \ If we get here then A >= 215, so this is a two-letter
                        \ token from the extended TKN2/QQ16 table

 SBC #215               \ Subtract 215 to get a token number in the range 0-12
                        \ (the C flag is set as we passed through the BCC above,
                        \ so this subtraction is correct)

 ASL A                  \ Set A = A * 2, so it can be used as a pointer into the
                        \ two-letter token tables at TKN2 and QQ16

 PHA                    \ Store A on the stack, so we can restore it for the
                        \ second letter below

 TAX                    \ Fetch the first letter of the two-letter token from
 LDA TKN2_C,X             \ TKN2, which is at TKN2 + X

 JSR DTS_C                \ Call DTS to print it

 PLA                    \ Restore A from the stack and transfer it into X
 TAX

 LDA TKN2_C+1,X           \ Fetch the second letter of the two-letter token from
                        \ TKN2, which is at TKN2 + X + 1, and fall through into
                        \ DTS to print it

.DTS_C

 CMP #'A'               \ If A < ASCII "A", jump to DT9 to print this as ASCII
 BCC DT9_C

 BIT DTW6               \ If bit 7 of DTW6 is set, then lower case has been
 BMI DT10_C               \ enabled by jump token 13, {lower case}, so jump to
                        \ DT10 to apply the lower case and single cap masks

 BIT DTW2               \ If bit 7 of DTW2 is set, then we are not currently
 BMI DT5_C                \ printing a word, so jump to DT5 so we skip the setting
                        \ of lower case in Sentence Case (which we only want to
                        \ do when we are already printing a word)

.DT10_C

 ORA DTW1               \ Convert the character to lower case if DTW1 is
                        \ %00100000 (i.e. if we are in {sentence case} mode)

.DT5_C

 AND DTW8               \ Convert the character to upper case if DTW8 is
                        \ %11011111 (i.e. after a {single cap} token)

.DT9_C

 JMP x4_DASC               \ Jump to DASC to print the ASCII character in A,
                        \ returning from the routine using a tail call

.DT3_C

                        \ If we get here then the token number in A is in the
                        \ range 1 to 32, so this is a jump token that should
                        \ call the corresponding address in the jump table at
                        \ JMTB

 TAX                    \ Copy the token number from A into X

 TYA                    \ Store Y on the stack
 PHA

 LDA V                  \ Store V(1 0) on the stack
 PHA
 LDA V+1
 PHA

 TXA                    \ Copy the token number from X back into A

 ASL A                  \ Set A = A * 2, so it can be used as a pointer into the
                        \ jump table at JMTB, though because the original range
                        \ of values is 1-32, so the doubled range is 2-64, we
                        \ need to take the offset into the jump table from
                        \ JMTB-2 rather than JMTB

 TAX                    \ Copy the doubled token number from A into X

 LDA JMTB_C-2,X           \ Set DTM(2 1) to the X-th address from the table at
 STA DTM_C+1              \ JTM-2, which modifies the JSR DASC instruction at
 LDA JMTB_C-1,X           \ label DTM below so that it calls the subroutine at the
 STA DTM_C+2              \ relevant address from the JMTB table

 TXA                    \ Copy the doubled token number from X back into A

 LSR A                  \ Halve A to get the original token number

.DTM_C

 JSR x4_DASC               \ Call the relevant JMTB subroutine, as this instruction
                        \ will have been modified by the above to point to the
                        \ relevant address

.DT7_C

 PLA                    \ Restore V(1 0) from the stack, so it is preserved
 STA V+1                \ through calls to this routine
 PLA
 STA V

 PLA                    \ Restore Y from the stack, so it is preserved through
 TAY                    \ calls to this routine

 RTS                    \ Return from the subroutine

.DT6_C

                        \ If we get here then the token number in A is in the
                        \ range 91-128, which means we print a randomly picked
                        \ token from the token range given in the corresponding
                        \ entry in the MTIN table

 STA SC                 \ Store the token number in SC

 TYA                    \ Store Y on the stack
 PHA

 LDA V                  \ Store V(1 0) on the stack
 PHA
 LDA V+1
 PHA

 JSR x4_DORND              \ Set X to a random number
 TAX

 LDA #0                 \ Set A to 0, so we can build a random number from 0 to
                        \ 4 in A plus the C flag, with each number being equally
                        \ likely

 CPX #51                \ Add 1 to A if X >= 51
 ADC #0

 CPX #102               \ Add 1 to A if X >= 102
 ADC #0

 CPX #153               \ Add 1 to A if X >= 153
 ADC #0

 CPX #204               \ Set the C flag if X >= 204

 LDX SC                 \ Fetch the token number from SC into X, so X is now in
                        \ the range 91-128

 ADC MTIN_C-91,X          \ Set A = MTIN-91 + token number (91-128) + random (0-4)
                        \       = MTIN + token number (0-37) + random (0-4)

 JSR DETOK_C              \ Call DETOK to print the extended recursive token in A

 JMP DT7_C                \ Jump to DT7 to restore V(1 0) and Y from the stack and
                        \ return from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: MT1
\       Type: Subroutine
\   Category: Text
\    Summary: Switch to ALL CAPS when printing extended tokens
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ This routine sets the following:
\
\   * DTW1 = %00000000 (do not change case to lower case)
\
\   * DTW6 = %00000000 (lower case is not enabled)
\
\ ******************************************************************************

.MT1_C

 LDA #%00000000         \ Set A = %00000000, so when we fall through into MT2,
                        \ both DTW1 and DTW6 get set to %00000000

 EQUB &2C               \ Skip the next instruction by turning it into
                        \ &2C &A9 &20, or BIT &20A9, which does nothing apart
                        \ from affect the flags

\ ******************************************************************************
\
\       Name: MT2
\       Type: Subroutine
\   Category: Text
\    Summary: Switch to Sentence Case when printing extended tokens
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ This routine sets the following:
\
\   * DTW1 = %00100000 (apply lower case to the second letter of a word onwards)
\
\   * DTW6 = %00000000 (lower case is not enabled)
\
\ ******************************************************************************

.MT2_C

 LDA #%00100000         \ Set DTW1 = %00100000
 STA DTW1

 LDA #00000000          \ Set DTW6 = %00000000
 STA DTW6

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: MT8
\       Type: Subroutine
\   Category: Text
\    Summary: Tab to column 6 and start a new word when printing extended tokens
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ This routine sets the following:
\
\   * XC = 6 (tab to column 6)
\
\   * DTW2 = %11111111 (we are not currently printing a word)
\
\ ******************************************************************************

.MT8_C

 LDA #6                 \ Move the text cursor to column 6
 JSR x4_DOXC

 LDA #%11111111         \ Set all the bits in DTW2
 STA DTW2

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: MT9
\       Type: Subroutine
\   Category: Text
\    Summary: Clear the screen and set the current view type to 1
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ This routine sets the following:
\
\   * XC = 1 (tab to column 1)
\
\ before calling TT66 to clear the screen and set the view type to 1.
\
\ ******************************************************************************

.MT9_C

 LDA #1                 \ Move the text cursor to column 1
 STA XC

 JMP x4_TT66               \ Jump to TT66 to clear the screen and set the current
                        \ view type to 1, returning from the subroutine using a
                        \ tail call

\ ******************************************************************************
\
\       Name: MT13
\       Type: Subroutine
\   Category: Text
\    Summary: Switch to lower case when printing extended tokens
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ This routine sets the following:
\
\   * DTW1 = %00100000 (apply lower case to the second letter of a word onwards)
\
\   * DTW6 = %10000000 (lower case is enabled)
\
\ ******************************************************************************

.MT13_C

 LDA #%10000000         \ Set DTW6 = %10000000
 STA DTW6

 LDA #%00100000         \ Set DTW1 = %00100000
 STA DTW1

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: MT6
\       Type: Subroutine
\   Category: Text
\    Summary: Switch to standard tokens in Sentence Case
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ This routine sets the following:
\
\   * QQ17 = %10000000 (set Sentence Case for standard tokens)
\
\   * DTW3 = %11111111 (print standard tokens)
\
\ ******************************************************************************

.MT6_C

 LDA #%10000000         \ Set bit 7 of QQ17 to switch standard tokens to
 STA QQ17               \ Sentence Case

 LDA #%11111111         \ Set A = %11111111, so when we fall through into MT5,
                        \ DTW3 gets set to %11111111 and calls to DETOK print
                        \ standard tokens

 EQUB &2C               \ Skip the next instruction by turning it into
                        \ &2C &A9 &00, or BIT &00A9, which does nothing apart
                        \ from affect the flags

\ ******************************************************************************
\
\       Name: MT5
\       Type: Subroutine
\   Category: Text
\    Summary: Switch to extended tokens
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ This routine sets the following:
\
\   * DTW3 = %00000000 (print extended tokens)
\
\ ******************************************************************************

.MT5_C

 LDA #%00000000         \ Set DTW3 = %00000000, so that calls to DETOK print
 STA DTW3               \ extended tokens

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: MT14
\       Type: Subroutine
\   Category: Text
\    Summary: Switch to justified text when printing extended tokens
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ This routine sets the following:
\
\   * DTW4 = %10000000 (justify text, print buffer on carriage return)
\
\   * DTW5 = 0 (reset line buffer size)
\
\ ******************************************************************************

.MT14_C

 LDA #%10000000         \ Set A = %10000000, so when we fall through into MT15,
                        \ DTW4 gets set to %10000000

 EQUB &2C               \ Skip the next instruction by turning it into
                        \ &2C &A9 &00, or BIT &00A9, which does nothing apart
                        \ from affect the flags

\ ******************************************************************************
\
\       Name: MT15
\       Type: Subroutine
\   Category: Text
\    Summary: Switch to left-aligned text when printing extended tokens
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ This routine sets the following:
\
\   * DTW4 = %00000000 (do not justify text, print buffer on carriage return)
\
\   * DTW5 = 0 (reset line buffer size)
\
\ ******************************************************************************

.MT15_C

 LDA #0                 \ Set DTW4 = %00000000
 STA DTW4

 ASL A                  \ Set DTW5 = 0 (even when we fall through from MT14 with
 STA DTW5               \ A set to %10000000)

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: MT17
\       Type: Subroutine
\   Category: Text
\    Summary: Print the selected system's adjective, e.g. Lavian for Lave
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ The adjective for the current system is generated by taking the system name,
\ removing the last character if it is a vowel, and adding "-ian" to the end,
\ so:
\
\   * Lave gives Lavian (as in "Lavian tree grub")
\
\   * Leesti gives Leestian (as in "Leestian Evil Juice")
\
\ This routine is called by jump token 17, {system name adjective}, and it can
\ only be used when justified text is being printed - i.e. following jump token
\ 14, {justify} - because the routine needs to use the line buffer to work.
\
\ ******************************************************************************

.MT17_C

 LDA QQ17               \ Set QQ17 = %10111111 to switch to Sentence Case
 AND #%10111111
 STA QQ17

 LDA #3                 \ Print control code 3 (selected system name) into the
 JSR TT27_C               \ line buffer

 LDX DTW5               \ Load the last character of the line buffer BUF into A
 LDA BUF-1,X            \ (as DTW5 contains the buffer size, so character DTW5-1
                        \ is the last character in the buffer BUF)

 JSR VOWEL_C              \ Test whether the character is a vowel, in which case
                        \ this will set the C flag

 BCC MT171_C              \ If the character is not a vowel, skip the following
                        \ instruction

 DEC DTW5               \ The character is a vowel, so decrement DTW5, which
                        \ removes the last character from the line buffer (i.e.
                        \ it removes the trailing vowel from the system name)

.MT171_C

 LDA #153               \ Print extended token 153 ("IAN"), returning from the
 JMP DETOK_C              \ subroutine using a tail call

\ ******************************************************************************
\
\       Name: MT18
\       Type: Subroutine
\   Category: Text
\    Summary: Print a random 1-8 letter word in Sentence Case
\  Deep dive: Extended text tokens
\
\ ******************************************************************************

.MT18_C

 JSR MT19_C               \ Call MT19 to capitalise the next letter (i.e. set
                        \ Sentence Case for this word only)

 JSR x4_DORND              \ Set A and X to random numbers and reduce A to a
 AND #3                 \ random number in the range 0-3

 TAY                    \ Copy the random number into Y, so we can use Y as a
                        \ loop counter to print 1-4 words (i.e. Y+1 words)

.MT18L_C

 JSR x4_DORND              \ Set A and X to random numbers and reduce A to an even
 AND #62                \ random number in the range 0-62 (as bit 0 of 62 is 0)

 TAX                    \ Copy the random number into X, so X contains the table
                        \ offset of a random extended two-letter token from 0-31
                        \ which we can now use to pick a token from the combined
                        \ tables at TKN2+2 and QQ16 (we intentionally exclude
                        \ the first token in TKN2, which contains a newline)

 LDA TKN2_C+2,X           \ Print the first letter of the token at TKN2+2 + X
 JSR DTS_C

 LDA TKN2_C+3,X           \ Print the second letter of the token at TKN2+2 + X
 JSR DTS_C

 DEY                    \ Decrement the loop counter

 BPL MT18L_C              \ Loop back to MT18L to print another two-letter token
                        \ until we have printed Y+1 of them

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: MT19
\       Type: Subroutine
\   Category: Text
\    Summary: Capitalise the next letter
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ This routine sets the following:
\
\   * DTW8 = %11011111 (capitalise the next letter)
\
\ ******************************************************************************

.MT19_C

 LDA #%11011111         \ Set DTW8 = %11011111
 STA DTW8

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: VOWEL
\       Type: Subroutine
\   Category: Text
\    Summary: Test whether a character is a vowel
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The character to be tested
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              The C flag is set if the character is a vowel, otherwise
\                       it is clear
\
\ ******************************************************************************

.VOWEL_C

 ORA #%00100000         \ Set bit 5 of the character to make it lower case

 CMP #'a'               \ If the letter is a vowel, jump to VRTS to return from
 BEQ VRTS_C               \ the subroutine with the C flag set (as the CMP will
 CMP #'e'               \ set the C flag if the comparison is equal)
 BEQ VRTS_C
 CMP #'i'
 BEQ VRTS_C
 CMP #'o'
 BEQ VRTS_C
 CMP #'u'
 BEQ VRTS_C

 CLC                    \ The character is not a vowel, so clear the C flag

.VRTS_C

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: JMTB
\       Type: Variable
\   Category: Text
\    Summary: The extended token table for jump tokens 1-32 (DETOK)
\  Deep dive: Extended text tokens
\
\ ******************************************************************************

.JMTB_C

 EQUW MT1_C               \ Token  1: Switch to ALL CAPS
 EQUW MT2_C               \ Token  2: Switch to Sentence Case
 EQUW TT27_C              \ Token  3: Print the selected system name
 EQUW TT27_C              \ Token  4: Print the commander's name
 EQUW MT5_C               \ Token  5: Switch to extended tokens
 EQUW MT6_C               \ Token  6: Switch to standard tokens, in Sentence Case
 EQUW x4_DASC              \ Token  7: Beep
 EQUW MT8_C               \ Token  8: Tab to column 6
 EQUW MT9_C               \ Token  9: Clear screen, tab to column 1, view type = 1
 EQUW x4_DASC              \ Token 10: Line feed
 EQUW x4_NLIN4             \ Token 11: Draw box around title (line at pixel row 19)
 EQUW x4_DASC              \ Token 12: Carriage return
 EQUW MT13_C              \ Token 13: Switch to lower case
 EQUW MT14_C              \ Token 14: Switch to justified text
 EQUW MT15_C              \ Token 15: Switch to left-aligned text
 EQUW x4_MT16              \ Token 16: Print the character in DTW7 (drive number)
 EQUW MT17_C              \ Token 17: Print system name adjective in Sentence Case
 EQUW MT18_C              \ Token 18: Randomly print 1 to 4 two-letter tokens
 EQUW MT19_C              \ Token 19: Capitalise first letter of next word only
 EQUW x4_DASC              \ Token 20: Unused
 EQUW x4_CLYNS             \ Token 21: Clear the bottom few lines of the space view
 EQUW x4_PAUSE             \ Token 22: Display ship and wait for key press
 EQUW x4_MT23              \ Token 23: Move to row 10, white text, set lower case
 EQUW x4_PAUSE2            \ Token 24: Wait for a key press
 EQUW x4_BRIS              \ Token 25: Show incoming message screen, wait 2 seconds
 EQUW x4_MT26              \ Token 26: Fetch line input from keyboard (filename)
 EQUW MT27_C              \ Token 27: Print mission captain's name (217-219)
 EQUW MT28_C              \ Token 28: Print mission 1 location hint (220-221)
 EQUW x4_MT29              \ Token 29: Column 6, white text, lower case in words
 EQUW x4_FILEPR            \ Token 30: Display currently selected media (disk/tape)
 EQUW x4_OTHERFILEPR       \ Token 31: Display the non-selected media (disk/tape)
 EQUW x4_DASC              \ Token 32: Unused

\ ******************************************************************************
\
\       Name: TKN2
\       Type: Variable
\   Category: Text
\    Summary: The extended two-letter token lookup table
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ Two-letter token lookup table for extended tokens 215-227.
\
\ ******************************************************************************

.TKN2_C

 EQUB 12, 10            \ Token 215 = {crlf}
 EQUS "AB"              \ Token 216
 EQUS "OU"              \ Token 217
 EQUS "SE"              \ Token 218
 EQUS "IT"              \ Token 219
 EQUS "IL"              \ Token 220
 EQUS "ET"              \ Token 221
 EQUS "ST"              \ Token 222
 EQUS "ON"              \ Token 223
 EQUS "LO"              \ Token 224
 EQUS "NU"              \ Token 225
 EQUS "TH"              \ Token 226
 EQUS "NO"              \ Token 227

\ ******************************************************************************
\
\       Name: QQ16
\       Type: Variable
\   Category: Text
\    Summary: The two-letter token lookup table
\  Deep dive: Printing text tokens
\
\ ------------------------------------------------------------------------------
\
\ Two-letter token lookup table for tokens 128-159.
\
\ These two-letter tokens can also be used in the extended text token system, by
\ adding 100 to the token number. So the extended two-letter token 228 is "AL",
\ the same as the standard two-letter token 128. In this system, the last four
\ tokens are not available, as they would have numbers greater than 255.
\
\ ******************************************************************************

.QQ16_C

 EQUS "AL"              \ Token 128
 EQUS "LE"              \ Token 129
 EQUS "XE"              \ Token 130
 EQUS "GE"              \ Token 131
 EQUS "ZA"              \ Token 132
 EQUS "CE"              \ Token 133
 EQUS "BI"              \ Token 134
 EQUS "SO"              \ Token 135
 EQUS "US"              \ Token 136
 EQUS "ES"              \ Token 137
 EQUS "AR"              \ Token 138
 EQUS "MA"              \ Token 139
 EQUS "IN"              \ Token 140
 EQUS "DI"              \ Token 141
 EQUS "RE"              \ Token 142
 EQUS "A?"              \ Token 143
 EQUS "ER"              \ Token 144
 EQUS "AT"              \ Token 145
 EQUS "EN"              \ Token 146
 EQUS "BE"              \ Token 147
 EQUS "RA"              \ Token 148
 EQUS "LA"              \ Token 149
 EQUS "VE"              \ Token 150
 EQUS "TI"              \ Token 151
 EQUS "ED"              \ Token 152
 EQUS "OR"              \ Token 153
 EQUS "QU"              \ Token 154
 EQUS "AN"              \ Token 155
 EQUS "TE"              \ Token 156
 EQUS "IS"              \ Token 157
 EQUS "RI"              \ Token 158
 EQUS "ON"              \ Token 159

\ ******************************************************************************
\
\       Name: PDESC
\       Type: Subroutine
\   Category: Universe
\    Summary: Print the system's extended description or a mission 1 directive
\  Deep dive: Extended system descriptions
\             Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ This prints a specific system's extended description. This is called the "pink
\ volcanoes string" in a comment in the original source, and the "goat soup"
\ recipe by Ian Bell on his website (where he also refers to the species string
\ as the "pink felines" string).
\
\ For some special systems, when you are docked at them, the procedurally
\ generated extended description is overridden and a text token from the RUTOK
\ table is shown instead. If mission 1 is in progress, then a number of systems
\ along the route of that mission's story will show custom mission-related
\ directives in place of that system's normal "goat soup" phrase.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   ZZ                  The system number (0-255)
\
\ ******************************************************************************

.PDESC_C

 LDA QQ8                \ If either byte in QQ18(1 0) is non-zero, meaning that
 ORA QQ8+1              \ the distance from the current system to the selected
 BNE PD1_C                \ is non-zero, jump to PD1 to show the standard "goat
                        \ soup" description

 LDA QQ12               \ If QQ12 does not have bit 7 set, which means we are
 BPL PD1_C                \ not docked, jump to PD1 to show the standard "goat
                        \ soup" description

                        \ If we get here, then the current system is the same as
                        \ the selected system and we are docked, so now to check
                        \ whether there is a special override token for this
                        \ system

 LDY #NRU%              \ Set Y as a loop counter as we work our way through the
                        \ system numbers in RUPLA, starting at NRU% (which is
                        \ the number of entries in RUPLA, 26) and working our
                        \ way down to 1

.PDL1_C

 JSR RUPRD_C            \ Fetch the Y-th byte from RUPLA-1 into A (we use
                        \ RUPLA-1 because Y is looping from 26 to 1)

 CMP ZZ                 \ If A doesn't match the system whose description we
 BNE PD2_C                \ are printing (in ZZ), jump to PD2 to keep looping
                        \ through the system numbers in RUPLA

                        \ If we get here we have found a match for this system
                        \ number in RUPLA

 JSR RUGRD_C            \ Fetch the Y-th byte from RUGAL-1 into A

 AND #%01111111         \ Extract bits 0-6 of A

 CMP GCNT               \ If the result does not equal the current galaxy
 BNE PD2_C                \ number, jump to PD2 to keep looping through the system
                        \ numbers in RUPLA

 JSR RUGRD_C            \ Fetch the Y-th byte from RUGAL-1 into A, once again

 BMI PD3_C                \ If bit 7 is set, jump to PD3 to print the extended
                        \ token in A from the second table in RUTOK

 LDA TP                 \ Fetch bit 0 of TP into the C flag, and skip to PD1 if
 LSR A                  \ it is clear (i.e. if mission 1 is not in progress) to
 BCC PD1_C                \ print the "goat soup" extended description

                        \ If we get here then mission 1 is in progress, so we
                        \ print out the corresponding token from RUTOK

 JSR MT14_C               \ Call MT14 to switch to justified text

 LDA #1                 \ Set A = 1 so that extended token 1 (an empty string)
                        \ gets printed below instead of token 176, followed by
                        \ the Y-th token in RUTOK

 EQUB &2C               \ Skip the next instruction by turning it into
                        \ &2C &A9 &B0, or BIT &B0A9, which does nothing apart
                        \ from affect the flags

.PD3_C

 LDA #176               \ Print extended token 176 ("{lower case}{justify}
 JSR DETOK2_C             \ {single cap}")

 TYA                    \ Print the extended token in Y from the second table
 JSR DETOK3_C             \ in RUTOK

 LDA #177               \ Set A = 177 so when we jump to PD4 in the next
                        \ instruction, we print token 177 (".{cr}{left align}")

 BNE PD4_C                \ Jump to PD4 to print the extended token in A and
                        \ return from the subroutine using a tail call

.PD2_C

 DEY                    \ Decrement the byte counter in Y

 BNE PDL1_C               \ Loop back to check the next byte in RUPLA until we
                        \ either find a match for the system in ZZ, or we fall
                        \ through into the "goat soup" extended description
                        \ routine

.PD1_C

                        \ We now print the "goat soup" extended description

 LDX #3                 \ We now want to seed the random number generator with
                        \ the s1 and s2 16-bit seeds from the current system, so
                        \ we get the same extended description for each system
                        \ every time we call PDESC, so set a counter in X for
                        \ copying 4 bytes

.PDL1K_C                  \ This label is a duplicate of the label above
                        \
                        \ In the original source this label is PDL1, but
                        \ because BeebAsm doesn't allow us to redefine labels,
                        \ I have renamed it to PDL1K

 LDA QQ15+2,X           \ Copy QQ15+2 to QQ15+5 (s1 and s2) to RAND to RAND+3
 STA RAND,X

 DEX                    \ Decrement the loop counter

 BPL PDL1K_C              \ Loop back to PDL1K until we have copied all

 LDA #5                 \ Set A = 5, so we print extended token 5 in the next
                        \ instruction ("{lower case}{justify}{single cap}[86-90]
                        \ IS [140-144].{cr}{left align}"

.PD4_C

 JMP DETOK_C              \ Print the extended token given in A, and return from
                        \ the subroutine using a tail call

\ ******************************************************************************
\
\       Name: MTIN
\       Type: Variable
\   Category: Text
\    Summary: Lookup table for random tokens in the extended token table (0-37)
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ The ERND token type, which is part of the extended token system, takes an
\ argument between 0 and 37, and returns a randomly chosen token in the range
\ specified in this table. This is used to generate the extended description of
\ each system.
\
\ For example, the entry at position 13 in this table (counting from 0) is 66,
\ so ERND 14 will expand into a random token in the range 66-70, i.e. one of
\ "JUICE", "BRANDY", "WATER", "BREW" and "GARGLE BLASTERS".
\
\ ******************************************************************************

.MTIN_C

 EQUB 16                \ Token  0: a random extended token between 16 and 20
 EQUB 21                \ Token  1: a random extended token between 21 and 25
 EQUB 26                \ Token  2: a random extended token between 26 and 30
 EQUB 31                \ Token  3: a random extended token between 31 and 35
 EQUB 155               \ Token  4: a random extended token between 155 and 159
 EQUB 160               \ Token  5: a random extended token between 160 and 164
 EQUB 46                \ Token  6: a random extended token between 46 and 50
 EQUB 165               \ Token  7: a random extended token between 165 and 169
 EQUB 36                \ Token  8: a random extended token between 36 and 40
 EQUB 41                \ Token  9: a random extended token between 41 and 45
 EQUB 61                \ Token 10: a random extended token between 61 and 65
 EQUB 51                \ Token 11: a random extended token between 51 and 55
 EQUB 56                \ Token 12: a random extended token between 56 and 60
 EQUB 170               \ Token 13: a random extended token between 170 and 174
 EQUB 66                \ Token 14: a random extended token between 66 and 70
 EQUB 71                \ Token 15: a random extended token between 71 and 75
 EQUB 76                \ Token 16: a random extended token between 76 and 80
 EQUB 81                \ Token 17: a random extended token between 81 and 85
 EQUB 86                \ Token 18: a random extended token between 86 and 90
 EQUB 140               \ Token 19: a random extended token between 140 and 144
 EQUB 96                \ Token 20: a random extended token between 96 and 100
 EQUB 101               \ Token 21: a random extended token between 101 and 105
 EQUB 135               \ Token 22: a random extended token between 135 and 139
 EQUB 130               \ Token 23: a random extended token between 130 and 134
 EQUB 91                \ Token 24: a random extended token between 91 and 95
 EQUB 106               \ Token 25: a random extended token between 106 and 110
 EQUB 180               \ Token 26: a random extended token between 180 and 184
 EQUB 185               \ Token 27: a random extended token between 185 and 189
 EQUB 190               \ Token 28: a random extended token between 190 and 194
 EQUB 225               \ Token 29: a random extended token between 225 and 229
 EQUB 230               \ Token 30: a random extended token between 230 and 234
 EQUB 235               \ Token 31: a random extended token between 235 and 239
 EQUB 240               \ Token 32: a random extended token between 240 and 244
 EQUB 245               \ Token 33: a random extended token between 245 and 249
 EQUB 250               \ Token 34: a random extended token between 250 and 254
 EQUB 115               \ Token 35: a random extended token between 115 and 119
 EQUB 120               \ Token 36: a random extended token between 120 and 124
 EQUB 125               \ Token 37: a random extended token between 125 and 129

\ ******************************************************************************
\
\ Save ELTC.bin
\
\ ******************************************************************************
\
\       Name: cpl
\       Type: Subroutine
\   Category: Universe
\    Summary: Print the selected system name
\  Deep dive: Generating system names
\             Galaxy and system seeds
\
\ ------------------------------------------------------------------------------
\
\ Print control code 3 (the selected system name, i.e. the one in the crosshairs
\ in the Short-range Chart).
\
\ ******************************************************************************

.cpl_C

 LDX #5                 \ First we need to back up the seeds in QQ15, so set up
                        \ a counter in X to cover three 16-bit seeds (i.e.
                        \ 6 bytes)

.TT53_C

 LDA QQ15,X             \ Copy byte X from QQ15 to QQ19
 STA QQ19,X

 DEX                    \ Decrement the loop counter

 BPL TT53_C               \ Loop back for the next byte to back up

 LDY #3                 \ Step 1: Now that the seeds are backed up, we can
                        \ start the name-generation process. We will either
                        \ need to loop three or four times, so for now set
                        \ up a counter in Y to loop four times

 BIT QQ15               \ Check bit 6 of s0_lo, which is stored in QQ15

 BVS P%+3               \ If bit 6 is set then skip over the next instruction

 DEY                    \ Bit 6 is clear, so we only want to loop three times,
                        \ so decrement the loop counter in Y

 STY T                  \ Store the loop counter in T

.TT55_C

 LDA QQ15+5             \ Step 2: Load s2_hi, which is stored in QQ15+5, and
 AND #%00011111         \ extract bits 0-4 by AND'ing with %11111

 BEQ P%+7               \ If all those bits are zero, then skip the following
                        \ two instructions to go to step 3

 ORA #%10000000         \ We now have a number in the range 1-31, which we can
                        \ easily convert into a two-letter token, but first we
                        \ need to add 128 (or set bit 7) to get a range of
                        \ 129-159

 JSR TT27_C               \ Print the two-letter token in A

 JSR x4_TT54               \ Step 3: twist the seeds in QQ15

 DEC T                  \ Decrement the loop counter

 BPL TT55_C               \ Loop back for the next two letters

 LDX #5                 \ We have printed the system name, so we can now
                        \ restore the seeds we backed up earlier. Set up a
                        \ counter in X to cover three 16-bit seeds (i.e. 6
                        \ bytes)

.TT56_C

 LDA QQ19,X             \ Copy byte X from QQ19 to QQ15
 STA QQ15,X

 DEX                    \ Decrement the loop counter

 BPL TT56_C               \ Loop back for the next byte to restore

 RTS                    \ Once all the seeds are restored, return from the
                        \ subroutine

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

.cmn_C

 LDY #0                 \ Set up a counter in Y, starting from 0

.QUL4_C

 LDA NAME,Y             \ The commander's name is stored at NAME, so load the
                        \ Y-th character from NAME

 CMP #13                \ If we have reached the end of the name, return from
 BEQ ypl_C-1              \ the subroutine (ypl-1 points to the RTS below)

 JSR x4_TT26               \ Print the character we just loaded

 INY                    \ Increment the loop counter

 BNE QUL4_C               \ Loop back for the next character

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

.ypl_C

 BIT MJ                 \ Check the mis-jump flag at MJ, and if bit 7 is set
 BMI ypl16_C              \ then we are in witchspace, and witchspace doesn't have
                        \ a system name, so jump to ypl16 to return from the
                        \ subroutine

 JSR TT62_C               \ Call TT62 below to swap the three 16-bit seeds in
                        \ QQ2 and QQ15 (before the swap, QQ2 contains the seeds
                        \ for the current system, while QQ15 contains the seeds
                        \ for the selected system)

 JSR cpl_C                \ Call cpl to print out the system name for the seeds
                        \ in QQ15 (which now contains the seeds for the current
                        \ system)

                        \ Now we fall through into the TT62 subroutine, which
                        \ will swap QQ2 and QQ15 once again, so everything goes
                        \ back into the right place, and the RTS at the end of
                        \ TT62 will return from the subroutine

.TT62_C

 LDX #5                 \ Set up a counter in X for the three 16-bit seeds we
                        \ want to swap (i.e. 6 bytes)

.TT78_C

 LDA QQ15,X             \ Swap byte X between QQ2 and QQ15
 LDY QQ2,X
 STA QQ2,X
 STY QQ15,X

 DEX                    \ Decrement the loop counter

 BPL TT78_C               \ Loop back for the next byte to swap

.ypl16_C

 RTS                    \ Once all bytes are swapped, return from the
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

.tal_C

 CLC                    \ We don't want to print the galaxy number with a
                        \ decimal point, so clear the C flag for pr2 to take as
                        \ an argument

 LDX GCNT               \ Load the current galaxy number from GCNT into X

 INX                    \ Add 1 to the galaxy number, as the galaxy numbers
                        \ are 0-7 internally, but we want to display them as
                        \ galaxy 1 through 8

 JMP x4_pr2                \ Jump to pr2, which prints the number in X to a width
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

.fwl_C

 LDA #105               \ Print recursive token 105 ("FUEL") followed by a
 JSR TT68_C               \ colon

 LDX QQ14               \ Load the current fuel level from QQ14

 SEC                    \ We want to print the fuel level with a decimal point,
                        \ so set the C flag for pr2 to take as an argument

 JSR x4_pr2                \ Call pr2, which prints the number in X to a width of
                        \ 3 figures (i.e. in the format x.x, which will always
                        \ be exactly 3 characters as the maximum fuel is 7.0)

 LDA #195               \ Print recursive token 35 ("LIGHT YEARS") followed by
 JSR plf_C                \ a newline

.PCASH_C

 LDA #119               \ Print recursive token 119 ("CASH:" then control code
 BNE TT27_C               \ 0, which prints cash levels, then " CR" and newline)

\ ******************************************************************************
\
\       Name: csh
\       Type: Subroutine
\   Category: Status
\    Summary: Print the current amount of cash
\
\ ------------------------------------------------------------------------------
\
\ Print control code 0 (the current amount of cash, right-aligned to width 9,
\ followed by " CR" and a newline).
\
\ ******************************************************************************

.csh_C

 LDX #3                 \ We are going to use the BPRNT routine to print out
                        \ the current amount of cash, which is stored as a
                        \ 32-bit number at location CASH. BPRNT prints out
                        \ the 32-bit number stored in K, so before we call
                        \ BPRNT, we need to copy the four bytes from CASH into
                        \ K, so first we set up a counter in X for the 4 bytes

.pc1_C

 LDA CASH,X             \ Copy byte X from CASH to K
 STA K,X

 DEX                    \ Decrement the loop counter

 BPL pc1_C                \ Loop back for the next byte to copy

 LDA #9                 \ We want to print the cash amount using up to 9 digits
 STA U                  \ (including the decimal point), so store this in U
                        \ for BRPNT to take as an argument

 SEC                    \ We want to print the cash amount with a decimal point,
                        \ so set the C flag for BRPNT to take as an argument

 JSR x4_BPRNT              \ Print the amount of cash to 9 digits with a decimal
                        \ point

 LDA #226               \ Print recursive token 66 (" CR") followed by a
                        \ newline by falling through into plf

\ ******************************************************************************
\
\       Name: plf
\       Type: Subroutine
\   Category: Text
\    Summary: Print a text token followed by a newline
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The text token to be printed
\
\ ******************************************************************************

.plf_C

 JSR TT27_C               \ Print the text token in A

 JMP x4_TT67               \ Jump to TT67 to print a newline and return from the
                        \ subroutine using a tail call

\ ******************************************************************************
\
\       Name: TT68
\       Type: Subroutine
\   Category: Text
\    Summary: Print a text token followed by a colon
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The text token to be printed
\
\ ******************************************************************************

.TT68_C

 JSR TT27_C               \ Print the text token in A and fall through into TT73
                        \ to print a colon

\ ******************************************************************************
\
\       Name: TT73
\       Type: Subroutine
\   Category: Text
\    Summary: Print a colon
\
\ ******************************************************************************

.TT73_C

 LDA #':'               \ Set A to ASCII ":" and fall through into TT27 to
                        \ actually print the colon

\ ******************************************************************************
\
\       Name: TT27
\       Type: Subroutine
\   Category: Text
\    Summary: Print a text token
\  Deep dive: Printing text tokens
\
\ ------------------------------------------------------------------------------
\
\ Print a text token (i.e. a character, control code, two-letter token or
\ recursive token).
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The text token to be printed
\
\ ******************************************************************************

.TT27_C

 TAX                    \ Copy the token number from A to X. We can then keep
                        \ decrementing X and testing it against zero, while
                        \ keeping the original token number intact in A; this
                        \ effectively implements a switch statement on the
                        \ value of the token

 BEQ csh_C                \ If token = 0, this is control code 0 (current amount
                        \ of cash and newline), so jump to csh to print the
                        \ amount of cash and return from the subroutine using
                        \ a tail call

 BMI TT43_C               \ If token > 127, this is either a two-letter token
                        \ (128-159) or a recursive token (160-255), so jump
                        \ to TT43 to process tokens

 DEX                    \ If token = 1, this is control code 1 (current galaxy
 BEQ tal_C                \ number), so jump to tal to print the galaxy number and
                        \ return from the subroutine using a tail call

 DEX                    \ If token = 2, this is control code 2 (current system
 BEQ ypl_C                \ name), so jump to ypl to print the current system name
                        \ and return from the subroutine using a tail call

 DEX                    \ If token > 3, skip the following instruction
 BNE P%+5

 JMP cpl_C                \ This token is control code 3 (selected system name)
                        \ so jump to cpl to print the selected system name
                        \ and return from the subroutine using a tail call

 DEX                    \ If token = 4, this is control code 4 (commander
 BEQ cmn_C                \ name), so jump to cmn to print the commander name
                        \ and return from the subroutine using a tail call

 DEX                    \ If token = 5, this is control code 5 (fuel, newline,
 BEQ fwl_C                \ cash, newline), so jump to fwl to print the fuel level
                        \ and return from the subroutine using a tail call

 DEX                    \ If token > 6, skip the following three instructions
 BNE P%+7

 LDA #%10000000         \ This token is control code 6 (switch to Sentence
 STA QQ17               \ Case), so set bit 7 of QQ17 to switch to Sentence Case
 RTS                    \ and return from the subroutine as we are done

 DEX                    \ If token > 8, skip the following two instructions
 DEX
 BNE P%+5

 STX QQ17               \ This token is control code 8 (switch to ALL CAPS), so
 RTS                    \ set QQ17 to 0 to switch to ALL CAPS and return from
                        \ the subroutine as we are done

 DEX                    \ If token = 9, this is control code 9 (tab to column
 BEQ crlf_C               \ 21 and print a colon), so jump to crlf

 CMP #96                \ By this point, token is either 7, or in 10-127.
 BCS ex_C                 \ Check token number in A and if token >= 96, then the
                        \ token is in 96-127, which is a recursive token, so
                        \ jump to ex, which prints recursive tokens in this
                        \ range (i.e. where the recursive token number is
                        \ correct and doesn't need correcting)

 CMP #14                \ If token < 14, skip the following two instructions
 BCC P%+6

 CMP #32                \ If token < 32, then this means token is in 14-31, so
 BCC qw_C                 \ this is a recursive token that needs 114 adding to it
                        \ to get the recursive token number, so jump to qw
                        \ which will do this

                        \ By this point, token is either 7 (beep) or in 10-13
                        \ (line feeds and carriage returns), or in 32-95
                        \ (ASCII letters, numbers and punctuation)

 LDX QQ17               \ Fetch QQ17, which controls letter case, into X

 BEQ TT74_C               \ If QQ17 = 0, then ALL CAPS is set, so jump to TT74
                        \ to print this character as is (i.e. as a capital)

 BMI TT41_C               \ If QQ17 has bit 7 set, then we are using Sentence
                        \ Case, so jump to TT41, which will print the
                        \ character in upper or lower case, depending on
                        \ whether this is the first letter in a word

 BIT QQ17               \ If we get here, QQ17 is not 0 and bit 7 is clear, so
 BVS TT46_C               \ either it is bit 6 that is set, or some other flag in
                        \ QQ17 is set (bits 0-5). So check whether bit 6 is set.
                        \ If it is, then ALL CAPS has been set (as bit 7 is
                        \ clear) but bit 6 is still indicating that the next
                        \ character should be printed in lower case, so we need
                        \ to fix this. We do this with a jump to TT46, which
                        \ will print this character in upper case and clear bit
                        \ 6, so the flags are consistent with ALL CAPS going
                        \ forward

                        \ If we get here, some other flag is set in QQ17 (one
                        \ of bits 0-5 is set), which shouldn't happen in this
                        \ version of Elite. If this were the case, then we
                        \ would fall through into TT42 to print in lower case,
                        \ which is how printing all words in lower case could
                        \ be supported (by setting QQ17 to 1, say)

\ ******************************************************************************
\
\       Name: TT42
\       Type: Subroutine
\   Category: Text
\    Summary: Print a letter in lower case
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
\                         * 10-13 (line feeds and carriage returns)
\
\                         * 32-95 (ASCII capital letters, numbers and
\                           punctuation)
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   TT44                Jumps to TT26 to print the character in A (used to
\                       enable us to use a branch instruction to jump to TT26)
\
\ ******************************************************************************

.TT42_C

 CMP #'A'               \ If A < ASCII "A", then this is punctuation, so jump
 BCC TT44_C               \ to TT26 (via TT44) to print the character as is, as
                        \ we don't care about the character's case

 CMP #'Z'+1             \ If A >= (ASCII "Z" + 1), then this is also
 BCS TT44_C               \ punctuation, so jump to TT26 (via TT44) to print the
                        \ character as is, as we don't care about the
                        \ character's case

 ADC #32                \ Add 32 to the character, to convert it from upper to
                        \ lower case

.TT44_C

 JMP x4_TT26               \ Print the character in A

\ ******************************************************************************
\
\       Name: TT41
\       Type: Subroutine
\   Category: Text
\    Summary: Print a letter according to Sentence Case
\
\ ------------------------------------------------------------------------------
\
\ The rules for printing in Sentence Case are as follows:
\
\   * If QQ17 bit 6 is set, print lower case (via TT45)
\
\   * If QQ17 bit 6 is clear, then:
\
\       * If character is punctuation, just print it
\
\       * If character is a letter, set QQ17 bit 6 and print letter as a capital
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
\                         * 10-13 (line feeds and carriage returns)
\
\                         * 32-95 (ASCII capital letters, numbers and
\                           punctuation)
\
\   X                   Contains the current value of QQ17
\
\   QQ17                Bit 7 is set
\
\ ******************************************************************************

.TT41_C

                        \ If we get here, then QQ17 has bit 7 set, so we are in
                        \ Sentence Case

 BIT QQ17               \ If QQ17 also has bit 6 set, jump to TT45 to print
 BVS TT45_C               \ this character in lower case

                        \ If we get here, then QQ17 has bit 6 clear and bit 7
                        \ set, so we are in Sentence Case and we need to print
                        \ the next letter in upper case

 CMP #'A'               \ If A < ASCII "A", then this is punctuation, so jump
 BCC TT74_C               \ to TT26 (via TT44) to print the character as is, as
                        \ we don't care about the character's case

 PHA                    \ Otherwise this is a letter, so store the token number

 TXA                    \ Set bit 6 in QQ17 (X contains the current QQ17)
 ORA #%1000000          \ so the next letter after this one is printed in lower
 STA QQ17               \ case

 PLA                    \ Restore the token number into A

 BNE TT44_C               \ Jump to TT26 (via TT44) to print the character in A
                        \ (this BNE is effectively a JMP as A will never be
                        \ zero)

\ ******************************************************************************
\
\       Name: qw
\       Type: Subroutine
\   Category: Text
\    Summary: Print a recursive token in the range 128-145
\
\ ------------------------------------------------------------------------------
\
\ Print a recursive token where the token number is in 128-145 (so the value
\ passed to TT27 is in the range 14-31).
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   A value from 128-145, which refers to a recursive token
\                       in the range 14-31
\
\ ******************************************************************************

.qw_C

 ADC #114               \ This is a recursive token in the range 0-95, so add
 BNE ex_C                 \ 114 to the argument to get the token number 128-145
                        \ and jump to ex to print it

\ ******************************************************************************
\
\       Name: crlf
\       Type: Subroutine
\   Category: Text
\    Summary: Tab to column 21 and print a colon
\
\ ------------------------------------------------------------------------------
\
\ Print control code 9 (tab to column 21 and print a colon). The subroutine
\ name is pretty misleading, as it doesn't have anything to do with carriage
\ returns or line feeds.
\
\ ******************************************************************************

.crlf_C

 LDA #21                \ Set the X-column in XC to 21
 JSR x4_DOXC

 JMP TT73_C               \ Jump to TT73, which prints a colon (this BNE is
                        \ effectively a JMP as A will never be zero)

\ ******************************************************************************
\
\       Name: TT45
\       Type: Subroutine
\   Category: Text
\    Summary: Print a letter in lower case
\
\ ------------------------------------------------------------------------------
\
\ This routine prints a letter in lower case. Specifically:
\
\   * If QQ17 = 255, abort printing this character as printing is disabled
\
\   * If this is a letter then print in lower case
\
\   * Otherwise this is punctuation, so clear bit 6 in QQ17 and print
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
\                         * 10-13 (line feeds and carriage returns)
\
\                         * 32-95 (ASCII capital letters, numbers and
\                           punctuation)
\
\   X                   Contains the current value of QQ17
\
\   QQ17                Bits 6 and 7 are set
\
\ ******************************************************************************

.TT45_C

                        \ If we get here, then QQ17 has bit 6 and 7 set, so we
                        \ are in Sentence Case and we need to print the next
                        \ letter in lower case

 CPX #255               \ If QQ17 = 255 then printing is disabled, so return
 BEQ TT48_C               \ from the subroutine (as TT48 contains an RTS)

 CMP #'A'               \ If A >= ASCII "A", then jump to TT42, which will
 BCS TT42_C               \ print the letter in lowercase

                        \ Otherwise this is not a letter, it's punctuation, so
                        \ this is effectively a word break. We therefore fall
                        \ through to TT46 to print the character and set QQ17
                        \ to ensure the next word starts with a capital letter

\ ******************************************************************************
\
\       Name: TT46
\       Type: Subroutine
\   Category: Text
\    Summary: Print a character and switch to capitals
\
\ ------------------------------------------------------------------------------
\
\ Print a character and clear bit 6 in QQ17, so that the next letter that gets
\ printed after this will start with a capital letter.
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
\                         * 10-13 (line feeds and carriage returns)
\
\                         * 32-95 (ASCII capital letters, numbers and
\                           punctuation)
\
\   X                   Contains the current value of QQ17
\
\   QQ17                Bits 6 and 7 are set
\
\ ******************************************************************************

.TT46_C

 PHA                    \ Store the token number

 TXA                    \ Clear bit 6 in QQ17 (X contains the current QQ17) so
 AND #%10111111         \ the next letter after this one is printed in upper
 STA QQ17               \ case

 PLA                    \ Restore the token number into A

                        \ Now fall through into TT74 to print the character

\ ******************************************************************************
\
\       Name: TT74
\       Type: Subroutine
\   Category: Text
\    Summary: Print a character
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The character to be printed
\
\ ******************************************************************************

.TT74_C

 JMP x4_TT26               \ Print the character in A

\ ******************************************************************************
\
\       Name: TT43
\       Type: Subroutine
\   Category: Text
\    Summary: Print a two-letter token or recursive token 0-95
\
\ ------------------------------------------------------------------------------
\
\ Print a two-letter token, or a recursive token where the token number is in
\ 0-95 (so the value passed to TT27 is in the range 160-255).
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   One of the following:
\
\                         * 128-159 (two-letter token)
\
\                         * 160-255 (the argument to TT27 that refers to a
\                           recursive token in the range 0-95)
\
\ ******************************************************************************

.TT43_C

 CMP #160               \ If token >= 160, then this is a recursive token, so
 BCS TT47_C               \ jump to TT47 below to process it

 AND #127               \ This is a two-letter token with number 128-159. The
 ASL A                  \ set of two-letter tokens is stored in a lookup table
                        \ at QQ16, with each token taking up two bytes, so to
                        \ convert this into the token's position in the table,
                        \ we subtract 128 (or just clear bit 7) and multiply
                        \ by 2 (or shift left)

 TAY                    \ Transfer the token's position into Y so we can look
                        \ up the token using absolute indexed mode

 LDA QQ16_C,Y             \ Get the first letter of the token and print it
 JSR TT27_C

 LDA QQ16_C+1,Y           \ Get the second letter of the token

 CMP #'?'               \ If the second letter of the token is a question mark
 BEQ TT48_C               \ then this is a one-letter token, so just return from
                        \ the subroutine without printing (as TT48 contains an
                        \ RTS)

 JMP TT27_C               \ Print the second letter and return from the
                        \ subroutine

.TT47_C

 SBC #160               \ This is a recursive token in the range 160-255, so
                        \ subtract 160 from the argument to get the token
                        \ number 0-95 and fall through into ex to print it

\ ******************************************************************************
\
\       Name: ex
\       Type: Subroutine
\   Category: Text
\    Summary: Print a recursive token
\  Deep dive: Printing text tokens
\
\ ------------------------------------------------------------------------------
\
\ This routine works its way through the recursive text tokens that are stored
\ in tokenised form in the table at QQ18, and when it finds token number A,
\ it prints it. Tokens are null-terminated in memory and fill three pages,
\ but there is no lookup table as that would consume too much memory, so the
\ only way to find the correct token is to start at the beginning and look
\ through the table byte by byte, counting tokens as we go until we are in the
\ right place. This approach might not be terribly speed efficient, but it is
\ certainly memory-efficient.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The recursive token to be printed, in the range 0-148
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   TT48                Contains an RTS
\
\ ******************************************************************************

.ex_C

 TAX                    \ Copy the token number into X

 LDA #LO(QQ18)          \ Set V(1 0) to point to the recursive token table at
 STA V                  \ location QQ18
 LDA #HI(QQ18)
 STA V+1

 LDY #0                 \ Set a counter Y to point to the character offset
                        \ as we scan through the table

 TXA                    \ Copy the token number back into A, so both A and X
                        \ now contain the token number we want to print

 BEQ TT50_C               \ If the token number we want is 0, then we have
                        \ already found the token we are looking for, so jump
                        \ to TT50, otherwise start working our way through the
                        \ null-terminated token table until we find the X-th
                        \ token

.TT51_C

 LDA (V),Y              \ Fetch the Y-th character from the token table page
                        \ we are currently scanning

 BEQ TT49_C               \ If the character is null, we've reached the end of
                        \ this token, so jump to TT49

 INY                    \ Increment character pointer and loop back around for
 BNE TT51_C               \ the next character in this token, assuming Y hasn't
                        \ yet wrapped around to 0

 INC V+1                \ If it has wrapped round to 0, we have just crossed
 BNE TT51_C               \ into a new page, so increment V+1 so that V points
                        \ to the start of the new page

.TT49_C

 INY                    \ Increment the character pointer

 BNE TT59_C               \ If Y hasn't just wrapped around to 0, skip the next
                        \ instruction

 INC V+1                \ We have just crossed into a new page, so increment
                        \ V+1 so that V points to the start of the new page

.TT59_C

 DEX                    \ We have just reached a new token, so decrement the
                        \ token number we are looking for

 BNE TT51_C               \ Assuming we haven't yet reached the token number in
                        \ X, look back up to keep fetching characters

.TT50_C

                        \ We have now reached the correct token in the token
                        \ table, with Y pointing to the start of the token as
                        \ an offset within the page pointed to by V, so let's
                        \ print the recursive token. Because recursive tokens
                        \ can contain other recursive tokens, we need to store
                        \ our current state on the stack, so we can retrieve
                        \ it after printing each character in this token

 TYA                    \ Store the offset in Y on the stack
 PHA

 LDA V+1                \ Store the high byte of V (the page containing the
 PHA                    \ token we have found) on the stack, so the stack now
                        \ contains the address of the start of this token

 LDA (V),Y              \ Load the character at offset Y in the token table,
                        \ which is the next character of this token that we
                        \ want to print

 EOR #RE                \ Tokens are stored in memory having been EOR'd with the
                        \ value of RE - which is 35 for all versions of Elite
                        \ except for NES, where RE is 62 - so we repeat the
                        \ EOR to get the actual character to print

 JSR TT27_C               \ Print the text token in A, which could be a letter,
                        \ number, control code, two-letter token or another
                        \ recursive token

 PLA                    \ Restore the high byte of V (the page containing the
 STA V+1                \ token we have found) into V+1

 PLA                    \ Restore the offset into Y
 TAY

 INY                    \ Increment Y to point to the next character in the
                        \ token we are printing

 BNE P%+4               \ If Y is zero then we have just crossed into a new
 INC V+1                \ page, so increment V+1 so that V points to the start
                        \ of the new page

 LDA (V),Y              \ Load the next character we want to print into A

 BNE TT50_C               \ If this is not the null character at the end of the
                        \ token, jump back up to TT50 to print the next
                        \ character, otherwise we are done printing

.TT48_C

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TKRD, RUPRD, RUGRD
\       Type: Subroutine
\   Category: Text
\    Summary: Port: read the extended token tables in shadow RAM
\
\ ------------------------------------------------------------------------------
\
\ The extended tokens (TKN1, RUPLA, RUGAL, RUTOK) are in shadow RAM at &3100
\ (docs/MASTER-MAP.md), visible at &3000-&7FFF only while ACCCON X is set.
\ These replace the original's reads: they leave A and the N and Z flags as
\ LDA (V),Y, LDA RUPLA-1,Y and LDA RUGAL-1,Y would, and C and V unchanged.
\ ACCCON X is set and cleared on its own (TSB/TRB), leaving the other bits
\ alone. They are in the cold area, which stays visible while X is set.
\
\ ******************************************************************************

.TKRD_C

 LDA #%00000100         \ Set ACCCON X: shadow RAM at &3000-&7FFF
 TSB VIA+&34
 LDA (V),Y              \ The token byte (bankcheck: ok)
 PHA
 LDA #%00000100         \ Clear ACCCON X: main RAM back at &3000-&7FFF
 TRB VIA+&34
 PLA                    \ A and its N and Z flags
 RTS

.RUPRD_C

 LDA #%00000100
 TSB VIA+&34
 LDA RUPLA-1,Y          \ bankcheck: ok
 PHA
 LDA #%00000100
 TRB VIA+&34
 PLA
 RTS

.RUGRD_C

 LDA #%00000100
 TSB VIA+&34
 LDA RUGAL-1,Y          \ bankcheck: ok
 PHA
 LDA #%00000100
 TRB VIA+&34
 PLA
 RTS
