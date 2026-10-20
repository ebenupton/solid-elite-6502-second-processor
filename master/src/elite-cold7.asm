\ ******************************************************************************
\
\ elite-cold7.asm - cold code in bank 7 (COLD7LO-&BFFF)
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
 JSR DOXC_C

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

 JMP TT66_C               \ Jump to TT66 to clear the screen and set the current
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
 EQUW NLIN4_C             \ Token 11: Draw box around title (line at pixel row 19)
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
 EQUW PAUSE_C             \ Token 22: Display ship and wait for key press
 EQUW MT23_C              \ Token 23: Move to row 10, white text, set lower case
 EQUW PAUSE2_C            \ Token 24: Wait for a key press
 EQUW BRIS_C              \ Token 25: Show incoming message screen, wait 2 seconds
 EQUW MT26_C              \ Token 26: Fetch line input from keyboard (filename)
 EQUW MT27_C              \ Token 27: Print mission captain's name (217-219)
 EQUW MT28_C              \ Token 28: Print mission 1 location hint (220-221)
 EQUW MT29_C              \ Token 29: Column 6, white text, lower case in words
 EQUW FILEPR_C            \ Token 30: Display currently selected media (disk/tape)
 EQUW x4_DASC              \ Token 31: Display the non-selected media (disk/tape)
                        \ (Port: unused, as no token has control code 31, so
                        \ x4_DASC as for 20 and 32; OTHERFILEPR is removed)
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

 JSR TT54_C               \ Step 3: twist the seeds in QQ15

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

 JMP pr2_C                \ Jump to pr2, which prints the number in X to a width
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

 JSR pr2_C                \ Call pr2, which prints the number in X to a width of
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

 JSR BPRNT_C              \ Print the amount of cash to 9 digits with a decimal
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

 JMP TT67_C               \ Jump to TT67 to print a newline and return from the
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
 JSR DOXC_C

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

.TT51w_C

                        \ Port: TT51w and TT49w are here, out of the way, so
                        \ that the scan loop in ex below stays in one page

 INC V+1                \ We have just crossed into a new page, so increment
 INC TT51_C+2           \ V+1 (and the LDA operand) so that V points to the
 BNE TT51_C             \ start of the new page, and keep scanning (this BNE
                        \ is always taken)

.TT49w_C

 INC V+1                \ We have just crossed into a new page, so increment
 INC TT51_C+2           \ V+1 (and the LDA operand) so that V points to the
 BNE TT59_C             \ start of the new page, and go on to count the token
                        \ (this BNE is always taken)

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

 LDA #LO(QQ18)          \ Set the low byte of V(1 0) to that of the recursive
 STA V                  \ token table at QQ18

 PHP                    \ Port: rather than scan from token 0, start at token
 TXA                    \ 16*k (k = token DIV 16, 0-9), whose page and offset
 LSR A                  \ are in QQ18IX_C, and skip only the remaining 0-15
 LSR A                  \ tokens; V(1 0), Y and the LDA operand below end up
 LSR A                  \ as the full scan from QQ18 leaves them (the flags
 LSR A                  \ are saved around the shifts, so C and V are kept)
 TAY

 LDA QQ18IX_C,Y         \ Set V+1 to the page of token 16*k
 STA V+1
 STA TT51_C+2           \ Port: the scan below reads with LDA abs,Y, whose
                        \ operand (low byte LO(QQ18), high byte patched here and
                        \ incremented alongside V+1) always equals V(1 0)

 LDA QQ18IX_C+10,Y      \ Set Y to the offset of token 16*k within that page
 TAY

 PLP                    \ Restore the flags

 TXA                    \ Set X to the number of tokens still to skip, the
 AND #15                \ token number mod 16
 TAX

 BEQ TT50_C               \ If there are none, then we have already found the
                        \ token we are looking for, so jump to TT50, otherwise
                        \ work our way through the null-terminated token table
                        \ until we have skipped X more tokens

.TT51_C

 LDA QQ18,Y             \ Fetch the Y-th character from the token table page
                        \ we are currently scanning (the operand's high byte is
                        \ self-modified to track V+1, so this is LDA (V),Y)

 BEQ TT49_C               \ If the character is null, we've reached the end of
                        \ this token, so jump to TT49

 INY                    \ Increment character pointer and loop back around for
 BNE TT51_C               \ the next character in this token, assuming Y hasn't
                        \ yet wrapped around to 0

 BEQ TT51w_C            \ Y has wrapped round to 0, so jump to TT51w to move to
                        \ the next page (this BEQ is always taken)

.TT49_C

 INY                    \ Increment the character pointer

 BEQ TT49w_C            \ If Y has just wrapped around to 0, jump to TT49w to
                        \ move to the next page

.TT59_C

 DEX                    \ We have just reached a new token, so decrement the
                        \ token number we are looking for

 BNE TT51_C               \ Assuming we haven't yet reached the token number in
                        \ X, look back up to keep fetching characters

                        \ Otherwise we have found the token, so fall through
                        \ into TT50 to print it

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
\       Name: QQ18IX_C
\       Type: Variable
\   Category: Text
\    Summary: Port: where every 16th recursive token starts in QQ18, for ex
\
\ ------------------------------------------------------------------------------
\
\ Entry k is token 16*k as ex's scan from QQ18 would leave it, with V = LO(QQ18):
\ the page (V+1) in the first ten bytes, the offset (Y) in the next ten. The
\ offsets are those of tokens 0, 16, ..., 144 in QQ18 (elite-data.asm), whose
\ contents are the original game's and never change.
\
\ ******************************************************************************

.QQ18IX_C

 EQUB HI(QQ18 + &000 - LO(QQ18))   \ Token 0
 EQUB HI(QQ18 + &069 - LO(QQ18))   \ Token 16
 EQUB HI(QQ18 + &0E1 - LO(QQ18))   \ Token 32
 EQUB HI(QQ18 + &14E - LO(QQ18))   \ Token 48
 EQUB HI(QQ18 + &1B9 - LO(QQ18))   \ Token 64
 EQUB HI(QQ18 + &208 - LO(QQ18))   \ Token 80
 EQUB HI(QQ18 + &26F - LO(QQ18))   \ Token 96
 EQUB HI(QQ18 + &2C8 - LO(QQ18))   \ Token 112
 EQUB HI(QQ18 + &340 - LO(QQ18))   \ Token 128
 EQUB HI(QQ18 + &397 - LO(QQ18))   \ Token 144

 EQUB LO(QQ18 + &000 - LO(QQ18))   \ Token 0
 EQUB LO(QQ18 + &069 - LO(QQ18))   \ Token 16
 EQUB LO(QQ18 + &0E1 - LO(QQ18))   \ Token 32
 EQUB LO(QQ18 + &14E - LO(QQ18))   \ Token 48
 EQUB LO(QQ18 + &1B9 - LO(QQ18))   \ Token 64
 EQUB LO(QQ18 + &208 - LO(QQ18))   \ Token 80
 EQUB LO(QQ18 + &26F - LO(QQ18))   \ Token 96
 EQUB LO(QQ18 + &2C8 - LO(QQ18))   \ Token 112
 EQUB LO(QQ18 + &340 - LO(QQ18))   \ Token 128
 EQUB LO(QQ18 + &397 - LO(QQ18))   \ Token 144

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

\ ******************************************************************************
\
\       Name: setzp
\       Type: Subroutine
\   Category: Utility routines
\    Summary: Copy the top part of zero page (&0090 to &00FF) into the buffer at
\             &3000
\
\ ******************************************************************************

.setzp_C

IF _COMPACT

 JSR NMICLAIM_C           \ Claim the NMI workspace (&00A0 to &00A7) from the MOS
                        \ so the game can use it

ENDIF

 LDA #%00001111         \ Set bits 1 and 2 of the Access Control Register at
 STA VIA+&34            \ SHEILA &34 to switch screen memory into &3000-&7FFF

 LDX #&90               \ We want to save zero page from &0090 and up, so set an
                        \ index in X, starting from &90

.sz1_C

 LDA ZP,X               \ Copy the X-th byte of ZP to the X-th byte of &3000
 STA &3000,X

 INX                    \ Increment the loop counter

 BNE sz1_C                \ Loop back until we have copied the last byte of zero
                        \ page

 LDA #%00001001         \ Clear bits 1 and 2 of the Access Control Register at
 STA VIA+&34            \ SHEILA &34 to switch main memory back into &3000-&7FFF

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: NMIRELEASE
\       Type: Subroutine
\   Category: Utility routines
\    Summary: Release the NMI workspace (&00A0 to &00A7) so the MOS can use it
\             and store the top part of zero page in the buffer at &3000
\
\ ******************************************************************************

IF _COMPACT

.NMIRELEASE_C

 JSR getzp_C+3            \ Call getzp+3 to restore the top part of zero page
                        \ from the buffer at &3000, but without first claiming
                        \ the NMI workspace (as it's already been claimed by
                        \ this point)

 LDA #143               \ Call OSBYTE 143 to issue a paged ROM service call of
 LDX #&B                \ type &B with Y set to the previous NMI owner's ID.
 LDY NMI                \ This releases the NMI workspace back to the original
 JMP OSBYTE             \ owner, from whom we claimed the workspace in the
                        \ NMICLAIM routine, and returns from the subroutine
                        \ using a tail call

ENDIF

\ ******************************************************************************
\
\       Name: getzp
\       Type: Subroutine
\   Category: Utility routines
\    Summary: Swap zero page (&0090 to &00EF) with the buffer at &3000
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   getzp+3             Restore the top part of zero page, but without first
\                       claiming the NMI workspace (Master Compact variant only)
\
\ ******************************************************************************

.getzp_C

IF _COMPACT

 JSR NMICLAIM_C           \ Claim the NMI workspace (&00A0 to &00A7) from the MOS
                        \ so the game can use it

ENDIF

 LDA #%00001111         \ Set bits 1 and 2 of the Access Control Register at
 STA VIA+&34            \ SHEILA &34 to switch screen memory into &3000-&7FFF

 LDX #&90               \ We want to swap zero page from &0090 and up, so set an
                        \ index in X, starting from &90

.sz2_C

 LDA ZP,X               \ Swap the X-th byte of ZP with the X-th byte of &3000
 LDY &3000,X
 STY ZP,X
 STA &3000,X

 INX                    \ Increment the loop counter

 CPX #&F0               \ Loop back until we have swapped up to location &00EF
 BNE sz2_C

 LDA #%00001001         \ Clear bits 1 and 2 of the Access Control Register at
 STA VIA+&34            \ SHEILA &34 to switch main memory back into &3000-&7FFF

                        \ Port: the original set the ROM Select latch to bank 6
                        \ here, to page the game's data back in after disc
                        \ access. getzp now runs in the cold area, so it leaves
                        \ ROMSEL alone: the far call that reaches it pages the
                        \ caller's bank back in, and NEWBRK pages Elite's home
                        \ bank in itself before calling it

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: NMICLAIM
\       Type: Subroutine
\   Category: Utility routines
\    Summary: Claim the NMI workspace (&00A0 to &00A7) back from the MOS so the
\             game can use it once again
\
\ ******************************************************************************

IF _COMPACT

.NMICLAIM_C

 LDA #143               \ Call OSBYTE 143 to issue a paged ROM service call of
 LDX #&C                \ type &C with argument &FF, which is the "NMI claim"
 LDY #&FF               \ service call that asks the current user of the NMI
 JSR OSBYTE             \ space to clear it out

 STY NMI                \ Save the returned value of Y in NMI, as it contains
                        \ the filing system ID of the previous claimant of the
                        \ NMI, which we need to restore once we have finished
                        \ using the NMI workspace

 RTS                    \ Return from the subroutine

ENDIF

\ ******************************************************************************
\
\       Name: YESNO
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Wait until either "Y" or "N" is pressed
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              Set if "Y" was pressed, clear if "N" was pressed
\
\ ******************************************************************************

.YESNO_C

 JSR t_C                  \ Scan the keyboard until a key is pressed, returning
                        \ the ASCII code in A and X

 CMP #'Y'               \ If "Y" was pressed, return from the subroutine with
 BNE P%+3               \ the C flag set (as the CMP sets the C flag; Port: the
 RTS                    \ original branched to the RTS at PL6, in PLANET)

 CMP #'N'               \ If "N" was not pressed, loop back to keep scanning
 BNE YESNO_C              \ for key presses

 CLC                    \ Clear the C flag

 RTS                    \ Return from the subroutine

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
\ ******************************************************************************

.RESET_C

 JSR ZERO_C               \ Reset the ship slots for the local bubble of universe,
                        \ and various flight and ship status variables

 LDX #6                 \ Set up a counter for zeroing BETA through BETA+6

.SAL3_C

 STA BETA,X             \ Zero the X-th byte after BETA

 DEX                    \ Decrement the loop counter

 BPL SAL3_C               \ Loop back for the next byte to zero

 STX JSTGY              \ X is now negative - i.e. &FF - so this sets JSTGY to
                        \ &FF to set the joystick Y-channel to the default
                        \ direction

 TXA                    \ X is now negative - i.e. &FF - so this sets A and QQ12
 STA QQ12               \ to &FF to indicate we are docked

 LDX #2                 \ We're now going to recharge both shields and the
                        \ energy bank, which live in the three bytes at FSH,
                        \ ASH (FSH+1) and ENERGY (FSH+2), so set a loop counter
                        \ in X for 3 bytes

.REL5_C

 STA FSH,X              \ Set the X-th byte of FSH to &FF to charge up that
                        \ shield/bank

 DEX                    \ Decrement the loop counter

 BPL REL5_C               \ Loop back to REL5 until we have recharged both shields
                        \ and the energy bank

                        \ Fall through into RES2 to reset the stardust and ship
                        \ workspace at INWK

\ ******************************************************************************
\
\       Name: RES2
\       Type: Subroutine
\   Category: Start and end
\    Summary: Reset a number of flight variables and workspaces
\
\ ------------------------------------------------------------------------------
\
\ This is called after we launch from a space station, arrive in a new system
\ after hyperspace, launch an escape pod, or die a cold, lonely death in the
\ depths of space.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   Y                   Y is set to &FF
\
\ ******************************************************************************

.RES2_C

\JSR stopbd             \ This instruction is commented out in the original
                        \ source

 LDA #NOST              \ Reset NOSTM, the number of stardust particles, to the
 STA NOSTM              \ maximum allowed (20)

 LDX #&FF               \ Reset LSX2 and LSY2, the ball line heaps used by the
 STX LSX2               \ BLINE routine for drawing circles, to &FF, to set the
 STX LSY2               \ heap to empty

 STX MSTG               \ Reset MSTG, the missile target, to &FF (no target)

 LDA #128               \ Set the current pitch rate to the mid-point, 128
 STA JSTY

 STA ALP2               \ Reset ALP2 (roll sign) and BET2 (pitch sign)
 STA BET2               \ to negative, i.e. pitch and roll negative

 ASL A                  \ This sets A to 0

 STA BETA               \ Reset BETA (pitch angle alpha) to 0

 STA BET1               \ Reset BET1 (magnitude of the pitch angle) to 0

 STA ALP2+1             \ Reset ALP2+1 (flipped roll sign) and BET2+1 (flipped
 STA BET2+1             \ pitch sign) to positive, i.e. pitch and roll negative

 STA MCNT               \ Reset MCNT (the main loop counter) to 0

\STA TRIBCT             \ This instruction is commented out in the original
                        \ source; it is left over from the Commodore 64 version
                        \ of Elite and would reset the number of Trumbles

 LDA #3                 \ Reset DELTA (speed) to 3
 STA DELTA

 STA ALPHA              \ Reset ALPHA (roll angle alpha) to 3

 STA ALP1               \ Reset ALP1 (magnitude of roll angle alpha) to 3

\LDA #&10               \ These instructions are commented out in the original
\STA COL2               \ source

 LDA #0                 \ Set dontclip to 0 (though this variable is never used,
 STA dontclip           \ so this has no effect; it is left over from the
                        \ Commodore 64 version)

 LDA #2*Y-1             \ Set Yx2M1 to the number of pixel lines in the space
 STA Yx2M1              \ view

 LDA SSPR               \ Fetch the "space station present" flag, and if we are
 BEQ P%+5               \ not inside the safe zone, skip the next instruction

 JSR x4_SPBLB              \ Light up the space station bulb on the dashboard

 LDA ECMA               \ Fetch the E.C.M. status flag, and if E.C.M. is off,
 BEQ yu_C                 \ skip the next instruction

 JSR x4_ECMOF              \ Turn off the E.C.M. sound

.yu_C

 JSR x4_WPSHPS             \ Wipe all ships from the scanner

 JSR ZERO_C               \ Reset the ship slots for the local bubble of universe,
                        \ and various flight and ship status variables

 LDA #LO(LS%)           \ We have reset the ship line heap, so we now point
 STA SLSP               \ SLSP to LS% (the byte below the ship blueprints at D%)
 LDA #HI(LS%)           \ to indicate that the heap is empty
 STA SLSP+1

 JMP x4_ZINF            \ Finally, reset the INWK ship workspace with ZINF and
                        \ return (Port: the original fell through into ZINF)

\ ******************************************************************************
\
\       Name: TT170
\       Type: Subroutine
\   Category: Start and end
\    Summary: Main entry point for the Elite game code
\  Deep dive: Program flow of the main game loop
\
\ ------------------------------------------------------------------------------
\
\ This is the main entry point for the main game code.
\
\ ******************************************************************************

.TT170_C

 LDX #&FF               \ Set the stack pointer to &01FF, which is the standard
 TXS                    \ location for the 6502 stack, so this instruction
                        \ effectively resets the stack

 JSR RESET_C              \ Call RESET to initialise most of the game variables

                        \ Fall through into DEATH2 to start the game

\ ******************************************************************************
\
\       Name: DEATH2
\       Type: Subroutine
\   Category: Start and end
\    Summary: Reset most of the game and restart from the title screen
\
\ ------------------------------------------------------------------------------
\
\ This routine is called following death, and when the game is quit by pressing
\ ESCAPE when paused.
\
\ ******************************************************************************

.DEATH2_C

 LDX #&FF               \ Set the stack pointer to &01FF, which is the standard
 TXS                    \ location for the 6502 stack, so this instruction
                        \ effectively resets the stack

 JSR RES2_C               \ Reset a number of flight variables and workspaces
                        \ and fall through into the entry code for the game
                        \ to restart from the title screen

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
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   QU5                 Restart the game using the last saved commander without
\                       asking whether to load a new commander file
\
\ ******************************************************************************

.BR1_C

 JSR x4_ZEKTRAN            \ Call ZEKTRAN to clear the key logger

 LDA #3                 \ Set XC = 3 (set text cursor to column 3)
 STA XC

\JSR startat            \ This instruction is commented out in the original
                        \ source

 LDX #CYL               \ Call TITLE to show a rotating Cobra Mk III (#CYL) and
 LDA #6                 \ token 6 ("LOAD NEW {single cap}COMMANDER {all caps}
 LDY #200               \ (Y/N)?{sentence case}{cr}{cr}"), with the ship at a
 JSR TITLE_C              \ distance of 200, returning with the internal number
                        \ of the key pressed in A

 CPX #'Y'               \ Did we press "Y"? If not, jump to QU5, otherwise
 BNE QU5_C                \ continue on to load a new commander

\JSR stopat             \ This instruction is commented out in the original
                        \ source

 JSR DFAULT_C             \ Call DFAULT to reset the current commander data block
                        \ to the last saved commander

 JSR SVE_C                \ Call SVE to load a new commander into the last saved
                        \ commander data block

\JSR startat            \ This instruction is commented out in the original
                        \ source

.QU5_C

 JSR DFAULT_C             \ Call DFAULT to reset the current commander data block
                        \ to the last saved commander

\ ******************************************************************************
\
\       Name: BR1 (Part 2 of 2)
\       Type: Subroutine
\   Category: Start and end
\    Summary: Show the "Press Fire or Space, Commander" screen and start the
\             game
\
\ ------------------------------------------------------------------------------
\
\ BRKV is set to point to BR1 by the loading process.
\
\ ******************************************************************************

 JSR x4_msblob              \ Reset the dashboard's missile indicators so none of
                        \ them are targeted

 LDA #7                 \ Call TITLE to show a rotating Cougar (#COU) and token
 LDX #COU               \ 7 ("PRESS SPACE OR FIRE,{single cap}COMMANDER.{cr}
 LDY #100               \ {cr}"), with the ship at a distance of 100, returning
 JSR TITLE_C              \ with the internal number of the key pressed in A

 JSR ping_C               \ Set the target system coordinates (QQ9, QQ10) to the
                        \ current system coordinates (QQ0, QQ1) we just loaded

 JSR TT111_C              \ Select the system closest to galactic coordinates
                        \ (QQ9, QQ10)

 JSR jmp_C                \ Set the current system to the selected system

 LDX #5                 \ We now want to copy the seeds for the selected system
                        \ in QQ15 into QQ2, where we store the seeds for the
                        \ current system, so set up a counter in X for copying
                        \ 6 bytes (for three 16-bit seeds)

                        \ The label below is called likeTT112 because this code
                        \ is almost identical to the TT112 loop in the hyp1
                        \ routine

.likeTT112_C

 LDA QQ15,X             \ Copy the X-th byte in QQ15 to the X-th byte in QQ2
 STA QQ2,X

 DEX                    \ Decrement the counter

 BPL likeTT112_C          \ Loop back to likeTT112 if we still have more bytes to
                        \ copy

 INX                    \ Set X = 0 (as we ended the above loop with X = &FF)

 STX EV                 \ Set EV, the extra vessels spawning counter, to 0, as
                        \ we are entering a new system with no extra vessels
                        \ spawned

 LDA QQ3                \ Set the current system's economy in QQ28 to the
 STA QQ28               \ selected system's economy from QQ3

 LDA QQ5                \ Set the current system's tech level in tek to the
 STA tek                \ selected system's economy from QQ5

 LDA QQ4                \ Set the current system's government in gov to the
 STA gov                \ selected system's government from QQ4

                        \ Fall through into the docking bay routine below

\ ******************************************************************************
\
\       Name: BAY
\       Type: Subroutine
\   Category: Status
\    Summary: Go to the docking bay (i.e. show the Status Mode screen)
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

.BAY_C

 LDA #&FF               \ Set QQ12 = &FF (the docked flag) to indicate that we
 STA QQ12               \ are docked

 LDA #f8                \ Jump into the main loop at FRCE, setting the key
 JMP j4_FRCE               \ that's "pressed" to red key f8 (so we show the Status
                        \ Mode screen)

\ ******************************************************************************
\
\       Name: DFAULT
\       Type: Subroutine
\   Category: Start and end
\    Summary: Reset the current commander data block to the last saved commander
\
\ ******************************************************************************

.DFAULT_C

 LDX #NT%+8             \ The size of the last saved commander data block is NT%
                        \ bytes, and it is preceded by the 8 bytes of the
                        \ commander name (seven characters plus a carriage
                        \ return). The commander data block at NAME is followed
                        \ by the commander data block, so we need to copy the
                        \ name and data from the "last saved" buffer at NA% to
                        \ the current commander workspace at NAME. So we set up
                        \ a counter in X for the NT% + 8 bytes that we want to
                        \ copy

.QUL1_C

 LDA NA%-1,X            \ Copy the X-th byte of NA%-1 to the X-th byte of
 STA NAME-1,X           \ NAME-1 (the -1 is because X is counting down from
                        \ NT% + 8 to 1)

 DEX                    \ Decrement the loop counter

 BNE QUL1_C               \ Loop back for the next byte of the commander data
                        \ block

 STX QQ11               \ X is 0 by the end of the above loop, so this sets QQ11
                        \ to 0, which means we will be showing a view without a
                        \ boxed title at the top (i.e. we're going to use the
                        \ screen layout of a space view in the following)

                        \ If the commander check below fails, we keep jumping
                        \ back to here to crash the game with an infinite loop

.doitagain_C

 JSR CHECK_C              \ Call the CHECK subroutine to calculate the checksum
                        \ for the current commander block at NA%+8 and put it
                        \ in A

 CMP CHK                \ Test the calculated checksum against CHK

IF _REMOVE_CHECKSUMS

 NOP                    \ If we have disabled checksums, then ignore the result
 NOP                    \ of the comparison and fall through into the next part

ELSE

 BNE doitagain_C          \ If the calculated checksum does not match CHK, then
                        \ loop back to repeat the check - in other words, we
                        \ enter an infinite loop here, as the checksum routine
                        \ will keep returning the same incorrect value

ENDIF

                        \ The checksum CHK is correct, so now we check whether
                        \ CHK2 = CHK EOR A9, and if this check fails, bit 7 of
                        \ the competition flags at COK gets set, to indicate
                        \ to Acornsoft via the competition code that there has
                        \ been some hacking going on with this competition entry

 EOR #&A9               \ X = checksum EOR &A9
 TAX

 LDA COK                \ Set A to the competition flags in COK

 CPX CHK2               \ If X = CHK2, then skip the next instruction
 BEQ tZ_C

 ORA #%10000000         \ Set bit 7 of A to indicate this commander file has
                        \ been tampered with

.tZ_C

 ORA #%00001000         \ Set bit 3 of A to denote that this is the Master
                        \ version (which is the same flag as the Apple II
                        \ version)

 STA COK                \ Store the updated competition flags in COK

\JSR CHECK2             \ These instructions are commented out in the original
\                       \ source
\CMP CHK3
\BNE doitagain

 RTS                    \ Return from the subroutine

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
\   A                   The number of the extended token to show below the
\                       rotating ship (see variable TKN1 for details of
\                       recursive tokens)
\
\   X                   The type of the ship to show (see variable XX21 for a
\                       list of ship types)
\
\   Y                   The distance to show the ship rotating, once it has
\                       finished moving towards us
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   X                   If a key is being pressed, X contains the ASCII code
\                       of the key pressed
\
\ ******************************************************************************

.TITLE_C

 STY distaway           \ Store the ship distance in distaway

 PHA                    \ Store the token number on the stack for later

 STX TYPE               \ Store the ship type in location TYPE

 JSR RESET_C              \ Reset our ship so we can use it for the rotating
                        \ title ship

 JSR x4_ZEKTRAN            \ Call ZEKTRAN to clear the key logger

 JSR x4_ZINF               \ Call ZINF to reset the INWK ship workspace

 LDA #32                \ Set the mode 1 palette to yellow (colour 1), white
 JSR x4_DOVDU19            \ (colour 2) and cyan (colour 3)

 LDA #13                \ Clear the top part of the screen, draw a border box,
 JSR TT66_C               \ and set the current view type in QQ11 to 13 (rotating
                        \ ship view)

 LDA #RED               \ Switch to colour 2, which is white in the title screen
 STA COL

 LDA #0                 \ Set QQ11 to 0, so from here on we are using a space
 STA QQ11               \ view

 LDA #96                \ Set nosev_z hi = 96 (96 is the value of unity in the
 STA INWK+14            \ rotation vector)

 LDA #96                \ Set A = 96 as the distance that the ship starts at

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

 LDA #6                 \ Move the text cursor to column 6
 STA XC

 LDA #30                \ Print recursive token 144 ("---- E L I T E ----")
 JSR plf_C                \ followed by a newline

 LDA #10                \ Print a line feed to move the text cursor down a line
 JSR x4_TT26

 LDA #6                 \ Move the text cursor to column 6 again
 STA XC

 LDA PATG               \ If PATG = 0, skip the following two lines, which
 BEQ awe_C                \ print the author credits (PATG can be toggled by
                        \ pausing the game and pressing "X")

 LDA #13                \ Print extended token 13 ("BY D.BRABEN & I.BELL")
 JSR DETOK_C

.awe_C

 LDY #0                 \ Set DELTA = 0 (i.e. ship speed = 0)
 STY DELTA

 STY JSTK               \ Set JSTK = 0 (i.e. keyboard, not joystick)

 LDA #20                \ Move the text cursor to row 20
 STA YC

 LDA #1                 \ Move the text cursor to column 1
 STA XC

 PLA                    \ Restore the recursive token number we stored on the
                        \ stack at the start of this subroutine

 JSR DETOK_C              \ Print the extended token in A

 LDA #7                 \ Move the text cursor to column 7
 STA XC

 LDA #12                \ Print extended token 12 ("({single cap}C) ACORNSOFT
 JSR DETOK_C              \ 1986")

 LDA #12                \ Set CNT2 = 12 as the outer loop counter for the loop
 STA CNT2               \ starting at TLL2

 LDA #5                 \ Set the main loop counter in MCNT to 5, to act as the
 STA MCNT               \ inner loop counter for the loop starting at TLL2

 STZ JSTK               \ Set JSTK = 0 (i.e. keyboard, not joystick)

.TLL2_C

 LDA INWK+7             \ If z_hi (the ship's distance) is 1, jump to TL1 to
 CMP #1                 \ skip the following decrement
 BEQ TL1_C

 DEC INWK+7             \ Decrement the ship's distance, to bring the ship
                        \ a bit closer to us

.TL1_C

 JSR x4_MVEIT              \ Move the ship in space according to the orientation
                        \ vectors and the new value in z_hi

 LDX distaway           \ Set z_lo to the distance value we passed to the
 STX INWK+6             \ routine, so this is the closest the ship gets to us

 LDA #0                 \ Set x_lo = 0, so the ship remains in the screen centre
 STA INWK

 STA INWK+3             \ Set y_lo = 0, so the ship remains in the screen centre

 JSR x4_LL9F               \ Call LL9 to display the ship, then render the frame
                        \ (Port: LL9F)

 DEC MCNT               \ Decrement the main loop counter

IF _SNG47

 LDA VIA+&40            \ Read 6522 System VIA input register IRB (SHEILA &40)

 AND #%00010000         \ Bit 4 of IRB (PB4) is clear if joystick 1's fire
                        \ button is pressed, otherwise it is set, so AND'ing
                        \ the value of IRB with %10000 extracts this bit

ELIF _COMPACT

 JSR x4_RDFIRE             \ Call RDFIRE to check whether the joystick's fire
                        \ button is being pressed

 BCS TL3_C                \ If the C flag is set then the joystick fire button
                        \ is being pressed, so jump to TL3

ENDIF

IF _SNG47

 BEQ TL3_C                \ If the joystick fire button is pressed, jump to TL3

ENDIF

 JSR x4_RDKEY              \ Scan the keyboard for a key press and return the ASCII
                        \ code of the key pressed in A and X (or 0 for no key
                        \ press)

 BEQ TLL2_C               \ If no key was pressed, loop back up to move/rotate
                        \ the ship and check again for a key press

 RTS                    \ Return from the subroutine

.TL3_C

 DEC JSTK               \ Joystick fire button was pressed, so set JSTK to &FF
                        \ (it was set to 0 above), to disable keyboard and
                        \ enable joysticks

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: CHECK
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

.CHECK_C

 LDX #NT%-3             \ Set X to the size of the commander data block, less
                        \ 3 (as there are two checksum bytes and the save count)

 CLC                    \ Clear the C flag so we can do addition without the
                        \ C flag affecting the result

 TXA                    \ Seed the checksum calculation by setting A to the
                        \ size of the commander data block, less 2

                        \ We now loop through the commander data block,
                        \ starting at the end and looping down to the start
                        \ (so at the start of this loop, the X-th byte is the
                        \ last byte of the commander data block, i.e. the save
                        \ count)

.QUL2_C

 ADC NA%+7,X            \ Add the X-1-th byte of the data block to A, plus the
                        \ C flag

 EOR NA%+8,X            \ EOR A with the X-th byte of the data block

 DEX                    \ Decrement the loop counter

 BNE QUL2_C               \ Loop back for the next byte in the calculation, until
                        \ we have added byte #0 and EOR'd with byte #1 of the
                        \ data block

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: CHECK2
\       Type: Subroutine
\   Category: Save and load
\    Summary: Calculate the third checksum for the last saved commander data
\             block (Commodore 64 and Apple II versions only)
\
\ ******************************************************************************

.CHECK2_C

\LDX #NT%-3             \ These instructions are commented out in the original
\                       \ source (they are from the Commodore 64 and Apple II
\CLC                    \ versions, and implement the third commander checksum
\                       \ which the Master version doesn't have)
\TXA
\
\.QU2L2
\
\STX T
\EOR T
\ROR A
\
\ADC NA%+7,X
\
\EOR NA%+8,X
\
\DEX
\
\BNE QU2L2
\
\RTS

\ ******************************************************************************
\
\       Name: JAMESON
\       Type: Subroutine
\   Category: Save and load
\    Summary: Restore the default JAMESON commander
\
\ ******************************************************************************

.JAMESON_C

 LDY #(NAEND%-NA2%)     \ We are going to copy the default commander at NA2%
                        \ over the top of the last saved commander at NA%, so
                        \ set a counter to copy all the bytes between NA2% and
                        \ NAEND%

.JAMEL1_C

 LDA NA2%,Y             \ Copy the Y-th byte of NA2% to the Y-th byte of NA%
 STA NA%,Y

 DEY                    \ Decrement the loop counter

 BPL JAMEL1_C             \ Loop back until we have copied the whole commander

 LDY #7                 \ Set oldlong to 7, the length of the commander name
 STY oldlong            \ "JAMESON"

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TRNME
\       Type: Subroutine
\   Category: Save and load
\    Summary: Copy the last saved commander's name from INWK to NA%
\
\ ******************************************************************************

.TRNME_C

 LDX #7                 \ The commander's name can contain a maximum of 7
                        \ characters, and is terminated by a carriage return,
                        \ so set up a counter in X to copy 8 characters

 LDA thislong           \ Copy the length of the commander's name from thislong
 STA oldlong            \ to oldlong (though this is never used, so this
                        \ doesn't have any effect)

.GTL1_C

 LDA INWK+5,X           \ Copy the X-th byte of INWK+5 to the X-th byte of NA%
 STA NA%,X

 DEX                    \ Decrement the loop counter

 BPL GTL1_C               \ Loop back until we have copied all 8 bytes

                        \ Fall through into TR1 to copy the name back from NA%
                        \ to INWK. This isn't necessary as the name is already
                        \ there, but it does save one byte, as we don't need an
                        \ RTS here

\ ******************************************************************************
\
\       Name: TR1
\       Type: Subroutine
\   Category: Save and load
\    Summary: Copy the last saved commander's name from NA% to INWK
\
\ ******************************************************************************

.TR1_C

 LDX #7                 \ The commander's name can contain a maximum of 7
                        \ characters, and is terminated by a carriage return,
                        \ so set up a counter in X to copy 8 characters

.GTL2_C

 LDA NA%,X              \ Copy the X-th byte of NA% to the X-th byte of INWK+5
 STA INWK+5,X

 DEX                    \ Decrement the loop counter

 BPL GTL2_C               \ Loop back until we have copied all 8 bytes

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: GTNMEW
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
\   INWK                The full filename, including drive and directory, in
\                       the form ":0.E.JAMESON", for example, terminated by a
\                       return character (13)
\
\ ******************************************************************************

.GTNMEW_C

.GTNME_C

 LDX #4                 \ First we want to copy the drive and directory part of
                        \ the commander file from NA%-5, so set a counter in X
                        \ for 5 bytes, as the string is of the form ":0.E."

.GTL3_C

 LDA NA%-5,X            \ Copy the X-th byte from NA%-5 to INWK
 STA INWK,X

 DEX                    \ Decrement the loop counter

 BPL GTL3_C               \ Loop back until the whole drive and directory string
                        \ has been copied to INWK to INWK+4

 LDA #7                 \ The call to MT26 below uses the OSWORD block at RLINE
 STA RLINE+2            \ to fetch the line, and RLINE+2 defines the maximum
                        \ line length allowed, so this changes the maximum
                        \ length to 7 (as that's the longest commander name
                        \ allowed)

 LDA #8                 \ Print extended token 8 ("{single cap}COMMANDER'S
 JSR DETOK_C              \ NAME? ")

 JSR MT26_C               \ Call MT26 to fetch a line of text from the keyboard
                        \ to INWK+5, with the text length in Y, so INWK now
                        \ contains the full pathname of the file, as in
                        \ ":0.E.JAMESON", for example

 LDA #9                 \ Reset the maximum length in RLINE+2 to the original
 STA RLINE+2            \ value of 9

 TYA                    \ The OSWORD call returns the length of the commander's
                        \ name in Y, so transfer this to A

 BEQ TR1_C                \ If A = 0, no name was entered, so jump to TR1 to copy
                        \ the last saved commander's name from NA% to INWK
                        \ and return from the subroutine there

 STY thislong           \ Store the length of the length of the commander's that
                        \ was entered in thislong

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: MT26
\       Type: Subroutine
\   Category: Text
\    Summary: Fetch a line of text from the keyboard
\  Deep dive: Extended text tokens
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   Y                   The size of the entered text, or 0 if none was entered
\
\   INWK+5              The entered text, terminated by a carriage return
\
\   C flag              Set if ESCAPE was pressed
\
\ ******************************************************************************

.MT26_C

 LDA COL                \ Store the current colour on the stack
 PHA

 LDA #RED               \ Switch to colour 2, which is magenta in the trade view
 STA COL

 LDY #8                 \ Wait for 8/50 of a second (0.16 seconds)
 JSR x4_DELAY

 JSR FLKB_C               \ Call FLKB to flush the keyboard buffer

 LDY #0                 \ Set Y = 0 to hold the length of the text entered

.OSW0L_C

 JSR TT217_C              \ Scan the keyboard until a key is pressed, and return
                        \ the key's ASCII code in A (and X)

 CMP #13                \ If RETURN was pressed, jump to OSW03
 BEQ OSW03_C

 CMP #27                \ If ESCAPE was pressed, jump to OSW04
 BEQ OSW04_C

 CMP #127               \ If DELETE was pressed, jump to OSW05
 BEQ OSW05_C

IF _COMPACT

 PHX                    \ Store X on the stack so we can retrieve it after the
                        \ call to SHIFT

 PHA                    \ Store the number of the key being pressed on the stack

 JSR x4_SHIFT              \ If SHIFT is not being pressed, jump to noshift to skip
 BPL noshift_C            \ the following

 PLA                    \ SHIFT is being pressed, so fetch the number of the key
                        \ being pressed from the stack

 CMP #'@'               \ If A >= ASCII "@", then we are pressing a letter key,
 BCS P%+4               \ so skip the following instruction

 EOR #%00010000         \ We are pressing SHIFT and a number key, so flip bit 4
                        \ of the key number, which flips the letter between the
                        \ ASCII code of the number being pressed and the ASCII
                        \ code of the number being pressed when SHIFT is being
                        \ held down (so SHIFT-1 will enter !, SHIFT-2 will enter
                        \ ", and so on)

 PHA                    \ Push the updated key number onto the stack

.noshift_C

 PLA                    \ Retrieve the values of X and A we stored on the stack
 PLX                    \ above

ENDIF

 CPY RLINE+2            \ If Y >= RLINE+2 (the maximum line length from the
 BCS OSW01_C              \ OSWORD configuration block at RLINE), then jump to
                        \ OSW01 to give an error beep as we have reached the
                        \ character limit

 CMP RLINE+3            \ If the key pressed is less than the character in
 BCC OSW01_C              \ RLINE+3 (the lowest allowed character from the OSWORD
                        \ configuration block at RLINE), then jump to OSW01
                        \ to give an error beep as the key pressed is out of
                        \ range

 CMP RLINE+4            \ If the key pressed is greater than or equal to the
 BCS OSW01_C              \ character in RLINE+4 (the highest allowed character
                        \ from the OSWORD configuration block at RLINE), then
                        \ jump to OSW01 to give an error beep as the key
                        \ pressed is out of range

 STA INWK+5,Y           \ Store the key's ASCII code in the Y-th byte of INWK+5

 INY                    \ Increment Y to point to the next free byte in INWK+5

 EQUB &2C               \ Skip the next instruction by turning it into
                        \ &2C &A9 &07, or BIT &07A9, which does nothing apart
                        \ from affect the flags

.OSW01_C

 LDA #7                 \ Set A to the beep character, so the next instruction
                        \ makes a system beep

.OSW06_C

 JSR x4_CHPR               \ Print the character in A (and clear the C flag)

 BCC OSW0L_C              \ Loop back to OSW0L to fetch another key press (this
                        \ BCC is effectively a JMP as CHPR clears the C flag)

.OSW03_C

 STA INWK+5,Y           \ Store the return character in the Y-th byte of INWK+5

 LDA #12                \ Print a newline
 JSR x4_CHPR

 EQUB &24               \ Skip the next instruction by turning it into &24 &38,
                        \ or BIT &0038, which does nothing apart from affect the
                        \ flags

.OSW04_C

 SEC                    \ Set the C flag as ESCAPE was pressed

 PLA                    \ Restore the original colour from the stack and set it
 STA COL                \ as the current colour

 RTS                    \ Return from the subroutine

.OSW05_C

 TYA                    \ If the length of the line so far in Y is 0, then we
 BEQ OSW01_C              \ just pressed DELETE on an empty line, so jump to
                        \ OSW01 give an error beep

 DEY                    \ Otherwise we want to delete a character, so decrement
                        \ the length of the line so far in Y

 LDA #127               \ Set A = 127 and jump back to OSW06 to print the
 BNE OSW06_C              \ character in A (i.e. the DELETE character) and listen
                        \ for the next key press

\ ******************************************************************************
\
\       Name: FILEPR
\       Type: Subroutine
\   Category: Save and load
\    Summary: Display the currently selected media (disk or tape)
\  Deep dive: Extended text tokens
\
\ ******************************************************************************

.FILEPR_C

 LDA #3                 \ Print extended token 3 + DISK, i.e. token 3 or 2 (as
 CLC                    \ DISK can be 0 or &FF). In other versions of the game,
 ADC DISK               \ such as the Commodore 64 version, token 2 is "disk"
 JMP DETOK_C              \ and token 3 is "tape", so this displays the currently
                        \ selected media, but this system is unused in the
                        \ Master version and tokens 2 and 3 contain different
                        \ text

\ ******************************************************************************
\
\       Name: OTHERFILEPR
\       Type: Subroutine
\   Category: Save and load
\    Summary: Display the non-selected media (disk or tape)
\  Deep dive: Extended text tokens
\
\ ******************************************************************************

                        \ Port: removed (unreachable: its only reference was
                        \ JMTB's entry for control code 31, which no extended
                        \ token contains, so this system is unused in the Master
                        \ version)

\ ******************************************************************************
\
\       Name: ZERO
\       Type: Subroutine
\   Category: Utility routines
\    Summary: Reset the local bubble of universe and ship status
\
\ ------------------------------------------------------------------------------
\
\ This resets the following workspaces to zero:
\
\   * UP workspace variables from FRIN to de, which include the ship slots for
\     the local bubble of universe, and various flight and ship status variables
\
\ ******************************************************************************

.ZERO_C

 LDX #(de-FRIN)         \ We're going to zero the UP workspace variables from
                        \ FRIN to de, so set a counter in X for the correct
                        \ number of bytes

 LDA #0                 \ Set A = 0 so we can zero the variables

.ZEL2_C

 STA FRIN,X             \ Zero the X-th byte of FRIN to de

 DEX                    \ Decrement the loop counter

 BPL ZEL2_C               \ Loop back to zero the next variable until we have done
                        \ them all

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: GTDIR
\       Type: Subroutine
\   Category: Save and load
\    Summary: Fetch the name of an ADFS directory on the Master Compact and
\             change to that directory
\
\ ******************************************************************************

IF _COMPACT

.GTDIR_C

 LDA #2                 \ Print extended token 2 ("{cr}WHICH DRIVE?")
 JSR DETOK_C

 LDA #19                \ The call to MT26 below uses the OSWORD block at RLINE
 STA RLINE+2            \ to fetch the line, and RLINE+2 defines the maximum
                        \ line length allowed, so this changes the maximum
                        \ length to 19 (as that's the longest directory name
                        \ allowed)

 JSR MT26_C               \ Call MT26 to fetch a line of text from the keyboard
                        \ to INWK+5, with the text length in Y, so INWK now
                        \ contains the full directory name

 LDA #9                 \ Reset the maximum length in RLINE+2 to the original
 STA RLINE+2            \ value of 9

 TYA                    \ The OSWORD call returns the length of the commander's
                        \ name in Y, so transfer this to A

 BEQ GTDIR_C-1            \ If A = 0, no name was entered, so jump to DIR-1 to
                        \ return from the subroutine (as GTDIR-1 contains an
                        \ RTS)

                        \ We now copy the entered filename from INWK to DIRI, so
                        \ that it overwrites the filename part of the string,
                        \ i.e. the "12345678901234567890" part of
                        \ "DIR 12345678901234567890"

 LDX #18                \ Set up a counter in X to count from 18 to 0, so that
                        \ we copy the string starting at INWK+5 to DIRI+4
                        \ onwards (i.e. "12345678901234567890")

.DIRL_C

 LDA INWK+5,X           \ Copy the X-th byte of INWK+5 to the X-th byte of
 STA DIRI+4,X           \ DIRI+4

 DEX                    \ Decrement the loop counter

 BPL DIRL_C               \ Loop back to DIRL to copy the next character until we
                        \ have copied the whole filename

 JSR NMIRELEASE_C         \ Release the NMI workspace (&00A0 to &00A7) so the MOS
                        \ can use it, and store the top part of zero page in the
                        \ the buffer at &3000, as it gets corrupted by the MOS
                        \ during disc access

 LDX #LO(DIRI)          \ Set (Y X) to point to DIRI ("DIR <name entered>")
 LDY #HI(DIRI)

 JSR DOSCLI_C           \ (Port: through DOSCLI, the HAZEL and NMI glue)
                        \ Call OSCLI to run the OS command in DIRI, which
                        \ changes the disc directory to the name entered

 JMP getzp_C              \ Call getzp to restore the top part of zero page from
                        \ the buffer at &3000 and return from the subroutine
                        \ using a tail call

ENDIF

\ ******************************************************************************
\
\       Name: CATS
\       Type: Subroutine
\   Category: Save and load
\    Summary: Ask for a disc drive number and print a catalogue of that drive
\
\ ------------------------------------------------------------------------------
\
\ This routine asks for a disc drive number, and if it is a valid number (0-3)
\ it displays a catalogue of the disc in that drive. It also updates the OS
\ command at CTLI so that when that command is run, it catalogues the correct
\ drive.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              Clear if a valid drive number was entered (0-3), set
\                       otherwise
\
\ ******************************************************************************

.CATS_C

IF _SNG47

 JSR GTDRV_C              \ Get an ASCII disc drive number from the keyboard in A,
                        \ setting the C flag if an invalid drive number was
                        \ entered

 BCS DELT_C-1             \ If the C flag is set, then an invalid drive number was
                        \ entered, so return from the subroutine (as DELT-1
                        \ contains an RTS)

 STA CTLI+4             \ Store the drive number in the fifth byte of the
                        \ command string at CTLI, so it overwrites the "1" in
                        \ "CAT 1" with the drive number to catalogue

 STA DTW7               \ Store the drive number in DTW7, so printing extended
                        \ token 4 will show the correct drive number (as token 4
                        \ contains the {drive number} jump code, which calls
                        \ MT16 to print the character in DTW7)

ELIF _COMPACT

 JSR GTDIR_C              \ Get a directory name from the keyboard and change to
                        \ that directory

ENDIF

 LDA #3                 \ Print extended token 3, which clears the screen and
 JSR DETOK_C              \ prints the boxed-out title "DRIVE {drive number}
                        \ CATALOGUE"

 LDA #1                 \ Set the CATF flag to 1, so that the TT26 routine will
 STA CATF               \ print out the disc catalogue correctly

 STA XC                 \ Move the text cursor to column 1

IF _SNG47

 JSR getzp_C              \ Call getzp to store the top part of zero page in the
                        \ the buffer at &3000, as it gets corrupted by the MOS
                        \ during disc access

ELIF _COMPACT

 JSR NMIRELEASE_C         \ Release the NMI workspace (&00A0 to &00A7) so the MOS
                        \ can use it, and store the top part of zero page in the
                        \ the buffer at &3000, as it gets corrupted by the MOS
                        \ during disc access

ENDIF

 LDX #LO(CTLI)          \ Set (Y X) to point to the OS command at CTLI, which
 LDY #HI(CTLI)          \ contains a dot and the drive number, which is the
                        \ DFS command for cataloguing that drive (*. being short
                        \ for *CAT)

 JSR DOSCLI_C           \ (Port: through DOSCLI, the HAZEL and NMI glue)
                        \ Call OSCLI to execute the OS command at (Y X), which
                        \ catalogues the disc

 JSR getzp_C              \ Call getzp to restore the top part of zero page from
                        \ the buffer at &3000

 STZ CATF               \ Set the CATF flag to 0, so the TT26 routine reverts to
                        \ standard formatting

 CLC                    \ Clear the C flag

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: DELT
\       Type: Subroutine
\   Category: Save and load
\    Summary: Catalogue a disc, ask for a filename to delete, and delete the
\             file
\
\ ------------------------------------------------------------------------------
\
\ This routine asks for a disc drive number, and if it is a valid number (0-3)
\ it displays a catalogue of the disc in that drive. It then asks for a filename
\ to delete, updates the OS command at DELI so that when that command is run, it
\ deletes the correct file, and then it does the deletion.
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   DELT-1              Contains an RTS
\
\ ******************************************************************************

.DELT_C

 JSR CATS_C               \ Call CATS to ask for a drive number (or a directory
                        \ name on the Master Compact) and catalogue that disc
                        \ or directory

 BCS SVE_C                \ If the C flag is set then an invalid drive number was
                        \ entered as part of the catalogue process, so jump to
                        \ SVE to display the disc access menu

IF _SNG47

 LDA CTLI+4             \ The call to CATS above put the drive number into
 STA DELI+8             \ CTLI+4, so copy the drive number into DELI+8 so that
                        \ the drive number in the "DELETE :1.1234567" string
                        \ gets updated (i.e. the number after the colon)

ENDIF

 LDA #8                 \ Print extended token 8 ("{single cap}COMMANDER'S
 JSR DETOK_C              \ NAME? ")

 JSR MT26_C               \ Call MT26 to fetch a line of text from the keyboard
                        \ to INWK+5, with the text length in Y

 TYA                    \ If no text was entered (Y = 0) then jump to SVE to
 BEQ SVE_C                \ display the disc access menu

IF _SNG47

                        \ We now copy the entered filename from INWK to DELI, so
                        \ that it overwrites the filename part of the string,
                        \ i.e. the "E.1234567" part of "DELETE :1.1234567"

 LDX #9                 \ Set up a counter in X to count from 9 to 1, so that we
                        \ copy the string starting at INWK+4+1 (i.e. INWK+5) to
                        \ DELI+9+1 (i.e. DELI+10 onwards, or "1.1234567")
                        \
                        \ Note that this is a bug - X should be set to 8, as a
                        \ value of 9 overwrites the first character of the
                        \ "SAVE" command in savosc
                        \
                        \ This means that if you delete a file, it breaks the
                        \ save command, so you can't save a commander file if
                        \ you have previously deleted a file

ELIF _COMPACT

                        \ We now copy the entered filename from INWK to DELI, so
                        \ that it overwrites the filename part of the string,
                        \ i.e. the "1234567890" part of "DELETE 1234567890"

 LDX #8                 \ Set up a counter in X to count from 8 to 0, so that we
                        \ copy the string starting at INWK+5+0 (i.e. INWK+5) to
                        \ DELI+7+0 (i.e. DELI+7 onwards, or "1234567890")

ENDIF

.DELL1_C

IF _SNG47

 LDA INWK+4,X           \ Copy the X-th byte of INWK+4 to the X-th byte of
 STA DELI+9,X           \ DELI+9

 DEX                    \ Decrement the loop counter

 BNE DELL1_C              \ Loop back to DELL1 to copy the next character until we
                        \ have copied the whole filename

 JSR getzp_C              \ Call getzp to store the top part of zero page in the
                        \ the buffer at &3000, as it gets corrupted by the MOS
                        \ during disc access

ELIF _COMPACT

 LDA INWK+5,X           \ Copy the X-th byte of INWK+5 to the X-th byte of
 STA DELI+7,X           \ DELI+7

 DEX                    \ Decrement the loop counter

 BPL DELL1_C              \ Loop back to DELL1 to copy the next character until we
                        \ have copied the whole filename

 JSR NMIRELEASE_C         \ Release the NMI workspace (&00A0 to &00A7) so the MOS
                        \ can use it, and store the top part of zero page in the
                        \ the buffer at &3000, as it gets corrupted by the MOS
                        \ during disc access

ENDIF

 LDX #LO(DELI)          \ Set (Y X) to point to the OS command at DELI, which
 LDY #HI(DELI)          \ contains the DFS command for deleting this file

 JSR DOSCLI_C           \ (Port: through DOSCLI, the HAZEL and NMI glue)
                        \ Call OSCLI to execute the OS command at (Y X), which
                        \ deletes the file

 JSR getzp_C              \ Call getzp to restore the top part of zero page from
                        \ the buffer at &3000

 JMP SVE_C                \ Jump to SVE to display the disc access menu and return
                        \ from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: SVE
\       Type: Subroutine
\   Category: Save and load
\    Summary: Display the disk access menu and process saving of commander files
\  Deep dive: Commander save files
\             The competition code
\
\ ******************************************************************************

.SVE_C

 TSX                    \ Transfer the stack pointer to X and store it in
 STX stackpt            \ stackpt, so we can restore it in the NEWBRK routine

 JSR TRADEMODE2_C         \ Set the palette for trading screens and switch the
                        \ current colour to white

 LDA #1                 \ Print extended token 1, the disc access menu, which
 JSR DETOK_C              \ presents these options:
                        \
                        \   1. Load New Commander
                        \   2. Save Commander {commander name}
                        \   3. Catalogue
                        \   4. Delete A File
                        \   5. Default JAMESON
                        \   6. Exit

 JSR t_C                  \ Scan the keyboard until a key is pressed, returning
                        \ the ASCII code in A and X

 CMP #'1'               \ Option 1 was chosen, so jump to loading to load a new
 BEQ loading_C            \ commander

 CMP #'2'               \ Option 2 was chosen, so jump to SV1 to save the
 BEQ SV1_C                \ current commander

 CMP #'3'               \ Option 3 was chosen, so jump to feb10 to catalogue a
 BEQ feb10_C              \ disc

 CMP #'4'               \ If option 4 wasn't chosen, skip the next two
 BNE jan18_C              \ instructions

 JSR DELT_C               \ Option 4 was chosen, so call DELT to delete a file

 JMP SVE_C                \ Jump to SVE to display the disc access menu again and
                        \ return from the subroutine using a tail call

.jan18_C

 CMP #'5'               \ If option 5 wasn't chosen, skip to feb13 to exit the
 BNE feb13_C              \ menu

 LDA #224               \ Print extended token 224 ("ARE YOU SURE?")
 JSR DETOK_C

 JSR YESNO_C              \ Call YESNO to wait until either "Y" or "N" is pressed

 BCC feb13_C              \ If "N" was pressed, jump to feb13

 JSR JAMESON_C            \ Otherwise "Y" was pressed, so call JAMESON to set the
                        \ last saved commander to the default "JAMESON"
                        \ commander

 JMP DFAULT_C             \ Jump to DFAULT to reset the current commander data
                        \ block to the last saved commander, returning from the
                        \ subroutine using a tail call

.feb13_C

 CLC                    \ Option 5 was chosen, so clear the C flag to indicate
                        \ that nothing was loaded

 RTS                    \ Return from the subroutine

.feb10_C

 JSR CATS_C               \ Call CATS to ask for a drive number (or a directory
                        \ name on the Master Compact) and catalogue that disc
                        \ or directory

 JSR t_C                  \ Scan the keyboard until a key is pressed, returning
                        \ the ASCII code in A and X

 JMP SVE_C                \ Jump to SVE to display the disc access menu and return
                        \ from the subroutine using a tail call

.loading_C

 JSR GTNMEW_C             \ If we get here then option 1 (load) was chosen, so
                        \ call GTNMEW to fetch the name of the commander file
                        \ to load (including drive number and directory) into
                        \ INWK

IF _SNG47

 JSR GTDRV_C              \ Get an ASCII disc drive number from the keyboard in A,
                        \ setting the C flag if an invalid drive number was
                        \ entered

 BCS jan2186_C            \ If the C flag is set, then an invalid drive number was
                        \ entered, so return from the subroutine (as DELT-1
                        \ contains an RTS)

 STA lodosc+6           \ Store the ASCII drive number in lodosc+6, which is the
                        \ drive character of the load filename string ":1.E."

ENDIF

 JSR LOD_C                \ Call LOD to load the commander file

 JSR TRNME_C              \ Transfer the commander filename from INWK to NA%

 SEC                    \ Set the C flag to indicate we loaded a new commander

.jan2186_C

 RTS                    \ Return from the subroutine

.SV1_C

 JSR GTNMEW_C             \ If we get here then option 2 (save) was chosen, so
                        \ call GTNMEW to fetch the name of the commander file
                        \ to save (including drive number and directory) into
                        \ INWK

 JSR TRNME_C              \ Transfer the commander filename from INWK to NA%

 LSR SVC                \ Halve the save count value in SVC

 LDA #4                 \ Print extended token 4, which is blank (this was where
 JSR DETOK_C              \ the competition number was printed in older versions,
                        \ but the competition was long gone by the time of the
                        \ BBC Master version

 LDX #NT%               \ We now want to copy the current commander data block
                        \ from location TP to the last saved commander block at
                        \ NA%+8, so set a counter in X to copy the NT% bytes in
                        \ the commander data block

.SVL1_C

 LDA TP,X               \ Copy the X-th byte of TP to the X-th byte of NA%+8
\STA &0B00,X            \
 STA NA%+8,X            \ The STA is commented out in the original source

 DEX                    \ Decrement the loop counter

 BPL SVL1_C               \ Loop back until we have copied all the bytes in the
                        \ commander data block

\JSR CHECK2             \ These instructions are commented out in the original
\                       \ source
\STA CHK3

 JSR CHECK_C              \ Call CHECK to calculate the checksum for the last
                        \ saved commander and return it in A

 STA CHK                \ Store the checksum in CHK, which is at the end of the
                        \ last saved commander block

 PHA                    \ Store the checksum on the stack

 ORA #%10000000         \ Set K = checksum with bit 7 set
 STA K

 EOR COK                \ Set K+2 = K EOR COK (the competition flags)
 STA K+2

 EOR CASH+2             \ Set K+1 = K+2 EOR CASH+2 (the third cash byte)
 STA K+1

 EOR #&5A               \ Set K+3 = K+1 EOR &5A EOR TALLY+1 (the high byte of
 EOR TALLY+1            \ the kill tally)
 STA K+3

 CLC                    \ Clear the C flag so the call to BPRNT does not include
                        \ a decimal point

 JSR TT67_C               \ Call TT67 twice to print two newlines
 JSR TT67_C

 PLA                    \ Restore the checksum from the stack

 EOR #&A9               \ Store the checksum EOR &A9 in CHK2, the penultimate
 STA CHK2               \ byte of the last saved commander block

                        \ We now copy the current commander data block into the
                        \ TAP% staging area, though this has no effect as we
                        \ then ignore the result (this code is left over from
                        \ the Apple II version)

 LDY #NT%               \ Set a counter in X to copy the NT% bytes in the
                        \ commander data block

.copyme2_C

 LDA NA%+8,Y            \ Copy the X-th byte of NA% to the X-th byte of TAP%
 STA TAP%,Y

 DEY                    \ Decrement the loop counter

 BPL copyme2_C            \ Loop back until we have copied all the bytes in the
                        \ commander data block

IF _SNG47

 JSR GTDRV_C              \ Get an ASCII disc drive number from the keyboard in A,
                        \ setting the C flag if an invalid drive number was
                        \ entered

 BCS SVEX9_C              \ If the C flag is set, then an invalid drive number was
                        \ entered, so skip the next two instructions

 STA savosc+6           \ Store the ASCII drive number in savosc+6, which is the
                        \ drive character of the save filename string ":1.E."

ENDIF

 JSR wfile_C              \ Call wfile to save the commander file

.SVEX9_C

 JSR DFAULT_C             \ Call DFAULT to reset the current commander data
                        \ block to the last saved commander

.SVEX_C

 CLC                    \ Clear the C flag to indicate that no new commander
                        \ file was loaded

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: GTDRV
\       Type: Subroutine
\   Category: Save and load
\    Summary: Get an ASCII disc drive number from the keyboard
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   The ASCII value of the entered drive number ("0" to "3")
\
\   C flag              Clear if a valid drive number was entered (0-3), set
\                       otherwise
\
\ ******************************************************************************

.GTDRV_C

 LDA #2                 \ Print extended token 2 ("{cr}WHICH DRIVE?")
 JSR DETOK_C

 JSR t_C                  \ Scan the keyboard until a key is pressed, returning
                        \ the ASCII code in A and X

 ORA #%00010000         \ Set bit 4 of A, perhaps to avoid printing any control
                        \ characters in the next instruction

 JSR x4_CHPR               \ Print the character in A

 PHA                    \ Store A on the stack so we can retrieve it after the
                        \ call to FEED

 JSR x4_FEED               \ Print a newline

 PLA                    \ Restore A from the stack

 CMP #'0'               \ If A < ASCII "0", then it is not a valid drive number,
 BCC LOR_C                \ so jump to LOR to set the C flag and return from the
                        \ subroutine

 CMP #'4'               \ If A >= ASCII "4", then it is not a valid drive
                        \ number, and this CMP sets the C flag, otherwise it is
                        \ a valid drive number in the range 0-3, so clear it

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: LOD
\       Type: Subroutine
\   Category: Save and load
\    Summary: Load a commander file
\
\ ------------------------------------------------------------------------------
\
\ The filename should be stored at INWK, terminated with a carriage return (13).
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   LOR                 Set the C flag and return from the subroutine
\
\ ******************************************************************************

.LOD_C

 JSR rfile_C              \ Call rfile to load the commander file to the TAP%
                        \ staging area

 LDA TAP%               \ If the first byte of the loaded file has bit 7 set,
 BMI ELT2F_C              \ jump to ELT2F, as this is an invalid commander file
                        \
                        \ ELT2F contains a BRK instruction, which will force an
                        \ interrupt to call the address in BRKV, which will
                        \ print out the system error at ELT2F

 LDY #NT%               \ We have successfully loaded the commander file to the
                        \ TAP% staging area, so now we want to copy it to the
                        \ last saved commander data block at NA%+8, so we set up
                        \ a counter in Y to copy NT% bytes

.copyme_C

 LDA TAP%,Y             \ Copy the Y-th byte of TAP% to the Y-th byte of NA%+8
 STA NA%+8,Y

 DEY                    \ Decrement the loop counter

 BPL copyme_C             \ Loop back until we have copied all NT% bytes

.LOR_C

 SEC                    \ Set the C flag

 RTS                    \ Return from the subroutine

.ELT2F_C

 LDA #9                 \ Print extended token 9 ("{cr}{all caps}ILLEGAL ELITE
 JSR DETOK_C              \ II FILE{sentence case}")

 JSR t_C                  \ Scan the keyboard until a key is pressed, returning
                        \ the ASCII code in A and X

 JMP SVE_C                \ Jump to SVE to display the disc access menu and return
                        \ from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: backtonormal
\       Type: Subroutine
\   Category: Utility routines
\    Summary: Disable the keyboard, set the SVN flag to 0, and return with A = 0
\
\ ------------------------------------------------------------------------------
\
\ This routine is unused in this version of Elite (it is left over from the
\ 6502 Second Processor version).
\
\ ******************************************************************************

                        \ Port: removed (unreachable: backtonormal has no caller
                        \ in SNG47)

\ ******************************************************************************
\
\       Name: CLDELAY
\       Type: Subroutine
\   Category: Utility routines
\    Summary: Delay by iterating through 5 * 256 (1280) empty loops
\
\ ------------------------------------------------------------------------------
\
\ This routine is unused in this version of Elite (it is left over from the
\ 6502 Second Processor version).
\
\ ******************************************************************************

                        \ Port: removed (unreachable: CLDELAY has no caller in
                        \ SNG47)

\ ******************************************************************************
\
\       Name: wfile
\       Type: Subroutine
\   Category: Save and load
\    Summary: Save the commander file
\
\ ------------------------------------------------------------------------------
\
\ This routine copies a commander file into the commbuf file buffer at &087E
\ (Port: &0E7E in the original), and then saves it.
\
\ ******************************************************************************

.wfile_C

 LDY #NT%               \ We first want to copy the current commander data block
                        \ to the commbuf file buffer so we can do a file save
                        \ operation, so we set a counter in Y to copy the NT%
                        \ bytes in the commander data block

.wfileL1_C

 LDA NA%+8,Y            \ Copy the Y-th byte of NA%+8 to the Y-th byte of the
 STA commbuf,Y          \ commbuf file buffer

 DEY                    \ Decrement the loop counter

 BPL wfileL1_C            \ Loop back until we have copied all the bytes in the
                        \ commander data block

 LDA #0                 \ The save file is 256 bytes long but only NT% (76) of
                        \ those contain data, so before we save we need to zero
                        \ out the rest of the 256-byte block, so we set A = 0 to
                        \ do this

 LDY #NT%               \ Set an index in Y to point the byte after the end of
                        \ the first NT% bytes in the commander data block

.wfileL2_C

 STA commbuf,Y          \ Zero the Y-th byte of the commbuf file buffer

 INY                    \ Increment the loop counter

 BNE wfileL2_C            \ Loop back until we have zeroed the rest of the
                        \ 256-byte block

 LDY #0                 \ Now we need to change the save command at savosc to
                        \ contain the commander name as the filename, so set an
                        \ index in Y so we can copy the commander name from NA%
                        \ into the savosc command

.wfileL3_C

 LDA NA%,Y              \ Fetch the Y-th character of the commander name at NA%

 CMP #13                \ If the character is a carriage return then we have
 BEQ wfileL4_C            \ reached the end of the name, so jump to wfileL4 as we
                        \ have now copied the whole name

IF _SNG47

 STA savosc+10,Y        \ Store the Y-th character of the commander name in the
                        \ Y-th character of savosc+10, where savosc+10 points to
                        \ the JAMESON part of the save command in savosc:
                        \
                        \   "SAVE :1.E.JAMESON  E7E +100 0 0"

ELIF _COMPACT

 STA savosc+5,Y         \ Store the Y-th character of the commander name in the
                        \ Y-th character of savosc+5, where savosc+5 points to
                        \ the JAMESON part of the save command in savosc:
                        \
                        \   "SAVE JAMESON  E7E +100 0 0"

ENDIF

 INY                    \ Increment the loop counter

 CPY #7                 \ If Y < 7 then there may be more characters in the
 BCC wfileL3_C            \ name, so loop back to wfileL3 to fetch the next one

.wfileL4_C

 LDA #' '               \ We have copied the name into the savosc command
                        \ string, but the new name might be shorter than the
                        \ previous one, so we now need to blank out the rest
                        \ of the name with spaces, so we load the space
                        \ character into A

.wfileL5_C

IF _SNG47

 STA savosc+10,Y        \ Store the Y-th character of the commander name in the
                        \ Y-th character of savosc+10, which will be directly
                        \ after the last letter we copied above

ELIF _COMPACT

 STA savosc+5,Y         \ Store the Y-th character of the commander name in the
                        \ Y-th character of savosc+5, which will be directly
                        \ after the last letter we copied above

ENDIF

 INY                    \ Increment the loop counter

 CPY #7                 \ If Y < 7 then we haven't yet blanked out the whole
 BCC wfileL4_C            \ name, so loop back to wfileL4 to blank the next one
                        \ until the save string is ready for use

IF _SNG47

 JSR getzp_C              \ Call getzp to store the top part of zero page in the
                        \ the buffer at &3000, as it gets corrupted by the MOS
                        \ during disc access

ELIF _COMPACT

 JSR NMIRELEASE_C         \ Release the NMI workspace (&00A0 to &00A7) so the MOS
                        \ can use it, and store the top part of zero page in the
                        \ the buffer at &3000, as it gets corrupted by the MOS
                        \ during disc access

ENDIF

 LDX #LO(savosc)        \ Set (Y X) to point to the OS command at savosc, which
 LDY #HI(savosc)        \ contains the DFS command for saving the commander file

 JSR DOSCLI_C           \ (Port: through DOSCLI, the HAZEL and NMI glue)
                        \ Call OSCLI to execute the OS command at (Y X), which
                        \ saves the commander file

 JMP getzp_C              \ Call getzp to restore the top part of zero page from
                        \ the buffer at &3000 and return from the subroutine
                        \ using a tail call

\ ******************************************************************************
\
\       Name: rfile
\       Type: Subroutine
\   Category: Save and load
\    Summary: Load the commander file
\
\ ------------------------------------------------------------------------------
\
\ This routine loads a commander file into the commbuf file buffer at &087E
\ (Port: &0E7E in the original), and then copies it to the TAP% staging area
\ (though the latter is not used in this version, as it's left over from the
\ Commodore 64 version).
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   INWK+5              The filename, terminated by a carriage return
\
\ ******************************************************************************

.rfile_C

 LDY #0                 \ We start by changing the load command at lodosc to
                        \ contain the filename that was just entered by the
                        \ user, so we set an index in Y so we can copy the
                        \ filename from INWK+5 into the lodosc command

.rfileL3_C

 LDA INWK+5,Y           \ Fetch the Y-th character of the filename

 CMP #13                \ If the character is a carriage return then we have
 BEQ rfileL4_C            \ reached the end of the filename, so jump to rfileL4 as
                        \ we have now copied the whole filename

IF _SNG47

 STA lodosc+10,Y        \ Store the Y-th character of the filename in the Y-th
                        \ character of lodosc+10, where lodosc+10 points to the
                        \ JAMESON part of the load command in lodosc:
                        \
                        \   "LOAD :1.E.JAMESON  E7E"

ELIF _COMPACT

 STA lodosc+5,Y         \ Store the Y-th character of the filename in the Y-th
                        \ character of lodosc+5, where lodosc+5 points to the
                        \ JAMESON part of the load command in lodosc:
                        \
                        \   "LOAD JAMESON  E7E"

ENDIF

 INY                    \ Increment the loop counter

 CPY #7                 \ If Y < 7 then there may be more characters in the
 BCC rfileL3_C            \ name, so loop back to rfileL3 to fetch the next one

.rfileL4_C

 LDA #' '               \ We have copied the name into the lodosc command
                        \ string, but the new name might be shorter than the
                        \ previous one, so we now need to blank out the rest of
                        \ the name with spaces, so we load the space character
                        \ into A

.rfileL5_C

IF _SNG47

 STA lodosc+10,Y        \ Store the Y-th character of the filename in the Y-th
                        \ character of lodosc+10, which will be directly after
                        \ the last letter we copied above

ELIF _COMPACT

 STA lodosc+5,Y         \ Store the Y-th character of the filename in the Y-th
                        \ character of lodosc+5, which will be directly after
                        \ the last letter we copied above

ENDIF

 INY                    \ Increment the loop counter

 CPY #7                 \ If Y < 7 then we haven't yet blanked out the whole
 BCC rfileL4_C            \ name, so loop back to rfileL4 to blank the next one
                        \ until the load string is ready for use

IF _SNG47

 JSR getzp_C              \ Call getzp to store the top part of zero page in the
                        \ the buffer at &3000, as it gets corrupted by the MOS
                        \ during disc access

ELIF _COMPACT

 JSR NMIRELEASE_C         \ Release the NMI workspace (&00A0 to &00A7) so the MOS
                        \ can use it, and store the top part of zero page in the
                        \ the buffer at &3000, as it gets corrupted by the MOS
                        \ during disc access

ENDIF

 LDX #LO(lodosc)        \ Set (Y X) to point to the OS command at lodosc, which
 LDY #HI(lodosc)        \ contains the DFS command for loading the commander
                        \ file

 JSR DOSCLI_C           \ (Port: through DOSCLI, the HAZEL and NMI glue)
                        \ Call OSCLI to execute the OS command at (Y X), which
                        \ loads the commander file

 JSR getzp_C              \ Call getzp to restore the top part of zero page from
                        \ the buffer at &3000

                        \ We now copy the newly loaded commander data block to
                        \ the TAP% staging area, though this has no effect as we
                        \ then ignore the result (this code is left over from
                        \ the Commodore 64 version)

 LDY #NT%               \ Set a counter in Y to copy the NT% bytes in the
                        \ commander data block

.rfileL1_C

 LDA commbuf,Y          \ Copy the Y-th byte of the commbuf file buffer to the
 STA TAP%,Y             \ Y-th byte of the TAP% staging area

 DEY                    \ Decrement the loop counter

 BPL rfileL1_C            \ Loop back until we have copied all the bytes in the
                        \ newly loaded commander data block

 RTS                    \ Return from the subroutine

                        \ Port: the RTS that followed is removed (unreachable:
                        \ "This instruction has no effect")

\ ******************************************************************************
\
\       Name: DOENTRY
\       Type: Subroutine
\   Category: Flight
\    Summary: Dock at the space station, show the ship hangar and work out any
\             mission progression
\  Deep dive: The Constrictor mission
\             The Thargoid Plans mission
\
\ ******************************************************************************

.DOENTRY_C

 JSR RES2_C               \ Reset a number of flight variables and workspaces

 JSR LAUN_C               \ Show the space station docking tunnel

 LDA #0                 \ Reduce the speed to 0
 STA DELTA

 STA GNTMP              \ Cool down the lasers completely

 STA QQ22+1             \ Reset the on-screen hyperspace counter

 LDA #&FF               \ Recharge the forward and aft shields
 STA FSH
 STA ASH

 STA ENERGY             \ Recharge the energy banks

 JSR x4_HALL               \ Show the ship hangar

 LDY #44                \ Wait for 44/50 of a second (0.88 seconds)
 JSR x4_DELAY

 LDA TP                 \ Fetch bits 0 and 1 of TP, and if they are non-zero
 AND #%00000011         \ (i.e. mission 1 is either in progress or has been
 BNE EN1_C                \ completed), skip to EN1

 LDA TALLY+1            \ If the high byte of TALLY is zero (so we have a combat
 BEQ EN4_C                \ rank below Competent, or we are Competent but have not
                        \ yet earned a grand total of at least 256 kill points),
                        \ jump to EN4 as we are not yet good enough to qualify
                        \ for a mission

 LDA GCNT               \ Fetch the galaxy number into A, and if any of bits 1-7
 LSR A                  \ are set (i.e. A > 1), jump to EN4 as mission 1 can
 BNE EN4_C                \ only be triggered in the first two galaxies

 JMP BRIEF_C              \ If we get here then mission 1 hasn't started, we have
                        \ reached a combat rank of at least Competent plus 128
                        \ kill points, and we are in galaxy 0 or 1 (shown
                        \ in-game as galaxy 1 or 2), so it's time to start
                        \ mission 1 by calling BRIEF

.EN1_C

                        \ If we get here then mission 1 is either in progress or
                        \ has been completed

 CMP #%00000011         \ If bits 0 and 1 are not both set, then jump to EN2
 BNE EN2_C

 JMP DEBRIEF_C            \ Bits 0 and 1 are both set, so mission 1 is both in
                        \ progress and has been completed, which means we have
                        \ only just completed it, so jump to DEBRIEF to end the
                        \ mission get our reward

.EN2_C

                        \ Mission 1 has been completed, so now to check for
                        \ mission 2

 LDA GCNT               \ Fetch the galaxy number into A

 CMP #2                 \ If this is not galaxy 2 (shown in-game as galaxy 3),
 BNE EN4_C                \ jump to EN4 as we can only start mission 2 in the
                        \ third galaxy

 LDA TP                 \ Extract bits 0-3 of TP into A
 AND #%00001111

 CMP #%00000010         \ If mission 1 is complete and no longer in progress,
 BNE EN3_C                \ and mission 2 is not yet started, then bits 0-3 of TP
                        \ will be %0010, so this jumps to EN3 if this is not the
                        \ case

 LDA TALLY+1            \ If the high byte of TALLY is < 5 (so we have a combat
 CMP #5                 \ rank that is less than 3/8 of the way from Dangerous
 BCC EN4_C                \ to Deadly), jump to EN4 as our rank isn't high enough
                        \ for mission 2

 JMP BRIEF2_C             \ If we get here, mission 1 is complete and no longer in
                        \ progress, mission 2 hasn't started, we have reached a
                        \ combat rank of 3/8 of the way from Dangerous to
                        \ Deadly, and we are in galaxy 2 (shown in-game as
                        \ galaxy 3), so it's time to start mission 2 by calling
                        \ BRIEF2

.EN3_C

 CMP #%00000110         \ If mission 1 is complete and no longer in progress,
 BNE EN5_C                \ and mission 2 has started but we have not yet been
                        \ briefed and picked up the plans, then bits 0-3 of TP
                        \ will be %0110, so this jumps to EN5 if this is not the
                        \ case

 LDA QQ0                \ Set A = the current system's galactic x-coordinate

 CMP #215               \ If A <> 215 then jump to EN4
 BNE EN4_C

 LDA QQ1                \ Set A = the current system's galactic y-coordinate

 CMP #84                \ If A <> 84 then jump to EN4
 BNE EN4_C

 JMP BRIEF3_C             \ If we get here, mission 1 is complete and no longer in
                        \ progress, mission 2 has started but we have not yet
                        \ picked up the plans, and we have just arrived at
                        \ Ceerdi at galactic coordinates (215, 84), so we jump
                        \ to BRIEF3 to get a mission brief and pick up the plans
                        \ that we need to carry to Birera

.EN5_C

 CMP #%00001010         \ If mission 1 is complete and no longer in progress,
 BNE EN4_C                \ and mission 2 has started and we have picked up the
                        \ plans, then bits 0-3 of TP will be %1010, so this
                        \ jumps to EN5 if this is not the case

 LDA QQ0                \ Set A = the current system's galactic x-coordinate

 CMP #63                \ If A <> 63 then jump to EN4
 BNE EN4_C

 LDA QQ1                \ Set A = the current system's galactic y-coordinate

 CMP #72                \ If A <> 72 then jump to EN4
 BNE EN4_C

 JMP DEBRIEF2_C           \ If we get here, mission 1 is complete and no longer in
                        \ progress, mission 2 has started and we have picked up
                        \ the plans, and we have just arrived at Birera at
                        \ galactic coordinates (63, 72), so we jump to DEBRIEF2
                        \ to end the mission and get our reward

.EN4_C

\LDA CASH+2             \ These instructions are commented out in the original
\CMP #&C4               \ source
\BCC EN6
\
\LDA TP
\AND #&10
\BNE EN6
\
\JMP TBRIEF
\
\.EN6

 JMP BAY_C                \ If we get here them we didn't start or any missions,
                        \ so jump to BAY to go to the docking bay (i.e. show the
                        \ Status Mode screen)

\ ******************************************************************************
\
\       Name: LL164
\       Type: Subroutine
\   Category: Drawing circles
\    Summary: Make the hyperspace sound and draw the hyperspace tunnel
\
\ ------------------------------------------------------------------------------
\
\ See the IRQ1 routine for details on the multi-coloured effect that's used.
\
\ ******************************************************************************

.LL164_C

 LDY #sohyp             \ Call the NOISE routine with Y = 10 to make the first
 JSR x4_NOISE              \ sound of the hyperspace drive being engaged

 LDY #sohyp2            \ Call the NOISE routine with Y = 11 to make the second
 JSR x4_NOISE              \ sound of the hyperspace drive being engaged

 LDA #4                 \ Set the step size for the hyperspace rings to 4, so
                        \ there are more sections in the rings and they are
                        \ quite round (compared to the step size of 8 used in
                        \ the much more polygonal launch rings)

 STA HFX                \ Set HFX to 4, which switches the screen mode to a full
                        \ mode 2 screen, therefore making the hyperspace rings
                        \ multi-coloured and all zig-zaggy (see the IRQ1 routine
                        \ for details)

 JSR HFS2_C               \ Call HFS2 to draw the hyperspace tunnel rings

 STZ HFX                \ Set HFX back to 0, so we switch back to the normal
                        \ split-screen mode

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: LAUN
\       Type: Subroutine
\   Category: Drawing circles
\    Summary: Make the launch sound and draw the launch tunnel
\
\ ------------------------------------------------------------------------------
\
\ This is shown when launching from or docking with the space station.
\
\ ******************************************************************************

.LAUN_C

 LDY #solaun            \ Call the NOISE routine with Y = 8 to make the sound
 JSR x4_NOISE              \ of the ship launching from the station

 LDA #8                 \ Set the step size for the launch tunnel rings to 8, so
                        \ there are fewer sections in the rings and they are
                        \ quite polygonal (compared to the step size of 4 used
                        \ in the much rounder hyperspace rings)

                        \ Fall through into HFS2 to draw the launch tunnel rings

\ ******************************************************************************
\
\       Name: HFS2
\       Type: Subroutine
\   Category: Drawing circles
\    Summary: Draw the launch or hyperspace tunnel
\
\ ------------------------------------------------------------------------------
\
\ The animation gets drawn like this. First, we draw a circle of radius 8 at the
\ centre, and then double the radius, draw another circle, double the radius
\ again and draw a circle, and we keep doing this until the radius is bigger
\ than 160 (which goes beyond the edge of the screen, which is 256 pixels wide,
\ equivalent to a radius of 128). We then repeat this whole process for an
\ initial circle of radius 9, then radius 10, all the way up to radius 15.
\
\ This has the effect of making the tunnel appear to be racing towards us as we
\ hurtle out into hyperspace or through the space station's docking tunnel.
\
\ The hyperspace effect is done in a full mode 2 screen, which makes the rings
\ all coloured and zig-zaggy, while the launch screen is in the normal
\ four-colour mode 1 screen.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The step size of the straight lines making up the rings
\                       (4 for launch, 8 for hyperspace)
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   HFS1                Don't clear the screen, and draw 8 concentric rings
\                       with the step size in STP
\
\ ******************************************************************************

.HFS2_C

 STA STP                \ Store the step size in A

 LDA QQ11               \ Store the current view type in QQ11 on the stack
 PHA

 LDA #0                 \ Clear the top part of the screen, draw a border box,
 JSR TT66_C               \ and set the current view type in QQ11 to 0 (the space
                        \ view)

 PLA                    \ Restore the view type from the stack
 STA QQ11

.HFS1_C

 LDX #&FF               \ Port: the rings are drawn directly, even in record
 STX GFORCE             \ mode (GFORCE, gfx-gvars.asm)

 LDX #X                 \ Set K3 = #X (the x-coordinate of the centre of the
 STX K3                 \ screen)

 LDX #Y                 \ Set K4 = #Y (the y-coordinate of the centre of the
 STX K4                 \ screen)

 LDX #0                 \ Set X = 0

 STX XX4                \ Set XX4 = 0, which we will use as a counter for
                        \ drawing eight concentric rings

 STX K3+1               \ Set the high bytes of K3(1 0) and K4(1 0) to 0
 STX K4+1

.HFL5_C

 JSR HFL1_C               \ Call HFL1 below to draw a set of rings, with each one
                        \ twice the radius of the previous one, until they won't
                        \ fit on-screen

 INC XX4                \ Increment the counter and fetch it into X
 LDX XX4

 CPX #8                 \ If we haven't drawn 8 sets of rings yet, loop back to
 BNE HFL5_C               \ HFL5 to draw the next ring

 STZ GFORCE             \ Port: back to recording (flags kept)

 RTS                    \ Return from the subroutine

.HFL1_C

 LDA XX4                \ Set K to the ring number in XX4 (0-7) + 8, so K has
 AND #7                 \ a value of 8 to 15, which we will use as the starting
 CLC                    \ radius for our next set of rings
 ADC #8
 STA K

.HFL2_C

 LDA #1                 \ Set LSP = 1 to reset the ball line heap
 STA LSP

 JSR x4_CIRCLE2            \ Call CIRCLE2 to draw a circle with the centre at
                        \ (K3(1 0), K4(1 0)) and radius K

 ASL K                  \ Double the radius in K

 BCS HF8_C                \ If the radius had a 1 in bit 7 before the above shift,
                        \ then doubling K will means the circle will no longer
                        \ fit on the screen (which is width 256), so jump to
                        \ HF8 to stop drawing circles

 LDA K                  \ If the radius in K <= 160, loop back to HFL2 to draw
 CMP #160               \ another one
 BCC HFL2_C

.HF8_C

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: dockEd
\       Type: Subroutine
\   Category: Flight
\    Summary: Print a message to say there is no hyperspacing allowed inside the
\             station
\
\ ------------------------------------------------------------------------------
\
\ Print "Docked" at the bottom of the screen to indicate we can't hyperspace
\ when docked.
\
\ ******************************************************************************

.dockEd_C

 JSR x4_CLYNS              \ Clear the bottom three text rows of the upper screen,
                        \ and move the text cursor to the first cleared row

 LDA #15                \ Move the text cursor to column 15 (the middle of the
 STA XC                 \ screen), setting A to 15 at the same time for the
                        \ following call to TT27

 LDA #RED               \ Switch to colour 2, which is magenta in the trade view
 STA COL                \ or red in the chart view

 LDA #205               \ Print extended token 205 ("DOCKED") and return from
 JMP DETOK_C              \ the subroutine using a tail call

\ ******************************************************************************
\
\       Name: hyp
\       Type: Subroutine
\   Category: Flight
\    Summary: Start the hyperspace process
\
\ ------------------------------------------------------------------------------
\
\ Called when "H" or CTRL-H is pressed during flight. Checks the following:
\
\   * We are in space
\
\   * We are not already in a hyperspace countdown
\
\ If CTRL is being held down, we jump to Ghy to engage the galactic hyperdrive,
\ otherwise we check that:
\
\   * The selected system is not the current system
\
\   * We have enough fuel to make the jump
\
\ and if all the pre-jump checks are passed, we print the destination on-screen
\ and start the countdown.
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   TTX111              Used to rejoin this routine from the call to TTX110
\
\ ******************************************************************************

.hyp_C

 LDA QQ12               \ If we are docked (QQ12 = &FF) then jump to dockEd to
 BNE dockEd_C             \ print an error message and return from the subroutine
                        \ using a tail call (as we can't hyperspace when docked)

 LDA QQ22+1             \ Fetch QQ22+1, which contains the number that's shown
                        \ on-screen during hyperspace countdown

 BEQ P%+3               \ If it is zero, skip the next instruction

 RTS                    \ The count is non-zero, so return from the subroutine

 LDA #CYAN              \ The count is zero, so switch to colour 3, which is
 STA COL                \ cyan in the space view

IF _SNG47

 JSR x4_CTRL               \ Scan the keyboard to see if CTRL is currently pressed

ELIF _COMPACT

 JSR x4_CTRLmc             \ Scan the keyboard to see if CTRL is currently pressed

ENDIF

 BMI Ghy_C                \ If it is, then the galactic hyperdrive has been
                        \ activated, so jump to Ghy to process it

 LDA QQ11               \ If the current view is 0 (i.e. the space view) then
 BEQ TTX110_C             \ jump to TTX110, which calls TT111 to set the current
                        \ system to the nearest system to (QQ9, QQ10), and jumps
                        \ back into this routine at TTX111 below

 AND #%11000000         \ If either bit 6 or 7 of the view type is set - so
 BNE P%+3               \ this is either the Short-range or Long-range Chart -
                        \ then skip the following instruction

 RTS                    \ This is not a chart view, so return from the
                        \ subroutine

 JSR hm_C                 \ This is a chart view, so call hm to redraw the chart
                        \ crosshairs

.TTX111_C

                        \ If we get here then the current view is either the
                        \ space view or a chart

 LDA QQ8                \ If either byte of the distance to the selected system
 ORA QQ8+1              \ in QQ8 are zero, skip the next instruction to make a
 BNE P%+3               \ copy of the destination seeds in safehouse

 RTS                    \ The selected system is the same as the current system,
                        \ so return from the subroutine

 LDX #5                 \ We now want to copy those seeds into safehouse, so we
                        \ so set a counter in X to copy 6 bytes

.sob_C

 LDA QQ15,X             \ Copy the X-th byte of QQ15 into the X-th byte of
 STA safehouse,X        \ safehouse

 DEX                    \ Decrement the loop counter

 BPL sob_C                \ Loop back to copy the next byte until we have copied
                        \ all six seed bytes

 LDA #7                 \ Move the text cursor to column 7, row 22 (in the
 STA XC                 \ middle of the bottom text row)
 LDA #22
 STA YC

 LDA #0                 \ Set QQ17 = 0 to switch to ALL CAPS
 STA QQ17

 LDA #189               \ Print recursive token 29 ("HYPERSPACE ")
 JSR TT27_C

 LDA QQ8+1              \ If the high byte of the distance to the selected
 BNE goTT147_C            \ system in QQ8 is > 0, then it is definitely too far to
                        \ jump (as our maximum range is 7.0 light years, or a
                        \ value of 70 in QQ8(1 0)), so jump to TT147 via goTT147
                        \ to print "RANGE?" and return from the subroutine using
                        \ a tail call

 LDA QQ14               \ Fetch our current fuel level from Q114 into A

 CMP QQ8                \ If our fuel reserves are greater than or equal to the
 BCS P%+5               \ distance to the selected system, then we have enough
                        \ fuel for this jump, so skip the following instruction
                        \ to start the hyperspace countdown

.goTT147_C

 JMP TT147_C              \ We don't have enough fuel to reach the destination, so
                        \ jump to TT147 to print "RANGE?" and return from the
                        \ subroutine using a tail call

 LDA #'-'               \ Print a hyphen
 JSR TT27_C

 JSR cpl_C                \ Call cpl to print the name of the selected system

                        \ Fall through into wW to start the hyperspace countdown

\ ******************************************************************************
\
\       Name: wW
\       Type: Subroutine
\   Category: Flight
\    Summary: Start a hyperspace countdown
\
\ ------------------------------------------------------------------------------
\
\ Start the hyperspace countdown (for both inter-system hyperspace and the
\ galactic hyperdrive).
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   wW2                 Start the hyperspace countdown, starting the countdown
\                       from the value in A
\
\ ******************************************************************************

.wW_C

 LDA #15                \ The hyperspace countdown starts from 15, so set A to
                        \ 15 so we can set the two hyperspace counters

.wW2_C

 STA QQ22+1             \ Set the number in QQ22+1 to A, which is the number
                        \ that's shown on-screen during the hyperspace countdown

 STA QQ22               \ Set the number in QQ22 to 15, which is the internal
                        \ counter that counts down by 1 each iteration of the
                        \ main game loop, and each time it reaches zero, the
                        \ on-screen counter gets decremented, and QQ22 gets set
                        \ to 5, so setting QQ22 to 15 here makes the first tick
                        \ of the hyperspace counter longer than subsequent ticks

 TAX                    \ Print the 8-bit number in X (i.e. 15) at text location
 JMP ee3_C                \ (0, 1), padded to 5 digits, so it appears in the top
                        \ left corner of the screen, and return from the
                        \ subroutine using a tail call

\ ******************************************************************************
\
\       Name: TTX110
\       Type: Subroutine
\   Category: Flight
\    Summary: Set the current system to the nearest system and return to hyp
\
\ ******************************************************************************

.TTX110_C

                        \ This routine is only called from the hyp routine, and
                        \ it jumps back into hyp at label TTX111

 JSR TT111_C              \ Call TT111 to set the current system to the nearest
                        \ system to (QQ9, QQ10), and put the seeds of the
                        \ nearest system into QQ15 to QQ15+5

 JMP TTX111_C             \ Return to TTX111 in the hyp routine

\ ******************************************************************************
\
\       Name: Ghy
\       Type: Subroutine
\   Category: Flight
\    Summary: Perform a galactic hyperspace jump
\  Deep dive: Twisting the system seeds
\             Galaxy and system seeds
\
\ ------------------------------------------------------------------------------
\
\ Engage the galactic hyperdrive. Called from the hyp routine above if CTRL-H is
\ being pressed.
\
\ This routine also updates the galaxy seeds to point to the next galaxy. Using
\ a galactic hyperdrive rotates each seed byte to the left, rolling each byte
\ left within itself like this:
\
\   01234567 -> 12345670
\
\ to get the seeds for the next galaxy. So after 8 galactic jumps, the seeds
\ roll round to those of the first galaxy again.
\
\ We always arrive in a new galaxy at galactic coordinates (96, 96), and then
\ find the nearest system and set that as our location.
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   zZ+1                Contains an RTS
\
\ ******************************************************************************

.Ghy_C

 LDX GHYP               \ Fetch GHYP, which tells us whether we own a galactic
 BEQ zZ_C+1               \ hyperdrive, and if it is zero, which means we don't,
                        \ return from the subroutine (as zZ+1 contains an RTS)

 INX                    \ We own a galactic hyperdrive, so X is &FF, so this
                        \ instruction sets X = 0

\STX QQ8                \ These instructions are commented out in the original
\STX QQ8+1              \ source

 STX GHYP               \ The galactic hyperdrive is a one-use item, so set GHYP
                        \ to 0 so we no longer have one fitted

 STX FIST               \ Changing galaxy also clears our criminal record, so
                        \ set our legal status in FIST to 0 ("clean")

 LDA #2                 \ Call wW2 with A = 2 to start the hyperspace countdown,
 JSR wW2_C                \ but starting the countdown from 2

 LDX #5                 \ To move galaxy, we rotate the galaxy's seeds left, so
                        \ set a counter in X for the 6 seed bytes

 INC GCNT               \ Increment the current galaxy number in GCNT

 LDA GCNT               \ Clear bit 3 of GCNT, so we jump from galaxy 7 back
 AND #%11110111         \ to galaxy 0 (shown in-game as going from galaxy 8 back
 STA GCNT               \ to the starting point in galaxy 1). We also retain any
                        \ set bits in the high nibble, so if the galaxy number
                        \ is manually set to 16 or higher, it will stay high
                        \ (though the high nibble doesn't seem to get set by
                        \ the game at any point, so it isn't clear what this is
                        \ for, though Lave in galaxy 16 does show a unique
                        \ system description override, so something is going on
                        \ here...)

.G1_C

 LDA QQ21,X             \ Load the X-th seed byte into A

 ASL A                  \ Set the C flag to bit 7 of the seed

 ROL QQ21,X             \ Rotate the seed in memory, which will add bit 7 back
                        \ in as bit 0, so this rolls the seed around on itself

 DEX                    \ Decrement the counter

 BPL G1_C                 \ Loop back for the next seed byte, until we have
                        \ rotated them all

\JSR DORND              \ This instruction is commented out in the original
                        \ source, and would set A and X to random numbers, so
                        \ perhaps the original plan was to arrive in each new
                        \ galaxy in a random place?

.zZ_C

 LDA #96                \ Set (QQ9, QQ10) to (96, 96), which is where we always
 STA QQ9                \ arrive in a new galaxy (the selected system will be
 STA QQ10               \ set to the nearest actual system later on)

 JSR TT110_C              \ Call TT110 to show the front space view

 JSR TT111_C              \ Call TT111 to set the current system to the nearest
                        \ system to (QQ9, QQ10), and put the seeds of the
                        \ nearest system into QQ15 to QQ15+5
                        \
                        \ This call fixes a bug in the cassette version, where
                        \ the galactic hyperdrive will take us to coordinates
                        \ (96, 96) in the new galaxy, even if there isn't
                        \ actually a system there, so if we jump when we are
                        \ low on fuel, it is possible to get stuck in the
                        \ middle of nowhere when changing galaxy
                        \
                        \ This call sets the current system correctly, so we
                        \ always arrive at the nearest system to (96, 96)

 LDX #5                 \ We now want to copy those seeds into safehouse, so we
                        \ so set a counter in X to copy 6 bytes

.dumdeedum_C

 LDA QQ15,X             \ Copy the X-th byte of QQ15 into the X-th byte of
 STA safehouse,X        \ safehouse

 DEX                    \ Decrement the loop counter

 BPL dumdeedum_C          \ Loop back to copy the next byte until we have copied
                        \ all six seed bytes

 LDX #0                 \ Set the distance to the selected system in QQ8(1 0)
 STX QQ8                \ to 0
 STX QQ8+1

 LDA #116               \ Print recursive token 116 (GALACTIC HYPERSPACE ")
 JSR MESS_C               \ as an in-flight message

                        \ Fall through into jmp to set the system to the
                        \ current system and return from the subroutine there

\ ******************************************************************************
\
\       Name: jmp
\       Type: Subroutine
\   Category: Universe
\    Summary: Set the current system to the selected system
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   (QQ0, QQ1)          The galactic coordinates of the new system
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   hy5                 Contains an RTS
\
\ ******************************************************************************

.jmp_C

 LDA QQ9                \ Set the current system's galactic x-coordinate to the
 STA QQ0                \ x-coordinate of the selected system

 LDA QQ10               \ Set the current system's galactic y-coordinate to the
 STA QQ1                \ y-coordinate of the selected system

.hy5_C

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: ee3
\       Type: Subroutine
\   Category: Flight
\    Summary: Print the hyperspace countdown in the top-left of the screen
\
\ ------------------------------------------------------------------------------
\
\ 5 digits, left-padding with spaces for numbers with fewer than 3 digits (so
\ numbers < 10000 are right-aligned), with no decimal point.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The number to print
\
\ ******************************************************************************

.ee3_C

 LDA #RED               \ Switch to colour 2, which is red in the space view
 STA COL

 LDA #1                 \ Move the text cursor to column 1
 STA XC

 STA YC                 \ Move the text cursor to row 1

 LDY #0                 \ Set Y = 0 for the high byte in pr6

 CLC                    \ Call TT11 to print X to 3 digits with no decimal point
 LDA #3                 \ and return from the subroutine using a tail call
 JMP TT11_C

\ ******************************************************************************
\
\       Name: pr6
\       Type: Subroutine
\   Category: Text
\    Summary: Print 16-bit number, left-padded to 5 digits, no point
\
\ ------------------------------------------------------------------------------
\
\ Print the 16-bit number in (Y X) to 5 digits, left-padding with spaces for
\ numbers with fewer than 3 digits (so numbers < 10000 are right-aligned),
\ with no decimal point.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The low byte of the number to print
\
\   Y                   The high byte of the number to print
\
\ ******************************************************************************

.pr6_C

 CLC                    \ Do not display a decimal point when printing

                        \ Fall through into pr5 to print X to 5 digits

\ ******************************************************************************
\
\       Name: pr5
\       Type: Subroutine
\   Category: Text
\    Summary: Print a 16-bit number, left-padded to 5 digits, and optional point
\
\ ------------------------------------------------------------------------------
\
\ Print the 16-bit number in (Y X) to 5 digits, left-padding with spaces for
\ numbers with fewer than 3 digits (so numbers < 10000 are right-aligned).
\ Optionally include a decimal point.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The low byte of the number to print
\
\   Y                   The high byte of the number to print
\
\   C flag              If set, include a decimal point
\
\ ******************************************************************************

.pr5_C

 LDA #5                 \ Set the number of digits to print to 5

 JMP TT11_C               \ Call TT11 to print (Y X) to 5 digits and return from
                        \ the subroutine using a tail call

\ ******************************************************************************
\
\       Name: TT147
\       Type: Subroutine
\   Category: Flight
\    Summary: Print an error when a system is out of hyperspace range
\
\ ------------------------------------------------------------------------------
\
\ Print "RANGE?" for when the hyperspace distance is too far
\
\ ******************************************************************************

.TT147_C

 LDA #202               \ Load A with token 42 ("RANGE") and fall through into
                        \ prq to print it, followed by a question mark

\ ******************************************************************************
\
\       Name: prq
\       Type: Subroutine
\   Category: Text
\    Summary: Print a text token followed by a question mark
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The text token to be printed
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   prq+3               Print a question mark
\
\ ******************************************************************************

.prq_C

 JSR TT27_C               \ Print the text token in A

 LDA #'?'               \ Print a question mark and return from the
 JMP TT27_C               \ subroutine using a tail call

\ ******************************************************************************
\
\       Name: hyp1
\       Type: Subroutine
\   Category: Universe
\    Summary: Process a jump to the system closest to (QQ9, QQ10)
\
\ ------------------------------------------------------------------------------
\
\ Do a hyperspace jump to the system closest to galactic coordinates
\ (QQ9, QQ10), and set up the current system's state to those of the new system.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   (QQ0, QQ1)          The galactic coordinates of the new system
\
\   QQ2 to QQ2+6        The seeds of the new system
\
\   EV                  Set to 0
\
\   QQ28                The new system's economy
\
\   tek                 The new system's tech level
\
\   gov                 The new system's government
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   hyp1+3              Jump straight to the system at (QQ9, QQ10) without
\                       first calculating which system is closest. We do this
\                       if we already know that (QQ9, QQ10) points to a system
\
\ ******************************************************************************

.hyp1_C

                        \ Port: JSR TT111 removed (unreachable: hyp1 is only
                        \ ever called as hyp1+3, now hyp1_C)

 JSR jmp_C                \ Set the current system to the selected system

 LDX #5                 \ We now want to copy the seeds for the selected system
                        \ in QQ15 into QQ2, where we store the seeds for the
                        \ current system, so set up a counter in X for copying
                        \ 6 bytes (for three 16-bit seeds)

.TT112_C

 LDA safehouse,X        \ Copy the X-th byte in safehouse to the X-th byte in
 STA QQ2,X              \ QQ2

 DEX                    \ Decrement the counter

 BPL TT112_C              \ Loop back to TT112 if we still have more bytes to
                        \ copy

 INX                    \ Set X = 0 (as we ended the above loop with X = &FF)

 STX EV                 \ Set EV, the extra vessels spawning counter, to 0, as
                        \ we are entering a new system with no extra vessels
                        \ spawned

 LDA QQ3                \ Set the current system's economy in QQ28 to the
 STA QQ28               \ selected system's economy from QQ3

 LDA QQ5                \ Set the current system's tech level in tek to the
 STA tek                \ selected system's economy from QQ5

 LDA QQ4                \ Set the current system's government in gov to the
 STA gov                \ selected system's government from QQ4

                        \ Fall through into GVL to calculate the availability of
                        \ market items in the new system

\ ******************************************************************************
\
\       Name: GVL
\       Type: Subroutine
\   Category: Universe
\    Summary: Calculate the availability of market items
\  Deep dive: Market item prices and availability
\             Galaxy and system seeds
\
\ ------------------------------------------------------------------------------
\
\ Calculate the availability for each market item and store it in AVL. This is
\ called on arrival in a new system.
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   hyR                 Contains an RTS
\
\ ******************************************************************************

.GVL_C

 JSR x4_DORND              \ Set A and X to random numbers

 STA QQ26               \ Set QQ26 to the random byte that's used in the market
                        \ calculations

 LDX #0                 \ We are now going to loop through the market item
 STX XX4                \ availability table in AVL, so set a counter in XX4
                        \ (and X) for the market item number, starting with 0

.hy9_C

 LDA QQ23+1,X           \ Fetch byte #1 from the market prices table (units and
 STA QQ19+1             \ economic_factor) for item number X and store it in
                        \ QQ19+1

 JSR var_C                \ Call var to set QQ19+3 = economy * |economic_factor|
                        \ (and set the availability of alien items to 0)

 LDA QQ23+3,X           \ Fetch byte #3 from the market prices table (mask) and
 AND QQ26               \ AND with the random number for this system visit
                        \ to give:
                        \
                        \   A = random AND mask

 CLC                    \ Add byte #2 from the market prices table
 ADC QQ23+2,X           \ (base_quantity) so we now have:
                        \
                        \   A = base_quantity + (random AND mask)

 LDY QQ19+1             \ Fetch the byte #1 that we stored above and jump to
 BMI TT157_C              \ TT157 if it is negative (i.e. if the economic_factor
                        \ is negative)

 SEC                    \ Set A = A - QQ19+3
 SBC QQ19+3             \
                        \       = base_quantity + (random AND mask)
                        \         - (economy * |economic_factor|)
                        \
                        \ which is the result we want, as the economic_factor
                        \ is positive

 JMP TT158_C              \ Jump to TT158 to skip TT157

.TT157_C

 CLC                    \ Set A = A + QQ19+3
 ADC QQ19+3             \
                        \       = base_quantity + (random AND mask)
                        \         + (economy * |economic_factor|)
                        \
                        \ which is the result we want, as the economic_factor
                        \ is negative

.TT158_C

 BPL TT159_C              \ If A < 0, then set A = 0, so we don't have negative
 LDA #0                 \ availability

.TT159_C

 LDY XX4                \ Fetch the counter (the market item number) into Y

 AND #%00111111         \ Take bits 0-5 of A, i.e. A mod 64, and store this as
 STA AVL,Y              \ this item's availability in the Y=th byte of AVL, so
                        \ each item has a maximum availability of 63t

 INY                    \ Increment the counter into XX44, Y and A
 TYA
 STA XX4

 ASL A                  \ Set X = counter * 4, so that X points to the next
 ASL A                  \ item's entry in the four-byte market prices table,
 TAX                    \ ready for the next loop

 CMP #63                \ If A < 63, jump back up to hy9 to set the availability
 BCC hy9_C                \ for the next market item

.hyR_C

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: QQ23
\       Type: Variable
\   Category: Market
\    Summary: Market prices table
\             (Port: in the cold area, as only cold code reads it)
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
\       Name: GTHG
\       Type: Subroutine
\   Category: Universe
\    Summary: Spawn a Thargoid ship and a Thargon companion
\  Deep dive: Fixing ship positions
\             Aggression and hostility in ship tactics
\
\ ******************************************************************************

.GTHG_C

 JSR Ze_C                 \ Call Ze to initialise INWK to a fairly aggressive
                        \ ship (though we increase this below)
                        \
                        \ Note that because Ze uses the value of X returned by
                        \ DORND, and X contains the value of A returned by the
                        \ previous call to DORND, this does not set the new ship
                        \ to a totally random location

 LDA #%11111111         \ Set the AI flag in byte #32 so that the ship has AI,
 STA INWK+32            \ an aggression level of 63 out of 63, and E.C.M.

 LDA #THG               \ Call NWSHP to add a new Thargoid ship to our local
 JSR x4_NWSHP              \ bubble of universe

 LDA #TGL               \ Call NWSHP to add a new Thargon ship to our local
 JMP x4_NWSHP              \ bubble of universe, and return from the subroutine
                        \ using a tail call

\ ******************************************************************************
\
\       Name: MJP
\       Type: Subroutine
\   Category: Flight
\    Summary: Process a mis-jump into witchspace
\
\ ------------------------------------------------------------------------------
\
\ Process a mis-jump into witchspace (which happens very rarely). Witchspace has
\ a strange, almost dust-free aspect to it, and it is populated by aggressive
\ Thargoids. Using our escape pod will be fatal, and our position on the
\ galactic chart is in-between systems. It is a scary place...
\
\ There is a 0.78% chance that this routine is called from TT18 instead of doing
\ a normal hyperspace, or we can manually trigger a mis-jump by holding down
\ CTRL after first enabling the "author display" configuration option ("X") when
\ paused.
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   ptg                 Called when the user manually forces a mis-jump
\
\   RTS111              Contains an RTS
\
\ ******************************************************************************

.ptg_C

 LSR COK                \ Set bit 0 of the competition flags in COK, so that the
 SEC                    \ competition code will include the fact that we have
 ROL COK                \ manually forced a mis-jump into witchspace

.MJP_C

\JSR CATLOD             \ This instruction is commented out in the original
                        \ source

 LDA #3                 \ Clear the top part of the screen, draw a border box,
 JSR TT66_C               \ and set the current view type in QQ11 to 3

 JSR LL164_C              \ Call LL164 to show the hyperspace tunnel and make the
                        \ hyperspace sound for a second time (as we already
                        \ called LL164 in TT18)

 JSR RES2_C               \ Reset a number of flight variables and workspaces, as
                        \ well as setting Y to &FF

 STY MJ                 \ Set the mis-jump flag in MJ to &FF, to indicate that
                        \ we are now in witchspace

.MJP1_C

 JSR GTHG_C               \ Call GTHG to spawn a Thargoid ship and a Thargon
                        \ companion

 LDA #2                 \ Fetch the number of Thargoid ships from MANY+THG, and
 CMP MANY+THG           \ if it is less than or equal to 2, loop back to MJP1 to
 BCS MJP1_C               \ spawn another one, until we have three Thargoids

 STA NOSTM              \ Set NOSTM (the maximum number of stardust particles)
                        \ to 3, so there are fewer bits of stardust in
                        \ witchspace (normal space has a maximum of 18)

 LDX #0                 \ Initialise the front space view
 JSR x4_LOOK1

 LDA QQ1                \ Fetch the current system's galactic y-coordinate in
 EOR #%00011111         \ QQ1 and flip bits 0-5, so we end up somewhere in the
 STA QQ1                \ vicinity of our original destination, but above or
                        \ below it in the galactic chart

 RTS                    \ Return from the subroutine

.RTS111_C

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TT18
\       Type: Subroutine
\   Category: Flight
\    Summary: Try to initiate a jump into hyperspace
\
\ ------------------------------------------------------------------------------
\
\ Try to go through hyperspace. Called from TT102 in the main loop when the
\ hyperspace countdown has finished.
\
\ ******************************************************************************

.TT18_C

 LDA QQ14               \ Subtract the distance to the selected system (in QQ8)
 SEC                    \ from the amount of fuel in our tank (in QQ14) into A
 SBC QQ8

 BCS P%+4               \ If the subtraction didn't overflow, skip the next
                        \ instruction

 LDA #0                 \ The subtraction overflowed, so set A = 0 so we don't
                        \ end up with a negative amount of fuel

 STA QQ14               \ Store the updated fuel amount in QQ14

 LDA QQ11               \ If the current view is not a space view, jump to ee5
 BNE ee5_C                \ to skip the following

 JSR TT66_C               \ Clear the top part of the screen, draw a border box,
                        \ and set the current view type in QQ11 to 0 (space
                        \ view)

 JSR LL164_C              \ Call LL164 to show the hyperspace tunnel and make the
                        \ hyperspace sound

.ee5_C

IF _SNG47

 JSR x4_CTRL               \ Scan the keyboard to see if CTRL is currently pressed,
                        \ returning a negative value in A if it is

ELIF _COMPACT

 JSR x4_CTRLmc             \ Scan the keyboard to see if CTRL is currently pressed,
                        \ returning a negative value in A if it is

ENDIF

 AND PATG               \ If the game is configured to show the author's names
                        \ on the start-up screen, then PATG will contain &FF,
                        \ otherwise it will be 0

 BMI ptg_C                \ By now, A will be negative if we are holding down CTRL
                        \ and author names are configured, which is what we have
                        \ to do in order to trigger a manual mis-jump, so jump
                        \ to ptg to do a mis-jump (ptg not only mis-jumps, but
                        \ updates the competition flags, so Acornsoft could tell
                        \ from the competition code whether this feature had
                        \ been used)

 JSR x4_DORND              \ Set A and X to random numbers

 CMP #253               \ If A >= 253 (0.78% chance) then jump to MJP to trigger
 BCS MJP_C                \ a mis-jump into witchspace

\JSR TT111              \ This instruction is commented out in the original
                        \ source. It finds the closest system to coordinates
                        \ (QQ9, QQ10), but we don't need to do this as the
                        \ crosshairs will already be on a system by this point

 JSR hyp1_C             \ Jump straight to the system at (QQ9, QQ10) without
                        \ first calculating which system is closest (Port:
                        \ hyp1+3 in the original, as hyp1's JSR TT111 is gone)

 JSR RES2_C               \ Reset a number of flight variables and workspaces

 JSR SOLAR_C              \ Halve our legal status, update the missile indicators,
                        \ and set up data blocks and slots for the planet and
                        \ sun

\JSR CATLOD             \ These instructions are commented out in the original
\                       \ source
\JSR LOMOD

 LDA QQ11               \ If the current view in QQ11 is not a space view (0) or
 AND #%00111111         \ one of the charts (64 or 128), return from the
 BNE RTS111_C             \ subroutine (as RTS111 contains an RTS)

 JSR x4_TTX66              \ Otherwise clear the screen and draw a border box

 LDA QQ11               \ If the current view is one of the charts, jump to
 BNE TT114_C              \ TT114 (from which we jump to the correct routine to
                        \ display the chart)

 INC QQ11               \ This is a space view, so increment QQ11 to 1

                        \ Fall through into TT110 to show the front space view

\ ******************************************************************************
\
\       Name: TT110
\       Type: Subroutine
\   Category: Flight
\    Summary: Launch from a station or show the front space view
\
\ ------------------------------------------------------------------------------
\
\ Launch the ship (if we are docked), or show the front space view (if we are
\ already in space).
\
\ Called when red key f0 is pressed while docked (launch), after we arrive in a
\ new galaxy, or after a hyperspace if the current view is a space view.
\
\ ******************************************************************************

.TT110_C

 LDX QQ12               \ If we are not docked (QQ12 = 0) then jump to NLUNCH
 BEQ NLUNCH_C             \ to skip the launch tunnel and setup process

 JSR LAUN_C               \ Show the space station launch tunnel

 JSR RES2_C               \ Reset a number of flight variables and workspaces

 JSR TT111_C              \ Select the system closest to galactic coordinates
                        \ (QQ9, QQ10)

 INC INWK+8             \ Increment z_sign ready for the call to SOS, so the
                        \ planet appears at a z_sign of 1 in front of us when
                        \ we launch

 JSR SOS1_C               \ Call SOS1 to set up the planet's data block and add it
                        \ to FRIN, where it will get put in the first slot as
                        \ it's the first one to be added to our local bubble of
                        \ universe following the call to RES2 above

 LDA #128               \ For the space station, set z_sign to &80, so it's
 STA INWK+8             \ behind us (&80 is negative)

 INC INWK+7             \ And increment z_hi, so it's only just behind us

 JSR x4_NWSPS              \ Add a new space station to our local bubble of
                        \ universe

 LDA #12                \ Set our launch speed in DELTA to 12
 STA DELTA

 JSR BAD_C                \ Call BAD to work out how much illegal contraband we
                        \ are carrying in our hold (A is up to 40 for a
                        \ standard hold crammed with contraband, up to 70 for
                        \ an extended cargo hold full of narcotics and slaves)

 ORA FIST               \ OR the value in A with our legal status in FIST to
                        \ get a new value that is at least as high as both
                        \ values, to reflect the fact that launching with a
                        \ hold full of contraband can only make matters worse

 STA FIST               \ Update our legal status with the new value

 LDA #255               \ Set the view type in QQ11 to 255
 STA QQ11

 JSR HFS1_C               \ Call HFS1 to draw 8 concentric rings to remove the
                        \ launch tunnel that we drew above

.NLUNCH_C

 LDX #0                 \ Set QQ12 to 0 to indicate we are not docked
 STX QQ12

 JMP x4_LOOK1              \ Jump to LOOK1 to switch to the front view (X = 0),
                        \ returning from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: TT114
\       Type: Subroutine
\   Category: Charts
\    Summary: Display either the Long-range or Short-range Chart
\
\ ------------------------------------------------------------------------------
\
\ Display either the Long-range or Short-range Chart, depending on the current
\ view setting. Called from TT18 once we know the current view is one of the
\ charts.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The current view, loaded from QQ11
\
\ ******************************************************************************

.TT114_C

 BMI TT115_C              \ If bit 7 of the current view is set (i.e. the view is
                        \ the Short-range Chart, 128), skip to TT115 below to
                        \ jump to TT23 to display the chart

 JMP TT22_C               \ Otherwise the current view is the Long-range Chart, so
                        \ jump to TT22 to display it

.TT115_C

 JMP TT23_C               \ Jump to TT23 to display the Short-range Chart

\ ******************************************************************************
\
\       Name: SOS1
\       Type: Subroutine
\   Category: Universe
\    Summary: Update the missile indicators, set up the planet data block
\
\ ------------------------------------------------------------------------------
\
\ Update the missile indicators, and set up a data block for the planet, but
\ only setting the pitch and roll counters to 127 (no damping).
\
\ ******************************************************************************

.SOS1_C

 JSR x4_msblob              \ Reset the dashboard's missile indicators so none of
                        \ them are targeted

 LDA #127               \ Set the pitch and roll counters to 127, so that's a
 STA INWK+29            \ clockwise roll and a diving pitch with no damping, so
 STA INWK+30            \ the planet's rotation doesn't slow down

 LDA tek                \ Set A = 128 or 130 depending on bit 1 of the system's
 AND #%00000010         \ tech level in tek
 ORA #%10000000

 JMP x4_NWSHP              \ Add a new planet to our local bubble of universe,
                        \ with the planet type defined by A (128 is a planet
                        \ with an equator and meridian, 130 is a planet with
                        \ a crater)

\ ******************************************************************************
\
\       Name: SOLAR
\       Type: Subroutine
\   Category: Universe
\    Summary: Set up various aspects of arriving in a new system
\  Deep dive: A sense of scale
\
\ ------------------------------------------------------------------------------
\
\ Halve our legal status, update the missile indicators, and set up data blocks
\ and slots for the planet and sun.
\
\ ******************************************************************************

.SOLAR_C

 LDA TRIBBLE            \ If we have no Trumbles in the hold, skip to nobirths
 BEQ nobirths_C

                        \ If we get here then we have Trumbles in the hold, so
                        \ this is where they breed (though we never get here in
                        \ the Master version as the number of Trumbles is always
                        \ zero)

 LDA #0                 \ Trumbles eat food and narcotics during the hyperspace
 STA QQ20               \ journey, so zero the amount of food and narcotics in
 STA QQ20+6             \ the hold

 JSR x4_DORND              \ Take the number of Trumbles from TRIBBLE(1 0), add a
 AND #15                \ random number between 4 and 15, and double the result,
 ADC TRIBBLE            \ storing the resulting number in TRIBBLE(1 0)
 ORA #4                 \
 ROL A                  \ We start with the low byte
 STA TRIBBLE

 ROL TRIBBLE+1          \ And then do the high byte

 BPL P%+5               \ If bit 7 of the high byte is set, then rotate the high
 ROR TRIBBLE+1          \ byte back to the right, so the number of Trumbles is
                        \ always positive

.nobirths_C

 LSR FIST               \ Halve our legal status in FIST, making us less bad,
                        \ and moving bit 0 into the C flag (so every time we
                        \ arrive in a new system, our legal status improves a
                        \ bit)

 JSR x4_ZINF               \ Call ZINF to reset the INWK ship workspace, which
                        \ doesn't affect the C flag

 LDA QQ15+1             \ Fetch s0_hi

 AND #%00000011         \ Extract bits 0-1 (which also help to determine the
                        \ economy), which will be between 0 and 3

 ADC #3                 \ Add 3 + C, to get a result between 3 and 7, clearing
                        \ the C flag in the process

 STA INWK+8             \ Store the result in z_sign in byte #6

 ROR A                  \ Halve A, rotating in the C flag (which is clear) and
 STA INWK+2             \ store in both x_sign and y_sign, moving the planet to
 STA INWK+5             \ the upper right

 JSR SOS1_C               \ Call SOS1 to set up the planet's data block and add it
                        \ to FRIN, where it will get put in the first slot as
                        \ it's the first one to be added to our local bubble of
                        \ this new system's universe

 LDA QQ15+3             \ Fetch s1_hi, extract bits 0-2, set bits 0 and 7 and
 AND #%00000111         \ store in z_sign, so the sun is behind us at a distance
 ORA #%10000001         \ of 1 to 7
 STA INWK+8

 LDA QQ15+5             \ Fetch s2_hi, extract bits 0-1 and store in x_sign and
 AND #%00000011         \ y_sign, so the sun is either dead centre in our rear
 STA INWK+2             \ laser crosshairs, or off to the top left by a distance
 STA INWK+1             \ of 1 or 2 when we look out the back

 LDA #0                 \ Set the pitch and roll counters to 0 (no rotation)
 STA INWK+29
 STA INWK+30

 LDA #129               \ Set A = 129, the ship type for the sun

 JSR x4_NWSHP              \ Call NWSHP to set up the sun's data block and add it
                        \ to FRIN, where it will get put in the second slot as
                        \ it's the second one to be added to our local bubble
                        \ of this new system's universe

 JMP x4_NWSTARS            \ Port: set up the stardust and return (the original
                        \ fell through into NWSTARS)

\ ******************************************************************************
\
\       Name: SETINTS
\       Type: Subroutine
\   Category: Loader
\    Summary: Set the various vectors, interrupts and timers
\
\ ******************************************************************************

.SETINTS_C

 SEI                    \ Disable interrupts

 LDA #%00111001         \ Set 6522 System VIA interrupt enable register IER
 STA VIA+&4E            \ (SHEILA &4E) bits 0 and 3-5 (i.e. disable the Timer1,
                        \ CB1, CB2 and CA2 interrupts from the System VIA)

 LDA #%01111111         \ Set 6522 User VIA interrupt enable register IER
 STA &FE6E              \ (SHEILA &6E) bits 0-7 (i.e. disable all hardware
                        \ interrupts from the User VIA)

 LDA IRQ1V              \ Store the current IRQ1V vector in VEC, so VEC(1 0) now
 STA VEC                \ contains the original address of the IRQ1 handler
 LDA IRQ1V+1
 STA VEC+1

 LDA #LO(IRQ1)          \ Set the IRQ1V vector to IRQ1, so IRQ1 is now the
 STA IRQ1V              \ interrupt handler
 LDA #HI(IRQ1)
 STA IRQ1V+1

 LDA VSCAN              \ Set 6522 System VIA T1C-L timer 1 high-order counter
 STA VIA+&45            \ (SHEILA &45) to the contents of VSCAN (57) to start
                        \ the T1 counter counting down from 14592 at a rate of
                        \ 1 MHz

 CLI                    \ Enable interrupts again

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TGINT
\       Type: Variable
\   Category: Keyboard
\    Summary: The keys used to toggle configuration settings when the game is
\             paused
\
\ ******************************************************************************

.TGINT_C

 EQUB 1                 \ The configuration keys in the same order as their
 EQUS "AXFYJKUT"        \ configuration bytes (starting from DAMP). The 1 is
                        \ for CAPS LOCK, and although "U" and "T" still toggle
                        \ the relevant configuration bytes, those values are not
                        \ used, so those keys have no effect

\ ******************************************************************************
\
\       Name: S%
\       Type: Subroutine
\   Category: Loader
\    Summary: Move code, set up break handler and start the game
\
\ ******************************************************************************

                        \ Port: the RTS here is removed (unreachable: "This
                        \ byte appears to be unused")

.S%

 CLD                    \ Clear the D flag to make sure we are in binary mode

 JSR DEEOR_C              \ Call DEEOR to unscramble the main code

 JSR COLD_C               \ Call COLD to set up the break handler

\JSR Checksum           \ This instruction is commented out in the original
                        \ source

 JMP j4_BEGIN              \ Jump to BEGIN to start the game

\ ******************************************************************************
\
\       Name: DEEOR
\       Type: Subroutine
\   Category: Utility routines
\    Summary: Unscramble the main code
\
\ ------------------------------------------------------------------------------
\
\ The main game code and data are encrypted. This routine decrypts the game code
\ in two parts: the main game code between G% and F%, and the game data between
\ XX21 and the end of the game data at &B1FF.
\
\ In the BeebAsm version, the encryption is done by elite-checksum.py, but in
\ the original this would have been done by the BBC BASIC build scripts.
\
\ ******************************************************************************

.DEEOR_C

 LDA #LO(G%-1)          \ Set FRIN(1 0) = G%-1 as the low address of the
 STA FRIN               \ decryption block, so we decrypt from the start of the
 LDA #HI(G%-1)          \ DOENTRY routine
 STA FRIN+1

 LDA #HI(F%-1)          \ Set (A Y) to F% as the high address of the decryption
 LDY #LO(F%-1)          \ block, so we decrypt to the end of the main game code
                        \ at F%

 LDX #KEY1              \ Set X = KEY1 as the decryption seed (the value used to
                        \ encrypt the code, which is done in elite-checksum.py)

 NOP                    \ If we have disabled checksums, skip the call to DEEORS
 NOP                    \ and return from the subroutine to skip the second call
 RTS                    \ below

                        \ Port: the rest is removed (unreachable: the port is
                        \ always built with _REMOVE_CHECKSUMS, so DEEOR returns
                        \ above): the ELSE's JSR DEEORS, and the second block's
                        \ set-up (XX21-1 to &B1FF, KEY2) that fell into DEEORS

\ ******************************************************************************
\
\       Name: DEEORS
\       Type: Subroutine
\   Category: Utility routines
\    Summary: Decrypt a multi-page block of memory
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   FRIN(1 0)           The start address of the block to decrypt
\
\   (A Y)               The end address of the block to decrypt
\
\   X                   The decryption seed
\
\ ******************************************************************************

                        \ Port: removed (unreachable without the copy
                        \ protection): DEEORS and DEEORL, and the four unused
                        \ "red herring" bytes after them (EQUB &B7, &AA, &45,
                        \ &23)

\ ******************************************************************************
\
\       Name: COLD
\       Type: Subroutine
\   Category: Save and load
\    Summary: Set the standard BRKV handler for the game
\
\ ******************************************************************************

.COLD_C

 LDA #LO(NEWBRK)        \ Set BRKV to point to the NEWBRK routine
 STA BRKV
 LDA #HI(NEWBRK)
 STA BRKV+1

 LDA #LO(CHPR)          \ Set WRCHV to point to the CHPR routine
 STA WRCHV
 LDA #HI(CHPR)
 STA WRCHV+1

 JSR setzp_C              \ Call setzp to copy the top part of zero page into
                        \ the buffer at &3000

 JSR SETINTS_C            \ Call SETINTS to set various vectors, interrupts and
                        \ timers

 JMP x4_SOFLUSH            \ Call SOFLUSH to reset the sound buffers and return
                        \ from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: DOSCLI
\       Type: Subroutine
\   Category: Save and load
\    Summary: Port: OSCLI for the disc commands, with the renderer's HAZEL and
\             NMI glue (docs/MASTER-MEMORY.md)
\
\ ------------------------------------------------------------------------------
\
\ DFS and the MOS overwrite HAZEL's &C000-&C2FF, the DFS and ADFS private
\ pages &D900-&DAFF, &DC00 up to the command's end and &DF00-&DFFF during a
\ disc command, and keep their own lasting state in &C2C0-&C2FF and
\ &DFDA-&DFDB (docs/MASTER-MEMORY.md); a third-party ROM may write its own
\ page of HAZEL too. So the whole of HAZEL is stashed in screen buffer 0
\ (main RAM &4000-&5FFF, not on show while docked) for the command and copied
\ back afterwards, and GSTASH tells the renderer that buffer 0 no longer
\ holds a frame (the next space-mode frame clears it, f_b0new). DFS's and
\ the MOS's lasting bytes (&C2C0-&C2FF, and &DFC0-&DFFF: the MOS's FSCV copy
\ at &DFDA-&DFDB, and the ACCCON its error path puts back from &DFDC when
\ &DFDD is non-zero) live in DFSST while the game runs (the loader takes
\ them after its last disc access): they go back before the command and are
\ stashed again after it (or after its error, through DOSNMI), as *DIR and
\ *DRIVE change them. Before the command the catalogue cache is invalidated
\ too (&FF to &C282, &C287 and &C28B-&C28E: re-read the catalogue, restore
\ the head), as with the drive motor still on DFS would otherwise trust a
\ cache the game has overwritten (and could write a catalogue built from
\ it). What the IRQ handler and the printing of the catalogue (CHPR) read
\ during the command is in HAZEL's &C300-&D8FF, which disc commands leave
\ alone. DFS copies its own NMI routine to &0D00 for the command; afterwards
\ the 1770 is quietened (Force Interrupt) and the minimal handler the loader
\ installed goes back (a stray NMI would otherwise run DFS's handler with
\ the game's zero page at &A0-&A7). The error path (BRKV, NEWBRK) does the
\ same through DOSNMI.
\
\ ******************************************************************************

.DOSCLI_C

 PHA                    \ Stash HAZEL in buffer 0 (A, X and Y are kept for
 PHX                    \ OSCLI), with GSTASH set (in HAZEL: the copy back
 PHY                    \ keeps it): buffer 0 holds no frame from now on
 LDA #&80
 STA GSTASH
 LDX #&C0
 LDY #&40
 JSR dosmv
 PLY

 LDX #63                \ Put back DFS's and the MOS's lasting bytes
.dosc1
 LDA DFSST,X
 STA &C2C0,X
 LDA DFSST+64,X
 STA &DFC0,X
 DEX
 BPL dosc1
 PLX

 LDA #&FF               \ Invalidate DFS's catalogue cache and drive state
 STA &C282
 STA &C287
 STA &C28B
 STA &C28C
 STA &C28D
 STA &C28E
 STA DFSIN              \ (a disc command is under way)
 PLA

 JSR OSCLI              \ The command

                        \ Fall through into DOSNMI to put the minimal NMI
                        \ handler back

.DOSNMI_C

 PHP                    \ Keep the flags and A (X and Y are not changed)
 PHA
 SEI

 LDA #&D0               \ 1770 Force Interrupt, no conditions: terminate any
 STA &FE28              \ command and raise no interrupt

 LDA #8                 \ Give the 1770 time to take the command
.dosn1
 DEC A
 BNE dosn1

 LDA &FE28              \ Read the status register, which clears INTRQ

 LDA #&40               \ &0D00 = RTI, then the body at &0D01 (LDA &FE28 :
 STA &0D00              \ PLA : RTI), then &0D00 = PHA, so &0D00 holds a
 LDA #&AD               \ complete handler at every step (page &0D is otherwise
 STA &0D01              \ off limits, docs/MASTER-MEMORY.md)
 LDA #&28
 STA &0D02
 LDA #&FE
 STA &0D03
 LDA #&68
 STA &0D04
 LDA #&40
 STA &0D05
 LDA #&48
 STA &0D00

.DOSNMI_END_C

 BIT DFSIN              \ After a disc command (or its error), stash DFS's
 BPL dosn3              \ lasting bytes again (the command may have changed
 PHX                    \ them: *DIR, *DRIVE), then put HAZEL back from
 PHY                    \ buffer 0
 LDX #63
.dosn2
 LDA &C2C0,X
 STA DFSST,X
 LDA &DFC0,X
 STA DFSST+64,X
 DEX
 BPL dosn2
 LDX #&40
 LDY #&C0
 JSR dosmv
 STZ DFSIN
 PLY
 PLX
.dosn3

 PLA
 PLP
 RTS

.dosmv                  \ Copy the 32 pages (8K) from page X on to page Y on,
 LDA #4                 \ with ACCCON X = 0 (buffer 0 is main RAM)
 TRB VIA+&34
 STX dosm1+2
 STY dosm2+2
 LDY #32
 LDX #0
.dosm1
 LDA &C000,X            \ (patched)
.dosm2
 STA &4000,X            \ (patched)
 INX
 BNE dosm1
 INC dosm1+2
 INC dosm2+2
 DEY
 BNE dosm1
 RTS

\ ******************************************************************************
\
\       Name: HANGER
\       Type: Subroutine
\   Category: Ship hangar
\    Summary: Display the ship hangar
\             (Port: in the cold area, called through the stub HANGER)
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

.HANGER_C

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

 TYA                    \ Port (in the cold area, away from bank 4's ylookup):
 LSR A                  \ A = ylookup(Y) = &40 + (Y DIV 8) * 2, the page number
 LSR A                  \ of the character row that contains the pixel with
 AND #%11111110         \ the y-coordinate in Y (at most &3E before the ORA)
 ORA #&40               \
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

.Ze_C

 JSR x4_ZINF               \ Call ZINF to reset the INWK ship workspace

 JSR x4_DORND              \ Set A and X to random numbers

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
                        \ randomly (Port: DORND2 is CLC then DORND, in main
                        \ RAM, so do the CLC here and jump to DORND)

 CLC
 JMP x4_DORND

\ ******************************************************************************
\
\       Name: FRS1
\       Type: Subroutine
\   Category: Tactics
\    Summary: Launch a ship straight ahead of us, below the laser sights
\
\ ------------------------------------------------------------------------------
\
\ This is used in three places:
\
\   * When we launch a missile, in which case the missile is the ship that is
\     launched ahead of us
\
\   * When we launch our escape pod, in which case it's our abandoned Cobra Mk
\     III that is launched ahead of us
\
\   * The fq1 entry point is used to launch a bunch of cargo canisters ahead of
\     us as part of the death screen
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The type of ship to launch ahead of us
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   C flag              Set if the ship was successfully launched, clear if it
\                       wasn't (as there wasn't enough free memory)
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   fq1                 Used to add a cargo canister to the universe
\
\ ******************************************************************************

.FRS1_C

 JSR x4_ZINF               \ Call ZINF to reset the INWK ship workspace

 LDA #28                \ Set y_lo = 28
 STA INWK+3

 LSR A                  \ Set z_lo = 14, so the launched ship starts out
 STA INWK+6             \ ahead of us

 LDA #%10000000         \ Set y_sign to be negative, so the launched ship is
 STA INWK+5             \ launched just below our line of sight

 LDA MSTG               \ Set A to the missile lock target, shifted left so the
 ASL A                  \ slot number is in bits 1-5

 ORA #%10000000         \ Set bit 7 and store the result in byte #32, the AI
 STA INWK+32            \ flag launched ship for the launched ship. For missiles
                        \ this enables AI (bit 7), makes it friendly towards us
                        \ (bit 6), sets the target to the value of MSTG (bits
                        \ 1-5), and sets its lock status as launched (bit 0).
                        \ It doesn't matter what it does for our abandoned
                        \ Cobra, as the AI flag gets overwritten once we return
                        \ from the subroutine back to the ESCAPE routine that
                        \ called FRS1 in the first place

.fq1_C

 LDA #&60               \ Set byte #14 (nosev_z_hi) to 1 (&60), so the launched
 STA INWK+14            \ ship is pointing away from us

 ORA #128               \ Set byte #22 (sidev_x_hi) to -1 (&D0), so the launched
 STA INWK+22            \ ship has the same orientation as spawned ships, just
                        \ pointing away from us (if we set sidev to +1 instead,
                        \ this ship would be a mirror image of all the other
                        \ ships, which are spawned with -1 in nosev and +1 in
                        \ sidev)

 LDA DELTA              \ Set byte #27 (speed) to 2 * DELTA, so the launched
 ROL A                  \ ship flies off at twice our speed
 STA INWK+27

 TXA                    \ Add a new ship of type X to our local bubble of
 JMP x4_NWSHP              \ universe and return from the subroutine using a tail
                        \ call

\ ******************************************************************************
\
\       Name: FRMIS
\       Type: Subroutine
\   Category: Tactics
\    Summary: Fire a missile from our ship
\
\ ------------------------------------------------------------------------------
\
\ We fired a missile, so send it streaking away from us to unleash mayhem and
\ destruction on our sworn enemies.
\
\ ******************************************************************************

.FRMIS_C

 LDX #MSL               \ Call FRS1 to launch a missile straight ahead of us
 JSR FRS1_C

 BCC FR1_C                \ If FRS1 returns with the C flag clear, then there
                        \ isn't room in the universe for our missile, so jump
                        \ down to FR1 to display a "missile jammed" message

 LDX MSTG               \ Fetch the slot number of the missile's target

 JSR x4_GINF               \ Get the address of the data block for the target ship
                        \ and store it in INF

 LDA FRIN,X             \ Fetch the ship type of the missile's target into A

 JSR ANGRY_C              \ Call ANGRY to make the target ship or station hostile,
                        \ and if this is a ship, wake up its AI and give it a
                        \ kick of speed

 LDY #0                 \ We have just launched a missile, so we need to remove
 JSR x4_ABORT              \ missile lock and hide the leftmost indicator on the
                        \ dashboard by setting it to black (Y = 0)

 DEC NOMSL              \ Reduce the number of missiles we have by 1

 LDY #solaun            \ Call the NOISE routine with Y = 8 to make the sound
 JSR x4_NOISE              \ of a missile launch

 JMP ANGRY_C            \ (Port: FRMIS fell through into ANGRY, now in ANDY)

                        \ Fall through into ANGRY to make the missile target
                        \ angry, though as we already did this above, I'm not
                        \ entirely sure why we do this again

\ ******************************************************************************
\
\       Name: FR1
\       Type: Subroutine
\   Category: Tactics
\    Summary: Display the "missile jammed" message
\
\ ------------------------------------------------------------------------------
\
\ This is shown if there isn't room in the local bubble of universe for a new
\ missile.
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   FR1-2               Clear the C flag and return from the subroutine
\
\ ******************************************************************************

.FR1_C

 LDA #201               \ Print recursive token 41 ("MISSILE JAMMED") as an
 JMP MESS_C               \ in-flight message and return from the subroutine using
                        \ a tail call

                        \ Port: ZEKTRAN is in the main code (elite-source.asm)
