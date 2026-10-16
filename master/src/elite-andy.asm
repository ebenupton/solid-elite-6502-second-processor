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
 JSR TRADEMODE_C          \ and set up a trading screen with a view type in QQ11
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
 JSR prq_C                \ mark

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

 JSR TT67_C               \ Print a newline

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
 JSR DOYC_C

 LDA #0                 \ Move the text cursor to column 0
 JSR DOXC_C

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

 JSR TT217_C              \ Scan the keyboard until a key is pressed, and return
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

 JSR TT67_C               \ Print a newline

 LDA #176               \ Print recursive token 127 ("ITEM") followed by a
 JSR prq_C                \ question mark

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
 JSR TRADEMODE_C          \ and set up a trading screen with a view type in QQ11
                        \ of 4 (Sell Cargo screen)

 LDA #10                \ Move the text cursor to column 10
 STA XC

 LDA #205               \ Print recursive token 45 ("SELL")
 JSR TT27_C

 LDA #206               \ Print recursive token 46 (" CARGO{sentence case}")
 JSR NLIN3_C              \ draw a horizontal line at pixel row 19 to box in the
                        \ title

 JSR TT67_C               \ Print a newline

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

 JSR TT69_C               \ Call TT69 to set Sentence Case and print a newline

 CLC                    \ Print recursive token 48 + QQ29, which will be in the
 LDA QQ29               \ range 48 ("FOOD") to 64 ("ALIEN ITEMS"), so this
 ADC #208               \ prints the current item's name
 JSR TT27_C

 LDA #14                \ Move the text cursor to column 14, for the item's
 JSR DOXC_C               \ quantity

 PLA                    \ Restore the amount of item in the hold into X
 TAX

 STA QQ25               \ Store the amount of this item in the hold in QQ25

 CLC                    \ Print the 8-bit number in X to 3 digits, without a
 JSR pr2_C                \ decimal point

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

 JSR TT69_C               \ Call TT69 to set Sentence Case and print a newline

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

 JSR TT11_C               \ Call TT11 to print the number of Trumbles in (Y X),
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
 JSR TRADEMODE_C          \ and set up a trading screen with a view type in QQ11
                        \ of 4 (Inventory screen)

 LDA #11                \ Move the text cursor to column 11 to print the screen
 STA XC                 \ title

 LDA #164               \ Print recursive token 4 ("INVENTORY{crlf}") followed
 JSR TT60_C               \ by a paragraph break and Sentence Case

 JSR NLIN4_C              \ Draw a horizontal line at pixel row 19 to box in the
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

 JSR TT217_C              \ Scan the keyboard until a key is pressed, and return
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
 JSR DOXC_C

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
 JSR pr5_C                \ to print (Y X) to 5 digits, including a decimal
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

 JSR pr2_C+2              \ Otherwise print the 8-bit number in X to 5 digits,
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
 JSR DOXC_C

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
 JSR DOXC_C

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
 JSR TRADEMODE_C          \ and set up a trading screen with a view type in QQ11
                        \ of 32 (Market Price screen)

 LDA #5                 \ Move the text cursor to column 5
 STA XC

 LDA #167               \ Print recursive token 7 ("{current system name} MARKET
 JSR NLIN3_C              \ PRICES") and draw a horizontal line at pixel row 19
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

 JMP BAY_C                \ Go to the docking bay (i.e. show the Status Mode
                        \ screen)

.EQSHP_C

 LDA #32                \ Clear the top part of the screen, draw a border box,
 JSR TRADEMODE_C          \ and set up a printable trading screen with a view type
                        \ in QQ11 of 32 (Equip Ship screen)

 LDA #12                \ Move the text cursor to column 12
 STA XC

 LDA #207               \ Print recursive token 47 ("EQUIP") followed by a space
 JSR spc_C

 LDA #185               \ Print recursive token 25 ("SHIP") and draw a
 JSR NLIN3_C              \ horizontal line at pixel row 19 to box in the title

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

 JSR TT67_C               \ Print a newline

 LDX XX13               \ Print the current item number + 1 to 3 digits, left-
 CLC                    \ padding with spaces, and with no decimal point, so the
 JSR pr2_C                \ items are numbered from 1

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
 JSR TT11_C               \ with spaces and including a decimal point, which will
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
 JSR prq_C                \ question mark

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
 JSR spc_C                \ followed by a space

 LDA #31                \ Print recursive token 145 ("PRESENT")
 JSR TT27_C

.err_C

 JSR dn2_C                \ Call dn2 to make a short, high beep and delay for 1
                        \ second

 JMP BAY_C                \ Jump to BAY to go to the docking bay (i.e. show the
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
 JSR spc_C                \ followed by a space

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
 JSR prq_C                \ of equipment, so print recursive token 37 ("CASH")
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
 JSR TT66_C               \ and set the current view type in QQ11 to 32 (Equip
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
 JSR spc_C                \ space

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
 JSR prq_C                \ a question mark

 JSR TT217_C              \ Scan the keyboard until a key is pressed, and return
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

 JSR TT103_C              \ Draw small crosshairs at coordinates (QQ9, QQ10),
                        \ which will erase the crosshairs currently there

 JSR TT111_C              \ Select the system closest to galactic coordinates
                        \ (QQ9, QQ10)

 JSR TT103_C              \ Draw small crosshairs at coordinates (QQ9, QQ10),
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

\ ******************************************************************************
\
\       Name: STATUS
\       Type: Subroutine
\   Category: Status
\    Summary: Show the Status Mode screen (red key f8)
\  Deep dive: Combat rank
\
\ ******************************************************************************

.wearedocked_C

                        \ We call this from STATUS below if we are docked

 LDA #205               \ Print extended token 205 ("DOCKED") and return from
 JSR DETOK_C              \ the subroutine using a tail call

 JSR x4_TT67K              \ Print a newline

 JMP st6_C+3              \ Jump down to st6+3, to print recursive token 125 and
                        \ continue to the rest of the Status Mode screen

.st4_C

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
 BCS st3_C                \ are Elite

 DEX                    \ Decrement X to 8 for a Deadly rating

 CMP #10                \ If A >= 10, jump to st3 to print out our rating, as we
 BCS st3_C                \ are Deadly

 DEX                    \ Decrement X to 7 for a Dangerous rating

 CMP #2                 \ If A >= 2, jump to st3 to print out our rating, as we
 BCS st3_C                \ are Dangerous

 DEX                    \ Decrement X to 6 for a Competent rating

 BNE st3_C                \ Jump to st3 to print out our rating, as we are
                        \ Competent (this BNE is effectively a JMP as A will
                        \ never be zero)

.STATUS_C

 LDA #8                 \ Clear the top part of the screen, draw a border box,
 JSR TRADEMODE_C          \ and set up a trading screen with a view type in QQ11
                        \ of 8 (Status Mode screen)

 JSR TT111_C              \ Select the system closest to galactic coordinates
                        \ (QQ9, QQ10)

 LDA #7                 \ Move the text cursor to column 7
 STA XC

 LDA #126               \ Print recursive token 126, which prints the top
 JSR NLIN3_C              \ four lines of the Status Mode screen:
                        \
                        \         COMMANDER {commander name}
                        \
                        \
                        \   Present System      : {current system name}
                        \   Hyperspace System   : {selected system name}
                        \   Condition           :
                        \
                        \ and draw a horizontal line at pixel row 19 to box
                        \ in the title

 LDA #15                \ This instruction is left over from the cassette
                        \ version, where it sets the token number for the
                        \ "DOCKED" text, but it has no effect in this version
                        \ as the "DOCKED" text is now an extended token

 LDY QQ12               \ Fetch the docked status from QQ12, and if we are
 BNE wearedocked_C        \ docked, jump to wearedocked

 LDA #230               \ Otherwise we are in space, so start off by setting A
                        \ to token 70 ("GREEN")

 LDY JUNK               \ Set Y to the number of junk items in our local bubble
                        \ of universe (where junk is asteroids, canisters,
                        \ escape pods and so on)

 LDX FRIN+2,Y           \ The ship slots at FRIN are ordered with the first two
                        \ slots reserved for the planet and sun/space station,
                        \ and then any ships, so if the slot at FRIN+2+Y is not
                        \ empty (i.e. is non-zero), then that means the number
                        \ of non-asteroids in the vicinity is at least 1

 BEQ st6_C                \ So if X = 0, there are no ships in the vicinity, so
                        \ jump to st6 to print "Green" for our ship's condition

 LDY ENERGY             \ Otherwise we have ships in the vicinity, so we load
                        \ our energy levels into Y

 CPY #128               \ Set the C flag if Y >= 128, so C is set if we have
                        \ more than half of our energy banks charged

 ADC #1                 \ Add 1 + C to A, so if C is not set (i.e. we have low
                        \ energy levels) then A is set to token 231 ("RED"),
                        \ and if C is set (i.e. we have healthy energy levels)
                        \ then A is set to token 232 ("YELLOW")

.st6_C

 JSR plf_C                \ Print the text token in A (which contains our ship's
                        \ condition) followed by a newline

 LDA #125               \ Print recursive token 125, which prints the next
 JSR spc_C                \ three lines of the Status Mode screen:
                        \
                        \   Fuel: {fuel level} Light Years
                        \   Cash: {cash} Cr
                        \   Legal Status:
                        \
                        \ followed by a space

 LDA #19                \ Set A to token 133 ("CLEAN")

 LDY FIST               \ Fetch our legal status, and if it is 0, we are clean,
 BEQ st5_C                \ so jump to st5 to print "Clean"

 CPY #50                \ Set the C flag if Y >= 50, so C is set if we have
                        \ a legal status of 50+ (i.e. we are a fugitive)

 ADC #1                 \ Add 1 + C to A, so if C is not set (i.e. we have a
                        \ legal status between 1 and 49) then A is set to token
                        \ 134 ("OFFENDER"), and if C is set (i.e. we have a
                        \ legal status of 50+) then A is set to token 135
                        \ ("FUGITIVE")

.st5_C

 JSR plf_C                \ Print the text token in A (which contains our legal
                        \ status) followed by a newline

 LDA #16                \ Print recursive token 130 ("RATING:") followed by a
 JSR spc_C                \ space

 LDA TALLY+1            \ Fetch the high byte of the kill tally, and if it is
 BNE st4_C                \ not zero, then we have more than 256 kill points, so
                        \ jump to st4 to work out whether we are Competent,
                        \ Dangerous, Deadly or Elite

                        \ Otherwise we have fewer than 256 kill pointss, so we
                        \ are one of Harmless, Mostly Harmless, Poor, Average,
                        \ Above Average or Competent

 TAX                    \ Set X to 0 (as A is 0)

 LDA TALLY              \ Set A to the lower byte of tally, with bits 0 and 1
 LSR A                  \ shifted off to the right, so we can now analyse bits
 LSR A                  \ 2 to 7 by shifting A to the right one bit at a time

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

 BNE P%-2               \ Keep looping back two instructions (i.e. to the INX
                        \ instruction) until A = 0, which means there are no set
                        \ bits left in A

.st3_C

 TXA                    \ A now contains our rating as a value of 1 to 9, so
                        \ transfer X to A, so we can print it out

 CLC                    \ Print recursive token 135 + A, which will be in the
 ADC #21                \ range 136 ("HARMLESS") to 144 ("---- E L I T E ----")
 JSR plf_C                \ followed by a newline

 LDA #18                \ Print recursive token 132, which prints the next bit
 JSR plf2_C               \ of the Status Mode screen:
                        \
                        \   EQUIPMENT:
                        \
                        \ followed by a newline and an indent of 6 characters

 LDA ESCP               \ If we don't have an escape pod fitted (i.e. ESCP is
 BEQ P%+7               \ zero), skip the following two instructions

 LDA #112               \ We do have an escape pod fitted, so print recursive
 JSR plf2_C               \ token 112 ("ESCAPE POD"), followed by a newline and an
                        \ indent of 6 characters

 LDA BST                \ If we don't have fuel scoops fitted, skip the
 BEQ P%+7               \ following two instructions

 LDA #111               \ We do have fuel scoops fitted, so print recursive
 JSR plf2_C               \ token 111 ("FUEL SCOOPS"), followed by a newline and
                        \ an indent of 6 characters

 LDA ECM                \ If we don't have an E.C.M. fitted, skip the following
 BEQ P%+7               \ two instructions

 LDA #108               \ We do have an E.C.M. fitted, so print recursive token
 JSR plf2_C               \ 108 ("E.C.M.SYSTEM"), followed by a newline and an
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

.stqv_C

 TAY                    \ Fetch byte BOMB+0 through BOMB+4 for values of XX4
 LDX BOMB-113,Y         \ from 113 through 117

 BEQ P%+5               \ If it is zero then we do not own that piece of
                        \ equipment, so skip the next instruction

 JSR plf2_C               \ Print the recursive token in A from 113 ("ENERGY
                        \ BOMB") through 116 ("GALACTIC HYPERSPACE "), followed
                        \ by a newline and an indent of 6 characters

 INC XX4                \ Increment the counter (and A as well)
 LDA XX4

 CMP #117               \ If A < 117, loop back up to stqv to print the next
 BCC stqv_C               \ piece of equipment

 LDX #0                 \ Now to print our ship's lasers, so set a counter in X
                        \ to count through the four views (0 = front, 1 = rear,
                        \ 2 = left, 3 = right)

.st_C

 STX CNT                \ Store the view number in CNT

 LDY LASER,X            \ Fetch the laser power for view X, and if we do not
 BEQ st1_C                \ have a laser fitted to that view, jump to st1 to move
                        \ on to the next one

 TXA                    \ Print recursive token 96 + X, which will print from 96
 CLC                    \ ("FRONT") through to 99 ("RIGHT"), followed by a space
 ADC #96
 JSR spc_C

 LDA #103               \ Set A to token 103 ("PULSE LASER")

 LDX CNT                \ Retrieve the view number from CNT that we stored above

 LDY LASER,X            \ Set Y = the laser power for view X

 CPY #128+POW           \ If the laser power for view X is not #POW+128 (beam
 BNE P%+4               \ laser), skip the next LDA instruction

 LDA #104               \ This sets A = 104 if the laser in view X is a beam
                        \ laser (token 104 is "BEAM LASER")

 CPY #Armlas            \ If the laser power for view X is not #Armlas (military
 BNE P%+4               \ laser), skip the next LDA instruction

 LDA #117               \ This sets A = 117 if the laser in view X is a military
                        \ laser (token 117 is "MILITARY  LASER")

 CPY #Mlas              \ If the laser power for view X is not #Mlas (mining
 BNE P%+4               \ laser), skip the next LDA instruction

 LDA #118               \ This sets A = 118 if the laser in view X is a mining
                        \ laser (token 118 is "MINING  LASER")

 JSR plf2_C               \ Print the text token in A (which contains the laser
                        \ type) followed by a newline and an indent of 6
                        \ characters

.st1_C

 LDX CNT                \ Increment the counter in X and CNT to point to the
 INX                    \ next view

 CPX #4                 \ If this isn't the last of the four views, jump back up
 BCC st_C                 \ to st to print out the next one

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

.plf2_C

 JSR plf_C                \ Print the text token in A followed by a newline

 LDA #6                 \ Move the text cursor to column 6
 STA XC

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: HME2
\       Type: Subroutine
\   Category: Charts
\    Summary: Search the galaxy for a system
\
\ ******************************************************************************

.HME2_C

 LDA #CYAN              \ Switch to colour 3, which is white in the chart view
 STA COL

 LDA #14                \ Print extended token 14 ("{clear bottom of screen}
 JSR DETOK_C              \ PLANET NAME?{fetch line input from keyboard}"). The
                        \ last token calls MT26, which puts the entered search
                        \ term in INWK+5 and the term length in Y

 JSR TT103_C              \ Draw small crosshairs at coordinates (QQ9, QQ10),
                        \ which will erase the crosshairs currently there

 JSR TT81_C               \ Set the seeds in QQ15 (the selected system) to those
                        \ of system 0 in the current galaxy (i.e. copy the seeds
                        \ from QQ21 to QQ15)

 LDA #0                 \ We now loop through the galaxy's systems in order,
 STA XX20               \ until we find a match, so set XX20 to act as a system
                        \ counter, starting with system 0

.HME3_C

 JSR MT14_C               \ Switch to justified text when printing extended
                        \ tokens, so the call to cpl prints into the justified
                        \ text buffer at BUF instead of the screen, and DTW5
                        \ gets set to the length of the system name

 JSR cpl_C                \ Print the selected system name into the justified text
                        \ buffer

 LDX DTW5               \ Fetch DTW5 into X, so X is now equal to the length of
                        \ the selected system name

 LDA INWK+5,X           \ Fetch the X-th character from the entered search term

 CMP #13                \ If the X-th character is not a carriage return, then
 BNE HME6_C               \ the selected system name and the entered search term
                        \ are different lengths, so jump to HME6 to move on to
                        \ the next system

.HME4_C

 DEX                    \ Decrement X so it points to the last letter of the
                        \ selected system name (and, when we loop back here, it
                        \ points to the next letter to the left)

 LDA INWK+5,X           \ Set A to the X-th character of the entered search term

 ORA #%00100000         \ Set bit 5 of the character to make it lower case

 CMP BUF,X              \ If the character in A matches the X-th character of
 BEQ HME4_C               \ the selected system name in BUF, loop back to HME4 to
                        \ check the next letter to the left

 TXA                    \ The last comparison didn't match, so copy the letter
 BMI HME5_C               \ number into A, and if it's negative, that means we
                        \ managed to go past the first letters of each term
                        \ before we failed to get a match, so the terms are the
                        \ same, so jump to HME5 to process a successful search

.HME6_C

                        \ If we get here then the selected system name and the
                        \ entered search term did not match

 JSR TT20_C               \ We want to move on to the next system, so call TT20
                        \ to twist the three 16-bit seeds in QQ15

 INC XX20               \ Increment the system counter in XX20

 BNE HME3_C               \ If we haven't yet checked all 256 systems in the
                        \ current galaxy, loop back to HME3 to check the next
                        \ system

                        \ If we get here then the entered search term did not
                        \ match any systems in the current galaxy

 JSR TT111_C              \ Select the system closest to galactic coordinates
                        \ (QQ9, QQ10), so we can put the crosshairs back where
                        \ they were before the search

 JSR TT103_C              \ Draw small crosshairs at coordinates (QQ9, QQ10)

 JSR x4_BOOP               \ Call the BOOP routine to make a low, long beep to
                        \ indicate a failed search

 LDA #215               \ Print extended token 215 ("{left align} UNKNOWN
 JMP DETOK_C              \ PLANET"), which will print on-screen as the left align
                        \ code disables justified text, and return from the
                        \ subroutine using a tail call

.HME5_C

                        \ If we get here then we have found a match for the
                        \ entered search

 LDA QQ15+3             \ The x-coordinate of the system described by the seeds
 STA QQ9                \ in QQ15 is in QQ15+3 (s1_hi), so we copy this to QQ9
                        \ as the x-coordinate of the search result

 LDA QQ15+1             \ The y-coordinate of the system described by the seeds
 STA QQ10               \ in QQ15 is in QQ15+1 (s0_hi), so we copy this to QQ10
                        \ as the y-coordinate of the search result

 JSR TT111_C              \ Select the system closest to galactic coordinates
                        \ (QQ9, QQ10)

 JSR TT103_C              \ Draw small crosshairs at coordinates (QQ9, QQ10)

 JSR MT15_C               \ Switch to left-aligned text when printing extended
                        \ tokens so future tokens will print to the screen (as
                        \ this disables justified text)

 JMP x4_T95                \ Jump to T95 to print the distance to the selected
                        \ system and return from the subroutine using a tail
                        \ call

\ ******************************************************************************
\
\ Save ELTB.bin
\
\ ******************************************************************************
\
\       Name: ping
\       Type: Subroutine
\   Category: Universe
\    Summary: Set the selected system to the current system
\
\ ******************************************************************************

.ping_C

 LDX #1                 \ We want to copy the X- and Y-coordinates of the
                        \ current system in (QQ0, QQ1) to the selected system's
                        \ coordinates in (QQ9, QQ10), so set up a counter to
                        \ copy two bytes

.pl1_C

 LDA QQ0,X              \ Load byte X from the current system in QQ0/QQ1

 STA QQ9,X              \ Store byte X in the selected system in QQ9/QQ10

 DEX                    \ Decrement the loop counter

 BPL pl1_C                \ Loop back for the next byte to copy

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: SCALEY
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Scale the y-coordinate in A to 0.5 * A
\
\ ------------------------------------------------------------------------------
\
\ This routine (and the related SCALEY2 and SCALEX routines) are called from
\ various places in the code to scale the value in A. This code is different in
\ the Apple II and BBC Master versions, and allows coordinates to be scaled
\ correctly on different platforms.
\
\ In the Master version, the only scaling routine that does anything is SCALEY,
\ which halves the y-coordinates in the Long-range Chart (as the galaxy is half
\ as tall as it is wide). The other routines are left over from the Apple II
\ version, which uses them to scale the system charts to fit into its smaller
\ screen size.
\
\ ******************************************************************************

.SCALEY_C

 LSR A                  \ Halve the value in A

                        \ Fall through into SCALEY2 to return from the
                        \ subroutine

\ ******************************************************************************
\
\       Name: SCALEY2
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Scale the y-coordinate in A (leave it unchanged)
\
\ ------------------------------------------------------------------------------
\
\ This routine (and the related SCALEY and SCALEX routines) are called from
\ various places in the code to scale the value in A. This code is different in
\ the Apple II and BBC Master versions, and allows coordinates to be scaled
\ correctly on different platforms.
\
\ The original source contains the comment "SCALE Scans by 3/4 to fit in".
\
\ In the Master version, the only scaling routine that does anything is SCALEY,
\ which halves the y-coordinates in the Long-range Chart (as the galaxy is half
\ as tall as it is wide). The other routines are left over from the Apple II
\ version, which uses them to scale the system charts to fit into its smaller
\ screen size.
\
\ ******************************************************************************

.SCALEY2_C

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: SCALEX
\       Type: Subroutine
\   Category: Maths (Geometry)
\    Summary: Scale the x-coordinate in A (leave it unchanged)
\
\ ------------------------------------------------------------------------------
\
\ This routine (and the related SCALEY and SCALEY2 routines) are called from
\ various places in the code to scale the value in A. This code is different in
\ the Apple II and BBC Master versions, and allows coordinates to be scaled
\ correctly on different platforms.
\
\ In the Master version, the only scaling routine that does anything is SCALEY,
\ which halves the y-coordinates in the Long-range Chart (as the galaxy is half
\ as tall as it is wide). The other routines are left over from the Apple II
\ version, which uses them to scale the system charts to fit into its smaller
\ screen size.
\
\ ******************************************************************************

.SCALEX_C

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: DVLOIN
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw a vertical line from (A, GCYT) to (A, GCYB)
\
\ ------------------------------------------------------------------------------
\
\ This routine is from the Apple II version of Elite and is not used in the BBC
\ Master version.
\
\ ******************************************************************************

.DVLOIN_C

 STA X1                 \ Draw a vertical line from (A, GCYT) to (A, GCYB)
 STA X2
 LDA #GCYT
 STA Y1
 LDA #GCYB
 STA Y2
 JMP x4_LOIN

\ ******************************************************************************
\
\       Name: DOXC
\       Type: Subroutine
\   Category: Text
\    Summary: Move the text cursor to a specific column
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The text column
\
\ ******************************************************************************

.DOXC_C

 STA XC                 \ Store the new text column in XC

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: DOYC
\       Type: Subroutine
\   Category: Text
\    Summary: Move the text cursor to a specific row
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The text row
\
\ ******************************************************************************

.DOYC_C

 STA YC                 \ Store the new text row in YC

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: INCYC
\       Type: Subroutine
\   Category: Text
\    Summary: Move the text cursor to the next row
\
\ ******************************************************************************

.INCYC_C

 INC YC                 \ Move the text cursor to the next row

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TRADEMODE
\       Type: Subroutine
\   Category: Drawing the screen
\    Summary: Clear the screen and set up a trading screen
\
\ ------------------------------------------------------------------------------
\
\ Clear the top part of the screen, draw a border box, set the palette for
\ trading screens, and set the current view type in QQ11 to A.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The type of the new current view (see QQ11 for a list of
\                       view types)
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   TRADEMODE2          Set the palette for trading screens and switch the
\                       current colour to white
\
\ ******************************************************************************

.TRADEMODE_C

 JSR TT66_C               \ Clear the top part of the screen, draw a border box,
                        \ and set the current view type in QQ11 to A

 JSR FLKB_C               \ Call FLKB to flush the keyboard buffer

.TRADEMODE2_C

 LDA #48                \ Switch to the mode 1 palette for trading screens,
 JSR x4_DOVDU19            \ which is yellow (colour 1), magenta (colour 2) and
                        \ white (colour 3)

 LDA #CYAN              \ Switch to colour 3, which is white in the trade view
 STA COL

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TT20
\       Type: Subroutine
\   Category: Universe
\    Summary: Twist the selected system's seeds four times
\  Deep dive: Twisting the system seeds
\             Galaxy and system seeds
\
\ ------------------------------------------------------------------------------
\
\ Twist the three 16-bit seeds in QQ15 (selected system) four times, to
\ generate the next system.
\
\ ******************************************************************************

.TT20_C

 JSR P%+3               \ This line calls the line below as a subroutine, which
                        \ does two twists before returning here, and then we
                        \ fall through to the line below for another two
                        \ twists, so the net effect of these two consecutive
                        \ JSR calls is four twists, not counting the ones
                        \ inside your head as you try to follow this process

 JSR P%+3               \ This line calls TT54 as a subroutine to do a twist,
                        \ and then falls through into TT54 to do another twist
                        \ before returning from the subroutine

\ ******************************************************************************
\
\       Name: TT54
\       Type: Subroutine
\   Category: Universe
\    Summary: Twist the selected system's seeds
\  Deep dive: Twisting the system seeds
\             Galaxy and system seeds
\
\ ------------------------------------------------------------------------------
\
\ This routine twists the three 16-bit seeds in QQ15 once.
\
\ If we start with seeds s0, s1 and s2 and we want to work out their new values
\ after we perform a twist (let's call the new values s0´, s1´ and s2´), then:
\
\  s0´ = s1
\  s1´ = s2
\  s2´ = s0 + s1 + s2
\
\ So given an existing set of seeds in s0, s1 and s2, we can get the new values
\ s0´, s1´ and s2´ simply by doing the above sums. And if we want to do the
\ above in-place without creating three new s´ variables, then we can do the
\ following:
\
\  tmp = s0 + s1
\  s0 = s1
\  s1 = s2
\  s2 = tmp + s1
\
\ So this is what we do in this routine, where each seed is a 16-bit number.
\
\ ******************************************************************************

.TT54_C

 LDA QQ15               \ X = tmp_lo = s0_lo + s1_lo
 CLC
 ADC QQ15+2
 TAX

 LDA QQ15+1             \ Y = tmp_hi = s1_hi + s1_hi + C
 ADC QQ15+3
 TAY

 LDA QQ15+2             \ s0_lo = s1_lo
 STA QQ15

 LDA QQ15+3             \ s0_hi = s1_hi
 STA QQ15+1

 LDA QQ15+5             \ s1_hi = s2_hi
 STA QQ15+3

 LDA QQ15+4             \ s1_lo = s2_lo
 STA QQ15+2

 CLC                    \ s2_lo = X + s1_lo
 TXA
 ADC QQ15+2
 STA QQ15+4

 TYA                    \ s2_hi = Y + s1_hi + C
 ADC QQ15+3
 STA QQ15+5

 RTS                    \ The twist is complete so return from the subroutine

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

.TT146_C

 LDA QQ8                \ Take the two bytes of the 16-bit value in QQ8 and
 ORA QQ8+1              \ OR them together to check whether there are any
 BNE TT63_C               \ non-zero bits, and if so, jump to TT63 to print the
                        \ distance

 INC YC                 \ The distance is zero, so we just move the text cursor
 RTS                    \ in YC down by one line and return from the subroutine

.TT63_C

 LDA #191               \ Print recursive token 31 ("DISTANCE") followed by
 JSR TT68_C               \ a colon

 LDX QQ8                \ Load (Y X) from QQ8, which contains the 16-bit
 LDY QQ8+1              \ distance we want to show

 SEC                    \ Set the C flag so that the call to pr5 will include a
                        \ decimal point, and display the value as (Y X) / 10

 JSR pr5_C                \ Print (Y X) to 5 digits, including a decimal point

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

.TT60_C

 JSR TT27_C               \ Print the text token in A and fall through into TTX69
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

.TTX69_C

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

.TT69_C

 LDA #%10000000         \ Set bit 7 of QQ17 to switch to Sentence Case
 STA QQ17

                        \ Fall through into TT67 to print a newline

\ ******************************************************************************
\
\       Name: TT67
\       Type: Subroutine
\   Category: Text
\    Summary: Print a newline
\
\ ******************************************************************************

.TT67_C

\INC YC                 \ This instruction is commented out in the original
                        \ source

 LDA #12                \ Load a newline character into A

 JMP TT27_C               \ Print the text token in A and return from the
                        \ subroutine using a tail call

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

.TT70_C

 LDA #173               \ Print recursive token 13 ("MAINLY ")
 JSR TT27_C

 JMP TT72_C               \ Jump to TT72 to continue printing system data as part
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

.spc_C

 JSR TT27_C               \ Print the text token in A

 JMP TT162_C              \ Print a space and return from the subroutine using a
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

.TT25_C

 LDA #1                 \ Clear the top part of the screen, draw a border box,
 JSR TRADEMODE_C          \ and set up a trading screen with a view type in QQ11
                        \ of 1

 LDA #9                 \ Move the text cursor to column 9
 STA XC

 LDA #163               \ Print recursive token 3 ("DATA ON {selected system
 JSR NLIN3_C              \ name}" and draw a horizontal line at pixel row 19
                        \ to box in the title

 JSR TTX69_C              \ Print a paragraph break and set Sentence Case

 JSR TT146_C              \ If the distance to this system is non-zero, print
                        \ "DISTANCE", then the distance, "LIGHT YEARS" and a
                        \ paragraph break, otherwise just move the cursor down
                        \ a line

 LDA #194               \ Print recursive token 34 ("ECONOMY") followed by
 JSR TT68_C               \ a colon

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
 BEQ TT70_C

 LDA QQ3                \ If (QQ3 + 1) >> 1 < %10, i.e. if QQ3 = %000, %001 or
 BCC TT71_C               \ %010 (0, 1 or 2), then jump to TT71 with A set to the
                        \ original value of QQ3

 SBC #5                 \ Here QQ3 = %101, %110 or %111 (5, 6 or 7), so subtract
 CLC                    \ 5 to bring it down to 0, 1 or 2 (the C flag is already
                        \ set so the SBC will be correct)

.TT71_C

 ADC #170               \ A is now 0, 1 or 2, so print recursive token 10 + A.
 JSR TT27_C               \ This means that:
                        \
                        \   QQ3 = 0 or 5 prints token 10 ("RICH ")
                        \   QQ3 = 1 or 6 prints token 11 ("AVERAGE ")
                        \   QQ3 = 2 or 7 prints token 12 ("POOR ")

.TT72_C

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
 JSR TT60_C               \
                        \   QQ3 bit 2 = 0 prints token 8 ("INDUSTRIAL")
                        \   QQ3 bit 2 = 1 prints token 9 ("AGRICULTURAL")

 LDA #162               \ Print recursive token 2 ("GOVERNMENT") followed by
 JSR TT68_C               \ a colon

 LDA QQ4                \ The system's government is determined by the value in
                        \ QQ4, so fetch it into A

 CLC                    \ Print recursive token 17 + A, followed by a paragraph
 ADC #177               \ break and Sentence Case, so:
 JSR TT60_C               \
                        \   QQ4 = 0 prints token 17 ("ANARCHY")
                        \   QQ4 = 1 prints token 18 ("FEUDAL")
                        \   QQ4 = 2 prints token 19 ("MULTI-GOVERNMENT")
                        \   QQ4 = 3 prints token 20 ("DICTATORSHIP")
                        \   QQ4 = 4 prints token 21 ("COMMUNIST")
                        \   QQ4 = 5 prints token 22 ("CONFEDERACY")
                        \   QQ4 = 6 prints token 23 ("DEMOCRACY")
                        \   QQ4 = 7 prints token 24 ("CORPORATE STATE")

 LDA #196               \ Print recursive token 36 ("TECH.LEVEL") followed by a
 JSR TT68_C               \ colon

 LDX QQ5                \ Fetch the tech level from QQ5 and increment it, as it
 INX                    \ is stored in the range 0-14 but the displayed range
                        \ should be 1-15

 CLC                    \ Call pr2 to print the technology level as a
 JSR pr2_C                \ three-digit number without a decimal point (by
                        \ clearing the C flag)

 JSR TTX69_C              \ Print a paragraph break and set Sentence Case

 LDA #192               \ Print recursive token 32 ("POPULATION") followed by a
 JSR TT68_C               \ colon

 SEC                    \ Call pr2 to print the population as a three-digit
 LDX QQ6                \ number with a decimal point (by setting the C flag),
 JSR pr2_C                \ so the number printed will be population / 10

 LDA #198               \ Print recursive token 38 (" BILLION"), followed by a
 JSR TT60_C               \ paragraph break and Sentence Case

 LDA #'('               \ Print an opening bracket
 JSR TT27_C

 LDA QQ15+4             \ Now to calculate the species, so first check bit 7 of
 BMI TT75_C               \ s2_lo, and if it is set, jump to TT75 as this is an
                        \ alien species

 LDA #188               \ Bit 7 of s2_lo is clear, so print recursive token 28
 JSR TT27_C               \ ("HUMAN COLONIAL")

 JMP TT76_C               \ Jump to TT76 to print "S)" and a paragraph break, so
                        \ the whole species string is "(HUMAN COLONIALS)"

.TT75_C

 LDA QQ15+5             \ This is an alien species, and we start with the first
 LSR A                  \ adjective, so fetch bits 2-7 of s2_hi into A and push
 LSR A                  \ onto the stack so we can use this later
 PHA

 AND #%00000111         \ Set A = bits 0-2 of A (so that's bits 2-4 of s2_hi)

 CMP #3                 \ If A >= 3, jump to TT205 to skip the first adjective,
 BCS TT205_C

 ADC #227               \ Otherwise A = 0, 1 or 2, so print recursive token
 JSR spc_C                \ 67 + A, followed by a space, so:
                        \
                        \   A = 0 prints token 67 ("LARGE") and a space
                        \   A = 1 prints token 68 ("FIERCE") and a space
                        \   A = 2 prints token 69 ("SMALL") and a space

.TT205_C

 PLA                    \ Now for the second adjective, so restore A to bits
 LSR A                  \ 2-7 of s2_hi, and throw away bits 2-4 to leave
 LSR A                  \ A = bits 5-7 of s2_hi
 LSR A

 CMP #6                 \ If A >= 6, jump to TT206 to skip the second adjective
 BCS TT206_C

 ADC #230               \ Otherwise A = 0 to 5, so print recursive token
 JSR spc_C                \ 70 + A, followed by a space, so:
                        \
                        \   A = 0 prints token 70 ("GREEN") and a space
                        \   A = 1 prints token 71 ("RED") and a space
                        \   A = 2 prints token 72 ("YELLOW") and a space
                        \   A = 3 prints token 73 ("BLUE") and a space
                        \   A = 4 prints token 74 ("BLACK") and a space
                        \   A = 5 prints token 75 ("HARMLESS") and a space

.TT206_C

 LDA QQ15+3             \ Now for the third adjective, so EOR the high bytes of
 EOR QQ15+1             \ s0 and s1 and extract bits 0-2 of the result:
 AND #%00000111         \
 STA QQ19               \   A = (s0_hi EOR s1_hi) AND %111
                        \
                        \ storing the result in QQ19 so we can use it later

 CMP #6                 \ If A >= 6, jump to TT207 to skip the third adjective
 BCS TT207_C

 ADC #236               \ Otherwise A = 0 to 5, so print recursive token
 JSR spc_C                \ 76 + A, followed by a space, so:
                        \
                        \   A = 0 prints token 76 ("SLIMY") and a space
                        \   A = 1 prints token 77 ("BUG-EYED") and a space
                        \   A = 2 prints token 78 ("HORNED") and a space
                        \   A = 3 prints token 79 ("BONY") and a space
                        \   A = 4 prints token 80 ("FAT") and a space
                        \   A = 5 prints token 81 ("FURRY") and a space

.TT207_C

 LDA QQ15+5             \ Now for the actual species, so take bits 0-1 of
 AND #%00000011         \ s2_hi, add this to the value of A that we used for
 CLC                    \ the third adjective, and take bits 0-2 of the result
 ADC QQ19
 AND #%00000111

 ADC #242               \ A = 0 to 7, so print recursive token 82 + A, so:
 JSR TT27_C               \
                        \   A = 0 prints token 82 ("RODENT")
                        \   A = 1 prints token 83 ("FROG")
                        \   A = 2 prints token 84 ("LIZARD")
                        \   A = 3 prints token 85 ("LOBSTER")
                        \   A = 4 prints token 86 ("BIRD")
                        \   A = 5 prints token 87 ("HUMANOID")
                        \   A = 6 prints token 88 ("FELINE")
                        \   A = 7 prints token 89 ("INSECT")

.TT76_C

 LDA #'S'               \ Print an "S" to pluralise the species
 JSR TT27_C

 LDA #')'               \ And finally, print a closing bracket, followed by a
 JSR TT60_C               \ paragraph break and Sentence Case, to end the species
                        \ section

 LDA #193               \ Print recursive token 33 ("GROSS PRODUCTIVITY"),
 JSR TT68_C               \ followed by a colon

 LDX QQ7                \ Fetch the 16-bit productivity value from QQ7 into
 LDY QQ7+1              \ (Y X)

 JSR pr6_C                \ Print (Y X) to 5 digits with no decimal point

 JSR TT162_C              \ Print a space

 STZ QQ17               \ Set QQ17 = 0 to switch to ALL CAPS

 LDA #'M'               \ Print "M"
 JSR TT27_C

 LDA #226               \ Print recursive token 66 (" CR"), followed by a
 JSR TT60_C               \ paragraph break and Sentence Case

 LDA #250               \ Print recursive token 90 ("AVERAGE RADIUS"), followed
 JSR TT68_C               \ by a colon

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

 JSR pr5_C                \ Print (Y X) to 5 digits, not including a decimal
                        \ point, as the C flag will be clear (as the maximum
                        \ radius will always fit into 16 bits)

 JSR TT162_C              \ Print a space

 LDA #'k'               \ Print "km"
 JSR x4_TT26
 LDA #'m'
 JSR x4_TT26

 JSR TTX69_C              \ Print a paragraph break and set Sentence Case

                        \ By this point, ZZ contains the current system number
                        \ which PDESC requires. It gets put there in the TT102
                        \ routine, which calls TT111 to populate ZZ before
                        \ calling TT25 (this routine)

 JMP PDESC_C              \ Jump to PDESC to print the system's extended
                        \ description, returning from the subroutine using a
                        \ tail call

\ ******************************************************************************
\
\       Name: TT24
\       Type: Subroutine
\   Category: Universe
\    Summary: Calculate system data from the system seeds
\  Deep dive: Generating system data
\             Galaxy and system seeds
\
\ ------------------------------------------------------------------------------
\
\ Calculate system data from the seeds in QQ15 and store them in the relevant
\ locations. Specifically, this routine calculates the following from the three
\ 16-bit seeds in QQ15 (using only s0_hi, s1_hi and s1_lo):
\
\   QQ3 = economy (0-7)
\   QQ4 = government (0-7)
\   QQ5 = technology level (0-14)
\   QQ6 = population * 10 (1-71)
\   QQ7 = productivity (96-62480)
\
\ The ranges of the various values are shown in brackets. Note that the radius
\ and type of inhabitant are calculated on-the-fly in the TT25 routine when
\ the system data gets displayed, so they aren't calculated here.
\
\ ******************************************************************************

.TT24_C

 LDA QQ15+1             \ Fetch s0_hi and extract bits 0-2 to determine the
 AND #%00000111         \ system's economy, and store in QQ3
 STA QQ3

 LDA QQ15+2             \ Fetch s1_lo and extract bits 3-5 to determine the
 LSR A                  \ system's government, and store in QQ4
 LSR A
 LSR A
 AND #%00000111
 STA QQ4

 LSR A                  \ If government isn't anarchy or feudal, skip to TT77,
 BNE TT77_C               \ as we need to fix the economy of anarchy and feudal
                        \ systems so they can't be rich

 LDA QQ3                \ Set bit 1 of the economy in QQ3 to fix the economy
 ORA #%00000010         \ for anarchy and feudal governments
 STA QQ3

.TT77_C

 LDA QQ3                \ Now to work out the tech level, which we do like this:
 EOR #%00000111         \
 CLC                    \   flipped_economy + (s1_hi AND %11) + (government / 2)
 STA QQ5                \
                        \ or, in terms of memory locations:
                        \
                        \   QQ5 = (QQ3 EOR %111) + (QQ15+3 AND %11) + (QQ4 / 2)
                        \
                        \ We start by setting QQ5 = QQ3 EOR %111

 LDA QQ15+3             \ We then take the first 2 bits of s1_hi (QQ15+3) and
 AND #%00000011         \ add it into QQ5
 ADC QQ5
 STA QQ5

 LDA QQ4                \ And finally we add QQ4 / 2 and store the result in
 LSR A                  \ QQ5, using LSR then ADC to divide by 2, which rounds
 ADC QQ5                \ up the result for odd-numbered government types
 STA QQ5

 ASL A                  \ Now to work out the population, like so:
 ASL A                  \
 ADC QQ3                \   (tech level * 4) + economy + government + 1
 ADC QQ4                \
 ADC #1                 \ or, in terms of memory locations:
 STA QQ6                \
                        \   QQ6 = (QQ5 * 4) + QQ3 + QQ4 + 1

 LDA QQ3                \ Finally, we work out productivity, like this:
 EOR #%00000111         \
 ADC #3                 \  (flipped_economy + 3) * (government + 4)
 STA P                  \                        * population
 LDA QQ4                \                        * 8
 ADC #4                 \
 STA Q                  \ or, in terms of memory locations:
 JSR x4_MULTU              \
                        \   QQ7 = (QQ3 EOR %111 + 3) * (QQ4 + 4) * QQ6 * 8
                        \
                        \ We do the first step by setting P to the first
                        \ expression in brackets and Q to the second, and
                        \ calling MULTU, so now (A P) = P * Q. The highest this
                        \ can be is 10 * 11 (as the maximum values of economy
                        \ and government are 7), so the high byte of the result
                        \ will always be 0, so we actually have:
                        \
                        \   P = P * Q
                        \     = (flipped_economy + 3) * (government + 4)

 LDA QQ6                \ We now take the result in P and multiply by the
 STA Q                  \ population to get the productivity, by setting Q to
 JSR x4_MULTU              \ the population from QQ6 and calling MULTU again, so
                        \ now we have:
                        \
                        \   (A P) = P * population

 ASL P                  \ Next we multiply the result by 8, as a 16-bit number,
 ROL A                  \ so we shift both bytes to the left three times, using
 ASL P                  \ the C flag to carry bits from bit 7 of the low byte
 ROL A                  \ into bit 0 of the high byte
 ASL P
 ROL A

 STA QQ7+1              \ Finally, we store the productivity in two bytes, with
 LDA P                  \ the low byte in QQ7 and the high byte in QQ7+1
 STA QQ7

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TT22
\       Type: Subroutine
\   Category: Charts
\    Summary: Show the Long-range Chart (red key f4)
\  Deep dive: A sense of scale
\
\ ******************************************************************************

.TT22_C

 LDA #64                \ Clear the top part of the screen, draw a border box,
 JSR TT66_C               \ and set the current view type in QQ11 to 32 (Long-
                        \ range Chart)

 LDA #16                \ Switch to the mode 1 palette for the trade view, which
 JSR x4_DOVDU19            \ is yellow (colour 1), magenta (colour 2) and white
                        \ (colour 3)

 LDA #CYAN              \ Switch to colour 3, which is white in the chart view
 STA COL

 LDA #7                 \ Move the text cursor to column 7
 STA XC

 JSR TT81_C               \ Set the seeds in QQ15 to those of system 0 in the
                        \ current galaxy (i.e. copy the seeds from QQ21 to QQ15)

 LDA #199               \ Print recursive token 39 ("GALACTIC CHART{galaxy
 JSR TT27_C               \ number right-aligned to width 3}")

 JSR NLIN_C               \ Draw a horizontal line at pixel row 23 to box in the
                        \ title and act as the top frame of the chart, and move
                        \ the text cursor down one line

 LDA #GCYB+1            \ Move the text cursor down one line and draw a
 JSR NLIN5_C              \ screen-wide horizontal line at pixel row GCYB+1 (153)
                        \ for the bottom edge of the chart, so the chart itself
                        \ is 128 pixels high, starting on row 24 and ending on
                        \ row 153

 JSR TT14_C               \ Call TT14 to draw a circle with crosshairs at the
                        \ current system's galactic coordinates

 LDX #0                 \ We're now going to plot each of the galaxy's systems,
                        \ so set up a counter in X for each system, starting at
                        \ 0 and looping through to 255

.TT83_C

 STX XSAV               \ Store the counter in XSAV

 LDX QQ15+3             \ Fetch the s1_hi seed into X, which gives us the
                        \ galactic x-coordinate of this system

 LDY QQ15+4             \ Fetch the s2_lo seed and set bits 4 and 6, storing the
 TYA                    \ result in ZZ to give a random number between 80 and
 ORA #%01010000         \ (but which will always be the same for this system).
 STA ZZ                 \ We use this value to determine the size of the point
                        \ for this system on the chart by passing it as the
                        \ distance argument to the PIXEL routine below

 LDA #YELLOW            \ Switch to colour 1, which is yellow
 STA COL

 LDA QQ15+1             \ Fetch the s0_hi seed into A, which gives us the
                        \ galactic y-coordinate of this system

 JSR SCALEY_C             \ We halve the y-coordinate because the galaxy in
                        \ in Elite is rectangular rather than square, and is
                        \ twice as wide (x-axis) as it is high (y-axis), so the
                        \ chart is 256 pixels wide and 128 high
                        \
                        \ The call to SCALEY simply does an LSR A, but having
                        \ this call instruction here would enable different
                        \ scaling to be applied by altering the SCALE routines
                        \
                        \ This code is left over from the Apple II version,
                        \ where the scale factor is different

 CLC                    \ Add GCYT to the halved y-coordinate in A (so the top
 ADC #GCYT              \ of the chart is on pixel row GCYT, just below the line
                        \ we drew on row 23 above)

 JSR x4_PIXEL              \ Call PIXEL to draw a point at (X, A), with the size of
                        \ the point dependent on the distance specified in ZZ
                        \ (so a high value of ZZ will produce a one-pixel point,
                        \ a medium value will produce a two-pixel dash, and a
                        \ small value will produce a four-pixel square)

 JSR TT20_C               \ We want to move on to the next system, so call TT20
                        \ to twist the three 16-bit seeds in QQ15

 LDX XSAV               \ Restore the loop counter from XSAV

 INX                    \ Increment the counter

 BNE TT83_C               \ If X > 0 then we haven't done all 256 systems yet, so
                        \ loop back up to TT83

 LDA QQ9                \ Set QQ19 to the selected system's x-coordinate
 JSR SCALEX_C             \
 STA QQ19               \ The call to SCALEX has no effect as it only contains
                        \ an RTS, but having this call instruction here would
                        \ enable different scaling to be applied by altering
                        \ the SCALE routines
                        \
                        \ This code is left over from the Apple II version,
                        \ where the scale factor is different

 LDA QQ10               \ Set QQ19+1 to the selected system's y-coordinate,
 JSR SCALEY_C             \ halved to fit it into the chart
 STA QQ19+1             \
                        \ The call to SCALEY simply does an LSR A, but having
                        \ this call instruction here would enable different
                        \ scaling to be applied by altering the SCALE routines
                        \
                        \ This code is left over from the Apple II version,
                        \ where the scale factor is different

 LDA #4                 \ Set QQ19+2 to size 4 for the crosshairs size
 STA QQ19+2

 LDA #GREEN             \ Switch to stripe 3-1-3-1, which is white/yellow in the
 STA COL                \ chart view

                        \ Fall through into TT15 to draw crosshairs of size 4 at
                        \ the selected system's coordinates

\ ******************************************************************************
\
\       Name: TT15
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw a set of crosshairs
\
\ ------------------------------------------------------------------------------
\
\ For all views except the Short-range Chart, the centre is drawn 24 pixels to
\ the right of the y-coordinate given.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   QQ19                The pixel x-coordinate of the centre of the crosshairs
\
\   QQ19+1              The pixel y-coordinate of the centre of the crosshairs
\
\   QQ19+2              The size of the crosshairs
\
\ ******************************************************************************

.TT15_C

 LDA #GCYT              \ Set A to GCYT, which we will use as the minimum
                        \ screen indent for the crosshairs (i.e. the minimum
                        \ distance from the top-left corner of the screen)

 LDX QQ11               \ If the current view is not the Short-range Chart,
 BPL TT178_C              \ which is the only view with bit 7 set, then jump to
                        \ TT178 to skip the following instruction

 LDA #0                 \ This is the Short-range Chart, so set A to 0, so the
                        \ crosshairs can go right up against the screen edges

.TT178_C

 STA QQ19+5             \ Set QQ19+5 to A, which now contains the correct indent
                        \ for this view

 LDA QQ19               \ Set A = crosshairs x-coordinate - crosshairs size
 SEC                    \ to get the x-coordinate of the left edge of the
 SBC QQ19+2             \ crosshairs

 BIT QQ11               \ If bit 7 of QQ11 is set, then this this is the
 BMI TT84_C               \ Short-range Chart, so jump to TT84

 BCC botchfix13_C         \ If the above subtraction underflowed, then A is
                        \ positive, so skip the next two instructions

 CMP #2                 \ If A >= 2, skip the next instruction
 BCS TT84_C

.botchfix13_C

 LDA #2                 \ The subtraction underflowed or A < 2, so set A to 2
                        \ so the crosshairs don't spill out of the left of the
                        \ screen

.TT84_C

 STA X1                 \ Set X1 = A (the x-coordinate of the left edge of the
                        \ crosshairs)

 LDA QQ19               \ Set A = crosshairs x-coordinate + crosshairs size
 CLC                    \ to get the x-coordinate of the right edge of the
 ADC QQ19+2             \ crosshairs

\BIT QQ11               \ These instructions are commented out in the original
\BMI TT85               \ source

 BCS botchfix12_C         \ If the above addition overflowed, skip the following
                        \ two instructions to set A = 254

 CMP #254               \ The addition didn't overflow, so if A < 254, jump to
 BCC TT85_C               \ TT85

.botchfix12_C

 LDA #254               \ Set A = 254, so the crosshairs don't spill out of the
                        \ right of the screen

.TT85_C

 STA X2                 \ Set X2 = A (the x-coordinate of the right edge of the
                        \ crosshairs)

 LDA QQ19+1             \ Set Y1 = crosshairs y-coordinate + indent to get the
 CLC                    \ y-coordinate of the centre of the crosshairs
 ADC QQ19+5
 STA Y1

 JSR x4_HLOIN3             \ Call HLOIN3 to draw a line from (X1, Y1) to (X2, Y1)

 LDA QQ19+1             \ Set A = crosshairs y-coordinate - crosshairs size
 SEC                    \ to get the y-coordinate of the top edge of the
 SBC QQ19+2             \ crosshairs

 BCS TT86_C               \ If the above subtraction didn't underflow, then A is
                        \ correct, so skip the next instruction

 LDA #0                 \ The subtraction underflowed, so set A to 0 so the
                        \ crosshairs don't spill out of the top of the screen

.TT86_C

 CLC                    \ Set Y1 = A + indent to get the y-coordinate of the top
 ADC QQ19+5             \ edge of the indented crosshairs
 STA Y1

 LDA QQ19+1             \ Set A = crosshairs y-coordinate + crosshairs size
 CLC                    \ + indent to get the y-coordinate of the bottom edge
 ADC QQ19+2             \ of the indented crosshairs
 ADC QQ19+5

 CMP #GCYB              \ If A < GCYB then skip the following, as the crosshairs
 BCC TT87_C               \ won't spill out of the bottom of the screen

 LDX QQ11               \ A >= 152, so we need to check whether this will fit in
                        \ this view, so fetch the view type

 BMI TT87_C               \ If this is the Short-range Chart then the y-coordinate
                        \ is fine, so skip to TT87

 LDA #GCYB              \ Otherwise this is the Long-range Chart, so we need to
                        \ clip the crosshairs at a maximum y-coordinate of GCYB

.TT87_C

 STA Y2                 \ Set Y2 = A (the y-coordinate of the bottom edge of the
                        \ crosshairs)

 LDA QQ19               \ Set X1 = the x-coordinate of the centre of the
 STA X1                 \ crosshairs

 STA X2                 \ Set X2 = the x-coordinate of the centre of the
                        \ crosshairs

 JMP x4_LOIN               \ Draw a vertical line from (X1, Y1) to (X2, Y2), which
                        \ will draw from the top edge of the crosshairs to the
                        \ bottom edge, through the centre of the crosshairs,
                        \ and returning from the subroutine using a tail call

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

.TT126_C

 LDA #104               \ Set QQ19 = 104, for the x-coordinate of the centre of
 STA QQ19               \ the fixed circle on the Short-range Chart

 LDA #90                \ Set QQ19+1 = 90, for the y-coordinate of the centre of
 STA QQ19+1             \ the fixed circle on the Short-range Chart

 LDA #16                \ Set QQ19+2 = 16, the size of the crosshairs on the
 STA QQ19+2             \ Short-range Chart

 LDA #GREEN             \ Switch to stripe 3-1-3-1, which is white/yellow in the
 STA COL                \ chart view

 JSR TT15_C               \ Draw the set of crosshairs defined in QQ19, at the
                        \ exact coordinates as this is the Short-range Chart

 LDA QQ14               \ Set K to the fuel level from QQ14, so this can act as
 JSR SCALEY2_C            \ the circle's radius (70 being a full tank)
 STA K                  \
                        \ The call to SCALEY2 has no effect as it only contains
                        \ an RTS, but having this call instruction here would
                        \ enable different scaling to be applied by altering
                        \ the SCALE routines
                        \
                        \ This code is left over from the Apple II version,
                        \ where the scale factor is different

 JMP TT128_C              \ Jump to TT128 to draw a circle with the centre at the
                        \ same coordinates as the crosshairs, (QQ19, QQ19+1),
                        \ and radius K that reflects the current fuel levels,
                        \ returning from the subroutine using a tail call

.TT14_C

 LDA QQ11               \ If the current view is the Short-range Chart, which
 BMI TT126_C              \ is the only view with bit 7 set, then jump up to TT126
                        \ to draw the crosshairs and circle for that view

                        \ Otherwise this is the Long-range Chart, so we draw the
                        \ crosshairs and circle for that view instead

 LDA QQ14               \ Set K to the fuel level from QQ14 divided by 4, so
 LSR A                  \ this can act as the circle's radius (70 being a full
 JSR SCALEY_C             \ tank, which divides down to a radius of 17)
 STA K                  \
                        \ The call to SCALEY simply does an LSR A, but having
                        \ this call instruction here would enable different
                        \ scaling to be applied by altering the SCALE routines
                        \
                        \ This code is left over from the Apple II version,
                        \ where the scale factor is different

 LDA QQ0                \ Set QQ19 to the x-coordinate of the current system,
 JSR SCALEX_C             \ which will be the centre of the circle and crosshairs
 STA QQ19               \ we draw
                        \
                        \ The call to SCALEX has no effect as it only contains
                        \ an RTS, but having this call instruction here would
                        \ enable different scaling to be applied by altering
                        \ the SCALE routines
                        \
                        \ This code is left over from the Apple II version,
                        \ where the scale factor is different

 LDA QQ1                \ Set QQ19+1 to the y-coordinate of the current system,
 JSR SCALEY_C             \ halved because the galactic chart is half as high as
 STA QQ19+1             \ it is wide, which will again be the centre of the
                        \ circle and crosshairs we draw
                        \
                        \ Again, the call to SCALEY simply does an LSR A (see
                        \ the comment above)

 LDA #7                 \ Set QQ19+2 = 7, the size of the crosshairs on the
 STA QQ19+2             \ Long-range Chart

 LDA #CYAN              \ Switch to colour 3, which is white in the chart view
 STA COL

 JSR TT15_C               \ Draw the set of crosshairs defined in QQ19, which will
                        \ be drawn 24 pixels to the right of QQ19+1

 LDA QQ19+1             \ Add GCYT to the y-coordinate of the crosshairs in
 CLC                    \ QQ19+1 so that the centre of the circle matches the
 ADC #GCYT              \ centre of the crosshairs
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

.TT128_C

 LDA QQ19               \ Set K3 = the x-coordinate of the centre
 STA K3

 LDA QQ19+1             \ Set K4 = the y-coordinate of the centre
 STA K4

 STZ K4+1               \ Set the high bytes of K3(1 0) and K4(1 0) to 0
 STZ K3+1

 LDX #1                 \ Set LSP = 1 to reset the ball line heap
 STX LSP

 INX                    \ Set STP = 2, the step size for the circle
 STX STP

 LDA #RED               \ Switch to colour 2, which is red in the chart view
 STA COL

 JMP x4_CIRCLE2            \ Jump to CIRCLE2 to draw a circle with the centre at
                        \ (K3(1 0), K4(1 0)) and radius K, returning from the
                        \ subroutine using a tail call

\ ******************************************************************************
\
\       Name: TT16
\       Type: Subroutine
\   Category: Charts
\    Summary: Move the crosshairs on a chart
\
\ ------------------------------------------------------------------------------
\
\ Move the chart crosshairs by the amount in X and Y.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The amount to move the crosshairs in the x-axis
\
\   Y                   The amount to move the crosshairs in the y-axis
\
\ ******************************************************************************

.TT16_C

 TXA                    \ Push the change in X onto the stack (let's call this
 PHA                    \ the x-delta)

 DEY                    \ Negate the change in Y and push it onto the stack
 TYA                    \ (let's call this the y-delta)
 EOR #&FF
 PHA

 JSR x4_WSCAN              \ Call WSCAN to wait for the vertical sync, so the whole
                        \ screen gets drawn and we can move the crosshairs with
                        \ no screen flicker

 JSR TT103_C              \ Draw small crosshairs at coordinates (QQ9, QQ10),
                        \ which will erase the crosshairs currently there

 PLA                    \ Store the y-delta in QQ19+3 and fetch the current
 STA QQ19+3             \ y-coordinate of the crosshairs from QQ10 into A, ready
 LDA QQ10               \ for the call to TT123

 JSR TT123_C              \ Call TT123 to move the selected system's galactic
                        \ y-coordinate by the y-delta, putting the new value in
                        \ QQ19+4

 LDA QQ19+4             \ Store the updated y-coordinate in QQ10 (the current
 STA QQ10               \ y-coordinate of the crosshairs)

 STA QQ19+1             \ This instruction has no effect, as QQ19+1 is
                        \ overwritten below, both in TT103 and TT105

 PLA                    \ Store the x-delta in QQ19+3 and fetch the current
 STA QQ19+3             \ x-coordinate of the crosshairs from QQ10 into A, ready
 LDA QQ9                \ for the call to TT123

 JSR TT123_C              \ Call TT123 to move the selected system's galactic
                        \ x-coordinate by the x-delta, putting the new value in
                        \ QQ19+4

 LDA QQ19+4             \ Store the updated x-coordinate in QQ9 (the current
 STA QQ9                \ x-coordinate of the crosshairs)

 STA QQ19               \ This instruction has no effect, as QQ19 is overwritten
                        \ below, both in TT103 and TT105

                        \ Now we've updated the coordinates of the crosshairs,
                        \ fall through into TT103 to redraw them at their new
                        \ location

\ ******************************************************************************
\
\       Name: TT103
\       Type: Subroutine
\   Category: Charts
\    Summary: Draw a small set of crosshairs on a chart
\
\ ------------------------------------------------------------------------------
\
\ Draw a small set of crosshairs on a galactic chart at the coordinates in
\ (QQ9, QQ10).
\
\ ******************************************************************************

.TT103_C

 LDA #GREEN             \ Switch to stripe 3-1-3-1, which is white/yellow in the
 STA COL                \ chart view

 LDA QQ11               \ Fetch the current view type into A

 BMI TT105_C              \ If this is the Short-range Chart screen, jump to TT105

 LDA QQ9                \ Store the crosshairs x-coordinate in QQ19
 JSR SCALEX_C             \
 STA QQ19               \ The call to SCALEX has no effect as it only contains
                        \ an RTS, but having this call instruction here would
                        \ enable different scaling to be applied by altering
                        \ the SCALE routines
                        \
                        \ This code is left over from the Apple II version,
                        \ where the scale factor is different

 LDA QQ10               \ Halve the crosshairs y-coordinate and store it in QQ19
 JSR SCALEY_C             \ (we halve it because the Long-range Chart is half as
 STA QQ19+1             \ high as it is wide)
                        \
                        \ The call to SCALEY simply does an LSR A, but having
                        \ this call instruction here would enable different
                        \ scaling to be applied by altering the SCALE routines
                        \
                        \ This code is left over from the Apple II version,
                        \ where the scale factor is different

 LDA #4                 \ Set QQ19+2 to 4 denote crosshairs of size 4
 STA QQ19+2

 JMP TT15_C               \ Jump to TT15 to draw crosshairs of size 4 at the
                        \ crosshairs coordinates, returning from the subroutine
                        \ using a tail call

\ ******************************************************************************
\
\       Name: TT123
\       Type: Subroutine
\   Category: Charts
\    Summary: Move galactic coordinates by a signed delta
\
\ ------------------------------------------------------------------------------
\
\ Move an 8-bit galactic coordinate by a certain distance in either direction
\ (i.e. a signed 8-bit delta), but only if it doesn't cause the coordinate to
\ overflow. The coordinate is in a single axis, so it's either an x-coordinate
\ or a y-coordinate.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The galactic coordinate to update
\
\   QQ19+3              The delta (can be positive or negative)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   QQ19+4              The updated coordinate after moving by the delta (this
\                       will be the same as A if moving by the delta overflows)
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   TT180               Contains an RTS
\
\ ******************************************************************************

.TT123_C

 STA QQ19+4             \ Store the original coordinate in temporary storage at
                        \ QQ19+4

 CLC                    \ Set A = A + QQ19+3, so A now contains the original
 ADC QQ19+3             \ coordinate, moved by the delta

 LDX QQ19+3             \ If the delta is negative, jump to TT124
 BMI TT124_C

 BCC TT125_C              \ If the C flag is clear, then the above addition didn't
                        \ overflow, so jump to TT125 to return the updated value

 RTS                    \ Otherwise the C flag is set and the above addition
                        \ overflowed, so do not update the return value

.TT124_C

 BCC TT180_C              \ If the C flag is clear, then because the delta is
                        \ negative, this indicates the addition (which is
                        \ effectively a subtraction) underflowed, so jump to
                        \ TT180 to return from the subroutine without updating
                        \ the return value

.TT125_C

 STA QQ19+4             \ Store the updated coordinate in QQ19+4

.TT180_C

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TT105
\       Type: Subroutine
\   Category: Charts
\    Summary: Draw crosshairs on the Short-range Chart, with clipping
\
\ ------------------------------------------------------------------------------
\
\ Check whether the crosshairs are close enough to the current system to appear
\ on the Short-range Chart, and if so, draw them.
\
\ ******************************************************************************

.TT105_C

 LDA QQ9                \ Set A = QQ9 - QQ0, the horizontal distance between the
 SEC                    \ crosshairs (QQ9) and the current system (QQ0)
 SBC QQ0

 BCS P%+6               \ If the subtraction didn't underflow, skip the next two
                        \ instructions

 EOR #&FF               \ The subtraction underflowed, so negate the result
 ADC #1                 \ using two's complement so that it is positive, i.e.
                        \ A = |QQ9 - QQ0|, the absolute horizontal distance

 CMP #29                \ If the absolute horizontal distance in A >= 29, then
 BCS TT180_C              \ the crosshairs are too far from the current system to
                        \ appear in the Short-range Chart, so jump to TT180 to
                        \ return from the subroutine (as TT180 contains an RTS)

 LDA QQ9                \ Set A = QQ9 - QQ0, the horizontal distance between the
 SEC                    \ crosshairs (QQ9) and the current system (QQ0)
 SBC QQ0

 BPL TT179_C              \ If the horizontal distance in A is positive, then skip
                        \ the next two instructions

 CMP #233               \ If the horizontal distance in A < -23, then the
 BCC TT180_C              \ crosshairs are too far from the current system to
                        \ appear in the Short-range Chart, so jump to TT180 to
                        \ return from the subroutine (as TT180 contains an RTS)

.TT179_C

 ASL A                  \ Set QQ19 = 104 + A * 4
 ASL A                  \
 CLC                    \ 104 is the x-coordinate of the centre of the chart,
 ADC #104               \ so this sets QQ19 to the screen pixel x-coordinate
 JSR SCALEY2_C            \
 STA QQ19               \ The call to SCALEY2 has no effect as it only contains
                        \ an RTS, but having this call instruction here would
                        \ enable different scaling to be applied by altering
                        \ the SCALE routines
                        \
                        \ This code is left over from the Apple II version,
                        \ where the scale factor is different

 LDA QQ10               \ Set A = QQ10 - QQ1, the vertical distance between the
 SEC                    \ crosshairs (QQ10) and the current system (QQ1)
 SBC QQ1

 BCS P%+6               \ If the subtraction didn't underflow, skip the next two
                        \ instructions

 EOR #&FF               \ The subtraction underflowed, so negate the result
 ADC #1                 \ using two's complement so that it is positive, i.e.
                        \ A = |QQ10 - QQ0|, the absolute vertical distance

 CMP #35                \ If the absolute vertical distance in A >= 35, then
 BCS TT180_C              \ the crosshairs are too far from the current system to
                        \ appear in the Short-range Chart, so jump to TT180 to
                        \ return from the subroutine (as TT180 contains an RTS)

 LDA QQ10               \ Set A = QQ10 - QQ1, the vertical distance between the
 SEC                    \ crosshairs (QQ10) and the current system (QQ1)
 SBC QQ1

 ASL A                  \ Set QQ19+1 = 90 + A * 2
 CLC                    \
 ADC #90                \ 90 is the y-coordinate of the centre of the chart,
 JSR SCALEY2_C            \ so this sets QQ19+1 to the screen pixel x-coordinate
 STA QQ19+1             \ of the crosshairs
                        \
                        \ The call to SCALEY2 has no effect as it only contains
                        \ an RTS, but having this call instruction here would
                        \ enable different scaling to be applied by altering
                        \ the SCALE routines
                        \
                        \ This code is left over from the Apple II version,
                        \ where the scale factor is different

 LDA #8                 \ Set QQ19+2 to 8 denote crosshairs of size 8
 STA QQ19+2

 LDA #GREEN             \ Switch to stripe 3-1-3-1, which is white/yellow in the
 STA COL                \ chart view

 JMP TT15_C               \ Jump to TT15 to draw crosshairs of size 8 at the
                        \ crosshairs coordinates, returning from the subroutine
                        \ using a tail call

\ ******************************************************************************
\
\       Name: TT23
\       Type: Subroutine
\   Category: Charts
\    Summary: Show the Short-range Chart (red key f5)
\
\ ******************************************************************************

.TT23_C

 LDA #128               \ Clear the top part of the screen, draw a border box,
 JSR TT66_C               \ and set the current view type in QQ11 to 128 (Short-
                        \ range Chart)

 LDA #16                \ Switch to the mode 1 palette for the trade view, which
 JSR x4_DOVDU19            \ is yellow (colour 1), magenta (colour 2) and white
                        \ (colour 3)

 LDA #CYAN              \ Switch to colour 3, which is white in the chart view
 STA COL

 LDA #7                 \ Move the text cursor to column 7
 STA XC

 LDA #190               \ Print recursive token 30 ("SHORT RANGE CHART") and
 JSR NLIN3_C              \ draw a horizontal line at pixel row 19 to box in the
                        \ title

 JSR TT14_C               \ Call TT14 to draw a circle with crosshairs at the
                        \ current system's galactic coordinates

 JSR TT103_C              \ Draw small crosshairs at coordinates (QQ9, QQ10),
                        \ i.e. at the selected system

 JSR TT81_C               \ Set the seeds in QQ15 to those of system 0 in the
                        \ current galaxy (i.e. copy the seeds from QQ21 to QQ15)

 LDA #CYAN              \ Switch to colour 3, which is white in the chart view
 STA COL

 LDA #0                 \ Set A = 0, which we'll use below to zero out the INWK
                        \ workspace

 STA XX20               \ We're about to start working our way through each of
                        \ the galaxy's systems, so set up a counter in XX20 for
                        \ each system, starting at 0 and looping through to 255

 LDX #24                \ First, though, we need to zero out the 25 bytes at
                        \ INWK so we can use them to work out which systems have
                        \ room for a label, so set a counter in X for 25 bytes

.EE3_C

 STA INWK,X             \ Set the X-th byte of INWK to zero

 DEX                    \ Decrement the counter

 BPL EE3_C                \ Loop back to EE3 for the next byte until we've zeroed
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

.TT182_C

 LDA QQ15+3             \ Set A = s1_hi - QQ0, the horizontal distance between
 SEC                    \ (s1_hi, s0_hi) and (QQ0, QQ1)
 SBC QQ0

 BCS TT184_C              \ If a borrow didn't occur, i.e. s1_hi >= QQ0, then the
                        \ result is positive, so jump to TT184 and skip the
                        \ following two instructions

 EOR #&FF               \ Otherwise negate the result in A, so A is always
 ADC #1                 \ positive (i.e. A = |s1_hi - QQ0|)

.TT184_C

 CMP #29                \ If the horizontal distance in A is >= 29, then this
 BCS TT187s_C             \ system is too far away from the current system to
                        \ appear in the Short-range Chart, so jump to TT187 via
                        \ TT187s to move on to the next system

 LDA QQ15+1             \ Set A = s0_hi - QQ1, the vertical distance between
 SEC                    \ (s1_hi, s0_hi) and (QQ0, QQ1)
 SBC QQ1

 BCS TT186_C              \ If a borrow didn't occur, i.e. s0_hi >= QQ1, then the
                        \ result is positive, so jump to TT186 and skip the
                        \ following two instructions

 EOR #&FF               \ Otherwise negate the result in A, so A is always
 ADC #1                 \ positive (i.e. A = |s0_hi - QQ1|)

.TT186_C

 CMP #40                \ If the vertical distance in A is >= 40, then this
 BCS TT187s_C             \ system is too far away from the current system to
                        \ appear in the Short-range Chart, so jump to TT187 via
                        \ TT187s to move on to the next system

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
 JSR SCALEY2_C            \ so this sets XX12 to the centre 104 +/- 76, the pixel
 STA XX12               \ x-coordinate of this system
                        \
                        \ The call to SCALEY2 has no effect as it only contains
                        \ an RTS, but having this call instruction here would
                        \ enable different scaling to be applied by altering
                        \ the SCALE routines
                        \
                        \ This code is left over from the Apple II version,
                        \ where the scale factor is different

 LSR A                  \ Move the text cursor to column x-delta / 2 + 1
 LSR A                  \ which will be in the range 1-10
 LSR A
 INC A
 STA XC

 LDA QQ15+1             \ Set A = s0_hi - QQ1, the vertical distance between
 SEC                    \ this system and the current system, where |A| < 38.
 SBC QQ1                \ Let's call this the y-delta, as it's the vertical
                        \ difference between the current system at the centre of
                        \ the chart, and this system (and this time we keep the
                        \ sign of A, so it can be negative if it's above the
                        \ chart's centre, or positive if it's below)

 ASL A                  \ Set K4 = 90 + y-delta * 2
 ADC #90                \
 JSR SCALEY2_C            \ 90 is the y-coordinate of the centre of the chart,
 STA K4                 \ so this sets K4 to the centre 90 +/- 74, the pixel
                        \ y-coordinate of this system
                        \
                        \ The call to SCALEY2 has no effect as it only contains
                        \ an RTS, but having this call instruction here would
                        \ enable different scaling to be applied by altering
                        \ the SCALE routines
                        \
                        \ This code is left over from the Apple II version,
                        \ where the scale factor is different

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
 BEQ EE4_C                \ containing this system does not already have another
                        \ system's label on it), jump to EE4 to store this
                        \ system's label on this row

 INY                    \ If the value in INWK+Y+1 is 0 (i.e. the text row below
 LDX INWK,Y             \ the one containing this system does not already have
 BEQ EE4_C                \ another system's label on it), jump to EE4 to store
                        \ this system's label on this row

 DEY                    \ If the value in INWK+Y-1 is 0 (i.e. the text row above
 DEY                    \ the one containing this system does not already have
 LDX INWK,Y             \ another system's label on it), fall through into to
 BNE ee1_C                \ EE4 to store this system's label on this row,
                        \ otherwise jump to ee1 to skip printing a label for
                        \ this system (as there simply isn't room)

.EE4_C

 STY YC                 \ Now to print the label, so move the text cursor to row
                        \ Y (which contains the row where we can print this
                        \ system's label)

 CPY #3                 \ If Y < 3, then the system would clash with the chart
 BCC TT187_C              \ title, so jump to TT187 to skip showing the system

 CPY #21                \ If Y > 21, then the label will be off the bottom of
 BCS TT187_C              \ the chart, so jump to TT187 to skip showing the system

 TYA                    \ Store Y on the stack so it can be preserved across the
 PHA                    \ call to readdistnce

 LDA QQ15+3             \ Set A = s1_hi, so A contains the galactic x-coordinate
                        \ of the system we are displaying on the chart

 JSR readdistnce_C        \ Call readdistnce to calculate the distance between the
                        \ system with galactic coordinates (A, QQ15+1) - i.e.
                        \ the system we are displaying - and the current system
                        \ at (QQ0, QQ1), returning the result in QQ8(1 0)

 PLA                    \ Restore Y from the stack
 TAY

 LDA QQ8+1              \ If the high byte of the distance in QQ8(1 0) is
 BNE TT187_C              \ non-zero, jump to TT187 to skip showing the system as
                        \ it is too far away from the current system

 LDA QQ8                \ If the low byte of the distance in QQ8(1 0) is >= 70,
 CMP #70                \ jump to TT187 to skip showing the system as it is too
                        \ far away from the current system

.TT187s_C

 BCS TT187_C              \ If we get here from the instruction above, we jump to
                        \ TT187 if QQ8(1 0) >= 70, so we only show systems that
                        \ are within distance 70 (i.e. 7 light years) of the
                        \ current system
                        \
                        \ If we jump here from elsewhere with a BCS TT187s, we
                        \ jump straight on to TT187

 LDA #&FF               \ Store &FF in INWK+Y, to denote that this row is now
 STA INWK,Y             \ occupied so we don't try to print another system's
                        \ label on this row

 LDA #%10000000         \ Set bit 7 of QQ17 to switch to Sentence Case
 STA QQ17

 JSR cpl_C                \ Call cpl to print out the system name for the seeds
                        \ in QQ15 (which now contains the seeds for the current
                        \ system)

.ee1_C

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

 JSR x4_FLFLLS             \ Call FLFLLS to reset the LSO block

 JSR x4_SUN                \ Call SUN to plot a sun with radius K at pixel
                        \ coordinate (K3, K4)

 JSR x4_FLFLLS             \ Call FLFLLS to reset the LSO block

 LDA #CYAN              \ Switch to colour 3, which is white in the chart view
 STA COL

.TT187_C

 JSR TT20_C               \ We want to move on to the next system, so call TT20
                        \ to twist the three 16-bit seeds in QQ15

 INC XX20               \ Increment the counter

 BEQ P%+5               \ If X = 0 then we have done all 256 systems, so skip
                        \ the next instruction to return from the subroutine

 JMP TT182_C              \ Otherwise jump back up to TT182 to process the next
                        \ system

\LDA #0                 \ These instructions are commented out in the original
\STA dontclip           \ source
\
\LDA #2*Y-1
\STA Yx2M1

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TT81
\       Type: Subroutine
\   Category: Universe
\    Summary: Set the selected system's seeds to those of system 0
\
\ ------------------------------------------------------------------------------
\
\ Copy the three 16-bit seeds for the current galaxy's system 0 (QQ21) into the
\ seeds for the selected system (QQ15) - in other words, set the selected
\ system's seeds to those of system 0.
\
\ ******************************************************************************

.TT81_C

 LDX #5                 \ Set up a counter in X to copy six bytes (for three
                        \ 16-bit numbers)

 LDA QQ21,X             \ Copy the X-th byte in QQ21 to the X-th byte in QQ15
 STA QQ15,X

 DEX                    \ Decrement the counter

 BPL TT81_C+2             \ Loop back up to the LDA instruction if we still have
                        \ more bytes to copy

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TT111
\       Type: Subroutine
\   Category: Universe
\    Summary: Set the current system to the nearest system to a point
\
\ ------------------------------------------------------------------------------
\
\ Given a set of galactic coordinates in (QQ9, QQ10), find the nearest system
\ to this point in the galaxy, and set this as the currently selected system.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   QQ9                 The x-coordinate near which we want to find a system
\
\   QQ10                The y-coordinate near which we want to find a system
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   QQ8(1 0)            The distance from the current system to the nearest
\                       system to the original coordinates
\
\   QQ9                 The x-coordinate of the nearest system to the original
\                       coordinates
\
\   QQ10                The y-coordinate of the nearest system to the original
\                       coordinates
\
\   QQ15 to QQ15+5      The three 16-bit seeds of the nearest system to the
\                       original coordinates
\
\   ZZ                  The system number of the nearest system
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   TT111-1             Contains an RTS
\
\   readdistnce         Calculate the distance between the system with galactic
\                       coordinates (A, QQ15+1) and the system at (QQ0, QQ1),
\                       returning the result in QQ8(1 0)
\
\ ******************************************************************************

.TT111_C

 JSR TT81_C               \ Set the seeds in QQ15 to those of system 0 in the
                        \ current galaxy (i.e. copy the seeds from QQ21 to QQ15)

                        \ We now loop through every single system in the galaxy
                        \ and check the distance from (QQ9, QQ10). We get the
                        \ galactic coordinates of each system from the system's
                        \ seeds, like this:
                        \
                        \   x = s1_hi (which is stored in QQ15+3)
                        \   y = s0_hi (which is stored in QQ15+1)
                        \
                        \ so the following loops through each system in the
                        \ galaxy in turn and calculates the distance between
                        \ (QQ9, QQ10) and (s1_hi, s0_hi) to find the closest one

 LDY #127               \ Set Y = T = 127 to hold the shortest distance we've
 STY T                  \ found so far, which we initially set to half the
                        \ distance across the galaxy, or 127, as our coordinate
                        \ system ranges from (0,0) to (255, 255)

 LDA #0                 \ Set A = U = 0 to act as a counter for each system in
 STA U                  \ the current galaxy, which we start at system 0 and
                        \ loop through to 255, the last system

.TT130_C

 LDA QQ15+3             \ Set A = s1_hi - QQ9, the horizontal distance between
 SEC                    \ (s1_hi, s0_hi) and (QQ9, QQ10)
 SBC QQ9

 BCS TT132_C              \ If a borrow didn't occur, i.e. s1_hi >= QQ9, then the
                        \ result is positive, so jump to TT132 and skip the
                        \ following two instructions

 EOR #&FF               \ Otherwise negate the result in A, so A is always
 ADC #1                 \ positive (i.e. A = |s1_hi - QQ9|)

.TT132_C

 LSR A                  \ Set S = A / 2
 STA S                  \       = |s1_hi - QQ9| / 2

 LDA QQ15+1             \ Set A = s0_hi - QQ10, the vertical distance between
 SEC                    \ (s1_hi, s0_hi) and (QQ9, QQ10)
 SBC QQ10

 BCS TT134_C              \ If a borrow didn't occur, i.e. s0_hi >= QQ10, then the
                        \ result is positive, so jump to TT134 and skip the
                        \ following two instructions

 EOR #&FF               \ Otherwise negate the result in A, so A is always
 ADC #1                 \ positive (i.e. A = |s0_hi - QQ10|)

.TT134_C

 LSR A                  \ Set A = S + A / 2
 CLC                    \       = |s1_hi - QQ9| / 2 + |s0_hi - QQ10| / 2
 ADC S                  \
                        \ So A now contains the sum of the horizontal and
                        \ vertical distances, both divided by 2 so the result
                        \ fits into one byte, and although this doesn't contain
                        \ the actual distance between the systems, it's a good
                        \ enough approximation to use for comparing distances

 CMP T                  \ If A >= T, then this system's distance is bigger than
 BCS TT135_C              \ our "minimum distance so far" stored in T, so it's no
                        \ closer than the systems we have already found, so
                        \ skip to TT135 to move on to the next system

 STA T                  \ This system is the closest to (QQ9, QQ10) so far, so
                        \ update T with the new "distance" approximation

 LDX #5                 \ As this system is the closest we have found yet, we
                        \ want to store the system's seeds in case it ends up
                        \ being the closest of all, so we set up a counter in X
                        \ to copy six bytes (for three 16-bit numbers)

.TT136_C

 LDA QQ15,X             \ Copy the X-th byte in QQ15 to the X-th byte in QQ19,
 STA QQ19,X             \ where QQ15 contains the seeds for the system we just
                        \ found to be the closest so far, and QQ19 is temporary
                        \ storage

 DEX                    \ Decrement the counter

 BPL TT136_C              \ Loop back to TT136 if we still have more bytes to
                        \ copy

 LDA U                  \ Store the system number U in ZZ, so when we are done
 STA ZZ                 \ looping through all the candidates, the winner's
                        \ number will be in ZZ

.TT135_C

 JSR TT20_C               \ We want to move on to the next system, so call TT20
                        \ to twist the three 16-bit seeds in QQ15

 INC U                  \ Increment the system counter in U

 BNE TT130_C              \ If U > 0 then we haven't done all 256 systems yet, so
                        \ loop back up to TT130

                        \ We have now finished checking all the systems in the
                        \ galaxy, and the seeds for the closest system are in
                        \ QQ19, so now we want to copy these seeds to QQ15,
                        \ to set the selected system to this closest system

 LDX #5                 \ So we set up a counter in X to copy six bytes (for
                        \ three 16-bit numbers)

.TT137_C

 LDA QQ19,X             \ Copy the X-th byte in QQ19 to the X-th byte in QQ15
 STA QQ15,X

 DEX                    \ Decrement the counter

 BPL TT137_C              \ Loop back to TT137 if we still have more bytes to
                        \ copy

 LDA QQ15+1             \ The y-coordinate of the system described by the seeds
 STA QQ10               \ in QQ15 is in QQ15+1 (s0_hi), so we copy this to QQ10
                        \ as this is where we store the selected system's
                        \ y-coordinate

 LDA QQ15+3             \ The x-coordinate of the system described by the seeds
 STA QQ9                \ in QQ15 is in QQ15+3 (s1_hi), so we copy this to QQ9
                        \ as this is where we store the selected system's
                        \ x-coordinate

                        \ We have now found the closest system to (QQ9, QQ10)
                        \ and have set it as the selected system, so now we
                        \ need to work out the distance between the selected
                        \ system and the current system

.readdistnce_C

 SEC                    \ Set A = QQ9 - QQ0, the horizontal distance between
 SBC QQ0                \ the selected system's x-coordinate (QQ9) and the
                        \ current system's x-coordinate (QQ0)

 BCS TT139_C              \ If a borrow didn't occur, i.e. QQ9 >= QQ0, then the
                        \ result is positive, so jump to TT139 and skip the
                        \ following two instructions

 EOR #&FF               \ Otherwise negate the result in A, so A is always
 ADC #1                 \ positive (i.e. A = |QQ9 - QQ0|)

                        \ A now contains the difference between the two
                        \ systems' x-coordinates, with the sign removed. We
                        \ will refer to this as the x-delta ("delta" means
                        \ change or difference in maths)

.TT139_C

 JSR x4_SQUA2              \ Set (A P) = A * A
                        \           = |QQ9 - QQ0| ^ 2
                        \           = x_delta ^ 2

 STA K+1                \ Store (A P) in K(1 0)
 LDA P
 STA K

 LDA QQ15+1             \ Set A = QQ15+1 - QQ1, the vertical distance between
\LDA QQ10               \ the selected system's y-coordinate (QQ15+1) and the
 SEC                    \ current system's y-coordinate (QQ1)
 SBC QQ1                \
                        \ The LDA instruction is commented out in the original
                        \ source

 BCS TT141_C              \ If a borrow didn't occur, i.e. QQ10 >= QQ1, then the
                        \ result is positive, so jump to TT141 and skip the
                        \ following two instructions

 EOR #&FF               \ Otherwise negate the result in A, so A is always
 ADC #1                 \ positive (i.e. A = |QQ10 - QQ1|)

.TT141_C

 LSR A                  \ Set A = A / 2

                        \ A now contains the difference between the two
                        \ systems' y-coordinates, with the sign removed, and
                        \ halved. We halve the value because the galaxy in
                        \ in Elite is rectangular rather than square, and is
                        \ twice as wide (x-axis) as it is high (y-axis), so to
                        \ get a distance that matches the shape of the
                        \ long-range galaxy chart, we need to halve the
                        \ distance between the vertical y-coordinates. We will
                        \ refer to this as the y-delta

 JSR x4_SQUA2              \ Set (A P) = A * A
                        \           = (|QQ10 - QQ1| / 2) ^ 2
                        \           = y_delta ^ 2

                        \ By this point we have the following results:
                        \
                        \   K(1 0) = x_delta ^ 2
                        \    (A P) = y_delta ^ 2
                        \
                        \ so to find the distance between the two points, we
                        \ can use Pythagoras - so first we need to add the two
                        \ results together, and then take the square root

 PHA                    \ Store the high byte of the y-axis value on the stack,
                        \ so we can use A for another purpose

 LDA P                  \ Set Q = P + K, which adds the low bytes of the two
 CLC                    \ calculated values
 ADC K
 STA Q

 PLA                    \ Restore the high byte of the y-axis value from the
                        \ stack into A again

 ADC K+1                \ Set A = A + K+1, which adds the high bytes of the two
                        \ calculated values

 BCC P%+4               \ If the above addition overflowed, set A = 255
 LDA #255

 STA R                  \ Store A in R, so we now have R = A + K+1, and:
                        \
                        \   (R Q) = K(1 0) + (A P)
                        \         = (x_delta ^ 2) + (y_delta ^ 2)

 JSR x4_LL5                \ Set Q = SQRT(R Q), so Q now contains the distance
                        \ between the two systems, in terms of coordinates

                        \ We now store the distance to the selected system * 4
                        \ in the two-byte location QQ8, by taking (0 Q) and
                        \ shifting it left twice, storing it in QQ8(1 0)

 LDA Q                  \ First we shift the low byte left by setting
 ASL A                  \ A = Q * 2, with bit 7 of A going into the C flag

 LDX #0                 \ Now we set the high byte in QQ8+1 to 0 and rotate
 STX QQ8+1              \ the C flag into bit 0 of QQ8+1
 ROL QQ8+1

 ASL A                  \ And then we repeat the shift left of (QQ8+1 A)
 ROL QQ8+1

 STA QQ8                \ And store A in the low byte, QQ8, so QQ8(1 0) now
                        \ contains Q * 4. Given that the width of the galaxy is
                        \ 256 in coordinate terms, the width of the galaxy
                        \ would be 1024 in the units we store in QQ8

 JMP TT24_C               \ Call TT24 to calculate system data from the seeds in
                        \ QQ15 and store them in the relevant locations, so our
                        \ new selected system is fully set up, and return from
                        \ the subroutine using a tail call

\ ******************************************************************************
\
\       Name: BRIEF2
\       Type: Subroutine
\   Category: Missions
\    Summary: Start mission 2
\  Deep dive: The Thargoid Plans mission
\
\ ******************************************************************************

.BRIEF2_C

 LDA TP                 \ Set bit 2 of TP to indicate mission 2 is in progress
 ORA #%00000100         \ but plans have not yet been picked up
 STA TP

 LDA #11                \ Set A = 11 so the call to BRP prints extended token 11
                        \ (the initial contact at the start of mission 2, asking
                        \ us to head for Ceerdi for a mission briefing)

                        \ Fall through into BRP to print the extended token in A
                        \ and show the Status Mode screen

\ ******************************************************************************
\
\       Name: BRP
\       Type: Subroutine
\   Category: Missions
\    Summary: Print an extended token and show the Status Mode screen
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   BAYSTEP             Go to the docking bay (i.e. show the Status Mode screen)
\
\ ******************************************************************************

.BRP_C

 LDX #CYAN              \ Switch to colour 3, which is white or cyan
 STX COL

 JSR DETOK_C              \ Print the extended token in A

.BAYSTEP_C

 JMP BAY_C                \ Jump to BAY to go to the docking bay (i.e. show the
                        \ Status Mode screen) and return from the subroutine
                        \ using a tail call

\ ******************************************************************************
\
\       Name: BRIEF3
\       Type: Subroutine
\   Category: Missions
\    Summary: Receive the briefing and plans for mission 2
\  Deep dive: The Thargoid Plans mission
\
\ ******************************************************************************

.BRIEF3_C

 LDA TP                 \ Set bits 1 and 3 of TP to indicate that mission 1 is
 AND #%11110000         \ complete, and mission 2 is in progress and the plans
 ORA #%00001010         \ have been picked up
 STA TP

 LDA #222               \ Set A = 222 so the call to BRP prints extended token
                        \ 222 (the briefing for mission 2 where we pick up the
                        \ plans we need to take to Birera)

 BNE BRP_C                \ Jump to BRP to print the extended token in A and show
                        \ the Status Mode screen), returning from the subroutine
                        \ using a tail call (this BNE is effectively a JMP as A
                        \ is never zero)

\ ******************************************************************************
\
\       Name: DEBRIEF2
\       Type: Subroutine
\   Category: Missions
\    Summary: Finish mission 2
\  Deep dive: The Thargoid Plans mission
\
\ ******************************************************************************

.DEBRIEF2_C

 LDA TP                 \ Set bit 2 of TP to indicate mission 2 is complete (so
 ORA #%00000100         \ both bits 2 and 3 are now set)
 STA TP

 LDA #2                 \ Set ENGY to 2 so our energy banks recharge at a faster
 STA ENGY               \ rate, as our mission reward is a special navy energy
                        \ unit that recharges at a rate of 3 units of energy on
                        \ each iteration of the main loop, compared to a rate of
                        \ 2 units of energy for the standard energy unit

 INC TALLY+1            \ Award 256 kill points for completing the mission

 LDA #223               \ Set A = 223 so the call to BRP prints extended token
                        \ 223 (the thank you message at the end of mission 2)

 BNE BRP_C                \ Jump to BRP to print the extended token in A and show
                        \ the Status Mode screen), returning from the subroutine
                        \ using a tail call (this BNE is effectively a JMP as A
                        \ is never zero)

\ ******************************************************************************
\
\       Name: DEBRIEF
\       Type: Subroutine
\   Category: Missions
\    Summary: Finish mission 1
\  Deep dive: The Constrictor mission
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   BRPS                Print the extended token in A, show the Status Mode
\                       screen and return from the subroutine
\
\ ******************************************************************************

.DEBRIEF_C

 LSR TP                 \ Clear bit 0 of TP to indicate that mission 1 is no
 ASL TP                 \ longer in progress, as we have completed it

\INC TALLY+1            \ This instruction is commented out in the original
                        \ source

 LDX #LO(50000)         \ Increase our cash reserves by the generous mission
 LDY #HI(50000)         \ reward of 5,000 CR
 JSR MCASH_C

 LDA #15                \ Set A = 15 so the call to BRP prints extended token 15
                        \ (the thank you message at the end of mission 1)

.BRPS_C

 BNE BRP_C                \ Jump to BRP to print the extended token in A and show
                        \ the Status Mode screen, returning from the subroutine
                        \ using a tail call (this BNE is effectively a JMP as A
                        \ is never zero)

\ ******************************************************************************
\
\       Name: TBRIEF
\       Type: Subroutine
\   Category: Missions
\    Summary: Start mission 3
\  Deep dive: The Trumbles mission
\
\ ******************************************************************************

\.TBRIEF                \ These instructions are commented out in the original
\                       \ source (they are the checks for the Trumble mission,
\LDA TP                 \ which is not present in the Master version)
\ORA #%00010000
\STA TP
\
\LDA #199
\JSR DETOK
\
\JSR YESNO
\
\BCC BAYSTEP
\
\LDY #HI(50000)
\LDX #LO(50000)
\JSR LCASH
\
\INC TRIBBLE
\
\JMP BAY

\ ******************************************************************************
\
\       Name: BRIEF
\       Type: Subroutine
\   Category: Missions
\    Summary: Start mission 1 and show the mission briefing
\  Deep dive: The Constrictor mission
\
\ ------------------------------------------------------------------------------
\
\ This routine does the following:
\
\   * Clear the screen
\   * Display "INCOMING MESSAGE" in the middle of the screen
\   * Wait for 2 seconds
\   * Clear the screen
\   * Show the Constrictor rolling and pitching in the middle of the screen
\   * Do this for 64 loop iterations
\   * Move the ship away from us and up until it's near the top of the screen
\   * Show the mission 1 briefing in extended token 10
\
\ The mission briefing ends with a "{display ship, wait for key press}" token,
\ which calls the PAUSE routine. This continues to display the rotating ship,
\ waiting until a key is pressed, and then removes the ship from the screen.
\
\ ******************************************************************************

.BRIEF_C

 LSR TP                 \ Set bit 0 of TP to indicate that mission 1 is now in
 SEC                    \ progress
 ROL TP

 JSR BRIS_C               \ Call BRIS to clear the screen, display "INCOMING
                        \ MESSAGE" and wait for 2 seconds

 JSR x4_ZINF               \ Call ZINF to reset the INWK ship workspace

 LDA #CON               \ Set the ship type in TYPE to the Constrictor
 STA TYPE

 JSR x4_NWSHP              \ Add a new Constrictor to the local bubble (in this
                        \ case, the briefing screen)

 LDA #1                 \ Move the text cursor to column 1
 JSR DOXC_C

 STA INWK+7             \ Set z_hi = 1, the distance at which we show the
                        \ rotating ship

 LDA #13                \ Clear the top part of the screen, draw a border box,
 JSR TT66_C               \ and set the current view type in QQ11 to 13 (rotating
                        \ ship view)

 LDA #64                \ Set the main loop counter to 64, so the ship rotates
 STA MCNT               \ for 64 iterations through MVEIT

.BRL1_C

 LDX #%01111111         \ Set the ship's roll counter to a positive roll that
 STX INWK+29            \ doesn't dampen (a clockwise roll)

 STX INWK+30            \ Set the ship's pitch counter to a positive pitch that
                        \ doesn't dampen (a diving pitch)

 JSR x4_LL9                \ Draw the ship on screen

 JSR x4_MVEIT              \ Call MVEIT to rotate the ship in space

 DEC MCNT               \ Decrease the counter in MCNT

 BNE BRL1_C               \ Loop back to keep moving the ship until we have done
                        \ all 64 iterations

.BRL2_C

 LSR INWK               \ Halve x_lo so the Constrictor moves towards the centre

 INC INWK+6             \ Increment z_lo so the Constrictor moves away from us

 BEQ BR2_C                \ If z_lo = 0 (i.e. it just went past 255), jump to BR2
                        \ to show the briefing

 INC INWK+6             \ Increment z_lo so the Constrictor moves a bit further
                        \ away from us

 BEQ BR2_C                \ If z_lo = 0 (i.e. it just went past 255), jump out of
                        \ the loop to BR2 to stop moving the ship up the screen
                        \ and show the briefing

 LDX INWK+3             \ Set X = y_lo + 1
 INX

 CPX #120               \ If X < 120 then skip the next instruction
 BCC P%+4

 LDX #120               \ X is bigger than 120, so set X = 120 so that X has a
                        \ maximum value of 120

 STX INWK+3             \ Set y_lo = X
                        \          = y_lo + 1
                        \
                        \ so the ship moves up the screen (as space coordinates
                        \ have the y-axis going up)

 JSR x4_LL9                \ Draw the ship on screen

 JSR x4_MVEIT              \ Call MVEIT to move and rotate the ship in space

 DEC MCNT               \ Decrease the counter in MCNT

 JMP BRL2_C               \ Loop back to keep moving the ship up the screen and
                        \ away from us

.BR2_C

 INC INWK+7             \ Increment z_hi, to keep the ship at the same distance
                        \ as we just incremented z_lo past 255

 JSR PAS1_C               \ Call PAS1 to display the rotating ship at space
                        \ coordinates (0, 112, 256) and scan the keyboard,
                        \ returning the ASCII code of the key in X (or 0 for no
                        \ key press)

 LDA #10                \ Set A = 10 so the call to BRP prints extended token 10
                        \ (the briefing for mission 1 where we find out all
                        \ about the stolen Constrictor)

 BNE BRPS_C               \ Jump to BRP via BRPS to print the extended token in A
                        \ and show the Status Mode screen, returning from the
                        \ subroutine using a tail call (this BNE is effectively
                        \ a JMP as A is never zero)

\ ******************************************************************************
\
\       Name: BRIS
\       Type: Subroutine
\   Category: Missions
\    Summary: Clear the screen, display "INCOMING MESSAGE" and wait for 2
\             seconds
\
\ ******************************************************************************

.BRIS_C

 LDA #216               \ Print extended token 216 ("{clear screen}{tab 6}{move
 JSR DETOK_C              \ to row 10, white, lower case}{white}{all caps}INCOMING
                        \ MESSAGE"

 LDY #100               \ Wait for 100/50 of a second (2 seconds) and return
 JMP x4_DELAY              \ from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: PAUSE
\       Type: Subroutine
\   Category: Missions
\    Summary: Display a rotating ship, waiting until a key is pressed, then
\             remove the ship from the screen
\
\ ******************************************************************************

.PAUSE_C

 JSR PAS1_C               \ Call PAS1 to display the rotating ship at space
                        \ coordinates (0, 112, 256) and scan the keyboard,
                        \ returning the internal key number in X (or 0 for no
                        \ key press)

 BNE PAUSE_C              \ If a key was already being held down when we entered
                        \ this routine, keep looping back up to PAUSE, until
                        \ the key is released

.PAL1_C

 JSR PAS1_C               \ Call PAS1 to display the rotating ship at space
                        \ coordinates (0, 112, 256) and scan the keyboard,
                        \ returning the internal key number in X (or 0 for no
                        \ key press)

 BEQ PAL1_C               \ Keep looping up to PAL1 until a key is pressed

 LDA #0                 \ Set the ship's AI flag to 0 (no AI) so it doesn't get
 STA INWK+31            \ any ideas of its own

 LDA #1                 \ Clear the top part of the screen, draw a border box,
 JSR TT66_C               \ and set the current view type in QQ11 to 1

 JSR x4_LL9                \ Draw the ship on screen to redisplay it

                        \ Fall through into MT23 to move to row 10, switch to
                        \ white text, and switch to lower case when printing
                        \ extended tokens

\ ******************************************************************************
\
\       Name: MT23
\       Type: Subroutine
\   Category: Text
\    Summary: Move to row 10, switch to white text, and switch to lower case
\             when printing extended tokens
\  Deep dive: Extended text tokens
\
\ ******************************************************************************

.MT23_C

 LDA #10                \ Set A = 10, so when we fall through into MT29, the
                        \ text cursor gets moved to row 10

 EQUB &2C               \ Skip the next instruction by turning it into
                        \ &2C &A9 &06, or BIT &06A9, which does nothing apart
                        \ from affect the flags

                        \ Fall through into MT29 to move to the row in A, switch
                        \ to white text, and switch to lower case

\ ******************************************************************************
\
\       Name: MT29
\       Type: Subroutine
\   Category: Text
\    Summary: Move to row 6, switch to white text, and switch to lower case when
\             printing extended tokens
\  Deep dive: Extended text tokens
\
\ ******************************************************************************

.MT29_C

 LDA #6                 \ Move the text cursor to row 6
 STA YC

 LDA #CYAN              \ Set white text
 STA COL

 JMP MT13_C               \ Jump to MT13 to set bit 7 of DTW6 and bit 5 of DTW1,
                        \ returning from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: PAS1
\       Type: Subroutine
\   Category: Missions
\    Summary: Display a rotating ship at space coordinates (0, 120, 256) and
\             scan the keyboard
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   X                   If a key is being pressed, X contains the ASCII code of
\                       the key being pressed, otherwise it contains 0
\
\   A                   Contains the same as X
\
\ ******************************************************************************

.PAS1_C

 LDA #120               \ Set y_lo = 120
 STA INWK+3

 LDA #0                 \ Set x_lo = 0
 STA INWK

 STA INWK+6             \ Set z_lo = 0

 LDA #2                 \ Set z_hi = 1, so (z_hi z_lo) = 256
 STA INWK+7

 JSR x4_LL9                \ Draw the ship on screen

 JSR x4_MVEIT              \ Call MVEIT to move and rotate the ship in space

 JMP x4_RDKEY              \ Scan the keyboard for a key press and return the
                        \ ASCII code of the key pressed in X (or 0 for no key
                        \ press), returning from the subroutine using a tail
                        \ call

\ ******************************************************************************
\
\       Name: PAUSE2
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Wait until a key is pressed, ignoring any existing key press
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   X                   The ASCII code of the key that was pressed
\
\ ******************************************************************************

.PAUSE2_C

 JSR x4_RDKEY              \ Scan the keyboard for a key press and return the ASCII
                        \ code of the key pressed in A and X (or 0 for no key
                        \ press)

 BNE PAUSE2_C             \ If a key was already being held down when we entered
                        \ this routine, keep looping back up to PAUSE2, until
                        \ the key is released

 JSR x4_RDKEY              \ Any pre-existing key press is now gone, so we can
                        \ start scanning the keyboard again, returning the
                        \ ASCII code of the key pressed in X (or 0 for no key
                        \ press)

 BEQ PAUSE2_C             \ Keep looping up to PAUSE2 until a key is pressed

.newyearseve_C

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: DKS3
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Toggle a configuration setting and emit a beep
\
\ ------------------------------------------------------------------------------
\
\ This is called when the game is paused and a key is pressed that changes the
\ game's configuration.
\
\ Specifically, this routine toggles the configuration settings for the
\ following keys:
\
\   * CAPS LOCK toggles keyboard flight damping (0)
\   * A toggles keyboard auto-recentre (1)
\   * X toggles author names on start-up screen (2)
\   * F toggles flashing console bars (3)
\   * Y toggles reverse joystick Y channel (4)
\   * J toggles reverse both joystick channels (5)
\   * K toggles keyboard and joystick (6)
\
\ The numbers in brackets are the configuration options that we pass in Y. We
\ pass the ASCII code of the key that has been pressed in X, and the option to
\ check it against in Y, so this routine is typically called in a loop that
\ loops through the various configuration option.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The ASCII code of the key that's been pressed
\
\   Y                   The number of the configuration option to check against
\                       from the list above (i.e. Y must be from 0 to 6)
\
\ ******************************************************************************

.DKS3_C

 TXA                    \ Copy the ASCII code of the key that has been pressed
                        \ into A

 CMP TGINT,Y            \ If the pressed key doesn't match the configuration key
 BNE Dk3_C                \ for option Y (as listed in the TGINT table), then jump
                        \ to Dk3 to return from the subroutine

 LDA DAMP,Y             \ The configuration keys listed in TGINT correspond to
 EOR #&FF               \ the configuration option settings from DAMP onwards,
 STA DAMP,Y             \ so to toggle a setting, we fetch the existing byte
                        \ from DAMP+Y, invert it and put it back (0 means no
                        \ and &FF means yes in the configuration bytes, so
                        \ this toggles the setting)

 BPL P%+5               \ If the result has a clear bit 7 (i.e. we just turned
                        \ the option off), skip the following instruction

 JSR x4_BELL               \ We just turned the option on, so make a standard
                        \ system beep, so in all we make two beeps

 JSR x4_BELL               \ Make a beep sound so we know something has happened

 TYA                    \ Store Y and A on the stack so we can retrieve them
 PHA                    \ below

 LDY #20                \ Wait for 20/50 of a second (0.4 seconds)
 JSR x4_DELAY

 PLA                    \ Restore A and Y from the stack
 TAY

.Dk3_C

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: FLKB
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Flush the keyboard buffer
\
\ ------------------------------------------------------------------------------
\
\ This routine does nothing in the BBC Master version of Elite. It does have a
\ function in the disc and 6502SP versions, so the authors presumably just
\ cleared out the FLKB routine for the Master version, rather than unplumbing it
\ from the code.
\
\ ******************************************************************************

.FLKB_C

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: NLIN3
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Print a title and draw a horizontal line at row 19 to box it in
\
\ ------------------------------------------------------------------------------
\
\ This routine print a text token at the cursor position and draws a horizontal
\ line at pixel row 19. It is used for the Status Mode screen, the Short-range
\ Chart, the Market Price screen and the Equip Ship screen.
\
\ ******************************************************************************

.NLIN3_C

 JSR TT27_C               \ Print the text token in A

                        \ Fall through into NLIN4 to draw a horizontal line at
                        \ pixel row 19

\ ******************************************************************************
\
\       Name: NLIN4
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw a horizontal line at pixel row 19 to box in a title
\
\ ------------------------------------------------------------------------------
\
\ This routine is used on the Inventory screen to draw a horizontal line at
\ pixel row 19 to box in the title.
\
\ ******************************************************************************

.NLIN4_C

 LDA #19                \ Jump to NLIN2 to draw a horizontal line at pixel row
 BNE NLIN2_C              \ 19, returning from the subroutine with using a tail
                        \ call (this BNE is effectively a JMP as A will never
                        \ be zero)

\ ******************************************************************************
\
\       Name: NLIN
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw a horizontal line at pixel row 23 to box in a title
\
\ ------------------------------------------------------------------------------
\
\ Draw a horizontal line at pixel row 23 and move the text cursor down one
\ line.
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   NLIN5               Move the text cursor down one line before drawing the
\                       line
\
\ ******************************************************************************

.NLIN_C

 LDA #23                \ Set A = 23 so NLIN2 below draws a horizontal line at
                        \ pixel row 23

.NLIN5_C

 INC YC                 \ Move the text cursor down one line

                        \ Fall through into NLIN2 to draw the horizontal line
                        \ at row 23

\ ******************************************************************************
\
\       Name: NLIN2
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Draw a screen-wide horizontal line at the pixel row in A
\
\ ------------------------------------------------------------------------------
\
\ This draws a line from (2, A) to (254, A), which is almost screen-wide and
\ fits in nicely between the border boxes without clashing with it.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The pixel row on which to draw the horizontal line
\
\ ******************************************************************************

.NLIN2_C

 STA Y1                 \ Set Y1 = A

 LDA #YELLOW            \ Switch to colour 1, which is yellow
 STA COL

 LDX #2                 \ Set X1 = 2, so (X1, Y1) = (2, A)
 STX X1

 LDX #254               \ Set X2 = 254, so (X2, Y2) = (254, A)
 STX X2

 JSR x4_HLOIN3             \ Call HLOIN3 to draw a line from (2, A) to (254, A)

 LDA #CYAN              \ Switch to colour 3, which is cyan or white
 STA COL

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: HLOIN2
\       Type: Subroutine
\   Category: Drawing lines
\    Summary: Remove a line from the sun line heap and draw it on-screen
\
\ ------------------------------------------------------------------------------
\
\ Specifically, this does the following:
\
\   * Set X1 and X2 to the x-coordinates of the ends of the horizontal line with
\     centre YY(1 0) and length A to the left and right
\
\   * Set the Y-th byte of the LSO block to 0 (i.e. remove this line from the
\     sun line heap)
\
\   * Draw a horizontal line from (X1, Y) to (X2, Y)
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   YY(1 0)             The x-coordinate of the centre point of the line
\
\   A                   The half-width of the line, i.e. the contents of the
\                       Y-th byte of the sun line heap
\
\   Y                   The number of the entry in the sun line heap (which is
\                       also the y-coordinate of the line)
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   Y                   Y is preserved
\
\ ******************************************************************************

.HLOIN2_C

 JSR x4_EDGES              \ Call EDGES to calculate X1 and X2 for the horizontal
                        \ line centred on YY(1 0) and with half-width A

 STY Y1                 \ Set Y1 = Y

 LDA #0                 \ Set the Y-th byte of the LSO block to 0
 STA LSO,Y

 JMP x4_HLOIN              \ Call HLOIN to draw a horizontal line from (X1, Y) to
                        \ (X2, Y), returning from the subroutine using a tail
                        \ call

\ ******************************************************************************
\
\       Name: TENS
\       Type: Variable
\   Category: Text
\    Summary: A constant used when printing large numbers in BPRNT
\  Deep dive: Printing decimal numbers
\
\ ------------------------------------------------------------------------------
\
\ Contains the four low bytes of the value 100,000,000,000 (100 billion).
\
\ The maximum number of digits that we can print with the BPRNT routine is 11,
\ so the biggest number we can print is 99,999,999,999. This maximum number
\ plus 1 is 100,000,000,000, which in hexadecimal is:
\
\   17 48 76 E8 00
\
\ The TENS variable contains the lowest four bytes in this number, with the
\ most significant byte first, i.e. 48 76 E8 00. This value is used in the
\ BPRNT routine when working out which decimal digits to print when printing a
\ number.
\
\ ******************************************************************************

.TENS_C

 EQUD &00E87648

\ ******************************************************************************
\
\       Name: pr2
\       Type: Subroutine
\   Category: Text
\    Summary: Print an 8-bit number, left-padded to 3 digits, and optional point
\
\ ------------------------------------------------------------------------------
\
\ Print the 8-bit number in X to 3 digits, left-padding with spaces for numbers
\ with fewer than 3 digits (so numbers < 100 are right-aligned). Optionally
\ include a decimal point.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The number to print
\
\   C flag              If set, include a decimal point
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   pr2+2               Print the 8-bit number in X to the number of digits in A
\
\ ******************************************************************************

.pr2_C

 LDA #3                 \ Set A to the number of digits (3)

 LDY #0                 \ Zero the Y register, so we can fall through into TT11
                        \ to print the 16-bit number (Y X) to 3 digits, which
                        \ effectively prints X to 3 digits as the high byte is
                        \ zero

\ ******************************************************************************
\
\       Name: TT11
\       Type: Subroutine
\   Category: Text
\    Summary: Print a 16-bit number, left-padded to n digits, and optional point
\
\ ------------------------------------------------------------------------------
\
\ Print the 16-bit number in (Y X) to a specific number of digits, left-padding
\ with spaces for numbers with fewer digits (so lower numbers will be right-
\ aligned). Optionally include a decimal point.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   X                   The low byte of the number to print
\
\   Y                   The high byte of the number to print
\
\   A                   The number of digits
\
\   C flag              If set, include a decimal point
\
\ ******************************************************************************

.TT11_C

 STA U                  \ We are going to use the BPRNT routine (below) to
                        \ print this number, so we store the number of digits
                        \ in U, as that's what BPRNT takes as an argument

 LDA #0                 \ BPRNT takes a 32-bit number in K to K+3, with the
 STA K                  \ most significant byte first (big-endian), so we set
 STA K+1                \ the two most significant bytes to zero (K and K+1)
 STY K+2                \ and store (Y X) in the least two significant bytes
 STX K+3                \ (K+2 and K+3), so we are going to print the 32-bit
                        \ number (0 0 Y X)

                        \ Finally we fall through into BPRNT to print out the
                        \ number in K to K+3, which now contains (Y X), to A
                        \ digits (as U = A), using the same C flag as when pr2
                        \ was called to control the decimal point

\ ******************************************************************************
\
\       Name: BPRNT
\       Type: Subroutine
\   Category: Text
\    Summary: Print a 32-bit number, left-padded to a specific number of digits,
\             with an optional decimal point
\  Deep dive: Printing decimal numbers
\
\ ------------------------------------------------------------------------------
\
\ Print the 32-bit number stored in K(0 1 2 3) to a specific number of digits,
\ left-padding with spaces for numbers with fewer digits (so lower numbers are
\ right-aligned). Optionally include a decimal point.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   K(0 1 2 3)          The number to print, stored with the most significant
\                       byte in K and the least significant in K+3 (i.e. as a
\                       big-endian number, which is the opposite way to how the
\                       6502 assembler stores addresses, for example)
\
\   U                   The maximum number of digits to print, including the
\                       decimal point (spaces will be used on the left to pad
\                       out the result to this width, so the number is right-
\                       aligned to this width). U must be 11 or less
\
\   C flag              If set, include a decimal point followed by one
\                       fractional digit (i.e. show the number to 1 decimal
\                       place). In this case, the number in K(0 1 2 3) contains
\                       10 * the number we end up printing, so to print 123.4,
\                       we would pass 1234 in K(0 1 2 3) and would set the C
\                       flag to include the decimal point
\
\ ******************************************************************************

.BPRNT_C

 LDX #11                \ Set T to the maximum number of digits allowed (11
 STX T                  \ characters, which is the number of digits in 10
                        \ billion). We will use this as a flag when printing
                        \ characters in TT37 below

 PHP                    \ Make a copy of the status register (in particular
                        \ the C flag) so we can retrieve it later

 BCC TT30_C               \ If the C flag is clear, we do not want to print a
                        \ decimal point, so skip the next two instructions

 DEC T                  \ As we are going to show a decimal point, decrement
 DEC U                  \ both the number of characters and the number of
                        \ digits (as one of them is now a decimal point)

.TT30_C

 LDA #11                \ Set A to 11, the maximum number of digits allowed

 SEC                    \ Set the C flag so we can do subtraction without the
                        \ C flag affecting the result

 STA XX17               \ Store the maximum number of digits allowed (11) in
                        \ XX17

 SBC U                  \ Set U = 11 - U + 1, so U now contains the maximum
 STA U                  \ number of digits minus the number of digits we want
 INC U                  \ to display, plus 1 (so this is the number of digits
                        \ we should skip before starting to print the number
                        \ itself, and the plus 1 is there to ensure we print at
                        \ least one digit)

 LDY #0                 \ In the main loop below, we use Y to count the number
                        \ of times we subtract 10 billion to get the leftmost
                        \ digit, so set this to zero

 STY S                  \ In the main loop below, we use location S as an
                        \ 8-bit overflow for the 32-bit calculations, so
                        \ we need to set this to 0 before joining the loop

 JMP TT36_C               \ Jump to TT36 to start the process of printing this
                        \ number's digits

.TT35_C

                        \ This subroutine multiplies K(S 0 1 2 3) by 10 and
                        \ stores the result back in K(S 0 1 2 3), using the fact
                        \ that K * 10 = (K * 2) + (K * 2 * 2 * 2)

 ASL K+3                \ Set K(S 0 1 2 3) = K(S 0 1 2 3) * 2 by rotating left
 ROL K+2
 ROL K+1
 ROL K
 ROL S

 LDX #3                 \ Now we want to make a copy of the newly doubled K in
                        \ XX15, so we can use it for the first (K * 2) in the
                        \ equation above, so set up a counter in X for copying
                        \ four bytes, starting with the last byte in memory
                        \ (i.e. the least significant)

.tt35_C

 LDA K,X                \ Copy the X-th byte of K(0 1 2 3) to the X-th byte of
 STA XX15,X             \ XX15(0 1 2 3), so that XX15 will contain a copy of
                        \ K(0 1 2 3) once we've copied all four bytes

 DEX                    \ Decrement the loop counter

 BPL tt35_C               \ Loop back to copy the next byte until we have copied
                        \ all four

 LDA S                  \ Store the value of location S, our overflow byte, in
 STA XX15+4             \ XX15+4, so now XX15(4 0 1 2 3) contains a copy of
                        \ K(S 0 1 2 3), which is the value of (K * 2) that we
                        \ want to use in our calculation

 ASL K+3                \ Now to calculate the (K * 2 * 2 * 2) part. We still
 ROL K+2                \ have (K * 2) in K(S 0 1 2 3), so we just need to shift
 ROL K+1                \ it twice. This is the first one, so we do this:
 ROL K                  \
 ROL S                  \   K(S 0 1 2 3) = K(S 0 1 2 3) * 2 = K * 4

 ASL K+3                \ And then we do it again, so that means:
 ROL K+2                \
 ROL K+1                \   K(S 0 1 2 3) = K(S 0 1 2 3) * 2 = K * 8
 ROL K
 ROL S

 CLC                    \ Clear the C flag so we can do addition without the
                        \ C flag affecting the result

 LDX #3                 \ By now we've got (K * 2) in XX15(4 0 1 2 3) and
                        \ (K * 8) in K(S 0 1 2 3), so the final step is to add
                        \ these two 32-bit numbers together to get K * 10.
                        \ So we set a counter in X for four bytes, starting
                        \ with the last byte in memory (i.e. the least
                        \ significant)

.tt36_C

 LDA K,X                \ Fetch the X-th byte of K into A

 ADC XX15,X             \ Add the X-th byte of XX15 to A, with carry

 STA K,X                \ Store the result in the X-th byte of K

 DEX                    \ Decrement the loop counter

 BPL tt36_C               \ Loop back to add the next byte, moving from the least
                        \ significant byte to the most significant, until we
                        \ have added all four

 LDA XX15+4             \ Finally, fetch the overflow byte from XX15(4 0 1 2 3)

 ADC S                  \ And add it to the overflow byte from K(S 0 1 2 3),
                        \ with carry

 STA S                  \ And store the result in the overflow byte from
                        \ K(S 0 1 2 3), so now we have our desired result, i.e.
                        \
                        \   K(S 0 1 2 3) = K(S 0 1 2 3) * 10

 LDY #0                 \ In the main loop below, we use Y to count the number
                        \ of times we subtract 10 billion to get the leftmost
                        \ digit, so set this to zero so we can rejoin the main
                        \ loop for another subtraction process

.TT36_C

                        \ This is the main loop of our digit-printing routine.
                        \ In the following loop, we are going to count the
                        \ number of times that we can subtract 10 million and
                        \ store that count in Y, which we have already set to 0

 LDX #3                 \ Our first calculation concerns 32-bit numbers, so
                        \ set up a counter for a four-byte loop

 SEC                    \ Set the C flag so we can do subtraction without the
                        \ C flag affecting the result

.tt37_C

                        \ We now loop through each byte in turn to do this:
                        \
                        \   XX15(4 0 1 2 3) = K(S 0 1 2 3) - 100,000,000,000

 LDA K,X                \ Subtract the X-th byte of TENS (i.e. 10 billion) from
 SBC TENS_C,X             \ the X-th byte of K

 STA XX15,X             \ Store the result in the X-th byte of XX15

 DEX                    \ Decrement the loop counter

 BPL tt37_C               \ Loop back to subtract the next byte, moving from the
                        \ least significant byte to the most significant, until
                        \ we have subtracted all four

 LDA S                  \ Subtract the fifth byte of 10 billion (i.e. &17) from
 SBC #&17               \ the fifth (overflow) byte of K, which is S

 STA XX15+4             \ Store the result in the overflow byte of XX15

 BCC TT37_C               \ If subtracting 10 billion took us below zero, jump to
                        \ TT37 to print out this digit, which is now in Y

 LDX #3                 \ We now want to copy XX15(4 0 1 2 3) back into
                        \ K(S 0 1 2 3), so we can loop back up to do the next
                        \ subtraction, so set up a counter for a four-byte loop

.tt38_C

 LDA XX15,X             \ Copy the X-th byte of XX15(0 1 2 3) to the X-th byte
 STA K,X                \ of K(0 1 2 3), so that K(0 1 2 3) will contain a copy
                        \ of XX15(0 1 2 3) once we've copied all four bytes

 DEX                    \ Decrement the loop counter

 BPL tt38_C               \ Loop back to copy the next byte, until we have copied
                        \ all four

 LDA XX15+4             \ Store the value of location XX15+4, our overflow
 STA S                  \ byte in S, so now K(S 0 1 2 3) contains a copy of
                        \ XX15(4 0 1 2 3)

 INY                    \ We have now managed to subtract 10 billion from our
                        \ number, so increment Y, which is where we are keeping
                        \ a count of the number of subtractions so far

 JMP TT36_C               \ Jump back to TT36 to subtract the next 10 billion

.TT37_C

 TYA                    \ If we get here then Y contains the digit that we want
                        \ to print (as Y has now counted the total number of
                        \ subtractions of 10 billion), so transfer Y into A

 BNE TT32_C               \ If the digit is non-zero, jump to TT32 to print it

 LDA T                  \ Otherwise the digit is zero. If we are already
                        \ printing the number then we will want to print a 0,
                        \ but if we haven't started printing the number yet,
                        \ then we probably don't, as we don't want to print
                        \ leading zeroes unless this is the only digit before
                        \ the decimal point
                        \
                        \ To help with this, we are going to use T as a flag
                        \ that tells us whether we have already started
                        \ printing digits:
                        \
                        \   * If T <> 0 we haven't printed anything yet
                        \
                        \   * If T = 0 then we have started printing digits
                        \
                        \ We initially set T above to the maximum number of
                        \ characters allowed, less 1 if we are printing a
                        \ decimal point, so the first time we enter the digit
                        \ printing routine at TT37, it is definitely non-zero

 BEQ TT32_C               \ If T = 0, jump straight to the print routine at TT32,
                        \ as we have already started printing the number, so we
                        \ definitely want to print this digit too

 DEC U                  \ We initially set U to the number of digits we want to
 BPL TT34_C               \ skip before starting to print the number. If we get
                        \ here then we haven't printed any digits yet, so
                        \ decrement U to see if we have reached the point where
                        \ we should start printing the number, and if not, jump
                        \ to TT34 to set up things for the next digit

 LDA #' '               \ We haven't started printing any digits yet, but we
 BNE tt34_C               \ have reached the point where we should start printing
                        \ our number, so call TT26 (via tt34) to print a space
                        \ so that the number is left-padded with spaces (this
                        \ BNE is effectively a JMP as A will never be zero)

.TT32_C

 LDY #0                 \ We are printing an actual digit, so first set T to 0,
 STY T                  \ to denote that we have now started printing digits as
                        \ opposed to spaces

 CLC                    \ The digit value is in A, so add ASCII "0" to get the
 ADC #'0'               \ ASCII character number to print

.tt34_C

 JSR x4_TT26               \ Call TT26 to print the character in A and fall through
                        \ into TT34 to get things ready for the next digit

.TT34_C

 DEC T                  \ Decrement T but keep T >= 0 (by incrementing it
 BPL P%+4               \ again if the above decrement made T negative)
 INC T

 DEC XX17               \ Decrement the total number of characters left to
                        \ print, which we stored in XX17

 BMI rT10_C               \ If the result is negative, we have printed all the
                        \ characters, so jump down to rT10 to return from the
                        \ subroutine

 BNE P%+10              \ If the result is positive (> 0) then we still have
                        \ characters left to print, so loop back to TT35 (via
                        \ the JMP TT35 instruction below) to print the next
                        \ digit

 PLP                    \ If we get here then we have printed the exact number
                        \ of digits that we wanted to, so restore the C flag
                        \ that we stored at the start of the routine

 BCC P%+7               \ If the C flag is clear, we don't want a decimal point,
                        \ so loop back to TT35 (via the JMP TT35 instruction
                        \ below) to print the next digit

 LDA #'.'               \ Otherwise the C flag is set, so print the decimal
 JSR x4_TT26               \ point

 JMP TT35_C               \ Loop back to TT35 to print the next digit

.rT10_C

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: ESCAPE
\       Type: Subroutine
\   Category: Flight
\    Summary: Launch our escape pod
\
\ ------------------------------------------------------------------------------
\
\ This routine displays our doomed Cobra Mk III disappearing off into the ether
\ before arranging our replacement ship. Called when we press ESCAPE during
\ flight and have an escape pod fitted.
\
\ ******************************************************************************

.ESCAPE_C

 JSR RES2_C               \ Reset a number of flight variables and workspaces

 LDX #CYL               \ Set the current ship type to a Cobra Mk III, so we
 STX TYPE               \ can show our ship disappear into the distance when we
                        \ eject in our pod

 JSR x4_FRS1               \ Call FRS1 to launch the Cobra Mk III straight ahead,
                        \ like a missile launch, but with our ship instead

 BCS ES1_C                \ If the Cobra was successfully added to the local
                        \ bubble, jump to ES1 to skip the following instructions

 LDX #CYL2              \ The Cobra wasn't added to the local bubble for some
 JSR x4_FRS1               \ reason, so try launching a pirate Cobra Mk III instead

.ES1_C

 LDA #8                 \ Set the Cobra's byte #27 (speed) to 8
 STA INWK+27

 LDA #194               \ Set the Cobra's byte #30 (pitch counter) to 194, so it
 STA INWK+30            \ pitches up as we pull away

 LSR A                  \ Set the Cobra's byte #32 (AI flag) to %01100001, so it
 STA INWK+32            \ has no AI, and we can use this value as a counter to
                        \ do the following loop 97 times

.ESL1_C

 JSR x4_MVEIT              \ Call MVEIT to move the Cobra in space

 LDA QQ11               \ If either of QQ11 or VIEW is non-zero (i.e. this is
 ORA VIEW               \ not the front space view), skip the following
 BNE P%+5               \ instruction

 JSR x4_LL9                \ Call LL9 to draw the Cobra on-screen

 DEC INWK+32            \ Decrement the counter in byte #32

 BNE ESL1_C               \ Loop back to keep moving the Cobra until the AI flag
                        \ is 0, which gives it time to drift away from our pod

 JSR x4_SCAN               \ Call SCAN to remove the Cobra from the scanner (by
                        \ redrawing it)

 LDA #0                 \ Set A = 0 so we can use it to zero the contents of
                        \ the cargo hold

 LDX #16                \ We lose all our cargo when using our escape pod, so
                        \ up a counter in X so we can zero the 17 cargo slots
                        \ in QQ20

.ESL2_C

 STA QQ20,X             \ Set the X-th byte of QQ20 to zero, so we no longer
                        \ have any of item type X in the cargo hold

 DEX                    \ Decrement the counter

 BPL ESL2_C               \ Loop back to ESL2 until we have emptied the entire
                        \ cargo hold

 STA FIST               \ Launching an escape pod also clears our criminal
                        \ record, so set our legal status in FIST to 0 ("clean")

 STA ESCP               \ The escape pod is a one-use item, so set ESCP to 0 so
                        \ we no longer have one fitted

\LDA TRIBBLE            \ These instructions are commented out in the original
\ORA TRIBBLE+1          \ source
\BEQ nosurviv           \
\                       \ They ensure that in games with the Trumble mission,
\JSR DORND              \ at least one Trumble will hitch a ride in the escape
\AND #7                 \ pod (so using an escape pod is not a solution to the
\ORA #1                 \ trouble with Trumbles)
\STA TRIBBLE            \
\LDA #0                 \ This version of Elite does not contain the Trumble
\STA TRIBBLE+1          \ mission, so the code is disabled
\
\.nosurviv

 LDA #70                \ Our replacement ship is delivered with a full tank of
 STA QQ14               \ fuel, so set the current fuel level in QQ14 to 70, or
                        \ 7.0 light years

 JMP j4_GOIN               \ Go to the docking bay (i.e. show the ship hangar
                        \ screen) and return from the subroutine with a tail
                        \ call

\ ******************************************************************************
\
\       Name: SWAPPZERO
\       Type: Subroutine
\   Category: Utility routines
\    Summary: An unused routine that swaps bytes in and out of zero page
\
\ ******************************************************************************

.SWAPPZERO_C

 LDX #K3+1              \ This routine starts copying zero page from the byte
                        \ after K3 and up, using X as an index

.SWPZL_C

 LDA ZP,X               \ These instructions have no effect, as they simply swap
 LDY ZP,X               \ a byte with itself
 STA ZP,X
 STY ZP,X

 INX                    \ Increment the loop counter

 BNE SWPZL_C              \ Loop back for the next byte

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: BAD
\       Type: Subroutine
\   Category: Status
\    Summary: Calculate how bad we have been
\
\ ------------------------------------------------------------------------------
\
\ Work out how bad we are from the amount of contraband in our hold. The
\ formula is:
\
\   (slaves + narcotics) * 2 + firearms
\
\ so slaves and narcotics are twice as illegal as firearms. The value in FIST
\ (our legal status) is set to at least this value whenever we launch from a
\ space station, and a FIST of 50 or more gives us fugitive status, so leaving a
\ station carrying 25 tonnes of slaves/narcotics, or 50 tonnes of firearms
\ across multiple trips, is enough to make us a fugitive.
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   A                   A value that determines how bad we are from the amount
\                       of contraband in our hold
\
\ ******************************************************************************

.BAD_C

 LDA QQ20+3             \ Set A to the number of tonnes of slaves in the hold

 CLC                    \ Clear the C flag so we can do addition without the
                        \ C flag affecting the result

 ADC QQ20+6             \ Add the number of tonnes of narcotics in the hold

 ASL A                  \ Double the result and add the number of tonnes of
 ADC QQ20+10            \ firearms in the hold

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: TT217
\       Type: Subroutine
\   Category: Keyboard
\    Summary: Scan the keyboard until a key is pressed
\
\ ------------------------------------------------------------------------------
\
\ Scan the keyboard until a key is pressed, and return the key's ASCII code.
\ If, on entry, a key is already being held down, then wait until that key is
\ released first (so this routine detects the first key down event following
\ the subroutine call).
\
\ ------------------------------------------------------------------------------
\
\ Returns:
\
\   X                   The ASCII code of the key that was pressed
\
\   A                   Contains the same as X
\
\   Y                   Y is preserved
\
\ ------------------------------------------------------------------------------
\
\ Other entry points:
\
\   out                 Contains an RTS
\
\   t                   As TT217 but don't preserve Y, set it to YSAV instead
\
\ ******************************************************************************

.TT217_C

 STY YSAV               \ Store Y in temporary storage, so we can restore it
                        \ later

.t_C

 LDY #2                 \ Wait for 2/50 of a second (0.04 seconds) to implement
 JSR x4_DELAY              \ a simple keyboard debounce and prevent multiple key
                        \ presses being recorded

 JSR x4_RDKEY              \ Scan the keyboard for a key press and return the
                        \ ASCII code of the key pressed in A and X (or 0 for no
                        \ key press)

 BNE t_C                  \ If a key was already being held down when we entered
                        \ this routine, keep looping back up to t, until the
                        \ key is released

.t2_C

 JSR x4_RDKEY              \ Any pre-existing key press is now gone, so we can
                        \ start scanning the keyboard again, returning the
                        \ ASCII code of the key pressed in X (or 0 for no key
                        \ press)

 BEQ t2_C                 \ Keep looping up to t2 until a key is pressed

 LDY YSAV               \ Restore the original value of Y we stored above

 TAX                    \ Copy A into X

.out_C

 RTS                    \ Return from the subroutine

\ ******************************************************************************
\
\       Name: me1
\       Type: Subroutine
\   Category: Flight
\    Summary: Erase an old in-flight message and display a new one
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The text token to be printed
\
\   X                   Must be set to 0
\
\ ******************************************************************************

.me1_C

 STX DLY                \ Set the message delay in DLY to 0, so any new
                        \ in-flight messages will be shown instantly

 PHA                    \ Store the new message token we want to print

 LDA #YELLOW            \ Switch to colour 1, which is yellow
 STA COL

 LDA MCH                \ Set A to the token number of the message that is
 JSR mes9_C               \ currently on-screen, and call mes9 to print it (which
                        \ will remove it from the screen, as printing is done
                        \ using EOR logic)

 PLA                    \ Restore the new message token

\ ******************************************************************************
\
\       Name: MESS
\       Type: Subroutine
\   Category: Flight
\    Summary: Display an in-flight message
\
\ ------------------------------------------------------------------------------
\
\ Display an in-flight message in capitals at the bottom of the space view,
\ erasing any existing in-flight message first.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The text token to be printed
\
\ ******************************************************************************

.MESS_C

 PHA                    \ Store A on the stack so we can restore it after the
                        \ following

 LDX QQ11               \ If this is the space view, skip the following
 BEQ infrontvw_C          \ instruction

 JSR x4_CLYNS              \ Clear the bottom three text rows of the upper screen,
                        \ and move the text cursor to the first cleared row

.infrontvw_C

 LDA #21                \ Move the text cursor to row 21
 STA YC

 LDA #YELLOW            \ Switch to colour 1, which is yellow
 STA COL

 LDX #0                 \ Set QQ17 = 0 to switch to ALL CAPS
 STX QQ17

 LDA messXC             \ Move the text cursor to column messXC, in case we
 STA XC                 \ jump to me1 below to erase the current in-flight
                        \ message (whose column we stored in messXC when we
                        \ called MESS to put it there in the first place)

 PLA                    \ Restore A from the stack

 LDY #20                \ Set Y = 20 for setting the message delay below

 CPX DLY                \ If the message delay in DLY is not zero, jump up to
 BNE me1_C                \ me1 to erase the current message first (whose token
                        \ number will be in MCH)

 STY DLY                \ Set the message delay in DLY to 20

 STA MCH                \ Set MCH to the token we are about to display

                        \ Before we fall through into mes9 to print the token,
                        \ we need to work out the starting column for the
                        \ message we want to print, so it's centred on-screen,
                        \ so the following doesn't print anything, it just uses
                        \ the justified text mechanism to work out the number of
                        \ characters in the message we are going to print

 LDA #%11000000         \ Set the DTW4 flag to %11000000 (justify text, buffer
 STA DTW4               \ entire token including carriage returns)

 LDA de                 \ Set the C flag to bit 1 of the destruction flag in de
 LSR A

 LDA #0                 \ Set A = 0

 BCC P%+4               \ If the destruction flag in de is not set, skip the
                        \ following instruction

 LDA #10                \ Set A = 10

 STA DTW5               \ Store A in DTW5, so DTW5 (which holds the size of the
                        \ justified text buffer at BUF) is set to 0 if the
                        \ destruction flag is not set, or 10 if it is (10 being
                        \ the number of characters in the " DESTROYED" token)

 LDA MCH                \ Call TT27 to print the token in MCH into the buffer
 JSR TT27_C               \ (this doesn't print it on-screen, it just puts it into
                        \ the buffer and moves the DTW5 pointer along, so DTW5
                        \ now contains the size of the message we want to print,
                        \ including the " DESTROYED" part if that's going to be
                        \ included)

 LDA #32                \ Set A = (32 - DTW5) / 2
 SEC                    \
 SBC DTW5               \ so A now contains the column number we need to print
 LSR A                  \ our message at for it to be centred on-screen (as
                        \ there are 32 columns)

 STA messXC             \ Store A in messXC, so when we erase the message via
                        \ the branch to me1 above, messXC will tell us where to
                        \ print it

 STA XC                 \ Move the text cursor to column messXC

 JSR MT15_C               \ Call MT15 to switch to left-aligned text when printing
                        \ extended tokens, disabling the justify text setting we
                        \ set above

 LDA MCH                \ Set MCH to the token we are about to display

                        \ Fall through into mes9 to print the token in A

\ ******************************************************************************
\
\       Name: mes9
\       Type: Subroutine
\   Category: Flight
\    Summary: Print a text token, possibly followed by " DESTROYED"
\
\ ------------------------------------------------------------------------------
\
\ Print a text token, followed by " DESTROYED" if the destruction flag is set
\ (for when a piece of equipment is destroyed).
\
\ ******************************************************************************

.mes9_C

 JSR TT27_C               \ Call TT27 to print the text token in A

 LSR de                 \ If bit 0 of variable de is clear, return from the
 BCC out_C                \ subroutine (as out contains an RTS)

 LDA #253               \ Print recursive token 93 (" DESTROYED") and return
 JMP TT27_C               \ from the subroutine using a tail call

\ ******************************************************************************
\
\       Name: OUCH
\       Type: Subroutine
\   Category: Flight
\    Summary: Potentially lose cargo or equipment following damage
\
\ ------------------------------------------------------------------------------
\
\ Our shields are dead and we are taking damage, so there is a small chance of
\ losing cargo or equipment.
\
\ ******************************************************************************

.OUCH_C

 JSR x4_DORND              \ Set A and X to random numbers

 BMI out_C                \ If A < 0 (50% chance), return from the subroutine
                        \ (as out contains an RTS)

 CPX #22                \ If X >= 22 (91% chance), return from the subroutine
 BCS out_C                \ (as out contains an RTS)

 LDA QQ20,X             \ If we do not have any of item QQ20+X, return from the
 BEQ out_C                \ subroutine (as out contains an RTS). X is in the range
                        \ 0-21, so this not only checks for cargo, but also for
                        \ E.C.M., fuel scoops, energy bomb, energy unit and
                        \ docking computer, all of which can be destroyed

 LDA DLY                \ If there is already an in-flight message on-screen,
 BNE out_C                \ return from the subroutine (as out contains an RTS)

 LDY #3                 \ Set bit 1 of de, the equipment destruction flag, so
 STY de                 \ that when we call MESS below, " DESTROYED" is appended
                        \ to the in-flight message

 STA QQ20,X             \ A is 0 (as we didn't branch with the BNE above), so
                        \ this sets QQ20+X to 0, which destroys any cargo or
                        \ equipment we have of that type

 CPX #17                \ If X >= 17 then we just lost a piece of equipment, so
 BCS ou1_C                \ jump to ou1 to print the relevant message

 TXA                    \ Print recursive token 48 + A as an in-flight token,
 ADC #208               \ which will be in the range 48 ("FOOD") to 64 ("ALIEN
 JMP MESS_C               \ ITEMS") as the C flag is clear, so this prints the
                        \ destroyed item's name, followed by " DESTROYED" (as we
                        \ set bit 1 of the de flag above), and returns from the
                        \ subroutine using a tail call

.ou1_C

 BEQ ou2_C                \ If X = 17, jump to ou2 to print "E.C.M.SYSTEM
                        \ DESTROYED" and return from the subroutine using a tail
                        \ call

 CPX #18                \ If X = 18, jump to ou3 to print "FUEL SCOOPS
 BEQ ou3_C                \ DESTROYED" and return from the subroutine using a tail
                        \ call

 TXA                    \ Otherwise X is in the range 19 to 21 and the C flag is
 ADC #113-20            \ set (as we got here via a BCS to ou1), so we set A as
                        \ follows:
                        \
                        \   A = 113 - 20 + X + C
                        \     = 113 - 19 + X
                        \     = 113 to 115

 JMP MESS_C               \ Print recursive token A ("ENERGY BOMB", "ENERGY UNIT"
                        \ or "DOCKING COMPUTERS") as an in-flight message,
                        \ followed by " DESTROYED", and return from the
                        \ subroutine using a tail call

\ ******************************************************************************
\
\       Name: ou2
\       Type: Subroutine
\   Category: Flight
\    Summary: Display "E.C.M.SYSTEM DESTROYED" as an in-flight message
\
\ ******************************************************************************

.ou2_C

 LDA #108               \ Set A to recursive token 108 ("E.C.M.SYSTEM")

 JMP MESS_C               \ Print recursive token A as an in-flight message,
                        \ followed by " DESTROYED", and return from the
                        \ subroutine using a tail call

\ ******************************************************************************
\
\       Name: ou3
\       Type: Subroutine
\   Category: Flight
\    Summary: Display "FUEL SCOOPS DESTROYED" as an in-flight message
\
\ ******************************************************************************

.ou3_C

 LDA #111               \ Set A to recursive token 111 ("FUEL SCOOPS")

 JMP MESS_C               \ Print recursive token A as an in-flight message,
                        \ followed by " DESTROYED", and return from the
                        \ subroutine using a tail call

\ ******************************************************************************
\
\       Name: TT66
\       Type: Subroutine
\   Category: Drawing the screen
\    Summary: Clear the screen and set the current view type
\
\ ------------------------------------------------------------------------------
\
\ Clear the top part of the screen, draw a border box, and set the current
\ view type in QQ11 to A.
\
\ ------------------------------------------------------------------------------
\
\ Arguments:
\
\   A                   The type of the new current view (see QQ11 for a list of
\                       view types)
\
\ ******************************************************************************

.TT66_C

 STA QQ11               \ Set the current view type in QQ11 to A

                        \ Fall through into TTX66K to clear the screen and draw
                        \ a border box

\ ******************************************************************************
\
\       Name: TTX66K
\       Type: Subroutine
\   Category: Drawing the screen
\    Summary: Clear the top part of the screen, draw a border box and configure
\             the specified view
\
\ ------------------------------------------------------------------------------
\
\ Clear the top part of the screen (the space view) and draw a border box
\ along the top and sides.
\
\ ******************************************************************************

.TTX66K_C

 JSR x4_TTX66              \ Call TTX66 to clear the top part of the screen and
                        \ draw a border box

 JSR MT2_C                \ Switch to Sentence Case when printing extended tokens

 LDA #0                 \ Reset the ball line heap pointer at LSP
 STA LSP

 LDA #%10000000         \ Set bit 7 of QQ17 to switch to Sentence Case
 STA QQ17

 STA DTW2               \ Set bit 7 of DTW2 to indicate we are not currently
                        \ printing a word

 JSR x4_FLFLLS             \ Call FLFLLS to reset the LSO block

 LDA #0                 \ Set LAS2 = 0 to stop any laser pulsing
 STA LAS2

 STA DLY                \ Set the delay in DLY to 0, to indicate that we are
                        \ no longer showing an in-flight message, so any new
                        \ in-flight messages will be shown instantly

 STA de                 \ Clear de, the flag that appends " DESTROYED" to the
                        \ end of the next text token, so that it doesn't

 LDX QQ22+1             \ Fetch into X the number that's shown on-screen during
                        \ the hyperspace countdown

 BEQ P%+5               \ If the counter is zero then we are not counting down
                        \ to hyperspace, so skip the next instruction

 JSR ee3_C                \ Print the 8-bit number in X at text location (0, 1),
                        \ i.e. print the hyperspace countdown in the top-left
                        \ corner

 LDA QQ11               \ If this is not a space view, jump to tt66 to skip
 BNE tt66_C               \ displaying the view name

 LDA #11                \ Move the text cursor to column 11
 STA XC

 LDA #CYAN              \ Switch to colour 3, which is cyan in the space view
 STA COL

 LDA VIEW               \ Load the current view into A:
                        \
                        \   0 = front
                        \   1 = rear
                        \   2 = left
                        \   3 = right

 ORA #&60               \ OR with &60 so we get a value of &60 to &63 (96 to 99)

 JSR TT27_C               \ Print recursive token 96 to 99, which will be in the
                        \ range "FRONT" to "RIGHT"

 JSR TT162_C              \ Print a space

 LDA #175               \ Print recursive token 15 ("VIEW ")
 JSR TT27_C

.tt66_C

 LDX #0                 \ Set QQ17 = 0 to switch to ALL CAPS
 STX QQ17

 RTS                    \ Return from the subroutine
