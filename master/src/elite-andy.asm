\ ******************************************************************************
\
\ elite-andy.asm - cold code in ANDY (&8000-&8FFF)
\
\ Port (docs/MASTER-MAP.md, master/src/elite-far.asm): the first part of the
\ cold area, paged in as ROMSEL = &87 (ANDY over bank 7's &8000-&8FFF). Labels
\ have the suffix _C; code outside the cold area calls them through the stubs
\ in elite-stubs7.asm, and they call out through elite-coldstubs.asm.
\ ******************************************************************************

\ ******************************************************************************
\
\       Name: tnpr1
\       Type: Subroutine
\   Category: Market
\    Summary: Work out if we have space for one tonne of cargo
\
\ ------------------------------------------------------------------------------
\
\ Given a market item, work out whether there is room in the cargo hold for one
\ tonne of this item.
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
\   A                   The type of market item (see QQ23 for a list of market
\                       item numbers)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   A = 1
\
\   C flag              Returns the result:
\
\                         * Set if there is no room for this item
\
\                         * Clear if there is room for this item
\
\ ******************************************************************************

.tnpr1_C

 STA QQ29               \ Store the type of market item in QQ29

 LDA #1                 \ Set the number of units of this market item to 1

                        \ Fall through into tnpr to work out whether there is
                        \ room in the cargo hold for A tonnes of the item of
                        \ type QQ29

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

.tnpr_C

 PHA                    \ Store A on the stack

 LDX #12                \ If QQ29 > 12 then jump to kg below, as this cargo
 CPX QQ29               \ type is gold, platinum, gem-stones or alien items,
 BCC kg_C                 \ and they have different cargo limits to the standard
                        \ tonne canisters

.Tml_C

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

 BPL Tml_C                \ Loop back to add in the next market item in the hold,
                        \ until we have added up all market items from 12
                        \ (minerals) down to 0 (food)

 ADC TRIBBLE+1          \ Add the high byte of the number of Trumbles in the
                        \ hold, as 256 Trumbles take up one tonne of cargo space

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

.kg_C

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

\ ******************************************************************************
\
\       Name: TT219
\       Type: Subroutine
\   Category: Market
\    Summary: Show the Buy Cargo screen (red key f1)
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

.TT219_C

 LDA #2                 \ Clear the top part of the screen, draw a border box,
 JSR x4_TRADEMODE          \ and set up a trading screen with a view type in QQ11
                        \ of 2 (Buy Cargo screen)

 JSR TT163_C              \ Print the column headers for the prices table

 LDA #%10000000         \ Set bit 7 of QQ17 to switch to Sentence Case, with the
 STA QQ17               \ next letter in capitals

 LDA #0                 \ We're going to loop through all the available market
 STA QQ29               \ items, so we set up a counter in QQ29 to denote the
                        \ current item and start it at 0

.TT220_C

 JSR TT151_C              \ Call TT151 to print the item name, market price and
                        \ availability of the current item, and set QQ24 to the
                        \ item's price / 4, QQ25 to the quantity available and
                        \ QQ19+1 to byte #1 from the market prices table for
                        \ this item

 LDA QQ25               \ If there are some of the current item available, jump
 BNE TT224_C              \ to TT224 below to see if we want to buy any

 JMP TT222_C              \ Otherwise there are none available, so jump down to
                        \ TT222 to skip this item

.TQ4_C

 LDY #176               \ Set Y to the recursive token 16 ("QUANTITY")

.Tc_C

 JSR TT162_C              \ Print a space

 TYA                    \ Print the recursive token in Y followed by a question
 JSR x4_prq                \ mark

.TTX224_C

 JSR dn2_C                \ Call dn2 to make a short, high beep and delay for 1
                        \ second

.TT224_C

 JSR x4_CLYNS              \ Clear the bottom three text rows of the upper screen,
                        \ and move the text cursor to the first cleared row

 LDA #204               \ Print recursive token 44 ("QUANTITY OF ")
 JSR TT27_C

 LDA QQ29               \ Print recursive token 48 + QQ29, which will be in the
 CLC                    \ range 48 ("FOOD") to 64 ("ALIEN ITEMS"), so this
 ADC #208               \ prints the current item's name
 JSR TT27_C

 LDA #'/'               \ Print "/"
 JSR TT27_C

 JSR TT152_C              \ Print the unit ("t", "kg" or "g") for the current item
                        \ (as the call to TT151 above set QQ19+1 with the
                        \ appropriate value)

 LDA #'?'               \ Print "?"
 JSR TT27_C

 JSR x4_TT67               \ Print a newline

 LDX #0                 \ These instructions have no effect, as they are
 STX R                  \ repeated at the start of gnum, which we call next.
 LDX #12                \ Perhaps they were left behind when code was moved from
 STX T1                 \ here into gnum, and weren't deleted?

.TT223K_C                 \ This label is a duplicate of a label in the gnum
                        \ routine, so this could also be a remnant from code
                        \ that got moved into the gnum subroutine
                        \
                        \ In the original source this label is TT223, but
                        \ because BeebAsm doesn't allow us to redefine labels,
                        \ I have renamed it to TT223K

 JSR gnum_C               \ Call gnum to get a number from the keyboard, which
                        \ will be the quantity of this item we want to purchase,
                        \ returning the number entered in A and R

 BCS TQ4_C                \ If gnum set the C flag, the number entered is greater
                        \ than the quantity available, so jump up to TQ4 to
                        \ display a "Quantity?" error, beep, clear the number
                        \ and try again

 STA P                  \ Otherwise we have a valid purchase quantity entered,
                        \ so store the amount we want to purchase in P

 JSR tnpr_C               \ Call tnpr to work out whether there is room in the
                        \ cargo hold for this item

 LDY #206               \ Set Y to recursive token 46 (" CARGO{sentence case}")
                        \ to pass to the Tc routine if we call it

 LDA R                  \ If R = 0, then we didn't enter a number above, so skip
 BEQ P%+4               \ the following instruction

 BCS Tc_C                 \ If the C flag is set, then there is no room in the
                        \ cargo hold, jump up to Tc to print a "Cargo?" error,
                        \ beep, clear the number and try again

 LDA QQ24               \ There is room in the cargo hold, so now to check
 STA Q                  \ whether we have enough cash, so fetch the item's
                        \ price / 4, which was returned in QQ24 by the call
                        \ to TT151 above and store it in Q

 JSR GCASH_C              \ Call GCASH to calculate:
                        \
                        \   (Y X) = P * Q * 4
                        \
                        \ which will be the total price of this transaction
                        \ (as P contains the purchase quantity and Q contains
                        \ the item's price / 4)

 JSR LCASH_C              \ Subtract (Y X) cash from the cash pot in CASH

 LDY #197               \ If the C flag is clear, we didn't have enough cash,
 BCC Tc_C                 \ so set Y to the recursive token 37 ("CASH") and jump
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

 BEQ TT222_C              \ If we didn't buy anything, jump to TT222 to skip the
                        \ following instruction

 JSR dn_C                 \ Call dn to print the amount of cash left in the cash
                        \ pot, then make a short, high beep to confirm the
                        \ purchase, and delay for 1 second

.TT222_C

 LDA QQ29               \ Move the text cursor to row QQ29 + 5 (where QQ29 is
 CLC                    \ the item number, starting from 0)
 ADC #5
 JSR x4_DOYC

 LDA #0                 \ Move the text cursor to column 0
 JSR x4_DOXC

 INC QQ29               \ Increment QQ29 to point to the next item

 LDA QQ29               \ If QQ29 >= 17 then jump to BAY2 as we have done the
 CMP #17                \ last item
 BCS BAY2_C

 JMP TT220_C              \ Otherwise loop back to TT220 to print the next market
                        \ item

.BAY2_C

\LDA #&10               \ These instructions are commented out in the original
\STA COL2               \ source

 LDA #f9                \ Jump into the main loop at FRCE, setting the key
 JMP j4_FRCE               \ "pressed" to red key f9 (so we show the Inventory
                        \ screen)

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
\ Pressing "Y" will return the maximum number (i.e. buy/sell all items), while
\ pressing "N" will abort the sale and return a 0.
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
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   OUT                 The OUTK routine jumps back here after printing the key
\                       that was just pressed
\
\ ******************************************************************************

.gnum_C

 LDA #MAGENTA           \ Switch to colour 2, which is magenta in the trade view
 STA COL

 LDX #0                 \ We will build the number entered in R, so initialise
 STX R                  \ it with 0

 LDX #12                \ We will check for up to 12 key presses, so set a
 STX T1                 \ counter in T1

.TT223_C

 JSR x4_TT217              \ Scan the keyboard until a key is pressed, and return
                        \ the key's ASCII code in A (and X)

 LDX R                  \ If R is non-zero then skip to NWDAV2, as we are
 BNE NWDAV2_C             \ already building a number

 CMP #'Y'               \ If "Y" was pressed, jump to NWDAV1 to return the
 BEQ NWDAV1_C             \ maximum number allowed (i.e. buy/sell the whole stock)

 CMP #'N'               \ If "N" was pressed, jump to NWDAV3 to return from the
 BEQ NWDAV3_C             \ subroutine with a result of 0 (i.e. abort transaction)

.NWDAV2_C

 STA Q                  \ Store the key pressed in Q

 SEC                    \ Subtract ASCII "0" from the key pressed, to leave the
 SBC #'0'               \ numeric value of the key in A (if it was a number key)

 BCC OUT_C                \ If A < 0, jump to OUT to load the current number and
                        \ return from the subroutine, as the key pressed was
                        \ RETURN (or some other character with a value less than
                        \ ASCII "0")

 CMP #10                \ If A >= 10, jump to BAY2 to display the Inventory
 BCS BAY2_C               \ screen, as the key pressed was a letter or other
                        \ non-digit and is greater than ASCII "9"

 STA S                  \ Store the numeric value of the key pressed in S

 LDA R                  \ Fetch the result so far into A

\BEQ P%+4               \ This instruction is commented out in the original
                        \ source, and has a comment "tribs"

 CMP #26                \ If A >= 26, where A is the number entered so far, then
 BCS OUTK_C               \ adding a further digit will make it bigger than 256,
                        \ so jump to OUTK to print the key that was just pressed
                        \ before jumping to OUT below with the C flag still set

 ASL A                  \ Set A = (A * 2) + (A * 8) = A * 10
 STA T
 ASL A
 ASL A
 ADC T

 ADC S                  \ Add the pressed digit to A

 BCS OUTK_C               \ If the addition overflowed, then jump to OUTK to print
                        \ the key that was just pressed before jumping to OUT
                        \ below with the C flag still set

 STA R                  \ Otherwise store the result in R, so R now contains
                        \ its previous value with the new key press tacked onto
                        \ the end

 CMP QQ25               \ If the result in R = the maximum allowed in QQ25, jump
 BEQ TT226_C              \ to TT226 to print the key press and keep looping (the
                        \ BEQ is needed because the BCS below would jump to OUT
                        \ if R >= QQ25, which we don't want)

 BCS OUTK_C               \ If the result in R > QQ25, jump to OUTK to print
                        \ the key that was just pressed before jumping to OUT
                        \ below with the C flag still set

.TT226_C

 LDA Q                  \ Print the character in Q (i.e. the key that was
 JSR x4_TT26               \ pressed, as we stored the ASCII value in Q earlier)

 DEC T1                 \ Decrement the loop counter

 BNE TT223_C              \ Loop back to TT223 until we have checked for 12 digits

.OUT_C

 LDA #CYAN              \ Switch to colour 3, which is white in the trade view
 STA COL

 LDA R                  \ Set A to the result we have been building in R

 RTS                    \ Return from the subroutine

.NWDAV1_C

                        \ If we get here then "Y" was pressed, so we return the
                        \ maximum number allowed, which is in QQ25

 JSR x4_TT26               \ Print the character for the key that was pressed

 LDA QQ25               \ Set R = QQ25, so we return the maximum value allowed
 STA R

 JMP OUT_C                \ Jump to OUT to return from the subroutine

.NWDAV3_C

                        \ If we get here then "N" was pressed, so we return 0

 JSR x4_TT26               \ Print the character for the key that was pressed

 STZ R                  \ Set R = 0, so we return 0

 JMP OUT_C                \ Jump to OUT to return from the subroutine

\ ******************************************************************************
\
\       Name: NWDAV4
\       Type: Subroutine
\   Category: Market
\    Summary: Print an "ITEM?" error, make a beep and rejoin the TT210 routine
\
\ ******************************************************************************

.NWDAV4_C

 JSR x4_TT67               \ Print a newline

 LDA #176               \ Print recursive token 127 ("ITEM") followed by a
 JSR x4_prq                \ question mark

 JSR dn2_C                \ Call dn2 to make a short, high beep and delay for 1
                        \ second

 LDY QQ29               \ Fetch the item number we are selling from QQ29

 JMP NWDAVxx_C            \ Jump back into the TT210 routine that called NWDAV4

\ ******************************************************************************
\
\       Name: OUTK
\       Type: Subroutine
\   Category: Text
\    Summary: Print the character in Q before returning to gnum
\
\ ******************************************************************************

.OUTK_C

 LDA Q                  \ Print the character in Q, which is the key that was
 JSR x4_DASC               \ just pressed in the gnum routine

 SEC                    \ Set the C flag, as this routine is only called if the
                        \ key pressed makes the number too high

 JMP OUT_C                \ Jump back into the gnum routine to return the number
                        \ that has been built

\ ******************************************************************************
\
\       Name: TT208
\       Type: Subroutine
\   Category: Market
\    Summary: Show the Sell Cargo screen (red key f2)
\
\ ******************************************************************************

.TT208_C

 LDA #4                 \ Clear the top part of the screen, draw a border box,
 JSR x4_TRADEMODE          \ and set up a trading screen with a view type in QQ11
                        \ of 4 (Sell Cargo screen)

 LDA #10                \ Move the text cursor to column 10
 STA XC

 LDA #205               \ Print recursive token 45 ("SELL")
 JSR TT27_C

 LDA #206               \ Print recursive token 46 (" CARGO{sentence case}")
 JSR x4_NLIN3              \ draw a horizontal line at pixel row 19 to box in the
                        \ title

 JSR x4_TT67               \ Print a newline

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
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   NWDAVxx             Used to rejoin this routine from the call to NWDAV4
\
\ ******************************************************************************

.TT210_C

 LDY #0                 \ We're going to loop through all the available market
                        \ items and check whether we have any in the hold (and,
                        \ if we are in the Sell Cargo screen, whether we want
                        \ to sell any items), so we set up a counter in Y to
                        \ denote the current item and start it at 0

.TT211_C

 STY QQ29               \ Store the current item number in QQ29

.NWDAVxx_C

 LDX QQ20,Y             \ Fetch into X the amount of the current item that we
 BEQ TT212_C              \ have in our cargo hold, which is stored in QQ20+Y,
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

 JSR x4_TT69               \ Call TT69 to set Sentence Case and print a newline

 CLC                    \ Print recursive token 48 + QQ29, which will be in the
 LDA QQ29               \ range 48 ("FOOD") to 64 ("ALIEN ITEMS"), so this
 ADC #208               \ prints the current item's name
 JSR TT27_C

 LDA #14                \ Move the text cursor to column 14, for the item's
 JSR x4_DOXC               \ quantity

 PLA                    \ Restore the amount of item in the hold into X
 TAX

 STA QQ25               \ Store the amount of this item in the hold in QQ25

 CLC                    \ Print the 8-bit number in X to 3 digits, without a
 JSR x4_pr2                \ decimal point

 JSR TT152_C              \ Print the unit ("t", "kg" or "g") for the market item
                        \ whose byte #1 from the market prices table is in
                        \ QQ19+1 (which we set up above)

 LDA QQ11               \ If the current view type in QQ11 is not 4 (Sell Cargo
 CMP #4                 \ screen), jump to TT212 to skip the option to sell
 BNE TT212_C              \ items

\JSR TT162              \ This instruction is commented out in the original
                        \ source

 LDA #205               \ Print recursive token 45 ("SELL")
 JSR TT27_C

 LDA #206               \ Print extended token 206 ("{all caps}(Y/N)?")
 JSR DETOK_C

 JSR gnum_C               \ Call gnum to get a number from the keyboard, which
                        \ will be the number of the item we want to sell,
                        \ returning the number entered in A and R, and setting
                        \ the C flag if the number is bigger than the available
                        \ amount of this item in QQ25

 BEQ TT212_C              \ If no number was entered, jump to TT212 to move on to
                        \ the next item

 BCS NWDAV4_C             \ If the number entered was too big, jump to NWDAV4 to
                        \ print an "ITEM?" error, make a beep and rejoin the
                        \ routine at NWDAVxx above

 LDA QQ29               \ We are selling this item, so fetch the item number
                        \ from QQ29

 LDX #255               \ Set QQ17 = 255 to disable printing
 STX QQ17

 JSR TT151_C              \ Call TT151 to set QQ24 to the item's price / 4 (the
                        \ routine doesn't print the item details, as we just
                        \ disabled printing)

 LDY QQ29               \ Subtract R (the number of items we just asked to buy)
 LDA QQ20,Y             \ from the available amount of this item in QQ20, as we
 SEC                    \ just bought them
 SBC R
 STA QQ20,Y

 LDA R                  \ Set P to the amount of this item we just bought
 STA P

 LDA QQ24               \ Set Q to the item's price / 4
 STA Q

 JSR GCASH_C              \ Call GCASH to calculate
                        \
                        \   (Y X) = P * Q * 4
                        \
                        \ which will be the total price we make from this sale
                        \ (as P contains the quantity we're selling and Q
                        \ contains the item's price / 4)

 JSR MCASH_C              \ Add (Y X) cash to the cash pot in CASH

 LDA #0                 \ We've made the sale, so set the amount

 STA QQ17               \ Set QQ17 = 0, which enables printing again

.TT212_C

 LDY QQ29               \ Fetch the item number from QQ29 into Y, and increment
 INY                    \ Y to point to the next item

 CPY #17                \ Loop back to TT211 to print the next item in the hold
 BCC TT211_C              \ until Y = 17 (at which point we have done the last
                        \ item)

 LDA QQ11               \ If the current view type in QQ11 is not 4 (Sell Cargo
 CMP #4                 \ screen), skip the next two instructions and move on to
 BNE P%+8               \ printing the number of Trumbles

 JSR dn2_C                \ This is the Sell Cargo screen, so call dn2 to make a
                        \ short, high beep and delay for 1 second

 JMP BAY2_C               \ And then jump to BAY2 to display the Inventory
                        \ screen, as we have finished selling cargo

 JSR x4_TT69               \ Call TT69 to set Sentence Case and print a newline

 LDA TRIBBLE            \ If there are any Trumbles in the hold, skip the
 ORA TRIBBLE+1          \ following RTS and continue on (in the Master version,
 BNE P%+3               \ there are never any Trumbles, so this value will
                        \ always be zero)

.zebra_C

 RTS                    \ There are no Trumbles in the hold, so return from the
                        \ subroutine

                        \ If we get here then we have Trumbles in the hold, so
                        \ we print out the number (though we never get here in
                        \ the Master version)

 CLC                    \ Clear the C flag, so the call to TT11 below doesn't
                        \ include a decimal point

 LDA #0                 \ Set A = 0, for the call to TT11 below, so we don't pad
                        \ out the number of Trumbles

 LDX TRIBBLE            \ Fetch the number of Trumbles into (Y X)
 LDY TRIBBLE+1

 JSR x4_TT11               \ Call TT11 to print the number of Trumbles in (Y X),
                        \ with no decimal point

 JSR x4_DORND              \ Print out a random extended token from 111 to 114, all
 AND #3                 \ of which are blank in this version of Elite
 CLC
 ADC #111
 JSR DETOK_C

 LDA #198               \ Print extended token 198, which is blank, but would
 JSR DETOK_C              \ contain the text "LITTLE TRUMBLE" if the Trumbles
                        \ mission was enabled

 LDA TRIBBLE+1          \ If we have more than 256 Trumbles, skip to DOANS
 BNE DOANS_C

 LDX TRIBBLE            \ If we have exactly one Trumble, return from the
 DEX                    \ subroutine (as zebra contains an RTS)
 BEQ zebra_C

.DOANS_C

 LDA #'s'               \ We have more than one Trumble, so print an 's' and
 JMP x4_DASC               \ return from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: TT213
\       Type: Subroutine
\   Category: Market
\    Summary: Show the Inventory screen (red key f9)
\
\ ******************************************************************************

.TT213_C

 LDA #8                 \ Clear the top part of the screen, draw a border box,
 JSR x4_TRADEMODE          \ and set up a trading screen with a view type in QQ11
                        \ of 4 (Inventory screen)

 LDA #11                \ Move the text cursor to column 11 to print the screen
 STA XC                 \ title

 LDA #164               \ Print recursive token 4 ("INVENTORY{crlf}") followed
 JSR x4_TT60               \ by a paragraph break and Sentence Case

 JSR x4_NLIN4              \ Draw a horizontal line at pixel row 19 to box in the
                        \ title. The authors could have used a call to NLIN3
                        \ instead and saved the above call to TT60, but you
                        \ just can't optimise everything

 JSR fwl_C                \ Call fwl to print the fuel and cash levels on two
                        \ separate lines

 LDA CRGO               \ If our ship's cargo capacity is < 26 (i.e. we do not
 CMP #26                \ have a cargo bay extension), skip the following two
 BCC P%+7               \ instructions

 LDA #107               \ We do have a cargo bay extension, so print recursive
 JSR TT27_C               \ token 107 ("LARGE CARGO{sentence case} BAY")

 JMP TT210_C              \ Jump to TT210 to print the contents of our cargo bay
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

.TT214_C

\.TT214                 \ These instructions are commented out in the original
\                       \ source
\PHA
\JSR TT162
\PLA

.TT221_C

 JSR TT27_C               \ Print the text token in A

 LDA #206               \ Print extended token 206 ("{all caps}(Y/N)?")
 JSR DETOK_C

 JSR x4_TT217              \ Scan the keyboard until a key is pressed, and return
                        \ the key's ASCII code in A and X

 ORA #%00100000         \ Set bit 5 in the value of the key pressed, which
                        \ converts it to lower case

 CMP #'y'               \ If "y" was pressed, jump to TT218
 BEQ TT218_C

 LDA #'n'               \ Otherwise jump to TT26 to print "n" and return from
 JMP x4_TT26               \ the subroutine using a tail call (so all other
                        \ responses apart from "y" indicate a no)

.TT218_C

 JSR x4_TT26               \ Print the character in A, i.e. print "y"

 SEC                    \ Set the C flag to indicate a "yes" response

 RTS                    \ Return from the subroutine

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

.TT151q_C

                        \ We jump here from below if we are in witchspace

 PLA                    \ Restore the item number from the stack

 RTS                    \ Return from the subroutine

.TT151_C

 PHA                    \ Store the item number on the stack and in QQ19+4
 STA QQ19+4

 ASL A                  \ Store the item number * 4 in QQ19, so this will act as
 ASL A                  \ an index into the market prices table at QQ23 for this
 STA QQ19               \ item (as there are four bytes per item in the table)

 LDA MJ                 \ If we are in witchspace, we can't trade items, so jump
 BNE TT151q_C             \ up to TT151q to return from the subroutine

 LDA #1                 \ Move the text cursor to column 1, for the item's name
 JSR x4_DOXC

 PLA                    \ Restore the item number

 ADC #208               \ Print recursive token 48 + A, which will be in the
 JSR TT27_C               \ range 48 ("FOOD") to 64 ("ALIEN ITEMS"), so this
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

 JSR TT152_C              \ Call TT152 to print the item's unit ("t", "kg" or
                        \ "g"), padded to a width of two characters

 JSR var_C                \ Call var to set QQ19+3 = economy * |economic_factor|
                        \ (and set the availability of alien items to 0)

 LDA QQ19+1             \ Fetch the byte #1 that we stored above and jump to
 BMI TT155_C              \ TT155 if it is negative (i.e. if the economic_factor
                        \ is negative)

 LDA QQ24               \ Set A = QQ24 + QQ19+3
 ADC QQ19+3             \
                        \       = base_price + (random AND mask)
                        \         + (economy * |economic_factor|)
                        \
                        \ which is the result we want, as the economic_factor
                        \ is positive

 JMP TT156_C              \ Jump to TT156 to multiply the result by 4

.TT155_C

 LDA QQ24               \ Set A = QQ24 - QQ19+3
 SEC                    \
 SBC QQ19+3             \       = base_price + (random AND mask)
                        \         - (economy * |economic_factor|)
                        \
                        \ which is the result we want, as economic_factor
                        \ is negative

.TT156_C

 STA QQ24               \ Store the result in QQ24 and P
 STA P

 LDA #0                 \ Set A = 0 and call GC2 to calculate (Y X) = (A P) * 4,
 JSR GC2_C                \ which is the same as (Y X) = P * 4 because A = 0

 SEC                    \ We now have our final price, * 10, so we can call pr5
 JSR x4_pr5                \ to print (Y X) to 5 digits, including a decimal
                        \ point, as the C flag is set

 LDY QQ19+4             \ We now move on to availability, so fetch the market
                        \ item number that we stored in QQ19+4 at the start

 LDA #5                 \ Set A to 5 so we can print the availability to 5
                        \ digits (right-padded with spaces)

 LDX AVL,Y              \ Set X to the item's availability, which is given in
                        \ the AVL table

 STX QQ25               \ Store the availability in QQ25

 CLC                    \ Clear the C flag

 BEQ TT172_C              \ If none are available, jump to TT172 to print a tab
                        \ and a "-"

 JSR x4_pr2_p2              \ Otherwise print the 8-bit number in X to 5 digits,
                        \ right-aligned with spaces. This works because we set
                        \ A to 5 above, and we jump into the pr2 routine just
                        \ after the first instruction, which would normally
                        \ set the number of digits to 3

 JMP TT152_C              \ Print the unit ("t", "kg" or "g") for the market item,
                        \ with a following space if required to make it two
                        \ characters long, and return from the subroutine using
                        \ a tail call

.TT172_C

 LDA #25                \ Move the text cursor to column 25
 JSR x4_DOXC

 LDA #'-'               \ Print a "-" character by jumping to TT162+2, which
 BNE TT162_C+2            \ contains JMP TT27 (this BNE is effectively a JMP as A
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

.TT152_C

 LDA QQ19+1             \ Fetch the economic_factor from QQ19+1

 AND #96                \ If bits 5 and 6 are both clear, jump to TT160 to
 BEQ TT160_C              \ print "t" for tonne, followed by a space, and return
                        \ from the subroutine using a tail call

 CMP #32                \ If bit 5 is set, jump to TT161 to print "kg" for
 BEQ TT161_C              \ kilograms, and return from the subroutine using a tail
                        \ call

 JSR TT16a_C              \ Otherwise call TT16a to print "g" for grams, and fall
                        \ through into TT162 to print a space and return from
                        \ the subroutine

\ ******************************************************************************
\
\       Name: TT162
\       Type: Subroutine
\   Category: Text
\    Summary: Print a space
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   TT162+2             Jump to TT27 to print the text token in A
\
\ ******************************************************************************

.TT162_C

 LDA #' '               \ Load a space character into A

 JMP TT27_C               \ Print the text token in A and return from the
                        \ subroutine using a tail call

\ ******************************************************************************
\
\       Name: TT160
\       Type: Subroutine
\   Category: Market
\    Summary: Print "t" (for tonne) and a space
\
\ ******************************************************************************

.TT160_C

 LDA #'t'               \ Load a "t" character into A

 JSR x4_TT26               \ Print the character, using TT216 so that it doesn't
                        \ change the character case

 BCC TT162_C              \ Jump to TT162 to print a space and return from the
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

.TT161_C

 LDA #'k'               \ Load a "k" character into A

 JSR x4_TT26               \ Print the character, using TT216 so that it doesn't
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

.TT16a_C

 LDA #'g'               \ Load a "g" character into A

 JMP x4_TT26               \ Print the character, using TT216 so that it doesn't
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

.TT163_C

 LDA #17                \ Move the text cursor in XC to column 17
 JSR x4_DOXC

 LDA #255               \ Print recursive token 95 token ("UNIT  QUANTITY
 BNE TT162_C+2            \ {crlf} PRODUCT   UNIT PRICE FOR SALE{crlf}{lf}") by
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

.TT167_C

 LDA #16                \ Clear the top part of the screen, draw a border box,
 JSR x4_TRADEMODE          \ and set up a trading screen with a view type in QQ11
                        \ of 32 (Market Price screen)

 LDA #5                 \ Move the text cursor to column 5
 STA XC

 LDA #167               \ Print recursive token 7 ("{current system name} MARKET
 JSR x4_NLIN3              \ PRICES") and draw a horizontal line at pixel row 19
                        \ to box in the title

 LDA #3                 \ Move the text cursor to row 3
 STA YC

 JSR TT163_C              \ Print the column headers for the prices table

 LDA #6                 \ Move the text cursor to row 6
 STA YC

 LDA #0                 \ We're going to loop through all the available market
 STA QQ29               \ items, so we set up a counter in QQ29 to denote the
                        \ current item and start it at 0

.TT168_C

 LDX #%10000000         \ Set bit 7 of QQ17 to switch to Sentence Case, with the
 STX QQ17               \ next letter in capitals

 JSR TT151_C              \ Call TT151 to print the item name, market price and
                        \ availability of the current item, and set QQ24 to the
                        \ item's price / 4, QQ25 to the quantity available and
                        \ QQ19+1 to byte #1 from the market prices table for
                        \ this item

 INC YC                 \ Move the text cursor down one row

 INC QQ29               \ Increment QQ29 to point to the next item

 LDA QQ29               \ If QQ29 >= 17 then jump to TT168 as we have done the
 CMP #17                \ last item
 BCC TT168_C

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: var
\       Type: Subroutine
\   Category: Market
\    Summary: Calculate QQ19+3 = economy * |economic_factor|
\
\ ------------------------------------------------------------------------------
\
\ Set QQ19+3 = economy * |economic_factor|, given byte #1 of the market prices
\ table for an item. Also sets the availability of alien items to 0.
\
\ This routine forms part of the calculations for market item prices (TT151)
\ and availability (GVL).
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   QQ19+1              Byte #1 of the market prices table for this market item
\                       (which contains the economic_factor in bits 0-5, and the
\                       sign of the economic_factor in bit 7)
\
\ ******************************************************************************

.var_C

 LDA QQ19+1             \ Extract bits 0-5 from QQ19+1 into A, to get the
 AND #31                \ economic_factor without its sign, in other words:
                        \
                        \   A = |economic_factor|

 LDY QQ28               \ Set Y to the economy byte of the current system

 STA QQ19+2             \ Store A in QQ19+2

 CLC                    \ Clear the C flag so we can do additions below

 LDA #0                 \ Set AVL+16 (availability of alien items) to 0,
 STA AVL+16             \ setting A to 0 in the process

.TT153_C

                        \ We now do the multiplication by doing a series of
                        \ additions in a loop, building the result in A. Each
                        \ loop adds QQ19+2 (|economic_factor|) to A, and it
                        \ loops the number of times given by the economy byte;
                        \ in other words, because A starts at 0, this sets:
                        \
                        \   A = economy * |economic_factor|

 DEY                    \ Decrement the economy in Y, exiting the loop when it
 BMI TT154_C              \ becomes negative

 ADC QQ19+2             \ Add QQ19+2 to A

 JMP TT153_C              \ Loop back to TT153 to do another addition

.TT154_C

 STA QQ19+3             \ Store the result in QQ19+3

 RTS                    \ Return from the subroutine

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

.LCASH_C

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

 BCS TT113_C              \ If the C flag is set then the subtraction didn't
                        \ underflow, so the value in CASH is correct and we can
                        \ jump to TT113 to return from the subroutine with the
                        \ C flag set to indicate success (as TT113 contains an
                        \ RTS)

                        \ Otherwise we didn't have enough cash in CASH to
                        \ subtract (Y X) from it, so fall through into
                        \ MCASH to reverse the sum and restore the original
                        \ value in CASH, and returning with the C flag clear

\ ******************************************************************************
\
\       Name: MCASH
\       Type: Subroutine
\   Category: Maths (Arithmetic)
\    Summary: Add an amount of cash to the cash pot
\
\ ------------------------------------------------------------------------------
\
\ Add (Y X) cash to the cash pot in CASH. As CASH is a four-byte number, this
\ calculates:
\
\   CASH(0 1 2 3) = CASH(0 1 2 3) + (Y X)
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   TT113               Contains an RTS
\
\ ******************************************************************************

.MCASH_C

 TXA                    \ Add the least significant bytes:
 CLC                    \
 ADC CASH+3             \   CASH+3 = CASH+3 + X
 STA CASH+3

 TYA                    \ Then the second most significant bytes:
 ADC CASH+2             \
 STA CASH+2             \   CASH+2 = CASH+2 + Y

 LDA CASH+1             \ Then the third most significant bytes (which are 0):
 ADC #0                 \
 STA CASH+1             \   CASH+1 = CASH+1 + 0

 LDA CASH               \ And finally the most significant bytes (which are 0):
 ADC #0                 \
 STA CASH               \   CASH = CASH + 0

 CLC                    \ Clear the C flag, so if the above was done following
                        \ a failed LCASH call, the C flag correctly indicates
                        \ failure

.TT113_C

 RTS                    \ Return from the subroutine

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

.GCASH_C

 JSR x4_MULTU              \ Call MULTU to calculate (A P) = P * Q

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

.GC2_C

 ASL P                  \ Set (A P) = (A P) * 4
 ROL A
 ASL P
 ROL A

 TAY                    \ Set (Y X) = (A P)
 LDX P

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: EQSHP
\       Type: Subroutine
\   Category: Equipment
\    Summary: Show the Equip Ship screen (red key f3)
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

.bay_C

 JMP j4_BAY                \ Go to the docking bay (i.e. show the Status Mode
                        \ screen)

.EQSHP_C

 LDA #32                \ Clear the top part of the screen, draw a border box,
 JSR x4_TRADEMODE          \ and set up a printable trading screen with a view type
                        \ in QQ11 of 32 (Equip Ship screen)

 LDA #12                \ Move the text cursor to column 12
 STA XC

 LDA #207               \ Print recursive token 47 ("EQUIP") followed by a space
 JSR x4_spc

 LDA #185               \ Print recursive token 25 ("SHIP") and draw a
 JSR x4_NLIN3              \ horizontal line at pixel row 19 to box in the title

 LDA #%10000000         \ Set bit 7 of QQ17 to switch to Sentence Case, with the
 STA QQ17               \ next letter in capitals

 INC YC                 \ Move the text cursor down one line

 LDA tek                \ Fetch the tech level of the current system from tek
 CLC                    \ and add 3 (the tech level is stored as 0-14, so A is
 ADC #3                 \ now set to between 3 and 17)

 CMP #12                \ If A >= 12 then set A = 14, so A is now set to between
 BCC P%+4               \ 3 and 14
 LDA #14

 STA Q                  \ Set QQ25 = A (so QQ25 is in the range 3-14 and
 STA QQ25               \ represents the number of the most advanced item
 INC Q                  \ available in this system, which we can pass to gnum
                        \ below when asking which item we want to buy)
                        \
                        \ Set Q = A + 1 (so Q is in the range 4-15 and contains
                        \ QQ25 + 1, i.e. the highest item number on sale + 1)

 LDA #70                \ Set A = 70 - QQ14, where QQ14 contains the current
 SEC                    \ fuel in light years * 10, so this leaves the amount
 SBC QQ14               \ of fuel we need to fill 'er up (in light years * 10)

 ASL A                  \ The price of fuel is always 2 Cr per light year, so we
 STA PRXS_C               \ double A and store it in PRXS, as the first price in
                        \ the price list (which is reserved for fuel), and
                        \ because the table contains prices as price * 10, it's
                        \ in the right format (so tank containing 7.0 light
                        \ years of fuel would be 14.0 Cr, or a PRXS value of
                        \ 140)

 LDX #1                 \ We are now going to work our way through the equipment
                        \ price list at PRXS, printing out the equipment that is
                        \ available at this station, so set a counter in X,
                        \ starting at 1, to hold the number of the current item
                        \ plus 1 (so the item number in X loops through 1-13)

.EQL1_C

 STX XX13               \ Store the current item number + 1 in XX13

 JSR x4_TT67               \ Print a newline

 LDX XX13               \ Print the current item number + 1 to 3 digits, left-
 CLC                    \ padding with spaces, and with no decimal point, so the
 JSR x4_pr2                \ items are numbered from 1

 JSR TT162_C              \ Print a space

 LDA XX13               \ Print recursive token 104 + XX13, which will be in the
 CLC                    \ range 105 ("FUEL") to 116 ("GALACTIC HYPERSPACE ")
 ADC #104               \ so this prints the current item's name
 JSR TT27_C

 LDA XX13               \ Call prx-3 to set (Y X) to the price of the item with
 JSR prx_C-3              \ number XX13 - 1 (as XX13 contains the item number + 1)

 SEC                    \ Set the C flag so we will print a decimal point when
                        \ we print the price

 LDA #25                \ Move the text cursor to column 25
 STA XC

 LDA #6                 \ Print the number in (Y X) to 6 digits, left-padding
 JSR x4_TT11               \ with spaces and including a decimal point, which will
                        \ be the correct price for this item as (Y X) contains
                        \ the price * 10, so the trailing zero will go after the
                        \ decimal point (i.e. 5250 will be printed as 525.0)

 LDX XX13               \ Increment the current item number in XX13
 INX

 CPX Q                  \ If X < Q, loop back up to print the next item on the
 BCC EQL1_C               \ list of equipment available at this station

 JSR x4_CLYNS              \ Clear the bottom three text rows of the upper screen,
                        \ and move the text cursor to the first cleared row

 LDA #127               \ Print recursive token 127 ("ITEM") followed by a
 JSR x4_prq                \ question mark

 JSR gnum_C               \ Call gnum to get a number from the keyboard, which
                        \ will be the number of the item we want to purchase,
                        \ returning the number entered in A and R, and setting
                        \ the C flag if the number is bigger than the highest
                        \ item number in QQ25

 BEQ bay_C                \ If no number was entered, jump up to bay to go to the
                        \ docking bay (i.e. show the Status Mode screen)

 BCS bay_C                \ If the number entered was too big, jump up to bay to
                        \ go to the docking bay (i.e. show the Status Mode
                        \ screen)

 SBC #0                 \ Set A to the number entered - 1 (because the C flag is
                        \ clear), which will be the actual item number we want
                        \ to buy

 PHA                    \ Store A on the stack so we can restore it after the
                        \ following call to DOXC

 LDA #2                 \ Move the text cursor to column 2
 STA XC

 INC YC                 \ Move the text cursor down one line

 PLA                    \ Restore A from the stack

 PHA                    \ While preserving the value in A, call eq to subtract
 JSR eq_C                 \ the price of the item we want to buy (which is in A)
 PLA                    \ from our cash pot, but only if we have enough cash in
                        \ the pot. If we don't have enough cash, exit to the
                        \ docking bay (i.e. show the Status Mode screen)

 BNE et0_C                \ If A is not 0 (i.e. the item we've just bought is not
                        \ fuel), skip to et0

 LDX #70                \ Set the current fuel level * 10 in QQ14 to 70, or 7.0
 STX QQ14               \ light years (a full tank)

.et0_C

 CMP #1                 \ If A is not 1 (i.e. the item we've just bought is not
 BNE et1_C                \ a missile), skip to et1

 LDX NOMSL              \ Fetch the current number of missiles from NOMSL into X

 INX                    \ Increment X to the new number of missiles

 LDY #124               \ Set Y to recursive token 124 ("ALL")

 CPX #5                 \ If buying this missile would give us 5 missiles, this
 BCS pres_C               \ is more than the maximum of 4 missiles that we can
                        \ fit, so jump to pres to show the error "All Present",
                        \ beep and exit to the docking bay (i.e. show the Status
                        \ Mode screen)

 STX NOMSL              \ Otherwise update the number of missiles in NOMSL

 JSR x4_msblob             \ Reset the dashboard's missile indicators so none of
                        \ them are targeted

 LDA #1                 \ Set A to 1 as the call to msblob will have overwritten
                        \ the original value, and we still need it set
                        \ correctly so we can continue through the conditional
                        \ statements for all the other equipment

.et1_C

 LDY #107               \ Set Y to recursive token 107 ("LARGE CARGO{sentence
                        \ case} BAY")

 CMP #2                 \ If A is not 2 (i.e. the item we've just bought is not
 BNE et2_C                \ a large cargo bay), skip to et2

 LDX #37                \ If our current cargo capacity in CRGO is 37, then we
 CPX CRGO               \ already have a large cargo bay fitted, so jump to pres
 BEQ pres_C               \ to show the error "Large Cargo Bay Present", beep and
                        \ exit to the docking bay (i.e. show the Status Mode
                        \ screen)

 STX CRGO               \ Otherwise we just scored ourselves a large cargo bay,
                        \ so update our current cargo capacity in CRGO to 37

.et2_C

 CMP #3                 \ If A is not 3 (i.e. the item we've just bought is not
 BNE et3_C                \ an E.C.M. system), skip to et3

 INY                    \ Increment Y to recursive token 108 ("E.C.M.SYSTEM")

 LDX ECM                \ If we already have an E.C.M. fitted (i.e. ECM is
 BNE pres_C               \ non-zero), jump to pres to show the error "E.C.M.
                        \ System Present", beep and exit to the docking bay
                        \ (i.e. show the Status Mode screen)

 DEC ECM                \ Otherwise we just took delivery of a brand new E.C.M.
                        \ system, so set ECM to &FF (as ECM was 0 before the DEC
                        \ instruction)

.et3_C

 CMP #4                 \ If A is not 4 (i.e. the item we've just bought is not
 BNE et4_C                \ an extra pulse laser), skip to et4

 JSR qv_C                 \ Print a menu listing the four views, with a "View ?"
                        \ prompt, and ask for a view number, which is returned
                        \ in X (which now contains 0-3)

 LDA #POW               \ Call refund with A set to the power of the new pulse
 JSR refund_C             \ laser to install the new laser and process a refund if
                        \ we already have a laser fitted to this view

 LDA #4                 \ Set A to 4 as we just overwrote the original value,
                        \ and we still need it set correctly so we can continue
                        \ through the conditional statements for all the other
                        \ equipment

.et4_C

 CMP #5                 \ If A is not 5 (i.e. the item we've just bought is not
 BNE et5_C                \ an extra beam laser), skip to et5

 JSR qv_C                 \ Print a menu listing the four views, with a "View ?"
                        \ prompt, and ask for a view number, which is returned
                        \ in X (which now contains 0-3)

 LDA #POW+128           \ Call refund with A set to the power of the new beam
 JSR refund_C             \ laser to install the new laser and process a refund if
                        \ we already have a laser fitted to this view

.et5_C

 LDY #111               \ Set Y to recursive token 111 ("FUEL SCOOPS")

 CMP #6                 \ If A is not 6 (i.e. the item we've just bought is not
 BNE et6_C                \ a fuel scoop), skip to et6

 LDX BST                \ If we already have fuel scoops fitted (i.e. BST is
 BEQ ed9_C                \ zero), jump to ed9, otherwise fall through into pres
                        \ to show the error "Fuel Scoops Present", beep and
                        \ exit to the docking bay (i.e. show the Status Mode
                        \ screen)

.pres_C

                        \ If we get here we need to show an error to say that
                        \ the item whose name is in recursive token Y is already
                        \ present, and then process a refund for the cost of
                        \ item number A

 STY K                  \ Store the item's name in K

 JSR prx_C                \ Call prx to set (Y X) to the price of equipment item
                        \ number A

 JSR MCASH_C              \ Add (Y X) cash to the cash pot in CASH, as the station
                        \ already took the money for this item in the JSR eq
                        \ instruction above, but we can't fit the item, so need
                        \ our money back

 LDA K                  \ Print the recursive token in K (the item's name)
 JSR x4_spc                \ followed by a space

 LDA #31                \ Print recursive token 145 ("PRESENT")
 JSR TT27_C

.err_C

 JSR dn2_C                \ Call dn2 to make a short, high beep and delay for 1
                        \ second

 JMP j4_BAY                \ Jump to BAY to go to the docking bay (i.e. show the
                        \ Status Mode screen)

.ed9_C

 DEC BST                \ We just bought a shiny new fuel scoop, so set BST to
                        \ &FF (as BST was 0 before the jump to ed9 above)

.et6_C

 INY                    \ Increment Y to recursive token 112 ("E.C.M.SYSTEM")

 CMP #7                 \ If A is not 7 (i.e. the item we've just bought is not
 BNE et7_C                \ an escape pod), skip to et7

 LDX ESCP               \ If we already have an escape pod fitted (i.e. ESCP is
 BNE pres_C               \ non-zero), jump to pres to show the error "Escape Pod
                        \ Present", beep and exit to the docking bay (i.e. show
                        \ the Status Mode screen)

 DEC ESCP               \ Otherwise we just bought an escape pod, so set ESCP
                        \ to &FF (as ESCP was 0 before the DEC instruction)

.et7_C

 INY                    \ Increment Y to recursive token 113 ("ENERGY BOMB")

 CMP #8                 \ If A is not 8 (i.e. the item we've just bought is not
 BNE et8_C                \ an energy bomb), skip to et8

 LDX BOMB               \ If we already have an energy bomb fitted (i.e. BOMB
 BNE pres_C               \ is non-zero), jump to pres to show the error "Energy
                        \ Bomb Present", beep and exit to the docking bay (i.e.
                        \ show the Status Mode screen)

 LDX #&7F               \ Otherwise we just bought an energy bomb, so set BOMB
 STX BOMB               \ to &7F

.et8_C

 INY                    \ Increment Y to recursive token 114 ("ENERGY UNIT")

 CMP #9                 \ If A is not 9 (i.e. the item we've just bought is not
 BNE etA_C                \ an energy unit), skip to etA

 LDX ENGY               \ If we already have an energy unit fitted (i.e. ENGY is
 BNE pres_C               \ non-zero), jump to pres to show the error "Energy Unit
                        \ Present", beep and exit to the docking bay (i.e. show
                        \ the Status Mode screen)

 INC ENGY               \ Otherwise we just picked up an energy unit, so set
                        \ ENGY to 1 (as ENGY was 0 before the INC instruction)

.etA_C

 INY                    \ Increment Y to recursive token 115 ("DOCKING
                        \ COMPUTERS")

 CMP #10                \ If A is not 10 (i.e. the item we've just bought is not
 BNE etB_C                \ a docking computer), skip to etB

 LDX DKCMP              \ If we already have a docking computer fitted (i.e.
 BNE pres_C               \ DKCMP is non-zero), jump to pres to show the error
                        \ "Docking Computer Present", beep and exit to the
                        \ docking bay (i.e. show the Status Mode screen)

 DEC DKCMP              \ Otherwise we just got hold of a docking computer, so
                        \ set DKCMP to &FF (as DKCMP was 0 before the DEC
                        \ instruction)

.etB_C

 INY                    \ Increment Y to recursive token 116 ("GALACTIC
                        \ HYPERSPACE ")

 CMP #11                \ If A is not 11 (i.e. the item we've just bought is not
 BNE et9_C                \ a galactic hyperdrive), skip to et9

 LDX GHYP               \ If we already have a galactic hyperdrive fitted (i.e.
 BNE pres_C               \ GHYP is non-zero), jump to pres to show the error
                        \ "Galactic Hyperspace Present", beep and exit to the
                        \ docking bay (i.e. show the Status Mode screen)

 DEC GHYP               \ Otherwise we just splashed out on a galactic
                        \ hyperdrive, so set GHYP to &FF (as GHYP was 0 before
                        \ the DEC instruction)

.et9_C

 INY                    \ Increment Y to recursive token 117 ("MILITARY  LASER")

 CMP #12                \ If A is not 12 (i.e. the item we've just bought is not
 BNE et10_C               \ a military laser), skip to et10

 JSR qv_C                 \ Print a menu listing the four views, with a "View ?"
                        \ prompt, and ask for a view number, which is returned
                        \ in X (which now contains 0-3)

 LDA #Armlas            \ Call refund with A set to the power of the new
 JSR refund_C             \ military laser to install the new laser and process a
                        \ refund if we already have a laser fitted to this view

.et10_C

 INY                    \ Increment Y to recursive token 118 ("MINING  LASER")

 CMP #13                \ If A is not 13 (i.e. the item we've just bought is not
 BNE et11_C               \ a mining laser), skip to et11

 JSR qv_C                 \ Print a menu listing the four views, with a "View ?"
                        \ prompt, and ask for a view number, which is returned
                        \ in X (which now contains 0-3)

 LDA #Mlas              \ Call refund with A set to the power of the new mining
 JSR refund_C             \ laser to install the new laser and process a refund if
                        \ we already have a laser fitted to this view

.et11_C

 JSR dn_C                 \ We are done buying equipment, so print the amount of
                        \ cash left in the cash pot, then make a short, high
                        \ beep to confirm the purchase, and delay for 1 second

 JMP EQSHP_C              \ Jump back up to EQSHP to show the Equip Ship screen
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

.dn_C

 JSR TT162_C              \ Print a space

 LDA #119               \ Print recursive token 119 ("CASH:{cash} CR{crlf}")
 JSR x4_spc                \ followed by a space

                        \ Fall through into dn2 to make a beep and delay for
                        \ 1 second before returning from the subroutine

\ ******************************************************************************
\
\       Name: dn2
\       Type: Subroutine
\   Category: Text
\    Summary: Make a short, high beep and delay for 0.5 seconds
\
\ ******************************************************************************

.dn2_C

 JSR x4_BEEP               \ Call the BEEP subroutine to make a short, high beep

 LDY #25                \ Wait for 25/50 of a second (0.5 second) and return
 JMP x4_DELAY              \ from the subroutine using a tail call

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

.eq_C

 JSR prx_C                \ Call prx to set (Y X) to the price of equipment item
                        \ number A

 JSR LCASH_C              \ Subtract (Y X) cash from the cash pot, but only if
                        \ we have enough cash

 BCS c_C                  \ If the C flag is set then we did have enough cash for
                        \ the transaction, so jump to c to return from the
                        \ subroutine (as c contains an RTS)

 LDA #197               \ Otherwise we don't have enough cash to buy this piece
 JSR x4_prq                \ of equipment, so print recursive token 37 ("CASH")
                        \ followed by a question mark

 JMP err_C                \ Jump to err to beep, pause and go to the docking bay
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
\   A                   The item number of the piece of equipment (0-13) as
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

.prx_C

 ASL A                  \ Set Y = A * 2, so it can act as an index into the
 TAY                    \ PRXS table, which has two bytes per entry

 LDX PRXS_C,Y             \ Fetch the low byte of the price into X

 LDA PRXS_C+1,Y           \ Fetch the high byte of the price into A and transfer
 TAY                    \ it to X, so the price is now in (Y X)

.c_C

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

.qv_C

 LDA tek                \ If the current system's tech level is less than 8,
 CMP #8                 \ skip the next two instructions, otherwise we clear the
 BCC P%+7               \ screen to prevent the view menu from clashing with the
                        \ longer equipment menu available in higher tech systems

 LDA #32                \ Clear the top part of the screen, draw a border box,
 JSR x4_TT66               \ and set the current view type in QQ11 to 32 (Equip
                        \ Ship screen)

 LDA #16                \ Move the text cursor to row 16, and at the same time
 TAY                    \ set Y to a counter going from 16 to 19 in the loop
 STA YC                 \ below

.qv1_C

 LDA #12                \ Move the text cursor to column 12
 STA XC

 TYA                    \ Transfer the counter value from Y to A

 CLC                    \ Print ASCII character "0" - 16 + A, so as A goes from
 ADC #'0'-16            \ 16 to 19, this prints "0" through "3" followed by a
 JSR x4_spc                \ space

 LDA YC                 \ Print recursive text token 80 + YC, so as YC goes from
 CLC                    \ 16 to 19, this prints "FRONT", "REAR", "LEFT" and
 ADC #80                \ "RIGHT"
 JSR TT27_C

 INC YC                 \ Move the text cursor down a row, and increment the
                        \ counter in YC at the same time

 LDY YC                 \ Update Y with the incremented counter in YC

 CPY #20                \ If Y < 20 then loop back up to qv1 to print the next
 BCC qv1_C                \ view in the menu

 JSR x4_CLYNS              \ Clear the bottom three text rows of the upper screen,
                        \ and move the text cursor to the first cleared row

.qv2_C

 LDA #175               \ Print recursive text token 15 ("VIEW ") followed by
 JSR x4_prq                \ a question mark

 JSR x4_TT217              \ Scan the keyboard until a key is pressed, and return
                        \ the key's ASCII code in A (and X)

 SEC                    \ Subtract ASCII "0" from the key pressed, to leave the
 SBC #'0'               \ numeric value of the key in A (if it was a number key)

 CMP #4                 \ If the number entered in A < 4, then it is a valid
 BCC qv3_C                \ view number, so jump down to qv3 as we are done

 JSR x4_CLYNS              \ Otherwise we didn't get a valid view number, so clear
                        \ the bottom three text rows of the upper screen, and
                        \ move the text cursor to column 1 on row 21

 JMP qv2_C                \ Jump back to qv2 to try again

.qv3_C

 TAX                    \ We have a valid view number, so transfer it to X

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: hm
\       Type: Subroutine
\   Category: Charts
\    Summary: Select the closest system and redraw the chart crosshairs
\
\ ------------------------------------------------------------------------------
\
\ Set the system closest to galactic coordinates (QQ9, QQ10) as the selected
\ system, redraw the crosshairs on the chart accordingly (if they are being
\ shown), and if this is not the space view, clear the bottom three text rows of
\ the screen.
\
\ ******************************************************************************

.hm_C

 JSR x4_TT103              \ Draw small crosshairs at coordinates (QQ9, QQ10),
                        \ which will erase the crosshairs currently there

 JSR x4_TT111              \ Select the system closest to galactic coordinates
                        \ (QQ9, QQ10)

 JSR x4_TT103              \ Draw small crosshairs at coordinates (QQ9, QQ10),
                        \ which will draw the crosshairs at our current home
                        \ system

 JMP x4_CLYNS              \ Clear the bottom three text rows of the upper screen,
                        \ move the text cursor to the first cleared row, and
                        \ return from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: refund
\       Type: Subroutine
\   Category: Equipment
\    Summary: Install a new laser, processing a refund if applicable
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The power of the new laser to be fitted
\
\   X                   The view number for fitting the new laser (0-3)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   A is preserved
\
\   X                   X is preserved
\
\ ******************************************************************************

\.ref2                  \ These instructions are commented out in the original
\                       \ source, but they would jump to pres in the EQSHP
\LDY #187               \ routine with Y = 187, which would show the error:
\JMP pres               \ "LASER PRESENT" (this code was part of the refund
\                       \ bug in the BBC Micro disc version of Elite, which
\Belgium                \ is why it is commented out)
                        \
                        \ There is also a comment in the original source - the
                        \ solitary word "Belgium"
                        \
                        \ This is presumably a reference to the Hitchhiker's
                        \ Guide to the Galaxy, which says that Belgium is the
                        \ galaxy's most unspeakably rude word, so this no doubt
                        \ reflects the authors' strong feelings on the refund
                        \ bug

.refund_C

 STA T1                 \ Store A in T1 so we can retrieve it later

 LDA LASER,X            \ If there is no laser in view X (i.e. the laser power
 BEQ ref3_C               \ is zero), jump to ref3 to skip the refund code

\CMP T1                 \ These instructions are commented out in the original
\BEQ ref2               \ source, but they would jump to ref2 above if we were
                        \ trying to replace a laser with one of the same type
                        \ (this code was part of the refund bug in the BBC Micro
                        \ disc version of Elite, which is why it is commented
                        \ out)

 LDY #4                 \ If the current laser has power #POW (pulse laser),
 CMP #POW               \ jump to ref1 with Y = 4 (the item number of a pulse
 BEQ ref1_C               \ laser in the table at PRXS)

 LDY #5                 \ If the current laser has power #POW+128 (beam laser),
 CMP #POW+128           \ jump to ref1 with Y = 5 (the item number of a beam
 BEQ ref1_C               \ laser in the table at PRXS)

 LDY #12                \ If the current laser has power #Armlas (military
 CMP #Armlas            \ laser), jump to ref1 with Y = 12 (the item number of a
 BEQ ref1_C               \ military laser in the table at PRXS)

 LDY #13                \ Otherwise this is a mining laser, so fall through into
                        \ ref1 with Y = 13 (the item number of a mining laser in
                        \ the table at PRXS)

.ref1_C

                        \ We now want to refund the laser of type Y that we are
                        \ exchanging for the new laser

 STX ZZ                 \ Store the view number in ZZ so we can retrieve it
                        \ later

 TYA                    \ Copy the laser type to be refunded from Y to A

 JSR prx_C                \ Call prx to set (Y X) to the price of equipment item
                        \ number A

 JSR MCASH_C              \ Call MCASH to add (Y X) to the cash pot

 LDX ZZ                 \ Retrieve the view number from ZZ

.ref3_C

                        \ Finally, we install the new laser

 LDA T1                 \ Retrieve the new laser's power from T1 into A

 STA LASER,X            \ Set the laser view to the new laser's power

 RTS                    \ Return from the subroutine

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

.PRXS_C

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
 EQUW 60000             \ 12 Extra Military Lasers     6000.0 Cr
 EQUW 8000              \ 13 Extra Mining Lasers        800.0 Cr

\ ******************************************************************************
\
\ Save ELTD.bin
\
