\ ******************************************************************************
\
\ elite-cold5.asm - cold game code in bank 5
\
\ Port: flight-rare game code in sideways RAM bank 5, after the rasteriser,
\ reached as elite-cold6.asm's is: stubs keeping the routine's name call far5
\ (HAZEL, elite-hazel.asm), and this code calls out through its own stubs
\ (z4_name: JSR far4 : EQUW name). bankcheck.py's area "cold5".
\
\ ******************************************************************************

.z4_SFS1m2
 JSR far4
 EQUW SFS1-2

.z4_MESS
 JSR far4
 EQUW MESS

.z4_NOISE
 JSR far4
 EQUW NOISE

.z4_ECBLB
 JSR far4
 EQUW ECBLB

.z4_MSBAR
 JSR far4
 EQUW MSBAR

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

                        \ Port: moved here from the main code (elite-source.asm)
                        \ to make room there

.SFRMIS_C

 LDX #MSL               \ Set X to the ship type of a missile, and call SFS1-2
 JSR z4_SFS1m2             \ to add a missile to our universe that has AI (bit 7
                        \ set), is hostile (bit 6 set) and has been launched
                        \ (bit 0 clear); the target slot number is set to 31,
                        \ but this is ignored as the hostile flags means we
                        \ are the target


 BCS P%+3               \ The C flag will be set if the call to SFS1-2 was a
 RTS                    \ (Port: return here, as ZEKRTS did)
                        \ success, so if it's clear, jump to ZEKRTS to
                        \ return from the subroutine (as ZEKRTS contains
                        \ an RTS)


 LDA #120               \ Print recursive token 120 ("INCOMING MISSILE") as an
 JSR z4_MESS               \ in-flight message

 LDY #solaun            \ Call the NOISE routine with Y = 8 to make the sound
 JMP z4_NOISE              \ of the missile being launched and return from the
                        \ subroutine using a tail call

\ ******************************************************************************
\
\       Name: ECMOF
\       Type: Subroutine
\   Category: Dashboard
\    Summary: Switch off the E.C.M. and turn off the dashboard bulb
\
\ ------------------------------------------------------------------------------
\
\ Port: moved from the end of the main code (cold), to make room there
\
\ ******************************************************************************

.ECMOF_C


 LDA #0                 \ Set ECMA and ECMP to 0 to indicate that no E.C.M. is
 STA ECMA               \ currently running
 STA ECMP


 JMP z4_ECBLB              \ Update the E.C.M. indicator bulb on the dashboard and
                        \ return from the subroutine using a tail call

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
\ ------------------------------------------------------------------------------
\
\ Port: moved from the main code (cold), to make room there
\
\ ******************************************************************************

.THERE_C

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

.msblob_C

 LDX #4                 \ Set up a loop counter in X to count through all four
                        \ missile indicators

.ss

 CPX NOMSL              \ If the counter is equal to the number of missiles,
 BEQ SAL8               \ jump down to SAL8 to draw the remaining missiles, as
                        \ the rest of them are present and should be drawn in
                        \ green

 LDY #0                 \ Draw the missile indicator at position X in black
 JSR z4_MSBAR

 DEX                    \ Decrement the counter to point to the next missile

 BNE ss                 \ Loop back to ss if we still have missiles to draw

 RTS                    \ Return from the subroutine

.SAL8

 LDY #GREEN2            \ Draw the missile indicator at position X in green
 JSR z4_MSBAR

 DEX                    \ Decrement the counter to point to the next missile

 BNE SAL8               \ Loop back to SAL8 if we still have missiles to draw

 RTS                    \ Return from the subroutine
