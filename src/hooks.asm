\ ******************************************************************************
\
\ hooks.asm - the glue between Elite's drawing code and the frame layer
\
\ Lives in HAZEL (&C000-&DFFF, always visible once the loader has set ACCCON
\ bit Y). Elite's drawing routines call these with a single JSR at their
\ start (tools/patch.py inserts them). "Record mode" is QQ11 = 0 (a view that
\ draws ships) and GFORCE = 0: drawing is then recorded for FRAME instead of
\ being done. A hook that takes over pulls its return address (PLA : PLA) so
\ its RTS returns from the hooked routine itself.
\
\ ******************************************************************************

\ H_SKIP: in record mode, return from the hooked routine at once (LL155,
\ HLOIN). Clobbers A.

.H_SKIP
 LDA QQ11
 ORA GFORCE
 BEQ P%+3
 RTS
 PLA
 PLA
.hrts
 RTS

\ H_LL155: in record mode the ship line heap holds no lines, but its first
\ byte still says how many there would be (H_EE31 sets it), so return with
\ LL155's flags: C set and Y = XX20 = heap size if it is 4 or more, else C
\ clear and Y = 0

.H_LL155
 LDA QQ11
 ORA GFORCE
 BEQ P%+3
 RTS
 PLA
 PLA
 LDY #0
 LDA (XX19),Y
 STA XX20
 CMP #4
 BCC hrts
 TAY
 SEC
 RTS

\ H_LOIN: record the line X1,Y1 - X2,Y2 (unless erasing)

.H_LOIN
 LDA QQ11
 ORA GFORCE
 BEQ P%+3
 RTS
 PLA                    \ in record mode lines are not drawn (the planet's
 PLA                    \ meridians and craters are filled from BLINE's
 LDA #0                 \ points instead)
 STA SWAP               \ as LOIN would for a line it didn't swap
 RTS

\ H_STAR: PIXEL2 has converted star Y's position to X = x, A = y

.H_STAR
 STA hA
 LDA QQ11
 ORA GFORCE
 BNE hsd
 PLA
 PLA
 SEC
 JSR G_STAR
.hpxc
 LDA ZZ                 \ leave C = (ZZ >= 80) and A = ZZ as PIXEL would
 CMP #80
 RTS
.hsd
 SEC                    \ outside record mode PIXEL draws it: note where
 JSR G_DSTAR            \ (F_DSTAR preserves X and Y)
.hdd
 LDA hA
 RTS

.hA EQUB 0

\ H_STAROFF: PIXEL2 found star Y off screen

.H_STAROFF
 LDA QQ11
 ORA GFORCE
 BEQ P%+6
 CLC                    \ (outside record mode: see H_STAR; F_DSTAR returns
 JMP G_DSTAR            \ C set)
 CLC
 JSR G_STAR
 SEC                    \ as PIXEL2's BCS PX4 leaves it
 RTS

\ H_DOT: PIXEL with X = x, A = y (explosion particles)

.H_DOT
 STA hA
 LDA QQ11
 ORA GFORCE
 BNE hdd
 PLA
 PLA
 LDA GDRAWON
 BEQ hpxc
 LDA hA
 JSR G_DOT
 JMP hpxc

\ H_CHAR: TT26 is about to draw the character in K3 at (XC-1, YC); A = YC,
\ C clear on return. The text map is kept outside record mode too, where
\ TT26 also draws the character into main RAM (see f_sync in frame.asm), so
\ text printed before the screen carries on in record mode without a TT66
\ (DEATH's "GAME OVER") is still known to FRAME.

.H_CHAR
 STA hA
 JSR G_CHAR             \ (F_CHAR reads K3)
 LDA QQ11
 ORA GFORCE
 BNE hcd
 PLA
 PLA
 JMP RR4
.hcd
 LDA hA
 CLC
 RTS

\ H_DEL: TT26 is deleting the character at (XC, YC) (kept in the text map in
\ direct mode too, as H_CHAR)

.H_DEL
 JSR G_DELCHAR          \ (F_DELCHAR reads XC, YC)
 LDA QQ11
 ORA GFORCE
 BEQ P%+3
 RTS
 PLA
 PLA
 JMP RR4

.hrts3
 RTS

\ H_CLYNS: clear text rows 21-23 and leave the cursor at (1, 21), A = Y = 0, as
\ CLYNS (falling into LYN) does (X preserved)

.H_CLYNS
 JSR G_CLRTEXT          \ text map rows 21-23, in direct mode too (as H_CHAR;
                        \ F_CLRTEXT preserves X and Y, as CLYNS does)
 LDA QQ11
 ORA GFORCE
 BEQ P%+3
 RTS
 PLA
 PLA
 LDA #20
 STA YC
 JSR TT67
 LDA #1
 STA XC
 LDY #0
 LDA #0
 RTS

\ GFORCE on/off around TTX66's border box

.H_FORCE1
 LDA #&FF
 STA GFORCE
 RTS

.H_FORCE0
 LDA #0
 STA GFORCE
 RTS

\ H_VSYNC: called by the IRQ handler at vertical sync (flip, show the front
\ buffer). A only. (The dashboard split is handled in the IRQ itself.)

.H_VSYNC
 LDA GFLIP              \ GFRS = the front buffer: the pending one if a flip
 BEQ hv0                \ is due, 0 (main RAM) in direct mode (the IRQ's
 LDA GPEND              \ dashboard split zeroes GFRONT until vsync, so GFRS
 STA GFRS               \ keeps it)
 STZ GFLIP
.hv0
 BIT GMODE
 BMI hv1
 STZ GFRS
.hv1
 LDA GFRS
 STA GFRONT
 ORA GACCX
 ORA #ACCY
 STA &FE34
 RTS

.GFRS EQUB 0

\ H_EE31: LL9 has projected the ship; in record mode record it (and its laser
\ beam if it is firing at us) instead of drawing edges

.H_EE31
 LDA QQ11
 ORA GFORCE
 BEQ P%+3
 RTS
 PLA
 PLA
 LDA #%00001000         \ the ship is now "on screen" (as EE31 does)
 ORA XX1+31
 STA XX1+31
 LDY #12                \ faces = byte #12 / 4
 LDA (XX0),Y
 LSR A
 LSR A
 STA GNF
 LDY #8                 \ vertices = byte #8 / 6
 LDA (XX0),Y
 LDX #0
.hee1
 CMP #6
 BCC hee2
 SBC #6
 INX
 BNE hee1
.hee2
 STX GNV
 JSR G_SHIP

 LDY GNF                \ the line heap's size, as far as LL155's flags are
 LDA #1                 \ concerned: 5 if any face is visible, else 1
 STA hcnt
.hee3
 DEY
 BMI hee4
 LDA XX2,Y
 BEQ hee3
 LDA #5
 STA hcnt
.hee4

 BIT XX1+31             \ firing its lasers at us? (as EE31 part 8)
 BVC hee9
 LDA XX1+31
 AND #%10111111
 STA XX1+31
 LDY #6
 LDA (XX0),Y
 TAY
 LDX XX3,Y
 STX XX15
 INX
 BEQ hee9
 LDX XX3+1,Y
 STX XX15+1
 INX
 BEQ hee9
 LDX XX3+2,Y
 STX XX15+2
 LDX XX3+3,Y
 STX XX15+3
 LDA #0
 STA XX15+4
 STA XX15+5
 STA XX12+1
 LDA XX1+6
 STA XX12
 LDA XX1+2
 BPL P%+4
 DEC XX15+4
 JSR LL145
 BCS hee9
 LDA #FC_ELASER
 STA GLCOL
 JSR G_LINE
 LDA #FC_PLINE
 STA GLCOL
 LDA #5
 STA hcnt
.hee9
 LDA hcnt
 LDY #0
 STA (XX19),Y
 RTS

.hcnt EQUB 0

\ H_SHPPT: a distant ship drawn as a dot at (K3, K4)

.H_SHPPT
 LDA QQ11
 ORA GFORCE
 BEQ P%+3
 RTS
 JSR G_SHPPT
.hrts2
 RTS

\ H_CIRC: CIRCLE in record mode records the planet disc instead

.H_CIRC
 LDA QQ11
 ORA GFORCE
 BEQ P%+3
 RTS
 PLA
 PLA
 JSR CHKON
 BCC P%+3
 RTS
 JSR G_PLANET
 LDA #0                 \ leave what CIRCLE2 leaves: LSX2 = 0, FLAG = 0,
 STA LSX2               \ STP = 8/4/2 by radius and CNT = the first multiple
 STA FLAG               \ of STP above 64 (TACTICS reads a stale CNT)
 LDX K
 LDA #8
 LDY #72
 CPX #8
 BCC hci1
 LDA #4
 LDY #68
 CPX #60
 BCC hci1
 LDA #2
 LDY #66
.hci1
 STA STP
 STY CNT
 CLC
 RTS

\ H_WPLS2: the planet's lines aren't on screen, just reset the ball line heap

.H_WPLS2
 LDA QQ11
 ORA GFORCE
 BEQ P%+3
 RTS
 PLA
 PLA
 JMP WP1

\ H_SUN: SUN found the sun on screen: record centre and radius (the fringe
\ calculations carry on as before, for the random number sequence)

.H_SUN
 LDA QQ11
 ORA GFORCE
 BEQ P%+3
 RTS
 JMP G_PLANET

\ H_PTCLSE: DOEXP removing the old explosion cloud: run PTCLS (for its random
\ numbers) without recording anything

.H_PTCLSE
 LDA #0
 STA GDRAWON
 JSR PTCLS
 LDA #&FF
 STA GDRAWON
 RTS

\ Our laser beams: LASLI (falling into LASLI2) shows them, LASLI2 called
\ directly removes them

.H_LAS1
 LDA QQ11
 ORA GFORCE
 BEQ P%+3
 RTS
 PLA
 PLA
 LDA #&FF
 STA GLASV
 RTS

.H_LAS2
 LDA QQ11
 ORA GFORCE
 BEQ P%+3
 RTS
 PLA
 PLA
 LDA #0
 STA GLASV
 RTS

\ H_SIGHT: the sights are drawn by FRAME while GSIGHT is non-zero

.H_SIGHT
 LDA QQ11
 ORA GFORCE
 BEQ P%+3
 RTS
 PLA
 PLA
 LDY VIEW
 LDA LASER,Y
 STA GSIGHT
 RTS

\ H_HFS: the hyperspace / launch rings are drawn directly (EOR, then erased)

.H_HFS
 LDA #&FF
 STA GFORCE
 JSR HFS1
 JSR HFS1
 LDA #0
 STA GFORCE
 PLA
 PLA
 RTS

\ H_MFRAME / H_LL9F: a main-loop iteration (or a title-screen one), then the
\ frame

.H_MFRAME
 JSR M%
 JMP hframe

.H_LL9F
 JSR LL9

.hframe                 \ the frame, preserving A, X, Y and the flags (the
 PHP                    \ main loop's next DORND uses the carry M% leaves)
 PHA
 PHX
 PHY
 JSR G_FRAME
 PLY
 PLX
 PLA
 PLP
 RTS
 EQUB 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 \ padding: keeps raster_vars' tables (R_DIRTYL0/1, R_WL at &xx03) from moving to &xxFF and page-crossing on every indexed read

\ H_PCURVE: PLS22 is about to compute an ellipse (TGT segments): start a new
\ curve (PLS22 calls PM_HOOK, in bank 4, which comes here). H_BPT: BLINE has
\ the next point in K6(1 0), K6(3 2): record it. Both preserve X, Y and C
\ (both callers reload A and set N and Z straight after).

.H_PCURVE
 LDA QQ11
 ORA GFORCE
 BNE hpc9
 JMP G_PCURVE

.H_BPT
 LDA QQ11
 ORA GFORCE
 BNE hpc9
 JMP G_PPOINT
.hpc9
 RTS
