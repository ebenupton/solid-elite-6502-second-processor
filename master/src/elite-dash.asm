\ ******************************************************************************
\
\       Name: DASHBOARD
\       Type: Subroutine
\   Category: Dashboard
\    Summary: Port: the MODE 1 CMYK dashboard (DIALS, SCAN, DOT, the bulbs and
\             the missile indicators)
\
\ ------------------------------------------------------------------------------
\
\ Port (from the Demonstration Disc port's dashboard, src/elite-source.asm):
\ the dashboard (&7000-&7DFF, 7 character rows of 64 bytes x 8 lines) is a
\ 256 x 56 MODE 1 image in the space view's palette (black, cyan, magenta,
\ yellow), drawn by master/tools/dashboard.py, which also generates the
\ colour, dot, bulb and missile tables (build/dashtab.asm) used here. It is
\ in shadow RAM, like Master Elite's own dashboard, so these routines set
\ ACCCON X while they write it (and run from bank 4, outside &3000-&7FFF).
\ Colours are 2x2 dither cells, kept as a pair of bytes: the four pixels for
\ even lines and for odd lines.
\
\ They replace Master Elite's DIALS, PZW, DILX, DIL, DIL2, ADDK, SCAN, CPIXK,
\ DOT, ECBLB2, ECBLB, SPBLB and MSBAR, and leave every game variable and
\ temporary that the game reads afterwards, and the registers and flags where
\ a caller can see them, as those did (see each routine). Only the bytes of
\ a bar that change are drawn.
\
\ ******************************************************************************

DCN_SAFE = 0            \ Colour numbers: shields, energy banks: safe
DCN_SAFE2 = 1           \ speed, temperatures: safe
DCN_FUEL = 2
DCN_ALT = 3
DCN_DANGER = 4
DCN_FLASH = 5
DCN_MARK = 6            \ roll / pitch marker

.dcolE
 EQUB DC_SAFE_E, DC_SAFE2_E, DC_FUEL_E, DC_ALT_E, DC_DANGER_E, DC_FLASH_E, DC_MARK_E
.dcolO
 EQUB DC_SAFE_O, DC_SAFE2_O, DC_FUEL_O, DC_ALT_O, DC_DANGER_O, DC_FLASH_O, DC_MARK_O

.dlmt                   \ the left n pixels of a byte, n = 0..3
 EQUB &00, &88, &CC, &EE

.dpE    EQUB 0          \ the current colour pair (even, odd lines)
.dpO    EQUB 0
.dmk    EQUB 0          \ the current byte mask
.dlo    EQUB 0          \ DSEG: byte range [dlo, dhi) of the indicator
.dhi    EQUB 0
.dsS    EQUB 0          \ DSEG: the segment [dsS, dsE) in pixels
.dsE    EQUB 0
.dl0    EQUB 0          \ DSEG: the first line and the number of lines
.dln    EQUB 0
.dcol   EQUB 0          \ DIL: the colour number
.dtmp   EQUB 0
.ddn    EQUB 0          \ ddot: lines to go
.deq    EQUB 0          \ DSEG: the segment's end byte, pixels in it
.der    EQUB 0
.dsq    EQUB 0          \ DSEG: the segment's start byte, pixels from it on
.dsr    EQUB 0
.dme    EQUB 0          \ DSEG: the masked even-line byte, even EOR odd
.dmx    EQUB 0
.dsx    EQUB 0
.dtv    EQUB 0
.dK     EQUB 0          \ DIL: colour numbers for values >= dT and < dT
.dK1    EQUB 0
.dT     EQUB 0          \ DIL: the colour threshold (pixels)
.dbank  EQUB 0, 0, 0, 0 \ the energy banks' bar lengths (32 per bank)
.dX1    EQUB 0          \ the dot's x-coordinate (SCAN, DOT)
.dlen   EQUB 0          \ SCAN: the stick's length (signed)
.dstab  SKIP 8          \ SCAN: the stick's byte for each line of a row

\ ------------------------------------------------------------------------------
\ DIALS: update the dashboard indicators, every iteration, as Master's DIALS.
\ The game's temporaries are left as that DIALS left them: K and K+1 (its
\ mode 2 colour bytes), T1 (its thresholds), XX15 (the energy banks at 16 per
\ bank), and P, R, S, T, U (the roll and pitch values are still calculated
\ with ADD, which is ADDK's twin). The MODE 1 dashboard's own values (colour
\ numbers dK/dK1, thresholds dT, the finer bar lengths) are its own.
\ ------------------------------------------------------------------------------

.DIALS
 LDA #%00001111         \ Shadow RAM at &3000-&7FFF (the dashboard), as Master
 STA VIA+&34            \ (and not Master's store to HAZEL &DDEB: HAZEL is the
                        \ renderer's)

 LDA #&A0               \ SC(1 0) = &71A0: the speed indicator (right panel,
 STA SC                 \ row 0, byte 52)
 LDA #&71
 STA SC+1

 JSR PZW2               \ high values: danger colour, low values: safe (2)
 STX K+1
 STA K
 STY dK
 LDA #DCN_SAFE2
 STA dK1

 LDA #14                \ (T1 as Master)
 STA T1
 LDA #28                \ speed: 0-40, one pixel per unit, danger from 28
 STA dT
 LDA DELTA
 JSR DIL

 STZ R                  \ Roll and pitch, calculated as Master (ADD, ADDK's
 STZ P                  \ twin), for the side effects on P, R, S, T, T1, U
 LDA #8
 STA S
 LDA ALP1
 LSR A
 LSR A
 ORA ALP2
 EOR #%10000000
 JSR ADD

                        \ The roll marker: at 15 -/+ ALP1 / 2 (0..30), on the
                        \ side Master's ADD put it

 LDA ALP1
 LSR A
 STA dtv
 LDA ALP2
 BMI drl1               \ (ALP2 positive gives the smaller value)
 LDA #15
 SEC
 SBC dtv
 BRA drl2
.drl1
 LDA #15
 CLC
 ADC dtv
.drl2
 JSR DIL2               \ (returns C set, as Master's DIL2)

 LDA BETA               \ The pitch, as Master
 LDX BET1
 BEQ P%+4
 SBC #1
 JSR ADD

                        \ The pitch marker: at 15 +/- (2 * BET1 - 1), with
                        \ BETA's sign (sign-magnitude), 15 when BET1 = 0

 LDA BET1
 BEQ dpt1
 ASL A
 SEC
 SBC #1
.dpt1
 STA dtv
 LDA BETA
 BMI dpt2
 LDA #15
 CLC
 ADC dtv
 BRA dpt3
.dpt2
 LDA #15
 SEC
 SBC dtv
.dpt3
 JSR DIL2

                        \ The four energy banks, first as Master (XX15, 16 per
                        \ bank, from ENERGY / 4), then for the bars (dbank, 32
                        \ per bank, from ENERGY / 2), each filling from the
                        \ bottom bank up

 JSR PZW                \ high values: safe colour, low values: danger
 STX K
 STA K+1
 STY dK1
 LDY #0
 LDA #DCN_SAFE
 STA dK
 LDX #3
 STX T1
 LDA #6                 \ danger below 6 pixels (Master's 3 of 16)
 STA dT

.dll23
 STY XX15,X
 STZ dbank,X
 DEX
 BPL dll23
 LDX #3
 LDA ENERGY
 LSR A
 LSR A
 STA Q
.dll24
 SEC
 SBC #16
 BCC dll26
 STA Q
 LDA #16
 STA XX15,X
 LDA Q
 DEX
 BPL dll24
 BMI dll27
.dll26
 LDA Q
 STA XX15,X
.dll27
 LDX #3
 LDA ENERGY
 LSR A
 STA dtv
.dll28
 SEC
 SBC #32
 BCC dll29
 STA dtv
 LDA #32
 STA dbank,X
 LDA dtv
 DEX
 BPL dll28
 BMI dll9a
.dll29
 LDA dtv
 STA dbank,X
.dll9a
 LDY #0
.dll9
 LDA dbank,Y
 STY P
 JSR DIL
 LDY P
 INY
 CPY #4
 BNE dll9

 LDA #&70               \ SC(1 0) = &7020: forward shield (left panel, row 0,
 STA SC+1               \ byte 4)
 LDA #&20
 STA SC

 LDA FSH                \ shields: 0-255 -> 0-31 (danger below 6, as above)
 LSR A
 LSR A
 LSR A
 JSR DIL
 LDA ASH
 LSR A
 LSR A
 LSR A
 JSR DIL

 LDA #YELLOW2           \ fuel: 0-70 -> 0-35 (clipped at 32)
 STA K
 STA K+1
 LDA #DCN_FUEL
 STA dK
 STA dK1
 LDA QQ14
 LSR A
 JSR DIL

 JSR PZW2               \ temperatures: high values danger, low safe (2)
 STX K+1
 STA K
 STY dK
 LDA #DCN_SAFE2
 STA dK1
 LDX #11
 STX T1
 LDA #22                \ danger from 22 pixels (Master's 11 of 16)
 STA dT
 LDA CABTMP
 LSR A
 LSR A
 LSR A
 JSR DIL
 LDA GNTMP
 LSR A
 LSR A
 LSR A
 JSR DIL

 LDA #240               \ altitude: 0-255 -> 0-31, one colour
 STA T1
 STA dT
 LDA #YELLOW2
 STA K
 STA K+1
 LDA #DCN_ALT
 STA dK
 STA dK1
 LDA ALTIT
 LSR A
 LSR A
 LSR A
 JSR DIL

 LDA #%00001001         \ Main RAM back at &3000-&7FFF
 STA VIA+&34

 JMP COMPAS             \ and the compass, returning from there

\ ------------------------------------------------------------------------------
\ PZW: X = the safe colour byte, A = the danger colour byte, as Master's (red,
\ or green on every other 8 iterations if flashing is enabled), and Y = the
\ danger colour number. PZW2: the same with the second safe colour
\ ------------------------------------------------------------------------------

.PZW2
 LDX #WHITE2
 EQUB &2C               \ skip the next instruction (BIT abs)

.PZW
 LDX #STRIPE
 LDA MCNT
 AND #%00001000
 AND FLH
 BEQ pzw1
 LDY #DCN_FLASH
 LDA #GREEN2
 RTS
.pzw1
 LDY #DCN_DANGER
 LDA #RED2
 RTS

\ ------------------------------------------------------------------------------
\ DIL: draw a bar of A pixels (clipped to 32) at SC(1 0) in colour dK if A >= dT,
\ else dK1, on lines 2-4 of the character row, then move SC down a row. Only
\ the bytes that differ from what is on screen are drawn (DILQ/DILC remember
\ each bar's length and colour). Returns C clear, as Master's DIL
\ ------------------------------------------------------------------------------

.DIL
 CMP #33
 BCC P%+4
 LDA #32
 STA dsE
 CMP dT
 LDA dK
 BCS P%+5
 LDA dK1
 STA dcol
 JSR DILI
 LDA dcol
 CMP DILC,X
 BNE dil3               \ new colour: redraw all of it
 LDA dsE
 CMP DILQ,X
 BEQ dil9               \ unchanged
 BCC dil1
 LDY DILQ,X             \ longer: bytes old DIV 4 to (new + 3) DIV 4
 STA dhi
 TYA
 BRA dil2
.dil1
 LDY DILQ,X             \ shorter: bytes new DIV 4 to (old + 3) DIV 4
 STY dhi
.dil2
 LSR A
 LSR A
 STA dlo
 LDA dhi
 CLC
 ADC #3
 LSR A
 LSR A
 STA dhi
 BRA dil4
.dil3
 STA DILC,X
 STZ dlo
 LDA #8
 STA dhi
.dil4
 LDA dsE
 STA DILQ,X
 STZ dsS
 LDA #2                 \ lines 2-4
 STA dl0
 LDA #3
 STA dln
 JSR DSEG
.dil9
 INC SC+1               \ the next character row down
 INC SC+1
 CLC
 RTS

\ ------------------------------------------------------------------------------
\ DIL2: draw the roll / pitch marker at pixels A, A + 1 (A = 0..30) of the
\ indicator at SC(1 0), on lines 1-5, then move SC down a row. Returns C set,
\ as Master's DIL2 (DIALS' pitch calculation takes it in)
\ ------------------------------------------------------------------------------

.DIL2
 CMP #31
 BCC P%+4
 LDA #30
 STA dsS
 CLC
 ADC #2
 STA dsE
 JSR DILI
 LDA DILQ,X
 CMP #&FF
 BEQ dl23               \ nothing drawn yet: all of it
 CMP dsS
 BEQ dl29               \ unchanged
 BCC dl21
 LDY dsS                \ old > new: bytes new DIV 4 to (old + 2) DIV 4
 BRA dl22
.dl21
 TAY                    \ old < new: bytes old DIV 4 to (new + 2) DIV 4
 LDA dsS
.dl22
 CLC
 ADC #5
 LSR A
 LSR A
 STA dhi
 TYA
 LSR A
 LSR A
 STA dlo
 BRA dl24
.dl23
 STZ dlo
 LDA #8
 STA dhi
.dl24
 LDA dsS
 STA DILQ,X
 LDA #DCN_MARK
 STA dcol
 LDA #1                 \ lines 1-5
 STA dl0
 LDA #5
 STA dln
 JSR DSEG
.dl29
 INC SC+1
 INC SC+1
 SEC
 RTS

\ ------------------------------------------------------------------------------
\ DILI: X = the cache index of the indicator at SC(1 0): its character row,
\ plus 8 for the right panel
\ ------------------------------------------------------------------------------

.DILI
 LDA SC+1
 AND #%00001110
 LSR A
 BIT SC
 BPL P%+4
 ORA #8
 TAX
 RTS

.DILQ                   \ the length (bars) or position (markers) on screen
 FOR I%, 0, 15
  EQUB &FF
 NEXT

.DILC                   \ the colour number of the bars on screen
 FOR I%, 0, 15
  EQUB &FF
 NEXT

\ ------------------------------------------------------------------------------
\ DSEG: draw bytes dlo..dhi-1 of an indicator at SC(1 0): the pixels of the
\ segment [dsS, dsE) in colour dcol, the rest black, on dln lines from dl0
\ ------------------------------------------------------------------------------

.DSEG
 LDX dcol
 LDA dcolE,X
 STA dpE
 LDA dcolO,X
 STA dpO
 LDA dsE                \ the segment's end: byte deq, pixels der in it
 LSR A
 LSR A
 STA deq
 LDA dsE
 AND #3
 TAX
 LDA dlmt,X
 STA der
 LDA dsS                \ and its start: byte dsq, pixels dsr from it on
 LSR A
 LSR A
 STA dsq
 LDA dsS
 AND #3
 TAX
 LDA dlmt,X
 EOR #&FF
 STA dsr
 LDX dlo

.dsg1
 CPX dhi
 BCS dsg9
 LDA #&FF               \ the mask: before the end byte all, at it der, after
 CPX deq                \ it none
 BCC dsg3
 BNE dsg2
 LDA der
 BRA dsg3
.dsg2
 LDA #0
.dsg3
 CPX dsq                \ and before the start byte none, at it only from
 BCC dsg4               \ pixel dsS AND 3 on (dsr)
 BNE dsg5
 AND dsr
 BRA dsg5
.dsg4
 LDA #0
.dsg5
 STA dmk
 AND dpE                \ dme = the even-line byte, dmx = even EOR odd
 STA dme
 LDA dmk
 AND dpO
 EOR dme
 STA dmx
 TXA                    \ Y = 8 * byte + first line
 ASL A
 ASL A
 ASL A
 ORA dl0
 TAY
 STX dsx
 LDA dl0                \ the first line's byte
 LSR A
 LDA dme
 BCC P%+5
 EOR dmx
 LDX dln
.dsg7
 STA (SC),Y
 EOR dmx                \ the next line's
 INY
 DEX
 BNE dsg7
 LDX dsx
 INX
 BNE dsg1
.dsg9
 RTS

\ ------------------------------------------------------------------------------
\ ddot: EOR a 3-pixel dot at dX1..dX1 + 2 on ddn lines (1 or 2) up from screen
\ line A, in the colour whose dot tables (dt0E etc., from dashboard.py) are
\ indexed by X = 4 * colour class + (dX1 AND 3). Leaves SC(1 0) and Y (0-7)
\ at its top line, X as it was
\ ------------------------------------------------------------------------------

.ddot
 TAY
 LSR A
 LSR A
 AND #%11111110
 ORA #&40
 STA SCH
 LDA dX1
 AND #%11111100
 ASL A
 STA SC
 BCC P%+4
 INC SCH
 TYA
 AND #7
 TAY

.ddl
 TYA                    \ even or odd line
 LSR A
 BCS ddo
 LDA dt0E,X
 EOR (SC),Y
 STA (SC),Y
 LDA dt1E,X
 BEQ ddn2
 STA dmk
 TYA
 ORA #8
 TAY
 LDA dmk
 EOR (SC),Y
 STA (SC),Y
 TYA
 AND #7
 TAY
 BRA ddn2
.ddo
 LDA dt0O,X
 EOR (SC),Y
 STA (SC),Y
 LDA dt1O,X
 BEQ ddn2
 STA dmk
 TYA
 ORA #8
 TAY
 LDA dmk
 EOR (SC),Y
 STA (SC),Y
 TYA
 AND #7
 TAY
.ddn2
 DEC ddn
 BEQ ddt9
 DEY                    \ the line above
 BPL ddl
 LDY #7
 DEC SCH
 DEC SCH
 BNE ddl                \ (always)
.ddt9
 RTS

\ ------------------------------------------------------------------------------
\ SCAN: draw (or erase, as it uses EOR) the current ship on the scanner: a
\ 3 x 2 dot at (dX1, Y1 - 1 .. Y1) and a one-pixel stick at dX1 + 1 to the
\ ship's position in the scanner's plane (Y2), as Master's SCAN plots its dash
\ at (X1, Y1) and its stick: so it leaves COL (Master's scanner colour), X1
\ (rounded to even), Y1 (the dot's line) and Y2 (the stick's base) as Master
\ does, and returns as Master's: A = %00001001 (ACCCON), X = 0, and with no
\ stick Y = Y1 AND 7 and C set, with an upward one Y = (Y2 - 1) AND 7 and C
\ set, with a downward one Y = (Y2 + 1) AND 7 and C clear
\ ------------------------------------------------------------------------------

.scr1
 RTS

.SCAN
 LDA INWK+31            \ not if it isn't shown on the scanner
 AND #%00010000
 BEQ scr1
 LDX TYPE               \ or is the planet or sun
 BMI scr1
 LDA scacol,X           \ COL = Master's scanner colour, as it leaves it
 STA COL
 LDA INWK+1             \ or is out of range
 ORA INWK+4
 ORA INWK+7
 AND #%11000000
 BNE scr1

 LDA INWK+1             \ dX1 = 125 + x_hi, and X1 = that rounded to even, as
 CLC                    \ Master (the dot is drawn at dX1)
 LDX INWK+2
 BPL scn2
 EOR #%11111111
 ADC #1
 CLC
.scn2
 ADC #125
 STA dX1
 AND #%11111110
 STA X1

 LDA INWK+7             \ Y2 = 220 - z_hi / 4: the stick's base, as Master
 LSR A
 LSR A
 CLC
 LDY INWK+8
 BPL scn3
 EOR #%11111111
 SEC
.scn3
 ADC #35
 EOR #%11111111
 STA Y2

 LDA INWK+4             \ Y1 = Y2 - y_hi / 2, clipped to 194..246, as Master
 LSR A
 CLC
 LDY INWK+5
 BMI scn4
 EOR #%11111111
 SEC
.scn4
 ADC Y2
 BPL scn5
 CMP #194
 BCS P%+4
 LDA #194
 CMP #247
 BCC P%+4
.scn5
 LDA #246
 STA Y1

 LDY #%00001111         \ Shadow RAM at &3000-&7FFF (the dashboard)
 STY VIA+&34

 LDX TYPE               \ X = the dot tables' index: 4 * class + (dX1 AND 3)
 LDA dtcls,X
 STA dtmp
 LDA dX1
 AND #3
 ORA dtmp
 TAX
 STX dtmp

 SEC                    \ dlen = Y1 - Y2: the stick's length, up if positive
 LDA Y1
 SBC Y2
 STA dlen

 LDA #2                 \ the dot, lines Y1 - 1 and Y1 (no higher than lines
 STA ddn                \ 194-195, the dashboard's first two)
 LDA Y1
 CMP #195
 BCS P%+4
 LDA #195
 JSR ddot               \ (leaves SC, Y at the dot's top line)

 LDA dlen
 BEQ scnz
 LDX dtmp
 TXA                    \ the stick: the dot's middle pixel, which is in its
 AND #3                 \ second byte if dX1 AND 3 = 3
 CMP #3
 BNE scs1
 LDA SC
 CLC
 ADC #8
 STA SC
 BCC scs1
 INC SCH
.scs1
 LDA dtsE,X             \ the stick's byte for each line of a character row
 STA dstab
 STA dstab+2
 STA dstab+4
 STA dstab+6
 LDA dtsO,X
 STA dstab+1
 STA dstab+3
 STA dstab+5
 STA dstab+7

 LDX dlen
 BMI scndn
 DEX                    \ up from the line above the dot's top: lines Y2 to
 BEQ scnu9              \ Y1 - 2 (the dot covers Y1 - 1), dlen - 1 of them

.scnup
 DEY
 BPL scu1
 LDY #7
 DEC SCH
 DEC SCH
.scu1
 LDA dstab,Y
 EOR (SC),Y
 STA (SC),Y
 DEX
 BNE scnup
.scnu9
 LDA Y2                 \ Y = (Y2 - 1) AND 7, C set, as Master after an upward
 DEC A                  \ stick (its loop's last DEY)
 BRA scnex

.scnz                   \ No stick: Y = Y1 AND 7, C set, as Master
 LDA Y1
.scnex
 AND #7
 TAY
 LDX #0
 SEC
 LDA #%00001001         \ Main RAM back at &3000-&7FFF (A as Master leaves it)
 STA VIA+&34
 RTS

.scndn                  \ down from the dot's lower line, X = -(length): lines
 INY                    \ Y1 + 1 to Y2
 CPY #8
 BNE scd2
 LDY #0
 INC SCH
 INC SCH
.scd2
 LDA dstab,Y
 EOR (SC),Y
 STA (SC),Y
 INX
 BNE scndn
 LDA Y2                 \ Y = (Y2 + 1) AND 7, C clear, as Master after a
 INC A                  \ downward stick (its loop's last INY)
 AND #7
 TAY
 LDX #0
 CLC
 LDA #%00001001
 STA VIA+&34
 RTS

\ ------------------------------------------------------------------------------
\ DOT: draw (EOR) the compass dot at (COMX, COMY) in colour COMC: YELLOW2 (in
\ front) a 3 x 2 dot, GREEN2 (behind) a 3 x 1 one. Leaves X1 = COMX, COL =
\ COMC and Y1 = COMY (minus one for the 3 x 2 dot), and A = %00001001, as
\ Master's DOT
\ ------------------------------------------------------------------------------

.DOT
 LDA #%00001111         \ Shadow RAM at &3000-&7FFF (the dashboard)
 STA VIA+&34
 LDA COMX
 STA X1
 CMP #186               \ dX1 = COMX kept inside the compass ring (186..204,
 BCS P%+4               \ so its pixels stay left of the panel divider at
 LDA #186               \ x = 207)
 CMP #205
 BCC P%+4
 LDA #204
 STA dX1
 AND #3
 TAX
 LDA COMY
 STA Y1
 CMP #195               \ the lower line, COMY kept to 195..213, inside the
 BCS P%+4               \ ring and off the dashboard's first two lines
 LDA #195
 CMP #214
 BCC P%+4
 LDA #213
 STA dtmp
 LDA COMC
 STA COL
 CMP #YELLOW2
 BNE dot1
 TXA                    \ In front: a double-height dot, Y1 one less
 ORA #4 * DT_FRONT
 TAX
 LDA #2
 STA ddn
 DEC Y1
 BRA dot2
.dot1
 TXA                    \ Behind: a single-height dot
 ORA #4 * DT_BEHIND
 TAX
 LDA #1
 STA ddn
.dot2
 LDA dtmp
 JSR ddot
 LDA #%00001001         \ Main RAM back at &3000-&7FFF
 STA VIA+&34
 RTS

\ ------------------------------------------------------------------------------
\ ECBLB2: start up the E.C.M. (ECMA = 32), then light up its bulb. ECBLB,
\ SPBLB: EOR the E.C.M. or space station bulb onto the dashboard. They return
\ as Master's: A = %00001001, X preserved, Y = &FF
\ ------------------------------------------------------------------------------

.ECBLB2
 LDA #32
 STA ECMA

.ECBLB
 LDA #&70               \ the E.C.M. bulb's bitmap, at &7A70 (row 5, bytes
 STA SC                 \ 14-15)
 LDA #&7A
 STA SC+1
 LDY #15
 LDA #%00001111
 STA VIA+&34
.bul1
 LDA ECBT,Y
 EOR (SC),Y
 STA (SC),Y
 DEY
 BPL bul1
 BMI bul3

.SPBLB
 LDA #&80               \ the space station bulb's bitmap, at &7B80 (row 5,
 STA SC                 \ bytes 48-49)
 LDA #&7B
 STA SC+1
 LDY #15
 LDA #%00001111
 STA VIA+&34
.bul2
 LDA SPBT,Y
 EOR (SC),Y
 STA (SC),Y
 DEY
 BPL bul2
.bul3
 LDA #%00001001
 STA VIA+&34
 RTS

\ ------------------------------------------------------------------------------
\ MSBAR: draw missile indicator X (1-4) in colour Y (0 = none, GREEN2 =
\ unarmed, YELLOW2 = armed, RED2 = locked) in row 6, bytes 12 - 2X and 13 -
\ 2X. Returns as Master's: X preserved, Y = 0 (ABORT2 stores it in MSAR), T =
\ X * 16, A = %00001001
\ ------------------------------------------------------------------------------

.MSBAR
 STY dtv                \ keep the colour argument and X
 STX dsx
 TXA                    \ T = X * 16, as Master
 ASL A
 ASL A
 ASL A
 ASL A
 STA T
 STA dtmp               \ SC(1 0) = &7C60 - X * 16
 LDA #&60
 SEC
 SBC dtmp
 STA SC
 LDA #&7C
 STA SCH

 LDX #0                 \ X = the colour number: none, unarmed, armed, locked
 LDA dtv
 BEQ msb3
 INX
 CMP #GREEN2
 BEQ msb3
 INX
 CMP #YELLOW2
 BEQ msb3
 INX
.msb3
 LDA dmscolE,X
 STA dpE
 LDA dmscolO,X
 STA dpO

 LDA #%00001111         \ Shadow RAM at &3000-&7FFF (the dashboard)
 STA VIA+&34
 LDX #0                 \ X = the index into the shape's masks
 LDY #1                 \ Y = the line, 1 to 5
.msb1
 TYA                    \ the colour for this line
 LSR A
 LDA dpE
 BCC P%+5
 LDA dpO
 STA dmk
 AND dmsmask,X          \ the left byte
 STA (SC),Y
 TYA
 ORA #8
 TAY
 LDA dmk
 AND dmsmask+1,X        \ the right byte
 STA (SC),Y
 TYA
 AND #7
 TAY
 INX
 INX
 INY
 CPY #6
 BNE msb1

 LDX dsx                \ X preserved, Y = 0, as Master
 LDY #0
 LDA #%00001001
 STA VIA+&34
 RTS

\ ------------------------------------------------------------------------------
\ The dashboard's generated tables (master/tools/dashboard.py)
\ ------------------------------------------------------------------------------

INCLUDE "build/dashtab.asm"
